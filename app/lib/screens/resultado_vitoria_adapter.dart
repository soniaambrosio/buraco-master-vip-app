import 'resultado_partida_screen.dart';
import 'vitoria_celebracao.dart';

/// Monta a celebração a partir do resultado já confirmado pelo servidor/motor.
///
/// [assentosVencedores] deve vir da fonte autoritativa. Este adaptador não
/// compara placares para decidir vencedor e não conhece regra de parceria.
CelebracaoVitoriaVM celebracaoVitoriaDoResultado({
  required String eventoId,
  required bool fimPartida,
  required Set<int> assentosVencedores,
  required List<JogadorResultadoVM> jogadores,
  required bool somHabilitado,
  String efeitoId = 'confete_padrao',
}) {
  final vencedores = jogadores
      .where((jogador) => assentosVencedores.contains(jogador.assento))
      .toList(growable: false);

  final resultadoValido =
      fimPartida && eventoId.trim().isNotEmpty && vencedores.isNotEmpty;

  return CelebracaoVitoriaVM(
    eventoId: eventoId,
    ativa: resultadoValido,
    jogadorLocalVenceu:
        resultadoValido && vencedores.any((jogador) => jogador.souEu),
    nomesVencedores: vencedores.map((jogador) => jogador.nome).toList(),
    somHabilitado: somHabilitado,
    efeitoId: efeitoId,
  );
}
