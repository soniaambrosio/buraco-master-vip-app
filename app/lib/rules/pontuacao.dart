// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// Ajuste obrigatório 7 — distinção EXPLÍCITA entre pontuação PARCIAL da rodada
// e pontuação ACUMULADA da partida.

/// Pontuação PARCIAL da rodada corrente (o que está em jogo NESTA rodada).
class PontuacaoRodada {
  final int melds; // pontos de cartas baixadas
  final int canastras; // bônus de canastras (limpa/suja)
  final int mao; // desconto das cartas restantes na mão
  final int bonus; // batida, morto, etc.

  const PontuacaoRodada({
    this.melds = 0,
    this.canastras = 0,
    this.mao = 0,
    this.bonus = 0,
  });

  int get total => melds + canastras + bonus - mao;
}

/// Pontuação ACUMULADA da partida (soma das rodadas), por dupla.
/// É esta que dispara a vulnerabilidade (limiar sobre o ACUMULADO).
class PontuacaoPartida {
  final int nos;
  final int eles;
  const PontuacaoPartida({this.nos = 0, this.eles = 0});

  PontuacaoPartida somarRodada(String dupla, PontuacaoRodada r) {
    if (dupla == 'nos') {
      return PontuacaoPartida(nos: nos + r.total, eles: eles);
    }
    return PontuacaoPartida(nos: nos, eles: eles + r.total);
  }

  int de(String dupla) => dupla == 'nos' ? nos : eles;
}
