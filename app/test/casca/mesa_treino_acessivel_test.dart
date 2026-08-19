// mesa_treino_acessivel_test.dart — a Mesa de Treino audível e tocável.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO PROVA, E O QUE ELE SE RECUSA A PROVAR
// ---------------------------------------------------------------------------
//
// Ele é o oposto do grupo `defeito` de `mesa_treino_caracterizacao_test.dart`,
// removido no mesmo commit em que estes casos entraram. A auditoria de
// acessibilidade de 19/08/2026 encontrou cinco coisas na mesa, e cada uma tem
// aqui o seu contrário medido:
//
//   1. cartas da mão sem nome          -> `nome`
//   2. cartas sem papel nem estado     -> `papel e estado`
//   3. três controles laterais sem nome-> `os controles da mesa`
//   4. faixa efetiva de 21,1 pontos    -> `faixa efetiva de toque`
//   5. ordem de foco reembaralhada     -> `ordem de leitura`
//
// ---------------------------------------------------------------------------
// NENHUM CASO AQUI PROCURA `Semantics` NO CÓDIGO
// ---------------------------------------------------------------------------
//
// Um teste que varre a fonte atrás da palavra `Semantics` passa com um
// `Semantics` vazio, e reprova quem resolver a mesma coisa por outro caminho —
// ele mede a escrita, não a experiência. Todos os casos daqui leem a ÁRVORE
// SEMÂNTICA COMPILADA, que é o que o TalkBack lê, ou TOCAM a tela e observam o
// que aconteceu com a partida.
//
// A varredura de toque, em particular, não confere tamanho declarado nem o
// retângulo entregue ao leitor: ela caminha ponto a ponto pela mão e pergunta,
// em cada um, qual carta o dedo pegou. É a única medida que corresponde ao que
// acontece com a mão de quem joga.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/cartas/nome_falavel_da_carta.dart';

import 'bancada_mesa_treino.dart';

/// O nó da árvore semântica cujo rótulo casa com [padrao].
SemanticsNode noComRotulo(WidgetTester tester, Pattern padrao) {
  final achados = tester.semantics
      .simulatedAccessibilityTraversal()
      .where((n) => n.label.contains(padrao))
      .toList();
  expect(
    achados,
    hasLength(1),
    reason: 'esperava UM nó falando "$padrao", achei '
        '${achados.map((n) => n.label).toList()}',
  );
  return achados.single;
}

/// O nó oferece a ação de toque.
///
/// `SemanticsNode` não expõe `hasAction`: quem sabe das ações é o
/// `SemanticsData` compilado a partir dele.
bool ofereceToque(SemanticsNode no) =>
    no.getSemanticsData().hasAction(SemanticsAction.tap);

void main() {
  // =========================================================================
  // 1 — O NOME DA CARTA
  // =========================================================================
  group('nome', () {
    test('a convenção de nomes é a mesma da Mesa Online', () {
      // A extração para `lib/cartas/nome_falavel_da_carta.dart` não pode ter
      // mudado o que a Mesa Online já anunciava: é o mesmo módulo que ela usa.
      expect(nomeFalavelDaCarta(valor: 'K', naipe: 'espadas'), 'rei de espadas');
      expect(nomeFalavelDaCarta(valor: 'A', naipe: 'ouros'), 'ás de ouros');
      expect(nomeFalavelDaCarta(valor: 'Q', naipe: 'copas'), 'dama de copas');
      expect(nomeFalavelDaCarta(valor: 'J', naipe: 'paus'), 'valete de paus');
      expect(nomeFalavelDaCarta(valor: '7', naipe: 'copas'), '7 de copas');
      expect(nomeFalavelDaCarta(valor: 'JOKER'), 'curinga');
      // Naipe desconhecido some do nome em vez de virar código na fala.
      expect(nomeFalavelDaCarta(valor: '7', naipe: 'trevos'), '7');
    });

    testWidgets('todas as cartas da mão têm rótulo falável', (tester) async {
      await abrirMesaDeTreino(tester);

      final cartas = cartasNaOrdemDeLeitura(tester);
      expect(cartas, hasLength(11));
      for (final rotulo in cartas) {
        expect(
          rotulo.replaceAll(kMarcaDeCartaDaMao, '').trim(),
          isNotEmpty,
          reason: 'uma carta ficou com a posição e sem nome: "$rotulo"',
        );
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('valores e naipes são anunciados em português', (tester) async {
      await abrirMesaDeTreino(tester);

      // A mão vem do baralho embaralhado, então o caso não pede uma carta
      // específica: pede que TODA carta caiba na convenção — figura ou número,
      // e um naipe em português, ou "curinga", que não tem naipe.
      final nomes = cartasNaOrdemDeLeitura(tester)
          .map((r) => r.replaceAll(kMarcaDeCartaDaMao, '').trim())
          .toList();
      final aceita = RegExp(
        r'^(curinga|(ás|valete|dama|rei|[0-9]{1,2}) '
        r'de (copas|ouros|paus|espadas))$',
      );
      for (final nome in nomes) {
        expect(
          aceita.hasMatch(nome),
          isTrue,
          reason: '"$nome" não é um nome de carta em português',
        );
      }
      // E o nome não é a letra crua do motor: `K`, `Q`, `J` e `A` seriam
      // soletrados pelo leitor de tela.
      for (final nome in nomes) {
        expect(nome, isNot(matches(RegExp(r'^[AJQK] '))));
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('cada carta traz a posição lógica na mão', (tester) async {
      await abrirMesaDeTreino(tester);

      // Dois baralhos: a mesma carta pode aparecer duas vezes, lado a lado. Sem
      // a posição, seriam dois "rei de espadas" indistinguíveis para quem ouve.
      final cartas = cartasNaOrdemDeLeitura(tester);
      for (var i = 0; i < cartas.length; i++) {
        expect(cartas[i], endsWith(', carta ${i + 1} de 11'));
      }
      expect(cartas.toSet(), hasLength(11), reason: 'dois rótulos idênticos');

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a imagem da carta não fala junto com o rótulo', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      // Antes da correção a mão produzia onze nós de IMAGEM sem rótulo: o foco
      // parava em cada carta e o leitor não dizia nada. Agora quem fala é o nó
      // da carta, e ele é o único.
      //
      // A conferência é RECORTADA à mão de propósito. A mesa tem nós vazios de
      // outras camadas, anteriores a esta OS e fora do assunto dela; exigir a
      // mesa inteira limpa faria este caso reprovar por dívida que ele não abriu
      // — e o jeito de "consertar" seria mexer onde a OS proíbe.
      final mao = areaDaMao(tester);
      final vazios = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => n.label.trim().isEmpty)
          .where((n) => retanguloNaTela(n).overlaps(mao))
          .toList();
      expect(
        vazios,
        isEmpty,
        reason: 'sobrou nó sem rótulo dentro da mão: '
            '${vazios.map(retanguloNaTela).toList()}',
      );
      expect(
        tester.semantics
            .simulatedAccessibilityTraversal()
            .where(ehImagem)
            .where((n) => retanguloNaTela(n).overlaps(mao))
            .toList(),
        isEmpty,
        reason: 'uma imagem da mão voltou a ser um alvo de leitura por si só',
      );

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 2 — PAPEL E ESTADO
  // =========================================================================
  group('papel e estado', () {
    testWidgets('cada carta é um botão habilitado, com uma ação de toque', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final nos = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => kMarcaDeCartaDaMao.hasMatch(n.label))
          .toList();
      expect(nos, hasLength(11));
      for (final no in nos) {
        expect(ehBotao(no), isTrue,
            reason: '"${no.label}" não é um botão');
        expect(estaHabilitado(no), isTrue,
            reason: '"${no.label}" está desabilitada na vez do jogador');
        expect(ofereceToque(no), isTrue,
            reason: '"${no.label}" não oferece toque');
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('selecionar e desselecionar mudam o estado semântico', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      bool estaSelecionada(String rotulo) =>
          estaSelecionado(noComRotulo(tester, rotulo));

      final alvo = cartasNaOrdemDeLeitura(tester)[3];
      expect(estaSelecionada(alvo), isFalse);

      final rects = cartasDaMao(tester);
      final ponto = Offset(rects[3].left + 2, rects[3].center.dy);
      expect(await tocarEm(tester, ponto), <int>{3});
      expect(
        estaSelecionada(alvo),
        isTrue,
        reason: 'a carta foi escolhida e o leitor de tela não soube',
      );

      expect(await tocarEm(tester, ponto), isEmpty);
      expect(estaSelecionada(alvo), isFalse);

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('fora da vez a mão é anunciada como desabilitada', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      // Passar a vez: comprar e descartar. Depois disso os robôs jogam, e
      // enquanto jogam a mão não aceita toque — o que o leitor precisa dizer,
      // em vez de deixar a pessoa tocando numa carta que não responde.
      await tester.tap(find.text('MONTE'));
      await tester.pump(const Duration(milliseconds: 100));
      await tocarEm(tester, cartasDaMao(tester).last.center);
      await tester.tap(find.textContaining('LIXO'));
      await tester.pump(const Duration(milliseconds: 100));

      final nos = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => kMarcaDeCartaDaMao.hasMatch(n.label))
          .toList();
      expect(nos, isNotEmpty);
      for (final no in nos) {
        expect(ehBotao(no), isTrue);
        // `estaDesabilitado`, e não "não está habilitado": a carta tem de dizer
        // que existe e está indisponível. Um nó sem estado de habilitação
        // nenhum também passaria no "não está habilitado", e ele soa para quem
        // ouve como um botão comum que simplesmente não responde.
        expect(
          estaDesabilitado(no),
          isTrue,
          reason: '"${no.label}" não se anuncia indisponível fora da vez',
        );
        expect(ofereceToque(no), isFalse);
      }

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 3 — OS CONTROLES DA MESA
  // =========================================================================
  group('os controles da mesa', () {
    testWidgets('monte, lixo e mortos têm nome e estado', (tester) async {
      await abrirMesaDeTreino(tester);

      final monte = noComRotulo(tester, 'monte, ');
      expect(monte.label, matches(RegExp(r'^monte, \d+ cartas?$')));
      expect(ehBotao(monte), isTrue);
      expect(
        estaHabilitado(monte),
        isTrue,
        reason: 'na vez do jogador, e antes de comprar, o monte está disponível',
      );

      final lixo = noComRotulo(tester, 'lixo');
      expect(lixo.label, startsWith('lixo aberto, '));
      expect(ehBotao(lixo), isTrue);

      expect(noComRotulo(tester, 'morto 1').label, 'morto 1, disponível');
      expect(noComRotulo(tester, 'morto 2').label, 'morto 2, disponível');

      // As tarjas de desenho — "MONTE", "MORTO", "1", "LIXO ABERTO" — não podem
      // voltar como leitura solta ao lado do nome.
      final leitura = ordemDeLeitura(tester);
      for (final tarja in const ['MONTE', 'MORTO', 'LIXO ABERTO', 'LIXO']) {
        expect(leitura, isNot(contains(tarja)),
            reason: 'a tarja "$tarja" está sendo lida junto com o nome');
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('o lixo anuncia a contagem e a carta do topo', (tester) async {
      await abrirMesaDeTreino(tester);

      // No aberto o topo é público, e é com ele que se decide comprar. Depois
      // de um descarte a contagem sobe e o topo passa a ser a carta descartada.
      await tester.tap(find.text('MONTE'));
      await tester.pump(const Duration(milliseconds: 100));
      final antes = noComRotulo(tester, 'lixo').label;

      await tocarEm(tester, cartasDaMao(tester).last.center);
      await tester.tap(find.textContaining('LIXO'));
      await tester.pump(const Duration(milliseconds: 100));

      final depois = noComRotulo(tester, 'lixo').label;
      expect(depois, isNot(antes));
      expect(depois, matches(RegExp(r'^lixo aberto, \d+ cartas?, topo .+$')));

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('chat, expressões e som têm nome, e o som diz o estado', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      for (final nome in const ['chat', 'expressões']) {
        final no = noComRotulo(tester, nome);
        expect(no.label, nome);
        expect(ehBotao(no), isTrue);
        expect(ofereceToque(no), isTrue);
      }

      final som = noComRotulo(tester, 'som');
      expect(som.label, 'som');
      expect(ehBotao(som), isTrue);
      expect(temLigaDesliga(som), isTrue);
      expect(
        estaLigado(som),
        isTrue,
        reason: 'o som começa ligado e o leitor tem de dizer isso',
      );

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        estaLigado(noComRotulo(tester, 'som')),
        isFalse,
        reason: 'o som desligou e o estado anunciado não mudou',
      );

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 4 — A FAIXA EFETIVA DE TOQUE
  // =========================================================================
  group('faixa efetiva de toque', () {
    /// A varredura completa numa superfície, com o piso conferido.
    Future<Varredura> varrerEm(WidgetTester tester, Size superficie) async {
      await abrirMesaDeTreino(tester, superficie: superficie);
      final rects = cartasDaMao(tester);
      final varredura = await medirFaixasEfetivas(tester);
      // ignore: avoid_print
      print(
        'SUPERFÍCIE ${superficie.width ~/ 3}x${superficie.height ~/ 3} pt · '
        'primeira carta em ${rects.first.left.toStringAsFixed(2)} · '
        'largura varrida ${varredura.larguraVarrida.toStringAsFixed(2)} · '
        'faixas ${varredura.faixas} · '
        'mortos ${varredura.pontosMortos.length}',
      );
      return varredura;
    }

    testWidgets('as onze cartas respondem, e nenhuma fica abaixo de 24 pontos',
        (tester) async {
      final varredura = await varrerEm(tester, kSuperficieDaAuditoria);

      expect(
        varredura.faixas.where((f) => f > 0),
        hasLength(11),
        reason: 'alguma carta não respondeu a toque nenhum',
      );
      for (var i = 0; i < varredura.faixas.length; i++) {
        expect(
          varredura.faixas[i],
          greaterThanOrEqualTo(kFaixaMinimaDeToque),
          reason: 'a carta ${i + 1} ficou com ${varredura.faixas[i]} pontos',
        );
      }
      expect(
        varredura.pontosMortos,
        isEmpty,
        reason: 'há pontos da mão em que o toque não pega carta nenhuma',
      );
      // Toda a largura da mão pertence a alguma carta.
      expect(
        varredura.faixas.reduce((a, b) => a + b),
        closeTo(varredura.larguraVarrida, 1.5),
      );

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('o piso vale também na menor superfície produtiva', (
      tester,
    ) async {
      // Em 320 pontos de largura as onze cartas com 24 de faixa pedem mais mão
      // do que cabe na tela. A escolha é declarada e está no código: o piso não
      // cede, e a mão ROLA — que é o que ela já fazia. O que este caso prova é
      // que a rolagem não é desculpa para faixa curta.
      final varredura = await varrerEm(tester, kSuperficieMinima);

      for (var i = 0; i < varredura.faixas.length; i++) {
        expect(
          varredura.faixas[i],
          greaterThanOrEqualTo(kFaixaMinimaDeToque),
          reason: 'a carta ${i + 1} ficou com ${varredura.faixas[i]} pontos '
              'em 320 pontos de largura',
        );
      }
      expect(
        varredura.pontosMortos,
        isEmpty,
        reason: 'há pontos à vista em que o toque não pega carta nenhuma',
      );

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('na menor superfície a mão rola, e o fim dela continua ao dedo',
        (tester) async {
      await abrirMesaDeTreino(tester, superficie: kSuperficieMinima);

      final antes = cartasDaMao(tester);
      final janela = viewportDaMao(tester);
      expect(
        antes.last.right,
        greaterThan(janela.right),
        reason: 'a mão coube inteira — este caso não tem o que provar aqui',
      );

      // Rolar até o fim, do jeito que o dedo rolaria: o arrasto começa SOBRE a
      // mão. Puxar do meio da tela pega o tabuleiro, que não rola.
      await tester.dragFrom(antes.first.center, const Offset(-150, 0));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      final depois = cartasDaMao(tester);
      expect(
        depois.last.right,
        lessThanOrEqualTo(janela.right + 0.5),
        reason: 'rolar não trouxe a última carta para dentro da janela',
      );

      // E ela responde ao toque, com a carta inteira à mostra.
      expect(
        await tocarEm(tester, depois.last.center),
        <int>{depois.length - 1},
      );

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('as faixas anunciadas ao leitor de tela não se sobrepõem', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      // A varredura acima prova o dedo que ENXERGA a carta e mira nela. Quem usa
      // TalkBack navega diferente: arrasta o dedo pela tela e ouve o que passa
      // por baixo, e o que responde ali é o RETÂNGULO DO NÓ, não o detector de
      // gesto. Retângulos empilhados dariam onze alvos por cima uns dos outros —
      // a mesma armadilha da mão antiga, num caminho que a varredura não vê.
      final faixas = tester.semantics
          .simulatedAccessibilityTraversal()
          .where((n) => kMarcaDeCartaDaMao.hasMatch(n.label))
          .map((n) => (rotulo: n.label, area: retanguloNaTela(n)))
          .toList();
      expect(faixas, hasLength(11));

      for (final faixa in faixas) {
        expect(
          faixa.area.width,
          greaterThanOrEqualTo(kFaixaMinimaDeToque),
          reason: '"${faixa.rotulo}" é anunciada com ${faixa.area.width} '
              'pontos de largura',
        );
      }
      for (var i = 0; i < faixas.length; i++) {
        for (var j = i + 1; j < faixas.length; j++) {
          final comum = faixas[i].area.intersect(faixas[j].area);
          expect(
            comum.isEmpty || comum.width <= 0.01,
            isTrue,
            reason: '"${faixas[i].rotulo}" e "${faixas[j].rotulo}" dividem '
                '${comum.width} pontos de tela',
          );
        }
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a última carta não é a única confortável', (tester) async {
      await abrirMesaDeTreino(tester);
      final varredura = await medirFaixasEfetivas(tester);

      // O defeito antigo tinha uma assinatura: dez faixas de 21 e uma de 66. A
      // dispersão entre as dez primeiras é o que denuncia o retorno dele.
      final semAUltima = varredura.faixas.take(10).toList();
      final menor = semAUltima.reduce((a, b) => a < b ? a : b);
      final maior = semAUltima.reduce((a, b) => a > b ? a : b);
      expect(maior - menor, lessThanOrEqualTo(2.0));
      expect(menor, greaterThanOrEqualTo(kFaixaMinimaDeToque));

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('selecionar uma carta não engole a faixa da vizinha', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      // Este é o caso que a correção do desenho sozinha não cobriria: a carta
      // selecionada sobe para o topo da pilha de PINTURA. Se o toque seguisse a
      // pintura, ela passaria a cobrir a vizinha por 66 pontos e a deixaria
      // inalcançável enquanto a seleção durasse.
      final rects = cartasDaMao(tester);
      final ponto = Offset(rects[4].left + 2, rects[4].center.dy);
      expect(await tocarEm(tester, ponto), <int>{4});

      final varredura = await medirFaixasEfetivas(tester);
      // ignore: avoid_print
      print('COM A CARTA 5 SELECIONADA: ${varredura.faixas}');
      for (var i = 0; i < varredura.faixas.length; i++) {
        expect(
          varredura.faixas[i],
          greaterThanOrEqualTo(kFaixaMinimaDeToque),
          reason: 'com a carta 5 escolhida, a carta ${i + 1} ficou com '
              '${varredura.faixas[i]} pontos',
        );
      }

      await encerrarMesaDeTreino(tester);
    });
  });

  // =========================================================================
  // 5 — A ORDEM DE LEITURA
  // =========================================================================
  group('ordem de leitura', () {
    testWidgets('a mão é lida da primeira à última carta', (tester) async {
      await abrirMesaDeTreino(tester);

      final cartas = cartasNaOrdemDeLeitura(tester);
      expect(cartas, hasLength(11));
      for (var i = 0; i < cartas.length; i++) {
        expect(cartas[i], endsWith('carta ${i + 1} de 11'));
      }

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('selecionar, trocar e desfazer não reordenam a leitura', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      final antes = cartasNaOrdemDeLeitura(tester);
      final rects = cartasDaMao(tester);
      Offset naCarta(int i) => Offset(rects[i].left + 2, rects[i].center.dy);

      // Selecionar.
      expect(await tocarEm(tester, naCarta(2)), <int>{2});
      expect(cartasNaOrdemDeLeitura(tester), orderedEquals(antes));

      // Trocar a escolhida.
      expect(await tocarEm(tester, naCarta(7)), <int>{2, 7});
      expect(cartasNaOrdemDeLeitura(tester), orderedEquals(antes));

      // Desfazer as duas.
      await tocarEm(tester, naCarta(2));
      expect(await tocarEm(tester, naCarta(7)), isEmpty);
      expect(cartasNaOrdemDeLeitura(tester), orderedEquals(antes));

      await encerrarMesaDeTreino(tester);
    });

    testWidgets('a ordem de desenho continua mudando — e só ela', (
      tester,
    ) async {
      await abrirMesaDeTreino(tester);

      // A carta escolhida sobe por cima das vizinhas: isso é do jogo e não
      // muda. O que este caso fixa é que a mudança ficou CONTIDA no desenho.
      final desenhoAntes = ordemDeDesenho(tester);
      final leituraAntes = cartasNaOrdemDeLeitura(tester);

      final rects = cartasDaMao(tester);
      await tocarEm(tester, Offset(rects[5].left + 2, rects[5].center.dy));

      expect(ordemDeDesenho(tester), isNot(orderedEquals(desenhoAntes)));
      expect(cartasNaOrdemDeLeitura(tester), orderedEquals(leituraAntes));

      await encerrarMesaDeTreino(tester);
    });
  });
}
