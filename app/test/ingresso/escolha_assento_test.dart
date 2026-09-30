@Timeout(Duration(minutes: 20))
library;

// escolha_assento_test.dart — a TELA da escolha de assento (OS 38.3 §8, §11 e
// §13).
//
// TRÊS TRABALHOS:
//
// 1. O QUE A TELA MOSTRA é a ocupação que o SERVIDOR mandou. Ela não marca
//    cadeira como ocupada por causa de um toque, não esconde cadeira e não
//    conclui vaga a partir de `vagas`.
// 2. O QUE A TELA NÃO FAZ: não navega, não tenta outra cadeira depois de uma
//    recusa e não manda um segundo pedido enquanto o primeiro está em voo.
// 3. ELA CABE E É USÁVEL: 320/360/412 dp, fonte de 100% a 200%, alvos de
//    toque, papel, estado e anúncio.
//
// A tela é exercitada NUA (sem transporte), com mesas construídas pelo mesmo
// dublê que copia o contrato do servidor. Um caso que precisasse de socket
// para afirmar "a cadeira ocupada não é botão" estaria medindo o transporte.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/descoberta/estado_descoberta.dart';
import 'package:buraco_master_vip/descoberta/modelo_descoberta.dart';
import 'package:buraco_master_vip/ingresso/estado_ingresso.dart';
import 'package:buraco_master_vip/ingresso/modelo_ingresso.dart';
import 'package:buraco_master_vip/screens/escolha_assento_screen.dart';

import '../descoberta/retrato_de_teste.dart';

/// Piso de toque da régua desta base.
const double kAlvoMinimo = 48;

void main() {
  // =========================================================================
  group('§8.1 — O JOGADOR VÊ OS LUGARES E ESCOLHE', () {
    // =======================================================================

    testWidgets('EA-01 as QUATRO posições aparecem, com quem está nelas', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 2, bots: 1, apelidos: ['Ana', 'Bia']),
      );

      final frases = rotulos(tester).where((r) => r.startsWith('Posição'));
      expect(frases, hasLength(4));
      expect(frases, contains('Posição 1, Ana'));
      expect(frases, contains('Posição 2, Bia'));
      expect(frases, contains('Posição 3, robô'));
      expect(frases, contains('Posição 4, livre, sentar aqui'));
      sem.dispose();
    });

    testWidgets('EA-02 tocar numa cadeira LIVRE pede AQUELA cadeira', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      final pedidos = <int>[];
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        onEscolherAssento: pedidos.add,
      );

      // PELO CAMINHO DO LEITOR DE TELA: `performAction` é o que o TalkBack
      // faz. Um controle que só responde a `tester.tap` passa no teste de
      // toque e continua inacessível.
      await tocarPorSemantica(tester, 'Posição 3, livre, sentar aqui');
      expect(pedidos, [2]);
      sem.dispose();
    });

    testWidgets('EA-03 cadeira OCUPADA não é botão', (tester) async {
      final sem = tester.ensureSemantics();
      final pedidos = <int>[];
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Bia']),
        // O CALLBACK É OBRIGATÓRIO AQUI, e a falta dele era um furo real:
        // sem ele NENHUMA cadeira é escolhível, e o caso passava sem
        // conseguir distinguir a ocupada não ser botão de nada ser botão.
        // A mutação I23 apagou a checagem de ocupação e escapou por isso.
        onEscolherAssento: pedidos.add,
      );
      // A cadeira LIVRE é botão — é o que dá sentido à afirmação seguinte.
      expect(
        no(tester, 'Posição 3, livre, sentar aqui').flagsCollection.isButton,
        isTrue,
      );
      final ocupada = no(tester, 'Posição 1, Ana');
      expect(
        ocupada.flagsCollection.isButton,
        isFalse,
        reason: 'um nó tocável que não faz nada é pior que nenhum',
      );
      expect(ocupada.flagsCollection.isEnabled == Tristate.isFalse, isTrue);
      expect(
        ocupada.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'e ela não responde ao leitor de tela',
      );
      expect(pedidos, isEmpty);
      sem.dispose();
    });

    testWidgets('EA-04 mesa NÃO INGRESSÁVEL não oferece cadeira nenhuma', (
      tester,
    ) async {
      // `ingressavel` vem do SERVIDOR. Mesa em andamento pode ter cadeira
      // vazia e mesmo assim não aceitar ninguém — concluir por `vagas > 0`
      // mandaria a pessoa buscar uma recusa que o retrato já sabia dar.
      final sem = tester.ensureSemantics();
      final pedidos = <int>[];
      await montar(
        tester,
        bruta: mesa(
          codigo: 'M-01',
          humanos: 2,
          iniciada: true,
          apelidos: ['Ana', 'Bia'],
        ),
        onEscolherAssento: pedidos.add,
      );
      final livres = nos(tester).where(
        (n) => n.label.startsWith('Posição') && n.label.contains('livre'),
      );
      expect(livres, isNotEmpty, reason: 'há cadeira vazia — o servidor disse');
      for (final n in livres) {
        expect(n.flagsCollection.isButton, isFalse, reason: n.label);
        expect(n.label, contains('indisponível nesta mesa'));
      }
      expect(pedidos, isEmpty);
      sem.dispose();
    });
  });

  // =========================================================================
  group('§8.1 — UMA INTENÇÃO ATIVA', () {
    // =======================================================================

    testWidgets('EA-05 com pedido em voo, NENHUMA cadeira é botão', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      final pedidos = <int>[];
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.solicitando,
        assentoSolicitado: 2,
        onEscolherAssento: pedidos.add,
      );
      for (final n in nos(tester).where((n) => n.label.startsWith('Posição'))) {
        expect(
          n.flagsCollection.isButton,
          isFalse,
          reason: 'toque duplo travado na tela: ${n.label}',
        );
      }
      expect(pedidos, isEmpty);
      sem.dispose();
    });

    testWidgets('EA-06 a cadeira PEDIDA aparece selecionada — e não ocupada', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.solicitando,
        assentoSolicitado: 2,
      );
      final pedida = no(tester, 'Posição 3, pedido enviado, aguardando o servidor');
      expect(pedida.flagsCollection.isSelected == Tristate.isTrue, isTrue);
      // A OCUPAÇÃO NÃO MUDOU. Pintá-la de ocupada seria o cliente afirmando o
      // que só o servidor sabe — e ela pode voltar recusada.
      expect(
        textos(tester).where((t) => t == 'Livre'),
        hasLength(3),
        reason: 'as três cadeiras livres continuam livres na tela',
      );
      sem.dispose();
    });

    testWidgets('EA-07 com pedido em voo, a ação automática some', (
      tester,
    ) async {
      var automaticos = 0;
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.solicitando,
        assentoSolicitado: 2,
        onEntrarEmQualquerLugar: () => automaticos++,
      );
      expect(find.text('Entrar em qualquer lugar'), findsNothing);
      expect(automaticos, 0);
    });

    testWidgets('EA-08 a ação automática NÃO promete uma cadeira', (
      tester,
    ) async {
      var automaticos = 0;
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        onEntrarEmQualquerLugar: () => automaticos++,
      );
      expect(find.text('Entrar em qualquer lugar'), findsOneWidget);
      expect(
        textos(tester),
        contains('O servidor escolhe o lugar disponível.'),
        reason:
            'prometer o lugar aqui seria reproduzir o algoritmo do servidor, '
            'que é o caminho mais curto para os dois discordarem',
      );
      await tester.tap(find.text('Entrar em qualquer lugar'));
      await tester.pumpAndSettle();
      expect(automaticos, 1);
    });
  });

  // =========================================================================
  group('§8.3 e §8.4 — RECUSA SEM FALLBACK', () {
    // =======================================================================

    testWidgets('EA-09 assento ocupado: a recusa aparece e a pessoa fica', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      final pedidos = <int>[];
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.recusado,
        recusa: const RecusaDeIngresso(
          motivo: MotivoDeRecusaDeIngresso.assentoOcupado,
          assentoPedido: 2,
        ),
        onEscolherAssento: pedidos.add,
      );

      expect(
        textos(tester).any((t) => t.contains('posição 3 acabou de ser ocupada')),
        isTrue,
      );
      // NENHUMA segunda tentativa saiu sozinha.
      expect(pedidos, isEmpty);
      // E a pessoa pode escolher de novo — pelo gesto dela.
      await tocarPorSemantica(tester, 'Posição 4, livre, sentar aqui');
      expect(pedidos, [3]);
      sem.dispose();
    });

    testWidgets('EA-10 a recusa é ANUNCIADA (região viva)', (tester) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.recusado,
        recusa: const RecusaDeIngresso(
          motivo: MotivoDeRecusaDeIngresso.assentoOcupado,
          assentoPedido: 2,
        ),
      );
      final vivos = nos(tester)
          .where((n) => n.flagsCollection.isLiveRegion)
          .toList();
      expect(
        vivos,
        hasLength(1),
        reason:
            'uma região viva, e uma só: duas fariam o leitor de tela repetir a '
            'mesa inteira a cada atualização automática da lista',
      );
      expect(vivos.single.label, contains('acabou de ser ocupada'));
      sem.dispose();
    });

    testWidgets('EA-11 assento inválido: recusa, sem alterar a ocupação', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.recusado,
        recusa: const RecusaDeIngresso(
          motivo: MotivoDeRecusaDeIngresso.assentoInvalido,
          assentoPedido: 9,
        ),
      );
      expect(
        textos(tester).any((t) => t.contains('Esse lugar não existe')),
        isTrue,
      );
      expect(textos(tester).where((t) => t == 'Livre'), hasLength(3));
      sem.dispose();
    });

    testWidgets('EA-12 o pedido em voo é ANUNCIADO', (tester) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.solicitando,
        assentoSolicitado: 1,
      );
      final vivos = nos(tester).where((n) => n.flagsCollection.isLiveRegion);
      expect(vivos, hasLength(1));
      expect(vivos.single.label, contains('Pedindo a posição 2'));
      sem.dispose();
    });

    testWidgets('EA-13 o ingresso CONFIRMADO é anunciado', (tester) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        fase: FaseDoIngresso.confirmado,
        confirmacao: const IngressoConfirmado(
          codigo: 'M-01',
          assento: 2,
          reconexao: false,
        ),
      );
      final vivos = nos(tester).where((n) => n.flagsCollection.isLiveRegion);
      expect(vivos, hasLength(1));
      expect(
        vivos.single.label,
        'Lugar confirmado na posição 3.',
        reason:
            'sem isto o sucesso seria o único desfecho mudo da tela — o pedido '
            'é anunciado, a recusa é anunciada, e o que a pessoa espera não',
      );
      sem.dispose();
    });

    testWidgets('EA-14 sem nada transitório, NÃO há região viva', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montar(tester, bruta: mesa(codigo: 'M-01', humanos: 1));
      expect(
        nos(tester).where((n) => n.flagsCollection.isLiveRegion),
        isEmpty,
        reason:
            'região viva permanente faria o leitor repetir a tela a cada '
            'atualização automática, para sempre',
      );
      sem.dispose();
    });
  });

  // =========================================================================
  group('§11 — ESTADOS HONESTOS', () {
    // =======================================================================

    testWidgets('EA-15 a mesa SUMIU da lista: a tela diz, e não desenha velho', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarSemMesa(tester, faseDaDescoberta: FaseDaDescoberta.disponivel);
      expect(find.text('Mesa indisponível'), findsOneWidget);
      expect(
        rotulos(tester).where((r) => r.startsWith('Posição')),
        isEmpty,
        reason: 'nenhuma cadeira de uma mesa que não existe mais',
      );
      expect(find.text('Voltar para as mesas'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('EA-16 ainda CARREGANDO não é "mesa sumiu"', (tester) async {
      await montarSemMesa(tester, faseDaDescoberta: FaseDaDescoberta.carregando);
      expect(find.text('Carregando a mesa…'), findsOneWidget);
      expect(find.text('Mesa indisponível'), findsNothing);
    });

    testWidgets('EA-17 a tela mostra os números do SERVIDOR, sem recalcular', (
      tester,
    ) async {
      await montar(
        tester,
        bruta: mesa(
          codigo: 'M-01',
          humanos: 2,
          bots: 1,
          metaPontos: 3000,
          modalidade: 'sbtl',
          apelidos: ['Ana', 'Bia'],
        ),
      );
      final t = textos(tester);
      expect(
        t.any((x) => x.contains('STBL') && x.contains('Meta 3000')),
        isTrue,
      );
      expect(t.any((x) => x.contains('2 de 4 jogadores')), isTrue);
      expect(t.any((x) => x.contains('1 vaga')), isTrue);
    });

    testWidgets('EA-18 a chave do servidor NÃO aparece', (tester) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, modalidade: 'sbtl'),
      );
      final tudo = [...textos(tester), ...rotulos(tester)].join(' | ');
      expect(tudo, contains('STBL'));
      expect(tudo, isNot(contains('sbtl')));
      expect(tudo, isNot(contains('SBTL')));
      sem.dispose();
    });

    testWidgets('EA-19 nada de identidade interna atravessa para a tela', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'CODIGO-OPACO-1', humanos: 2, apelidos: ['Ana', 'Bia']),
      );
      final tudo = [...textos(tester), ...rotulos(tester)].join(' | ');
      for (final proibido in const [
        'uid',
        'UID',
        'jogadorId',
        'admissaoId',
        'tentativaEntradaId',
        'token',
        'credencial',
      ]) {
        expect(tudo, isNot(contains(proibido)), reason: proibido);
      }
      expect(
        tudo,
        isNot(contains('CODIGO-OPACO-1')),
        reason: 'o código é OPACO: ele serve para pedir, não para exibir',
      );
      sem.dispose();
    });
  });

  // =========================================================================
  group('§13 — ACESSIBILIDADE', () {
    // =======================================================================

    testWidgets('A11Y-20 o Voltar e o Atualizar têm nome e piso de toque', (
      tester,
    ) async {
      await montar(tester, bruta: mesa(codigo: 'M-01', humanos: 1));
      final voltar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(voltar.tooltip, 'Voltar');
      final atualizar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh_rounded),
      );
      expect(atualizar.tooltip, 'Atualizar a mesa');
      for (final icone in const [Icons.chevron_left, Icons.refresh_rounded]) {
        final t = tester.getSize(find.widgetWithIcon(IconButton, icone));
        expect(t.height >= kAlvoMinimo, isTrue, reason: '$icone mede $t');
        expect(t.width >= kAlvoMinimo, isTrue, reason: '$icone mede $t');
      }
    });

    testWidgets('A11Y-21 a cadeira escolhível é BOTÃO, com ação de toque', (
      tester,
    ) async {
      // `excludeSemantics` sobre o `InkWell` LEVA O TOQUE JUNTO: o nó sai com
      // `isButton` e sem ação, passa em `tester.tap` e é inerte para o
      // TalkBack. É a lição da OS 38.2, e ela só aparece com `performAction`.
      final sem = tester.ensureSemantics();
      final pedidos = <int>[];
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1),
        onEscolherAssento: pedidos.add,
      );
      final alvo = no(tester, 'Posição 2, livre, sentar aqui');
      expect(alvo.flagsCollection.isButton, isTrue);
      expect(alvo.flagsCollection.isEnabled == Tristate.isTrue, isTrue);
      expect(
        alvo.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'sem ação de toque o controle é inerte para o leitor de tela',
      );
      expect(pedidos, isEmpty);
      sem.dispose();
    });

    testWidgets('A11Y-22 cada cadeira tem 48 dp de altura', (tester) async {
      await montar(tester, bruta: mesa(codigo: 'M-01', humanos: 1));
      final caixas = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.constraints?.minHeight == kAlvoMinimo);
      expect(
        caixas.length >= 4,
        isTrue,
        reason: 'as quatro cadeiras precisam do piso; achei ${caixas.length}',
      );
    });

    testWidgets('A11Y-23 não há nó semântico DUPLICADO por cadeira', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montar(
        tester,
        bruta: mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana']),
        onEscolherAssento: (_) {},
      );
      final porPosicao = <String, int>{};
      for (final n in nos(tester)) {
        final m = RegExp(r'^Posição (\d)').firstMatch(n.label);
        if (m != null) {
          porPosicao[m.group(1)!] = (porPosicao[m.group(1)!] ?? 0) + 1;
        }
      }
      expect(porPosicao.length, 4);
      for (final e in porPosicao.entries) {
        expect(e.value, 1, reason: 'posição ${e.key} tem ${e.value} nós');
      }
      sem.dispose();
    });

    for (final largura in const [320.0, 360.0, 412.0]) {
      for (final escala in const [1.0, 1.3, 1.5, 1.75, 2.0]) {
        testWidgets(
          'RS-24 ${largura.toInt()} dp a ${(escala * 100).toInt()}%: '
          'sem estouro e com tudo alcançável',
          (tester) async {
            final sem = tester.ensureSemantics();
            final estouros = <String>[];
            final anterior = FlutterError.onError;
            FlutterError.onError = (d) {
              if (d.exceptionAsString().contains('overflowed by')) {
                estouros.add(d.exceptionAsString());
                return;
              }
              anterior?.call(d);
            };
            addTearDown(() => FlutterError.onError = anterior);

            await montar(
              tester,
              bruta: mesa(
                codigo: 'M-01',
                humanos: 2,
                apelidos: ['Anabela Constância', 'Bernardo Nepomuceno'],
                metaPontos: 3000,
              ),
              onEscolherAssento: (_) {},
              onEntrarEmQualquerLugar: () {},
              largura: largura,
              escalaDeTexto: escala,
            );

            // O `reason` é avaliado SEMPRE, inclusive quando a expectativa
            // passa — `estouros.first` numa lista vazia derruba o caso com
            // "Bad state: No element" e faz um teste verde parecer defeito.
            expect(
              estouros,
              isEmpty,
              reason:
                  'estouro em ${largura}dp @ ${escala}x: '
                  '${estouros.isEmpty ? "" : estouros.first}',
            );

            // A ÚLTIMA CADEIRA É ALCANÇÁVEL. `ensureVisible` não serve: a
            // lista é preguiçosa e o que está fora da viewport não tem
            // Element. Quem constrói o que falta é a rolagem.
            await tester.scrollUntilVisible(
              find.text('Entrar em qualquer lugar'),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            expect(find.text('Entrar em qualquer lugar'), findsWidgets);
            expect(find.text('Posição 4'), findsWidgets);
            sem.dispose();
          },
        );
      }
    }
  });
}

// ---------------------------------------------------------------------------
// ARNÊS
// ---------------------------------------------------------------------------

List<SemanticsNode> nos(WidgetTester tester) =>
    find.semantics.byPredicate((_) => true).evaluate().toList();

List<String> rotulos(WidgetTester tester) =>
    nos(tester).map((n) => n.label).where((r) => r.isNotEmpty).toList();

SemanticsNode no(WidgetTester tester, String rotulo) =>
    nos(tester).firstWhere((n) => n.label == rotulo);

List<String> textos(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}')
    .toList();

/// Toca PELO CAMINHO DO LEITOR DE TELA.
Future<void> tocarPorSemantica(WidgetTester tester, String rotulo) async {
  final alvo = find.semantics.byPredicate((n) => n.label == rotulo);
  // `performAction` é síncrono: `await` nele não compila. Quem espera o efeito
  // é o `pumpAndSettle` da linha seguinte.
  tester.semantics.performAction(alvo, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

/// Constrói a `MesaPublica` PELA FRONTEIRA de produção — o mesmo adaptador que
/// roda no aplicativo. Montar o objeto à mão aqui deixaria a suíte medir uma
/// mesa que o adaptador talvez recusasse.
MesaPublica mesaTipada(Map<String, Object?> bruta) {
  final estado = EstadoDaDescoberta();
  final ok = estado.aplicar(
    retratoDeMesas(mesas: [bruta]),
    geracaoDeTransporte: 0,
  );
  expect(ok, isTrue, reason: 'o arnês precisa de um retrato válido');
  return estado.retrato!.mesas.single;
}

Future<void> montar(
  WidgetTester tester, {
  required Map<String, Object?> bruta,
  FaseDoIngresso fase = FaseDoIngresso.ocioso,
  int? assentoSolicitado,
  RecusaDeIngresso? recusa,
  IngressoConfirmado? confirmacao,
  void Function(int)? onEscolherAssento,
  VoidCallback? onEntrarEmQualquerLugar,
  double largura = 390,
  double escalaDeTexto = 1.0,
}) => _montar(
  tester,
  mesa: mesaTipada(bruta),
  fase: fase,
  assentoSolicitado: assentoSolicitado,
  recusa: recusa,
  confirmacao: confirmacao,
  onEscolherAssento: onEscolherAssento,
  onEntrarEmQualquerLugar: onEntrarEmQualquerLugar,
  largura: largura,
  escalaDeTexto: escalaDeTexto,
);

Future<void> montarSemMesa(
  WidgetTester tester, {
  required FaseDaDescoberta faseDaDescoberta,
}) => _montar(
  tester,
  mesa: null,
  fase: FaseDoIngresso.ocioso,
  faseDaDescoberta: faseDaDescoberta,
);

Future<void> _montar(
  WidgetTester tester, {
  required MesaPublica? mesa,
  required FaseDoIngresso fase,
  FaseDaDescoberta faseDaDescoberta = FaseDaDescoberta.disponivel,
  int? assentoSolicitado,
  RecusaDeIngresso? recusa,
  IngressoConfirmado? confirmacao,
  void Function(int)? onEscolherAssento,
  VoidCallback? onEntrarEmQualquerLugar,
  double largura = 390,
  double escalaDeTexto = 1.0,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = Size(largura * 3, 844 * 3);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(escalaDeTexto)),
      child: MaterialApp(
        home: EscolhaAssentoScreen(
          mesa: mesa,
          fase: fase,
          faseDaDescoberta: faseDaDescoberta,
          assentoSolicitado: assentoSolicitado,
          recusa: recusa,
          confirmacao: confirmacao,
          onVoltar: () {},
          onAtualizar: () {},
          onEscolherAssento: onEscolherAssento,
          onEntrarEmQualquerLugar: onEntrarEmQualquerLugar,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
