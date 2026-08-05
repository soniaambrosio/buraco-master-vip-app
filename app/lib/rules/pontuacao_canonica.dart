// C3 — pontuação canônica. SEM comportamento de produção: só a suíte de testes
// usa isto; o motor antigo (class Jogo) continua ativo em runtime.
//
// Valores/bônus fiéis à regra canônica (mesma tabela dos testes PONT do motor
// antigo):
//   Cartas: A=15, JOKER=50, 2=10, 8..K=10, 3..7=5.
//   Canastra (só o MAIOR bônus por canastra; cartas contadas à parte):
//     as_a_as=1000, de_500=500, limpa (7+ sem curinga)=200, suja (7+ com curinga)=100.
//     Trinca NUNCA é canastra (sem bônus), mas suas cartas pontuam normalmente.
//   Batida=+100; cartas na mão descontam pelo valor; morto NÃO pego (alguém
//     pegou e sem conversão)=-100.
// Pontos das cartas e bônus de canastra são somados SEPARADAMENTE — sem dupla contagem.
import 'estado.dart' show CartaSnapshot;
import 'rule_spec.dart';
import 'pontuacao.dart';
import 'meld/meld_validator.dart';

/// Valor de cada carta (tabela canônica).
int valorCarta(CartaSnapshot c) {
  switch (c.valor) {
    case 'A':
      return 15;
    case 'JOKER':
      return 50;
    case '2':
      return 10;
    case '8':
    case '9':
    case '10':
    case 'J':
    case 'Q':
    case 'K':
      return 10;
    default:
      return 5; // 3,4,5,6,7
  }
}

/// Soma dos valores das cartas (cada carta contada uma vez).
int pontosCartas(Iterable<CartaSnapshot> cartas) =>
    cartas.fold(0, (s, c) => s + valorCarta(c));

/// Bônus de canastra de UM meld (só o maior; NÃO inclui valor das cartas).
int bonusCanastra(ResultadoMeld m) {
  if (!m.valido || m.tipo != 'sequencia') return 0; // trinca nunca é canastra
  switch (m.classificacao) {
    case 'as_a_as':
      return 1000;
    case 'de_500':
      return 500;
    case 'limpa':
      return m.ordenado.length >= 7 ? 200 : 0;
    case 'suja':
      return m.ordenado.length >= 7 ? 100 : 0;
    default:
      return 0;
  }
}

/// Pontos de um meld: cartas (uma vez) + bônus de canastra (uma vez).
class PontosMeld {
  final int cartas;
  final int bonus;
  const PontosMeld(this.cartas, this.bonus);
  int get total => cartas + bonus;
}

PontosMeld pontosMeld(ResultadoMeld m) =>
    PontosMeld(pontosCartas(m.ordenado), bonusCanastra(m));

/// Entrada para pontuar UMA dupla numa rodada.
class EntradaRodada {
  final List<List<CartaSnapshot>> melds; // jogos baixados da dupla
  final List<CartaSnapshot> mao; // cartas restantes na mão da dupla
  final bool bateu;
  final bool mortoPego;
  final bool algumPegouMorto;
  final bool mortoConvertido;
  const EntradaRodada({
    this.melds = const [],
    this.mao = const [],
    this.bateu = false,
    this.mortoPego = false,
    this.algumPegouMorto = false,
    this.mortoConvertido = false,
  });
}

/// Detalhe da pontuação de uma dupla numa rodada (componentes separados para
/// testar cada parte e evitar dupla contagem).
class ResultadoRodada {
  final int cartas; // pontos das cartas baixadas
  final int canastras; // soma dos bônus de canastra
  final int batida; // 100 ou 0
  final int penalidadeMorto; // 100 (a subtrair) ou 0
  final int mao; // pontos das cartas na mão (a subtrair)
  const ResultadoRodada({
    required this.cartas,
    required this.canastras,
    required this.batida,
    required this.penalidadeMorto,
    required this.mao,
  });

  int get total => cartas + canastras + batida - penalidadeMorto - mao;

  /// Pontuação PARCIAL da rodada (integra com a acumulada da partida).
  PontuacaoRodada get parcial => PontuacaoRodada(
        melds: cartas,
        canastras: canastras,
        mao: mao,
        bonus: batida - penalidadeMorto,
      );
}

/// Pontua a rodada de uma dupla a partir dos jogos baixados, mão e flags.
ResultadoRodada pontuarRodada(EntradaRodada e, RuleSpec spec) {
  int cartas = 0, canastras = 0;
  for (final jogo in e.melds) {
    final r = validarJogoMesa(jogo, spec);
    if (!r.valido) continue; // meld ilegal não pontua
    cartas += pontosCartas(r.ordenado);
    canastras += bonusCanastra(r);
  }
  final batida = e.bateu ? 100 : 0;
  final penalidadeMorto =
      (!e.mortoPego && e.algumPegouMorto && !e.mortoConvertido) ? 100 : 0;
  return ResultadoRodada(
    cartas: cartas,
    canastras: canastras,
    batida: batida,
    penalidadeMorto: penalidadeMorto,
    mao: pontosCartas(e.mao),
  );
}

/// A partida encerra quando alguém cruza a meta e NÃO há empate exato
/// (empate na meta força rodada extra).
bool partidaEncerrada(PontuacaoPartida p, int metaPontos) =>
    (p.nos >= metaPontos || p.eles >= metaPontos) && p.nos != p.eles;
