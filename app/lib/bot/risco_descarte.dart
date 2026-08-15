// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — §2/§7 OpponentModel + DiscardRisk.
//
// Mede o RISCO de uma carta ir ao lixo, usando exclusivamente sinais públicos:
// os jogos já baixados dos adversários, o tamanho das mãos, quem já pegou morto
// e o tamanho do lixo. Nunca lê a mão de ninguém — a `VisaoInformacao` sequer
// carrega as mãos alheias, então "ler" não é uma opção disponível.
//
// O modelo trabalha com PROBABILIDADE DECLARADA, não com leitura absoluta: ele
// nunca afirma "o adversário tem o 7 de copas". Ele afirma "esta carta completa
// um jogo que está na mesa" (fato público) ou "esta carta encosta num jogo que
// está na mesa" (vizinhança pública), e pesa isso pela ameaça visível.
import '../rules/estado.dart';
import '../rules/pontuacao_canonica.dart' show valorCarta;
import '../rules/rule_spec.dart';
import 'leitura_meld.dart';
import 'visao_informacao.dart';

/// Composição do risco de UM descarte (cada parcela é auditável em separado).
class RiscoDoDescarte {
  /// A carta ESTENDE um jogo público adversário (o pior caso).
  final bool alimentaJogoAdversario;

  /// A carta ENCOSTA num jogo público adversário.
  final bool adjacenteAJogoAdversario;

  /// Há ameaça imediata visível (mão curta, ou morto pego + canastra na mesa).
  final bool ameacaImediata;

  /// Quantas cartas o adversário levaria junto se pegasse o lixo agora.
  final int volumeDoLixo;

  /// Pontos que a carta entrega se for aproveitada.
  final int pontosEntregues;

  const RiscoDoDescarte({
    required this.alimentaJogoAdversario,
    required this.adjacenteAJogoAdversario,
    required this.ameacaImediata,
    required this.volumeDoLixo,
    required this.pontosEntregues,
  });

  /// Nota agregada de risco (0 = seguro). Escala deliberadamente pequena e
  /// inteira: os pesos ficam em `PesosHeuristicos`, não escondidos aqui.
  int get nota {
    var n = 0;
    if (alimentaJogoAdversario) n += 6;
    if (adjacenteAJogoAdversario) n += 2;
    if (ameacaImediata) n += 2;
    if (pontosEntregues >= 10) n += 1;
    // Entregar o lixo INTEIRO é pior que entregar uma carta. O volume só pesa
    // quando a carta é realmente aproveitável pelo adversário.
    if (alimentaJogoAdversario && volumeDoLixo >= 4) n += 2;
    return n;
  }
}

class ModeloAdversario {
  final VisaoInformacao visao;
  final RuleSpec spec;

  // MEMÓRIA por carta. Os jogos públicos não mudam durante uma decisão, então
  // a resposta para a mesma carta é sempre a mesma — e ela é cara: cada consulta
  // roda o validador canônico uma vez por jogo exposto. Sem cache, uma decisão
  // com centenas de planos revalida as mesmas cartas centenas de vezes.
  final Map<String, RiscoDoDescarte> _cache = {};

  ModeloAdversario(this.visao, this.spec);

  /// Ameaça imediata dos adversários, medida só por sinal público.
  bool get ameacaImediata {
    if (visao.menorMaoAdversaria <= 3) return true;
    if (!visao.mortoPegoAdversaria) return false;
    for (final m in visao.meldsAdversarios) {
      if (ehCanastra(m, spec)) return true;
    }
    return false;
  }

  /// A carta completa/estende um jogo público adversário?
  bool alimenta(CartaSnapshot c) {
    for (final m in visao.meldsAdversarios) {
      if (estendeMeld(m, c, spec)) return true;
    }
    return false;
  }

  /// A carta encosta num jogo público adversário?
  bool adjacente(CartaSnapshot c) {
    for (final m in visao.meldsAdversarios) {
      if (adjacenteAoMeld(m, c, spec)) return true;
    }
    return false;
  }

  /// Risco completo de descartar `c` agora (memoizado por carta).
  RiscoDoDescarte avaliar(CartaSnapshot c) => _cache.putIfAbsent(
        c.id,
        () => RiscoDoDescarte(
          alimentaJogoAdversario: alimenta(c),
          adjacenteAJogoAdversario: adjacente(c),
          ameacaImediata: ameacaImediata,
          volumeDoLixo: visao.lixoTamanho,
          pontosEntregues: valorCarta(c),
        ),
      );
}
