/**
 * backfillHash.test.js — o mecanismo que preenche `purchaseTokenHash`.
 *
 * O QUE ESTES TESTES PRECISAM PROVAR
 *
 * Um backfill erra de dois jeitos, e os dois sao caros de desfazer. Se ele for
 * TIMIDO demais, o jogador legado continua sem ficha mensal e a OS nao serviu
 * para nada. Se ele for FROUXO, grava um hash errado num documento de pagante — e
 * um hash errado nao e um campo errado: ele vira a chave de
 * `fichasConcessoes/{hash}_{indice}` e o titulo de `mesmoToken`, entao o estrago
 * atravessa Billing, RTDN e livro-razao ao mesmo tempo.
 *
 * Por isso a bateria nao se contenta em exercitar as classes. Ela amarra:
 *
 *   - a REGRA a cada uma das oito perguntas de `classificarBackfill`, incluindo
 *     as que recusam (BFH-01 a BFH-18);
 *   - a VARREDURA as fronteiras de pagina, a retomada e a independencia do
 *     tamanho de pagina (BFH-19 a BFH-25);
 *   - a ESCRITA a idempotencia, a concorrencia e ao nao-sobrescrever
 *     (BFH-26 a BFH-35);
 *   - e tres provas ESTRUTURAIS, que sao as que separam este modulo de um
 *     `dry-run` com flag: BFH-36 (o dry-run sai com o banco documento a documento
 *     na mesma versao), BFH-40 (o fonte do classificador nao contem API de
 *     escrita) e BFH-41 (dry-run e escrita concordam classe a classe sobre a
 *     mesma base — nao ha dois classificadores).
 *
 * PAGINACAO: as fronteiras testadas sao derivadas de `TAMANHO_PAGINA`, e nao
 * escritas a mao — se o tamanho mudar, os casos mudam junto.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  CLASSE,
  MOTIVO,
  PARADA,
  ORIGEM_BACKFILL,
  ehHashValido,
  classificarBackfill,
  resumoZerado,
  somarResumos,
  criarBackfillHash,
  criarPortasDeLeitura,
} = require('../backfillHash');

const { RECUSA, APLICADO, criarGravadorDeHash } = require('../backfillHashStore');
const { chaveDaCompra } = require('../entitlementStore');
const { ESTADO: ESTADO_COMPRA } = require('../idempotencia');
const { TAMANHO_PAGINA } = require('../varredura');
const { FirestoreFalso, CARIMBO, FieldPathFalso } = require('./apoio/firestore_falso');

const TOKEN_A = 'token-play-A';
const TOKEN_B = 'token-play-B';
const HASH_A = chaveDaCompra(TOKEN_A);
const HASH_B = chaveDaCompra(TOKEN_B);

// ---------------------------------------------------------------------------
// Construtores de cenario
// ---------------------------------------------------------------------------

/** `playerEntitlements/{uid}` de um direito migrado do legado. */
function publicoMigrado(extra = {}) {
  return {
    uid: 'u1',
    vipAtivo: true,
    estado: 'ativo',
    produtoId: 'vip_mensal',
    planoBase: null,
    origem: 'legado_usuarios',
    inicioEm: null,
    expiraEm: '2026-12-01T00:00:00.000Z',
    renovacaoAutomatica: false,
    atualizadoEm: '2026-08-01T00:00:00.000Z',
    esquema: 1,
    ...extra,
  };
}

/** `playerEntitlements/{uid}/interno/billing` de um migrado: sem hash, sem token. */
function internoMigrado(extra = {}) {
  return {
    uid: 'u1',
    purchaseTokenHash: null,
    purchaseToken: null,
    produtoId: 'vip_mensal',
    assinatura: true,
    fonte: 'migracao',
    ultimaVerificacaoEm: '2026-08-01T00:00:00.000Z',
    esquema: 1,
    ...extra,
  };
}

/** Um registro de `compras/{hash}` como `validarCompraPlay` o grava. */
function compra(hash, extra = {}) {
  return {
    hash,
    dados: {
      uid: 'u1',
      produtoId: 'vip_mensal',
      assinatura: true,
      estado: ESTADO_COMPRA.CONCEDIDA,
      concessao: { vip: true, vipExpiraEm: '2026-12-01T00:00:00.000Z' },
      ...extra,
    },
  };
}

function classificar(opcoes = {}) {
  const {
    uid = 'u1',
    publico = publicoMigrado(),
    interno = internoMigrado(),
    compras = [],
  } = opcoes;
  return classificarBackfill({ uid, publico, interno, compras });
}

// ===========================================================================
// A REGRA DE ELEGIBILIDADE
// ===========================================================================

test('BFH-01 uma unica compra concedida deste uid e correlacao inequivoca', () => {
  const c = classificar({ compras: [compra(HASH_A)] });
  assert.equal(c.classe, CLASSE.AUTO);
  assert.equal(c.motivo, MOTIVO.CORRELACAO_INEQUIVOCA);
  assert.equal(c.hash, HASH_A);
});

test('BFH-02 o valor devolvido e o documentId historico, e nao algo derivado do uid', () => {
  const c = classificar({ compras: [compra(HASH_A)] });
  // O hash e exatamente o que `chaveDaCompra` produziria com o token na mao.
  assert.equal(c.hash, chaveDaCompra(TOKEN_A));
  assert.notEqual(c.hash, chaveDaCompra('u1'));
});

test('BFH-03 nenhum registro de compra: sem fonte, e nao "auto por falta de opcao"', () => {
  const c = classificar({ compras: [] });
  assert.equal(c.classe, CLASSE.SEM_FONTE);
  assert.equal(c.motivo, MOTIVO.NENHUMA_COMPRA_ATRIBUIVEL);
  assert.equal(c.hash, null);
});

test('BFH-04 duas compras atribuiveis sao AMBIGUAS, e nao se desempatam aqui', () => {
  const c = classificar({ compras: [compra(HASH_A), compra(HASH_B)] });
  assert.equal(c.classe, CLASSE.AMBIGUO);
  assert.equal(c.motivo, MOTIVO.MULTIPLAS_COMPRAS_ATRIBUIVEIS);
  assert.equal(c.hash, null);
});

test('BFH-05 o desempate por prazo que o DIAGNOSTICO usa nao vale para gravar', () => {
  // `diagnosticoPopulacao` escolheria a compra cujo `concessao.vipExpiraEm` casa
  // com o prazo do legado. Aqui isso continua AMBIGUO de proposito: contar quantos
  // sao recuperaveis e gravar num documento de pagante nao merecem o mesmo limiar.
  const c = classificar({
    compras: [
      compra(HASH_A, { concessao: { vipExpiraEm: '2026-12-01T00:00:00.000Z' } }),
      compra(HASH_B, { concessao: { vipExpiraEm: '2025-01-01T00:00:00.000Z' } }),
    ],
  });
  assert.equal(c.classe, CLASSE.AMBIGUO);
});

test('BFH-06 uma compra parada em `em_validacao` nao e fonte, e e SEM_FONTE', () => {
  const c = classificar({
    compras: [compra(HASH_A, { estado: ESTADO_COMPRA.EM_VALIDACAO })],
  });
  assert.equal(c.classe, CLASSE.SEM_FONTE);
  assert.equal(c.motivo, MOTIVO.UNICA_COMPRA_NAO_CONCEDIDA);
});

test('BFH-07 compra recusada tampouco concede hash', () => {
  const c = classificar({
    compras: [compra(HASH_A, { estado: ESTADO_COMPRA.RECUSADA })],
  });
  assert.equal(c.classe, CLASSE.SEM_FONTE);
});

test('BFH-08 uma compra NAO concedida ainda CONTA para a ambiguidade', () => {
  // Este e o caso que fecha o risco de `token_superado`: `titularDoToken` nao
  // olha o estado, entao a compra parada em validacao ainda pode trazer uma RTDN.
  // Exclui-la da contagem faria este uid parecer inequivoco.
  const c = classificar({
    compras: [compra(HASH_A), compra(HASH_B, { estado: ESTADO_COMPRA.EM_VALIDACAO })],
  });
  assert.equal(c.classe, CLASSE.AMBIGUO);
  assert.equal(c.fatos.comprasAtribuiveis, 2);
  assert.equal(c.fatos.comprasConcedidas, 1);
});

test('BFH-09 compra que nao e assinatura nao entra nem como fonte nem como ambiguidade', () => {
  const c = classificar({
    compras: [compra(HASH_A), compra(HASH_B, { assinatura: false })],
  });
  assert.equal(c.classe, CLASSE.AUTO);
  assert.equal(c.hash, HASH_A);
  assert.equal(c.fatos.comprasAtribuiveis, 1);
});

test('BFH-10 compra sem `uid` gravado nao e atribuivel a ninguem', () => {
  // `titularDoToken` recusa `registro_sem_uid`; a regra daqui acompanha.
  const c = classificar({ compras: [compra(HASH_A, { uid: undefined })] });
  assert.equal(c.classe, CLASSE.SEM_FONTE);
});

test('BFH-11 compra de outro titular no lote e CONFLITO, e nao ruido a ignorar', () => {
  const c = classificar({ compras: [compra(HASH_A), compra(HASH_B, { uid: 'u2' })] });
  assert.equal(c.classe, CLASSE.CONFLITO);
  assert.equal(c.motivo, MOTIVO.COMPRA_DE_OUTRO_TITULAR);
  assert.equal(c.hash, null);
});

test('BFH-12 id de compra fora do formato sha256 nao e hash e nao e usado', () => {
  const c = classificar({ compras: [compra('NAO-E-UM-SHA256')] });
  assert.equal(c.classe, CLASSE.SEM_FONTE);
  assert.equal(ehHashValido('NAO-E-UM-SHA256'), false);
  assert.equal(ehHashValido(HASH_A.toUpperCase()), false);
  assert.equal(ehHashValido(HASH_A), true);
});

test('BFH-13 entitlement JA preenchido com o hash historico e "ja preenchido"', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseTokenHash: HASH_A }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.JA_PREENCHIDO);
  assert.equal(c.motivo, MOTIVO.HASH_ATUAL_CONFERE);
  assert.equal(c.hash, null);
});

test('BFH-14 entitlement preenchido com hash que NAO esta em compras e CONFLITO', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseTokenHash: HASH_B }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.CONFLITO);
  assert.equal(c.motivo, MOTIVO.HASH_ATUAL_NAO_ESTA_EM_COMPRAS);
});

test('BFH-15 hash gravado fora de formato e CONFLITO, e nunca "vamos consertar"', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseTokenHash: 'lixo' }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.CONFLITO);
  assert.equal(c.motivo, MOTIVO.HASH_ATUAL_FORA_DE_FORMATO);
  assert.equal(c.hash, null);
});

test('BFH-16 o token em claro DESMENTE um candidato, e o desmentido vence', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseToken: TOKEN_B }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.CONFLITO);
  assert.equal(c.motivo, MOTIVO.CANDIDATO_DISCORDA_DO_TOKEN);
});

test('BFH-17 o token em claro que CONFIRMA o candidato deixa o AUTO passar', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseToken: TOKEN_A }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.AUTO);
  assert.equal(c.hash, HASH_A);
});

test('BFH-18 o token em claro sozinho NAO cria AUTO: a fonte autorizada e `compras/`', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseToken: TOKEN_A }),
    compras: [],
  });
  assert.equal(c.classe, CLASSE.SEM_FONTE);
  assert.equal(c.hash, null);
});

test('BFH-19 hash gravado que discorda do token em claro e CONFLITO', () => {
  const c = classificar({
    interno: internoMigrado({ purchaseTokenHash: HASH_A, purchaseToken: TOKEN_B }),
    compras: [compra(HASH_A)],
  });
  assert.equal(c.classe, CLASSE.CONFLITO);
  assert.equal(c.motivo, MOTIVO.HASH_ATUAL_DISCORDA_DO_TOKEN);
});

test('BFH-20 sem correlacao executada nao se conclui NEM "sem fonte" NEM "auto"', () => {
  const c = classificar({ compras: null });
  assert.equal(c.classe, CLASSE.NAO_INVESTIGADO);
  assert.equal(c.motivo, MOTIVO.CORRELACAO_NAO_EXECUTADA);
  assert.equal(c.hash, null);
});

test('BFH-21 sem entitlement e sem documento interno nao ha onde gravar', () => {
  assert.equal(
    classificar({ publico: null, compras: [compra(HASH_A)] }).classe,
    CLASSE.FORA_DO_ESCOPO
  );
  const semInterno = classificar({ interno: null, compras: [compra(HASH_A)] });
  assert.equal(semInterno.classe, CLASSE.FORA_DO_ESCOPO);
  assert.equal(semInterno.motivo, MOTIVO.SEM_DOCUMENTO_INTERNO);
});

test('BFH-22 o relatorio nunca carrega o hash inteiro, so oito caracteres', () => {
  const c = classificar({ compras: [compra(HASH_A)] });
  assert.equal(c.rotuloHash, HASH_A.slice(0, 8));
  assert.equal(c.rotuloHash.length, 8);
});

// ===========================================================================
// VARREDURA — paginacao, retomada, dry-run
// ===========================================================================

/** Semeia um jogador completo no Firestore falso. */
function semearJogador(db, uid, { publico, interno, compras = [] } = {}) {
  if (publico !== null) {
    db.semear(`playerEntitlements/${uid}`, publico || publicoMigrado({ uid }));
  }
  if (interno !== null) {
    db.semear(
      `playerEntitlements/${uid}/interno/billing`,
      interno || internoMigrado({ uid })
    );
  }
  for (const c of compras) db.semear(`compras/${c.hash}`, c.dados);
  return db;
}

/** Hash historico deterministico e distinto por jogador. */
function hashDe(uid, sufixo = '') {
  return chaveDaCompra(`token-${uid}${sufixo}`);
}

/** N jogadores AUTO: migrado sem hash, com exatamente uma compra concedida. */
function semearAutos(db, n, prefixo = 'u') {
  for (let i = 0; i < n; i += 1) {
    // Zeros a esquerda para que a ordem por id seja a ordem numerica: sem isso
    // 'u10' viria antes de 'u2' e os testes de fronteira mediriam outra coisa.
    const uid = `${prefixo}${String(i).padStart(5, '0')}`;
    semearJogador(db, uid, {
      publico: publicoMigrado({ uid }),
      interno: internoMigrado({ uid }),
      compras: [compra(hashDe(uid), { uid })],
    });
  }
  return db;
}

function montar(db, { escrever = false, correlacionar = true } = {}) {
  const portas = criarPortasDeLeitura({ db, FieldPath: FieldPathFalso });
  const gravador = criarGravadorDeHash({ db, carimbo: () => CARIMBO });
  return criarBackfillHash({
    ...portas,
    lerComprasDoJogador: correlacionar ? portas.lerComprasDoJogador : null,
    gravarHash: escrever ? gravador.gravarHash : null,
    agora: () => '2026-08-15T12:00:00.000Z',
  });
}

test('BFH-23 dry-run classifica a base inteira e declara o que SERIA alterado', async () => {
  const db = semearAutos(new FirestoreFalso(), 7);
  const r = await montar(db).executar();

  assert.equal(r.modo, 'dry_run');
  assert.equal(r.examinados, 7);
  assert.equal(r.resumo.porClasse[CLASSE.AUTO], 7);
  assert.equal(r.seriamAlterados, 7);
  assert.equal(r.permaneceriamIntocados, 0);
  assert.equal(r.jaCorretos, 0);
  assert.equal(r.esgotou, true);
  assert.equal(r.cursor, null);
  assert.equal(r.parada, null);
});

test('BFH-24 o dry-run NAO escreve: o banco sai com a mesma versao documento a documento', async () => {
  const db = semearAutos(new FirestoreFalso(), 12);
  const antes = db.retrato();

  await montar(db).executar();

  // `caminhos()` sozinho nao provaria nada: reescrever um documento existente nao
  // cria caminho novo. A versao sobe a cada gravacao, entao dois retratos iguais
  // significam que nenhuma escrita aconteceu — inclusive as que sobrescrevem.
  assert.deepEqual(db.retrato(), antes);
  assert.equal(db.commits, 0);
});

test('BFH-25 a soma das classes fecha exatamente com os examinados', async () => {
  const db = new FirestoreFalso();
  semearAutos(db, 4, 'a');
  semearJogador(db, 'b1', { compras: [] }); // sem fonte
  semearJogador(db, 'b2', {
    interno: internoMigrado({ uid: 'b2', purchaseTokenHash: HASH_A }),
    compras: [compra(HASH_A, { uid: 'b2' })],
  }); // ja preenchido
  semearJogador(db, 'b3', {
    compras: [compra(hashDe('b3'), { uid: 'b3' }), compra(hashDe('b3', 'x'), { uid: 'b3' })],
  }); // ambiguo
  semearJogador(db, 'b4', { interno: null }); // fora do escopo

  const r = await montar(db).executar();
  const soma = Object.values(r.resumo.porClasse).reduce((a, b) => a + b, 0);

  assert.equal(r.examinados, 8);
  assert.equal(soma, 8);
  assert.equal(r.resumo.porClasse[CLASSE.AUTO], 4);
  assert.equal(r.resumo.porClasse[CLASSE.SEM_FONTE], 1);
  assert.equal(r.resumo.porClasse[CLASSE.JA_PREENCHIDO], 1);
  assert.equal(r.resumo.porClasse[CLASSE.AMBIGUO], 1);
  assert.equal(r.resumo.porClasse[CLASSE.FORA_DO_ESCOPO], 1);
  assert.equal(r.permaneceriamIntocados, 4);
});

for (const n of [0, 1, TAMANHO_PAGINA - 1, TAMANHO_PAGINA, TAMANHO_PAGINA + 1]) {
  test(`BFH-26 (${n} jogadores) a varredura visita TODOS e para por esgotamento`, async () => {
    const db = semearAutos(new FirestoreFalso(), n);
    const r = await montar(db).executar();
    assert.equal(r.examinados, n);
    assert.equal(r.resumo.porClasse[CLASSE.AUTO], n);
    assert.equal(r.esgotou, true);
  });
}

test('BFH-27 o resultado NAO depende do tamanho da pagina', async () => {
  const semear = () => semearAutos(new FirestoreFalso(), 53);
  const referencia = await montar(semear()).executar();

  for (const tamanho of [1, 2, 7, 53, 54, 500]) {
    const r = await montar(semear()).executar({ tamanhoPagina: tamanho });
    assert.equal(r.examinados, referencia.examinados, `tamanho ${tamanho}`);
    assert.deepEqual(r.resumo.porClasse, referencia.resumo.porClasse);
  }
});

test('BFH-28 o teto de paginas DEVOLVE cursor, e nao corta em silencio', async () => {
  const db = semearAutos(new FirestoreFalso(), 30);
  const r = await montar(db).executar({ tamanhoPagina: 10, maxPaginas: 2 });

  assert.equal(r.examinados, 20);
  assert.equal(r.esgotou, false);
  assert.equal(r.parada, PARADA.TETO_DE_PAGINAS);
  assert.equal(typeof r.cursor, 'string');
});

test('BFH-29 retomar pelo cursor termina a base, e a soma bate com a execucao inteira', async () => {
  const inteira = await montar(semearAutos(new FirestoreFalso(), 30)).executar();

  const db = semearAutos(new FirestoreFalso(), 30);
  const backfill = montar(db);
  const p1 = await backfill.executar({ tamanhoPagina: 10, maxPaginas: 2 });
  const p2 = await backfill.executar({
    tamanhoPagina: 10,
    cursorInicial: p1.cursor,
  });

  assert.equal(p2.esgotou, true);
  const soma = somarResumos(p1.resumo, p2.resumo);
  assert.equal(soma.examinados, inteira.resumo.examinados);
  assert.deepEqual(soma.porClasse, inteira.resumo.porClasse);
});

test('BFH-30 um jogador problematico nao impede que os seguintes sejam examinados', async () => {
  const db = semearAutos(new FirestoreFalso(), 5);
  const portas = criarPortasDeLeitura({ db, FieldPath: FieldPathFalso });
  const alvo = 'u00002';

  const backfill = criarBackfillHash({
    ...portas,
    lerComprasDoJogador: async (uid) => {
      if (uid === alvo) throw new Error('leitura de compras falhou');
      return portas.lerComprasDoJogador(uid);
    },
  });

  const r = await backfill.executar();
  assert.equal(r.examinados, 4);
  assert.equal(r.resumo.comFalha, 1);
  assert.equal(r.resumo.porClasse[CLASSE.AUTO], 4);
  assert.equal(r.esgotou, true);
});

test('BFH-31 sem correlacao de compras o modulo NAO conclui "sem fonte" para a base', async () => {
  const db = semearAutos(new FirestoreFalso(), 3);
  const r = await montar(db, { correlacionar: false }).executar();

  assert.equal(r.correlacionouCompras, false);
  assert.equal(r.resumo.porClasse[CLASSE.NAO_INVESTIGADO], 3);
  assert.equal(r.resumo.porClasse[CLASSE.SEM_FONTE], 0);
  assert.equal(r.seriamAlterados, 0);
});

// ===========================================================================
// ESCRITA — idempotencia, concorrencia, precondicao
// ===========================================================================

const CAMINHO_INTERNO = (uid) => `playerEntitlements/${uid}/interno/billing`;

test('BFH-32 o modo escrita preenche o hash historico, e so ele', async () => {
  const db = semearAutos(new FirestoreFalso(), 3);
  const r = await montar(db, { escrever: true }).executar();

  assert.equal(r.modo, 'escrita');
  assert.equal(r.resumo.escritas.aplicadas, 3);
  assert.equal(r.resumo.escritas.recusadas, 0);

  const interno = db.ver(CAMINHO_INTERNO('u00000'));
  assert.equal(interno.purchaseTokenHash, hashDe('u00000'));
  assert.equal(interno.purchaseTokenHashOrigem, ORIGEM_BACKFILL);
  // O resto do documento interno sobrevive: `set` sem merge apagaria tudo.
  assert.equal(interno.produtoId, 'vip_mensal');
  assert.equal(interno.fonte, 'migracao');
  assert.equal(interno.esquema, 1);
});

test('BFH-33 o documento PUBLICO nao e tocado: o jogador nao le nada diferente', async () => {
  const db = semearAutos(new FirestoreFalso(), 2);
  const antes = db.ver('playerEntitlements/u00000');
  const versaoAntes = db.retrato().filter((l) => l.startsWith('playerEntitlements/u00000@'));

  await montar(db, { escrever: true }).executar();

  assert.deepEqual(db.ver('playerEntitlements/u00000'), antes);
  assert.deepEqual(
    db.retrato().filter((l) => l.startsWith('playerEntitlements/u00000@')),
    versaoAntes
  );
});

test('BFH-34 a segunda execucao nao altera nada: o banco sai identico', async () => {
  const db = semearAutos(new FirestoreFalso(), 6);
  const backfill = montar(db, { escrever: true });

  const primeira = await backfill.executar();
  const retratoDepoisDaPrimeira = db.retrato();

  const segunda = await backfill.executar();

  assert.equal(primeira.resumo.escritas.aplicadas, 6);
  assert.equal(segunda.resumo.escritas.aplicadas, 0);
  assert.equal(segunda.resumo.porClasse[CLASSE.AUTO], 0);
  assert.equal(segunda.resumo.porClasse[CLASSE.JA_PREENCHIDO], 6);
  assert.deepEqual(db.retrato(), retratoDepoisDaPrimeira);
});

test('BFH-35 tres execucoes seguidas mantem o resultado exato', async () => {
  const db = semearAutos(new FirestoreFalso(), 4);
  const backfill = montar(db, { escrever: true });
  await backfill.executar();
  const retrato = db.retrato();
  await backfill.executar();
  await backfill.executar();
  assert.deepEqual(db.retrato(), retrato);
});

test('BFH-36 interrupcao no meio e nova execucao terminam sem duplicar nem pular', async () => {
  const db = semearAutos(new FirestoreFalso(), 25);
  const backfill = montar(db, { escrever: true });

  const p1 = await backfill.executar({ tamanhoPagina: 5, maxPaginas: 2 });
  assert.equal(p1.esgotou, false);
  assert.equal(p1.resumo.escritas.aplicadas, 10);

  const p2 = await backfill.executar({ cursorInicial: p1.cursor });
  assert.equal(p2.esgotou, true);
  assert.equal(p2.resumo.escritas.aplicadas, 15);

  for (let i = 0; i < 25; i += 1) {
    const uid = `u${String(i).padStart(5, '0')}`;
    assert.equal(db.ver(CAMINHO_INTERNO(uid)).purchaseTokenHash, hashDe(uid));
  }
});

test('BFH-37 o teto de escritas para a varredura e devolve o ponto exato de retomada', async () => {
  const db = semearAutos(new FirestoreFalso(), 20);
  const backfill = montar(db, { escrever: true });

  const piloto = await backfill.executar({ maxEscritas: 3 });
  assert.equal(piloto.resumo.escritas.aplicadas, 3);
  assert.equal(piloto.esgotou, false);
  assert.equal(piloto.parada, PARADA.TETO_DE_ESCRITAS);

  // O documento que NAO foi gravado por causa do teto tem que voltar na retomada.
  const resto = await backfill.executar({ cursorInicial: piloto.cursor });
  assert.equal(resto.resumo.escritas.aplicadas, 17);
  for (let i = 0; i < 20; i += 1) {
    const uid = `u${String(i).padStart(5, '0')}`;
    assert.ok(db.ver(CAMINHO_INTERNO(uid)).purchaseTokenHash, `${uid} ficou sem hash`);
  }
});

test('BFH-38 um hash ja gravado NUNCA e sobrescrito, nem por outro valor', async () => {
  const db = new FirestoreFalso();
  semearJogador(db, 'u1', {
    interno: internoMigrado({ uid: 'u1', purchaseTokenHash: HASH_B }),
    compras: [compra(HASH_A)],
  });

  const r = await montar(db, { escrever: true }).executar();

  assert.equal(r.resumo.porClasse[CLASSE.CONFLITO], 1);
  assert.equal(r.resumo.escritas.tentadas, 0);
  assert.equal(db.ver(CAMINHO_INTERNO('u1')).purchaseTokenHash, HASH_B);
});

test('BFH-39 o gravador recusa sozinho quando a precondicao nao vale mais', async () => {
  const db = new FirestoreFalso();
  const { gravarHash } = criarGravadorDeHash({ db, carimbo: () => CARIMBO });

  // sem entitlement
  assert.equal(
    (await gravarHash({ uid: 'x', hash: HASH_A })).motivo,
    RECUSA.ENTITLEMENT_AUSENTE
  );

  // sem documento interno
  db.semear('playerEntitlements/x', publicoMigrado({ uid: 'x' }));
  assert.equal(
    (await gravarHash({ uid: 'x', hash: HASH_A })).motivo,
    RECUSA.INTERNO_AUSENTE
  );

  // sem o registro de compra
  db.semear(CAMINHO_INTERNO('x'), internoMigrado({ uid: 'x' }));
  assert.equal(
    (await gravarHash({ uid: 'x', hash: HASH_A })).motivo,
    RECUSA.COMPRA_AUSENTE
  );

  // compra de outro titular
  db.semear(`compras/${HASH_A}`, compra(HASH_A, { uid: 'outro' }).dados);
  assert.equal(
    (await gravarHash({ uid: 'x', hash: HASH_A })).motivo,
    RECUSA.COMPRA_DE_OUTRO_TITULAR
  );

  // compra que nao foi concedida
  db.semear(
    `compras/${HASH_A}`,
    compra(HASH_A, { uid: 'x', estado: ESTADO_COMPRA.EM_VALIDACAO }).dados
  );
  assert.equal(
    (await gravarHash({ uid: 'x', hash: HASH_A })).motivo,
    RECUSA.COMPRA_NAO_CONCEDIDA
  );

  // hash fora de formato
  assert.equal(
    (await gravarHash({ uid: 'x', hash: 'lixo' })).motivo,
    RECUSA.ENTRADA_INVALIDA
  );

  // e agora, com tudo no lugar
  db.semear(`compras/${HASH_A}`, compra(HASH_A, { uid: 'x' }).dados);
  const ok = await gravarHash({ uid: 'x', hash: HASH_A });
  assert.equal(ok.aplicado, true);
  assert.equal(ok.motivo, APLICADO);
});

test('BFH-40 duas execucoes concorrentes nao corrompem: uma grava, a outra recusa', async () => {
  const db = new FirestoreFalso();
  semearJogador(db, 'u1', { compras: [compra(HASH_A)] });
  const { gravarHash } = criarGravadorDeHash({ db, carimbo: () => CARIMBO });

  let liberada = null;
  const espera = new Promise((r) => {
    liberada = r;
  });

  // A primeira transacao le, e SEGURA antes do commit. A segunda roda inteira
  // nesse meio-tempo. Sem o ponto de interleaving controlado, um teste de
  // concorrencia vira sorteio, e teste que passa por sorteio nao prova nada.
  let primeiraVez = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeiraVez) return;
    primeiraVez = false;
    await espera;
  };

  const a = gravarHash({ uid: 'u1', hash: HASH_A });
  await new Promise((r) => setImmediate(r));

  db.pausarAntesDoCommit = null;
  const b = await gravarHash({ uid: 'u1', hash: HASH_A });
  liberada();
  const ra = await a;

  const aplicadas = [ra, b].filter((r) => r.aplicado).length;
  assert.equal(aplicadas, 1, 'exatamente uma das duas grava');
  assert.equal(
    [ra, b].find((r) => !r.aplicado).motivo,
    RECUSA.JA_PREENCHIDO
  );
  assert.equal(db.ver(CAMINHO_INTERNO('u1')).purchaseTokenHash, HASH_A);
  assert.ok(db.conflitos >= 1, 'houve contencao de verdade');
});

test('BFH-41 uma compra validada no meio do caminho vence o backfill, e nao e sobrescrita', async () => {
  const db = new FirestoreFalso();
  semearJogador(db, 'u1', { compras: [compra(HASH_A)] });
  const { gravarHash } = criarGravadorDeHash({ db, carimbo: () => CARIMBO });

  // Entre a leitura e o commit do backfill, `validarCompraPlay` grava o hash da
  // compra NOVA. A transacao do backfill e descartada por contencao, roda de novo
  // contra o estado novo, e encontra o campo preenchido.
  let primeiraVez = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeiraVez) return;
    primeiraVez = false;
    db.semear(CAMINHO_INTERNO('u1'), {
      ...internoMigrado({ uid: 'u1' }),
      purchaseTokenHash: HASH_B,
      purchaseToken: TOKEN_B,
    });
  };

  const r = await gravarHash({ uid: 'u1', hash: HASH_A });
  assert.equal(r.aplicado, false);
  assert.equal(r.motivo, RECUSA.CONFLITO_NO_COMMIT);
  assert.equal(db.ver(CAMINHO_INTERNO('u1')).purchaseTokenHash, HASH_B);
});

test('BFH-42 falha no commit nao deixa escrita parcial: ou grava tudo, ou nada', async () => {
  const db = new FirestoreFalso();
  semearJogador(db, 'u1', { compras: [compra(HASH_A)] });
  const antes = db.retrato();

  const { gravarHash } = criarGravadorDeHash({
    db,
    carimbo: () => {
      throw new Error('carimbo indisponivel');
    },
  });

  await assert.rejects(() => gravarHash({ uid: 'u1', hash: HASH_A }));
  assert.deepEqual(db.retrato(), antes);
});

// ===========================================================================
// PROVAS ESTRUTURAIS
// ===========================================================================

test('BFH-43 o fonte do classificador nao contem nenhuma API de escrita', () => {
  const fonte = fs.readFileSync(
    path.join(__dirname, '..', 'backfillHash.js'),
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
      `\`${proibido}\` apareceu em backfillHash.js: a garantia de dry-run e ESTRUTURAL`
    );
  }
});

test('BFH-44 dry-run e escrita concordam classe a classe: ha UM classificador', async () => {
  const cenario = (db) => {
    semearAutos(db, 3, 'a');
    semearJogador(db, 'b1', { compras: [] });
    semearJogador(db, 'b2', {
      interno: internoMigrado({ uid: 'b2', purchaseTokenHash: HASH_A }),
      compras: [compra(HASH_A, { uid: 'b2' })],
    });
    semearJogador(db, 'b3', {
      compras: [compra(hashDe('b3'), { uid: 'b3' }), compra(hashDe('b3', 'x'), { uid: 'b3' })],
    });
    semearJogador(db, 'b4', {
      interno: internoMigrado({ uid: 'b4', purchaseTokenHash: HASH_B }),
      compras: [compra(HASH_A, { uid: 'b4' })],
    });
    return db;
  };

  const seco = await montar(cenario(new FirestoreFalso())).executar();
  const molhado = await montar(cenario(new FirestoreFalso()), {
    escrever: true,
  }).executar();

  assert.deepEqual(molhado.resumo.porClasse, seco.resumo.porClasse);
  assert.deepEqual(molhado.resumo.porMotivo, seco.resumo.porMotivo);
  // E o que o dry-run prometeu alterar e exatamente o que a escrita alterou.
  assert.equal(molhado.resumo.escritas.aplicadas, seco.seriamAlterados);
});

test('BFH-46 o dry-run mede quantos AUTO ficariam mesmo assim SEM ficha mensal', async () => {
  // O hash e necessario e nao suficiente: `concederFichasMensais` tambem precisa
  // de `planoBase` e `inicioEm`, e o direito MIGRADO nasce sem os dois (IMP-33).
  // Um relatorio que so dissesse "N seriam preenchidos" seria lido como "N voltam
  // a receber", e a diferenca entre as duas frases e a decisao inteira.
  const db = new FirestoreFalso();
  semearAutos(db, 3, 'm'); // migrados: sem planoBase, sem inicioEm
  semearJogador(db, 'p1', {
    publico: publicoMigrado({
      uid: 'p1',
      origem: 'play',
      planoBase: 'mensal',
      inicioEm: '2026-01-01T00:00:00.000Z',
    }),
    interno: internoMigrado({ uid: 'p1' }),
    compras: [compra(hashDe('p1'), { uid: 'p1' })],
  });

  const r = await montar(db).executar();

  assert.equal(r.seriamAlterados, 4);
  assert.equal(r.resumo.autoAptoAFicha, 1);
  assert.equal(r.resumo.autoSemPlanoOuInicio, 3);
  assert.equal(
    r.resumo.autoAptoAFicha + r.resumo.autoSemPlanoOuInicio,
    r.seriamAlterados
  );
});

test('BFH-47 o resumo zerado tem todas as chaves, e somar dois resumos preserva o total', () => {
  const z = resumoZerado();
  for (const classe of Object.values(CLASSE)) {
    assert.equal(z.porClasse[classe], 0, `classe ${classe} ausente do resumo`);
  }
  for (const motivo of Object.values(MOTIVO)) {
    assert.equal(z.porMotivo[motivo], 0, `motivo ${motivo} ausente do resumo`);
  }

  const a = resumoZerado();
  a.examinados = 2;
  a.porClasse[CLASSE.AUTO] = 2;
  a.escritas.aplicadas = 2;
  a.escritas.porMotivo[APLICADO] = 2;
  const b = resumoZerado();
  b.examinados = 3;
  b.porClasse[CLASSE.SEM_FONTE] = 3;

  const soma = somarResumos(a, b);
  assert.equal(soma.examinados, 5);
  assert.equal(soma.porClasse[CLASSE.AUTO], 2);
  assert.equal(soma.porClasse[CLASSE.SEM_FONTE], 3);
  assert.equal(soma.escritas.porMotivo[APLICADO], 2);
});
