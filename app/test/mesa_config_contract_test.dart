import 'package:flutter_test/flutter_test.dart';
import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';

void main() {
  test('contrato preserva todas as escolhas da Mesa Privada', () {
    final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
      modalidade: ModalidadeJogo.sbtl,
      modo: ModoJogo.dois,
      pontos: 3000,
      tempo: 30,
      chat: ChatMesa.soBaloes,
      aposta: const ApostaVM(
        valor: 1000,
        opcoes: [0, 500, 1000, 5000],
        pote: 2000,
      ),
      espectadores: false,
    );

    final contrato = MesaConfigContract.fromVm(vm);

    expect(contrato.tipoCodigo, 'privada');
    expect(contrato.modalidadeCodigo, 'STBL');
    expect(contrato.quantidadeJogadores, 2);
    expect(contrato.pontos, 3000);
    expect(contrato.tempoSegundos, 30);
    expect(contrato.chat, ChatMesa.soBaloes);
    expect(contrato.apostaMoedas, 1000);
    expect(contrato.poteMoedas, 2000);
    expect(contrato.espectadores, isFalse);
    expect(contrato.codigoSala, 'BURACO-7K2M');
    expect(contrato.cadeiras, hasLength(4));
    expect(contrato.custoCriar, 500);
  });

  test('Pública não ganha campos exclusivos ao atravessar a fronteira', () {
    final contrato = MesaConfigContract.fromVm(
      ConfigMesaVM.mock(tipo: TipoMesa.publica),
    );

    expect(contrato.tipoCodigo, 'publica');
    expect(contrato.apostaMoedas, isNull);
    expect(contrato.poteMoedas, isNull);
    expect(contrato.espectadores, isNull);
    expect(contrato.codigoSala, isNull);
    expect(contrato.cadeiras, isNull);
  });

  test('VIP leva aposta sem carregar controles exclusivos da Privada', () {
    final contrato = MesaConfigContract.fromVm(
      ConfigMesaVM.mock(tipo: TipoMesa.vip),
    );

    expect(contrato.tipoCodigo, 'vip');
    expect(contrato.apostaMoedas, 500);
    expect(contrato.poteMoedas, 2000);
    expect(contrato.codigoSala, isNull);
    expect(contrato.cadeiras, isNull);
    expect(contrato.espectadores, isNull);
  });
}
