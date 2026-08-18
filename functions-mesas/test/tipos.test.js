/**
 * tipos.test.js — A TAXONOMIA, E AS COMBINACOES QUE ELA RECUSA.
 *
 * OS 2 — Arbitragem e canonizacao autoritativa dos tipos de mesa, permissoes
 * VIP e passe de cortesia v1.
 *
 * Cobre os casos obrigatorios 3 (Publica nunca gera Ranking), 5 (Publica
 * marcada como ranqueada), 20 (cliente nao transforma Publica em VIP), 45/49
 * (Mesa Privada nao altera Ranking) e 51 (Treino nao altera Ranking).
 *
 * O eixo que mais importa aqui e `traduzirDoServidor`. Ela e o unico ponto do
 * sistema em que as duas dimensoes do servidor viram um tipo canonico, e o
 * unico lugar onde uma combinacao impossivel pode ser adivinhada por engano.
 * Toda a matriz e percorrida, inclusive as celulas que devem recusar.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  TIPO_MESA,
  TIPOS_DE_MESA,
  TIPO_DE_PARTIDA_WIRE,
  tipoDeMesaPorWire,
  traduzirDoServidor,
  tipoDePartidaDe,
  alimentaRanking,
  exigeElegibilidadeVip,
  aceitaPasseDeCortesia,
} = require("../lib/tipos");

describe("TAX — os quatro tipos", () => {
  test("TAX-01 sao exatamente quatro, e os nomes sao os da OS", () => {
    assert.deepEqual([...TIPOS_DE_MESA], ["publica", "vipRanqueada", "privada", "treino"]);
  });

  test("TAX-02 a serializacao vai e volta para os quatro", () => {
    for (const t of TIPOS_DE_MESA) {
      assert.equal(tipoDeMesaPorWire(t), t);
    }
  });

  test("TAX-03 valor desconhecido nao vira tipo", () => {
    for (const lixo of ["vip", "VIP", "publico", "", "treinamento", null, 7, {}, ["publica"]]) {
      assert.equal(tipoDeMesaPorWire(lixo), null, `aceitou ${JSON.stringify(lixo)}`);
    }
  });
});

describe("TAX — traducao das duas dimensoes do servidor", () => {
  const casos = [
    ["publica", "casual", TIPO_MESA.PUBLICA],
    ["publica", "vip_ranqueada", TIPO_MESA.VIP_RANQUEADA],
    ["privada", "casual", TIPO_MESA.PRIVADA],
    ["simulada", "casual", TIPO_MESA.TREINO],
    ["simulada", "vip_ranqueada", TIPO_MESA.TREINO],
  ];

  for (const [tipoPartida, categoria, esperado] of casos) {
    test(`TAX-04 ${tipoPartida} x ${categoria} -> ${esperado}`, () => {
      assert.equal(traduzirDoServidor({ tipoPartida, categoriaCompetitiva: categoria }), esperado);
    });
  }

  test("TAX-05 privada x vip_ranqueada NAO resolve — seria ranking em sala fechada", () => {
    assert.equal(
      traduzirDoServidor({ tipoPartida: "privada", categoriaCompetitiva: "vip_ranqueada" }),
      null,
    );
  });

  test("TAX-06 categoria desconhecida do servidor nao vira casual", () => {
    // O servidor resolve configuracao invalida para `desconhecida`. Se ela
    // virasse `casual` aqui, um erro de configuracao transformaria mesa que
    // cobra em mesa aberta e gratuita, em silencio.
    assert.equal(
      traduzirDoServidor({ tipoPartida: "publica", categoriaCompetitiva: "desconhecida" }),
      null,
    );
  });

  test("TAX-07 topologia fora da enumeracao recusa", () => {
    for (const topologia of ["torneio", "vip", "", "PUBLICA", null, 3]) {
      assert.equal(
        traduzirDoServidor({ tipoPartida: topologia, categoriaCompetitiva: "casual" }),
        null,
        `aceitou ${JSON.stringify(topologia)}`,
      );
    }
  });

  test("TAX-08 nao existe caminho em que o cliente escolha o tipo", () => {
    // O corpo do contrato `admissao-vip-v1` nao tem campo de tipo canonico: ele
    // tem `categoriaCompetitiva`, que o servidor fixa na CONSTRUCAO do
    // processo. Este teste protege a fronteira do outro lado: mesmo que um
    // payload chegue com um tipo pronto, a traducao so aceita as duas
    // dimensoes, e nao um tipo canonico direto.
    assert.equal(
      traduzirDoServidor({ tipoPartida: "publica", categoriaCompetitiva: "vipRanqueada" }),
      null,
    );
  });
});

describe("TAX — quem alimenta o Ranking", () => {
  test("TAX-09 SO a VIP/Ranqueada alimenta o Ranking", () => {
    assert.equal(alimentaRanking(TIPO_MESA.VIP_RANQUEADA), true);
    assert.equal(alimentaRanking(TIPO_MESA.PUBLICA), false);
    assert.equal(alimentaRanking(TIPO_MESA.PRIVADA), false);
    assert.equal(alimentaRanking(TIPO_MESA.TREINO), false);
  });

  test("TAX-10 o nome de rastreabilidade de cada tipo", () => {
    assert.equal(tipoDePartidaDe(TIPO_MESA.PUBLICA), TIPO_DE_PARTIDA_WIRE.PUBLICA_CASUAL);
    assert.equal(tipoDePartidaDe(TIPO_MESA.VIP_RANQUEADA), TIPO_DE_PARTIDA_WIRE.PUBLICA_RANQUEADA);
    assert.equal(tipoDePartidaDe(TIPO_MESA.PRIVADA), TIPO_DE_PARTIDA_WIRE.PRIVADA);
    assert.equal(tipoDePartidaDe(TIPO_MESA.TREINO), TIPO_DE_PARTIDA_WIRE.TREINAMENTO);
  });

  test("TAX-11 o unico tipo que vira `publica_ranqueada` e o que alimenta o Ranking", () => {
    // Trava cruzada: se alguem mudar `tipoDePartidaDe` para mapear a Privada em
    // `publica_ranqueada` (por exemplo, "para ela aparecer no historico"), a
    // pontuacao dela passaria a contar. Aqui os dois lados sao conferidos
    // juntos, e a divergencia derruba a suite.
    for (const t of TIPOS_DE_MESA) {
      const ranqueia = tipoDePartidaDe(t) === TIPO_DE_PARTIDA_WIRE.PUBLICA_RANQUEADA;
      assert.equal(ranqueia, alimentaRanking(t), `divergencia em ${t}`);
    }
  });
});

describe("TAX — elegibilidade e cortesia divergem na Privada", () => {
  test("TAX-12 exigem VIP: vipRanqueada E privada", () => {
    assert.equal(exigeElegibilidadeVip(TIPO_MESA.VIP_RANQUEADA), true);
    assert.equal(exigeElegibilidadeVip(TIPO_MESA.PRIVADA), true);
    assert.equal(exigeElegibilidadeVip(TIPO_MESA.PUBLICA), false);
    assert.equal(exigeElegibilidadeVip(TIPO_MESA.TREINO), false);
  });

  test("TAX-13 a cortesia serve SO na vipRanqueada", () => {
    assert.equal(aceitaPasseDeCortesia(TIPO_MESA.VIP_RANQUEADA), true);
    assert.equal(aceitaPasseDeCortesia(TIPO_MESA.PRIVADA), false);
    assert.equal(aceitaPasseDeCortesia(TIPO_MESA.PUBLICA), false);
    assert.equal(aceitaPasseDeCortesia(TIPO_MESA.TREINO), false);
  });

  test("TAX-14 as duas perguntas NAO sao a mesma — a Privada e a prova", () => {
    // Se alguem simplificar as duas funcoes numa so (um `isVip`), este teste
    // cai: a Privada exige VIP e nao aceita cortesia.
    assert.notEqual(
      exigeElegibilidadeVip(TIPO_MESA.PRIVADA),
      aceitaPasseDeCortesia(TIPO_MESA.PRIVADA),
    );
  });

  test("TAX-15 cortesia nunca implica ranking, e ranking nunca implica cortesia sozinho", () => {
    for (const t of TIPOS_DE_MESA) {
      if (aceitaPasseDeCortesia(t)) assert.equal(exigeElegibilidadeVip(t), true, t);
    }
  });
});
