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

import 'package:flutter/material.dart';
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

/// Os retângulos das cartas da mão, da esquerda para a direita.
///
/// A âncora é o `AnimatedContainer` de 66x100 de `_handCard`. O lixo também tem
/// um `AnimatedContainer`, mas sem largura fixa; as cartas do lixo, do monte e
/// dos mortos são `Container` comum. Este par de medidas é só da mão.
///
/// A ordem por `left` crescente É a ordem lógica da mão: `_hand` posiciona a
/// carta de índice `i` em `left = i * step`, e a seleção muda a camada visual e
/// a altura, nunca o `left`.
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

List<Rect> cartasDaMao(WidgetTester tester) {
  final rects = <Rect>[
    for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao))
      tester.getRect(find.byWidget(w)),
  ];
  rects.sort((a, b) => a.left.compareTo(b.left));
  return rects;
}

/// As cartas da mão na ordem em que aparecem na ÁRVORE, e não na tela.
///
/// Cada valor é o `left` global do retângulo. A ordem da lista é a ordem de
/// profundidade da árvore de widgets — que é a ordem de desenho do `Stack` e,
/// quando existe semântica nas próprias cartas, também a ordem em que um leitor
/// de tela as visitaria.
///
/// É por aqui que se enxerga o reembaralhamento: `_hand` ordena os filhos do
/// `Stack` por prioridade de seleção, então selecionar uma carta a manda para o
/// fim da lista.
List<double> ordemDeDesenho(WidgetTester tester) => <double>[
      for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao))
        tester.getRect(find.byWidget(w)).left,
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
  final cartas = <({double esquerda, bool selecionada})>[];
  for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao)) {
    final alvo = find.byWidget(w);
    final subida = tester
        .widgetList<AnimatedSlide>(
          find.ancestor(of: alvo, matching: find.byType(AnimatedSlide)),
        )
        .first;
    cartas.add((
      esquerda: tester.getRect(alvo).left,
      selecionada: subida.offset.dy != 0,
    ));
  }
  cartas.sort((a, b) => a.esquerda.compareTo(b.esquerda));
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
Future<List<double>> medirFaixasEfetivas(
  WidgetTester tester, {
  double passo = 1.0,
}) async {
  final rects = cartasDaMao(tester);
  expect(rects, isNotEmpty, reason: 'a mão não desenhou carta nenhuma');

  final contagem = <int, int>{};
  final y = rects.first.center.dy;
  final inicio = rects.first.left;
  final fim = rects.last.right;

  for (var x = inicio + passo / 2; x < fim; x += passo) {
    final ponto = Offset(x, y);
    final depois = await tocarEm(tester, ponto);
    if (depois.isEmpty) continue;
    expect(
      depois,
      hasLength(1),
      reason: 'um toque em $ponto mexeu em mais de uma carta',
    );
    contagem[depois.single] = (contagem[depois.single] ?? 0) + 1;
    final desfeito = await tocarEm(tester, ponto);
    expect(
      desfeito,
      isEmpty,
      reason: 'o segundo toque em $ponto não desfez a seleção',
    );
  }

  return <double>[
    for (var i = 0; i < rects.length; i++) (contagem[i] ?? 0) * passo,
  ];
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
final RegExp kMarcaDeCartaDaMao = RegExp(r', carta \d+ de \d+$');

List<String> cartasNaOrdemDeLeitura(WidgetTester tester) =>
    ordemDeLeitura(tester).where(kMarcaDeCartaDaMao.hasMatch).toList();
