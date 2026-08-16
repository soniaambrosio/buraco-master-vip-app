import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';
import '../lib/screens/preparando_partida_config_adapter.dart';

void main() {
  group('Configuração -> Preparando partida', () {
    test('preserva todas as escolhas da Mesa VIP', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.vip).copyWith(
        modalidade: ModalidadeJogo.sbtl,
        modo: ModoJogo.dois,
        pontos: 3000,
        tempo: 30,
        aposta: const ApostaVM(
          valor: 1000,
          opcoes: [0, 500, 1000, 5000],
          pote: 2000,
        ),
      );

      final contrato = MesaConfigContract.fromVm(vm);
      final preparacao = prepararPartidaDaConfiguracao(contrato);

      expect(contrato.tipoCodigo, 'vip');
      expect(contrato.modalidadeCodigo, 'STBL');
      expect(contrato.quantidadeJogadores, 2);
      expect(contrato.pontos, 3000);
      expect(contrato.tempoSegundos, 30);
      expect(contrato.apostaMoedas, 1000);
      expect(contrato.poteMoedas, 2000);
      expect(contrato.poteCoerente, isTrue);

      expect(preparacao.titulo, 'SUA MESA VIP VAI COMEÇAR');
      expect(preparacao.subtitulo, contains('STBL'));
      expect(preparacao.subtitulo, contains('2 jogadores'));
      expect(preparacao.subtitulo, contains('3.000 pontos'));
      expect(preparacao.subtitulo, contains('30s'));
      expect(preparacao.subtitulo, contains('aposta 1.000'));
      expect(preparacao.jogadores, hasLength(2));
    });

    test('Mesa Privada de 2 jogadores só leva duas cadeiras ativas', () {
      final vm = ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
        modo: ModoJogo.dois,
        aposta: const ApostaVM(
          valor: 500,
          opcoes: [0, 500, 1000, 5000],
          pote: 1000,
        ),
        espectadores: false,
      );

      final contrato = MesaConfigContract.fromVm(vm);
      final preparacao = prepararPartidaDaConfiguracao(contrato);

      expect(contrato.quantidadeJogadores, 2);
      expect(contrato.cadeirasAtivas, hasLength(2));
      expect(contrato.cadeirasAtivas![0].id, 'dono');
      expect(contrato.cadeirasAtivas![1].id, 'convidado');
      expect(contrato.poteCoerente, isTrue);
      expect(preparacao.jogadores, hasLength(2));
      expect(preparacao.subtitulo, contains('sem espectadores'));
    });

    test('Mesa Pública não inventa aposta nem código na transição', () {
      final vm = ConfigMesaVM.mock(
        tipo: TipoMesa.publica,
        ehVip: false,
      ).copyWith(
        modalidade: ModalidadeJogo.aberto,
        modo: ModoJogo.quatro,
        pontos: 1500,
        tempo: 45,
      );

      final contrato = MesaConfigContract.fromVm(vm);
      final preparacao = prepararPartidaDaConfiguracao(contrato);

      expect(contrato.apostaMoedas, isNull);
      expect(contrato.poteMoedas, isNull);
      expect(contrato.codigoSala, isNull);
      expect(contrato.cadeiras, isNull);
      expect(contrato.poteCoerente, isTrue);
      expect(preparacao.ehVip, isFalse);
      expect(preparacao.jogadores, hasLength(4));
      expect(preparacao.titulo, 'SUA MESA PÚBLICA VAI COMEÇAR');
    });

    test('status VIP do jogador atravessa o contrato sem depender do tipo de mesa', () {
      final publicaVip = MesaConfigContract.fromVm(
        ConfigMesaVM.mock(tipo: TipoMesa.publica, ehVip: true),
      );
      final publicaLivre = MesaConfigContract.fromVm(
        ConfigMesaVM.mock(tipo: TipoMesa.publica, ehVip: false),
      );

      expect(prepararPartidaDaConfiguracao(publicaVip).ehVip, isTrue);
      expect(prepararPartidaDaConfiguracao(publicaLivre).ehVip, isFalse);
    });
  });
}
