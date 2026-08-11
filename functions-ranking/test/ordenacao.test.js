/**
 * Prova a ordem oficial e a paginacao por cursor.
 *
 * Cobre a secao 23 ("Ranking": ordenacao, desempate, paginacao, cursor, fim da
 * lista) e a secao 18 inteira.
 *
 * O DEFEITO QUE ESTA SUITE EXISTE PARA IMPEDIR e o mais silencioso da lista: um
 * desempate instavel faz duas paginas consecutivas repetirem ou PULAREM linhas.
 * O `dedupe` do cliente esconde a repeticao, e o pulo nao aparece em lugar nenhum
 * — o jogador simplesmente nunca ve aquelas pessoas.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  compararOficial,
  normalizarLimite,
  PAGINA_PADRAO,
  PAGINA_MAXIMA,
  codificarCursor,
  decodificarCursor,
  CursorInvalido,
  fecharPagina,
  VERSAO_CURSOR,
} = require("../lib/ordenacao");

const linha = (pontos, publicPlayerId) => ({ pontos, publicPlayerId });

describe("ordenacao: a ordem oficial", () => {
  test("mais pontos vem antes", () => {
    assert.ok(compararOficial(linha(100, "PA"), linha(50, "PB")) < 0);
    assert.ok(compararOficial(linha(50, "PA"), linha(100, "PB")) > 0);
  });

  test("empate desempata por id publico, crescente", () => {
    assert.ok(compararOficial(linha(100, "PAAA"), linha(100, "PBBB")) < 0);
    assert.ok(compararOficial(linha(100, "PBBB"), linha(100, "PAAA")) > 0);
  });

  test("a ordem e TOTAL: nada empata de verdade", () => {
    // A propriedade que o cursor depende. Dois documentos so comparam igual se
    // forem o MESMO documento, porque o id publico e unico.
    const pessoas = [linha(10, "PA"), linha(10, "PB"), linha(10, "PC")];
    for (const a of pessoas) {
      for (const b of pessoas) {
        if (a.publicPlayerId === b.publicPlayerId) {
          assert.equal(compararOficial(a, b), 0);
        } else {
          assert.notEqual(compararOficial(a, b), 0);
        }
      }
    }
  });

  test("a ordem e estavel e reproduzivel", () => {
    const base = [linha(5, "PC"), linha(9, "PA"), linha(5, "PA"), linha(9, "PB")];
    const uma = [...base].sort(compararOficial).map((l) => `${l.pontos}${l.publicPlayerId}`);
    const outra = [...base].reverse().sort(compararOficial).map((l) => `${l.pontos}${l.publicPlayerId}`);
    assert.deepEqual(uma, outra);
    assert.deepEqual(uma, ["9PA", "9PB", "5PA", "5PC"]);
  });

  test("o desempate NAO usa numero de partidas nem vitorias", () => {
    // Guarda contra a regressao mais provavel desta area: alguem "melhorar" o
    // desempate com um criterio que parece justo. Qualquer um deles seria uma
    // regra competitiva decidida por conta propria (secao 10).
    const a = { pontos: 100, publicPlayerId: "PZZZ", partidasComputadas: 1, vitorias: 99 };
    const b = { pontos: 100, publicPlayerId: "PAAA", partidasComputadas: 500, vitorias: 0 };
    assert.ok(compararOficial(a, b) > 0, "PZZZ deve vir DEPOIS de PAAA, so pelo id");
  });
});

describe("ordenacao: tamanho de pagina", () => {
  test("padrao quando nao informado ou invalido", () => {
    for (const bruto of [undefined, null, "20", 0, -5, NaN, Infinity]) {
      assert.equal(normalizarLimite(bruto), PAGINA_PADRAO);
    }
  });

  test("respeita o pedido dentro do teto", () => {
    assert.equal(normalizarLimite(10), 10);
    assert.equal(normalizarLimite(PAGINA_MAXIMA), PAGINA_MAXIMA);
  });

  test("o teto existe — um pedido gigante nao vira leitura integral", () => {
    // Sem o teto, `limite: 100000` seria a leitura da base inteira que a secao 19
    // proibe, pedida pelo proprio cliente.
    assert.equal(normalizarLimite(100000), PAGINA_MAXIMA);
  });
});

describe("cursor: ida e volta", () => {
  const alvo = { escopo: "temporada", seasonId: "2026-A" };

  test("codifica e decodifica sem perda", () => {
    const texto = codificarCursor({
      versao: VERSAO_CURSOR,
      escopo: "temporada",
      seasonId: "2026-A",
      pontos: 1234,
      publicPlayerId: "PABC123XYZ45",
    });
    const lido = decodificarCursor(texto, alvo);
    assert.equal(lido.pontos, 1234);
    assert.equal(lido.publicPlayerId, "PABC123XYZ45");
  });

  test("o cursor nao carrega nada sensivel", () => {
    const texto = codificarCursor({
      versao: VERSAO_CURSOR,
      escopo: "temporada",
      seasonId: "2026-A",
      pontos: 10,
      publicPlayerId: "PAAAAAAAAAAA",
    });
    const cru = Buffer.from(texto, "base64url").toString("utf8");
    for (const proibido of ["uid", "email", "token", "userId"]) {
      assert.equal(cru.includes(proibido), false, `cursor vazou "${proibido}": ${cru}`);
    }
  });

  test("texto que nao e cursor e recusado", () => {
    for (const lixo of ["", "   ", "nao-e-base64!!", undefined, null, 42]) {
      assert.throws(() => decodificarCursor(lixo, alvo), CursorInvalido);
    }
  });

  test("base64 valido que nao e JSON de cursor e recusado", () => {
    const texto = Buffer.from("apenas um texto", "utf8").toString("base64url");
    assert.throws(() => decodificarCursor(texto, alvo), CursorInvalido);
  });

  test("versao desconhecida e recusada, nao adivinhada", () => {
    const texto = Buffer.from(
      JSON.stringify({ v: 99, e: "temporada", s: "2026-A", p: 1, i: "PA" }),
      "utf8"
    ).toString("base64url");
    assert.throws(() => decodificarCursor(texto, alvo), /versao 99/);
  });

  test("cursor de outra ABA e recusado", () => {
    // O cliente mantem tres paginadores independentes. Sem esta conferencia, um
    // cursor da aba "temporada" aplicado a "global" devolveria uma pagina
    // PLAUSIVEL do lugar errado — a lista pularia gente sem nenhum sinal de erro.
    const texto = codificarCursor({
      versao: VERSAO_CURSOR,
      escopo: "global",
      seasonId: "",
      pontos: 10,
      publicPlayerId: "PA",
    });
    assert.throws(() => decodificarCursor(texto, alvo), /escopo/);
  });

  test("cursor de outra TEMPORADA e recusado", () => {
    const texto = codificarCursor({
      versao: VERSAO_CURSOR,
      escopo: "temporada",
      seasonId: "2025-B",
      pontos: 10,
      publicPlayerId: "PA",
    });
    assert.throws(() => decodificarCursor(texto, alvo), /temporada/);
  });

  test("cursor sem pontuacao inteira e recusado", () => {
    const texto = Buffer.from(
      JSON.stringify({ v: VERSAO_CURSOR, e: "temporada", s: "2026-A", p: 1.5, i: "PA" }),
      "utf8"
    ).toString("base64url");
    assert.throws(() => decodificarCursor(texto, alvo), /pontuacao inteira/);
  });
});

describe("cursor: fechamento de pagina", () => {
  const dez = Array.from({ length: 10 }, (_, i) => linha(100 - i, `P${String(i).padStart(2, "0")}`));

  test("pagina cheia com mais adiante devolve cursor e nao declara fim", () => {
    // A consulta pede `limite + 1`; receber 6 para um limite de 5 PROVA que ha
    // proxima pagina, sem uma segunda ida ao banco.
    const r = fecharPagina(dez.slice(0, 6), 5, "temporada", "2026-A");
    assert.equal(r.itens.length, 5);
    assert.equal(r.fim, false);
    assert.notEqual(r.cursorProxima, null);
  });

  test("o cursor aponta para o ULTIMO item devolvido", () => {
    const r = fecharPagina(dez.slice(0, 6), 5, "temporada", "2026-A");
    const lido = decodificarCursor(r.cursorProxima, { escopo: "temporada", seasonId: "2026-A" });
    const ultimo = r.itens[r.itens.length - 1];
    assert.equal(lido.pontos, ultimo.pontos);
    assert.equal(lido.publicPlayerId, ultimo.publicPlayerId);
  });

  test("pagina exatamente do tamanho do limite declara FIM", () => {
    // Pediu 6, recebeu 5: nao ha proxima. Sem isso o cliente gastaria uma ida a
    // rede so para descobrir que a lista acabou.
    const r = fecharPagina(dez.slice(0, 5), 5, "temporada", "2026-A");
    assert.equal(r.itens.length, 5);
    assert.equal(r.fim, true);
    assert.equal(r.cursorProxima, null);
  });

  test("pagina vazia declara fim", () => {
    const r = fecharPagina([], 5, "temporada", "2026-A");
    assert.deepEqual(r.itens, []);
    assert.equal(r.fim, true);
    assert.equal(r.cursorProxima, null);
  });

  test("paginar a lista inteira nao repete nem pula ninguem", () => {
    // A propriedade de ponta a ponta. Simula o servidor: a cada volta, filtra o
    // que vem DEPOIS do cursor pela ordem oficial, como o `startAfter` faz.
    const universo = [...dez].sort(compararOficial);
    const vistos = [];
    let cursor = null;
    let voltas = 0;

    for (;;) {
      if (++voltas > 50) throw new Error("paginacao nao terminou");
      const restantes =
        cursor === null
          ? universo
          : universo.filter(
              (l) => compararOficial(l, { pontos: cursor.pontos, publicPlayerId: cursor.publicPlayerId }) > 0
            );
      const r = fecharPagina(restantes.slice(0, 4), 3, "temporada", "2026-A");
      vistos.push(...r.itens.map((l) => l.publicPlayerId));
      if (r.fim) break;
      cursor = decodificarCursor(r.cursorProxima, { escopo: "temporada", seasonId: "2026-A" });
    }

    assert.equal(vistos.length, universo.length, "pulou ou repetiu alguem");
    assert.equal(new Set(vistos).size, universo.length, "houve repeticao");
    assert.deepEqual(vistos, universo.map((l) => l.publicPlayerId), "a ordem mudou entre paginas");
  });

  test("paginar com empate em massa tambem nao repete nem pula", () => {
    // O caso que quebra um cursor mal desempatado: todo mundo com a MESMA
    // pontuacao. Sem o id publico na ordem, `startAfter(pontos)` reiniciaria a
    // lista a cada pagina, ou pularia o bloco inteiro.
    const empatados = Array.from({ length: 9 }, (_, i) => linha(50, `P${String(i).padStart(2, "0")}`));
    const universo = [...empatados].sort(compararOficial);
    const vistos = [];
    let cursor = null;

    for (let voltas = 0; voltas < 50; voltas++) {
      const restantes =
        cursor === null
          ? universo
          : universo.filter(
              (l) => compararOficial(l, { pontos: cursor.pontos, publicPlayerId: cursor.publicPlayerId }) > 0
            );
      const r = fecharPagina(restantes.slice(0, 3), 2, "temporada", "2026-A");
      vistos.push(...r.itens.map((l) => l.publicPlayerId));
      if (r.fim) break;
      cursor = decodificarCursor(r.cursorProxima, { escopo: "temporada", seasonId: "2026-A" });
    }

    assert.deepEqual(vistos, universo.map((l) => l.publicPlayerId));
  });
});
