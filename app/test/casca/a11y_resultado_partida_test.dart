// a11y_resultado_partida_test.dart — a tela de fim de partida tem de ser
// legível e tocável com a fonte do sistema em 200%.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE PROVA, E POR QUE ASSIM
// ---------------------------------------------------------------------------
//
// O relatório de acessibilidade mediu, nesta tela, um botão produtivo de 27 pt
// de altura e texto produtivo entre 6,6 e 9 pt. Os dois números são medidas,
// não impressões: 27 vinha de um `SizedBox(height: 27)` em volta do botão de
// amizade, e 6,6 era o `fontSize` do rótulo dentro dele.
//
// Por isso a prova principal aqui é MEDIÇÃO DA ÁRVORE RENDERIZADA, e não busca
// textual no código: a suíte monta a tela, pergunta ao `RenderBox` de cada
// controle qual é a altura dele e pergunta a cada `RenderParagraph` qual fonte
// ele está usando. Um `grep` por "27" continuaria verde se o encolhimento
// voltasse por outro caminho — um tema com `shrinkWrap`, um `FittedBox`, um
// `Transform.scale`. A medida não continua.
//
// Dois cuidados que valem registro:
//
//   1. ALTURA MEDIDA DUAS VEZES. Um botão do Material tem duas alturas: a do
//      alvo de toque (que o `MaterialTapTargetSize.padded` infla) e a da
//      superfície pintada. Aumentar só a primeira deixa o botão parecendo o
//      mesmo carimbo minúsculo; aumentar só a segunda não amplia o alvo. A
//      suíte exige 48 nas DUAS, para que a correção não passe por metade.
//
//   2. ESCALA NÃO PODE SER FINGIDA. Uma tela que trava `textScaler` passa em
//      qualquer teste de overflow — ela simplesmente ignora o pedido do
//      usuário. Aqui a prova é ao contrário: o parágrafo tem de FICAR MAIOR
//      quando a escala sobe. Se alguém travar a escala para calar um estouro,
//      este arquivo reprova.
//
// A tela é `StatelessWidget` de entradas puras: placar, detalhe, jogadores e
// callbacks chegam prontos de `mesa.dart`. Nada aqui recalcula regra — os
// casos de vitória, derrota e empate são montados com os mesmos valores que a
// mesa entregaria, e a suíte confere que a tela os mostra sem alterar nenhum.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/screens/resultado_partida_screen.dart';

// ===========================================================================
// RÉGUA
// ===========================================================================

/// Piso do alvo tocável — o mesmo `kMinInteractiveDimension` do Material e o
/// mínimo do WCAG 2.5.5.
const double kAlvoMinimo = 48.0;

/// Piso tipográfico desta tela. O relatório reprovou de 6,6 a 9; a Casca não
/// desce de 10,5. 11 é o chão adotado, e nenhum texto produtivo pode furá-lo.
const double kFonteMinima = 11.0;

/// Superfície de telefone usada no resto da suíte da Casca: 360 x 780 lógicos.
/// É a MENOR largura produtiva — todo estouro horizontal aparece aqui antes de
/// aparecer em qualquer aparelho maior.
const Size kTelefoneFisico = Size(1080, 2340);
const double kDpr = 3;

// ===========================================================================
// BANCADA
// ===========================================================================

/// Registra o que a tela chamou. Nenhum callback faz nada além de anotar —
/// a tela não pode depender do efeito para se comportar.
class _Bancada {
  int continuar = 0;
  int convidarRevanche = 0;
  int jogarNovamente = 0;
  int voltarLobby = 0;
  int verAnuncio = 0;
  final List<int> amigosAdicionados = <int>[];

  List<String> get chamadas => <String>[
        if (continuar > 0) 'continuar:$continuar',
        if (convidarRevanche > 0) 'convidarRevanche:$convidarRevanche',
        if (jogarNovamente > 0) 'jogarNovamente:$jogarNovamente',
        if (voltarLobby > 0) 'voltarLobby:$voltarLobby',
        if (verAnuncio > 0) 'verAnuncio:$verAnuncio',
        if (amigosAdicionados.isNotEmpty)
          'adicionarAmigo:${amigosAdicionados.join(",")}',
      ];
}

const _detalheNos = DetalhePontuacaoVM(
  total: 1235,
  canastras: 400,
  cartasBaixadas: 285,
  bonusBatida: 100,
  descontoMao: -30,
  penalidadeMorto: -100,
  limpas: 2,
  sujas: 1,
  de500: 1,
  de1000: 1,
);

const _detalheEles = DetalhePontuacaoVM(
  total: -85,
  canastras: 200,
  cartasBaixadas: 115,
  bonusBatida: 0,
  descontoMao: -300,
  penalidadeMorto: -100,
  limpas: 0,
  sujas: 1,
  de500: 0,
  de1000: 0,
);

const _jogadores = <JogadorResultadoVM>[
  JogadorResultadoVM(assento: 0, nome: 'Você', avatar: '🙂', souEu: true),
  JogadorResultadoVM(assento: 1, nome: 'Marcinha', avatar: '🐱'),
  JogadorResultadoVM(assento: 2, nome: 'Parceiro', avatar: '🦊'),
  JogadorResultadoVM(assento: 3, nome: 'Zé do Baralho', avatar: '🐼'),
];

Widget _tela(
  _Bancada b, {
  bool fimPartida = true,
  bool mesaVip = false,
  int rodada = 3,
  String titulo = 'NÓS VENCEMOS!',
  int pontosNos = 3020,
  int pontosEles = 1785,
  Map<int, EstadoAmizade> amizades = const {
    1: EstadoAmizade.disponivel,
    2: EstadoAmizade.enviado,
    3: EstadoAmizade.amigos,
  },
  bool conviteRevancheEnviado = false,
  bool anuncioDisponivel = true,
  bool anuncioAssistido = false,
  bool assinanteSemAnuncios = false,
}) {
  return ResultadoPartidaScreen(
    fimPartida: fimPartida,
    mesaVip: mesaVip,
    rodada: rodada,
    titulo: titulo,
    pontosNos: pontosNos,
    pontosEles: pontosEles,
    detalheNos: _detalheNos,
    detalheEles: _detalheEles,
    jogadores: _jogadores,
    amizades: amizades,
    conviteRevancheEnviado: conviteRevancheEnviado,
    anuncioDisponivel: anuncioDisponivel,
    anuncioAssistido: anuncioAssistido,
    assinanteSemAnuncios: assinanteSemAnuncios,
    recompensaAnuncio: '+50 fichas de continuidade',
    onContinuar: () => b.continuar++,
    onConvidarRevanche: () => b.convidarRevanche++,
    onJogarNovamente: () => b.jogarNovamente++,
    onVoltarLobby: () => b.voltarLobby++,
    onAdicionarAmigo: b.amigosAdicionados.add,
    onVerAnuncio: () => b.verAnuncio++,
  );
}

/// Estouros de layout capturados durante a montagem. `RenderFlex overflowed`
/// não derruba o teste sozinho no `flutter_test` — vira erro reportado — então
/// a suíte intercepta e afirma sobre a lista.
List<String> _estouros = <String>[];

/// Monta a tela numa superfície de telefone, na escala pedida.
///
/// `escala` é a escala de fonte do SISTEMA. Ela entra por `MediaQuery`, que é
/// exatamente por onde o Android e o iOS a entregam — se a tela a ignorasse,
/// os casos de tipografia abaixo denunciariam.
Future<void> _montar(
  WidgetTester tester,
  _Bancada b, {
  double escala = 1.0,
  Size fisico = kTelefoneFisico,
  ThemeData? tema,
  bool fimPartida = true,
  bool mesaVip = false,
  String titulo = 'NÓS VENCEMOS!',
  int pontosNos = 3020,
  int pontosEles = 1785,
  bool conviteRevancheEnviado = false,
  bool anuncioAssistido = false,
  bool anuncioDisponivel = true,
  bool assinanteSemAnuncios = false,
  Map<int, EstadoAmizade> amizades = const {
    1: EstadoAmizade.disponivel,
    2: EstadoAmizade.enviado,
    3: EstadoAmizade.amigos,
  },
}) async {
  _estouros = <String>[];
  final anterior = FlutterError.onError;
  FlutterError.onError = (detalhes) {
    final texto = detalhes.exception.toString();
    if (texto.contains('overflowed')) {
      _estouros.add(texto.split('\n').first);
    } else {
      anterior?.call(detalhes);
    }
  };
  addTearDown(() => FlutterError.onError = anterior);

  tester.view.physicalSize = fisico;
  tester.view.devicePixelRatio = kDpr;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(escala)),
        child: _tela(
          b,
          fimPartida: fimPartida,
          mesaVip: mesaVip,
          titulo: titulo,
          pontosNos: pontosNos,
          pontosEles: pontosEles,
          amizades: amizades,
          conviteRevancheEnviado: conviteRevancheEnviado,
          anuncioDisponivel: anuncioDisponivel,
          anuncioAssistido: anuncioAssistido,
          assinanteSemAnuncios: assinanteSemAnuncios,
        ),
      ),
    ),
  );
  await tester.pump();
}

// ===========================================================================
// MEDIDAS
// ===========================================================================

const List<Type> _tiposDeBotao = <Type>[
  ElevatedButton,
  OutlinedButton,
  TextButton,
];

/// Uma medida por controle produtivo da tela.
class _Controle {
  _Controle(this.tipo, this.rotulo, this.alvo, this.pintado);

  final Type tipo;
  final String rotulo;

  /// Altura do alvo de toque — a caixa mais externa do botão, já com o
  /// preenchimento que o `MaterialTapTargetSize` acrescenta.
  final double alvo;

  /// Altura da superfície pintada — o `Material` que recebe cor, borda e
  /// tinta do toque. É o que o olho enxerga como "o botão".
  final double pintado;

  @override
  String toString() => '$tipo("$rotulo") alvo=$alvo pintado=$pintado';
}

List<_Controle> _controles(WidgetTester tester) {
  final medidas = <_Controle>[];
  for (final tipo in _tiposDeBotao) {
    final f = find.byType(tipo);
    for (var i = 0; i < f.evaluate().length; i++) {
      final elemento = f.at(i);
      final caixa = tester.renderObject<RenderBox>(elemento);
      final material =
          find.descendant(of: elemento, matching: find.byType(Material));
      final pintado = material.evaluate().isEmpty
          ? caixa.size
          : (material.evaluate().first.renderObject! as RenderBox).size;
      final rotulo = find
          .descendant(of: elemento, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .join('/');
      medidas.add(_Controle(tipo, rotulo, caixa.size.height, pintado.height));
    }
  }
  return medidas;
}

/// Fonte EFETIVAMENTE usada por cada parágrafo, lida do `RenderParagraph` —
/// não do `TextStyle` que o código escreveu. Um `DefaultTextStyle`, um tema ou
/// um `FittedBox` no meio do caminho apareceriam aqui.
Map<String, double> _fontes(WidgetTester tester) {
  final porTexto = <String, double>{};
  for (final elemento in find.byType(Text).evaluate()) {
    final render = elemento.renderObject;
    if (render is! RenderParagraph) continue;
    final texto = render.text.toPlainText();
    final tamanho = render.text.style?.fontSize;
    if (tamanho == null) continue;
    porTexto[texto] = tamanho;
  }
  return porTexto;
}

/// Altura pintada de um parágrafo específico. Serve para provar que o texto
/// CRESCE com a escala do sistema — a prova de que a escala não está travada.
double _alturaDoParagrafo(WidgetTester tester, String texto) {
  final render = tester.renderObject<RenderParagraph>(
    find.byWidgetPredicate(
      (w) => w is Text && w.data == texto,
      description: 'Text("$texto")',
    ),
  );
  return render.size.height;
}

/// Texto visível dentro de um botão, usado como identidade dele nos casos de
/// foco. O rótulo do botão de amizade fica sob `ExcludeSemantics` — invisível
/// ao leitor de tela, mas presente na árvore de widgets, que é o que se lê
/// aqui.
String _rotuloDoBotao(Element botao) => find
    .descendant(of: find.byWidget(botao.widget), matching: find.byType(Text))
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .join('/');

/// Qual botão está com o foco primário, subindo do nó focado até o primeiro
/// ancestral que seja um botão do Material.
String? _rotuloDoFocado(WidgetTester tester) {
  final contexto = primaryFocus?.context;
  if (contexto == null) return null;
  String? achado;
  contexto.visitAncestorElements((elemento) {
    if (elemento.widget is ButtonStyleButton) {
      achado = _rotuloDoBotao(elemento);
      return false;
    }
    return true;
  });
  return achado;
}

/// Rótulos que os leitores de tela anunciam, na ordem em que a árvore de
/// semântica os apresenta.
List<String> _rotulosSemanticos(WidgetTester tester) {
  final rotulos = <String>[];
  void percorrer(SemanticsNode no) {
    final r = no.label.trim();
    if (r.isNotEmpty) rotulos.add(r);
    no.visitChildren((filho) {
      percorrer(filho);
      return true;
    });
  }

  percorrer(tester.getSemantics(find.byType(MaterialApp)));
  return rotulos;
}

/// Rola o controle até a vista e toca nele.
///
/// A tela é um painel rolante — já era antes da correção, e com a tipografia
/// legível passou a rolar mais. Tocar sem rolar acertaria o vazio e o caso
/// passaria a medir a rolagem, não o callback.
Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  final rolagem = find.byType(Scrollable);
  if (rolagem.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(alvo, 120, scrollable: rolagem.first);
  }
  await tester.tap(alvo);
  await tester.pump();
}

/// Textos visíveis na tela, na ordem da árvore.
List<String> _textos(WidgetTester tester) => find
    .byType(Text)
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .toList();

// ===========================================================================

void main() {
  // =========================================================================
  // 1. ALVOS TOCÁVEIS — §5.1
  // =========================================================================
  //
  // O relatório mediu 27 pt no botão de amizade. Estes casos medem TODOS os
  // controles produtivos, nos dois estados da tela e nas três escalas, e
  // cobram 48 no alvo e na superfície pintada.
  group('todo controle produtivo tem 48 pt de altura', () {
    for (final escala in <double>[1.0, 1.5, 2.0]) {
      final pct = (escala * 100).round();

      testWidgets('fim de partida, fonte em $pct%', (tester) async {
        final b = _Bancada();
        await _montar(tester, b, escala: escala);

        final medidas = _controles(tester);
        // Se a varredura não achasse controle nenhum, o caso passaria vazio.
        expect(
          medidas.length,
          greaterThanOrEqualTo(7),
          reason: 'a tela de fim de partida tem 1 botão principal, 1 de lobby, '
              '3 de amizade e 2 ações de texto — vieram ${medidas.length}',
        );

        for (final m in medidas) {
          expect(
            m.alvo,
            greaterThanOrEqualTo(kAlvoMinimo),
            reason: 'alvo de toque abaixo de $kAlvoMinimo pt em $m',
          );
          expect(
            m.pintado,
            greaterThanOrEqualTo(kAlvoMinimo),
            reason: 'superfície pintada abaixo de $kAlvoMinimo pt em $m — '
                'inflar só o alvo deixa o botão do mesmo tamanho aos olhos',
          );
        }
      });

      testWidgets('fim de rodada, fonte em $pct%', (tester) async {
        final b = _Bancada();
        await _montar(tester, b, escala: escala, fimPartida: false);

        final medidas = _controles(tester);
        expect(medidas, hasLength(1), reason: 'só a ação de próxima rodada');
        expect(medidas.single.alvo, greaterThanOrEqualTo(kAlvoMinimo));
        expect(medidas.single.pintado, greaterThanOrEqualTo(kAlvoMinimo));
      });
    }

    testWidgets('o botão de amizade — o de 27 pt do relatório', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      final amizade = _controles(tester)
          .where((m) => m.tipo == OutlinedButton && m.rotulo.contains('AMIGO'))
          .toList();
      expect(amizade, isNotEmpty, reason: 'o botão de amizade sumiu da tela');
      for (final m in amizade) {
        expect(
          m.alvo,
          greaterThanOrEqualTo(kAlvoMinimo),
          reason: 'é exatamente este controle que o relatório mediu em 27 pt',
        );
      }
    });

    testWidgets('nenhuma área de toque se sobrepõe a outra', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      final caixas = <Rect>[];
      for (final tipo in _tiposDeBotao) {
        for (final elemento in find.byType(tipo).evaluate()) {
          final caixa = elemento.renderObject! as RenderBox;
          final topo = caixa.localToGlobal(Offset.zero);
          caixas.add(topo & caixa.size);
        }
      }
      for (var i = 0; i < caixas.length; i++) {
        for (var j = i + 1; j < caixas.length; j++) {
          final corte = caixas[i].intersect(caixas[j]);
          expect(
            corte.isEmpty || corte.width <= 0 || corte.height <= 0,
            isTrue,
            reason: 'alvos de toque sobrepostos: ${caixas[i]} e ${caixas[j]}',
          );
        }
      }
    });

    // PROVA NEGATIVA DO PISO.
    //
    // O 48 de um botão do Material vem de graça quando o tema usa
    // `MaterialTapTargetSize.padded`. Se a correção tivesse se apoiado nisso,
    // um tema com `shrinkWrap` — que existe, e é o padrão em telas densas —
    // devolveria o botão de 27 pt sem que ninguém percebesse. Aqui a tela é
    // montada justamente com esse tema hostil: o piso tem de ser da TELA.
    testWidgets('o piso não depende do tema: com shrinkWrap segue 48',
        (tester) async {
      final b = _Bancada();
      await _montar(
        tester,
        b,
        tema: ThemeData(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      );

      for (final m in _controles(tester)) {
        expect(
          m.alvo,
          greaterThanOrEqualTo(kAlvoMinimo),
          reason: 'com o tema em shrinkWrap o controle encolheu: $m — o piso '
              'de 48 tem de estar declarado na tela, não herdado do tema',
        );
      }
    });
  });

  // =========================================================================
  // 2. NOMES SEMÂNTICOS — §5.1
  // =========================================================================
  group('cada controle tem nome e papel', () {
    testWidgets('todo botão é anunciado como botão e com nome', (tester) async {
      final b = _Bancada();
      final semantica = tester.ensureSemantics();
      await _montar(tester, b);

      for (final tipo in _tiposDeBotao) {
        final f = find.byType(tipo);
        for (var i = 0; i < f.evaluate().length; i++) {
          final no = tester.getSemantics(f.at(i));
          expect(
            no.label.trim(),
            isNotEmpty,
            reason: '$tipo[$i] chegaria mudo ao leitor de tela',
          );
          expect(
            no,
            isSemantics(isButton: true),
            reason: '$tipo[$i] não se apresenta como botão',
          );
        }
      }
      semantica.dispose();
    });

    testWidgets('os três botões de amizade dizem de QUEM são', (tester) async {
      final b = _Bancada();
      final semantica = tester.ensureSemantics();
      await _montar(tester, b);

      // Visualmente os três cartões trazem "+ AMIGO", "ENVIADO" e "AMIGOS".
      // Sem o nome do jogador, quem usa leitor de tela ouve três botões
      // indistinguíveis e não sabe qual é de quem.
      final cartoes = find.byType(OutlinedButton);
      final deAmizade = <String>[];
      for (var i = 0; i < cartoes.evaluate().length; i++) {
        final rotulo = tester.getSemantics(cartoes.at(i)).label.trim();
        if (rotulo.contains('VOLTAR AO LOBBY')) continue;
        deAmizade.add(rotulo);
      }

      expect(
        deAmizade,
        hasLength(3),
        reason: 'a mesa tem quatro jogadores e um sou eu: são três cartões — '
            'se aparecesse um quarto, eu estaria me convidando',
      );
      expect(
        deAmizade.where((r) => r.contains('Marcinha')),
        hasLength(1),
        reason: 'o botão do assento 1 não nomeia Marcinha: $deAmizade',
      );
      expect(
        deAmizade.where((r) => r.contains('Parceiro')),
        hasLength(1),
        reason: 'o botão do assento 2 não nomeia Parceiro: $deAmizade',
      );
      expect(
        deAmizade.where((r) => r.contains('Zé do Baralho')),
        hasLength(1),
        reason: 'o botão do assento 3 não nomeia Zé do Baralho: $deAmizade',
      );
      expect(
        deAmizade.toSet(),
        hasLength(3),
        reason: 'dois botões com o mesmo nome — é o defeito que a correção '
            'fecha: três "+ AMIGO" indistinguíveis ao leitor de tela',
      );
      semantica.dispose();
    });

    testWidgets('o estado habilitado chega ao leitor de tela', (tester) async {
      final b = _Bancada();
      final semantica = tester.ensureSemantics();
      await _montar(tester, b);

      // Assento 1 disponível: o botão convida, e se anuncia como acionável.
      final disponivel = tester.getSemantics(
        find.widgetWithText(OutlinedButton, '+ AMIGO'),
      );
      expect(
        disponivel,
        isSemantics(isEnabled: true, hasTapAction: true),
        reason: 'o botão de convite disponível não se apresenta acionável',
      );

      // Assentos 2 e 3: convite já enviado e amizade já feita. Os dois
      // continuam sendo lidos — some o toque, não a informação.
      for (final rotulo in <String>['ENVIADO', 'AMIGOS']) {
        final no = tester.getSemantics(
          find.widgetWithText(OutlinedButton, rotulo),
        );
        expect(
          no,
          isSemantics(isEnabled: false),
          reason: '"$rotulo" deveria estar desabilitado e não está',
        );
        expect(
          no.label.trim(),
          isNotEmpty,
          reason: 'um controle desabilitado ainda precisa ser lido',
        );
      }
      semantica.dispose();
    });

    testWidgets('o foco percorre os controles na ordem visual', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      // A ordem é lida pela ÁRVORE, e não por coordenada de tela: focar um
      // controle abaixo da dobra rola o painel, e a coordenada de todo mundo
      // muda junto. A árvore é uma coluna, então a ordem dela É a ordem
      // visual, e ela não se mexe quando a tela rola.
      //
      // A varredura tem de ser por PREDICADO, e não por tipo: `find.byType`
      // casa o tipo exato, então percorrer [_tiposDeBotao] traria todos os
      // elevados, depois todos os contornados, depois os de texto — a ordem
      // dos TIPOS, não a da tela.
      final naArvore = <String>[];
      for (final elemento
          in find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate()) {
        final habilitado =
            (elemento.widget as ButtonStyleButton).onPressed != null;
        if (habilitado) naArvore.add(_rotuloDoBotao(elemento));
      }

      final percurso = <String>[];
      for (var i = 0; i < 12; i++) {
        if (!(primaryFocus?.nextFocus() ?? false)) break;
        await tester.pump();
        final rotulo = _rotuloDoFocado(tester);
        if (rotulo == null) continue;
        if (percurso.contains(rotulo)) break; // deu a volta
        percurso.add(rotulo);
      }

      expect(
        percurso.length,
        greaterThanOrEqualTo(3),
        reason: 'a travessia de foco não andou pelos controles: $percurso',
      );
      // Todo controle habilitado tem de ser alcançável só com o teclado.
      expect(
        percurso.toSet(),
        equals(naArvore.toSet()),
        reason: 'a travessia de foco não cobre os controles habilitados.\n'
            'árvore: $naArvore\nfoco:   $percurso',
      );
      // E na mesma ordem em que a coluna os apresenta.
      expect(
        percurso,
        equals(naArvore.where(percurso.contains).toList()),
        reason: 'o foco pula de um lugar para outro fora da ordem visual.\n'
            'árvore: $naArvore\nfoco:   $percurso',
      );
    });

    testWidgets('a ordem de leitura segue a ordem visual', (tester) async {
      final b = _Bancada();
      final semantica = tester.ensureSemantics();
      await _montar(tester, b);

      final rotulos = _rotulosSemanticos(tester);
      int onde(String agulha) =>
          rotulos.indexWhere((r) => r.contains(agulha));

      final tituloEm = onde('NÓS VENCEMOS!');
      final placarEm = onde('3020');
      final acaoEm = onde('VAMOS JOGAR?');
      final lobbyEm = onde('VOLTAR AO LOBBY');

      expect(tituloEm, isNonNegative, reason: 'o título não é anunciado');
      expect(placarEm, isNonNegative, reason: 'o placar não é anunciado');
      expect(acaoEm, isNonNegative, reason: 'a ação principal não é anunciada');

      expect(
        tituloEm < placarEm && placarEm < acaoEm && acaoEm < lobbyEm,
        isTrue,
        reason: 'a leitura tem de ir do resultado ao placar e só então às '
            'ações — veio $rotulos',
      );
      semantica.dispose();
    });
  });

  // =========================================================================
  // 3. TIPOGRAFIA — §5.2
  // =========================================================================
  group('nenhum texto produtivo abaixo de $kFonteMinima pt', () {
    for (final escala in <double>[1.0, 1.5, 2.0]) {
      final pct = (escala * 100).round();
      for (final fim in <bool>[true, false]) {
        final estado = fim ? 'fim de partida' : 'fim de rodada';
        testWidgets('$estado, fonte em $pct%', (tester) async {
          final b = _Bancada();
          await _montar(tester, b, escala: escala, fimPartida: fim);

          final fontes = _fontes(tester);
          expect(
            fontes,
            isNotEmpty,
            reason: 'nenhum parágrafo medido — o caso seria um verde vazio',
          );
          fontes.forEach((texto, tamanho) {
            expect(
              tamanho,
              greaterThanOrEqualTo(kFonteMinima),
              reason: '"$texto" está em $tamanho pt, abaixo do piso '
                  '$kFonteMinima — era assim que a tela tinha 6,6 e 8',
            );
          });
        });
      }
    }

    testWidgets('a microtipografia do relatório não existe mais',
        (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      final usadas = _fontes(tester).values.toSet();
      // Os tamanhos nomeados no relatório-base, um a um.
      for (final proibida in <double>[6.6, 7.0, 7.5, 8.0, 9.0]) {
        expect(
          usadas,
          isNot(contains(proibida)),
          reason: '$proibida pt voltou à tela',
        );
      }
    });

    testWidgets('a hierarquia entre título, placar, detalhe e ação continua',
        (tester) async {
      final b = _Bancada();
      await _montar(tester, b);
      final fontes = _fontes(tester);

      final placar = fontes['3020']!;
      final titulo = fontes['NÓS VENCEMOS!']!;
      final acao = fontes['VAMOS JOGAR?']!;
      final detalhe = fontes['Canastras']!;

      expect(placar, greaterThan(titulo), reason: 'o placar é o maior');
      expect(titulo, greaterThan(acao), reason: 'o título domina a ação');
      expect(acao, greaterThan(detalhe), reason: 'a ação domina o detalhe');
    });

    // PROVA NEGATIVA DA ESCALA.
    //
    // Uma tela que trava `textScaler` — ou que enfia um `FittedBox` em volta
    // do conteúdo — passa em qualquer teste de overflow, porque simplesmente
    // desobedece ao usuário. A prova é que o parágrafo TEM DE CRESCER quando a
    // escala sobe. Se alguém travar a escala para calar um estouro, aqui
    // reprova.
    testWidgets('o texto cresce de verdade quando o sistema amplia',
        (tester) async {
      final b = _Bancada();

      await _montar(tester, b);
      final em100 = _alturaDoParagrafo(tester, 'NÓS VENCEMOS!');
      final placar100 = _alturaDoParagrafo(tester, '3020');

      await _montar(tester, b, escala: 2.0);
      final em200 = _alturaDoParagrafo(tester, 'NÓS VENCEMOS!');
      final placar200 = _alturaDoParagrafo(tester, '3020');

      expect(
        em200,
        greaterThan(em100 * 1.8),
        reason: 'o título não acompanhou a escala do sistema: $em100 -> $em200 '
            '— a tela está travando ou encolhendo a fonte',
      );
      expect(
        placar200,
        greaterThan(placar100 * 1.8),
        reason: 'o placar não acompanhou a escala: $placar100 -> $placar200',
      );
    });

    // A fonte DECLARADA não muda com a escala: quem amplia é o sistema, e não
    // a tela que escolhe um número menor para caber. Se alguém introduzir um
    // "se estiver apertado, use 8", os dois conjuntos deixam de bater.
    testWidgets('a tela não escolhe fonte menor para caber', (tester) async {
      final b = _Bancada();

      await _montar(tester, b);
      final declaradas100 = _fontes(tester).values.toSet();

      await _montar(tester, b, escala: 2.0);
      final declaradas200 = _fontes(tester).values.toSet();

      expect(
        declaradas200,
        equals(declaradas100),
        reason: 'os tamanhos declarados mudaram entre 100% e 200% — a tela '
            'está reduzindo tipografia para esconder overflow',
      );
    });
  });

  // =========================================================================
  // 4. LAYOUT EM 100%, 150% E 200% — §5.3
  // =========================================================================
  group('a tela sobrevive à ampliação sem estourar', () {
    for (final escala in <double>[1.0, 1.5, 2.0]) {
      final pct = (escala * 100).round();
      for (final fim in <bool>[true, false]) {
        final estado = fim ? 'fim de partida' : 'fim de rodada';
        testWidgets('$estado em $pct%, sem overflow', (tester) async {
          final b = _Bancada();
          await _montar(tester, b, escala: escala, fimPartida: fim);
          expect(
            _estouros,
            isEmpty,
            reason: 'estouro de layout em $pct%: $_estouros',
          );
        });
      }
    }

    testWidgets('nem no estado VIP, nem com o convite já enviado, nem com o '
        'anúncio recebido — 200%', (tester) async {
      for (final variante in <Map<String, bool>>[
        {'vip': true},
        {'convite': true},
        {'anuncioAssistido': true},
        {'semAnuncios': true},
      ]) {
        final b = _Bancada();
        await _montar(
          tester,
          b,
          escala: 2.0,
          mesaVip: variante['vip'] ?? false,
          conviteRevancheEnviado: variante['convite'] ?? false,
          anuncioAssistido: variante['anuncioAssistido'] ?? false,
          assinanteSemAnuncios: variante['semAnuncios'] ?? false,
        );
        expect(_estouros, isEmpty, reason: 'estouro na variante $variante');
      }
    });

    testWidgets('numa tela ainda mais estreita — 320 pt lógicos, 200%',
        (tester) async {
      final b = _Bancada();
      await _montar(
        tester,
        b,
        escala: 2.0,
        fisico: const Size(960, 1920), // 320 x 640 lógicos
      );
      expect(_estouros, isEmpty, reason: 'estouro em 320 pt de largura');
    });

    testWidgets('o conteúdo que não cabe rola, e não é cortado', (tester) async {
      final b = _Bancada();
      await _montar(tester, b, escala: 2.0);

      final posicao = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(
        posicao.maxScrollExtent,
        greaterThan(0),
        reason: 'em 200% o conteúdo passa da tela; se não há rolagem, ele foi '
            'cortado ou encolhido',
      );
    });

    testWidgets('em 200% todo controle é alcançável por rolagem e responde',
        (tester) async {
      final b = _Bancada();
      await _montar(tester, b, escala: 2.0);

      // O último controle da tela é o mais fundo — se ele chega, todos chegam.
      final anuncio = find.widgetWithText(TextButton, 'ASSISTIR');
      await tester.scrollUntilVisible(anuncio, 200);
      await tester.tap(anuncio);
      await tester.pump();
      expect(
        b.verAnuncio,
        1,
        reason: 'o controle do fim da tela não é alcançável em 200%',
      );

      final lobby = find.widgetWithText(OutlinedButton, 'VOLTAR AO LOBBY');
      await tester.scrollUntilVisible(lobby, -200);
      await tester.tap(lobby);
      await tester.pump();
      expect(b.voltarLobby, 1, reason: 'o botão de lobby não responde em 200%');
    });
  });

  // =========================================================================
  // 5. FIDELIDADE À PARTIDA — §5.4
  // =========================================================================
  //
  // A tela não decide vitória, derrota nem empate: ela recebe o título e o
  // placar prontos de `mesa.dart`. Estes casos provam que ela os EXIBE sem
  // alterar nenhum — em todas as escalas, porque a correção mexeu no layout.
  group('placar, vencedor e desfecho chegam intactos', () {
    for (final caso in <Map<String, Object>>[
      {'titulo': 'NÓS VENCEMOS!', 'nos': 3020, 'eles': 1785, 'nome': 'vitória'},
      {'titulo': 'ELES VENCERAM', 'nos': 1420, 'eles': 3055, 'nome': 'derrota'},
      {'titulo': 'NÓS BATEMOS!', 'nos': 2000, 'eles': 2000, 'nome': 'empate'},
      {'titulo': 'BARALHO ESGOTADO', 'nos': 0, 'eles': 0, 'nome': 'zerado'},
    ]) {
      for (final escala in <double>[1.0, 2.0]) {
        final pct = (escala * 100).round();
        testWidgets('${caso['nome']} em $pct%', (tester) async {
          final b = _Bancada();
          await _montar(
            tester,
            b,
            escala: escala,
            titulo: caso['titulo']! as String,
            pontosNos: caso['nos']! as int,
            pontosEles: caso['eles']! as int,
          );

          final textos = _textos(tester);
          expect(textos, contains(caso['titulo']));
          expect(
            textos,
            contains('${caso['nos']}'),
            reason: 'o placar de NÓS não é o que a mesa entregou',
          );
          expect(
            textos,
            contains('${caso['eles']}'),
            reason: 'o placar de ELES não é o que a mesa entregou',
          );
          // E nenhum controle foi sacrificado para caber.
          for (final m in _controles(tester)) {
            expect(m.alvo, greaterThanOrEqualTo(kAlvoMinimo));
          }
        });
      }
    }

    testWidgets('o detalhamento mostra os mesmos números das duas duplas',
        (tester) async {
      final b = _Bancada();
      await _montar(tester, b, escala: 2.0);

      final textos = _textos(tester);
      // Totais: +1235 para NÓS, -85 para ELES (negativo continua negativo).
      expect(textos, contains('+1235'));
      expect(textos, contains('-85'));
      // Componentes do detalhe de NÓS.
      expect(textos, contains('+400')); // canastras
      expect(textos, contains('+285')); // cartas baixadas
      expect(textos, contains('+100')); // bônus de batida
      expect(textos, contains('-30')); // cartas na mão
      // Selos.
      expect(textos, contains('LIMPA 2'));
      expect(textos, contains('SUJA 1'));
      expect(textos, contains('500 1'));
      expect(textos, contains('1000 1'));
    });

    testWidgets('placar e detalhe são idênticos em 100% e em 200%',
        (tester) async {
      final b = _Bancada();

      await _montar(tester, b);
      final em100 = _textos(tester)..sort();

      await _montar(tester, b, escala: 2.0);
      final em200 = _textos(tester)..sort();

      expect(
        em200,
        equals(em100),
        reason: 'ampliar a fonte mudou o CONTEÚDO da tela — algum texto sumiu, '
            'foi trocado ou abreviado para caber',
      );
    });
  });

  // =========================================================================
  // 6. CALLBACKS — §5.4
  // =========================================================================
  group('cada controle continua chamando o que chamava', () {
    testWidgets('a ação principal convida para a revancha', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      await _tocar(tester, find.widgetWithText(ElevatedButton, 'VAMOS JOGAR?'));
      await tester.pump();
      expect(b.chamadas, <String>['convidarRevanche:1']);
    });

    testWidgets('com o convite enviado, a ação principal joga de novo',
        (tester) async {
      final b = _Bancada();
      await _montar(tester, b, conviteRevancheEnviado: true);

      await _tocar(tester, find.widgetWithText(ElevatedButton, 'JOGAR NOVAMENTE'));
      await tester.pump();
      expect(b.chamadas, <String>['jogarNovamente:1']);
    });

    testWidgets('o convite da faixa chama convidar, e só ele', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      await _tocar(tester, find.widgetWithText(TextButton, 'CONVIDAR'));
      await tester.pump();
      expect(b.chamadas, <String>['convidarRevanche:1']);
    });

    testWidgets('voltar ao lobby chama voltar ao lobby', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      await _tocar(tester, find.widgetWithText(OutlinedButton, 'VOLTAR AO LOBBY'));
      await tester.pump();
      expect(b.chamadas, <String>['voltarLobby:1']);
    });

    testWidgets('a próxima rodada chama continuar', (tester) async {
      final b = _Bancada();
      await _montar(tester, b, fimPartida: false);

      await _tocar(tester, find.widgetWithText(ElevatedButton, 'PRÓXIMA RODADA'));
      await tester.pump();
      expect(b.chamadas, <String>['continuar:1']);
    });

    testWidgets('o anúncio chama ver anúncio', (tester) async {
      final b = _Bancada();
      await _montar(tester, b);

      await _tocar(tester, find.widgetWithText(TextButton, 'ASSISTIR'));
      await tester.pump();
      expect(b.chamadas, <String>['verAnuncio:1']);
    });

    testWidgets('adicionar amigo leva o ASSENTO certo, e não o índice',
        (tester) async {
      final b = _Bancada();
      // Só o assento 3 está disponível: se a tela mandasse o índice da grade,
      // chegaria 2 em vez de 3, e o convite iria para outra pessoa.
      await _montar(
        tester,
        b,
        amizades: const {
          1: EstadoAmizade.amigos,
          2: EstadoAmizade.enviado,
          3: EstadoAmizade.disponivel,
        },
      );

      await _tocar(tester, find.widgetWithText(OutlinedButton, '+ AMIGO'));
      await tester.pump();
      expect(b.chamadas, <String>['adicionarAmigo:3']);
    });

    testWidgets('controles desabilitados continuam desabilitados',
        (tester) async {
      final b = _Bancada();
      await _montar(
        tester,
        b,
        conviteRevancheEnviado: true,
        anuncioAssistido: true,
      );

      // Convite já enviado: a faixa mostra ENVIADO e não chama nada.
      await tester.tap(
        find.widgetWithText(TextButton, 'ENVIADO'),
        warnIfMissed: false,
      );
      // Anúncio já assistido: RECEBIDO não chama nada.
      await tester.tap(
        find.widgetWithText(TextButton, 'RECEBIDO'),
        warnIfMissed: false,
      );
      // Amizade já enviada / já amigos: nenhum dos dois chama nada.
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'ENVIADO'),
        warnIfMissed: false,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'AMIGOS'),
        warnIfMissed: false,
      );
      await tester.pump();

      expect(
        b.chamadas,
        isEmpty,
        reason: 'um controle desabilitado disparou: ${b.chamadas}',
      );
    });

    testWidgets('em 200% os toques continuam indo para o mesmo lugar',
        (tester) async {
      final b = _Bancada();
      await _montar(tester, b, escala: 2.0);

      final principal = find.widgetWithText(ElevatedButton, 'VAMOS JOGAR?');
      await tester.scrollUntilVisible(principal, 200);
      await tester.tap(principal);
      await tester.pump();
      expect(b.chamadas, <String>['convidarRevanche:1']);
    });
  });

  // =========================================================================
  // 7. PROVA ESTRUTURAL — SECUNDÁRIA, E DE PROPÓSITO
  // =========================================================================
  //
  // Tudo acima é medida na árvore renderizada, que é a prova que vale. Este
  // grupo é o cinto por cima do suspensório: proíbe, no código-fonte, os três
  // atalhos que ESCONDEM o defeito em vez de corrigi-lo — encolher a tipografia
  // por transformação geométrica, e travar a escala do sistema. São atalhos que
  // fariam os casos de overflow passarem com a tela pior do que está.
  group('o código não contém os atalhos que mascaram o defeito', () {
    late String fonte;

    setUpAll(() {
      final bruto =
          File('lib/screens/resultado_partida_screen.dart').readAsStringSync();
      // COMENTÁRIO FORA. O comentário que EXPLICA a remoção do
      // `SizedBox(height: 27)` cita o próprio trecho removido — sem esta
      // limpeza, a prova casaria com a explicação e reprovaria o código certo.
      // É o mesmo motivo pelo qual esta varredura é secundária: ela lê texto,
      // e texto mente com facilidade.
      fonte = bruto
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
    });

    test('o arquivo foi mesmo lido, e sem comentário', () {
      expect(
        fonte,
        contains('class ResultadoPartidaScreen'),
        reason: 'o caminho da tela mudou e este grupo viraria verde vazio',
      );
      expect(
        fonte,
        isNot(contains('RÉGUA DE ACESSIBILIDADE')),
        reason: 'a limpeza de comentários não funcionou, e as provas abaixo '
            'passariam a ler prosa em vez de código',
      );
    });

    test('não há FittedBox nem Transform encolhendo texto', () {
      expect(fonte, isNot(contains('FittedBox')));
      expect(fonte, isNot(contains('Transform.scale')));
    });

    test('a tela não impõe textScaler nenhum', () {
      expect(
        fonte,
        isNot(contains('TextScaler.noScaling')),
        reason: 'travar a escala é desobedecer ao ajuste de fonte do sistema',
      );
      expect(
        RegExp(r'textScaler\s*:').hasMatch(fonte),
        isFalse,
        reason: 'a tela está sobrescrevendo o textScaler que recebe',
      );
    });

    test('o SizedBox de 27 pt não voltou', () {
      expect(
        RegExp(r'height:\s*27\b').hasMatch(fonte),
        isFalse,
        reason: 'o `SizedBox(height: 27)` do botão de amizade voltou',
      );
    });
  });
}
