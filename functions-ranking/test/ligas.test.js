/**
 * Prova a Liga como propriedade derivada de uma escada PARAMETRIZADA.
 *
 * Cobre a secao 23 ("Liga"): limite inferior, limite superior, mudanca de faixa
 * e ausencia de configuracao invalida.
 *
 * O QUE ESTA SUITE NAO FAZ, e isso e o ponto: ela nao afirma que Bronze vai de 0
 * a 999. Nenhum teste aqui conhece o nome de uma liga do jogo. As escadas usadas
 * sao inventadas PARA O TESTE, e e por isso que elas podem ser inventadas — a do
 * produto nao existe, e forjar uma aqui a tornaria real por tabela.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  SEM_ESCADA,
  escadaDefinida,
  conferirEscada,
  ligaDe,
  escadaParaExibicao,
  escadaDeJson,
} = require("../lib/ligas");

const degrau = (ligaId, min, max) => ({
  ligaId,
  nome: ligaId.toUpperCase(),
  icone: `assets/teste/${ligaId}.webp`,
  pontosMinimos: min,
  pontosMaximos: max,
});

// Escada de TESTE. Tres faixas contiguas, a ultima sem teto.
const ESCADA_DE_TESTE = {
  ladderId: "escada-de-teste",
  nome: "escada de teste",
  degraus: [degrau("baixa", 0, 99), degrau("media", 100, 199), degrau("alta", 200, null)],
};

describe("ligas: a ausencia de escada e o estado de fabrica", () => {
  test("SEM_ESCADA nao esta definida", () => {
    assert.equal(escadaDefinida(SEM_ESCADA), false);
    assert.deepEqual(SEM_ESCADA.degraus, []);
  });

  test("sem escada, ninguem tem liga — e nao 'cai no primeiro degrau'", () => {
    // A alternativa (default para a liga mais baixa) seria decidir rebaixamento,
    // que e politica de produto. `null` faz o cliente exibir ausencia.
    assert.equal(ligaDe(SEM_ESCADA, 0), null);
    assert.equal(ligaDe(SEM_ESCADA, 999999), null);
    assert.equal(ligaDe(SEM_ESCADA, -50), null);
  });
});

describe("ligas: limites de faixa", () => {
  test("limite inferior e INCLUSIVO", () => {
    assert.equal(ligaDe(ESCADA_DE_TESTE, 100).ligaId, "media");
  });

  test("limite superior e INCLUSIVO", () => {
    assert.equal(ligaDe(ESCADA_DE_TESTE, 199).ligaId, "media");
  });

  test("um ponto acima do teto ja e a proxima faixa", () => {
    assert.equal(ligaDe(ESCADA_DE_TESTE, 200).ligaId, "alta");
  });

  test("um ponto abaixo do piso ainda e a faixa anterior", () => {
    assert.equal(ligaDe(ESCADA_DE_TESTE, 99).ligaId, "baixa");
  });

  test("o topo nao tem teto", () => {
    assert.equal(ligaDe(ESCADA_DE_TESTE, 10 ** 9).ligaId, "alta");
  });

  test("abaixo do primeiro piso nao ha liga", () => {
    // Pontuacao negativa e possivel: uma politica futura pode ter delta negativo
    // por abandono. Encaixar isso na faixa mais baixa seria inventar a regra de
    // "piso de divisao", que a OS lista como decisao pendente.
    assert.equal(ligaDe(ESCADA_DE_TESTE, -1), null);
  });

  test("mudanca de faixa acompanha a pontuacao", () => {
    const trilha = [0, 99, 100, 199, 200, 5000].map((p) => ligaDe(ESCADA_DE_TESTE, p).ligaId);
    assert.deepEqual(trilha, ["baixa", "baixa", "media", "media", "alta", "alta"]);
  });
});

describe("ligas: configuracao invalida e RECUSADA", () => {
  test("escada vazia", () => {
    const c = conferirEscada([]);
    assert.equal(c.valida, false);
    assert.equal(c.recusa, "degraus_vazios");
  });

  test("liga duplicada", () => {
    const c = conferirEscada([degrau("a", 0, 9), degrau("a", 10, null)]);
    assert.equal(c.recusa, "liga_duplicada");
  });

  test("faixa invertida", () => {
    const c = conferirEscada([degrau("a", 100, 50), degrau("b", 101, null)]);
    assert.equal(c.recusa, "faixa_invertida");
  });

  test("faixas sobrepostas", () => {
    // Sem esta recusa, a mesma pontuacao daria ligas diferentes conforme a ordem
    // em que os degraus fossem lidos.
    const c = conferirEscada([degrau("a", 0, 100), degrau("b", 50, null)]);
    assert.equal(c.recusa, "faixa_sobreposta");
  });

  test("buraco entre faixas", () => {
    // Sem esta recusa, quem tivesse 50 ficaria sem liga nenhuma e ninguem saberia
    // por que.
    const c = conferirEscada([degrau("a", 0, 49), degrau("b", 51, null)]);
    assert.equal(c.recusa, "buraco_entre_faixas");
  });

  test("teto ausente no meio da escada", () => {
    const c = conferirEscada([degrau("a", 0, null), degrau("b", 100, null)]);
    assert.equal(c.recusa, "teto_no_meio");
  });

  test("a escada de teste e valida", () => {
    assert.equal(conferirEscada(ESCADA_DE_TESTE.degraus).valida, true);
  });
});

describe("ligas: leitura de escada persistida", () => {
  test("escada invalida no banco vira SEM_ESCADA, sem derrubar a leitura", () => {
    // Uma escada mal registrada nao pode derrubar o ranking inteiro. Ela derruba
    // a LIGA, que passa a ser nula, e o problema aparece no diagnostico.
    const lida = escadaDeJson({
      ladderId: "quebrada",
      degraus: [degrau("a", 0, 10), degrau("b", 50, null)],
    });
    assert.equal(escadaDefinida(lida), false);
  });

  test("lixo vira SEM_ESCADA", () => {
    assert.equal(escadaDeJson(null).degraus.length, 0);
    assert.equal(escadaDeJson({ degraus: "nao e lista" }).degraus.length, 0);
    assert.equal(escadaDeJson({ degraus: [{ ligaId: "" }] }).degraus.length, 0);
  });

  test("escada valida sobrevive a ida e volta", () => {
    const lida = escadaDeJson(ESCADA_DE_TESTE);
    assert.equal(escadaDefinida(lida), true);
    assert.equal(lida.degraus.length, 3);
    assert.equal(ligaDe(lida, 150).ligaId, "media");
  });
});

describe("ligas: a escada como o cliente a exibe", () => {
  test("marca o degrau atual, e so ele", () => {
    const exibida = escadaParaExibicao(ESCADA_DE_TESTE, "media");
    assert.deepEqual(
      exibida.map((d) => d.atual),
      [false, true, false]
    );
  });

  test("sem liga atual, nenhum degrau fica marcado", () => {
    const exibida = escadaParaExibicao(ESCADA_DE_TESTE, null);
    assert.equal(
      exibida.every((d) => d.atual === false),
      true
    );
  });

  test("sem escada, a lista sai vazia — e nao com degraus inventados", () => {
    assert.deepEqual(escadaParaExibicao(SEM_ESCADA, null), []);
  });
});
