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
import 'package:buraco_master_vip/sessao/comandos_de_autenticacao.dart';

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
///
/// Sem [versaoEstado]/[eventoId] o envelope sai LEGADO — sem carimbo —, que é o
/// que o servidor em produção emite hoje. Os casos de ordem passam o par
/// explicitamente, e ele viaja como IRMÃO de `visao`, nunca dentro dela.
Future<void> servidorManda(
  WidgetTester tester,
  Bancada b,
  Map<String, dynamic> visao, {
  int? versaoEstado,
  String? eventoId,
}) async {
  b.canal.servidorEnvia(
    envelopeEstado(visao, versaoEstado: versaoEstado, eventoId: eventoId),
  );
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

      // No modo legado (sem carimbo) a garantia possível é esta: reprocessar o
      // mesmo retrato produz o mesmo desenho. Com carimbo, o reenvio nem chega
      // a ser reaplicado — ver o grupo "ordem da visão versionada".
      expect(find.text('Sua mão · 3'), findsOneWidget);
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
    });
  });

  // =========================================================================
  // Ordem da visão versionada — o carimbo do servidor chegando à mesa
  // =========================================================================
  //
  // A matriz da POLÍTICA está em `ordem_da_visao_test.dart`. O que se prova
  // aqui é que ela está no CAMINHO: transporte de produção, socket falso, tela
  // montada, e o carimbo entrando pelo ponto único.
  group('ordem da visão versionada', () {
    testWidgets('a visão atrasada não desfaz o que a mesa já mostrou', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 10),
        versaoEstado: 10,
        eventoId: 'ev-10',
      );
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 12),
        versaoEstado: 12,
        eventoId: 'ev-12',
      );
      expect(find.textContaining('Rodada 12'), findsOneWidget);

      // A 11 chega DEPOIS da 12 — retomada atrasada. Aplicá-la faria a mesa
      // voltar no tempo na frente da pessoa.
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 11),
        versaoEstado: 11,
        eventoId: 'ev-11',
      );
      expect(find.textContaining('Rodada 11'), findsNothing);
      expect(find.textContaining('Rodada 12'), findsOneWidget);
    });

    testWidgets('o reenvio do mesmo carimbo não reconstrói a mesa', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 5),
        versaoEstado: 5,
        eventoId: 'ev-5',
      );

      var avisos = 0;
      void contar() => avisos++;
      b.online.addListener(contar);
      addTearDown(() => b.online.removeListener(contar));

      final antes = b.online.visao;
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 5),
        versaoEstado: 5,
        eventoId: 'ev-5',
      );

      expect(
        avisos,
        0,
        reason: 'mensagem descartada não avisa ouvinte nem redesenha',
      );
      expect(
        identical(b.online.visao, antes),
        isTrue,
        reason: 'o retrato na mão é o mesmo objeto — nada foi reaplicado',
      );
      expect(find.textContaining('Rodada 5'), findsOneWidget);
    });

    testWidgets('mesma versão com outro eventoId não substitui o estado', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 7),
        versaoEstado: 7,
        eventoId: 'ev-7',
      );

      // Duas emissões dizendo ser o mesmo estado. O contrato do servidor não
      // permite isso; escolher uma delas seria o cliente inventando autoridade.
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 77),
        versaoEstado: 7,
        eventoId: 'outro',
      );
      expect(find.textContaining('Rodada 77'), findsNothing);
      expect(find.textContaining('Rodada 7'), findsOneWidget);
    });

    testWidgets('envelope com carimbo quebrado é descartado inteiro', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 3),
        versaoEstado: 3,
        eventoId: 'ev-3',
      );

      // Uma recusa de regra deixa a explicação na tela. A mensagem malformada
      // que vem depois não pode limpá-la — seria mutação parcial: o estado fica
      // como estava e a explicação some.
      b.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'você já comprou nesta jogada',
      });
      await tester.pumpAndSettle();
      expect(b.online.erro, 'você já comprou nesta jogada');

      b.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': visaoDeJogo(rodada: 44),
        'versaoEstado': 'quarenta e quatro',
        'eventoId': 'ev-44',
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Rodada 44'), findsNothing);
      expect(find.textContaining('Rodada 3'), findsOneWidget);
      expect(
        b.online.erro,
        'você já comprou nesta jogada',
        reason: 'o descarte é inteiro — nem estado, nem erro limpo',
      );
    });

    testWidgets('visão sem carimbo depois de uma carimbada é recusada', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 6),
        versaoEstado: 6,
        eventoId: 'ev-6',
      );
      // Sem carimbo. Um servidor que carimba não deixa de carimbar no meio da
      // partida: isto é anomalia, não compatibilidade.
      await servidorManda(tester, b, visaoDeJogo(rodada: 66));

      expect(find.textContaining('Rodada 66'), findsNothing);
      expect(find.textContaining('Rodada 6'), findsOneWidget);
    });

    testWidgets('a retomada reenvia a versão vigente e a mesa volta', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 12),
        versaoEstado: 12,
        eventoId: 'ev-12',
      );

      // A conexão cai. Ao voltar, o `OnlineService` reentra na mesa e descarta a
      // projeção anterior — e o servidor NÃO cria versão nova para quem volta
      // (reconectar não muta a sala). Ele reenvia a 12.
      b.canal.servidorDerruba();
      await tester.pump(const Duration(seconds: 1));
      b.online.tentarNovamente();
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();

      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 12),
        versaoEstado: 12,
        eventoId: 'ev-12',
      );

      expect(
        find.byType(MesaOnlineScreen),
        findsOneWidget,
        reason: 'com o marcador sobrevivendo à queda, o reenvio viraria '
            'duplicata e a mesa ficaria em branco',
      );
      expect(find.textContaining('Rodada 12'), findsOneWidget);

      await encerrarTransporte(tester, b);
    });

    testWidgets('callback tardio da conexão anterior não contamina a ordem', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 4),
        versaoEstado: 4,
        eventoId: 'ev-4',
      );

      final canalAntigo = b.canal;
      b.online.desligar();
      b.online.conectar();
      await tester.pumpAndSettle();

      // O socket velho fala, e fala ALTO: versão gigante. Se ela entrasse no
      // marcador, tudo o que a conexão nova mandasse depois seria "atrasado" e
      // a mesa nunca mais se mexeria.
      canalAntigo.servidorEnvia({
        'tipo': 'estado',
        'visao': visaoDeJogo(rodada: 999),
        'versaoEstado': 999999,
        'eventoId': 'ev-do-socket-morto',
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Rodada 999'), findsNothing);

      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 5),
        versaoEstado: 5,
        eventoId: 'ev-5',
      );

      expect(
        find.textContaining('Rodada 5'),
        findsOneWidget,
        reason: 'a conexão nova continua mandando na mesa',
      );

      await encerrarTransporte(tester, b);
    });

    testWidgets('outra mesa pode começar com versão menor', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 30),
        versaoEstado: 50,
        eventoId: 'sala-A-50',
      );

      // Sair da mesa e entrar em outra. A sala nova tem contador próprio, e o
      // dela pode estar bem atrás — recusar por isso deixaria a pessoa numa
      // mesa que nunca desenha.
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.byType(LobbyOnline), findsOneWidget);

      await criarMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 1),
        versaoEstado: 3,
        eventoId: 'sala-B-3',
      );

      expect(find.byType(MesaOnlineScreen), findsOneWidget);
      expect(find.textContaining('Rodada 1'), findsOneWidget);
    });

    testWidgets('logout e login novo começam a ordem do zero', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 20),
        versaoEstado: 80,
        eventoId: 'de-A-80',
      );

      b.autenticacao.uidQueVaiEntrar = 'uid-B';
      await b.autenticacao.sair();
      await tester.pumpAndSettle();
      expect(b.online.visao, isNull);

      // A pessoa nova percorre o caminho inteiro de novo — a pilha de rotas foi
      // eliminada junto com a sessão anterior.
      await b.autenticacao.entrar(ProvedorDeLogin.google);
      await tester.pumpAndSettle();
      await irAoLobby(tester, b);
      await criarMesa(tester, b);
      await servidorManda(
        tester,
        b,
        visaoDeJogo(rodada: 1),
        versaoEstado: 2,
        eventoId: 'de-B-2',
      );

      expect(
        find.byType(MesaOnlineScreen),
        findsOneWidget,
        reason: 'a ordem da conta anterior não pode barrar a mesa da nova',
      );

      await encerrarTransporte(tester, b);
    });
  });

  // =========================================================================
  // Efeito terminal — separado da aplicação do retrato
  // =========================================================================
  group('efeito terminal', () {
    /// Assina o ponto de saída dos efeitos e devolve o que foi despachado.
    List<EncerramentoAutoritativo> escutarEncerramento(Bancada b) {
      final recebidos = <EncerramentoAutoritativo>[];
      b.online.aoEncerrar = recebidos.add;
      addTearDown(() => b.online.aoEncerrar = null);
      return recebidos;
    }

    Map<String, dynamic> visaoTerminal() => visaoDeJogo(
      encerrada: true,
      rodadaEncerrada: true,
      duplaQueBateu: 'nos',
      suaVez: false,
      placar: {'nos': 3010, 'eles': 1200},
    );

    testWidgets('o encerramento despacha uma vez e a mesa fica no estado', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      final avisos = escutarEncerramento(b);

      await servidorManda(
        tester,
        b,
        visaoTerminal(),
        versaoEstado: 13,
        eventoId: 'fim-13',
      );

      expect(avisos, hasLength(1));
      expect(avisos.single.eventoId, 'fim-13');
      expect(avisos.single.versaoEstado, 13);
      expect(find.text('Partida encerrada'), findsOneWidget);
    });

    testWidgets('o encerramento retransmitido não despacha de novo', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      final avisos = escutarEncerramento(b);

      for (var i = 0; i < 3; i++) {
        await servidorManda(
          tester,
          b,
          visaoTerminal(),
          versaoEstado: 13,
          eventoId: 'fim-13',
        );
      }

      expect(
        avisos,
        hasLength(1),
        reason: 'diálogo, navegação, som e registro acontecem uma vez só',
      );
    });

    testWidgets('cair e voltar redesenha a mesa sem repetir o desfecho', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      final avisos = escutarEncerramento(b);

      await servidorManda(
        tester,
        b,
        visaoTerminal(),
        versaoEstado: 13,
        eventoId: 'fim-13',
      );
      expect(avisos, hasLength(1));

      b.canal.servidorDerruba();
      await tester.pump(const Duration(seconds: 1));
      b.online.tentarNovamente();
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();

      await servidorManda(
        tester,
        b,
        visaoTerminal(),
        versaoEstado: 13,
        eventoId: 'fim-13',
      );

      expect(
        find.text('Partida encerrada'),
        findsOneWidget,
        reason: 'o retrato terminal volta a ser desenhado — isso é o snapshot',
      );
      expect(
        avisos,
        hasLength(1),
        reason: 'o efeito, não: quem só caiu e voltou já viu o resultado',
      );

      await encerrarTransporte(tester, b);
    });

    testWidgets('nenhum efeito terminal sem o servidor declarar o fim', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await irAMesa(tester, b);
      final avisos = escutarEncerramento(b);

      // Rodada encerrada NÃO é partida encerrada, e um placar alto não é o
      // cliente concluindo nada.
      await servidorManda(
        tester,
        b,
        visaoDeJogo(
          rodadaEncerrada: true,
          duplaQueBateu: 'nos',
          suaVez: false,
          placar: {'nos': 9999, 'eles': 0},
        ),
        versaoEstado: 14,
        eventoId: 'ev-14',
      );

      expect(avisos, isEmpty);
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
