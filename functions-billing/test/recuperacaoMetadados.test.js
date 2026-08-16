/**
 * recuperacaoMetadados.test.js — o que da para recuperar, e o que nao da.
 *
 * O QUE ESTES TESTES PRECISAM PROVAR
 *
 * A OS proibe inventar dado comercial, e uma proibicao so vale se houver teste
 * que falhe quando ela for violada. Por isso a bateria nao se contenta em
 * exercitar as classes: ela fixa em codigo o **esquema historico completo** de
 * `compras/{hash}` — todos os campos que ja existiram em cinco geracoes de
 * `validarCompraPlay` — e prova que, com tudo preenchido, `inicioEm` continua
 * `SEM_FONTE` (`REC-30`) e que nenhuma das tres datas presentes vira inicio
 * (`REC-31`).
 *
 * Se alguem um dia decidir que `criadoEm` "da para usar", esses dois testes
 * quebram antes da revisao humana. E se um campo novo aparecer em `compras/`,
 * a fixture precisa ser atualizada de proposito — o que e exatamente o momento
 * de reabrir a pergunta.
 *
 * `REC-40` fecha a garantia estrutural: o fonte do diagnostico nao contem API de
 * escrita e nao importa o modulo que a tem.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  VEREDITO,
  CLASSE,
  BLOQUEIO,
  DATAS_HISTORICAS_QUE_NAO_SERVEM,
  avaliarPlanoBase,
  avaliarInicioEm,
  comprasAtribuiveis,
  classificarMetadados,
  resumoZerado,
  somarResumos,
  criarDiagnosticoMetadados,
} = require('../recuperacaoMetadados');

const { criarPortasDeLeitura } = require('../backfillHash');
const { chaveDaCompra } = require('../entitlementStore');
const { ESTADO: ESTADO_COMPRA } = require('../idempotencia');
const { ESTADO } = require('../entitlement');
const { TAMANHO_PAGINA } = require('../varredura');
const { FirestoreFalso, FieldPathFalso } = require('./apoio/firestore_falso');

const AGORA = '2026-08-15T12:00:00.000Z';
const FUTURO = '2026-12-01T00:00:00.000Z';
const PASSADO = '2026-01-10T00:00:00.000Z';

const HASH_A = chaveDaCompra('token-A');
const HASH_B = chaveDaCompra('token-B');

// ---------------------------------------------------------------------------
// O ESQUEMA HISTORICO, fixado em codigo
// ---------------------------------------------------------------------------

/**
 * `compras/{hash}` com TODOS os campos que ja existiram, nas cinco geracoes de
 * `validarCompraPlay` (`767b74a`, `32b6709`, `fe4cdb5`, `f2b06c1`/`4ef296e`,
 * `83a522b`). Nenhum campo foi omitido — e e por isso que `REC-30` prova alguma
 * coisa: se um campo novo aparecer, esta fixture tem que mudar junto.
 */
function compraHistoricaCompleta(hash, extra = {}) {
  return {
    hash,
    dados: {
      uid: 'u1',
      produtoId: 'vip_assinatura',
      assinatura: true,
      orderId: 'GPA.3311-2233-4455-66778',
      estado: ESTADO_COMPRA.CONCEDIDA,
      motivo: '',
      ultimoErro: null,
      // As DUAS datas que existem, as duas `serverTimestamp()` do momento em que
      // ESTE SISTEMA validou — e nao do inicio da assinatura na Google.
      criadoEm: '2026-02-01T08:30:00.000Z',
      concedidoEm: '2026-02-01T08:30:04.000Z',
      concessao: {
        vip: true,
        vipExpiraEm: FUTURO,
        planoBase: 'mensal',
        fichasCreditadas: 1500,
      },
      ...extra,
    },
  };
}

/** A mesma compra, mas com o `concessao` que a OS pode alterar caso a caso. */
function compra(hash, { concessao = {}, ...extra } = {}) {
  const base = compraHistoricaCompleta(hash, extra);
  base.dados.concessao = { ...base.dados.concessao, ...concessao };
  return base;
}

function publico(extra = {}) {
  return {
    uid: 'u1',
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: 'vip_assinatura',
    planoBase: null,
    origem: 'legado_usuarios',
    inicioEm: null,
    expiraEm: FUTURO,
    esquema: 1,
    ...extra,
  };
}

function interno(extra = {}) {
  return {
    uid: 'u1',
    purchaseTokenHash: null,
    purchaseToken: null,
    produtoId: 'vip_assinatura',
    assinatura: true,
    esquema: 1,
    ...extra,
  };
}

function classificar(opcoes = {}) {
  const {
    uid = 'u1',
    pub = publico(),
    int = interno(),
    compras = [],
  } = opcoes;
  return classificarMetadados({
    uid,
    publico: pub,
    interno: int,
    compras,
    agora: AGORA,
  });
}

// ===========================================================================
// `planoBase` — a fonte que EXISTE
// ===========================================================================

test('REC-01 plano ausente com UMA compra concedida e recuperavel', () => {
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [compra(HASH_A)],
  });
  assert.equal(r.veredito, VEREDITO.AUTO);
  assert.equal(r.valor, 'mensal');
});

test('REC-02 o valor recuperado e `concessao.planoBase`, e nada derivado', () => {
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [compra(HASH_A, { concessao: { planoBase: 'anual' } })],
  });
  assert.equal(r.valor, 'anual');
  // Nao vem do produtoId, nem das fichas creditadas, nem do prazo.
  assert.notEqual(r.valor, 'vip_assinatura');
});

test('REC-03 compra concedida SEM plano registrado nao vira fonte', () => {
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [compra(HASH_A, { concessao: { planoBase: null } })],
  });
  assert.equal(r.veredito, VEREDITO.SEM_FONTE);
  assert.equal(r.valor, null);
});

test('REC-04 compra em validacao nao prova plano', () => {
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [compra(HASH_A, { estado: ESTADO_COMPRA.EM_VALIDACAO })],
  });
  assert.equal(r.veredito, VEREDITO.SEM_FONTE);
});

test('REC-05 compra recusada (cancelada antes de valer) nao prova plano', () => {
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [compra(HASH_A, { estado: ESTADO_COMPRA.RECUSADA })],
  });
  assert.equal(r.veredito, VEREDITO.SEM_FONTE);
});

test('REC-06 duas compras com planos DIFERENTES sao ambiguas — upgrade/downgrade', () => {
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [
      compra(HASH_A, { concessao: { planoBase: 'mensal' } }),
      compra(HASH_B, { concessao: { planoBase: 'anual' } }),
    ],
  });
  assert.equal(r.veredito, VEREDITO.AMBIGUO);
  assert.equal(r.valor, null);
  assert.equal(r.motivo, 'planos_historicos_divergentes');
});

test('REC-07 duas compras com o MESMO plano nao sao ambiguas: nao ha escolha a fazer', () => {
  // Resubscribe ou renovacao com token novo, mesmo plano. Qualquer compra que se
  // escolhesse daria o mesmo valor, entao nao existe decisao a tomar.
  const r = avaliarPlanoBase({
    atual: null,
    atribuiveis: [
      compra(HASH_A, { concessao: { planoBase: 'trimestral' } }),
      compra(HASH_B, { concessao: { planoBase: 'trimestral' } }),
    ],
  });
  assert.equal(r.veredito, VEREDITO.AUTO);
  assert.equal(r.valor, 'trimestral');
  assert.equal(r.motivo, 'plano_unico_em_varias_compras');
});

test('REC-08 nao se escolhe a compra mais recente nem a mais antiga', () => {
  // A OS proibe explicitamente. Com planos distintos, a ordem nao desempata.
  const antiga = compra(HASH_A, {
    criadoEm: '2026-01-01T00:00:00.000Z',
    concessao: { planoBase: 'mensal' },
  });
  const recente = compra(HASH_B, {
    criadoEm: '2026-07-01T00:00:00.000Z',
    concessao: { planoBase: 'anual' },
  });
  assert.equal(
    avaliarPlanoBase({ atual: null, atribuiveis: [antiga, recente] }).veredito,
    VEREDITO.AMBIGUO
  );
  assert.equal(
    avaliarPlanoBase({ atual: null, atribuiveis: [recente, antiga] }).veredito,
    VEREDITO.AMBIGUO
  );
});

test('REC-09 plano ja presente nunca e sobrescrito', () => {
  const r = avaliarPlanoBase({
    atual: 'anual',
    atribuiveis: [compra(HASH_A, { concessao: { planoBase: 'anual' } })],
  });
  assert.equal(r.veredito, VEREDITO.PRESENTE);
  assert.equal(r.valor, 'anual');
});

test('REC-10 plano presente que DISCORDA da fonte e inconsistente, e nao corrigido', () => {
  const r = avaliarPlanoBase({
    atual: 'mensal',
    atribuiveis: [compra(HASH_A, { concessao: { planoBase: 'anual' } })],
  });
  assert.equal(r.veredito, VEREDITO.INCONSISTENTE);
  assert.equal(r.valor, null);
});

test('REC-11 plano presente sem fonte para conferir continua presente', () => {
  const r = avaliarPlanoBase({ atual: 'mensal', atribuiveis: [] });
  assert.equal(r.veredito, VEREDITO.PRESENTE);
});

// ===========================================================================
// `inicioEm` — a fonte que NAO EXISTE
// ===========================================================================

test('REC-30 com o esquema historico COMPLETO preenchido, `inicioEm` segue sem fonte', () => {
  // Esta e a prova central da OS. A fixture tem todos os campos que ja
  // existiram em `compras/{hash}` nas cinco geracoes de `validarCompraPlay`.
  // Nenhuma geracao jamais persistiu `startTime`.
  const completa = compraHistoricaCompleta(HASH_A);

  // Sanidade: a fixture esta mesmo cheia, e nao vazia por acidente.
  assert.ok(completa.dados.criadoEm);
  assert.ok(completa.dados.concedidoEm);
  assert.ok(completa.dados.concessao.vipExpiraEm);
  assert.ok(completa.dados.concessao.planoBase);
  assert.ok(completa.dados.orderId);

  const r = avaliarInicioEm({ atual: null, atribuiveis: [completa] });
  assert.equal(r.veredito, VEREDITO.SEM_FONTE);
  assert.equal(r.valor, null);
  assert.equal(r.motivo, 'compras_existem_mas_nenhuma_registrou_inicio');
});

test('REC-31 as tres datas que EXISTEM sao recusadas por nome, e nao ignoradas', () => {
  const r = avaliarInicioEm({
    atual: null,
    atribuiveis: [compraHistoricaCompleta(HASH_A)],
  });
  // O diagnostico DECLARA quais datas viu e recusou. Recusar em silencio faria
  // parecer que nao havia data nenhuma, quando o problema e outro: ha datas, e
  // nenhuma delas significa "inicio da assinatura".
  assert.deepEqual(r.datasRecusadas, DATAS_HISTORICAS_QUE_NAO_SERVEM);
  assert.deepEqual(
    [...DATAS_HISTORICAS_QUE_NAO_SERVEM].sort(),
    ['concedidoEm', 'concessao.vipExpiraEm', 'criadoEm']
  );
});

test('REC-32 nem com dez compras historicas o inicio aparece', () => {
  const muitas = Array.from({ length: 10 }, (_, i) =>
    compraHistoricaCompleta(chaveDaCompra(`token-${i}`), {
      criadoEm: `2026-0${(i % 9) + 1}-01T00:00:00.000Z`,
    })
  );
  const r = avaliarInicioEm({ atual: null, atribuiveis: muitas });
  assert.equal(r.veredito, VEREDITO.SEM_FONTE);
});

test('REC-33 `inicioEm` ja presente e reconhecido, e nunca recalculado', () => {
  const r = avaliarInicioEm({
    atual: PASSADO,
    atribuiveis: [compraHistoricaCompleta(HASH_A)],
  });
  assert.equal(r.veredito, VEREDITO.PRESENTE);
  assert.equal(r.valor, PASSADO);
});

// ===========================================================================
// CLASSIFICACAO DO ENTITLEMENT
// ===========================================================================

test('REC-12 entitlement ja completo e JA_CONSISTENTE e apto antes e depois', () => {
  const c = classificar({
    pub: publico({ planoBase: 'mensal', inicioEm: PASSADO, origem: 'play' }),
    int: interno({ purchaseTokenHash: HASH_A }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.JA_CONSISTENTE);
  assert.equal(c.apto.antes, true);
  assert.equal(c.apto.depois, true);
  assert.equal(c.bloqueio, BLOQUEIO.NENHUM);
});

test('REC-13 hash ausente com plano e inicio presentes e AUTO_RECUPERAVEL, e fica apto', () => {
  const c = classificar({
    pub: publico({ planoBase: 'mensal', inicioEm: PASSADO, origem: 'play' }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.AUTO_RECUPERAVEL);
  assert.equal(c.campos.purchaseTokenHash.veredito, VEREDITO.AUTO);
  assert.equal(c.apto.antes, false);
  assert.equal(c.apto.depois, true, 'este e o caso que a recuperacao destrava');
});

test('REC-14 o direito MIGRADO tipico e AUTO_PARCIAL, e continua bloqueado por `inicioEm`', () => {
  // ESTE E O CASO DA POPULACAO LEGADA. Hash e plano sao recuperaveis; o inicio
  // nao existe em lugar nenhum, e sem ele nenhuma parcela vence.
  const c = classificar({ compras: [compra(HASH_A)] });

  assert.equal(c.classe, CLASSE.AUTO_PARCIAL);
  assert.equal(c.campos.purchaseTokenHash.veredito, VEREDITO.AUTO);
  assert.equal(c.campos.planoBase.veredito, VEREDITO.AUTO);
  assert.equal(c.campos.inicioEm.veredito, VEREDITO.SEM_FONTE);
  assert.equal(c.apto.antes, false);
  assert.equal(c.apto.depois, false);
  assert.equal(c.bloqueio, 'inicioEm');
  assert.deepEqual(c.faltantes, ['inicioEm']);
});

test('REC-15 sem nenhuma compra atribuivel tudo fica irrecuperavel', () => {
  const c = classificar({ compras: [] });
  assert.equal(c.classe, CLASSE.IRRECUPERAVEL);
  assert.equal(c.bloqueio, BLOQUEIO.MULTIPLOS);
  assert.deepEqual(c.faltantes, ['purchaseTokenHash', 'planoBase', 'inicioEm']);
});

test('REC-16 compra de OUTRO uid nao recupera nada deste', () => {
  const c = classificar({ compras: [compra(HASH_A, { uid: 'u2' })] });
  // O hash denuncia o titular alheio; o plano nao ve fonte nenhuma.
  assert.equal(c.classe, CLASSE.INCONSISTENTE);
  assert.equal(comprasAtribuiveis([compra(HASH_A, { uid: 'u2' })], 'u1').length, 0);
});

test('REC-17 compra que nao e assinatura nao e atribuivel', () => {
  const c = classificar({ compras: [compra(HASH_A, { assinatura: false })] });
  assert.equal(c.campos.planoBase.veredito, VEREDITO.SEM_FONTE);
  assert.equal(c.campos.purchaseTokenHash.veredito, VEREDITO.SEM_FONTE);
});

test('REC-18 planos divergentes tornam o entitlement AMBIGUO, e nao parcialmente auto', () => {
  const c = classificar({
    compras: [
      compra(HASH_A, { concessao: { planoBase: 'mensal' } }),
      compra(HASH_B, { concessao: { planoBase: 'anual' } }),
    ],
  });
  assert.equal(c.classe, CLASSE.AMBIGUO);
  assert.equal(c.apto.depois, false);
});

test('REC-19 contradicao vence ambiguidade e ausencia na escolha da classe', () => {
  // Plano atual discorda da fonte E o hash e ambiguo. O operador precisa ver a
  // contradicao, que e o fato mais grave.
  const c = classificar({
    pub: publico({ planoBase: 'mensal', inicioEm: PASSADO }),
    compras: [
      compra(HASH_A, { concessao: { planoBase: 'anual' } }),
      compra(HASH_B, { concessao: { planoBase: 'anual' } }),
    ],
  });
  assert.equal(c.campos.planoBase.veredito, VEREDITO.INCONSISTENTE);
  assert.equal(c.classe, CLASSE.INCONSISTENTE);
});

test('REC-20 direito vencido nunca conta como apto, mesmo com os tres campos', () => {
  const c = classificar({
    pub: publico({
      planoBase: 'mensal',
      inicioEm: PASSADO,
      expiraEm: '2026-07-01T00:00:00.000Z', // ja passou
      vipAtivo: true,
    }),
    int: interno({ purchaseTokenHash: HASH_A }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.vigente, false);
  assert.equal(c.apto.antes, false);
  assert.equal(c.apto.depois, false);
  assert.equal(c.bloqueio, BLOQUEIO.SEM_DIREITO_VIGENTE);
});

test('REC-21 entitlement estornado nao vira apto por recuperacao de metadado', () => {
  const c = classificar({
    pub: publico({
      estado: ESTADO.REEMBOLSADO,
      vipAtivo: false,
      planoBase: 'mensal',
      inicioEm: PASSADO,
    }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.vigente, false);
  assert.equal(c.apto.depois, false);
});

test('REC-22 documento orfao e sem interno ficam FORA_DO_ESCOPO', () => {
  assert.equal(classificar({ pub: null }).classe, CLASSE.FORA_DO_ESCOPO);
  assert.equal(classificar({ int: null }).classe, CLASSE.FORA_DO_ESCOPO);
});

test('REC-23 sem correlacao de compras nao se conclui nada', () => {
  const c = classificarMetadados({
    uid: 'u1',
    publico: publico(),
    interno: interno(),
    compras: null,
    agora: AGORA,
  });
  assert.equal(c.classe, CLASSE.NAO_INVESTIGADO);
});

test('REC-24 compras duplicadas com dados identicos nao criam ambiguidade', () => {
  // O mesmo documento devolvido duas vezes por um leitor defeituoso: o plano e o
  // mesmo, entao nao ha escolha; o HASH, porem, e o mesmo valor repetido e o
  // classificador do hash conta duas entradas — e conta certo, porque duas
  // linhas em `compras/` sao duas compras ate prova em contrario.
  const c = classificar({ compras: [compra(HASH_A), compra(HASH_A)] });
  assert.equal(c.campos.planoBase.veredito, VEREDITO.AUTO);
  assert.equal(c.campos.purchaseTokenHash.veredito, VEREDITO.AMBIGUO);
  assert.equal(c.classe, CLASSE.AMBIGUO);
});

// ===========================================================================
// VARREDURA
// ===========================================================================

function semear(db, uid, { pub, int, compras = [] } = {}) {
  if (pub !== null) db.semear(`playerEntitlements/${uid}`, pub || publico({ uid }));
  if (int !== null) {
    db.semear(`playerEntitlements/${uid}/interno/billing`, int || interno({ uid }));
  }
  for (const c of compras) db.semear(`compras/${c.hash}`, c.dados);
  return db;
}

function semearMigrados(db, n, prefixo = 'u') {
  for (let i = 0; i < n; i += 1) {
    const uid = `${prefixo}${String(i).padStart(5, '0')}`;
    const h = chaveDaCompra(`token-${uid}`);
    semear(db, uid, {
      pub: publico({ uid }),
      int: interno({ uid }),
      compras: [compra(h, { uid })],
    });
  }
  return db;
}

function montar(db, { correlacionar = true } = {}) {
  const portas = criarPortasDeLeitura({ db, FieldPath: FieldPathFalso });
  return criarDiagnosticoMetadados({
    ...portas,
    lerComprasDoJogador: correlacionar ? portas.lerComprasDoJogador : null,
    agora: () => AGORA,
  });
}

test('REC-25 a soma das classes fecha com os examinados', async () => {
  const db = new FirestoreFalso();
  semearMigrados(db, 4, 'a');
  semear(db, 'b1', { compras: [] });
  semear(db, 'b2', {
    pub: publico({ uid: 'b2', planoBase: 'mensal', inicioEm: PASSADO }),
    int: interno({ uid: 'b2', purchaseTokenHash: HASH_A }),
    compras: [compra(HASH_A, { uid: 'b2' })],
  });
  semear(db, 'b3', { int: null });

  const r = await montar(db).diagnosticar();
  const soma = Object.values(r.resumo.porClasse).reduce((a, b) => a + b, 0);

  assert.equal(r.examinados, 7);
  assert.equal(soma, 7);
  assert.equal(r.resumo.porClasse[CLASSE.AUTO_PARCIAL], 4);
  assert.equal(r.resumo.porClasse[CLASSE.IRRECUPERAVEL], 1);
  assert.equal(r.resumo.porClasse[CLASSE.JA_CONSISTENTE], 1);
  assert.equal(r.resumo.porClasse[CLASSE.FORA_DO_ESCOPO], 1);
});

test('REC-26 a METRICA PRINCIPAL: aptos antes, aptos depois, e o ganho', async () => {
  const db = new FirestoreFalso();
  // 5 migrados: recuperaveis em hash e plano, bloqueados por inicio. Ganho zero.
  semearMigrados(db, 5, 'm');
  // 2 que so precisam do hash: a recuperacao destrava os dois.
  for (const uid of ['p1', 'p2']) {
    const h = chaveDaCompra(`token-${uid}`);
    semear(db, uid, {
      pub: publico({ uid, planoBase: 'mensal', inicioEm: PASSADO, origem: 'play' }),
      int: interno({ uid }),
      compras: [compra(h, { uid })],
    });
  }
  // 1 ja completo.
  semear(db, 'z1', {
    pub: publico({ uid: 'z1', planoBase: 'mensal', inicioEm: PASSADO, origem: 'play' }),
    int: interno({ uid: 'z1', purchaseTokenHash: HASH_A }),
    compras: [compra(HASH_A, { uid: 'z1' })],
  });

  const r = await montar(db).diagnosticar();

  assert.equal(r.resumo.aptidao.vigentes, 8);
  assert.equal(r.resumo.aptidao.aptosAntes, 1);
  assert.equal(r.resumo.aptidao.aptosDepois, 3);
  assert.equal(r.resumo.aptidao.ganho, 2);
  // E os cinco migrados continuam bloqueados pelo MESMO campo.
  assert.equal(r.resumo.porBloqueio.inicioEm, 5);
});

test('REC-27 o relatorio diz QUAL campo bloqueia, campo a campo', async () => {
  const db = semearMigrados(new FirestoreFalso(), 3);
  const r = await montar(db).diagnosticar();

  assert.equal(r.resumo.porCampo.purchaseTokenHash[VEREDITO.AUTO], 3);
  assert.equal(r.resumo.porCampo.planoBase[VEREDITO.AUTO], 3);
  assert.equal(r.resumo.porCampo.inicioEm[VEREDITO.SEM_FONTE], 3);
  assert.equal(r.resumo.porBloqueio.inicioEm, 3);
});

for (const n of [0, 1, TAMANHO_PAGINA - 1, TAMANHO_PAGINA, TAMANHO_PAGINA + 1]) {
  test(`REC-28 (${n} entitlements) a varredura visita todos e esgota`, async () => {
    const db = semearMigrados(new FirestoreFalso(), n);
    const r = await montar(db).diagnosticar();
    assert.equal(r.examinados, n);
    assert.equal(r.esgotou, true);
  });
}

test('REC-29 o resultado nao depende do tamanho da pagina, e a retomada soma', async () => {
  const semeador = () => semearMigrados(new FirestoreFalso(), 25);
  const inteira = await montar(semeador()).diagnosticar();

  for (const tamanho of [1, 3, 25, 26, 500]) {
    const r = await montar(semeador()).diagnosticar({ tamanhoPagina: tamanho });
    assert.deepEqual(r.resumo.porClasse, inteira.resumo.porClasse, `tamanho ${tamanho}`);
  }

  const d = montar(semeador());
  const p1 = await d.diagnosticar({ tamanhoPagina: 5, maxPaginas: 2 });
  assert.equal(p1.esgotou, false);
  const p2 = await d.diagnosticar({ tamanhoPagina: 5, cursorInicial: p1.cursor });
  assert.equal(p2.esgotou, true);

  const soma = somarResumos(p1.resumo, p2.resumo);
  assert.equal(soma.examinados, inteira.resumo.examinados);
  assert.deepEqual(soma.porClasse, inteira.resumo.porClasse);
  assert.equal(soma.aptidao.ganho, inteira.resumo.aptidao.ganho);
});

test('REC-34 executar de novo sobre os mesmos dados devolve exatamente o mesmo numero', async () => {
  const db = semearMigrados(new FirestoreFalso(), 12);
  const d = montar(db);
  const a = await d.diagnosticar();
  const b = await d.diagnosticar();
  assert.deepEqual(b.resumo, a.resumo);
});

test('REC-35 o diagnostico NAO escreve: o banco sai com a mesma versao documento a documento', async () => {
  const db = semearMigrados(new FirestoreFalso(), 10);
  const antes = db.retrato();
  await montar(db).diagnosticar();
  assert.deepEqual(db.retrato(), antes);
  assert.equal(db.commits, 0);
});

test('REC-36 um jogador problematico nao impede que os seguintes sejam examinados', async () => {
  const db = semearMigrados(new FirestoreFalso(), 5);
  const portas = criarPortasDeLeitura({ db, FieldPath: FieldPathFalso });
  const d = criarDiagnosticoMetadados({
    ...portas,
    lerComprasDoJogador: async (uid) => {
      if (uid === 'u00002') throw new Error('leitura falhou');
      return portas.lerComprasDoJogador(uid);
    },
    agora: () => AGORA,
  });
  const r = await d.diagnosticar();
  assert.equal(r.examinados, 4);
  assert.equal(r.resumo.comFalha, 1);
  assert.equal(r.esgotou, true);
});

test('REC-37 as amostras nao carregam uid nem valor recuperado', async () => {
  const db = semearMigrados(new FirestoreFalso(), 3);
  const r = await montar(db).diagnosticar();
  const texto = JSON.stringify(r.amostras);
  assert.equal(texto.includes('u00000'), false, 'uid vazou para a amostra');
  assert.equal(texto.includes(chaveDaCompra('token-u00000')), false, 'hash vazou');
  assert.ok(r.amostras[CLASSE.AUTO_PARCIAL].length > 0);
  assert.equal(r.amostras[CLASSE.AUTO_PARCIAL][0].bloqueio, 'inicioEm');
});

// ===========================================================================
// PROVAS ESTRUTURAIS
// ===========================================================================

test('REC-40 o fonte do diagnostico nao contem API de escrita nem importa quem tem', () => {
  const fonte = fs.readFileSync(
    path.join(__dirname, '..', 'recuperacaoMetadados.js'),
    'utf8'
  );
  for (const proibido of [
    '.set(',
    '.update(',
    '.delete(',
    '.create(',
    'runTransaction',
    'batch(',
    'FieldValue',
  ]) {
    assert.equal(
      fonte.includes(proibido),
      false,
      `\`${proibido}\` apareceu em recuperacaoMetadados.js: o dry-run e ESTRUTURAL`
    );
  }

  // O modulo de escrita da OS anterior. O que e proibido e IMPORTA-LO — citar o
  // nome dele em comentario, para explicar por que ele nao entra, e justamente o
  // que se quer que exista. Por isso a checagem e do `require`, e nao da palavra.
  assert.equal(
    /require\(['"]\.\/backfillHashStore['"]\)/.test(fonte),
    false,
    'importar backfillHashStore poria uma porta de escrita num caminho somente-leitura'
  );
});

test('REC-41 o classificador do hash e CONSUMIDO, e nao reimplementado', () => {
  const fonte = fs.readFileSync(
    path.join(__dirname, '..', 'recuperacaoMetadados.js'),
    'utf8'
  );
  assert.ok(
    fonte.includes("require('./backfillHash')"),
    'o modulo tem que consumir o classificador da OS anterior'
  );
  // E nao pode ter uma segunda regra de hash: nada de `sha256` nem de
  // `chaveDaCompra` aqui dentro.
  assert.equal(fonte.includes('createHash'), false);
  assert.equal(fonte.includes('chaveDaCompra'), false);
});

test('REC-42 o resumo zerado tem todas as chaves de todas as dimensoes', () => {
  const z = resumoZerado();
  for (const c of Object.values(CLASSE)) assert.equal(z.porClasse[c], 0, `classe ${c}`);
  for (const b of Object.values(BLOQUEIO)) assert.equal(z.porBloqueio[b], 0, `bloqueio ${b}`);
  for (const campo of ['purchaseTokenHash', 'planoBase', 'inicioEm']) {
    for (const v of Object.values(VEREDITO)) {
      assert.equal(z.porCampo[campo][v], 0, `${campo}.${v}`);
    }
  }
  assert.equal(z.aptidao.ganho, 0);
});
