/**
 * Prova a leitura do resultado oficial e a decisao de processa-lo.
 *
 * Cobre a secao 23 ("Idempotencia": mesma partida duas vezes, evento atrasado,
 * retry apos falha parcial) e a parte da secao 8 que nao depende do banco.
 *
 * O CASO CENTRAL DE HOJE, e ele tem teste proprio: sem calculadora registrada,
 * NENHUMA partida pontua e TODAS vao para o backlog. E o comportamento correto
 * enquanto a formula for decisao de produto — e o backlog e o que impede a
 * ausencia de regra de virar um buraco silencioso.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  resultadoDeJson,
  estadoTerminal,
  decidirProcessamento,
  chaveDeContribuicao,
} = require("../lib/resultado");

/// Um documento `matches/{id}` como `RegistroDePartida.toJson()` o grava.
const REGISTRO = {
  matchId: "m-001",
  estado: "finalizada",
  tipo: "publica_ranqueada",
  alteraRanking: true,
  motivoEncerramento: "objetivo_atingido",
  ladoVencedor: "A",
  encerradaEm: "2026-08-11T20:00:00.000Z",
  participantes: [
    { classe: "humano", userId: "u1", assento: 0, lado: "A" },
    { classe: "humano", userId: "u2", assento: 1, lado: "B" },
    { classe: "robo", botId: "bot-7", assento: 2 },
    { classe: "espectador", userId: "u9" },
  ],
  placar: [
    { lado: "A", pontos: 3000, canastrasLimpas: 2 },
    { lado: "B", pontos: 1500, canastrasLimpas: 0 },
  ],
};

const decidir = (extra) =>
  decidirProcessamento({
    resultado: resultadoDeJson(REGISTRO),
    jaProcessado: false,
    temporadaVigente: "2026-A",
    temporadaEncerrada: false,
    temCalculadora: true,
    ...extra,
  });

describe("resultado: leitura do documento oficial", () => {
  test("le o recorte que o ranking consome", () => {
    const r = resultadoDeJson(REGISTRO);
    assert.equal(r.matchId, "m-001");
    assert.equal(r.estado, "finalizada");
    assert.equal(r.alteraRanking, true);
    assert.equal(r.ladoVencedor, "A");
  });

  test("SO humanos com userId competem", () => {
    // Robo nao tem conta e espectador nao competiu. Errar isso pontuaria um bot
    // ou daria pontos a quem so assistiu.
    const r = resultadoDeJson(REGISTRO);
    assert.deepEqual(r.competidores.map((c) => c.userId), ["u1", "u2"]);
  });

  test("o lado de cada competidor e preservado", () => {
    const r = resultadoDeJson(REGISTRO);
    assert.deepEqual(r.competidores.map((c) => c.lado), ["A", "B"]);
  });

  test("`alteraRanking` e LIDO, e nao recalculado", () => {
    // `TipoDePartida.alteraRanking` no Dart e "a UNICA fonte de isto vale ranking
    // no sistema". Recalcular aqui criaria a segunda. Se o registro disser que
    // uma ranqueada finalizada nao altera ranking, e isso que vale.
    const contraditorio = { ...REGISTRO, alteraRanking: false };
    assert.equal(resultadoDeJson(contraditorio).alteraRanking, false);
  });

  test("documento sem forma minima vira null, sem estourar", () => {
    // O gatilho recebe QUALQUER escrita em `matches`, inclusive as de abertura.
    for (const lixo of [null, undefined, {}, "texto", { matchId: "m" }, { estado: "x" }]) {
      assert.equal(resultadoDeJson(lixo), null);
    }
  });

  test("partida sem participantes le sem competidores", () => {
    const r = resultadoDeJson({ ...REGISTRO, participantes: undefined });
    assert.deepEqual(r.competidores, []);
  });
});

describe("resultado: estados terminais", () => {
  test("os tres terminais do dominio", () => {
    assert.equal(estadoTerminal("finalizada"), true);
    assert.equal(estadoTerminal("abandonada"), true);
    assert.equal(estadoTerminal("cancelada"), true);
  });

  test("qualquer outro nao e terminal", () => {
    for (const e of ["aberta", "em_andamento", "pausada", ""]) {
      assert.equal(estadoTerminal(e), false);
    }
  });
});

describe("resultado: a decisao de processar", () => {
  test("resultado valido, temporada vigente e calculadora -> processa", () => {
    const d = decidir();
    assert.equal(d.processa, true);
    assert.equal(d.recusa, null);
  });

  test("documento sem resultado e ignorado em silencio", () => {
    const d = decidir({ resultado: null });
    assert.equal(d.recusa, "sem_resultado");
    assert.equal(d.benigna, true);
    assert.equal(d.guardarNoBacklog, false);
  });

  test("partida ainda em andamento e ignorada", () => {
    const d = decidir({ resultado: resultadoDeJson({ ...REGISTRO, estado: "em_andamento" }) });
    assert.equal(d.recusa, "nao_terminal");
    assert.equal(d.guardarNoBacklog, false);
  });

  test("partida que nao pontua e recusa DEFINITIVA, sem backlog", () => {
    // Casual, privada, treino e contra robos nunca vao pontuar, nem quando a
    // formula existir. Guarda-las poluiria a lista de reprocessamento para sempre.
    const casual = resultadoDeJson({ ...REGISTRO, tipo: "publica_casual", alteraRanking: false });
    const d = decidir({ resultado: casual });
    assert.equal(d.recusa, "nao_pontua");
    assert.equal(d.benigna, true);
    assert.equal(d.guardarNoBacklog, false);
  });

  test("partida sem competidor pontuavel e recusa definitiva", () => {
    const soBots = resultadoDeJson({
      ...REGISTRO,
      participantes: [{ classe: "robo", botId: "b1", assento: 0 }],
    });
    assert.equal(decidir({ resultado: soBots }).recusa, "sem_competidores");
  });
});

describe("resultado: idempotencia (secao 8)", () => {
  test("a mesma partida duas vezes: a segunda e recusa BENIGNA", () => {
    const d = decidir({ jaProcessado: true });
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "ja_processado");
    assert.equal(d.benigna, true);
    // Nao vai para o backlog: ela ja contribuiu, nao esta esperando nada.
    assert.equal(d.guardarNoBacklog, false);
  });

  test("a idempotencia vem ANTES da politica", () => {
    // O detalhe que o dominio Dart tambem registra: um reprocessamento de partida
    // antiga tem que sair como "ja processado" em vez de estourar por causa de
    // uma politica que mudou desde entao. Invertido, um retry apos troca de regra
    // viraria erro permanente.
    const d = decidir({ jaProcessado: true, temCalculadora: false });
    assert.equal(d.recusa, "ja_processado");
  });

  test("a idempotencia vem ANTES da temporada tambem", () => {
    const d = decidir({ jaProcessado: true, temporadaVigente: null });
    assert.equal(d.recusa, "ja_processado");
  });
});

describe("resultado: o caminho de HOJE — sem formula", () => {
  test("sem calculadora, nao pontua e VAI PARA O BACKLOG", () => {
    // A afirmacao mais importante desta suite. Nenhuma politica esta registrada
    // em producao, entao e aqui que todo resultado oficial cai hoje.
    const d = decidir({ temCalculadora: false });
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "politica_nao_definida");
    assert.equal(d.benigna, true);
    assert.equal(d.guardarNoBacklog, true);
  });

  test("sem temporada vigente, tambem vai para o backlog", () => {
    // A partida aconteceu de verdade e o resultado dela e permanente. Descarta-la
    // perderia a informacao; guarda-la permite reprocessar (secao 22).
    const d = decidir({ temporadaVigente: null });
    assert.equal(d.recusa, "sem_temporada_vigente");
    assert.equal(d.guardarNoBacklog, true);
  });

  test("temporada ja encerrada nao recebe partida atrasada", () => {
    // O "evento atrasado" da secao 23: um callback que chega depois do
    // fechamento nao pode mexer numa classificacao ja publicada.
    const d = decidir({ temporadaEncerrada: true });
    assert.equal(d.recusa, "temporada_encerrada");
    assert.equal(d.guardarNoBacklog, true);
  });
});

describe("resultado: a chave de contribuicao", () => {
  test("carrega partida, temporada, politica e versao", () => {
    assert.equal(
      chaveDeContribuicao("m-001", "2026-A", "temporada-2026-v1", 3),
      "m-001|2026-A|temporada-2026-v1|v3"
    );
  });

  test("a mesma partida na mesma temporada e com a mesma regra colide", () => {
    // E o que faz a segunda gravacao ser a mesma escrita.
    assert.equal(
      chaveDeContribuicao("m", "s", "p", 1),
      chaveDeContribuicao("m", "s", "p", 1)
    );
  });

  test("temporada diferente e outra contribuicao", () => {
    // Permite reconstruir uma temporada (secao 22) sem que a chave da original
    // atrapalhe.
    assert.notEqual(chaveDeContribuicao("m", "s1", "p", 1), chaveDeContribuicao("m", "s2", "p", 1));
  });

  test("versao de politica diferente e outra contribuicao", () => {
    // Trocar a regra e recalcular vira uma contribuicao NOVA, com trilha propria,
    // em vez de uma reescrita silenciosa da antiga.
    assert.notEqual(chaveDeContribuicao("m", "s", "p", 1), chaveDeContribuicao("m", "s", "p", 2));
  });
});
