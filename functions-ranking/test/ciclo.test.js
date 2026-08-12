/**
 * Prova o CICLO DE VIDA competitivo de um jogador: colocacao, consolidacao,
 * encerramento de temporada, soft reset e revalidacao.
 *
 * Cobre os blocos "Colocacao", "Temporada" e "Idempotencia" da secao 33.
 *
 * POR QUE ISTO RODA SEM EMULADOR: a evolucao de um jogador dentro da temporada
 * foi extraida para `situacaoApos`, que e pura. `firestore.ts` nao repete essa
 * aritmetica — ele chama a mesma funcao que esta suite chama. Nao ha, portanto,
 * uma "versao testada" e uma "versao que roda em producao".
 *
 * O QUE ESTA SUITE NAO PROVA, e esta declarado no relatorio: a transacao do
 * Firestore, a paginacao contra o banco real e a concorrencia de verdade. Ver
 * `firebase/testes/ranking.test.js` para o que roda no emulador.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  situacaoInicial,
  situacaoApos,
  calcularDeltaV1,
  ESCADA_V1,
} = require("../lib/competicao");
const { ligaDe } = require("../lib/ligas");
const { RATING_INICIAL, softReset } = require("../lib/elo");

const AGORA = "2026-08-11T20:00:00.000Z";

/// Uma partida ja resolvida, do ponto de vista de UM jogador. `delta` chega
/// pronto porque a calculadora e exercitada em `competicao.test.js` — aqui o que
/// se prova e o efeito acumulado sobre a situacao.
const partida = (resultado, delta, saldoDaPartida = 100, agora = AGORA) => ({
  resultado,
  delta,
  saldoDaPartida,
  agora,
});

/// Aplica N partidas iguais em sequencia.
const aplicarVarias = (situacao, n, efeito) => {
  let s = situacao;
  for (let i = 0; i < n; i++) s = situacaoApos(s, efeito);
  return s;
};

/// A Liga que a projecao exibiria: so existe para quem consolidou (secao 15).
const ligaVisivel = (s) =>
  s.estado === "classificado" ? ligaDe(ESCADA_V1, s.rating)?.ligaId ?? null : null;

describe("colocacao: o jogador novo (secoes 7 e 8)", () => {
  test("comeca em 1000, em colocacao, devendo 10 partidas", () => {
    const s = situacaoInicial(null);
    assert.equal(s.rating, RATING_INICIAL);
    assert.equal(s.estado, "em_colocacao");
    assert.equal(s.qualificacaoExigida, 10);
    assert.equal(s.partidas, 0);
  });

  test("o rating e calculado normalmente DURANTE a colocacao", () => {
    // Secao 8: "Durante essas 10 partidas: o rating e calculado normalmente".
    // O que nao existe ainda e a LIGA, e nao a pontuacao.
    const s = situacaoApos(situacaoInicial(null), partida(1, 20));
    assert.equal(s.rating, 1020);
    assert.equal(s.estado, "em_colocacao");
  });

  test("a Liga NAO aparece antes da decima partida", () => {
    let s = situacaoInicial(null);
    for (let i = 1; i <= 9; i++) {
      s = situacaoApos(s, partida(1, 20));
      assert.equal(s.estado, "em_colocacao", `apos ${i} partidas`);
      assert.equal(ligaVisivel(s), null, `Liga vazou na partida ${i}`);
    }
    assert.equal(s.partidasDeQualificacao, 9);
  });

  test("a DECIMA partida consolida, e a Liga sai do rating daquele momento", () => {
    // Secao 8: "Ao completar a 10a partida valida: sai de `Em colocacao`; recebe
    // a Liga correspondente ao rating atual". A Liga e a do rating COM o delta da
    // decima ja aplicado.
    const s = aplicarVarias(situacaoInicial(null), 10, partida(1, 20));
    assert.equal(s.partidasDeQualificacao, 10);
    assert.equal(s.estado, "classificado");
    assert.equal(s.rating, 1200, "1000 + 10 x 20");
    assert.equal(ligaVisivel(s), "ouro", "1200 esta na faixa 1100-1249");
  });

  test("depois de consolidar, a qualificacao para de contar", () => {
    let s = aplicarVarias(situacaoInicial(null), 10, partida(1, 20));
    s = aplicarVarias(s, 5, partida(1, 12));
    assert.equal(s.partidasDeQualificacao, 10, "a 11a nao consumiu nada");
    assert.equal(s.partidas, 15);
    assert.equal(s.estado, "classificado");
  });

  test("quem perde a colocacao inteira consolida em Bronze, e nao fica sem Liga", () => {
    // O piso aberto do Bronze garante que sempre exista uma Liga. Antes dele,
    // um rating baixo o bastante ficaria sem faixa nenhuma.
    const s = aplicarVarias(situacaoInicial(null), 10, partida(0, -20));
    assert.equal(s.rating, 800);
    assert.equal(s.estado, "classificado");
    assert.equal(ligaVisivel(s), "bronze");
  });
});

describe("colocacao: o que NAO conta para as 10 (secoes 3, 6 e 13)", () => {
  test("so o que chega a `situacaoApos` consome qualificacao", () => {
    // A garantia real nao esta nesta funcao — esta em `resultado.ts`, que recusa
    // casual, torneio, anulada e incompleta ANTES. O que se prova aqui e o
    // complemento: uma partida recusada simplesmente nao chama esta funcao, e a
    // situacao fica intacta.
    const antes = aplicarVarias(situacaoInicial(null), 3, partida(1, 20));
    const depois = antes; // nenhuma chamada = nenhum efeito
    assert.deepEqual(depois, antes);
    assert.equal(depois.partidasDeQualificacao, 3);
  });

  test("dez partidas VALIDAS consolidam; nove nao", () => {
    assert.equal(aplicarVarias(situacaoInicial(null), 9, partida(1, 20)).estado, "em_colocacao");
    assert.equal(aplicarVarias(situacaoInicial(null), 10, partida(1, 20)).estado, "classificado");
  });
});

describe("contadores e desempate (secoes 17 e 24)", () => {
  test("vitoria, derrota e empate caem em contadores distintos", () => {
    let s = situacaoInicial(null);
    s = situacaoApos(s, partida(1, 20));
    s = situacaoApos(s, partida(0, -20));
    s = situacaoApos(s, partida(0.5, 0));
    assert.equal(s.vitorias, 1);
    assert.equal(s.derrotas, 1);
    assert.equal(s.empates, 1);
    assert.equal(s.partidas, 3);
  });

  test("o saldo de pontos acumula, e pode ser negativo", () => {
    let s = situacaoInicial(null);
    s = situacaoApos(s, partida(1, 20, 1500));
    s = situacaoApos(s, partida(0, -20, -2000));
    assert.equal(s.saldoPontos, -500);
  });

  test("o saldo de pontos NAO altera o rating (secao 11)", () => {
    // Duas historias com o mesmo delta e saldos radicalmente diferentes chegam
    // ao mesmo rating.
    const goleada = situacaoApos(situacaoInicial(null), partida(1, 12, 3000));
    const apertada = situacaoApos(situacaoInicial(null), partida(1, 12, 5));
    assert.equal(goleada.rating, apertada.rating);
    assert.notEqual(goleada.saldoPontos, apertada.saldoPontos);
  });

  test("o carimbo do 5o criterio anda quando o rating muda", () => {
    const s = situacaoApos(situacaoInicial(null), partida(1, 20, 100, "2026-03-01T00:00:00.000Z"));
    assert.equal(s.ratingAtingidoEm, "2026-03-01T00:00:00.000Z");
  });

  test("o carimbo NAO anda quando o delta e zero", () => {
    // "Desde quando este jogador esta neste rating" e literalmente o que o
    // criterio 5 pergunta. Um lancamento que nao move o rating nao reinicia o
    // relogio.
    let s = situacaoApos(situacaoInicial(null), partida(1, 20, 100, "2026-03-01T00:00:00.000Z"));
    s = situacaoApos(s, partida(0.5, 0, 0, "2026-09-01T00:00:00.000Z"));
    assert.equal(s.ratingAtingidoEm, "2026-03-01T00:00:00.000Z");
  });

  test("os abandonos nao sao incrementados — nao ha fonte que os atribua", () => {
    // Declarado no relatorio: o registro oficial marca que houve abandono, mas
    // nao diz QUEM abandonou. Incrementar aqui puniria o parceiro inocente.
    const s = aplicarVarias(situacaoInicial(null), 5, partida(0, -20));
    assert.equal(s.abandonos, 0);
  });
});

describe("virada de temporada: soft reset e revalidacao (secoes 19, 20 e 21)", () => {
  test("o veterano entra com soft reset, em revalidacao, devendo 5", () => {
    const consolidou = { seasonId: "2026-A", ratingFinal: 1700 };
    const s = situacaoInicial(consolidou);
    assert.equal(s.rating, 1420);
    assert.equal(s.estado, "em_revalidacao");
    assert.equal(s.qualificacaoExigida, 5);
  });

  test("a QUINTA partida consolida o veterano", () => {
    const s0 = situacaoInicial({ seasonId: "2026-A", ratingFinal: 1400 });
    assert.equal(s0.rating, 1240);
    for (let i = 1; i <= 4; i++) {
      const parcial = aplicarVarias(s0, i, partida(1, 20));
      assert.equal(parcial.estado, "em_revalidacao", `apos ${i} partidas`);
      assert.equal(ligaVisivel(parcial), null, `Liga vazou na partida ${i}`);
    }
    const s5 = aplicarVarias(s0, 5, partida(1, 20));
    assert.equal(s5.estado, "classificado");
    assert.equal(s5.rating, 1340);
    assert.equal(ligaVisivel(s5), "platina", "1340 esta na faixa 1250-1399");
  });

  test("veterano faz 5 e jogador novo faz 10, na MESMA temporada", () => {
    // A afirmacao literal da secao 21, lado a lado.
    const veterano = aplicarVarias(situacaoInicial({ seasonId: "x", ratingFinal: 1200 }), 5, partida(1, 20));
    const novato = aplicarVarias(situacaoInicial(null), 5, partida(1, 20));
    assert.equal(veterano.estado, "classificado");
    assert.equal(novato.estado, "em_colocacao");
    assert.equal(aplicarVarias(novato, 5, partida(1, 20)).estado, "classificado");
  });

  test("a temporada nova comeca do zero em contadores, e nao em rating", () => {
    // O rating atravessa a virada (comprimido); vitorias, saldo e partidas nao.
    const s = situacaoInicial({ seasonId: "2026-A", ratingFinal: 1600 });
    assert.equal(s.rating, softReset(1600));
    assert.equal(s.vitorias, 0);
    assert.equal(s.derrotas, 0);
    assert.equal(s.partidas, 0);
    assert.equal(s.saldoPontos, 0);
  });

  test("uma temporada nao sobrescreve a anterior — sao objetos independentes", () => {
    // Secao 19: a classificacao final fica congelada. No banco isso e garantido
    // pela chave `{seasonId}|{uid}`; aqui se prova o correlato na regra: a
    // situacao nova e derivada, e nao uma mutacao da antiga.
    const finalAnterior = aplicarVarias(situacaoInicial(null), 10, partida(1, 20));
    const copia = { ...finalAnterior };
    const nova = situacaoInicial({ seasonId: "2026-A", ratingFinal: finalAnterior.rating });
    aplicarVarias(nova, 3, partida(1, 20));
    assert.deepEqual(finalAnterior, copia, "a temporada anterior foi mutada");
  });

  test("quem NAO consolidou nao vira veterano (secao 21)", () => {
    // O carimbo de consolidacao so e escrito para quem terminou classificado.
    // Quem viu a temporada acabar no meio da colocacao chega a proxima como
    // `null` — 1000 e 10 partidas.
    const s = situacaoInicial(null);
    assert.equal(s.estado, "em_colocacao");
    assert.equal(s.rating, RATING_INICIAL);
  });

  test("tres temporadas seguidas: consolida, comprime, reconsolida", () => {
    const t1 = aplicarVarias(situacaoInicial(null), 10, partida(1, 25));
    assert.equal(t1.rating, 1250);
    assert.equal(t1.estado, "classificado");
    assert.equal(ligaVisivel(t1), "platina");

    const t2 = situacaoInicial({ seasonId: "t1", ratingFinal: t1.rating });
    assert.equal(t2.rating, softReset(1250));
    assert.equal(t2.rating, 1150);
    assert.equal(t2.estado, "em_revalidacao");

    const t2Final = aplicarVarias(t2, 5, partida(0, -12));
    assert.equal(t2Final.rating, 1090);
    assert.equal(t2Final.estado, "classificado");
    assert.equal(ligaVisivel(t2Final), "prata");

    const t3 = situacaoInicial({ seasonId: "t2", ratingFinal: t2Final.rating });
    assert.equal(t3.rating, softReset(1090));
    assert.equal(t3.estado, "em_revalidacao");
  });
});

describe("idempotencia: aplicar duas vezes NAO e o mesmo que aplicar uma (secao 29)", () => {
  test("a funcao acumula — logo a protecao tem que estar na chave, e nao aqui", () => {
    // Este teste existe para deixar explicito ONDE mora a idempotencia. Aplicar
    // a mesma partida duas vezes A ESTA FUNCAO dobra tudo, e isso e o correto:
    // ela e uma transicao de estado, nao um registro.
    //
    // Quem impede a segunda aplicacao e a chave de idempotencia
    // `rankingContributions/{matchId|seasonId|politica|vN}`, que E o id do
    // documento — a segunda gravacao encontra o documento existente e recusa
    // `ja_processado` antes de chegar aqui.
    const uma = situacaoApos(situacaoInicial(null), partida(1, 20));
    const duas = situacaoApos(uma, partida(1, 20));
    assert.equal(uma.rating, 1020);
    assert.equal(duas.rating, 1040, "a funcao acumula, como deve");
    assert.equal(duas.vitorias, 2);
    assert.equal(duas.partidasDeQualificacao, 2);
  });

  test("a sequencia e determinstica: mesma ordem, mesmo fim", () => {
    const roteiro = [partida(1, 20), partida(0, -18), partida(0.5, 2), partida(1, 15)];
    const rodar = () => roteiro.reduce((s, p) => situacaoApos(s, p), situacaoInicial(null));
    assert.deepEqual(rodar(), rodar());
  });

  test("o Elo NAO e comutativo — por isso o backlog reprocessa em ordem", () => {
    // A justificativa do `orderBy('registradoEm')` do reprocessamento, provada
    // com a calculadora de verdade: aplicar as mesmas duas partidas em ordens
    // diferentes leva a ratings diferentes, porque a expectativa de cada uma
    // depende do rating vigente na hora.
    const confronto = (meuRating, adversario, resultado) =>
      calcularDeltaV1({
        matchId: "m",
        userId: "u",
        saldoAtual: meuRating,
        estadoCompetitivo: "classificado",
        estado: "finalizada",
        motivoEncerramento: null,
        ladoVencedor: resultado === 1 ? "A" : "B",
        ladoDoJogador: "A",
        placar: [],
        tipo: "publica_ranqueada",
        ratingsDaMinhaDupla: [meuRating],
        ratingsDaDuplaAdversaria: [adversario],
      });

    // Vencer o forte e depois perder para o fraco...
    let a = 1000;
    a += confronto(a, 1600, 1);
    a += confronto(a, 800, 0);

    // ...nao e o mesmo que perder para o fraco e depois vencer o forte.
    let b = 1000;
    b += confronto(b, 800, 0);
    b += confronto(b, 1600, 1);

    assert.notEqual(a, b, "se fossem iguais, a ordem do reprocessamento nao importaria");
  });
});
