// a11y_estados_anunciados_caracterizacao_test.dart — o SILÊNCIO, como ele é hoje.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO EXISTE ANTES DA MUDANÇA
// ---------------------------------------------------------------------------
//
// A Auditoria Canônica de 19/08/2026 diz que seis mudanças de estado acontecem
// sem que o leitor de tela diga nada. "Sem que diga nada" é uma AUSÊNCIA, e
// ausência não se prova com grep: o que se vê num fonte é a chamada ESCRITA,
// não a chamada ACONTECIDA.
//
// Então cada caso aqui monta o aplicativo de produção, provoca a mudança real
// pelo caminho real (o servidor manda a visão, a conexão cai, o provedor
// recusa o login) e grava TUDO que sairia pelo canal de acessibilidade. Hoje
// essa lista volta vazia — e é isso que estes casos fixam.
//
// ---------------------------------------------------------------------------
// O QUE MUDA QUANDO A CORREÇÃO ENTRAR
// ---------------------------------------------------------------------------
//
// Estes casos são caracterização, não contrato: eles descrevem o defeito. O
// commit da correção inverte cada afirmação em
// `a11y_estados_anunciados_test.dart` e apaga este arquivo no MESMO commit. É o
// que torna a passagem de "mudo" para "anunciado" auditável por `git log`, em
// vez de afirmada em prosa no relatório.
//
// ---------------------------------------------------------------------------
// A CONTAGEM DE RECONSTRUÇÕES
// ---------------------------------------------------------------------------
//
// A OS manda registrar quantas vezes cada estado é reconstruído, porque o
// anúncio tem de sair por TRANSIÇÃO e não por reconstrução. Cada caso conta os
// avisos do transporte — que são exatamente os `setState` do lobby, e portanto
// as reconstruções da mesa — e deixa o número no próprio `reason`.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/mesa_online/mesa_online_screen.dart';
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

/// O nó de semântica que cobre [alvo] está marcado como região viva?
bool ehRegiaoViva(WidgetTester tester, Finder alvo) =>
    tester.getSemantics(alvo).getSemanticsData().hasFlag(
      SemanticsFlag.isLiveRegion,
    );

/// O foco primário está dentro de um widget do tipo [T]?
bool focoDentroDe<T extends Widget>() {
  final contexto = FocusManager.instance.primaryFocus?.context;
  if (contexto == null) return false;
  if (contexto.widget is T) return true;
  return contexto.findAncestorWidgetOfExactType<T>() != null;
}

void main() {
  // =========================================================================
  // 1 — a vez que chega sem avisar
  // =========================================================================
  group('turno', () {
    testWidgets('a vez passa a ser sua e nada é anunciado', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(suaVez: false));
      expect(find.text('É a sua vez'), findsNothing);

      var reconstrucoes = 0;
      b.online.addListener(() => reconstrucoes++);
      escuta.limpar();

      await servidorManda(tester, b, visaoDeJogo(suaVez: true));

      // A tela MOSTRA a troca...
      expect(find.text('É a sua vez'), findsOneWidget);
      // ...e o leitor de tela não ouve nada.
      expect(
        escuta.mensagens,
        isEmpty,
        reason:
            'a vez virou em $reconstrucoes reconstrução(ões) do transporte e '
            'nenhuma delas produziu anúncio — quem não vê a tela não fica '
            'sabendo que pode jogar',
      );

      await encerrarTransporte(tester, b);
    });
  });

  // =========================================================================
  // 2 — a recusa que só quem vê descobre
  // =========================================================================
  group('recusa de comando', () {
    testWidgets('a recusa aparece na tela e não é anunciada', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b, visao: visaoDeJogo(jaComprou: true));
      escuta.limpar();

      // Uma jogada sai, e o servidor recusa pela regra.
      await tester.tap(find.text('Monte · 60'));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'você já comprou nesta jogada',
      });
      await tester.pumpAndSettle();

      final recusa = find.text('você já comprou nesta jogada');
      expect(recusa, findsOneWidget);
      expect(
        ehRegiaoViva(tester, recusa),
        isFalse,
        reason: 'a recusa não é região viva: ela entra na árvore calada',
      );
      expect(
        escuta.mensagens,
        isEmpty,
        reason: 'a recusa do servidor não é anunciada',
      );

      await encerrarTransporte(tester, b);
      semantica.dispose();
    });
  });

  // =========================================================================
  // 3 — a conexão que cai e volta sem dizer nada
  // =========================================================================
  group('conexão', () {
    testWidgets('a queda desenha a faixa, sem região viva e sem anúncio', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();
      final escuta = escutarAnuncios(tester);

      await irAMesa(tester, b);
      var reconstrucoes = 0;
      b.online.addListener(() => reconstrucoes++);
      escuta.limpar();

      b.canal.servidorDerruba();
      await tester.pumpAndSettle();

      final faixa = find.textContaining('reconectando');
      expect(faixa, findsOneWidget);
      expect(
        ehRegiaoViva(tester, faixa),
        isFalse,
        reason: 'a faixa de reconexão não é região viva',
      );
      expect(
        escuta.mensagens,
        isEmpty,
        reason:
            'a conexão caiu em $reconstrucoes reconstrução(ões) e ninguém foi '
            'avisado por áudio',
      );

      // E a volta também é muda.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(find.textContaining('reconectando'), findsNothing);
      expect(
        escuta.mensagens,
        isEmpty,
        reason: 'a conexão voltou e a faixa apenas sumiu, em silêncio',
      );

      await encerrarTransporte(tester, b);
      semantica.dispose();
    });
  });

  // =========================================================================
  // 4 e 5 — o login
  // =========================================================================
  group('login', () {
    testWidgets('o indicador de entrada em voo não tem nome acessível', (
      tester,
    ) async {
      final b = Bancada();
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();

      await irAoLogin(tester, b);
      b.autenticacao.segurarProximoLogin();

      await tester.tap(find.text('Entrar com Google'));
      await tester.pump();

      // O rótulo sumiu junto com o texto do botão.
      expect(find.text('Entrar com Google'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(FilledButton)).label,
        isEmpty,
        reason:
            'o botão em voo é um nó sem nome: o leitor de tela anuncia um '
            'controle desabilitado e não diz do que se trata',
      );

      b.autenticacao.soltarLogin();
      await tester.pumpAndSettle();
      semantica.dispose();
    });

    testWidgets('a falha entra depois do botão, sem região viva e sem anúncio', (
      tester,
    ) async {
      final b = Bancada();
      addTearDown(b.fechar);
      final semantica = tester.ensureSemantics();
      final escuta = escutarAnuncios(tester);

      await irAoLogin(tester, b);
      b.autenticacao.proximoResultado = const ResultadoDeLogin.falhou(
        'não foi possível entrar agora',
      );
      escuta.limpar();

      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();

      final erro = find.text('não foi possível entrar agora');
      expect(erro, findsOneWidget);

      // ABAIXO do botão: quem varre a tela de cima para baixo passa pelo
      // controle antes de encontrar a explicação — e só a encontra procurando.
      expect(
        tester.getTopLeft(erro).dy,
        greaterThan(tester.getTopLeft(find.byType(FilledButton)).dy),
      );
      expect(
        ehRegiaoViva(tester, erro),
        isFalse,
        reason: 'a mensagem de falha não é região viva',
      );
      expect(escuta.mensagens, isEmpty, reason: 'a falha não é anunciada');
      semantica.dispose();
    });
  });

  // =========================================================================
  // 6 — a troca de corpo
  // =========================================================================
  group('lobby para mesa', () {
    testWidgets('a troca de corpo não é anunciada e não reposiciona o foco', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      final escuta = escutarAnuncios(tester);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await criarMesa(tester, b);
      escuta.limpar();

      await servidorManda(tester, b, visaoDeJogo());
      expect(find.byType(MesaOnlineScreen), findsOneWidget);

      expect(
        escuta.mensagens,
        isEmpty,
        reason: 'o corpo da rota virou a mesa e ninguém foi avisado',
      );
      expect(
        focoDentroDe<MesaOnlineScreen>(),
        isFalse,
        reason:
            'nenhum ponto de entrada foi estabelecido na superfície nova — o '
            'foco fica onde o framework o deixou cair',
      );

      await encerrarTransporte(tester, b);
    });
  });
}
