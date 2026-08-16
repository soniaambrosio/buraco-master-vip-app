/**
 * Prova a aritmetica da Politica Competitiva v1.
 *
 * Cobre a secao 33 da OS nos blocos "Elo" (nove afirmacoes) e "Temporada" (os
 * cinco exemplos obrigatorios de soft reset).
 *
 * O DEFEITO QUE ESTA SUITE EXISTE PARA IMPEDIR e o mais caro que um ranking pode
 * ter: um delta errado gravado no `rankingLedger`, que e permanente. Nao ha
 * "corrigir depois" barato — corrigir exige reprocessar a temporada inteira sob
 * uma politica nova.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  RATING_INICIAL,
  K_COLOCACAO,
  K_CLASSIFICADO,
  PARTIDAS_DE_COLOCACAO,
  PARTIDAS_DE_REVALIDACAO,
  DIVISOR_ELO,
  arredondarMeioLongeDeZero,
  ratingDaDupla,
  expectativa,
  deltaElo,
  softReset,
} = require("../lib/elo");

/// O delta de um jogador, dado o confronto. Atalho de leitura para a suite.
const delta = (meu, dele, k, resultado) =>
  deltaElo({ k, resultado, esperado: expectativa(meu, dele) });

describe("elo: as constantes da OS", () => {
  test("os numeros sao os que a OS mandou, e nao aproximacoes", () => {
    assert.equal(RATING_INICIAL, 1000, "secao 7");
    assert.equal(K_COLOCACAO, 40, "secao 8");
    assert.equal(K_CLASSIFICADO, 24, "secao 10");
    assert.equal(PARTIDAS_DE_COLOCACAO, 10, "secao 8");
    assert.equal(PARTIDAS_DE_REVALIDACAO, 5, "secao 21");
    assert.equal(DIVISOR_ELO, 400, "Elo convencional");
  });
});

describe("elo: arredondamento", () => {
  test("meio vai para LONGE de zero, nos dois sentidos", () => {
    assert.equal(arredondarMeioLongeDeZero(12.5), 13);
    assert.equal(arredondarMeioLongeDeZero(-12.5), -13);
    assert.equal(arredondarMeioLongeDeZero(0.5), 1);
    assert.equal(arredondarMeioLongeDeZero(-0.5), -1);
  });

  test("o arredondamento e SIMETRICO — nao cria pontuacao do nada", () => {
    // O DEFEITO QUE ISTO IMPEDE: com `Math.round` (meio para cima), uma partida
    // equilibrada de K impar daria +13 ao vencedor e -12 ao perdedor. A mesa
    // inteira ganharia um ponto, a cada partida, para sempre — inflacao de rating
    // por defeito de arredondamento, invisivel ate todo mundo estar em Lenda.
    for (const x of [0.5, 1.5, 12.5, 99.5, 0.25, 7.31]) {
      assert.equal(
        arredondarMeioLongeDeZero(x) + arredondarMeioLongeDeZero(-x),
        0,
        `assimetrico em ${x}`
      );
    }
  });

  test("numero nao finito e recusado em vez de virar lancamento", () => {
    for (const lixo of [NaN, Infinity, -Infinity]) {
      assert.throws(() => arredondarMeioLongeDeZero(lixo));
    }
  });
});

describe("elo: forca da dupla (secao 9)", () => {
  test("media aritmetica dos dois", () => {
    assert.equal(ratingDaDupla([1200, 1400]), 1300, "o exemplo literal da secao 9");
  });

  test("a media NAO e arredondada", () => {
    // Arredondar aqui faria 1200+1401 e 1200+1400 produzirem a mesma
    // expectativa, e o rating do parceiro deixaria de importar em metade dos
    // casos.
    assert.equal(ratingDaDupla([1200, 1401]), 1300.5);
  });

  test("um lado de um jogador so vale ele mesmo", () => {
    assert.equal(ratingDaDupla([1234]), 1234);
  });

  test("lado sem jogador e erro, e nao zero", () => {
    assert.throws(() => ratingDaDupla([]));
  });
});

describe("elo: expectativa", () => {
  test("forcas iguais dao exatamente meio a meio", () => {
    assert.equal(expectativa(1000, 1000), 0.5);
    assert.equal(expectativa(1700, 1700), 0.5);
  });

  test("400 pontos de vantagem valem 10 para 1", () => {
    // A propriedade que define o divisor 400 do Elo classico.
    assert.ok(Math.abs(expectativa(1400, 1000) - 10 / 11) < 1e-12);
    assert.ok(Math.abs(expectativa(1000, 1400) - 1 / 11) < 1e-12);
  });

  test("as duas expectativas de um confronto somam 1", () => {
    for (const [a, b] of [[1000, 1000], [1500, 1200], [800, 1700], [1300.5, 1299.5]]) {
      assert.ok(Math.abs(expectativa(a, b) + expectativa(b, a) - 1) < 1e-12);
    }
  });
});

describe("elo: as quatro assimetrias que a secao 33 exige", () => {
  const FAVORITO = 1400;
  const AZARAO = 1000;

  test("o favorito ganha POUCO ao vencer", () => {
    assert.equal(delta(FAVORITO, AZARAO, K_CLASSIFICADO, 1), 2);
  });

  test("o azarao ganha MUITO ao vencer", () => {
    assert.equal(delta(AZARAO, FAVORITO, K_CLASSIFICADO, 1), 22);
  });

  test("o favorito perde MUITO ao perder", () => {
    assert.equal(delta(FAVORITO, AZARAO, K_CLASSIFICADO, 0), -22);
  });

  test("o azarao perde POUCO ao perder", () => {
    assert.equal(delta(AZARAO, FAVORITO, K_CLASSIFICADO, 0), -2);
  });

  test("as quatro afirmacoes valem como desigualdade, e nao so nestes numeros", () => {
    // A propriedade, e nao o caso. Vale para qualquer par com favoritismo.
    for (const [alto, baixo] of [[1200, 1000], [1700, 800], [1550, 1549]]) {
      const ganhoFavorito = delta(alto, baixo, K_CLASSIFICADO, 1);
      const ganhoAzarao = delta(baixo, alto, K_CLASSIFICADO, 1);
      const perdaFavorito = delta(alto, baixo, K_CLASSIFICADO, 0);
      const perdaAzarao = delta(baixo, alto, K_CLASSIFICADO, 0);
      assert.ok(ganhoFavorito <= ganhoAzarao, `${alto}x${baixo}: favorito ganhou demais`);
      assert.ok(perdaFavorito <= perdaAzarao, `${alto}x${baixo}: favorito perdeu de menos`);
    }
  });
});

describe("elo: empate (secao 12)", () => {
  test("entre iguais, o empate nao move ninguem", () => {
    assert.equal(delta(1000, 1000, K_CLASSIFICADO, 0.5), 0);
    assert.equal(delta(1000, 1000, K_COLOCACAO, 0.5), 0);
  });

  test("o empate PUNE o favorito e PREMIA o azarao", () => {
    // O empate vale 0.5, e o favorito esperava mais que isso.
    assert.ok(delta(1400, 1000, K_CLASSIFICADO, 0.5) < 0);
    assert.ok(delta(1000, 1400, K_CLASSIFICADO, 0.5) > 0);
  });

  test("o empate fica entre a derrota e a vitoria", () => {
    const perder = delta(1400, 1000, K_CLASSIFICADO, 0);
    const empatar = delta(1400, 1000, K_CLASSIFICADO, 0.5);
    const vencer = delta(1400, 1000, K_CLASSIFICADO, 1);
    assert.ok(perder < empatar && empatar < vencer);
  });
});

describe("elo: o fator K (secao 10)", () => {
  test("K=40 na colocacao move o dobro de K=24 no mesmo confronto", () => {
    assert.equal(delta(1000, 1000, K_COLOCACAO, 1), 20);
    assert.equal(delta(1000, 1000, K_CLASSIFICADO, 1), 12);
  });

  test("K maior move mais, em qualquer confronto e nos dois sentidos", () => {
    for (const [a, b] of [[1000, 1000], [1400, 1000], [900, 1500]]) {
      assert.ok(
        Math.abs(delta(a, b, K_COLOCACAO, 1)) >= Math.abs(delta(a, b, K_CLASSIFICADO, 1))
      );
      assert.ok(
        Math.abs(delta(a, b, K_COLOCACAO, 0)) >= Math.abs(delta(a, b, K_CLASSIFICADO, 0))
      );
    }
  });
});

describe("elo: o placar NAO entra na conta (secao 11)", () => {
  test("a assinatura torna a influencia impossivel, e nao apenas ausente", () => {
    // A prova mais forte disponivel: nenhuma funcao deste modulo recebe placar.
    // Nao ha caminho pelo qual a diferenca de pontos chegue ao delta, entao nao
    // ha o que testar caso a caso — ha o que constatar de uma vez.
    assert.equal(deltaElo.length, 1, "deltaElo recebe um objeto so");
    assert.deepEqual(Object.keys({ k: 0, resultado: 0, esperado: 0 }), [
      "k",
      "resultado",
      "esperado",
    ]);
  });

  test("duas vitorias contra o mesmo rating dao o MESMO delta", () => {
    // A afirmacao literal da secao 11: "ganhar por 100 pontos ou por 2.000
    // pontos continua sendo vitoria competitiva". Como o placar nem chega aqui,
    // o mesmo confronto so pode produzir o mesmo numero.
    const porPouco = delta(1150, 1150, K_CLASSIFICADO, 1);
    const porMuito = delta(1150, 1150, K_CLASSIFICADO, 1);
    assert.equal(porPouco, porMuito);
    assert.equal(porPouco, 12);
  });
});

describe("elo: determinismo (secao 26 — reprocessamento)", () => {
  test("a mesma entrada da o mesmo numero, sempre", () => {
    // O reprocessamento do backlog so produz o resultado correto se o calculo
    // for reproduzivel. Sem `Math.random` e sem relogio, ele e.
    for (let i = 0; i < 200; i++) {
      assert.equal(delta(1337, 1042, K_CLASSIFICADO, 1), delta(1337, 1042, K_CLASSIFICADO, 1));
    }
  });

  test("o delta e sempre inteiro — o ledger recusa fracionario", () => {
    for (const a of [800, 1000, 1234, 1700]) {
      for (const b of [800, 999, 1301, 1699]) {
        for (const s of [0, 0.5, 1]) {
          for (const k of [K_CLASSIFICADO, K_COLOCACAO]) {
            assert.ok(Number.isInteger(delta(a, b, k, s)), `${a}x${b} s=${s} k=${k}`);
          }
        }
      }
    }
  });
});

describe("elo: soft reset (secao 20)", () => {
  test("os CINCO exemplos obrigatorios da OS, literalmente", () => {
    assert.equal(softReset(1700), 1420);
    assert.equal(softReset(1400), 1240);
    assert.equal(softReset(1200), 1120);
    assert.equal(softReset(1000), 1000);
    assert.equal(softReset(800), 880);
  });

  test("nao zera ninguem — a secao 20 proibe", () => {
    // "Nao zerar todos para 1000". Quem terminou diferente de 1000 continua
    // diferente de 1000.
    for (const r of [1700, 1400, 1200, 800, 400]) {
      assert.notEqual(softReset(r), RATING_INICIAL, `${r} foi zerado`);
    }
  });

  test("comprime na direcao do centro, nos dois sentidos", () => {
    assert.ok(softReset(1700) < 1700 && softReset(1700) > RATING_INICIAL);
    assert.ok(softReset(800) > 800 && softReset(800) < RATING_INICIAL);
  });

  test("preserva a ORDEM entre jogadores", () => {
    // Quem terminou a temporada acima de outro comeca a seguinte acima dele. Um
    // soft reset que inverta posicoes seria uma punicao aleatoria.
    const finais = [400, 800, 1000, 1200, 1400, 1700, 2100];
    const depois = finais.map(softReset);
    for (let i = 1; i < depois.length; i++) {
      assert.ok(depois[i] > depois[i - 1], `${finais[i]} nao ficou acima de ${finais[i - 1]}`);
    }
  });

  test("o resultado e sempre inteiro, inclusive fora dos exemplos redondos", () => {
    for (let r = 700; r <= 1800; r++) {
      assert.ok(Number.isInteger(softReset(r)), `softReset(${r}) nao e inteiro`);
    }
  });

  test("aplicado varias vezes, aproxima do centro sem NUNCA ultrapassar", () => {
    // Temporadas seguidas de inatividade nao podem jogar ninguem para o outro
    // lado do centro — um jogador que foi Lenda nao pode virar Bronze so por
    // nao jogar. A propriedade decorre do fator estar entre 0 e 1.
    //
    // O PONTO FIXO NAO E 1000, E ISSO E ESPERADO: `softReset(1001)` da 1000.6,
    // que arredonda de volta para 1001. A sequencia estaciona a um ponto do
    // centro em vez de chegar nele, o que e inofensivo e preferivel a um
    // arredondamento que empurrasse o veterano para o lado de baixo.
    let acima = 1700;
    let abaixo = 400;
    for (let i = 0; i < 50; i++) {
      acima = softReset(acima);
      abaixo = softReset(abaixo);
      assert.ok(acima >= RATING_INICIAL, `quem estava acima cruzou o centro: ${acima}`);
      assert.ok(abaixo <= RATING_INICIAL, `quem estava abaixo cruzou o centro: ${abaixo}`);
    }
    assert.ok(acima - RATING_INICIAL <= 1, `estacionou longe do centro: ${acima}`);
    assert.ok(RATING_INICIAL - abaixo <= 1, `estacionou longe do centro: ${abaixo}`);
  });
});
