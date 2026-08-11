import 'package:flutter_test/flutter_test.dart';

import '../lib/ranking/ranking_apresentacao.dart';
import '../lib/ranking/ranking_contract.dart';
import '../lib/screens/ranking_screen.dart';
import 'ranking_fixtures.dart';

/// A tradução contrato → view-model. O ponto sensível é o que ela NÃO faz.
void main() {
  group('autoridade: a tela repete, nao recalcula', () {
    test('ordem e posicao saem exatamente como entraram', () {
      // Fonte deliberadamente fora de ordem e com buracos na numeracao: se a
      // camada de apresentacao "corrigisse" alguma coisa, este teste quebra.
      final itens = [
        jogador(42, pontos: 10),
        jogador(3, pontos: 9000),
        jogador(17, pontos: 55),
      ];

      final vm = montarRankingVM(
        escopo: RankingEscopo.global,
        resumo: resumo(),
        itens: itens,
      );

      expect(vm.lista.map((l) => l.posicao).toList(), [42, 3, 17]);
      expect(vm.lista.map((l) => l.pontos).toList(), [10, 9000, 55]);
    });

    test('nao renumera a lista pelo indice', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.global,
        resumo: resumo(),
        itens: [jogador(500), jogador(501)],
      );

      expect(vm.lista.first.posicao, 500);
      expect(vm.lista.last.posicao, 501);
    });

    test('quem sou eu vem da fonte, nao de comparacao de apelido', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.global,
        resumo: resumo(),
        itens: [
          jogador(1, apelido: 'Você', souEu: false),
          jogador(2, apelido: 'Outra pessoa', souEu: true),
        ],
      );

      expect(vm.lista.first.ehVoce, isFalse);
      expect(vm.lista.last.ehVoce, isTrue);
    });
  });

  group('liga e divisao vem do contrato', () {
    test('o rotulo da liga da linha e o publicado', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.temporada,
        resumo: resumo(),
        itens: [jogador(1, liga: 'Imperial II')],
      );

      expect(vm.lista.single.liga, 'Imperial II');
    });

    test('a escada de ligas e a atual saem do resumo', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.temporada,
        resumo: resumo(escadaLigas: escadaDemo),
        itens: const [],
      );

      expect(vm.escadaLigas.map((l) => l.nome).toList(),
          ['Bronze', 'Prata', 'Diamante']);
      expect(vm.escadaLigas.where((l) => l.atual).map((l) => l.nome).single,
          'Diamante');
    });

    test('divisao ausente na fonte fica ausente na tela', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.amigos,
        resumo: resumo(divisao: null),
        itens: const [],
      );

      expect(vm.divisao, isNull);
    });

    test('divisao publicada atravessa campo a campo', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.temporada,
        resumo: resumo(divisao: divisaoDemo),
        itens: const [],
      );

      expect(vm.divisao!.nome, 'Diamante III');
      expect(vm.divisao!.faltamPontos, 260);
      expect(vm.divisao!.posicaoLiga, 12);
      expect(vm.divisao!.proximaDivisao, 'Diamante II');
    });
  });

  group('podio', () {
    test('a moldura sai da posicao recebida', () {
      final vm = montarRankingVM(
        escopo: RankingEscopo.temporada,
        resumo: resumo(podio: [jogador(1), jogador(2), jogador(3)]),
        itens: const [],
      );

      expect(vm.podio.map((p) => p.moldura).toList(), [
        'assets/ranking/podio_ouro.webp',
        'assets/ranking/podio_prata.webp',
        'assets/ranking/podio_bronze.webp',
      ]);
    });
  });

  group('abas e escopos sao a mesma coisa vista dos dois lados', () {
    test('ida e volta preserva', () {
      for (final escopo in RankingEscopo.values) {
        expect(escopoDaAba(abaDoEscopo(escopo)), escopo);
      }
      for (final aba in RankingAba.values) {
        expect(abaDoEscopo(escopoDaAba(aba)), aba);
      }
    });
  });

  group('posicao -> identificador publico', () {
    test('acha na lista e no podio', () {
      final r = resumo(podio: [jogador(1, id: 'uid-topo')]);
      final itens = [jogador(12, id: 'uid-doze')];

      expect(idNaPosicao(1, resumo: r, itens: itens), 'uid-topo');
      expect(idNaPosicao(12, resumo: r, itens: itens), 'uid-doze');
    });

    test('posicao desconhecida nao resolve', () {
      expect(
        idNaPosicao(99, resumo: resumo(), itens: [jogador(1)]),
        isNull,
      );
    });

    test('fonte sem id publicado nao resolve', () {
      expect(
        idNaPosicao(1, resumo: resumo(), itens: [jogador(1, id: '')]),
        isNull,
        reason: 'posicao nunca pode virar chave de navegacao',
      );
    });
  });
}
