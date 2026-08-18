// meta_canonica_lobby_test.dart — a meta da partida na criação da mesa.
//
// O aplicativo montado aqui é o de produção, do `RaizDoAplicativo` para baixo,
// e o caminho é o que a pessoa percorre: Home → Jogar → Mesa por código. Falso
// é só o canal WebSocket — então o que estes casos leem é o BYTE que o app
// escreveu no fio, e não uma intenção guardada num campo da tela.
//
// A pergunta que organiza o arquivo: o que sai no comando é exatamente o que a
// pessoa tocou? E o que a tela oferece é exatamente o que o servidor aceita?
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, paisagem de
// desktop, e o lobby é tela de celular.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/services/meta_de_pontos.dart';

import 'package:buraco_master_vip/services/online_service.dart';

import 'bancada_online.dart';

/// Sobe o aplicativo de produção numa superfície de telefone.
///
/// Os passos até o lobby estão repetidos aqui, e não importados da suíte da
/// mesa: um arquivo de teste que importa outro amarra os dois, e mexer no
/// caminho da mesa passaria a quebrar casos que não falam dela.
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

/// O que o app escreveu no fio ao pedir a mesa.
Map<String, dynamic> pedidoDeMesa(Bancada b) {
  final pedidos = b.canal.doTipo('criarMesa');
  expect(pedidos, hasLength(1), reason: 'o comando de criação sai uma vez só');
  return pedidos.single;
}

/// Os três botões da meta, na ordem em que estão na tela.
List<ChoiceChip> chipsDaMeta(WidgetTester tester) =>
    tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();

Future<void> tocarMeta(WidgetTester tester, String rotulo) async {
  final alvo = find.widgetWithText(ChoiceChip, rotulo);
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> tocarCriar(WidgetTester tester) async {
  await tester.tap(find.text('Criar mesa'));
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  group('a vitrine', () {
    testWidgets('MET-01: a tela oferece 1.500, 2.000 e 3.000 — e nada mais', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      expect(find.text('Meta da partida'), findsOneWidget);
      final chips = chipsDaMeta(tester);
      expect(chips, hasLength(3), reason: 'são três opções, nem mais nem menos');
      for (final rotulo in ['1.500 pontos', '2.000 pontos', '3.000 pontos']) {
        expect(find.widgetWithText(ChoiceChip, rotulo), findsOneWidget);
      }
    });

    testWidgets('MET-02: exatamente uma opção nasce marcada, e é 2.000', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      final marcados = chipsDaMeta(tester).where((c) => c.selected);
      expect(marcados, hasLength(1), reason: 'seleção única');

      // E é o PADRÃO DECLARADO — não "o primeiro botão". As duas asserções
      // medem coisas diferentes: a segunda cai se alguém amarrar o valor
      // inicial à ordem da vitrine.
      expect(find.widgetWithText(ChoiceChip, '2.000 pontos'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, '2.000 pontos'),
            )
            .selected,
        isTrue,
      );
      expect(MetaDePontos.padrao, MetaDePontos.doisMil);
      expect(MetaDePontos.padrao, isNot(MetaDePontos.values.first));
    });

    testWidgets('MET-03: nenhuma meta fora do catálogo pode nascer na tela', (
      tester,
    ) async {
      // A vitrine não é uma lista de números soltos: cada botão é um valor da
      // enumeração fechada, e o comando só aceita esse tipo. "Mandar 1.732"
      // não é um caminho que a interface tenha — é código que não compila.
      expect(MetaDePontos.values, hasLength(3));
      expect(
        MetaDePontos.values.map((m) => m.pontos).toList(),
        [1500, 2000, 3000],
      );
      expect(MetaDePontos.deValor(1999), isNull);
      expect(MetaDePontos.deValor('2000'), isNull);
      expect(MetaDePontos.deValor(null), isNull);
    });
  });

  // =========================================================================
  group('o que sai no fio', () {
    testWidgets('MET-04: tocar 1.500 manda 1500', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      await tocarMeta(tester, '1.500 pontos');
      await tocarCriar(tester);

      expect(pedidoDeMesa(b)['metaPontos'], 1500);
    });

    testWidgets('MET-05: tocar 2.000 manda 2000', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      // Passa por 3.000 antes de propósito: se o caso tocasse direto no valor
      // que já nasce marcado, ele não distinguiria "2.000 foi escolhido" de
      // "2.000 é o padrão", e MET-05 seria uma cópia de MET-07.
      await tocarMeta(tester, '3.000 pontos');
      await tocarMeta(tester, '2.000 pontos');
      await tocarCriar(tester);

      expect(pedidoDeMesa(b)['metaPontos'], 2000);
    });

    testWidgets('MET-06: tocar 3.000 manda 3000', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      await tocarMeta(tester, '3.000 pontos');
      await tocarCriar(tester);

      expect(pedidoDeMesa(b)['metaPontos'], 3000);
    });

    testWidgets('MET-07: sem tocar em nada, sai o padrão', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      await tocarCriar(tester);

      expect(pedidoDeMesa(b)['metaPontos'], 2000);
    });

    testWidgets('MET-08: a seleção é única — escolher uma apaga a anterior', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      await tocarMeta(tester, '1.500 pontos');
      expect(chipsDaMeta(tester).where((c) => c.selected), hasLength(1));

      await tocarMeta(tester, '3.000 pontos');
      final marcados = chipsDaMeta(tester).where((c) => c.selected).toList();
      expect(marcados, hasLength(1), reason: 'duas metas marcadas ao mesmo tempo');

      await tocarCriar(tester);
      expect(pedidoDeMesa(b)['metaPontos'], 3000, reason: 'venceu a última');
    });

    testWidgets('MET-09: tocar de novo na marcada não desmarca nada', (
      tester,
    ) async {
      // O toque DEFINE, não alterna. Se alternasse, existiria um estado "mesa
      // sem meta escolhida" na tela — e ele não existe no domínio.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      await tocarMeta(tester, '1.500 pontos');
      await tocarMeta(tester, '1.500 pontos');

      expect(chipsDaMeta(tester).where((c) => c.selected), hasLength(1));
      await tocarCriar(tester);
      expect(pedidoDeMesa(b)['metaPontos'], 1500);
    });

    testWidgets('MET-10: o comando não carrega valor econômico nenhum', (
      tester,
    ) async {
      // A cicatriz da OS anterior: a meta viajar por mensagem não é licença
      // para a aposta voltar de carona. O cliente não é autoridade econômica.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      await tocarMeta(tester, '3.000 pontos');
      await tocarCriar(tester);

      final pedido = pedidoDeMesa(b);
      expect(pedido.keys.toSet(), {
        'tipo',
        'apelido',
        'metaPontos',
        'modalidade',
      });
      for (final proibido in [
        'aposta',
        'saldo',
        'custo',
        'fichas',
        'moedas',
        'recompensa',
        'premio',
        'preco',
      ]) {
        expect(
          pedido.containsKey(proibido),
          isFalse,
          reason: 'o cliente voltou a mandar $proibido',
        );
      }
    });
  });

  // =========================================================================
  group('a mesa que já existe', () {
    testWidgets('MET-11: a sala mostra a meta que o servidor disse', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await tocarCriar(tester);

      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {...visaoDeLobby(), 'metaPontos': 1500},
      });
      await tester.pumpAndSettle();

      expect(find.text('Meta: 1.500 pontos'), findsOneWidget);
    });

    testWidgets('MET-12: meta fora do catálogo vira traço, e não o padrão', (
      tester,
    ) async {
      // Se as duas listas um dia divergirem, o sintoma tem de ser visível.
      // Desenhar 2.000 sobre uma mesa de 5.000 esconderia a divergência
      // justamente de quem poderia notá-la.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      await tocarCriar(tester);

      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {...visaoDeLobby(), 'metaPontos': 5000},
      });
      await tester.pumpAndSettle();

      expect(find.text('Meta: —'), findsOneWidget);
      expect(find.text('Meta: 2.000 pontos'), findsNothing);
    });

    testWidgets('MET-13: dentro da sala não há seletor de meta', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);
      expect(find.byType(ChoiceChip), findsNWidgets(3));

      await tocarCriar(tester);
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 0,
      });
      await tester.pumpAndSettle();
      b.canal.servidorEnvia({'tipo': 'estado', 'visao': visaoDeLobby()});
      await tester.pumpAndSettle();

      expect(find.byType(LobbyOnline), findsOneWidget);
      expect(
        find.byType(ChoiceChip),
        findsNothing,
        reason: 'a mesa já existe: a meta dela não se reabre',
      );
    });

    testWidgets('MET-14: entrar por código não manda meta nenhuma', (
      tester,
    ) async {
      // O convidado vê a meta e aceita a mesa. Ele não a escolhe, e o comando
      // de entrada não tem por onde carregá-la.
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      await abrirAplicativo(tester, b);
      await irAoLobby(tester, b);

      // Mexe no seletor ANTES de entrar por código, de propósito: se o campo
      // vazasse para o outro caminho, é aqui que apareceria.
      await tocarMeta(tester, '1.500 pontos');
      await tester.enterText(
        find.widgetWithText(TextField, 'Código da mesa (ex.: BURACO-0001)'),
        'BURACO-0001',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar por código'));
      await tester.pumpAndSettle();

      final entradas = b.canal.doTipo('entrarMesa');
      expect(entradas, hasLength(1));
      expect(entradas.single.containsKey('metaPontos'), isFalse);
      expect(b.canal.doTipo('criarMesa'), isEmpty, reason: 'não criou mesa');
    });
  });
}
