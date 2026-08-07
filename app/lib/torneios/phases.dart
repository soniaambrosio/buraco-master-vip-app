// phases.dart — fases da edicao (OS 02 secao 8).
//
// Camada pura: sem Firestore, sem UI e sem relogio.
//
// POR QUE FASE E UM ESTADO PROPRIO: a OS 02 secao 4 lista "fase concluida" junto
// dos estados do torneio, mas as duas coisas nao podem viver no mesmo enum. Uma
// edicao no formato misto tem a fase de grupos concluida e a semifinal em
// andamento AO MESMO TEMPO; um unico campo de status nao consegue dizer isso.
// Aqui a edicao fica em `emAndamento` e cada fase carrega o proprio estado.

import 'match_contract.dart';
import 'seating.dart';
import 'standings.dart';
import 'tournament_model.dart';

/// Papel da fase dentro do formato.
enum TipoFase {
  /// Primeira fase de um formato por pontos ou de grupos.
  inicial('inicial'),

  /// Rodada subsequente do mesmo estagio classificatorio.
  rodada('rodada'),

  /// Mata-mata anterior a semifinal.
  eliminatoria('eliminatoria'),

  semifinal('semifinal'),
  finalDecisiva('final');

  final String wire;
  const TipoFase(this.wire);

  /// A fase decide o campeao da edicao.
  bool get decisiva => this == finalDecisiva;

  static TipoFase? porWire(String wire) {
    for (final t in TipoFase.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Situacao da fase.
enum StatusFase {
  /// Criada, mesas ainda nao formadas.
  pendente('pendente'),

  /// Mesas formadas e partidas em curso.
  emAndamento('em_andamento'),

  /// Todas as mesas encerradas e classificacao apurada.
  concluida('concluida'),

  cancelada('cancelada');

  final String wire;
  const StatusFase(this.wire);

  static StatusFase? porWire(String wire) {
    for (final s in StatusFase.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Uma fase da edicao.
class Fase {
  final String faseId;
  final String tournamentId;
  final String editionId;

  /// Posicao na sequencia, comecando em 1.
  final int ordem;

  final TipoFase tipo;
  final StatusFase status;

  /// Semente do sorteio de mesas. Guardada para que reprocessar a formacao
  /// devolva exatamente as mesmas mesas (ver seating.dart).
  final int semente;

  /// Unidades por mesa nesta fase.
  final int ladosPorMesa;

  /// Quantos avancam para a proxima fase. null na fase decisiva, onde ninguem
  /// avanca — quem vence e campeao.
  final int? vagasAvanco;

  const Fase({
    required this.faseId,
    required this.tournamentId,
    required this.editionId,
    required this.ordem,
    required this.tipo,
    required this.semente,
    required this.ladosPorMesa,
    this.status = StatusFase.pendente,
    this.vagasAvanco,
  });

  /// A fase encerra a edicao.
  bool get decisiva => tipo.decisiva;

  Fase comStatus(StatusFase novo) => Fase(
        faseId: faseId,
        tournamentId: tournamentId,
        editionId: editionId,
        ordem: ordem,
        tipo: tipo,
        semente: semente,
        ladosPorMesa: ladosPorMesa,
        status: novo,
        vagasAvanco: vagasAvanco,
      );

  Map<String, dynamic> toJson() => {
        'faseId': faseId,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'ordem': ordem,
        'tipo': tipo.wire,
        'status': status.wire,
        'semente': semente,
        'ladosPorMesa': ladosPorMesa,
        'vagasAvanco': vagasAvanco,
      };

  factory Fase.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('fase: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    int inteiro(String campo, {int minimo = 1}) {
      final v = json[campo];
      if (v is! int || v < minimo) {
        throw FormatException('fase: $campo deve ser int >= $minimo (recebido: $v).');
      }
      return v;
    }

    final tipo = TipoFase.porWire(texto('tipo'));
    if (tipo == null) {
      throw FormatException('fase: tipo desconhecido "${json['tipo']}".');
    }
    final status = StatusFase.porWire(texto('status'));
    if (status == null) {
      throw FormatException('fase: status desconhecido "${json['status']}".');
    }
    final semente = json['semente'];
    if (semente is! int) {
      throw FormatException('fase: semente deve ser int (recebido: $semente).');
    }
    final vagas = json['vagasAvanco'];
    if (vagas != null && (vagas is! int || vagas < 1)) {
      throw FormatException('fase: vagasAvanco deve ser int >= 1 ou null (recebido: $vagas).');
    }
    if (tipo.decisiva && vagas != null) {
      throw FormatException('fase: a fase decisiva nao tem vagasAvanco.');
    }

    return Fase(
      faseId: texto('faseId'),
      tournamentId: texto('tournamentId'),
      editionId: texto('editionId'),
      ordem: inteiro('ordem'),
      tipo: tipo,
      status: status,
      semente: semente,
      ladosPorMesa: inteiro('ladosPorMesa', minimo: 2),
      vagasAvanco: vagas as int?,
    );
  }

  @override
  String toString() => 'Fase($faseId ${tipo.wire} ${status.wire})';
}

/// A fase pode ser dada por concluida: existe ao menos uma mesa e nenhuma segue
/// pendente ou em jogo.
///
/// Mesas canceladas nao impedem a conclusao — elas ja foram desfeitas de
/// proposito. Uma fase sem mesa nenhuma NAO conclui: isso seria uma fase que
/// nunca aconteceu sendo tratada como disputada.
bool faseConcluida(Iterable<Mesa> mesas) {
  var houveMesa = false;
  for (final mesa in mesas) {
    if (mesa.status == StatusMesa.cancelada) continue;
    houveMesa = true;
    if (mesa.status != StatusMesa.encerrada) return false;
  }
  return houveMesa;
}

/// Por que o avanco de fase foi recusado.
enum RecusaAvanco {
  /// Ainda ha mesa aberta.
  faseIncompleta('fase_incompleta'),

  /// A fase ja foi concluida antes. Recusa em vez de silencio para que
  /// reprocessar a automacao nao pareca progresso novo (OS 02 secao 19).
  faseJaConcluida('fase_ja_concluida'),

  /// A fase decisiva nao avanca para lugar nenhum: ela define o campeao.
  faseDecisiva('fase_decisiva'),

  /// A fase nao declarou quantos avancam.
  vagasNaoDefinidas('vagas_nao_definidas'),

  /// O corte cai sobre um empate que os criterios esportivos nao resolveram
  /// (OS 02 secao 11).
  empateNaoResolvido('empate_nao_resolvido');

  final String wire;
  const RecusaAvanco(this.wire);
}

/// Veredito de [apurarFase].
class ResultadoApuracao {
  /// Classificacao da fase, com avanco e eliminacao ja marcados.
  final List<LinhaClassificacao> classificacao;

  /// Quem segue para a proxima fase, na ordem da classificacao.
  final List<String> avancam;

  final RecusaAvanco? recusa;

  const ResultadoApuracao._(this.classificacao, this.avancam, this.recusa);

  const ResultadoApuracao.apurada(
      List<LinhaClassificacao> classificacao, List<String> avancam)
      : this._(classificacao, avancam, null);

  const ResultadoApuracao.recusada(RecusaAvanco recusa)
      : this._(const [], const [], recusa);

  bool get apurada => recusa == null;

  @override
  String toString() => apurada
      ? 'ResultadoApuracao.apurada(${avancam.length} avancam)'
      : 'ResultadoApuracao.recusada(${recusa!.wire})';
}

/// Apura uma fase encerrada e diz quem avanca (OS 02 secoes 8 e 10).
///
/// Funcao pura. Nao muda o status da fase nem grava nada: devolve o veredito para
/// a camada chamadora aplicar, do mesmo jeito que tournament_lifecycle.dart separa
/// decidir de aplicar.
ResultadoApuracao apurarFase({
  required Fase fase,
  required Iterable<Mesa> mesas,
  required Iterable<ResultadoPartida> resultados,
  required List<CriterioDesempate> criterios,
}) {
  if (fase.status == StatusFase.concluida) {
    return const ResultadoApuracao.recusada(RecusaAvanco.faseJaConcluida);
  }
  if (!faseConcluida(mesas)) {
    return const ResultadoApuracao.recusada(RecusaAvanco.faseIncompleta);
  }

  // So os resultados DESTA fase entram. Sem este filtro, a classificacao da
  // semifinal herdaria os pontos da fase de grupos e o corte sairia errado.
  final daFase = resultados.where((r) => r.faseId == fase.faseId).toList(growable: false);

  final participantes = <String>{
    for (final mesa in mesas)
      if (mesa.status != StatusMesa.cancelada)
        for (final assento in mesa.assentos) assento.participanteId,
  };

  final classificacao = calcularClassificacao(
    resultados: daFase,
    criterios: criterios,
    participantes: participantes,
  );

  if (fase.decisiva) {
    return const ResultadoApuracao.recusada(RecusaAvanco.faseDecisiva);
  }
  final vagas = fase.vagasAvanco;
  if (vagas == null) {
    return const ResultadoApuracao.recusada(RecusaAvanco.vagasNaoDefinidas);
  }

  final List<LinhaClassificacao> comCorte;
  try {
    comCorte = aplicarCorte(classificacao, vagas: vagas);
  } on StateError {
    // aplicarCorte recusa cortar no meio de um empate nao resolvido. Aqui isso
    // vira recusa de dominio em vez de excecao, para a automacao parar limpo e a
    // pendencia chegar ao operador.
    return const ResultadoApuracao.recusada(RecusaAvanco.empateNaoResolvido);
  }

  return ResultadoApuracao.apurada(
    comCorte,
    comCorte
        .where((l) => l.situacao == SituacaoClassificacao.avancou)
        .map((l) => l.participanteId)
        .toList(growable: false),
  );
}

/// Apura a fase decisiva, que nao tem avanco: ela produz a classificacao final.
///
/// Separada de [apurarFase] de proposito — misturar as duas faria a fase decisiva
/// precisar de um `vagasAvanco` ficticio, e um numero ficticio no banco vira
/// regra de verdade quando alguem le sem contexto.
ResultadoApuracao apurarFaseDecisiva({
  required Fase fase,
  required Iterable<Mesa> mesas,
  required Iterable<ResultadoPartida> resultados,
  required List<CriterioDesempate> criterios,
}) {
  if (!fase.decisiva) {
    return const ResultadoApuracao.recusada(RecusaAvanco.vagasNaoDefinidas);
  }
  if (fase.status == StatusFase.concluida) {
    return const ResultadoApuracao.recusada(RecusaAvanco.faseJaConcluida);
  }
  if (!faseConcluida(mesas)) {
    return const ResultadoApuracao.recusada(RecusaAvanco.faseIncompleta);
  }

  final daFase = resultados.where((r) => r.faseId == fase.faseId).toList(growable: false);
  final participantes = <String>{
    for (final mesa in mesas)
      if (mesa.status != StatusMesa.cancelada)
        for (final assento in mesa.assentos) assento.participanteId,
  };

  return ResultadoApuracao.apurada(
    calcularClassificacao(
      resultados: daFase,
      criterios: criterios,
      participantes: participantes,
    ),
    const [],
  );
}

/// Monta a sequencia de fases prevista pelo formato do template.
///
/// [semente] gera as sementes derivadas de cada fase, mantendo tudo reproduzivel
/// a partir de um unico numero guardado na edicao.
///
/// Lanca [ArgumentError] quando o template ainda nao definiu o numero de fases:
/// gerar uma quantidade arbitraria decidiria o formato da competicao no lugar da
/// administracao (OS 02 secao 3).
List<Fase> montarFases({
  required String tournamentId,
  required String editionId,
  required TorneioTemplate template,
  required int semente,
  required int ladosPorMesa,
  List<int> vagasPorFase = const [],
}) {
  final total = template.numeroFases;
  if (total == null) {
    throw ArgumentError('template ${template.tournamentId}: numeroFases indefinido');
  }
  if (total < 1) {
    throw ArgumentError.value(total, 'numeroFases', 'deve ser >= 1');
  }
  if (vagasPorFase.length != total - 1) {
    throw ArgumentError.value(vagasPorFase, 'vagasPorFase',
        'precisa de ${total - 1} entradas para $total fases');
  }

  final fases = <Fase>[];
  for (var i = 0; i < total; i++) {
    final ultima = i == total - 1;
    final tipo = _tipoDaFase(
      indice: i,
      total: total,
      formato: template.formato,
    );
    fases.add(Fase(
      faseId: '$editionId-fase-${i + 1}',
      tournamentId: tournamentId,
      editionId: editionId,
      ordem: i + 1,
      tipo: tipo,
      // Semente derivada por fase: reformar a mesa da fase 2 nao pode remontar a
      // fase 1, e todas continuam reproduziveis a partir da semente da edicao.
      semente: semente + i * 7919,
      ladosPorMesa: ladosPorMesa,
      vagasAvanco: ultima ? null : vagasPorFase[i],
    ));
  }
  return fases;
}

TipoFase _tipoDaFase({
  required int indice,
  required int total,
  required FormatoTorneio formato,
}) {
  // Pontos corridos nao tem mata-mata: todas as fases sao rodadas, e a ultima
  // continua sendo rodada — o campeao sai da classificacao, nao de um confronto.
  if (formato == FormatoTorneio.pontosCorridos) {
    return indice == 0 ? TipoFase.inicial : TipoFase.rodada;
  }
  final restantes = total - indice;
  if (restantes == 1) return TipoFase.finalDecisiva;
  if (restantes == 2) return TipoFase.semifinal;
  if (indice == 0) return TipoFase.inicial;
  return formato == FormatoTorneio.eliminatorio
      ? TipoFase.eliminatoria
      : TipoFase.rodada;
}
