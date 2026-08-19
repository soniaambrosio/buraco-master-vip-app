// localizacao_ptbr_test.dart — as strings que o FRAMEWORK escreve sozinho.
//
// ---------------------------------------------------------------------------
// O DEFEITO QUE ESTE ARQUIVO FECHA
// ---------------------------------------------------------------------------
//
// Todo texto NOSSO já estava em português. Só que nem todo texto da tela é
// nosso: o botão de retorno da `AppBar`, o rótulo da barreira que fecha um
// diálogo e o menu de recortar/copiar/colar são escritos pelo Material. Sem os
// delegados de localização, o `MaterialApp` cai em
// `DefaultMaterialLocalizations` — que só fala inglês. A árvore semântica da
// raiz produtiva anunciava "Back", "Dismiss" e "Cut/Copy/Paste" no meio de um
// aplicativo em português, e quem paga isso é quem usa leitor de tela.
//
// ---------------------------------------------------------------------------
// POR QUE ESTES CASOS, E NÃO UMA BUSCA POR TEXTO
// ---------------------------------------------------------------------------
//
// Procurar `GlobalMaterialLocalizations.delegate` no código-fonte provaria que
// alguém DIGITOU a linha — não que ela está ligada. A ligação só é observável
// na árvore montada: qual `MaterialLocalizations` o framework resolveu, e o que
// os widgets que ele instancia sozinho realmente anunciam.
//
// Por isso as telas usadas aqui são as de PRODUÇÃO. O botão de retorno é o que
// a `AppBar` do `LobbyOnline` monta sozinha; a barreira é a do diálogo real de
// "Sair da conta"; o campo de texto é o do lobby. Nenhum deles foi construído
// pelo teste, e nenhum recebe `tooltip` nosso — se a localização se desligar,
// os três voltam a falar inglês e os casos abaixo caem.
//
// ---------------------------------------------------------------------------
// AS PROVAS NEGATIVAS
// ---------------------------------------------------------------------------
//
// Cada peça removida derruba algo daqui:
//
//   * tirar `flutter_localizations` do pubspec  → a raiz não compila (o import
//     some), e junto com ela todos os casos deste arquivo;
//   * tirar os delegados do `MaterialApp`       → `MaterialLocalizations` volta
//     a ser `DefaultMaterialLocalizations` e o retorno vira "Back";
//   * tirar `Locale('pt','BR')`                 → `supportedLocales` volta ao
//     padrão `[en_US]`, e o aparelho em inglês passa a ser atendido em inglês;
//   * ligar a localização em OUTRO `MaterialApp` que não o produtivo → a raiz
//     montada aqui é a de produção, e ela continuaria em inglês.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
// de desktop e faz telas de celular estourarem em overflow.

import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:buraco_master_vip/casca/casca_de_producao.dart';
import 'package:buraco_master_vip/casca/configuracoes_de_producao.dart';
import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/onde_jogar_de_producao.dart';

import 'bancada_online.dart';

// ===========================================================================
// O caminho até as telas reais
// ===========================================================================

Future<void> _abrirAplicativo(WidgetTester tester, Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
  expect(find.byType(HomeDeProducao), findsOneWidget);
}

/// Home → Jogar → Mesa por código. É a única tela produtiva com `AppBar` que
/// um teste de widget alcança sem servidor, e é dela que sai o botão de
/// retorno que o framework monta sozinho.
Future<void> _irAoLobby(WidgetTester tester, Bancada b) async {
  await tester.tap(find.text('Jogar').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mesa por código'));
  await tester.pumpAndSettle();
  expect(find.byType(LobbyOnline), findsOneWidget);
  // O servidor aceita a credencial. Não é enfeite: sem a resposta, o
  // `OnlineService` fica com o temporizador de 15s da autenticação armado, e o
  // `flutter_test` reprova o caso por temporizador pendente na desmontagem.
  b.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
}

/// O `MaterialApp` produtivo — e a garantia, em cada leitura, de que só existe
/// um. Se alguém montar um segundo bootstrap, este `expect` cai antes de
/// qualquer asserção sobre idioma.
MaterialApp _appProdutivo(WidgetTester tester) {
  expect(
    find.byType(MaterialApp),
    findsOneWidget,
    reason: 'a raiz produtiva tem UM MaterialApp, e a localização mora nele',
  );
  return tester.widget<MaterialApp>(find.byType(MaterialApp));
}

void main() {
  // =========================================================================
  // 1 e 2 — a raiz produtiva declara a localização oficial
  // =========================================================================
  group('a raiz produtiva', () {
    testWidgets('suporta pt-BR e carrega os delegados oficiais do SDK', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await _abrirAplicativo(tester, b);

      final app = _appProdutivo(tester);

      expect(
        app.supportedLocales,
        contains(const Locale('pt', 'BR')),
        reason: 'sem isto o padrão do MaterialApp é [en_US]',
      );

      // Os TRÊS delegados oficiais, e por identidade — não por nome nem por
      // tipo. `GlobalMaterialLocalizations.delegate` é uma constante do SDK:
      // trocá-la por uma tabela nossa faria este caso cair.
      final delegados = app.localizationsDelegates?.toList() ?? const [];
      expect(delegados, contains(GlobalMaterialLocalizations.delegate));
      expect(delegados, contains(GlobalWidgetsLocalizations.delegate));
      expect(delegados, contains(GlobalCupertinoLocalizations.delegate));
    });

    testWidgets('resolve as localizações do flutter_localizations, e não as '
        'de emergência do framework', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await _abrirAplicativo(tester, b);

      // A LEITURA É FEITA DE DENTRO DA CASCA PRODUTIVA. É o mesmo `context`
      // que qualquer tela do aplicativo usa — quem responde aqui é quem
      // responde para elas.
      final ctx = tester.element(find.byType(HomeDeProducao));

      expect(Localizations.localeOf(ctx), const Locale('pt', 'BR'));
      expect(
        MaterialLocalizations.of(ctx),
        isA<GlobalMaterialLocalizations>(),
        reason: 'sem os delegados isto é DefaultMaterialLocalizations',
      );
      expect(CupertinoLocalizations.of(ctx), isA<GlobalCupertinoLocalizations>());
    });

    testWidgets('aparelho em inglês continua sendo atendido em português', (
      tester,
    ) async {
      // A prova de que `supportedLocales` está fazendo trabalho: com UMA locale
      // suportada, a resolução do Flutter devolve pt-BR para qualquer idioma do
      // aparelho. Com a lista padrão `[en_US]`, este caso devolveria inglês.
      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'US'),
      ];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await _abrirAplicativo(tester, b);

      final ctx = tester.element(find.byType(HomeDeProducao));
      expect(Localizations.localeOf(ctx), const Locale('pt', 'BR'));
      expect(MaterialLocalizations.of(ctx).backButtonTooltip, 'Voltar');
    });
  });

  // =========================================================================
  // 3, 4 e 5 — o que o framework anuncia nas telas reais
  // =========================================================================
  group('as strings do framework', () {
    testWidgets('o botão de retorno da AppBar produtiva é anunciado como '
        '"Voltar"', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      // Não vai para `addTearDown`: a verificação de handles vazados roda ANTES
      // dos tearDowns, e o caso reprovaria mesmo tendo passado.
      final semantica = tester.ensureSemantics();

      await _abrirAplicativo(tester, b);
      await _irAoLobby(tester, b);

      // O botão NÃO foi construído pelo teste nem pela tela: a `AppBar` do
      // lobby não declara `leading`, e é o Material que monta o `BackButton`
      // ao ver que a rota pode voltar.
      final botao = find.byType(BackButton);
      expect(botao, findsOneWidget);
      expect(
        tester.widget<BackButton>(botao).tooltip,
        isNull,
        reason: 'o rótulo tem de vir da localização, não de um tooltip nosso',
      );

      // O que o leitor de tela recebe.
      final no = tester.getSemantics(botao);
      expect(no.tooltip, 'Voltar');
      expect(no.label, isNot(contains('Back')));

      // E o que aparece na tela ao segurar o botão. O `Tooltip` é montado pelo
      // `IconButton` que o `BackButton` constrói, e a mensagem dele vem da
      // mesma autoridade que o rótulo semântico acima.
      final dica = tester.widget<Tooltip>(
        find.descendant(of: botao, matching: find.byType(Tooltip)).first,
      );
      expect(dica.message, 'Voltar');

      semantica.dispose();
    });

    testWidgets('a barreira do diálogo produtivo é rotulada em português', (
      tester,
    ) async {
      // A tela de Ajustes lê preferências do disco; sem isto o plugin lança e a
      // carga vira exceção assíncrona no meio do teste.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);

      // O caminho REAL: Home → Ajustes → Sair da conta.
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracoesDeProducao), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sair da conta'), 200);
      await tester.ensureVisible(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);

      // O rótulo da barreira é o que um leitor de tela lê para "toque aqui para
      // fechar". `showDialog` o pega de `MaterialLocalizations`, e nenhuma tela
      // nossa o escreve.
      final rotulos = tester
          .widgetList<ModalBarrier>(find.byType(ModalBarrier))
          .map((barreira) => barreira.semanticsLabel)
          .whereType<String>()
          .toList();
      expect(rotulos, contains('Dispensar'));
      expect(rotulos, isNot(contains('Dismiss')));

      // Fecha o diálogo: deixar uma rota modal aberta no fim do caso derruba a
      // limpeza da bancada.
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
    });

    testWidgets('o menu de seleção do campo de texto produtivo usa os rótulos '
        'em português', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _irAoLobby(tester, b);

      // O campo é o do lobby — código de mesa/apelido —, não um construído
      // aqui. O menu que aparece ao selecionar é montado pelo Material.
      final campo = find.byType(EditableText).first;
      await tester.enterText(campo, 'BURACO-0001');
      await tester.pumpAndSettle();

      final editor = tester.state<EditableTextState>(campo);
      editor.selectAll(SelectionChangedCause.toolbar);
      await tester.pumpAndSettle();
      expect(editor.showToolbar(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Cortar'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Cut'), findsNothing);

      // O restante da barra, pela mesma autoridade — inclusive os itens que só
      // aparecem quando a área de transferência tem conteúdo.
      final material = MaterialLocalizations.of(tester.element(campo));
      expect(material.pasteButtonLabel, 'Colar');
      expect(material.selectAllButtonLabel, 'Selecionar tudo');

      editor.hideToolbar();
      await tester.pumpAndSettle();
    });
  });

  // =========================================================================
  // 6, 7 e 8 — o que esta correção NÃO tinha o direito de mudar
  // =========================================================================
  group('o resto da raiz', () {
    testWidgets('a navegação continua funcionando, e volta pelo botão '
        'localizado', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _irAoLobby(tester, b);

      // Ida provada acima; agora a volta, pelo próprio botão do framework.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LobbyOnline), findsNothing);
      expect(find.byType(OndeJogarDeProducao), findsOneWidget);

      // O degrau seguinte volta pelo controle PRÓPRIO da tela — `Onde jogar`
      // não usa `AppBar`, e é de propósito que ela não passou a usar: esta
      // correção mexe no idioma do framework, não no desenho das telas.
      expect(find.byType(BackButton), findsNothing);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.byType(HomeDeProducao), findsOneWidget);
    });

    testWidgets('o bootstrap produtivo segue único, com o mesmo tema e a mesma '
        'chave de geração', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      final app = _appProdutivo(tester);

      // Tema: exatamente o que estava lá antes desta correção.
      expect(app.theme?.useMaterial3, isTrue);
      expect(app.theme?.brightness, Brightness.dark);
      expect(app.darkTheme, isNull);
      expect(app.title, 'Buraco Master VIP');
      expect(app.debugShowCheckedModeBanner, isFalse);

      // Roteamento: nada de rotas nomeadas nem de gerador — a `home` continua
      // sendo a casca, e é ela que decide a tela.
      expect(app.home, isA<CascaDeProducao>());
      expect(app.routes, isEmpty);
      expect(app.initialRoute, isNull);
      expect(app.onGenerateRoute, isNull);
      expect(app.onGenerateInitialRoutes, isNull);

      // A chave de geração — o que apaga a pilha na troca de sessão — não foi
      // trocada por uma chave de idioma.
      expect(app.key, isA<ValueKey<int>>());

      // E navegar não faz nascer um segundo bootstrap.
      await _irAoLobby(tester, b);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
