// colecao_inventario.dart — inventario do jogador e regra de equipagem.
//
// Camada pura: sem Firestore, sem UI e sem relogio. Todo insumo entra por
// parametro e nada e gravado — cabe a camada de persistencia aplicar o
// resultado devolvido.
//
// ESCOPO: colecao_catalogo.dart diz QUAIS itens existem, colecao_campanha.dart
// diz QUEM tem direito, colecao_resgate.dart descreve o ATO de conceder, e este
// arquivo descreve o que o jogador JA POSSUI e o que esta ATIVO no perfil.
//
// DOCUMENTO DETERMINISTICO: cada item vira `users/{uid}/inventory/{itemId}`. O
// id do documento e o proprio itemId, nao um id gerado. Duas gravacoes da mesma
// concessao colidem no mesmo documento em vez de criarem duas linhas, e a
// idempotencia sobrevive a reinstalacao e a troca de aparelho sem depender de
// consulta previa.
//
// DATAS: todo instante e normalizado para UTC na fronteira, pela mesma razao
// adotada em lib/torneios/reward_grants.dart — comparar em fuso local tornaria a
// auditoria dependente do relogio do aparelho.

import 'colecao_catalogo.dart';

/// Origem de um item no inventario. Existe para que o inventario saiba
/// distinguir o que foi conquistado do que foi comprado ou concedido a mao, sem
/// precisar consultar a campanha depois.
enum OrigemItem {
  /// Concedido por campanha comemorativa.
  campanha('campanha'),

  /// Concedido individualmente pela administracao.
  administrativa('administrativa');

  final String wire;
  const OrigemItem(this.wire);
}

/// Motivo pelo qual uma equipagem foi recusada. Estado explicito e
/// serializavel: recusa silenciosa vira chamado de suporte sem rastro.
enum RecusaEquipagem {
  /// O itemId nao existe no catalogo.
  itemInexistente('item_inexistente'),

  /// O jogador nao possui o item.
  itemNaoPossuido('item_nao_possuido'),

  /// O item nao e equipavel (o Bau, por exemplo, e arte de apresentacao).
  itemNaoEquipavel('item_nao_equipavel'),

  /// O item foi desligado no catalogo (`enabled: false`).
  itemDesabilitado('item_desabilitado'),

  /// O slot nao esta declarado no catalogo.
  slotDesconhecido('slot_desconhecido'),

  /// O slot admite mais de um item ativo e ja esta cheio: quem escolhe o que
  /// sai e o jogador, nao o sistema.
  slotCheio('slot_cheio'),

  /// O item ja esta equipado. Recusa explicita em vez de no-op silencioso.
  jaEquipado('ja_equipado'),

  /// Pedido de desequipar um item que nao estava equipado.
  naoEstavaEquipado('nao_estava_equipado');

  final String wire;
  const RecusaEquipagem(this.wire);
}

/// Um item possuido pelo jogador. Espelho do documento
/// `users/{uid}/inventory/{itemId}`.
class ItemInventario {
  final String userId;

  /// Chave estrangeira para o catalogo; tambem o id do documento.
  final String itemId;

  final String collectionId;

  final OrigemItem origem;

  /// Campanha que originou a concessao; null em origem administrativa avulsa.
  final String? campaignId;

  /// Versao da campanha no momento da concessao. Congelada de proposito: se a
  /// campanha for reeditada, o passado do jogador nao e reinterpretado.
  final int? campaignVersion;

  /// Instante do desbloqueio, sempre em UTC. Gravado com server timestamp — ver
  /// firebase/functions/index.js.
  final DateTime unlockedAt;

  final bool equipped;

  ItemInventario._({
    required this.userId,
    required this.itemId,
    required this.collectionId,
    required this.origem,
    required this.campaignId,
    required this.campaignVersion,
    required this.unlockedAt,
    required this.equipped,
  });

  factory ItemInventario({
    required String userId,
    required String itemId,
    required String collectionId,
    required OrigemItem origem,
    required DateTime unlockedAt,
    String? campaignId,
    int? campaignVersion,
    bool equipped = false,
  }) {
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'nao pode ser vazio');
    }
    if (itemId.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'nao pode ser vazio');
    }
    if (collectionId.isEmpty) {
      throw ArgumentError.value(collectionId, 'collectionId', 'nao pode ser vazio');
    }

    // Origem campanha exige rastro completo da campanha. Sem isso nao daria
    // para auditar qual edicao concedeu o item, nem para reconciliar depois.
    if (origem == OrigemItem.campanha) {
      if (campaignId == null || campaignId.isEmpty) {
        throw ArgumentError.value(campaignId, 'campaignId', 'obrigatorio em origem campanha');
      }
      if (campaignVersion == null || campaignVersion < 1) {
        throw ArgumentError.value(
            campaignVersion, 'campaignVersion', 'obrigatorio e >= 1 em origem campanha');
      }
    }

    return ItemInventario._(
      userId: userId,
      itemId: itemId,
      collectionId: collectionId,
      origem: origem,
      campaignId: campaignId,
      campaignVersion: campaignVersion,
      unlockedAt: unlockedAt.toUtc(),
      equipped: equipped,
    );
  }

  /// Reconstroi um documento ja persistido. Rejeita registro corrompido com
  /// [FormatException] em vez de assumir default: um campo faltando vira
  /// silenciosamente um item errado no perfil e ninguem descobre a origem
  /// depois.
  factory ItemInventario.fromMap(Map<String, dynamic> json) {
    final userId = _texto(json, 'userId');
    final itemId = _texto(json, 'itemId');
    final collectionId = _texto(json, 'collectionId');
    final origemWire = _texto(json, 'source');
    OrigemItem? origem;
    for (final o in OrigemItem.values) {
      if (o.wire == origemWire) origem = o;
    }
    if (origem == null) {
      _erro('source', origemWire, 'nao corresponde a nenhuma origem conhecida');
    }

    final campaignId = json['campaignId'] as String?;
    final campaignVersion = json['campaignVersion'];
    if (campaignVersion != null && campaignVersion is! int) {
      _erro('campaignVersion', campaignVersion, 'deve ser inteiro ou nulo');
    }

    final unlockedAt = _instanteUtc(json, 'unlockedAt');

    final equipped = json['equipped'];
    if (equipped is! bool) _erro('equipped', equipped, 'deve ser booleano');

    try {
      return ItemInventario(
        userId: userId,
        itemId: itemId,
        collectionId: collectionId,
        origem: origem,
        campaignId: campaignId,
        campaignVersion: campaignVersion as int?,
        unlockedAt: unlockedAt,
        equipped: equipped,
      );
    } on ArgumentError catch (e) {
      throw FormatException('inventario: documento invalido ($e).');
    }
  }

  ItemInventario copiarCom({bool? equipped}) => ItemInventario._(
        userId: userId,
        itemId: itemId,
        collectionId: collectionId,
        origem: origem,
        campaignId: campaignId,
        campaignVersion: campaignVersion,
        unlockedAt: unlockedAt,
        equipped: equipped ?? this.equipped,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'itemId': itemId,
        'collectionId': collectionId,
        'source': origem.wire,
        'campaignId': campaignId,
        'campaignVersion': campaignVersion,
        'unlockedAt': unlockedAt.toIso8601String(),
        'equipped': equipped,
      };

  @override
  String toString() => 'ItemInventario($userId/$itemId${equipped ? " equipado" : ""})';

  static Never _erro(String campo, Object? valor, String problema) =>
      throw FormatException('inventario: $campo $problema (recebido: $valor).');

  static String _texto(Map<String, dynamic> json, String campo) {
    final Object? valor = json[campo];
    if (valor is! String || valor.isEmpty) {
      _erro(campo, valor, 'deve ser string nao vazia');
    }
    return valor;
  }

  static DateTime _instanteUtc(Map<String, dynamic> json, String campo) {
    final Object? valor = json[campo];
    if (valor is! String || valor.isEmpty) {
      _erro(campo, valor, 'deve ser string ISO-8601 em UTC');
    }
    final instante = DateTime.tryParse(valor);
    if (instante == null) _erro(campo, valor, 'nao e ISO-8601 valido');
    if (!instante.isUtc) _erro(campo, valor, 'deve estar em UTC (sufixo Z)');
    return instante;
  }
}

/// Resultado de [InventarioUsuario.equipar] / [InventarioUsuario.desequipar].
class ResultadoEquipagem {
  /// Inventario resultante; null quando houve recusa.
  final InventarioUsuario? inventario;

  /// Itens que sairam do slot para dar lugar ao novo. Vazio quando nada saiu.
  /// A camada de persistencia precisa gravar estes tambem, senao o perfil fica
  /// com dois itens ativos no mesmo slot.
  final List<String> desequipados;

  /// null quando a operacao foi aceita.
  final RecusaEquipagem? recusa;

  const ResultadoEquipagem._(this.inventario, this.desequipados, this.recusa);

  const ResultadoEquipagem.aceita(
    InventarioUsuario inventario, {
    List<String> desequipados = const <String>[],
  }) : this._(inventario, desequipados, null);

  const ResultadoEquipagem.recusada(RecusaEquipagem recusa)
      : this._(null, const <String>[], recusa);

  bool get aceita => recusa == null;

  @override
  String toString() => aceita
      ? 'ResultadoEquipagem.aceita(desequipados: $desequipados)'
      : 'ResultadoEquipagem.recusada(${recusa!.wire})';
}

/// O que o jogador possui, e o que esta ativo. Estrutura imutavel: cada operacao
/// devolve um inventario novo, nunca muta o anterior.
class InventarioUsuario {
  final String userId;
  final Map<String, ItemInventario> _porItemId;

  const InventarioUsuario._(this.userId, this._porItemId);

  factory InventarioUsuario(String userId, Iterable<ItemInventario> itens) {
    final porId = <String, ItemInventario>{};
    for (final item in itens) {
      if (item.userId != userId) {
        throw ArgumentError('item ${item.itemId} pertence a ${item.userId}, nao a $userId');
      }
      if (porId.containsKey(item.itemId)) {
        throw ArgumentError('itemId duplicado no inventario: ${item.itemId}');
      }
      porId[item.itemId] = item;
    }
    return InventarioUsuario._(userId, Map.unmodifiable(porId));
  }

  factory InventarioUsuario.vazio(String userId) =>
      InventarioUsuario._(userId, const <String, ItemInventario>{});

  Iterable<ItemInventario> get itens => _porItemId.values;

  int get total => _porItemId.length;

  bool possui(String itemId) => _porItemId.containsKey(itemId);

  ItemInventario? buscar(String itemId) => _porItemId[itemId];

  bool estaEquipado(String itemId) => _porItemId[itemId]?.equipped ?? false;

  /// Itens de uma colecao especifica.
  Iterable<ItemInventario> daColecao(String collectionId) =>
      _porItemId.values.where((i) => i.collectionId == collectionId);

  /// true quando o jogador possui TODOS os [itemIds]. Usado para decidir se a
  /// concessao ja esta completa antes de tentar reconciliar.
  bool possuiTodos(Iterable<String> itemIds) => itemIds.every(possui);

  /// Itens atualmente equipados no [slot], segundo o catalogo.
  List<ItemInventario> equipadosNoSlot(String slot, CatalogoColecoes catalogo) =>
      _porItemId.values
          .where((i) => i.equipped && catalogo.buscarItem(i.itemId)?.slot == slot)
          .toList(growable: false);

  /// Equipa um item, respeitando a exclusividade do slot.
  ///
  /// Quando o slot admite UM item ativo, o ocupante anterior sai automaticamente
  /// e aparece em [ResultadoEquipagem.desequipados] — e a troca que o jogador
  /// espera de um cosmetico. Quando o slot admite mais de um e ja esta cheio, a
  /// operacao e RECUSADA com [RecusaEquipagem.slotCheio] em vez de o sistema
  /// escolher sozinho quem sai: com varias vagas nao existe vitima obvia, e
  /// remover a errada e pior do que pedir ao jogador que escolha.
  ResultadoEquipagem equipar(String itemId, CatalogoColecoes catalogo) {
    final definicao = catalogo.buscarItem(itemId);
    if (definicao == null) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.itemInexistente);
    }
    if (!possui(itemId)) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.itemNaoPossuido);
    }
    if (!definicao.equipavel) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.itemNaoEquipavel);
    }
    if (!definicao.enabled) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.itemDesabilitado);
    }
    if (estaEquipado(itemId)) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.jaEquipado);
    }

    final slot = definicao.slot!;
    final regra = catalogo.buscarSlot(slot);
    if (regra == null) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.slotDesconhecido);
    }

    final ocupantes = equipadosNoSlot(slot, catalogo);
    final desequipados = <String>[];

    if (ocupantes.length >= regra.maxAtivos) {
      if (regra.maxAtivos != 1) {
        return const ResultadoEquipagem.recusada(RecusaEquipagem.slotCheio);
      }
      desequipados.add(ocupantes.single.itemId);
    }

    final novo = Map<String, ItemInventario>.from(_porItemId);
    for (final saindo in desequipados) {
      novo[saindo] = novo[saindo]!.copiarCom(equipped: false);
    }
    novo[itemId] = novo[itemId]!.copiarCom(equipped: true);

    return ResultadoEquipagem.aceita(
      InventarioUsuario._(userId, Map.unmodifiable(novo)),
      desequipados: List.unmodifiable(desequipados),
    );
  }

  ResultadoEquipagem desequipar(String itemId, CatalogoColecoes catalogo) {
    if (catalogo.buscarItem(itemId) == null) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.itemInexistente);
    }
    if (!possui(itemId)) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.itemNaoPossuido);
    }
    if (!estaEquipado(itemId)) {
      return const ResultadoEquipagem.recusada(RecusaEquipagem.naoEstavaEquipado);
    }

    final novo = Map<String, ItemInventario>.from(_porItemId);
    novo[itemId] = novo[itemId]!.copiarCom(equipped: false);
    return ResultadoEquipagem.aceita(
      InventarioUsuario._(userId, Map.unmodifiable(novo)),
      desequipados: List.unmodifiable(<String>[itemId]),
    );
  }

  /// Anexa itens concedidos, ignorando os que ja existem.
  ///
  /// Idempotente de proposito: reaplicar a mesma concessao — por retry, por
  /// reinstalacao ou por reconciliacao — nao duplica nada e nao desfaz a
  /// equipagem ja escolhida pelo jogador.
  InventarioUsuario comItens(Iterable<ItemInventario> novos) {
    final mapa = Map<String, ItemInventario>.from(_porItemId);
    for (final item in novos) {
      if (item.userId != userId) {
        throw ArgumentError('item ${item.itemId} pertence a ${item.userId}, nao a $userId');
      }
      mapa.putIfAbsent(item.itemId, () => item);
    }
    return InventarioUsuario._(userId, Map.unmodifiable(mapa));
  }
}
