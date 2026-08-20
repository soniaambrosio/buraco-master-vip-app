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

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bancada_mesa_treino.dart';

/// O piso de toque que a OS 29-C1 exige, nos dois eixos, em pontos lógicos.
const double kPisoExigido = 48.0;

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

    testWidgets('acompanha a INSTÂNCIA, e não o valor e o naipe', (
      tester,
    ) async {
      final obrigatoria = await abrirComObrigacaoDoLixo(tester);
      // O nome da carta é tudo o que vem antes da posição.
      final nome = obrigatoria.substring(0, obrigatoria.indexOf(', carta '));

      // A mão tem DOIS baralhos: quando existe uma segunda carta com o mesmo
      // nome, ela NÃO pode receber o destaque. É esta a diferença entre marcar
      // uma instância e marcar um valor.
      final iguais = arvoreDaMesa(tester)
          .where((n) => kCarta.hasMatch(n.label) && n.label.startsWith('$nome,'))
          .toList();
      final marcadas =
          iguais.where((n) => n.label.contains(kMarcaDaObrigacao)).toList();
      expect(
        marcadas,
        hasLength(1),
        reason: 'havia ${iguais.length} cartas chamadas "$nome" e '
            '${marcadas.length} marcadas como obrigatórias',
      );

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
  });

  // =========================================================================
  // 5 — OS TRÊS CONTROLES LATERAIS
  // =========================================================================
  group('os controles laterais', () {
    testWidgets('cada um tem 48 × 48 de região acionável', (tester) async {
      await abrirMesaDeTreino(tester);

      for (final nome in const ['chat', 'expressões', 'som']) {
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

    testWidgets('os três alvos não se sobrepõem nem pegam o vizinho', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final rs = <String, Rect>{
        for (final nome in const ['chat', 'expressões', 'som'])
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
}
