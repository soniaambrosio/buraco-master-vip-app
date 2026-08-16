import 'configurar_mesa_screen.dart';
import 'mesa_config_contract.dart';
import 'mesa_config_validator.dart';
import 'mesa_launch_spec.dart';
import 'mesa_renderer_contract.dart';
import 'preparando_partida_config_adapter.dart';
import 'preparando_partida_screen.dart';

/// Resultado único da camada visual/contratual antes da ligação autoritativa.
///
/// O host deve construir este objeto uma vez ao tocar em CRIAR MESA e entregar
/// suas partes para servidor/preparação/runtime. Isso evita recalcular cada
/// escolha em callbacks diferentes.
class MesaFlowPlan {
  final MesaConfigContract config;
  final MesaConfigValidation validation;
  final PreparandoPartidaVM preparacao;
  final MesaLaunchSpec launch;
  final MesaRendererContract renderer;

  const MesaFlowPlan({
    required this.config,
    required this.validation,
    required this.preparacao,
    required this.launch,
    required this.renderer,
  });

  factory MesaFlowPlan.fromVm(
    ConfigMesaVM vm, {
    List<JogadorPreparacaoVM>? jogadores,
  }) {
    final config = MesaConfigContract.fromVm(vm);
    final validation = validarMesaConfig(config);
    final preparacao = prepararPartidaDaConfiguracao(
      config,
      jogadores: jogadores,
    );
    final launch = MesaLaunchSpec.fromConfig(config);
    final renderer = MesaRendererContract.fromLaunch(launch);

    return MesaFlowPlan(
      config: config,
      validation: validation,
      preparacao: preparacao,
      launch: launch,
      renderer: renderer,
    );
  }

  bool get valido => validation.ok;

  /// O renderer/motor legado de app/lib/mesa.dart ainda nasceu com quatro
  /// assentos. Abrir uma partida 1 × 1 nele como se fosse 2 × 2 mascararia uma
  /// falha de integração. A preparação visual 1 × 1 pode existir, mas o runtime
  /// real só é liberado quando o adaptador autoritativo suportar dois jogadores.
  bool get podeUsarRuntimeLegado =>
      valido && launch.quantidadeJogadores == 4;

  bool get precisaMotorDoisJogadores =>
      valido && launch.quantidadeJogadores == 2;

  /// Pública usa a pele pública. VIP e Privada usam a pele premium, mantendo
  /// seus contextos separados no [renderer].
  String get legacyRendererSkinCode =>
      renderer.skin == MesaRendererSkin.publica ? 'publica' : 'vip';
}
