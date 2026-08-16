import 'package:flutter_test/flutter_test.dart';

import '../lib/ranking/ranking_contract.dart';
import '../lib/ranking/ranking_paginacao.dart';
import 'ranking_fixtures.dart';

/// As regras de paginação da OS §10/§11, medidas sem widget nenhum no meio.
void main() {
  late RankingFonteFake fonte;
  late RankingPaginador paginador;

  setUp(() {
    fonte = RankingFonteFake();
    paginador = RankingPaginador(
      service: fonte,
      escopo: RankingEscopo.temporada,
    );
  });

  test('antes da resposta fica carregando, sem inventar conteudo', () {
    paginador.abrir();

    expect(paginador.fase, RankingFase.carregando);
    expect(paginador.itens, isEmpty);
    expect(paginador.resumo, isNull);
  });

  test('abrir duas vezes nao dispara duas buscas', () async {
    paginador.abrir();
    paginador.abrir();

    expect(fonte.aberturas.length, 1);

    fonte.aberturas.first.complete(abertura(itens: [jogador(1)]));
    await Future<void>.value();

    // Voltar para a tela ja carregada tambem nao rebusca nem duplica.
    await paginador.abrir();
    expect(fonte.aberturas.length, 1);
    expect(paginador.itens.length, 1);
  });

  test('lista carregada mantem a ordem de chegada', () async {
    paginador.abrir();
    fonte.aberturas.first.complete(
      abertura(itens: [jogador(7), jogador(3), jogador(91)], fim: true),
    );
    await Future<void>.value();

    expect(paginador.fase, RankingFase.pronto);
    expect(
      paginador.itens.map((j) => j.posicao).toList(),
      [7, 3, 91],
      reason: 'o paginador nao pode reordenar o que a fonte publicou',
    );
  });

  test('fonte sem ninguem vira estado vazio, e nao erro', () async {
    paginador.abrir();
    fonte.aberturas.first.complete(abertura(itens: const [], fim: true));
    await Future<void>.value();

    expect(paginador.fase, RankingFase.vazio);
    expect(paginador.itens, isEmpty);
  });

  test('falha na abertura vira erro com o motivo da fonte', () async {
    paginador.abrir();
    fonte.aberturas.first
        .completeError(const RankingIndisponivel('fonte fora do ar'));
    await Future<void>.value();

    expect(paginador.fase, RankingFase.erro);
    expect(paginador.mensagemErro, 'fonte fora do ar');
  });

  test('tentar de novo depois do erro refaz a busca e recupera', () async {
    paginador.abrir();
    fonte.aberturas.first
        .completeError(const RankingIndisponivel('fonte fora do ar'));
    await Future<void>.value();
    expect(paginador.fase, RankingFase.erro);

    paginador.recarregar();
    expect(fonte.aberturas.length, 2);
    fonte.aberturas.last.complete(abertura(itens: [jogador(1)], fim: true));
    await Future<void>.value();

    expect(paginador.fase, RankingFase.pronto);
    expect(paginador.mensagemErro, isNull);
    expect(paginador.itens.length, 1);
  });

  test('paginacao acumula sem repetir jogador entre paginas', () async {
    paginador.abrir();
    fonte.aberturas.first.complete(
      abertura(itens: [jogador(1), jogador(2)], cursorProxima: 'c1'),
    );
    await Future<void>.value();
    expect(paginador.temMais, isTrue);

    paginador.carregarMais();
    // A fonte repete o jogador 2 na virada da pagina - acontece quando alguem
    // sobe de posicao entre uma consulta e outra.
    fonte.paginacoes.first.complete(
      pagina([jogador(2), jogador(3)], cursorProxima: 'c2'),
    );
    await Future<void>.value();

    expect(paginador.itens.map((j) => j.posicao).toList(), [1, 2, 3]);
    expect(fonte.cursoresPedidos, ['c1']);
  });

  test('carregar mais duas vezes seguidas busca uma pagina so', () async {
    paginador.abrir();
    fonte.aberturas.first
        .complete(abertura(itens: [jogador(1)], cursorProxima: 'c1'));
    await Future<void>.value();

    paginador.carregarMais();
    paginador.carregarMais();
    paginador.carregarMais();

    expect(fonte.paginacoes.length, 1);
  });

  test('fim de lista reconhecido: sem cursor, sem mais busca', () async {
    paginador.abrir();
    fonte.aberturas.first
        .complete(abertura(itens: [jogador(1)], cursorProxima: 'c1'));
    await Future<void>.value();

    paginador.carregarMais();
    fonte.paginacoes.first.complete(pagina([jogador(2)], fim: true));
    await Future<void>.value();

    expect(paginador.temMais, isFalse);
    await paginador.carregarMais();
    expect(fonte.paginacoes.length, 1);
  });

  test('cursor nulo tambem encerra, mesmo sem a fonte marcar fim', () async {
    paginador.abrir();
    fonte.aberturas.first.complete(abertura(itens: [jogador(1)]));
    await Future<void>.value();

    expect(paginador.temMais, isFalse);
  });

  test('erro numa pagina posterior nao apaga o que ja veio', () async {
    paginador.abrir();
    fonte.aberturas.first.complete(
      abertura(itens: [jogador(1), jogador(2)], cursorProxima: 'c1'),
    );
    await Future<void>.value();

    paginador.carregarMais();
    fonte.paginacoes.first
        .completeError(const RankingIndisponivel('caiu no meio'));
    await Future<void>.value();

    expect(paginador.fase, RankingFase.pronto);
    expect(paginador.itens.length, 2);
    expect(paginador.mensagemErro, isNull);
    expect(paginador.erroDePagina, 'caiu no meio');

    // E tentar de novo repete a MESMA pagina, com o mesmo cursor.
    paginador.carregarMais();
    expect(fonte.cursoresPedidos, ['c1', 'c1']);
  });

  test('refresh substitui a lista em vez de concatenar', () async {
    paginador.abrir();
    fonte.aberturas.first.complete(
      abertura(itens: [jogador(1), jogador(2)], cursorProxima: 'c1'),
    );
    await Future<void>.value();
    paginador.carregarMais();
    fonte.paginacoes.first.complete(pagina([jogador(3)], fim: true));
    await Future<void>.value();
    expect(paginador.itens.length, 3);

    paginador.recarregar();
    fonte.aberturas.last.complete(
      abertura(itens: [jogador(1), jogador(2), jogador(3)], fim: true),
    );
    await Future<void>.value();

    expect(
      paginador.itens.map((j) => j.posicao).toList(),
      [1, 2, 3],
      reason: 'refresh nao pode duplicar quem ja estava na lista',
    );
  });

  test('resposta que chega depois do descarte e ignorada', () async {
    paginador.abrir();
    paginador.descartar();

    fonte.aberturas.first.complete(abertura(itens: [jogador(1)], fim: true));
    await Future<void>.value();

    expect(paginador.itens, isEmpty);
    expect(paginador.fase, RankingFase.carregando,
        reason: 'estado de tela descartada nao muda mais');
  });

  test('descarte impede busca nova', () async {
    paginador.descartar();

    await paginador.abrir();
    await paginador.recarregar();
    await paginador.carregarMais();

    expect(fonte.aberturas, isEmpty);
    expect(fonte.paginacoes, isEmpty);
  });

  test('resposta de um refresh antigo nao volta por cima do novo', () async {
    paginador.abrir();
    fonte.aberturas.first
        .complete(abertura(itens: [jogador(1)], cursorProxima: 'c1'));
    await Future<void>.value();

    paginador.recarregar(); // gera a abertura #2
    paginador.recarregar(); // gera a abertura #3
    expect(fonte.aberturas.length, 3);

    fonte.aberturas[2].complete(abertura(itens: [jogador(9)], fim: true));
    await Future<void>.value();
    fonte.aberturas[1].complete(abertura(itens: [jogador(5)], fim: true));
    await Future<void>.value();

    expect(paginador.itens.single.posicao, 9,
        reason: 'a resposta atrasada do refresh anterior nao pode assumir');
  });
}
