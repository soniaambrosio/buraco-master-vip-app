import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/hall/hall_contract.dart';
import '../lib/pages/hall_page.dart';
import '../lib/screens/hall_screen.dart';
import 'ranking_fixtures.dart';
import 'superficie_de_teste.dart';

void main() {
  late HallFonteFake fonte;

  setUp(() => fonte = HallFonteFake());

  Future<void> montar(
    WidgetTester tester, {
    HallPage? pagina,
    Size superficie = const Size(390, 844),
  }) async {
    usarTelefoneRetrato(tester, logico: superficie);
    await tester.pumpWidget(
      MaterialApp(home: pagina ?? HallPage(service: fonte)),
    );
  }

  HallEstado estadoDaTela(WidgetTester tester) =>
      tester.widget<HallScreen>(find.byType(HallScreen)).estado;

  testWidgets('carregando: avisa que esta consultando, sem nome nenhum',
      (tester) async {
    await montar(tester);

    expect(estadoDaTela(tester), HallEstado.carregando);
    expect(find.text('Consultando o Hall…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('quadro disponivel mostra nome e estatisticas da fonte',
      (tester) async {
    await montar(tester);
    fonte.consultas.first.complete(
      HallQuadro(honrados: [
        honrado(
          HallCategoria.campeaoHoje,
          nome: 'Sônia Rainha',
          estatisticas: const ['342', '18', '68%'],
        ),
        honrado(
          HallCategoria.lendaMes,
          nome: 'Ricardo',
          estatisticas: const ['892', '34', '77%'],
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(estadoDaTela(tester), HallEstado.disponivel);
    expect(find.text('Sônia Rainha'), findsOneWidget);
    expect(find.text('Ricardo'), findsOneWidget);
    expect(find.text('342'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);
  });

  testWidgets('categoria sem vencedor fica com o traco da arte',
      (tester) async {
    await montar(tester);
    fonte.consultas.first.complete(
      HallQuadro(honrados: [honrado(HallCategoria.campeaoHoje)]),
    );
    await tester.pumpAndSettle();

    // As outras quatro categorias tem tres lugares de estatistica cada; sem
    // vencedor, todos exibem o traco.
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('hall vazio tem texto proprio', (tester) async {
    await montar(tester);
    fonte.consultas.first.complete(HallQuadro.vazio);
    await tester.pumpAndSettle();

    expect(estadoDaTela(tester), HallEstado.vazio);
    expect(find.text('Nenhum imortal ainda'), findsOneWidget);
  });

  testWidgets('falha inesperada vira erro com botao de tentar de novo',
      (tester) async {
    await montar(tester);
    fonte.consultas.first.completeError(StateError('rede caiu'));
    await tester.pumpAndSettle();

    expect(estadoDaTela(tester), HallEstado.erro);
    expect(find.text('Não consegui abrir o Hall'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();
    expect(fonte.consultas.length, 2);
  });

  testWidgets('fonte que nao publica vira indisponivel, com o motivo dela',
      (tester) async {
    await montar(tester);
    fonte.consultas.first
        .completeError(const HallIndisponivel('quadro em apuracao'));
    await tester.pumpAndSettle();

    expect(estadoDaTela(tester), HallEstado.indisponivel);
    expect(find.text('Hall indisponível agora'), findsOneWidget);
    expect(find.text('quadro em apuracao'), findsOneWidget);
  });

  testWidgets('sem fonte oficial (caminho de producao) nao fabrica vencedor',
      (tester) async {
    await montar(tester, pagina: const HallPage());
    await tester.pumpAndSettle();

    expect(estadoDaTela(tester), HallEstado.indisponivel);
    expect(
      find.text('O Hall dos Imortais ainda não está sendo publicado.'),
      findsOneWidget,
    );
    expect(find.text('Sônia Rainha'), findsNothing);
    expect(find.text('Ricardo'), findsNothing);
  });

  testWidgets('sair da tela antes da resposta nao quebra nada', (tester) async {
    await montar(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    fonte.consultas.first.complete(HallQuadro.vazio);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('320x640 desenha o quadro sem estouro', (tester) async {
    await montar(tester, superficie: const Size(320, 640));
    fonte.consultas.first.complete(
      HallQuadro(honrados: [
        honrado(HallCategoria.campeaoHoje,
            nome: 'Maria Aparecida da Conceição Fernandes'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(estadoDaTela(tester), HallEstado.disponivel);
  });
}
