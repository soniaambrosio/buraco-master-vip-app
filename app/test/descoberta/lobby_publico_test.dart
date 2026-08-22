// lobby_publico_test.dart — o Lobby Público (OS 38.2 §14.4 e §14.5).
//
// TRÊS TRABALHOS:
//
// 1. O QUE A TELA MOSTRA é o que o servidor mandou — na ORDEM que ele mandou,
//    com os NÚMEROS que ele mandou. A tela não ordena, não soma e não corrige.
// 2. O QUE A TELA NÃO FAZ: não envia ingresso. Esta OS não tem porta para isso,
//    e um card que parecesse clicável prometeria o que não há.
// 3. ELA CABE E É USÁVEL: 320/360/412 dp, fonte de 100% a 200%, alvos de
//    toque, semântica completa e ordem de foco.
//
// A tela é exercitada NUA (sem transporte), com retratos construídos pelo
// mesmo dublê que copia o contrato do servidor. Um caso que precisasse de
// socket para afirmar "a ordem não muda" estaria medindo o transporte.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/descoberta/estado_descoberta.dart';
import 'package:buraco_master_vip/descoberta/modelo_descoberta.dart';
import 'package:buraco_master_vip/screens/lobby_publico_screen.dart';

import 'retrato_de_teste.dart';

/// Piso de toque da régua desta base.
const double kAlvoMinimo = 48;


/// Toca um filtro PELO CAMINHO DO LEITOR DE TELA.
///
/// Dois motivos, e os dois importam:
///
///   * PRECISÃO. `find.textContaining("STBL")` casa com o chip do filtro E com
///     a etiqueta do card, e `tester.tap` num finder ambíguo acerta o que
///     estiver primeiro na árvore — o teste passaria medindo outra coisa.
///   * FORÇA. `performAction` é o que o TalkBack faz. Um controle que só
///     responde a `tester.tap` passa no teste de toque e continua
///     inacessível.
Future<void> tocarFiltro(WidgetTester tester, String rotulo) async {
  final alvo = find.semantics.byPredicate((n) => n.label.startsWith(rotulo));
  // `performAction` é síncrono: ele não devolve Future, e `await` nele não
  // compila. Quem espera o efeito é o `pumpAndSettle` da linha seguinte.
  tester.semantics.performAction(alvo, SemanticsAction.tap);
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  group('§11 — O QUE A TELA MOSTRA', () {
    // =======================================================================

    testWidgets('LB-01 a ORDEM do servidor é preservada, tal e qual', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      // O servidor já manda ordenado. A tela recebe uma ordem que NÃO é
      // alfabética, nem por vagas, nem por modalidade — de propósito: se ela
      // reordenasse por qualquer critério, o resultado seria diferente deste.
      final b = await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'Z-TRES', humanos: 3, apelidos: ['Zoe', 'Ana', 'Beto']),
          mesa(codigo: 'A-DOIS', humanos: 2, apelidos: ['Ana', 'Beto']),
          mesa(codigo: 'M-UM', humanos: 1, apelidos: ['Caio']),
        ],
      );

      final ordem = nomesDosCards(tester);
      expect(ordem, ['Mesa de Zoe', 'Mesa de Ana', 'Mesa de Caio']);
      // E o retrato realmente traz essa ordem — o dublê não a embaralhou.
      expect(
        b.retrato!.mesas.map((m) => m.codigo),
        ['Z-TRES', 'A-DOIS', 'M-UM'],
      );
      sem.dispose();
    });

    testWidgets('LB-02 Meta e modalidade são as recebidas', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', metaPontos: 1500, modalidade: 'fechado'),
          mesa(codigo: 'M-02', metaPontos: 3000, modalidade: 'aberto'),
        ],
      );
      expect(find.text('Meta 1500'), findsOneWidget);
      expect(find.text('Meta 3000'), findsOneWidget);
      expect(find.text('Fechado'), findsWidgets);
      expect(find.text('Aberto'), findsWidgets);
      sem.dispose();
    });

    testWidgets('LB-03 ocupação, vagas e QUATRO assentos, sempre', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Beto']),
        ],
      );

      expect(find.text('2/4'), findsOneWidget);
      // Dois ocupados com nome, dois livres — quatro posições desenhadas.
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Livre'), findsNWidgets(2));

      final frase = fraseDoCard(tester, 'Mesa de Ana');
      expect(frase, contains('2 de 4 jogadores'));
      expect(frase, contains('2 vagas'));
      expect(frase, contains('Posição 1, Ana'));
      expect(frase, contains('Posição 2, Beto'));
      expect(frase, contains('Posição 3, livre'));
      expect(frase, contains('Posição 4, livre'));
      sem.dispose();
    });

    testWidgets('LB-04 bot é desenhado como robô, e não conta como jogador', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', humanos: 1, bots: 3, iniciada: true, apelidos: ['Ana']),
        ],
      );
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('Robô'), findsNWidgets(3));
      final frase = fraseDoCard(tester, 'Mesa de Ana');
      expect(frase, contains('1 de 4 jogador'));
      expect(frase, contains('sem vagas'));
      expect(frase, contains('Posição 2, robô'));
      sem.dispose();
    });

    testWidgets('LB-05 EM ANDAMENTO aparece marcada e não é ingressável', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', humanos: 2, bots: 2, iniciada: true, apelidos: ['Ana', 'Beto']),
          mesa(codigo: 'M-02', humanos: 1, apelidos: ['Caio']),
        ],
      );
      expect(find.text('Partida em andamento'), findsOneWidget);
      expect(find.text('Aguardando jogadores'), findsOneWidget);
      expect(fraseDoCard(tester, 'Mesa de Ana'), contains('Partida em andamento'));
      sem.dispose();
    });

    testWidgets('LB-06 "Pública" NÃO é repetida em card nenhum', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01'), mesa(codigo: 'M-02')],
      );
      // O título da tela diz. Os cards, não.
      expect(find.text('Lobby Público'), findsOneWidget);
      final textos = textosVisiveis(tester);
      final repeticoes = textos.where((t) => t.contains('Pública')).length;
      expect(repeticoes, 0, reason: 'a tela inteira já é de mesa pública');
      sem.dispose();
    });

    testWidgets('LB-07 o card NÃO expõe uid nem chave proibida', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Beto']),
        ],
      );
      final tudo = [...textosVisiveis(tester), ...rotulosSemanticos(tester)]
          .join(' | ');
      for (final proibido in const [
        'uid',
        'jogadorId',
        'admissaoId',
        'token',
        'M-01', // nem o código opaco é desenhado: ele serve à 38.3, não à tela
      ]) {
        expect(
          tudo.contains(proibido),
          isFalse,
          reason: 'apareceu "$proibido" na superfície',
        );
      }
      sem.dispose();
    });
  });

  // =========================================================================
  group('§11.2 — FILTROS', () {
    // =======================================================================

    testWidgets('LB-08 os cinco filtros existem, com o rótulo certo', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(tester, mesas: [mesa(codigo: 'M-01')]);
      for (final f in FiltroDoLobby.values) {
        expect(
          find.textContaining(f.rotulo),
          findsWidgets,
          reason: 'filtro ${f.name} ausente',
        );
      }
      sem.dispose();
    });

    testWidgets('LB-09 as CONTAGENS vêm do servidor, não da lista', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      // Um retrato em que `porModalidade` NÃO bate com a lista desenhada. É
      // artificial de propósito: é o único jeito de distinguir "leu do
      // servidor" de "contou os cards".
      final mesas = [mesa(codigo: 'M-01', modalidade: 'aberto', humanos: 1)];
      final retrato = retratoDeMesas(mesas: mesas);
      final porMod =
          (retrato['presenca']! as Map<String, Object?>)['porModalidade']!
              as Map<String, Object?>;
      (porMod['aberto']! as Map<String, Object?>)['mesas'] = 9;

      await montarLobbyCru(tester, retrato);

      // O chip mostra 9 — o número do servidor —, e não 1, que é o que a
      // lista desenhada tem.
      expect(find.textContaining('Aberto (9)'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('LB-10 filtrar OCULTA cards e NÃO mexe nos números', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', modalidade: 'aberto', humanos: 2, apelidos: ['Ana', 'Beto']),
          mesa(codigo: 'M-02', modalidade: 'fechado', humanos: 1, apelidos: ['Caio']),
        ],
      );
      expect(nomesDosCards(tester), hasLength(2));
      final resumoAntes = find
          .textContaining('em 2 mesas')
          .evaluate()
          .isNotEmpty;
      expect(resumoAntes, isTrue);

      await tocarFiltro(tester, 'Fechado');

      expect(nomesDosCards(tester), ['Mesa de Caio']);
      // O resumo oficial continua dizendo 2 mesas: filtrar não recalcula nada.
      expect(find.textContaining('em 2 mesas'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('LB-11 "Com vagas" usa `ingressavel`, não aritmética de assento', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          // Em andamento COM assento vazio: tem vaga na conta, e não aceita
          // ninguém. Não pode aparecer em "Com vagas".
          mesa(codigo: 'M-01', humanos: 1, iniciada: true, apelidos: ['Ana']),
          mesa(codigo: 'M-02', humanos: 1, apelidos: ['Beto']),
        ],
      );

      await tocarFiltro(tester, 'Com vagas');

      expect(nomesDosCards(tester), ['Mesa de Beto']);
      sem.dispose();
    });

    testWidgets('LB-12 filtro sem resultado explica, e diz onde está o resto', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01', modalidade: 'aberto', apelidos: ['Ana'])],
      );
      await tocarFiltro(tester, 'Fechado');

      expect(find.text('Nenhuma mesa nesse filtro'), findsOneWidget);
      expect(find.textContaining('1 mesa em outros filtros'), findsOneWidget);
      sem.dispose();
    });
  });

  // =========================================================================
  group('§12 — ESTADOS HONESTOS', () {
    // =======================================================================

    testWidgets('LB-13 lista VAZIA REAL diz que está vazia', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(tester, mesas: const []);
      expect(find.text('Nenhuma mesa aberta agora'), findsOneWidget);
      expect(find.textContaining('Procurando'), findsNothing);
      sem.dispose();
    });

    testWidgets('LB-14 CARREGANDO não é lista vazia', (tester) async {
      final sem = tester.ensureSemantics();
      await montarNuLobby(tester, fase: FaseDaDescoberta.carregando);
      expect(find.text('Procurando mesas…'), findsOneWidget);
      expect(find.text('Nenhuma mesa aberta agora'), findsNothing);
      sem.dispose();
    });

    testWidgets('LB-15 RECONECTANDO, INDISPONÍVEL, INVÁLIDO e ENCERRADA', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarNuLobby(tester, fase: FaseDaDescoberta.reconectando);
      expect(find.text('Reconectando…'), findsOneWidget);

      await montarNuLobby(tester, fase: FaseDaDescoberta.servidorIndisponivel);
      expect(find.text('Servidor indisponível'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);

      await montarNuLobby(tester, fase: FaseDaDescoberta.retratoInvalido);
      expect(find.text('Resposta fora do contrato'), findsOneWidget);

      await montarNuLobby(tester, fase: FaseDaDescoberta.sessaoEncerrada);
      expect(find.text('Sessão encerrada'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('LB-16 uma falha de atualização NÃO esvazia a lista', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01', apelidos: ['Ana'])],
        ultimaRecusada: true,
      );
      // O card continua...
      expect(find.text('Mesa de Ana'), findsOneWidget);
      // ...e a tela diz por que ele pode estar velho.
      expect(
        find.textContaining('não pôde ser aplicada'),
        findsOneWidget,
      );
      sem.dispose();
    });

    testWidgets('LB-17 SEM MESAS INGRESSÁVEIS é diferente de lista vazia', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', humanos: 1, bots: 3, iniciada: true, apelidos: ['Ana']),
        ],
      );
      // A mesa aparece — ela existe e tem gente.
      expect(find.text('Mesa de Ana'), findsOneWidget);
      expect(find.text('Nenhuma mesa aberta agora'), findsNothing);

      // E o filtro "Com vagas" explica que não há onde entrar.
      await tocarFiltro(tester, 'Com vagas');
      expect(find.text('Nenhuma mesa com vaga agora'), findsOneWidget);
      sem.dispose();
    });

    testWidgets('LB-18 ATUALIZANDO desabilita o botão e diz o que faz', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01')],
        atualizando: true,
      );
      final botao = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh_rounded),
      );
      expect(botao.onPressed, isNull);
      expect(botao.tooltip, 'Atualizando a lista');
      sem.dispose();
    });

    testWidgets('LB-19 não há dado de demonstração em estado nenhum', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      for (final fase in FaseDaDescoberta.values) {
        await montarNuLobby(tester, fase: fase);
        final tudo = textosVisiveis(tester).join(' | ');
        // Os nomes, metas e modalidades dos protótipos.
        for (final maquete in const [
          'Mesa de Exemplo',
          '150',
          '200',
          '300',
          '500',
          '1000',
          'Rápida',
          'Normal',
          'Clássica',
        ]) {
          expect(
            tudo.contains(maquete),
            isFalse,
            reason: 'maquete "$maquete" na fase $fase',
          );
        }
      }
      sem.dispose();
    });
  });

  // =========================================================================
  group('§11.3 — INGRESSO NÃO PERTENCE A ESTA OS', () {
    // =======================================================================

    testWidgets('LB-20 sem callback, o card NÃO é botão', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(tester, mesas: [mesa(codigo: 'M-01', apelidos: ['Ana'])]);
      final nos = nosSemanticos(tester)
          .where((n) => n.label.contains('Mesa de Ana'))
          .toList();
      expect(nos, hasLength(1));
      expect(
        nos.single.flagsCollection.isButton,
        isFalse,
        reason: 'não há ingresso nesta OS; um botão prometeria o que não há',
      );
      sem.dispose();
    });

    testWidgets('LB-21 o callback recebe o CÓDIGO OPACO — e nada mais', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      final escolhidos = <String>[];
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'CODIGO-OPACO-1', apelidos: ['Ana'])],
        onEscolherMesa: escolhidos.add,
      );
      await tester.tap(find.text('Mesa de Ana'));
      await tester.pumpAndSettle();
      expect(escolhidos, ['CODIGO-OPACO-1']);
      sem.dispose();
    });
  });

  // =========================================================================
  group('§13 — ACESSIBILIDADE', () {
    // =======================================================================

    testWidgets('A11Y-22 o Voltar tem nome', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(tester, mesas: [mesa(codigo: 'M-01')]);
      final voltar = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left),
      );
      expect(voltar.tooltip, 'Voltar');
      sem.dispose();
    });

    testWidgets('A11Y-23 os filtros têm PAPEL e ESTADO de seleção', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await montarLobby(tester, mesas: [mesa(codigo: 'M-01')]);

      final todas = nosSemanticos(
        tester,
      ).where((n) => n.label.startsWith('Todas')).toList();
      expect(todas, hasLength(1));
      expect(todas.single.flagsCollection.isButton, isTrue);
      expect((todas.single.flagsCollection.isSelected == Tristate.isTrue), isTrue);

      final aberto = nosSemanticos(
        tester,
      ).where((n) => n.label.startsWith('Aberto')).toList();
      expect((aberto.single.flagsCollection.isSelected == Tristate.isTrue), isFalse);

      // Selecionar troca o estado — e troca DOS DOIS lados.
      await tocarFiltro(tester, 'Aberto');
      expect(
        nosSemanticos(tester)
            .firstWhere((n) => n.label.startsWith('Aberto'))
            .flagsCollection.isSelected == Tristate.isTrue,
        isTrue,
      );
      expect(
        nosSemanticos(tester)
            .firstWhere((n) => n.label.startsWith('Todas'))
            .flagsCollection.isSelected == Tristate.isTrue,
        isFalse,
      );
      sem.dispose();
    });

    testWidgets('A11Y-24 o card é UMA frase, sem duplicação', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Beto'])],
      );
      // O nome da mesa aparece em UM nó semântico só. Se o `Text` interno
      // produzisse o seu, seriam dois com o mesmo conteúdo.
      final comNome = nosSemanticos(
        tester,
      ).where((n) => n.label.contains('Mesa de Ana')).toList();
      expect(comNome, hasLength(1));
      // E os apelidos dos assentos não viram nós próprios.
      expect(
        nosSemanticos(tester).where((n) => n.label == 'Ana'),
        isEmpty,
      );
      sem.dispose();
    });

    testWidgets('A11Y-25 nenhum nó tocável é anônimo', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01'), mesa(codigo: 'M-02')],
      );
      final anonimos = nosSemanticos(tester)
          .where(
            (n) =>
                (n.flagsCollection.isButton ||
                    n.getSemanticsData().hasAction(SemanticsAction.tap)) &&
                n.label.trim().isEmpty,
          )
          .toList();
      expect(anonimos, isEmpty);
      sem.dispose();
    });

    testWidgets('A11Y-26 todo alvo de toque tem 48 dp ou mais', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01'), mesa(codigo: 'M-02')],
      );

      // Os dois botões do cabeçalho.
      for (final icone in [Icons.chevron_left, Icons.refresh_rounded]) {
        final alvo = find.widgetWithIcon(IconButton, icone);
        final t = tester.getSize(alvo);
        expect(
          t.width >= kAlvoMinimo && t.height >= kAlvoMinimo,
          isTrue,
          reason: 'botão $icone mede $t',
        );
      }

      // Os cinco chips de filtro.
      for (final f in FiltroDoLobby.values) {
        final chip = find.ancestor(
          of: find.textContaining(f.rotulo).first,
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(chip.first);
        await tester.pumpAndSettle();
        final t = tester.getSize(chip.first);
        expect(
          t.height >= kAlvoMinimo,
          isTrue,
          reason: 'filtro ${f.rotulo} mede $t',
        );
      }
      sem.dispose();
    });

    testWidgets('A11Y-27 os assentos são nomeados um a um', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [mesa(codigo: 'M-01', humanos: 1, apelidos: ['Ana'])],
      );
      final frase = fraseDoCard(tester, 'Mesa de Ana');
      for (var i = 1; i <= 4; i++) {
        expect(frase, contains('Posição $i'));
      }
      sem.dispose();
    });

    testWidgets('A11Y-28 a ordem de foco é a ordem da tela', (tester) async {
      final sem = tester.ensureSemantics();
      await montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', apelidos: ['Ana']),
          mesa(codigo: 'M-02', apelidos: ['Beto']),
        ],
      );
      final rotulos = rotulosSemanticos(tester);
      final iVoltar = rotulos.indexWhere((r) => r == 'Voltar');
      final iTodas = rotulos.indexWhere((r) => r.startsWith('Todas'));
      final iAna = rotulos.indexWhere((r) => r.contains('Mesa de Ana'));
      final iBeto = rotulos.indexWhere((r) => r.contains('Mesa de Beto'));
      expect(iVoltar, lessThan(iTodas));
      expect(iTodas, lessThan(iAna));
      expect(iAna, lessThan(iBeto), reason: 'a ordem do servidor manda no foco');
      sem.dispose();
    });
  });

  // =========================================================================
  group('§14.5 — RESPONSIVIDADE', () {
    // =======================================================================

    for (final largura in const [320.0, 360.0, 412.0]) {
      for (final escala in const [1.0, 1.3, 1.5, 1.75, 2.0]) {
        testWidgets(
          'RS-29 ${largura.toInt()} dp a ${(escala * 100).toInt()}%: '
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

            await montarLobby(
              tester,
              mesas: [
                mesa(
                  codigo: 'M-01',
                  humanos: 3,
                  apelidos: ['Anabela', 'Bernardo', 'Constância'],
                  metaPontos: 3000,
                ),
                mesa(codigo: 'M-02', humanos: 1, apelidos: ['Dulce']),
              ],
              largura: largura,
              escalaDeTexto: escala,
            );

            // O `reason` é avaliado SEMPRE, inclusive quando a expectativa
            // passa — `estouros.first` numa lista vazia derruba o caso com
            // "Bad state: No element" e faz um teste verde parecer defeito da
            // tela. O texto tem de ser seguro para lista vazia.
            expect(
              estouros,
              isEmpty,
              reason:
                  'estouro em ${largura}dp @ ${escala}x: '
                  '${estouros.isEmpty ? "" : estouros.first}',
            );

            // A LISTA ROLA, e o último card é alcançável.
            //
            // `ensureVisible` NÃO serve aqui: a lista é preguiçosa, e um card
            // inteiramente fora da viewport não tem Element — o finder vem
            // vazio e o caso morre com "Bad state: No element", parecendo
            // defeito da tela. Com fonte a 200% em 320 dp, o primeiro card
            // sozinho já passa da altura útil, então o segundo SEMPRE está
            // fora. Quem constrói o que falta é a rolagem.
            await tester.scrollUntilVisible(
              find.text('Mesa de Dulce'),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            expect(find.text('Mesa de Dulce'), findsWidgets);

            // E o Voltar continua com o piso de toque.
            final t = tester.getSize(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            );
            expect(t.height >= kAlvoMinimo, isTrue, reason: 'Voltar mede $t');
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

List<SemanticsNode> nosSemanticos(WidgetTester tester) =>
    find.semantics.byPredicate((_) => true).evaluate().toList();

List<String> rotulosSemanticos(WidgetTester tester) => nosSemanticos(tester)
    .map((n) => n.label)
    .where((r) => r.isNotEmpty)
    .toList();

List<String> textosVisiveis(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}')
    .toList();

/// Os nomes das mesas desenhadas, NA ORDEM em que aparecem na árvore.
List<String> nomesDosCards(WidgetTester tester) => textosVisiveis(
  tester,
).where((t) => t.startsWith('Mesa de ')).toList();

/// A frase acessível do card cujo rótulo contém [nome].
String fraseDoCard(WidgetTester tester, String nome) => rotulosSemanticos(
  tester,
).firstWhere((r) => r.contains(nome));

Future<EstadoDaDescoberta> montarLobby(
  WidgetTester tester, {
  required List<Map<String, Object?>> mesas,
  bool atualizando = false,
  bool ultimaRecusada = false,
  void Function(String)? onEscolherMesa,
  double largura = 390,
  double escalaDeTexto = 1.0,
}) async {
  final estado = EstadoDaDescoberta();
  final ok = estado.aplicar(
    retratoDeMesas(mesas: mesas),
    geracaoDeTransporte: 0,
  );
  expect(ok, isTrue, reason: 'o arnês precisa de um retrato válido');

  await _montar(
    tester,
    retrato: estado.retrato,
    fase: estado.fase,
    atualizando: atualizando,
    ultimaRecusada: ultimaRecusada,
    onEscolherMesa: onEscolherMesa,
    largura: largura,
    escalaDeTexto: escalaDeTexto,
  );
  return estado;
}

/// Monta a partir de um retrato CRU — para os casos que precisam de um
/// payload que o construtor não produziria sozinho.
Future<void> montarLobbyCru(
  WidgetTester tester,
  Map<String, Object?> bruto,
) async {
  final estado = EstadoDaDescoberta();
  final ok = estado.aplicar(bruto, geracaoDeTransporte: 0);
  expect(ok, isTrue, reason: 'o retrato cru do arnês tem de ser válido');
  await _montar(
    tester,
    retrato: estado.retrato,
    fase: estado.fase,
    atualizando: false,
    ultimaRecusada: false,
    onEscolherMesa: null,
  );
}

/// Monta a tela SEM retrato, numa fase escolhida.
Future<void> montarNuLobby(
  WidgetTester tester, {
  required FaseDaDescoberta fase,
}) async {
  await _montar(
    tester,
    retrato: null,
    fase: fase,
    atualizando: false,
    ultimaRecusada: false,
    onEscolherMesa: null,
  );
}

Future<void> _montar(
  WidgetTester tester, {
  required dynamic retrato,
  required FaseDaDescoberta fase,
  required bool atualizando,
  required bool ultimaRecusada,
  required void Function(String)? onEscolherMesa,
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
        home: LobbyPublicoScreen(
          retrato: retrato,
          fase: fase,
          atualizando: atualizando,
          ultimaAtualizacaoRecusada: ultimaRecusada,
          onVoltar: () {},
          onAtualizar: () {},
          onEscolherMesa: onEscolherMesa,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
