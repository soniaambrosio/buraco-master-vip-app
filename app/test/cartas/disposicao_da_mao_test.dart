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
//
// ---------------------------------------------------------------------------
// E POR QUE CADA LAÇO CONTA QUANTAS VEZES RODOU
// ---------------------------------------------------------------------------
//
// A força deste arquivo está nos laços: é varrendo noventa e sete larguras e
// vinte e duas quantidades de carta que ele diz alguma coisa que a suíte de
// widget não diz. E era exatamente aí que ele mentia.
//
// A OS 29-R1 injetou a mutação de ESVAZIAR todos os laços de largura, e os
// treze casos continuaram VERDES: um laço que não roda nenhuma volta não
// reprova nada, porque afirmação nenhuma chega a ser feita. O arquivo passava a
// provar o vazio e continuava contando como prova.
//
// Cada caso paramétrico agora conta as voltas e confere a CONTAGEM, que é uma
// afirmação que o laço vazio não consegue satisfazer. E, como segunda rede, o
// censo do fim do arquivo confere quantas larguras DISTINTAS o conjunto tocou —
// é ele que pega a troca de um cenário por uma repetição do vizinho, que os
// contadores locais deixariam passar.

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

/// Toda largura que este arquivo levou ao módulo, e toda quantidade de cartas.
///
/// O conjunto é global de propósito: o censo do fim afirma sobre o ARQUIVO
/// inteiro, e não sobre um caso.
final Set<double> largurasExercitadas = <double>{};
final Set<int> quantidadesExercitadas = <int>{};

/// O par `cartas @ largura` de cada chamada.
///
/// A largura sozinha não distingue os cenários: a varredura de 240 a 1200
/// passa por 320, 360, 400, 600 e 900, então trocar uma dessas telas por uma
/// repetição da vizinha em qualquer outro laço não muda o conjunto de larguras.
/// O PAR muda — a varredura só usa onze cartas, e os outros laços varrem de
/// zero a vinte e duas.
final Set<String> paresExercitados = <String>{};
int chamadasAoModulo = 0;

/// A única porta deste arquivo para o módulo — e é por ela passar em todo caso
/// que o censo do fim consegue afirmar sobre o conjunto.
DisposicaoDaMao calcular({
  required int cartas,
  required double larguraDisponivel,
}) {
  largurasExercitadas.add(larguraDisponivel);
  quantidadesExercitadas.add(cartas);
  paresExercitados.add('$cartas@$larguraDisponivel');
  chamadasAoModulo++;
  return DisposicaoDaMao.calcular(
    cartas: cartas,
    larguraDisponivel: larguraDisponivel,
  );
}

void main() {
  group('o passo é sempre o piso', () {
    test('não cede em largura nenhuma, de 240 a 1200 pontos', () {
      var voltas = 0;
      for (var tela = 240.0; tela <= 1200; tela += 10) {
        final d = calcular(cartas: 11, larguraDisponivel: utilEm(tela));
        expect(
          d.passo,
          kPisoExigido,
          reason: 'em $tela pontos o passo virou ${d.passo}',
        );
        voltas++;
      }
      // De 240 a 1200 de dez em dez são 97 larguras. Sem esta conferência, um
      // laço que não roda nenhuma volta sai verde.
      expect(
        voltas,
        97,
        reason: 'a varredura percorreu $voltas larguras, e não 97',
      );
    });

    test('não cresce além do piso quando sobra largura', () {
      final d = calcular(cartas: 3, larguraDisponivel: 4000);
      expect(d.passo, kPisoExigido);
      expect(d.fileiras, 1);
    });
  });

  group('uma fileira quando cabe, duas quando não cabe', () {
    test('onze cartas não cabem em 320, 360 nem 400', () {
      // A lista sai do `for` para poder ser CONFERIDA. Contar as voltas pega o
      // laço esvaziado; só a conferência de telas distintas pega a troca de uma
      // delas por uma repetição da vizinha, que mantém a contagem e perde o
      // cenário.
      const telas = <double>[320, 360, 400];
      expect(telas.toSet(), hasLength(3),
          reason: 'a lista deixou de ter três telas DISTINTAS');
      var voltas = 0;
      for (final tela in telas) {
        final d = calcular(cartas: 11, larguraDisponivel: utilEm(tela));
        expect(
          d.fileiras,
          2,
          reason: 'em $tela pontos a mão ficou em ${d.fileiras} fileira(s)',
        );
        // A metade maior fica em cima: a de baixo é a que aparece inteira.
        expect(d.cartasNaPrimeiraFileira, 6);
        voltas++;
      }
      expect(voltas, 3, reason: 'faltou uma das três telas nomeadas pela OS');
    });

    test('onze cartas cabem numa fileira quando há 587 pontos de mão', () {
      // 66 + 10 × 48 = 546 de mão, mais bordas e respiro.
      final d = calcular(cartas: 11, larguraDisponivel: utilEm(600));
      expect(d.fileiras, 1);
      expect(d.largura, closeTo(546, 0.01));
    });

    test('a fronteira entre uma e duas fileiras é exata', () {
      const cartas = 7;
      final exata = DisposicaoDaMao.larguraDeUmaFileira(cartas);
      expect(exata, closeTo(66 + 6 * 48, 0.01));

      expect(
        calcular(cartas: cartas, larguraDisponivel: exata).fileiras,
        1,
        reason: 'na largura exata a mão ainda cabe numa fileira',
      );
      expect(
        calcular(cartas: cartas, larguraDisponivel: exata - 0.5).fileiras,
        2,
        reason: 'meio ponto a menos e a segunda fileira tem de nascer',
      );
    });

    test('uma carta, e nenhuma carta, não viram duas fileiras', () {
      expect(calcular(cartas: 1, larguraDisponivel: 10).fileiras, 1);
      final vazia = calcular(cartas: 0, larguraDisponivel: 300);
      expect(vazia.faixas, isEmpty);
      expect(vazia.fileiras, 1);
    });
  });

  group('o piso vale para TODA carta, nos dois eixos', () {
    test('de 1 a 22 cartas, em 320, 360 e 400 pontos', () {
      const telas = <double>[320, 360, 400];
      expect(telas.toSet(), hasLength(3),
          reason: 'a lista deixou de ter três telas DISTINTAS');
      var voltas = 0;
      for (final tela in telas) {
        for (var cartas = 1; cartas <= 22; cartas++) {
          final d = calcular(cartas: cartas, larguraDisponivel: utilEm(tela));
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
          voltas++;
        }
      }
      expect(
        voltas,
        3 * 22,
        reason: 'o piso foi conferido em $voltas combinações, e não em 66',
      );
    });

    test('a última de cada fileira aparece inteira', () {
      final d = calcular(cartas: 11, larguraDisponivel: utilEm(360));
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
      const telas = <double>[320, 360, 400, 600];
      expect(telas.toSet(), hasLength(4),
          reason: 'a lista deixou de ter quatro telas DISTINTAS');
      var voltas = 0;
      for (final tela in telas) {
        for (var cartas = 2; cartas <= 22; cartas++) {
          final d = calcular(cartas: cartas, larguraDisponivel: utilEm(tela));
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
          voltas++;
        }
      }
      expect(
        voltas,
        4 * 21,
        reason: 'a colisão foi conferida em $voltas combinações, e não em 84',
      );
    });
  });

  group('a ordem é a lógica da mão', () {
    test('índices em sequência, e a fileira de cima vem primeiro', () {
      final d = calcular(cartas: 11, larguraDisponivel: utilEm(360));
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
      final uma = calcular(cartas: 3, larguraDisponivel: utilEm(600));
      final duas = calcular(cartas: 11, larguraDisponivel: utilEm(360));
      expect(uma.fileiras, 1);
      expect(duas.fileiras, 2);
      expect(duas.altura - uma.altura, closeTo(kPisoExigido, 0.01));
      // E a última faixa termina exatamente na base da mão: nem sobra, nem
      // vaza.
      expect(duas.faixas.last.base, closeTo(duas.altura, 0.01));
      expect(uma.faixas.last.base, closeTo(uma.altura, 0.01));
    });

    test('`alturaNecessaria` e `calcular().altura` dão o mesmo número', () {
      const telas = <double>[320, 360, 400, 600, 900];
      expect(telas.toSet(), hasLength(5),
          reason: 'a lista deixou de ter cinco telas DISTINTAS');
      var voltas = 0;
      for (final tela in telas) {
        for (var cartas = 0; cartas <= 22; cartas++) {
          expect(
            DisposicaoDaMao.alturaNecessaria(
              cartas: cartas,
              larguraDisponivel: utilEm(tela),
            ),
            closeTo(
              calcular(cartas: cartas, larguraDisponivel: utilEm(tela)).altura,
              0.001,
            ),
            reason: 'a mesa reservaria uma altura e a mão desenharia outra '
                '($cartas cartas em $tela pontos)',
          );
          voltas++;
        }
      }
      expect(
        voltas,
        5 * 23,
        reason: 'a altura foi conferida em $voltas combinações, e não em 115',
      );
    });
  });

  group('o desenho não é a faixa', () {
    test('a carta de cima é desenhada inteira e tocada só no que aparece', () {
      final d = calcular(cartas: 11, larguraDisponivel: utilEm(360));
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

  // =========================================================================
  // O CENSO — A SEGUNDA REDE, E A ÚNICA QUE OLHA O ARQUIVO INTEIRO
  // =========================================================================
  //
  // Os contadores de cada caso pegam o laço esvaziado. Não pegam a troca de um
  // cenário por outro igual: uma lista de telas com 320, 360 e 360 mantém as
  // três voltas e cobre duas larguras. Quem pega isso é a contagem de larguras
  // DISTINTAS.
  //
  // Este caso depende de todos os anteriores terem rodado, e é assim de
  // propósito: ele é o fecho do arquivo, não um caso independente. Rodar um caso
  // isolado por nome deixa o censo sem o que contar — e o portão, que roda o
  // arquivo inteiro, é quem manda.
  group('o censo do que este arquivo exercitou', () {
    test('nenhum laço saiu vazio, e a cobertura de larguras é a de sempre', () {
      // As 97 larguras da varredura, mais as telas nomeadas e as degeneradas.
      // O piso é conservador de propósito: o que ele existe para pegar é a
      // queda para meia dúzia, e não um número exato que mudaria a cada
      // cenário novo.
      expect(
        largurasExercitadas.length,
        greaterThanOrEqualTo(100),
        reason: 'o arquivo tocou ${largurasExercitadas.length} larguras '
            'distintas — algum cenário de largura foi removido ou repetido',
      );
      // AS TESTEMUNHAS DE CADA LAÇO.
      //
      // Cada par abaixo só pode ter sido produzido por UM dos laços deste
      // arquivo, e é isso que faz dele testemunha. A largura sozinha não
      // serviria: a varredura de 240 a 1200 passa por 320, 360, 400, 600 e 900,
      // e cobriria a ausência de qualquer uma delas nos outros laços.
      const testemunhas = <String, String>{
        '11@199.0': 'a varredura de larguras não chega mais a 240 pontos',
        '11@1159.0': 'a varredura de larguras não chega mais a 1200 pontos',
        '22@279.0': 'o piso deixou de ser conferido em 320 pontos',
        '22@319.0': 'o piso deixou de ser conferido em 360 pontos',
        '22@359.0': 'o piso deixou de ser conferido em 400 pontos',
        '22@559.0': 'a colisão deixou de ser conferida em 600 pontos',
        '0@859.0': 'a altura deixou de ser conferida em 900 pontos',
        '22@859.0': 'a altura em 900 pontos não vai mais até 22 cartas',
      };
      for (final t in testemunhas.entries) {
        expect(
          paresExercitados,
          contains(t.key),
          reason: '${t.value} (par ${t.key} ausente)',
        );
      }
      // De 0 a 22 cartas, sem buraco.
      expect(
        quantidadesExercitadas.length,
        greaterThanOrEqualTo(23),
        reason: 'o arquivo exercitou ${quantidadesExercitadas.length} '
            'quantidades de carta, e a faixa de 0 a 22 tem 23',
      );
      expect(
        chamadasAoModulo,
        greaterThanOrEqualTo(97 + 66 + 84 + 115),
        reason: 'o módulo foi chamado $chamadasAoModulo vezes, abaixo do que '
            'os laços deste arquivo somam',
      );
      // ignore: avoid_print
      print(
        'CENSO: ${chamadasAoModulo} chamadas · '
        '${largurasExercitadas.length} larguras · '
        '${quantidadesExercitadas.length} quantidades · '
        '${paresExercitados.length} pares',
      );
      expect(
        paresExercitados.length,
        greaterThanOrEqualTo(190),
        reason: 'o arquivo exercitou ${paresExercitados.length} combinações '
            'distintas de cartas e largura — algum laço encolheu',
      );
    });
  });
}
