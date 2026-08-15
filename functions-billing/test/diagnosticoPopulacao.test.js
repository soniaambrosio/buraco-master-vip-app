/**
 * diagnosticoPopulacao.test.js — o censo da populacao VIP, conferido caso a caso.
 *
 * O QUE ESTES TESTES PRECISAM PROVAR
 *
 * Um diagnostico erra de dois jeitos, e os dois sao caros. Se ele SUBESTIMA o
 * estrago, a migracao roda com aval e derruba pagante. Se ele SUPERESTIMA, a
 * ativacao comercial fica parada por um numero que ninguem conferiu.
 *
 * Por isso a bateria nao se contenta em exercitar as categorias: ela amarra cada
 * projecao a regra REAL que a migracao usa, e amarra cada contagem a soma que o
 * relatorio final publica. `DIAG-29` existe porque um resumo cujas partes nao
 * fecham com o total e pior que nenhum resumo — ele parece conferido.
 *
 * Tres provas estruturais fecham a bateria, e sao elas que separam este modulo de
 * um `dry-run` com flag: `DIAG-30` (reexecucao sobre os mesmos dados devolve
 * exatamente o mesmo numero), `DIAG-31` (o fonte nao contem API de escrita) e
 * `DIAG-32` (o banco sai da varredura com versao identica documento a documento).
 *
 * PAGINACAO: a fronteira testada e `TAMANHO_PAGINA` (200 hoje), com os casos
 * imediatamente antes, exatamente em cima e imediatamente depois — 199/200/201 e
 * 499/500/501 — mais 0, 1 e 1.200. Se o tamanho de pagina mudar, estes numeros
 * mudam junto: e por isso que eles sao derivados de `TAMANHO_PAGINA` e nao
 * escritos a mao no laco.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  CATEGORIA,
  ALERTA,
  INCONSISTENCIA,
  ACAO_DA_MIGRACAO,
  INTERSECAO,
  FASE,
  rotuloUid,
  classificarJogador,
  resumoZerado,
  somarResumos,
  criarDiagnosticoPopulacao,
  criarPortasFirestore,
} = require('../diagnosticoPopulacao');

const { TAMANHO_PAGINA } = require('../varredura');
const { FirestoreFalso, FieldPathFalso } = require('./apoio/firestore_falso');

const AGORA = '2026-08-15T12:00:00.000Z';
const FUTURO = '2026-09-20T12:00:00.000Z';
const PASSADO = '2026-07-01T12:00:00.000Z';
const MAIS_LONGE = '2026-12-01T12:00:00.000Z';

function classificar(legado, opcoes = {}) {
  const { publico = null, interno = null, compras = null, uid = 'u1' } = opcoes;
  return classificarJogador({ uid, legado, publico, interno, compras, agora: AGORA });
}

/** Um entitlement vindo da Play, completo. */
function entitlementPlay(extra = {}) {
  return {
    publico: {
      origem: 'play',
      estado: 'ativo',
      vipAtivo: true,
      expiraEm: FUTURO,
      ...(extra.publico || {}),
    },
    interno: {
      purchaseTokenHash: 'h'.repeat(64),
      purchaseToken: 'token-cru',
      ...(extra.interno || {}),
    },
  };
}

/** Um entitlement escrito pela migracao: sem hash e sem token, por construcao. */
function entitlementMigrado(extra = {}) {
  return {
    publico: {
      origem: 'legado_usuarios',
      estado: 'ativo',
      vipAtivo: true,
      expiraEm: FUTURO,
      ...(extra.publico || {}),
    },
    interno: { purchaseTokenHash: null, purchaseToken: null, ...(extra.interno || {}) },
  };
}

/** Um registro de `compras/{hash}` de assinatura. */
function compra(hash, { uid = 'u1', vipExpiraEm = null, assinatura = true } = {}) {
  return {
    hash,
    dados: {
      uid,
      assinatura,
      produtoId: 'vip_assinatura',
      estado: 'concedida',
      concessao: { vip: true, vipExpiraEm },
    },
  };
}

// ===========================================================================
// Classificacao — uma categoria por vez
// ===========================================================================

test('DIAG-01 documento sem `vip` verdadeiro e sem entitlement fica fora da populacao', () => {
  for (const legado of [{}, { vip: false }, { fichas: 900 }, { vip: null }]) {
    const c = classificar(legado);
    assert.equal(c.categoria, CATEGORIA.FORA_DA_POPULACAO);
    assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO);
    assert.deepEqual(c.alertas, []);
    assert.deepEqual(c.inconsistencias, []);
  }
});

test('DIAG-02 vip com prazo no futuro e migravel, e a migracao concede', () => {
  const c = classificar({ vip: true, vipExpiraEm: FUTURO, vipProdutoId: 'vip_mensal' });
  assert.equal(c.categoria, CATEGORIA.MIGRAVEL_VIGENTE);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.GRAVAR_ATIVO);
  assert.equal(c.estadoProjetado, 'ativo');
  assert.equal(c.fatos.legadoVigente, true);
});

test('DIAG-03 vip com prazo vencido migra como expirado, e e possivel pagante rebaixado', () => {
  const c = classificar({ vip: true, vipExpiraEm: PASSADO });
  assert.equal(c.categoria, CATEGORIA.MIGRAVEL_VENCIDO);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.GRAVAR_EXPIRADO);
  assert.equal(c.estadoProjetado, 'expirado');
  assert.ok(c.alertas.includes(ALERTA.POSSIVEL_PAGANTE_REBAIXADO));
  // Expirado nao receberia ficha nem com hash: nao ha perda mensal a contar.
  assert.ok(!c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
});

test('DIAG-04 vip sem prazo nenhum e bloqueado, e a migracao o faz sumir em silencio', () => {
  for (const legado of [{ vip: true }, { vip: true, vipExpiraEm: null }, { vip: true, vipExpiraEm: '' }]) {
    const c = classificar(legado);
    assert.equal(c.categoria, CATEGORIA.BLOQUEADO_SEM_PRAZO);
    assert.equal(c.acao, ACAO_DA_MIGRACAO.PULAR_SEM_PRAZO);
    assert.ok(c.alertas.includes(ALERTA.SUMICO_SILENCIOSO));
  }
});

test('DIAG-05 entitlement vindo da Play nao e tocado, e nao perde nada', () => {
  const c = classificar({ vip: true, vipExpiraEm: FUTURO }, entitlementPlay());
  assert.equal(c.categoria, CATEGORIA.JA_COBERTO_PELA_PLAY);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE);
  assert.ok(!c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
  assert.ok(!c.alertas.includes(ALERTA.SEM_RECONSULTA_POSSIVEL));
});

test('DIAG-06 entitlement ja migrado e reconhecido como tal, e perde a ficha mensal', () => {
  const c = classificar({ vip: true, vipExpiraEm: FUTURO }, entitlementMigrado());
  assert.equal(c.categoria, CATEGORIA.JA_MIGRADO);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE);
  assert.ok(c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
  assert.ok(c.alertas.includes(ALERTA.SEM_RECONSULTA_POSSIVEL));
});

test('DIAG-07 assinante comercial de hoje nao esta no legado, e e `so_entitlement`', () => {
  // Desde a consolidacao o Billing parou de gravar `vip` em `usuarios/`: este e o
  // formato do assinante NOVO, e a versao anterior do diagnostico nao o via.
  const c = classificar({ fichas: 120 }, entitlementPlay());
  assert.equal(c.categoria, CATEGORIA.SO_ENTITLEMENT);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO);
  assert.deepEqual(c.alertas, []);
});

test('DIAG-08 entitlement sem documento em `usuarios/` e orfao, e nao `so_entitlement`', () => {
  const c = classificarJogador({
    uid: 'u1',
    legado: null,
    ...entitlementPlay(),
    compras: null,
    agora: AGORA,
  });
  assert.equal(c.categoria, CATEGORIA.ENTITLEMENT_ORFAO);
  assert.equal(c.fatos.temLegado, false);
});

test('DIAG-09 `vip` truthy que nao e booleano fica INCLASSIFICAVEL, e nao "fora"', () => {
  // `where('vip','==',true)` nao ve nenhum destes. O efeito e o mesmo de estar
  // fora da populacao; a afirmacao, nao — e o diagnostico nao pode afirmar que
  // alguem nao tem VIP so porque o campo foi gravado com o tipo errado.
  for (const valor of [1, 'true', 'sim', 'VIP']) {
    const c = classificar({ vip: valor, vipExpiraEm: FUTURO });
    assert.equal(c.categoria, CATEGORIA.INCLASSIFICAVEL);
    assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO);
    assert.ok(c.inconsistencias.includes(INCONSISTENCIA.VIP_NAO_BOOLEANO));
  }
});

test('DIAG-10 `vip` mal tipado COM entitlement nao e inclassificavel: o entitlement decide', () => {
  const c = classificar({ vip: 1 }, entitlementPlay());
  assert.equal(c.categoria, CATEGORIA.SO_ENTITLEMENT);
  // A inconsistencia continua contada — ela e um defeito de dado, nao some.
  assert.ok(c.inconsistencias.includes(INCONSISTENCIA.VIP_NAO_BOOLEANO));
});

test('DIAG-11 prazo presente e ilegivel e contado como defeito, e nao vira "sem prazo" mudo', () => {
  const c = classificar({ vip: true, vipExpiraEm: 'nao-e-data' });
  assert.equal(c.categoria, CATEGORIA.BLOQUEADO_SEM_PRAZO);
  assert.ok(c.inconsistencias.includes(INCONSISTENCIA.PRAZO_ILEGIVEL));
  // Ausencia de campo NAO e defeito de dado: e so ausencia.
  const semCampo = classificar({ vip: true });
  assert.deepEqual(semCampo.inconsistencias, []);
});

test('DIAG-12 legado que promete mais que o entitlement vira DIVERGENCIA_DE_PRAZO', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: MAIS_LONGE },
    entitlementPlay({ publico: { expiraEm: FUTURO } })
  );
  assert.ok(c.alertas.includes(ALERTA.DIVERGENCIA_DE_PRAZO));
});

// ===========================================================================
// `purchaseTokenHash` — o achado central
// ===========================================================================

test('DIAG-13 hash e token sao campos diferentes: so o token governa a reconsulta', () => {
  const semToken = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    entitlementPlay({ interno: { purchaseTokenHash: 'h'.repeat(64), purchaseToken: null } })
  );
  assert.ok(semToken.alertas.includes(ALERTA.SEM_RECONSULTA_POSSIVEL));
  // Tem hash: o livro-razao funciona, a ficha mensal NAO se perde.
  assert.ok(!semToken.alertas.includes(ALERTA.SEM_FICHA_MENSAL));

  const semHash = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    entitlementPlay({ interno: { purchaseTokenHash: null, purchaseToken: 'cru' } })
  );
  assert.ok(semHash.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
  assert.ok(!semHash.alertas.includes(ALERTA.SEM_RECONSULTA_POSSIVEL));
});

test('DIAG-14 sem correlacao de compras o modulo NAO conclui que o hash e irrecuperavel', () => {
  const c = classificar({ vip: true, vipExpiraEm: FUTURO }, { compras: null });
  assert.ok(c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
  for (const a of [
    ALERTA.HASH_RECUPERAVEL_DE_COMPRAS,
    ALERTA.HASH_AMBIGUO,
    ALERTA.HASH_IRRECUPERAVEL,
  ]) {
    assert.ok(!c.alertas.includes(a), `nao devia afirmar ${a} sem ter investigado`);
  }
});

test('DIAG-15 migravel COM registro de compra tem o hash disponivel, e a perda e evitavel', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    { compras: [compra('a'.repeat(64))] }
  );
  assert.equal(c.categoria, CATEGORIA.MIGRAVEL_VIGENTE);
  assert.ok(c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
  assert.ok(c.alertas.includes(ALERTA.HASH_RECUPERAVEL_DE_COMPRAS));
  assert.ok(c.alertas.includes(ALERTA.EVIDENCIA_COMERCIAL));
  assert.ok(c.interseccoes.includes(INTERSECAO.MIGRAVEL_COM_HASH_RECUPERAVEL));
  assert.equal(c.fatos.hashesCandidatos, 1);
});

test('DIAG-16 migravel SEM registro de compra tem o hash irrecuperavel, e isso e declarado', () => {
  const c = classificar({ vip: true, vipExpiraEm: FUTURO }, { compras: [] });
  assert.ok(c.alertas.includes(ALERTA.HASH_IRRECUPERAVEL));
  assert.ok(!c.alertas.includes(ALERTA.EVIDENCIA_COMERCIAL));
  assert.ok(c.interseccoes.includes(INTERSECAO.MIGRAVEL_SEM_HASH_RECUPERAVEL));
});

test('DIAG-17 compra que nao e assinatura nao vira evidencia de VIP', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    { compras: [compra('c'.repeat(64), { assinatura: false })] }
  );
  assert.ok(c.alertas.includes(ALERTA.HASH_IRRECUPERAVEL));
  assert.equal(c.fatos.evidenciaComercial, false);
});

test('DIAG-18 duas assinaturas: ambiguo, salvo quando o prazo concedido desempata', () => {
  const ambiguo = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    { compras: [compra('a'.repeat(64)), compra('b'.repeat(64))] }
  );
  assert.ok(ambiguo.alertas.includes(ALERTA.HASH_AMBIGUO));
  assert.ok(ambiguo.inconsistencias.includes(INCONSISTENCIA.MULTIPLOS_HASHES_CANDIDATOS));
  assert.ok(!ambiguo.interseccoes.includes(INTERSECAO.MIGRAVEL_COM_HASH_RECUPERAVEL));

  // Uma delas concedeu exatamente o prazo que o legado carrega hoje.
  const desempatado = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    {
      compras: [
        compra('a'.repeat(64), { vipExpiraEm: PASSADO }),
        compra('b'.repeat(64), { vipExpiraEm: FUTURO }),
      ],
    }
  );
  assert.ok(desempatado.alertas.includes(ALERTA.HASH_RECUPERAVEL_DE_COMPRAS));
  assert.equal(desempatado.fatos.hashesCandidatos, 1);
});

test('DIAG-19 registro de compra de outro titular e denunciado, e nao usado', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    { uid: 'u1', compras: [compra('a'.repeat(64), { uid: 'outro' })] }
  );
  assert.ok(c.inconsistencias.includes(INCONSISTENCIA.COMPRA_DE_OUTRO_TITULAR));
  assert.equal(c.fatos.evidenciaComercial, false);
  assert.ok(c.alertas.includes(ALERTA.HASH_IRRECUPERAVEL));
});

// ===========================================================================
// Registros incompletos e contraditorios
// ===========================================================================

test('DIAG-20 entitlement sem estado e sem origem e contado como defeito de dado', () => {
  const c = classificar({}, { publico: { vipAtivo: false }, interno: null });
  assert.ok(c.inconsistencias.includes(INCONSISTENCIA.ENTITLEMENT_SEM_ESTADO));
  assert.ok(c.inconsistencias.includes(INCONSISTENCIA.ENTITLEMENT_SEM_ORIGEM));
});

test('DIAG-21 `vipAtivo: true` vencido ou sem prazo e contradicao, e nao acesso', () => {
  const vencido = classificar({}, entitlementPlay({ publico: { expiraEm: PASSADO } }));
  assert.ok(vencido.inconsistencias.includes(INCONSISTENCIA.ENTITLEMENT_ATIVO_VENCIDO));
  assert.equal(vencido.fatos.vigenteAgora, false);

  const semPrazo = classificar({}, entitlementPlay({ publico: { expiraEm: null } }));
  assert.ok(semPrazo.inconsistencias.includes(INCONSISTENCIA.ENTITLEMENT_ATIVO_SEM_PRAZO));
  assert.equal(semPrazo.fatos.vigenteAgora, false);
});

test('DIAG-22 origens impossiveis sao denunciadas nos dois sentidos', () => {
  const migradoComHash = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    entitlementMigrado({ interno: { purchaseTokenHash: 'x'.repeat(64) } })
  );
  assert.ok(migradoComHash.inconsistencias.includes(INCONSISTENCIA.MIGRADO_COM_HASH));

  const playSemHash = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    entitlementPlay({ interno: { purchaseTokenHash: null } })
  );
  assert.ok(playSemHash.inconsistencias.includes(INCONSISTENCIA.PLAY_SEM_HASH));
});

test('DIAG-23 legado VIP com entitlement sem acesso e uma contradicao entre fontes', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    entitlementPlay({ publico: { vipAtivo: false, estado: 'expirado', expiraEm: PASSADO } })
  );
  assert.ok(c.interseccoes.includes(INTERSECAO.LEGADO_VIP_E_ENTITLEMENT_SEM_ACESSO));
  assert.ok(c.interseccoes.includes(INTERSECAO.LEGADO_E_ENTITLEMENT));
});

// ===========================================================================
// Varredura — universo, paginacao, retomada
// ===========================================================================

/** Monta um banco falso e o diagnostico ligado nele pelas portas reais. */
function montar(semeador, { correlacionar = true } = {}) {
  const db = new FirestoreFalso();
  semeador(db);
  const portas = criarPortasFirestore({ db, FieldPath: FieldPathFalso });
  const diag = criarDiagnosticoPopulacao({
    ...portas,
    lerComprasDoJogador: correlacionar ? portas.lerComprasDoJogador : null,
    agora: () => AGORA,
  });
  return { db, diag };
}

/** `n` legados VIP vigentes, com id ordenavel e estavel. */
function semearLegados(db, n, extra = () => ({})) {
  for (let i = 1; i <= n; i += 1) {
    const uid = `u-${String(i).padStart(5, '0')}`;
    db.semear(`usuarios/${uid}`, { vip: true, vipExpiraEm: FUTURO, ...extra(i, uid) });
  }
}

test('DIAG-24 populacao vazia devolve zero, esgotou e sem cursor', async () => {
  const { diag } = montar(() => {});
  const r = await diag.diagnosticar();
  assert.equal(r.resumo.examinados, 0);
  assert.equal(r.esgotou, true);
  assert.equal(r.cursor, null);
  // Todas as chaves presentes desde o inicio, e todas zeradas.
  assert.deepEqual(r.resumo.porCategoria, resumoZerado().porCategoria);
});

test('DIAG-25 a varredura nao perde nem duplica em nenhuma fronteira de pagina', async () => {
  const p = TAMANHO_PAGINA;
  const tamanhos = [0, 1, p - 1, p, p + 1, 499, 500, 501, 1200];

  for (const n of tamanhos) {
    const { diag } = montar((db) => semearLegados(db, n));
    const r = await diag.diagnosticar();

    assert.equal(r.esgotou, true, `${n}: devia ter esgotado`);
    assert.equal(r.cursor, null, `${n}: nao devia sobrar cursor`);
    assert.equal(r.resumo.examinados, n, `${n}: total examinado`);
    assert.equal(
      r.resumo.porCategoria[CATEGORIA.MIGRAVEL_VIGENTE],
      n,
      `${n}: todos deviam ser migraveis vigentes`
    );
    // A soma das categorias fecha com o total: ninguem caiu em lugar nenhum.
    const soma = Object.values(r.resumo.porCategoria).reduce((a, b) => a + b, 0);
    assert.equal(soma, n, `${n}: soma das categorias`);
  }
});

test('DIAG-26 o jogador exatamente na virada de pagina e visitado uma vez so', async () => {
  const p = TAMANHO_PAGINA;
  // O documento de indice `p` e o primeiro da segunda pagina; o de indice `p-1`
  // e o ultimo da primeira. Sao os dois que um cursor errado perde ou repete.
  const { diag } = montar((db) =>
    semearLegados(db, p + 1, (i) => (i === p || i === p + 1 ? { vipExpiraEm: PASSADO } : {}))
  );
  const r = await diag.diagnosticar();
  assert.equal(r.resumo.examinados, p + 1);
  assert.equal(r.resumo.porCategoria[CATEGORIA.MIGRAVEL_VIGENTE], p - 1);
  assert.equal(r.resumo.porCategoria[CATEGORIA.MIGRAVEL_VENCIDO], 2);
});

test('DIAG-27 o teto de paginas devolve `esgotou: false` e o cursor, nunca um corte mudo', async () => {
  const { diag } = montar((db) => semearLegados(db, 1200));
  const parcial = await diag.diagnosticar({ tamanhoPagina: 100, maxPaginas: 3 });

  assert.equal(parcial.esgotou, false);
  assert.equal(parcial.cursor.fase, FASE.USUARIOS);
  assert.equal(parcial.resumo.examinados, 300);
  assert.ok(parcial.cursor.cursor, 'o ponto de retomada precisa vir junto');
});

test('DIAG-28 retomada por cursor atravessa as DUAS fases sem perder ninguem', async () => {
  const { diag } = montar((db) => {
    semearLegados(db, 250);
    // 40 entitlements orfaos: existem em `playerEntitlements/` e nao em `usuarios/`.
    for (let i = 1; i <= 40; i += 1) {
      const uid = `orfao-${String(i).padStart(5, '0')}`;
      db.semear(`playerEntitlements/${uid}`, {
        origem: 'play',
        estado: 'ativo',
        vipAtivo: true,
        expiraEm: FUTURO,
      });
      db.semear(`playerEntitlements/${uid}/interno/billing`, {
        purchaseTokenHash: 'h'.repeat(64),
        purchaseToken: 'cru',
      });
    }
  });

  const inteiro = await diag.diagnosticar();
  assert.equal(inteiro.resumo.examinados, 290);
  assert.equal(inteiro.resumo.porCategoria[CATEGORIA.ENTITLEMENT_ORFAO], 40);
  assert.equal(inteiro.resumo.porFase[FASE.USUARIOS], 250);
  assert.equal(inteiro.resumo.porFase[FASE.ENTITLEMENTS], 40);

  // Agora em pedacos de 3 paginas de 40, retomando pelo cursor ate esgotar.
  let acumulado = resumoZerado();
  let cursor = null;
  let voltas = 0;
  do {
    const parte = await diag.diagnosticar({
      cursorInicial: cursor,
      tamanhoPagina: 40,
      maxPaginas: 3,
    });
    acumulado = somarResumos(acumulado, parte.resumo);
    cursor = parte.esgotou ? null : parte.cursor;
    voltas += 1;
    assert.ok(voltas < 50, 'protecao contra laco infinito na retomada');
  } while (cursor);

  assert.deepEqual(acumulado, inteiro.resumo, 'a soma das partes e o todo');
});

test('DIAG-29 os totais fecham, e as interseccoes contam as sobreposicoes de verdade', async () => {
  const { diag } = montar((db) => {
    // 1) legado vigente, sem entitlement, COM compra registrada -> hash recuperavel
    db.semear('usuarios/a1', { vip: true, vipExpiraEm: FUTURO });
    db.semear('compras/hash-a1', {
      uid: 'a1',
      assinatura: true,
      concessao: { vipExpiraEm: FUTURO },
    });

    // 2) legado vigente, sem entitlement, SEM compra -> hash irrecuperavel
    db.semear('usuarios/a2', { vip: true, vipExpiraEm: FUTURO });

    // 3) legado vencido
    db.semear('usuarios/a3', { vip: true, vipExpiraEm: PASSADO });

    // 4) legado sem prazo, com evidencia comercial
    db.semear('usuarios/a4', { vip: true });
    db.semear('compras/hash-a4', { uid: 'a4', assinatura: true });

    // 5) legado + entitlement ja migrado (sem hash), vigente
    db.semear('usuarios/a5', { vip: true, vipExpiraEm: FUTURO });
    db.semear('playerEntitlements/a5', {
      origem: 'legado_usuarios',
      estado: 'ativo',
      vipAtivo: true,
      expiraEm: FUTURO,
    });
    db.semear('playerEntitlements/a5/interno/billing', {
      purchaseTokenHash: null,
      purchaseToken: null,
    });

    // 6) assinante comercial normal, completo
    db.semear('usuarios/a6', { fichas: 10 });
    db.semear('playerEntitlements/a6', {
      origem: 'play',
      estado: 'ativo',
      vipAtivo: true,
      expiraEm: FUTURO,
    });
    db.semear('playerEntitlements/a6/interno/billing', {
      purchaseTokenHash: 'h'.repeat(64),
      purchaseToken: 'cru',
    });

    // 7) fora de tudo
    db.semear('usuarios/a7', { fichas: 3 });
  });

  const { resumo } = await diag.diagnosticar();

  assert.equal(resumo.examinados, 7);
  assert.equal(resumo.correlacaoDeCompras, 7, 'a correlacao rodou para todos');

  assert.deepEqual(resumo.porCategoria, {
    [CATEGORIA.FORA_DA_POPULACAO]: 1,
    [CATEGORIA.SO_ENTITLEMENT]: 1,
    [CATEGORIA.JA_COBERTO_PELA_PLAY]: 0,
    [CATEGORIA.JA_MIGRADO]: 1,
    [CATEGORIA.MIGRAVEL_VIGENTE]: 2,
    [CATEGORIA.MIGRAVEL_VENCIDO]: 1,
    [CATEGORIA.BLOQUEADO_SEM_PRAZO]: 1,
    [CATEGORIA.ENTITLEMENT_ORFAO]: 0,
    [CATEGORIA.INCLASSIFICAVEL]: 0,
  });

  // Os prejudicados pela ausencia de hash: os dois migraveis vigentes + o migrado.
  assert.equal(resumo.porAlerta[ALERTA.SEM_FICHA_MENSAL], 3);
  assert.equal(resumo.porAlerta[ALERTA.HASH_RECUPERAVEL_DE_COMPRAS], 1);
  assert.equal(resumo.porAlerta[ALERTA.HASH_IRRECUPERAVEL], 2);
  // ...e recuperavel + ambiguo + irrecuperavel fecha com o total de prejudicados.
  assert.equal(
    resumo.porAlerta[ALERTA.HASH_RECUPERAVEL_DE_COMPRAS] +
      resumo.porAlerta[ALERTA.HASH_AMBIGUO] +
      resumo.porAlerta[ALERTA.HASH_IRRECUPERAVEL],
    resumo.porAlerta[ALERTA.SEM_FICHA_MENSAL]
  );

  assert.equal(resumo.porInterseccao[INTERSECAO.LEGADO_E_ENTITLEMENT], 1);
  assert.equal(resumo.porInterseccao[INTERSECAO.LEGADO_E_ENTITLEMENT_SEM_HASH], 1);
  assert.equal(resumo.porInterseccao[INTERSECAO.LEGADO_ATIVO_E_EVIDENCIA_COMERCIAL], 1);
  assert.equal(resumo.porInterseccao[INTERSECAO.MIGRAVEL_COM_HASH_RECUPERAVEL], 1);
  assert.equal(resumo.porInterseccao[INTERSECAO.MIGRAVEL_SEM_HASH_RECUPERAVEL], 2);
  assert.equal(resumo.porInterseccao[INTERSECAO.SEM_PRAZO_COM_EVIDENCIA_COMERCIAL], 1);
  assert.equal(resumo.porInterseccao[INTERSECAO.ENTITLEMENT_VIGENTE_SEM_HASH], 1);

  // `migravel_vencido` conta como migravel, mas nao entra nas contas de hash:
  // expirado nao recebe ficha, entao nao ha perda a recuperar.
  assert.equal(
    resumo.porInterseccao[INTERSECAO.MIGRAVEL_COM_HASH_RECUPERAVEL] +
      resumo.porInterseccao[INTERSECAO.MIGRAVEL_SEM_HASH_RECUPERAVEL],
    resumo.porAcao[ACAO_DA_MIGRACAO.GRAVAR_ATIVO] +
      resumo.porAcao[ACAO_DA_MIGRACAO.GRAVAR_EXPIRADO]
  );
});

test('DIAG-30 reexecutar sobre os mesmos dados devolve exatamente o mesmo resultado', async () => {
  const semear = (db) => {
    semearLegados(db, 120, (i) => {
      if (i % 5 === 0) return { vipExpiraEm: PASSADO };
      if (i % 7 === 0) return { vipExpiraEm: null };
      if (i % 11 === 0) return { vip: 1 };
      return {};
    });
    db.semear('compras/h1', { uid: 'u-00001', assinatura: true });
  };
  const { diag } = montar(semear);

  const a = await diag.diagnosticar();
  const b = await diag.diagnosticar();
  const c = await diag.diagnosticar({ tamanhoPagina: 7 });

  assert.deepEqual(b.resumo, a.resumo, 'duas execucoes iguais');
  // Tamanho de pagina e detalhe de transporte: nao pode mudar o censo.
  assert.deepEqual(c.resumo, a.resumo, 'o resultado nao depende do tamanho da pagina');
  assert.deepEqual(b.amostras, a.amostras, 'ate as amostras sao estaveis');
});

// ===========================================================================
// Garantias estruturais de somente-leitura
// ===========================================================================

test('DIAG-31 o fonte do modulo nao contem nenhuma API de escrita do Firestore', () => {
  const fonte = fs.readFileSync(
    path.join(__dirname, '..', 'diagnosticoPopulacao.js'),
    'utf8'
  );
  // Fora dos comentarios: o cabecalho fala sobre escrita de proposito.
  const codigo = fonte
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '')
    // E fora das cadeias de hash: `createHash(..).update(..).digest(..)` tem um
    // `.update(` que nao e escrita nenhuma. Recortar a cadeia inteira e melhor do
    // que abrir excecao para a string `.update(`, que passaria a valer tambem
    // para um `doc.update(` de verdade colado logo abaixo.
    .replace(/createHash\([^)]*\)(?:\.[a-zA-Z]+\([^)]*\))*/g, 'HASH');

  for (const proibido of [
    '.set(',
    '.update(',
    '.delete(',
    '.create(',
    '.add(',
    'runTransaction',
    'batch(',
    'FieldValue',
  ]) {
    assert.ok(
      !codigo.includes(proibido),
      `o diagnostico nao pode conter "${proibido}" — ele e somente leitura`
    );
  }
});

test('DIAG-32 a varredura inteira deixa o banco com a versao identica, documento a documento', async () => {
  const { db, diag } = montar((db) => {
    semearLegados(db, 250, (i) => (i % 3 === 0 ? { vipExpiraEm: PASSADO } : {}));
    db.semear('playerEntitlements/u-00002', {
      origem: 'legado_usuarios',
      estado: 'ativo',
      vipAtivo: true,
      expiraEm: FUTURO,
    });
    db.semear('playerEntitlements/u-00002/interno/billing', { purchaseTokenHash: null });
    db.semear('playerEntitlements/orfao', { origem: 'play', estado: 'ativo', vipAtivo: true, expiraEm: FUTURO });
    db.semear('compras/h1', { uid: 'u-00001', assinatura: true });
  });

  const antes = db.retrato();
  const r = await diag.diagnosticar();
  const depois = db.retrato();

  assert.ok(r.resumo.examinados > 0, 'o teste so vale se a varredura tiver trabalhado');
  // Caminho E versao: reescrever um documento existente nao criaria caminho novo,
  // entao comparar so a lista de caminhos deixaria a escrita passar.
  assert.deepEqual(depois, antes);
  assert.equal(db.commits, 0, 'nenhuma transacao foi commitada');
});

test('DIAG-33 as amostras carregam rotulo anonimo e estavel, nunca o uid nem o token', async () => {
  const { diag } = montar((db) => {
    db.semear('usuarios/jogador-real', { vip: true, vipExpiraEm: FUTURO });
    db.semear('compras/hash-secreto', { uid: 'jogador-real', assinatura: true });
  });

  const r = await diag.diagnosticar();
  const amostra = r.amostras[CATEGORIA.MIGRAVEL_VIGENTE][0];

  const texto = JSON.stringify(amostra);
  assert.ok(!texto.includes('jogador-real'), 'o uid nao pode vazar na amostra');
  assert.ok(!texto.includes('hash-secreto'), 'o hash do token nao pode vazar na amostra');
  // Deterministico: quem ja suspeita de um uid confere o rotulo sem enumerar ninguem.
  assert.equal(amostra.rotulo, rotuloUid('jogador-real'));
  assert.equal(amostra.rotulo.length, 12);
});

test('DIAG-34 sem a porta de compras a correlacao e declarada como nao executada', async () => {
  const { diag } = montar((db) => semearLegados(db, 5), { correlacionar: false });
  const r = await diag.diagnosticar();

  assert.equal(r.resumo.examinados, 5);
  assert.equal(r.resumo.correlacaoDeCompras, 0);
  assert.equal(r.resumo.porAlerta[ALERTA.SEM_FICHA_MENSAL], 5);
  // E, crucialmente, nada foi afirmado sobre recuperabilidade.
  assert.equal(r.resumo.porAlerta[ALERTA.HASH_IRRECUPERAVEL], 0);
  assert.equal(r.resumo.porAlerta[ALERTA.HASH_RECUPERAVEL_DE_COMPRAS], 0);
});
