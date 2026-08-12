/**
 * Prova a atribuicao de posicao oficial.
 *
 * Cobre a secao 23 ("Ranking": ordenacao, desempate, jogador fora da primeira
 * pagina, posicao com 1, 2, 3, 4 e 5+ digitos).
 *
 * A CONVENCAO QUE ESTA SUITE TRAVA: posicao MENOR e melhor, entao "subiu"
 * significa que o numero DIMINUIU. Escrito errado, inverteria as setas de toda a
 * tela — e e o tipo de defeito que passa em revisao, porque as duas leituras de
 * "subiu de 10 para 5" parecem certas.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  compararPosicao,
  apurarLote,
  posicoesSaoDensasEUnicas,
  apuracaoId,
  carimboDeMinuto,
  direcaoDeJson,
} = require("../lib/apuracao");
const { SEM_ESCADA } = require("../lib/ligas");

const ESCADA = {
  ladderId: "teste",
  nome: "teste",
  degraus: [
    { ligaId: "baixa", nome: "BAIXA", icone: "", pontosMinimos: 0, pontosMaximos: 99 },
    { ligaId: "alta", nome: "ALTA", icone: "", pontosMinimos: 100, pontosMaximos: null },
  ],
};

/// `classificado` por default: a maioria dos testes desta suite mede POSICAO, e
/// posicao existe para todo mundo. Os testes de Liga variam o estado de
/// proposito, porque a secao 15 amarra as duas coisas.
const linha = (uid, pontos, publicPlayerId, posicao = null, extra = {}) => ({
  uid,
  pontos,
  publicPlayerId,
  posicao,
  vitorias: 0,
  saldoPontos: 0,
  abandonos: 0,
  ratingAtingidoEm: "2026-01-01T00:00:00.000Z",
  estadoCompetitivo: "classificado",
  ...extra,
});

describe("apuracao: direcao do movimento", () => {
  test("numero MENOR e melhor: 10 -> 5 e SUBIU", () => {
    assert.deepEqual(compararPosicao(5, 10), { direcao: "subiu", deltaPosicao: 5 });
  });

  test("5 -> 10 e DESCEU", () => {
    assert.deepEqual(compararPosicao(10, 5), { direcao: "desceu", deltaPosicao: 5 });
  });

  test("mesma posicao e estavel", () => {
    assert.deepEqual(compararPosicao(7, 7), { direcao: "estavel", deltaPosicao: 0 });
  });

  test("quem nao tinha posicao anterior sai ESTAVEL, e nao 'subiu do infinito'", () => {
    // Sem isto, todo jogador novo apareceria com seta verde e um numero enorme
    // na primeira aparicao.
    assert.deepEqual(compararPosicao(4321, null), { direcao: "estavel", deltaPosicao: 0 });
  });

  test("o delta e sempre nao-negativo", () => {
    assert.ok(compararPosicao(1, 900).deltaPosicao > 0);
    assert.ok(compararPosicao(900, 1).deltaPosicao > 0);
  });
});

describe("apuracao: um lote", () => {
  test("posicoes comecam em 1 e sao densas", () => {
    const r = apurarLote({
      linhas: [linha("a", 300, "PA"), linha("b", 200, "PB"), linha("c", 100, "PC")],
      primeiraPosicao: 1,
      escada: SEM_ESCADA,
    });
    assert.deepEqual(r.map((x) => x.posicao), [1, 2, 3]);
    assert.equal(posicoesSaoDensasEUnicas(r), true);
  });

  test("empatados recebem posicoes DIFERENTES", () => {
    // Posicao compartilhada ("dois em quarto, ninguem em quinto") e uma convencao
    // competitiva; escolher uma seria decidir produto. A densa e a unica que a
    // paginacao por cursor sustenta sem ambiguidade.
    const r = apurarLote({
      linhas: [linha("a", 100, "PAAA"), linha("b", 100, "PBBB")],
      primeiraPosicao: 1,
      escada: SEM_ESCADA,
    });
    assert.deepEqual(r.map((x) => x.posicao), [1, 2]);
  });

  test("o segundo lote continua a contagem do primeiro", () => {
    // Sem isto, cada pagina da apuracao reiniciaria em 1 e a temporada inteira
    // teria varios "primeiros lugares".
    const r = apurarLote({
      linhas: [linha("d", 50, "PD"), linha("e", 40, "PE")],
      primeiraPosicao: 401,
      escada: SEM_ESCADA,
    });
    assert.deepEqual(r.map((x) => x.posicao), [401, 402]);
  });

  test("lote fora da ordem oficial FALHA em vez de ser reordenado", () => {
    // Reordenar aqui esconderia um problema de consulta (indice errado, campo
    // faltando) enquanto produzisse posicoes que nao batem com a paginacao que o
    // jogador ve.
    assert.throws(
      () =>
        apurarLote({
          linhas: [linha("a", 100, "PA"), linha("b", 300, "PB")],
          primeiraPosicao: 1,
          escada: SEM_ESCADA,
        }),
      /fora da ordem oficial/
    );
  });

  test("lote fora de ordem NO DESEMPATE tambem falha", () => {
    assert.throws(
      () =>
        apurarLote({
          linhas: [linha("a", 100, "PZZZ"), linha("b", 100, "PAAA")],
          primeiraPosicao: 1,
          escada: SEM_ESCADA,
        }),
      /fora da ordem oficial/
    );
  });

  test("lote vazio produz lote vazio", () => {
    assert.deepEqual(apurarLote({ linhas: [], primeiraPosicao: 1, escada: SEM_ESCADA }), []);
  });
});

describe("apuracao: a liga sai junto", () => {
  test("cada linha recebe a liga da sua faixa", () => {
    const r = apurarLote({
      linhas: [linha("a", 500, "PA"), linha("b", 50, "PB")],
      primeiraPosicao: 1,
      escada: ESCADA,
    });
    assert.equal(r[0].ligaId, "alta");
    assert.equal(r[1].ligaId, "baixa");
    assert.equal(r[0].ligaNome, "ALTA");
  });

  test("quem esta EM COLOCACAO nao recebe liga, mesmo com rating de sobra", () => {
    // SECAO 15: "Durante colocacao: `Em colocacao`, nao Bronze/Prata". A linha
    // entra na classificacao, com posicao, e sem Liga. Gravar a Liga aqui e
    // esconde-la na projecao seria escrever no banco uma afirmacao que nao vale.
    const r = apurarLote({
      linhas: [
        linha("a", 500, "PA", null, { estadoCompetitivo: "em_colocacao" }),
        linha("b", 400, "PB", null, { estadoCompetitivo: "em_revalidacao" }),
        linha("c", 300, "PC"),
      ],
      primeiraPosicao: 1,
      escada: ESCADA,
    });
    assert.deepEqual(r.map((x) => x.ligaId), [null, null, "alta"]);
    assert.deepEqual(r.map((x) => x.posicao), [1, 2, 3], "posicao existe para todos");
  });

  test("sem escada, ninguem recebe liga — e isso nao interrompe a apuracao", () => {
    // A posicao continua sendo atribuida. E o estado de hoje: ha classificacao,
    // nao ha liga.
    const r = apurarLote({
      linhas: [linha("a", 500, "PA"), linha("b", 50, "PB")],
      primeiraPosicao: 1,
      escada: SEM_ESCADA,
    });
    assert.deepEqual(r.map((x) => x.ligaId), [null, null]);
    assert.deepEqual(r.map((x) => x.posicao), [1, 2]);
  });
});

describe("apuracao: posicao com 1 a 5+ digitos", () => {
  test("a apuracao nao trunca nem formata numero grande", () => {
    // A OS pede posicao com 1, 2, 3, 4 e 5+ digitos. Aqui se prova o lado da
    // autoridade: o numero sai inteiro e exato. O lado da tela ja esta coberto
    // por `ranking_regressao_visual_test.dart`, na branch do cliente.
    for (const inicio of [1, 42, 573, 9999, 54321, 123456]) {
      const r = apurarLote({
        linhas: [linha("a", 10, "PA")],
        primeiraPosicao: inicio,
        escada: SEM_ESCADA,
      });
      assert.equal(r[0].posicao, inicio);
      assert.equal(String(r[0].posicao).length, String(inicio).length);
    }
  });

  test("jogador fora da primeira pagina mantem posicao coerente", () => {
    const r = apurarLote({
      linhas: [linha("x", 3, "PX")],
      primeiraPosicao: 1001,
      escada: SEM_ESCADA,
    });
    assert.equal(r[0].posicao, 1001);
  });
});

describe("apuracao: o movimento entre duas passagens", () => {
  test("quem subiu de posicao entre apuracoes e marcado", () => {
    const r = apurarLote({
      linhas: [linha("a", 300, "PA", 5), linha("b", 200, "PB", 1), linha("c", 100, "PC", 3)],
      primeiraPosicao: 1,
      escada: SEM_ESCADA,
    });
    assert.deepEqual(
      r.map((x) => [x.posicao, x.direcao, x.deltaPosicao]),
      [
        [1, "subiu", 4],
        [2, "desceu", 1],
        [3, "estavel", 0],
      ]
    );
  });

  test("a posicao anterior e preservada para a proxima comparacao", () => {
    const r = apurarLote({
      linhas: [linha("a", 300, "PA", 9)],
      primeiraPosicao: 1,
      escada: SEM_ESCADA,
    });
    assert.equal(r[0].posicaoAnterior, 9);
  });
});

describe("apuracao: a chave de idempotencia", () => {
  test("nao carrega milissegundo", () => {
    // Dois ticks do mesmo minuto tem que produzir a MESMA chave, senao a apuracao
    // roda duas vezes e a segunda passagem zera `direcao` e `delta` de todo mundo
    // comparando a posicao nova com ela mesma.
    const a = carimboDeMinuto(new Date("2026-08-11T20:31:07.123Z"));
    const b = carimboDeMinuto(new Date("2026-08-11T20:31:59.999Z"));
    assert.equal(a, b);
    assert.equal(apuracaoId("2026-A", a), apuracaoId("2026-A", b));
  });

  test("minutos diferentes produzem chaves diferentes", () => {
    const a = carimboDeMinuto(new Date("2026-08-11T20:31:00.000Z"));
    const b = carimboDeMinuto(new Date("2026-08-11T20:32:00.000Z"));
    assert.notEqual(apuracaoId("2026-A", a), apuracaoId("2026-A", b));
  });

  test("temporadas diferentes nao colidem", () => {
    const c = carimboDeMinuto(new Date("2026-08-11T20:31:00.000Z"));
    assert.notEqual(apuracaoId("2026-A", c), apuracaoId("2026-B", c));
  });

  test("o carimbo e UTC", () => {
    assert.equal(carimboDeMinuto(new Date("2026-08-11T20:31:07.123Z")), "2026-08-11T20:31Z");
  });
});

describe("apuracao: leitura de direcao persistida", () => {
  test("valores conhecidos passam", () => {
    assert.equal(direcaoDeJson("subiu"), "subiu");
    assert.equal(direcaoDeJson("desceu"), "desceu");
    assert.equal(direcaoDeJson("estavel"), "estavel");
  });

  test("qualquer outra coisa vira estavel", () => {
    // "Sem movimento" e o unico default que nao afirma nada sobre o jogador.
    for (const lixo of [null, undefined, "", "SUBIU", 1, {}]) {
      assert.equal(direcaoDeJson(lixo), "estavel");
    }
  });
});
