// alvo_minimo.dart — o piso de área tocável das telas da casca.
//
// ---------------------------------------------------------------------------
// POR QUE UM HELPER, E POR QUE ELE É TÃO PEQUENO
// ---------------------------------------------------------------------------
//
// Três telas — Início, Onde jogar e Perfil — tinham cada uma o seu piso: 28,
// 30, 34, 36, 40, 47. Nenhum deles era decisão; eram o tamanho que o ícone
// tinha por dentro. Um número escrito num lugar só faz a próxima tela nascer
// certa, e dá ao portão o que citar.
//
// O QUE ELE NÃO FAZ, e isso é o desenho: não recebe callback, não envolve
// gesto e não decide disponibilidade. Ele só empurra as restrições de layout.
// Quem manda no toque continua sendo o widget de dentro — este helper é
// incapaz de criar, desviar ou engolir uma navegação.

import 'package:flutter/widgets.dart';

/// O piso de área tocável adotado nas telas da casca, em pontos lógicos.
///
/// 48 é o mesmo número que o Flutter usa em `kMinInteractiveDimension` e que a
/// WCAG 2.5.8 pede como alvo mínimo. Não é um alvo "confortável": é o chão.
const double kAlvoMinimoDeToque = 48.0;

/// Garante [kAlvoMinimoDeToque] em volta de [child], sem mexer no desenho dele.
///
/// O filho continua com o tamanho que sempre teve — o que cresce é a caixa que
/// o cerca, e é ela que o `InkWell` de fora passa a cobrir. Por isso o uso
/// correto é `InkWell(onTap: ..., child: AlvoMinimo(child: <o visual>))`: ao
/// contrário, o piso ficaria por fora do gesto e não valeria de nada.
class AlvoMinimo extends StatelessWidget {
  const AlvoMinimo({
    super.key,
    required this.child,
    this.largura = kAlvoMinimoDeToque,
    this.altura = kAlvoMinimoDeToque,
  });

  final Widget child;
  final double largura;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: largura, minHeight: altura),
      // Os fatores 1.0 impedem que o Center estufe até o limite máximo: ele
      // fica do tamanho do filho e sobe até o piso, nunca além.
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
