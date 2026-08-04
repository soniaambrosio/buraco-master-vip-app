// reward_policies.dart — politica de recompensa por assetId.
//
// Fundacao apenas: nenhuma logica de premiacao, expiracao ou Firestore roda
// aqui. Este arquivo so declara e valida a REGRA; quem a aplica vem depois.
//
// ESCOPO: separado de assets_registry.dart de proposito. La mora a arte
// (arquivo, categoria, status), aqui mora a politica (permanencia, duracao,
// hierarquia, contador). Trocar um PNG nao pode mexer em regra de premiacao.
//
// Fonte de dados: app/data/torneios/reward_policies.seed.json.

import 'dart:convert';

import 'assets_registry.dart';

/// Como a recompensa deixa (ou nao) de valer.
enum ExpirationPolicy {
  /// Nunca expira.
  permanent('permanent'),

  /// Expira apos [RecompensaPolitica.defaultDuration] a partir da concessao.
  fixedDuration('fixed_duration'),

  /// Vale ate a proxima edicao do mesmo torneio;
  /// [RecompensaPolitica.defaultDuration] e o teto caso a proxima edicao atrase.
  untilNextEdition('until_next_edition'),

  /// Regra de expiracao ainda nao definida pela administracao. Estado
  /// deliberado: nao substituir por um prazo chutado.
  pendingAdminDefinition('pending_admin_definition');

  final String wire;
  const ExpirationPolicy(this.wire);

  bool get exigeDuracao => this == fixedDuration || this == untilNextEdition;
}

/// Politica de recompensa de um asset. DTO puro: sem estado, sem widget.
class RecompensaPolitica {
  /// Chave estrangeira para o registro de assets.
  final String assetId;

  final ExpirationPolicy expirationPolicy;

  /// Validade em [ExpirationPolicy.fixedDuration]; teto maximo em
  /// [ExpirationPolicy.untilNextEdition]; null nos demais casos.
  final Duration? defaultDuration;

  /// Ordem de prestigio crescente, para desempate de exibicao.
  /// null enquanto a ordem nao tiver sido definida.
  final int? hierarquia;

  /// true = concessoes repetidas incrementam um contador em vez de duplicar
  /// a insignia no perfil.
  final bool acumulaContador;

  const RecompensaPolitica({
    required this.assetId,
    required this.expirationPolicy,
    required this.defaultDuration,
    required this.hierarquia,
    required this.acumulaContador,
  });

  bool get permanente => expirationPolicy == ExpirationPolicy.permanent;

  /// A duracao ainda depende de decisao administrativa.
  bool get aguardaDefinicao =>
      expirationPolicy == ExpirationPolicy.pendingAdminDefinition;

  factory RecompensaPolitica.fromJson(Map<String, dynamic> json) {
    final assetId = json['assetId'] as String;
    final policy = _parsePolicy(json['expirationPolicy'] as String, assetId);
    final duracao = _parseDuracao(json['defaultDuration'] as String?, assetId);

    if (policy.exigeDuracao && duracao == null) {
      throw FormatException('$assetId: ${policy.wire} exige defaultDuration.');
    }
    if (!policy.exigeDuracao && duracao != null) {
      throw FormatException('$assetId: ${policy.wire} nao pode ter defaultDuration.');
    }

    final hierarquia = json['hierarquia'] as int?;
    if (hierarquia != null && hierarquia < 1) {
      throw FormatException('$assetId: hierarquia deve ser >= 1 ou null.');
    }

    return RecompensaPolitica(
      assetId: assetId,
      expirationPolicy: policy,
      defaultDuration: duracao,
      hierarquia: hierarquia,
      acumulaContador: json['acumulaContador'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'expirationPolicy': expirationPolicy.wire,
        'defaultDuration':
            defaultDuration == null ? null : 'P${defaultDuration!.inDays}D',
        'hierarquia': hierarquia,
        'acumulaContador': acumulaContador,
      };

  static ExpirationPolicy _parsePolicy(String valor, String assetId) =>
      ExpirationPolicy.values.firstWhere(
        (p) => p.wire == valor,
        orElse: () => throw FormatException('$assetId: expirationPolicy desconhecida "$valor".'),
      );

  /// Aceita ISO-8601 restrito a dias inteiros (ex.: `P35D`).
  static Duration? _parseDuracao(String? valor, String assetId) {
    if (valor == null) return null;
    final m = RegExp(r'^P(\d+)D$').firstMatch(valor);
    if (m == null) {
      throw FormatException('$assetId: defaultDuration "$valor" fora do formato PnD.');
    }
    final dias = int.parse(m.group(1)!);
    if (dias < 1) {
      throw FormatException('$assetId: defaultDuration deve ser >= P1D.');
    }
    return Duration(days: dias);
  }
}

/// Colecao imutavel de politicas, indexada por [assetId].
class RewardPoliciesRegistry {
  final int schemaVersion;
  final Map<String, RecompensaPolitica> _porId;

  const RewardPoliciesRegistry._(this.schemaVersion, this._porId);

  factory RewardPoliciesRegistry.fromSeedJson(String source) =>
      RewardPoliciesRegistry.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory RewardPoliciesRegistry.fromMap(Map<String, dynamic> raiz) {
    final itens = (raiz['policies'] as List)
        .map((e) => RecompensaPolitica.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final porId = <String, RecompensaPolitica>{};
    for (final item in itens) {
      if (porId.containsKey(item.assetId)) {
        throw FormatException('assetId duplicado nas politicas: ${item.assetId}.');
      }
      porId[item.assetId] = item;
    }

    return RewardPoliciesRegistry._(raiz['schemaVersion'] as int, porId);
  }

  Iterable<RecompensaPolitica> get todas => _porId.values;

  RecompensaPolitica operator [](String assetId) =>
      _porId[assetId] ?? (throw ArgumentError('assetId sem politica: $assetId'));

  RecompensaPolitica? buscar(String assetId) => _porId[assetId];

  /// Politicas cuja duracao ainda depende de decisao administrativa.
  Iterable<RecompensaPolitica> get aguardandoDefinicao =>
      _porId.values.where((p) => p.aguardaDefinicao);

  /// Checagem cruzada entre os dois seeds: toda coroa/selo precisa de exatamente
  /// uma politica, e nenhuma politica pode apontar para asset inexistente ou
  /// para uma capa (capa nao e recompensa).
  void validarCobertura(TorneioAssetsRegistry assets) {
    final esperados = assets.recompensaveis.map((a) => a.assetId).toSet();
    final declarados = _porId.keys.toSet();

    final semPolitica = esperados.difference(declarados);
    if (semPolitica.isNotEmpty) {
      throw FormatException('assets sem politica: ${semPolitica.toList()..sort()}.');
    }

    for (final assetId in declarados.difference(esperados)) {
      final asset = assets.buscar(assetId);
      throw FormatException(asset == null
          ? 'politica aponta para assetId inexistente: $assetId.'
          : 'politica declarada para asset nao recompensavel: $assetId.');
    }
  }
}
