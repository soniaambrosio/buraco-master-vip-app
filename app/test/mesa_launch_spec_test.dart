import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';
import '../lib/screens/mesa_launch_spec.dart';
import '../lib/screens/mesa_renderer_contract.dart';

void main() {
  group('MesaLaunchSpec — fronteira Preparando -> Mesa', () {
    test('Pública preserva configuração e não vira premium', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.publica).copyWith(
        modalidade: ModalidadeJogo.sbtl,
        modo: ModoJogo.dois,
        pontos: 3000,
        tempo: 30,
        chat: ChatMesa.soBaloes,
      );
      final spec = MesaLaunchSpec.fromConfig(MesaConfigContract.fromVm(vm));
      final renderer = MesaRendererContract.fromLaunch(spec);

      expect(spec.visualVariant, MesaVisualVariant.publica);
      expect(spec.modalidade, 'STBL');
      expect(spec.quantidadeJogadores, 2);
      expect(spec.metaPontos, 3000);
      expect(spec.tempoSegundos, 30);
      expect(spec.chat, ChatMesa.soBaloes);
      expect(spec.apostaMoedas, isNull);
      expect(spec.ehPublica, isTrue);
      expect(renderer.context, MesaRuntimeContext.publica);
      expect(renderer.skin, MesaRendererSkin.publica);
      expect(renderer.habilitaContextoPrivado, isFalse);
    });

    test('VIP preserva aposta e usa pele premium', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip).copyWith(
        aposta: const ApostaVM(
          valor: 1000,
          opcoes: [0, 500, 1000, 5000],
          pote: 4000,
        ),
      );
      final spec = MesaLaunchSpec.fromConfig(MesaConfigContract.fromVm(vm));
      final renderer = MesaRendererContract.fromLaunch(spec);

      expect(spec.visualVariant, MesaVisualVariant.vip);
      expect(spec.apostaMoedas, 1000);
      expect(spec.poteMoedas, 4000);
      expect(spec.ehVip, isTrue);
      expect(renderer.context, MesaRuntimeContext.vip);
      expect(renderer.skin, MesaRendererSkin.premium);
      expect(renderer.habilitaContextoPrivado, isFalse);
    });

    test('Privada usa pele premium sem perder contexto privado', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
        modalidade: ModalidadeJogo.aberto,
        chat: ChatMesa.completo,
        espectadores: false,
      );
      final spec = MesaLaunchSpec.fromConfig(MesaConfigContract.fromVm(vm));
      final renderer = MesaRendererContract.fromLaunch(spec);

      expect(spec.visualVariant, MesaVisualVariant.privada);
      expect(spec.modalidade, 'ABERTO');
      expect(spec.chat, ChatMesa.completo);
      expect(spec.espectadores, isFalse);
      expect(spec.codigoSala, 'BURACO-7K2M');
      expect(spec.ehPrivada, isTrue);
      expect(spec.ehVip, isFalse);

      expect(renderer.context, MesaRuntimeContext.privada);
      expect(renderer.skin, MesaRendererSkin.premium);
      expect(renderer.usaPelePremium, isTrue);
      expect(renderer.habilitaContextoPrivado, isTrue);
    });
  });
}
