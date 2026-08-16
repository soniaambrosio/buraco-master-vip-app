import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/hall/hall_contract.dart';
import '../lib/pages/hall_page.dart';
import '../lib/pages/ranking_page.dart';
import '../lib/ranking/ranking_contract.dart';
import '../lib/screens/hall_screen.dart';
import '../lib/screens/ranking_screen.dart';
import 'ranking_fixtures.dart';
import 'superficie_de_teste.dart';

/// Regressão visual da OS §17.
///
/// **Este arquivo não filtra overflow de propósito.** Os outros testes de
/// widget chamam `ignorarOverflowDaFonteDeTeste()` porque a fonte substituta do
/// runner infla o texto; aqui não, porque o que se está medindo é justamente
/// estouro. Se alguma composição passar a estourar em 390×844 ou 320×640, o
/// teste quebra.
void main() {
  const superficies = <String, Size>{
    'telefone comum (390x844)': Size(390, 844),
    'telefone pequeno (320x640)': Size(320, 640),
  };

  /// Conteúdo hostil de propósito: nome enorme, posição de 1, 2, 3 e 5
  /// dígitos, pontuação grande (que a tela formata com separador) e selo.
  final listaHostil = [
    jogador(
      1,
      apelido: 'Maria Aparecida da Conceição Fernandes de Albuquerque',
      liga: 'Imperial',
      pontos: 1234567,
      direcao: RankingDirecao.subiu,
      delta: 12,
      selo: 'assets/ranking/selos/campeao_do_dia.webp',
    ),
    jogador(42, apelido: 'Zé', liga: 'Ouro', pontos: 900),
    jogador(837, apelido: 'Nome Médio Aqui', liga: 'Platina', pontos: 12345),
    jogador(
      10248,
      apelido: 'Você',
      liga: 'Diamante III',
      pontos: 7,
      souEu: true,
      selo: 'assets/ranking/selos/top_1.webp',
    ),
  ];

  final podioHostil = [
    jogador(1, apelido: 'Maria Aparecida da Conceição', pontos: 502000),
    jogador(2, apelido: 'Marina', pontos: 4180),
    jogador(3, apelido: 'Beto', pontos: 3910),
  ];

  Future<RankingFonteFake> abrirRanking(
    WidgetTester tester,
    Size superficie,
  ) async {
    usarTelefoneRetrato(tester, logico: superficie);
    final fonte = RankingFonteFake();
    await tester.pumpWidget(MaterialApp(home: RankingPage(service: fonte)));
    return fonte;
  }

  superficies.forEach((rotulo, superficie) {
    group(rotulo, () {
      testWidgets('cabecalho, podio, lista, escada e rolagem cabem',
          (tester) async {
        final fonte = await abrirRanking(tester, superficie);
        fonte.aberturas.first.complete(
          abertura(
            cabecalho: resumo(
              faixaTempo: 'Temporada acaba em 129d 23h',
              divisao: divisaoDemo,
              podio: podioHostil,
              escadaLigas: escadaDemo,
            ),
            itens: listaHostil,
            cursorProxima: 'c1',
          ),
        );
        await tester.pumpAndSettle();

        // Cabeçalho, pódio, lista, botão de paginação e escada, todos juntos.
        // “Ranking” aparece duas vezes: título do topo e rótulo da nav de baixo.
        expect(find.text('Ranking'), findsNWidgets(2));
        expect(find.text('Hall dos Imortais'), findsOneWidget);
        expect(find.text('Temporada'), findsOneWidget);
        expect(find.text('SUAS LIGAS'), findsOneWidget);
        expect(find.text('Carregar mais'), findsOneWidget);

        // Posições de 1, 2, 3 e 5 dígitos convivem na mesma coluna estreita.
        expect(find.text('1'), findsWidgets);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('837'), findsOneWidget);
        expect(find.text('10248'), findsOneWidget);

        // A tela inteira rola até o fim sem estourar.
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('esqueleto de carregamento cabe', (tester) async {
        await abrirRanking(tester, superficie);
        await tester.pump();

        expect(
          tester.widget<RankingScreen>(find.byType(RankingScreen)).estado,
          RankingEstado.carregando,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('estado vazio cabe', (tester) async {
        final fonte = await abrirRanking(tester, superficie);
        fonte.aberturas.first.complete(abertura(itens: const [], fim: true));
        await tester.pumpAndSettle();

        expect(find.text('Ainda sem ninguém aqui'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('erro com mensagem longa cabe', (tester) async {
        final fonte = await abrirRanking(tester, superficie);
        fonte.aberturas.first.completeError(
          const RankingIndisponivel(
            'Uma mensagem de erro razoavelmente longa, do jeito que uma fonte '
            'de verdade costuma devolver quando alguma coisa sai do lugar.',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tentar de novo'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('hall com nome extenso cabe', (tester) async {
        usarTelefoneRetrato(tester, logico: superficie);
        final fonte = HallFonteFake();
        await tester.pumpWidget(MaterialApp(home: HallPage(service: fonte)));
        fonte.consultas.first.complete(
          HallQuadro(honrados: [
            honrado(HallCategoria.campeaoHoje,
                nome: 'Maria Aparecida da Conceição Fernandes'),
            honrado(HallCategoria.melhorDupla,
                nome: 'Maria Aparecida & Cláudia Regina', avatar2: '🐰'),
            honrado(HallCategoria.maiorSequencia, nome: 'Beto'),
            honrado(HallCategoria.reiRainhaSemana, nome: 'Marina'),
            honrado(HallCategoria.lendaMes, nome: 'Ricardo'),
          ]),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<HallScreen>(find.byType(HallScreen)).estado,
          HallEstado.disponivel,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('hall indisponivel cabe', (tester) async {
        usarTelefoneRetrato(tester, logico: superficie);
        await tester.pumpWidget(const MaterialApp(home: HallPage()));
        await tester.pumpAndSettle();

        expect(find.text('Hall indisponível agora'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
