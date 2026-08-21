// a11y_ranking_cabecalho_escala_test.dart — a matriz da OS "A11Y — Ranking
// estruturado e resiliente a 200%".
//
// ---------------------------------------------------------------------------
// AS DUAS COISAS QUE ESTA SUÍTE GUARDA
// ---------------------------------------------------------------------------
//
// 1. ESTRUTURA. O Ranking desenhava três títulos — o da tela, `PÓDIO` e
//    `CLASSIFICAÇÃO` — e nenhum deles era um cabeçalho para o leitor de tela.
//    Quem navega por cabeçalhos caía direto numa lista de linhas sem saber
//    onde o pódio termina e a classificação começa; e, sem cabeçalho, o gesto
//    "próximo cabeçalho" simplesmente não tinha para onde ir.
//
//    O que NÃO pode virar cabeçalho é a linha do jogador. Nome, colocação e
//    liga são conteúdo da tabela; promovê-los a cabeçalho encheria a navegação
//    estrutural com um item por jogador e destruiria justamente o atalho que
//    ela existe para dar.
//
// 2. ESCALA. A linha da tabela reservava 44 lógicos FIXOS para a colocação e
//    prendia nome e liga em uma linha com reticências. A 200% — a maior fonte
//    que o Android oferece sem recursos extras — o `#123` não cabia nos 44 e o
//    nome do jogador era cortado. Perder o nome de quem está classificado não
//    é degradação cosmética: é a informação competitiva da tela.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE NÃO FAZ
// ---------------------------------------------------------------------------
//
// Não constrói `EstadoTabelaRanking` na mão. Todos os estados nascem de uma
// resposta com a FORMA do contrato real atravessando `LeitorDeRanking` e
// `RankingDaSessao` — o mesmo caminho da produção. Um teste que injetasse
// estado pulando o leitor provaria a tela contra uma tabela que a produção não
// sabe fabricar.
//
// Não afirma nada sobre cálculo, temporada, liga ou ordem: quem decide é
// `ordenacao.ts`, e a tela — como a suíte vizinha já prova — repassa.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/ranking_de_producao.dart';
import 'package:buraco_master_vip/ranking/escopo_ranking.dart';
import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_da_sessao.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';

// ===========================================================================
// Fixtures — a FORMA do contrato real, e nada além dela
// ===========================================================================

const contaA = 'P0A1B2C3D4E5';
const alvoX = 'PXX1XX2XX3XX';
const alvoY = 'PYY1YY2YY3YY';

/// Um apelido longo de verdade. É o apelido comprido que revela o corte a 200%.
const nomeLongo = 'Mariana Aparecida Nascimento';

Map<String, Object?> jogadorBruto({
  required String id,
  String apelido = '',
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int pontos = 1200,
  int posicao = 1,
  bool souEu = false,
}) => {
  'id': id,
  'apelido': apelido,
  'avatar': '',
  'liga': liga,
  'ligaId': ligaId,
  'pontos': pontos,
  'posicao': posicao,
  'direcao': 'manteve',
  'delta': 0,
  'selo': null,
  'souEu': souEu,
  'estado': 'classificado',
  'qualificacaoRestante': 0,
  'partidas': 10,
  'vitorias': 6,
  'derrotas': 4,
  'aproveitamento': 60.0,
};

Map<String, Object?> abertura({
  String? temporadaId = 'T-2026-01',
  Object? eu,
  List<Map<String, Object?>> podio = const [],
  List<Map<String, Object?>> primeiraPagina = const [],
}) => {
  'resumo': {
    'escopo': 'temporada',
    'temporadaId': temporadaId,
    'temporadaNome': 'Temporada 1',
    'faixaTempo': 'em andamento',
    'fimEm': null,
    'divisao': null,
    'podio': podio,
    'escadaLigas': const [],
    'eu': eu,
  },
  'primeiraPagina': {
    'itens': primeiraPagina,
    'cursorProxima': null,
    'fim': true,
  },
};

/// A tabela do pior caso de largura: colocação de três dígitos, apelido longo,
/// rótulo de liga longo e o selo "você" na mesma linha.
///
/// O RÓTULO LONGO É `Diamante`, e a escolha não é indiferente: ele tem oito
/// caracteres — a maior das sete Ligas oficiais, empatado com nenhuma — e é uma
/// Liga que EXISTE. Até a canonização das sete Ligas este fixture usava
/// `Imperial`, que tem o mesmo comprimento e por isso media a mesma coisa, mas
/// deixava o nome de uma liga inexistente espalhado por cinco asserções desta
/// suíte. A propriedade medida aqui é a largura, e ela sobreviveu à troca.
Map<String, Object?> aberturaPovoada({String? temporadaId = 'T-2026-01'}) =>
    abertura(
      temporadaId: temporadaId,
      eu: jogadorBruto(id: contaA, apelido: nomeLongo, souEu: true, posicao: 2),
      podio: [
        jogadorBruto(id: alvoX, apelido: 'Primeira', posicao: 1, pontos: 2000),
        jogadorBruto(
          id: contaA,
          apelido: nomeLongo,
          posicao: 2,
          souEu: true,
          liga: 'Diamante',
          ligaId: 'diamante',
        ),
        jogadorBruto(id: alvoY, apelido: 'Terceiro', posicao: 3, pontos: 900),
      ],
      primeiraPagina: [
        jogadorBruto(id: alvoX, apelido: 'Primeira', posicao: 1, pontos: 2000),
        jogadorBruto(
          id: contaA,
          apelido: nomeLongo,
          posicao: 2,
          souEu: true,
          liga: 'Diamante',
          ligaId: 'diamante',
        ),
        // Colocação de TRÊS DÍGITOS: é ela que não cabia nos 44 fixos.
        jogadorBruto(
          id: alvoY,
          apelido: 'Centesimo Vigesimo Terceiro',
          posicao: 123,
          pontos: 400,
          liga: 'Bronze',
          ligaId: 'bronze',
        ),
      ],
    );

// ===========================================================================
// Transporte regulável — responde o que o teste mandar, quando mandar
// ===========================================================================

class TransporteRegulavel extends TransporteRanking {
  bool automatico = true;
  Object? resposta = aberturaPovoada();
  FalhaRanking? falha;
  final List<Completer<AberturaRanking>> pendentes = [];

  @override
  Future<AberturaRanking> abrirRanking() {
    if (!automatico) {
      final c = Completer<AberturaRanking>();
      pendentes.add(c);
      return c.future;
    }
    final f = falha;
    if (f != null) return Future<AberturaRanking>.error(f);
    return Future.value(AberturaRanking.daResposta(resposta));
  }

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) =>
      Future.value(
        FotografiaRanking.doPerfilPublico({
          'id': publicId,
          'temporadaId': 'T-2026-01',
          'classificado': true,
          'jogador': jogadorBruto(id: publicId, posicao: 50),
        }),
      );
}

// ===========================================================================
// Ferramentas de medição
// ===========================================================================

/// Superfície de telefone. Um teste de widget nasce em 800x600 lógicos — mais
/// largo que qualquer telefone —, e é justamente a largura que esta OS mede.
void telefone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Todos os nós da árvore semântica, em ordem de travessia.
List<SemanticsNode> nosSemanticos(WidgetTester tester) {
  // A raiz sai de `getSemantics`, e não de `binding.pipelineOwner`: o segundo
  // está deprecado, e o `rootPipelineOwner` que o substituiu não é o dono da
  // árvore montada por `pumpWidget` — ali ele devolve `null` e a suíte inteira
  // mediria uma árvore vazia sem reclamar.
  final raiz = tester.getSemantics(find.byType(MaterialApp));
  final saida = <SemanticsNode>[];
  void visitar(SemanticsNode n) {
    saida.add(n);
    n.visitChildren((filho) {
      visitar(filho);
      return true;
    });
  }

  visitar(raiz);
  return saida;
}

/// Os rótulos marcados como cabeçalho, na ordem em que o leitor de tela os
/// encontra.
List<String> cabecalhos(WidgetTester tester) => nosSemanticos(tester)
    .where((n) => n.flagsCollection.isHeader)
    .map((n) => n.label.trim())
    .where((l) => l.isNotEmpty)
    .toList();

/// Todos os rótulos falados da árvore.
List<String> rotulos(WidgetTester tester) => nosSemanticos(tester)
    .map((n) => n.label.trim())
    .where((l) => l.isNotEmpty)
    .toList();

/// Os parágrafos que a engine teve de cortar para caber.
List<String> textosCortados(WidgetTester tester) => tester.allRenderObjects
    .whereType<RenderParagraph>()
    .where((p) => p.didExceedMaxLines)
    .map((p) => p.text.toPlainText())
    .toList();

/// O texto visível da tela.
String textoDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// Tudo o que a pessoa ALCANÇA, rolando a lista até o fim.
///
/// A `ListView` só constrói o que cabe na viewport; com fonte grande as linhas
/// ficam altas e o fim da tabela deixa de existir na árvore até alguém rolar.
/// Medir só o primeiro quadro confundiria "não coube ainda" com "sumiu" — e a
/// pergunta da OS é se o conteúdo continua ALCANÇÁVEL.
Future<String> textoAlcancavel(WidgetTester tester) async {
  final visto = StringBuffer(textoDaTela(tester));
  if (find.byType(ListView).evaluate().isEmpty) return visto.toString();
  for (var i = 0; i < 20; i++) {
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pump();
    visto.write(' | ${textoDaTela(tester)}');
  }
  return visto.toString();
}

/// Estouro de layout. `RenderFlex overflowed` chega por `FlutterError` em modo
/// debug, e `takeException` é onde ele aterrissa.
void semEstouro(WidgetTester tester, String contexto) {
  final erro = tester.takeException();
  expect(
    erro,
    isNull,
    reason: 'estouro de layout em $contexto — o Ranking perdeu conteúdo: $erro',
  );
}

/// Nada pintado fora da largura da tela.
void dentroDaLargura(WidgetTester tester, String contexto) {
  final largura = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (final elemento in find.byType(Text).evaluate()) {
    final caixa = elemento.renderObject as RenderBox?;
    if (caixa == null || !caixa.hasSize) continue;
    final canto = caixa.localToGlobal(Offset.zero);
    final texto = (elemento.widget as Text).data ?? '';
    expect(
      canto.dx + caixa.size.width,
      lessThanOrEqualTo(largura + 0.5),
      reason: '"$texto" passa da borda direita em $contexto',
    );
    expect(
      canto.dx,
      greaterThanOrEqualTo(-0.5),
      reason: '"$texto" comeca fora da borda esquerda em $contexto',
    );
  }
}

// ===========================================================================
// Montagem — sempre pelo caminho real
// ===========================================================================

late TransporteRegulavel transporte;
late RankingDaSessao ranking;

void abrirSessao() {
  transporte = TransporteRegulavel();
  ranking = RankingDaSessao(leitor: LeitorDeRanking(transporte: transporte));
  addTearDown(ranking.dispose);
}

Future<void> montar(
  WidgetTester tester, {
  double escala = 1.0,
}) async {
  telefone(tester);
  ranking.aoMudarSessao(geracao: 1, publicId: contaA);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(escala)),
      child: EscopoRanking(
        ranking: ranking,
        child: const MaterialApp(home: RankingDeProducao()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

// ===========================================================================
// Auditoria estrutural — o fecho que nasce em `main()`
// ===========================================================================

String semComentarios(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';
    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
        if (i + 1 < fonte.length) saida.write(fonte[i + 1]);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }
    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

final RegExp _import = RegExp('import\\s+[\'"]([^\'"]+)[\'"]');

String _barras(String p) => p.replaceAll(r'\', '/');

String _resolver(String de, String alvo) {
  if (alvo.startsWith('package:buraco_master_vip/')) {
    return 'lib/${alvo.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(de).split('/')..removeLast();
  for (final parte in alvo.split('/')) {
    if (parte == '..') {
      base.removeLast();
    } else if (parte != '.') {
      base.add(parte);
    }
  }
  return base.join('/');
}

Set<String> alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(semComentarios(f))) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolver(atual, alvo));
    }
  }
  return vistos;
}

void main() {
  setUp(abrirSessao);

  // =========================================================================
  // A1 — os cabeçalhos existem, e são SÓ os títulos
  // =========================================================================
  group('A1 — estrutura por cabeçalhos', () {
    testWidgets('A1a — o título da tela é um cabeçalho', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      expect(cabecalhos(tester), contains('Ranking'));
      handle.dispose();
    });

    testWidgets('A1b — PÓDIO e CLASSIFICAÇÃO são cabeçalhos', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      final marcados = cabecalhos(tester);
      expect(marcados, contains('PÓDIO'));
      expect(marcados, contains('CLASSIFICAÇÃO'));
      handle.dispose();
    });

    testWidgets('A1c — a ordem é a visual: título, pódio, classificação', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      expect(cabecalhos(tester), ['Ranking', 'PÓDIO', 'CLASSIFICAÇÃO']);
      handle.dispose();
    });

    testWidgets('A1d — NENHUM jogador vira cabeçalho', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      // Os três títulos, e mais nada. Um cabeçalho por linha destruiria o
      // atalho que a navegação estrutural existe para dar.
      expect(cabecalhos(tester), hasLength(3));
      for (final c in cabecalhos(tester)) {
        expect(c, isNot(contains(nomeLongo)));
        expect(c, isNot(contains('Posição')));
        expect(c, isNot(contains('Diamante')));
      }
      handle.dispose();
    });

    testWidgets('A1e — sem seção não há cabeçalho de seção', (tester) async {
      final handle = tester.ensureSemantics();
      transporte.resposta = abertura(eu: null);
      await montar(tester);
      // Estado vazio: o título da tela permanece, e os de seção não são
      // inventados para uma tabela que não existe.
      expect(cabecalhos(tester), ['Ranking']);
      handle.dispose();
    });
  });

  // =========================================================================
  // A2 — a semântica que já era boa continua de pé
  // =========================================================================
  group('A2 — a linha continua falando por extenso', () {
    testWidgets('A2a — a frase de `_anuncio` chega inteira', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      final falados = rotulos(tester);
      expect(
        falados,
        contains(
          'Posição 2. $nomeLongo. Diamante. Você. Toque para ver o perfil.',
        ),
      );
      expect(
        falados,
        contains(
          'Posição 123. Centesimo Vigesimo Terceiro. Bronze. Toque para ver '
          'o perfil.',
        ),
      );
      handle.dispose();
    });

    testWidgets('A2b — os fragmentos NÃO voltam à árvore', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      final linhas = rotulos(
        tester,
      ).where((l) => l.contains('Toque para ver o perfil')).toList();
      expect(linhas, isNotEmpty);

      // COMO O DEFEITO SE PARECE. Sem `excludeSemantics` os pedaços não viram
      // nós soltos — `container: true` os MESCLA no rótulo da linha, e o que o
      // leitor de tela fala vira a frase inteira seguida de "#2, Mariana
      // Aparecida Nascimento, Diamante, você" outra vez. Procurar um nó igual a
      // "#2" não acha isso; o que acha é exigir que a frase TERMINE onde
      // `_anuncio` termina.
      for (final l in linhas) {
        expect(
          l.endsWith('Toque para ver o perfil.'),
          isTrue,
          reason: 'sobrou fragmento depois do anúncio em "$l"',
        );
        // A frase diz "Posição 2", e nunca o "#2" que está desenhado na tela.
        expect(l, isNot(contains('#')), reason: 'fragmento visual em "$l"');
        expect(l, isNot(contains('você')), reason: 'selo cru em "$l"');
      }
      handle.dispose();
    });

    testWidgets('A2c — o nome não é dito duas vezes dentro do rótulo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      final comNome = rotulos(
        tester,
      ).where((l) => l.contains(nomeLongo)).toList();
      expect(comNome, isNotEmpty);
      // Pódio e primeira página trazem a MESMA pessoa — duas linhas, e é a
      // autoridade que manda as duas. O que não pode é o nome aparecer duas
      // vezes DENTRO de um rótulo.
      for (final l in comNome) {
        expect(nomeLongo.allMatches(l).length, 1, reason: 'duplicado em "$l"');
      }
      handle.dispose();
    });

    testWidgets('A2d — o botão Voltar continua nomeado', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      expect(rotulos(tester), contains('Voltar'));
      handle.dispose();
    });
  });

  // =========================================================================
  // A3 — os estados, cada um dizendo a sua frase
  // =========================================================================
  group('A3 — os estados', () {
    testWidgets('A3a — carregando', (tester) async {
      transporte.automatico = false;
      await montar(tester);
      expect(textoDaTela(tester), contains('Carregando o ranking'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('A3b — preenchido', (tester) async {
      await montar(tester);
      final texto = textoDaTela(tester);
      expect(texto, contains('PÓDIO'));
      expect(texto, contains('CLASSIFICAÇÃO'));
      expect(texto, contains(nomeLongo));
      expect(texto, contains('#123'));
    });

    testWidgets('A3c — vazio com resposta', (tester) async {
      transporte.resposta = abertura(eu: null);
      await montar(tester);
      expect(textoDaTela(tester), contains('Ninguém classificado'));
    });

    testWidgets('A3d — indisponível (sem temporada)', (tester) async {
      transporte.falha = const FalhaRanking(
        MotivoFalhaRanking.semTemporada,
        'sem temporada em andamento',
      );
      await montar(tester);
      final texto = textoDaTela(tester);
      expect(texto, contains('ainda não está sendo publicado'));
      expect(texto, isNot(contains('Ninguém classificado')));
      // Sem botão: insistir não abre uma temporada.
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('A3e — erro recuperável, com retry acessível', (tester) async {
      transporte.falha = const FalhaRanking(
        MotivoFalhaRanking.indisponivel,
        'soluço',
      );
      await montar(tester);
      expect(textoDaTela(tester), contains('Não consegui carregar'));
      expect(find.text('Tentar de novo'), findsOneWidget);
      final alvo = tester.getSize(
        find.ancestor(
          of: find.text('Tentar de novo'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(alvo.height, greaterThanOrEqualTo(48));
    });

    testWidgets('A3f — acesso recusado é NEUTRO e oferece retry', (
      tester,
    ) async {
      transporte.falha = const FalhaRanking(
        MotivoFalhaRanking.credencialOuAtestacao,
        'unauthenticated',
      );
      await montar(tester);
      final texto = textoDaTela(tester);
      expect(texto, contains('Não foi possível acessar'));
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('A3g — temporada ausente não vira tabela vazia', (
      tester,
    ) async {
      transporte.resposta = aberturaPovoada(temporadaId: null);
      await montar(tester);
      // Sem `temporadaId` a autoridade ainda respondeu, e os jogadores que ela
      // mandou continuam na tela.
      expect(textoDaTela(tester), contains(nomeLongo));
      expect(textoDaTela(tester), isNot(contains('Ninguém classificado')));
    });
  });

  // =========================================================================
  // A4 — 100%, 150% e 200%
  // =========================================================================
  group('A4 — escala de texto', () {
    for (final escala in const [1.0, 1.5, 2.0]) {
      final rotulo = '${(escala * 100).round()}%';

      testWidgets('A4 $rotulo — tabela cheia sem estouro nem corte', (
        tester,
      ) async {
        await montar(tester, escala: escala);
        semEstouro(tester, 'tabela cheia a $rotulo');
        expect(
          textosCortados(tester),
          isEmpty,
          reason: 'texto cortado a $rotulo',
        );
        dentroDaLargura(tester, 'tabela cheia a $rotulo');
      });

      testWidgets('A4 $rotulo — a informação competitiva continua alcançável', (
        tester,
      ) async {
        await montar(tester, escala: escala);
        final texto = await textoAlcancavel(tester);
        // Colocação, nome e liga: os três sobrevivem à fonte grande — inteiros,
        // porque `textosCortados` já provou que nenhum foi cortado.
        expect(texto, contains('#123'), reason: 'colocação sumiu a $rotulo');
        expect(texto, contains(nomeLongo), reason: 'nome sumiu a $rotulo');
        expect(texto, contains('Diamante'), reason: 'liga sumiu a $rotulo');
        expect(
          texto,
          contains('Centesimo Vigesimo Terceiro'),
          reason: 'o último da tabela ficou fora do alcance a $rotulo',
        );
        semEstouro(tester, 'rolagem a $rotulo');
      });

      testWidgets('A4 $rotulo — erro com botão sem estouro', (tester) async {
        transporte.falha = const FalhaRanking(
          MotivoFalhaRanking.indisponivel,
          'soluço',
        );
        await montar(tester, escala: escala);
        semEstouro(tester, 'estado de erro a $rotulo');
        expect(textosCortados(tester), isEmpty, reason: 'corte a $rotulo');
        expect(find.text('Tentar de novo'), findsOneWidget);
      });

      testWidgets('A4 $rotulo — o topo sobrevive', (tester) async {
        final handle = tester.ensureSemantics();
        await montar(tester, escala: escala);
        semEstouro(tester, 'topo a $rotulo');
        expect(cabecalhos(tester), contains('Ranking'));
        expect(rotulos(tester), contains('Voltar'));
        handle.dispose();
      });
    }

    testWidgets('A4z — a 200% nada fica FORA da rolagem', (tester) async {
      await montar(tester, escala: 2.0);
      // Todo o conteúdo da tabela mora dentro de UMA lista rolável. Um bloco
      // desenhado fora dela ficaria inalcançável assim que a fonte crescesse.
      expect(find.byType(ListView), findsOneWidget);
      final texto = await textoAlcancavel(tester);
      for (final esperado in const [
        'PÓDIO',
        'CLASSIFICAÇÃO',
        'Primeira',
        nomeLongo,
        'Centesimo Vigesimo Terceiro',
      ]) {
        expect(texto, contains(esperado), reason: '"$esperado" fora do alcance');
      }
      semEstouro(tester, 'rolagem a 200%');
    });
  });

  // =========================================================================
  // RANKING-01 — o Ranking é real, e só real
  // =========================================================================
  group('RANKING-01 — nenhuma maquete no caminho', () {
    testWidgets('R01a — sem fonte, a tela NÃO inventa jogador', (tester) async {
      telefone(tester);
      await tester.pumpWidget(const MaterialApp(home: RankingDeProducao()));
      await tester.pumpAndSettle();

      final texto = textoDaTela(tester);
      expect(texto, contains('ainda não está sendo publicado'));
      // Nenhum jogador, nenhuma liga, nenhuma colocação.
      expect(texto, isNot(contains('#')));
      expect(texto, isNot(contains('Bronze')));
      expect(texto, isNot(contains('Ouro')));
      expect(texto, isNot(contains('PÓDIO')));
      expect(texto, isNot(contains('CLASSIFICAÇÃO')));
      expect(texto, isNot(contains('Ninguém classificado')));
    });

    testWidgets('R01b — sem fonte não há cabeçalho de seção', (tester) async {
      final handle = tester.ensureSemantics();
      telefone(tester);
      await tester.pumpWidget(const MaterialApp(home: RankingDeProducao()));
      await tester.pumpAndSettle();
      expect(cabecalhos(tester), ['Ranking']);
      handle.dispose();
    });

    testWidgets('R01c — o erro não fabrica tabela', (tester) async {
      transporte.falha = const FalhaRanking(
        MotivoFalhaRanking.desconhecida,
        'boom',
      );
      await montar(tester);
      final texto = textoDaTela(tester);
      expect(texto, isNot(contains('PÓDIO')));
      expect(texto, isNot(contains('#')));
      expect(find.byType(ListView), findsNothing);
    });

    test('R01d — `RankingVM.mock()` não é alcançável de `main()`', () {
      final alcancaveis = alcancaveisDaRaiz();
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis, contains('lib/casca/ranking_de_producao.dart'));
      expect(
        alcancaveis,
        isNot(contains('lib/screens/ranking_screen.dart')),
        reason: 'a tela de maquete entrou num caminho que nasce em main()',
      );
      // E o fecho inteiro não constrói um `RankingVM`.
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        expect(
          semComentarios(f),
          isNot(contains('RankingVM')),
          reason: '$caminho constrói RankingVM no fecho produtivo',
        );
      }
    });

    testWidgets('R01e — a tela repassa a autoridade, sem reordenar', (
      tester,
    ) async {
      await montar(tester);
      final texto = textoDaTela(tester);
      // A ordem da autoridade é 1, 2, 123 — e é essa que aparece.
      final pos1 = texto.indexOf('#1 ');
      final pos123 = texto.indexOf('#123');
      expect(pos1, greaterThanOrEqualTo(0));
      expect(pos123, greaterThan(pos1));
    });

    testWidgets('R01f — a linha continua sendo um botão que abre o perfil', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await montar(tester);
      // O gesto sobrevive à marcação de cabeçalho.
      final linhas = nosSemanticos(tester)
          .where((n) => n.flagsCollection.isButton)
          .where((n) => n.label.contains('Toque para ver o perfil'))
          .toList();
      expect(linhas, isNotEmpty);
      handle.dispose();
    });
  });
}
