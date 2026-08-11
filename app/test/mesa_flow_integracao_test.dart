import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/mesa.dart';
import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_config_contract.dart';
import '../lib/screens/mesa_flow_preview_host.dart';
import '../lib/screens/mesa_launch_spec.dart';
import '../lib/screens/mesa_renderer_contract.dart';
import '../lib/screens/preparando_partida_screen.dart';
import 'superficie_de_teste.dart';

/// Contratos da ligacao configuracao -> runtime.
///
/// O que estes testes protegem e a fronteira que o host legado atravessava
/// perdendo carga: ele abria a Mesa com `publica ? publica : vip` e
/// `PreparandoPartidaVM.mock`, entao modalidade, meta, tempo, chat e o proprio
/// contexto da sala nao chegavam ao runtime.
MesaRendererContract _rendererDe(ConfigMesaVM vm) =>
    MesaRendererContract.fromLaunch(
      MesaLaunchSpec.fromConfig(MesaConfigContract.fromVm(vm)),
    );

MesaScreen _mesaDaArvore(WidgetTester tester) =>
    tester.widget<MesaScreen>(find.byType(MesaScreen));

void main() {
  group('Onde jogar decide o tipo; o configurador nao repete a escolha', () {
    testWidgets('Publica abre somente a configuracao publica', (tester) async {
      usarTelefoneRetrato(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: MesaFlowPreviewHost(tipoInicial: TipoMesa.publica),
        ),
      );

      expect(find.text('Configurar Mesa Pública'), findsOneWidget);
      expect(find.text('CRIAR MESA PÚBLICA'), findsOneWidget);
      // Nada de VIP nem de Privada vaza para a mesa publica.
      expect(find.text('CRIAR MESA VIP'), findsNothing);
      expect(find.text('CRIAR MESA PRIVADA'), findsNothing);
      expect(find.text('MONTE SUA PARTIDA'), findsNothing);
    });

    testWidgets('Privada abre a configuracao privada, com turma e codigo',
        (tester) async {
      usarTelefoneRetrato(tester);

      await tester.pumpWidget(
        const MaterialApp(
          home: MesaFlowPreviewHost(tipoInicial: TipoMesa.privada),
        ),
      );

      expect(find.text('Configurar Mesa Privada'), findsOneWidget);
      expect(find.text('CRIAR MESA PRIVADA'), findsOneWidget);
      expect(find.text('CRIAR MESA PÚBLICA'), findsNothing);
    });
  });

  group('As escolhas atravessam a fronteira ate o runtime', () {
    testWidgets('a Mesa usa o contrato, nao os parametros soltos',
        (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      // Parametros soltos deliberadamente errados: se a Mesa os usasse, o
      // cabecalho mostraria ABERTO/1500 em vez de STBL/3000.
      final renderer = _rendererDe(
        ConfigMesaVM.mock(tipo: TipoMesa.privada).copyWith(
          modalidade: ModalidadeJogo.sbtl,
          pontos: 3000,
          tempo: 30,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MesaScreen(
            modalidade: 'ABERTO',
            metaPontos: 1500,
            tempoSegundos: 45,
            renderer: renderer,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('STBL'), findsOneWidget);
      expect(find.text('3000'), findsOneWidget);
      expect(find.text('ABERTO'), findsNothing);
      expect(find.text('1500'), findsNothing);

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('Privada chega a Mesa como Privada, nunca como VIP',
        (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      final renderer =
          _rendererDe(ConfigMesaVM.mock(tipo: TipoMesa.privada));

      expect(renderer.context, MesaRuntimeContext.privada);
      // Compartilhar a pele premium com a VIP nao pode apagar o contexto.
      expect(renderer.usaPelePremium, isTrue);

      await tester.pumpWidget(
        MaterialApp(home: MesaScreen(renderer: renderer)),
      );
      await tester.pump();

      // O contexto privado esta vivo no runtime: o chat responde como Privada.
      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.pump();
      expect(
        find.textContaining('Chat livre da Mesa Privada'),
        findsOneWidget,
      );

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('chat desligado na configuracao e respeitado na Mesa',
        (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      final renderer = _rendererDe(
        ConfigMesaVM.mock(tipo: TipoMesa.vip)
            .copyWith(chat: ChatMesa.desligado),
      );

      await tester.pumpWidget(
        MaterialApp(home: MesaScreen(renderer: renderer)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.chat_bubble_rounded), findsNothing);
      await tester.tap(find.byIcon(Icons.speaker_notes_off_rounded));
      await tester.pump();
      expect(find.textContaining('Chat desligado'), findsOneWidget);

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('a travessia inteira preserva a configuracao ate a Mesa',
        (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      await tester.pumpWidget(
        const MaterialApp(
          home: MesaFlowPreviewHost(tipoInicial: TipoMesa.vip),
        ),
      );

      await tester.ensureVisible(find.text('CRIAR MESA VIP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRIAR MESA VIP'));
      // A tela de preparacao anima o tempo todo, entao nunca "assenta":
      // avancar a transicao de rota a mao em vez de esperar por silencio.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PreparandoPartidaScreen), findsOneWidget);

      // A preparacao tem duracao minima propria e anima ate o fim; nao cabe
      // pumpAndSettle nem aqui nem depois, ja que o relogio de turno da Mesa e
      // periodico e a arvore nunca fica quieta.
      await avancarAte(tester, find.byType(MesaScreen));

      expect(find.byType(MesaScreen), findsOneWidget);
      final mesa = _mesaDaArvore(tester);
      final launch = mesa.renderer!.launch;
      expect(mesa.renderer!.context, MesaRuntimeContext.vip);
      expect(launch.quantidadeJogadores, 4);
      expect(launch.apostaMoedas, isNotNull);
      // VIP nao herda os controles exclusivos da Privada.
      expect(launch.codigoSala, isNull);

      await desmontarEDrenarTimers(tester);
    });
  });
}
