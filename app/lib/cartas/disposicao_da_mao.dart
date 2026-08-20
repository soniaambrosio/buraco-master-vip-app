// disposicao_da_mao.dart — onde cada carta da mão fica, e que pedaço dela o
// dedo alcança.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO É UM MÓDULO PURO, E NÃO UM TRECHO DE `mesa.dart`
// ---------------------------------------------------------------------------
//
// A OS 33 vai levar esta mesma mão para a Pública, a VIP/Ranqueada e a Privada.
// Se a regra morar dentro de `_MesaScreenState`, cada mesa nova a copia — e no
// dia em que uma delas ajustar o piso de toque, as outras três continuam com o
// número velho. Aqui a regra é UMA, não conhece Flutter, não conhece `Carta` e
// não desenha nada: recebe quantas cartas há e quanta largura existe, e devolve
// geometria.
//
// ---------------------------------------------------------------------------
// O PASSO É A FAIXA DE TOQUE — E O PISO NÃO É NEGOCIÁVEL
// ---------------------------------------------------------------------------
//
// As cartas se sobrepõem: a de índice `i+1` cobre a de índice `i` a partir de
// `passo` pontos. O que sobra descoberto de cada carta — e portanto o que o dedo
// pega sem pegar a vizinha — é EXATAMENTE `passo`. Só a última de cada fileira
// aparece inteira.
//
// A auditoria de 19/08/2026 mediu 21,12 pontos nessa faixa. A correção da OS 29
// subiu para 24–25,3 usando `clamp(24, 48)` sobre a largura disponível: passou a
// WCAG 2.5.8 e ficou abaixo do piso do Material, que é o que a OS 29 cobrava.
// A conta que faltava é simples: onze cartas a 48 pontos de passo pedem
// `66 + 10 × 48 = 546` pontos de largura, e telefone nenhum tem isso.
//
// Então o piso deixa de ser o que sobra da largura e passa a ser a ENTRADA da
// conta:
//
//   * `passo` é SEMPRE `pisoDeToque` (48). Nunca menos — o piso é o contrato —,
//     e nunca mais, porque espalhar além do piso só afasta as cartas sem
//     ninguém ganhar nada;
//   * quem se adapta é o NÚMERO DE FILEIRAS. Uma fileira enquanto a mão inteira
//     couber na largura; duas quando não couber;
//   * quando nem duas fileiras couberem — onze cartas em 320 pontos é o caso —,
//     a mão ROLA na horizontal, que é o que ela sempre fez. Rolar custa um
//     gesto; uma faixa de 21 pontos custa a jogada.
//
// A segunda fileira fica ABAIXO da primeira e a cobre em parte: a primeira
// mostra `pisoDeToque` pontos de altura, a segunda mostra a carta inteira. É por
// isso que a altura de duas fileiras é `elevação + piso + altura da carta`, e
// não duas cartas empilhadas — a mesa não tem essa altura para dar.
//
// ---------------------------------------------------------------------------
// A ORDEM É A LÓGICA DA MÃO, SEMPRE
// ---------------------------------------------------------------------------
//
// A primeira metade das cartas vai para a fileira de cima, a segunda para a de
// baixo, e dentro de cada fileira a ordem é a da mão. Lida de cima para baixo e
// da esquerda para a direita, a sequência é 1, 2, 3 … n — a mesma de uma fileira
// só. Nenhuma decisão de desenho, seleção ou animação entra nesta conta.

import 'dart:math' as math;

/// A largura desenhada de uma carta da mão, em pontos lógicos.
const double kLarguraPadraoDaCarta = 66.0;

/// A altura desenhada de uma carta da mão, em pontos lógicos.
const double kAlturaPadraoDaCarta = 100.0;

/// O piso de toque: WCAG 2.5.8 recomenda 24 como mínimo AA e o Material Design
/// pede 48. Este é o número que a OS 29-C1 tornou obrigatório.
const double kPisoDeToque = 48.0;

/// Quanto a carta selecionada sobe. A mão reserva essa altura no topo para que
/// a subida não saia da área.
const double kElevacaoDaSelecao = 13.0;

/// O respiro horizontal de cada lado da mão.
const double kRespiroDaMao = 14.0;

/// A faixa de UMA carta: o retângulo que o dedo alcança e que o leitor de tela
/// recebe. Coordenadas relativas ao canto superior esquerdo da mão.
class FaixaDaCarta {
  const FaixaDaCarta({
    required this.indice,
    required this.fileira,
    required this.esquerda,
    required this.topo,
    required this.largura,
    required this.altura,
  });

  /// A posição da carta na mão, de 0 a n-1. É a ordem lógica, e é ela que
  /// governa leitura e foco — nunca a fileira nem a pintura.
  final int indice;

  /// 0 = fileira de cima, 1 = fileira de baixo.
  final int fileira;

  final double esquerda;
  final double topo;
  final double largura;
  final double altura;

  double get direita => esquerda + largura;
  double get base => topo + altura;

  /// A faixa cumpre o piso nos dois eixos?
  bool cumpre(double piso) => largura >= piso && altura >= piso;

  /// Esta faixa e [outra] se sobrepõem? Duas faixas sobrepostas mandam o toque
  /// para a carta errada, que é o defeito que a fileira única tinha.
  bool colideCom(FaixaDaCarta outra) =>
      esquerda < outra.direita &&
      outra.esquerda < direita &&
      topo < outra.base &&
      outra.topo < base;
}

/// Como a mão inteira se organiza numa largura dada.
class DisposicaoDaMao {
  const DisposicaoDaMao({
    required this.fileiras,
    required this.passo,
    required this.largura,
    required this.altura,
    required this.larguraDaCarta,
    required this.alturaDaCarta,
    required this.elevacao,
    required this.faixas,
  });

  /// 1 ou 2. Nunca mais do que isso: três fileiras numa mesa desta altura
  /// deixariam a carta de cima com uma nesga que não vale como alvo.
  final int fileiras;

  /// A distância entre o começo de uma carta e o da seguinte, na mesma fileira.
  /// É também a faixa de toque de todas as cartas menos a última de cada
  /// fileira.
  final double passo;

  /// A largura total desenhada. Maior que a disponível quando a mão rola.
  final double largura;

  /// A altura total que a mão precisa, já com a elevação da seleção.
  final double altura;

  final double larguraDaCarta;
  final double alturaDaCarta;
  final double elevacao;

  /// Uma faixa por carta, na ORDEM LÓGICA da mão.
  final List<FaixaDaCarta> faixas;

  /// Quantas cartas há na fileira de cima. Na de baixo ficam as demais.
  int get cartasNaPrimeiraFileira =>
      faixas.where((f) => f.fileira == 0).length;

  /// A menor faixa de toque da mão, no eixo mais apertado.
  double get menorFaixa => faixas.isEmpty
      ? 0
      : faixas
          .map((f) => math.min(f.largura, f.altura))
          .reduce((a, b) => a < b ? a : b);

  /// A largura que uma fileira de [cartas] ocupa: a última aparece inteira, e
  /// cada uma das anteriores mostra um passo.
  static double larguraDeUmaFileira(
    int cartas, {
    double larguraDaCarta = kLarguraPadraoDaCarta,
    double passo = kPisoDeToque,
  }) =>
      cartas <= 0 ? 0 : larguraDaCarta + (cartas - 1) * passo;

  /// A altura que a mão precisa, sem montar as faixas.
  ///
  /// É o que a mesa pergunta ANTES de desenhar, para reservar o rodapé do
  /// jogador. Chamar `calcular` e ler `.altura` daria o mesmo número; existe
  /// separado porque a mesa faz essa conta a cada quadro e não precisa das
  /// faixas para isso.
  static double alturaNecessaria({
    required int cartas,
    required double larguraDisponivel,
    double larguraDaCarta = kLarguraPadraoDaCarta,
    double alturaDaCarta = kAlturaPadraoDaCarta,
    double pisoDeToque = kPisoDeToque,
    double elevacao = kElevacaoDaSelecao,
  }) {
    final duas = _precisaDeDuasFileiras(
      cartas: cartas,
      larguraDisponivel: larguraDisponivel,
      larguraDaCarta: larguraDaCarta,
      passo: pisoDeToque,
    );
    return elevacao + alturaDaCarta + (duas ? pisoDeToque : 0);
  }

  static bool _precisaDeDuasFileiras({
    required int cartas,
    required double larguraDisponivel,
    required double larguraDaCarta,
    required double passo,
  }) {
    if (cartas <= 1) return false;
    final deUmaVez = larguraDeUmaFileira(
      cartas,
      larguraDaCarta: larguraDaCarta,
      passo: passo,
    );
    return deUmaVez > larguraDisponivel;
  }

  /// Monta a disposição da mão.
  ///
  /// [larguraDisponivel] é a largura ÚTIL, já sem o respiro dos dois lados.
  static DisposicaoDaMao calcular({
    required int cartas,
    required double larguraDisponivel,
    double larguraDaCarta = kLarguraPadraoDaCarta,
    double alturaDaCarta = kAlturaPadraoDaCarta,
    double pisoDeToque = kPisoDeToque,
    double elevacao = kElevacaoDaSelecao,
  }) {
    assert(cartas >= 0);
    final passo = pisoDeToque;

    if (cartas == 0) {
      return DisposicaoDaMao(
        fileiras: 1,
        passo: passo,
        largura: 0,
        altura: elevacao + alturaDaCarta,
        larguraDaCarta: larguraDaCarta,
        alturaDaCarta: alturaDaCarta,
        elevacao: elevacao,
        faixas: const <FaixaDaCarta>[],
      );
    }

    final duas = _precisaDeDuasFileiras(
      cartas: cartas,
      larguraDisponivel: larguraDisponivel,
      larguraDaCarta: larguraDaCarta,
      passo: passo,
    );

    // A fileira de cima leva a metade maior quando o número é ímpar: assim a de
    // baixo — que é a que aparece inteira — nunca fica mais cheia do que a que
    // está parcialmente coberta.
    final naPrimeira = duas ? (cartas + 1) ~/ 2 : cartas;
    final tamanhos = duas
        ? <int>[naPrimeira, cartas - naPrimeira]
        : <int>[cartas];

    // A altura visível da fileira de cima é o próprio piso: é o que a de baixo
    // deixa à mostra. A de baixo mostra a carta inteira.
    final alturaDaPrimeira = elevacao + pisoDeToque;

    final faixas = <FaixaDaCarta>[];
    var indice = 0;
    for (var fileira = 0; fileira < tamanhos.length; fileira++) {
      final n = tamanhos[fileira];
      final topo = fileira == 0 ? 0.0 : alturaDaPrimeira;
      final altura = duas
          ? (fileira == 0 ? alturaDaPrimeira : alturaDaCarta)
          : elevacao + alturaDaCarta;
      for (var j = 0; j < n; j++) {
        faixas.add(FaixaDaCarta(
          indice: indice,
          fileira: fileira,
          esquerda: j * passo,
          topo: topo,
          // A última de cada fileira não tem vizinha cobrindo: fica inteira.
          largura: j == n - 1 ? larguraDaCarta : passo,
          altura: altura,
        ));
        indice++;
      }
    }

    final largura = tamanhos
        .map((n) => larguraDeUmaFileira(
              n,
              larguraDaCarta: larguraDaCarta,
              passo: passo,
            ))
        .reduce(math.max);

    return DisposicaoDaMao(
      fileiras: tamanhos.length,
      passo: passo,
      largura: largura,
      altura: elevacao + alturaDaCarta + (duas ? pisoDeToque : 0),
      larguraDaCarta: larguraDaCarta,
      alturaDaCarta: alturaDaCarta,
      elevacao: elevacao,
      faixas: faixas,
    );
  }

  /// Onde a carta [indice] é DESENHADA, que não é onde ela é tocada.
  ///
  /// A faixa da carta de cima tem a altura do piso; o desenho dela é a carta
  /// inteira, e vaza por baixo da fileira seguinte. Separar as duas coisas é o
  /// que impede a pintura de governar o toque — a raiz de todos os defeitos que
  /// a OS 29 mediu.
  ({double esquerda, double topo}) posicaoDeDesenho(int indice) {
    final f = faixas[indice];
    return (
      esquerda: f.esquerda,
      topo: f.fileira == 0 ? elevacao : elevacao + (altura - elevacao - alturaDaCarta),
    );
  }
}
