// elo.ts — A ARITMETICA DA POLITICA COMPETITIVA V1. Puro, sem banco e sem relogio.
//
// Este arquivo e a resposta as secoes 9, 10, 11 e 20 da OS DA POLITICA
// COMPETITIVA V1, e ele existe separado de `competicao.ts` por um motivo
// pratico: aqui nao ha nenhuma decisao sobre QUEM pontua, so sobre QUANTO. Uma
// funcao deste arquivo nao sabe o que e uma Mesa Publica, um torneio ou uma
// partida anulada — quando ela e chamada, a elegibilidade ja foi decidida.
//
// TUDO AQUI E DETERMINISTICO E SEM ESTADO. Nao ha `Math.random`, nao ha
// `Date.now`, nao ha leitura de configuracao. E o que permite reprocessar o
// backlog (secao 26) e obter exatamente os mesmos numeros que a execucao
// original obteve, meses depois, com o mesmo codigo.
//
// ---------------------------------------------------------------------------
// O QUE NAO ENTRA NA CONTA, E ISSO E REGRA E NAO ESQUECIMENTO
// ---------------------------------------------------------------------------
// SECAO 11: a diferenca de pontos da partida NAO multiplica o delta. Ganhar de
// 2.000 a 0 e ganhar de 100 a 90 valem o mesmo delta contra o mesmo adversario.
// Nenhuma funcao deste arquivo recebe placar — a impossibilidade e de assinatura,
// e nao uma disciplina que alguem precisa lembrar de manter. O saldo de pontos e
// registrado em outro lugar (estatistica e desempate), e nao chega ate aqui.
//
// SECAO 14: nao ha multa de Elo por abandono. O WO decretado pelo servidor entra
// como vitoria/derrota normal e passa por estas mesmas funcoes, sem desvio.
// Sancao pertence ao dominio de moderacao.
//
// E nao ha, em lugar nenhum: multiplicador VIP, bonus de sequencia, decay por
// inatividade, protecao de liga ou vantagem por assinatura. O jogador paga para
// PARTICIPAR da competicao, nunca para ter vantagem dentro dela.

/// Rating de partida do jogador que nunca competiu (secao 7).
export const RATING_INICIAL = 1000;

/// Fator K de quem ainda esta sendo localizado pelo sistema — colocacao (secao
/// 8) e revalidacao (secao 21).
///
/// POR QUE O MESMO K PARA OS DOIS ESTADOS, que e uma interpretacao e precisa
/// estar declarada como tal: a secao 10 nomeia dois fatores, "em colocacao" (40)
/// e "ja classificado" (24), e a secao 21 criou um terceiro estado — revalidacao
/// — sem lhe atribuir um K. A leitura adotada e que a divisao real da secao 10 e
/// entre PROVISORIO e CONSOLIDADO: os dois estados provisorios sao periodos em
/// que o sistema ainda nao sabe onde o jogador esta, que e exatamente para o que
/// um K alto serve. A alternativa (revalidacao com K=24) faria o veterano sair
/// do soft reset preso a um rating que ele levaria o dobro de partidas para
/// corrigir, esvaziando o proposito da revalidacao.
///
/// A decisao esta isolada nesta constante de proposito: se o produto decidir o
/// contrario, muda-se uma linha em `kDoEstado` e nada mais.
export const K_EM_QUALIFICACAO = 40;

/// Fator K de quem ja consolidou a Liga (secao 10).
export const K_CLASSIFICADO = 24;

/// Partidas ranqueadas validas para consolidar a Liga pela primeira vez (secao 8).
export const PARTIDAS_DE_COLOCACAO = 10;

/// Partidas ranqueadas validas para reconsolidar na temporada seguinte (secao 21).
export const PARTIDAS_DE_REVALIDACAO = 5;

/// Quanto da distancia ao rating inicial o jogador conserva na virada (secao 20).
export const FATOR_SOFT_RESET = 0.6;

/// O divisor classico do Elo. Uma diferenca de 400 pontos entre as duplas
/// significa expectativa de 10 para 1 a favor da mais forte.
export const DIVISOR_ELO = 400;

/// O resultado de UM lado da mesa, como o Elo o entende (secao 10).
///
/// Nao ha um quarto valor. Partida anulada, incompleta ou inconsistente nao
/// chega aqui — ela e recusada antes, em `resultado.ts`, e produz delta zero por
/// nao ser processada (secao 13).
export type ResultadoElo = 1 | 0.5 | 0;

// ---------------------------------------------------------------------------
// ARREDONDAMENTO
// ---------------------------------------------------------------------------

/// Arredonda meio para LONGE DE ZERO.
///
/// POR QUE NAO `Math.round`, que seria o obvio: `Math.round` arredonda meio para
/// CIMA, o que trata os dois lados da mesa de forma diferente. Numa partida
/// perfeitamente equilibrada com K=25, o vencedor receberia `round(+12.5) = +13`
/// e o perdedor `round(-12.5) = -12` — a mesa inteira ganharia um ponto do nada,
/// a cada partida, para sempre. Repetido por milhoes de partidas, isso e inflacao
/// de rating por defeito de arredondamento, e ela e invisivel ate o dia em que
/// todo mundo esta em Lenda.
///
/// Meio para longe de zero e SIMETRICO: `+12.5 -> +13` e `-12.5 -> -13`. A soma
/// dos deltas de uma partida equilibrada continua sendo zero.
///
/// O rating e guardado como INTEIRO (a exigencia vem de `aplicarLancamento`, que
/// recusa ponto flutuante no ledger para que a soma `antes + delta == depois`
/// nao pare de fechar depois de algumas centenas de lancamentos). Entao o
/// arredondamento acontece exatamente uma vez, no delta final, e nunca nos
/// valores intermediarios — arredondar a media da dupla ou a expectativa
/// introduziria erro antes da multiplicacao por K.
export function arredondarMeioLongeDeZero(valor: number): number {
  if (!Number.isFinite(valor)) {
    throw new Error(`arredondamento recebeu ${valor}, que nao e um numero finito`);
  }
  return valor < 0 ? -Math.round(-valor) : Math.round(valor);
}

// ---------------------------------------------------------------------------
// FORCA DA DUPLA (secao 9)
// ---------------------------------------------------------------------------

/// A forca de um lado da mesa: media aritmetica do rating de quem o compoe.
///
/// NAO E ARREDONDADA. Uma dupla de 1200 e 1401 vale 1300.5, e esse meio ponto
/// entra inteiro na expectativa. Arredondar aqui faria duas duplas distintas
/// (1200+1401 e 1200+1400) produzirem a mesma expectativa, e o rating do parceiro
/// deixaria de importar em metade dos casos.
///
/// Funciona para lados de um ou de dois jogadores: a media de uma lista de um
/// elemento e o proprio elemento. A secao 9 fala em dupla porque o Buraco e
/// jogado em dupla, mas nada aqui exige exatamente dois — e nada aqui INVENTA
/// suporte a outro formato: quem decide quantos lados e quantos jogadores por
/// lado existem e o registro oficial da partida.
export function ratingDaDupla(ratings: ReadonlyArray<number>): number {
  if (ratings.length === 0) {
    throw new Error("um lado da mesa sem jogador nao tem forca a calcular");
  }
  let soma = 0;
  for (const r of ratings) soma += r;
  return soma / ratings.length;
}

// ---------------------------------------------------------------------------
// A FORMULA (secao 10)
// ---------------------------------------------------------------------------

/// Expectativa de vitoria da dupla `minha` contra a dupla `adversaria`.
///
///     E = 1 / (1 + 10^((Ra - Rm) / 400))
///
/// Elo convencional, sem alteracao. Devolve um numero entre 0 e 1 exclusive.
///
/// OS DOIS INTEGRANTES DE UMA DUPLA RECEBEM A MESMA EXPECTATIVA, porque ela e
/// uma propriedade do CONFRONTO e nao do jogador (secao 9: "cada integrante da
/// mesma dupla parte da mesma expectativa de resultado referente a forca media do
/// confronto"). O que difere entre eles e o K, que e individual.
export function expectativa(ratingMinhaDupla: number, ratingDuplaAdversaria: number): number {
  const diferenca = (ratingDuplaAdversaria - ratingMinhaDupla) / DIVISOR_ELO;
  return 1 / (1 + Math.pow(10, diferenca));
}

/// O delta de UM jogador, ja arredondado para inteiro.
///
///     delta = K x (resultado real - resultado esperado)
///
/// E so isso. Nao ha termo de placar, nao ha bonus, nao ha piso e nao ha teto.
///
/// As consequencias que a secao 33 exige testar caem todas fora desta unica
/// linha, sem nenhum caso especial: o favorito tem `esperado` alto, entao ganha
/// pouco ao vencer e perde muito ao perder; o azarao tem `esperado` baixo, entao
/// ganha muito ao vencer e perde pouco ao perder.
export function deltaElo(params: {
  k: number;
  resultado: ResultadoElo;
  esperado: number;
}): number {
  return arredondarMeioLongeDeZero(params.k * (params.resultado - params.esperado));
}

// ---------------------------------------------------------------------------
// SOFT RESET (secao 20)
// ---------------------------------------------------------------------------

/// O rating com que um veterano comeca a temporada seguinte.
///
///     novoRating = 1000 + 0.60 x (ratingFinalAnterior - 1000)
///
/// Comprime a distancia ao centro em 40%, nos dois sentidos: quem terminou acima
/// de 1000 desce um pouco, quem terminou abaixo sobe um pouco, e quem terminou
/// exatamente em 1000 nao se move. NAO E ZERAR — a secao 20 e explicita ("Nao
/// zerar todos para 1000"), e o motivo e que zerar jogaria fora a informacao que
/// custou uma temporada inteira para ser obtida.
///
/// Os cinco exemplos obrigatorios da secao 20 dao inteiro exato (1700->1420,
/// 1400->1240, 1200->1120, 1000->1000, 800->880), entao o arredondamento nao
/// aparece neles. Ele existe para os outros: 1701 x 0.6 nao e inteiro, e o rating
/// precisa ser.
export function softReset(ratingFinalAnterior: number): number {
  return arredondarMeioLongeDeZero(
    RATING_INICIAL + FATOR_SOFT_RESET * (ratingFinalAnterior - RATING_INICIAL)
  );
}
