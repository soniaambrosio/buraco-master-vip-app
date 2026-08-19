// a11y_estados_anunciados_test.dart — o que a mesa, o lobby e o login DIZEM.
//
// ===========================================================================
// O QUE ESTA SUÍTE JULGA
// ===========================================================================
//
// Seis mudanças de estado que aconteciam em silêncio, e que a Auditoria
// Canônica de 19/08/2026 listou como P1: a vez que chega, a recusa do
// servidor, a conexão que cai e volta, a falha de login, o login em andamento e
// a troca do corpo do lobby pela mesa.
//
// A pergunta que organiza o arquivo é sempre a mesma: QUANTAS VEZES. Não basta
// falar — falar duas vezes por uma coisa que aconteceu uma vez é pior do que
// não falar, porque quem depende do leitor de tela perde a confiança no que
// ouve. Por isso quase todo caso aqui conta ocorrências em vez de afirmar
// presença.
//
// ===========================================================================
// COMO SE MEDE UM ANÚNCIO
// ===========================================================================
//
// Anúncio não deixa nó na árvore: sai como uma mensagem no canal
// `flutter/accessibility` e acaba. `escuta_de_anuncios.dart` grava esse canal,
// então o que estes casos leem é o que a pessoa cega efetivamente ouviria — na
// ordem, com o texto exato, e contável.
//
// Região viva é o contrário: ela É um nó, e por isso se prova pela árvore de
// semântica (`isLiveRegion` + o rótulo no MESMO nó). Onde a notícia é um texto
// que fica, ela é o mecanismo certo; onde a notícia é um desaparecimento, só o
// anúncio funciona. Os dois aparecem aqui, cada um onde cabe.
//
// ===========================================================================
// NENHUM ESTADO NOVO FOI INVENTADO
// ===========================================================================
//
// Tudo que se ouve aqui já existia como autoridade antes desta OS:
//
//   * a vez           — `visao['suaVez']`, do servidor;
//   * a recusa        — `OnlineService.erro`, já redigido, com o selo de
//                       ocorrência da `PortaDeComandosOnline`;
//   * a conexão       — `OnlineService.status` + `OnlineService.geracao`;
//   * o login         — `ResultadoDeLogin`, do adaptador de autenticação;
//   * a entrada       — a existência da própria `MesaOnlineScreen`.
//
// O último caso do arquivo prova o outro lado disso: nada do que se passou a
// dizer mudou o que se manda pelo fio.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/mesa_online/mesa_online_screen.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/sessao/comandos_de_autenticacao.dart';

import 'bancada_online.dart';
import 'escuta_de_anuncios.dart';

// ===========================================================================
// O caminho — o mesmo de `mesa_online_test.dart`
// ===========================================================================

/// Monta o aplicativo numa superfície de TELEFONE. O padrão do `flutter_test`
/// é 800x600 — paisagem de desktop —, e estas telas estouram nele.
Future<void> abrirAplicativo(WidgetTester tester, Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

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

Future<void> servidorManda(
  WidgetTester tester,
  Bancada b,
  Map<String, dynamic> visao,
) async {
  b.canal.servidorEnvia({'tipo': 'estado', 'visao': visao});
  await tester.pumpAndSettle();
}

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

/// Encerra o ciclo de reconexão antes de o caso terminar — um timer vivo na
/// desmontagem falha o caso por motivo que não é o dele.
Future<void> encerrarTransporte(WidgetTester tester, Bancada b) async {
  b.online.desligar();
  await tester.pumpAndSettle();
}

/// Leva o aplicativo até a tela pública de entrada.
Future<void> irAoLogin(WidgetTester tester, Bancada b) async {
  await abrirAplicativo(tester, b);
  b.fluxo.add(null);
  await tester.pumpAndSettle();
  expect(find.byType(LoginDeProducao), findsOneWidget);
}

/// O foco primário está dentro de um widget do tipo [T]?
bool focoDentroDe<T extends Widget>() {
  final contexto = FocusManager.instance.primaryFocus?.context;
  if (contexto == null) return false;
  if (contexto.widget is T) return true;
  return contexto.findAncestorWidgetOfExactType<T>() != null;
}

void main() {
  // =========================================================================
  // 1, 2 e 3 — a vez
  // =========================================================================
  group('a vez', () {
    testWidgets('entrar na vez anuncia UMA vez', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(suaVez: false));
      escuta.limpar();

      await servidorManda(tester, b, visaoDeJogo(suaVez: true));

      expect(find.text('É a sua vez'), findsOneWidget);
      expect(escuta.quantasVezesDisse('É a sua vez'), 1);

      await encerrarTransporte(tester, b);
    });

    testWidgets('reconstruir sem trocar a vez não repete o anúncio', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(suaVez: false));
      escuta.limpar();
      await servidorManda(tester, b, visaoDeJogo(suaVez: true));
      expect(escuta.quantasVezesDisse('É a sua vez'), 1);

      // Cinco retratos NOVOS do servidor com a MESMA vez. Cada um é um aviso do
      // transporte, um `setState` do lobby e uma reconstrução inteira da mesa —
      // e nenhum deles é notícia.
      var reconstrucoes = 0;
      b.online.addListener(() => reconstrucoes++);
      for (var i = 0; i < 5; i++) {
        await servidorManda(tester, b, visaoDeJogo(suaVez: true, monteQtd: 60 - i));
      }
      expect(
        reconstrucoes,
        5,
        reason: 'o cenário precisa MESMO reconstruir para provar alguma coisa',
      );
      expect(
        escuta.quantasVezesDisse('É a sua vez'),
        1,
        reason: 'o anúncio é por transição, não por reconstrução',
      );

      await encerrarTransporte(tester, b);
    });

    testWidgets('sair da vez e voltar a ela anuncia de novo', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(suaVez: false));
      escuta.limpar();

      await servidorManda(tester, b, visaoDeJogo(suaVez: true));
      await servidorManda(tester, b, visaoDeJogo(suaVez: false));
      await servidorManda(tester, b, visaoDeJogo(suaVez: true));

      expect(escuta.quantasVezesDisse('É a sua vez'), 2);
      // E sair da própria vez não vira notícia: a pessoa acabou de jogar.
      expect(escuta.mensagens.where((m) => m.contains('Vez de')), isEmpty);

      await encerrarTransporte(tester, b);
    });
  });

  // =========================================================================
  // 4 e 5 — a recusa
  // =========================================================================
  group('a recusa de comando', () {
    testWidgets('a recusa do servidor é anunciada com o texto que se lê', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));
      escuta.limpar();

      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'você já comprou nesta jogada',
      });
      await tester.pumpAndSettle();

      expect(find.text('você já comprou nesta jogada'), findsOneWidget);
      expect(escuta.quantasVezesDisse('você já comprou nesta jogada'), 1);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a recusa anunciada não carrega nada técnico', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));
      escuta.limpar();

      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();
      // Um servidor mal-comportado: motivo com credencial dentro, e um código
      // interno junto. O texto que sai já vem redigido pelo transporte, e o
      // anúncio não acrescenta NADA a ele.
      b.canal.servidorEnvia({
        'tipo': 'erro',
        'codigo': 'REGRA_MOTOR_7',
        'motivo':
            'jogada recusada — token=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abcdefgh '
            'uid=Zk39dLmQ',
      });
      await tester.pumpAndSettle();

      expect(escuta.mensagens, hasLength(1));
      final dito = escuta.mensagens.single;
      expect(dito, contains('jogada recusada'));
      for (final vazamento in const [
        'eyJ',
        'Zk39dLmQ',
        'REGRA_MOTOR_7',
        'MotivoDaRecusa',
      ]) {
        expect(
          dito,
          isNot(contains(vazamento)),
          reason: 'o anúncio vazou $vazamento',
        );
      }
      // E é EXATAMENTE o que está escrito na tela: ouvir e ler dão a mesma
      // informação, nem mais nem menos.
      expect(find.text(dito), findsOneWidget);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a mesma recusa em eventos diferentes é anunciada de novo', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));
      escuta.limpar();

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Monte · 60'));
        await tester.pumpAndSettle();
        b.canal.servidorEnvia({
          'tipo': 'erro',
          'motivo': 'você já comprou nesta jogada',
        });
        await tester.pumpAndSettle();
        // O servidor retransmite a mesa: é o que ele faz depois de recusar.
        await servidorManda(tester, b, visaoDeJogo(jaComprou: true));
      }

      // DUAS tentativas, DOIS anúncios — apesar de o texto ser idêntico. Quem
      // comparasse a mensagem em vez do selo de ocorrência ouviria uma só.
      expect(escuta.quantasVezesDisse('você já comprou nesta jogada'), 2);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a recusa do LOBBY é região viva, com o texto no mesmo nó', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();
      final escuta = escutarAnuncios(tester);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      escuta.limpar();

      // O código digitado não existe. É uma recusa de comando como as da mesa,
      // só que numa tela em que a mensagem FICA — e por isso o mecanismo aqui é
      // a região viva, e não o anúncio.
      b.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'não encontrei essa mesa',
      });
      await tester.pumpAndSettle();

      final recusa = find.text('não encontrei essa mesa');
      expect(recusa, findsOneWidget);
      // A MARCA E O RÓTULO NO MESMO NÓ. Separados, a região viva ficaria vazia
      // e não haveria mudança de conteúdo para o leitor de tela anunciar.
      expect(
        tester.getSemantics(recusa),
        isSemantics(isLiveRegion: true, label: 'não encontrei essa mesa'),
      );
      // E ninguém falou duas vezes: o nó fala, o anúncio se cala.
      expect(escuta.quantasVezesDisse('não encontrei essa mesa'), 0);

      await encerrarTransporte(tester, b);
      semantica.dispose();
    });
  });

  // =========================================================================
  // 6, 7, 8 e 9 — a conexão
  // =========================================================================
  group('a conexão', () {
    testWidgets('a queda é anunciada UMA vez, e não a cada tentativa', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b);
      escuta.limpar();

      b.canal.servidorDerruba();
      await tester.pumpAndSettle();
      expect(escuta.quantasVezesDisse('conexão perdida'), 1);

      // O ciclo automático insiste. Cada tentativa reabre o canal, e o teste
      // deixa TODAS falharem — nenhuma delas é notícia nova.
      final aberturasAntes = b.aberturas;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        b.canal.servidorDerruba();
        await tester.pumpAndSettle();
      }
      expect(
        b.aberturas,
        greaterThan(aberturasAntes),
        reason: 'o cenário precisa MESMO tentar de novo para provar alguma coisa',
      );
      expect(
        escuta.quantasVezesDisse('conexão perdida'),
        1,
        reason: 'o temporizador de reconexão não fala; a transição fala',
      );

      await encerrarTransporte(tester, b);
    });

    testWidgets('a volta é anunciada UMA vez, e só depois de uma queda', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b);
      // A PRIMEIRA conexão da sessão já aconteceu aqui, e não foi anunciada
      // como volta: ninguém tinha ido a lugar nenhum.
      expect(escuta.quantasVezesDisse('conexão restaurada'), 0);
      escuta.limpar();

      b.canal.servidorDerruba();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.online.status, OnlineStatus.conectado);

      expect(escuta.quantasVezesDisse('conexão restaurada'), 1);

      // E a mesa que volta não repete a volta.
      await servidorManda(tester, b, visaoDeJogo());
      await servidorManda(tester, b, visaoDeJogo(monteQtd: 59));
      expect(escuta.quantasVezesDisse('conexão restaurada'), 1);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a desistência do ciclo automático é anunciada', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      escuta.limpar();

      // Deixa o backoff esgotar. O transporte para de insistir e diz por quê —
      // é o único estado em que esperar não resolve e a pessoa precisa agir.
      b.canal.servidorDerruba();
      await tester.pumpAndSettle();
      for (var i = 0; i < 12 && !b.online.falhaTerminal; i++) {
        await tester.pump(const Duration(seconds: 40));
        await tester.pumpAndSettle();
        if (b.canais.length > i) b.canais.last.servidorDerruba();
        await tester.pumpAndSettle();
      }
      expect(b.online.status, OnlineStatus.semConexao);
      expect(escuta.quantasVezesDisse('sem conexão'), 1);

      await encerrarTransporte(tester, b);
    });

    testWidgets('trocar de conta não vira "conexão perdida"', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      expect(b.online.status, OnlineStatus.conectado);
      final geracaoAntes = b.online.geracao;
      escuta.limpar();

      // A sessão vira. O transporte da conta anterior é derrubado e um novo
      // sobe — o que, medido só pelo status, é indistinguível de uma queda de
      // rede seguida de reconexão.
      b.autenticacao.uidQueVaiEntrar = 'uid-B';
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(
        b.online.geracao,
        greaterThan(geracaoAntes),
        reason: 'o cenário precisa MESMO virar a geração para provar algo',
      );
      expect(
        escuta.quantasVezesDisse('conexão perdida'),
        0,
        reason:
            'quem trocou de conta não perdeu conexão nenhuma — o estado '
            'anterior era de uma sessão que já não existe',
      );
      expect(escuta.quantasVezesDisse('conexão restaurada'), 0);

      await encerrarTransporte(tester, b);
    });
  });

  // =========================================================================
  // 10, 11 e 12 — o login
  // =========================================================================
  group('o login', () {
    testWidgets('o botão em voo continua tendo nome', (tester) async {
      final b = Bancada();
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();

      await irAoLogin(tester, b);
      b.autenticacao.segurarProximoLogin();

      await tester.tap(find.text('Entrar com Google'));
      await tester.pump();

      // O rótulo visual saiu — quem vê tem o giro do indicador no lugar dele.
      expect(find.text('Entrar com Google'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // O nome ACESSÍVEL não saiu, e ganhou o estado junto.
      final rotulo = tester.getSemantics(find.byType(FilledButton)).label;
      expect(rotulo, contains('Entrar com Google'));
      expect(rotulo, contains('entrando'));

      b.autenticacao.soltarLogin();
      await tester.pumpAndSettle();
      semantica.dispose();
    });

    testWidgets('a falha é região viva, com o texto no mesmo nó', (
      tester,
    ) async {
      final b = Bancada();
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();

      await irAoLogin(tester, b);
      b.autenticacao.proximoResultado = const ResultadoDeLogin.falhou(
        'não foi possível entrar agora',
      );

      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();

      final erro = find.text('não foi possível entrar agora');
      expect(erro, findsOneWidget);
      // A MARCA E O RÓTULO NO MESMO NÓ: a mensagem é lida no instante em que
      // entra, e uma região viva sem rótulo não teria conteúdo para anunciar.
      expect(
        tester.getSemantics(erro),
        isSemantics(
          isLiveRegion: true,
          label: 'não foi possível entrar agora',
        ),
        reason: 'a falha precisa se apresentar sozinha, sem ser procurada',
      );

      // O botão volta acionável, e com o nome de sempre.
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(find.text('Entrar com Google'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('o sucesso posterior apaga o estado de erro', (tester) async {
      final b = Bancada();
      addTearDown(b.fechar);

      await irAoLogin(tester, b);
      b.autenticacao.proximoResultado = const ResultadoDeLogin.falhou(
        'não foi possível entrar agora',
      );
      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();
      expect(find.text('não foi possível entrar agora'), findsOneWidget);

      b.autenticacao.proximoResultado = const ResultadoDeLogin.entrou();
      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();

      // A falha não fica pendurada numa tela que deu certo — e a região viva
      // some junto com ela, em vez de continuar anunciável.
      expect(find.text('não foi possível entrar agora'), findsNothing);
      expect(find.byType(HomeDeProducao), findsOneWidget);
    });
  });

  // =========================================================================
  // 13, 14 e 15 — a entrada na mesa
  // =========================================================================
  group('a entrada na mesa', () {
    testWidgets('a troca de corpo é anunciada UMA vez', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await criarMesa(tester, b);
      escuta.limpar();

      await servidorManda(tester, b, visaoDeJogo());
      expect(find.byType(MesaOnlineScreen), findsOneWidget);
      expect(escuta.quantasVezesDisse('entrou na mesa'), 1);

      // E a mesa que continua sendo a mesa não anuncia entrada de novo.
      await servidorManda(tester, b, visaoDeJogo(monteQtd: 59));
      await servidorManda(tester, b, visaoDeJogo(monteQtd: 58));
      expect(escuta.quantasVezesDisse('entrou na mesa'), 1);

      await encerrarTransporte(tester, b);
    });

    testWidgets('o foco sai do lobby removido e pousa na mesa', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      // A pessoa estava digitando no campo do apelido, que existe SÓ no lobby.
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      final focoNoLobby = FocusManager.instance.primaryFocus;
      expect(focoNoLobby, isNotNull);

      await criarMesa(tester, b);
      await servidorManda(tester, b, visaoDeJogo());
      expect(find.byType(MesaOnlineScreen), findsOneWidget);

      expect(
        FocusManager.instance.primaryFocus,
        isNot(same(focoNoLobby)),
        reason: 'o foco ficou num campo que não existe mais',
      );
      expect(
        focoDentroDe<MesaOnlineScreen>(),
        isTrue,
        reason: 'a superfície nova precisa de um ponto de entrada',
      );

      await encerrarTransporte(tester, b);
    });

    testWidgets('sair da tela impede qualquer anúncio atrasado', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(suaVez: false));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(MesaOnlineScreen), findsNothing);
      expect(find.byType(LobbyOnline), findsNothing);
      escuta.limpar();

      // O transporte continua vivo — ele é da raiz, e não morre com a tela. O
      // servidor manda mais mesa, e depois derruba a conexão.
      b.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': visaoDeJogo(suaVez: true),
      });
      await tester.pumpAndSettle();
      b.canal.servidorDerruba();
      await tester.pumpAndSettle();

      expect(
        escuta.mensagens,
        isEmpty,
        reason:
            'uma tela que já não está na árvore não fala — nem da vez, nem da '
            'conexão',
      );

      await encerrarTransporte(tester, b);
    });
  });

  // =========================================================================
  // 16 — nada do que se passou a DIZER mudou o que se FAZ
  // =========================================================================
  group('o protocolo e a partida não mudaram', () {
    testWidgets('o fio leva exatamente as mesmas mensagens', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      escutarAnuncios(tester);

      await irAMesa(tester, b);
      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();

      // A lista INTEIRA, e não uma amostra: um anúncio que virasse mensagem
      // apareceria aqui como um elemento a mais.
      expect(
        b.canal.mensagens.map((m) => m['tipo']).toList(),
        ['auth', 'criarMesa', 'jogada'],
      );
      expect(b.canal.jogadas, [
        {'tipo': 'comprarMonte'},
      ]);

      // E a mesa continua sendo a do servidor: uma compra recusada não é uma
      // compra aplicada, e nenhum anúncio mexeu no que está desenhado.
      expect(find.textContaining('Rodada 1'), findsOneWidget);
      expect(find.text('Monte · 60'), findsOneWidget);

      await encerrarTransporte(tester, b);
    });

    testWidgets('a queda e a volta não acrescentam mensagem nenhuma', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      escutarAnuncios(tester);

      await irAMesa(tester, b);
      b.canal.servidorDerruba();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();

      // O canal NOVO recebe o aperto de mão e a REENTRADA na mesa — as duas
      // mensagens que o transporte já mandava antes desta OS, e nada além
      // delas. Reconectar não reenvia jogada, não repete `criarMesa` e não
      // inventa mensagem de acessibilidade: anúncio não vai no fio.
      expect(b.canal.mensagens.map((m) => m['tipo']).toList(), [
        'auth',
        'entrarMesa',
      ]);

      await encerrarTransporte(tester, b);
    });

    testWidgets('o assento e a reconexão continuam sendo do transporte', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      escutarAnuncios(tester);

      await irAMesa(tester, b, assento: 2);
      // Quem diz de que assento a pessoa é continua sendo o servidor: a tela
      // desenha `(você)` no lugar que o `entrou` declarou, e nenhum anúncio
      // participou dessa decisão.
      expect(b.online.meuAssento, 2);
      expect(find.text('Bia (você)'), findsOneWidget);

      await encerrarTransporte(tester, b);
    });
  });
}
