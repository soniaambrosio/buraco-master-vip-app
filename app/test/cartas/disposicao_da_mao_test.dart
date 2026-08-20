// disposicao_da_mao_test.dart — a regra da mão, sem tela nenhuma.
//
// ---------------------------------------------------------------------------
// POR QUE ESTE ARQUIVO EXISTE AO LADO DA SUÍTE DE WIDGET
// ---------------------------------------------------------------------------
//
// A suíte de widget prova o que ACONTECE na mesa: o dedo toca e a carta certa
// responde, o leitor de tela lê na ordem certa, a obrigação do lixo sobrevive a
// uma reorganização. Ela é cara — monta a mesa, espera os robôs, toca ponto a
// ponto — e por isso cobre poucos tamanhos de tela.
//
// A regra, porém, tem de valer em TODA largura, inclusive nas que nenhum
// aparelho tem. Aqui ela é exercitada como aritmética: nada monta, nada anima,
// e varrer cinquenta larguras custa milissegundos. É também o arquivo que a OS
// 33 vai ler quando levar esta mão para a Pública, a VIP/Ranqueada e a Privada.
//
// OS NÚMEROS DESTE ARQUIVO SÃO LITERAIS, DE PROPÓSITO. Importar `kPisoDeToque`
// da produção faria o piso do teste andar junto com o da produção — e a mutação
// que baixasse o piso passaria despercebida, porque as duas pontas teriam
// mudado ao mesmo tempo. 48 está escrito aqui porque 48 é o contrato.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/cartas/disposicao_da_mao.dart';

/// O piso de toque exigido pela OS 29-C1, escrito à mão.
const double kPisoExigido = 48.0;

/// A largura desenhada da carta, escrita à mão pelo mesmo motivo.
const double kCartaLarga = 66.0;
const double kCartaAlta = 100.0;

/// A largura útil da mão numa tela de [pontos] de largura.
///
/// Tira as bordas do tabuleiro (13) e o respiro dos dois lados (2 × 14), que é
/// a mesma conta que `_board` faz antes de chamar o módulo.
double utilEm(double pontos) => pontos - 13 - 2 * 14;

void main() {
  group('o passo é sempre o piso', () {
    test('não cede em largura nenhuma, de 240 a 1200 pontos', () {
      for (var tela = 240.0; tela <= 1200; tela += 10) {
        final d = DisposicaoDaMao.calcular(
          cartas: 11,
          larguraDisponivel: utilEm(tela),
        );
        expect(
          d.passo,
          kPisoExigido,
          reason: 'em $tela pontos o passo virou ${d.passo}',
        );
      }
    });

    test('não cresce além do piso quando sobra largura', () {
      final d = DisposicaoDaMao.calcular(
        cartas: 3,
        larguraDisponivel: 4000,
      );
      expect(d.passo, kPisoExigido);
      expect(d.fileiras, 1);
    });
  });

  group('uma fileira quando cabe, duas quando não cabe', () {
    test('onze cartas não cabem em 320, 360 nem 400', () {
      for (final tela in <double>[320, 360, 400]) {
        final d = DisposicaoDaMao.calcular(
          cartas: 11,
          larguraDisponivel: utilEm(tela),
        );
        expect(
          d.fileiras,
          2,
          reason: 'em $tela pontos a mão ficou em ${d.fileiras} fileira(s)',
        );
        // A metade maior fica em cima: a de baixo é a que aparece inteira.
        expect(d.cartasNaPrimeiraFileira, 6);
      }
    });

    test('onze cartas cabem numa fileira quando há 587 pontos de mão', () {
      // 66 + 10 × 48 = 546 de mão, mais bordas e respiro.
      final d = DisposicaoDaMao.calcular(
        cartas: 11,
        larguraDisponivel: utilEm(600),
      );
      expect(d.fileiras, 1);
      expect(d.largura, closeTo(546, 0.01));
    });

    test('a fronteira entre uma e duas fileiras é exata', () {
      const cartas = 7;
      final exata = DisposicaoDaMao.larguraDeUmaFileira(cartas);
      expect(exata, closeTo(66 + 6 * 48, 0.01));

      expect(
        DisposicaoDaMao.calcular(cartas: cartas, larguraDisponivel: exata)
            .fileiras,
        1,
        reason: 'na largura exata a mão ainda cabe numa fileira',
      );
      expect(
        DisposicaoDaMao.calcular(
          cartas: cartas,
          larguraDisponivel: exata - 0.5,
        ).fileiras,
        2,
        reason: 'meio ponto a menos e a segunda fileira tem de nascer',
      );
    });

    test('uma carta, e nenhuma carta, não viram duas fileiras', () {
      expect(
        DisposicaoDaMao.calcular(cartas: 1, larguraDisponivel: 10).fileiras,
        1,
      );
      final vazia = DisposicaoDaMao.calcular(cartas: 0, larguraDisponivel: 300);
      expect(vazia.faixas, isEmpty);
      expect(vazia.fileiras, 1);
    });
  });

  group('o piso vale para TODA carta, nos dois eixos', () {
    test('de 1 a 22 cartas, em 320, 360 e 400 pontos', () {
      for (final tela in <double>[320, 360, 400]) {
        for (var cartas = 1; cartas <= 22; cartas++) {
          final d = DisposicaoDaMao.calcular(
            cartas: cartas,
            larguraDisponivel: utilEm(tela),
          );
          expect(d.faixas, hasLength(cartas));
          for (final f in d.faixas) {
            expect(
              f.cumpre(kPisoExigido),
              isTrue,
              reason: 'em $tela pontos, com $cartas cartas, a carta '
                  '${f.indice + 1} ficou ${f.largura} x ${f.altura}',
            );
          }
          expect(d.menorFaixa, greaterThanOrEqualTo(kPisoExigido));
        }
      }
    });

    test('a última de cada fileira aparece inteira', () {
      final d = DisposicaoDaMao.calcular(
        cartas: 11,
        larguraDisponivel: utilEm(360),
      );
      final ultimaDeCima = d.faixas.lastWhere((f) => f.fileira == 0);
      final ultimaDeBaixo = d.faixas.lastWhere((f) => f.fileira == 1);
      expect(ultimaDeCima.largura, closeTo(kCartaLarga, 0.01));
      expect(ultimaDeBaixo.largura, closeTo(kCartaLarga, 0.01));
      // E as demais têm exatamente o passo.
      for (final f in d.faixas) {
        if (f != ultimaDeCima && f != ultimaDeBaixo) {
          expect(f.largura, closeTo(kPisoExigido, 0.01));
        }
      }
    });
  });

  group('faixa nenhuma invade a vizinha', () {
    test('nem dentro da fileira, nem entre as duas, de 1 a 22 cartas', () {
      for (final tela in <double>[320, 360, 400, 600]) {
        for (var cartas = 2; cartas <= 22; cartas++) {
          final d = DisposicaoDaMao.calcular(
            cartas: cartas,
            larguraDisponivel: utilEm(tela),
          );
          for (var i = 0; i < d.faixas.length; i++) {
            for (var j = i + 1; j < d.faixas.length; j++) {
              expect(
                d.faixas[i].colideCom(d.faixas[j]),
                isFalse,
                reason: 'em $tela pontos, com $cartas cartas, as faixas '
                    '${i + 1} e ${j + 1} se sobrepõem',
              );
            }
          }
        }
      }
    });
  });

  group('a ordem é a lógica da mão', () {
    test('índices em sequência, e a fileira de cima vem primeiro', () {
      final d = DisposicaoDaMao.calcular(
        cartas: 11,
        larguraDisponivel: utilEm(360),
      );
      for (var i = 0; i < d.faixas.length; i++) {
        expect(d.faixas[i].indice, i);
      }
      final fileiras = d.faixas.map((f) => f.fileira).toList();
      expect(fileiras, orderedEquals(<int>[0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1]));
      // Dentro de cada fileira, a esquerda cresce.
      for (var i = 1; i < d.faixas.length; i++) {
        if (d.faixas[i].fileira == d.faixas[i - 1].fileira) {
          expect(d.faixas[i].esquerda, greaterThan(d.faixas[i - 1].esquerda));
        } else {
          expect(d.faixas[i].esquerda, 0);
        }
      }
    });
  });

  group('a altura pedida é a altura entregue', () {
    test('uma fileira reserva a elevação, duas reservam mais um piso', () {
      final uma = DisposicaoDaMao.calcular(
        cartas: 3,
        larguraDisponivel: utilEm(600),
      );
      final duas = DisposicaoDaMao.calcular(
        cartas: 11,
        larguraDisponivel: utilEm(360),
      );
      expect(uma.fileiras, 1);
      expect(duas.fileiras, 2);
      expect(duas.altura - uma.altura, closeTo(kPisoExigido, 0.01));
      // E a última faixa termina exatamente na base da mão: nem sobra, nem
      // vaza.
      expect(duas.faixas.last.base, closeTo(duas.altura, 0.01));
      expect(uma.faixas.last.base, closeTo(uma.altura, 0.01));
    });

    test('`alturaNecessaria` e `calcular().altura` dão o mesmo número', () {
      for (final tela in <double>[320, 360, 400, 600, 900]) {
        for (var cartas = 0; cartas <= 22; cartas++) {
          expect(
            DisposicaoDaMao.alturaNecessaria(
              cartas: cartas,
              larguraDisponivel: utilEm(tela),
            ),
            closeTo(
              DisposicaoDaMao.calcular(
                cartas: cartas,
                larguraDisponivel: utilEm(tela),
              ).altura,
              0.001,
            ),
            reason: 'a mesa reservaria uma altura e a mão desenharia outra '
                '($cartas cartas em $tela pontos)',
          );
        }
      }
    });
  });

  group('o desenho não é a faixa', () {
    test('a carta de cima é desenhada inteira e tocada só no que aparece', () {
      final d = DisposicaoDaMao.calcular(
        cartas: 11,
        larguraDisponivel: utilEm(360),
      );
      final deCima = d.faixas.first;
      final desenho = d.posicaoDeDesenho(0);
      // A faixa da carta de cima é curta — é o que a de baixo deixa à mostra —,
      // e o desenho dela continua sendo a carta inteira, que vaza por baixo.
      expect(deCima.altura, lessThan(kCartaAlta));
      expect(deCima.altura, greaterThanOrEqualTo(kPisoExigido));
      expect(desenho.topo + kCartaAlta, greaterThan(deCima.base));
      // A de baixo é desenhada abaixo da faixa da de cima.
      expect(d.posicaoDeDesenho(6).topo, closeTo(deCima.base, 0.01));
    });
  });
}
