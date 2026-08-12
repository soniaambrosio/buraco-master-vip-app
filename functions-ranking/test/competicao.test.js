/**
 * Prova a Politica Competitiva v1: quem compete, em que estado, por qual escada.
 *
 * Cobre a secao 33 nos blocos "Elegibilidade" (a parte que nao depende de
 * Firestore), "Colocacao", "Ligas" (os doze limites literais) e "Temporada"
 * (revalidacao de 5 e colocacao de 10).
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  POLITICA_COMPETITIVA_V1,
  AMBIENTE_COMPETITIVO,
  noAmbienteCompetitivo,
  ESTADOS_COMPETITIVOS,
  emQualificacao,
  partidasExigidas,
  kDoEstado,
  estadoApos,
  estadoCompetitivoDeJson,
  exigirEstadoCompetitivo,
  sementeDaTemporada,
  DEGRAUS_V1,
  ESCADA_V1,
  LADDER_V1_ID,
  escadaEmCodigo,
  resultadoElo,
  calcularDeltaV1,
  registrarPoliticaV1,
} = require("../lib/competicao");
const { conferirEscada, ligaDe } = require("../lib/ligas");
const { calculadoraDe, politicaDefinida, politicasRegistradas } = require("../lib/politica");
const { K_EM_QUALIFICACAO, K_CLASSIFICADO, softReset } = require("../lib/elo");

describe("politica: versionamento (secao 25)", () => {
  test("a v1 tem id e versao explicitos", () => {
    assert.equal(POLITICA_COMPETITIVA_V1.id, "competitiva");
    assert.equal(POLITICA_COMPETITIVA_V1.versao, 1);
  });

  test("a v1 NAO e a politica pendente", () => {
    // Secao 35: "`PoliticaDeRanking.pendente` deixar de ser a politica ativa".
    assert.equal(politicaDefinida(POLITICA_COMPETITIVA_V1), true);
  });

  test("registrar liga a calculadora, e o registro e idempotente", () => {
    registrarPoliticaV1();
    registrarPoliticaV1();
    assert.equal(calculadoraDe(POLITICA_COMPETITIVA_V1), calcularDeltaV1);
    assert.equal(
      politicasRegistradas().filter((p) => p === "competitiva@v1").length,
      1,
      "registrar duas vezes nao cria duas entradas"
    );
  });

  test("a politica pendente continua SEM calculadora", () => {
    // O mecanismo de pendencia nao foi desligado: uma temporada que declare
    // "nao_definida" continua sem pontuar.
    assert.equal(calculadoraDe({ id: "nao_definida", versao: 0 }), null);
  });
});

describe("elegibilidade: o ambiente competitivo (secoes 3, 5 e 6)", () => {
  test("so a mesa publica RANQUEADA alimenta o rating", () => {
    assert.deepEqual([...AMBIENTE_COMPETITIVO], ["publica_ranqueada"]);
    assert.equal(noAmbienteCompetitivo("publica_ranqueada"), true);
  });

  test("Mesa Publica casual esta fora (secao 3.1)", () => {
    assert.equal(noAmbienteCompetitivo("publica_casual"), false);
  });

  test("TORNEIO esta fora (secao 6)", () => {
    // O ponto mais facil de errar da OS inteira: no dominio Dart,
    // `TipoDePartida.alteraRanking` e `publicaRanqueada || torneio`. Reaproveitar
    // aquele campo sozinho faria toda partida de torneio pontuar Elo.
    assert.equal(noAmbienteCompetitivo("torneio"), false);
  });

  test("privada, treinamento e contra-robos continuam fora", () => {
    for (const tipo of ["privada", "treinamento", "contra_robos"]) {
      assert.equal(noAmbienteCompetitivo(tipo), false, tipo);
    }
  });

  test("tipo desconhecido esta fora — a lista e branca", () => {
    for (const tipo of ["", "nova_modalidade", "PUBLICA_RANQUEADA", "publica-ranqueada"]) {
      assert.equal(noAmbienteCompetitivo(tipo), false, tipo);
    }
  });
});

describe("estado competitivo (secoes 8 e 21)", () => {
  test("sao tres, e nenhum deles e uma Liga", () => {
    assert.deepEqual([...ESTADOS_COMPETITIVOS], [
      "em_colocacao",
      "em_revalidacao",
      "classificado",
    ]);
  });

  test("colocacao exige 10 e revalidacao exige 5", () => {
    assert.equal(partidasExigidas("em_colocacao"), 10);
    assert.equal(partidasExigidas("em_revalidacao"), 5);
    assert.equal(partidasExigidas("classificado"), 0);
  });

  test("os dois estados provisorios usam K=40; o consolidado usa K=24", () => {
    assert.equal(kDoEstado("em_colocacao"), K_EM_QUALIFICACAO);
    assert.equal(kDoEstado("em_revalidacao"), K_EM_QUALIFICACAO);
    assert.equal(kDoEstado("classificado"), K_CLASSIFICADO);
  });

  test("consolida EXATAMENTE na partida que completa a exigencia", () => {
    for (let n = 0; n < 10; n++) {
      assert.equal(estadoApos("em_colocacao", n), "em_colocacao", `${n} partidas`);
    }
    assert.equal(estadoApos("em_colocacao", 10), "classificado");
    assert.equal(estadoApos("em_colocacao", 11), "classificado");
  });

  test("a revalidacao consolida na quinta", () => {
    for (let n = 0; n < 5; n++) {
      assert.equal(estadoApos("em_revalidacao", n), "em_revalidacao", `${n} partidas`);
    }
    assert.equal(estadoApos("em_revalidacao", 5), "classificado");
  });

  test("quem consolidou nao volta a qualificar dentro da temporada", () => {
    // Secao 32: nao ha decay, nao ha protecao de liga e nao ha rebaixamento de
    // estado. A revalidacao acontece na virada, e nao dentro da temporada.
    assert.equal(estadoApos("classificado", 0), "classificado");
  });

  test("estado ilegivel cai em colocacao na LEITURA, e falha alto no CALCULO", () => {
    // Um standing gravado antes desta OS nao tem o campo — e quem o sistema nao
    // colocou esta, por definicao, em colocacao.
    assert.equal(estadoCompetitivoDeJson(undefined), "em_colocacao");
    assert.equal(estadoCompetitivoDeJson("liga_ouro"), "em_colocacao");
    assert.equal(estadoCompetitivoDeJson("classificado"), "classificado");
    // No calculo, o mesmo default daria K=40 a um classificado — delta errado,
    // gravado para sempre. Melhor nao pontuar.
    assert.throws(() => exigirEstadoCompetitivo("liga_ouro"));
    assert.equal(exigirEstadoCompetitivo("classificado"), "classificado");
  });
});

describe("semente: como se entra numa temporada (secoes 7, 20 e 21)", () => {
  test("jogador novo comeca em 1000, em colocacao, com 10 partidas", () => {
    assert.deepEqual(sementeDaTemporada(null), {
      rating: 1000,
      estado: "em_colocacao",
      qualificacaoExigida: 10,
    });
  });

  test("veterano entra com soft reset, em revalidacao, com 5 partidas", () => {
    assert.deepEqual(sementeDaTemporada({ seasonId: "2026-A", ratingFinal: 1700 }), {
      rating: 1420,
      estado: "em_revalidacao",
      qualificacaoExigida: 5,
    });
  });

  test("a semente do veterano e exatamente o soft reset, para qualquer final", () => {
    for (const final of [800, 1000, 1200, 1400, 1700, 2000]) {
      assert.equal(
        sementeDaTemporada({ seasonId: "x", ratingFinal: final }).rating,
        softReset(final)
      );
    }
  });

  test("quem nunca consolidou volta as 10 partidas, do 1000", () => {
    // Secao 21: a revalidacao e para "jogador que ja possuia classificacao
    // competitiva anterior". Quem entrou em novembro, jogou 4 das 10 e viu a
    // temporada acabar nunca teve uma — e o carimbo de consolidacao nunca foi
    // escrito para ele, entao ele chega aqui como `null`.
    const s = sementeDaTemporada(null);
    assert.equal(s.estado, "em_colocacao");
    assert.equal(s.qualificacaoExigida, 10);
  });
});

describe("ligas: a escada v1 (secoes 15 e 16)", () => {
  test("sao exatamente sete, nos nomes da OS", () => {
    assert.deepEqual(
      DEGRAUS_V1.map((d) => d.nome),
      ["Bronze", "Prata", "Ouro", "Platina", "Diamante", "Mestre", "Lenda"]
    );
  });

  test("a escada e valida: sem buraco, sem sobreposicao, sem ordem invertida", () => {
    const c = conferirEscada(DEGRAUS_V1);
    assert.equal(c.valida, true, c.detalhe ?? "");
  });

  test("as pontas sao abertas: Bronze sem piso, Lenda sem teto", () => {
    assert.equal(DEGRAUS_V1[0].pontosMinimos, null);
    assert.equal(DEGRAUS_V1[6].pontosMaximos, null);
  });

  test("OS DOZE LIMITES EXATOS DA SECAO 33", () => {
    // A lista literal da OS, um por um. Este e o teste que quebra se alguem
    // mexer num numero da escada.
    const casos = [
      [949, "bronze"],
      [950, "prata"],
      [1099, "prata"],
      [1100, "ouro"],
      [1249, "ouro"],
      [1250, "platina"],
      [1399, "platina"],
      [1400, "diamante"],
      [1549, "diamante"],
      [1550, "mestre"],
      [1699, "mestre"],
      [1700, "lenda"],
    ];
    for (const [rating, ligaId] of casos) {
      assert.equal(ligaDe(ESCADA_V1, rating)?.ligaId, ligaId, `rating ${rating}`);
    }
  });

  test("TODO rating tem Liga — nem o piso nem o teto deixam ninguem de fora", () => {
    // Consequencia das pontas abertas. Um piso inventado no Bronze deixaria uma
    // faixa inteira sem Liga nenhuma.
    for (const rating of [-5000, -1, 0, 1, 500, 1000, 3000, 99999]) {
      assert.notEqual(ligaDe(ESCADA_V1, rating), null, `rating ${rating} ficou sem liga`);
    }
  });

  test("o rating inicial cai em Prata", () => {
    // 1000 esta entre 950 e 1099. Nao e uma decisao desta suite — e a
    // consequencia das faixas da secao 15, e vale registrar porque e onde todo
    // jogador novo aparece assim que consolida.
    assert.equal(ligaDe(ESCADA_V1, 1000)?.ligaId, "prata");
  });

  test("NAO ha divisao, estrela nem ponto de promocao (secao 15)", () => {
    for (const d of DEGRAUS_V1) {
      assert.equal(/\b(I{1,3}|1|2|3)\b/.test(d.nome), false, `"${d.nome}" parece subdividido`);
      for (const proibido of ["divisao", "estrela", "promocao", "protecao", "shield"]) {
        assert.equal(proibido in d, false, `degrau tem "${proibido}"`);
      }
    }
  });

  test("o icone sai vazio nos sete — a arte nao foi inventada", () => {
    // A branch do cliente tem sete arquivos, mas o sexto se chama
    // `liga_imperial.webp` enquanto a secao 15 nomeia a sexta liga como MESTRE.
    // Amarrar as duas coisas seria inventar uma associacao de arte.
    assert.deepEqual([...new Set(DEGRAUS_V1.map((d) => d.icone))], [""]);
  });

  test("a escada e resolvida por CODIGO, pelo id da politica", () => {
    assert.equal(escadaEmCodigo(LADDER_V1_ID), ESCADA_V1);
    assert.equal(escadaEmCodigo("uma-escada-qualquer"), null);
  });

  test("os numeros aparecem UMA vez — a escada e a unica fonte", () => {
    // Secao 16: "Evitar espalhar numeros magicos em multiplos arquivos". A prova
    // possivel aqui e que os limites sejam derivaveis da escada, e nao redigitados:
    // cada teto e o piso do proximo menos um.
    for (let i = 0; i < DEGRAUS_V1.length - 1; i++) {
      assert.equal(DEGRAUS_V1[i].pontosMaximos + 1, DEGRAUS_V1[i + 1].pontosMinimos);
    }
  });
});

describe("ligas: escadas invalidas continuam sendo recusadas", () => {
  const degrau = (ligaId, min, max) => ({ ligaId, nome: ligaId, icone: "", pontosMinimos: min, pontosMaximos: max });

  test("buraco entre faixas", () => {
    const c = conferirEscada([degrau("a", null, 100), degrau("b", 200, null)]);
    assert.equal(c.recusa, "buraco_entre_faixas");
  });

  test("faixas sobrepostas", () => {
    const c = conferirEscada([degrau("a", null, 100), degrau("b", 50, null)]);
    assert.equal(c.recusa, "faixa_sobreposta");
  });

  test("piso aberto no MEIO da escada", () => {
    // Novo nesta OS, simetrico ao teto no meio: um piso aberto no meio engoliria
    // todas as faixas abaixo dele, porque `ligaDe` para no primeiro que aceita.
    const c = conferirEscada([degrau("a", 0, 100), degrau("b", null, null)]);
    assert.equal(c.recusa, "piso_no_meio");
  });

  test("teto aberto no meio da escada", () => {
    const c = conferirEscada([degrau("a", null, null), degrau("b", 200, null)]);
    assert.equal(c.recusa, "teto_no_meio");
  });

  test("liga duplicada", () => {
    const c = conferirEscada([degrau("a", null, 100), degrau("a", 101, null)]);
    assert.equal(c.recusa, "liga_duplicada");
  });

  test("duas ligas nunca respondem pelo mesmo rating", () => {
    // A propriedade que a secao 16 pede, exercitada sobre a escada oficial: para
    // cada rating, existe no maximo um degrau que o aceita.
    for (let r = 900; r <= 1750; r += 1) {
      const aceitam = DEGRAUS_V1.filter(
        (d) =>
          (d.pontosMinimos === null || r >= d.pontosMinimos) &&
          (d.pontosMaximos === null || r <= d.pontosMaximos)
      );
      assert.equal(aceitam.length, 1, `rating ${r} caiu em ${aceitam.length} ligas`);
    }
  });
});

describe("calculadora v1: o desfecho vira resultado (secoes 10, 12 e 14)", () => {
  test("vitoria, derrota e empate", () => {
    assert.equal(resultadoElo("norte", "norte"), 1);
    assert.equal(resultadoElo("sul", "norte"), 0);
    assert.equal(resultadoElo(null, "norte"), 0.5);
  });

  const entrada = (over) => ({
    matchId: "m1",
    userId: "u1",
    saldoAtual: 1000,
    estadoCompetitivo: "classificado",
    estado: "finalizada",
    motivoEncerramento: null,
    ladoVencedor: "norte",
    ladoDoJogador: "norte",
    placar: [
      { lado: "norte", pontos: 2000, canastrasLimpas: 3 },
      { lado: "sul", pontos: 0, canastrasLimpas: 0 },
    ],
    tipo: "publica_ranqueada",
    ratingsDaMinhaDupla: [1000, 1000],
    ratingsDaDuplaAdversaria: [1000, 1000],
    ...over,
  });

  test("duplas iguais, vitoria de classificado: +12", () => {
    assert.equal(calcularDeltaV1(entrada({})), 12);
  });

  test("o MESMO confronto com placar apertado da o MESMO delta (secao 11)", () => {
    // A afirmacao literal da secao 33: "duas vitorias contra o mesmo rating
    // adversario produzem o mesmo delta independentemente da diferenca de pontos".
    const goleada = calcularDeltaV1(
      entrada({
        placar: [
          { lado: "norte", pontos: 2000, canastrasLimpas: 5 },
          { lado: "sul", pontos: 0, canastrasLimpas: 0 },
        ],
      })
    );
    const apertada = calcularDeltaV1(
      entrada({
        placar: [
          { lado: "norte", pontos: 1005, canastrasLimpas: 1 },
          { lado: "sul", pontos: 1000, canastrasLimpas: 1 },
        ],
      })
    );
    const semPlacar = calcularDeltaV1(entrada({ placar: [] }));
    assert.equal(goleada, apertada);
    assert.equal(apertada, semPlacar);
    assert.equal(goleada, 12);
  });

  test("o K sai do estado do JOGADOR, nao do da dupla (secao 10)", () => {
    // Dois parceiros, mesma dupla, mesma expectativa, K diferente.
    const emColocacao = calcularDeltaV1(entrada({ estadoCompetitivo: "em_colocacao" }));
    const classificado = calcularDeltaV1(entrada({ estadoCompetitivo: "classificado" }));
    assert.equal(emColocacao, 20);
    assert.equal(classificado, 12);
  });

  test("a forca do PARCEIRO entra na conta (secao 9)", () => {
    // O mesmo jogador, o mesmo adversario, parceiros diferentes. Sem o rating do
    // parceiro, estes dois numeros seriam iguais — que era o defeito de
    // `saldosDosOponentes`, o campo que esta OS substituiu.
    const parceiroForte = calcularDeltaV1(
      entrada({ ratingsDaMinhaDupla: [1000, 1600], ratingsDaDuplaAdversaria: [1200, 1200] })
    );
    const parceiroFraco = calcularDeltaV1(
      entrada({ ratingsDaMinhaDupla: [1000, 800], ratingsDaDuplaAdversaria: [1200, 1200] })
    );
    assert.ok(
      parceiroForte < parceiroFraco,
      "com parceiro forte a dupla era favorita, entao a vitoria vale menos"
    );
  });

  test("os dois integrantes da dupla partem da MESMA expectativa (secao 9)", () => {
    const duplas = { ratingsDaMinhaDupla: [900, 1500], ratingsDaDuplaAdversaria: [1100, 1100] };
    const um = calcularDeltaV1(entrada({ ...duplas, saldoAtual: 900 }));
    const outro = calcularDeltaV1(entrada({ ...duplas, saldoAtual: 1500 }));
    assert.equal(um, outro, "a expectativa e do CONFRONTO, nao do jogador");
  });

  test("o WO passa pela formula padrao, sem multa (secao 14)", () => {
    // Partida `abandonada` com vencedor decretado: vitoria e derrota normais.
    // Nao ha termo extra, nao ha ponto a mais retirado.
    const vencedorDoWO = calcularDeltaV1(
      entrada({ estado: "abandonada", motivoEncerramento: "abandono" })
    );
    assert.equal(vencedorDoWO, 12, "identico a uma vitoria comum");

    const perdedorDoWO = calcularDeltaV1(
      entrada({ estado: "abandonada", motivoEncerramento: "abandono", ladoDoJogador: "sul" })
    );
    assert.equal(perdedorDoWO, -12, "identico a uma derrota comum");
  });

  test("nao ha vantagem por assinatura em lugar nenhum (secao 37)", () => {
    // A prova possivel e por ausencia: a entrada da calculadora nao tem campo de
    // VIP, entitlement ou assinatura, entao nao ha o que consultar.
    const campos = Object.keys(entrada({}));
    for (const proibido of ["vip", "assinante", "entitlement", "premium", "plano"]) {
      assert.equal(
        campos.some((c) => c.toLowerCase().includes(proibido)),
        false,
        `a entrada expoe "${proibido}"`
      );
    }
  });
});
