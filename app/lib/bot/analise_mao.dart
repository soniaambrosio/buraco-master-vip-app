// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — HandAnalyzer.
//
// Lê SOMENTE a própria mão e devolve a estrutura dela em números: quem encosta
// em quem, que corridas naturais existem, quanto é peso morto, quantos curingas
// há e QUANTO CUSTA perder cada carta. É a matéria-prima do descarte inteligente
// (§2) e da decisão de não baixar tudo que é legal (§4).
//
// NÃO decide legalidade e NÃO valida meld: quem valida é `meld_validator.dart`.
// Aqui é medição estrutural pura, sem regra e sem estado de mesa.
//
// Convenção sobre o "2": nesta análise ele conta como CURINGA, nunca como carta
// natural de corrida. É a leitura conservadora que a §3 pede — o 2 é recurso, e
// tratá-lo como carta comum faria a mão parecer mais estruturada do que é. O
// validador canônico continua livre para lê-lo contextualmente (A-2-3 etc.)
// quando o gerador propõe um meld de verdade.
import '../rules/estado.dart';
import '../rules/pontuacao_canonica.dart' show valorCarta;
import '../rules/rule_spec.dart';

const List<String> _ordemRank = [
  'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
];

/// Rank base 1..13 (A=1 .. K=13).
int rankBase(String valor) => _ordemRank.indexOf(valor) + 1;

/// CURINGA para a camada estratégica: decidido pelo VALOR, nunca pela flag.
///
/// `CartaSnapshot.curinga` copia o `ehCoringa` do legado, e existe estado real
/// (fixtures, snapshots antigos) onde um "2" chega com a flag em `false`. Se a
/// política "não descartar 2" dependesse da flag, ela falharia justamente nesse
/// estado. A autoridade canônica usa o mesmo critério por valor na sua poda.
bool ehCuringaEstrategico(CartaSnapshot c) =>
    c.valor == '2' || c.valor == 'JOKER';

/// Ranks possíveis de uma carta natural. O ÁS vale 1 (baixo) ou 14 (alto).
List<int> ranksNaturais(CartaSnapshot c) =>
    c.valor == 'A' ? const [1, 14] : <int>[rankBase(c.valor)];

/// Medida estrutural de UMA carta dentro da mão.
class LigacaoCarta {
  final String id;

  /// Cartas do mesmo naipe a exatamente 1 rank de distância.
  final int vizinhosDiretos;

  /// Cartas do mesmo naipe a exatamente 2 ranks (buraco tapável por curinga).
  final int vizinhosProximos;

  /// Cartas naturais de mesmo valor (embrião de trinca; 0 se a modalidade não
  /// permite trinca — sem trinca, valor repetido não é estrutura).
  final int iguais;

  /// Tamanho da maior corrida NATURAL contígua (mesmo naipe) que contém a carta.
  final int corridaNatural;

  const LigacaoCarta({
    required this.id,
    required this.vizinhosDiretos,
    required this.vizinhosProximos,
    required this.iguais,
    required this.corridaNatural,
  });

  /// Prêmio por participar de uma corrida natural. Mede POTENCIAL NÃO
  /// REALIZADO — e é por isso que ele sobe até 6 cartas e some em 7.
  ///
  /// A curva importa mais que os números:
  ///  • 2 cartas: embrião, vale proteger de descarte;
  ///  • 3 cartas: já é meld — na mão vale quase o mesmo que na mesa, e segurar
  ///    só adia pontos. Prêmio mínimo, de propósito;
  ///  • 5 a 6 cartas: uma ou duas cartas de uma canastra LIMPA de 200 pontos.
  ///    Desmontar isso para fazer jogo pequeno é o erro que a §4 nomeia;
  ///  • 7+: já É canastra. Não há mais potencial a proteger; segurá-la na mão é
  ///    perder os 200 pontos que ela vale na mesa. Prêmio ZERO.
  ///
  /// A primeira calibração usava um degrau em "≥ 3" e um prêmio sempre crescente.
  /// O resultado, medido em 10 rodadas completas, foi um bot que não baixava
  /// NADA: 7 canastras contra 64 do robô antigo e saldo negativo. Segurar tudo
  /// é uma forma de sabotagem tão real quanto baixar tudo.
  static int premioCorrida(int n) {
    switch (n) {
      case 2:
        return 4;
      case 3:
        return 1;
      case 4:
        return 8;
      case 5:
        return 27;
      case 6:
        return 40;
      default:
        return 0; // 0-1 sem corrida; 7+ já é canastra
    }
  }

  /// Força estrutural: quanto a mão perde ao entregar esta carta.
  int get forca =>
      vizinhosDiretos * 3 +
      vizinhosProximos * 1 +
      iguais * 2 +
      premioCorrida(corridaNatural);
}

/// POTENCIAL de canastra de uma sequência de `n` cartas, em PONTOS esperados.
///
/// É a mesma moeda dos bônus de canastra (limpa = 200), e é isso que permite
/// comparar "segurar na mão" com "baixar na mesa" sem inventar câmbio. A curva
/// cresce até 6 — uma carta da limpa — e ZERA em 7, porque aí o potencial virou
/// bônus de verdade e contá-lo de novo seria dupla contagem.
///
/// Foi a dupla contagem que produziu o pior defeito medido da primeira
/// calibração: o bot fazia jogos de 4, 5 e 6 cartas e PARAVA, porque estender
/// para 7 apagava um potencial que valia mais, na conta dele, que a canastra.
int potencialCanastra(int n) {
  if (n < 3) return 0;
  switch (n) {
    case 3:
      return 10;
    case 4:
      return 30;
    case 5:
      return 70;
    case 6:
      return 130;
    default:
      return 0; // 7+ já é canastra: o valor está no bônus, não no potencial
  }
}

/// Retrato estrutural da mão.
class AnaliseMao {
  final List<CartaSnapshot> mao;
  final List<CartaSnapshot> curingas;
  final Map<String, LigacaoCarta> ligacoes;

  /// Pontos das cartas SEM nenhuma ligação (peso morto).
  final int pontosDeadwood;

  /// LIGAÇÕES: soma das vizinhanças das cartas naturais + reserva dos curingas.
  /// Mede o quanto a mão está "encaixada", sem contar potencial de canastra.
  final int pontosEstrutura;

  /// POTENCIAL de canastra das corridas naturais da mão, em pontos esperados
  /// (mesma moeda de `potencialCanastra`). É contado UMA vez por corrida, não
  /// por carta: uma corrida de cinco é um potencial, não cinco.
  final int potencialCorridas;

  /// Pontos totais das cartas na mão (viram desconto se a rodada fechar).
  final int pontosMao;

  const AnaliseMao({
    required this.mao,
    required this.curingas,
    required this.ligacoes,
    required this.pontosDeadwood,
    required this.pontosEstrutura,
    required this.potencialCorridas,
    required this.pontosMao,
  });

  /// Valor estrutural de reserva de um curinga guardado na mão. Alto de
  /// propósito: §3 trata curinga como recurso, não como carta de encher jogo.
  static const int valorReservaCuringa = 9;

  /// Dano estrutural de entregar a carta `id`. Curinga tem dano proibitivo —
  /// ele nunca é "a carta de menor dano".
  int dano(String id) {
    final c = mao.where((x) => x.id == id);
    if (c.isEmpty) return 0;
    if (ehCuringaEstrategico(c.first)) return 1000;
    return ligacoes[id]?.forca ?? 0;
  }

  /// A carta participa de uma corrida natural de 3+ (potencial de canastra limpa)?
  bool emCorridaNatural(String id) => (ligacoes[id]?.corridaNatural ?? 0) >= 3;

  /// Analisa a mão. `spec` só decide se valor repetido conta como estrutura
  /// (trinca existe apenas no Fechado).
  factory AnaliseMao.analisar(List<CartaSnapshot> mao, RuleSpec spec) {
    final curingas = [for (final c in mao) if (ehCuringaEstrategico(c)) c];
    final naturais = [for (final c in mao) if (!ehCuringaEstrategico(c)) c];

    // Ranks presentes por naipe (conjunto, para corridas contíguas).
    final ranksPorNaipe = <String, Set<int>>{};
    for (final c in naturais) {
      final s = ranksPorNaipe.putIfAbsent(c.naipe ?? '', () => <int>{});
      s.addAll(ranksNaturais(c));
    }

    // Contagem por valor natural (embrião de trinca).
    final porValor = <String, int>{};
    for (final c in naturais) {
      porValor[c.valor] = (porValor[c.valor] ?? 0) + 1;
    }

    int corridaEm(Set<int> ranks, int r) {
      if (!ranks.contains(r)) return 0;
      var n = 1;
      for (var x = r - 1; ranks.contains(x); x--) {
        n++;
      }
      for (var x = r + 1; ranks.contains(x); x++) {
        n++;
      }
      return n;
    }

    final ligacoes = <String, LigacaoCarta>{};
    for (final c in naturais) {
      final ranks = ranksPorNaipe[c.naipe ?? ''] ?? const <int>{};
      var diretos = 0, proximos = 0, corrida = 0;
      for (final r in ranksNaturais(c)) {
        var d = 0, p = 0;
        if (ranks.contains(r - 1)) d++;
        if (ranks.contains(r + 1)) d++;
        if (ranks.contains(r - 2)) p++;
        if (ranks.contains(r + 2)) p++;
        // O Ás fica com a MELHOR das duas leituras (baixo/alto).
        if (d > diretos || (d == diretos && p > proximos)) {
          diretos = d;
          proximos = p;
        }
        final n = corridaEm(ranks, r);
        if (n > corrida) corrida = n;
      }
      final iguais = spec.trincaPermitida ? ((porValor[c.valor] ?? 1) - 1) : 0;
      ligacoes[c.id] = LigacaoCarta(
        id: c.id,
        vizinhosDiretos: diretos,
        vizinhosProximos: proximos,
        iguais: iguais,
        corridaNatural: corrida,
      );
    }

    var deadwood = 0, estrutura = 0;
    for (final c in naturais) {
      final f = ligacoes[c.id]!.forca;
      estrutura += f;
      if (f == 0) deadwood += valorCarta(c);
    }
    estrutura += curingas.length * valorReservaCuringa;

    // POTENCIAL por CORRIDA (uma vez cada), varrendo as corridas maximais de
    // cada naipe. Contar por carta inflaria o valor de segurar em proporção ao
    // tamanho da corrida — e foi assim que o bot deixou de baixar.
    var potencial = 0;
    for (final ranks in ranksPorNaipe.values) {
      final ordenados = ranks.toList()..sort();
      var i = 0;
      while (i < ordenados.length) {
        var fim = i;
        while (fim + 1 < ordenados.length &&
            ordenados[fim + 1] == ordenados[fim] + 1) {
          fim++;
        }
        potencial += potencialCanastra(fim - i + 1);
        i = fim + 1;
      }
    }

    return AnaliseMao(
      mao: [for (final c in mao) c.copia()],
      curingas: curingas,
      ligacoes: ligacoes,
      pontosDeadwood: deadwood,
      pontosEstrutura: estrutura,
      potencialCorridas: potencial,
      pontosMao: mao.fold<int>(0, (s, c) => s + valorCarta(c)),
    );
  }
}
