// apresentacao_stbl_test.dart — O SEGUNDO P0 (OS 38.2 §3.2 e §14.3).
//
// UMA REGRA, e ela vale em toda superfície visível:
//
//   A CHAVE DO FIO É `sbtl`. O TEXTO DA JOGADORA É `STBL`.
//
// As duas coisas são verdadeiras ao mesmo tempo e nenhuma se dobra à outra:
// mexer na chave quebraria o servidor; mostrar a chave crua mostraria jargão de
// código para quem só quer jogar.
//
// ---------------------------------------------------------------------------
// POR QUE UMA VARREDURA DE CÓDIGO-FONTE, E NÃO SÓ CASOS DE TELA
// ---------------------------------------------------------------------------
//
// Um caso de tela prova o que ELE desenha. Amanhã alguém acrescenta um tooltip,
// uma mensagem de erro ou um item de filtro novo, escreve `'sbtl'` porque é a
// chave que estava à mão, e nenhum caso existente reprova — o texto novo não
// tem caso.
//
// A varredura fecha isso pelo outro lado: nenhum literal `'sbtl'` pode existir
// nas camadas de APRESENTAÇÃO. A chave só vive em `modelo_descoberta.dart` (a
// tradução), em `contrato_descoberta.dart` (o vocabulário) e no adaptador — os
// três lugares que falam com o servidor.
//
// A varredura é sobre CÓDIGO, não sobre prosa: comentários explicam a regra e
// citam a chave o tempo todo, e procurá-la no arquivo cru daria falso positivo
// em cima da própria explicação.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/descoberta/estado_descoberta.dart';
import 'package:buraco_master_vip/descoberta/modelo_descoberta.dart';
import 'package:buraco_master_vip/screens/lobby_publico_screen.dart';

import 'retrato_de_teste.dart';

/// Camadas onde a chave do servidor NÃO pode aparecer.
///
/// `lib/casca` e `lib/screens` são apresentação inteira. `lib/descoberta` entra
/// com exceções nomeadas — são os três arquivos que existem justamente para
/// falar a língua do servidor.
const _pastasDeApresentacao = ['lib/casca', 'lib/screens'];
const _excecoesDaDescoberta = {
  'contrato_descoberta.dart', // o vocabulário do fio
  'modelo_descoberta.dart', // a tradução `sbtl` -> `STBL`
  'adaptador_descoberta.dart', // a fronteira que lê o mapa cru
};

/// Tira comentários e literais de string do fonte, deixando só o CÓDIGO.
///
/// Ingênuo de propósito: não é um parser de Dart, é uma varredura. O que ele
/// precisa acertar é não confundir prosa com código, e para isso basta.
String soCodigo(String fonte) {
  final semBloco = fonte.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final linhas = semBloco.split('\n').map((l) {
    final i = l.indexOf('//');
    return i == -1 ? l : l.substring(0, i);
  });
  return linhas.join('\n');
}

List<File> _dartsDe(String pasta) {
  final d = Directory(pasta);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}


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
  group('§3.2 — A CHAVE E O RÓTULO', () {
    // =======================================================================

    test('ST-01 a tradução é exatamente a da tabela da OS', () {
      expect(ModalidadeDeMesa.aberto.chave, 'aberto');
      expect(ModalidadeDeMesa.aberto.rotulo, 'Aberto');
      expect(ModalidadeDeMesa.fechado.chave, 'fechado');
      expect(ModalidadeDeMesa.fechado.rotulo, 'Fechado');
      expect(ModalidadeDeMesa.sbtl.chave, 'sbtl');
      expect(ModalidadeDeMesa.sbtl.rotulo, 'STBL');
    });

    test('ST-02 nenhum rótulo é a chave crua, e nenhum é nome inventado', () {
      const inventados = ['Rápida', 'Normal', 'Clássica', 'Sbtl', 'sbtl'];
      for (final m in ModalidadeDeMesa.values) {
        expect(
          inventados.contains(m.rotulo),
          isFalse,
          reason: 'rótulo "${m.rotulo}" é chave crua ou nome inventado',
        );
      }
      // E `Sbtl` — o erro mais provável de digitação — não é aceito.
      expect(ModalidadeDeMesa.sbtl.rotulo, isNot('Sbtl'));
      expect(ModalidadeDeMesa.sbtl.rotulo, isNot('SBTL'));
    });

    test('ST-03 o FILTRO tira o rótulo do modelo, não de um literal próprio', () {
      expect(FiltroDoLobby.stbl.rotulo, 'STBL');
      expect(FiltroDoLobby.stbl.modalidade, ModalidadeDeMesa.sbtl);
      expect(FiltroDoLobby.aberto.rotulo, 'Aberto');
      expect(FiltroDoLobby.fechado.rotulo, 'Fechado');
      expect(FiltroDoLobby.todas.rotulo, 'Todas');
      expect(FiltroDoLobby.comVagas.rotulo, 'Com vagas');
    });

    test('ST-04 a chave continua sendo o que o servidor entende', () {
      // Se alguém "consertar" a chave para STBL, o retrato do servidor deixa de
      // ser lido — e é este caso que diz por quê.
      expect(ModalidadeDeMesa.daChave('sbtl'), ModalidadeDeMesa.sbtl);
      expect(ModalidadeDeMesa.daChave('STBL'), isNull);
      expect(ModalidadeDeMesa.daChave('Sbtl'), isNull);
    });
  });

  // =========================================================================
  group('§14.3 — VARREDURA GLOBAL DO CÓDIGO', () {
    // =======================================================================

    test('ST-05 a chave crua não existe no CÓDIGO da apresentação', () {
      final culpados = <String>[];
      for (final pasta in _pastasDeApresentacao) {
        for (final f in _dartsDe(pasta)) {
          final codigo = soCodigo(f.readAsStringSync());
          if (codigo.contains("'sbtl'") ||
              codigo.contains('"sbtl"') ||
              codigo.contains("'Sbtl'") ||
              codigo.contains("'SBTL'")) {
            culpados.add(f.path);
          }
        }
      }
      expect(
        culpados,
        isEmpty,
        reason:
            'a chave do servidor apareceu na apresentação: $culpados. Use '
            'ModalidadeDeMesa.rotulo — ele é o único lugar que traduz.',
      );
    });

    test('ST-06 dentro de lib/descoberta, só os três arquivos da fronteira', () {
      final culpados = <String>[];
      for (final f in _dartsDe('lib/descoberta')) {
        final nome = f.uri.pathSegments.last;
        if (_excecoesDaDescoberta.contains(nome)) continue;
        final codigo = soCodigo(f.readAsStringSync());
        if (codigo.contains("'sbtl'") || codigo.contains('"sbtl"')) {
          culpados.add(f.path);
        }
      }
      expect(culpados, isEmpty, reason: 'chave crua fora da fronteira: $culpados');
    });

    test('ST-07 a varredura ENXERGA o que deve enxergar (controle)', () {
      // Sem este caso, a varredura passaria feliz com um bug que a fizesse não
      // ler arquivo nenhum. Ela tem de acusar um fonte plantado.
      const plantado = "final x = 'sbtl';";
      expect(soCodigo(plantado).contains("'sbtl'"), isTrue);
      // E tem de IGNORAR prosa.
      const prosa = "// a chave do servidor é 'sbtl' e vira STBL na tela";
      expect(soCodigo(prosa).contains("'sbtl'"), isFalse);
      // E tem de estar lendo arquivos de verdade.
      expect(_dartsDe('lib/screens').length, greaterThan(5));
      expect(_dartsDe('lib/casca').length, greaterThan(5));
    });
  });

  // =========================================================================
  group('§14.3 — NA TELA', () {
    // =======================================================================

    testWidgets('ST-08 filtros, cards e semântica dizem STBL', (tester) async {
      final sem = tester.ensureSemantics();
      await _montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', modalidade: 'sbtl', humanos: 2),
          mesa(codigo: 'M-02', modalidade: 'aberto', humanos: 1),
          mesa(codigo: 'M-03', modalidade: 'fechado', humanos: 3),
        ],
      );

      // O chip do filtro.
      expect(find.textContaining('STBL'), findsWidgets);
      // A etiqueta do card.
      expect(find.text('STBL'), findsWidgets);
      // A semântica.
      final rotulos = _rotulosSemanticos(tester);
      expect(rotulos.any((r) => r.contains('modalidade STBL')), isTrue);
      expect(rotulos.any((r) => r.contains('modalidade Aberto')), isTrue);
      expect(rotulos.any((r) => r.contains('modalidade Fechado')), isTrue);
      sem.dispose();
    });

    testWidgets('ST-09 NENHUM texto visível contém a chave crua', (tester) async {
      final sem = tester.ensureSemantics();
      await _montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-01', modalidade: 'sbtl', humanos: 2),
          mesa(codigo: 'M-02', modalidade: 'aberto'),
          mesa(codigo: 'M-03', modalidade: 'fechado'),
        ],
      );

      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}')
          .toList();
      expect(textos, isNotEmpty, reason: 'o arnês tem de ter desenhado algo');
      for (final t in textos) {
        expect(t.contains('sbtl'), isFalse, reason: 'texto visível: "$t"');
        expect(t.contains('Sbtl'), isFalse, reason: 'texto visível: "$t"');
      }
      for (final r in _rotulosSemanticos(tester)) {
        expect(r.contains('sbtl'), isFalse, reason: 'semântica: "$r"');
        expect(r.contains('Sbtl'), isFalse, reason: 'semântica: "$r"');
      }
      sem.dispose();
    });

    testWidgets('ST-10 o filtro STBL seleciona as mesas de chave `sbtl`', (
      tester,
    ) async {
      final sem = tester.ensureSemantics();
      await _montarLobby(
        tester,
        mesas: [
          mesa(codigo: 'M-SBTL', modalidade: 'sbtl', humanos: 2, apelidos: ['Ana', 'Beto']),
          mesa(codigo: 'M-ABER', modalidade: 'aberto', humanos: 1, apelidos: ['Caio']),
        ],
      );

      await tocarFiltro(tester, 'STBL');

      // O card da mesa `sbtl` continua; o da `aberto` sai.
      expect(find.text('Mesa de Ana'), findsOneWidget);
      expect(find.text('Mesa de Caio'), findsNothing);
      final rotulos = _rotulosSemanticos(tester);
      final deMesa = rotulos.where((r) => r.contains('modalidade')).toList();
      expect(deMesa, hasLength(1));
      expect(deMesa.single.contains('modalidade STBL'), isTrue);
      sem.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// auxiliares
// ---------------------------------------------------------------------------

List<String> _rotulosSemanticos(WidgetTester tester) => find.semantics
    .byPredicate((n) => n.label.isNotEmpty)
    .evaluate()
    .map((n) => n.label)
    .toList();

Future<void> _montarLobby(
  WidgetTester tester, {
  required List<Map<String, Object?>> mesas,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final estado = EstadoDaDescoberta();
  final ok = estado.aplicar(
    retratoDeMesas(mesas: mesas),
    geracaoDeTransporte: 0,
  );
  expect(ok, isTrue, reason: 'o arnês precisa de um retrato válido');

  await tester.pumpWidget(
    MaterialApp(
      home: LobbyPublicoScreen(
        retrato: estado.retrato,
        fase: estado.fase,
        atualizando: false,
        onVoltar: () {},
        onAtualizar: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}
