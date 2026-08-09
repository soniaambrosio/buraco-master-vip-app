import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';
import '../lib/screens/mesa_launch_spec.dart';

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

      expect(spec.visualVariant, MesaVisualVariant.publica);
      expect(spec.modalidade, 'STBL');
      expect(spec.quantidadeJogadores, 2);
      expect(spec.metaPontos, 3000);
      expect(spec.tempoSegundos, 30);
      expect(spec.chat, ChatMesa.soBaloes);
      expect(spec.apostaMoedas, isNull);
      expect(spec.ehPublica, isTrue);
      expect(spec.exigeResolucaoDeVariantPrivada, isFalse);
    });

    test('VIP preserva aposta e permanece VIP', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip).copyWith(
        aposta: const ApostaVM(
          valor: 1000,
          opcoes: [0, 500, 1000, 5000],
          pote: 4000,
        ),
      );
      final spec = MesaLaunchSpec.fromConfig(MesaConfigContract.fromVm(vm));

      expect(spec.visualVariant, MesaVisualVariant.vip);
      expect(spec.apostaMoedas, 1000);
      expect(spec.poteMoedas, 4000);
      expect(spec.ehVip, isTrue);
      expect(spec.ehPrivada, isFalse);
    });

    test('Privada nunca é convertida silenciosamente em VIP', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
        modalidade: ModalidadeJogo.aberto,
        chat: ChatMesa.completo,
        espectadores: false,
      );
      final spec = MesaLaunchSpec.fromConfig(MesaConfigContract.fromVm(vm));

      expect(spec.visualVariant, MesaVisualVariant.privada);
      expect(spec.modalidade, 'ABERTO');
      expect(spec.chat, ChatMesa.completo);
      expect(spec.espectadores, isFalse);
      expect(spec.codigoSala, 'BURACO-7K2M');
      expect(spec.ehPrivada, isTrue);
      expect(spec.ehVip, isFalse);
      expect(spec.exigeResolucaoDeVariantPrivada, isTrue);
    });
  });
}
