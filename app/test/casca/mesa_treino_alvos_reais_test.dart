// mesa_treino_alvos_reais_test.dart — o portão da OS 29-C1.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO PROVA, E POR QUE ELE É SEPARADO
// ---------------------------------------------------------------------------
//
// `mesa_treino_acessivel_test.dart` é o portão da OS 29: a mesa fala, tem papel
// e estado, e nenhuma carta ficou com a faixa de 21 pontos que a auditoria
// mediu. Ele continua valendo palavra por palavra, e nada aqui o substitui.
//
// A OS 29 foi REPROVADA por uma linha da matriz: o piso de toque exigido é 48
// pontos, e a correção parou em 24–25,3 na carta e nos 38 herdados dos três
// controles laterais. Este arquivo é o portão do que faltava:
//
//   * o alvo efetivo de 48 × 48 em toda carta, em toda largura, com a mão em
//     uma ou em duas fileiras conforme a largura permitir;
//   * os três controles laterais em 48 × 48, com `enabled`;
//   * o jogo baixado com nome, e não um nó tocável mudo;
//   * o assento e o avatar como UM jogador, e não quatro cacos;
//   * a carta obrigatória do topo do lixo seguindo a INSTÂNCIA certa.
//
// ---------------------------------------------------------------------------
// A MEDIDA É A FAIXA, E A FAIXA SE MEDE DE DOIS JEITOS
// ---------------------------------------------------------------------------
//
// O dedo e o leitor de tela não usam a mesma coisa. O dedo usa o teste de
// acerto: quem responde ao toque naquele ponto. O explorar-por-toque do
// TalkBack usa o RETÂNGULO DO NÓ semântico. Um pode estar certo com o outro
// errado, e a OS 29 provou isso na prática — a varredura ponto a ponto sozinha
// não pegava a faixa estreita do nó. Aqui os dois são medidos, sempre.
//
// Os números do piso estão escritos à mão neste arquivo, e não importados da
// produção: um piso importado anda junto com a mutação que o baixa, e o teste
// que deveria pegá-la fica verde.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bancada_mesa_treino.dart';

/// O piso de toque que a OS 29-C1 exige, nos dois eixos, em pontos lógicos.
const double kPisoExigido = 48.0;

/// Os três controles da lateral, na ordem em que a mesa os empilha.
const List<String> kControlesLaterais = <String>['chat', 'expressões', 'som'];

/// O DESENHO do disco lateral na mesa original, escrito à mão.
///
/// Como o piso, estes números não são importados da produção: importá-los faria
/// o desenho do teste andar junto com o da tela, e a medição que existe para
/// pegar o deslocamento passaria verde exatamente quando ele acontecesse.
const double kDiscoDesenhado = 38.0;

/// O passo entre um disco e o próximo na mesa original: 38 de disco + 7 de
/// folga. Ele NÃO é o passo do alvo, que é o piso de 48 — e é dessa diferença
/// que nasce o deslocamento que a OS 29-R1 mediu.
const double kPassoDesenhado = 45.0;

/// A distância entre a borda direita dos discos e a do assento da direita: a
/// lateral está em `right: 4`, o assento em `right: 1`.
const double kFolgaAteOAssentoDaDireita = 3.0;

/// A marca que distingue uma carta da mão de qualquer outro nó da mesa.
final RegExp kCarta = RegExp(r', carta (\d+) de (\d+)(,|$)');

/// A marca de um jogo baixado.
final RegExp kJogoBaixado = RegExp(r'^jogo \d+ de (nós|eles), ');

/// Uma tela larga o bastante para a mão inteira caber numa fileira só, mesmo
/// depois de comprar o lixo: 66 + 12 × 48 = 642 de mão, mais bordas e respiro.
const Size kSuperficieLarga = Size(2700, 3000); // 900 x 1000 lógicos

/// Uma proporção quadrada — tablet em pé, janela redimensionada.
const Size kSuperficieQuadrada = Size(1800, 1800); // 600 x 600 lógicos

/// A superfície de 400 pontos que a OS 29-C1 §5.3 nomeia.
const Size kSuperficie400 = Size(1200, 2400);

List<SemanticsNode> _cartasDaArvore(WidgetTester tester) =>
    arvoreDaMesa(tester).where((n) => kCarta.hasMatch(n.label)).toList();

/// O piso, conferido no retângulo do NÓ de cada carta.
void exigirPisoNosNos(WidgetTester tester) {
  final cartas = _cartasDaArvore(tester);
  expect(cartas, isNotEmpty, reason: 'nenhuma carta na árvore semântica');
  for (final no in cartas) {
    final r = retanguloEmPontos(tester, no);
    expect(
      r.width,
      greaterThanOrEqualTo(kPisoExigido - 0.01),
      reason: '"${no.label}" tem ${r.width.toStringAsFixed(2)} de largura',
    );
    expect(
      r.height,
      greaterThanOrEqualTo(kPisoExigido - 0.01),
      reason: '"${no.label}" tem ${r.height.toStringAsFixed(2)} de altura',
    );
  }
}

/// Nenhum nó de carta invade o retângulo de outro.
void exigirNosSemSobreposicao(WidgetTester tester) {
  final rs = [
    for (final n in _cartasDaArvore(tester)) retanguloEmPontos(tester, n),
  ];
  for (var i = 0; i < rs.length; i++) {
    for (var j = i + 1; j < rs.length; j++) {
      expect(
        rs[i].overlaps(rs[j]),
        isFalse,
        reason: 'as faixas anunciadas ${i + 1} e ${j + 1} se sobrepõem',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// O DESENHO DA OBRIGAÇÃO, E POR QUE ELE PRECISA DE PORTÃO PRÓPRIO
// ---------------------------------------------------------------------------
//
// A OS 29-R2 mediu o buraco que faltava neste arquivo. O ANÚNCIO da carta
// obrigatória — `, obrigatória do lixo` — tem prova em quatro casos aqui em
// baixo. O DESENHO dela não tinha nenhuma, em suíte alguma: uma varredura por
// `USE ESTA`, `3B30` e `boxShadow` em `test/` inteiro devolvia zero.
//
// As duas coisas são decididas SEPARADAMENTE na produção. O rótulo sai do `id`
// que o motor guarda, na camada de fala; o desenho sai de um `switch` sobre o
// destaque, na camada de pintura. Por isso duas mutações atravessavam a suíte
// inteira sem que nada reclamasse:
//
//   * tirar a orientação `USE ESTA`;
//   * amarrar o destaque ao brilho DOURADO da compra, que morre sozinho em
//     1,85 s enquanto a obrigação do motor segue viva — e anunciada.
//
// Nas duas, quem não vê a tela continua encontrando a carta pelo nome, e quem
// vê fica com uma jogada obrigatória e nenhuma indicação de qual carta é. É
// exatamente o caso que o destaque existe para resolver.
//
// Os três atributos estão escritos à mão aqui, como o piso de toque e o desenho
// do disco lateral: importá-los da produção faria a prova andar junto com a
// mutação que ela existe para pegar.

/// Quantos baralhos negociar até um trazer a obrigação E a gêmea dela.
///
/// ---------------------------------------------------------------------------
/// O NÚMERO É MEDIDO, E O ANTERIOR NÃO ERA
/// ---------------------------------------------------------------------------
///
/// A OS 29-C2 pôs 40 aqui com a conta de que a gêmea aparece em cerca de um
/// TERÇO dos negócios que permitem pegar o lixo no FECHADO — o que daria uma
/// chance de falha da ordem de uma em dez milhões. Censo de cinco corridas de
/// 40 negócios cada, nesta árvore: 15 a 21 negócios permitem a compra, e
/// apenas 1 a 3 deles trazem a gêmea. Não é um terço: é perto de um DÉCIMO,
/// e a chance de nenhum dos 40 servir fica em torno de 13%.
///
/// Medido também pelo lado de fora: o caso `acompanha a INSTÂNCIA`, tal como
/// a C2 o entregou, reprovou 1 de 15 execuções isoladas — pelo `fail` alto da
/// bancada, e não por defeito do produto. Um portão obrigatório que reprova
/// uma vez em oito é um portão que ensina a reexecutar até passar.
///
/// Com 240, a chance de nenhum servir cai para menos de uma em vinte mil, e o
/// custo continua pequeno: o desfecho comum é achar na vigésima tentativa, e
/// só a corrida azarada paga o resto.
const int kBaralhosAteAGemea = 240;

/// O vermelho da obrigação: o gradiente que o recuo de 2 vira moldura.
const Color kVermelhoDaObrigacao = Color(0xFFFF3B30);

/// A sombra da obrigação — a "leve elevação" que não move a carta de lugar.
const Color kSombraDaObrigacao = Color(0x99FF3B30);

/// A orientação curta escrita na carta obrigada.
const String kOrientacaoDaObrigacao = 'USE ESTA';

/// Bem depois do dourado da compra, que dura 1,85 s.
///
/// É este atraso que separa os dois estados. Quem pega o lixo no FECHADO recebe
/// a carta do topo E ela é, no mesmo instante, uma carta recém-comprada: os
/// dois destaques caem sobre a MESMA carta, e só o relógio distingue um que
/// morre sozinho de um que dura até o motor dizer que acabou.
const Duration kDepoisDoDourado = Duration(milliseconds: 2400);

/// As cartas DESENHADAS da mão, na ordem lógica — a mesma de `cartasDaMao`.
///
/// A camada de desenho e a de toque são separadas de propósito e ficam em
/// posições diferentes: o retângulo do nó semântico é a FAIXA de toque, e o da
/// carta é o desenho. Casar as duas por geometria daria falso negativo.
///
/// O que casa é a ORDEM. `cartasDaMao` já ordena por (fileira, `left`), que é a
/// ordem lógica da mão — a mesma que numera o `carta N de M` do anúncio.
List<AnimatedContainer> cartasDesenhadasDaMao(WidgetTester tester) {
  final porRetangulo = <Rect, AnimatedContainer>{};
  for (final w in tester.widgetList<AnimatedContainer>(kCartaDaMao)) {
    porRetangulo[tester.getRect(find.byWidget(w))] = w;
  }
  final ordem = cartasDaMao(tester);
  expect(ordem, isNotEmpty, reason: 'a mão não desenhou carta nenhuma');
  expect(
    porRetangulo,
    hasLength(ordem.length),
    reason: 'duas cartas da mão foram desenhadas no MESMO retângulo — a ordem '
        'lógica deixou de distinguir uma carta da outra',
  );
  return <AnimatedContainer>[
    for (final r in ordem)
      porRetangulo[r] ??
          (throw TestFailure('a carta desenhada em $r sumiu da mão')),
  ];
}

/// A decoração declarada por esta carta NESTE quadro.
///
/// É o campo do widget, e não o que está pintado: `AnimatedContainer` interpola
/// a decoração ao longo de 220 ms, então ler a pintura devolveria um estado
/// intermediário que não é decisão de ninguém.
BoxDecoration decoracaoDaCarta(AnimatedContainer carta) {
  final d = carta.decoration;
  expect(
    d,
    isA<BoxDecoration>(),
    reason: 'a carta da mão deixou de declarar uma BoxDecoration',
  );
  return d! as BoxDecoration;
}

/// A carta traz a borda vermelha da obrigação.
bool temBordaDaObrigacao(AnimatedContainer carta) {
  final g = decoracaoDaCarta(carta).gradient;
  return g is LinearGradient && g.colors.contains(kVermelhoDaObrigacao);
}

/// A carta traz a sombra vermelha da obrigação.
bool temSombraDaObrigacao(AnimatedContainer carta) {
  final sombras = decoracaoDaCarta(carta).boxShadow;
  return sombras != null && sombras.any((s) => s.color == kSombraDaObrigacao);
}

/// Quantas orientações `USE ESTA` estão escritas DENTRO desta carta.
int orientacoesNaCarta(WidgetTester tester, AnimatedContainer carta) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byWidget(carta),
        matching: find.text(kOrientacaoDaObrigacao),
      ),
    )
    .length;

/// Os rótulos que carregam a marca da obrigação, na mesa montada.
///
/// Passa por `arvoreDaMesa` de propósito: "nenhum" e "exatamente um" são
/// afirmações que passam trivialmente sobre uma árvore vazia.
List<String> anunciosDaObrigacao(WidgetTester tester) => <String>[
      for (final no in arvoreDaMesa(tester))
        if (no.label.contains(kMarcaDaObrigacao)) no.label,
    ];

/// A posição que o próprio anúncio declara: `carta 3 de 12` devolve `2`.
int posicaoAnunciada(String rotulo) {
  final m = kCarta.firstMatch(rotulo);
  expect(m, isNotNull, reason: '"$rotulo" não é uma carta da mão');
  return int.parse(m!.group(1)!) - 1;
}

/// Valor e naipe de uma carta, lidos do anúncio dela.
///
/// `rei de espadas` vira `(rei, espadas)`; o curingão, que não tem naipe, vira
/// `(curinga, )`.
({String valor, String naipe}) nomeDaCarta(String rotulo) {
  final corte = rotulo.indexOf(', carta ');
  expect(corte, greaterThan(0), reason: '"$rotulo" não é uma carta da mão');
  final nome = rotulo.substring(0, corte);
  final sep = nome.indexOf(' de ');
  if (sep < 0) return (valor: nome, naipe: '');
  return (valor: nome.substring(0, sep), naipe: nome.substring(sep + 4));
}

/// Esta carta pode entrar num jogo novo ao lado do topo do lixo?
///
/// Um jogo de três com o topo é trinca (mesmo VALOR) ou sequência (mesmo
/// NAIPE), e em qualquer das duas um curinga ocupa um lugar — o curingão e o 2,
/// que o motor aceita como substituto. O filtro é frouxo de propósito: ele só
/// precisa NÃO DESCARTAR a combinação que o motor aceitaria, porque quem decide
/// se o jogo vale continua sendo o motor, do outro lado do toque.
bool combinaComOTopo(
  ({String valor, String naipe}) c,
  ({String valor, String naipe}) topo,
) {
  if (topo.valor == 'curinga' || topo.valor == '2') return true;
  return c.valor == topo.valor ||
      c.valor == 'curinga' ||
      c.valor == '2' ||
      (c.naipe.isNotEmpty && c.naipe == topo.naipe);
}

/// Faz o MOTOR encerrar a obrigação, pelo caminho de quem joga.
///
/// A obrigação nasce no motor e só morre lá: `baixar` e `estender` a consomem
/// quando usam a carta do topo, e a vez que passa a limpa. Pela tela, e sem
/// jogo nenhum baixado ainda, o caminho é um só — escolher a carta obrigada
/// mais duas e tocar no feltro da própria dupla.
///
/// Que ESSA combinação existe não é sorte: foi a trava do FECHADO que permitiu
/// pegar o lixo, e ela só permite quando o topo tem uso imediato. Achar QUAL é
/// se faz como o motor faz para os robôs — tentando os pares, do mais provável
/// para o menos. Quando nenhum serve, isto FALHA ALTO: um encerramento que não
/// aconteceu deixaria o resto do caso confirmando o desaparecimento de um
/// destaque que nunca chegou a existir.
Future<void> cumprirAObrigacao(WidgetTester tester, String obrigatoria) async {
  final alvo = posicaoAnunciada(obrigatoria);
  final mao = cartasNaOrdemDeLeitura(tester);
  final topo = nomeDaCarta(obrigatoria);

  // OS PONTOS DE TOQUE SÃO LIDOS AGORA, COM A MÃO EM REPOUSO, E REUSADOS.
  //
  // `pontoDeToqueDaCarta` parte de `cartasDaMao`, que ordena a mão por
  // posição de REPOUSO — e a posição de repouso é calculada descontando a
  // subida declarada do retângulo PINTADO. Entre escolher uma carta e o fim
  // dos 180 ms da subida, os dois discordam: o widget já declara a subida e a
  // pintura ainda não a fez. Nessa janela a conta devolve uma carta treze
  // pontos abaixo do lugar dela, o que basta para trocar a fileira e, com a
  // fileira, a ordem — e o toque seguinte cai na carta errada.
  //
  // A camada de toque não se mexe com a escolha. Ler os pontos uma vez, antes
  // da primeira escolha, é o que torna cada tentativa independente da
  // anterior.
  expect(
    selecionadasNaMao(tester),
    isEmpty,
    reason: 'a mão já vinha com carta escolhida: os pontos de toque seriam '
        'lidos de uma mão em movimento',
  );
  final pontos = <Offset>[
    for (var i = 0; i < mao.length; i++) pontoDeToqueDaCarta(tester, i),
  ];

  final pares = <List<int>>[];
  for (var i = 0; i < mao.length; i++) {
    if (i == alvo || !combinaComOTopo(nomeDaCarta(mao[i]), topo)) continue;
    for (var k = i + 1; k < mao.length; k++) {
      if (k == alvo || !combinaComOTopo(nomeDaCarta(mao[k]), topo)) continue;
      pares.add(<int>[i, k]);
    }
  }
  // A trinca primeiro: numa mão de dois baralhos ela é o jogo mais comum, e
  // cada tentativa custa sete toques.
  int distancia(List<int> p) =>
      -p.where((i) => nomeDaCarta(mao[i]).valor == topo.valor).length;
  pares.sort((a, b) => distancia(a).compareTo(distancia(b)));

  for (final par in pares) {
    final escolha = <int>[alvo, par[0], par[1]];
    for (final i in escolha) {
      await tocarEm(tester, pontos[i]);
    }
    // O feltro da dupla de baixo. A tarja "NÓS" mora DENTRO dele e está sob um
    // `IgnorePointer`, então tocar na tarja é tocar no feltro — e a tarja é o
    // ponto do feltro cuja posição não depende de quantas fileiras a mão
    // resolveu usar.
    await tester.tapAt(tester.getRect(find.text('NÓS').first).center);
    await tester.pump();
    if (anunciosDaObrigacao(tester).isEmpty) {
      // Baixar reorganiza a mão inteira. Deixar a animação terminar é o que faz
      // a leitura seguinte valer.
      await tester.pump(const Duration(milliseconds: 400));
      return;
    }
    // A baixada recusada NÃO desfaz a escolha, e sem desfazer a tentativa
    // seguinte levaria seis cartas ao feltro.
    for (final i in escolha) {
      await tocarEm(tester, pontos[i]);
    }
    expect(
      selecionadasNaMao(tester),
      isEmpty,
      reason: 'a escolha não voltou ao zero entre duas tentativas de baixar',
    );
  }
  fail(
    'nenhuma das ${pares.length} combinações baixou a carta obrigatória — a '
    'trava do FECHADO garante que existe uma, então ou ela deixou de garantir, '
    'ou o feltro deixou de aceitar a baixada',
  );
}

void main() {
  // =========================================================================
  // 1 — UMA FILEIRA OU DUAS, CONFORME A LARGURA
  // =========================================================================
  group('a mão se adapta à largura', () {
    testWidgets('numa tela larga as onze cartas cabem numa fileira', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester, superficie: kSuperficieLarga);

      final fileiras = fileirasDaMao(tester);
      expect(fileiras, hasLength(11));
      expect(
        fileiras.toSet(),
        <int>{0},
        reason: 'havia largura de sobra e a mão se partiu em duas fileiras',
      );
      exigirPisoNosNos(tester);
      exigirNosSemSobreposicao(tester);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('em 360 pontos a mão usa duas fileiras', (tester) async {
      await abrirMesaDeTreino(tester);

      final fileiras = fileirasDaMao(tester);
      expect(fileiras.toSet(), <int>{0, 1});
      // A metade maior em cima: a de baixo é a que aparece inteira.
      expect(fileiras.where((f) => f == 0), hasLength(6));
      expect(fileiras.where((f) => f == 1), hasLength(5));

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a mesa não estoura em 320, 360, 400 nem no quadrado', (
      tester,
    ) async {
      // Um estouro de layout vira exceção no `flutter_test` e derruba o caso
      // sozinho; este caso existe para que a derrubada aponte para a largura.
      for (final s in <Size>[
        kSuperficieMinima,
        kSuperficieDaAuditoria,
        kSuperficie400,
        kSuperficieQuadrada,
      ]) {
        await abrirMesaDeTreino(tester, superficie: s);
        expect(
          cartasDaMao(tester),
          hasLength(11),
          reason: 'em ${s.width ~/ 3} pontos a mão não desenhou onze cartas',
        );
        exigirPisoNosNos(tester);
        exigirNosSemSobreposicao(tester);
        await encerrarMesaDeTreino(tester);
      }
    });

    testWidgets('com a fonte do sistema em 200% o piso continua de pé', (
      tester,
    ) async {
      // O QUE ESTE CASO NÃO É. A Mesa de Treino JÁ estoura a 200% na base
      // congelada `907a350`, e antes dela em `bf5a9e7`: o relógio do turno
      // (`_turnBadge`) é um círculo de 33 pontos com o número dentro, e o
      // número dobra de tamanho enquanto o círculo não. Isso foi medido e está
      // registrado; corrigir layout de texto é da OS A11Y-4, não desta.
      //
      // O que ESTE caso prova é que o piso de toque não depende da escala de
      // fonte, e — igualmente importante — que nenhum estouro NOVO nasceu com a
      // segunda fileira. Por isso os erros são coletados e conferidos um a um
      // em vez de ignorados: qualquer estouro que não seja o do relógio derruba
      // o caso.
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final erros = <FlutterErrorDetails>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = erros.add;
      try {
        await abrirMesaDeTreino(tester);
      } finally {
        FlutterError.onError = anterior;
      }

      expect(cartasDaMao(tester), hasLength(11));
      exigirPisoNosNos(tester);
      exigirNosSemSobreposicao(tester);

      // O QUE SE PODE AFIRMAR SOBRE OS ESTOUROS HERDADOS, E O QUE NÃO SE PODE.
      //
      // Contá-los seria mentira: quantos aparecem depende do baralho — quantos
      // assentos mostram o relógio, que apelido calhou de ser mais comprido.
      // Medido na base congelada, o mesmo código deu 3 numa execução e 4 na
      // seguinte, sem nada ter mudado. Um número aqui viraria um teste
      // intermitente, que é pior do que teste nenhum.
      //
      // O que se pode afirmar é o TIPO: a 200% a mesa só produz estouro de
      // layout, e nada mais. Se a segunda fileira introduzisse uma exceção de
      // outra natureza — asserção, nulo, índice fora da faixa —, ela aparece
      // aqui. E o piso, que é o objeto desta OS, é conferido acima sem depender
      // disso.
      for (final e in erros) {
        expect(
          e.library,
          'rendering library',
          reason: 'a 200% apareceu um erro que não é de layout: ${e.exception}',
        );
        expect(
          e.exception.toString(),
          contains('overflowed'),
          reason: 'a 200% apareceu um erro que não é estouro: ${e.exception}',
        );
      }

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 2 — O ALVO EFETIVO, TOCADO PONTO A PONTO
  // =========================================================================
  group('o piso de 48 pontos', () {
    Future<void> pisoEm(WidgetTester tester, Size superficie) async {
      await abrirMesaDeTreino(tester, superficie: superficie);
      exigirPisoNosNos(tester);
      exigirNosSemSobreposicao(tester);

      final varredura = await medirFaixasEfetivas(tester);
      final fileiras = fileirasDaMao(tester);
      // A última de cada fileira pode estar cortada pela JANELA quando a mão
      // rola — o pedaço fora do recorte não é faixa curta, é faixa que ainda
      // não chegou. As demais são medidas inteiras.
      for (var i = 0; i < varredura.faixas.length; i++) {
        final ultimaDaFileira =
            i + 1 >= fileiras.length || fileiras[i + 1] != fileiras[i];
        if (ultimaDaFileira) continue;
        expect(
          varredura.faixas[i],
          greaterThanOrEqualTo(kPisoExigido),
          reason: 'em ${superficie.width ~/ 3} pontos a carta ${i + 1} ficou '
              'com ${varredura.faixas[i]} pontos de faixa efetiva',
        );
      }
      expect(varredura.pontosMortos, isEmpty);
      await encerrarMesaDeTreino(tester);
    }

    testWidgets('vale em 320 pontos, a menor superfície produtiva',
        (tester) => pisoEm(tester, kSuperficieMinima));

    testWidgets('vale em 360 pontos, a superfície da auditoria',
        (tester) => pisoEm(tester, kSuperficieDaAuditoria));

    testWidgets('vale em 400 pontos', (tester) => pisoEm(tester, kSuperficie400));

    testWidgets('o toque em cada carta acerta a carta, e não a vizinha', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);
      final total = cartasDaMao(tester).length;

      for (var i = 0; i < total; i++) {
        final ponto = pontoDeToqueDaCarta(tester, i);
        expect(
          await tocarEm(tester, ponto),
          <int>{i},
          reason: 'o toque destinado à carta ${i + 1} acertou outra',
        );
        expect(await tocarEm(tester, ponto), isEmpty);
      }

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 3 — ORDEM, FOCO E SELEÇÃO ATRAVESSAM A MIGRAÇÃO DE FILEIRA
  // =========================================================================
  group('ordem, foco e seleção', () {
    testWidgets('a leitura é 1…11, com as duas fileiras', (tester) async {
      await abrirMesaDeTreino(tester);

      final cartas = cartasNaOrdemDeLeitura(tester);
      expect(cartas, hasLength(11));
      for (var i = 0; i < cartas.length; i++) {
        expect(cartas[i], endsWith('carta ${i + 1} de 11'));
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a leitura é a mesma em uma e em duas fileiras', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester, superficie: kSuperficieLarga);
      final numaFileira = cartasNaOrdemDeLeitura(tester)
          .map((r) => r.replaceAll(kCarta, ''))
          .toList();
      expect(fileirasDaMao(tester).toSet(), <int>{0});
      await encerrarMesaDeTreino(tester);

      await abrirMesaDeTreino(tester);
      expect(fileirasDaMao(tester).toSet(), <int>{0, 1});
      final emDuas = cartasNaOrdemDeLeitura(tester)
          .map((r) => r.replaceAll(kCarta, ''))
          .toList();
      await encerrarMesaDeTreino(tester);

      // As mãos são de baralhos diferentes; o que se compara é a FORMA da
      // leitura: onze nomes, todos com posição, e nenhum buraco.
      expect(numaFileira, hasLength(11));
      expect(emDuas, hasLength(11));
      expect(numaFileira.where((r) => r.trim().isEmpty), isEmpty);
      expect(emDuas.where((r) => r.trim().isEmpty), isEmpty);
    });

    testWidgets('selecionar na fileira de cima não mexe na de baixo', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);
      final antes = cartasNaOrdemDeLeitura(tester);

      // Uma de cada fileira.
      expect(await tocarEm(tester, pontoDeToqueDaCarta(tester, 1)), <int>{1});
      expect(cartasNaOrdemDeLeitura(tester), orderedEquals(antes));
      expect(
        await tocarEm(tester, pontoDeToqueDaCarta(tester, 8)),
        <int>{1, 8},
      );
      expect(cartasNaOrdemDeLeitura(tester), orderedEquals(antes));

      // E as faixas continuam de pé com duas cartas escolhidas.
      exigirPisoNosNos(tester);
      exigirNosSemSobreposicao(tester);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a reorganização da compra não quebra ordem nem piso', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);
      expect(cartasDaMao(tester), hasLength(11));

      // Comprar no monte acrescenta uma carta e RE-ORDENA a mão inteira.
      await tester.tap(find.bySemanticsLabel(RegExp('^monte')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cartas = cartasNaOrdemDeLeitura(tester);
      expect(cartas, hasLength(12));
      for (var i = 0; i < cartas.length; i++) {
        expect(cartas[i], endsWith('carta ${i + 1} de 12'));
      }
      exigirPisoNosNos(tester);
      exigirNosSemSobreposicao(tester);

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 4 — A CARTA OBRIGATÓRIA DO TOPO DO LIXO
  // =========================================================================
  group('a obrigação do lixo', () {
    testWidgets('é anunciada, e só numa carta', (tester) async {
      final obrigatoria = await abrirComObrigacaoDoLixo(tester);

      expect(obrigatoria, contains(kMarcaDaObrigacao));
      expect(kCarta.hasMatch(obrigatoria), isTrue,
          reason: 'a obrigação caiu num nó que não é carta da mão');
      final comMarca = arvoreDaMesa(tester)
          .where((n) => n.label.contains(kMarcaDaObrigacao))
          .toList();
      expect(comMarca, hasLength(1));

      await encerrarMesaDeTreino(tester);
    });

    // -----------------------------------------------------------------------
    // A GÊMEA TEM DE ESTAR NA MESA ANTES DE A COMPARAÇÃO VALER
    // -----------------------------------------------------------------------
    //
    // "exatamente uma marcada entre as de mesmo nome" é verdade e não diz nada
    // quando só existe UMA carta com aquele nome. A OS 29-R1 mediu: a mutação
    // que troca a identidade pelo nome sobrevivia em quatro de cada seis
    // execuções, porque em dois terços dos negócios a gêmea do segundo baralho
    // não estava na mão e o caso passava vazio.
    //
    // Agora a bancada insiste até negociar um baralho que tenha as duas, e o
    // caso EXIGE as duas antes de olhar a marca. O verde passa a significar o
    // que ele sempre pareceu significar.
    //
    // Quantas insistências, ver `kBaralhosAteAGemea`.
    testWidgets('acompanha a INSTÂNCIA, e não o valor e o naipe', (
      tester,
    ) async {
      final obrigatoria = await abrirComObrigacaoDoLixo(
        tester,
        comHomonimaNaMao: true,
        tentativas: kBaralhosAteAGemea,
      );
      // O nome da carta é tudo o que vem antes da posição.
      final nome = obrigatoria.substring(0, obrigatoria.indexOf(', carta '));

      // A mão tem DOIS baralhos, e este negócio trouxe as duas cartas de mesmo
      // nome. A segunda NÃO pode receber o destaque: é esta a diferença entre
      // marcar uma instância e marcar um valor.
      final iguais = arvoreDaMesa(tester)
          .where((n) => kCarta.hasMatch(n.label) && n.label.startsWith('$nome,'))
          .toList();
      expect(
        iguais.length,
        greaterThanOrEqualTo(2),
        reason: 'a mão tem ${iguais.length} carta(s) chamada(s) "$nome" — sem '
            'a gêmea, comparar instância com valor não distingue nada',
      );
      final marcadas =
          iguais.where((n) => n.label.contains(kMarcaDaObrigacao)).toList();
      expect(
        marcadas,
        hasLength(1),
        reason: 'havia ${iguais.length} cartas chamadas "$nome" e '
            '${marcadas.length} marcadas como obrigatórias',
      );
      // E a marcada é a que o motor apontou, não "uma delas".
      expect(marcadas.single.label, obrigatoria);

      await encerrarMesaDeTreino(tester);
    });
    testWidgets('sobrevive à seleção, à desmarcação e ao rebuild', (
      tester,
    ) async {
      final obrigatoria = await abrirComObrigacaoDoLixo(tester);

      String? marcada() {
        final ns = tester.semantics
            .simulatedAccessibilityTraversal()
            .where((n) => n.label.contains(kMarcaDaObrigacao))
            .toList();
        return ns.length == 1 ? ns.single.label : null;
      }

      // Escolher e desescolher redesenham a mão inteira.
      await tocarEm(tester, pontoDeToqueDaCarta(tester, 0));
      expect(marcada(), obrigatoria);
      await tocarEm(tester, pontoDeToqueDaCarta(tester, 0));
      expect(marcada(), obrigatoria);

      // E um quadro novo, bem depois de o brilho da compra ter passado: o
      // destaque temporário dura 1,85 s, e a obrigação tem de continuar lá
      // quando ele já se foi. É este atraso que separa os dois estados.
      await tester.pump(const Duration(milliseconds: 2400));
      expect(marcada(), obrigatoria);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('sobrevive à mudança de fileira', (tester) async {
      final obrigatoria = await abrirComObrigacaoDoLixo(tester);
      expect(fileirasDaMao(tester).toSet(), <int>{0, 1},
          reason: 'a mão precisa estar em duas fileiras para este caso valer');

      // A mesma mesa numa tela larga: a mão volta para UMA fileira, e a carta
      // obrigatória muda de lugar sem mudar de identidade.
      tester.view.physicalSize = kSuperficieLarga;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fileirasDaMao(tester).toSet(), <int>{0});
      final ns = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => n.label.contains(kMarcaDaObrigacao))
          .toList();
      expect(ns, hasLength(1));
      expect(ns.single.label, obrigatoria);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a compra comum do monte NÃO vira obrigação', (tester) async {
      await abrirMesaDeTreino(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^monte')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // A carta recém-comprada tem destaque TEMPORÁRIO — dourado, e some
      // sozinho. Ele não pode se anunciar como a obrigação, que é vermelha e
      // dura até o motor dizer que acabou.
      expect(
        arvoreDaMesa(tester).where((n) => n.label.contains(kMarcaDaObrigacao)),
        isEmpty,
        reason: 'uma compra comum do monte foi anunciada como obrigatória',
      );
      // E no ABERTO a obrigação nunca nasce — nem depois que o brilho passa.
      await tester.pump(const Duration(milliseconds: 2200));
      expect(
        arvoreDaMesa(tester).where((n) => n.label.contains(kMarcaDaObrigacao)),
        isEmpty,
      );

      await encerrarMesaDeTreino(tester);
    });

    // -----------------------------------------------------------------------
    // O DESENHO, E NÃO SÓ O ANÚNCIO
    // -----------------------------------------------------------------------
    //
    // Os quatro casos acima provam o que a carta obrigatória FALA. Este prova o
    // que ela MOSTRA, e prende as duas coisas à mesma autoridade: enquanto o
    // motor obrigar, os três atributos ficam de pé na instância que ele
    // apontou; quando o motor encerrar, os três somem juntos.
    //
    // O relógio é a parte que não pode faltar. Comprar o lixo acende dois
    // destaques na MESMA carta — o dourado da compra e o vermelho da obrigação
    // —, e um teste tirado no instante da compra fica verde com o desenho
    // amarrado ao dourado, que morre sozinho em 1,85 s. A medição vale depois
    // disso, e é por isso que ela começa avançando o relógio.
    // >>> GUARDA DO DESENHO DA OBRIGACAO - INICIO
    testWidgets('o destaque vermelho dura o que a obrigação durar', (
      tester,
    ) async {
      // A gêmea do segundo baralho na mão: sem ela, "só a carta certa está
      // destacada" é uma frase verdadeira sobre uma carta só, e não distingue
      // instância de valor.
      final obrigatoria = await abrirComObrigacaoDoLixo(
        tester,
        comHomonimaNaMao: true,
        tentativas: kBaralhosAteAGemea,
      );
      final alvo = posicaoAnunciada(obrigatoria);

      // O RELÓGIO. Daqui em diante o dourado da compra já não existe, e o que
      // sobrar na tela é decisão da obrigação, não do brilho temporário.
      await tester.pump(kDepoisDoDourado);

      // A autoridade continua sendo do motor, e continua sendo por INSTÂNCIA:
      // um anúncio só, na mesma carta de antes, e a posição que ele declara é a
      // posição em que a mão o entrega.
      expect(
        anunciosDaObrigacao(tester),
        <String>[obrigatoria],
        reason: 'depois do dourado a obrigação sumiu, dobrou ou trocou de carta',
      );
      final maoAnunciada = cartasNaOrdemDeLeitura(tester);
      expect(
        maoAnunciada[alvo],
        obrigatoria,
        reason: 'a posição anunciada não é a posição em que a mão a entrega',
      );

      final nome = obrigatoria.substring(0, obrigatoria.indexOf(', carta '));
      final homonimas = <int>[
        for (var i = 0; i < maoAnunciada.length; i++)
          if (maoAnunciada[i].startsWith('$nome,')) i,
      ];
      expect(
        homonimas.length,
        greaterThanOrEqualTo(2),
        reason: 'a mão tem ${homonimas.length} carta(s) chamada(s) "$nome" — '
            'sem a gêmea, destacar a instância e destacar o valor desenham a '
            'mesma tela',
      );

      // OS TRÊS ATRIBUTOS, JUNTOS, NA CARTA QUE O MOTOR APONTOU.
      final desenho = cartasDesenhadasDaMao(tester);
      expect(
        desenho,
        hasLength(maoAnunciada.length),
        reason: 'a mão desenhou ${desenho.length} cartas e anunciou '
            '${maoAnunciada.length}',
      );
      expect(
        find.text(kOrientacaoDaObrigacao),
        findsOneWidget,
        reason: 'a orientação "$kOrientacaoDaObrigacao" tem de existir uma vez '
            'na mesa inteira',
      );
      expect(
        orientacoesNaCarta(tester, desenho[alvo]),
        1,
        reason: 'a orientação não está DENTRO da carta obrigada',
      );
      expect(
        temBordaDaObrigacao(desenho[alvo]),
        isTrue,
        reason: 'a carta obrigada perdeu a borda $kVermelhoDaObrigacao',
      );
      expect(
        temSombraDaObrigacao(desenho[alvo]),
        isTrue,
        reason: 'a carta obrigada perdeu a sombra $kSombraDaObrigacao',
      );

      // E EM NENHUMA OUTRA — a homônima comum inclusive.
      for (var i = 0; i < desenho.length; i++) {
        if (i == alvo) continue;
        final qual = homonimas.contains(i)
            ? 'a homônima "$nome" na posição ${i + 1}'
            : '"${maoAnunciada[i]}"';
        expect(temBordaDaObrigacao(desenho[i]), isFalse,
            reason: '$qual recebeu a borda da obrigação');
        expect(temSombraDaObrigacao(desenho[i]), isFalse,
            reason: '$qual recebeu a sombra da obrigação');
        expect(orientacoesNaCarta(tester, desenho[i]), 0,
            reason: '$qual recebeu a orientação da obrigação');
      }

      // E SÓ SOMEM DEPOIS QUE O MOTOR ENCERRA. Quem encerra é a jogada: a carta
      // obrigada entra num jogo, e `baixar` limpa a pendência.
      await cumprirAObrigacao(tester, obrigatoria);

      expect(
        anunciosDaObrigacao(tester),
        isEmpty,
        reason: 'o motor deveria ter encerrado a obrigação com a baixada',
      );
      expect(
        find.text(kOrientacaoDaObrigacao),
        findsNothing,
        reason: 'a obrigação acabou e a orientação continuou na tela',
      );
      final depois = cartasDesenhadasDaMao(tester);
      expect(depois, isNotEmpty, reason: 'a mão ficou vazia depois de baixar');
      for (var i = 0; i < depois.length; i++) {
        expect(temBordaDaObrigacao(depois[i]), isFalse,
            reason: 'a obrigação acabou e a carta ${i + 1} seguiu com a borda');
        expect(temSombraDaObrigacao(depois[i]), isFalse,
            reason: 'a obrigação acabou e a carta ${i + 1} seguiu com a sombra');
      }

      await encerrarMesaDeTreino(tester);
    });
    // <<< GUARDA DO DESENHO DA OBRIGACAO - FIM
  });

  // =========================================================================
  // 5 — OS TRÊS CONTROLES LATERAIS
  // =========================================================================
  group('os controles laterais', () {
    testWidgets('cada um tem 48 × 48 de região acionável', (tester) async {
      await abrirMesaDeTreino(tester);

      for (final nome in kControlesLaterais) {
        final no = arvoreDaMesa(tester).singleWhere((n) => n.label == nome);
        final r = retanguloEmPontos(tester, no);
        expect(
          r.width,
          greaterThanOrEqualTo(kPisoExigido - 0.01),
          reason: '"$nome" tem ${r.width.toStringAsFixed(2)} de largura',
        );
        expect(
          r.height,
          greaterThanOrEqualTo(kPisoExigido - 0.01),
          reason: '"$nome" tem ${r.height.toStringAsFixed(2)} de altura',
        );
        expect(ehBotao(no), isTrue);
        expect(estaHabilitado(no), isTrue, reason: '"$nome" não diz `enabled`');
      }

      await encerrarMesaDeTreino(tester);
    });

    // -----------------------------------------------------------------------
    // O ALVO CRESCEU E O DESENHO FICOU PARADO
    // -----------------------------------------------------------------------
    //
    // A OS 29-R1 mediu o preço da primeira solução: com o disco de 38 centrado
    // numa faixa de 48, as faixas andam de 48 em 48 e os discos, que andavam de
    // 45, desceram 5, 8 e 11 pontos. O alvo estava certo e o desenho da mesa —
    // que a OS mandou preservar — tinha mudado.
    //
    // Este caso mede o DESENHO, e o de cima mede o ALVO. Os dois juntos são o
    // que impede trocar um pelo outro: crescer o disco para 48 passaria no de
    // cima e reprovaria aqui; voltar a faixa para 38 passaria aqui e reprovaria
    // lá.
    testWidgets('os discos continuam onde a mesa original os desenhou', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final discos = <String, Rect>{
        for (final nome in kControlesLaterais)
          nome: discoDoControleLateral(tester, nome),
      };

      for (final e in discos.entries) {
        expect(
          e.value.width,
          closeTo(kDiscoDesenhado, 0.01),
          reason: 'o disco de "${e.key}" mede ${e.value.width} de largura',
        );
        expect(
          e.value.height,
          closeTo(kDiscoDesenhado, 0.01),
          reason: 'o disco de "${e.key}" mede ${e.value.height} de altura',
        );
      }

      // A coluna continua andando de 45 em 45 — 38 de disco e 7 de folga.
      expect(
        discos['expressões']!.top - discos['chat']!.top,
        closeTo(kPassoDesenhado, 0.01),
        reason: 'o passo entre "chat" e "expressões" mudou',
      );
      expect(
        discos['som']!.top - discos['expressões']!.top,
        closeTo(kPassoDesenhado, 0.01),
        reason: 'o passo entre "expressões" e "som" mudou',
      );

      // E os três seguem alinhados pela direita.
      for (final nome in kControlesLaterais) {
        expect(
          discos[nome]!.right,
          closeTo(discos['chat']!.right, 0.01),
          reason: 'o disco de "$nome" saiu da coluna',
        );
      }

      // AS DUAS ÂNCORAS DA MESA, medidas contra assentos que nenhuma OS desta
      // família moveu. O assento da esquerda divide com a lateral a linha de
      // `bottom: playerDockHeight + 8`; o da direita está em `right: 1` contra
      // os `right: 4` da lateral. Medir assim é o que torna a afirmação
      // independente da altura do rodapé — que esta família mudou de propósito,
      // porque a mão passou a caber em duas fileiras.
      final esquerda = assentoNaBorda(tester, 'Mateus');
      final direita = assentoNaBorda(tester, 'Sofia');
      expect(
        discos['som']!.bottom,
        closeTo(esquerda.bottom, 0.01),
        reason: 'a lateral saiu da linha de baixo da mesa: o disco termina em '
            '${discos['som']!.bottom} e o assento em ${esquerda.bottom}',
      );
      expect(
        direita.right - discos['chat']!.right,
        closeTo(kFolgaAteOAssentoDaDireita, 0.01),
        reason: 'a lateral saiu da coluna da direita',
      );

      await encerrarMesaDeTreino(tester);
    });

    // -----------------------------------------------------------------------
    // CINCO PONTOS, E NÃO SÓ O CENTRO
    // -----------------------------------------------------------------------
    //
    // O caso de cima lê o retângulo que a mesa ANUNCIA. Este confere que o
    // retângulo anunciado é o que o dedo encontra: um alvo de um ponto no meio
    // do nó de 48 passaria no primeiro caso e reprova aqui, porque os quatro
    // cantos não responderiam.
    testWidgets('os cinco pontos de cada alvo respondem, e só ao dono', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      for (final nome in kControlesLaterais) {
        final faixa = retanguloEmPontos(tester, noDaMesa(tester, nome));
        expect(
          faixa.width,
          greaterThanOrEqualTo(kPisoExigido - 0.01),
          reason: '"$nome" anunciou ${faixa.width} de largura',
        );
        expect(
          faixa.height,
          greaterThanOrEqualTo(kPisoExigido - 0.01),
          reason: '"$nome" anunciou ${faixa.height} de altura',
        );

        final pontos = cincoPontosDe(faixa);
        expect(pontos, hasLength(5));
        for (final ponto in pontos) {
          expect(
            await respostaDaLateral(tester, ponto, sondando: nome),
            nome,
            reason: 'o ponto $ponto do alvo de "$nome" não respondeu a ele',
          );
        }
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('os três alvos não se sobrepõem nem pegam o vizinho', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final rs = <String, Rect>{
        for (final nome in kControlesLaterais)
          nome: retanguloEmPontos(
            tester,
            arvoreDaMesa(tester).singleWhere((n) => n.label == nome),
          ),
      };
      final nomes = rs.keys.toList();
      for (var i = 0; i < nomes.length; i++) {
        for (var j = i + 1; j < nomes.length; j++) {
          expect(
            rs[nomes[i]]!.overlaps(rs[nomes[j]]!),
            isFalse,
            reason: '"${nomes[i]}" e "${nomes[j]}" se sobrepõem',
          );
        }
      }

      // E o toque no centro de cada um aciona SÓ ele: o som é o único com
      // estado visível, então é por ele que se confere que o vizinho não
      // roubou o gesto.
      final antes = estaLigado(noDaMesa(tester, 'som'));
      await tester.tapAt(rs['chat']!.center);
      await tester.pump();
      expect(estaLigado(noDaMesa(tester, 'som')), antes,
          reason: 'tocar em "chat" mexeu no som');
      await tester.tapAt(rs['som']!.center);
      await tester.pump();
      expect(estaLigado(noDaMesa(tester, 'som')), !antes);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a mão desabilitada não oferece ação', (tester) async {
      // O caso do controle DESABILITADO. Os três laterais respondem sempre; a
      // mão, não — fora da vez ela é anunciada desabilitada, e um nó
      // desabilitado não pode continuar oferecendo `tap`, senão o leitor de
      // tela convida para uma ação que não acontece.
      await abrirMesaDeTreino(tester);
      await tester.tap(find.bySemanticsLabel(RegExp('^monte')));
      await tester.pump();
      // Descartar passa a vez para os robôs.
      await tocarEm(tester, pontoDeToqueDaCarta(tester, 0));
      await tester.tap(find.bySemanticsLabel(RegExp('^lixo')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final cartas = _cartasDaArvore(tester);
      expect(cartas, isNotEmpty);
      for (final no in cartas) {
        expect(estaDesabilitado(no), isTrue,
            reason: '"${no.label}" continuou habilitada fora da vez');
        expect(ofereceToqueNoNo(no), isFalse,
            reason: '"${no.label}" oferece toque estando desabilitada');
      }

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 6 — JOGOS BAIXADOS, ASSENTOS E AVATAR
  // =========================================================================
  group('o resto da mesa fala', () {
    testWidgets('nó tocável nenhum fica sem nome', (tester) async {
      await abrirMesaDeTreino(tester);

      final mudos = arvoreDaMesa(tester).where((n) {
        final d = n.getSemanticsData();
        final nome = '${d.label}${d.value}${d.hint}${d.tooltip}'.trim();
        return d.hasAction(SemanticsAction.tap) && nome.isEmpty;
      }).toList();
      expect(
        mudos,
        isEmpty,
        reason: 'sobraram ${mudos.length} nós tocáveis sem nome nenhum',
      );

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('o jogo baixado diz de quem é, quantas cartas e o que faz', (
      tester,
    ) async {
      final rotulo = await abrirComJogoBaixado(tester);

      expect(kJogoBaixado.hasMatch(rotulo), isTrue,
          reason: 'o jogo baixado não se apresenta: "$rotulo"');
      expect(rotulo, contains('cartas'));
      expect(rotulo, contains(':'),
          reason: 'o jogo não lista a composição');

      final no = arvoreDaMesa(tester).singleWhere((n) => n.label == rotulo);
      expect(ehBotao(no), isTrue);
      expect(estaHabilitado(no), isTrue);
      expect(no.getSemanticsData().hint, isNotEmpty,
          reason: 'o jogo não diz o que o toque faz');

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('cada jogador é UM nó, e o avatar não vira o segundo', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);
      final arvore = arvoreDaMesa(tester);

      // Nenhum nó com o emoji do avatar solto, nem com o rótulo de desenho do
      // rodapé: os dois eram nós próprios antes desta correção.
      expect(arvore.where((n) => n.label == '👑'), isEmpty);
      expect(arvore.where((n) => n.label.startsWith('VOCÊ')), isEmpty);

      // Um nó por assento, com o apelido e a contagem.
      for (final apelido in const ['você', 'Cláudia', 'Mateus', 'Sofia']) {
        final assentos =
            arvore.where((n) => n.label.startsWith('$apelido,')).toList();
        expect(
          assentos,
          hasLength(1),
          reason: 'esperava um nó para "$apelido", achei '
              '${assentos.map((n) => n.label).toList()}',
        );
        final no = assentos.single;
        expect(no.label, contains('carta'));
        expect(ehBotao(no), isTrue);
        expect(estaHabilitado(no), isTrue);
        // UMA FRASE, e não a frase mais os cacos do desenho.
        //
        // O `GestureDetector` do assento é um contêiner semântico: tudo o que
        // está dentro dele é FUNDIDO no mesmo nó. Sem `ExcludeSemantics`, o
        // contador, o emoji do avatar e o rótulo "VOCÊ • N cartas" entram no
        // rótulo em linhas novas — o nó continua existindo, continua sendo um
        // só, e passa a ser lido como "Cláudia, adversário, robô, 11 cartas /
        // 11". A quebra de linha é a assinatura disso.
        expect(
          no.label,
          isNot(contains('\n')),
          reason: 'o rótulo do assento traz cacos do desenho: "${no.label}"',
        );
        expect(no.label, isNot(contains('👑')));
        expect(no.label, isNot(contains('VOCÊ')));
      }

      // Exatamente um assento diz que está jogando agora.
      expect(
        arvore.where((n) => n.label.contains('jogando agora')),
        hasLength(1),
      );

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 8 — A GUARDA DO CASO QUE GUARDA O DESENHO
  // =========================================================================
  //
  // Um caso de teste é a única coisa deste arquivo que ninguém confere. Esvaziar
  // o corpo do caso acima — trocá-lo por um `expect` trivial — deixa o portão
  // `mesac1` verde com um a mais no placar e sem nenhuma das afirmações que ele
  // existe para fazer. É a mesma família de buraco que a OS 29-R1 mediu quando
  // tirou `mesac1` de `OBRIGATORIOS` e nada reclamou.
  //
  // A conferência de DECLARAÇÃO (a chave no workflow, a suíte no disco) mora em
  // `auditoria_casca_test.dart`, fora do que ela garante. Esta aqui é de outra
  // natureza e por isso mora junto: ela lê o próprio arquivo e exige que o caso
  // continue chamando as coisas que fazem a prova. Os marcadores que a delimitam
  // ficam FORA do corpo do caso, então sobrevivem a um corpo trocado.
  //
  // Comentário não conta. A leitura descarta as linhas de comentário antes de
  // procurar, porque um `grep` que casa com a prosa que explica a remoção fica
  // verde exatamente no commit que removeu o que ela descrevia.
  group('a guarda do desenho da obrigação', () {
    const inicio = '// >>> GUARDA DO DESENHO DA OBRIGACAO - INICIO';
    const fim = '// <<< GUARDA DO DESENHO DA OBRIGACAO - FIM';

    /// As linhas de CÓDIGO do caso delimitado, sem comentário e sem os
    /// marcadores.
    List<String> corpoDoCaso() {
      final arquivo = File('test/casca/mesa_treino_alvos_reais_test.dart');
      expect(
        arquivo.existsSync(),
        isTrue,
        reason: 'a suíte não se enxerga do diretório de execução — o caminho '
            'declarado no workflow é relativo à raiz do pacote',
      );
      final linhas = arquivo.readAsLinesSync();
      final a = linhas.indexWhere((l) => l.trim() == inicio);
      final b = linhas.indexWhere((l) => l.trim() == fim);
      expect(a, greaterThanOrEqualTo(0), reason: 'o marcador de início sumiu');
      expect(b, greaterThan(a), reason: 'o marcador de fim sumiu ou trocou de '
          'lugar com o de início');
      return <String>[
        for (final l in linhas.sublist(a + 1, b))
          if (!l.trimLeft().startsWith('//')) l,
      ];
    }

    test('o caso do desenho continua fazendo o que ele promete', () {
      final corpo = corpoDoCaso().join('\n');

      const exigido = <String, String>{
        'abrirComObrigacaoDoLixo(': 'uma obrigação vinda do motor',
        'comHomonimaNaMao: true': 'a gêmea do segundo baralho na mão',
        'pump(kDepoisDoDourado)': 'o relógio depois do dourado da compra',
        'anunciosDaObrigacao(tester)': 'a obrigação lida da mesa montada',
        'find.text(kOrientacaoDaObrigacao)': 'a orientação escrita na carta',
        'temBordaDaObrigacao(': 'a borda vermelha',
        'temSombraDaObrigacao(': 'a sombra vermelha',
        'orientacoesNaCarta(': 'a orientação conferida carta a carta',
        'cumprirAObrigacao(': 'o encerramento pelo motor',
      };
      for (final e in exigido.entries) {
        expect(
          corpo.contains(e.key),
          isTrue,
          reason: 'o caso do desenho deixou de exigir ${e.value} '
              '(`${e.key}` não aparece mais no corpo dele)',
        );
      }

      // Um corpo trivial pode citar um nome sem afirmar nada com ele. O piso de
      // afirmações é grosseiro de propósito: ele não julga qualidade, só impede
      // que o caso vire casca.
      expect(
        'expect('.allMatches(corpo).length,
        greaterThanOrEqualTo(14),
        reason: 'o caso do desenho ficou com '
            '${'expect('.allMatches(corpo).length} afirmações',
      );
    });

    test('os três atributos continuam escritos à mão', () {
      // Se estes números viessem da produção, a mutação que apaga o destaque
      // levaria a prova junto e o portão ficaria verde no dia do defeito.
      expect(kVermelhoDaObrigacao, const Color(0xFFFF3B30));
      expect(kSombraDaObrigacao, const Color(0x99FF3B30));
      expect(kOrientacaoDaObrigacao, 'USE ESTA');
      expect(
        kDepoisDoDourado.inMilliseconds,
        greaterThanOrEqualTo(2400),
        reason: 'o dourado da compra dura 1,85 s: medir antes disso não '
            'distingue os dois destaques',
      );
    });
  });
}
