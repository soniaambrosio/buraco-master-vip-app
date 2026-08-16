import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';
import '../lib/screens/mesa_config_validator.dart';

void main() {
  group('Validação do contrato visual da mesa', () {
    test('aceita os três mocks aprovados quando elegíveis', () {
      final publica = validarMesaConfig(
        MesaConfigContract.fromVm(
          ConfigMesaVM.mock(tipo: TipoMesa.publica, ehVip: false),
        ),
      );
      final vip = validarMesaConfig(
        MesaConfigContract.fromVm(
          ConfigMesaVM.mock(tipo: TipoMesa.vip, ehVip: true),
        ),
      );
      final privada = validarMesaConfig(
        MesaConfigContract.fromVm(
          ConfigMesaVM.mock(tipo: TipoMesa.privada, ehVip: true),
        ),
      );

      expect(publica.ok, isTrue, reason: publica.erros.join(', '));
      expect(vip.ok, isTrue, reason: vip.erros.join(', '));
      expect(privada.ok, isTrue, reason: privada.erros.join(', '));
    });

    test('recusa Mesa VIP para não assinante', () {
      final resultado = validarMesaConfig(
        MesaConfigContract.fromVm(
          ConfigMesaVM.mock(tipo: TipoMesa.vip, ehVip: false),
        ),
      );

      expect(resultado.ok, isFalse);
      expect(resultado.erros, contains('VIP_EXIGE_ASSINANTE'));
    });

    test('recusa criação de Mesa Privada para não VIP', () {
      final resultado = validarMesaConfig(
        MesaConfigContract.fromVm(
          ConfigMesaVM.mock(tipo: TipoMesa.privada, ehVip: false),
        ),
      );

      expect(resultado.ok, isFalse);
      expect(resultado.erros, contains('CRIAR_PRIVADA_EXIGE_VIP'));
    });

    test('recusa pote incompatível com aposta e número de jogadores', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip, ehVip: true).copyWith(
        modo: ModoJogo.dois,
        aposta: const ApostaVM(
          valor: 1000,
          opcoes: [0, 500, 1000, 5000],
          pote: 4000,
        ),
      );
      final resultado = validarMesaConfig(MesaConfigContract.fromVm(vm));

      expect(resultado.ok, isFalse);
      expect(resultado.erros, contains('POTE_INCOERENTE'));
    });
  });
}
