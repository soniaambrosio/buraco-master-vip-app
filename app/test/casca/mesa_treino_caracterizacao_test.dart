// mesa_treino_caracterizacao_test.dart — a Mesa de Treino COMO ELA ESTÁ HOJE.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO É ESCRITO ANTES DA CORREÇÃO
// ---------------------------------------------------------------------------
//
// A OS de acessibilidade manda mexer em `lib/mesa.dart` — motor, regras e tela
// no mesmo arquivo, a única superfície de jogo que funciona de ponta a ponta.
// Um teste escrito depois prova que a mudança funciona; ele não prova que o que
// já existia continua de pé, porque nunca viu o estado anterior.
//
// Então este arquivo é escrito ANTES, contra a base congelada
// `bf5a9e7ed0a51ae2c55f249d87c930bb88e76a0c`.
//
// ---------------------------------------------------------------------------
// AS COISAS FICAM SEPARADAS
// ---------------------------------------------------------------------------
//
//   * `ação real` — o que o toque faz com a PARTIDA: seleciona, desfaz, compra
//     no monte, descarta no lixo, aciona os três controles laterais. Nada aqui
//     fala de onde a carta aparece na tela;
//   * `desenho` — onde as cartas ficam, e onde elas CONTINUAM depois de mexer.
//
// A separação não é estética. Uma correção de acessibilidade que mexe em
// geometria pode passar num teste de ação e quebrar o desenho, ou o contrário —
// e um caso que mistura os dois não diz qual dos dois quebrou.
//
// ---------------------------------------------------------------------------
// O GRUPO `defeito` VIVEU AQUI, E FOI REMOVIDO PELO COMMIT QUE CORRIGE
// ---------------------------------------------------------------------------
//
// Ele mediu, contra `bf5a9e7`, as cinco coisas que a auditoria de acessibilidade
// de 19/08/2026 encontrou:
//
//     faixa efetiva de toque .... [21, 21, 21, 21, 22, 21, 21, 21, 21, 21, 66]
//     mão para o leitor de tela . onze nós de imagem, todos sem rótulo
//     monte, lixo e mortos ...... lidos pelas tarjas de desenho, sem nome
//     chat, expressões e som .... nó nenhum
//     ordem da mão .............. a carta escolhida ia para o fim da lista
//
// Não era contrato: era a fotografia do buraco. Cada caso dele foi substituído
// pelo seu oposto em `mesa_treino_acessivel_test.dart`, no MESMO commit da
// correção. Quem quiser conferir a passagem de "muda e intocável" para "audível
// e tocável" lê o `git log` deste arquivo, e não uma frase de relatório.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bancada_mesa_treino.dart';

void main() {
  // =========================================================================
  // AÇÃO REAL — o que o toque faz com a partida
  // =========================================================================
  group('ação real', () {
    testWidgets('a mão abre com onze cartas', (tester) async {
      await abrirMesaDeTreino(tester);

      expect(cartasDaMao(tester), hasLength(11));
      expect(find.textContaining('11 cartas'), findsOneWidget);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('tocar seleciona, tocar de novo desfaz', (tester) async {
      await abrirMesaDeTreino(tester);

      final rects = cartasDaMao(tester);
      // A última carta é a única que hoje aparece inteira, e por isso é a única
      // em que um toque no centro é garantido antes da correção.
      final centro = rects.last.center;

      expect(selecionadasNaMao(tester), isEmpty);
      expect(await tocarEm(tester, centro), <int>{rects.length - 1});
      expect(await tocarEm(tester, centro), isEmpty);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('comprar no monte, selecionar e descartar no lixo', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);
      expect(cartasDaMao(tester), hasLength(11));

      await tester.tap(find.text('MONTE'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        cartasDaMao(tester),
        hasLength(12),
        reason: 'a compra no monte não entregou a carta',
      );

      await tocarEm(tester, cartasDaMao(tester).last.center);
      expect(selecionadasNaMao(tester), hasLength(1));

      await tester.tap(find.textContaining('LIXO'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        cartasDaMao(tester),
        hasLength(11),
        reason: 'o descarte não saiu da mão',
      );

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('os três controles laterais respondem ao toque', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      await tester.tap(find.byIcon(Icons.chat_bubble_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('Chat'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.sentiment_satisfied_alt_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.textContaining('Expressões'), findsOneWidget);

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byIcon(Icons.volume_off_rounded),
        findsOneWidget,
        reason: 'o controle de som não alternou',
      );

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // DESENHO — onde as cartas ficam, e onde continuam depois de mexer
  // =========================================================================
  group('desenho', () {
    testWidgets('as cartas ficam lado a lado, em passo constante', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final rects = cartasDaMao(tester);
      final passos = <double>[
        for (var i = 1; i < rects.length; i++)
          rects[i].left - rects[i - 1].left,
      ];
      for (final p in passos) {
        expect(
          p,
          closeTo(passos.first, 0.01),
          reason: 'a mão deixou de ter passo único entre as cartas',
        );
      }
      expect(passos.first, greaterThan(0));

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('selecionar não move a posição lógica de carta nenhuma', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final antes = cartasDaMao(tester).map((r) => r.left).toList();
      await tocarEm(tester, cartasDaMao(tester).last.center);
      final depois = cartasDaMao(tester).map((r) => r.left).toList();

      expect(depois, hasLength(antes.length));
      for (var i = 0; i < antes.length; i++) {
        expect(depois[i], closeTo(antes[i], 0.01));
      }

      await encerrarMesaDeTreino(tester);
    });
  });
}
