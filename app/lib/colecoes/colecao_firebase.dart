// colecao_firebase.dart — adaptador real de Firestore e Cloud Functions.
//
// E o UNICO arquivo do modulo que conhece Firebase. O dominio inteiro
// (catalogo, campanha, resgate, inventario, contrato de UI) continua puro e
// testavel sem emulador.
//
// TRANSPORTE DO RESGATE: `claimPioneerKit` e uma Cloud Function `https.onCall`
// (ver firebase/functions/index.js), consumida aqui por `cloud_functions`. Nao
// ha endpoint HTTP publico, e nao ha caminho pelo qual o cliente grave
// inventario direto — as regras recusam (firebase/firestore.rules).
//
// DATAS: o Firestore devolve `Timestamp`, e os DTOs do dominio exigem ISO-8601
// com sufixo Z. A conversao acontece em [_normalizar], na fronteira, para que a
// regra de "nada de data sem fuso" continue valendo dentro do dominio.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'colecao_campanha.dart';
import 'colecao_inventario.dart';
import 'colecao_repositorio.dart';

/// Regiao das funcoes. Precisa casar com a declarada em
/// firebase/functions/index.js — chamar a regiao errada devolve `not-found`, que
/// e facil de confundir com campanha ausente.
const kRegiaoFuncoes = 'southamerica-east1';

class ColecaoRepositorioFirebase implements ColecaoRepositorio {
  final FirebaseFirestore _db;
  FirebaseFunctions? _functionsInjetado;

  ColecaoRepositorioFirebase({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functionsInjetado = functions;

  /// Resolvido na primeira chamada, e nao no construtor.
  ///
  /// `FirebaseFunctions.instanceFor` exige `Firebase.initializeApp()` ja
  /// executado. Resolver no construtor obrigaria qualquer teste de LEITURA —
  /// que so precisa do Firestore — a subir o Firebase inteiro.
  FirebaseFunctions get _functions =>
      _functionsInjetado ??= FirebaseFunctions.instanceFor(region: kRegiaoFuncoes);

  // -------------------------------------------------------------------------
  // Leitura
  // -------------------------------------------------------------------------

  @override
  Future<CampanhaColecao> carregarCampanha(String campaignId) async {
    final snap = await _guardar(() => _db.doc('campaigns/$campaignId').get());
    final dados = snap.data();
    if (!snap.exists || dados == null) {
      throw ErroColecao(FalhaBackend.naoEncontrado, 'campanha ausente: $campaignId');
    }
    try {
      return CampanhaColecao.fromMap(_normalizar(dados));
    } on FormatException catch (e) {
      // Configuracao invalida no Firestore e problema de operacao, nao de rede:
      // repetir nao resolve, e a tela precisa saber disso.
      throw ErroColecao(FalhaBackend.precondicaoFalhou, 'campanha malformada: ${e.message}');
    }
  }

  @override
  Future<bool> featureFlagLigada(CampanhaColecao campanha) async {
    final snap = await _guardar(() => _db.doc('config/featureFlags').get());
    // Documento ausente = flag desligada. Falhar aqui deixaria a campanha
    // inacessivel por um detalhe de configuracao; desligada e o padrao seguro.
    return snap.data()?[campanha.featureFlag] == true;
  }

  @override
  Future<EvidenciaElegibilidade> carregarEvidencia({
    required String campaignId,
    required String uid,
  }) async {
    final snap = await _guardar(
      () => _db.doc('campaigns/$campaignId/eligible/$uid').get(),
    );
    final dados = snap.data();
    if (!snap.exists || dados == null) return EvidenciaElegibilidade.nenhuma;
    return EvidenciaElegibilidade.fromMap(dados);
  }

  @override
  Future<InventarioUsuario> carregarInventario({
    required String uid,
    String? collectionId,
  }) async {
    Query<Map<String, dynamic>> consulta = _db.collection('users/$uid/inventory');
    if (collectionId != null) {
      consulta = consulta.where('collectionId', isEqualTo: collectionId);
    }
    final snap = await _guardar(() => consulta.get());

    final itens = <ItemInventario>[];
    for (final doc in snap.docs) {
      try {
        itens.add(ItemInventario.fromMap(_normalizar(doc.data())));
      } on FormatException catch (e) {
        // Um documento corrompido nao pode esconder os outros nove. Descarta o
        // ruim, mantem o resto — a reconciliacao do resgate regrava o que
        // faltar na proxima chamada.
        _avisar('inventario: documento ${doc.id} ignorado (${e.message})');
      }
    }
    return InventarioUsuario(uid, itens);
  }

  // -------------------------------------------------------------------------
  // Escrita
  // -------------------------------------------------------------------------

  @override
  Future<RespostaResgate> resgatar(String campaignId) async {
    try {
      final chamada = _functions.httpsCallable('claimPioneerKit');
      // Sem payload de proposito: a funcao pega o UID do contexto autenticado e
      // le a elegibilidade das fontes confiaveis. Nada que o cliente mande
      // influencia a decisao.
      final resposta = await chamada.call<Map<String, dynamic>>();
      return RespostaResgate.doWire(Map<String, dynamic>.from(resposta.data));
    } on FirebaseFunctionsException catch (e) {
      throw ErroColecao(_traduzirCodigo(e.code), e.message ?? e.code);
    } on FirebaseException catch (e) {
      throw ErroColecao(_traduzirCodigo(e.code), e.message ?? e.code);
    }
  }

  @override
  Future<void> aplicarEquipagem({
    required String uid,
    required String itemIdEquipado,
    required List<String> itemIdsDesequipados,
  }) async {
    // Lote, e nao gravacoes soltas: se so a metade passasse, o jogador ficaria
    // com dois itens ativos no mesmo slot.
    final lote = _db.batch();
    for (final itemId in itemIdsDesequipados) {
      lote.update(_db.doc('users/$uid/inventory/$itemId'), {'equipped': false});
    }
    lote.update(_db.doc('users/$uid/inventory/$itemIdEquipado'), {'equipped': true});

    // `update` (e nao `set`) de proposito: as regras so permitem alterar o campo
    // `equipped` de um documento QUE JA EXISTE. Um `set` criaria o documento e
    // seria recusado — que e exatamente a protecao desejada contra o cliente
    // inventar itens no proprio inventario.
    await _guardar(() => lote.commit());
  }

  // -------------------------------------------------------------------------
  // Fronteira
  // -------------------------------------------------------------------------

  /// Converte `Timestamp` em ISO-8601 UTC e mantem o resto intacto.
  ///
  /// Os DTOs do dominio exigem sufixo Z, e o Firestore devolve `Timestamp`. Sem
  /// esta conversao todo documento gravado pelo servidor seria recusado na
  /// hidratacao.
  static Map<String, dynamic> _normalizar(Map<String, dynamic> bruto) {
    final saida = <String, dynamic>{};
    bruto.forEach((chave, valor) {
      if (valor is Timestamp) {
        saida[chave] = valor.toDate().toUtc().toIso8601String();
      } else if (valor is DateTime) {
        saida[chave] = valor.toUtc().toIso8601String();
      } else if (valor is Map<String, dynamic>) {
        saida[chave] = _normalizar(valor);
      } else {
        saida[chave] = valor;
      }
    });
    return saida;
  }

  static FalhaBackend _traduzirCodigo(String codigo) => switch (codigo) {
        'unauthenticated' => FalhaBackend.naoAutenticado,
        'permission-denied' => FalhaBackend.recusado,
        'not-found' => FalhaBackend.naoEncontrado,
        'failed-precondition' => FalhaBackend.precondicaoFalhou,
        'unavailable' || 'deadline-exceeded' || 'aborted' => FalhaBackend.indisponivel,
        _ => FalhaBackend.desconhecida,
      };

  /// Envolve chamadas de Firestore para que a tela receba sempre [ErroColecao],
  /// e nunca uma excecao de plugin.
  static Future<T> _guardar<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FirebaseException catch (e) {
      throw ErroColecao(_traduzirCodigo(e.code), e.message ?? e.code);
    }
  }

  /// Diagnostico apenas em debug: `debugPrint` some no build de release, e o
  /// `assert` garante que nem a construcao da string acontece em producao.
  static void _avisar(String mensagem) {
    assert(() {
      debugPrint('[colecoes] $mensagem');
      return true;
    }());
  }
}
