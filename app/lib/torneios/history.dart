// history.dart — historico consultavel das edicoes (OS 02 secao 15).
//
// Camada pura: sem Firestore, sem UI e sem relogio.
//
// SNAPSHOT, NAO CONSULTA VIVA: o historico e congelado no momento da conclusao,
// nao remontado sob demanda a partir das colecoes operacionais. Dois motivos, e o
// segundo e o que importa:
//
//   1. custo — reconstruir a classificacao de uma edicao de 2026 exigiria varrer
//      todas as partidas dela toda vez que alguem abrisse o perfil;
//   2. VERDADE HISTORICA — se o historico fosse recalculado, mudar um criterio de
//      desempate amanha reescreveria quem foi campeao ontem. O snapshot congela o
//      resultado sob a regra que valia no dia, exatamente como
//      `RecompensaConcessao` ja congela `acumulaContador`.
//
// "O historico deve permanecer disponivel mesmo apos o torneio terminar"
// (OS 02 secao 15): por isso nada aqui depende da edicao continuar existindo nas
// colecoes ativas.

import 'champion.dart';
import 'standings.dart';
import 'tournament_model.dart';

/// Uma linha congelada da classificacao final.
class LinhaHistorico {
  final int posicao;
  final String participanteId;

  /// Jogadores por tras do participante. Dois em dupla.
  final List<String> membros;

  final int vitorias;
  final int derrotas;
  final int pontosFeitos;
  final int pontosSofridos;
  final int canastrasLimpas;

  const LinhaHistorico({
    required this.posicao,
    required this.participanteId,
    required this.membros,
    required this.vitorias,
    required this.derrotas,
    required this.pontosFeitos,
    required this.pontosSofridos,
    required this.canastrasLimpas,
  });

  int get saldo => pontosFeitos - pontosSofridos;

  Map<String, dynamic> toJson() => {
        'posicao': posicao,
        'participanteId': participanteId,
        'membros': membros,
        'vitorias': vitorias,
        'derrotas': derrotas,
        'pontosFeitos': pontosFeitos,
        'pontosSofridos': pontosSofridos,
        'saldo': saldo,
        'canastrasLimpas': canastrasLimpas,
      };

  factory LinhaHistorico.fromMap(Map<String, dynamic> json) => LinhaHistorico(
        posicao: json['posicao'] as int,
        participanteId: json['participanteId'] as String,
        membros: ((json['membros'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
        vitorias: (json['vitorias'] as int?) ?? 0,
        derrotas: (json['derrotas'] as int?) ?? 0,
        pontosFeitos: (json['pontosFeitos'] as int?) ?? 0,
        pontosSofridos: (json['pontosSofridos'] as int?) ?? 0,
        canastrasLimpas: (json['canastrasLimpas'] as int?) ?? 0,
      );
}

/// Premio efetivamente concedido, congelado no historico.
class PremioHistorico {
  final String userId;
  final int colocacao;

  /// Ativo de catalogo concedido. null quando a faixa so pagou fichas.
  final String? assetId;

  final int? fichas;

  const PremioHistorico({
    required this.userId,
    required this.colocacao,
    this.assetId,
    this.fichas,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'colocacao': colocacao,
        'assetId': assetId,
        'fichas': fichas,
      };

  factory PremioHistorico.fromMap(Map<String, dynamic> json) => PremioHistorico(
        userId: json['userId'] as String,
        colocacao: json['colocacao'] as int,
        assetId: json['assetId'] as String?,
        fichas: json['fichas'] as int?,
      );
}

/// Registro historico completo de uma edicao encerrada.
///
/// Cobre os oito itens que a OS 02 secao 15 exige consultar depois: torneios
/// realizados, edicoes, participantes, classificacao, fases, resultados,
/// vencedores e premiacoes.
class RegistroHistorico {
  final String tournamentId;
  final String editionId;
  final String nomeTorneio;
  final int numeroEdicao;
  final String temporada;

  /// Versao da regra sob a qual a edicao correu. Congelada junto: sem ela, nao da
  /// para explicar depois por que a classificacao saiu daquele jeito.
  final int regraVersao;

  final ModalidadeMesa modalidade;
  final TipoParticipacao participacao;
  final FormatoTorneio formato;

  /// Criterios de desempate vigentes na edicao, na ordem aplicada.
  final List<CriterioDesempate> criteriosDesempate;

  final DateTime inicio;
  final DateTime encerramento;

  /// Identificadores das fases disputadas, em ordem.
  final List<String> fases;

  /// Quantas partidas foram contabilizadas.
  final int totalPartidas;

  final int totalParticipantes;

  final String campeaoId;
  final List<String> campeoes;
  final String? viceId;
  final String? terceiroId;

  final List<LinhaHistorico> classificacaoFinal;
  final List<PremioHistorico> premiacoes;

  RegistroHistorico({
    required this.tournamentId,
    required this.editionId,
    required this.nomeTorneio,
    required this.numeroEdicao,
    required this.temporada,
    required this.regraVersao,
    required this.modalidade,
    required this.participacao,
    required this.formato,
    required this.criteriosDesempate,
    required DateTime inicio,
    required DateTime encerramento,
    required this.fases,
    required this.totalPartidas,
    required this.totalParticipantes,
    required this.campeaoId,
    required this.campeoes,
    this.viceId,
    this.terceiroId,
    required this.classificacaoFinal,
    required this.premiacoes,
  })  : inicio = inicio.toUtc(),
        encerramento = encerramento.toUtc();

  /// `tournamentId + editionId`. Uma linha de historico por edicao.
  String get chaveIdempotencia => '$tournamentId|$editionId';

  /// O jogador participou desta edicao.
  bool participou(String userId) =>
      classificacaoFinal.any((l) => l.membros.contains(userId));

  /// Colocacao do jogador nesta edicao, ou null se nao participou.
  int? colocacaoDe(String userId) {
    for (final linha in classificacaoFinal) {
      if (linha.membros.contains(userId)) return linha.posicao;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'editionId': editionId,
        'nomeTorneio': nomeTorneio,
        'numeroEdicao': numeroEdicao,
        'temporada': temporada,
        'regraVersao': regraVersao,
        'modalidade': modalidade.wire,
        'participacao': participacao.wire,
        'formato': formato.wire,
        'criteriosDesempate': criteriosDesempate.map((c) => c.wire).toList(),
        'inicio': inicio.toIso8601String(),
        'encerramento': encerramento.toIso8601String(),
        'fases': fases,
        'totalPartidas': totalPartidas,
        'totalParticipantes': totalParticipantes,
        'campeaoId': campeaoId,
        'campeoes': campeoes,
        'viceId': viceId,
        'terceiroId': terceiroId,
        'classificacaoFinal':
            classificacaoFinal.map((l) => l.toJson()).toList(),
        'premiacoes': premiacoes.map((p) => p.toJson()).toList(),
        'chaveIdempotencia': chaveIdempotencia,
      };

  factory RegistroHistorico.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('historico: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    DateTime instante(String campo) {
      final bruto = texto(campo);
      final parsed = DateTime.tryParse(bruto);
      if (parsed == null || !parsed.isUtc) {
        throw FormatException('historico: $campo deve ser ISO-8601 em UTC (recebido: $bruto).');
      }
      return parsed;
    }

    final modalidade = ModalidadeMesa.porWire(texto('modalidade'));
    if (modalidade == null) {
      throw FormatException('historico: modalidade desconhecida "${json['modalidade']}".');
    }
    final participacao = TipoParticipacao.porWire(texto('participacao'));
    if (participacao == null) {
      throw FormatException('historico: participacao desconhecida "${json['participacao']}".');
    }
    final formato = FormatoTorneio.porWire(texto('formato'));
    if (formato == null) {
      throw FormatException('historico: formato desconhecido "${json['formato']}".');
    }

    return RegistroHistorico(
      tournamentId: texto('tournamentId'),
      editionId: texto('editionId'),
      nomeTorneio: texto('nomeTorneio'),
      numeroEdicao: json['numeroEdicao'] as int,
      temporada: texto('temporada'),
      regraVersao: json['regraVersao'] as int,
      modalidade: modalidade,
      participacao: participacao,
      formato: formato,
      criteriosDesempate: ((json['criteriosDesempate'] as List?) ?? const [])
          .map((e) {
        final c = CriterioDesempate.porWire(e as String);
        if (c == null) {
          throw FormatException('historico: criterio de desempate desconhecido "$e".');
        }
        return c;
      }).toList(growable: false),
      inicio: instante('inicio'),
      encerramento: instante('encerramento'),
      fases: ((json['fases'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      totalPartidas: (json['totalPartidas'] as int?) ?? 0,
      totalParticipantes: (json['totalParticipantes'] as int?) ?? 0,
      campeaoId: texto('campeaoId'),
      campeoes: ((json['campeoes'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(growable: false),
      viceId: json['viceId'] as String?,
      terceiroId: json['terceiroId'] as String?,
      classificacaoFinal: ((json['classificacaoFinal'] as List?) ?? const [])
          .map((e) => LinhaHistorico.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
      premiacoes: ((json['premiacoes'] as List?) ?? const [])
          .map((e) => PremioHistorico.fromMap(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  String toString() => 'RegistroHistorico($chaveIdempotencia campeao=$campeaoId)';
}

/// Monta o registro historico de uma edicao concluida (OS 02 secao 15).
///
/// Funcao pura: recebe a conclusao, a classificacao e o que foi premiado, e
/// devolve o snapshot. Nada e gravado.
RegistroHistorico montarHistorico({
  required EdicaoTorneio edicao,
  required TorneioTemplate template,
  required ConclusaoEdicao conclusao,
  required List<LinhaClassificacao> classificacaoFinal,
  required List<String> fases,
  required int totalPartidas,
  required List<PremiacaoPlanejada> premiacoes,
}) {
  final linhas = <LinhaHistorico>[];
  for (final linha in classificacaoFinal) {
    linhas.add(LinhaHistorico(
      posicao: linha.posicao,
      participanteId: linha.participanteId,
      membros: _membrosDe(linha.participanteId),
      vitorias: linha.desempenho.vitorias,
      derrotas: linha.desempenho.derrotas,
      pontosFeitos: linha.desempenho.pontosFeitos,
      pontosSofridos: linha.desempenho.pontosSofridos,
      canastrasLimpas: linha.desempenho.canastrasLimpas,
    ));
  }

  // So o que foi EFETIVAMENTE concedido entra no historico. Uma concessao
  // recusada (arte pendente, politica indefinida) nao pode aparecer no perfil
  // como premio recebido.
  final concedidos = <PremioHistorico>[];
  for (final p in premiacoes) {
    final temAtivo = p.resultado.concedida;
    final temFichas = (p.fichas ?? 0) > 0;
    if (!temAtivo && !temFichas) continue;
    concedidos.add(PremioHistorico(
      userId: p.userId,
      colocacao: p.colocacao,
      assetId: temAtivo ? p.resultado.concessao!.assetId : null,
      fichas: temFichas ? p.fichas : null,
    ));
  }

  return RegistroHistorico(
    tournamentId: edicao.tournamentId,
    editionId: edicao.editionId,
    nomeTorneio: template.nome,
    numeroEdicao: edicao.numeroEdicao,
    temporada: edicao.temporada,
    regraVersao: edicao.regraVersao,
    modalidade: template.modalidade,
    participacao: template.participacao,
    formato: template.formato,
    criteriosDesempate: template.criteriosDesempate,
    inicio: edicao.inicioPrevisto,
    encerramento: conclusao.concluidaEm,
    fases: fases,
    totalPartidas: totalPartidas,
    totalParticipantes: conclusao.totalParticipantes,
    campeaoId: conclusao.campeaoId,
    campeoes: conclusao.campeoes,
    viceId: conclusao.viceId,
    terceiroId: conclusao.terceiroId,
    classificacaoFinal: linhas,
    premiacoes: concedidos,
  );
}

List<String> _membrosDe(String participanteId) => participanteId.split('+');

/// Edicoes de que o jogador participou, da mais recente para a mais antiga.
List<RegistroHistorico> historicoDoJogador(
  Iterable<RegistroHistorico> historico,
  String userId,
) {
  final lista = historico.where((h) => h.participou(userId)).toList(growable: false)
    ..sort((a, b) => b.encerramento.compareTo(a.encerramento));
  return lista;
}

/// Titulos do jogador: torneios de que foi campeao, sem repetir o torneio.
///
/// Alimenta o criterio de elegibilidade `campeao:<tournamentId>` em
/// eligibility.dart.
Set<String> titulosDoJogador(
  Iterable<RegistroHistorico> historico,
  String userId,
) =>
    {
      for (final h in historico)
        if (h.campeoes.contains(userId)) h.tournamentId,
    };
