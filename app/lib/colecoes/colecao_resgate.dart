// colecao_resgate.dart — dominio do ato de resgatar uma colecao.
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI e sem relogio. Aqui se
// decide SE o resgate pode acontecer e O QUE exatamente precisa ser gravado.
// Quem grava e a camada segura (ver firebase/functions/index.js), que aplica o
// plano devolvido em UMA transacao.
//
// ESCOPO: colecao_campanha.dart decide QUEM tem direito; este arquivo decide o
// que fazer com esse direito e devolve um PLANO. A separacao permite testar o
// resgate inteiro sem subir emulador.
//
// IDEMPOTENCIA — as tres camadas que impedem duplicidade:
//   1. o comprovante tem id DETERMINISTICO (`users/{uid}/campaign_claims/{campaignId}`),
//      entao uma segunda gravacao colide no mesmo documento em vez de criar outro;
//   2. cada item tem id DETERMINISTICO (`users/{uid}/inventory/{itemId}`), entao
//      reaplicar a concessao sobrescreve em vez de duplicar;
//   3. [prepararResgate] consulta o comprovante ANTES de planejar e devolve
//      `jaResgatado` sem itens novos.
// Repetir a chamada, sofrer timeout, reinstalar o app ou trocar de aparelho cai
// sempre em (1) ou (3). Nenhuma delas depende de estado guardado no cliente.

import 'colecao_campanha.dart';
import 'colecao_catalogo.dart';
import 'colecao_inventario.dart';

/// Chave determinista de idempotencia do resgate.
///
/// Contrato: `campaignId + version + userId`. A versao entra na chave porque uma
/// reedicao futura da campanha e concessao NOVA, nao repeticao da antiga — sem
/// esse segmento, reabrir a campanha em 2027 seria lido como duplicidade e
/// ninguem receberia nada.
///
/// Reproduzivel offline, sem consultar nada, para que cliente e servidor
/// deduplicem com o mesmo resultado.
abstract final class ChaveResgate {
  /// Separador que nao pode aparecer nos segmentos, sob pena de duas chaves
  /// distintas colidirem em uma so string.
  static const separador = '|';

  static String de({
    required String campaignId,
    required int version,
    required String userId,
  }) {
    _exigirSegmento(campaignId, 'campaignId');
    _exigirSegmento(userId, 'userId');
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'deve ser >= 1');
    }
    return '$campaignId$separador$version$separador$userId';
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

/// Motivo pelo qual o resgate foi recusado.
enum RecusaResgate {
  /// A feature flag esta desligada.
  featureFlagDesligada('feature_flag_desligada'),

  /// A campanha nao esta em `active`.
  campanhaInativa('campanha_inativa'),

  /// Fora da janela de vigencia ou do prazo de resgate.
  foraDaJanela('fora_da_janela'),

  /// Nenhuma evidencia de elegibilidade.
  naoElegivel('nao_elegivel'),

  /// A campanha aponta para uma colecao que o catalogo nao conhece.
  colecaoInexistente('colecao_inexistente'),

  /// A composicao da campanha diverge do catalogo.
  composicaoInvalida('composicao_invalida'),

  /// O comprovante encontrado pertence a outra versao da campanha: estado
  /// ambiguo, que exige decisao administrativa em vez de arbitragem automatica.
  comprovanteDeOutraVersao('comprovante_de_outra_versao');

  final String wire;
  const RecusaResgate(this.wire);
}

/// Comprovante de resgate. Espelho do documento
/// `users/{uid}/campaign_claims/{campaignId}`.
class ComprovanteResgate {
  final String userId;
  final String campaignId;

  /// Versao da campanha no momento do resgate.
  final int campaignVersion;

  /// Instante do resgate, sempre em UTC. Gravado com server timestamp.
  final DateTime claimedAt;

  /// Itens efetivamente concedidos por este comprovante.
  final List<String> itemIds;

  /// `campaignId + version + userId`. Sempre derivada, nunca recebida pronta.
  final String chaveIdempotencia;

  ComprovanteResgate._({
    required this.userId,
    required this.campaignId,
    required this.campaignVersion,
    required this.claimedAt,
    required this.itemIds,
    required this.chaveIdempotencia,
  });

  factory ComprovanteResgate({
    required String userId,
    required String campaignId,
    required int campaignVersion,
    required DateTime claimedAt,
    required List<String> itemIds,
  }) {
    if (itemIds.isEmpty) {
      throw ArgumentError.value(itemIds, 'itemIds', 'comprovante sem itens');
    }
    if (itemIds.toSet().length != itemIds.length) {
      throw ArgumentError.value(itemIds, 'itemIds', 'tem itemId repetido');
    }
    return ComprovanteResgate._(
      userId: userId,
      campaignId: campaignId,
      campaignVersion: campaignVersion,
      claimedAt: claimedAt.toUtc(),
      itemIds: List.unmodifiable(itemIds),
      chaveIdempotencia: ChaveResgate.de(
        campaignId: campaignId,
        version: campaignVersion,
        userId: userId,
      ),
    );
  }

  /// Reconstroi um comprovante ja persistido. Confere que a chave gravada bate
  /// com a que os proprios campos produzem: divergencia significa registro
  /// adulterado ou migracao mal feita, e aceitar quebraria a idempotencia
  /// justamente onde ela mais importa.
  factory ComprovanteResgate.fromMap(Map<String, dynamic> json) {
    final userId = _texto(json, 'userId');
    final campaignId = _texto(json, 'campaignId');

    final versao = json['campaignVersion'];
    if (versao is! int || versao < 1) {
      _erro('campaignVersion', versao, 'deve ser inteiro >= 1');
    }

    final claimedAt = _instanteUtc(json, 'claimedAt');

    final brutos = json['itemIds'];
    if (brutos is! List || brutos.isEmpty) {
      _erro('itemIds', brutos, 'deve ser lista nao vazia');
    }
    final itemIds = brutos.cast<String>().toList(growable: false);
    if (itemIds.toSet().length != itemIds.length) {
      _erro('itemIds', itemIds, 'tem itemId repetido');
    }

    final chave = _texto(json, 'chaveIdempotencia');
    final String esperada;
    try {
      esperada = ChaveResgate.de(
        campaignId: campaignId,
        version: versao,
        userId: userId,
      );
    } on ArgumentError catch (e) {
      throw FormatException('comprovante: segmento invalido para a chave de idempotencia ($e).');
    }
    if (chave != esperada) {
      _erro('chaveIdempotencia', chave, 'nao corresponde aos campos do registro ($esperada)');
    }

    return ComprovanteResgate._(
      userId: userId,
      campaignId: campaignId,
      campaignVersion: versao,
      claimedAt: claimedAt,
      itemIds: List.unmodifiable(itemIds),
      chaveIdempotencia: chave,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'campaignId': campaignId,
        'campaignVersion': campaignVersion,
        'claimedAt': claimedAt.toIso8601String(),
        'itemIds': itemIds,
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'ComprovanteResgate($chaveIdempotencia)';

  static Never _erro(String campo, Object? valor, String problema) =>
      throw FormatException('comprovante: $campo $problema (recebido: $valor).');

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

/// O que a camada segura precisa gravar, em UMA transacao.
///
/// "Tudo ou nada" e propriedade da gravacao, nao do plano: o plano apenas
/// descreve o conjunto completo. Se a transacao falhar, nada e aplicado e a
/// proxima chamada replaneja do zero.
class PlanoConcessao {
  final ComprovanteResgate comprovante;

  /// Itens que ainda precisam ser gravados. Numa primeira concessao sao todos;
  /// numa reconciliacao, apenas os que faltam.
  final List<ItemInventario> itensAGravar;

  const PlanoConcessao({
    required this.comprovante,
    required this.itensAGravar,
  });

  /// Quantos documentos de inventario a transacao vai escrever.
  int get quantidade => itensAGravar.length;

  @override
  String toString() =>
      'PlanoConcessao(${comprovante.chaveIdempotencia}, $quantidade itens)';
}

/// Situacao apurada por [prepararResgate].
enum SituacaoResgate {
  /// Primeiro resgate: comprovante e todos os itens serao gravados.
  concedido,

  /// Comprovante ja existia, porem faltavam itens no inventario. O plano traz
  /// somente os que faltam.
  reconciliado,

  /// Comprovante existe e o inventario esta completo: nada a gravar.
  jaResgatado,

  /// Resgate recusado.
  recusado,
}

/// Veredito de [prepararResgate].
class ResultadoResgate {
  final SituacaoResgate situacao;

  /// null em [SituacaoResgate.jaResgatado] e [SituacaoResgate.recusado].
  final PlanoConcessao? plano;

  /// Comprovante ja existente, quando havia um.
  final ComprovanteResgate? comprovanteExistente;

  /// null quando nao houve recusa.
  final RecusaResgate? recusa;

  const ResultadoResgate._({
    required this.situacao,
    this.plano,
    this.comprovanteExistente,
    this.recusa,
  });

  const ResultadoResgate.concedido(PlanoConcessao plano)
      : this._(situacao: SituacaoResgate.concedido, plano: plano);

  const ResultadoResgate.reconciliado(
    PlanoConcessao plano,
    ComprovanteResgate existente,
  ) : this._(
          situacao: SituacaoResgate.reconciliado,
          plano: plano,
          comprovanteExistente: existente,
        );

  const ResultadoResgate.jaResgatado(ComprovanteResgate existente)
      : this._(
          situacao: SituacaoResgate.jaResgatado,
          comprovanteExistente: existente,
        );

  const ResultadoResgate.recusado(RecusaResgate recusa)
      : this._(situacao: SituacaoResgate.recusado, recusa: recusa);

  /// Houve algo a gravar.
  bool get exigeGravacao => plano != null;

  @override
  String toString() => switch (situacao) {
        SituacaoResgate.recusado => 'ResultadoResgate.recusado(${recusa!.wire})',
        SituacaoResgate.jaResgatado => 'ResultadoResgate.jaResgatado',
        _ => 'ResultadoResgate.${situacao.name}($plano)',
      };
}

/// Apura o que fazer com um pedido de resgate e devolve o plano de gravacao.
///
/// Funcao pura: nao le relogio, nao consulta rede e nao grava. [agora] deve ser
/// o instante do SERVIDOR — o mesmo cuidado de [avaliarElegibilidade].
///
/// A ordem das checagens e estavel para que a recusa reportada seja sempre a
/// mesma diante do mesmo estado.
///
/// [comprovanteExistente] e [inventario] descrevem o estado ATUAL do jogador,
/// lidos pela mesma transacao que vai gravar. Le-los fora da transacao abriria
/// janela para duas chamadas simultaneas planejarem a mesma concessao; a
/// protecao final continua sendo o id deterministico do comprovante.
ResultadoResgate prepararResgate({
  required CampanhaColecao campanha,
  required CatalogoColecoes catalogo,
  required String userId,
  required EvidenciaElegibilidade evidencia,
  required bool featureFlagLigada,
  required DateTime agora,
  required InventarioUsuario inventario,
  ComprovanteResgate? comprovanteExistente,
}) {
  final colecao = catalogo.buscarColecao(campanha.collectionId);
  if (colecao == null) {
    return const ResultadoResgate.recusado(RecusaResgate.colecaoInexistente);
  }

  // A campanha nao pode prometer item que o catalogo nao tem, nem deixar de
  // fora item que a colecao declara. Divergencia aqui viraria concessao
  // incompleta silenciosa.
  final noCatalogo = colecao.itens.map((i) => i.itemId).toSet();
  if (campanha.rewardIds.toSet().length != campanha.rewardIds.length ||
      !noCatalogo.containsAll(campanha.rewardIds) ||
      campanha.rewardIds.length != noCatalogo.length) {
    return const ResultadoResgate.recusado(RecusaResgate.composicaoInvalida);
  }

  // Um comprovante de outra versao e estado ambiguo: pode ser reedicao legitima
  // ou migracao mal feita. Nao arbitrar — devolver recusa e deixar a decisao
  // para a administracao.
  if (comprovanteExistente != null &&
      comprovanteExistente.campaignVersion != campanha.version) {
    return const ResultadoResgate.recusado(RecusaResgate.comprovanteDeOutraVersao);
  }

  // Comprovante da MESMA versao: o direito ja foi exercido. A reconciliacao
  // acontece antes de qualquer checagem de elegibilidade, de proposito — quem ja
  // recebeu nao pode perder itens porque a campanha encerrou, a flag caiu ou a
  // allowlist foi limpa depois.
  if (comprovanteExistente != null) {
    final faltando = campanha.rewardIds.where((id) => !inventario.possui(id)).toList(growable: false);
    if (faltando.isEmpty) {
      return ResultadoResgate.jaResgatado(comprovanteExistente);
    }
    return ResultadoResgate.reconciliado(
      PlanoConcessao(
        comprovante: comprovanteExistente,
        itensAGravar: _materializar(
          itemIds: faltando,
          userId: userId,
          campanha: campanha,
          agora: comprovanteExistente.claimedAt,
        ),
      ),
      comprovanteExistente,
    );
  }

  final veredicto = avaliarElegibilidade(
    campanha: campanha,
    evidencia: evidencia,
    featureFlagLigada: featureFlagLigada,
    agora: agora,
  );
  if (!veredicto.elegivel) {
    return ResultadoResgate.recusado(_traduzir(veredicto.recusa!));
  }

  return ResultadoResgate.concedido(PlanoConcessao(
    comprovante: ComprovanteResgate(
      userId: userId,
      campaignId: campanha.campaignId,
      campaignVersion: campanha.version,
      claimedAt: agora,
      itemIds: campanha.rewardIds,
    ),
    itensAGravar: _materializar(
      itemIds: campanha.rewardIds,
      userId: userId,
      campanha: campanha,
      agora: agora,
    ),
  ));
}

/// Converte itemIds em documentos de inventario prontos para gravacao.
///
/// `unlockedAt` reusa o instante do comprovante tambem na reconciliacao: o item
/// que faltava foi conquistado no dia do resgate, nao no dia em que a falha foi
/// percebida.
List<ItemInventario> _materializar({
  required List<String> itemIds,
  required String userId,
  required CampanhaColecao campanha,
  required DateTime agora,
}) =>
    itemIds
        .map((itemId) => ItemInventario(
              userId: userId,
              itemId: itemId,
              collectionId: campanha.collectionId,
              origem: OrigemItem.campanha,
              campaignId: campanha.campaignId,
              campaignVersion: campanha.version,
              unlockedAt: agora,
            ))
        .toList(growable: false);

RecusaResgate _traduzir(RecusaElegibilidade recusa) => switch (recusa) {
      RecusaElegibilidade.featureFlagDesligada => RecusaResgate.featureFlagDesligada,
      RecusaElegibilidade.campanhaInativa => RecusaResgate.campanhaInativa,
      RecusaElegibilidade.foraDaJanelaAntes ||
      RecusaElegibilidade.foraDaJanelaDepois ||
      RecusaElegibilidade.prazoDeResgateEncerrado =>
        RecusaResgate.foraDaJanela,
      RecusaElegibilidade.semEvidencia => RecusaResgate.naoElegivel,
    };
