import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/mesa.dart';
import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_flow_preview_host.dart';
import '../lib/screens/preparando_partida_screen.dart';
import 'superficie_de_teste.dart';

/// Toque duplo, estados e navegacao.
///
/// Um toque duplo em CRIAR MESA nao pode virar duas partidas — cada uma com
/// motor, relogio e aposta proprios — e voltar da mesa nao pode deixar telas
/// empilhadas nem recomecar a celebracao.
void main() {
  testWidgets('CRIAR MESA acionado duas vezes abre uma preparacao so',
      (tester) async {
    usarTelefoneRetrato(tester);
    ignorarOverflowDaFonteDeTeste();

    await tester.pumpWidget(
      const MaterialApp(
        home: MesaFlowPreviewHost(tipoInicial: TipoMesa.vip),
      ),
    );
    await tester.pumpAndSettle();

    // Dois toques na tela nao servem como prova: a rota que entra ja cobre o
    // botao antes do segundo toque chegar. O que a trava protege e o callback
    // disparar duas vezes no mesmo quadro — dedo rapido, toque fantasma,
    // transicao lenta. Entao e isso que se aciona aqui.
    final tela = tester.widget<ConfigurarMesaScreen>(
      find.byType(ConfigurarMesaScreen),
    );
    tela.onCriarMesa();
    tela.onCriarMesa();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Rotas cobertas continuam montadas, entao contar sem pular as de baixo.
    expect(
      find.byType(PreparandoPartidaScreen, skipOffstage: false),
      findsOneWidget,
    );

    await avancarAte(tester, find.byType(MesaScreen));
    expect(find.byType(MesaScreen, skipOffstage: false), findsOneWidget);

    await desmontarEDrenarTimers(tester);
  });

  testWidgets('voltar da preparacao devolve a configuracao intacta',
      (tester) async {
    usarTelefoneRetrato(tester);
    ignorarOverflowDaFonteDeTeste();

    await tester.pumpWidget(
      const MaterialApp(
        home: MesaFlowPreviewHost(tipoInicial: TipoMesa.publica),
      ),
    );

    await tester.ensureVisible(find.text('CRIAR MESA PÚBLICA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CRIAR MESA PÚBLICA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PreparandoPartidaScreen), findsOneWidget);

    final navegador = tester.state<NavigatorState>(find.byType(Navigator));
    navegador.pop();
    // A preparacao anima enquanto existe, entao a rota so some quando a
    // transicao de volta termina; adiantar o relogio ate la.
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Uma unica tela de configuracao, e a mesma de antes.
    expect(
      find.byType(PreparandoPartidaScreen, skipOffstage: false),
      findsNothing,
    );
    expect(find.text('Configurar Mesa Pública'), findsOneWidget);

    // E o botao volta a funcionar: cancelar nao trava a criacao para sempre.
    await tester.ensureVisible(find.text('CRIAR MESA PÚBLICA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CRIAR MESA PÚBLICA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PreparandoPartidaScreen), findsOneWidget);

    await desmontarEDrenarTimers(tester);
  });

  testWidgets('seleção 1 x 1 para na previa e nao abre o motor de 4 assentos',
      (tester) async {
    usarTelefoneRetrato(tester);
    ignorarOverflowDaFonteDeTeste();

    await tester.pumpWidget(
      const MaterialApp(
        home: MesaFlowPreviewHost(tipoInicial: TipoMesa.privada),
      ),
    );

    await tester.tap(find.text('2 jogadores'));
    await tester.pump();
    final tela = tester.widget<ConfigurarMesaScreen>(
      find.byType(ConfigurarMesaScreen),
    );
    tela.onCriarMesa();
    tela.onCriarMesa();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(PreparandoPartidaScreen, skipOffstage: false),
      findsNothing,
    );
    expect(find.byType(MesaScreen, skipOffstage: false), findsNothing);
    expect(
      find.textContaining('Prévia 1 × 1 pronta até a preparação'),
      findsOneWidget,
    );
  });

}
