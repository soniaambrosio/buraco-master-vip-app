// match_contract.dart — contrato entre Motor de Torneios e Motor de Partidas
// (OS 02 secao 23) e ingestao de resultado (OS 02 secao 9).
//
// Camada pura: sem Firestore, sem UI e sem relogio implicito.
//
// O CONTRATO, NOS TERMOS DA OS:
//   1. "Torneio cria/solicita uma partida."  -> [SolicitacaoPartida] + [MotorDePartidas]
//   2. "Partida retorna resultado validado." -> [ResultadoPartida] + [ReceptorDeResultado]
//
// SEM DEPENDENCIA CIRCULAR: as duas interfaces sao declaradas AQUI, no dominio de
// torneios, e nao em mesa.dart. O Motor de Partidas passa a implementar
// [MotorDePartidas] sem importar nada deste pacote alem deste arquivo, e o
// Motor de Torneios nunca importa mesa.dart. A seta aponta em um sentido so.
//
// ESTE ARQUIVO NAO JOGA BURACO. Nao ha baralho, distribuicao, batida nem
// pontuacao de rodada aqui — isso e mesa.dart e continua sendo (OS 02 secao 7:
// "O Motor de Torneios nao deve reconstruir o Motor de Partidas").

import 'participants.dart';

/// Pedido de partida emitido pelo torneio.
///
/// Carrega tudo que a mesa precisa para existir e nada do que ela nao precisa
/// saber: o Motor de Partidas nao recebe classificacao, premiacao nem criterio de
/// desempate.
class SolicitacaoPartida {
  /// Identificador da partida, definido pelo TORNEIO antes de solicitar.
  ///
  /// Deliberadamente nao e o Motor de Partidas quem gera: se o id nascesse la, o
  /// torneio precisaria esperar a resposta para saber o que reconciliar, e uma
  /// solicitacao perdida no meio do caminho viraria uma mesa orfa impossivel de
  /// rastrear. Com o id vindo daqui, reenviar a solicitacao e idempotente.
  final String matchId;

  final String tournamentId;
  final String editionId;

  /// Fase a que a partida pertence. Ver phases.dart.
  final String faseId;

  /// Mesa dentro da fase. Ver seating.dart.
  final String mesaId;

  /// Participantes em ordem de assento. Dois em torneio de dupla (cada um com
  /// dois membros), ate quatro em individual.
  final List<Participante> assentos;

  /// `ABERTO` | `FECHADO` | `SBTL`, no vocabulario que `Jogo.modalidade` ja usa.
  final String modalidade;

  final int metaPontos;

  /// Instante da solicitacao, em UTC.
  final DateTime solicitadaEm;

  SolicitacaoPartida({
    required this.matchId,
    required this.tournamentId,
    required this.editionId,
    required this.faseId,
    required this.mesaId,
    required this.assentos,
    required this.modalidade,
    required this.metaPontos,
    required DateTime solicitadaEm,
  }) : solicitadaEm = solicitadaEm.toUtc() {
    if (matchId.isEmpty) {
      throw ArgumentError.value(matchId, 'matchId', 'nao pode ser vazio');
    }
    if (assentos.length < 2) {
      throw ArgumentError.value(assentos.length, 'assentos', 'partida exige ao menos 2 lados');
    }
    final ids = assentos.map((p) => p.participanteId).toSet();
    if (ids.length != assentos.length) {
      throw ArgumentError.value(assentos, 'assentos', 'participante repetido na mesma mesa');
    }
    if (metaPontos < 1) {
      throw ArgumentError.value(metaPontos, 'metaPontos', 'deve ser >= 1');
    }
  }

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'faseId': faseId,
        'mesaId': mesaId,
        'assentos': assentos.map((p) => p.participanteId).toList(),
        'modalidade': modalidade,
        'metaPontos': metaPontos,
        'solicitadaEm': solicitadaEm.toIso8601String(),
      };

  @override
  String toString() => 'SolicitacaoPartida($matchId @ $mesaId)';
}

/// Desfecho de um lado da mesa.
class LadoResultado {
  final String participanteId;

  /// Pontos finais acumulados na partida.
  final int pontos;

  /// Canastras limpas na partida. Quarto criterio de desempate do projeto.
  final int canastrasLimpas;

  const LadoResultado({
    required this.participanteId,
    required this.pontos,
    required this.canastrasLimpas,
  });

  factory LadoResultado.fromJson(Map<String, dynamic> json) {
    final id = json['participanteId'];
    if (id is! String || id.isEmpty) {
      throw FormatException('lado: participanteId deve ser string nao vazia (recebido: $id).');
    }
    final pontos = json['pontos'];
    if (pontos is! int) {
      throw FormatException('lado $id: pontos deve ser int (recebido: $pontos).');
    }
    final canastras = json['canastrasLimpas'];
    if (canastras is! int || canastras < 0) {
      throw FormatException('lado $id: canastrasLimpas deve ser int >= 0 (recebido: $canastras).');
    }
    return LadoResultado(
      participanteId: id,
      pontos: pontos,
      canastrasLimpas: canastras,
    );
  }

  Map<String, dynamic> toJson() => {
        'participanteId': participanteId,
        'pontos': pontos,
        'canastrasLimpas': canastrasLimpas,
      };
}

/// Como a partida terminou.
enum DesfechoPartida {
  /// Alguem atingiu a meta de pontos.
  normal('normal'),

  /// Um lado abandonou. O vencedor e o lado que ficou.
  abandono('abandono'),

  /// Encerrada pela administracao sem disputa completa.
  encerradaPorAdmin('encerrada_por_admin'),

  /// Anulada: nao gera pontuacao para ninguem.
  anulada('anulada');

  final String wire;
  const DesfechoPartida(this.wire);

  /// O resultado alimenta a classificacao.
  bool get pontua => this != anulada;

  static DesfechoPartida? porWire(String wire) {
    for (final d in DesfechoPartida.values) {
      if (d.wire == wire) return d;
    }
    return null;
  }
}

/// Resultado validado devolvido pelo Motor de Partidas.
///
/// "Validado" e responsabilidade de quem produz: o torneio confere COERENCIA
/// (identidade, vinculo com fase e mesa, unicidade do vencedor), nao a aritmetica
/// do buraco. Recontar pontos aqui seria reconstruir o Motor de Partidas.
class ResultadoPartida {
  final String matchId;
  final String tournamentId;
  final String editionId;
  final String faseId;
  final String mesaId;

  final List<LadoResultado> lados;

  /// Lado vencedor. null apenas em [DesfechoPartida.anulada].
  final String? vencedorId;

  final DesfechoPartida desfecho;

  /// Instante do encerramento, em UTC.
  final DateTime encerradaEm;

  ResultadoPartida({
    required this.matchId,
    required this.tournamentId,
    required this.editionId,
    required this.faseId,
    required this.mesaId,
    required this.lados,
    required this.vencedorId,
    required this.desfecho,
    required DateTime encerradaEm,
  }) : encerradaEm = encerradaEm.toUtc() {
    if (matchId.isEmpty) {
      throw ArgumentError.value(matchId, 'matchId', 'nao pode ser vazio');
    }
    if (lados.length < 2) {
      throw ArgumentError.value(lados.length, 'lados', 'resultado exige ao menos 2 lados');
    }
    final ids = lados.map((l) => l.participanteId).toSet();
    if (ids.length != lados.length) {
      throw ArgumentError.value(lados, 'lados', 'participante repetido no resultado');
    }
    if (desfecho == DesfechoPartida.anulada) {
      if (vencedorId != null) {
        throw ArgumentError.value(vencedorId, 'vencedorId', 'partida anulada nao tem vencedor');
      }
    } else {
      if (vencedorId == null) {
        throw ArgumentError.value(vencedorId, 'vencedorId', 'obrigatorio em ${desfecho.wire}');
      }
      if (!ids.contains(vencedorId)) {
        throw ArgumentError.value(vencedorId, 'vencedorId', 'nao esta entre os lados da mesa');
      }
    }
  }

  /// `tournamentId + editionId + matchId`.
  ///
  /// O `matchId` sozinho ja seria unico na pratica, mas incluir a edicao torna a
  /// chave auto-descritiva: um registro solto no banco diz a que edicao pertence
  /// sem precisar de join, e um resultado enviado para a edicao errada e recusado
  /// pela propria chave em vez de contaminar a classificacao alheia.
  String get chaveIdempotencia => '$tournamentId|$editionId|$matchId';

  LadoResultado? ladoDe(String participanteId) {
    for (final l in lados) {
      if (l.participanteId == participanteId) return l;
    }
    return null;
  }

  factory ResultadoPartida.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('resultado: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    final desfecho = DesfechoPartida.porWire(texto('desfecho'));
    if (desfecho == null) {
      throw FormatException('resultado: desfecho desconhecido "${json['desfecho']}".');
    }

    final ladosBrutos = json['lados'];
    if (ladosBrutos is! List) {
      throw FormatException('resultado: lados deve ser lista (recebido: $ladosBrutos).');
    }

    final encerradaEmBruta = texto('encerradaEm');
    final encerradaEm = DateTime.tryParse(encerradaEmBruta);
    if (encerradaEm == null) {
      throw FormatException('resultado: encerradaEm nao e ISO-8601 valido (recebido: $encerradaEmBruta).');
    }
    if (!encerradaEm.isUtc) {
      throw FormatException('resultado: encerradaEm deve estar em UTC (sufixo Z).');
    }

    final chave = texto('chaveIdempotencia');
    final esperada = '${texto('tournamentId')}|${texto('editionId')}|${texto('matchId')}';
    if (chave != esperada) {
      throw FormatException(
          'resultado: chaveIdempotencia nao corresponde aos campos do registro (esperada: $esperada, recebida: $chave).');
    }

    try {
      return ResultadoPartida(
        matchId: texto('matchId'),
        tournamentId: texto('tournamentId'),
        editionId: texto('editionId'),
        faseId: texto('faseId'),
        mesaId: texto('mesaId'),
        lados: ladosBrutos
            .map((e) => LadoResultado.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        vencedorId: json['vencedorId'] as String?,
        desfecho: desfecho,
        encerradaEm: encerradaEm,
      );
    } on ArgumentError catch (e) {
      throw FormatException('resultado: registro invalido ($e).');
    }
  }

  Map<String, dynamic> toJson() => {
        'matchId': matchId,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'faseId': faseId,
        'mesaId': mesaId,
        'lados': lados.map((l) => l.toJson()).toList(),
        'vencedorId': vencedorId,
        'desfecho': desfecho.wire,
        'encerradaEm': encerradaEm.toIso8601String(),
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'ResultadoPartida($chaveIdempotencia ${desfecho.wire})';
}

/// Lado 1 do contrato: o torneio solicita uma partida.
///
/// Implementado pelo Motor de Partidas (ou por um adaptador dele). O torneio
/// depende desta interface, nunca da implementacao.
abstract interface class MotorDePartidas {
  /// Cria a partida descrita. Deve ser idempotente por
  /// [SolicitacaoPartida.matchId]: reenviar a mesma solicitacao nao pode abrir
  /// duas mesas.
  Future<void> solicitarPartida(SolicitacaoPartida solicitacao);

  /// Cancela uma partida ainda nao encerrada. Silencioso quando o `matchId` nao
  /// existe — cancelar o que ja sumiu e o resultado desejado.
  Future<void> cancelarPartida(String matchId);
}

/// Lado 2 do contrato: a partida devolve resultado validado ao torneio.
///
/// Implementado pelo Motor de Torneios. O Motor de Partidas chama isto sem saber
/// o que acontece depois — nao conhece fase, classificacao nem premiacao.
abstract interface class ReceptorDeResultado {
  /// Entrega um resultado validado. Deve ser idempotente por
  /// [ResultadoPartida.chaveIdempotencia].
  Future<void> receberResultado(ResultadoPartida resultado);
}

/// Por que o resultado foi recusado na ingestao (OS 02 secao 9).
enum RecusaResultado {
  /// A partida nao consta como solicitada por esta edicao.
  partidaDesconhecida('partida_desconhecida'),

  /// Ja processado: a chave de idempotencia consta no historico.
  jaProcessado('ja_processado'),

  /// O resultado aponta para uma fase diferente da que a solicitacao registrou.
  faseIncorreta('fase_incorreta'),

  /// O resultado aponta para uma mesa diferente da que a solicitacao registrou.
  mesaIncorreta('mesa_incorreta'),

  /// Os lados do resultado nao batem com os assentos da solicitacao.
  participantesDivergentes('participantes_divergentes'),

  /// A edicao nao esta em disputa: resultado de torneio encerrado ou nao iniciado
  /// nao entra na classificacao.
  edicaoForaDeDisputa('edicao_fora_de_disputa');

  final String wire;
  const RecusaResultado(this.wire);
}

/// Veredito de [processarResultado].
class ResultadoProcessamento {
  /// null quando houve recusa.
  final ResultadoPartida? aceito;

  /// null quando o resultado foi aceito.
  final RecusaResultado? recusa;

  const ResultadoProcessamento._(this.aceito, this.recusa);

  const ResultadoProcessamento.aceito(ResultadoPartida resultado)
      : this._(resultado, null);

  const ResultadoProcessamento.recusado(RecusaResultado recusa)
      : this._(null, recusa);

  bool get processado => aceito != null;

  /// A recusa e benigna: o efeito ja aconteceu antes.
  ///
  /// Util para a camada de transporte responder 200 em vez de erro quando o
  /// Motor de Partidas reenvia por timeout — reenvio nao e falha.
  bool get idempotente => recusa == RecusaResultado.jaProcessado;

  @override
  String toString() => processado
      ? 'ResultadoProcessamento.aceito(${aceito!.chaveIdempotencia})'
      : 'ResultadoProcessamento.recusado(${recusa!.wire})';
}

/// Valida e admite um resultado de partida (OS 02 secao 9).
///
/// Confere que o resultado e identificavel, vinculado a partida/fase/mesa
/// corretas e impossivel de contabilizar duas vezes. Funcao pura: [processados]
/// entra por parametro e nada e gravado.
///
/// A ordem das checagens e estavel; a idempotencia vem CEDO, antes das
/// validacoes de vinculo, para que um reenvio seja sempre reportado como
/// `jaProcessado` e nunca como um erro de dados que assustaria o operador.
ResultadoProcessamento processarResultado({
  required ResultadoPartida resultado,
  required SolicitacaoPartida? solicitacao,
  required bool edicaoEmDisputa,
  Iterable<String> processados = const <String>[],
}) {
  if (processados.contains(resultado.chaveIdempotencia)) {
    return const ResultadoProcessamento.recusado(RecusaResultado.jaProcessado);
  }
  if (solicitacao == null) {
    return const ResultadoProcessamento.recusado(RecusaResultado.partidaDesconhecida);
  }
  if (solicitacao.matchId != resultado.matchId ||
      solicitacao.tournamentId != resultado.tournamentId ||
      solicitacao.editionId != resultado.editionId) {
    return const ResultadoProcessamento.recusado(RecusaResultado.partidaDesconhecida);
  }
  if (!edicaoEmDisputa) {
    return const ResultadoProcessamento.recusado(RecusaResultado.edicaoForaDeDisputa);
  }
  if (solicitacao.faseId != resultado.faseId) {
    return const ResultadoProcessamento.recusado(RecusaResultado.faseIncorreta);
  }
  if (solicitacao.mesaId != resultado.mesaId) {
    return const ResultadoProcessamento.recusado(RecusaResultado.mesaIncorreta);
  }

  final esperados = solicitacao.assentos.map((p) => p.participanteId).toSet();
  final recebidos = resultado.lados.map((l) => l.participanteId).toSet();
  if (esperados.length != recebidos.length ||
      !esperados.containsAll(recebidos)) {
    return const ResultadoProcessamento.recusado(RecusaResultado.participantesDivergentes);
  }

  return ResultadoProcessamento.aceito(resultado);
}
