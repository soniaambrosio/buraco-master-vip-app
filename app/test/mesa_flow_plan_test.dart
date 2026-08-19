import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_flow_plan.dart';
import '../lib/screens/mesa_renderer_contract.dart';

void main() {
  group('MesaFlowPlan', () {
  // AS DUAS TRAVESSIAS ABAIXO DECLARAM `ehVip: true`, e isso nao e remendo
  // para ficar verde: e a instrucao escrita na propria `ConfigMesaVM.mock`.
  //
  // O padrao do mock era `true`, e a autoridade dos tipos de mesa o inverteu de
  // proposito — "um mock e FONTE DE DADOS DE EXEMPLO; ele nao pode ser fonte de
  // autorizacao, e ausencia de informacao nao pode significar direito". Estes
  // casos foram escritos antes daquela inversao e herdavam o VIP em silencio.
  //
  // O que eles medem continua sendo o PLANO DE TRAVESSIA (runtime legado para 4,
  // motor novo para 2, contexto e skin preservados), e nao a elegibilidade. Para
  // medir a travessia de uma mesa privada e preciso ter direito a ela; quem prova
  // que o direito nao se inventa e o terceiro caso deste arquivo, mais
  // `test/mesa/gate_vip_selecao_test.dart` no cliente e `functions-mesas` no
  // servidor.
    test('4 jogadores pode chegar ao runtime legado preservando contexto', () {
      final plan = MesaFlowPlan.fromVm(
        ConfigMesaVM.mock(tipo: TipoMesa.privada, ehVip: true),
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
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada, ehVip: true).copyWith(
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
