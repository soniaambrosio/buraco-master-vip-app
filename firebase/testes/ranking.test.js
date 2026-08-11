// ranking.test.js — prova o BLOCO 6/6 do firestore.rules contra o emulador
// (OS Backend Autoritativo de Ranking, secoes 20 e 23).
//
// A DIVISAO DE TRABALHO E A MESMA DE rastreabilidade.test.js:
//
//   modulos puros -> o que uma DECISAO decide (ordem, cursor, liga, politica,
//                    idempotencia). Vive em functions-ranking/test/, roda sem
//                    emulador, 173 casos.
//   rules (aqui)  -> o que o BANCO permite. Quem escreve, quem le, quem apaga.
//
// Cobre, um caso por afirmacao da secao 20:
//   - o cliente NAO escreve a propria pontuacao;
//   - o cliente NAO escreve a propria posicao;
//   - o cliente NAO escreve a propria Liga;
//   - o cliente NAO cria, altera nem encerra temporada;
//   - o cliente NAO inventa uma escada de ligas;
//   - o cliente NAO se coloca no Hall;
//   - o cliente NAO marca uma partida como processada, nem desmarca;
//   - o cliente NAO le o mapeamento id publico -> uid;
//   - o cliente NAO le a classificacao crua (nem a propria linha);
//   - o cliente NAO apaga trilha de auditoria;
//   - o admin le a trilha, mas nao escreve por aqui;
//   - a temporada e a escada SAO legiveis por quem esta autenticado;
//   - quem nao esta autenticado nao le nada.
//
// Uso:
//   cd firebase/testes && npm install
//   firebase emulators:exec --only firestore "npm run test:ranking"

'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
} = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const DONO = 'uid_dono';
const ALHEIO = 'uid_alheio';
const ADMIN = 'uid_admin';

const TEMPORADA = '2026-A';
const LADDER = 'escada-2026';
const ID_PUBLICO_DONO = 'PDONO00000001';
const ID_PUBLICO_ALHEIO = 'PALHEIO000002';
const CHAVE_STANDING = `${TEMPORADA}|${DONO}`;
const CHAVE_STANDING_ALHEIO = `${TEMPORADA}|${ALHEIO}`;
const CHAVE_CONTRIBUICAO = `match-1|${TEMPORADA}|nao_definida|v0`;

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

  // Semeia o que SO o backend escreveria. `withSecurityRulesDisabled` e o
  // equivalente do Admin SDK: e assim que `functions-ranking/` popula tudo isto.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, 'rankingSeasons', TEMPORADA), {
      seasonId: TEMPORADA,
      nome: 'Temporada A',
      status: 'vigente',
      inicioEm: '2026-08-01T00:00:00.000Z',
      fimEm: null,
      // A politica REAL de hoje. O seed usa a pendente de proposito: semear uma
      // politica de mentira aqui faria o teste descrever um sistema que nao e o
      // que esta em producao.
      politica: { id: 'nao_definida', versao: 0 },
      ladderId: LADDER,
    });

    await setDoc(doc(db, 'rankingLadders', LADDER), {
      ladderId: LADDER,
      nome: 'escada de teste',
      degraus: [
        { ligaId: 'baixa', nome: 'BAIXA', icone: '', pontosMinimos: 0, pontosMaximos: 99 },
        { ligaId: 'alta', nome: 'ALTA', icone: '', pontosMinimos: 100, pontosMaximos: null },
      ],
    });

    for (const [chave, uid, pid, pontos, posicao] of [
      [CHAVE_STANDING, DONO, ID_PUBLICO_DONO, 120, 1],
      [CHAVE_STANDING_ALHEIO, ALHEIO, ID_PUBLICO_ALHEIO, 80, 2],
    ]) {
      await setDoc(doc(db, 'rankingStandings', chave), {
        seasonId: TEMPORADA,
        uid,
        publicPlayerId: pid,
        apelido: '',
        avatar: '',
        pontos,
        partidasComputadas: 3,
        posicao,
        posicaoAnterior: null,
        direcao: 'estavel',
        deltaPosicao: 0,
        ligaId: pontos >= 100 ? 'alta' : 'baixa',
        ligaNome: pontos >= 100 ? 'ALTA' : 'BAIXA',
        selo: null,
        atualizadoEm: '2026-08-11T16:00:00.000Z',
      });
    }

    await setDoc(doc(db, 'rankingPlayers', DONO), {
      uid: DONO,
      publicPlayerId: ID_PUBLICO_DONO,
      pontosTotais: 120,
      partidasTotais: 3,
      temporadaAtual: TEMPORADA,
    });
    await setDoc(doc(db, 'rankingPublicIds', ID_PUBLICO_DONO), {
      publicPlayerId: ID_PUBLICO_DONO,
      uid: DONO,
    });

    await setDoc(doc(db, 'rankingContributions', CHAVE_CONTRIBUICAO), {
      contributionId: CHAVE_CONTRIBUICAO,
      matchId: 'match-1',
      seasonId: TEMPORADA,
      politica: { id: 'nao_definida', versao: 0 },
      jogadores: [ALHEIO, DONO],
      deltas: { [DONO]: 10, [ALHEIO]: -10 },
      processadoEm: '2026-08-11T16:00:00.000Z',
    });

    await setDoc(doc(db, 'rankingBacklog', 'match-2'), {
      matchId: 'match-2',
      motivo: 'politica_nao_definida',
      jogadores: [DONO],
    });

    await setDoc(doc(db, 'rankingAudit', 'evento-1'), {
      eventoId: 'evento-1',
      evento: 'temporada_aberta',
      seasonId: TEMPORADA,
    });

    await setDoc(doc(db, 'rankingTasks', `${TEMPORADA}|apuracao|2026-08-11T16:00Z`), {
      chave: `${TEMPORADA}|apuracao|2026-08-11T16:00Z`,
      tarefa: 'apuracao',
    });

    // O Hall existe como colecao e esta VAZIO. Nenhum documento e semeado com
    // homenageado: nao ha criterio de elegibilidade definido, e semear um aqui
    // criaria em teste o dado ficticio que a secao 14 proibe em producao.
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoAlheio = () => ambiente.authenticatedContext(ALHEIO).firestore();
const comoAdmin = () => ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

// ---------------------------------------------------------------------------

describe('ranking: o jogador nao escreve a propria classificacao', () => {
  test('nao aumenta a propria pontuacao', async () => {
    // O item mais caro da secao 20. Um `update` aqui seria literalmente escolher
    // a propria pontuacao.
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingStandings', CHAVE_STANDING), { pontos: 999999 }),
    );
  });

  test('nao diminui a pontuacao de terceiros', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingStandings', CHAVE_STANDING_ALHEIO), { pontos: 0 }),
    );
  });

  test('nao escreve a propria posicao', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingStandings', CHAVE_STANDING), { posicao: 1 }),
    );
  });

  test('nao escreve a propria Liga', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingStandings', CHAVE_STANDING), {
        ligaId: 'alta',
        ligaNome: 'ALTA',
      }),
    );
  });

  test('nao cria uma linha de classificacao para si', async () => {
    // Sem esta negacao, bastaria criar `2026-A|meu_uid` com a pontuacao desejada
    // para entrar no ranking sem jogar.
    await assertFails(
      setDoc(doc(comoDono(), 'rankingStandings', `${TEMPORADA}|${DONO}-falso`), {
        seasonId: TEMPORADA,
        uid: DONO,
        pontos: 10000,
      }),
    );
  });

  test('nao apaga a propria linha para zerar uma temporada ruim', async () => {
    await assertFails(deleteDoc(doc(comoDono(), 'rankingStandings', CHAVE_STANDING)));
  });

  test('nem o admin escreve classificacao pelo cliente', async () => {
    // A escrita passa por Function inteira, para que ledger, contribuicao e
    // standing entrem na MESMA transacao. Um admin escrevendo direto criaria
    // pontuacao sem lancamento que a explique.
    await assertFails(
      updateDoc(doc(comoAdmin(), 'rankingStandings', CHAVE_STANDING), { pontos: 500 }),
    );
  });
});

describe('ranking: a classificacao crua nao e legivel', () => {
  test('o dono NAO le a propria linha crua', async () => {
    // Nao e desconfianca do dono: o documento carrega o `uid`, e liberar o `get`
    // daria a forma de descobrir o uid por tras de um id publico tentando
    // `rankingStandings/{season}|{uid}`. A propria linha chega pelo campo `eu` de
    // `abrirRanking`, projetada.
    await assertFails(getDoc(doc(comoDono(), 'rankingStandings', CHAVE_STANDING)));
  });

  test('ninguem varre a colecao de classificacao', async () => {
    await assertFails(getDocs(collection(comoDono(), 'rankingStandings')));
  });

  test('o mapeamento id publico -> uid nunca e legivel', async () => {
    // Entregar este documento seria o mesmo que nao ter separado identidade
    // publica de UID (secao 16).
    await assertFails(getDoc(doc(comoDono(), 'rankingPublicIds', ID_PUBLICO_DONO)));
    await assertFails(getDoc(doc(comoAdmin(), 'rankingPublicIds', ID_PUBLICO_DONO)));
  });

  test('o agregado por uid nao e legivel nem pelo dono', async () => {
    await assertFails(getDoc(doc(comoDono(), 'rankingPlayers', DONO)));
  });

  test('ninguem escreve no agregado', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingPlayers', DONO), { pontosTotais: 10 ** 9 }),
    );
  });
});

describe('ranking: temporada e escada de ligas', () => {
  test('quem esta autenticado LE a temporada vigente', async () => {
    // A tela precisa saber qual temporada esta correndo. O documento nao tem uid,
    // apelido nem pontuacao de ninguem.
    const lido = await assertSucceeds(getDoc(doc(comoDono(), 'rankingSeasons', TEMPORADA)));
    assert.equal(lido.data().status, 'vigente');
  });

  test('a temporada de producao carrega a politica PENDENTE', async () => {
    // Prova de estado, e nao de regra: confirma que o sistema semeado e o real —
    // uma temporada vigente cuja formula de pontuacao ainda nao foi decidida.
    const lido = await assertSucceeds(getDoc(doc(comoDono(), 'rankingSeasons', TEMPORADA)));
    assert.deepEqual(lido.data().politica, { id: 'nao_definida', versao: 0 });
  });

  test('quem esta autenticado LE a escada de ligas', async () => {
    const lido = await assertSucceeds(getDoc(doc(comoDono(), 'rankingLadders', LADDER)));
    assert.equal(lido.data().degraus.length, 2);
  });

  test('o cliente nao cria temporada', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'rankingSeasons', '2027-inventada'), {
        seasonId: '2027-inventada',
        status: 'vigente',
      }),
    );
  });

  test('o cliente nao encerra a temporada corrente', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingSeasons', TEMPORADA), { status: 'encerrada' }),
    );
  });

  test('o cliente nao troca a politica de pontuacao da temporada', async () => {
    // Seria escolher por que regra ele proprio pontua.
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingSeasons', TEMPORADA), {
        politica: { id: 'a-que-me-favorece', versao: 1 },
      }),
    );
  });

  test('nem o admin muda a temporada pelo cliente', async () => {
    // Trocar a politica de uma temporada em andamento pelo console mudaria o
    // significado dos lancamentos ja gravados. A transicao passa por Function,
    // que confere "no maximo uma vigente" e grava a auditoria na mesma transacao.
    await assertFails(
      updateDoc(doc(comoAdmin(), 'rankingSeasons', TEMPORADA), { status: 'encerrada' }),
    );
  });

  test('o cliente nao inventa uma escada de ligas', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'rankingLadders', 'a-minha'), {
        ladderId: 'a-minha',
        degraus: [{ ligaId: 'imperial', nome: 'IMPERIAL', pontosMinimos: 0, pontosMaximos: null }],
      }),
    );
  });

  test('o cliente nao rebaixa a faixa de uma liga existente', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingLadders', LADDER), {
        degraus: [{ ligaId: 'alta', nome: 'ALTA', pontosMinimos: 0, pontosMaximos: null }],
      }),
    );
  });
});

describe('ranking: idempotencia e trilha', () => {
  test('o cliente nao marca uma partida como processada', async () => {
    // Criar este documento a mao faria o sistema considerar a partida "ja
    // processada" sem que ela tivesse pontuado.
    await assertFails(
      setDoc(doc(comoDono(), 'rankingContributions', `match-9|${TEMPORADA}|nao_definida|v0`), {
        matchId: 'match-9',
        seasonId: TEMPORADA,
      }),
    );
  });

  test('o cliente nao DESMARCA uma partida processada', async () => {
    // O outro lado do mesmo defeito: apagar a chave faria a partida pontuar duas
    // vezes no proximo reprocessamento.
    await assertFails(deleteDoc(doc(comoDono(), 'rankingContributions', CHAVE_CONTRIBUICAO)));
  });

  test('nem o admin apaga a chave de idempotencia pelo cliente', async () => {
    await assertFails(deleteDoc(doc(comoAdmin(), 'rankingContributions', CHAVE_CONTRIBUICAO)));
  });

  test('o cliente nao le os deltas de terceiros', async () => {
    await assertFails(getDoc(doc(comoDono(), 'rankingContributions', CHAVE_CONTRIBUICAO)));
  });

  test('o admin LE a contribuicao', async () => {
    const lido = await assertSucceeds(
      getDoc(doc(comoAdmin(), 'rankingContributions', CHAVE_CONTRIBUICAO)),
    );
    assert.equal(lido.data().matchId, 'match-1');
  });

  test('o admin LE o backlog, e o jogador nao', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), 'rankingBacklog', 'match-2')));
    await assertFails(getDoc(doc(comoDono(), 'rankingBacklog', 'match-2')));
  });

  test('o cliente nao tira a propria partida do backlog', async () => {
    await assertFails(deleteDoc(doc(comoDono(), 'rankingBacklog', 'match-2')));
  });

  test('a trilha de auditoria nao se limpa pelo cliente', async () => {
    // Mesmo desenho de `audit/`, `tournamentAudit/` e `moderationAudit/`: nem o
    // admin apaga, para que a trilha nao possa ser limpa por quem a gerou.
    await assertFails(deleteDoc(doc(comoAdmin(), 'rankingAudit', 'evento-1')));
    await assertFails(deleteDoc(doc(comoDono(), 'rankingAudit', 'evento-1')));
    await assertSucceeds(getDoc(doc(comoAdmin(), 'rankingAudit', 'evento-1')));
  });

  test('o cliente nao reserva uma tarefa de apuracao', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'rankingTasks', `${TEMPORADA}|apuracao|2030-01-01T00:00Z`), {
        tarefa: 'apuracao',
      }),
    );
  });
});

describe('ranking: o Hall dos Imortais', () => {
  test('o cliente NAO se coloca no Hall', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'hallEntries', `${TEMPORADA}|lendaMes`), {
        categoria: 'lendaMes',
        honrado: { id: ID_PUBLICO_DONO, nome: 'Eu Mesmo' },
      }),
    );
  });

  test('o cliente nao coloca terceiro no Hall', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'hallEntries', `${TEMPORADA}|campeaoHoje`), {
        honrado: { id: ID_PUBLICO_ALHEIO },
      }),
    );
  });

  test('nem o admin escreve no Hall pelo cliente', async () => {
    await assertFails(
      setDoc(doc(comoAdmin(), 'hallEntries', `${TEMPORADA}|campeaoHoje`), { honrado: null }),
    );
  });

  test('o Hall nao e legivel direto — sai projetado pela Function', async () => {
    await assertFails(getDoc(doc(comoDono(), 'hallEntries', `${TEMPORADA}|campeaoHoje`)));
  });

  test('o Hall esta VAZIO, e isso e o esperado', async () => {
    // Nenhuma das cinco categorias tem criterio de elegibilidade definido. A
    // colecao existir vazia e a resposta honesta; preenche-la seria fabricar
    // vencedor (secao 14).
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const todos = await getDocs(collection(ctx.firestore(), 'hallEntries'));
      assert.equal(todos.size, 0, 'o Hall foi preenchido por alguem');
    });
  });
});

describe('ranking: sem login nao se le nada', () => {
  test('nem a temporada, nem a escada', async () => {
    await assertFails(getDoc(doc(semLogin(), 'rankingSeasons', TEMPORADA)));
    await assertFails(getDoc(doc(semLogin(), 'rankingLadders', LADDER)));
  });

  test('nem a classificacao', async () => {
    await assertFails(getDoc(doc(semLogin(), 'rankingStandings', CHAVE_STANDING)));
    await assertFails(getDocs(collection(semLogin(), 'rankingStandings')));
  });

  test('e nao se escreve nada', async () => {
    await assertFails(
      setDoc(doc(semLogin(), 'rankingStandings', `${TEMPORADA}|anonimo`), { pontos: 10 }),
    );
  });
});

describe('ranking: o ledger competitivo continua como a rastreabilidade o deixou', () => {
  // O bloco de ranking ESCREVE em `rankingLedger` mas nao redefine a regra dela.
  // Estes dois casos existem para provar que o Bloco 6/6 nao afrouxou o 4/6 —
  // que e exatamente o risco de acrescentar um bloco a um arquivo de regras
  // compartilhado, e o motivo pelo qual a suite roda tudo no MESMO firestore.rules.
  before(async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'rankingLedger', `match-1|${DONO}|resultado_de_partida`), {
        chaveIdempotencia: `match-1|${DONO}|resultado_de_partida`,
        matchId: 'match-1',
        userId: DONO,
        seasonId: TEMPORADA,
        rankingBefore: 110,
        rankingDelta: 10,
        rankingAfter: 120,
      });
    });
  });

  test('o jogador le o PROPRIO lancamento', async () => {
    const lido = await assertSucceeds(
      getDoc(doc(comoDono(), 'rankingLedger', `match-1|${DONO}|resultado_de_partida`)),
    );
    assert.equal(lido.data().rankingAfter, 120);
  });

  test('o jogador NAO escreve lancamento — nem para si', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingLedger', `match-1|${DONO}|resultado_de_partida`), {
        rankingAfter: 99999,
      }),
    );
  });

  test('o jogador nao le o lancamento alheio', async () => {
    await assertFails(
      getDoc(doc(comoAlheio(), 'rankingLedger', `match-1|${DONO}|resultado_de_partida`)),
    );
  });
});
