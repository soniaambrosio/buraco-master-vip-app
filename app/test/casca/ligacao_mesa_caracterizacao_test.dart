// ligacao_mesa_caracterizacao_test.dart — o caminho COMO ELE ESTÁ HOJE.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO EXISTE ANTES DA MUDANÇA
// ---------------------------------------------------------------------------
//
// A OS desta fatia manda ligar a Casca V2 à mesa online sem tocar em duas
// coisas que já funcionam: o TREINO local e a autoridade do transporte. Um
// teste escrito depois da mudança prova que a mudança funciona; ele não prova
// que o que já existia continua de pé, porque nunca viu o estado anterior.
//
// Então este arquivo é escrito ANTES, contra a base congelada, e fixa cinco
// fatos observáveis:
//
//   1. Treino abre a `MesaScreen` jogável de `lib/mesa.dart` — a que tem motor
//      de verdade —, e não a apresentação por VM de `lib/screens/`;
//   2. Treino roda sem transporte e sem abrir socket nenhum;
//   3. Mesa por código usa o ÚNICO `OnlineService` montado pela raiz;
//   4. entrar e sair do lobby não constrói um segundo transporte;
//   5. o logout derruba a pilha privada e a capacidade de jogar.
//
// Os cinco continuam valendo depois da ligação, e é por isso que eles ficam
// aqui em vez de dentro da suíte nova.
//
// ---------------------------------------------------------------------------
// O SEXTO CASO É DE VALIDADE LIMITADA, E ISSO ESTÁ ESCRITO NELE
// ---------------------------------------------------------------------------
//
// `o caminho online termina no aviso de fatia seguinte` descreve o DEFEITO que
// esta OS existe para remover: com a partida em andamento, o app desenha um
// resumo em texto e avisa que a mesa visual "é a próxima fatia". Ele é a
// caracterização do buraco, não um contrato — e o commit que liga a mesa o
// substitui pelo seu oposto, em `mesa_online_test.dart`
// ("o placeholder da fatia A2 não existe mais").
//
// Ele foi mantido no histórico e removido no mesmo commit da ligação: é o que
// torna a passagem de "não chega" para "chega" auditável por `git log`, em vez
// de afirmada em prosa no relatório.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/onde_jogar_de_producao.dart';
import 'package:buraco_master_vip/mesa.dart' show MesaScreen;
import 'package:buraco_master_vip/services/online_service.dart';

import 'bancada_online.dart';

/// Monta o aplicativo numa superfície de TELEFONE.
///
/// O padrão do `flutter_test` é 800x600 — paisagem de desktop —, e todas as
/// telas daqui são desenhadas para celular: sem isto elas estouram em overflow
/// e o caso falha por motivo que não é o dele.
Future<void> abrirAplicativo(WidgetTester tester, Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

Future<void> irAOndeJogar(WidgetTester tester) async {
  await tester.tap(find.text('Jogar').first);
  await tester.pumpAndSettle();
  expect(find.byType(OndeJogarDeProducao), findsOneWidget);
}

/// Desmonta a árvore e deixa o TREINO terminar o que já tinha começado.
///
/// `_rodarBots` de `lib/mesa.dart` é um laço `await Future.delayed(650ms)` que
/// só para quando a vez volta ao assento 0 — ele não confere `mounted` para
/// continuar, só para redesenhar. Se o assento sorteado para abrir a rodada for
/// de robô, o laço fica de pé quando o caso termina, e o `flutter_test` acusa
/// "A Timer is still pending" — uma falha que não é sobre o que o caso mede.
///
/// Desmontar primeiro cancela o relógio do turno (que o `dispose` fecha); o
/// tempo depois deixa os robôs chegarem ao fim do laço. Isto é característica
/// do treino tal como ele existe hoje, e esta OS não a altera.
Future<void> encerrarTreino(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

/// O servidor aceita a credencial.
///
/// Fora do que o caso mede, isto também FECHA o relógio de 15 segundos que o
/// `OnlineService` arma ao apresentar o `auth` — sem a resposta, o timer
/// sobrevive ao fim do caso e o `flutter_test` reclama dele.
Future<void> servidorAutentica(WidgetTester tester, Bancada b) async {
  b.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
}

Future<void> irAoLobby(WidgetTester tester) async {
  await irAOndeJogar(tester);
  await tester.tap(find.text('Mesa por código'));
  await tester.pumpAndSettle();
  expect(find.byType(LobbyOnline), findsOneWidget);
}

void main() {
  // =========================================================================
  // O caminho de treino — que já é honesto e não pode regredir
  // =========================================================================
  group('treino', () {
    testWidgets('Home autenticada abre Onde Jogar', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      expect(find.byType(HomeDeProducao), findsOneWidget);

      await irAOndeJogar(tester);
      b.aquietar();
    });

    testWidgets('Treino abre a MesaScreen jogável de lib/mesa.dart', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAOndeJogar(tester);

      await tester.tap(find.text('Treino'));
      await tester.pumpAndSettle();

      // `MesaScreen` aqui é a importada de `package:buraco_master_vip/mesa.dart`.
      // A homônima de `lib/screens/mesa_screen.dart` é outra classe, e não
      // satisfaz este `findsOneWidget`.
      expect(find.byType(MesaScreen), findsOneWidget);

      await encerrarTreino(tester);
      b.aquietar();
    });

    // ESTE CASO FOI REESCRITO PELA OS 38.2, E A MEDIDA FICOU MELHOR.
    //
    // Ele afirmava `aberturas == 0` — "o Treino não abre socket". Isso deixou
    // de ser verdade, e não por causa do Treino: a Home autenticada já conecta
    // antes, porque a presença online tem de existir para quem está no
    // aplicativo (§3.1). O socket que existe durante o Treino não é do Treino.
    //
    // O invariante que este caso sempre quis guardar continua valendo por
    // inteiro, e agora é medido DIRETAMENTE: a partida local não manda comando
    // nenhum ao servidor. Contar sockets era um proxy; ler o fio é a coisa.
    testWidgets('Treino não fala com o servidor', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      final pedidosAntes = b.credenciais.pedidos;
      final noFioAntes = b.canal.enviadas.length;

      await irAOndeJogar(tester);
      await tester.tap(find.text('Treino'));
      await tester.pumpAndSettle();

      expect(find.byType(MesaScreen), findsOneWidget);

      // NADA de mesa atravessou o fio por causa do Treino. O que puder ter
      // saído nesse intervalo é só o ritmo da descoberta, que roda desde a
      // Home e não sabe que existe uma partida local acontecendo.
      for (final m in b.canal.mensagens.skip(noFioAntes)) {
        expect(
          m['tipo'],
          anyOf('descobrirMesas', 'presenca_ping'),
          reason: 'o Treino mandou "${m['tipo']}" para o servidor',
        );
      }
      // E nenhuma credencial nova foi pedida: a partida local não autentica.
      expect(b.credenciais.pedidos, pedidosAntes);

      await encerrarTreino(tester);
      b.aquietar();
    });
  });

  // =========================================================================
  // O transporte — um só, e da raiz
  // =========================================================================
  group('transporte', () {
    testWidgets('Mesa por código usa o OnlineService da raiz', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester);

      // A prova de que é o MESMO objeto: quem conectou foi o da bancada.
      expect(b.online.querConectado, isTrue);
      expect(b.aberturas, 1);
      expect(b.canais, hasLength(1));

      await servidorAutentica(tester, b);
      expect(b.online.status, OnlineStatus.conectado);
      b.aquietar();
    });

    testWidgets('abrir e fechar o lobby não constrói um segundo transporte', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester);
      await servidorAutentica(tester, b);
      expect(b.aberturas, 1);

      // Sair da tela do lobby NÃO desliga o transporte: ele é da raiz.
      Navigator.of(tester.element(find.byType(LobbyOnline))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(LobbyOnline), findsNothing);

      await tester.tap(find.text('Mesa por código'));
      await tester.pumpAndSettle();
      expect(find.byType(LobbyOnline), findsOneWidget);

      expect(
        b.aberturas,
        1,
        reason: 'reabrir a tela não reabre o socket que já está de pé',
      );
      expect(b.canais, hasLength(1));
      b.aquietar();
    });

    testWidgets('logout no lobby derruba a pilha e a capacidade de jogar', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await irAoLobby(tester);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.online.status, OnlineStatus.conectado);

      final canalDaSessao = b.canal;
      await b.autenticacao.sair();
      await tester.pumpAndSettle();

      expect(canalDaSessao.fechado, isTrue);
      expect(b.online.status, OnlineStatus.desconectado);
      expect(b.online.querConectado, isFalse);
      expect(b.online.visao, isNull);
      expect(find.byType(LobbyOnline), findsNothing);
      expect(find.byType(LoginDeProducao), findsOneWidget);
      b.aquietar();
    });
  });

  // =========================================================================
  // O DEFEITO — removido pelo commit que ligou a mesa
  // =========================================================================
  //
  // Aqui morava `o caminho online termina no aviso de fatia seguinte`: com a
  // visão de partida chegando do servidor, o app desenhava um resumo em texto
  // e prometia que a mesa visual completa "é a próxima fatia (A2)".
  //
  // Ele foi apagado no MESMO commit que ligou a mesa, e substituído pelo seu
  // oposto em `mesa_online_test.dart` — `o aviso de "próxima fatia" não existe
  // mais`. Quem quiser conferir a passagem de "não chega" para "chega" lê o
  // `git log` deste arquivo, e não uma frase de relatório.
}
