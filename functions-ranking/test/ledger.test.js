/**
 * Prova a mecanica de lancamento: a invariante, a chave de idempotencia e a
 * recusa de cadeia rompida.
 *
 * Cobre a secao 23 ("Pontuacao": primeira partida, vitoria, derrota, empate,
 * multiplas partidas) usando DELTAS EXPLICITOS — o teste diz quanto vale cada
 * lancamento em vez de perguntar a uma formula. E deliberado: a formula nao
 * existe, e a mecanica precisa ser provavel sem ela.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  chaveDeLancamento,
  aplicarLancamento,
  lancamentoDeJson,
  conferirCadeia,
  exigeAutoridade,
  LancamentoIncoerente,
  MOTIVOS,
} = require("../lib/ledger");

const POLITICA = { id: "somente-para-teste", versao: 1 };

const aplicar = (extra) =>
  aplicarLancamento({
    matchId: "m1",
    userId: "u1",
    motivo: "resultado_de_partida",
    seasonId: "2026-A",
    saldoAtual: 0,
    delta: 0,
    registradoEm: "2026-08-11T20:00:00.000Z",
    politica: POLITICA,
    ...extra,
  });

describe("ledger: a chave de idempotencia", () => {
  test("e matchId|userId|motivo", () => {
    assert.equal(
      chaveDeLancamento("m1", "u1", "resultado_de_partida"),
      "m1|u1|resultado_de_partida"
    );
  });

  test("a MESMA partida do MESMO jogador produz a MESMA chave", () => {
    // A linha que impede ranking aplicado duas vezes: como a chave e o id do
    // documento, a segunda gravacao e a mesma escrita.
    assert.equal(
      chaveDeLancamento("m1", "u1", "resultado_de_partida"),
      chaveDeLancamento("m1", "u1", "resultado_de_partida")
    );
  });

  test("o motivo separa estorno de resultado", () => {
    // Sem o motivo na chave, o estorno seria recusado como duplicata do
    // lancamento que ele estorna.
    assert.notEqual(
      chaveDeLancamento("m1", "u1", "resultado_de_partida"),
      chaveDeLancamento("m1", "u1", "estorno")
    );
  });

  test("jogadores diferentes da mesma partida nao colidem", () => {
    assert.notEqual(
      chaveDeLancamento("m1", "u1", "resultado_de_partida"),
      chaveDeLancamento("m1", "u2", "resultado_de_partida")
    );
  });
});

describe("ledger: a invariante antes + delta == depois", () => {
  test("primeira partida, a partir de zero", () => {
    const l = aplicar({ delta: 25 });
    assert.equal(l.rankingBefore, 0);
    assert.equal(l.rankingDelta, 25);
    assert.equal(l.rankingAfter, 25);
  });

  test("delta negativo (derrota, pela politica que vier)", () => {
    const l = aplicar({ saldoAtual: 100, delta: -30 });
    assert.equal(l.rankingAfter, 70);
  });

  test("delta zero e REGISTRADO, e nao omitido", () => {
    // Registrar o zero prova que a partida foi avaliada. Nao registrar deixaria
    // "avaliada e nao mudou nada" indistinguivel de "nunca foi processada".
    const l = aplicar({ saldoAtual: 40, delta: 0 });
    assert.equal(l.rankingAfter, 40);
    assert.equal(l.rankingDelta, 0);
  });

  test("o saldo pode ficar negativo — o piso e decisao de produto", () => {
    const l = aplicar({ saldoAtual: 10, delta: -50 });
    assert.equal(l.rankingAfter, -40);
  });

  test("`depois` nao e parametro: nao ha como informar um que nao feche", () => {
    const l = aplicar({ saldoAtual: 7, delta: 5, rankingAfter: 999 });
    assert.equal(l.rankingAfter, 12);
  });

  test("delta fracionario e recusado", () => {
    // Ponto flutuante no ledger para de fechar sozinho depois de algumas centenas
    // de lancamentos.
    assert.throws(() => aplicar({ delta: 1.5 }), LancamentoIncoerente);
    assert.throws(() => aplicar({ saldoAtual: 0.1, delta: 1 }), LancamentoIncoerente);
  });

  test("lancamento sem partida, jogador ou temporada e recusado", () => {
    assert.throws(() => aplicar({ matchId: "" }), /sem partida/);
    assert.throws(() => aplicar({ userId: "" }), /sem jogador/);
    assert.throws(() => aplicar({ seasonId: "" }), /sem temporada/);
  });
});

describe("ledger: autoridade declarada", () => {
  test("os motivos que exigem autoridade sao correcao e estorno", () => {
    assert.deepEqual(MOTIVOS.filter(exigeAutoridade), [
      "correcao_administrativa",
      "estorno",
    ]);
  });

  test("correcao sem responsavel e recusada", () => {
    assert.throws(
      () => aplicar({ motivo: "correcao_administrativa", delta: 10 }),
      /exige autoridade declarada/
    );
  });

  test("lancamento automatico com autoridade tambem e recusado", () => {
    // Carimbar um responsavel num lancamento automatico e mentir sobre quem
    // decidiu — e a mentira ficaria na trilha de auditoria.
    assert.throws(
      () => aplicar({ motivo: "resultado_de_partida", autoridade: "admin1" }),
      /nao tem autoridade a declarar/
    );
  });

  test("correcao com responsavel passa", () => {
    const l = aplicar({ motivo: "correcao_administrativa", delta: 10, autoridade: "admin1" });
    assert.equal(l.autoridade, "admin1");
  });
});

describe("ledger: releitura revalida", () => {
  test("ida e volta preserva tudo", () => {
    const original = aplicar({ saldoAtual: 30, delta: 12 });
    const lido = lancamentoDeJson(JSON.parse(JSON.stringify(original)));
    assert.deepEqual(lido, original);
  });

  test("documento adulterado e recusado NA LEITURA", () => {
    // Alguem subiu `rankingAfter` sem mexer no delta. Sem esta revalidacao, o
    // numero adulterado viraria saldo.
    const adulterado = { ...aplicar({ saldoAtual: 0, delta: 10 }), rankingAfter: 9999 };
    assert.throws(() => lancamentoDeJson(adulterado), /incoerente/);
  });

  test("chave que nao corresponde aos campos e recusada", () => {
    const trocado = { ...aplicar({ delta: 5 }), chaveIdempotencia: "outra|coisa|estorno" };
    assert.throws(() => lancamentoDeJson(trocado), /nao corresponde aos campos/);
  });

  test("motivo desconhecido e recusado", () => {
    const estranho = { ...aplicar({ delta: 5 }), motivo: "porque_sim" };
    assert.throws(() => lancamentoDeJson(estranho), /motivo desconhecido/);
  });
});

describe("ledger: a cadeia de multiplas partidas", () => {
  /// Encadeia deltas explicitos, como o servidor faz: cada lancamento parte do
  /// `depois` do anterior.
  function cadeia(deltas) {
    let saldo = 0;
    return deltas.map((delta, i) => {
      const l = aplicar({ matchId: `m${i}`, saldoAtual: saldo, delta });
      saldo = l.rankingAfter;
      return l;
    });
  }

  test("uma sequencia bem formada confere", () => {
    assert.equal(conferirCadeia(cadeia([25, -10, 0, 40, -5])), null);
  });

  test("o saldo final e a dobra da sequencia", () => {
    const c = cadeia([25, -10, 0, 40, -5]);
    assert.equal(c[c.length - 1].rankingAfter, 50);
  });

  test("cadeia vazia confere e vale o saldo inicial", () => {
    assert.equal(conferirCadeia([]), null);
    assert.equal(conferirCadeia([], 100), null);
  });

  test("um lancamento faltando no meio e DETECTADO", () => {
    // O caso real: uma escrita parcial que perdeu um documento. Sem a
    // conferencia, o saldo simplesmente estaria errado e nada acusaria.
    const c = cadeia([10, 20, 30]);
    const comBuraco = [c[0], c[2]];
    assert.match(conferirCadeia(comBuraco), /parte de 30 e a sequencia estava em 10/);
  });

  test("um lancamento repetido no meio e DETECTADO", () => {
    const c = cadeia([10, 20]);
    assert.notEqual(conferirCadeia([c[0], c[0], c[1]]), null);
  });
});
