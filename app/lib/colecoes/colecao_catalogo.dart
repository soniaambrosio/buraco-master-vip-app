// colecao_catalogo.dart — catalogo de colecoes comemoraveis.
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI (nenhum import de
// flutter/material aqui, de proposito).
//
// ESCOPO: este arquivo descreve QUAIS itens existem e ONDE eles podem ser
// equipados. Quem tem direito ao kit vive em colecao_campanha.dart; o ato de
// resgatar vive em colecao_resgate.dart; o que o jogador ja possui vive em
// colecao_inventario.dart. A separacao e a mesma ja adotada em lib/torneios/:
// trocar um PNG nao pode mexer em elegibilidade, e mudar uma regra de campanha
// nao pode exigir tocar no catalogo.
//
// Contrato: o `itemId` e o identificador canonico e imutavel. Regras, inventario
// e telemetria devem referenciar `ColecaoItemIds.*` — nunca o nome fisico do
// PNG. Trocar ou renomear a arte altera somente `assetPath`.
//
// Fonte de dados: app/data/colecoes/catalogo.seed.json.
// Fonte da verdade da ARTE: app/data/colecoes/pioneiros_2026.manifest.json
// (dimensoes, alpha e SHA-256 dos originais aprovados).

import 'dart:convert';

import 'colecao_arte.dart';

/// Identificadores canonicos de colecao.
abstract final class ColecaoIds {
  static const pioneiros2026 = 'pioneiros_2026';
}

/// Identificadores canonicos de item. Use estas constantes no lugar de strings
/// soltas.
///
/// Os ids vem do manifesto oficial e usam o radical `pioneer_2026_`, enquanto a
/// colecao se chama `pioneiros_2026`. A divergencia e do pacote aprovado e foi
/// preservada de proposito — nao ha, portanto, regra de prefixo entre itemId e
/// collectionId.
abstract final class ColecaoItemIds {
  static const pioneerCrown = 'pioneer_2026_crown';
  static const pioneerChest = 'pioneer_2026_chest';
  static const pioneerMascotBulldog = 'pioneer_2026_mascot_bulldog';
  static const pioneerMascotOwl = 'pioneer_2026_mascot_owl';
  static const pioneerEmblem = 'pioneer_2026_emblem';
  static const pioneerThrone = 'pioneer_2026_throne';
  static const pioneerMedallion = 'pioneer_2026_medallion';
  static const pioneerMascotDragon = 'pioneer_2026_mascot_dragon';
  static const pioneerVortex = 'pioneer_2026_vortex';
  static const pioneerStatue = 'pioneer_2026_statue';

  /// Todos os itens esperados do Kit Pioneiros 2026, na ordem do manifesto.
  ///
  /// Serve de contrato de integridade: o seed nao pode faltar nem sobrar item em
  /// relacao a esta lista. E tambem o conjunto que uma concessao completa
  /// precisa gravar — dez itens, nunca nove.
  static const pioneiros2026 = <String>[
    pioneerCrown,
    pioneerChest,
    pioneerMascotBulldog,
    pioneerMascotOwl,
    pioneerEmblem,
    pioneerThrone,
    pioneerMedallion,
    pioneerMascotDragon,
    pioneerVortex,
    pioneerStatue,
  ];
}

/// Slot de equipagem. Define exclusividade: o jogador pode POSSUIR varios itens
/// do mesmo slot, mas manter apenas [maxAtivos] equipado(s).
class SlotEquipagem {
  final String slot;

  /// Quantos itens deste slot podem ficar ativos ao mesmo tempo.
  final int maxAtivos;

  /// true quando o slot ja existia na vitrine do perfil antes desta colecao.
  /// false marca uma adaptacao introduzida aqui, que a etapa visual precisa
  /// passar a expor.
  final bool preExistente;

  final String nota;

  const SlotEquipagem({
    required this.slot,
    required this.maxAtivos,
    required this.preExistente,
    required this.nota,
  });

  factory SlotEquipagem.fromJson(Map<String, dynamic> json) {
    final slot = _textoObrigatorio(json, 'slot');
    final max = json['maxAtivos'];
    if (max is! int || max < 1) {
      throw FormatException('slot $slot: maxAtivos deve ser inteiro >= 1 (recebido: $max).');
    }
    final origem = _textoObrigatorio(json, 'origem');
    if (origem != 'existente' && origem != 'novo') {
      throw FormatException('slot $slot: origem deve ser "existente" ou "novo" (recebido: "$origem").');
    }
    return SlotEquipagem(
      slot: slot,
      maxAtivos: max,
      preExistente: origem == 'existente',
      nota: _textoObrigatorio(json, 'nota'),
    );
  }
}

/// Item de catalogo. DTO puro: sem estado, sem widget, sem regra de campanha.
class ColecaoItem {
  final String collectionId;

  /// Identificador canonico e imutavel.
  final String itemId;

  final String displayName;

  /// Papel funcional do item no produto (mascot, badge_emblem, ...).
  final String categoria;

  /// Slot de equipagem, ou null quando o item nao e equipavel.
  final String? slot;

  final bool equipavel;

  /// De onde vem a arte: bundle hoje, possivelmente remota amanha. Ver
  /// colecao_arte.dart — a origem pode mudar sem que o [itemId] mude.
  final FonteArte arte;

  /// Ordem de apresentacao dentro da colecao, crescente.
  final int sortOrder;

  /// false desliga o item sem remove-lo do catalogo e sem quebrar inventarios
  /// ja concedidos.
  final bool enabled;

  final String accessibilityLabel;

  const ColecaoItem({
    required this.collectionId,
    required this.itemId,
    required this.displayName,
    required this.categoria,
    required this.slot,
    required this.equipavel,
    required this.arte,
    required this.sortOrder,
    required this.enabled,
    required this.accessibilityLabel,
  });

  /// Caminho no bundle. Atalho de conveniencia para as superficies que so lidam
  /// com arte empacotada — que hoje sao todas.
  ///
  /// Devolve null quando a arte e remota: nesse caso a superficie precisa passar
  /// pelo [ResolvedorDeArte], porque o arquivo pode nem estar no aparelho ainda.
  String? get assetPath => arte.assetPath;

  factory ColecaoItem.fromJson(Map<String, dynamic> json, String collectionId) {
    final itemId = _textoObrigatorio(json, 'itemId');
    final slot = json['slot'] as String?;
    final equipavel = json['equipavel'];
    if (equipavel is! bool) {
      throw FormatException('$itemId: equipavel deve ser booleano.');
    }

    // Equipavel e slot andam juntos: um item equipavel sem slot nao teria regra
    // de exclusividade, e um slot em item nao equipavel seria regra morta.
    if (equipavel && (slot == null || slot.isEmpty)) {
      throw FormatException('$itemId: item equipavel exige slot.');
    }
    if (!equipavel && slot != null) {
      throw FormatException('$itemId: item nao equipavel nao pode declarar slot.');
    }

    final sortOrder = json['sortOrder'];
    if (sortOrder is! int || sortOrder < 1) {
      throw FormatException('$itemId: sortOrder deve ser inteiro >= 1 (recebido: $sortOrder).');
    }
    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw FormatException('$itemId: enabled deve ser booleano.');
    }

    return ColecaoItem(
      collectionId: collectionId,
      itemId: itemId,
      displayName: _textoObrigatorio(json, 'displayName'),
      categoria: _textoObrigatorio(json, 'categoria'),
      slot: slot,
      equipavel: equipavel,
      arte: FonteArte.fromJson(json, itemId),
      sortOrder: sortOrder,
      enabled: enabled,
      accessibilityLabel: _textoObrigatorio(json, 'accessibilityLabel'),
    );
  }

  Map<String, dynamic> toJson() => {
        'collectionId': collectionId,
        'itemId': itemId,
        'displayName': displayName,
        'categoria': categoria,
        'slot': slot,
        'equipavel': equipavel,
        'arte': arte.toJson(),
        'sortOrder': sortOrder,
        'enabled': enabled,
        'accessibilityLabel': accessibilityLabel,
      };
}

/// Uma colecao comemorativa e seus itens.
class ColecaoDefinicao {
  final String collectionId;
  final String displayName;

  /// Grau de raridade no vocabulario do produto (`pioneer`).
  final String rarity;

  /// true quando os itens nao expiram. Diferente das recompensas de torneio,
  /// que tem politica de expiracao propria em lib/torneios/.
  final bool permanente;

  /// Fora da economia da loja: nao se compra, nao se transfere, nao se troca.
  final bool purchasable;
  final bool transferable;
  final bool tradable;

  /// Revogacao nao faz parte do fluxo comum; qualquer correcao exige acao
  /// administrativa explicita e auditada.
  final bool revocable;

  /// Caminho, no repositorio, do manifesto tecnico da arte.
  final String manifesto;

  final List<ColecaoItem> itens;

  const ColecaoDefinicao({
    required this.collectionId,
    required this.displayName,
    required this.rarity,
    required this.permanente,
    required this.purchasable,
    required this.transferable,
    required this.tradable,
    required this.revocable,
    required this.manifesto,
    required this.itens,
  });

  /// Itens visiveis, na ordem de apresentacao.
  List<ColecaoItem> get ativos =>
      itens.where((i) => i.enabled).toList(growable: false)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// Itens equipaveis desta colecao.
  Iterable<ColecaoItem> get equipaveis => itens.where((i) => i.equipavel);

  /// Nenhum item de colecao comemorativa aparece na loja. Consultado pelo teste
  /// de aceite e pela camada de apresentacao.
  bool get visivelNaLoja => false;

  factory ColecaoDefinicao.fromJson(Map<String, dynamic> json) {
    final collectionId = _textoObrigatorio(json, 'collectionId');
    final itens = (json['itens'] as List)
        .map((e) => ColecaoItem.fromJson(e as Map<String, dynamic>, collectionId))
        .toList(growable: false);

    if (itens.isEmpty) {
      throw FormatException('$collectionId: colecao sem itens.');
    }

    final ordens = <int, String>{};
    for (final item in itens) {
      final anterior = ordens[item.sortOrder];
      if (anterior != null) {
        throw FormatException(
            '$collectionId: sortOrder ${item.sortOrder} repetido em $anterior e ${item.itemId}.');
      }
      ordens[item.sortOrder] = item.itemId;
    }

    return ColecaoDefinicao(
      collectionId: collectionId,
      displayName: _textoObrigatorio(json, 'displayName'),
      rarity: _textoObrigatorio(json, 'rarity'),
      permanente: _booleanoObrigatorio(json, 'permanente', collectionId),
      purchasable: _comercialmenteFechado(json, 'purchasable', collectionId),
      transferable: _comercialmenteFechado(json, 'transferable', collectionId),
      tradable: _comercialmenteFechado(json, 'tradable', collectionId),
      revocable: _comercialmenteFechado(json, 'revocable', collectionId),
      manifesto: _textoObrigatorio(json, 'manifesto'),
      itens: itens,
    );
  }

  /// Trava de produto, nao apenas de schema: se alguem marcar `purchasable:
  /// true` num kit comemorativo, o seed nem carrega. E mais barato falhar aqui
  /// do que descobrir o item a venda na loja depois.
  static bool _comercialmenteFechado(
      Map<String, dynamic> json, String campo, String collectionId) {
    final valor = _booleanoObrigatorio(json, campo, collectionId);
    if (valor) {
      throw FormatException(
          '$collectionId: $campo deve ser false — colecao comemorativa nao entra na economia da loja.');
    }
    return valor;
  }
}

/// Colecao imutavel de definicoes, indexada por [itemId] e por [collectionId].
class CatalogoColecoes {
  final int schemaVersion;
  final Map<String, SlotEquipagem> _slots;
  final Map<String, ColecaoDefinicao> _colecoes;
  final Map<String, ColecaoItem> _itens;

  const CatalogoColecoes._(
    this.schemaVersion,
    this._slots,
    this._colecoes,
    this._itens,
  );

  /// Constroi a partir do conteudo bruto do seed JSON.
  factory CatalogoColecoes.fromSeedJson(String source) =>
      CatalogoColecoes.fromMap(jsonDecode(source) as Map<String, dynamic>);

  factory CatalogoColecoes.fromMap(Map<String, dynamic> raiz) {
    final slots = <String, SlotEquipagem>{};
    for (final bruto in (raiz['slots'] as Map<String, dynamic>)['definicoes'] as List) {
      final slot = SlotEquipagem.fromJson(bruto as Map<String, dynamic>);
      if (slots.containsKey(slot.slot)) {
        throw FormatException('slot duplicado no seed: ${slot.slot}.');
      }
      slots[slot.slot] = slot;
    }

    final colecoes = <String, ColecaoDefinicao>{};
    final itens = <String, ColecaoItem>{};
    final assetPaths = <String, String>{};

    for (final bruto in raiz['colecoes'] as List) {
      final colecao = ColecaoDefinicao.fromJson(bruto as Map<String, dynamic>);
      if (colecoes.containsKey(colecao.collectionId)) {
        throw FormatException('collectionId duplicado no seed: ${colecao.collectionId}.');
      }
      colecoes[colecao.collectionId] = colecao;

      for (final item in colecao.itens) {
        // itemId e unico em TODO o catalogo, nao apenas dentro da colecao: o
        // documento de inventario e indexado so por itemId.
        if (itens.containsKey(item.itemId)) {
          throw FormatException('itemId duplicado no catalogo: ${item.itemId}.');
        }
        itens[item.itemId] = item;

        // Uma unica copia de cada arquivo, uma unica origem por arte. Duas
        // entradas apontando para o mesmo PNG dobrariam o peso no bundle sem
        // que ninguem percebesse. A chave vem da FONTE, e nao do caminho local,
        // para valer tambem quando a arte for remota.
        final dono = assetPaths[item.arte.chaveCache];
        if (dono != null) {
          throw FormatException(
              'arte repetida entre $dono e ${item.itemId}: ${item.arte.chaveCache}.');
        }
        assetPaths[item.arte.chaveCache] = item.itemId;

        final slot = item.slot;
        if (slot != null && !slots.containsKey(slot)) {
          throw FormatException('${item.itemId}: slot "$slot" nao declarado em slots.definicoes.');
        }
      }
    }

    return CatalogoColecoes._(
      raiz['schemaVersion'] as int,
      Map.unmodifiable(slots),
      Map.unmodifiable(colecoes),
      Map.unmodifiable(itens),
    );
  }

  Iterable<ColecaoDefinicao> get colecoes => _colecoes.values;
  Iterable<ColecaoItem> get itens => _itens.values;
  Iterable<SlotEquipagem> get slots => _slots.values;

  /// Lanca se o [itemId] nao existir — falha cedo em vez de renderizar vazio.
  ColecaoItem operator [](String itemId) =>
      _itens[itemId] ?? (throw ArgumentError('itemId desconhecido: $itemId'));

  ColecaoItem? buscarItem(String itemId) => _itens[itemId];

  ColecaoDefinicao? buscarColecao(String collectionId) => _colecoes[collectionId];

  ColecaoDefinicao colecao(String collectionId) =>
      _colecoes[collectionId] ??
      (throw ArgumentError('collectionId desconhecido: $collectionId'));

  SlotEquipagem? buscarSlot(String slot) => _slots[slot];

  /// Itens de uma colecao, na ordem de apresentacao.
  List<ColecaoItem> itensDe(String collectionId) => colecao(collectionId).ativos;

  /// Confere que a colecao declara exatamente os [esperados], nem mais nem
  /// menos. Usado para amarrar o seed a `ColecaoItemIds.pioneiros2026`: uma
  /// concessao "completa" precisa saber, sem ambiguidade, quantos itens sao.
  void validarComposicao(String collectionId, List<String> esperados) {
    final declarados = colecao(collectionId).itens.map((i) => i.itemId).toSet();
    final alvo = esperados.toSet();

    final faltando = alvo.difference(declarados);
    if (faltando.isNotEmpty) {
      throw FormatException('$collectionId: itens ausentes no seed: ${faltando.toList()..sort()}.');
    }
    final sobrando = declarados.difference(alvo);
    if (sobrando.isNotEmpty) {
      throw FormatException('$collectionId: itens nao declarados no contrato: ${sobrando.toList()..sort()}.');
    }
  }
}

String _textoObrigatorio(Map<String, dynamic> json, String campo) {
  final Object? valor = json[campo];
  if (valor is! String || valor.isEmpty) {
    throw FormatException('catalogo: $campo deve ser string nao vazia (recebido: $valor).');
  }
  return valor;
}

bool _booleanoObrigatorio(Map<String, dynamic> json, String campo, String contexto) {
  final Object? valor = json[campo];
  if (valor is! bool) {
    throw FormatException('$contexto: $campo deve ser booleano (recebido: $valor).');
  }
  return valor;
}
