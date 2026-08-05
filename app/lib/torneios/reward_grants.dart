// reward_grants.dart — dominio de concessao de recompensas de torneio.
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI e sem timer. Aqui se
// decide SE uma recompensa pode ser concedida, ATE QUANDO ela vale e COMO o
// historico e agregado. Quem persiste, distribui ou desenha vem depois.
//
// ESCOPO: assets_registry.dart descreve a ARTE, reward_policies.dart descreve a
// REGRA, e este arquivo descreve o ATO de conceder. Nenhuma distribuicao
// automatica de premio e implementada nesta etapa.
//
// DATAS: todo instante e normalizado para UTC na fronteira. Comparar validade
// em fuso local tornaria a auditoria dependente do relogio do aparelho — duas
// leituras do mesmo registro poderiam divergir. As telas continuam livres para
// formatar em horario local; a decisao de validade nao.

import 'assets_registry.dart';
import 'reward_policies.dart';

/// Por que a recompensa foi concedida.
enum MotivoConcessao {
  /// Definido pela colocacao final na edicao; exige
  /// [RecompensaConcessao.colocacao].
  colocacao('colocacao'),

  /// Concluiu a edicao, sem recorte de podio.
  participacao('participacao'),

  /// Marcas em quadra (canastras, saldo, sequencias).
  desempenho('desempenho'),

  /// Conduta na edicao, sem abandono nem penalidade.
  fairPlay('fair_play'),

  /// Presenca por convite, como no torneio de encerramento anual.
  convite('convite'),

  /// Titulo honorifico de catalogo, como o Hall dos Imortais.
  consagracao('consagracao');

  final String wire;
  const MotivoConcessao(this.wire);

  bool get exigeColocacao => this == colocacao;
}

/// Motivo pelo qual a concessao foi recusada. Estado explicito e serializavel:
/// recusa silenciosa impede auditoria depois.
enum RecusaConcessao {
  /// O `assetId` nao existe no registro de assets.
  assetInexistente('asset_inexistente'),

  /// O asset existe, mas nao ha politica declarada para ele.
  politicaInexistente('politica_inexistente'),

  /// A arte ainda nao foi produzida (`status: pendingAsset`).
  artePendente('arte_pendente'),

  /// A regra de expiracao ainda depende da administracao
  /// (`pending_admin_definition`). Nao substituir por prazo chutado.
  politicaPendenteDefinicao('politica_pendente_definicao'),

  /// Coroa sem ordem de prestigio definida. Selo pode ter `hierarquia: null`.
  hierarquiaAusente('hierarquia_ausente'),

  /// A politica exige duracao e ela nao foi informada.
  duracaoAusente('duracao_ausente'),

  /// Duracao informada, porem nao positiva.
  duracaoInvalida('duracao_invalida'),

  /// A proxima edicao foi informada em instante anterior ou igual a concessao:
  /// a recompensa nasceria expirada. Dado inconsistente, nao arbitrar.
  proximaEdicaoInvalida('proxima_edicao_invalida'),

  /// Ja existe concessao com a mesma chave de idempotencia.
  concessaoDuplicada('concessao_duplicada');

  final String wire;
  const RecusaConcessao(this.wire);
}

/// Veredito de [podeAtivarRecompensa].
class ResultadoAtivacao {
  final bool permitido;

  /// null quando [permitido] e true.
  final RecusaConcessao? recusa;

  const ResultadoAtivacao.permitida()
      : permitido = true,
        recusa = null;

  const ResultadoAtivacao.recusada(RecusaConcessao this.recusa)
      : permitido = false;

  @override
  bool operator ==(Object other) =>
      other is ResultadoAtivacao &&
      other.permitido == permitido &&
      other.recusa == recusa;

  @override
  int get hashCode => Object.hash(permitido, recusa);

  @override
  String toString() =>
      permitido ? 'ResultadoAtivacao.permitida' : 'ResultadoAtivacao.recusada(${recusa!.wire})';
}

/// Chave determinista de idempotencia.
///
/// Contrato: `editionId + userId + assetId`. O mesmo jogador nao recebe duas
/// vezes o mesmo ativo na mesma edicao — e a chave e reproduzivel offline, sem
/// consultar nada, o que permite deduplicar no cliente e no servidor com o
/// mesmo resultado.
abstract final class ChaveIdempotencia {
  /// Separador que nao pode aparecer nos segmentos, sob pena de duas chaves
  /// distintas colidirem em uma so string.
  static const separador = '|';

  static String de({
    required String editionId,
    required String userId,
    required String assetId,
  }) {
    _exigirSegmento(editionId, 'editionId');
    _exigirSegmento(userId, 'userId');
    _exigirSegmento(assetId, 'assetId');
    return '$editionId$separador$userId$separador$assetId';
  }

  static void _exigirSegmento(String valor, String campo) {
    if (valor.isEmpty) {
      throw ArgumentError.value(valor, campo, 'nao pode ser vazio');
    }
    if (valor.contains(separador)) {
      throw ArgumentError.value(valor, campo, 'nao pode conter "$separador"');
    }
  }
}

/// Valida se um ativo pode virar recompensa ativa, considerando arte e politica.
///
/// Nao decide validade nem duplicidade: veja [resolverValidade] e
/// [concederRecompensa]. A ordem das checagens e estavel para que a recusa
/// reportada seja sempre a mesma diante do mesmo estado.
ResultadoAtivacao podeAtivarRecompensa({
  required String assetId,
  required TorneioAssetsRegistry assets,
  required RewardPoliciesRegistry politicas,
}) {
  final asset = assets.buscar(assetId);
  if (asset == null) {
    return const ResultadoAtivacao.recusada(RecusaConcessao.assetInexistente);
  }

  final politica = politicas.buscar(assetId);
  if (politica == null) {
    return const ResultadoAtivacao.recusada(RecusaConcessao.politicaInexistente);
  }

  if (asset.status == TorneioAssetStatus.pendingAsset) {
    return const ResultadoAtivacao.recusada(RecusaConcessao.artePendente);
  }

  if (politica.aguardaDefinicao) {
    return const ResultadoAtivacao.recusada(RecusaConcessao.politicaPendenteDefinicao);
  }

  // Coroa ocupa posicao de prestigio e por isso exige ordem definida. Selo e
  // acervo historico e pode viver com `hierarquia: null` — a diferenca e
  // deliberada, nao uma lacuna de dados.
  if (asset.categoria == TorneioAssetCategoria.coroa && politica.hierarquia == null) {
    return const ResultadoAtivacao.recusada(RecusaConcessao.hierarquiaAusente);
  }

  if (politica.expirationPolicy.exigeDuracao) {
    final duracao = politica.defaultDuration;
    if (duracao == null) {
      return const ResultadoAtivacao.recusada(RecusaConcessao.duracaoAusente);
    }
    if (duracao <= Duration.zero) {
      return const ResultadoAtivacao.recusada(RecusaConcessao.duracaoInvalida);
    }
  }

  return const ResultadoAtivacao.permitida();
}

/// Veredito de [resolverValidade].
class ResolucaoValidade {
  /// Instante de expiracao em UTC; null significa permanente.
  final DateTime? expiresAt;

  /// null quando a validade foi resolvida.
  final RecusaConcessao? recusa;

  const ResolucaoValidade._(this.expiresAt, this.recusa);

  const ResolucaoValidade.permanente() : this._(null, null);

  ResolucaoValidade.ate(DateTime expiresAt) : this._(expiresAt, null);

  const ResolucaoValidade.recusada(RecusaConcessao recusa) : this._(null, recusa);

  bool get resolvida => recusa == null;

  /// Resolvida e sem prazo de fim.
  bool get permanente => resolvida && expiresAt == null;

  @override
  String toString() => resolvida
      ? 'ResolucaoValidade(${expiresAt?.toIso8601String() ?? "permanente"})'
      : 'ResolucaoValidade.recusada(${recusa!.wire})';
}

/// Calcula ate quando a recompensa vale. Funcao pura: nao le relogio, nao
/// persiste e nao consulta rede — todo insumo entra por parametro.
///
/// [proximaEdicaoEm] so e consultado em `until_next_edition`; nos demais casos e
/// ignorado. Quando a proxima edicao ainda nao tem data, vale o teto de
/// `defaultDuration` — a recompensa nunca fica pendurada indefinidamente por
/// falta de calendario.
ResolucaoValidade resolverValidade({
  required RecompensaPolitica politica,
  required DateTime grantedAt,
  DateTime? proximaEdicaoEm,
}) {
  final inicio = grantedAt.toUtc();

  switch (politica.expirationPolicy) {
    case ExpirationPolicy.permanent:
      return const ResolucaoValidade.permanente();

    case ExpirationPolicy.fixedDuration:
      final duracao = politica.defaultDuration;
      if (duracao == null) {
        return const ResolucaoValidade.recusada(RecusaConcessao.duracaoAusente);
      }
      if (duracao <= Duration.zero) {
        return const ResolucaoValidade.recusada(RecusaConcessao.duracaoInvalida);
      }
      return ResolucaoValidade.ate(inicio.add(duracao));

    case ExpirationPolicy.untilNextEdition:
      // Em `until_next_edition` a duracao e TETO, nao validade: se a proxima
      // edicao atrasar, a recompensa expira no teto assim mesmo.
      final teto = politica.defaultDuration;
      if (teto == null) {
        return const ResolucaoValidade.recusada(RecusaConcessao.duracaoAusente);
      }
      if (teto <= Duration.zero) {
        return const ResolucaoValidade.recusada(RecusaConcessao.duracaoInvalida);
      }
      final limite = inicio.add(teto);
      final proxima = proximaEdicaoEm?.toUtc();
      if (proxima == null) return ResolucaoValidade.ate(limite);
      if (!proxima.isAfter(inicio)) {
        return const ResolucaoValidade.recusada(RecusaConcessao.proximaEdicaoInvalida);
      }
      return ResolucaoValidade.ate(proxima.isBefore(limite) ? proxima : limite);

    case ExpirationPolicy.pendingAdminDefinition:
      return const ResolucaoValidade.recusada(RecusaConcessao.politicaPendenteDefinicao);
  }
}

/// Registro historico individual de uma recompensa concedida.
///
/// Cada concessao e um registro proprio e permanece no historico mesmo quando o
/// selo aparece uma unica vez no perfil com contador agregado: o contador e
/// projecao, o registro e a fonte.
class RecompensaConcessao {
  /// Identificador do registro de concessao. Distinto de [chaveIdempotencia]:
  /// este identifica a LINHA, aquela identifica o DIREITO.
  final String rewardId;

  final String userId;
  final String tournamentId;
  final String editionId;

  /// Chave estrangeira para o registro de assets.
  final String assetId;

  /// Instante da concessao, sempre em UTC.
  final DateTime grantedAt;

  /// Instante de expiracao em UTC; null = permanente.
  final DateTime? expiresAt;

  final MotivoConcessao motivo;

  /// Colocacao final na edicao; obrigatoria e >= 1 quando
  /// [MotivoConcessao.colocacao], nula nos demais motivos.
  final int? colocacao;

  /// `editionId + userId + assetId`. Sempre derivada, nunca recebida pronta.
  final String chaveIdempotencia;

  RecompensaConcessao._({
    required this.rewardId,
    required this.userId,
    required this.tournamentId,
    required this.editionId,
    required this.assetId,
    required this.grantedAt,
    required this.expiresAt,
    required this.motivo,
    required this.colocacao,
    required this.chaveIdempotencia,
  });

  factory RecompensaConcessao({
    required String rewardId,
    required String userId,
    required String tournamentId,
    required String editionId,
    required String assetId,
    required DateTime grantedAt,
    required DateTime? expiresAt,
    required MotivoConcessao motivo,
    int? colocacao,
  }) {
    if (rewardId.isEmpty) {
      throw ArgumentError.value(rewardId, 'rewardId', 'nao pode ser vazio');
    }
    if (tournamentId.isEmpty) {
      throw ArgumentError.value(tournamentId, 'tournamentId', 'nao pode ser vazio');
    }
    if (motivo.exigeColocacao) {
      if (colocacao == null) {
        throw ArgumentError.value(colocacao, 'colocacao', 'obrigatoria em ${motivo.wire}');
      }
      if (colocacao < 1) {
        throw ArgumentError.value(colocacao, 'colocacao', 'deve ser >= 1');
      }
    } else if (colocacao != null) {
      throw ArgumentError.value(colocacao, 'colocacao', 'so vale em ${MotivoConcessao.colocacao.wire}');
    }

    final inicio = grantedAt.toUtc();
    final fim = expiresAt?.toUtc();
    if (fim != null && !fim.isAfter(inicio)) {
      throw ArgumentError.value(expiresAt, 'expiresAt', 'deve ser posterior a grantedAt');
    }

    return RecompensaConcessao._(
      rewardId: rewardId,
      userId: userId,
      tournamentId: tournamentId,
      editionId: editionId,
      assetId: assetId,
      grantedAt: inicio,
      expiresAt: fim,
      motivo: motivo,
      colocacao: colocacao,
      chaveIdempotencia: ChaveIdempotencia.de(
        editionId: editionId,
        userId: userId,
        assetId: assetId,
      ),
    );
  }

  bool get permanente => expiresAt == null;

  /// Vale no instante informado. Permanente vale sempre.
  bool ativaEm(DateTime instante) =>
      expiresAt == null || instante.toUtc().isBefore(expiresAt!);

  Map<String, dynamic> toJson() => {
        'rewardId': rewardId,
        'userId': userId,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'assetId': assetId,
        'grantedAt': grantedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'motivo': motivo.wire,
        'colocacao': colocacao,
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'RecompensaConcessao($chaveIdempotencia @ ${grantedAt.toIso8601String()})';
}

/// Veredito de [concederRecompensa].
class ResultadoConcessao {
  /// null quando houve recusa.
  final RecompensaConcessao? concessao;

  /// null quando a concessao foi emitida.
  final RecusaConcessao? recusa;

  const ResultadoConcessao._(this.concessao, this.recusa);

  const ResultadoConcessao.concedida(RecompensaConcessao concessao)
      : this._(concessao, null);

  const ResultadoConcessao.recusada(RecusaConcessao recusa) : this._(null, recusa);

  bool get concedida => concessao != null;

  @override
  String toString() => concedida
      ? 'ResultadoConcessao.concedida(${concessao!.chaveIdempotencia})'
      : 'ResultadoConcessao.recusada(${recusa!.wire})';
}

/// Emite uma concessao, ou explica por que nao emitiu.
///
/// Encadeia, nesta ordem: ativacao ([podeAtivarRecompensa]), idempotencia contra
/// [historico] e validade ([resolverValidade]). Puro: [historico] entra por
/// parametro e nada e gravado — cabe a camada de persistencia anexar o registro
/// devolvido.
ResultadoConcessao concederRecompensa({
  required String rewardId,
  required String userId,
  required String tournamentId,
  required String editionId,
  required String assetId,
  required DateTime grantedAt,
  required MotivoConcessao motivo,
  required TorneioAssetsRegistry assets,
  required RewardPoliciesRegistry politicas,
  int? colocacao,
  DateTime? proximaEdicaoEm,
  Iterable<RecompensaConcessao> historico = const <RecompensaConcessao>[],
}) {
  final ativacao = podeAtivarRecompensa(
    assetId: assetId,
    assets: assets,
    politicas: politicas,
  );
  if (!ativacao.permitido) {
    return ResultadoConcessao.recusada(ativacao.recusa!);
  }

  final chave = ChaveIdempotencia.de(
    editionId: editionId,
    userId: userId,
    assetId: assetId,
  );
  if (historico.any((c) => c.chaveIdempotencia == chave)) {
    return const ResultadoConcessao.recusada(RecusaConcessao.concessaoDuplicada);
  }

  final validade = resolverValidade(
    politica: politicas[assetId],
    grantedAt: grantedAt,
    proximaEdicaoEm: proximaEdicaoEm,
  );
  if (!validade.resolvida) {
    return ResultadoConcessao.recusada(validade.recusa!);
  }

  return ResultadoConcessao.concedida(RecompensaConcessao(
    rewardId: rewardId,
    userId: userId,
    tournamentId: tournamentId,
    editionId: editionId,
    assetId: assetId,
    grantedAt: grantedAt,
    expiresAt: validade.expiresAt,
    motivo: motivo,
    colocacao: colocacao,
  ));
}

/// Chave de agregacao do contador: `userId + assetId`.
class ChaveContador {
  final String userId;
  final String assetId;

  const ChaveContador(this.userId, this.assetId);

  @override
  bool operator ==(Object other) =>
      other is ChaveContador && other.userId == userId && other.assetId == assetId;

  @override
  int get hashCode => Object.hash(userId, assetId);

  @override
  String toString() => '$userId/$assetId';
}

/// Agrega quantas concessoes permanentes cada jogador tem por ativo.
///
/// Projecao de leitura: o selo aparece uma vez no perfil com o contador ao lado,
/// enquanto cada concessao segue existindo como registro proprio em [historico].
/// A funcao nao remove, nao funde e nao reescreve nada — recebe o historico como
/// [Iterable] e devolve um mapa novo.
Map<ChaveContador, int> contarConcessoesPermanentes(
  Iterable<RecompensaConcessao> historico,
) {
  final contagem = <ChaveContador, int>{};
  for (final concessao in historico) {
    if (!concessao.permanente) continue;
    final chave = ChaveContador(concessao.userId, concessao.assetId);
    contagem[chave] = (contagem[chave] ?? 0) + 1;
  }
  return contagem;
}

/// Contador de um par especifico. Zero quando nunca houve concessao permanente.
int contarPermanentesDe(
  Iterable<RecompensaConcessao> historico, {
  required String userId,
  required String assetId,
}) =>
    historico
        .where((c) => c.permanente && c.userId == userId && c.assetId == assetId)
        .length;
