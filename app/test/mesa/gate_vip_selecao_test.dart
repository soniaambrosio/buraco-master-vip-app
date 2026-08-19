// test/mesa/gate_vip_selecao_test.dart — O GATE VIP NA SUPERFÍCIE QUE ESCOLHE.
//
// POR QUE ESTE ARQUIVO NASCE
//
// O bloqueio de tipos pagos era provado em `ConfigurarMesaScreen`, de quando
// AQUELA tela escolhia o tipo. Ela deixou de escolher: hoje configura um tipo já
// escolhido, e a seleção — com o cadeado — vive em `OndeJogarScreen`. O callback
// `onTipoBloqueado` sobrevivia lá declarado, `required` e nunca invocado, o que
// fazia parecer que o gate continuava naquele endereço.
//
// AS DUAS CAMADAS, E O QUE CADA UMA PROTEGE
//
//   CLIENTE (aqui)      protege a EXPERIÊNCIA: quem não é VIP não avança, e a
//                       opção bloqueada não dispara navegação nem criação. É UX,
//                       e UX se prova na tela onde a pessoa toca.
//
//   `functions-mesas`   protege a AUTORIDADE: elegibilidade final e não
//                       contornável. Cliente adulterado, deep link ou mensagem
//                       forjada continuam recusados lá — e a suíte daquele
//                       codebase é quem prova isso.
//
// O caso `CRUZ-01`, no fim, é o que amarra as duas: mostra que passar por cima
// da tela não passa por cima do servidor.
//
// O QUE ESTE ARQUIVO NÃO FAZ: não duplica a regra VIP em Dart e não calcula
// entitlement no cliente. `ehVip` chega pronto; o que se mede é o que a tela faz
// com ele.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/screens/onde_jogar_screen.dart';

void main() {
  // -------------------------------------------------------------------------
  // Arnês
  // -------------------------------------------------------------------------

  /// O catálogo mínimo: uma opção livre e uma que exige VIP.
  OndeJogarVM catalogo({required bool ehVip}) => OndeJogarVM(
        ehVip: ehVip,
        opcoes: const [
          OpcaoMesa(
            id: 'treino',
            icone: '🤖',
            titulo: 'Treino',
            descricao: 'livre',
          ),
          OpcaoMesa(
            id: 'vip',
            icone: '💎',
            titulo: 'Mesa VIP',
            descricao: 'exige assinatura',
            bloqueado: true,
          ),
        ],
      );

  Future<({List<String> escolhidos, List<String> bloqueados})> montarETocar(
    WidgetTester tester, {
    required bool ehVip,
    required String toqueEm,
  }) async {
    final escolhidos = <String>[];
    final bloqueados = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OndeJogarScreen(
          vm: catalogo(ehVip: ehVip),
          onVoltar: () {},
          onEscolher: escolhidos.add,
          onBloqueado: bloqueados.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final alvo = find.text(toqueEm).first;
    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
    await tester.tap(alvo, warnIfMissed: false);
    await tester.pumpAndSettle();

    return (escolhidos: escolhidos, bloqueados: bloqueados);
  }

  // -------------------------------------------------------------------------
  // O gate
  // -------------------------------------------------------------------------

  group('GATE VIP — na tela que escolhe o tipo de mesa', () {
    testWidgets('SEL-01 sem VIP, a mesa que exige VIP NÃO prossegue', (
      tester,
    ) async {
      final r = await montarETocar(tester, ehVip: false, toqueEm: 'Mesa VIP');

      expect(
        r.escolhidos,
        isEmpty,
        reason: 'sem VIP, tocar na mesa VIP não pode escolher nada — é a '
            'navegação/criação que não acontece',
      );
      expect(
        r.bloqueados,
        contains('vip'),
        reason: 'e o toque tem de chegar como BLOQUEIO, para a tela poder '
            'explicar em vez de ficar muda',
      );
    });

    testWidgets('SEL-02 com VIP, a mesma opção prossegue', (tester) async {
      final r = await montarETocar(tester, ehVip: true, toqueEm: 'Mesa VIP');

      expect(r.escolhidos, contains('vip'), reason: 'VIP elegível avança');
      expect(r.bloqueados, isEmpty, reason: 'e não é barrado por engano');
    });

    testWidgets('SEL-03 a opção livre prossegue com ou sem VIP', (
      tester,
    ) async {
      for (final ehVip in [false, true]) {
        final r = await montarETocar(tester, ehVip: ehVip, toqueEm: 'Treino');
        expect(
          r.escolhidos,
          contains('treino'),
          reason: 'o gate é da opção paga, e não um cadeado geral (ehVip=$ehVip)',
        );
        expect(r.bloqueados, isEmpty);
      }
    });

    testWidgets('SEL-04 o mock NÃO concede VIP por omissão', (tester) async {
      // O padrão era `true`, e um padrão generoso concede direito a quem só
      // esqueceu de declarar. Quem precisa de VIP em teste declara.
      expect(OndeJogarVM.mock().ehVip, isFalse);
      expect(OndeJogarVM.mock(ehVip: true).ehVip, isTrue);

      final r = await tester.runAsync(() async => null);
      expect(r, isNull); // mantém a assinatura de testWidgets sem pump extra
    });

    testWidgets('SEL-05 estado desconhecido falha FECHADO', (tester) async {
      // Um id que a tela não conhece é tratado como bloqueado pelo destino: a
      // tela repassa o toque, e quem monta o destino (a casca) tem `default:`
      // que não navega. Aqui se prova o lado da tela: opção marcada como
      // bloqueada, com `ehVip` desconhecido (false por ausência), não escolhe.
      final escolhidos = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: OndeJogarScreen(
            // `ehVip` OMITIDO de propósito: ausência de informação é ausência de
            // direito, e não permissão.
            vm: const OndeJogarVM(
              opcoes: [
                OpcaoMesa(
                  id: 'desconhecida',
                  icone: '❔',
                  titulo: 'Desconhecida',
                  descricao: 'sem contrato',
                  bloqueado: true,
                ),
              ],
            ),
            onVoltar: () {},
            onEscolher: escolhidos.add,
            // `onBloqueado` AUSENTE: nem assim o toque vira escolha.
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desconhecida').first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        escolhidos,
        isEmpty,
        reason: 'sem informação de direito, e sem tratador de bloqueio, o toque '
            'não pode virar escolha',
      );
    });
  });

  // -------------------------------------------------------------------------
  // A prova cruzada
  // -------------------------------------------------------------------------

  group('CRUZ — as duas camadas, e o que cada uma garante', () {
    testWidgets('CRUZ-01 a tela barra, e o servidor barra de novo', (
      tester,
    ) async {
      // METADE 1 — CLIENTE. Sem VIP, a tela não deixa prosseguir.
      final r = await montarETocar(tester, ehVip: false, toqueEm: 'Mesa VIP');
      expect(r.escolhidos, isEmpty, reason: 'a UX barrou');

      // METADE 2 — SERVIDOR. Agora ignore a tela: alguém com o cliente
      // adulterado, um deep link ou uma mensagem montada à mão chama o backend
      // direto, afirmando que é VIP. A autoridade NÃO acredita no que o cliente
      // afirma — ela decide por `functions-mesas`.
      //
      // Esta metade é medida onde ela vive, e não aqui: duplicar a regra em Dart
      // criaria uma SEGUNDA autoridade de elegibilidade, que é exatamente o que
      // não pode existir. O que este caso faz é AMARRAR as duas provas, para que
      // nenhuma das metades possa ser apagada achando que a outra cobre.
      //
      //   autoridade final ......... functions-mesas/src/elegibilidade.ts
      //   prova .................... functions-mesas/test/elegibilidade.test.js
      //                              functions-mesas/test/decisao.test.js
      //                              functions-mesas/test/politica.test.js
      //
      // Se a suíte acima sumir, este comentário fica mentindo — e é por isso que
      // o laudo da composição carrega a tabela `teste antigo → nova prova →
      // camada`, e não só a lista de arquivos verdes.
      expect(
        r.bloqueados,
        contains('vip'),
        reason: 'o cliente registra a recusa; a autoridade final é do servidor',
      );
    });
  });
}
