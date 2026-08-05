// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// Ajuste obrigatório 2 — contrato ÚNICO de ação canônica.
// TODA mutação de jogo passa por aqui: compra do monte, compra do lixo,
// baixada/abertura (um ou vários jogos + extensões) e descarte. Sem ações
// paralelas fora do motor canônico.

/// Identificador estável de carta (mesmo esquema do motor atual: 'c123').
typedef CartaId = String;

/// Ação canônica (hierarquia selada — o motor cobre todos os casos).
sealed class Acao {
  const Acao();

  /// Serialização para o replay determinístico (ajuste 8).
  Map<String, dynamic> toJson();
}

/// Comprar a carta do topo do monte.
class ComprarMonte extends Acao {
  const ComprarMonte();
  @override
  Map<String, dynamic> toJson() => {'tipo': 'comprarMonte'};
}

/// Comprar o lixo inteiro. No Fechado/STBL exige uso do topo (ajuste da spec).
class ComprarLixo extends Acao {
  const ComprarLixo();
  @override
  Map<String, dynamic> toJson() => {'tipo': 'comprarLixo'};
}

/// Extensão de um jogo já baixado da dupla.
class Extensao {
  final int indiceJogo; // índice do jogo na mesa da dupla
  final List<CartaId> cartas;
  const Extensao(this.indiceJogo, this.cartas);

  Map<String, dynamic> toJson() =>
      {'indiceJogo': indiceJogo, 'cartas': cartas};

  static Extensao fromJson(Map<String, dynamic> j) => Extensao(
        j['indiceJogo'] as int,
        (j['cartas'] as List).cast<CartaId>(),
      );
}

/// Baixar: uma ou mais jogadas novas + extensões, avaliadas de forma ATÔMICA.
/// Representa também a abertura múltipla (vários jogos numa só ação) e o
/// consumo do topo do lixo quando a abertura decorre da compra do lixo.
class Baixar extends Acao {
  final List<List<CartaId>> jogosNovos;
  final List<Extensao> extensoes;
  final CartaId? topoLixoConsumido;
  const Baixar({
    this.jogosNovos = const [],
    this.extensoes = const [],
    this.topoLixoConsumido,
  });

  @override
  Map<String, dynamic> toJson() => {
        'tipo': 'baixar',
        'jogosNovos': jogosNovos,
        'extensoes': [for (final e in extensoes) e.toJson()],
        if (topoLixoConsumido != null)
          'topoLixoConsumido': topoLixoConsumido,
      };
}

/// Descartar uma carta (encerra o turno).
class Descartar extends Acao {
  final CartaId carta;
  const Descartar(this.carta);
  @override
  Map<String, dynamic> toJson() => {'tipo': 'descartar', 'carta': carta};
}

/// Reconstrói uma Acao a partir do JSON do replay (ajuste 8).
Acao acaoDeJson(Map<String, dynamic> j) {
  switch (j['tipo'] as String) {
    case 'comprarMonte':
      return const ComprarMonte();
    case 'comprarLixo':
      return const ComprarLixo();
    case 'baixar':
      return Baixar(
        jogosNovos: [
          for (final g in (j['jogosNovos'] as List))
            (g as List).cast<CartaId>(),
        ],
        extensoes: [
          for (final e in (j['extensoes'] as List? ?? const []))
            Extensao.fromJson((e as Map).cast<String, dynamic>()),
        ],
        topoLixoConsumido: j['topoLixoConsumido'] as CartaId?,
      );
    case 'descartar':
      return Descartar(j['carta'] as CartaId);
    default:
      throw ArgumentError('Ação desconhecida no replay: ${j['tipo']}');
  }
}

/// Resultado de avaliar/aplicar uma ação.
/// Ajuste 7 — a pontuação aqui é a PARCIAL da rodada, distinta da acumulada.
class ResultadoAcao {
  final bool valido;
  final String? motivo;
  final List<int> pontosPorJogo;
  final int pontosParcialRodada;
  final bool atingiuMinimo;

  const ResultadoAcao({
    required this.valido,
    this.motivo,
    this.pontosPorJogo = const [],
    this.pontosParcialRodada = 0,
    this.atingiuMinimo = false,
  });

  factory ResultadoAcao.recusa(String motivo) =>
      ResultadoAcao(valido: false, motivo: motivo);
}
