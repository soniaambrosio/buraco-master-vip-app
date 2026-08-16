/**
 * Prova QUEM pode alimentar o rating de temporada — o bloco "Elegibilidade" da
 * secao 33, e as secoes 3, 4, 5, 6, 12, 13 e 14 da OS da Politica Competitiva v1.
 *
 * SEPARADO DE `resultado.test.js` DE PROPOSITO: aquela suite prova a LEITURA do
 * documento oficial e a mecanica de idempotencia, que sao anteriores a esta OS e
 * nao mudaram. Esta prova a REGRA DE PRODUTO nova, que e onde um erro custa caro
 * — uma Mesa Publica pontuando ou um torneio alimentando o Elo.
 *
 * O PRINCIPIO QUE ESTA SUITE TRAVA (secao 37):
 *   Mesa Publica e o jogo casual. Mesa VIP/Ranqueada e o campeonato.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const { resultadoDeJson, decidirProcessamento, ladosDaMesa } = require("../lib/resultado");

/// Um documento `matches/{id}` como `RegistroDePartida.toJson()` o grava:
/// mesa publica ranqueada, finalizada, dupla A contra dupla B, A venceu.
const REGISTRO = {
  matchId: "m-elegivel",
  estado: "finalizada",
  tipo: "publica_ranqueada",
  alteraRanking: true,
  motivoEncerramento: "objetivo_atingido",
  ladoVencedor: "A",
  encerradaEm: "2026-08-11T20:00:00.000Z",
  participantes: [
    { classe: "humano", userId: "u1", assento: 0, lado: "A" },
    { classe: "humano", userId: "u2", assento: 1, lado: "B" },
    { classe: "humano", userId: "u3", assento: 2, lado: "A" },
    { classe: "humano", userId: "u4", assento: 3, lado: "B" },
    { classe: "robo", botId: "bot-7", assento: 4 },
    { classe: "espectador", userId: "u9" },
  ],
  placar: [
    { lado: "A", pontos: 3000, canastrasLimpas: 2 },
    { lado: "B", pontos: 1500, canastrasLimpas: 0 },
  ],
};

const comoRegistro = (over) => resultadoDeJson({ ...REGISTRO, ...over });

const decidirCom = (registro, extra = {}) =>
  decidirProcessamento({
    resultado: registro,
    jaProcessado: false,
    temporadaVigente: "2026-A",
    temporadaEncerrada: false,
    temCalculadora: true,
    ...extra,
  });

describe("mesa: agrupamento por lado (secao 9)", () => {
  test("duas duplas de dois viram dois lados", () => {
    const mesa = ladosDaMesa(comoRegistro({}).competidores);
    assert.notEqual(mesa, null);
    assert.deepEqual([...mesa.lados].sort(), ["A", "B"]);
    assert.deepEqual(mesa.porLado.get("A"), ["u1", "u3"]);
    assert.deepEqual(mesa.porLado.get("B"), ["u2", "u4"]);
  });

  test("robo e espectador ficam de fora dos lados", () => {
    const mesa = ladosDaMesa(comoRegistro({}).competidores);
    const todos = [...mesa.porLado.values()].flat();
    assert.equal(todos.includes("u9"), false, "espectador entrou na dupla");
    assert.equal(todos.length, 4);
  });

  test("competidor sem lado derruba a mesa inteira", () => {
    assert.equal(ladosDaMesa([{ userId: "u1", lado: "A" }, { userId: "u2", lado: null }]), null);
  });

  test("um lado so, ou tres, nao e confronto de duas duplas", () => {
    assert.equal(ladosDaMesa([{ userId: "u1", lado: "A" }, { userId: "u2", lado: "A" }]), null);
    assert.equal(
      ladosDaMesa([
        { userId: "u1", lado: "A" },
        { userId: "u2", lado: "B" },
        { userId: "u3", lado: "C" },
      ]),
      null
    );
  });
});

describe("elegibilidade: quem NAO pode pontuar (secoes 3, 6 e 13)", () => {
  test("Mesa Publica CASUAL nunca pontua", () => {
    // Delta zero, recusa definitiva, SEM backlog: ela nunca vai pontuar, entao
    // guardar criaria uma fila sem saida.
    const d = decidirCom(comoRegistro({ tipo: "publica_casual", alteraRanking: false }));
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "nao_pontua");
    assert.equal(d.guardarNoBacklog, false);
  });

  test("TORNEIO nao alimenta este rating, mesmo com alteraRanking VERDADEIRO", () => {
    // O TESTE QUE A SECAO 6 MANDA CRIAR, e o mais importante desta suite.
    //
    // No dominio Dart, `TipoDePartida.alteraRanking` e `publicaRanqueada ||
    // torneio` — uma partida de torneio chega aqui com o campo verdadeiro. Sem a
    // guarda de ambiente competitivo, ela pontuaria Elo, e o defeito seria
    // invisivel: os numeros pareceriam plausiveis.
    const d = decidirCom(comoRegistro({ tipo: "torneio", alteraRanking: true }));
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "fora_do_ambiente_competitivo");
    assert.equal(d.guardarNoBacklog, false);
  });

  test("privada, treinamento e contra-robos ficam de fora", () => {
    for (const tipo of ["privada", "treinamento", "contra_robos"]) {
      const d = decidirCom(comoRegistro({ tipo, alteraRanking: true }));
      assert.equal(d.processa, false, tipo);
      assert.equal(d.recusa, "fora_do_ambiente_competitivo", tipo);
    }
  });

  test("tipo novo e desconhecido nao pontua — a lista e branca", () => {
    const d = decidirCom(comoRegistro({ tipo: "modalidade_futura", alteraRanking: true }));
    assert.equal(d.recusa, "fora_do_ambiente_competitivo");
  });

  test("partida ANULADA nao pontua (secao 13)", () => {
    const d = decidirCom(comoRegistro({ estado: "cancelada", alteraRanking: false }));
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "nao_pontua");
  });

  test("partida INCOMPLETA nao pontua (secao 13)", () => {
    for (const estado of ["criada", "aguardando", "ativa", "reconectando"]) {
      const d = decidirCom(comoRegistro({ estado }));
      assert.equal(d.processa, false, estado);
      assert.equal(d.recusa, "nao_terminal", estado);
      assert.equal(d.guardarNoBacklog, false, estado);
    }
  });

  test("mesa inconsistente e recusada em vez de pontuada torto", () => {
    const semLado = comoRegistro({
      participantes: [
        { classe: "humano", userId: "u1", lado: "A" },
        { classe: "humano", userId: "u2" },
      ],
    });
    assert.equal(decidirCom(semLado).recusa, "lados_inconsistentes");
  });

  test("vencedor que nao esta na mesa e desfecho indefinido", () => {
    assert.equal(decidirCom(comoRegistro({ ladoVencedor: "Z" })).recusa, "desfecho_indefinido");
  });
});

describe("elegibilidade: quem PODE pontuar (secoes 5, 12 e 14)", () => {
  test("mesa publica ranqueada, finalizada, com vencedor: processa", () => {
    const d = decidirCom(comoRegistro({}));
    assert.equal(d.processa, true);
    assert.equal(d.recusa, null);
  });

  test("EMPATE oficial (finalizada sem vencedor) processa (secao 12)", () => {
    // A calculadora trata como 0.5 para os dois lados. Se o dominio produz ou
    // nao esse desfecho e assunto do dominio; aqui so nao se recusa um desfecho
    // que a autoridade declarou.
    assert.equal(decidirCom(comoRegistro({ ladoVencedor: null })).processa, true);
  });

  test("WO decretado (abandonada COM vencedor) processa como partida normal", () => {
    // Secao 14: "a dupla perdedora recebe derrota normal; a vencedora recebe
    // vitoria normal". Nao ha desvio de fluxo e nao ha multa.
    const d = decidirCom(
      comoRegistro({ estado: "abandonada", motivoEncerramento: "abandono", ladoVencedor: "A" })
    );
    assert.equal(d.processa, true);
  });

  test("abandono SEM vencedor decretado nao pontua (secoes 13 e 14)", () => {
    // Trata-lo como empate daria 0.5 a quem abandonou. Sem decreto da autoridade
    // nao ha desfecho, e sem desfecho o delta e zero.
    const d = decidirCom(comoRegistro({ estado: "abandonada", ladoVencedor: null }));
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "desfecho_indefinido");
  });
});

describe("elegibilidade: a natureza da partida e imutavel (secao 4)", () => {
  test("casual reclassificada como ranqueada e recusada", () => {
    // O caminho por onde uma casual viraria ranqueada depois do resultado:
    // alguem edita `tipo` no documento oficial e pede reprocessamento.
    const d = decidirCom(comoRegistro({}), { naturezaObservada: "publica_casual" });
    assert.equal(d.processa, false);
    assert.equal(d.recusa, "natureza_alterada");
    assert.equal(d.guardarNoBacklog, false);
  });

  test("ranqueada reclassificada como casual tambem e recusada", () => {
    // O sentido inverso importa igual: seria o jeito de apagar do ranking um
    // resultado ruim.
    const d = decidirCom(comoRegistro({ tipo: "publica_casual", alteraRanking: false }), {
      naturezaObservada: "publica_ranqueada",
    });
    assert.equal(d.processa, false);
  });

  test("natureza inalterada nao atrapalha o reprocessamento", () => {
    const d = decidirCom(comoRegistro({}), { naturezaObservada: "publica_ranqueada" });
    assert.equal(d.processa, true);
  });

  test("primeira observacao processa normalmente", () => {
    assert.equal(decidirCom(comoRegistro({}), { naturezaObservada: null }).processa, true);
  });
});

describe("elegibilidade: backlog e recusa definitiva (secoes 13 e 26)", () => {
  test("so falta-de-peca vai para o backlog", () => {
    // Backlog e para o que AINDA PODE pontuar: nao ha temporada, a temporada
    // fechou, ou a politica nao existe.
    assert.equal(decidirCom(comoRegistro({}), { temporadaVigente: null }).guardarNoBacklog, true);
    assert.equal(decidirCom(comoRegistro({}), { temporadaEncerrada: true }).guardarNoBacklog, true);
    assert.equal(decidirCom(comoRegistro({}), { temCalculadora: false }).guardarNoBacklog, true);
  });

  test("nenhuma recusa de elegibilidade vai para o backlog", () => {
    const casos = [
      comoRegistro({ tipo: "publica_casual", alteraRanking: false }),
      comoRegistro({ tipo: "torneio" }),
      comoRegistro({ estado: "ativa" }),
      comoRegistro({ estado: "abandonada", ladoVencedor: null }),
    ];
    for (const r of casos) {
      assert.equal(decidirCom(r).guardarNoBacklog, false, `${r.tipo}/${r.estado}`);
    }
  });

  test("a elegibilidade e reavaliada ANTES da idempotencia", () => {
    // SECAO 26: "Mesa publica antiga no backlog deve terminar em delta
    // zero/recusa coerente — nunca passar a pontuar retroativamente". Como as
    // guardas de elegibilidade correm contra o documento oficial ATUAL e vem
    // antes de `jaProcessado`, nao existe caminho pelo qual um item guardado sob
    // regras antigas pontue agora.
    const d = decidirCom(comoRegistro({ tipo: "torneio" }), { jaProcessado: true });
    assert.equal(d.recusa, "fora_do_ambiente_competitivo");
  });

  test("uma partida valida ja processada continua sendo recusa benigna", () => {
    const d = decidirCom(comoRegistro({}), { jaProcessado: true });
    assert.equal(d.recusa, "ja_processado");
    assert.equal(d.benigna, true);
    assert.equal(d.guardarNoBacklog, false);
  });
});
