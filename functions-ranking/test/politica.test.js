/**
 * Prova que a AUSENCIA de formula e um estado bem definido, e nao um buraco.
 *
 * O QUE ESTA SUITE PROTEGE (secoes 7 e 31 da OS): o dia em que alguem, com a
 * melhor das intencoes, registrar uma formula "provisoria" para "destravar os
 * testes". O ledger e permanente: uma pontuacao inventada gravada uma vez fica
 * no historico do jogador para sempre, e a unica forma de tira-la e um estorno
 * que tambem fica no historico.
 *
 * Sem emulador, sem Firestore, sem relogio.
 */

const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

const {
  POLITICA_PENDENTE,
  politicaDefinida,
  politicaDeJson,
  politicaComoTexto,
  registrarCalculadora,
  calculadoraDe,
  politicasRegistradas,
  esquecerCalculadora,
} = require("../lib/politica");

const POLITICA_DE_TESTE = { id: "somente-para-teste", versao: 1 };

describe("politica: o registro sai vazio de fabrica", () => {
  beforeEach(() => esquecerCalculadora(POLITICA_DE_TESTE));

  test("nenhuma calculadora vem registrada", () => {
    // A AFIRMACAO CENTRAL DESTA OS. Se este teste falhar, alguem registrou uma
    // formula em producao — e a pergunta a fazer nao e "como conserto o teste",
    // e sim "quem decidiu quanto vale uma vitoria".
    assert.deepEqual(politicasRegistradas(), []);
  });

  test("a politica pendente nao tem calculadora", () => {
    assert.equal(calculadoraDe(POLITICA_PENDENTE), null);
  });

  test("uma politica qualquer, nao registrada, tambem nao tem", () => {
    assert.equal(calculadoraDe({ id: "temporada-2026-v1", versao: 1 }), null);
  });

  test("nao se registra calculadora para a politica pendente", () => {
    // Sem esta guarda, registrar sob `nao_definida` faria TODA temporada que
    // ainda nao escolheu politica passar a pontuar por ela — a pendencia viraria
    // regra sem ninguem decidir.
    assert.throws(
      () => registrarCalculadora(POLITICA_PENDENTE, () => 0),
      /nao se registra calculadora para a politica pendente/
    );
    assert.deepEqual(politicasRegistradas(), []);
  });
});

describe("politica: o seam funciona quando a regra existir", () => {
  beforeEach(() => esquecerCalculadora(POLITICA_DE_TESTE));

  test("registrar e recuperar", () => {
    registrarCalculadora(POLITICA_DE_TESTE, () => 7);
    const calc = calculadoraDe(POLITICA_DE_TESTE);
    assert.notEqual(calc, null);
    assert.equal(calc({ userId: "u", saldoAtual: 0 }), 7);
    esquecerCalculadora(POLITICA_DE_TESTE);
  });

  test("a versao faz parte da identidade", () => {
    registrarCalculadora({ id: "p", versao: 1 }, () => 1);
    // Versao 2 e OUTRA politica: sem isso, mudar a formula reescreveria o
    // significado dos lancamentos antigos, que e exatamente o que o campo
    // `politica` do ledger existe para impedir.
    assert.equal(calculadoraDe({ id: "p", versao: 2 }), null);
    esquecerCalculadora({ id: "p", versao: 1 });
  });
});

describe("politica: leitura e identidade", () => {
  test("definida distingue a pendente de qualquer outra", () => {
    assert.equal(politicaDefinida(POLITICA_PENDENTE), false);
    assert.equal(politicaDefinida({ id: "nao_definida", versao: 0 }), false);
    assert.equal(politicaDefinida({ id: "nao_definida", versao: 1 }), true);
    assert.equal(politicaDefinida({ id: "temporada-2026-v1", versao: 1 }), true);
  });

  test("o id da pendente e o mesmo texto do dominio Dart", () => {
    // `PoliticaDeRanking.pendente` em app/lib/rastreabilidade/ledger_competitivo.dart
    // usa exatamente 'nao_definida' e versao 0. Os dois lados gravam no mesmo
    // documento; divergir aqui faria uma temporada criada por um lado parecer
    // definida para o outro.
    assert.equal(POLITICA_PENDENTE.id, "nao_definida");
    assert.equal(POLITICA_PENDENTE.versao, 0);
  });

  test("lixo vira pendente em vez de estourar", () => {
    assert.deepEqual(politicaDeJson(null), POLITICA_PENDENTE);
    assert.deepEqual(politicaDeJson("texto"), POLITICA_PENDENTE);
    assert.deepEqual(politicaDeJson({}), POLITICA_PENDENTE);
    assert.deepEqual(politicaDeJson({ id: "p" }), { id: "p", versao: 0 });
    assert.deepEqual(politicaDeJson({ id: "p", versao: 2.5 }), { id: "p", versao: 0 });
  });

  test("o texto da politica e estavel", () => {
    assert.equal(politicaComoTexto({ id: "temporada-2026-v1", versao: 3 }), "temporada-2026-v1@v3");
  });
});
