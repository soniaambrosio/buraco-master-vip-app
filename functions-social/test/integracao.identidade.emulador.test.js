/**
 * integracao.identidade.emulador.test.js — O CICLO INTEIRO, COM AS DUAS
 * IMPLEMENTACOES DE VERDADE.
 *
 * OS de integracao Identidade Publica x Ranking v1, secoes 7, 9, 22 e 23.
 *
 * POR QUE ESTA SUITE EXISTE, JA HAVENDO DUAS OUTRAS. As suites que ja existem
 * provam cada lado sozinho:
 *
 *   functions-social/test/chaves.test.js .............. o modulo puro social;
 *   functions-ranking/test/integracao.emulador.test.js  o ranking contra o banco,
 *                                                       com identidade de FIXTURE.
 *
 * Fixture e uma afirmacao sobre o que o vizinho produz. Esta suite substitui a
 * afirmacao pela coisa: ela chama `garantirIdentidade` DE VERDADE, e entrega o
 * resultado a `processarResultadoOficial` DE VERDADE. Se o formato que um grava
 * deixar de ser o que o outro le, e aqui que se descobre.
 *
 * E TAMBEM O UNICO LUGAR ONDE A CONCORRENCIA E TESTAVEL. §7 exige o cenario
 * "duas operacoes chegam simultaneamente para um usuario ainda sem identidade
 * publica", e chamada sequencial nao o cobre: o caminho comum (`ja existe`) e
 * uma leitura fora da transacao, e so duas chamadas realmente simultaneas fazem
 * as duas transacoes disputarem o mesmo documento.
 *
 * MORA NO CODEBASE SOCIAL porque a autoridade e dele. Ele importa o `lib/` do
 * ranking como TESTE — o oposto (o ranking importar o social) espelharia no
 * teste uma dependencia que a producao nao tem e nao deve ter.
 *
 * EXIGE: emulador do Firestore, `npm run build:domain` e `tsc` nos DOIS
 * codebases. Fora do `npm test` por isso. Alvo: `npm run test:integracao`.
 */

'use strict';

const assert = require('node:assert/strict');
const { test, describe, before, beforeEach, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const admin = require('firebase-admin');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    'esta suite exige o emulador do Firestore. Use `npm run test:integracao`.'
  );
}

const RANKING_LIB = path.join(__dirname, '..', '..', 'functions-ranking', 'lib');
if (!fs.existsSync(path.join(RANKING_LIB, 'firestore.js'))) {
  throw new Error(
    'functions-ranking/lib nao existe. Rode `npm run build` em functions-ranking ' +
      'antes: esta suite prova a integracao das DUAS implementacoes, e pular o ' +
      'lado competitivo a transformaria numa suite social a mais.'
  );
}

const PROJETO = process.env.GCLOUD_PROJECT || 'demo-bmv';

// DOIS `initializeApp`, E NAO UM. Cada codebase tem o SEU `node_modules`, entao
// cada um carrega uma copia distinta de `firebase-admin`, com um registro de
// apps proprio. Inicializar so o daqui deixaria o `getFirestore()` do ranking
// estourando "The default Firebase app does not exist".
//
// E isso nao e um contorno do teste: e a topologia REAL. Sao unidades de
// implantacao separadas, cada uma com o proprio processo e o proprio Admin SDK —
// e provar a integracao com dois clientes independentes contra o mesmo banco e
// mais fiel do que provar com um so.
admin.initializeApp({ projectId: PROJETO });

const adminDoRanking = require(
  path.join(__dirname, '..', '..', 'functions-ranking', 'node_modules', 'firebase-admin')
);
adminDoRanking.initializeApp({ projectId: PROJETO });

// A AUTORIDADE DE IDENTIDADE — a real, com o dominio Dart compilado.
const { garantirIdentidade, publicIdDe, resolverUid } = require('../lib/repositorio');
const {
  C_IDENTIDADES,
  C_INDICE_PUBLICO,
  C_PERFIS_PUBLICOS,
} = require('../lib/chaves');

// O CONSUMIDOR — o ranking, tambem o real.
const {
  processarResultadoOficial,
  reprocessarBacklog,
  abrirTemporada,
  identidadeCanonicaDe,
  porIdPublico,
  db,
} = require(path.join(RANKING_LIB, 'firestore.js'));
const {
  registrarPoliticaV1,
  POLITICA_COMPETITIVA_V1,
  LADDER_V1_ID,
} = require(path.join(RANKING_LIB, 'competicao.js'));

registrarPoliticaV1();

const TEMPORADA = '2026-IDENT';
const OS_QUATRO = ['u1', 'u2', 'u3', 'u4'];

const COLECOES = [
  C_IDENTIDADES,
  C_INDICE_PUBLICO,
  C_PERFIS_PUBLICOS,
  'playerSocial',
  'friendships',
  'rankingStandings',
  'rankingPlayers',
  'rankingLedger',
  'rankingContributions',
  'rankingBacklog',
  'rankingSeasons',
  'rankingTasks',
  'rankingAudit',
  'matches',
  // Nao existe mais, e por isso mesmo e limpa e conferida: um resto dela num
  // banco de teste esconderia uma regressao.
  'rankingPublicIds',
];

async function limpar() {
  for (const c of COLECOES) {
    const snap = await db().collection(c).get();
    if (snap.empty) continue;
    const lote = db().batch();
    snap.docs.forEach((d) => lote.delete(d.ref));
    await lote.commit();
  }
}

const abrirTemporadaV1 = () =>
  abrirTemporada({
    seasonId: TEMPORADA,
    nome: 'Integracao de identidade',
    inicioEm: '2026-08-01T00:00:00.000Z',
    fimEm: '2026-09-26T00:00:00.000Z',
    politica: POLITICA_COMPETITIVA_V1,
    ladderId: LADDER_V1_ID,
    autor: 'teste',
  });

const partidaRanqueada = (matchId, vencedor, over = {}) => ({
  matchId,
  estado: 'finalizada',
  tipo: 'publica_ranqueada',
  alteraRanking: true,
  motivoEncerramento: 'objetivo_atingido',
  ladoVencedor: vencedor,
  encerradaEm: '2026-08-11T20:00:00.000Z',
  participantes: [
    { classe: 'humano', userId: 'u1', assento: 0, lado: 'A' },
    { classe: 'humano', userId: 'u2', assento: 1, lado: 'B' },
    { classe: 'humano', userId: 'u3', assento: 2, lado: 'A' },
    { classe: 'humano', userId: 'u4', assento: 3, lado: 'B' },
  ],
  placar: [
    { lado: 'A', pontos: 3000, canastrasLimpas: 2 },
    { lado: 'B', pontos: 1500, canastrasLimpas: 0 },
  ],
  ...over,
});

const gravarPartida = (doc) => db().collection('matches').doc(doc.matchId).set(doc);
const standingDe = async (uid) =>
  (await db().collection('rankingStandings').doc(`${TEMPORADA}|${uid}`).get()).data();

before(limpar);
after(limpar);

// ---------------------------------------------------------------------------
// §22.1 a §22.6 — A AUTORIDADE DE EMISSAO
// ---------------------------------------------------------------------------

describe('identidade: emissao (§22.1 a §22.6)', () => {
  beforeEach(limpar);

  test('§22.1 — a criacao inicial grava os TRES documentos canonicos', async () => {
    const { publicId, criada } = await garantirIdentidade('u1', 'Sonia');
    assert.equal(criada, true);
    assert.match(publicId, /^P[0-9A-HJKMNP-TV-Z]{12}$/);

    const identidade = (await db().collection(C_IDENTIDADES).doc('u1').get()).data();
    assert.equal(identidade.publicId, publicId);
    assert.equal(identidade.uid, 'u1');

    const reverso = (await db().collection(C_INDICE_PUBLICO).doc(publicId).get()).data();
    assert.equal(reverso.uid, 'u1');

    const perfil = (await db().collection(C_PERFIS_PUBLICOS).doc(publicId).get()).data();
    assert.equal(perfil.publicId, publicId);
    // §31-F: o documento publico nao carrega uid. E a trava do servidor que o
    // garante, e aqui se confere o resultado dela no BANCO.
    assert.equal(perfil.uid, undefined);
  });

  test('§22.2 — o retry devolve o MESMO id, e nao cria um segundo', async () => {
    const primeira = await garantirIdentidade('u1', 'Sonia');
    const segunda = await garantirIdentidade('u1', 'Sonia');
    const terceira = await garantirIdentidade('u1', 'outro apelido');

    assert.equal(segunda.publicId, primeira.publicId);
    assert.equal(terceira.publicId, primeira.publicId);
    assert.equal(segunda.criada, false, 'a segunda chamada cunhou de novo');
    assert.equal(terceira.criada, false);
    assert.equal((await db().collection(C_INDICE_PUBLICO).get()).size, 1);
    assert.equal((await db().collection(C_PERFIS_PUBLICOS).get()).size, 1);
  });

  test('§22.3 — SEIS criacoes concorrentes convergem para UM id', async () => {
    // O cenario que §7 nomeia. Seis, e nao duas: com duas, uma corrida perdida
    // ainda pode passar por sorte de agendamento.
    const resultados = await Promise.all(
      Array.from({ length: 6 }, () => garantirIdentidade('u1', 'Sonia'))
    );

    const ids = new Set(resultados.map((r) => r.publicId));
    assert.equal(ids.size, 1, `convergiram para ${ids.size} ids: ${[...ids].join(', ')}`);
    assert.equal(
      resultados.filter((r) => r.criada).length,
      1,
      'mais de uma chamada afirmou ter CRIADO a identidade'
    );

    // E o banco tambem so tem um de cada. Nenhuma identidade orfa.
    assert.equal((await db().collection(C_IDENTIDADES).get()).size, 1);
    assert.equal((await db().collection(C_INDICE_PUBLICO).get()).size, 1);
    assert.equal((await db().collection(C_PERFIS_PUBLICOS).get()).size, 1);
  });

  test('§22.4 — mesmo uid, mesmo publicId, mesmo depois de mexer no perfil', async () => {
    const { publicId } = await garantirIdentidade('u1', 'Sonia');
    await db().collection(C_PERFIS_PUBLICOS).doc(publicId).update({
      apelido: 'Outro Nome',
      avatarRef: 'assets/avatares/9.webp',
    });
    assert.equal(await publicIdDe('u1'), publicId);
    assert.equal((await garantirIdentidade('u1', 'Sonia')).publicId, publicId);
  });

  test('§22.5 — uids diferentes recebem ids diferentes', async () => {
    const ids = new Set();
    for (const uid of OS_QUATRO) {
      ids.add((await garantirIdentidade(uid, `apelido-${uid}`)).publicId);
    }
    assert.equal(ids.size, OS_QUATRO.length);

    // E o caminho de volta aponta para o dono certo, um a um.
    for (const uid of OS_QUATRO) {
      assert.equal(await resolverUid(await publicIdDe(uid)), uid);
    }
  });

  test('§22.6 — ninguem reivindica o publicId de terceiro pelo backend', async () => {
    // A emissao NAO ACEITA um id desejado: a assinatura de `garantirIdentidade`
    // e `(uid, apelidoSugerido)`. Nao ha parametro por onde pedir um id, e essa
    // ausencia e a defesa — uma validacao poderia ser esquecida, um parametro
    // que nao existe nao pode ser passado.
    const dela = await garantirIdentidade('u1', 'Sonia');
    const dele = await garantirIdentidade('u2', 'Sonia');
    assert.notEqual(dele.publicId, dela.publicId);
    assert.equal(garantirIdentidade.length, 2, 'a funcao ganhou um terceiro parametro');

    // E o mapa reverso continua apontando cada id para o seu dono.
    assert.equal(await resolverUid(dela.publicId), 'u1');
    assert.equal(await resolverUid(dele.publicId), 'u2');
    // O bloqueio pelo lado do CLIENTE e provado nas Rules
    // (firebase/testes/social.test.js e ranking.test.js).
  });
});

// ---------------------------------------------------------------------------
// §23 — O CICLO COMPLETO
// ---------------------------------------------------------------------------

describe('ciclo completo: identidade -> partida -> ledger -> standings (§23)', () => {
  beforeEach(async () => {
    await limpar();
    await abrirTemporadaV1();
  });

  /// Roda o ciclo inteiro e devolve o que ele produziu. Chamado DUAS vezes no
  /// teste de estabilidade, que e o que §23 pede ao dizer "executar o cenario
  /// mais de uma vez".
  async function ciclo(matchId) {
    const emitidos = new Map();
    for (const uid of OS_QUATRO) {
      emitidos.set(uid, (await garantirIdentidade(uid, `apelido-${uid}`)).publicId);
    }
    await gravarPartida(partidaRanqueada(matchId, 'A'));
    const r = await processarResultadoOficial({ matchId, origem: 'gatilho', autor: null });
    return { emitidos, resultado: r };
  }

  test('as oito etapas, na ordem, com um unico id por jogador', async () => {
    const { emitidos, resultado } = await ciclo('m1');

    // 4. a partida competitiva foi processada.
    assert.equal(resultado.processada, true, resultado.detalhe ?? '');

    for (const uid of OS_QUATRO) {
      const publicId = emitidos.get(uid);

      // 2 e 3. identidade canonica e perfil publico existem.
      assert.equal(await identidadeCanonicaDe(uid), publicId);
      assert.equal(
        (await db().collection(C_PERFIS_PUBLICOS).doc(publicId).get()).exists,
        true
      );

      // 5. o ledger competitivo foi lancado.
      const lancamento = (
        await db().collection('rankingLedger').doc(`m1|${uid}|resultado_de_partida`).get()
      ).data();
      assert.ok(lancamento, `sem lancamento de ledger para ${uid}`);
      assert.equal(lancamento.rankingBefore + lancamento.rankingDelta, lancamento.rankingAfter);

      // 6 e 7. o standing existe e a projecao usa O MESMO id.
      const s = await standingDe(uid);
      assert.equal(s.publicPlayerId, publicId, `${uid} recebeu um id diferente do emitido`);

      // 8. apelido e avatar vieram do perfil publico.
      assert.equal(s.apelido, `apelido-${uid}`);
    }

    // 9. NENHUM SEGUNDO ID FOI CRIADO. E a afirmacao central da OS, e ela cabe
    // em duas contagens: quatro jogadores, quatro entradas em cada mapa.
    assert.equal((await db().collection(C_IDENTIDADES).get()).size, 4);
    assert.equal((await db().collection(C_INDICE_PUBLICO).get()).size, 4);
    assert.equal((await db().collection(C_PERFIS_PUBLICOS).get()).size, 4);
    assert.equal(
      (await db().collection('rankingPublicIds').get()).size,
      0,
      'a colecao de ids do ranking ressuscitou'
    );
  });

  test('rodar o ciclo DUAS vezes nao emite id novo nem duplica contribuicao', async () => {
    const primeiro = await ciclo('m1');
    const segundo = await ciclo('m2');

    for (const uid of OS_QUATRO) {
      assert.equal(
        segundo.emitidos.get(uid),
        primeiro.emitidos.get(uid),
        `${uid} trocou de id na segunda execucao`
      );
    }
    assert.equal((await db().collection(C_IDENTIDADES).get()).size, 4);
    // Duas partidas, duas contribuicoes — e nao quatro.
    assert.equal((await db().collection('rankingContributions').get()).size, 2);
    assert.equal((await standingDe('u1')).partidasComputadas, 2);
  });

  test('a navegacao "id publico -> jogador" atravessa o indice CANONICO', async () => {
    // Antes da OS, `porIdPublico` lia `rankingPublicIds`. Um id emitido pelo
    // dominio social nao resolvia ali — e este teste falharia.
    const { emitidos } = await ciclo('m1');
    const achado = await porIdPublico(emitidos.get('u1'), TEMPORADA);
    assert.ok(achado, 'o id canonico nao resolveu no ranking');
    assert.equal(achado.uid, 'u1');
    assert.equal(achado.standing.publicPlayerId, emitidos.get('u1'));
  });

  test('CASO B do §9 — a necessidade competitiva vem ANTES do provisionamento', async () => {
    // Nenhuma identidade existe ainda. A partida encerra.
    await gravarPartida(partidaRanqueada('m1', 'A'));
    const antes = await processarResultadoOficial({
      matchId: 'm1',
      origem: 'gatilho',
      autor: null,
    });
    assert.equal(antes.recusa, 'identidade_publica_ausente');

    // NENHUMA SEGUNDA AUTORIDADE FOI ACIONADA: o ranking nao criou identidade.
    assert.equal((await db().collection(C_IDENTIDADES).get()).size, 0);
    assert.equal((await db().collection(C_INDICE_PUBLICO).get()).size, 0);

    // Agora o mecanismo OFICIAL provisiona.
    const emitidos = new Map();
    for (const uid of OS_QUATRO) {
      emitidos.set(uid, (await garantirIdentidade(uid, `apelido-${uid}`)).publicId);
    }

    // E a operacao converge: o backlog retoma e usa exatamente aqueles ids.
    const r = await reprocessarBacklog({ limite: 10, autor: 'admin' });
    assert.equal(r.processados, 1, JSON.stringify(r));
    for (const uid of OS_QUATRO) {
      assert.equal((await standingDe(uid)).publicPlayerId, emitidos.get(uid));
    }
    assert.equal((await db().collection(C_IDENTIDADES).get()).size, 4);
  });

  test('CASO E do §9 — provisionamento concorrente com o competitivo', async () => {
    // As duas coisas ao mesmo tempo: seis provisionamentos simultaneos por
    // jogador e o processamento da partida disparado junto. Qualquer que seja a
    // ordem, o resultado tem que ser UMA identidade por jogador.
    await gravarPartida(partidaRanqueada('m1', 'A'));

    const provisionamentos = OS_QUATRO.flatMap((uid) =>
      Array.from({ length: 6 }, () => garantirIdentidade(uid, `apelido-${uid}`))
    );
    const [processamento] = await Promise.all([
      processarResultadoOficial({ matchId: 'm1', origem: 'gatilho', autor: null }),
      ...provisionamentos,
    ]);

    // O processamento pode ter chegado antes (backlog) ou depois (pontuou). Os
    // dois desfechos sao corretos; o que NAO pode variar e a identidade.
    assert.equal((await db().collection(C_IDENTIDADES).get()).size, 4);
    assert.equal((await db().collection(C_INDICE_PUBLICO).get()).size, 4);
    assert.equal((await db().collection(C_PERFIS_PUBLICOS).get()).size, 4);

    if (!processamento.processada) {
      assert.equal(processamento.recusa, 'identidade_publica_ausente');
      const r = await reprocessarBacklog({ limite: 10, autor: 'admin' });
      assert.equal(r.processados, 1);
    }
    for (const uid of OS_QUATRO) {
      assert.equal((await standingDe(uid)).publicPlayerId, await publicIdDe(uid));
    }
    assert.equal((await db().collection('rankingContributions').get()).size, 1);
  });
});

// ---------------------------------------------------------------------------
// §12, §13 e §14 — o que a integracao NAO pode ter mudado
// ---------------------------------------------------------------------------

describe('a integracao nao mexeu no que nao e dela (§12, §13, §14)', () => {
  beforeEach(async () => {
    await limpar();
    await abrirTemporadaV1();
    for (const uid of OS_QUATRO) {
      await garantirIdentidade(uid, `apelido-${uid}`);
    }
  });

  test('§12 — Mesa Publica casual continua sem Elo, mesmo com identidade', async () => {
    // A regressao imaginavel: "agora que todo mundo tem identidade publica, a
    // casual passou a criar linha". Nao passou.
    await gravarPartida(
      partidaRanqueada('casual', 'A', { tipo: 'publica_casual', alteraRanking: false })
    );
    const r = await processarResultadoOficial({
      matchId: 'casual',
      origem: 'gatilho',
      autor: null,
    });
    assert.equal(r.recusa, 'nao_pontua');
    assert.equal(await standingDe('u1'), undefined);
    assert.equal((await db().collection('rankingLedger').get()).size, 0);
  });

  test('§13 — torneio continua fora do Elo, mesmo com alteraRanking true', async () => {
    // A SEGUNDA GUARDA, que §13 manda manter protegida por teste: `alteraRanking`
    // sozinho deixaria o torneio passar.
    await gravarPartida(
      partidaRanqueada('t1', 'A', { tipo: 'torneio', alteraRanking: true })
    );
    const r = await processarResultadoOficial({ matchId: 't1', origem: 'gatilho', autor: null });
    assert.equal(r.recusa, 'fora_do_ambiente_competitivo');
    assert.equal(await standingDe('u1'), undefined);
  });

  test('§14 — identidade publica existe sem VIP e nao da vantagem nenhuma', async () => {
    // Ninguem aqui tem entitlement. A identidade foi emitida do mesmo jeito, o
    // rating inicial e 1000 para todos e o delta e o mesmo dos dois lados.
    assert.equal((await db().collection('playerEntitlements').get()).size, 0);

    await gravarPartida(partidaRanqueada('m1', 'A'));
    const r = await processarResultadoOficial({ matchId: 'm1', origem: 'gatilho', autor: null });
    assert.equal(r.processada, true);
    assert.deepEqual(r.deltas, { u1: 20, u2: -20, u3: 20, u4: -20 });
    assert.equal((await standingDe('u1')).ratingInicial, 1000);

    for (const uid of OS_QUATRO) {
      assert.match(await publicIdDe(uid), /^P[0-9A-HJKMNP-TV-Z]{12}$/);
    }
  });
});
