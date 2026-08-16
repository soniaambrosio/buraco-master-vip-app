// mesa_online_test.dart — a Casca V2 alcançando a mesa real.
//
// O aplicativo montado aqui é o de produção, do `RaizDoAplicativo` para baixo,
// e o caminho percorrido é o que a pessoa percorre: Home → Jogar → Mesa por
// código → criar mesa → o servidor manda a partida. Falso é só o canal
// WebSocket, e as visões que ele entrega são cópias do contrato do servidor.
//
// A pergunta que organiza o arquivo é sempre a mesma: QUEM MANDA. O servidor
// manda no estado; a tela mostra e pede. Cada grupo abaixo persegue uma forma
// de essa fronteira vazar — a mesa que se desenha sozinha, o comando que sai
// duas vezes, a carta alheia que aparece, a jogada aplicada antes da resposta,
// a sessão que acaba e a tela que continua.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/mesa_online/mesa_online_screen.dart';
import 'package:buraco_master_vip/casca/onde_jogar_de_producao.dart';
import 'package:buraco_master_vip/services/online_service.dart';

import 'bancada_online.dart';

// ===========================================================================
// O caminho
// ===========================================================================

Future<void> abrirAplicativo(WidgetTester tester, Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

/// Home → Jogar → Mesa por código, com o servidor aceitando a credencial.
Future<void> irAoLobby(WidgetTester tester, Bancada b) async {
  await tester.tap(find.text('Jogar').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mesa por código'));
  await tester.pumpAndSettle();
  expect(find.byType(LobbyOnline), findsOneWidget);
  b.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
  expect(b.online.status, OnlineStatus.conectado);
}

/// A pessoa cria a mesa e o servidor lhe dá o assento [assento].
Future<void> criarMesa(
  WidgetTester tester,
  Bancada b, {
  int assento = 0,
}) async {
  await tester.tap(find.text('Criar mesa'));
  await tester.pumpAndSettle();
  b.canal.servidorEnvia({
    'tipo': 'entrou',
    'codigo': 'BURACO-0001',
    'assento': assento,
  });
  await tester.pumpAndSettle();
}

/// O servidor transmite uma visão.
Future<void> servidorManda(
  WidgetTester tester,
  Bancada b,
  Map<String, dynamic> visao,
) async {
  b.canal.servidorEnvia({'tipo': 'estado', 'visao': visao});
  await tester.pumpAndSettle();
}

/// O caminho completo até a mesa aberta, em jogo.
Future<void> irAMesa(
  WidgetTester tester,
  Bancada b, {
  int assento = 0,
  Map<String, dynamic>? visao,
}) async {
  await abrirAplicativo(tester, b);
  await irAoLobby(tester, b);
  await criarMesa(tester, b, assento: assento);
  await servidorManda(tester, b, visao ?? visaoDeJogo(voceAssento: assento));
  expect(find.byType(MesaOnlineScreen), findsOneWidget);
}

/// Encerra o ciclo de reconexão automática antes de o caso terminar.
///
/// Depois de uma queda, o `OnlineService` agenda a próxima tentativa com
/// backoff — comportamento correto, e que o teste exercita de propósito. Mas um
/// timer vivo quando a árvore é desmontada faz o `flutter_test` acusar
/// "A Timer is still pending", e a falha não é sobre o que o caso mede.
///
/// `desligar()` é o mesmo caminho que a pessoa dispara ao sair do online.
Future<void> encerrarTransporte(WidgetTester tester, Bancada b) async {
  b.online.desligar();
  await tester.pumpAndSettle();
}

/// Todo texto desenhado na tela agora.
List<String> textosNaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}')
    .toList();

void main() {
  // =========================================================================
  // O placeholder morreu
  // =========================================================================
  group('a fatia A2 deixou de ser promessa', () {
    testWidgets('o aviso de "próxima fatia" não existe mais', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      // Este é o oposto exato do caso de caracterização que este commit
      // removeu. O que a pessoa vê agora é a mesa.
      expect(
        find.textContaining('próxima fatia'),
        findsNothing,
      );
      expect(find.textContaining('Cartas na sua mão:'), findsNothing);
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
    });

    testWidgets('a mesa mostra o que o servidor mandou', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      expect(find.textContaining('ABERTO'), findsWidgets); // modalidade
      expect(find.text('É a sua vez'), findsOneWidget);
      expect(find.textContaining('Rodada 1'), findsOneWidget);
      expect(find.text('Sua mão · 3'), findsOneWidget);
      expect(find.textContaining('Monte · 60'), findsOneWidget);
      expect(find.textContaining('Mortos · 2'), findsOneWidget);
      // Os quatro lugares, com apelido e contagem alheia.
      expect(find.textContaining('Ana'), findsWidgets);
      expect(find.textContaining('Bot 2'), findsOneWidget);
      expect(find.text('11'), findsWidgets);
    });
  });

  // =========================================================================
  // 9 a 11 — a transição, e a pilha de navegação
  // =========================================================================
  group('lobby → mesa', () {
    testWidgets('visão de lobby permanece no lobby', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await criarMesa(tester, b);
      await servidorManda(tester, b, visaoDeLobby());

      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.text('Código da mesa'), findsOneWidget);
      expect(find.text('BURACO-0001'), findsOneWidget);
    });

    testWidgets('a visão de partida troca para a mesa UMA vez', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await criarMesa(tester, b);
      await servidorManda(tester, b, visaoDeLobby());
      expect(find.byType(MesaOnlineScreen), findsNothing);

      await servidorManda(tester, b, visaoDeJogo());
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
    });

    testWidgets('atualizações seguintes não empilham mesa nenhuma', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      for (var i = 2; i <= 8; i++) {
        await servidorManda(tester, b, visaoDeJogo(rodada: i));
        expect(
          find.byType(MesaOnlineScreen),
          findsOneWidget,
          reason: 'a mesa é o CORPO desta rota, não uma rota nova por mensagem',
        );
      }
      expect(find.textContaining('Rodada 8'), findsOneWidget);
    });

    testWidgets('a mesa é a mesma rota do lobby: um pop volta a Onde Jogar', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      // Se a mesa tivesse sido empurrada como rota nova, este `pop` deixaria a
      // pessoa num lobby que afirma "aguardando jogadores" sobre uma partida
      // em andamento.
      Navigator.of(tester.element(find.byType(MesaOnlineScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.byType(LobbyOnline), findsNothing);
      expect(find.byType(OndeJogarDeProducao), findsOneWidget);
    });
  });

  // =========================================================================
  // 12 a 14 — visão inválida e ordem
  // =========================================================================
  group('a visão que não descreve uma mesa', () {
    testWidgets('visão inválida não quebra e não inventa estado', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await criarMesa(tester, b);

      // Uma visão de partida sem placar e sem mão.
      final quebrada = visaoDeJogo()
        ..remove('placar')
        ..remove('suaMao');
      await servidorManda(tester, b, quebrada);

      expect(tester.takeException(), isNull);
      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.text('Não consegui entender a mesa'), findsOneWidget);
      // E nada de mesa com zeros: o placar não foi desenhado.
      expect(find.text('Sua dupla'), findsNothing);
      expect(find.text('Adversários'), findsNothing);
    });

    testWidgets('a visão de OUTRO assento é recusada', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await criarMesa(tester, b, assento: 0);

      // Íntegra, mas do assento 2.
      await servidorManda(tester, b, visaoDeJogo(voceAssento: 2));

      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.text('Não consegui entender a mesa'), findsOneWidget);
    });

    testWidgets('a visão de um socket anterior não alcança a tela', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      expect(find.textContaining('Rodada 1'), findsOneWidget);

      // O canal em uso é guardado, e o transporte é reaberto: cada abertura
      // recebe um crachá de geração, e o `OnlineService` confere esse crachá em
      // toda volta tardia — mensagem, timer ou credencial.
      final canalAntigo = b.canal;
      b.online.desligar();
      b.online.conectar();
      await tester.pumpAndSettle();
      expect(
        b.canais.length,
        greaterThan(1),
        reason: 'a reabertura tem de ter criado um canal novo',
      );

      // Agora o socket ANTIGO fala. Um servidor lento, uma mensagem em trânsito
      // na hora da troca — e a mesa não pode voltar no tempo por causa dela.
      canalAntigo.servidorEnvia({
        'tipo': 'estado',
        'visao': visaoDeJogo(rodada: 99),
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Rodada 99'), findsNothing);
      expect(find.textContaining('Rodada 1'), findsOneWidget);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a visão mais nova atualiza a mesa', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      expect(find.text('É a sua vez'), findsOneWidget);

      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 2, suaVez: false),
      );
      expect(find.textContaining('Rodada 2'), findsOneWidget);
      expect(find.text('É a sua vez'), findsNothing);
      expect(find.text('Vez de Bot 2'), findsOneWidget);
    });

    testWidgets('a mesma visão duas vezes não acumula nada', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      final v = visaoDeJogo();
      await irAMesa(tester, b, visao: v);
      await servidorManda(tester, b, v);
      await servidorManda(tester, b, v);

      // Sem `eventoId` no protocolo, a garantia possível é esta: reprocessar o
      // mesmo retrato produz o mesmo desenho.
      expect(find.text('Sua mão · 3'), findsOneWidget);
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
    });
  });

  // =========================================================================
  // 15 e 16 — só a própria mão
  // =========================================================================
  group('a mão alheia não aparece', () {
    testWidgets('só a própria mão é desenhada; das outras, a contagem', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      expect(find.text('Sua mão · 3'), findsOneWidget);
      // Dos outros, contagem — e nenhuma carta.
      expect(find.text('11'), findsWidgets);
      expect(find.text('9'), findsWidgets);
    });

    testWidgets('cartas de outros assentos na visão não vazam para a tela', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      // Um servidor com defeito manda mais do que devia.
      final v = visaoDeJogo();
      v['maos'] = [
        [carta('minha', 'copas', '7')],
        [carta('CARTA-SECRETA-DO-VIZINHO', 'paus', 'K')],
      ];
      v['monte'] = [carta('CARTA-DO-MONTE', 'ouros', 'Q')];

      await irAMesa(tester, b, visao: v);

      // O adaptador é lista de permissão: o que ele não lê não chega aqui.
      for (final texto in textosNaTela(tester)) {
        expect(texto.contains('CARTA-SECRETA-DO-VIZINHO'), isFalse);
        expect(texto.contains('CARTA-DO-MONTE'), isFalse);
      }
    });
  });

  // =========================================================================
  // 17 a 21 — os comandos
  // =========================================================================
  group('comandos', () {
    testWidgets('comprar do monte manda a jogada do protocolo', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();

      expect(b.canal.jogadas, [
        {'tipo': 'comprarMonte'},
      ]);
    });

    testWidgets('duplo toque não envia duas intenções', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      final monte = find.text('Monte · 60');
      await tester.tap(monte);
      await tester.pump();
      await tester.tap(monte);
      await tester.pump();
      await tester.tap(monte);
      await tester.pumpAndSettle();

      expect(
        b.canal.jogadas,
        hasLength(1),
        reason: 'o protocolo não tem eventoId: a segunda compra chegaria como '
            'uma compra a mais',
      );
    });

    testWidgets('a intenção pendente aparece na tela', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await tester.tap(find.text('Monte · 60'));
      await tester.pump();

      expect(find.text('Comprando do monte…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('descartar exige uma carta selecionada e manda o id dela', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));

      // Sem seleção, o botão não age.
      final descartar = find.widgetWithText(ElevatedButton, 'Descartar');
      expect(tester.widget<ElevatedButton>(descartar).onPressed, isNull);

      // A pessoa toca a carta do meio (c2) e descarta.
      await tester.tap(find.bySemanticsLabel('8 de copas'));
      await tester.pumpAndSettle();
      await tester.tap(descartar);
      await tester.pumpAndSettle();

      expect(b.canal.jogadas.single, {'tipo': 'descartar', 'id': 'c2'});
    });

    testWidgets('baixar manda a lista de ids selecionados', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));

      await tester.tap(find.bySemanticsLabel('7 de copas'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('8 de copas'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Baixar 2'));
      await tester.pumpAndSettle();

      expect(b.canal.jogadas.single, {
        'tipo': 'baixar',
        'ids': ['c1', 'c2'],
      });
    });

    testWidgets('fora da minha vez não há ação oferecida', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b, visao: visaoDeJogo(suaVez: false));

      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Descartar'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();
      expect(b.canal.jogadas, isEmpty);
    });

    testWidgets('recusa de regra preserva o estado autoritativo', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));

      await tester.tap(find.bySemanticsLabel('rei de espadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Descartar'));
      await tester.pumpAndSettle();

      b.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'essa carta não tem mola',
      });
      await tester.pumpAndSettle();

      // A carta continua na mão: nada foi aplicado localmente.
      expect(find.text('Sua mão · 3'), findsOneWidget);
      expect(find.text('essa carta não tem mola'), findsOneWidget);
      // E a mesa aceita a próxima tentativa.
      expect(b.canal.jogadas, hasLength(1));
    });
  });

  // =========================================================================
  // 22 e 23 — queda e retomada
  // =========================================================================
  group('queda e retomada', () {
    testWidgets('a queda bloqueia ações novas e avisa', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));
      b.canal.servidorDerruba();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('sem conexão com o servidor'),
        findsWidgets,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Descartar'),
            )
            .onPressed,
        isNull,
      );
      final antes = b.canal.jogadas.length;
      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();
      expect(b.canal.jogadas, hasLength(antes));

      await encerrarTransporte(tester, b);
    });

    testWidgets('a mesa continua desenhada durante a reconexão', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      b.canal.servidorDerruba();
      await tester.pumpAndSettle();

      // A mesa não some: o último retrato autoritativo continua sendo o mais
      // recente que existe. Sumir com ela pareceria "a partida acabou".
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
      expect(find.textContaining('Rodada 1'), findsOneWidget);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a retomada substitui a mesa pela visão nova', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      b.canal.servidorDerruba();
      await tester.pumpAndSettle();

      // O backoff reabre o socket; o servidor autentica e reentrega a mesa.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(b.canais.length, greaterThan(1));

      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await servidorManda(tester, b, visaoDeJogo(rodada: 4));

      expect(find.textContaining('Rodada 4'), findsOneWidget);
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
    });
  });

  // =========================================================================
  // 27 a 31 — sessão, saída e falha terminal
  // =========================================================================
  group('sessão e saída', () {
    testWidgets('logout EM PARTIDA encerra a capacidade de jogar', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      final canalDaSessao = b.canal;

      await b.autenticacao.sair();
      await tester.pumpAndSettle();

      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(canalDaSessao.fechado, isTrue);
      expect(b.online.visao, isNull);
      expect(b.online.querConectado, isFalse);
    });

    testWidgets('trocar de conta elimina a pilha e o estado visual anterior', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      expect(find.textContaining('Rodada 1'), findsOneWidget);

      // Outra pessoa entra sem passar pelo logout.
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.byType(LobbyOnline), findsNothing);
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(b.online.visao, isNull);
      expect(b.online.codigo, isNull);

      // A ponte restabelece a conexão sob a identidade NOVA — comportamento
      // correto, e que deixa o relógio de autenticação armado quando o caso
      // termina.
      await encerrarTransporte(tester, b);
    });

    testWidgets('sair da mesa não é sair da conta', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(b.canal.doTipo('sair'), hasLength(1));
      expect(b.autenticacao.saidas, 0);
      expect(find.byType(LoginDeProducao), findsNothing);
      // Volta para a entrada do lobby, ainda conectada e ainda na conta.
      expect(find.byType(LobbyOnline), findsOneWidget);
      expect(find.text('Criar mesa'), findsOneWidget);
      expect(b.online.status, OnlineStatus.conectado);
    });

    testWidgets('falha terminal oferece ação explícita, sem laço', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      b.canal.servidorEnvia({
        'tipo': 'erro',
        'codigo': 'ATUALIZACAO_OBRIGATORIA',
        'motivo': 'atualize o aplicativo para continuar jogando online',
      });
      await tester.pumpAndSettle();

      expect(b.online.falhaTerminal, isTrue);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(
        find.text('atualize o aplicativo para jogar online'),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // 32 e 33 — o desfecho é do servidor
  // =========================================================================
  group('desfecho', () {
    testWidgets('o encerramento autoritativo mostra o resultado uma vez', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(
          encerrada: true,
          rodadaEncerrada: true,
          duplaQueBateu: 'nos',
          suaVez: false,
          placar: {'nos': 3010, 'eles': 1200},
        ),
      );

      expect(find.text('🏆 Sua dupla venceu'), findsOneWidget);
      expect(find.text('Partida encerrada'), findsOneWidget);
      expect(find.textContaining('3010'), findsWidgets);
    });

    testWidgets('quem bateu é lido do servidor, não do placar', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      // Assento 1 (dupla `eles`), e quem bateu foi `eles` — ou seja, a dupla
      // de quem está lendo, apesar de `nos` estar na frente no placar.
      await irAMesa(
        tester,
        b,
        assento: 1,
        visao: visaoDeJogo(
          voceAssento: 1,
          encerrada: true,
          rodadaEncerrada: true,
          duplaQueBateu: 'eles',
          suaVez: false,
          placar: {'nos': 3010, 'eles': 1200},
        ),
      );

      expect(find.text('🏆 Sua dupla venceu'), findsOneWidget);
      expect(
        find.textContaining('Sua dupla 1200'),
        findsOneWidget,
        reason: 'o placar da tela é relativo a quem está sentado',
      );
    });

    testWidgets('partida encerrada sem quem bateu não anuncia vencedor', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(encerrada: true, rodadaEncerrada: true, suaVez: false),
      );

      expect(find.text('A partida terminou'), findsOneWidget);
      expect(find.text('🏆 Sua dupla venceu'), findsNothing);
      expect(find.text('A dupla adversária venceu'), findsNothing);
    });

    testWidgets('encerrada a partida, nenhuma ação é oferecida', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(encerrada: true, suaVez: true, jaComprou: true),
      );

      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Descartar'),
            )
            .onPressed,
        isNull,
      );
      final antes = b.canal.jogadas.length;
      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();
      expect(b.canal.jogadas, hasLength(antes));
    });
  });

  // =========================================================================
  // 34 — o que não pode aparecer
  // =========================================================================
  group('nada de segredo na tela', () {
    testWidgets('a credencial não aparece em texto nenhum da mesa', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);

      final token = b.credenciais.token!;
      for (final texto in textosNaTela(tester)) {
        expect(texto.contains(token), isFalse);
      }
      // E o token saiu UMA vez pelo fio, dentro do `auth`.
      expect(
        b.canal.enviadas.where((m) => m.contains(token)),
        hasLength(1),
      );
      expect(b.canal.mensagens.first['tipo'], 'auth');
    });

    testWidgets('nenhuma conquista é concedida por inferência do cliente', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(
          encerrada: true,
          rodadaEncerrada: true,
          duplaQueBateu: 'nos',
          suaVez: false,
        ),
      );

      // A vitória é DESENHADA, e nada mais: o cliente não manda comando
      // nenhum de conquista, ranking ou pontuação ao ver a partida acabar.
      expect(find.text('🏆 Sua dupla venceu'), findsOneWidget);
      final tipos = b.canal.mensagens.map((m) => m['tipo']).toSet();
      expect(tipos.contains('conquista'), isFalse);
      expect(tipos.contains('ranking'), isFalse);
      expect(tipos.contains('perfil'), isFalse);
    });
  });
}
