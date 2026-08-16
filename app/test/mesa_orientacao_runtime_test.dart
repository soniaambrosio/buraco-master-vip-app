import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/mesa.dart';
import '../lib/screens/configuracoes_screen.dart';
import '../lib/screens/mesa_orientation_contract.dart';
import '../lib/screens/mesa_orientation_widgets.dart';
import 'superficie_de_teste.dart';

/// Orientacao da Mesa (docs/OS-CLAUDE-ADENDO-ORIENTACAO-MESA).
///
/// O que precisa ficar protegido: a opcao existe nos dois lugares exigidos, o
/// horizontal e composicao propria (nao a arvore vertical girada) e girar nao
/// mexe na partida.

/// Assinatura do estado autoritativo: se qualquer um destes numeros mudar ao
/// girar, a troca deixou de ser so apresentacao.
String _assinaturaDaPartida(WidgetTester tester) {
  final textos = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where((t) => t.contains('cartas') || t.startsWith('Nós '))
      .toList();
  return textos.join('|');
}

void main() {
  group('Configuracoes -> JOGO', () {
    testWidgets('mostra as tres opcoes de orientacao e devolve a escolha',
        (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      final escolhidas = <MesaOrientacaoPreferida>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ConfiguracoesScreen(
            perfil: const PerfilResumo(
              apelido: 'Você',
              email: '',
              vip: false,
              moedas: 0,
            ),
            config: const Configuracoes(versaoApp: '1.0.0'),
            onVoltar: () {},
            orientacaoMesa: MesaOrientacaoPreferida.vertical,
            onOrientacaoMesa: escolhidas.add,
            callbacks: ConfiguracoesCallbacks(
              onAlterar: (_) {},
              onEditarPerfil: () {},
              onAssinaturaVip: () {},
              onMoedasCompras: () {},
              onBloqueados: () {},
              onRegras: () {},
              onSuporte: () {},
              onTermos: () {},
              onAvaliar: () {},
              onSair: () {},
              // `onExcluirConta` e obrigatorio desde a OS de Exclusao de Conta.
              onExcluirConta: () {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Orientação da mesa'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('Horizontal'), findsOneWidget);
      expect(find.text('Automática'), findsOneWidget);

      await tester.ensureVisible(find.text('Horizontal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Horizontal'));
      await tester.pump();

      expect(escolhidas, [MesaOrientacaoPreferida.horizontal]);
    });

    testWidgets('sem callback a linha nao aparece', (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      await tester.pumpWidget(
        MaterialApp(
          home: ConfiguracoesScreen(
            perfil: const PerfilResumo(
              apelido: 'Você',
              email: '',
              vip: false,
              moedas: 0,
            ),
            config: const Configuracoes(versaoApp: '1.0.0'),
            onVoltar: () {},
            callbacks: ConfiguracoesCallbacks(
              onAlterar: (_) {},
              onEditarPerfil: () {},
              onAssinaturaVip: () {},
              onMoedasCompras: () {},
              onBloqueados: () {},
              onRegras: () {},
              onSuporte: () {},
              onTermos: () {},
              onAvaliar: () {},
              onSair: () {},
              // `onExcluirConta` e obrigatorio desde a OS de Exclusao de Conta.
              onExcluirConta: () {},
            ),
          ),
        ),
      );

      expect(find.text('Orientação da mesa'), findsNothing);
    });
  });

  group('Mesa em runtime', () {
    testWidgets('o menu da Mesa oferece a mesma escolha de orientacao',
        (tester) async {
      usarTelefoneRetrato(tester);
      ignorarOverflowDaFonteDeTeste();

      await tester.pumpWidget(const MaterialApp(home: MesaScreen()));
      await tester.pump();

      await tester.tap(find.byTooltip('Menu da mesa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MesaOrientacaoSelector), findsOneWidget);
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('Horizontal'), findsOneWidget);
      expect(find.text('Automática'), findsOneWidget);

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('girar troca a composicao sem reiniciar a partida',
        (tester) async {
      usarTelefoneRetrato(tester, logico: const Size(800, 360));
      ignorarOverflowDaFonteDeTeste();

      await tester.pumpWidget(const MaterialApp(home: MesaScreen()));
      await tester.pump();

      final antes = _assinaturaDaPartida(tester);
      expect(antes, isNotEmpty);

      await tester.tap(find.byTooltip('Menu da mesa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Horizontal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Fecha a folha do menu para conferir a mesa em si.
      await tester.tapAt(const Offset(400, 20));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Mesma partida: mao, placar e contagem de cartas atravessam a troca.
      expect(_assinaturaDaPartida(tester), antes);
      // E continua sendo a MESMA MesaScreen — nao houve recriacao de estado.
      expect(find.byType(MesaScreen), findsOneWidget);
      // A composicao mudou de verdade.
      expect(find.byKey(const ValueKey('mesa-horizontal')), findsOneWidget);
      // Nada some ao girar: rodape do jogador, rail de acoes e o placar
      // continuam na tela (adendo §3).
      expect(find.textContaining('VOCÊ'), findsOneWidget);
      expect(find.byTooltip('Menu da mesa'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);

      await desmontarEDrenarTimers(tester);
    });

    testWidgets('o horizontal e composicao propria, nao a vertical girada',
        (tester) async {
      usarTelefoneRetrato(tester, logico: const Size(800, 360));
      ignorarOverflowDaFonteDeTeste();

      await tester.pumpWidget(
        const MaterialApp(home: MesaScreen()),
      );
      await tester.pump();

      // Proibicao explicita do adendo §3.
      expect(find.byType(RotatedBox), findsNothing);

      await desmontarEDrenarTimers(tester);
    });
  });

  group('O menu nao mexe nos controles da partida', () {
    // O acesso ao menu nasceu na coluna de acoes e foi movido para o
    // cabecalho: a coluna e ancorada pela base, entao um quarto botao empurrava
    // chat, expressoes e som 45 px para cima. Trocar orientacao e configuracao,
    // nao jogada, e nao pode deslocar controle ja aprovado da partida.
    for (final tela in const [Size(390, 844), Size(320, 640)]) {
      testWidgets('em ${tela.width.toInt()}x${tela.height.toInt()} o menu fica '
          'no cabecalho, sem encostar no placar', (tester) async {
        usarTelefoneRetrato(tester, logico: tela);
        ignorarOverflowDaFonteDeTeste();

        await tester.pumpWidget(const MaterialApp(home: MesaScreen()));
        await tester.pump();

        final menu = tester.getRect(find.byTooltip('Menu da mesa'));
        final chat = tester.getRect(find.byIcon(Icons.chat_bubble_rounded));
        final placar = tester.getRect(find.text('Pontuação'));

        // Esta no cabecalho, muito acima do rail — nao e um quarto botao dele.
        expect(menu.bottom, lessThan(chat.top));
        // E nao invade a ultima metrica do cabecalho.
        expect(placar.right, lessThanOrEqualTo(menu.left));
        // Continua dentro da tela.
        expect(menu.right, lessThanOrEqualTo(tela.width));

        // A coluna de acoes segue com os tres botoes de sempre.
        expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
        expect(
          find.byIcon(Icons.sentiment_satisfied_alt_rounded),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

        // E o menu abre de dentro da partida.
        await tester.tap(find.byTooltip('Menu da mesa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MesaOrientacaoSelector), findsOneWidget);

        await desmontarEDrenarTimers(tester);
      });
    }
  });

  group('Responsividade (adendo §9)', () {
    // Sem `ignorarOverflowDaFonteDeTeste` de proposito: aqui o estouro de
    // layout e justamente o que se quer detectar. Confirmado que a Mesa nao
    // depende de metrica de fonte para caber — quem estourava eram telas com
    // paineis de altura travada, nao esta.
    final matriz = <String, ({Size tela, bool deitada})>{
      'telefone estreito em retrato': (tela: Size(320, 640), deitada: false),
      'telefone comum em retrato': (tela: Size(390, 844), deitada: false),
      'telefone comum deitado': (tela: Size(640, 360), deitada: true),
      'telefone grande deitado': (tela: Size(844, 390), deitada: true),
      'deitado bem baixo': (tela: Size(740, 320), deitada: true),
      'proporcao muito larga': (tela: Size(1280, 400), deitada: true),
    };

    matriz.forEach((nome, caso) {
      testWidgets('$nome escolhe a composicao que cabe', (tester) async {
        usarTelefoneRetrato(tester, logico: caso.tela);

        await tester.pumpWidget(const MaterialApp(home: MesaScreen()));
        await tester.pump();

        // Pede Horizontal em todos os casos: onde a largura nao comporta as
        // tres colunas, a Mesa fica na composicao vertical em vez de cortar
        // carta. Pedir a rotacao nao garante que o aparelho gire.
        await tester.tap(find.byTooltip('Menu da mesa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Horizontal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tapAt(Offset(caso.tela.width / 2, 12));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('mesa-horizontal')),
          caso.deitada ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('mesa-vertical')),
          caso.deitada ? findsNothing : findsOneWidget,
        );

        await desmontarEDrenarTimers(tester);
      });
    });
  });
}
