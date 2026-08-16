import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_flow_plan.dart';
import '../lib/screens/mesa_renderer_contract.dart';

void main() {
  group('MesaFlowPlan', () {
    test('4 jogadores pode chegar ao runtime legado preservando contexto', () {
      final plan = MesaFlowPlan.fromVm(
        ConfigMesaVM.mock(tipo: TipoMesa.privada),
      );

      expect(plan.valido, isTrue);
      expect(plan.launch.quantidadeJogadores, 4);
      expect(plan.podeUsarRuntimeLegado, isTrue);
      expect(plan.precisaMotorDoisJogadores, isFalse);
      expect(plan.renderer.context, MesaRuntimeContext.privada);
      expect(plan.renderer.skin, MesaRendererSkin.premium);
      expect(plan.legacyRendererSkinCode, 'vip');
      expect(plan.preparacao.jogadores, hasLength(4));
    });

    test('2 jogadores não é falsificado como partida de 4 no runtime antigo', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
        modo: ModoJogo.dois,
        aposta: const ApostaVM(
          valor: 500,
          opcoes: [0, 500, 1000, 5000],
          pote: 1000,
        ),
      );
      final plan = MesaFlowPlan.fromVm(vm);

      expect(plan.valido, isTrue);
      expect(plan.launch.quantidadeJogadores, 2);
      expect(plan.preparacao.jogadores, hasLength(2));
      expect(plan.podeUsarRuntimeLegado, isFalse);
      expect(plan.precisaMotorDoisJogadores, isTrue);
    });

    test('configuração inválida nunca recebe autorização do plano', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);
      final cadeiras = List<CadeiraVM>.of(vm.cadeiras!);
      cadeiras[1] = cadeiras[1].copyWith(
        ehVip: false,
        passeConvidadoVip: false,
      );

      final plan = MesaFlowPlan.fromVm(vm.copyWith(cadeiras: cadeiras));

      expect(plan.valido, isFalse);
      expect(plan.podeUsarRuntimeLegado, isFalse);
      expect(
        plan.validation.erros,
        contains('PRIVADA_PARTICIPANTE_SEM_VIP_OU_PASSE:convidado'),
      );
    });
  });
}
