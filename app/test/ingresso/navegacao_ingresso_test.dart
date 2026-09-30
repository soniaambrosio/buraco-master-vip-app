@Timeout(Duration(minutes: 20))
library;

// navegacao_ingresso_test.dart — O FLUXO INTEIRO (OS 38.3 §2, §12 e §15.4).
//
// UMA AFIRMAÇÃO:
//
//   Home → Onde Jogar → Lobby Público → mesa → assento → pedido → ACK → mesa.
//   E NADA nesse caminho anda um passo antes do ACK.
//
// Tudo é código de produção: a `RaizDoAplicativo` de verdade, a
// `SessaoDoJogador` de verdade, a `PonteSessaoOnline` de verdade e o
// `OnlineService` de verdade. Falsas são as quatro pontas do mundo. NENHUM
// CASO ABRE REDE.
//
// POR QUE ISTO PRECISA DE SUÍTE PRÓPRIA: nenhuma das outras percorre o
// caminho. A do transporte prova o fio e não sabe onde a pessoa está; a da
// tela prova o desenho e não tem `Navigator` de verdade acima dela. O defeito
// que esta suíte existe para pegar — navegar antes do veredito, ou navegar
// duas vezes — só é visível com a pilha real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/escolha_assento_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/lobby_publico_de_producao.dart';
import 'package:buraco_master_vip/ingresso/contrato_ingresso.dart';
import 'package:buraco_master_vip/ingresso/estado_ingresso.dart';

import '../casca/bancada_online.dart';
import '../descoberta/retrato_de_teste.dart';
import 'cena_de_ingresso.dart';

/// O aplicativo aberto, autenticado, com uma mesa pública na lista e o Lobby
/// na tela.
Future<Bancada> comLobbyAberto(
  WidgetTester tester, {
  bool iniciada = false,
  int humanos = 1,
}) async {
  final b = Bancada(uidInicial: 'uid-A');
  addTearDown(b.fechar);
  await abrirAplicativo(tester, b);
  await servidorAceita(tester, b);
  b.canal.servidorEnvia(
    retratoDeMesas(
      mesas: [
        mesa(
          codigo: 'CODIGO-OPACO-1',
          humanos: humanos,
          iniciada: iniciada,
          apelidos: const ['Ana', 'Bia', 'Cida'],
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  await irAoLobbyPublico(tester);
  return b;
}

/// Do Lobby para o seletor, pelo toque de verdade no card.
Future<void> abrirSeletor(WidgetTester tester) async {
  await tester.tap(find.text('Mesa de Ana'));
  await tester.pumpAndSettle();
  expect(find.byType(EscolhaAssentoDeProducao), findsOneWidget);
}

/// Pede a posição 3 (assento 2) pelo toque de verdade.
Future<void> pedirPosicao3(WidgetTester tester) async {
  await tester.tap(find.text('Posição 3'));
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  group('§2 · §12 — O CAMINHO', () {
    // =======================================================================

    testWidgets('NV-01 Lobby → card → SELETOR DE ASSENTO (e não a mesa)', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);

      // O card NÃO executou ingresso: nenhum `entrarMesa` saiu.
      expect(
        pedidosDeIngresso(b),
        isEmpty,
        reason:
            'entrar direto entraria em QUALQUER lugar, e a pessoa descobriria '
            'onde sentou depois de sentar',
      );
      expect(find.byType(LobbyOnline), findsNothing);
      // E as quatro cadeiras estão à vista.
      for (var i = 1; i <= 4; i++) {
        expect(find.text('Posição $i'), findsOneWidget);
      }
      aquietar(b);
    });

    testWidgets('NV-02 mesa EM ANDAMENTO: o card nem é botão', (tester) async {
      final b = await comLobbyAberto(tester, iniciada: true, humanos: 2);
      final sem = tester.ensureSemantics();
      final cards = find.semantics
          .byPredicate((n) => n.label.contains('Mesa de Ana'))
          .evaluate()
          .toList();
      expect(cards, hasLength(1));
      expect(
        cards.single.flagsCollection.isButton,
        isFalse,
        reason:
            '`ingressavel` vem do servidor; um card clicável aqui mandaria a '
            'pessoa buscar uma recusa que o retrato já sabia dar',
      );
      sem.dispose();
      aquietar(b);
    });

    testWidgets('NV-03 o toque na cadeira manda o pedido — e SÓ ele', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      final p = pedidosDeIngresso(b);
      expect(p, hasLength(1));
      expect(p.single['codigo'], 'CODIGO-OPACO-1');
      expect(p.single[ContratoDoIngresso.campoAssento], 2);
      expect(
        p.single['apelido'],
        'Ana',
        reason: 'o apelido vem da identidade pública da sessão canônica',
      );
      aquietar(b);
    });
  });

  // =========================================================================
  group('§8.2 · §15.4 — NAVEGAÇÃO SÓ DEPOIS DO ACK', () {
    // =======================================================================

    testWidgets('NV-04 pedido em voo NÃO navega', (tester) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      // Vários quadros depois, ainda no seletor.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pumpAndSettle();

      expect(find.byType(EscolhaAssentoDeProducao), findsOneWidget);
      expect(find.byType(LobbyOnline), findsNothing);
      expect(b.online.ingresso.fase, FaseDoIngresso.solicitando);
      aquietar(b);
    });

    testWidgets('NV-05 ACK positivo navega UMA vez, para a mesa', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      b.canal.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LobbyOnline), findsOneWidget);
      expect(find.byType(EscolhaAssentoDeProducao), findsNothing);

      // E O SELETOR SAIU DA PILHA, não só da tela.
      //
      // `findsNothing` sozinho NÃO prova isso: a rota debaixo de uma rota
      // opaca também não aparece nos finders, então trocar
      // `pushReplacement` por `push` passava despercebido — foi a mutação
      // I14, e ela escapou. Quem distingue as duas é o VOLTAR: com `push`,
      // sair da mesa devolveria a pessoa a um seletor de cadeiras de uma
      // mesa em que ela já está sentada.
      await voltar(tester);
      expect(
        find.byType(LobbyPublicoDeProducao),
        findsOneWidget,
        reason: 'voltar da mesa devolve à LISTA, e não ao seletor',
      );
      expect(find.byType(EscolhaAssentoDeProducao), findsNothing);
      aquietar(b);
    });

    testWidgets('NV-06 ACK DUPLICADO não empilha um segundo destino', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      b.canal.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      b.canal.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LobbyOnline), findsOneWidget);
      aquietar(b);
    });

    testWidgets('NV-07 o DESTINO recebe a mesa e o assento CONFIRMADOS', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);
      b.canal.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      await tester.pumpAndSettle();

      final destino = tester.widget<LobbyOnline>(find.byType(LobbyOnline));
      final confirmado = destino.ingressoConfirmado;
      expect(confirmado, isNotNull);
      expect(confirmado!.codigo, 'CODIGO-OPACO-1');
      expect(
        confirmado.assento,
        2,
        reason: 'o assento vem do ACK, e de nenhuma conta local',
      );
      // E a pessoa vê onde sentou.
      expect(find.textContaining('posição 3'), findsWidgets);
      aquietar(b);
    });

    testWidgets('NV-08 a RECUSA não navega, e a pessoa fica no seletor', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      b.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      expect(find.byType(LobbyOnline), findsNothing);
      expect(find.byType(EscolhaAssentoDeProducao), findsOneWidget);
      expect(
        find.textContaining('acabou de ser ocupada'),
        findsWidgets,
        reason: 'a recusa é PERCEPTÍVEL, e não um silêncio',
      );
      expect(
        pedidosDeIngresso(b),
        hasLength(1),
        reason: 'nenhuma segunda tentativa nasceu sozinha',
      );
      aquietar(b);
    });

    testWidgets('NV-09 depois da recusa, a pessoa escolhe OUTRA cadeira', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);
      b.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      // O gesto é DELA.
      await tester.tap(find.text('Posição 4'));
      await tester.pumpAndSettle();

      final p = pedidosDeIngresso(b);
      expect(p, hasLength(2));
      expect(p.last[ContratoDoIngresso.campoAssento], 3);
      expect(find.byType(LobbyOnline), findsNothing);
      aquietar(b);
    });

    testWidgets('NV-10 SAIR do seletor invalida o pedido: o ACK tardio não navega', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      await voltar(tester);
      expect(find.byType(LobbyPublicoDeProducao), findsOneWidget);

      // O servidor responde depois.
      b.canal.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(LobbyOnline),
        findsNothing,
        reason: 'callback tardio não navega',
      );
      expect(find.byType(LobbyPublicoDeProducao), findsOneWidget);
      aquietar(b);
    });

    testWidgets('NV-15 sair do seletor LIBERA a próxima escolha', (
      tester,
    ) async {
      // O QUE A MUTAÇÃO I15 REVELOU. Apagar o cancelamento do `dispose` não
      // quebrava NV-10: o host desmontado já não navega, faça o que fizer o
      // ACK. O estrago aparece um passo depois — a intenção fica em voo para
      // sempre, e a pessoa não consegue mais pedir cadeira NENHUMA, em mesa
      // nenhuma, até o socket cair.
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);
      expect(pedidosDeIngresso(b), hasLength(1));

      // Sai com o pedido em voo, e volta a entrar.
      await voltar(tester);
      await abrirSeletor(tester);
      await tester.tap(find.text('Posição 2'));
      await tester.pumpAndSettle();

      final p = pedidosDeIngresso(b);
      expect(
        p,
        hasLength(2),
        reason:
            'o segundo pedido tem de SAIR: a intenção anterior morreu quando '
            'a tela que a criou foi embora',
      );
      expect(p.last[ContratoDoIngresso.campoAssento], 1);
      aquietar(b);
    });

    testWidgets('NV-11 TROCA DE CONTA no meio do pedido não navega', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      final canalDeA = b.canal;
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      canalDeA.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LobbyOnline), findsNothing);
      aquietar(b);
    });

    testWidgets('NV-12 SESSÃO ENCERRADA não navega', (tester) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      await pedirPosicao3(tester);

      final canalDeA = b.canal;
      b.fluxo.add(null); // logout
      await tester.pumpAndSettle();

      canalDeA.servidorEnvia(
        ackDeIngresso(codigo: 'CODIGO-OPACO-1', assento: 2),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LobbyOnline), findsNothing);
      expect(b.online.ingresso.temConfirmacaoPendente, isFalse);
      aquietar(b);
    });
  });

  // =========================================================================
  group('§14 — O QUE A INTERFACE NÃO MOSTRA', () {
    // =======================================================================

    testWidgets('NV-13 zero identidade interna na tela do seletor', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      final sem = tester.ensureSemantics();

      final tudo = [
        ...tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}'),
        ...find.semantics
            .byPredicate((_) => true)
            .evaluate()
            .map((n) => n.label),
      ].join(' | ');

      for (final proibido in const [
        'uid-A',
        'uid',
        'jogadorId',
        'token-de-teste',
        'token',
        'credencial',
        'CODIGO-OPACO-1',
      ]) {
        expect(tudo, isNot(contains(proibido)), reason: proibido);
      }
      sem.dispose();
      aquietar(b);
    });

    testWidgets('NV-14 o ingresso NÃO toca a projeção da descoberta', (
      tester,
    ) async {
      final b = await comLobbyAberto(tester);
      await abrirSeletor(tester);
      final revisaoAntes = b.online.descoberta.retrato!.revisao;

      await pedirPosicao3(tester);
      b.canal.servidorEnvia(recusaAssentoOcupado());
      await tester.pumpAndSettle();

      expect(
        b.online.descoberta.retrato!.revisao,
        revisaoAntes,
        reason: 'as duas projeções não se tocam',
      );
      expect(b.online.descoberta.retrato!.mesas, hasLength(1));
      aquietar(b);
    });
  });
}
