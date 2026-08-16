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
  compararPor,
  normalizarLimite,
  PAGINA_PADRAO,
  PAGINA_MAXIMA,
  codificarCursor,
  decodificarCursor,
  CursorInvalido,
  fecharPagina,
  VERSAO_CURSOR,
  ORDEM_TEMPORADA,
  ORDEM_GLOBAL,
  valorDoCriterio,
} = require("../lib/ordenacao");

/// Uma linha completa. Os campos do desempate da secao 17 recebem o mesmo valor
/// em todas as linhas construidas por aqui, de proposito: assim os testes desta
/// primeira suite continuam medindo o que sempre mediram (pontos e id publico),
/// e o desempate competitivo e exercitado na suite propria, mais abaixo.
const linha = (pontos, publicPlayerId, extra = {}) => ({
  pontos,
  vitorias: 0,
  saldoPontos: 0,
  abandonos: 0,
  ratingAtingidoEm: "2026-01-01T00:00:00.000Z",
  publicPlayerId,
  ...extra,
});

const alvoTemporada = { escopo: "temporada", seasonId: "2026-A", ordem: ORDEM_TEMPORADA };

/// Reconstroi uma chave de ordem a partir do cursor, como o Firestore faria com
/// `startAfter(...chaves)`.
const deCursor = (cursor) => {
  const chave = {};
  ORDEM_TEMPORADA.forEach((c, i) => {
    chave[c.campo] = cursor.chaves[i];
  });
  return chave;
};

const cursorDe = (l, escopo = "temporada", seasonId = "2026-A") =>
  codificarCursor({
    versao: VERSAO_CURSOR,
    escopo,
    seasonId,
    chaves: (escopo === "global" ? ORDEM_GLOBAL : ORDEM_TEMPORADA).map((c) =>
      valorDoCriterio(l, c)
    ),
  });

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

  test("o id publico so decide quando os CINCO criterios competitivos empatam", () => {
    // Este teste substituiu um que afirmava o contrario ("o desempate NAO usa
    // vitorias"), e a troca e a propria mudanca de regra: ate a OS anterior nao
    // havia decisao de produto sobre desempate, e o id publico era o unico
    // criterio depois dos pontos. A secao 17 decidiu os cinco, e agora o id
    // publico e o SEXTO — ele so aparece quando nada mais distingue.
    const base = {
      pontos: 100,
      vitorias: 7,
      saldoPontos: 500,
      abandonos: 1,
      ratingAtingidoEm: "2026-03-01T00:00:00.000Z",
    };
    assert.ok(
      compararOficial({ ...base, publicPlayerId: "PZZZ" }, { ...base, publicPlayerId: "PAAA" }) > 0,
      "com tudo igual, PZZZ vem depois de PAAA"
    );
  });

  test("o UID nunca e criterio — ele nem chega a esta camada", () => {
    // Secao 17: "Nao usar UID como criterio competitivo". A garantia e de forma:
    // `ChaveDeOrdem` nao tem campo de uid, e `valorDoCriterio` recusa qualquer
    // campo que nao esteja na lista.
    assert.equal(
      ORDEM_TEMPORADA.some((c) => c.campo === "uid" || c.campo === "userId"),
      false
    );
    assert.throws(() => valorDoCriterio(linha(1, "PA"), { campo: "uid", sentido: "asc", competitivo: false }));
  });
});

describe("ordenacao: o desempate da secao 17, criterio a criterio", () => {
  // A OS pede que os cinco sejam testados SEQUENCIALMENTE: cada teste iguala
  // tudo que vem antes e varia so o criterio da vez. E o unico jeito de provar a
  // ORDEM dos criterios, e nao apenas que cada um funciona isolado.
  const igual = {
    pontos: 1200,
    vitorias: 10,
    saldoPontos: 300,
    abandonos: 2,
    ratingAtingidoEm: "2026-05-01T00:00:00.000Z",
    publicPlayerId: "PMMM",
  };

  test("1o criterio: maior rating vem antes", () => {
    assert.ok(compararOficial({ ...igual, pontos: 1201 }, { ...igual, pontos: 1200 }) < 0);
  });

  test("2o criterio: com rating igual, mais vitorias vem antes", () => {
    assert.ok(compararOficial({ ...igual, vitorias: 11 }, { ...igual, vitorias: 10 }) < 0);
  });

  test("3o criterio: com rating e vitorias iguais, maior saldo vem antes", () => {
    assert.ok(compararOficial({ ...igual, saldoPontos: 301 }, { ...igual, saldoPontos: 300 }) < 0);
  });

  test("4o criterio: com os tres iguais, MENOS abandonos vem antes", () => {
    // O unico criterio ASCENDENTE dos cinco, e por isso o mais facil de inverter
    // por engano — um `desc` aqui premiaria quem mais abandona.
    assert.ok(compararOficial({ ...igual, abandonos: 1 }, { ...igual, abandonos: 2 }) < 0);
    assert.ok(compararOficial({ ...igual, abandonos: 3 }, { ...igual, abandonos: 2 }) > 0);
  });

  test("5o criterio: com os quatro iguais, quem chegou ao rating PRIMEIRO vem antes", () => {
    const cedo = { ...igual, ratingAtingidoEm: "2026-05-01T00:00:00.000Z" };
    const tarde = { ...igual, ratingAtingidoEm: "2026-06-01T00:00:00.000Z" };
    assert.ok(compararOficial(cedo, tarde) < 0, "quem esta neste rating ha mais tempo vem antes");
  });

  test("um criterio anterior VENCE todos os seguintes", () => {
    // Prova a ORDEM. O jogador com mais rating vem antes mesmo perdendo em
    // vitorias, saldo, abandonos e antiguidade ao mesmo tempo.
    const forte = {
      pontos: 1201,
      vitorias: 0,
      saldoPontos: -9999,
      abandonos: 99,
      ratingAtingidoEm: "2026-12-31T00:00:00.000Z",
      publicPlayerId: "PZZZ",
    };
    const fraco = {
      pontos: 1200,
      vitorias: 999,
      saldoPontos: 9999,
      abandonos: 0,
      ratingAtingidoEm: "2026-01-01T00:00:00.000Z",
      publicPlayerId: "PAAA",
    };
    assert.ok(compararOficial(forte, fraco) < 0);

    // E o mesmo um degrau abaixo: vitorias vencem saldo, abandono e antiguidade.
    assert.ok(
      compararOficial(
        { ...fraco, pontos: 1200, vitorias: 1 },
        { ...fraco, pontos: 1200, vitorias: 0, saldoPontos: 99999, abandonos: 0 }
      ) < 0
    );
  });

  test("o escopo global usa a ordem DELE, e nao os cinco criterios", () => {
    // `rankingPlayers` nao tem vitorias nem saldo por temporada. Aplicar os cinco
    // ali exigiria inventar o significado de cada um fora do recorte em que a
    // secao 17 os definiu.
    assert.deepEqual(ORDEM_GLOBAL.map((c) => c.campo), ["pontos", "publicPlayerId"]);
    const a = { ...igual, vitorias: 0, publicPlayerId: "PAAA" };
    const b = { ...igual, vitorias: 999, publicPlayerId: "PBBB" };
    assert.ok(compararPor(ORDEM_GLOBAL, a, b) < 0, "no global, vitorias nao desempatam");
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
  const alvo = alvoTemporada;

  test("codifica e decodifica sem perda", () => {
    const original = linha(1234, "PABC123XYZ45", { vitorias: 9, saldoPontos: 77, abandonos: 1 });
    const lido = decodificarCursor(cursorDe(original), alvo);
    assert.deepEqual(deCursor(lido), {
      pontos: 1234,
      vitorias: 9,
      saldoPontos: 77,
      abandonos: 1,
      ratingAtingidoEm: "2026-01-01T00:00:00.000Z",
      publicPlayerId: "PABC123XYZ45",
    });
  });

  test("o cursor carrega TODOS os criterios da ordem, e nada alem", () => {
    // Um cursor com menos valores do que a consulta tem criterios faria o
    // `startAfter` posicionar por um PREFIXO — a pagina comecaria num lugar
    // plausivel e repetiria linhas. Falha que so aparece na segunda pagina.
    const lido = decodificarCursor(cursorDe(linha(10, "PAAAAAAAAAAA")), alvo);
    assert.equal(lido.chaves.length, ORDEM_TEMPORADA.length);
  });

  test("cursor com aridade errada e recusado", () => {
    const curto = Buffer.from(
      JSON.stringify({ v: VERSAO_CURSOR, e: "temporada", s: "2026-A", k: [10, "PA"] }),
      "utf8"
    ).toString("base64url");
    assert.throws(() => decodificarCursor(curto, alvo), /2 valor/);
  });

  test("o cursor nao carrega nada sensivel", () => {
    const texto = cursorDe(linha(10, "PAAAAAAAAAAA"));
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
      JSON.stringify({ v: 99, e: "temporada", s: "2026-A", k: [1, "PA"] }),
      "utf8"
    ).toString("base64url");
    assert.throws(() => decodificarCursor(texto, alvo), /versao 99/);
  });

  test("um cursor da versao ANTERIOR e recusado, e nao reinterpretado", () => {
    // O caso real do dia do deploy: um cursor v1 (`{p, i}`, dois criterios) no
    // bolso de um cliente que estava com a lista aberta. Sob a ordem de seis
    // criterios ele apontaria para o lugar errado — entao ele e recusado, e o
    // cliente recomeca a lista.
    const v1 = Buffer.from(
      JSON.stringify({ v: 1, e: "temporada", s: "2026-A", p: 100, i: "PA" }),
      "utf8"
    ).toString("base64url");
    assert.throws(() => decodificarCursor(v1, alvo), CursorInvalido);
  });

  test("cursor de outra ABA e recusado", () => {
    // O cliente mantem tres paginadores independentes. Sem esta conferencia, um
    // cursor da aba "temporada" aplicado a "global" devolveria uma pagina
    // PLAUSIVEL do lugar errado — a lista pularia gente sem nenhum sinal de erro.
    const texto = cursorDe(linha(10, "PA"), "global", "");
    assert.throws(() => decodificarCursor(texto, alvo), /escopo/);
  });

  test("cursor de outra TEMPORADA e recusado", () => {
    const texto = cursorDe(linha(10, "PA"), "temporada", "2025-B");
    assert.throws(() => decodificarCursor(texto, alvo), /temporada/);
  });

  test("cursor com valor fracionario e recusado", () => {
    const texto = Buffer.from(
      JSON.stringify({
        v: VERSAO_CURSOR,
        e: "temporada",
        s: "2026-A",
        k: [1.5, 0, 0, 0, "2026-01-01T00:00:00.000Z", "PA"],
      }),
      "utf8"
    ).toString("base64url");
    assert.throws(() => decodificarCursor(texto, alvo), /nao e inteiro/);
  });
});

describe("cursor: fechamento de pagina", () => {
  const dez = Array.from({ length: 10 }, (_, i) => linha(100 - i, `P${String(i).padStart(2, "0")}`));

  test("pagina cheia com mais adiante devolve cursor e nao declara fim", () => {
    // A consulta pede `limite + 1`; receber 6 para um limite de 5 PROVA que ha
    // proxima pagina, sem uma segunda ida ao banco.
    const r = fecharPagina(dez.slice(0, 6), 5, "temporada", "2026-A", ORDEM_TEMPORADA);
    assert.equal(r.itens.length, 5);
    assert.equal(r.fim, false);
    assert.notEqual(r.cursorProxima, null);
  });

  test("o cursor aponta para o ULTIMO item devolvido", () => {
    const r = fecharPagina(dez.slice(0, 6), 5, "temporada", "2026-A", ORDEM_TEMPORADA);
    const lido = decodificarCursor(r.cursorProxima, alvoTemporada);
    const ultimo = r.itens[r.itens.length - 1];
    // Os SEIS criterios apontam para a mesma linha. Conferir so `pontos` deixaria
    // passar um cursor que perdesse o desempate no meio do caminho.
    assert.deepEqual(
      lido.chaves,
      ORDEM_TEMPORADA.map((c) => valorDoCriterio(ultimo, c))
    );
  });

  test("pagina exatamente do tamanho do limite declara FIM", () => {
    // Pediu 6, recebeu 5: nao ha proxima. Sem isso o cliente gastaria uma ida a
    // rede so para descobrir que a lista acabou.
    const r = fecharPagina(dez.slice(0, 5), 5, "temporada", "2026-A", ORDEM_TEMPORADA);
    assert.equal(r.itens.length, 5);
    assert.equal(r.fim, true);
    assert.equal(r.cursorProxima, null);
  });

  test("pagina vazia declara fim", () => {
    const r = fecharPagina([], 5, "temporada", "2026-A", ORDEM_TEMPORADA);
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
              (l) => compararOficial(l, deCursor(cursor)) > 0
            );
      const r = fecharPagina(restantes.slice(0, 4), 3, "temporada", "2026-A", ORDEM_TEMPORADA);
      vistos.push(...r.itens.map((l) => l.publicPlayerId));
      if (r.fim) break;
      cursor = decodificarCursor(r.cursorProxima, alvoTemporada);
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
              (l) => compararOficial(l, deCursor(cursor)) > 0
            );
      const r = fecharPagina(restantes.slice(0, 3), 2, "temporada", "2026-A", ORDEM_TEMPORADA);
      vistos.push(...r.itens.map((l) => l.publicPlayerId));
      if (r.fim) break;
      cursor = decodificarCursor(r.cursorProxima, alvoTemporada);
    }

    assert.deepEqual(vistos, universo.map((l) => l.publicPlayerId));
  });
});
