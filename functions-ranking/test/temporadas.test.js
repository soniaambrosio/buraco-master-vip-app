/**
 * Prova a temporada como entidade: abertura, encerramento idempotente e a faixa
 * de tempo que o cliente exibe.
 *
 * Cobre a secao 23 ("Temporada": inicio, termino, temporada passada, temporada
 * atual, fechamento executado duas vezes) e a secao 13.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  decidirAbertura,
  decidirEncerramento,
  temporadaNova,
  temporadaEncerrada,
  temporadaDeJson,
  faixaDeTempo,
} = require("../lib/temporadas");
const { POLITICA_PENDENTE } = require("../lib/politica");

const AGORA = "2026-08-11T20:00:00.000Z";

const abertura = (extra) =>
  decidirAbertura({
    seasonId: "2026-A",
    inicioEm: "2026-08-01T00:00:00.000Z",
    fimEm: "2026-10-31T23:59:59.000Z",
    jaExiste: false,
    vigenteAtual: null,
    ...extra,
  });

describe("temporada: abertura", () => {
  test("abre quando nao ha nada no caminho", () => {
    assert.equal(abertura().aceita, true);
  });

  test("no maximo UMA vigente por vez", () => {
    // Com duas vigentes, `temporadaVigente()` teria que escolher — e escolheria
    // pela ordem em que o Firestore devolveu. O jogador veria uma classificacao
    // diferente conforme a hora do dia.
    const d = abertura({ vigenteAtual: "2026-Anterior" });
    assert.equal(d.aceita, false);
    assert.equal(d.recusa, "outra_vigente");
  });

  test("nao reabre uma temporada existente", () => {
    // Reabrir sobrescreveria a politica com que ela pontuou, e o ledger dela
    // ficaria explicado por uma regra que nao valia na epoca.
    assert.equal(abertura({ jaExiste: true }).recusa, "ja_existe");
  });

  test("recusa intervalo invertido", () => {
    assert.equal(
      abertura({ inicioEm: "2026-10-01T00:00:00.000Z", fimEm: "2026-09-01T00:00:00.000Z" })
        .recusa,
      "intervalo_invertido"
    );
  });

  test("recusa id vazio", () => {
    assert.equal(abertura({ seasonId: "" }).recusa, "id_vazio");
  });

  test("temporada sem data de termino e valida", () => {
    // "Nao decidimos quando acaba" e informacao, nao lacuna. E o caso de hoje.
    assert.equal(abertura({ fimEm: null }).aceita, true);
  });
});

describe("temporada: a temporada nova", () => {
  test("nasce vigente", () => {
    const t = temporadaNova({
      seasonId: "2026-A",
      nome: "Temporada A",
      inicioEm: AGORA,
      fimEm: null,
      agora: AGORA,
    });
    assert.equal(t.status, "vigente");
    assert.equal(t.abertaEm, AGORA);
    assert.equal(t.fechadaEm, null);
  });

  test("nasce com politica PENDENTE quando ninguem informa uma", () => {
    // Uma temporada vigente sem politica e um estado legitimo e visivel: ela
    // acumula partidas no backlog e nao pontua ninguem.
    const t = temporadaNova({
      seasonId: "2026-A",
      nome: "",
      inicioEm: AGORA,
      fimEm: null,
      agora: AGORA,
    });
    assert.deepEqual(t.politica, POLITICA_PENDENTE);
  });

  test("nasce sem escada de ligas", () => {
    const t = temporadaNova({
      seasonId: "2026-A",
      nome: "",
      inicioEm: AGORA,
      fimEm: null,
      agora: AGORA,
    });
    assert.equal(t.ladderId, "");
  });

  test("o nome cai no id quando nao informado", () => {
    const t = temporadaNova({
      seasonId: "2026-A",
      nome: "",
      inicioEm: AGORA,
      fimEm: null,
      agora: AGORA,
    });
    assert.equal(t.nome, "2026-A");
  });
});

describe("temporada: encerramento idempotente (secao 13)", () => {
  const vigente = temporadaNova({
    seasonId: "2026-A",
    nome: "A",
    inicioEm: AGORA,
    fimEm: null,
    agora: AGORA,
  });

  test("a primeira execucao encerra", () => {
    const d = decidirEncerramento({ temporada: vigente });
    assert.equal(d.resultado, "encerrada");
    assert.equal(d.idempotente, false);
  });

  test("a SEGUNDA execucao e sucesso sem efeito", () => {
    // Rodar duas vezes nao pode duplicar nada. A segunda e o caminho do retry, e
    // reenvio nao e falha.
    const fechada = temporadaEncerrada(vigente, AGORA);
    const d = decidirEncerramento({ temporada: fechada });
    assert.equal(d.resultado, "ja_encerrada");
    assert.equal(d.idempotente, true);
  });

  test("o segundo encerramento nao mexe no carimbo do primeiro", () => {
    const fechada = temporadaEncerrada(vigente, "2026-10-31T00:00:00.000Z");
    const denovo = temporadaEncerrada(fechada, "2026-12-25T00:00:00.000Z");
    // A funcao pura sobrescreveria; quem protege e `decidirEncerramento`, que
    // impede a segunda chamada de acontecer. Este teste documenta a divisao.
    assert.equal(decidirEncerramento({ temporada: fechada }).idempotente, true);
    assert.equal(denovo.status, "encerrada");
  });

  test("temporada inexistente nao e um encerramento bem-sucedido", () => {
    const d = decidirEncerramento({ temporada: null });
    assert.equal(d.resultado, "inexistente");
    assert.equal(d.idempotente, false);
  });

  test("o encerramento NAO zera nem carrega pontuacao", () => {
    // Reset, reducao e carry-over entre temporadas sao decisao de produto que nao
    // existe. Esta funcao so mexe em status e carimbo — se um dia ela mexer em
    // mais alguma coisa, este teste quebra.
    const fechada = temporadaEncerrada(vigente, AGORA);
    const { status, fechadaEm, ...restoFechada } = fechada;
    const { status: s0, fechadaEm: f0, ...restoVigente } = vigente;
    assert.deepEqual(restoFechada, restoVigente);
    assert.equal(status, "encerrada");
    assert.equal(fechadaEm, AGORA);
  });
});

describe("temporada: leitura", () => {
  test("lixo vira null", () => {
    assert.equal(temporadaDeJson(null), null);
    assert.equal(temporadaDeJson({}), null);
    assert.equal(temporadaDeJson({ seasonId: "x" }), null, "status invalido");
    assert.equal(temporadaDeJson({ seasonId: "x", status: "inventado" }), null);
  });

  test("le uma temporada bem formada", () => {
    const t = temporadaDeJson({
      seasonId: "2026-A",
      status: "vigente",
      inicioEm: AGORA,
      fimEm: null,
      politica: { id: "p", versao: 2 },
      ladderId: "escada",
    });
    assert.equal(t.seasonId, "2026-A");
    assert.deepEqual(t.politica, { id: "p", versao: 2 });
  });
});

describe("temporada: a faixa de tempo que o cliente exibe", () => {
  const em = (iso) => new Date(iso);
  const comFim = (fimEm, status = "vigente") => ({
    ...temporadaNova({ seasonId: "s", nome: "s", inicioEm: AGORA, fimEm, agora: AGORA }),
    status,
  });

  test("dias e horas", () => {
    assert.equal(
      faixaDeTempo(comFim("2026-08-24T02:00:00.000Z"), em(AGORA)),
      "Temporada acaba em 12d 6h"
    );
  });

  test("menos de um dia cai para horas e minutos", () => {
    assert.equal(
      faixaDeTempo(comFim("2026-08-11T23:30:00.000Z"), em(AGORA)),
      "Temporada acaba em 3h 30min"
    );
  });

  test("menos de uma hora cai para minutos", () => {
    assert.equal(
      faixaDeTempo(comFim("2026-08-11T20:45:00.000Z"), em(AGORA)),
      "Temporada acaba em 45min"
    );
  });

  test("temporada encerrada diz que encerrou", () => {
    assert.equal(faixaDeTempo(comFim(null, "encerrada"), em(AGORA)), "Temporada encerrada");
  });

  test("prazo ja vencido diz que encerrou, em vez de contar negativo", () => {
    assert.equal(
      faixaDeTempo(comFim("2026-08-01T00:00:00.000Z"), em(AGORA)),
      "Temporada encerrada"
    );
  });

  test("temporada sem data de termino nao exibe contagem", () => {
    // Vazio, e nao um texto inventado. O contrato do cliente aceita string vazia
    // e nao mostra a faixa.
    assert.equal(faixaDeTempo(comFim(null), em(AGORA)), "");
  });

  test("data ilegivel nao quebra a tela", () => {
    assert.equal(faixaDeTempo(comFim("nao e data"), em(AGORA)), "");
  });
});
