// entitlement_repositorio.dart — a leitura de `playerEntitlements/{uid}`.
//
// ESTE E O UNICO CAMINHO PELO QUAL O APLICATIVO DESCOBRE QUE ALGUEM E VIP.
//
// A resposta de `validarCompraPlay` nao serve para isso, e a resposta da Play
// Store muito menos. A compra e um EVENTO; o direito e um ESTADO, e o estado
// muda por fora do aplicativo: a assinatura renova sozinha, expira, entra em
// carencia, e pausada, e cancelada, e estornada. Quem escreve todas essas
// transicoes e o backend — pela RTDN, pela varredura de vencimento e pela
// propria validacao. O app le.
//
// SO LE. A regra do Firestore para esta colecao e `allow write: if false`
// (`firebase/firestore.rules`), inclusive para o dono e para o admin. Uma
// tentativa de escrita daqui seria recusada pelo servidor — e nao existe
// nenhuma neste arquivo, de proposito.
//
// O DOCUMENTO INTERNO NAO E LIDO AQUI, e nao poderia ser: o `purchaseToken` e o
// hash vivem em `playerEntitlements/{uid}/interno/billing`, fechado para todo
// cliente. A separacao em dois documentos existe porque regra do Firestore
// libera o DOCUMENTO INTEIRO — nao ha como conceder `vipAtivo` e esconder o
// token no mesmo lugar.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../elegibilidade/entitlement.dart';

/// Le o direito VIP consolidado que o Billing escreve.
class EntitlementRepositorio {
  EntitlementRepositorio({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String colecao = 'playerEntitlements';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(colecao).doc(uid);

  /// O direito agora, uma vez.
  Future<EntitlementVip> ler(String uid) async {
    final snap = await _doc(uid).get();
    return _interpretar(uid, snap.data());
  }

  /// O direito, e cada mudanca dele.
  ///
  /// E um `snapshots()` e nao uma consulta repetida porque as transicoes chegam
  /// de fora e a qualquer momento: uma RTDN de expiracao pode cair enquanto o
  /// jogador esta na tela. Sem escuta, a tela mostraria VIP ate alguem sair e
  /// voltar.
  Stream<EntitlementVip> observar(String uid) =>
      _doc(uid).snapshots().map((snap) => _interpretar(uid, snap.data()));

  /// Documento ausente vira [EntitlementVip.ausente], que NAO concede nada.
  ///
  /// Ausencia e recusa, e nao "ainda nao sei": tratar documento ausente como
  /// talvez-VIP entregaria acesso pago a quem nunca comprou.
  EntitlementVip _interpretar(String uid, Map<String, dynamic>? dados) {
    if (dados == null) return EntitlementVip.ausente(uid);
    return EntitlementVip.fromMap(uid, _normalizarInstantes(dados));
  }

  /// Converte `Timestamp` do Firestore em ISO-8601.
  ///
  /// O backend grava os instantes como STRING ISO (ver `documentosDeEntitlement`
  /// em `functions-billing/entitlement.js`), e [EntitlementVip.fromMap] so
  /// entende string — qualquer outro tipo vira `null`, e `expiraEm` nulo nao
  /// concede acesso.
  ///
  /// Esta normalizacao existe porque esse acoplamento e silencioso na direcao
  /// errada: se um dia alguem gravar `Timestamp` em vez de string, o app pararia
  /// de reconhecer assinantes pagantes SEM nenhum erro aparecer. Converter aqui
  /// custa nada e transforma uma falha silenciosa em nao-falha.
  Map<String, Object?> _normalizarInstantes(Map<String, dynamic> dados) {
    final saida = <String, Object?>{};
    for (final entrada in dados.entries) {
      final v = entrada.value;
      saida[entrada.key] = v is Timestamp
          ? v.toDate().toUtc().toIso8601String()
          : v;
    }
    return saida;
  }
}
