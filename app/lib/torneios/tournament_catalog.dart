// tournament_catalog.dart — catalogo dos torneios previstos
// (OS 02 secoes 2 e 14).
//
// Camada pura: sem Firestore, sem UI.
//
// Fonte de dados: app/data/torneios/tournaments.seed.json.
//
// Mesma disciplina de assets_registry.dart e reward_policies.dart: os
// identificadores canonicos ficam em constantes, o seed e validado contra elas na
// carga, e o registro e imutavel. Referenciar `TorneioIds.*` em vez de string
// solta e o que impede um erro de digitacao virar torneio fantasma.

import 'dart:convert';

import 'assets_registry.dart';
import 'tournament_model.dart';

/// Identificadores canonicos dos torneios.
abstract final class TorneioIds {
  static const quartaVulnerabilidade = 'quarta_vulnerabilidade';
  static const sextaMasterVip = 'sexta_master_vip';
  static const copaBuracoMaster = 'copa_buraco_master';
  static const domingoPintando7 = 'domingo_pintando_7';
  static const campeonatoMensal = 'campeonato_mensal';
  static const encerramentoAnual = 'encerramento_anual';

  /// Os cinco torneios da OS 02 secao 2.
  static const previstos = <String>[
    quartaVulnerabilidade,
    sextaMasterVip,
    copaBuracoMaster,
    domingoPintando7,
    campeonatoMensal,
  ];

  /// Tudo que o seed precisa conter: os cinco previstos mais o encerramento
  /// anual da secao 16.
  static const todos = <String>[...previstos, encerramentoAnual];
}

/// Colecao imutavel de templates, indexada por `tournamentId`.
class TorneioCatalogo {
  final int schemaVersion;
  final Map<String, TorneioTemplate> _porId;

  const TorneioCatalogo._(this.schemaVersion, this._porId);

  factory TorneioCatalogo.fromSeedJson(String source) =>
      TorneioCatalogo.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory TorneioCatalogo.fromMap(Map<String, dynamic> raiz) {
    final itens = (raiz['tournaments'] as List)
        .map((e) => TorneioTemplate.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final porId = <String, TorneioTemplate>{};
    for (final item in itens) {
      if (porId.containsKey(item.tournamentId)) {
        throw FormatException('tournamentId duplicado no seed: ${item.tournamentId}.');
      }
      porId[item.tournamentId] = item;
    }

    final esperados = TorneioIds.todos.toSet();
    final faltando = esperados.difference(porId.keys.toSet());
    if (faltando.isNotEmpty) {
      throw FormatException('tournamentIds ausentes no seed: ${faltando.toList()..sort()}.');
    }
    final sobrando = porId.keys.toSet().difference(esperados);
    if (sobrando.isNotEmpty) {
      throw FormatException(
          'tournamentIds nao declarados em TorneioIds: ${sobrando.toList()..sort()}.');
    }

    // `tipo` e `tournamentId` sao dois campos que dizem a mesma coisa e podem
    // divergir por descuido de edicao. Divergencia aqui faria uma consulta por
    // tipo devolver o torneio errado.
    for (final t in itens) {
      if (t.tipo.wire != t.tournamentId) {
        throw FormatException(
            '${t.tournamentId}: tipo "${t.tipo.wire}" diverge do tournamentId.');
      }
    }

    return TorneioCatalogo._(raiz['schemaVersion'] as int, porId);
  }

  Iterable<TorneioTemplate> get todos => _porId.values;

  /// Os cinco torneios recorrentes, sem o encerramento anual.
  Iterable<TorneioTemplate> get previstos => TorneioIds.previstos
      .map((id) => _porId[id])
      .whereType<TorneioTemplate>();

  TorneioTemplate operator [](String tournamentId) =>
      _porId[tournamentId] ??
      (throw ArgumentError('tournamentId desconhecido: $tournamentId'));

  TorneioTemplate? buscar(String tournamentId) => _porId[tournamentId];

  /// Templates prontos para rodar edicao de verdade.
  Iterable<TorneioTemplate> get configurados =>
      _porId.values.where((t) => t.configuracaoCompleta);

  /// Templates que ainda carregam pendencia. OS 02 secao 27 pede pendencias
  /// documentadas; esta consulta e o que permite lista-las sem ler o seed a mao.
  Iterable<TorneioTemplate> get comPendencias =>
      _porId.values.where((t) => t.pendencias.isNotEmpty);

  /// Todas as pendencias do catalogo, achatadas e prefixadas pelo torneio.
  List<String> get pendenciasConsolidadas => [
        for (final t in _porId.values)
          for (final p in t.pendencias) '${t.tournamentId}: $p',
      ];

  /// Checagem cruzada com o registro de assets.
  ///
  /// Toda capa referenciada precisa existir, ser da categoria `capa` e ter arte
  /// pronta; toda faixa de premiacao precisa apontar para um ativo recompensavel.
  /// Sem isso, um `assetId` errado so apareceria como quadro vazio na tela do
  /// jogador, ou como recusa de premiacao na noite da final.
  void validarCobertura(TorneioAssetsRegistry assets) {
    for (final template in _porId.values) {
      final capa = template.capaAssetId;
      if (capa != null) {
        final asset = assets.buscar(capa);
        if (asset == null) {
          throw FormatException('${template.tournamentId}: capaAssetId inexistente "$capa".');
        }
        if (asset.categoria != TorneioAssetCategoria.capa) {
          throw FormatException(
              '${template.tournamentId}: capaAssetId "$capa" nao e uma capa (e ${asset.categoria.name}).');
        }
      }
      for (final faixa in template.premiacao) {
        final assetId = faixa.assetId;
        if (assetId == null) continue;
        final asset = assets.buscar(assetId);
        if (asset == null) {
          throw FormatException(
              '${template.tournamentId}: premiacao aponta para assetId inexistente "$assetId".');
        }
        if (!asset.ehRecompensa) {
          throw FormatException(
              '${template.tournamentId}: premiacao aponta para "$assetId", que e capa e nao recompensa.');
        }
      }
    }
  }
}
