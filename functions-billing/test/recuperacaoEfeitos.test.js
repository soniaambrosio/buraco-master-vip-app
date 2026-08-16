/**
 * recuperacaoEfeitos.test.js — o efeito REAL da recuperacao, e o que ela nao pode
 * ampliar.
 *
 * TRES PERGUNTAS, TRES BLOCOS
 *
 * 1. `EFE-1x` — EFEITO EM `concederFichasMensais`. Nao basta provar que um campo
 *    foi preenchido: o que interessa e se o jogador passa a receber. Cada classe
 *    do diagnostico e submetida a varredura de fichas ANTES e DEPOIS da
 *    recuperacao simulada, e o resultado e afirmado nos dois lados. O caso que
 *    importa e `EFE-13`: o direito MIGRADO continua recebendo ZERO mesmo com hash
 *    e plano recuperados, porque `inicioEm` nao tem fonte.
 *
 * 2. `EFE-2x` — MONOTONICIDADE. Recuperar metadado nao pode fazer uma compra
 *    historicamente nao atribuivel virar direito. `EFE-20` varre
 *    combinatoriamente titular x tipo x estado x plano e afirma que AUTO so
 *    aparece na unica celula autorizada.
 *
 * 3. `EFE-3x` — AUDITORIA DO CICLO. A semantica de `inicioEm` dentro de
 *    `concederFichasMensais`, medida e nao suposta: mes civil, indice zero,
 *    teto por tick, deduplicacao — e o tamanho do lote retroativo que uma data
 *    antiga produziria. `EFE-32` existe para que esse numero apareca no relatorio
 *    como gate, e nao como surpresa em producao.
 *
 * NADA AQUI DISPARA CONCESSAO REAL: o Firestore e o falso, o catalogo e local, e
 * o relogio e injetado.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  VEREDITO,
  CLASSE,
  avaliarPlanoBase,
  comprasAtribuiveis,
  classificarMetadados,
} = require('../recuperacaoMetadados');

const { ESTADO, anteriorA } = require('../entitlement');
const { chaveDaCompra } = require('../entitlementStore');
const { ESTADO: ESTADO_COMPRA } = require('../idempotencia');
const {
  TETO_PARCELAS_POR_TICK,
  mesesDecorridos,
  indicesDevidos,
} = require('../fichas');
const { criarLivroDeFichas } = require('../fichasStore');
const { concederFichasDeTodosOsAssinantes } = require('../fichasVarredura');
const { FirestoreFalso, CARIMBO, FieldPathFalso } = require('./apoio/firestore_falso');

const AGORA = '2026-08-15T12:00:00.000Z';
const FUTURO = '2026-12-01T00:00:00.000Z';
const INICIO = '2026-05-15T00:00:00.000Z'; // 3 meses antes de AGORA
const HASH = chaveDaCompra('token-A');

const CATALOGO = {
  vip_assinatura: {
    assinatura: true,
    planos: { mensal: { ativacao: 1500, mensal: 1000 } },
  },
};

// ---------------------------------------------------------------------------
// Apoio
// ---------------------------------------------------------------------------

function semearEntitlement(db, uid, { hash, planoBase, inicioEm }) {
  db.semear(`playerEntitlements/${uid}`, {
    uid,
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: 'vip_assinatura',
    planoBase: planoBase || null,
    origem: 'legado_usuarios',
    inicioEm: inicioEm || null,
    expiraEm: FUTURO,
    esquema: 1,
  });
  db.semear(`playerEntitlements/${uid}/interno/billing`, {
    uid,
    purchaseTokenHash: hash || null,
    purchaseToken: null,
    produtoId: 'vip_assinatura',
    assinatura: true,
    esquema: 1,
  });
  return db;
}

function rodarFichas(db, agora = AGORA) {
  const livro = criarLivroDeFichas({
    db,
    carimbo: () => CARIMBO,
    incremento: (n) => ({ __incremento: n }),
  });
  return concederFichasDeTodosOsAssinantes({
    db,
    FieldPath: FieldPathFalso,
    colecaoEntitlement: 'playerEntitlements',
    catalogo: CATALOGO,
    agora,
    anteriorA,
    lerInterno: async (uid) => {
      const s = await db.doc(`playerEntitlements/${uid}/interno/billing`).get();
      return s.exists ? s.data() : null;
    },
    liquidarParcela: (p) => livro.liquidarParcela(p),
  });
}

/**
 * Roda a varredura de fichas ANTES e DEPOIS da recuperacao simulada.
 *
 * "Simulada" e a palavra exata: nada e gravado por rotina de backfill nenhuma. O
 * cenario "depois" e SEMEADO com os valores que o diagnostico declarou
 * recuperaveis (`veredito: AUTO`) — e so com esses. O que ele declarou
 * `SEM_FONTE` continua ausente, que e o ponto do teste.
 */
async function antesEDepois({ hash, planoBase, inicioEm, compras }) {
  const antesDb = semearEntitlement(new FirestoreFalso(), 'u1', {
    hash,
    planoBase,
    inicioEm,
  });
  const antes = await rodarFichas(antesDb);

  const c = classificarMetadados({
    uid: 'u1',
    publico: antesDb.ver('playerEntitlements/u1'),
    interno: antesDb.ver('playerEntitlements/u1/interno/billing'),
    compras,
    agora: AGORA,
  });

  const recuperado = (nome, atualValor) =>
    c.campos[nome].veredito === VEREDITO.AUTO ? c.campos[nome].valor : atualValor;

  const depoisDb = semearEntitlement(new FirestoreFalso(), 'u1', {
    hash: recuperado('purchaseTokenHash', hash),
    planoBase: recuperado('planoBase', planoBase),
    inicioEm: recuperado('inicioEm', inicioEm),
  });
  const depois = await rodarFichas(depoisDb);

  return { classificacao: c, antes, depois };
}

function compra(hash, extra = {}) {
  const { concessao = {}, ...resto } = extra;
  return {
    hash,
    dados: {
      uid: 'u1',
      produtoId: 'vip_assinatura',
      assinatura: true,
      orderId: 'GPA.1111-2222-3333-44444',
      estado: ESTADO_COMPRA.CONCEDIDA,
      criadoEm: '2026-05-20T10:00:00.000Z',
      concedidoEm: '2026-05-20T10:00:03.000Z',
      concessao: { vip: true, vipExpiraEm: FUTURO, planoBase: 'mensal', ...concessao },
      ...resto,
    },
  };
}

// ===========================================================================
// EFEITO REAL EM `concederFichasMensais`
// ===========================================================================

test('EFE-10 JA_CONSISTENTE: recebia antes e continua recebendo, sem mudanca', async () => {
  const r = await antesEDepois({
    hash: HASH,
    planoBase: 'mensal',
    inicioEm: INICIO,
    compras: [compra(HASH)],
  });

  assert.equal(r.classificacao.classe, CLASSE.JA_CONSISTENTE);
  assert.equal(r.antes.parcelas, 4, 'indices 0..3');
  assert.equal(r.depois.parcelas, 4);
  assert.equal(r.antes.fichas, r.depois.fichas);
});

test('EFE-11 so o HASH faltando: bloqueado antes, APTO depois — a recuperacao entrega', async () => {
  const r = await antesEDepois({
    hash: null,
    planoBase: 'mensal',
    inicioEm: INICIO,
    compras: [compra(HASH)],
  });

  assert.equal(r.classificacao.classe, CLASSE.AUTO_RECUPERAVEL);
  assert.equal(r.antes.parcelas, 0);
  assert.equal(r.antes.semPlano, 1, 'sem hash cai em `semPlano`');
  assert.equal(r.depois.parcelas, 4);
  assert.ok(r.depois.fichas > 0);
});

test('EFE-12 so o PLANO faltando: bloqueado antes, APTO depois', async () => {
  const r = await antesEDepois({
    hash: HASH,
    planoBase: null,
    inicioEm: INICIO,
    compras: [compra(HASH)],
  });

  assert.equal(r.classificacao.classe, CLASSE.AUTO_RECUPERAVEL);
  assert.equal(r.antes.parcelas, 0);
  assert.equal(r.antes.semPlano, 1, 'sem planoBase, `planoDoCatalogo` devolve null');
  assert.equal(r.depois.parcelas, 4);
});

test('EFE-13 o direito MIGRADO continua recebendo ZERO — e este e o resultado da OS', async () => {
  // Hash e plano sao recuperaveis; `inicioEm` nao tem fonte. Sem inicio,
  // `mesesDecorridos` devolve -1 e NENHUM indice vence. Preencher os outros dois
  // campos nao move uma ficha sequer.
  const r = await antesEDepois({
    hash: null,
    planoBase: null,
    inicioEm: null,
    compras: [compra(HASH)],
  });

  assert.equal(r.classificacao.classe, CLASSE.AUTO_PARCIAL);
  assert.equal(r.classificacao.campos.purchaseTokenHash.veredito, VEREDITO.AUTO);
  assert.equal(r.classificacao.campos.planoBase.veredito, VEREDITO.AUTO);
  assert.equal(r.classificacao.campos.inicioEm.veredito, VEREDITO.SEM_FONTE);

  assert.equal(r.antes.parcelas, 0);
  assert.equal(r.depois.parcelas, 0, 'DOIS campos recuperados, e nenhuma ficha paga');
  assert.equal(r.classificacao.apto.depois, false);
  assert.equal(r.classificacao.bloqueio, 'inicioEm');

  // E a ausencia e SILENCIOSA: nem `semPlano` acusa depois da recuperacao.
  assert.equal(r.depois.semPlano, 0);
  assert.equal(r.depois.candidatos, 1, 'o jogador e visitado, e sai sem nada');
});

test('EFE-14 AMBIGUO nao recupera nada, e o resultado nao muda', async () => {
  const r = await antesEDepois({
    hash: null,
    planoBase: null,
    inicioEm: INICIO,
    compras: [
      compra(HASH, { concessao: { planoBase: 'mensal' } }),
      compra(chaveDaCompra('token-B'), { concessao: { planoBase: 'anual' } }),
    ],
  });

  assert.equal(r.classificacao.classe, CLASSE.AMBIGUO);
  assert.equal(r.antes.parcelas, 0);
  assert.equal(r.depois.parcelas, 0);
});

test('EFE-15 IRRECUPERAVEL permanece corretamente recusado', async () => {
  const r = await antesEDepois({
    hash: null,
    planoBase: null,
    inicioEm: null,
    compras: [],
  });
  assert.equal(r.classificacao.classe, CLASSE.IRRECUPERAVEL);
  assert.equal(r.antes.parcelas, 0);
  assert.equal(r.depois.parcelas, 0);
});

test('EFE-16 INCONSISTENTE nao e corrigido, e o plano gravado sobrevive', async () => {
  const r = await antesEDepois({
    hash: HASH,
    planoBase: 'mensal',
    inicioEm: INICIO,
    compras: [compra(HASH, { concessao: { planoBase: 'anual' } })],
  });

  assert.equal(r.classificacao.classe, CLASSE.INCONSISTENTE);
  assert.equal(r.classificacao.campos.planoBase.veredito, VEREDITO.INCONSISTENTE);
  // O plano do documento continua sendo o que la estava: nada foi trocado.
  assert.equal(r.depois.parcelas, r.antes.parcelas);
});

// ===========================================================================
// MONOTONICIDADE — a recuperacao nao amplia direito
// ===========================================================================

test('EFE-20 AUTO so aparece na celula autorizada: titular, assinatura e concedida', () => {
  // Varredura combinatoria do que torna uma compra fonte legitima. Se algum dia
  // uma celula a mais passar a devolver AUTO, este teste quebra antes da revisao.
  const titulares = ['u1', 'u2', undefined];
  const tipos = [true, false];
  const estados = [
    ESTADO_COMPRA.CONCEDIDA,
    ESTADO_COMPRA.EM_VALIDACAO,
    ESTADO_COMPRA.RECUSADA,
  ];

  const autorizadas = [];
  for (const uid of titulares) {
    for (const assinatura of tipos) {
      for (const estado of estados) {
        const c = compra(HASH, { uid, assinatura, estado });
        const atribuiveis = comprasAtribuiveis([c], 'u1');
        const r = avaliarPlanoBase({ atual: null, atribuiveis });
        if (r.veredito === VEREDITO.AUTO) {
          autorizadas.push(`${uid}/${assinatura}/${estado}`);
        }
      }
    }
  }

  assert.deepEqual(autorizadas, ['u1/true/concedida']);
});

test('EFE-21 o plano de OUTRA assinatura nunca vaza para este entitlement', () => {
  const alheia = compra(chaveDaCompra('token-de-outro'), {
    uid: 'u2',
    concessao: { planoBase: 'anual' },
  });
  const c = classificarMetadados({
    uid: 'u1',
    publico: {
      uid: 'u1',
      vipAtivo: true,
      estado: ESTADO.ATIVO,
      produtoId: 'vip_assinatura',
      planoBase: null,
      inicioEm: null,
      expiraEm: FUTURO,
      origem: 'legado_usuarios',
    },
    interno: { uid: 'u1', purchaseTokenHash: null, purchaseToken: null },
    compras: [alheia],
    agora: AGORA,
  });

  assert.notEqual(c.campos.planoBase.valor, 'anual');
  assert.equal(c.campos.planoBase.veredito, VEREDITO.SEM_FONTE);
});

test('EFE-22 a fonte do plano usa o MESMO criterio de titularidade que a do hash', () => {
  // Se a fonte do plano fosse mais frouxa, uma compra incapaz de dar identidade
  // ao direito poderia dar PLANO a ele. Aqui os dois vereditos andam juntos.
  const casos = [
    compra(HASH, { uid: 'u2' }),
    compra(HASH, { assinatura: false }),
    compra(HASH, { uid: undefined }),
  ];
  for (const c of casos) {
    const cl = classificarMetadados({
      uid: 'u1',
      publico: {
        uid: 'u1',
        vipAtivo: true,
        estado: ESTADO.ATIVO,
        planoBase: null,
        inicioEm: null,
        expiraEm: FUTURO,
        origem: 'legado_usuarios',
      },
      interno: { uid: 'u1', purchaseTokenHash: null },
      compras: [c],
      agora: AGORA,
    });
    assert.notEqual(cl.campos.planoBase.veredito, VEREDITO.AUTO);
    assert.notEqual(cl.campos.purchaseTokenHash.veredito, VEREDITO.AUTO);
  }
});

test('EFE-23 recuperar metadado nunca torna apto quem nao tem direito vigente', () => {
  for (const pub of [
    { vipAtivo: false, expiraEm: FUTURO, estado: ESTADO.EXPIRADO },
    { vipAtivo: true, expiraEm: '2026-01-01T00:00:00.000Z', estado: ESTADO.ATIVO },
    { vipAtivo: false, expiraEm: AGORA, estado: ESTADO.REEMBOLSADO },
    { vipAtivo: true, expiraEm: null, estado: ESTADO.ATIVO },
  ]) {
    const c = classificarMetadados({
      uid: 'u1',
      publico: { uid: 'u1', produtoId: 'vip_assinatura', planoBase: 'mensal', inicioEm: INICIO, origem: 'play', ...pub },
      interno: { uid: 'u1', purchaseTokenHash: HASH },
      compras: [compra(HASH)],
      agora: AGORA,
    });
    assert.equal(c.apto.depois, false, JSON.stringify(pub));
  }
});

// ===========================================================================
// AUDITORIA DO CICLO DE FICHAS
// ===========================================================================

test('EFE-30 a contagem e de MES CIVIL, e o indice 0 e a ativacao', () => {
  // Nao e intervalo de 30 dias: uma assinatura iniciada em 31/01 completa o mes 1
  // em 28/02, e nao em 02/03.
  assert.equal(mesesDecorridos('2026-01-31T00:00:00.000Z', '2026-02-28T00:00:00.000Z'), 1);
  assert.equal(mesesDecorridos('2026-01-31T00:00:00.000Z', '2026-02-27T00:00:00.000Z'), 0);

  // O indice 0 vence no dia da compra — a primeira parcela nao espera um mes.
  const d = indicesDevidos({ inicioEm: INICIO, agora: INICIO });
  assert.deepEqual(d.indices, [0]);

  // E sem inicio, NENHUM indice vence. E daqui que vem o bloqueio do migrado.
  assert.deepEqual(indicesDevidos({ inicioEm: null, agora: AGORA }).indices, []);
  assert.equal(mesesDecorridos(null, AGORA), -1);
});

test('EFE-31 a deduplicacao continua sendo `fichasConcessoes/{hash}_{indice}`', async () => {
  const db = semearEntitlement(new FirestoreFalso(), 'u1', {
    hash: HASH,
    planoBase: 'mensal',
    inicioEm: INICIO,
  });

  const primeira = await rodarFichas(db);
  const segunda = await rodarFichas(db);

  assert.equal(primeira.parcelas, 4);
  assert.equal(segunda.parcelas, 0);
  const linhas = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.deepEqual(
    linhas,
    [0, 1, 2, 3].map((i) => `fichasConcessoes/${HASH}_${i}`)
  );
});

test('EFE-32 GATE DE PRODUCAO: uma data antiga produz lote retroativo grande', async () => {
  // Se `inicioEm` fosse recuperado (ou inventado) com uma data de tres anos
  // atras, a PRIMEIRA varredura liquidaria o teto inteiro de uma vez. Este e o
  // numero que precisa aparecer no relatorio antes de qualquer decisao sobre
  // preencher a data — e a razao pela qual "arredondar" a data nao e um detalhe.
  const TRES_ANOS_ANTES = '2023-08-15T00:00:00.000Z';

  const devidos = indicesDevidos({ inicioEm: TRES_ANOS_ANTES, agora: AGORA });
  assert.equal(mesesDecorridos(TRES_ANOS_ANTES, AGORA), 36);
  assert.equal(devidos.indices.length, TETO_PARCELAS_POR_TICK);
  assert.equal(devidos.truncado, true, 'o teto MORDE, e e reportado');

  const db = semearEntitlement(new FirestoreFalso(), 'u1', {
    hash: HASH,
    planoBase: 'mensal',
    inicioEm: TRES_ANOS_ANTES,
  });
  const r = await rodarFichas(db);

  // 1 ativacao (1.500) + 23 mensalidades (1.000) num unico tick.
  assert.equal(r.parcelas, TETO_PARCELAS_POR_TICK);
  assert.equal(r.fichas, 1500 + 23 * 1000);
  assert.equal(r.truncados, 1, 'o corte por teto e DECLARADO, nao silencioso');
});

test('EFE-34 DEFEITO PREEXISTENTE: o que passa do teto nunca e entregue', async () => {
  // `fichas.js` afirma, no cabecalho de `TETO_PARCELAS_POR_TICK`, que "o que
  // passar disso e entregue no tick seguinte — nunca perdido". ISSO NAO E O QUE
  // ACONTECE. `indicesDevidos` fatia SEMPRE a partir do indice 0:
  //
  //     const limite = Math.min(total, teto);
  //     for (let i = 0; i < limite; i += 1) indices.push(i);
  //
  // Ela nao pula o que ja foi pago. Entao o tick seguinte recomputa os MESMOS
  // 0..23, encontra todos liquidados, e devolve zero. As parcelas 24..N nunca
  // chegam — nao hoje, nao amanha, nunca.
  //
  // O defeito e ANTERIOR a esta OS e nao foi introduzido por ela: hoje ele e
  // inalcancavel, porque o plano mais longo tem 12 parcelas e ninguem acumula 24.
  // Ele passa a ser alcancavel exatamente se `inicioEm` for preenchido com uma
  // data antiga — que e a operacao que esta OS estava avaliando. Por isso ele
  // entra no relatorio como bloqueador, e nao como curiosidade.
  const TRES_ANOS_ANTES = '2023-08-15T00:00:00.000Z';
  const db = semearEntitlement(new FirestoreFalso(), 'u1', {
    hash: HASH,
    planoBase: 'mensal',
    inicioEm: TRES_ANOS_ANTES,
  });

  const primeira = await rodarFichas(db);
  assert.equal(primeira.parcelas, TETO_PARCELAS_POR_TICK);

  const segunda = await rodarFichas(db);
  assert.equal(segunda.parcelas, 0, 'o tick seguinte NAO entrega o resto');
  assert.equal(segunda.truncados, 1, 'e ele segue anunciando truncamento para sempre');

  // O livro-razao para em 23: as parcelas 24..36 nao existem em lugar nenhum.
  const linhas = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.equal(linhas.length, TETO_PARCELAS_POR_TICK);
  assert.equal(db.ver(`fichasConcessoes/${HASH}_23`) != null, true);
  assert.equal(db.ver(`fichasConcessoes/${HASH}_24`), null);
});

test('EFE-33 o teto por tick e por JOGADOR, e nao um limite da politica', () => {
  // `TETO_PARCELAS_POR_TICK` existe para o caso patologico (data corrompida),
  // e nao para limitar quanto um assinante pode receber. Documentar isso importa:
  // quem lesse "teto 24" poderia concluir que a divida para em 24 parcelas.
  assert.equal(TETO_PARCELAS_POR_TICK, 24);
  const d = indicesDevidos({ inicioEm: '2020-01-01T00:00:00.000Z', agora: AGORA, teto: 1000 });
  assert.ok(d.indices.length > TETO_PARCELAS_POR_TICK);
  assert.equal(d.truncado, false);
});
