import 'package:flutter/material.dart';

import 'vitoria_celebracao.dart';

/// Wrapper neutro para acoplar a celebração ao resultado sem duplicar o layout
/// aprovado de ResultadoPartidaScreen.
class ResultadoPartidaCelebrado extends StatelessWidget {
  final Widget resultado;
  final CelebracaoVitoriaVM celebracao;

  const ResultadoPartidaCelebrado({
    super.key,
    required this.resultado,
    required this.celebracao,
  });

  @override
  Widget build(BuildContext context) {
    return CelebracaoVitoriaLayer(
      vm: celebracao,
      child: resultado,
    );
  }
}
