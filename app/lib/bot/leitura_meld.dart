// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1.
//
// LEITURA de jogos PÚBLICOS: perguntas que os modelos de parceiro e adversário
// fazem sobre um meld que está na mesa. Tudo aqui é informação pública.
//
// A pergunta "esta carta ESTENDE este jogo?" NÃO é respondida por regra
// própria: delega para `validarJogoMesa`, a mesma autoridade que o motor usa.
// A pergunta "esta carta é ADJACENTE?" é heurística declarada — mede vizinhança
// de rank, não legalidade, e por isso vive aqui e não em `rules/`.
import '../rules/estado.dart';
import '../rules/meld/meld_validator.dart';
import '../rules/rule_spec.dart';
import 'analise_mao.dart' show ehCuringaEstrategico, ranksNaturais;

/// A carta ESTENDE legalmente o meld? Resposta da autoridade canônica.
bool estendeMeld(List<CartaSnapshot> meld, CartaSnapshot carta, RuleSpec spec) =>
    validarJogoMesa([...meld, carta], spec).valido;

/// O meld é uma canastra LIMPA (ou de_500 / as-a-ás) já formada (7+)?
bool ehCanastraLimpa(List<CartaSnapshot> meld, RuleSpec spec) {
  final r = validarJogoMesa(meld, spec);
  if (!r.valido || r.tipo != 'sequencia') return false;
  return r.classificacao == 'de_500' ||
      r.classificacao == 'as_a_as' ||
      (r.classificacao == 'limpa' && r.ordenado.length >= 7);
}

/// O meld está LIMPO (sem curinga), independentemente do tamanho? É o "forte
/// potencial de limpa" que a §3 manda não destruir.
bool ehLimpoAindaQuePequeno(List<CartaSnapshot> meld, RuleSpec spec) {
  final r = validarJogoMesa(meld, spec);
  if (!r.valido || r.tipo != 'sequencia') return false;
  return r.qtdCuringas == 0;
}

/// O meld é canastra (7+ sequência) de qualquer classificação?
bool ehCanastra(List<CartaSnapshot> meld, RuleSpec spec) {
  final r = validarJogoMesa(meld, spec);
  return r.valido && r.tipo == 'sequencia' && r.ordenado.length >= 7;
}

/// A carta é ADJACENTE ao meld — mesma família, encostando nas pontas sem ainda
/// ser extensão legal. Serve para "guardar o que o parceiro vai precisar" e para
/// "não entregar o que completa o adversário".
///
/// Sequência: mesmo naipe e rank a até 2 casas de uma das pontas do intervalo
/// natural do jogo. Trinca: mesmo valor.
bool adjacenteAoMeld(
    List<CartaSnapshot> meld, CartaSnapshot carta, RuleSpec spec) {
  if (ehCuringaEstrategico(carta)) return false;
  final r = validarJogoMesa(meld, spec);
  if (!r.valido) return false;
  if (r.tipo == 'trinca') {
    return meld.isNotEmpty && meld.first.valor == carta.valor;
  }
  if (r.naipeCanonico == null || carta.naipe != r.naipeCanonico) return false;
  // Quem é curinga DENTRO do meld quem diz é o validador canônico (um "2"
  // pode estar ali como natural). Deduzir pelo valor aqui erraria o intervalo.
  final idsCuringa = {
    for (final u in r.usos)
      if (u.papel == 'curinga') u.id
  };
  final naturais = [
    for (final c in r.ordenado)
      if (!idsCuringa.contains(c.id)) c
  ];
  if (naturais.isEmpty) return false;
  var minR = 99, maxR = -1;
  for (final c in naturais) {
    for (final k in ranksNaturais(c)) {
      if (k < minR) minR = k;
      if (k > maxR) maxR = k;
    }
  }
  for (final k in ranksNaturais(carta)) {
    if (k >= minR && k <= maxR) continue; // já coberto pelo intervalo
    if (k >= minR - 2 && k <= maxR + 2) return true;
  }
  return false;
}
