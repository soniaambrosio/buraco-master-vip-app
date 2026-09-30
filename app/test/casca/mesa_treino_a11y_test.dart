// mesa_treino_a11y_test.dart — a acessibilidade da Mesa de Treino, reexpressa
// sobre a mesa ATUAL (BMV-PUB-C1-COMP1, bloco E10, porte de b1616669).
//
// ---------------------------------------------------------------------------
// POR QUE ESTA SUÍTE, E NÃO AS DA ENTREGA
// ---------------------------------------------------------------------------
//
// A entrega de origem (OS 29 / 29-C1 / 29-C7) caracterizou uma mesa que já não
// existe nesta base: rodapé de 180, HUD de 52, núcleo de 118 e a mão numa
// geometria nova (passo de 48, duas fileiras). A base aprovou depois outra mesa
// — lados iguais, núcleo de 104, HUD compacto de 42, rodapé de 170 e variante
// deitada. Por decisão da Central, as caracterizações antigas NÃO entram
// literalmente: são reexpressas aqui, em três eixos separados, porque cada um
// quebra por um caminho diferente e merece a própria reprovação:
//
//   1. GEOMETRIA VISUAL ATUAL — o desenho aprovado não se mexe;
//   2. ALVO INTERATIVO — onde o piso de 48 foi alcançado sem mudar o desenho,
//      ele é medido; onde não foi, a Central registrou HOLD LOCALIZADO;
//   3. SEMÂNTICA — nome, papel, estado e ação de cada controle.
//
// HOLD LOCALIZADO (decisão da Central, registrado no laudo da COMP1):
//
//   * a mão do jogador: o alvo continua sendo a faixa descoberta de cada carta
//     (22–28 pontos na mão aprovada). A semântica entra; a geometria, não;
//   * a aba do assento inativo (12 × 46): crescer para 48 cobriria a borda da
//     área de jogos, onde há jogos baixados tocáveis;
//   * o HUD compacto do jogador em retrato (faixa de 42): crescer para 48 sem
//     mudar o desenho invadiria a mão ou a área de jogos.
//
// Esta suíte NÃO afirma o piso nesses três pontos — afirmar um defeito seria
// um teste que precisa ser apagado quando o defeito for corrigido.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/cartas/nome_falavel_da_carta.dart';
import 'package:buraco_master_vip/mesa.dart';

/// Um telefone de 360 × 780 pontos, a 3×: a largura da auditoria de a11y.
const Size _superficie = Size(1080, 2340);

Future<void> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = _superficie;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: MesaScreen(variant: MesaVariant.publica)),
  );
  await tester.pump();
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

/// Os nós da mesa na ordem em que um leitor de tela os percorre. Exige
/// `tester.ensureSemantics()` — e reprova se a árvore vier vazia, porque uma
/// varredura vazia fica verde justamente no dia em que a tela parou de montar.
List<SemanticsNode> _arvore(WidgetTester tester) {
  final nos = tester.semantics.simulatedAccessibilityTraversal().toList();
  expect(nos.length, greaterThan(10), reason: 'a árvore semântica veio vazia');
  return nos;
}

bool _botao(SemanticsNode n) => n.getSemanticsData().flagsCollection.isButton;
Tristate _habilitado(SemanticsNode n) =>
    n.getSemanticsData().flagsCollection.isEnabled;

/// O retângulo (em pontos lógicos, na tela) do widget `Semantics` com [rotulo].
Rect _alvo(WidgetTester tester, Pattern rotulo) {
  final f = find.byWidgetPredicate(
    (w) =>
        w is Semantics &&
        w.properties.label != null &&
        (rotulo is String
            ? w.properties.label == rotulo
            : (rotulo as RegExp).hasMatch(w.properties.label!)),
  );
  expect(f, findsOneWidget, reason: 'não achei o controle "$rotulo"');
  return tester.getRect(f);
}

/// Os discos desenhados da lateral (38 × 38, círculo), de cima para baixo.
List<Rect> _discosDoRail(WidgetTester tester) {
  final discos = tester
      .widgetList<Container>(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints ==
                  const BoxConstraints.tightFor(width: 38, height: 38) &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      )
      .map((c) => tester.getRect(find.byWidget(c)))
      .toList()
    ..sort((a, b) => a.top.compareTo(b.top));
  return discos;
}

bool _sobrepoe(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 0.01 && i.height > 0.01;
}

void main() {
  group('o nome falável da carta (autoridade única)', () {
    test('figuras viram palavras; números ficam para o sintetizador', () {
      expect(nomeFalavelDaCarta(valor: 'K', naipe: 'espadas'), 'rei de espadas');
      expect(nomeFalavelDaCarta(valor: 'A', naipe: 'ouros'), 'ás de ouros');
      expect(nomeFalavelDaCarta(valor: 'Q', naipe: 'copas'), 'dama de copas');
      expect(nomeFalavelDaCarta(valor: 'J', naipe: 'paus'), 'valete de paus');
      expect(nomeFalavelDaCarta(valor: '7', naipe: 'copas'), '7 de copas');
    });

    test('curinga e naipe desconhecido não viram código na fala', () {
      expect(nomeFalavelDaCarta(valor: 'JOKER'), 'curinga');
      expect(nomeFalavelDaCarta(valor: 'JOKER', naipe: 'copas'), 'curinga');
      expect(nomeFalavelDaCarta(valor: '5', naipe: 'xyz'), '5');
    });
  });

  group('geometria visual atual (o desenho aprovado não se mexe)', () {
    testWidgets('os três discos da lateral: 38 × 38, passo de 45, mesma coluna',
        (tester) async {
      await _abrir(tester);
      final discos = _discosDoRail(tester);
      expect(discos, hasLength(3));
      for (final d in discos) {
        expect(d.width, 38);
        expect(d.height, 38);
      }
      expect(discos[1].top - discos[0].top, closeTo(45, 0.01));
      expect(discos[2].top - discos[1].top, closeTo(45, 0.01));
      expect(discos[0].right, discos[1].right);
      expect(discos[1].right, discos[2].right);
      await _fechar(tester);
    });

    testWidgets('o disco de baixo termina 8 acima do rodapé, e a coluna a 4 da borda',
        (tester) async {
      await _abrir(tester);
      final discos = _discosDoRail(tester);
      // O HUD é a primeira faixa do rodapé: o topo dele É o topo do rodapé.
      final hud = _alvo(tester, RegExp(r'^você, \d+ cartas?(, jogando agora)?$'));
      expect(discos.last.bottom, closeTo(hud.top - 8, 0.01),
          reason: 'o desenho da lateral subiu ou desceu em relação ao rodapé');
      // Borda interna do feltro: margem 3 + moldura 2 + borda 1,5.
      final larguraLogica = _superficie.width / 3;
      expect(discos.last.right, closeTo(larguraLogica - 6.5 - 4, 0.01),
          reason: 'a coluna da lateral saiu da borda direita da mesa');
      await _fechar(tester);
    });

    testWidgets('o HUD compacto do jogador continua com 42 e avatar de 40',
        (tester) async {
      await _abrir(tester);
      final hud = _alvo(tester, RegExp(r'^você, \d+ cartas?(, jogando agora)?$'));
      expect(hud.height, 42);
      final avatar = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.hint == 'ver o jogador',
        ),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.constraints ==
                  const BoxConstraints.tightFor(width: 40, height: 40),
        ),
      );
      expect(avatar, findsOneWidget);
      await _fechar(tester);
    });
  });

  group('alvo interativo (piso de 48 onde o desenho permite)', () {
    testWidgets('cada controle lateral tem 48 × 48, e os três não se sobrepõem',
        (tester) async {
      await _abrir(tester);
      final alvos = [
        _alvo(tester, RegExp(r'^chat')),
        _alvo(tester, 'expressões'),
        _alvo(tester, 'som'),
      ];
      for (final a in alvos) {
        expect(a.width, greaterThanOrEqualTo(48));
        expect(a.height, greaterThanOrEqualTo(48));
      }
      for (var i = 0; i < alvos.length; i++) {
        for (var k = i + 1; k < alvos.length; k++) {
          expect(_sobrepoe(alvos[i], alvos[k]), isFalse,
              reason: 'as faixas $i e $k se sobrepõem');
        }
      }
      // Cada disco mora DENTRO da própria faixa — o toque no desenho acerta
      // o dono dele.
      final discos = _discosDoRail(tester);
      for (var i = 0; i < 3; i++) {
        expect(alvos[i].contains(discos[i].center), isTrue);
        expect(
          alvos[i].intersect(discos[i]).width * alvos[i].intersect(discos[i]).height,
          closeTo(38 * 38, 0.01),
          reason: 'o disco $i não cabe inteiro na própria faixa',
        );
      }
      await _fechar(tester);
    });

    testWidgets('o toque na borda da faixa aciona o controle dela', (tester) async {
      final h = tester.ensureSemantics();
      await _abrir(tester);
      final som = _alvo(tester, 'som');
      final antes = tester.getSemantics(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'som'),
      );
      final ligadoAntes = antes.getSemanticsData().flagsCollection.isToggled;
      // Canto superior esquerdo da faixa, FORA do disco de 38.
      await tester.tapAt(som.topLeft + const Offset(2, 2));
      await tester.pump();
      final depois = tester.getSemantics(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'som'),
      );
      expect(depois.getSemanticsData().flagsCollection.isToggled,
          isNot(ligadoAntes),
          reason: 'a região acionável não é a faixa inteira');
      await _fechar(tester);
      h.dispose();
    });

    testWidgets('monte, lixo e os dois mortos passam do piso', (tester) async {
      await _abrir(tester);
      for (final r in [
        RegExp(r'^monte, '),
        RegExp(r'^lixo( aberto)?, '),
        RegExp(r'^morto 1, '),
        RegExp(r'^morto 2, '),
      ]) {
        final a = _alvo(tester, r);
        expect(a.width, greaterThanOrEqualTo(48), reason: '$r');
        expect(a.height, greaterThanOrEqualTo(48), reason: '$r');
      }
      await _fechar(tester);
    });
  });

  group('semântica', () {
    testWidgets('nó tocável nenhum fica sem nome', (tester) async {
      final h = tester.ensureSemantics();
      await _abrir(tester);
      final mudos = _arvore(tester).where((n) {
        final d = n.getSemanticsData();
        final nome = '${d.label}${d.value}${d.hint}${d.tooltip}'.trim();
        return d.hasAction(SemanticsAction.tap) && nome.isEmpty;
      }).toList();
      expect(mudos, isEmpty,
          reason: 'sobraram ${mudos.length} nós tocáveis sem nome: $mudos');
      await _fechar(tester);
      h.dispose();
    });

    testWidgets('a lateral diz o nome, e o som diz o estado', (tester) async {
      final h = tester.ensureSemantics();
      await _abrir(tester);
      final nos = _arvore(tester);
      for (final nome in ['expressões', 'som']) {
        final n = nos.singleWhere((x) => x.label == nome);
        expect(_botao(n), isTrue, reason: nome);
        expect(_habilitado(n), Tristate.isTrue, reason: nome);
      }
      expect(nos.where((x) => x.label.startsWith('chat')), hasLength(1));
      final som = nos.singleWhere((x) => x.label == 'som');
      expect(som.getSemanticsData().flagsCollection.isToggled,
          isNot(Tristate.none),
          reason: 'o som não diz se está ligado');
      await _fechar(tester);
      h.dispose();
    });

    testWidgets('o centro fala nome e contagem, uma vez cada', (tester) async {
      final h = tester.ensureSemantics();
      await _abrir(tester);
      final nos = _arvore(tester);
      expect(nos.where((n) => RegExp(r'^monte, \d+ cartas?$').hasMatch(n.label)),
          hasLength(1));
      expect(nos.where((n) => RegExp(r'^lixo( aberto)?, \d+ cartas?').hasMatch(n.label)),
          hasLength(1));
      expect(nos.where((n) => n.label.startsWith('morto 1, ')), hasLength(1));
      expect(nos.where((n) => n.label.startsWith('morto 2, ')), hasLength(1));
      // As tarjas pintadas não sobram como nós soltos.
      expect(nos.where((n) => n.label == 'MONTE'), isEmpty);
      expect(nos.where((n) => n.label == 'MORTO'), isEmpty);
      await _fechar(tester);
      h.dispose();
    });

    testWidgets('cada jogador é UM nó, e o avatar não vira o segundo',
        (tester) async {
      final h = tester.ensureSemantics();
      await _abrir(tester);
      final assentos = _arvore(tester)
          .where((n) => n.getSemanticsData().hint == 'ver o jogador')
          .toList();
      expect(assentos, hasLength(4), reason: 'são quatro jogadores na mesa');
      for (final a in assentos) {
        expect(_botao(a), isTrue);
        expect(a.label, matches(RegExp(r'\d+ cartas?')));
      }
      expect(assentos.where((a) => a.label.contains('seu parceiro, robô')),
          hasLength(1));
      expect(assentos.where((a) => a.label.contains('adversário, robô')),
          hasLength(2));
      // O texto "VOCÊ • N cartas" não sobra como segundo nó do jogador.
      expect(_arvore(tester).where((n) => n.label.startsWith('VOCÊ')), isEmpty);
      await _fechar(tester);
      h.dispose();
    });

    testWidgets('a mão fala cada carta, com posição, na ordem da mão',
        (tester) async {
      final h = tester.ensureSemantics();
      await _abrir(tester);
      final cartas = _arvore(tester)
          .where((n) => RegExp(r', carta \d+ de \d+').hasMatch(n.label))
          .toList();
      expect(cartas, isNotEmpty);
      final total = cartas.length;
      final posicoes = <int>{
        for (final c in cartas)
          int.parse(RegExp(r'carta (\d+) de').firstMatch(c.label)!.group(1)!),
      };
      expect(posicoes, {for (var i = 1; i <= total; i++) i},
          reason: 'posições faltando ou repetidas');
      for (final c in cartas) {
        expect(c.label, endsWith('de $total') ,
            reason: 'o total falado diverge do tamanho da mão');
        expect(_botao(c), isTrue);
      }
      // O contador pintado da mão não é um terceiro anúncio do total.
      expect(_arvore(tester).where((n) => n.label == '$total'), isEmpty);
      await _fechar(tester);
      h.dispose();
    });
  });
}
