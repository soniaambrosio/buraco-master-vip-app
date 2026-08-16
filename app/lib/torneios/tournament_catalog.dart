// tournament_catalog.dart — catalogo dos torneios previstos
// (OS 02 secoes 2 e 14).
//
// Camada pura: sem Firestore, sem UI.
//
// Fonte de dados: app/data/torneios/tournamentTemplates.seed.json, aprovado
// fora do repositorio. Este arquivo CARREGA e VALIDA aquele seed; nenhum numero
// de regra e definido aqui.
//
// Mesma disciplina de assets_registry.dart e reward_policies.dart: os
// identificadores canonicos ficam em constantes, o seed e validado contra elas
// na carga, e o registro e imutavel. Referenciar `TorneioIds.*` em vez de string
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
  static const campeonatoAnual = 'campeonato_anual';
  static const encerramentoCampeoesAno = 'encerramento_campeoes_ano';

  /// Os cinco torneios regulares, que geram edicoes por recorrencia.
  static const regulares = <String>[
    quartaVulnerabilidade,
    sextaMasterVip,
    copaBuracoMaster,
    domingoPintando7,
    campeonatoMensal,
  ];

  /// Tudo que a chave `templates` do seed precisa conter. O Campeonato Anual
  /// entra aqui porque esta CADASTRADO, ainda que inativo (decisao #6); o
  /// encerramento nao entra porque vive na propria chave do seed.
  static const todos = <String>[...regulares, campeonatoAnual];
}

/// Colecao imutavel de templates, indexada por `templateId`.
class TorneioCatalogo {
  final Map<String, TorneioTemplate> _porId;

  /// O evento de encerramento anual, quando o seed o declara.
  final EventoEncerramento? encerramento;

  /// Regras que o proprio seed carrega em `_meta`, preservadas para auditoria.
  final List<String> regrasDoSeed;

  const TorneioCatalogo._(this._porId, this.encerramento, this.regrasDoSeed);

  factory TorneioCatalogo.fromSeedJson(String source) =>
      TorneioCatalogo.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory TorneioCatalogo.fromMap(Map<String, dynamic> raiz) {
    final itens = (raiz['templates'] as List)
        .map((e) => TorneioTemplate.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final porId = <String, TorneioTemplate>{};
    for (final item in itens) {
      if (porId.containsKey(item.tournamentId)) {
        throw FormatException('templateId duplicado no seed: ${item.tournamentId}.');
      }
      porId[item.tournamentId] = item;
    }

    final esperados = TorneioIds.todos.toSet();
    final faltando = esperados.difference(porId.keys.toSet());
    if (faltando.isNotEmpty) {
      throw FormatException('templateIds ausentes no seed: ${faltando.toList()..sort()}.');
    }
    final sobrando = porId.keys.toSet().difference(esperados);
    if (sobrando.isNotEmpty) {
      throw FormatException(
          'templateIds nao declarados em TorneioIds: ${sobrando.toList()..sort()}.');
    }

    final encerramentoBruto = raiz['eventoEncerramento'];
    final encerramento = encerramentoBruto is Map<String, dynamic>
        ? EventoEncerramento.fromJson(encerramentoBruto)
        : null;
    if (encerramento != null &&
        encerramento.tournamentId != TorneioIds.encerramentoCampeoesAno) {
      throw FormatException(
          'eventoEncerramento com templateId inesperado: ${encerramento.tournamentId}.');
    }

    final meta = raiz['_meta'];
    final regras = meta is Map
        ? ((meta['regras'] as List?) ?? const []).map((e) => e as String).toList(growable: false)
        : const <String>[];

    return TorneioCatalogo._(porId, encerramento, regras);
  }

  Iterable<TorneioTemplate> get todos => _porId.values;

  /// Os cinco torneios regulares, na ordem canonica.
  Iterable<TorneioTemplate> get regulares =>
      TorneioIds.regulares.map((id) => _porId[id]).whereType<TorneioTemplate>();

  TorneioTemplate operator [](String tournamentId) =>
      _porId[tournamentId] ??
      (throw ArgumentError('templateId desconhecido: $tournamentId'));

  TorneioTemplate? buscar(String tournamentId) => _porId[tournamentId];

  /// Templates que geram edicoes.
  Iterable<TorneioTemplate> get ativos => _porId.values.where((t) => t.ativo);

  /// Templates visiveis para o jogador.
  ///
  /// O seed aprovado traz TODOS com `publicado: false`: integrar configuracao
  /// nao e abrir torneio ao publico. Publicar e ato administrativo posterior.
  Iterable<TorneioTemplate> get publicados =>
      _porId.values.where((t) => t.publicado);

  /// Templates prontos para rodar edicao de verdade.
  Iterable<TorneioTemplate> get configurados =>
      _porId.values.where((t) => t.configuracaoCompleta);

  /// Templates que ainda carregam pendencia declarada.
  Iterable<TorneioTemplate> get comPendencias =>
      _porId.values.where((t) => t.pendencias.isNotEmpty);

  /// Todas as pendencias do catalogo, achatadas e prefixadas pelo torneio.
  List<String> get pendenciasConsolidadas => [
        for (final t in _porId.values)
          for (final p in t.pendencias) '${t.tournamentId}: $p',
      ];

  /// Checagem cruzada com o registro de assets.
  ///
  /// Toda capa referenciada precisa existir e ser da categoria `capa`; toda
  /// coroa e todo selo de premiacao precisam apontar para um ativo
  /// recompensavel. Sem isso, um `assetId` errado so apareceria como quadro
  /// vazio na tela do jogador, ou como recusa de premiacao na noite da final.
  ///
  /// A ARTE PODE ESTAR PENDENTE: `pendingAsset` nao e erro de configuracao. O
  /// identificador ja e estavel e o motor recusa a concessao com motivo
  /// explicito quando a arte faltar — recusar a carga do seed inteiro por causa
  /// disso impediria configurar o encerramento anual, cujas quatro artes ainda
  /// nao existem.
  void validarCobertura(TorneioAssetsRegistry assets) {
    void exigirRecompensa(String contexto, String assetId) {
      final asset = assets.buscar(assetId);
      if (asset == null) {
        throw FormatException('$contexto: premiacao aponta para assetId inexistente "$assetId".');
      }
      if (!asset.ehRecompensa) {
        throw FormatException(
            '$contexto: premiacao aponta para "$assetId", que e capa e nao recompensa.');
      }
    }

    void exigirCapa(String contexto, String? capa) {
      if (capa == null) return;
      final asset = assets.buscar(capa);
      if (asset == null) {
        throw FormatException('$contexto: coverAssetId inexistente "$capa".');
      }
      if (asset.categoria != TorneioAssetCategoria.capa) {
        throw FormatException(
            '$contexto: coverAssetId "$capa" nao e uma capa (e ${asset.categoria.name}).');
      }
    }

    for (final template in _porId.values) {
      exigirCapa(template.tournamentId, template.capaAssetId);
      for (final faixa in template.premiacao) {
        for (final assetId in faixa.assetIds) {
          exigirRecompensa(template.tournamentId, assetId);
        }
      }
      for (final selo in template.selosCondicionais) {
        exigirRecompensa(template.tournamentId, selo);
      }
    }

    final evento = encerramento;
    if (evento != null) {
      exigirCapa(evento.tournamentId, evento.capaAssetId);
      for (final premio in evento.premiacao.values) {
        for (final assetId in premio.assetIds) {
          exigirRecompensa(evento.tournamentId, assetId);
        }
      }
    }
  }
}
