// colecao_campanha.dart — configuracao de campanha e avaliacao de elegibilidade.
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI e sem relogio. Todo
// insumo entra por parametro.
//
// ESCOPO: colecao_catalogo.dart diz QUAIS itens existem; este arquivo diz QUEM
// tem direito e QUANDO. O ato de resgatar vive em colecao_resgate.dart.
//
// ONDE A DECISAO VALE DE VERDADE
// A avaliacao aqui e DETERMINISTICA e serve a dois consumidores:
//   1. o cliente, para escolher qual estado da tela mostrar (apresentacao);
//   2. a camada segura (Cloud Function), que espelha exatamente estas regras e
//      e a UNICA que autoriza a gravacao.
// O veredito do cliente nunca concede nada. Um aparelho com relogio adiantado,
// APK modificado ou chamada direta pode produzir `elegivel` aqui e mesmo assim
// ser recusado no servidor — que e o comportamento desejado. Por isso
// [avaliarElegibilidade] exige `agora` por parametro e nunca le
// `DateTime.now()`: quem chama precisa declarar de onde veio o instante.
//
// Fonte de dados: app/data/colecoes/campanha_pioneiros_2026.seed.json, espelho
// versionado do documento Firestore `campaigns/pioneiros_2026`.

import 'dart:convert';

/// Estado administrativo da campanha.
enum StatusCampanha {
  /// Invisivel e sem concessao. Estado de entrega.
  draft('draft'),

  /// Campanha valendo.
  active('active'),

  /// Visivel conforme [CampanhaColecao.catalogVisibility], porem sem conceder.
  paused('paused'),

  /// Encerrada: resgates novos sao recusados e o inventario ja concedido
  /// permanece intacto.
  closed('closed');

  final String wire;
  const StatusCampanha(this.wire);

  /// Somente `active` autoriza concessao.
  bool get concede => this == active;
}

/// Como a elegibilidade e determinada. O criterio fica configuravel para que
/// mudar de regra nao exija novo build.
enum ModoElegibilidade {
  /// Lista segura de UIDs em subcolecao.
  allowlist('allowlist'),

  /// Participantes do teste fechado.
  closedTest('closedTest'),

  /// Concluiu partida dentro da janela da campanha.
  matchInWindow('matchInWindow'),

  /// Qualquer uma das evidencias acima serve.
  hybrid('hybrid'),

  /// Somente concessao administrativa explicita, caso a caso.
  adminGrant('adminGrant');

  final String wire;
  const ModoElegibilidade(this.wire);
}

/// O que o nao elegivel enxerga.
enum VisibilidadeCatalogo {
  /// Nao elegivel nao ve nada.
  hidden('hidden'),

  /// Nao elegivel ve a colecao bloqueada, sem poder resgatar.
  teaser('teaser');

  final String wire;
  const VisibilidadeCatalogo(this.wire);
}

/// Motivo pelo qual a elegibilidade foi recusada. Estado explicito e
/// serializavel: recusa silenciosa impede auditoria e vira suporte depois.
enum RecusaElegibilidade {
  /// A feature flag esta desligada.
  featureFlagDesligada('feature_flag_desligada'),

  /// A campanha nao esta em `active`.
  campanhaInativa('campanha_inativa'),

  /// Ainda nao chegou `startAt`.
  foraDaJanelaAntes('fora_da_janela_antes'),

  /// Ja passou `endAt`.
  foraDaJanelaDepois('fora_da_janela_depois'),

  /// Ja passou `claimDeadline`.
  prazoDeResgateEncerrado('prazo_de_resgate_encerrado'),

  /// Nenhuma evidencia satisfaz o modo configurado.
  semEvidencia('sem_evidencia');

  final String wire;
  const RecusaElegibilidade(this.wire);
}

/// Evidencias que a FONTE CONFIAVEL afirma sobre o jogador.
///
/// Nao e o cliente quem preenche isto por conta propria: cada campo espelha um
/// documento que so o backend/admin pode gravar (ver firebase/firestore.rules).
/// Um jogador que consiga forjar este objeto localmente muda apenas o que a
/// propria tela dele desenha — a gravacao continua barrada no servidor.
class EvidenciaElegibilidade {
  /// UID consta na subcolecao de elegiveis da campanha.
  final bool naAllowlist;

  /// UID consta como participante do teste fechado.
  final bool participouTesteFechado;

  /// Concluiu partida dentro da janela da campanha, atestado pelo backend.
  final bool concluiuPartidaNaJanela;

  /// Concessao administrativa explicita para este UID.
  final bool concessaoAdministrativa;

  const EvidenciaElegibilidade({
    this.naAllowlist = false,
    this.participouTesteFechado = false,
    this.concluiuPartidaNaJanela = false,
    this.concessaoAdministrativa = false,
  });

  /// Nenhuma evidencia — estado padrao de quem nunca foi marcado.
  static const nenhuma = EvidenciaElegibilidade();

  factory EvidenciaElegibilidade.fromMap(Map<String, dynamic> json) =>
      EvidenciaElegibilidade(
        naAllowlist: json['naAllowlist'] as bool? ?? false,
        participouTesteFechado: json['participouTesteFechado'] as bool? ?? false,
        concluiuPartidaNaJanela: json['concluiuPartidaNaJanela'] as bool? ?? false,
        concessaoAdministrativa: json['concessaoAdministrativa'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'naAllowlist': naAllowlist,
        'participouTesteFechado': participouTesteFechado,
        'concluiuPartidaNaJanela': concluiuPartidaNaJanela,
        'concessaoAdministrativa': concessaoAdministrativa,
      };
}

/// Veredito de [avaliarElegibilidade].
class VeredictoElegibilidade {
  final bool elegivel;

  /// null quando [elegivel] e true.
  final RecusaElegibilidade? recusa;

  const VeredictoElegibilidade.elegivel()
      : elegivel = true,
        recusa = null;

  const VeredictoElegibilidade.recusado(RecusaElegibilidade this.recusa)
      : elegivel = false;

  @override
  bool operator ==(Object other) =>
      other is VeredictoElegibilidade &&
      other.elegivel == elegivel &&
      other.recusa == recusa;

  @override
  int get hashCode => Object.hash(elegivel, recusa);

  @override
  String toString() => elegivel
      ? 'VeredictoElegibilidade.elegivel'
      : 'VeredictoElegibilidade.recusado(${recusa!.wire})';
}

/// Configuracao da campanha. DTO puro, espelho do documento Firestore.
class CampanhaColecao {
  final String campaignId;

  /// Colecao concedida por esta campanha; chave estrangeira para o catalogo.
  final String collectionId;

  final String displayName;

  /// Versao da campanha. Entra no documento de inventario (`campaignVersion`) e
  /// na chave de idempotencia: uma reedicao futura e concessao nova, nao
  /// repeticao da antiga.
  final int version;

  final StatusCampanha status;

  /// Chave da feature flag consultada antes de qualquer coisa.
  final String featureFlag;

  /// Janela de vigencia em UTC; null = sem limite daquele lado.
  final DateTime? startAt;
  final DateTime? endAt;

  /// Prazo final de resgate, independente de [endAt]; null = sem prazo.
  final DateTime? claimDeadline;

  final ModoElegibilidade eligibilityMode;

  /// Caminho da fonte confiavel de elegibilidade.
  final String eligibilitySource;

  final VisibilidadeCatalogo catalogVisibility;

  /// Composicao exata da concessao.
  final List<String> rewardIds;

  const CampanhaColecao({
    required this.campaignId,
    required this.collectionId,
    required this.displayName,
    required this.version,
    required this.status,
    required this.featureFlag,
    required this.startAt,
    required this.endAt,
    required this.claimDeadline,
    required this.eligibilityMode,
    required this.eligibilitySource,
    required this.catalogVisibility,
    required this.rewardIds,
  });

  /// Le o seed versionado (envelope com a chave `campanha`).
  factory CampanhaColecao.fromSeedJson(String source) {
    final raiz = jsonDecode(source) as Map<String, dynamic>;
    return CampanhaColecao.fromMap(raiz['campanha'] as Map<String, dynamic>);
  }

  /// Le o documento Firestore ja convertido em mapa.
  factory CampanhaColecao.fromMap(Map<String, dynamic> json) {
    final campaignId = _texto(json, 'campaignId');

    final version = json['version'];
    if (version is! int || version < 1) {
      throw FormatException('$campaignId: version deve ser inteiro >= 1 (recebido: $version).');
    }

    final rewardIds = (json['rewardIds'] as List?)?.cast<String>().toList(growable: false);
    if (rewardIds == null || rewardIds.isEmpty) {
      throw FormatException('$campaignId: rewardIds nao pode ser vazio.');
    }
    if (rewardIds.toSet().length != rewardIds.length) {
      throw FormatException('$campaignId: rewardIds tem itemId repetido.');
    }

    final startAt = _instanteUtc(json, 'startAt', campaignId);
    final endAt = _instanteUtc(json, 'endAt', campaignId);
    if (startAt != null && endAt != null && !endAt.isAfter(startAt)) {
      throw FormatException('$campaignId: endAt deve ser posterior a startAt.');
    }

    final claimDeadline = _instanteUtc(json, 'claimDeadline', campaignId);
    if (startAt != null && claimDeadline != null && !claimDeadline.isAfter(startAt)) {
      throw FormatException('$campaignId: claimDeadline deve ser posterior a startAt.');
    }

    return CampanhaColecao(
      campaignId: campaignId,
      collectionId: _texto(json, 'collectionId'),
      displayName: _texto(json, 'displayName'),
      version: version,
      status: _enumPorWire(StatusCampanha.values, _texto(json, 'status'),
          (e) => e.wire, campaignId, 'status'),
      featureFlag: _texto(json, 'featureFlag'),
      startAt: startAt,
      endAt: endAt,
      claimDeadline: claimDeadline,
      eligibilityMode: _enumPorWire(ModoElegibilidade.values,
          _texto(json, 'eligibilityMode'), (e) => e.wire, campaignId, 'eligibilityMode'),
      eligibilitySource: _texto(json, 'eligibilitySource'),
      catalogVisibility: _enumPorWire(VisibilidadeCatalogo.values,
          _texto(json, 'catalogVisibility'), (e) => e.wire, campaignId, 'catalogVisibility'),
      rewardIds: List.unmodifiable(rewardIds),
    );
  }

  Map<String, dynamic> toJson() => {
        'campaignId': campaignId,
        'collectionId': collectionId,
        'displayName': displayName,
        'version': version,
        'status': status.wire,
        'featureFlag': featureFlag,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'claimDeadline': claimDeadline?.toIso8601String(),
        'eligibilityMode': eligibilityMode.wire,
        'eligibilitySource': eligibilitySource,
        'catalogVisibility': catalogVisibility.wire,
        'rewardIds': rewardIds,
      };

  /// Confere que a campanha concede exatamente a composicao esperada. Chamado no
  /// carregamento: uma campanha que prometa nove itens onde o contrato diz dez e
  /// erro de configuracao, nao uma variacao aceitavel.
  void validarComposicao(List<String> esperados) {
    final declarados = rewardIds.toSet();
    final alvo = esperados.toSet();

    final faltando = alvo.difference(declarados);
    if (faltando.isNotEmpty) {
      throw FormatException('$campaignId: rewardIds sem os itens ${faltando.toList()..sort()}.');
    }
    final sobrando = declarados.difference(alvo);
    if (sobrando.isNotEmpty) {
      throw FormatException('$campaignId: rewardIds com itens fora do contrato ${sobrando.toList()..sort()}.');
    }
  }

  static String _texto(Map<String, dynamic> json, String campo) {
    final Object? valor = json[campo];
    if (valor is! String || valor.isEmpty) {
      throw FormatException('campanha: $campo deve ser string nao vazia (recebido: $valor).');
    }
    return valor;
  }

  /// Exige ISO-8601 explicitamente em UTC, pela mesma razao adotada em
  /// lib/torneios/reward_grants.dart: data sem fuso seria interpretada com o
  /// relogio de quem le, e a mesma campanha abriria em horas diferentes em cada
  /// aparelho.
  static DateTime? _instanteUtc(Map<String, dynamic> json, String campo, String contexto) {
    final Object? valor = json[campo];
    if (valor == null) return null;
    if (valor is! String || valor.isEmpty) {
      throw FormatException('$contexto: $campo deve ser string ISO-8601 em UTC (recebido: $valor).');
    }
    final instante = DateTime.tryParse(valor);
    if (instante == null) {
      throw FormatException('$contexto: $campo nao e ISO-8601 valido (recebido: $valor).');
    }
    if (!instante.isUtc) {
      throw FormatException('$contexto: $campo deve estar em UTC, com sufixo Z (recebido: $valor).');
    }
    return instante;
  }

  static T _enumPorWire<T>(
    List<T> valores,
    String wire,
    String Function(T) leitor,
    String contexto,
    String campo,
  ) {
    for (final v in valores) {
      if (leitor(v) == wire) return v;
    }
    throw FormatException('$contexto: $campo desconhecido "$wire".');
  }
}

/// Decide se o jogador pode resgatar, e explica por que nao quando nao pode.
///
/// Funcao pura: nao le relogio, nao consulta rede e nao grava. A ordem das
/// checagens e estavel para que a recusa reportada seja sempre a mesma diante do
/// mesmo estado — feature flag primeiro, porque desligada ela vence tudo.
///
/// [featureFlagLigada] chega de fora (Remote Config/documento de flags) em vez de
/// ser lida daqui: a flag e infraestrutura, nao configuracao da campanha, e
/// precisa poder desligar a campanha inteira sem editar o documento dela.
///
/// [agora] deve ser o instante do SERVIDOR. Ver a nota no topo do arquivo: o
/// veredito calculado com relogio local serve para desenhar tela, nunca para
/// autorizar gravacao.
VeredictoElegibilidade avaliarElegibilidade({
  required CampanhaColecao campanha,
  required EvidenciaElegibilidade evidencia,
  required bool featureFlagLigada,
  required DateTime agora,
}) {
  if (!featureFlagLigada) {
    return const VeredictoElegibilidade.recusado(RecusaElegibilidade.featureFlagDesligada);
  }
  if (!campanha.status.concede) {
    return const VeredictoElegibilidade.recusado(RecusaElegibilidade.campanhaInativa);
  }

  final momento = agora.toUtc();

  final inicio = campanha.startAt;
  if (inicio != null && momento.isBefore(inicio)) {
    return const VeredictoElegibilidade.recusado(RecusaElegibilidade.foraDaJanelaAntes);
  }

  // Janela fechada no inicio e aberta no fim: `[startAt, endAt)`. No instante
  // exato de endAt a campanha ja acabou, senao duas edicoes consecutivas se
  // sobreporiam por um tick na virada.
  final fim = campanha.endAt;
  if (fim != null && !momento.isBefore(fim)) {
    return const VeredictoElegibilidade.recusado(RecusaElegibilidade.foraDaJanelaDepois);
  }

  final prazo = campanha.claimDeadline;
  if (prazo != null && !momento.isBefore(prazo)) {
    return const VeredictoElegibilidade.recusado(RecusaElegibilidade.prazoDeResgateEncerrado);
  }

  return _satisfazModo(campanha.eligibilityMode, evidencia)
      ? const VeredictoElegibilidade.elegivel()
      : const VeredictoElegibilidade.recusado(RecusaElegibilidade.semEvidencia);
}

/// Concessao administrativa vale em QUALQUER modo, de proposito: e a valvula de
/// correcao prevista para atender um jogador caso a caso sem alterar o modo da
/// campanha nem publicar novo build. Ela continua exigindo gravacao de admin e
/// gerando auditoria (ver firebase/firestore.rules).
bool _satisfazModo(ModoElegibilidade modo, EvidenciaElegibilidade e) {
  if (e.concessaoAdministrativa) return true;

  switch (modo) {
    case ModoElegibilidade.allowlist:
      return e.naAllowlist;
    case ModoElegibilidade.closedTest:
      return e.participouTesteFechado;
    case ModoElegibilidade.matchInWindow:
      return e.concluiuPartidaNaJanela;
    case ModoElegibilidade.hybrid:
      return e.naAllowlist || e.participouTesteFechado || e.concluiuPartidaNaJanela;
    case ModoElegibilidade.adminGrant:
      return false;
  }
}
