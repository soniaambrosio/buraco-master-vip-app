import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/pages/perfil_page.dart';
import '../lib/pages/ranking_page.dart';
import '../lib/ranking/ranking_contract.dart';
import '../lib/screens/ranking_screen.dart';
import 'ranking_fixtures.dart';
import 'superficie_de_teste.dart';

/// Guarda as rotas empilhadas para conferir PARA ONDE a tela navega sem
/// precisar montar a tela de destino.
class _ObservadorDeRotas extends NavigatorObserver {
  final List<Route<dynamic>> empilhadas = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? anterior) {
    empilhadas.add(route);
    super.didPush(route, anterior);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) empilhadas.add(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

void main() {
  late RankingFonteFake fonte;
  late _ObservadorDeRotas rotas;

  setUp(() {
    fonte = RankingFonteFake();
    rotas = _ObservadorDeRotas();
  });

  Future<void> montar(
    WidgetTester tester, {
    RankingPage? pagina,
    Size superficie = const Size(390, 844),
  }) async {
    usarTelefoneRetrato(tester, logico: superficie);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rotas],
        home: pagina ?? RankingPage(service: fonte),
      ),
    );
  }

  RankingEstado estadoDaTela(WidgetTester tester) =>
      tester.widget<RankingScreen>(find.byType(RankingScreen)).estado;

  /// A rota mais recente, sem montar a tela de destino.
  Widget destino(WidgetTester tester) {
    final rota = rotas.empilhadas.last as MaterialPageRoute;
    return rota.builder(tester.element(find.byType(RankingScreen)));
  }

  group('estados', () {
    testWidgets('carregando: esqueleto, e nenhum nome na tela', (tester) async {
      await montar(tester);

      expect(estadoDaTela(tester), RankingEstado.carregando);
      expect(find.text('Jogador 1'), findsNothing);
      expect(find.text('Sônia Rainha'), findsNothing);
    });

    testWidgets('lista carregada mostra apelido, posicao e liga',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(
          cabecalho: resumo(divisao: divisaoDemo, escadaLigas: escadaDemo),
          itens: [
            jogador(4, apelido: 'Cláudia', liga: 'Diamante', pontos: 3640),
            jogador(5, apelido: 'Ricardo', liga: 'Ouro', pontos: 3500),
          ],
          fim: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(estadoDaTela(tester), RankingEstado.normal);
      expect(find.text('Cláudia'), findsOneWidget);
      expect(find.text('Ricardo'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Diamante'), findsWidgets);
      expect(find.text('Ouro'), findsWidgets);
    });

    testWidgets('ranking vazio tem texto proprio, nao erro', (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(abertura(itens: const [], fim: true));
      await tester.pumpAndSettle();

      expect(estadoDaTela(tester), RankingEstado.vazio);
      expect(find.text('Ainda sem ninguém aqui'), findsOneWidget);
    });

    testWidgets('erro mostra o motivo da fonte e o botao de tentar de novo',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first
          .completeError(const RankingIndisponivel('servidor sem resposta'));
      await tester.pumpAndSettle();

      expect(estadoDaTela(tester), RankingEstado.erro);
      expect(find.text('servidor sem resposta'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('tentar de novo refaz a busca e recupera a lista',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first
          .completeError(const RankingIndisponivel('servidor sem resposta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      expect(fonte.aberturas.length, 2);

      fonte.aberturas.last.complete(
        abertura(itens: [jogador(1, apelido: 'Marina')], fim: true),
      );
      await tester.pumpAndSettle();

      expect(estadoDaTela(tester), RankingEstado.normal);
      expect(find.text('Marina'), findsOneWidget);
    });
  });

  group('sem fonte oficial (caminho de producao)', () {
    testWidgets('a tela diz que nao ha ranking publicado, sem inventar nome',
        (tester) async {
      // Sem injetar nada: e o RankingSemFonte embarcado no app.
      await montar(tester, pagina: const RankingPage());
      await tester.pumpAndSettle();

      expect(estadoDaTela(tester), RankingEstado.erro);
      expect(
        find.text('O ranking oficial ainda não está sendo publicado.'),
        findsOneWidget,
      );
      expect(find.text('VOCÊ'), findsNothing);
      expect(find.text('Sônia Rainha'), findsNothing);
    });
  });

  group('jogador local x outro jogador', () {
    testWidgets('so a linha marcada pela fonte recebe o selo VOCE',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(
          itens: [
            jogador(11, apelido: 'Fernanda'),
            jogador(12, apelido: 'Eu mesma', souEu: true),
          ],
          fim: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VOCÊ'), findsOneWidget);
    });

    testWidgets('tocar em outro jogador abre o perfil dele pelo id publico',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(
          itens: [jogador(7, id: 'uid-sete', apelido: 'Beto')],
          fim: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Beto'));
      await tester.pump();

      final alvo = destino(tester);
      expect(alvo, isA<PerfilPage>());
      expect((alvo as PerfilPage).publicIdVisitado, 'uid-sete');
      expect(alvo.ehMeuPerfil, isFalse);

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('tocar em si mesmo abre o proprio perfil', (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(
          itens: [jogador(12, id: 'uid-eu', apelido: 'Eu mesma', souEu: true)],
          fim: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Eu mesma'));
      await tester.pump();

      final alvo = destino(tester) as PerfilPage;
      expect(alvo.ehMeuPerfil, isTrue);
      expect(alvo.publicIdVisitado, isNull);

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('jogador sem id publicado nao navega', (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(itens: [jogador(3, id: '', apelido: 'Anônimo')], fim: true),
      );
      await tester.pumpAndSettle();

      final antes = rotas.empilhadas.length;
      await tester.tap(find.text('Anônimo'));
      await tester.pump();

      expect(rotas.empilhadas.length, antes);
      expect(find.text('Este jogador ainda não tem perfil público.'),
          findsOneWidget);
    });
  });

  group('paginacao na tela', () {
    testWidgets('sem proxima pagina, o botao nem aparece', (tester) async {
      await montar(tester);
      fonte.aberturas.first
          .complete(abertura(itens: [jogador(1)], fim: true));
      await tester.pumpAndSettle();

      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('carregar mais concatena e some no fim da lista',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(
          itens: [jogador(1, apelido: 'Primeira')],
          cursorProxima: 'c1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carregar mais'), findsOneWidget);

      await tester.tap(find.text('Carregar mais'));
      await tester.pump();
      fonte.paginacoes.first
          .complete(pagina([jogador(2, apelido: 'Segunda')], fim: true));
      await tester.pumpAndSettle();

      expect(find.text('Primeira'), findsOneWidget);
      expect(find.text('Segunda'), findsOneWidget);
      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('erro na segunda pagina nao apaga a primeira', (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(itens: [jogador(1, apelido: 'Primeira')], cursorProxima: 'c1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carregar mais'));
      await tester.pump();
      fonte.paginacoes.first
          .completeError(const RankingIndisponivel('caiu no meio'));
      await tester.pump();
      await tester.pump();

      expect(estadoDaTela(tester), RankingEstado.normal);
      expect(find.text('Primeira'), findsOneWidget);
      expect(find.text('caiu no meio'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('abas', () {
    testWidgets('trocar de aba busca a nova, e voltar nao rebusca',
        (tester) async {
      await montar(tester);
      fonte.aberturas.first.complete(
        abertura(itens: [jogador(1, apelido: 'DaTemporada')], fim: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Global'));
      await tester.pump();
      expect(fonte.escoposAbertos, [
        RankingEscopo.temporada,
        RankingEscopo.global,
      ]);

      fonte.aberturas.last.complete(
        abertura(itens: [jogador(1, apelido: 'DoGlobal')], fim: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('DoGlobal'), findsOneWidget);
      expect(find.text('DaTemporada'), findsNothing);

      await tester.tap(find.text('Temporada'));
      await tester.pumpAndSettle();

      expect(fonte.escoposAbertos.length, 2,
          reason: 'aba ja carregada nao dispara busca de novo');
      expect(find.text('DaTemporada'), findsOneWidget);
    });
  });

  group('descarte', () {
    testWidgets('sair da tela antes da resposta nao quebra nada',
        (tester) async {
      await montar(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      fonte.aberturas.first.complete(abertura(itens: [jogador(1)], fim: true));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('superficie pequena', () {
    testWidgets('320x640 desenha a lista sem estouro', (tester) async {
      await montar(tester, superficie: const Size(320, 640));
      fonte.aberturas.first.complete(
        abertura(
          cabecalho: resumo(divisao: divisaoDemo, escadaLigas: escadaDemo),
          itens: [
            jogador(1, apelido: 'Maria Aparecida da Conceição Fernandes'),
            jogador(1024, apelido: 'Zé'),
          ],
          fim: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(estadoDaTela(tester), RankingEstado.normal);
      expect(find.text('1024'), findsOneWidget);
    });
  });
}
