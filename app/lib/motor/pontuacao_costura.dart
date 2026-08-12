// C10 — COSTURA de CLASSIFICAÇÃO e PONTUAÇÃO canônicas para o consumidor real.
//
// Sob autoridade única, quem classifica um meld e quem conta a rodada é o motor
// canônico (`rules/meld/meld_validator.dart` + `rules/pontuacao_canonica.dart`).
// Este arquivo é SÓ a costura: converte `Carta` (legado) -> `CartaSnapshot`
// (canônico), chama a autoridade e devolve o resultado no FORMATO que a UI
// aprovada já consome. NENHUMA regra e NENHUMA tabela de pontos vive aqui.
//
// Fecha a EXC-04 (grupo só de ases): a classificação deixa de ter dois donos
// (`Jogo._validarJogoMesa` × `validarJogoMesa`) na hora de pontuar. Passa a
// existir um só — o canônico.
import '../mesa.dart' show Carta;
import '../rules/estado.dart' show CartaSnapshot;
import '../rules/meld/meld_validator.dart';
import '../rules/pontuacao_canonica.dart';
import '../rules/rule_spec.dart';
import 'projecao_estado.dart' show modalidadeCanonicaDe;

/// RuleSpec canônica da partida a partir dos campos legados (`modalidade` como
/// texto + `metaPontos`). Reusa a MESMA conversão de modalidade da projeção —
/// a spec da pontuação é a spec da autoridade, não uma cópia.
RuleSpec specCanonicaDaPartida(String modalidadeLegado, int metaPontos) =>
    RuleSpec.canonica(modalidadeCanonicaDe(modalidadeLegado),
        metaPontos: metaPontos);

CartaSnapshot _cs(Carta c) => CartaSnapshot(c.id, c.naipe, c.valor, c.ehCoringa);

List<CartaSnapshot> cartasCanonicas(List<Carta> l) => [for (final c in l) _cs(c)];

/// Classificação canônica de um meld no VOCABULÁRIO que a UI aprovada já usa
/// ('limpa' | 'suja' | 'de_500' | 'as_a_as' | 'trinca' | 'aberta'), ou `null`
/// se o meld for ilegal.
///
/// O mapeamento reproduz exatamente o degrau de tamanho do motor antigo
/// (`_finalizar`): sequência com menos de 7 cartas é 'aberta' (não é canastra);
/// `de_500`/`as_a_as` são estruturais (13/14 cartas) e não passam por ele; a
/// trinca mantém o rótulo 'trinca' em qualquer tamanho, como no legado. Assim a
/// tarja, o som e a celebração da mesa continuam se comportando igual — o que
/// muda é QUEM decide a classificação.
String? tipoCanonicoDeMeld(List<Carta> meld, RuleSpec spec) {
  final r = validarJogoMesa(cartasCanonicas(meld), spec);
  if (!r.valido) return null;
  if (r.tipo == 'trinca') return 'trinca';
  final cls = r.classificacao;
  if (cls == 'as_a_as' || cls == 'de_500') return cls;
  return r.ordenado.length >= 7 ? cls : 'aberta';
}

/// Pontuação canônica de UMA dupla numa rodada, devolvida no MESMO formato do
/// mapa `pontosRodada[dupla]` que a tela de resultado já lê
/// (`total`, `canastras`, `bonusBatida`, `penalidadeMorto`, `descontoMao` e
/// `detalhe: {asAas, de500, limpas, sujas, baixadas}`).
///
/// Os valores vêm de `pontuarRodada` (autoridade canônica); o detalhe por tipo
/// de canastra é apenas a CONTAGEM dos melds já classificados pelo validador
/// canônico — nenhum bônus é recalculado aqui.
Map<String, dynamic> pontuarDuplaCanonico({
  required List<List<Carta>> melds,
  required List<Carta> mao,
  required bool bateu,
  required bool mortoPego,
  required bool algumPegouMorto,
  required bool mortoConvertido,
  required RuleSpec spec,
}) {
  final meldsCanonicos = [for (final m in melds) cartasCanonicas(m)];
  final r = pontuarRodada(
    EntradaRodada(
      melds: meldsCanonicos,
      mao: cartasCanonicas(mao),
      bateu: bateu,
      mortoPego: mortoPego,
      algumPegouMorto: algumPegouMorto,
      mortoConvertido: mortoConvertido,
    ),
    spec,
  );

  final det = {'asAas': 0, 'de500': 0, 'limpas': 0, 'sujas': 0, 'baixadas': 0};
  for (final m in meldsCanonicos) {
    final v = validarJogoMesa(m, spec);
    if (!v.valido) continue;
    if (bonusCanastra(v) == 0) continue; // trinca e melds curtos não são canastra
    switch (v.classificacao) {
      case 'as_a_as':
        det['asAas'] = det['asAas']! + 1;
        break;
      case 'de_500':
        det['de500'] = det['de500']! + 1;
        break;
      case 'limpa':
        det['limpas'] = det['limpas']! + 1;
        break;
      case 'suja':
        det['sujas'] = det['sujas']! + 1;
        break;
    }
  }
  det['baixadas'] = r.cartas;

  return {
    'total': r.total,
    'canastras': r.canastras,
    'bonusBatida': r.batida,
    // A UI mostra as subtrações com sinal negativo (contrato antigo preservado).
    'penalidadeMorto': -r.penalidadeMorto,
    'descontoMao': -r.mao,
    'detalhe': det,
  };
}

/// Pontos já GARANTIDOS na mesa (placar ao vivo, só exibição): cartas baixadas
/// + bônus de canastra, pela mesma autoridade canônica do fim de rodada — para
/// que o número exibido durante a rodada não discorde do número final.
int pontosMesaCanonico(List<List<Carta>> melds, RuleSpec spec) {
  var p = 0;
  for (final m in melds) {
    final v = validarJogoMesa(cartasCanonicas(m), spec);
    if (!v.valido) continue;
    p += pontosMeld(v).total;
  }
  return p;
}
