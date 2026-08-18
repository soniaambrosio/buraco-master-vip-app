/**
 * espelho.test.js — A PROVA DE QUE O ESPELHO NAO ENVELHECEU.
 *
 * `src/tipos.ts` declara `TIPO_DE_PARTIDA_WIRE`, que ESPELHA os valores de
 * `TipoDePartida` do dominio Dart (`app/lib/rastreabilidade/
 * identidade_partida.dart`). O espelho existe porque este codebase nao compila
 * dominio Dart — a razao esta escrita em package.json — e o preco de nao
 * compilar e que o espelho pode envelhecer em silencio.
 *
 * Este arquivo e o antidoto, e ele e o mesmo padrao que
 * `functions-conta/test/inventario.test.js` usa para ler `firestore.rules` e
 * que `functions-ranking/test/identidade.test.js` usa para ler o codebase
 * vizinho: cruzar a copia com a FONTE que o autor da mudanca e obrigado a
 * tocar.
 *
 * O QUE ACONTECE QUANDO ESTE TESTE QUEBRA: alguem renomeou um valor de
 * `TipoDePartida` ou acrescentou um tipo novo. A correcao NAO e ajustar o
 * literal aqui e seguir — e decidir a que tipo de mesa aquele valor
 * corresponde, e escrever a decisao em `src/tipos.ts` com a justificativa.
 *
 * COBRE TAMBEM o caso obrigatorio 3/19: `alteraRanking` do dominio Dart e a
 * UNICA fonte de "isto vale ranking", e o recorte que este codebase produz
 * precisa bater com ela.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { TIPO_DE_PARTIDA_WIRE, TIPO_MESA, tipoDePartidaDe, alimentaRanking } = require("../lib/tipos");

const RAIZ = path.join(__dirname, "..", "..");
const CAMINHO_DART = path.join(RAIZ, "app", "lib", "rastreabilidade", "identidade_partida.dart");

const dart = fs.readFileSync(CAMINHO_DART, "utf8");

describe("ESP — o espelho de TipoDePartida", () => {
  test("ESP-01 o arquivo fonte do dominio Dart existe onde o espelho diz", () => {
    // Se o arquivo for movido, este teste cai antes dos outros e diz por que.
    assert.ok(dart.includes("enum TipoDePartida"), "TipoDePartida sumiu do arquivo");
  });

  test("ESP-02 todo valor espelhado existe no dominio Dart", () => {
    for (const wire of Object.values(TIPO_DE_PARTIDA_WIRE)) {
      assert.ok(
        dart.includes(`'${wire}'`),
        `o espelho declara "${wire}", que nao existe em identidade_partida.dart`,
      );
    }
  });

  test("ESP-03 os quatro tipos de mesa mapeiam para valores que o Dart conhece", () => {
    for (const tipo of Object.values(TIPO_MESA)) {
      const wire = tipoDePartidaDe(tipo);
      assert.ok(dart.includes(`'${wire}'`), `${tipo} -> "${wire}" nao existe no dominio Dart`);
    }
  });

  test("ESP-04 `alteraRanking` do Dart continua sendo publicaRanqueada + torneio", () => {
    // O recorte deste codebase e mais estreito que o do Dart, e de proposito:
    // mesa de torneio nao passa por esta admissao — quem a abre e o Motor de
    // Torneios. Mas se o DART mudar a lista, o recorte precisa ser revisto, e
    // e este teste que obriga a revisao.
    const trecho = dart.slice(dart.indexOf("bool get alteraRanking"));
    const corpo = trecho.slice(0, trecho.indexOf(";") + 1);
    assert.ok(corpo.includes("publicaRanqueada"), "publicaRanqueada saiu de alteraRanking");
    assert.ok(corpo.includes("torneio"), "torneio saiu de alteraRanking");
    assert.equal(
      /privada|treinamento|contraRobos|publicaCasual/.test(corpo),
      false,
      "um tipo que NAO deveria pontuar entrou em alteraRanking",
    );
  });

  test("ESP-05 o unico tipo de mesa que ranqueia mapeia para publica_ranqueada", () => {
    const ranqueaveis = Object.values(TIPO_MESA).filter((t) => alimentaRanking(t));
    assert.deepEqual(ranqueaveis, [TIPO_MESA.VIP_RANQUEADA]);
    assert.equal(tipoDePartidaDe(TIPO_MESA.VIP_RANQUEADA), "publica_ranqueada");
  });

  test("ESP-06 Privada e Treino mapeiam para valores que o Dart NAO pontua", () => {
    // Prova cruzada do caso 45/49 (Privada nao altera Ranking) e 51 (Treino
    // nao altera Ranking), medida contra a autoridade Dart e nao contra a
    // opiniao deste codebase.
    const trecho = dart.slice(dart.indexOf("bool get alteraRanking"));
    const corpo = trecho.slice(0, trecho.indexOf(";") + 1);
    for (const tipo of [TIPO_MESA.PRIVADA, TIPO_MESA.TREINO, TIPO_MESA.PUBLICA]) {
      const wire = tipoDePartidaDe(tipo);
      // O nome Dart do valor (`privada`, `treinamento`, `publicaCasual`) nao
      // pode aparecer na expressao de alteraRanking.
      const nomeDart = dart
        .split("\n")
        .find((l) => l.includes(`('${wire}')`))
        ?.trim()
        .split("(")[0];
      assert.ok(nomeDart, `nao achei o identificador Dart de "${wire}"`);
      assert.equal(corpo.includes(nomeDart), false, `${nomeDart} pontua no dominio Dart`);
    }
  });
});
