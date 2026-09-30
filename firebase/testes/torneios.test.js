// torneios.test.js — prova o BLOCO DE TORNEIOS do firestore.rules contra o
// emulador, e prova UMA coisa: o cliente nao escreve nada ali.
//
// POR QUE ESTA SUITE NASCEU AGORA, E POR QUE ELA E DA FUNDACAO
//
// O bloco de torneios existe em `firestore.rules` desde a OS 02 e NUNCA teve
// suite de regras. Tinha `results`, `standings`, `conclusion` e `phases` todos
// fechados — e uma porta aberta em `registrations`, autorizada por um comentario
// que dizia: "a elegibilidade, a lotacao e a janela sao revalidadas pela Function
// que reage a este documento".
//
// Essa Function nunca existiu. Os unicos gatilhos de documento do repositorio
// sao `aoRegistrarPartida`, `aoRegistrarResultadoOficial`, `aoBloquearJogador` e
// `aoConcluirEdicao`; nenhum reage a `registrations`. O efeito era completo: um
// cliente autenticado criava a propria inscricao em torneio VIP, lotado, fora da
// janela, com o perfil suspenso e sem pagar ficha — e a linha contava na lotacao
// lida pelo `tickTorneios`.
//
// A porta fechou na OS de Fundacao da Base P. Esta suite e o que impede que ela
// reabra, e por isso ela mede pelos DOIS lados: o que o cliente nao pode (a
// maioria dos casos) e o que a AUTORIDADE ainda consegue (SEM-01), porque uma
// regra que fechasse os dois teria quebrado o backend em vez de proteger.
//
// A DIVISAO DE TRABALHO, como em passe.test.js e ranking.test.js:
//
//   dominio puro -> quem PODE se inscrever. app/test/torneios/.
//   fundacao     -> que modelo pode existir. app/test/torneios/fundacao_base_p_test.dart.
//   rules (aqui) -> o que o BANCO permite ao cliente. E a resposta e: ler.
//
// Uso:
//   cd firebase/testes && npm install
//   firebase emulators:exec --only firestore "npm run test:torneios"

'use strict';

const fs = require('fs');
const path = require('path');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
} = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const DONO = 'uid_dono_torneio';
const ALHEIO = 'uid_alheio_torneio';
const ADMIN = 'uid_admin_torneio';

const TORNEIO = 'sexta_master_vip';
const EDICAO = 'ed-2026-08';

const T0 = '2026-08-22T20:00:00.000Z';

/// Caminho da inscricao do jogador, na forma que as Rules casam.
const INSCRICAO = ['tournaments', TORNEIO, 'editions', EDICAO, 'registrations', DONO];

let ambiente;

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Semeia o que SO o backend escreveria — pelo caminho do Admin SDK, que e o
  // que `withSecurityRulesDisabled` representa. E justamente o ponto: a
  // autoridade escreve por fora das Rules, e o cliente nao tem esse caminho.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, 'tournaments', TORNEIO), {
      templateId: TORNEIO,
      esquema: 1,
      versao: 1,
      acesso: 'vip',
      participacao: 'individual',
      publicado: false,
    });

    await setDoc(doc(db, 'tournaments', TORNEIO, 'editions', EDICAO), {
      tournamentId: TORNEIO,
      editionId: EDICAO,
      status: 'inscricoes_abertas',
      temporada: '2026',
    });

    await setDoc(doc(db, ...INSCRICAO), {
      userId: DONO,
      tournamentId: TORNEIO,
      editionId: EDICAO,
      status: 'inscrito',
      inscritoEm: T0,
      atualizadoEm: T0,
      fichasDebitadas: 100,
      chaveIdempotencia: `${TORNEIO}|${EDICAO}|${DONO}`,
    });

    for (const [colecao, id, dados] of [
      ['phases', 'fase-1', { faseId: 'fase-1', ordem: 1, status: 'em_andamento' }],
      ['tables', 'mesa-1', { mesaId: 'mesa-1', faseId: 'fase-1', status: 'aberta' }],
      ['results', 'res-1', { matchId: 'm-1', faseId: 'fase-1' }],
      ['standings', DONO, { participanteId: DONO, posicao: 1 }],
      ['conclusion', 'final', { campeoes: [DONO] }],
    ]) {
      await setDoc(
        doc(db, 'tournaments', TORNEIO, 'editions', EDICAO, colecao, id),
        dados
      );
    }
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

/// Os quatro papeis do arquivo. O ADMIN entra de proposito nos casos de escrita
/// competitiva: "so o admin" seria uma porta, e porta se atravessa.
function contextos() {
  return [
    ['o DONO da inscricao', ambiente.authenticatedContext(DONO)],
    ['um TERCEIRO autenticado', ambiente.authenticatedContext(ALHEIO)],
    ['o ADMIN', ambiente.authenticatedContext(ADMIN, { admin: true })],
    ['quem NAO esta autenticado', ambiente.unauthenticatedContext()],
  ];
}

// ===========================================================================
describe('TRN-RULES/INSCRICAO — a porta que estava aberta', () => {
  test('TRI-01: NINGUEM cria inscricao pelo cliente', async () => {
    // Era isto que passava antes da fundacao. A forma do documento e a MESMA
    // que a regra antiga aceitava — userId proprio, status inicial, sem
    // `posicaoEspera`, sem `fichasDebitadas` —, e agora ela e recusada.
    const nova = ['tournaments', TORNEIO, 'editions', EDICAO, 'registrations', ALHEIO];
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), ...nova), {
          userId: ALHEIO,
          tournamentId: TORNEIO,
          editionId: EDICAO,
          status: 'inscrito',
          inscritoEm: T0,
          atualizadoEm: T0,
          chaveIdempotencia: `${TORNEIO}|${EDICAO}|${ALHEIO}`,
        }),
        quem
      );
    }
  });

  test('TRI-02: o proprio dono nao altera a inscricao, nem para cancelar', async () => {
    // Cancelar era a UNICA escrita que sobrava, e sai junto: cancelamento move
    // vaga, e vaga e decisao de quem sabe a janela e a lista de espera.
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        updateDoc(doc(ctx.firestore(), ...INSCRICAO), {
          status: 'cancelado',
          atualizadoEm: T0,
        }),
        quem
      );
    }
  });

  test('TRI-03: ninguem se promove a check-in realizado', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        updateDoc(doc(ctx.firestore(), ...INSCRICAO), {
          status: 'checkin_realizado',
          atualizadoEm: T0,
        }),
        quem
      );
    }
  });

  test('TRI-04: ninguem indica parceiro', async () => {
    // A V1 e individual. O campo nem deveria existir no documento — e, se
    // existir, nao e o cliente quem o escreve.
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        updateDoc(doc(ctx.firestore(), ...INSCRICAO), { parceiroId: ALHEIO }),
        quem
      );
    }
  });

  test('TRI-05: ninguem declara o proprio pagamento', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        updateDoc(doc(ctx.firestore(), ...INSCRICAO), { fichasDebitadas: 0 }),
        quem
      );
    }
  });

  test('TRI-06: ninguem apaga a inscricao', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(deleteDoc(doc(ctx.firestore(), ...INSCRICAO)), quem);
    }
  });

  test('TRI-07: a LEITURA continua — o dono ve a propria, e o terceiro nao', async () => {
    // Fechar a leitura junto seria confundir "nao escreve" com "nao existe".
    await assertSucceeds(
      getDoc(doc(ambiente.authenticatedContext(DONO).firestore(), ...INSCRICAO))
    );
    await assertSucceeds(
      getDoc(doc(
        ambiente.authenticatedContext(ADMIN, { admin: true }).firestore(),
        ...INSCRICAO
      ))
    );
    await assertFails(
      getDoc(doc(ambiente.authenticatedContext(ALHEIO).firestore(), ...INSCRICAO))
    );
  });
});

// ===========================================================================
describe('TRN-RULES/COMPETICAO — nada disso e do cliente', () => {
  const alvos = [
    ['phases', 'fase-1', { status: 'concluida' }],
    ['tables', 'mesa-1', { status: 'encerrada' }],
    ['results', 'res-1', { vencedor: DONO }],
    ['standings', DONO, { posicao: 1 }],
    ['conclusion', 'final', { campeoes: [DONO] }],
  ];

  for (const [colecao, id, dados] of alvos) {
    test(`TRC-${colecao}: ninguem escreve em ${colecao}`, async () => {
      for (const [quem, ctx] of contextos()) {
        const ref = doc(
          ctx.firestore(), 'tournaments', TORNEIO, 'editions', EDICAO, colecao, id
        );
        await assertFails(setDoc(ref, dados), `${quem} setDoc`);
        await assertFails(updateDoc(ref, dados), `${quem} updateDoc`);
        await assertFails(deleteDoc(ref), `${quem} deleteDoc`);
      }
    });
  }

  test('TRC-01: ninguem cria nem aprova EDICAO', async () => {
    // Criar edicao e aprovar edicao sao as duas operacoes que a fundacao mantem
    // indisponiveis. O ADMIN esta na lista: o claim `admin` nao tem produtor
    // nesta arvore, e mesmo que tivesse, a publicacao passa por Function — e
    // pelo grafo, que exige aprovador distinto do criador.
    for (const [quem, ctx] of contextos()) {
      const nova = doc(
        ctx.firestore(), 'tournaments', TORNEIO, 'editions', 'ed-forjada'
      );
      await assertFails(setDoc(nova, { status: 'inscricoes_abertas' }), quem);

      const existente = doc(
        ctx.firestore(), 'tournaments', TORNEIO, 'editions', EDICAO
      );
      await assertFails(updateDoc(existente, { status: 'agendado' }), quem);
    }
  });

  test('TRC-02: ninguem registra premiacao', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), 'rewardGrants', `${TORNEIO}|${EDICAO}|${DONO}`), {
          userId: DONO,
          assetId: 'crown_champion',
        }),
        quem
      );
    }
  });

  test('TRC-03: ninguem forja qualificacao anual nem convite', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), 'annualQualifications', `2026|${TORNEIO}|${EDICAO}|${DONO}`), {
          userId: DONO, temporada: '2026',
        }),
        `${quem} annualQualifications`
      );
      await assertFails(
        setDoc(doc(ctx.firestore(), 'closingInvites', `2026|${DONO}`), {
          userId: DONO, temporada: '2026', status: 'convite_aceito',
        }),
        `${quem} closingInvites`
      );
    }
  });

  test('TRC-04: ninguem escreve o proprio historico de torneio', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), 'tournamentHistory', `${TORNEIO}|${EDICAO}`), {
          campeoes: [DONO],
        }),
        quem
      );
    }
  });
});

// ===========================================================================
describe('TRN-RULES/VIZINHANCA — o que nao pode vazar por tabela', () => {
  test('TRV-01: ninguem declara o proprio VIP', async () => {
    // A elegibilidade do torneio le `playerEntitlements`. Se o cliente pudesse
    // escrever ali, todo o resto desta suite seria decorativo.
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), 'playerEntitlements', DONO), {
          vipAtivo: true, estado: 'ativo',
        }),
        quem
      );
    }
  });

  test('TRV-02: ninguem levanta a propria suspensao', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), 'playerModeration', DONO), {
          suspensoAte: null, suspensaoPermanente: false,
        }),
        quem
      );
    }
  });

  test('TRV-03: a fila de tarefas e a trilha de auditoria sao fechadas', async () => {
    for (const [quem, ctx] of contextos()) {
      for (const colecao of ['tournamentTasks', 'tournamentJobs', 'tournamentAudit']) {
        await assertFails(
          setDoc(doc(ctx.firestore(), colecao, 'chave-forjada'), { x: 1 }),
          `${quem} ${colecao}`
        );
      }
    }
  });

  test('TRV-04: ninguem se poe no Hall', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(
        setDoc(doc(ctx.firestore(), 'hallEntries', `2026|${DONO}`), { uid: DONO }),
        quem
      );
    }
  });

  test('TRV-05: caminho vizinho inventado continua negado pelo fecho padrao', async () => {
    // Os erros de digitacao mais provaveis de quem for mexer aqui depois.
    const db = ambiente.authenticatedContext(DONO).firestore();
    for (const colecao of ['registrations', 'torneios', 'tournamentRegistrations']) {
      await assertFails(setDoc(doc(db, colecao, DONO), { x: 1 }), colecao);
    }
  });
});

// ===========================================================================
describe('TRN-RULES/AUTORIDADE — a porta certa continua aberta', () => {
  test('SEM-01: o Admin SDK escreve tudo o que o cliente nao escreve', async () => {
    // ESTE CASO E O CONTROLE, e sem ele a suite inteira seria satisfeita por um
    // `allow read, write: if false` no topo do arquivo — que fecharia o cliente
    // E o backend, e passaria em todos os outros casos acima.
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await assertSucceeds(
        updateDoc(doc(db, ...INSCRICAO), { status: 'checkin_realizado' })
      );
      await assertSucceeds(
        setDoc(doc(db, 'tournaments', TORNEIO, 'editions', EDICAO, 'standings', DONO), {
          participanteId: DONO, posicao: 1,
        })
      );
      await assertSucceeds(
        setDoc(doc(db, 'rewardGrants', 'chave-do-backend'), { userId: DONO })
      );
    });
  });

  test('SEM-02: a vitrine continua legivel para o jogador autenticado', async () => {
    // Publico nao-VIP pode VER a vitrine; o que ele nao pode e inscrever-se.
    // Fechar a leitura transformaria "exclusivo para VIP" em "invisivel para
    // quem nao e VIP", que e outra decisao e ninguem a tomou.
    const db = ambiente.authenticatedContext(ALHEIO).firestore();
    await assertSucceeds(getDoc(doc(db, 'tournaments', TORNEIO)));
    await assertSucceeds(
      getDoc(doc(db, 'tournaments', TORNEIO, 'editions', EDICAO))
    );
  });
});
