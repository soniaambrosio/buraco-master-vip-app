// assets_registry.dart — registro estavel de assets de torneios e premiacoes.
//
// Fundacao apenas: sem Firestore, sem logica de premiacao e sem dependencia de
// UI (nenhum import de flutter/material aqui, de proposito).
//
// Contrato: o `assetId` e o identificador canonico e imutavel. Regras futuras
// (premiacao, recorrencia, Hall dos Imortais, Firestore) devem referenciar
// `TorneioAssetIds.*` — nunca o nome fisico do PNG. Trocar ou renomear a arte
// altera somente `arquivoLocal`, sem quebrar regra nenhuma.
//
// Fonte de dados: app/data/torneios/assets_registry.seed.json.

import 'dart:convert';

enum TorneioAssetCategoria { capa, coroa, selo }

enum TorneioAssetStatus {
  /// Arte presente no repositorio e pronta para uso.
  ready,

  /// Arte ainda nao produzida; o identificador ja e estavel.
  pendingAsset,
}

/// Identificadores canonicos. Use estas constantes no lugar de strings soltas.
abstract final class TorneioAssetIds {
  // Capas de torneio.
  static const capaQuartaVulnerabilidade = 'capa_quarta_vulnerabilidade';
  static const capaSextaMasterVip = 'capa_sexta_master_vip';
  static const capaCopaBuracoMaster = 'capa_copa_buraco_master';
  static const capaDomingoPintando7 = 'capa_domingo_pintando_7';
  static const capaCampeonatoMensal = 'capa_campeonato_mensal';

  // Coroas.
  static const crownParticipant = 'crown_participant';
  static const crownTop3 = 'crown_top3';
  static const crownRunnerUp = 'crown_runner_up';
  static const crownChampion = 'crown_champion';
  static const crownMonthlyChampion = 'crown_monthly_champion';
  static const crownAnnualChampion = 'crown_annual_champion';
  static const crownLegendMaster = 'crown_legend_master';

  // Selos.
  static const sealParticipant = 'seal_participant';
  static const sealTop3 = 'seal_top3';
  static const sealRunnerUp = 'seal_runner_up';
  static const sealChampion = 'seal_champion';
  static const sealMonthlyChampion = 'seal_monthly_champion';
  static const sealAnnualChampion = 'seal_annual_champion';
  static const sealPerformance = 'seal_performance';
  static const sealFairPlay = 'seal_fair_play';

  // Encerramento de temporada.
  static const sealClosingGuest = 'seal_closing_guest';
  static const sealClosingChampion = 'seal_closing_champion';
  static const sealClosingRunnerUp = 'seal_closing_runner_up';
  static const crownClosingChampion = 'crown_closing_champion';

  /// Todos os identificadores esperados no seed. Serve de contrato de
  /// integridade: o seed nao pode faltar nem sobrar item em relacao a esta lista.
  static const todos = <String>[
    capaQuartaVulnerabilidade,
    capaSextaMasterVip,
    capaCopaBuracoMaster,
    capaDomingoPintando7,
    capaCampeonatoMensal,
    crownParticipant,
    crownTop3,
    crownRunnerUp,
    crownChampion,
    crownMonthlyChampion,
    crownAnnualChampion,
    crownLegendMaster,
    sealParticipant,
    sealTop3,
    sealRunnerUp,
    sealChampion,
    sealMonthlyChampion,
    sealAnnualChampion,
    sealPerformance,
    sealFairPlay,
    sealClosingGuest,
    sealClosingChampion,
    sealClosingRunnerUp,
    crownClosingChampion,
  ];
}

/// Definicao de um asset de torneio. DTO puro: sem estado, sem widget.
class TorneioAssetDefinicao {
  /// Identificador canonico e imutavel.
  final String assetId;

  final TorneioAssetCategoria categoria;

  /// Para que serve o asset, em linguagem de produto.
  final String finalidade;

  /// Caminho no bundle Flutter, ou null enquanto a arte nao existir.
  final String? arquivoLocal;

  /// true = permanece no perfil indefinidamente.
  final bool permanente;

  /// Validade padrao quando [permanente] e false; null caso contrario.
  final Duration? duracaoPadrao;

  final TorneioAssetStatus status;

  const TorneioAssetDefinicao({
    required this.assetId,
    required this.categoria,
    required this.finalidade,
    required this.arquivoLocal,
    required this.permanente,
    required this.duracaoPadrao,
    required this.status,
  });

  /// A arte ja existe no repositorio.
  bool get temArte => status == TorneioAssetStatus.ready && arquivoLocal != null;

  factory TorneioAssetDefinicao.fromJson(Map<String, dynamic> json) {
    final assetId = json['assetId'] as String;
    final permanente = json['permanente'] as bool;
    final duracao = _parseDuracao(json['duracaoPadrao'] as String?, assetId);

    if (permanente && duracao != null) {
      throw FormatException('$assetId: asset permanente nao pode ter duracaoPadrao.');
    }
    if (!permanente && duracao == null) {
      throw FormatException('$assetId: asset temporario exige duracaoPadrao.');
    }

    final status = _parseStatus(json['status'] as String, assetId);
    final arquivoLocal = json['arquivoLocal'] as String?;
    if (status == TorneioAssetStatus.ready && arquivoLocal == null) {
      throw FormatException('$assetId: status ready exige arquivoLocal.');
    }
    if (status == TorneioAssetStatus.pendingAsset && arquivoLocal != null) {
      throw FormatException('$assetId: status pendingAsset nao pode ter arquivoLocal.');
    }

    return TorneioAssetDefinicao(
      assetId: assetId,
      categoria: _parseCategoria(json['categoria'] as String, assetId),
      finalidade: json['finalidade'] as String,
      arquivoLocal: arquivoLocal,
      permanente: permanente,
      duracaoPadrao: duracao,
      status: status,
    );
  }

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'categoria': categoria.name,
        'finalidade': finalidade,
        'arquivoLocal': arquivoLocal,
        'permanente': permanente,
        'duracaoPadrao': duracaoPadrao == null ? null : 'P${duracaoPadrao!.inDays}D',
        'status': status.name,
      };

  static TorneioAssetCategoria _parseCategoria(String valor, String assetId) =>
      TorneioAssetCategoria.values.firstWhere(
        (c) => c.name == valor,
        orElse: () => throw FormatException('$assetId: categoria desconhecida "$valor".'),
      );

  static TorneioAssetStatus _parseStatus(String valor, String assetId) =>
      TorneioAssetStatus.values.firstWhere(
        (s) => s.name == valor,
        orElse: () => throw FormatException('$assetId: status desconhecido "$valor".'),
      );

  /// Aceita ISO-8601 restrito a dias inteiros (ex.: `P30D`).
  static Duration? _parseDuracao(String? valor, String assetId) {
    if (valor == null) return null;
    final m = RegExp(r'^P(\d+)D$').firstMatch(valor);
    if (m == null) {
      throw FormatException('$assetId: duracaoPadrao "$valor" fora do formato PnD.');
    }
    return Duration(days: int.parse(m.group(1)!));
  }
}

/// Colecao imutavel de definicoes, indexada por [assetId].
class TorneioAssetsRegistry {
  final int schemaVersion;
  final Map<String, TorneioAssetDefinicao> _porId;

  const TorneioAssetsRegistry._(this.schemaVersion, this._porId);

  /// Constroi a partir do conteudo bruto do seed JSON.
  factory TorneioAssetsRegistry.fromSeedJson(String source) =>
      TorneioAssetsRegistry.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory TorneioAssetsRegistry.fromMap(Map<String, dynamic> raiz) {
    final itens = (raiz['assets'] as List)
        .map((e) => TorneioAssetDefinicao.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final porId = <String, TorneioAssetDefinicao>{};
    for (final item in itens) {
      if (porId.containsKey(item.assetId)) {
        throw FormatException('assetId duplicado no seed: ${item.assetId}.');
      }
      porId[item.assetId] = item;
    }

    final esperados = TorneioAssetIds.todos.toSet();
    final faltando = esperados.difference(porId.keys.toSet());
    if (faltando.isNotEmpty) {
      throw FormatException('assetIds ausentes no seed: ${faltando.toList()..sort()}.');
    }
    final sobrando = porId.keys.toSet().difference(esperados);
    if (sobrando.isNotEmpty) {
      throw FormatException('assetIds nao declarados em TorneioAssetIds: ${sobrando.toList()..sort()}.');
    }

    return TorneioAssetsRegistry._(raiz['schemaVersion'] as int, porId);
  }

  Iterable<TorneioAssetDefinicao> get todos => _porId.values;

  /// Lanca se o [assetId] nao existir — falha cedo em vez de renderizar vazio.
  TorneioAssetDefinicao operator [](String assetId) =>
      _porId[assetId] ?? (throw ArgumentError('assetId desconhecido: $assetId'));

  TorneioAssetDefinicao? buscar(String assetId) => _porId[assetId];

  Iterable<TorneioAssetDefinicao> porCategoria(TorneioAssetCategoria categoria) =>
      _porId.values.where((a) => a.categoria == categoria);

  /// Assets cuja arte ainda precisa ser produzida.
  Iterable<TorneioAssetDefinicao> get pendentes =>
      _porId.values.where((a) => a.status == TorneioAssetStatus.pendingAsset);
}
