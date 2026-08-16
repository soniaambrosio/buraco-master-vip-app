/**
 * diagnosticoLegado.test.js — a projecao da migracao, conferida caso a caso.
 *
 * O QUE ESTES TESTES PRECISAM PROVAR
 *
 * Um diagnostico erra de dois jeitos, e os dois sao caros. Se ele SUBESTIMA o
 * estrago, a migracao roda com aval e derruba pagante. Se ele SUPERESTIMA, a
 * ativacao comercial fica parada por um numero que ninguem conferiu.
 *
 * Por isso a bateria nao se contenta em exercitar as categorias: ela amarra cada
 * projecao a regra REAL que a migracao usa. `DL-05` e `DL-06` sao os dois casos
 * em que o jogador termina pior do que comecou, e existem separados justamente
 * porque o retorno da migracao de verdade nao os distingue.
 *
 * E `DL-13` prova a garantia estrutural da OS: nenhuma porta de escrita chega ao
 * diagnostico, entao nao existe caminho — nem com argumento errado — que faca a
 * varredura gravar.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  CATEGORIA,
  ALERTA,
  ACAO_DA_MIGRACAO,
  classificarJogador,
  criarDiagnosticoLegado,
} = require('../diagnosticoLegado');

const AGORA = '2026-08-14T12:00:00.000Z';
const FUTURO = '2026-09-20T12:00:00.000Z';
const PASSADO = '2026-07-01T12:00:00.000Z';

function classificar(legado, { publico = null, interno = null, uid = 'u1' } = {}) {
  return classificarJogador({ uid, legado, publico, interno, agora: AGORA });
}

// ---------------------------------------------------------------------------
// Classificacao
// ---------------------------------------------------------------------------

test('DL-01 documento sem `vip: true` fica fora da populacao', () => {
  for (const legado of [{}, { vip: false }, { vip: 'true' }, { fichas: 900 }]) {
    const c = classificar(legado);
    assert.equal(c.categoria, CATEGORIA.FORA_DA_POPULACAO);
    assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_FORA_DA_POPULACAO);
    assert.deepEqual(c.alertas, []);
  }
});

test('DL-02 vip com prazo no futuro e migravel e a migracao concede', () => {
  const c = classificar({ vip: true, vipExpiraEm: FUTURO, vipProdutoId: 'vip_mensal' });
  assert.equal(c.categoria, CATEGORIA.MIGRAVEL_VIGENTE);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.GRAVAR_ATIVO);
  assert.equal(c.vipAtivoProjetado, true);
  assert.equal(c.expiraEmLegado, FUTURO);
});

test('DL-03 entitlement vindo da Play nao e tocado pela migracao', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    {
      publico: { origem: 'play', estado: 'ativo', vipAtivo: true, expiraEm: FUTURO },
      interno: { purchaseTokenHash: 'abc123' },
    }
  );
  assert.equal(c.categoria, CATEGORIA.JA_COBERTO_PELA_PLAY);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE);
  // Tem token: nem perde ficha, nem perde reconsulta.
  assert.deepEqual(c.alertas, []);
});

test('DL-04 entitlement ja migrado e reconhecido como tal, e nao como cobertura da Play', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    {
      publico: {
        origem: 'legado_usuarios',
        estado: 'ativo',
        vipAtivo: true,
        expiraEm: FUTURO,
      },
      interno: { purchaseTokenHash: null },
    }
  );
  assert.equal(c.categoria, CATEGORIA.JA_MIGRADO);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE);
  // Rodar a migracao de novo nao conserta a falta de token: ela nao sobrescreve.
  assert.ok(c.alertas.includes(ALERTA.SEM_RECONSULTA_POSSIVEL));
  assert.ok(c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
});

test('DL-05 vip com prazo VENCIDO entra como expirado e pode ser pagante rebaixado', () => {
  const c = classificar({ vip: true, vipExpiraEm: PASSADO });
  assert.equal(c.categoria, CATEGORIA.MIGRAVEL_VENCIDO);
  assert.equal(c.acao, ACAO_DA_MIGRACAO.GRAVAR_EXPIRADO);
  assert.equal(c.vipAtivoProjetado, false);
  // O ponto do caso: sem token, renovado e cancelado sao indistinguiveis.
  assert.ok(c.alertas.includes(ALERTA.POSSIVEL_PAGANTE_REBAIXADO));
});

test('DL-06 vip SEM prazo e pulado pela migracao e some sem deixar registro', () => {
  for (const legado of [
    { vip: true },
    { vip: true, vipExpiraEm: null },
    { vip: true, vipExpiraEm: '' },
    { vip: true, vipExpiraEm: 'nao-e-data' },
  ]) {
    const c = classificar(legado);
    assert.equal(c.categoria, CATEGORIA.BLOQUEADO_SEM_PRAZO);
    assert.equal(c.acao, ACAO_DA_MIGRACAO.PULAR_SEM_PRAZO);
    assert.ok(c.alertas.includes(ALERTA.SUMICO_SILENCIOSO));
  }
});

test('DL-07 migrado vigente nao recebe ficha mensal, e o diagnostico diz isso', () => {
  // `concederFichasMensais` exige `purchaseTokenHash` para ter livro-razao
  // idempotente; o migrado nasce sem hash e cai no ramo `semPlano`.
  const c = classificar({ vip: true, vipExpiraEm: FUTURO });
  assert.ok(c.alertas.includes(ALERTA.SEM_FICHA_MENSAL));
  assert.ok(c.alertas.includes(ALERTA.SEM_RECONSULTA_POSSIVEL));
});

test('DL-08 legado prometendo prazo maior que o entitlement vira divergencia, nao migracao', () => {
  const c = classificar(
    { vip: true, vipExpiraEm: FUTURO },
    {
      publico: {
        origem: 'play',
        estado: 'ativo',
        vipAtivo: true,
        expiraEm: '2026-08-20T12:00:00.000Z', // antes de FUTURO
      },
      interno: { purchaseTokenHash: 'abc123' },
    }
  );
  assert.ok(c.alertas.includes(ALERTA.DIVERGENCIA_DE_PRAZO));
  // Continua sem migrar: quem resolve divergencia e a reconsulta, nao o legado.
  assert.equal(c.acao, ACAO_DA_MIGRACAO.NADA_LEGADO_NAO_SOBRESCREVE);
});

test('DL-09 prazo do legado ja vencido nao vira divergencia', () => {
  // Um legado vencido contando menos que o entitlement e o estado NORMAL depois
  // de uma renovacao. Alertar aqui afogaria o alerta real em ruido.
  const c = classificar(
    { vip: true, vipExpiraEm: PASSADO },
    {
      publico: { origem: 'play', estado: 'ativo', vipAtivo: true, expiraEm: FUTURO },
      interno: { purchaseTokenHash: 'abc123' },
    }
  );
  assert.ok(!c.alertas.includes(ALERTA.DIVERGENCIA_DE_PRAZO));
});

test('DL-10 toda classificacao cai em exatamente uma categoria conhecida', () => {
  const conhecidas = new Set(Object.values(CATEGORIA));
  const casos = [
    {},
    { vip: false },
    { vip: true },
    { vip: true, vipExpiraEm: FUTURO },
    { vip: true, vipExpiraEm: PASSADO },
  ];
  for (const legado of casos) {
    assert.ok(conhecidas.has(classificar(legado).categoria));
  }
});

// ---------------------------------------------------------------------------
// Varredura
// ---------------------------------------------------------------------------

/** Portas de leitura, sobre um mapa em memoria. Nenhuma delas escreve. */
function portas(usuarios, entitlements = {}) {
  const lidos = [];
  return {
    lidos,
    lerPaginaLegado: async ({ cursor, lote }) => {
      const uids = Object.keys(usuarios).sort();
      const inicio = cursor ? uids.indexOf(cursor) + 1 : 0;
      const fatia = uids.slice(inicio, inicio + lote);
      return {
        docs: fatia.map((uid) => ({ uid, dados: usuarios[uid] })),
        fim: inicio + lote >= uids.length,
      };
    },
    lerEntitlement: async (uid) => {
      lidos.push(uid);
      return entitlements[uid] || { publico: null, interno: null };
    },
    agora: () => AGORA,
  };
}

test('DL-11 a varredura soma por categoria e as contagens fecham com os examinados', async () => {
  const diag = criarDiagnosticoLegado(
    portas(
      {
        a: { vip: true, vipExpiraEm: FUTURO },
        b: { vip: true, vipExpiraEm: PASSADO },
        c: { vip: true },
        d: { vip: false },
        e: { vip: true, vipExpiraEm: FUTURO },
      },
      {
        e: {
          publico: { origem: 'play', estado: 'ativo', vipAtivo: true, expiraEm: FUTURO },
          interno: { purchaseTokenHash: 'h' },
        },
      }
    )
  );

  const r = await diag.varrer({ lote: 10 });

  assert.equal(r.examinados, 5);
  assert.equal(r.porCategoria[CATEGORIA.MIGRAVEL_VIGENTE], 1);
  assert.equal(r.porCategoria[CATEGORIA.MIGRAVEL_VENCIDO], 1);
  assert.equal(r.porCategoria[CATEGORIA.BLOQUEADO_SEM_PRAZO], 1);
  assert.equal(r.porCategoria[CATEGORIA.FORA_DA_POPULACAO], 1);
  assert.equal(r.porCategoria[CATEGORIA.JA_COBERTO_PELA_PLAY], 1);

  const soma = Object.values(r.porCategoria).reduce((s, n) => s + n, 0);
  assert.equal(soma, r.examinados);

  assert.equal(r.porAlerta[ALERTA.POSSIVEL_PAGANTE_REBAIXADO], 1);
  assert.equal(r.porAlerta[ALERTA.SUMICO_SILENCIOSO], 1);
  assert.equal(r.cursor, null); // pagina incompleta: acabou
});

test('DL-12 o cursor pagina a base inteira sem repetir nem perder documento', async () => {
  const usuarios = {};
  for (let i = 0; i < 7; i += 1) {
    usuarios[`u${i}`] = { vip: true, vipExpiraEm: FUTURO };
  }
  const diag = criarDiagnosticoLegado(portas(usuarios));

  let cursor = null;
  let total = 0;
  let voltas = 0;
  do {
    const r = await diag.varrer({ cursor, lote: 3 });
    total += r.examinados;
    cursor = r.cursor;
    voltas += 1;
    assert.ok(voltas < 10, 'a paginacao nao pode girar sem fim');
  } while (cursor);

  assert.equal(total, 7);
});

test('DL-13 a varredura nao tem como escrever: nao ha porta de escrita', async () => {
  // A garantia da OS ("sem qualquer escrita em producao") e estrutural, e este
  // teste a exercita como contrato: o diagnostico e construido SO com as duas
  // portas de leitura. Se alguem acrescentar uma escrita ao modulo, ela nao tera
  // por onde sair — e este teste quebra na construcao, nao em uma assercao.
  const usuarios = { a: { vip: true, vipExpiraEm: FUTURO } };
  const p = portas(usuarios);

  const diag = criarDiagnosticoLegado({
    lerPaginaLegado: p.lerPaginaLegado,
    lerEntitlement: p.lerEntitlement,
    agora: p.agora,
  });

  const congelado = Object.freeze({ ...usuarios.a });
  usuarios.a = congelado;

  const r = await diag.varrer({ lote: 10 });

  assert.equal(r.examinados, 1);
  // O documento de origem sai da varredura identico ao que entrou.
  assert.deepEqual(usuarios.a, { vip: true, vipExpiraEm: FUTURO });
  assert.deepEqual(Object.keys(diag), ['varrer']);
});

test('DL-14 amostras trazem casos concretos, limitadas por categoria', async () => {
  const usuarios = {};
  for (let i = 0; i < 6; i += 1) usuarios[`u${i}`] = { vip: true };
  const diag = criarDiagnosticoLegado(portas(usuarios));

  const r = await diag.varrer({ lote: 10, amostrasPorCategoria: 2 });

  assert.equal(r.porCategoria[CATEGORIA.BLOQUEADO_SEM_PRAZO], 6);
  assert.equal(r.amostras[CATEGORIA.BLOQUEADO_SEM_PRAZO].length, 2);
  assert.ok(r.amostras[CATEGORIA.BLOQUEADO_SEM_PRAZO][0].uid);
});
