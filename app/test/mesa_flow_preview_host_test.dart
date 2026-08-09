import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/screens/configurar_mesa_screen.dart';
import '../lib/screens/mesa_flow_preview_host.dart';
import '../lib/screens/preparando_partida_screen.dart';

void main() {
  testWidgets('host novo mostra STBL correto nas regras', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MesaFlowPreviewHost(tipoInicial: TipoMesa.publica),
      ),
    );

    await tester.tap(find.text('Ver regras das modalidades'));
    await tester.pumpAndSettle();

    expect(
      find.text('STBL — sem trinca e bate somente com canastra limpa.'),
      findsOneWidget,
    );
    expect(find.textContaining('SBTL'), findsNothing);
  });

  testWidgets('host novo não abre motor de 4 assentos para seleção 1 x 1',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MesaFlowPreviewHost(tipoInicial: TipoMesa.privada),
      ),
    );

    await tester.tap(find.text('2 jogadores'));
    await tester.pump();
    await tester.tap(find.text('CRIAR MESA PRIVADA'));
    await tester.pump();

    expect(
      find.textContaining('Prévia 1 × 1 pronta até a preparação'),
      findsOneWidget,
    );
    expect(find.byType(PreparandoPartidaScreen), findsNothing);
  });
}
