/**
 * diario.test.js — CHAMADA DUPLICADA, RETOMADA E FALHA PARCIAL.
 *
 * OS de Exclusao de Conta e Dados do Jogador v1.
 *
 * Sao os tres casos da OS que NAO dependem de banco: o que muda entre eles e o
 * que o diario dizia quando a chamada chegou. Por isso a decisao e pura e mora
 * em `diario.ts` — provar "a segunda chamada converge" contra o emulador exigiria
 * encenar concorrencia real para afirmar uma regra que cabe numa funcao.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  ACAO,
  ESTADO_EXCLUSAO,
  comEtapaConcluida,
  decidirExecucao,
  estadoFinal,
  fundirResumo,
} = require("../lib/diario");

const TODAS = ["trancar", "social", "encerrar"];

describe("chamada duplicada", () => {
  test("sem diario, comeca do zero", () => {
    const d = decidirExecucao(null);
    assert.equal(d.acao, ACAO.COMECAR);
    assert.deepEqual(d.concluidas, []);
  });

  test("diario concluido faz a segunda chamada CONVERGIR, e nao refazer", () => {
    const d = decidirExecucao({
      estado: ESTADO_EXCLUSAO.CONCLUIDA,
      etapasConcluidas: TODAS,
    });
    assert.equal(d.acao, ACAO.CONVERGIR);
  });

  test("duplo toque com execucao em voo RETOMA, e nao recusa", () => {
    // Recusar aqui trancaria a conta num limbo: uma instancia que morre no meio
    // deixa `emAndamento` para sempre, e um erro "ja em andamento" nunca sairia.
    const d = decidirExecucao({
      estado: ESTADO_EXCLUSAO.EM_ANDAMENTO,
      etapasConcluidas: ["trancar"],
    });
    assert.equal(d.acao, ACAO.RETOMAR);
    assert.deepEqual(d.concluidas, ["trancar"]);
  });

  test("diario parcial retoma", () => {
    const d = decidirExecucao({
      estado: ESTADO_EXCLUSAO.PARCIAL,
      etapasConcluidas: ["trancar", "social"],
    });
    assert.equal(d.acao, ACAO.RETOMAR);
    assert.equal(d.concluidas.length, 2);
  });

  test("lista de etapas corrompida nao derruba a decisao", () => {
    // Um documento gravado por fora, ou por uma versao anterior, nao pode
    // impedir a conta de ser excluida.
    for (const lixo of [undefined, null, "trancar", 7, { a: 1 }]) {
      const d = decidirExecucao({ estado: ESTADO_EXCLUSAO.PARCIAL, etapasConcluidas: lixo });
      assert.deepEqual(d.concluidas, [], JSON.stringify(lixo));
    }
  });

  test("etapas nao-string sao descartadas, as validas ficam", () => {
    const d = decidirExecucao({
      estado: ESTADO_EXCLUSAO.PARCIAL,
      etapasConcluidas: ["trancar", 3, null, "social"],
    });
    assert.deepEqual(d.concluidas, ["trancar", "social"]);
  });
});

describe("registro de progresso", () => {
  test("etapa nova entra no fim", () => {
    assert.deepEqual(comEtapaConcluida(["trancar"], "social"), ["trancar", "social"]);
  });

  test("etapa repetida nao duplica", () => {
    // Sem isto, uma conta retomada muitas vezes faria o diario crescer sem
    // limite ate estourar o tamanho de documento do Firestore.
    assert.deepEqual(comEtapaConcluida(["trancar"], "trancar"), ["trancar"]);
  });
});

describe("estado final", () => {
  test("todas as etapas concluidas = concluida", () => {
    assert.equal(estadoFinal(TODAS, TODAS, false), ESTADO_EXCLUSAO.CONCLUIDA);
  });

  test("faltando etapa, com falha = parcial", () => {
    assert.equal(estadoFinal(["trancar"], TODAS, true), ESTADO_EXCLUSAO.PARCIAL);
  });

  test("faltando etapa, sem falha = em andamento", () => {
    // Acontece quando a instancia e reciclada sem lancar erro: nao houve falha a
    // registrar, e mesmo assim ficou trabalho.
    assert.equal(estadoFinal(["trancar"], TODAS, false), ESTADO_EXCLUSAO.EM_ANDAMENTO);
  });

  test("falha antiga nao deixa a conta parcial para sempre", () => {
    // A retomada concluiu o que faltava. O historico da falha continua em
    // `falhas`, que e o lugar dele — o ESTADO reflete o presente.
    assert.equal(estadoFinal(TODAS, TODAS, true), ESTADO_EXCLUSAO.CONCLUIDA);
  });

  test("nenhuma etapa concluida ainda nao e concluida", () => {
    assert.notEqual(estadoFinal([], TODAS, false), ESTADO_EXCLUSAO.CONCLUIDA);
  });
});

describe("resumo do encerramento", () => {
  test("o valor novo entra", () => {
    const r = fundirResumo(undefined, { fichas: 120 });
    assert.equal(r.fichas, 120);
  });

  test("a retomada NAO apaga o que a execucao anterior mediu", () => {
    // O saldo foi lido pela etapa que ja rodou; a carteira ja nao existe e a
    // retomada mediria `null`. Sobrescrever perderia o unico registro do saldo —
    // que e justamente o dado de que o suporte vai precisar num estorno.
    const r = fundirResumo({ fichas: 120, vipAtivo: true }, { amizades: 3 });
    assert.equal(r.fichas, 120);
    assert.equal(r.vipAtivo, true);
    assert.equal(r.amizades, 3);
  });

  test("zero e falso NAO sao tratados como ausencia", () => {
    // Saldo zero e um fato; VIP inativo tambem. Um `||` distraido os perderia.
    const r = fundirResumo({ fichas: 500, vipAtivo: true }, { fichas: 0, vipAtivo: false });
    assert.equal(r.fichas, 0);
    assert.equal(r.vipAtivo, false);
  });

  test("o que ninguem mediu fica nulo, e nao indefinido", () => {
    // `undefined` nao pode ir para o Firestore; `null` vai.
    const r = fundirResumo(undefined, {});
    for (const chave of Object.keys(r)) {
      assert.equal(r[chave], null, chave);
    }
  });
});
