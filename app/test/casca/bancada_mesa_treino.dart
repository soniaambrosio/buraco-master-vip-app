// bancada_mesa_treino.dart — as ferramentas para medir a Mesa de Treino.
//
// ---------------------------------------------------------------------------
// POR QUE UMA BANCADA, E NÃO ASSERÇÕES SOLTAS EM CADA CASO
// ---------------------------------------------------------------------------
//
// A Mesa de Treino é `lib/mesa.dart`: motor, regras e tela no mesmo arquivo de
// três mil e quatrocentas linhas. Nada dela é injetável — o `Jogo` nasce dentro
// do `initState`, o primeiro a jogar é SORTEADO (§3.2) e os robôs abrem a
// rodada num laço de 650 ms por assento.
//
// Medir isso sem ferramenta comum daria um teste que passa por sorte. Aqui
// ficam as três coisas que todo caso precisa:
//
//   1. `abrirMesaDeTreino` — monta a mesa numa superfície de telefone e só
//      devolve quando a vez está no assento 0, qualquer que tenha sido o
//      sorteio;
//   2. `cartasDaMao` / `selecionadasNaMao` — leem a mão pela GEOMETRIA da tela,
//      e não por estado privado. Valem antes e depois da correção, que é o que
//      permite o mesmo caso caracterizar o defeito e depois provar a correção;
//   3. `medirFaixasEfetivas` — TOCA ponto a ponto e observa qual carta subiu.
//      Não lê tamanho declarado, não lê retângulo de semântica: é a única forma
//      de medir a faixa que o dedo realmente pega quando as cartas se sobrepõem.
//
// ---------------------------------------------------------------------------
// POR QUE A LEITURA É GEOMÉTRICA
// ---------------------------------------------------------------------------
//
// `_MesaScreenState` é privado: `_sel`, `_j` e `_soundEnabled` não são
// alcançáveis de fora do arquivo. Um teste que quisesse lê-los pediria uma
// porta nova na produção só para ele existir.
//
// A seleção, porém, é VISÍVEL: a carta selecionada sobe `selectedLift` pontos
// (e só ela — as recém-compradas ficam alinhadas, o destaque delas é a moldura).
// Então "quais estão selecionadas" é lido do mesmo lugar de onde quem joga lê:
// a posição na tela. Isso mantém a produção sem porta de teste e mede a coisa,
// não a intenção.

// `Tristate` mora em `dart:ui` e não é reexportado por `flutter/semantics.dart`.
// O `show` é estreito de propósito: `dart:ui` também define `Rect` e `Offset`, e
// importá-lo inteiro colidiria com o material.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
// `rendering.dart` traz junto `MatrixUtils` e a camada de semântica.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/mesa.dart';

/// A superfície de telefone em que a auditoria de acessibilidade mediu.
///
/// É a mesma de `ligacao_mesa_caracterizacao_test.dart`: 1080x2340 físicos a 3x
/// dão 360x780 lógicos, o telefone Android comum. O padrão do `flutter_test` é
/// 800x600 — paisagem de desktop —, e a mesa é desenhada para retrato.
const Size kSuperficieDaAuditoria = Size(1080, 2340);

/// A menor superfície produtiva que o aplicativo suporta.
///
/// 320 pontos lógicos de largura é o piso histórico do Android e do iPhone SE.
/// Abaixo disso não há aparelho em que este aplicativo se instale.
const Size kSuperficieMinima = Size(960, 2080);

/// A largura lógica da superfície da auditoria.
const double kLarguraDaAuditoria = 360.0;

/// A faixa efetiva mínima que uma carta pode ter, em pontos lógicos.
///
/// É o piso da WCAG 2.5.8 (Target Size, Minimum, nível AA). O piso Material de
/// 48 é a meta, e onde ele não couber a razão está escrita no código.
const double kFaixaMinimaDeToque = 24.0;

/// A carta da mão desenhada por `_handCard`.
const double kLarguraDaCarta = 66.0;

/// A altura da carta da mão desenhada por `_handCard`.
const double kAlturaDaCarta = 100.0;

/// Monta a Mesa de Treino e devolve com a vez no assento 0.
///
/// O sorteio de §3.2 escolhe quem abre a rodada. Quando cai num robô, o
/// `_rodarBots` roda um laço de `Future.delayed(650ms)` por assento até a vez
/// voltar ao humano — no máximo três assentos, 1.950 ms. O tempo avançado aqui
/// cobre o pior caso com folga e continua muito abaixo dos 45 segundos do
/// relógio do turno, que não pode estourar no meio da medição.
Future<void> abrirMesaDeTreino(
  WidgetTester tester, {
  Size superficie = kSuperficieDaAuditoria,
  double densidade = 3,
  MesaVariant variante = MesaVariant.publica,
}) async {
  tester.view.physicalSize = superficie;
  tester.view.devicePixelRatio = densidade;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(home: MesaScreen(variant: variante)),
  );
  // O primeiro quadro é o que dispara o `addPostFrameCallback` do `initState`:
  // sem ele os robôs nem começam.
  await tester.pump();
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Desmonta a árvore e deixa o treino terminar o que já tinha começado.
///
/// Mesma razão de `ligacao_mesa_caracterizacao_test.dart`: `_rodarBots` não
/// confere `mounted` para continuar o laço, só para redesenhar. Desmontar
/// primeiro cancela o relógio do turno (o `dispose` fecha), e o tempo depois
/// deixa os robôs chegarem ao fim. Sem isto o `flutter_test` acusa "A Timer is
/// still pending" — falha que não é sobre o que o caso mede.
Future<void> encerrarMesaDeTreino(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

/// A carta da mão: o `AnimatedContainer` de 66x100 de `_handCard`.
///
/// Duas precisões que este `Finder` precisa ter, e cada uma custou uma medição
/// errada:
///
///   * `AnimatedContainer` guarda `width`/`height` dentro de `constraints`, e é
///     por lá que a medida é reconhecida;
///   * a MESMA medida de 66x100 é usada pelo monte e pelos dois mortos. Sem
///     recortar a mão, a leitura devolvia catorze cartas e uma ordem que não
///     era a de mão nenhuma. O recorte é o `AnimatedSlide`: só a mão embala
///     cada carta num — é ele que levanta a selecionada.
final Finder kCartaDaMao = find.descendant(
  of: find.byType(AnimatedSlide),
  matching: find.byWidgetPredicate(
    (w) =>
        w is AnimatedContainer &&
        w.constraints ==
            BoxConstraints.tightFor(
              width: kLarguraDaCarta,
              height: kAlturaDaCarta,
            ),
  ),
);


/// Um ponto GARANTIDAMENTE dentro da faixa de toque da carta [indice].
///
/// Enquanto a mão tinha uma fileira, o centro da carta servia. Com duas, não
/// serve mais: a fileira de baixo cobre a de cima a partir do piso de toque, e
/// o centro VISUAL de uma carta de cima cai dentro da carta de baixo. Tocar ali
/// seleciona a de baixo — corretamente, porque é ela que está pintada naquele
/// pixel. Um caso que tocasse no centro estaria medindo a carta errada e
/// acusando um defeito que não existe.
///
/// O ponto certo é o começo da faixa: alguns pontos à direita da borda esquerda
/// (que é onde a faixa começa) e, quando a fileira é coberta, na parte de cima,
/// que é a que fica à mostra.
Offset pontoDeToqueDaCarta(WidgetTester tester, int indice) {
  final rects = cartasDaMao(tester);
  final fileiras = fileirasDaMao(tester);
  final ultima = fileiras.reduce((a, b) => a > b ? a : b);
  final r = rects[indice];
  final coberta = fileiras[indice] < ultima;
  return Offset(
    r.left + 2,
    coberta ? r.top + r.height / 6 : r.center.dy,
  );
}
/// A janela por onde a mão é vista.
///
/// É o `SingleChildScrollView` horizontal que embala as cartas. O lixo também
/// tem um, e por isso a busca parte das CARTAS e sobe: o primeiro ancestral
/// desse tipo é o da mão, e nunca o do lixo.
///
/// Serve para separar duas coisas que parecem a mesma: a carta que está fora do
/// alcance do dedo, que é defeito, e a carta que está fora da JANELA, que é
/// rolagem — e rolar a mão é o que ela sempre fez.
Rect viewportDaMao(WidgetTester tester) => tester.getRect(
      find
          .ancestor(of: kCartaDaMao, matching: find.byType(SingleChildScrollView))
          .first,
    );

/// Onde a carta REPOUSA na vertical, sem a subida da seleção.
///
/// A OS 29-C1 trouxe a segunda fileira, e com ela a necessidade de dizer a que
/// fileira uma carta pertence. O topo pintado não serve para isso: a carta
/// selecionada sobe treze pontos, e uma carta da fileira de baixo, selecionada,
/// pinta mais alto do que uma da fileira de cima em repouso. As duas trocariam
/// de fileira aos olhos de quem mede.
///
/// A subida é uma `AnimatedSlide` com `offset.dy = -elevação / altura da carta`,
/// então desfazê-la é multiplicar de volta pela altura — sem precisar saber
/// quanto vale a elevação, que é justamente o número que as mutações mexem.
double _topoEmRepouso(WidgetTester tester, AnimatedContainer carta) {
  final alvo = find.byWidget(carta);
  final subida = tester
      .widgetList<AnimatedSlide>(
        find.ancestor(of: alvo, matching: find.byType(AnimatedSlide)),
      )
      .first;
  return tester.getRect(alvo).top - subida.offset.dy * kAlturaDaCarta;
}

/// A ordem lógica da mão, lida da tela: de cima para baixo, e da esquerda para
/// a direita dentro de cada fileira.
///
/// Com uma fileira é a ordem por `left`, como sempre foi. Com duas, ordenar só
/// por `left` embaralharia as duas fileiras — a carta 7 (primeira da fileira de
/// baixo) começa no mesmo `left` da carta 1.
int _compararNaMao(
  ({double repouso, Rect rect}) a,
  ({double repouso, Rect rect}) b,
) {
  // Meio ponto de tolerância: as fileiras distam o piso de toque inteiro, então
  // qualquer diferença real é de dezenas de pontos.
  if ((a.repouso - b.repouso).abs() > 0.5) {
    return a.repouso.compareTo(b.repouso);
  }
  return a.rect.left.compareTo(b.rect.left);
}

List<({double repouso, Rect rect, AnimatedContainer widget})> _maoLida(
  WidgetTester tester,
) {
  final cartas = <({double repouso, Rect rect, AnimatedContainer widget})>[];
  for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao)) {
    cartas.add((
      repouso: _topoEmRepouso(tester, w),
      rect: tester.getRect(find.byWidget(w)),
      widget: w,
    ));
  }
  cartas.sort((a, b) => _compararNaMao(
        (repouso: a.repouso, rect: a.rect),
        (repouso: b.repouso, rect: b.rect),
      ));
  return cartas;
}

/// Os retângulos das cartas da mão, NA ORDEM LÓGICA.
///
/// `_hand` posiciona a carta de índice `i` em `left = j * passo` dentro da sua
/// fileira, e a seleção muda a camada de desenho e a altura pintada, nunca a
/// posição de repouso. Por isso a ordem por (fileira, `left`) É a ordem da mão.
List<Rect> cartasDaMao(WidgetTester tester) =>
    [for (final c in _maoLida(tester)) c.rect];

/// A que fileira cada carta pertence, na ordem lógica da mão.
///
/// `0` é a de cima. Uma mão de uma fileira só devolve zeros.
List<int> fileirasDaMao(WidgetTester tester) {
  final cartas = _maoLida(tester);
  if (cartas.isEmpty) return const <int>[];
  final repousos = <double>[];
  for (final c in cartas) {
    if (repousos.every((r) => (r - c.repouso).abs() > 0.5)) {
      repousos.add(c.repouso);
    }
  }
  repousos.sort();
  return [
    for (final c in cartas)
      repousos.indexWhere((r) => (r - c.repouso).abs() <= 0.5),
  ];
}

/// As cartas da mão na ordem em que aparecem na ÁRVORE, e não na tela.
///
/// Cada valor identifica a POSIÇÃO de repouso da carta — fileira e `left` —,
/// que é o que distingue uma carta da outra quando as duas fileiras repetem os
/// mesmos `left`. A ordem da lista é a ordem de profundidade da árvore de
/// widgets, que é a ordem de desenho do `Stack`.
///
/// É por aqui que se enxerga o reembaralhamento da pintura: `_maoDisposta`
/// ordena os filhos do `Stack` por fileira e, dentro dela, por prioridade de
/// seleção — então selecionar uma carta a manda para o fim da sua fileira.
List<String> ordemDeDesenho(WidgetTester tester) => <String>[
      for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao))
        '${_topoEmRepouso(tester, w).toStringAsFixed(1)}'
            '@${tester.getRect(find.byWidget(w)).left.toStringAsFixed(1)}',
    ];

/// Quais cartas da mão estão selecionadas.
///
/// A carta selecionada sobe `selectedLift` pontos — e é a única que sobe: as
/// recém-compradas ficam alinhadas, o destaque delas é a moldura dourada. A
/// leitura é feita no `AnimatedSlide` de cada carta, cujo `offset` só é
/// diferente de zero para a selecionada.
///
/// POR QUE NÃO PELA GEOMETRIA. A primeira versão lia `getRect().top` e
/// comparava com a linha de base. Não funciona: `getRect` resolve a matriz de
/// pintura do último quadro desenhado, e a subida da carta é uma
/// `FractionalTranslation` animada. Medindo assim, uma carta já desselecionada
/// continuava aparecendo treze pontos acima — o teste media o quadro anterior.
/// O `offset` do widget é o valor declarado por este `build`, sem defasagem.
Set<int> selecionadasNaMao(WidgetTester tester) {
  final cartas = <({double repouso, Rect rect, bool selecionada})>[];
  for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao)) {
    final alvo = find.byWidget(w);
    final subida = tester
        .widgetList<AnimatedSlide>(
          find.ancestor(of: alvo, matching: find.byType(AnimatedSlide)),
        )
        .first;
    cartas.add((
      repouso: tester.getRect(alvo).top - subida.offset.dy * kAlturaDaCarta,
      rect: tester.getRect(alvo),
      selecionada: subida.offset.dy != 0,
    ));
  }
  // A MESMA ordem de `cartasDaMao`: fileira e depois `left`. Duas listas com
  // ordens diferentes fariam "a carta 3" querer dizer coisas diferentes em
  // lugares diferentes do mesmo caso de teste.
  cartas.sort((a, b) => _compararNaMao(
        (repouso: a.repouso, rect: a.rect),
        (repouso: b.repouso, rect: b.rect),
      ));
  return <int>{
    for (var i = 0; i < cartas.length; i++)
      if (cartas[i].selecionada) i,
  };
}

/// Toca no ponto e devolve a seleção resultante.
///
/// O quadro é desenhado SEM avançar o relógio, e isso é essencial. A varredura
/// de `medirFaixasEfetivas` dá mais de quinhentos toques; com um quarto de
/// segundo em cada um, ela sozinha consumia mais de dois minutos de tempo
/// simulado. O turno do humano dura 45 segundos e, quando estoura, a mesa JOGA
/// SOZINHA e passa a vez — a medição virava metade mão do jogador, metade robô,
/// com faixas de oito pontos que não eram da mão nem do defeito.
///
/// Nada aqui precisa de tempo: a seleção é lida do `offset` que este `build`
/// declarou, e não da animação que o desenha.
Future<Set<int>> tocarEm(WidgetTester tester, Offset ponto) async {
  await tester.tapAt(ponto);
  await tester.pump();
  return selecionadasNaMao(tester);
}

/// A faixa efetiva de toque de cada carta da mão, em pontos lógicos.
///
/// PERCORRE a largura da mão de [passo] em [passo] pontos, TOCA em cada ponto e
/// vê qual carta subiu. A faixa de uma carta é a soma dos pontos que a pegam —
/// que é a medida que interessa a quem tem pouca firmeza na mão, e não a
/// largura da carta desenhada nem o retângulo entregue ao leitor de tela.
///
/// Entre uma medição e a seguinte a seleção é DESFEITA. Sem isso a medição se
/// contaminaria: hoje a carta selecionada vai para o topo da pilha de desenho e
/// passa a cobrir a vizinha, então o resultado do ponto seguinte dependeria do
/// ponto anterior.
Future<Varredura> medirFaixasEfetivas(
  WidgetTester tester, {
  double passo = 1.0,
}) async {
  final rects = cartasDaMao(tester);
  expect(rects, isNotEmpty, reason: 'a mão não desenhou carta nenhuma');
  final fileiras = fileirasDaMao(tester);

  // A seleção de partida não precisa estar vazia: o que se mede é o que CADA
  // toque muda em relação a ela. É isto que permite varrer a mão com uma carta
  // já escolhida — o caso que prova que a carta no topo da pilha de pintura não
  // engole a faixa da vizinha.
  final base = selecionadasNaMao(tester);

  final contagem = <int, int>{};
  final mortos = <double>[];
  // A varredura não passa da janela da mão. Onde a mão não cabe ela ROLA, e o
  // pedaço fora do recorte não é faixa morta: é faixa que ainda não está à
  // vista. Medi-la como morta transformaria rolagem em defeito.
  final janela = viewportDaMao(tester);
  var larguraVarrida = 0.0;

  // UMA PASSADA POR FILEIRA.
  //
  // Enquanto a mão tinha uma fileira só, uma linha horizontal no meio das
  // cartas cruzava todas elas. Com duas, essa mesma linha cruza uma fileira e
  // ignora a outra por inteiro — e a outra apareceria com faixa zero, que é
  // exatamente o defeito que esta varredura existe para pegar. Um falso
  // positivo desses seria pior do que não medir.
  final quantasFileiras =
      fileiras.isEmpty ? 0 : fileiras.reduce((a, b) => a > b ? a : b) + 1;
  for (var fileira = 0; fileira < quantasFileiras; fileira++) {
    final naFileira = <int>[
      for (var i = 0; i < rects.length; i++)
        if (fileiras[i] == fileira) i,
    ];
    if (naFileira.isEmpty) continue;

    // A altura em que esta fileira é tocada. A carta de cima é coberta pela de
    // baixo, então tocar no CENTRO dela pegaria a vizinha de baixo: a linha
    // sobe para o terço superior, que é a parte que fica à mostra.
    final primeiro = rects[naFileira.first];
    final y = fileira == 0 && quantasFileiras > 1
        ? primeiro.top + primeiro.height / 6
        : primeiro.center.dy;

    final esquerda = rects[naFileira.first].left;
    final direita = rects[naFileira.last].right;
    final inicio = esquerda > janela.left ? esquerda : janela.left;
    final fim = direita < janela.right ? direita : janela.right;
    if (fim <= inicio) continue;
    larguraVarrida += fim - inicio;

    for (var x = inicio + passo / 2; x < fim; x += passo) {
      final ponto = Offset(x, y);
      final depois = await tocarEm(tester, ponto);
      final mudou = depois.difference(base).union(base.difference(depois));
      if (mudou.isEmpty) {
        mortos.add(x);
        continue;
      }
      expect(
        mudou,
        hasLength(1),
        reason: 'um toque em $ponto mexeu em mais de uma carta',
      );
      contagem[mudou.single] = (contagem[mudou.single] ?? 0) + 1;
      final desfeito = await tocarEm(tester, ponto);
      expect(
        desfeito,
        base,
        reason: 'o segundo toque em $ponto não desfez o que o primeiro fez',
      );
    }
  }

  return Varredura(
    faixas: <double>[
      for (var i = 0; i < rects.length; i++) (contagem[i] ?? 0) * passo,
    ],
    pontosMortos: mortos,
    larguraVarrida: larguraVarrida,
  );
}

/// O resultado de uma varredura da mão.
class Varredura {
  const Varredura({
    required this.faixas,
    required this.pontosMortos,
    required this.larguraVarrida,
  });

  /// A faixa efetiva de cada carta, em pontos lógicos, na ordem da mão.
  final List<double> faixas;

  /// Os pontos em que o toque não pegou carta nenhuma.
  ///
  /// Buraco na mão é tão ruim quanto faixa curta: o dedo encosta na carta e não
  /// acontece nada, e não há como saber por quê sem enxergar a tela.
  final List<double> pontosMortos;

  /// A largura total percorrida, da borda esquerda da primeira carta à borda
  /// direita da última.
  final double larguraVarrida;

  double get menorFaixa => faixas.reduce((a, b) => a < b ? a : b);
}

/// O rótulo de cada nó da árvore semântica, na ordem em que um leitor de tela
/// os visitaria.
List<String> ordemDeLeitura(WidgetTester tester) => <String>[
      for (final no in tester.semantics.simulatedAccessibilityTraversal())
        no.label,
    ];

/// Só os nós que são carta da mão, na ordem de leitura.
///
/// A marca é o sufixo de posição — `, carta 3 de 11` —, que é o que distingue
/// uma carta da mão de qualquer outro texto da tela.
// A obrigação do topo do lixo vem DEPOIS da posição no rótulo — "carta 3 de
// 12, obrigatória do lixo". Exigir fim de string aqui deixaria justamente a
// carta obrigatória de fora da leitura da mão, e a contagem cairia de 12 para
// 11 sem nenhum caso reclamar.
final RegExp kMarcaDeCartaDaMao = RegExp(r', carta \d+ de \d+(,|$)');

List<String> cartasNaOrdemDeLeitura(WidgetTester tester) =>
    ordemDeLeitura(tester).where(kMarcaDeCartaDaMao.hasMatch).toList();

/// O retângulo de um nó semântico em coordenadas de tela.
///
/// `SemanticsNode.rect` é local ao nó, e `transform` leva do sistema dele ao do
/// pai. Subir a cadeia aplicando uma matriz de cada vez é o que dá a posição na
/// tela — é por aqui que se pergunta se um nó CAI SOBRE a mão, que é a pergunta
/// que distingue um nó vazio do resto da mesa de um nó vazio dentro da mão.
/// As bandeiras de um nó semântico — botão, habilitado, selecionado, ligado.
///
/// `SemanticsNode.hasFlag` está depreciado desde a 3.32, e o CI pina a 3.44.8:
/// uma API que some entre uma versão e outra derrubaria o portão por motivo que
/// não é o do teste. `flagsCollection` é a forma atual, e concentrar a leitura
/// aqui deixa a próxima troca num lugar só.
SemanticsFlags bandeirasDe(SemanticsNode no) =>
    no.getSemanticsData().flagsCollection;

/// O nó é anunciado como botão.
bool ehBotao(SemanticsNode no) => bandeirasDe(no).isButton;

/// O nó é uma imagem para o leitor de tela.
bool ehImagem(SemanticsNode no) => bandeirasDe(no).isImage;

// `habilitado`, `selecionado` e `ligado` são TERNÁRIOS na árvore semântica, e a
// distinção importa: `Tristate.none` quer dizer "esta propriedade não se aplica
// a este nó", que é diferente de "se aplica, e está falsa". Um botão sem estado
// de habilitação e um botão desabilitado soam igual num teste que só olhe
// booleano, e são coisas opostas para quem ouve.

/// O nó diz que aceita interação agora.
bool estaHabilitado(SemanticsNode no) =>
    bandeirasDe(no).isEnabled == Tristate.isTrue;

/// O nó diz que existe, e que NÃO aceita interação agora.
bool estaDesabilitado(SemanticsNode no) =>
    bandeirasDe(no).isEnabled == Tristate.isFalse;

/// O nó está marcado como escolhido.
bool estaSelecionado(SemanticsNode no) =>
    bandeirasDe(no).isSelected == Tristate.isTrue;

/// O nó tem estado de liga/desliga — sem dizer qual.
bool temLigaDesliga(SemanticsNode no) =>
    bandeirasDe(no).isToggled != Tristate.none;

/// O nó está ligado.
bool estaLigado(SemanticsNode no) =>
    bandeirasDe(no).isToggled == Tristate.isTrue;

Rect retanguloNaTela(SemanticsNode no) {
  var rect = no.rect;
  for (SemanticsNode? atual = no; atual != null; atual = atual.parent) {
    final matriz = atual.transform;
    if (matriz != null) rect = MatrixUtils.transformRect(matriz, rect);
  }
  return rect;
}

/// O retângulo que a mão ocupa na tela.
Rect areaDaMao(WidgetTester tester) {
  final rects = cartasDaMao(tester);
  expect(rects, isNotEmpty, reason: 'a mão não desenhou carta nenhuma');
  return rects.reduce((a, b) => a.expandToInclude(b));
}

// ===========================================================================
// A OBRIGAÇÃO DO TOPO DO LIXO
// ===========================================================================
//
// No FECHADO e no SBTL, quem pega o lixo fica OBRIGADO a usar a carta que
// estava no topo antes de descartar. Quem guarda essa obrigação é o motor —
// `Jogo.lixoTopoObrigatorio`, o `id` da carta —, e ela só morre quando a carta
// entra num jogo ou quando a vez passa.
//
// Chegar a esse estado por fora do motor exigiria uma porta nova na produção só
// para o teste existir. Chegar por dentro dele depende do baralho: no FECHADO a
// compra só é permitida quando o topo tem uso imediato, e isso acontece em
// pouco menos de dois terços dos negócios. A saída é jogar de verdade e
// insistir com baralhos diferentes até um deles permitir — e falhar alto quando
// nenhum permitir, que é o único desfecho em que este auxiliar estaria mentindo.

/// O rótulo que a carta obrigatória do lixo carrega, e nenhuma outra.
const String kMarcaDaObrigacao = 'obrigatória do lixo';

/// Abre a Mesa de Treino no FECHADO e compra o lixo, deixando a obrigação viva.
///
/// Devolve o rótulo da carta obrigatória. A mesa fica montada e a vez continua
/// no assento 0 — quem chamou pode reorganizar, selecionar e redesenhar.
///
/// Com [comHomonimaNaMao], só devolve quando a mão tiver DUAS cartas de mesmo
/// nome — a obrigatória e a gêmea dela do segundo baralho. Ver
/// `homonimasNaMao` para a razão e para a conta das tentativas.
Future<String> abrirComObrigacaoDoLixo(
  WidgetTester tester, {
  Size superficie = kSuperficieDaAuditoria,
  int tentativas = 14,
  bool comHomonimaNaMao = false,
}) async {
  for (var tentativa = 0; tentativa < tentativas; tentativa++) {
    tester.view.physicalSize = superficie;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MesaScreen(
          // Chave nova a cada tentativa: é o que faz o `initState` rodar de
          // novo e um baralho diferente ser sorteado.
          key: ValueKey('obrigacao-$tentativa'),
          variant: MesaVariant.publica,
          modalidade: 'FECHADO',
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    final antes = cartasDaMao(tester).length;
    await tester.tap(find.bySemanticsLabel(RegExp('^lixo')));
    await tester.pump();
    if (cartasDaMao(tester).length > antes) {
      final obrigatorias = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => n.label.contains(kMarcaDaObrigacao))
          .map((n) => n.label)
          .toList();
      expect(
        obrigatorias,
        hasLength(1),
        reason: 'comprou o lixo no FECHADO e a obrigação não apareceu na mão',
      );
      // A gêmea do segundo baralho não vem em todo negócio. Quando o caso
      // depende dela, o baralho que não a trouxe é DESCARTADO — devolvê-lo
      // faria o caso passar sem ter o que comparar.
      if (!comHomonimaNaMao || homonimasNaMao(tester, obrigatorias.single) >= 2) {
        return obrigatorias.single;
      }
    }
    await encerrarMesaDeTreino(tester);
  }
  fail(
    'nenhum de $tentativas baralhos serviu: no FECHADO a compra do lixo '
    'depende de o topo ter uso imediato, e '
    '${comHomonimaNaMao ? 'este caso ainda precisa da carta gêmea na mão' : 'nenhum topo teve'} '
    '— a trava do topo mudou, ou o sorteio deixou de variar',
  );
}

/// Quantas cartas da mão têm o MESMO nome de [rotulo], contando a própria.
///
/// ---------------------------------------------------------------------------
/// POR QUE ISTO EXISTE, E POR QUE VALE INSISTIR POR ELE
/// ---------------------------------------------------------------------------
///
/// O destaque da obrigação segue a INSTÂNCIA, e não o valor e o naipe: com dois
/// baralhos existem duas cartas visualmente idênticas, e só uma delas é a que o
/// motor obriga a usar. O caso que prova isso confere que, entre as cartas de
/// mesmo nome, exatamente uma está marcada.
///
/// Só que essa afirmação é VERDADEIRA E VAZIA quando a gêmea não foi negociada:
/// "uma entre uma". A OS 29-R1 mediu o efeito injetando a mutação que trocava a
/// identidade pelo nome — ela sobrevivia em quatro de cada seis execuções, e o
/// caso ficava verde por não ter o que comparar.
///
/// A saída é a mesma que o resto desta bancada usa para chegar a estados que
/// dependem do baralho: insistir, e falhar alto quando nenhum servir. A gêmea
/// aparece em cerca de um terço dos negócios que permitem comprar o lixo no
/// FECHADO — a trava do topo pede duas cartas do mesmo VALOR na mão, e uma
/// delas ser também do mesmo naipe não é raro. Em quarenta tentativas, a chance
/// de nenhuma servir é da ordem de uma em dez milhões; e, quando acontece, o
/// desfecho é uma falha que diz o que faltou, e não um verde vazio.
int homonimasNaMao(WidgetTester tester, String rotulo) {
  final corte = rotulo.indexOf(', carta ');
  expect(
    corte,
    greaterThan(0),
    reason: '"$rotulo" não é uma carta da mão',
  );
  final nome = rotulo.substring(0, corte);
  return tester.semantics
      .simulatedAccessibilityTraversal()
      .where((n) =>
          kMarcaDeCartaDaMao.hasMatch(n.label) && n.label.startsWith('$nome,'))
      .length;
}

/// Todos os nós da árvore semântica, com a garantia de que existe árvore.
///
/// Boa parte das afirmações de acessibilidade tem a forma "não existe nó com
/// tal defeito" — nenhum tocável sem nome, nenhuma faixa abaixo do piso. Toda
/// afirmação dessa forma passa trivialmente sobre uma árvore VAZIA, e verde por
/// vazio é o pior resultado possível num portão de acessibilidade: ele fica
/// verde exatamente no dia em que a tela parou de montar.
List<SemanticsNode> arvoreDaMesa(WidgetTester tester) {
  final nos = tester.semantics.simulatedAccessibilityTraversal().toList();
  expect(
    nos.length,
    greaterThan(10),
    reason: 'a varredura precisa ter árvore para ler — vieram ${nos.length} nós',
  );
  return nos;
}

/// O retângulo do nó, em pontos lógicos.
///
/// `retanguloNaTela` acumula as matrizes até a raiz, e a matriz da raiz traz a
/// densidade da tela junto: o retângulo sai em pixels FÍSICOS. Dividir pela
/// densidade é o que devolve os pontos lógicos, que são a unidade em que a WCAG
/// e o Material escrevem os pisos — e a unidade em que a OS 29 mediu.
Rect retanguloEmPontos(WidgetTester tester, SemanticsNode no) {
  final r = retanguloNaTela(no);
  final d = tester.view.devicePixelRatio;
  return Rect.fromLTWH(r.left / d, r.top / d, r.width / d, r.height / d);
}

/// O nó da mesa cujo rótulo é exatamente [rotulo].
SemanticsNode noDaMesa(WidgetTester tester, String rotulo) =>
    arvoreDaMesa(tester).singleWhere(
      (n) => n.label == rotulo,
      orElse: () => throw TestFailure('nenhum nó chamado "$rotulo" na mesa'),
    );

/// O nó oferece a ação de toque.
bool ofereceToqueNoNo(SemanticsNode no) =>
    no.getSemanticsData().hasAction(SemanticsAction.tap);

// ===========================================================================
// O DESENHO DA LATERAL, SEPARADO DO ALVO DELA
// ===========================================================================
//
// Os três controles laterais têm duas geometrias que não coincidem: o DISCO,
// que é o que se vê, e a FAIXA de toque, que é o que o dedo pega e o que o
// leitor de tela recebe. A OS 29-C1 fez a segunda crescer para 48 e, sem
// querer, empurrou a primeira — os discos desceram 5, 8 e 11 pontos.
//
// Medir as duas é o que separa "o alvo cresceu" de "o desenho andou". O nó
// semântico dá a faixa; o `Container` do disco, o desenho.

/// O retângulo DESENHADO do disco do controle lateral [rotulo].
Rect discoDoControleLateral(WidgetTester tester, String rotulo) {
  final botao = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == rotulo,
  );
  expect(
    botao,
    findsOneWidget,
    reason: 'a mesa não tem um controle lateral chamado "$rotulo"',
  );
  final disco = find.descendant(of: botao, matching: find.byType(Container));
  expect(
    disco,
    findsOneWidget,
    reason: '"$rotulo" deixou de ter exatamente um disco desenhado',
  );
  return tester.getRect(disco);
}

/// O retângulo do assento de [apelido] na borda da mesa.
///
/// Serve de RÉGUA. Os assentos 2 e 3 são ancorados na mesma linha que a lateral
/// — `bottom: playerDockHeight + 8` e `right: 1` —, e nenhuma OS desta família
/// os moveu. Medir os discos contra eles diz onde a lateral está DENTRO da
/// mesa, sem depender da altura do rodapé, que esta família mudou de propósito.
Rect assentoNaBorda(WidgetTester tester, String apelido) {
  final assento = find.byWidgetPredicate(
    (w) => w is Semantics && (w.properties.label ?? '').startsWith('$apelido,'),
  );
  expect(
    assento,
    findsOneWidget,
    reason: 'a mesa não tem um assento de "$apelido"',
  );
  return tester.getRect(assento);
}

/// O aviso que a mesa mostra no rodapé do tabuleiro, ou `''` quando não há.
///
/// Só os avisos da lateral interessam aqui, e eles são os únicos que falam em
/// ligação final — é por isso que a busca é por esse trecho, e não por um
/// `Text` qualquer da mesa.
String avisoDaLateral(WidgetTester tester) {
  final f = find.textContaining('ligação final com o Claude');
  if (f.evaluate().isEmpty) return '';
  return tester.widget<Text>(f.first).data ?? '';
}

/// Os cinco pontos que provam uma região acionável: o centro e os quatro
/// cantos, meio ponto para dentro.
///
/// Tocar só no centro prova que existe alvo, e não prova tamanho nenhum: um
/// alvo de um ponto passaria igual. São os cantos que medem a região, porque um
/// alvo menor do que o retângulo anunciado deixa pelo menos um deles de fora.
List<Offset> cincoPontosDe(Rect r) => <Offset>[
      r.center,
      r.topLeft + const Offset(0.5, 0.5),
      r.topRight + const Offset(-0.5, 0.5),
      r.bottomLeft + const Offset(0.5, -0.5),
      r.bottomRight + const Offset(-0.5, -0.5),
    ];

/// Toca em [ponto] e devolve qual controle lateral respondeu, ou `null`.
///
/// Os três só se distinguem pelo que MUDA: o som inverte o próprio estado, e os
/// outros dois escrevem o aviso da mesa. Como um segundo toque no mesmo botão
/// reescreve o MESMO aviso, "não mudou nada" seria indistinguível de "respondeu
/// de novo" — por isso o aviso é levado antes a um valor que o controle sondado
/// não escreveria.
Future<String?> respostaDaLateral(
  WidgetTester tester,
  Offset ponto, {
  required String sondando,
}) async {
  final preparo = sondando == 'chat' ? 'expressões' : 'chat';
  await tester.tapAt(retanguloEmPontos(tester, noDaMesa(tester, preparo)).center);
  await tester.pump();

  final somAntes = estaLigado(noDaMesa(tester, 'som'));
  final avisoAntes = avisoDaLateral(tester);
  await tester.tapAt(ponto);
  await tester.pump();

  if (estaLigado(noDaMesa(tester, 'som')) != somAntes) return 'som';
  final aviso = avisoDaLateral(tester);
  if (aviso == avisoAntes) return null;
  if (aviso.startsWith('Chat')) return 'chat';
  if (aviso.startsWith('Expressões')) return 'expressões';
  return aviso;
}

// ===========================================================================
// UM JOGO BAIXADO NA MESA
// ===========================================================================
//
// A auditoria mediu, na área dos jogos da dupla, um nó TOCÁVEL sem nome. Provar
// que ele passou a falar exige um jogo baixado de verdade — e baixar exige
// cartas que formem jogo.
//
// No ABERTO só sequência vale, e três cartas do mesmo naipe em ordem não caem
// numa mão qualquer. No FECHADO a trinca vale, e três cartas do mesmo VALOR
// aparecem com folga numa mão de doze tirada de dois baralhos. Por isso este
// auxiliar joga no FECHADO: não é uma modalidade escolhida por conveniência de
// teste, é a única em que a jogada existe sem depender de sorte grande.
//
// O caminho é o de quem joga: comprar no monte, escolher as três cartas na mão
// e tocar no feltro da própria dupla — que é como `_meldArea` baixa.

/// Abre a Mesa de Treino e baixa um jogo, devolvendo o rótulo dele.
Future<String> abrirComJogoBaixado(
  WidgetTester tester, {
  Size superficie = kSuperficieDaAuditoria,
  int tentativas = 14,
}) async {
  for (var tentativa = 0; tentativa < tentativas; tentativa++) {
    tester.view.physicalSize = superficie;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MesaScreen(
          key: ValueKey('baixada-$tentativa'),
          variant: MesaVariant.publica,
          modalidade: 'FECHADO',
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Comprar primeiro: sem compra o motor recusa a baixada.
    await tester.tap(find.bySemanticsLabel(RegExp('^monte')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Três cartas do mesmo valor, lidas do próprio anúncio da mão. O valor é o
    // que vem antes do " de " — "dama de espadas" vira "dama"; o curinga não
    // tem naipe e fica de fora, porque uma trinca de curingas não é jogo.
    final mao = cartasNaOrdemDeLeitura(tester);
    final porValor = <String, List<int>>{};
    for (var i = 0; i < mao.length; i++) {
      final nome = mao[i].replaceAll(kMarcaDeCartaDaMao, '');
      final corte = nome.indexOf(' de ');
      if (corte < 0) continue;
      porValor.putIfAbsent(nome.substring(0, corte), () => <int>[]).add(i);
    }
    final trinca = porValor.values.where((v) => v.length >= 3).toList();
    if (trinca.isEmpty) {
      await encerrarMesaDeTreino(tester);
      continue;
    }

    for (final i in trinca.first.take(3)) {
      await tocarEm(tester, pontoDeToqueDaCarta(tester, i));
    }

    // O feltro da dupla de baixo. A tarja "NÓS" é decoração dentro dele, e
    // serve de referência: tocar logo abaixo dela cai na área de jogos.
    final tarja = tester.getRect(find.text('NÓS').first);
    await tester.tapAt(tarja.center + const Offset(0, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final jogos = tester.semantics
        .simulatedAccessibilityTraversal()
        .where((n) => RegExp(r'^jogo \d+ de ').hasMatch(n.label))
        .map((n) => n.label)
        .toList();
    if (jogos.isNotEmpty) return jogos.first;
    await encerrarMesaDeTreino(tester);
  }
  fail(
    'nenhum de $tentativas baralhos permitiu baixar um jogo no FECHADO — '
    'a trinca deixou de valer, ou a área de jogos deixou de aceitar o toque',
  );
}
