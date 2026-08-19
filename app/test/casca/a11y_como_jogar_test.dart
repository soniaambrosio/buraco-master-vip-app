// a11y_como_jogar_test.dart — Como Jogar por leitor de tela, e com a fonte
// ampliada.
//
// O QUE ESTA SUÍTE MEDE, E POR QUE ASSIM
//
// Acessibilidade de conteúdo não se prova olhando o widget: prova-se lendo a
// ÁRVORE SEMÂNTICA — a lista de nós que o leitor de tela realmente percorre, na
// ordem em que os percorre. É isso que cada caso aqui faz: monta a tela de
// produção, liga a semântica com `ensureSemantics()` e compara a sequência
// inteira de rótulos com uma lista congelada. Uma asserção por rótulo solto
// passaria mesmo com um emoji anunciado no meio da frase; a sequência inteira,
// não.
//
// A régua de escala é a mesma ideia, do outro lado: em vez de conferir se "cabe
// na tela", a suíte captura os erros de layout que o framework emite durante o
// `pump` (o `RenderFlex overflowed` é um deles) e varre os parágrafos atrás de
// `didExceedMaxLines` — que é o corte SILENCIOSO, o que não emite erro nenhum e
// só apaga o fim da palavra. Na base, 175% já estourava a barra de título e
// 150% já comia o rótulo de um passo; nenhum dos dois aparecia como falha.
//
// O QUE ELA NÃO FAZ: não afirma nada sobre as regras do Buraco. A prova de que
// nenhuma regra mudou é textual e literal — a lista `textosVisiveis` abaixo foi
// EXTRAÍDA da tela antes da correção e é conferida caractere a caractere. Se a
// pontuação, a distribuição ou a modalidade mudarem de texto, este arquivo cai.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/screens/como_jogar_screen.dart';

// ===========================================================================
// O que a tela deve anunciar, na ordem
// ===========================================================================

/// A sequência COMPLETA de rótulos da árvore semântica, de cima para baixo.
///
/// É a ordem de leitura: o que o leitor de tela fala, e em que ordem, ao
/// percorrer a tela do começo ao fim.
const ordemDeLeitura = <String>[
  'Voltar',
  'Como jogar',
  'Oi! Eu sou o Professor Coruja. Em 1 minutinho te ensino o Buraco — '
      'depois é só praticar no Treino!',
  'O objetivo',
  'Formar jogos (sequências ou trincas), fechar canastras e bater antes da '
      'dupla adversária. Ganha quem chegar primeiro na meta de pontos.',
  'A distribuição',
  'Cada jogador recebe 11 cartas. No centro ficam o monte (pra comprar), o '
      'lixo (descarte) e os 2 mortos — que você pega quando bate.',
  'A sua vez, em 3 passos',
  'Passo 1 de 3: Comprar',
  'Passo 2 de 3: Baixar jogos',
  'Passo 3 de 3: Descartar',
  'Canastras',
  'Canastra limpa: 7 cartas, sem curinga. Mais 200 pontos.',
  'Canastra suja: 7 cartas, com curinga. Mais 100 pontos.',
  'As 3 modalidades',
  'Aberto: lixo espalhado',
  'Fechado: aceita trinca',
  'SBTL: tradicional',
  'Pontuação (resumo)',
  'Canastra limpa: 200 pontos',
  'Canastra suja: 100 pontos',
  'Bater: 100 pontos',
  'Curinga: 20 pontos. Ás: 15 pontos',
  'Cartas na mão (ao bater adversário): menos pontos',
  'Jogar treino contra robôs',
];

/// Os cabeçalhos, na ordem. O primeiro é o título da tela; os seis seguintes
/// são as seções reais.
///
/// Repare no que NÃO está aqui: "LIMPA", "SUJA", "Aberto", "Comprar" e os
/// rótulos da tabela de pontos são texto em destaque, e não estrutura. Marcá-los
/// como cabeçalho encheria a navegação por cabeçalhos de paradas que não levam a
/// lugar nenhum.
const cabecalhos = <String>[
  'Como jogar',
  'O objetivo',
  'A distribuição',
  'A sua vez, em 3 passos',
  'Canastras',
  'As 3 modalidades',
  'Pontuação (resumo)',
];

/// TODO o texto desenhado na tela, na ordem em que os parágrafos aparecem na
/// árvore de renderização.
///
/// Esta lista foi extraída da tela ANTES da correção e não pode mudar: é a
/// prova de que nenhuma regra do jogo — pontuação, distribuição, canastra,
/// batida, modalidade — foi tocada. Acessibilidade aqui mexeu no que é
/// ANUNCIADO, nunca no que está escrito.
const textosVisiveis = <String>[
  '‹',
  'Como jogar',
  '🦉',
  'Oi! Eu sou o Professor Coruja. Em 1 minutinho te ensino o Buraco — depois é só praticar no Treino! 🃏',
  '🎯',
  'O objetivo',
  'Formar jogos (sequências ou trincas), fechar canastras e bater antes da dupla adversária. Ganha quem chegar primeiro na meta de pontos.',
  '🃏',
  'A distribuição',
  'Cada jogador recebe 11 cartas. No centro ficam o monte (pra comprar), o lixo (descarte) e os 2 mortos — que você pega quando bate.',
  '🔄',
  'A sua vez, em 3 passos',
  '1',
  '🂠',
  'Comprar',
  '2',
  '⬇️',
  'Baixar jogos',
  '3',
  '🗑️',
  'Descartar',
  '👑',
  'Canastras',
  'LIMPA',
  '7 cartas, sem curinga',
  '+200',
  'SUJA',
  '7 cartas, com curinga',
  '+100',
  '🎲',
  'As 3 modalidades',
  'Aberto',
  'lixo espalhado',
  'Fechado',
  'aceita trinca',
  'SBTL',
  'tradicional',
  '🏆',
  'Pontuação (resumo)',
  'Canastra limpa',
  '200',
  'Canastra suja',
  '100',
  'Bater',
  '100',
  'Curinga / Ás',
  '20 / 15',
  'Cartas na mão (ao bater adversário)',
  '− pontos',
  '🤖 Jogar treino contra robôs',
];

/// Ornamentos que a tela desenha e que NÃO podem ser falados: os seis ícones de
/// seção, os três dos passos, a coruja, a carta do fim da saudação, o robô do
/// botão e o chevron do Voltar.
const decoracao = <String>[
  '🦉', '🃏', '🎯', '🔄', '👑', '🎲', '🏆', '🂠', '⬇️', '🗑️', '🤖', '‹',
];

/// Qualquer pictograma, seta ou sinal ornamental — a rede larga, para o emoji
/// que alguém acrescentar depois e que não está na lista de cima.
final _pictograma = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}'
  r'\u{2030}-\u{205E}\u{FE0F}\u{2190}-\u{21FF}]',
  unicode: true,
);

// ===========================================================================
// Ferramentas
// ===========================================================================

class _No {
  final String rotulo;
  final bool cabecalho;
  final bool botao;
  final bool toque;
  final double largura;

  const _No(this.rotulo, this.cabecalho, this.botao, this.toque, this.largura);

  @override
  String toString() => '"$rotulo"'
      '${cabecalho ? ' [cabeçalho]' : ''}'
      '${botao ? ' [botão]' : ''}';
}

/// A árvore semântica achatada, na ordem de percurso, só com os nós que falam.
List<_No> _arvore(WidgetTester tester) {
  final saida = <_No>[];
  void visitar(SemanticsNode no) {
    final dado = no.getSemanticsData();
    if (dado.label.isNotEmpty) {
      saida.add(_No(
        dado.label,
        dado.hasFlag(SemanticsFlag.isHeader),
        dado.hasFlag(SemanticsFlag.isButton),
        dado.hasAction(SemanticsAction.tap),
        no.rect.width,
      ));
    }
    no.visitChildren((filho) {
      visitar(filho);
      return true;
    });
  }

  visitar(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return saida;
}

/// Todo o texto desenhado, na ordem da árvore de renderização.
List<String> _paragrafos(WidgetTester tester) {
  final saida = <String>[];
  void visitar(RenderObject o) {
    if (o is RenderParagraph) saida.add(o.text.toPlainText());
    o.visitChildren(visitar);
  }

  visitar(tester.binding.rootElement!.renderObject!);
  return saida;
}

/// Os parágrafos que o `maxLines` cortou. Este é o estrago SILENCIOSO: não
/// levanta erro nenhum, só some com o fim do texto.
List<String> _cortados(WidgetTester tester) {
  final saida = <String>[];
  void visitar(RenderObject o) {
    if (o is RenderParagraph && o.didExceedMaxLines) {
      saida.add(o.text.toPlainText());
    }
    o.visitChildren(visitar);
  }

  visitar(tester.binding.rootElement!.renderObject!);
  return saida;
}

/// Superfície de telefone. Sem isto o teste roda em 800x600 e mede uma tela que
/// ninguém tem.
void _telefone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _tela({
  double escala = 1,
  VoidCallback? onVoltar,
  VoidCallback? onJogarTreino,
}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(escala)),
    child: MaterialApp(
      home: ComoJogarScreen(
        onVoltar: onVoltar ?? () {},
        onJogarTreino: onJogarTreino ?? () {},
      ),
    ),
  );
}

/// Monta a tela e devolve o punho da semântica — que o caso precisa soltar.
Future<SemanticsHandle> _montar(WidgetTester tester, {double escala = 1}) async {
  _telefone(tester);
  final punho = tester.ensureSemantics();
  await tester.pumpWidget(_tela(escala: escala));
  await tester.pump(const Duration(milliseconds: 300));
  return punho;
}

/// Monta medindo o layout: devolve (erros do framework, parágrafos cortados).
Future<(List<String>, List<String>)> _medir(
  WidgetTester tester,
  double escala,
) async {
  final erros = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalhe) => erros.add(detalhe.exceptionAsString());
  try {
    _telefone(tester);
    await tester.pumpWidget(_tela(escala: escala));
    await tester.pump(const Duration(milliseconds: 300));
    return (erros, _cortados(tester));
  } finally {
    FlutterError.onError = anterior;
  }
}

/// A fonte da tela sem comentários — este arquivo explica em prosa o que é
/// proibido, e uma varredura ingênua acusaria a própria explicação.
String _fonteDaTela() {
  final f = File('lib/screens/como_jogar_screen.dart');
  final bruto = f.readAsStringSync();
  return bruto
      .split('\n')
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');
}

// ===========================================================================
// Casos
// ===========================================================================

void main() {
  group('estrutura — cabeçalhos', () {
    testWidgets('o título da tela é o cabeçalho de nível mais alto',
        (tester) async {
      final punho = await _montar(tester);
      final arvore = _arvore(tester);

      final primeiro = arvore.firstWhere((n) => n.cabecalho);
      expect(primeiro.rotulo, 'Como jogar');
      // E é o primeiro cabeçalho da tela, não o segundo: nada estruturado o
      // precede.
      expect(
        arvore.indexOf(primeiro),
        lessThan(arvore.indexWhere((n) => n.rotulo == 'O objetivo')),
      );
      punho.dispose();
    });

    testWidgets('as seis seções reais são cabeçalhos, e só elas',
        (tester) async {
      final punho = await _montar(tester);
      expect(
        _arvore(tester).where((n) => n.cabecalho).map((n) => n.rotulo).toList(),
        cabecalhos,
        reason: 'a navegação por cabeçalhos mudou de forma',
      );
      punho.dispose();
    });

    testWidgets('a navegação por cabeçalhos percorre a tela de cima a baixo',
        (tester) async {
      final punho = await _montar(tester);
      final arvore = _arvore(tester);

      // Os cabeçalhos aparecem na árvore em posições estritamente crescentes, e
      // na mesma ordem em que estão desenhados na tela.
      final posicoes = cabecalhos
          .map((t) => arvore.indexWhere((n) => n.cabecalho && n.rotulo == t))
          .toList();
      expect(posicoes, everyElement(isNonNegative));
      for (var i = 1; i < posicoes.length; i++) {
        expect(
          posicoes[i],
          greaterThan(posicoes[i - 1]),
          reason: '"${cabecalhos[i]}" foi anunciado antes de '
              '"${cabecalhos[i - 1]}"',
        );
      }
      punho.dispose();
    });
  });

  group('estrutura — leitura', () {
    testWidgets('a ordem de leitura acompanha o conteúdo, inteira',
        (tester) async {
      final punho = await _montar(tester);
      expect(_arvore(tester).map((n) => n.rotulo).toList(), ordemDeLeitura);
      punho.dispose();
    });

    testWidgets('cada instrução é UMA unidade, e não fragmentos soltos',
        (tester) async {
      final punho = await _montar(tester);
      final rotulos = _arvore(tester).map((n) => n.rotulo).toList();

      // Os três passos: número, ícone e rótulo chegam juntos.
      for (final passo in [
        'Passo 1 de 3: Comprar',
        'Passo 2 de 3: Baixar jogos',
        'Passo 3 de 3: Descartar',
      ]) {
        expect(rotulos, contains(passo));
      }
      // As duas canastras: nome, composição e valor numa frase só.
      expect(rotulos, contains('Canastra limpa: 7 cartas, sem curinga. Mais 200 pontos.'));
      expect(rotulos, contains('Canastra suja: 7 cartas, com curinga. Mais 100 pontos.'));
      // As modalidades e as linhas de pontuação: rótulo e valor colados.
      expect(rotulos, contains('Aberto: lixo espalhado'));
      expect(rotulos, contains('Curinga: 20 pontos. Ás: 15 pontos'));

      // E os fragmentos que existiam antes não voltaram como nó próprio.
      for (final caco in [
        '1', '2', '3', 'Comprar', 'Baixar jogos', 'Descartar',
        'LIMPA', 'SUJA', '+200', '+100', '7 cartas, sem curinga',
        'Aberto', 'lixo espalhado', '20 / 15', '− pontos',
        'Canastra limpa', '200',
      ]) {
        expect(
          rotulos,
          isNot(contains(caco)),
          reason: '"$caco" voltou a ser anunciado sozinho',
        );
      }
      punho.dispose();
    });

    testWidgets('nada é anunciado duas vezes', (tester) async {
      final punho = await _montar(tester);
      final rotulos = _arvore(tester).map((n) => n.rotulo).toList();
      expect(
        rotulos.length,
        rotulos.toSet().length,
        reason: 'há rótulo repetido na árvore: '
            '${rotulos.where((r) => rotulos.where((o) => o == r).length > 1).toSet()}',
      );
      punho.dispose();
    });
  });

  group('decoração', () {
    testWidgets('nenhum ornamento é falado', (tester) async {
      final punho = await _montar(tester);
      final rotulos = _arvore(tester).map((n) => n.rotulo).toList();

      for (final rotulo in rotulos) {
        for (final glifo in decoracao) {
          expect(
            rotulo.contains(glifo),
            isFalse,
            reason: 'o ornamento "$glifo" entrou no rótulo "$rotulo"',
          );
        }
        expect(
          _pictograma.hasMatch(rotulo),
          isFalse,
          reason: 'há pictograma anunciado em "$rotulo"',
        );
      }
      punho.dispose();
    });

    testWidgets('mas continua desenhado na tela', (tester) async {
      await _montar(tester).then((p) => p.dispose());
      final desenhado = _paragrafos(tester).join('\n');
      for (final glifo in decoracao) {
        expect(
          desenhado,
          contains(glifo),
          reason: 'o ornamento "$glifo" sumiu do desenho — excluir da árvore '
              'semântica não é apagar da tela',
        );
      }
    });

    testWidgets('imagem com significado tem descrição, e nenhuma tem nome de '
        'arquivo', (tester) async {
      final punho = await _montar(tester);

      // A tela de hoje é toda texto: não há `Image` nenhuma. O caso não é
      // decorativo — ele vale para a próxima imagem que alguém acrescentar.
      for (final imagem in tester.widgetList<Image>(find.byType(Image))) {
        expect(
          imagem.semanticLabel,
          isNotNull,
          reason: 'imagem sem descrição: ${imagem.image}',
        );
        expect(imagem.semanticLabel, isNot(contains('.')));
        expect(imagem.semanticLabel, isNot(contains('assets/')));
      }
      // E nenhum rótulo anuncia caminho de asset ou nome de arquivo.
      for (final no in _arvore(tester)) {
        expect(no.rotulo, isNot(contains('assets/')));
        expect(no.rotulo, isNot(matches(RegExp(r'\.(png|webp|jpg|svg|riv)\b'))));
      }
      punho.dispose();
    });
  });

  group('navegação', () {
    testWidgets('o Voltar é botão, tem nome, e volta de verdade',
        (tester) async {
      _telefone(tester);
      final punho = tester.ensureSemantics();

      final navegador = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navegador,
        home: const Scaffold(body: Center(child: Text('tela anterior'))),
      ));
      navegador.currentState!.push(MaterialPageRoute<void>(
        builder: (rota) => ComoJogarScreen(
          onVoltar: () => Navigator.of(rota).maybePop(),
          onJogarTreino: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Como jogar'), findsOneWidget);

      final voltar =
          _arvore(tester).firstWhere((n) => n.rotulo == 'Voltar');
      expect(voltar.botao, isTrue, reason: 'o Voltar não se anuncia como botão');
      expect(voltar.toque, isTrue, reason: 'o Voltar perdeu a ação de toque');

      await tester.tap(find.bySemanticsLabel('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('tela anterior'), findsOneWidget);
      expect(find.text('Como jogar'), findsNothing);
      punho.dispose();
    });

    testWidgets('o botão de treino é botão, e não empurra rota sozinho',
        (tester) async {
      var treinos = 0;
      _telefone(tester);
      final punho = tester.ensureSemantics();
      final navegador = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navegador,
        home: ComoJogarScreen(
          onVoltar: () {},
          onJogarTreino: () => treinos++,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final treino = _arvore(tester)
          .firstWhere((n) => n.rotulo == 'Jogar treino contra robôs');
      expect(treino.botao, isTrue);
      expect(treino.toque, isTrue);

      // Ele mora no fim da página: sem rolar até lá, o toque cai no vazio — e
      // um toque que não acerta nada passaria como "não navegou".
      await tester.scrollUntilVisible(
        find.text('🤖 Jogar treino contra robôs'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Jogar treino contra robôs'));
      await tester.pumpAndSettle();

      // A tela avisa quem a montou; quem decide a rota é o chamador. É esse
      // contrato que mantém Home e Ajustes abrindo Como Jogar de jeitos
      // diferentes sem que a tela saiba de nenhum dos dois.
      expect(treinos, 1);
      expect(navegador.currentState!.canPop(), isFalse);
      punho.dispose();
    });

    testWidgets('os dois controles moram DENTRO da área rolável',
        (tester) async {
      final punho = await _montar(tester);
      for (final rotulo in ['Voltar', 'Jogar treino contra robôs']) {
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.bySemanticsLabel(rotulo),
          ),
          findsOneWidget,
          reason: '"$rotulo" ficou fora da rolagem',
        );
      }
      punho.dispose();
    });
  });

  group('rolagem', () {
    testWidgets('a rolagem alcança o fim do conteúdo', (tester) async {
      final punho = await _montar(tester);
      final posicao = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(posicao.maxScrollExtent, greaterThan(0));

      await tester.scrollUntilVisible(
        find.text('🤖 Jogar treino contra robôs'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('🤖 Jogar treino contra robôs'), findsOneWidget);
      expect(posicao.pixels, greaterThan(0));
      punho.dispose();
    });

    testWidgets('a posição de leitura sobrevive a uma reconstrução',
        (tester) async {
      _telefone(tester);
      await tester.pumpWidget(_tela());
      await tester.pump(const Duration(milliseconds: 300));
      final posicao =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;

      posicao.jumpTo(300);
      await tester.pump();
      expect(posicao.pixels, 300);

      await tester.pumpWidget(_tela());
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels,
        300,
        reason: 'a tela voltou ao topo e perdeu o ponto de leitura',
      );
    });
  });

  group('escala de fonte', () {
    for (final escala in [1.0, 1.25, 1.5, 1.75, 2.0]) {
      final porcento = (escala * 100).round();
      testWidgets('$porcento% — sem estouro e sem corte', (tester) async {
        final (erros, cortados) = await _medir(tester, escala);
        expect(
          erros,
          isEmpty,
          reason: 'a tela estourou o layout em $porcento%: '
              '${erros.map((e) => e.split('\n').first).toList()}',
        );
        expect(
          cortados,
          isEmpty,
          reason: 'texto cortado em $porcento%: $cortados',
        );
      });
    }

    testWidgets('em 200% o conteúdo continua todo lá, e todo alcançável',
        (tester) async {
      final punho = await _montar(tester, escala: 2);

      // Nada de "some para caber": a árvore é a mesma, palavra por palavra.
      expect(_arvore(tester).map((n) => n.rotulo).toList(), ordemDeLeitura);

      // E o fim do conteúdo continua a uma rolagem de distância.
      await tester.scrollUntilVisible(
        find.text('🤖 Jogar treino contra robôs'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('🤖 Jogar treino contra robôs'), findsOneWidget);
      punho.dispose();
    });

    testWidgets('as fileiras de colunas viram lista quando a fonte cresce',
        (tester) async {
      // Este é o mecanismo que faz 150% e 200% caberem: três passos lado a
      // lado numa tela de telefone dão ~93px de coluna, e nessa largura
      // "Descartar" em corpo dobrado não cabe em linha nenhuma — o Flutter não
      // parte a palavra, e ela vaza por cima do cartão vizinho SEM levantar
      // erro. Por isso a checagem é do arranjo, e não da mensagem de estouro.
      const fileiras = [
        'Passo 1 de 3: Comprar',
        'Passo 2 de 3: Baixar jogos',
        'Passo 3 de 3: Descartar',
        'Canastra limpa: 7 cartas, sem curinga. Mais 200 pontos.',
        'Canastra suja: 7 cartas, com curinga. Mais 100 pontos.',
        'Aberto: lixo espalhado',
        'Fechado: aceita trinca',
        'SBTL: tradicional',
      ];

      final punho = await _montar(tester);
      var arvore = _arvore(tester);
      for (final rotulo in fileiras) {
        expect(
          arvore.firstWhere((n) => n.rotulo == rotulo).largura,
          lessThan(200),
          reason: 'em 100% "$rotulo" deveria dividir a linha com os irmãos',
        );
      }
      punho.dispose();

      for (final escala in [1.5, 2.0]) {
        final p = await _montar(tester, escala: escala);
        arvore = _arvore(tester);
        for (final rotulo in fileiras) {
          expect(
            arvore.firstWhere((n) => n.rotulo == rotulo).largura,
            greaterThan(300),
            reason: 'em ${(escala * 100).round()}% "$rotulo" continuou '
                'espremido numa coluna estreita',
          );
        }
        p.dispose();
      }
    });

    testWidgets('a tela não trava a escala nem encolhe o texto', (tester) async {
      final fonte = _fonteDaTela();
      for (final trava in [
        'textScaleFactor',
        'TextScaler.noScaling',
        'noScaling',
        'textScaler: TextScaler.linear',
      ]) {
        expect(
          fonte,
          isNot(contains(trava)),
          reason: 'a tela passou a impor a própria escala de fonte ($trava)',
        );
      }

      // E o efeito prático: ampliar a fonte faz o conteúdo crescer.
      _telefone(tester);
      final alturas = <double>[];
      for (final escala in [1.0, 1.5, 2.0]) {
        await tester.pumpWidget(_tela(escala: escala));
        await tester.pump(const Duration(milliseconds: 300));
        final p = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        alturas.add(p.maxScrollExtent + p.viewportDimension);
      }
      expect(alturas[1], greaterThan(alturas[0]));
      expect(alturas[2], greaterThan(alturas[1]));
    });
  });

  group('conteúdo', () {
    testWidgets('nenhuma regra do jogo mudou', (tester) async {
      _telefone(tester);
      await tester.pumpWidget(_tela());
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        _paragrafos(tester),
        textosVisiveis,
        reason: 'o texto desenhado na tela mudou — esta OS não autoriza tocar '
            'em regra, pontuação, canastra, batida ou modalidade',
      );
    });

    testWidgets('o que é falado a mais transcreve o que está escrito',
        (tester) async {
      final punho = await _montar(tester);
      final rotulos = _arvore(tester).map((n) => n.rotulo).toList();

      // Os números da tabela de pontos aparecem falados, e são os mesmos.
      expect(rotulos, contains('Canastra limpa: 200 pontos'));
      expect(rotulos, contains('Canastra suja: 100 pontos'));
      expect(rotulos, contains('Bater: 100 pontos'));
      // O par 'Curinga / Ás' → '20 / 15' desmontado no par que ele já é.
      expect(rotulos, contains('Curinga: 20 pontos. Ás: 15 pontos'));
      // E os valores das canastras batem com o que está desenhado.
      expect(
        rotulos.firstWhere((r) => r.startsWith('Canastra limpa: 7')),
        contains('200'),
      );
      expect(
        rotulos.firstWhere((r) => r.startsWith('Canastra suja: 7')),
        contains('100'),
      );
      punho.dispose();
    });
  });
}
