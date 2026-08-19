// passe.test.js — prova o BLOCO 8/8 do firestore.rules contra o emulador:
// o PASSE VIP QUINZENAL DE CORTESIA.
//
// A DIVISAO DE TRABALHO E A MESMA DE ranking.test.js:
//
//   modulos puros -> o que a REGRA decide (as duas fronteiras, o acumulo, o
//                    recibo). Vive em functions-ranking/test/passe.test.js.
//   integracao    -> o que so a TRANSACAO prova (concorrencia, persistencia).
//                    Vive em functions-ranking/test/integracao.passe.emulador.test.js.
//   rules (aqui)  -> o que o BANCO permite ao CLIENTE. E a resposta e: nada.
//
// POR QUE ESTE BLOCO E MAIS FECHADO QUE TODOS OS OUTROS DO ARQUIVO. Em
// `playerModeration` o dono LE o proprio documento; aqui nem isso. O documento
// interno carrega o `tentativaEntradaId` e o `admissaoId` de cada ciclo, que
// sao a chave de idempotencia do consumo — quem os enxerga sabe quando uma
// entrada foi aprovada e com qual identidade, e nao ha nada que o jogador
// precise fazer com isso. O que e dele, ele recebe pela PROJECAO.
//
// O QUE UM CLIENTE FARIA SE PUDESSE ESCREVER, e que estes casos impedem:
//   * autoconceder um passe que nunca recebeu;
//   * esticar `validoAte` de um que expirou;
//   * zerar `consumidoEm` para usar o mesmo passe de novo;
//   * apagar `cicloEncerradoEm` para ressuscitar um ciclo fechado;
//   * antecipar `proximaElegibilidadeEm` para ganhar dois por quinzena;
//   * apagar o historico, que e o que impede consumir duas vezes.
//
// Uso:
//   cd firebase/testes && npm install
//   firebase emulators:exec --only firestore "npm run test:passe"

'use strict';

const fs = require('fs');
const path = require('path');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
} = require('@firebase/rules-unit-testing');

const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
} = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const DONO = 'uid_dono_passe';
const ALHEIO = 'uid_alheio_passe';
const ADMIN = 'uid_admin_passe';

const CICLO = 'ciclo-opaco-de-teste';
const T0 = '2026-08-17T12:00:00.000Z';
const VALIDO_ATE = '2026-08-24T12:00:00.000Z';
const PROXIMA = '2026-09-01T12:00:00.000Z';

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
  // equivalente do Admin SDK — e e assim que `functions-ranking/` popula isto,
  // o que e justamente o ponto: a autoridade escreve por fora das Rules, e o
  // cliente nao tem esse caminho.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'playerCourtesyPass', DONO), {
      versaoContrato: 1,
      cicloAtualId: CICLO,
      recebidoEm: T0,
      validoAte: VALIDO_ATE,
      proximaElegibilidadeEm: PROXIMA,
      consumidoEm: null,
      cicloEncerradoEm: null,
      ultimaMaterializacaoEm: T0,
    });
    await setDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', CICLO), {
      cicloId: CICLO,
      recebidoEm: T0,
      validoAte: VALIDO_ATE,
      proximaElegibilidadeEm: PROXIMA,
      consumidoEm: null,
      encerradoEm: null,
      tentativaEntradaId: null,
      admissaoId: null,
      versaoContrato: 1,
    });
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

/// Os tres papeis que existem no arquivo: o dono, um terceiro autenticado e o
/// admin. Nenhum deles passa — e o admin entra na lista de proposito, porque
/// "so o admin" seria uma porta, e porta se atravessa.
function contextos() {
  return [
    ['o DONO', ambiente.authenticatedContext(DONO)],
    ['um TERCEIRO autenticado', ambiente.authenticatedContext(ALHEIO)],
    ['o ADMIN', ambiente.authenticatedContext(ADMIN, { admin: true })],
    ['quem NAO esta autenticado', ambiente.unauthenticatedContext()],
  ];
}

// ===========================================================================
describe('PASSE-RULES/LEITURA — ninguem le o documento interno', () => {
  test('PRL-01: o controle nao e legivel por ninguem, nem pelo proprio dono', async () => {
    // §9 e §11.16. `playerModeration` deixa o dono ler; este bloco nao — e a
    // diferenca e o conteudo: aqui moram os recibos de admissao.
    for (const [quem, ctx] of contextos()) {
      const db = ctx.firestore();
      await assertFails(getDoc(doc(db, 'playerCourtesyPass', DONO)), quem);
    }
  });

  test('PRL-02: o historico por ciclo tambem nao e legivel', async () => {
    // Regra de Firestore NAO desce por heranca: o `match` do controle nao cobre
    // a subcolecao sozinho. Por isso o bloco tem `match` proprio, e por isso
    // este caso existe separado — sem ele, um `cycles` esquecido ficaria aberto
    // e ninguem saberia.
    for (const [quem, ctx] of contextos()) {
      const db = ctx.firestore();
      await assertFails(getDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', CICLO)), quem);
      await assertFails(getDocs(collection(db, 'playerCourtesyPass', DONO, 'cycles')), quem + ' (listagem)');
    }
  });

  test('PRL-03: nem varrendo a colecao inteira', async () => {
    for (const [quem, ctx] of contextos()) {
      await assertFails(getDocs(collection(ctx.firestore(), 'playerCourtesyPass')), quem);
    }
  });
});

// ===========================================================================
describe('PASSE-RULES/ESCRITA — ninguem se autoconcede nada', () => {
  test('PRE-01: o cliente nao CRIA um passe para si', async () => {
    // §11.17 e §9: "nenhuma capacidade de autocriar". O jogador sem passe
    // tentando fabricar um, com o documento perfeitamente bem formado.
    const db = ambiente.authenticatedContext(ALHEIO).firestore();
    await assertFails(setDoc(doc(db, 'playerCourtesyPass', ALHEIO), {
      versaoContrato: 1,
      cicloAtualId: 'forjado',
      recebidoEm: T0,
      validoAte: VALIDO_ATE,
      proximaElegibilidadeEm: PROXIMA,
      consumidoEm: null,
      cicloEncerradoEm: null,
      ultimaMaterializacaoEm: T0,
    }));
  });

  test('PRE-02: o cliente nao PROLONGA a validade do proprio passe', async () => {
    const db = ambiente.authenticatedContext(DONO).firestore();
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO), {
      validoAte: '2027-01-01T00:00:00.000Z',
    }));
  });

  test('PRE-03: o cliente nao REATIVA um passe consumido', async () => {
    // Zerar `consumidoEm` seria usar o mesmo passe duas vezes.
    const db = ambiente.authenticatedContext(DONO).firestore();
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO), { consumidoEm: null }));
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', CICLO), { consumidoEm: null }));
  });

  test('PRE-04: o cliente nao apaga o ENCERRAMENTO de um ciclo', async () => {
    // `cicloEncerradoEm` e a protecao contra regressao de relogio. Se o cliente
    // pudesse limpa-la, ele reabriria um ciclo fechado — que e o mesmo que
    // ganhar um passe.
    const db = ambiente.authenticatedContext(DONO).firestore();
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO), { cicloEncerradoEm: null }));
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', CICLO), { encerradoEm: null }));
  });

  test('PRE-05: o cliente nao ANTECIPA a proxima elegibilidade', async () => {
    // Seria ganhar dois passes por quinzena — o acumulo que o modelo inteiro
    // existe para impedir.
    const db = ambiente.authenticatedContext(DONO).firestore();
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO), {
      proximaElegibilidadeEm: T0,
    }));
  });

  test('PRE-06: o cliente nao forja um RECIBO de admissao', async () => {
    // §9: "nenhuma exposicao de historico de admissao" — e, com mais razao,
    // nenhuma escrita nele. Um `admissaoId` forjado seria a prova de uma
    // aprovacao que nunca houve.
    const db = ambiente.authenticatedContext(DONO).firestore();
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', CICLO), {
      consumidoEm: T0,
      tentativaEntradaId: 'te_forjada',
      admissaoId: 'adm-forjada',
    }));
    await assertFails(setDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', 'ciclo-inventado'), {
      cicloId: 'ciclo-inventado',
      recebidoEm: T0,
      validoAte: VALIDO_ATE,
      proximaElegibilidadeEm: PROXIMA,
      consumidoEm: null,
      encerradoEm: null,
      tentativaEntradaId: null,
      admissaoId: null,
      versaoContrato: 1,
    }));
  });

  test('PRE-07: o cliente nao APAGA o passe nem o historico', async () => {
    // Apagar o historico seria apagar a idempotencia: sem o ciclo consumido,
    // nada impediria consumir de novo.
    for (const [quem, ctx] of contextos()) {
      const db = ctx.firestore();
      await assertFails(deleteDoc(doc(db, 'playerCourtesyPass', DONO)), quem);
      await assertFails(deleteDoc(doc(db, 'playerCourtesyPass', DONO, 'cycles', CICLO)), quem);
    }
  });

  test('PRE-08: nem o passe DE OUTRO jogador', async () => {
    const db = ambiente.authenticatedContext(ALHEIO).firestore();
    await assertFails(getDoc(doc(db, 'playerCourtesyPass', DONO)));
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO), { validoAte: PROXIMA }));
    await assertFails(deleteDoc(doc(db, 'playerCourtesyPass', DONO)));
  });

  test('PRE-09: nem o admin escreve por aqui', async () => {
    // Mesmo desenho de `audit/` e `moderationAudit/`: a trilha nao pode ser
    // limpa por quem a gerou. A autoridade escreve pelo Admin SDK, que nao
    // passa por Rules — e e essa a unica porta.
    const db = ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
    await assertFails(setDoc(doc(db, 'playerCourtesyPass', ALHEIO), { versaoContrato: 1, cicloAtualId: null }));
    await assertFails(updateDoc(doc(db, 'playerCourtesyPass', DONO), { consumidoEm: null }));
    await assertFails(deleteDoc(doc(db, 'playerCourtesyPass', DONO)));
  });
});

// ===========================================================================
describe('PASSE-RULES/FRONTEIRA — a assinatura paga nao se confunde com a cortesia', () => {
  test('PRF-01: `playerEntitlements` continua fora deste bloco', async () => {
    // §10 e §12.7. A cortesia nao mora na autoridade da assinatura, e o bloco
    // do passe nao abriu nenhuma porta para ela — o fecho padrao do arquivo
    // continua negando, como negava antes desta OS.
    for (const [quem, ctx] of contextos()) {
      const db = ctx.firestore();
      await assertFails(getDoc(doc(db, 'playerEntitlements', DONO)), quem);
      await assertFails(setDoc(doc(db, 'playerEntitlements', DONO), { vip: true }), quem);
    }
  });

  test('PRF-02: um caminho vizinho inventado continua negado pelo fecho padrao', async () => {
    // O bloco novo nao pode ter aberto nada por tabela. `courtesyPass` (sem o
    // prefixo) e `playerCourtesyPasses` (no plural) sao os erros de digitacao
    // mais provaveis de quem for mexer aqui depois.
    const db = ambiente.authenticatedContext(DONO).firestore();
    for (const colecao of ['courtesyPass', 'playerCourtesyPasses', 'vipPasses']) {
      await assertFails(getDoc(doc(db, colecao, DONO)), colecao);
      await assertFails(setDoc(doc(db, colecao, DONO), { x: 1 }), colecao);
    }
  });
});
