import 'mesa_launch_spec.dart';

/// A mesa atual possui duas peles visuais: pública e premium.
///
/// Mesa Privada usa a pele premium por ser um ambiente VIP, mas continua com
/// contexto `privada`. Isso evita o erro semântico antigo de `else => VIP`:
/// compartilhar aparência não transforma a sala privada em Mesa VIP.
enum MesaRendererSkin { publica, premium }

enum MesaRuntimeContext { publica, vip, privada }

class MesaRendererContract {
  final MesaRendererSkin skin;
  final MesaRuntimeContext context;
  final MesaLaunchSpec launch;

  const MesaRendererContract({
    required this.skin,
    required this.context,
    required this.launch,
  });

  factory MesaRendererContract.fromLaunch(MesaLaunchSpec launch) {
    final context = switch (launch.visualVariant) {
      MesaVisualVariant.publica => MesaRuntimeContext.publica,
      MesaVisualVariant.vip => MesaRuntimeContext.vip,
      MesaVisualVariant.privada => MesaRuntimeContext.privada,
    };

    final skin = context == MesaRuntimeContext.publica
        ? MesaRendererSkin.publica
        : MesaRendererSkin.premium;

    return MesaRendererContract(
      skin: skin,
      context: context,
      launch: launch,
    );
  }

  bool get ehPrivada => context == MesaRuntimeContext.privada;
  bool get usaPelePremium => skin == MesaRendererSkin.premium;

  /// Controles sociais/privados dependem do contexto, nunca da pele.
  bool get habilitaContextoPrivado => ehPrivada;
}
