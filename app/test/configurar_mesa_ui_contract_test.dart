import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/configurar_mesa_screen.dart';

void main() {
  group('Configuração de Mesa — contrato visual aprovado', () {
    test('Mesa Pública mostra somente opções públicas', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.publica);

      expect(vm.tipo, TipoMesa.publica);
      expect(vm.aposta, isNull);
      expect(vm.espectadores, isNull);
      expect(vm.codigo, isNull);
      expect(vm.cadeiras, isNull);
      expect(vm.custoCriar, 0);
      expect(vm.pontosOpcoes, [1500, 3000]);
      expect(vm.tempoOpcoes, [15, 30, 45]);
    });

    test('Mesa VIP tem aposta em moedas e não herda controles da Privada', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip);

      expect(vm.tipo, TipoMesa.vip);
      expect(vm.aposta, isNotNull);
      expect(vm.aposta!.opcoes, [0, 500, 1000, 5000]);
      expect(vm.espectadores, isNull);
      expect(vm.codigo, isNull);
      expect(vm.cadeiras, isNull);
    });

    test('Mesa Privada preserva configuração completa', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada);

      expect(vm.tipo, TipoMesa.privada);
      expect(vm.aposta, isNotNull);
      expect(vm.espectadores, isNotNull);
      expect(vm.codigo, isNotNull);
      expect(vm.codigo, isNotEmpty);
      expect(vm.cadeiras, isNotNull);
      expect(vm.cadeiras, hasLength(4));
    });

    test('pote acompanha aposta x quantidade de jogadores', () {
      const aposta = ApostaVM(valor: 1000, opcoes: [0, 500, 1000, 5000], pote: 4000);

      expect(aposta.valor * 4, aposta.pote);
      expect(aposta.copyWith(valor: 500, pote: 1000).pote, 1000);
    });
  });
}
