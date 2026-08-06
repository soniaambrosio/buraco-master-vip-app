import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'billing_catalogo.dart';
import 'billing_validacao.dart';
import 'billing_validacao_firebase.dart';

/// Ponte com a Google Play Billing Library (via `in_app_purchase`).
///
/// O que este servico FAZ: conversa com a Play Store, consulta o catalogo,
/// dispara a compra e encaminha o token resultante para a validacao no backend.
///
/// O que este servico NAO FAZ, nunca: conceder VIP ou fichas. Quem concede e o
/// backend, depois de confirmar o token com a Google Play Developer API. Ver
/// [ValidadorDeCompra]. O app so descobre o que ganhou lendo o Firestore
/// depois — e por isso que um aparelho adulterado nao consegue se dar VIP.
///
/// ESTADO ATUAL: [BillingCatalogo] esta vazio de proposito, porque a Play
/// Console ainda nao liberou a area de produtos. Com o catalogo vazio,
/// [iniciar] devolve [BillingEstado.semCatalogo] e nenhuma compra e oferecida.
/// A biblioteca continua compilada dentro do AAB — que e justamente o que a
/// Play Console precisa detectar para liberar o cadastro dos produtos.
enum BillingEstado {
  /// [iniciar] ainda nao foi chamado.
  naoIniciado,

  /// Plataforma sem Play Billing (web, desktop) ou Play Store indisponivel
  /// no aparelho (emulador sem Play Services, conta sem Play).
  indisponivel,

  /// Play Store respondeu, mas [BillingCatalogo] nao tem IDs. Situacao de hoje.
  semCatalogo,

  /// Play Store respondeu e ha produtos consultaveis.
  pronto,
}

enum TipoEventoBilling {
  /// Compra aguardando acao do jogador (ex.: boleto, aprovacao familiar).
  pendente,

  /// Backend confirmou e ja gravou a concessao.
  concedida,

  /// Backend olhou e disse que a compra nao vale.
  recusada,

  /// Nao deu para validar agora. A compra segue pendente e volta depois.
  adiada,

  /// Jogador desistiu.
  cancelada,

  /// Erro devolvido pela propria Play Store.
  erro,
}

class EventoBilling {
  const EventoBilling(this.tipo, this.produtoId, {this.mensagem, this.detalhes = const <String, dynamic>{}});

  final TipoEventoBilling tipo;
  final String produtoId;
  final String? mensagem;

  /// O que o backend concedeu, quando [tipo] e [TipoEventoBilling.concedida].
  final Map<String, dynamic> detalhes;

  @override
  String toString() => 'EventoBilling($tipo, $produtoId, $mensagem)';
}

class BillingService {
  BillingService({InAppPurchase? loja, ValidadorDeCompra? validador})
      : _lojaInjetada = loja,
        _validador = validador ?? ValidadorFirebase();

  static final BillingService instance = BillingService();

  final InAppPurchase? _lojaInjetada;
  final ValidadorDeCompra _validador;

  /// Acesso preguicoso de proposito: em plataforma sem suporte,
  /// `InAppPurchase.instance` lanca. So tocamos nele depois de [_plataformaSuportada].
  InAppPurchase get _loja => _lojaInjetada ?? InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _assinaturaDoFluxo;
  final StreamController<EventoBilling> _eventos = StreamController<EventoBilling>.broadcast();

  BillingEstado _estado = BillingEstado.naoIniciado;
  List<ProductDetails> _produtos = const <ProductDetails>[];

  BillingEstado get estado => _estado;

  /// Eventos de compra para a UI reagir (snackbar, atualizar saldo, etc.).
  Stream<EventoBilling> get eventos => _eventos.stream;

  /// A assinatura `master_vip`. Os planos-base (mensal, trimestral, anual)
  /// chegam como ofertas DENTRO deste `ProductDetails`, nao como itens separados.
  List<ProductDetails> get assinaturas =>
      _produtos.where((p) => BillingCatalogo.ehAssinatura(p.id)).toList(growable: false);

  /// Produtos unicos consumiveis (pacotes de fichas).
  List<ProductDetails> get consumiveis =>
      _produtos.where((p) => BillingCatalogo.ehConsumivel(p.id)).toList(growable: false);

  bool get _plataformaSuportada =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Liga o servico. Idempotente: chamar duas vezes nao duplica a escuta.
  Future<BillingEstado> iniciar() async {
    if (_assinaturaDoFluxo != null) return _estado;

    if (!_plataformaSuportada) {
      return _estado = BillingEstado.indisponivel;
    }

    final disponivel = await _loja.isAvailable();
    if (!disponivel) {
      return _estado = BillingEstado.indisponivel;
    }

    // A escuta comeca ANTES de qualquer compra: a Play Store reentrega aqui as
    // compras que ficaram penduradas de sessoes anteriores (ex.: o app fechou
    // no meio da validacao). Sem isso, o jogador pagaria e nao receberia.
    _assinaturaDoFluxo = _loja.purchaseStream.listen(
      _aoReceberCompras,
      onError: (Object e) => _emitir(EventoBilling(TipoEventoBilling.erro, '', mensagem: '$e')),
    );

    await recarregarCatalogo();
    return _estado;
  }

  /// Consulta a Play Store pelos IDs declarados em [BillingCatalogo].
  ///
  /// Assinaturas e produtos unicos vao na MESMA consulta: a implementacao
  /// Android do `in_app_purchase` ja pergunta pelos dois tipos internamente.
  Future<void> recarregarCatalogo() async {
    if (!BillingCatalogo.configurado) {
      _produtos = const <ProductDetails>[];
      _estado = BillingEstado.semCatalogo;
      return;
    }

    final resposta = await _loja.queryProductDetails(BillingCatalogo.todos);

    if (resposta.error != null) {
      debugPrint('[billing] falha ao consultar o catalogo: ${resposta.error}');
      _produtos = const <ProductDetails>[];
      _estado = BillingEstado.indisponivel;
      return;
    }

    if (resposta.notFoundIDs.isNotEmpty) {
      // Declarado no app mas ausente na Play Console: ID errado, produto
      // inativo, ou build ainda nao publicado numa faixa de teste.
      debugPrint('[billing] IDs nao encontrados na Play Console: ${resposta.notFoundIDs}');
    }

    _produtos = resposta.productDetails;
    _estado = _produtos.isEmpty ? BillingEstado.semCatalogo : BillingEstado.pronto;
  }

  /// Abre o fluxo de compra da assinatura.
  ///
  /// Para escolher entre mensal/trimestral/anual, passe em [ofertaPlanoBase] o
  /// `offerToken` do plano-base desejado — ele vem de
  /// `(produto as GooglePlayProductDetails).productDetails.subscriptionOfferDetails`.
  /// Sem ele, a Play Store usa a oferta padrao da assinatura.
  Future<bool> comprarAssinatura(ProductDetails produto, {String? ofertaPlanoBase}) {
    final parametro = defaultTargetPlatform == TargetPlatform.android
        ? GooglePlayPurchaseParam(productDetails: produto, offerToken: ofertaPlanoBase)
        : PurchaseParam(productDetails: produto);
    // Assinatura usa `buyNonConsumable`: ela nao se "gasta", quem controla o
    // ciclo de vida (renovacao, cancelamento, carencia) e a Play Store.
    return _loja.buyNonConsumable(purchaseParam: parametro);
  }

  /// Abre o fluxo de compra de um pacote de fichas.
  Future<bool> comprarConsumivel(ProductDetails produto) {
    // `autoConsume: false` de proposito, e o consumo NAO acontece neste app.
    //
    // Quem consome o token e o backend, via `purchases.products.consume` da
    // Google Play Developer API, e so DEPOIS de creditar as fichas. O motivo:
    // consumir e o que libera o token para ser comprado de novo, entao consumir
    // antes de creditar (ou consumir no cliente, que pode ser morto a qualquer
    // instante) e a receita para o jogador pagar e nao receber.
    //
    // Aqui o app so abre o fluxo e, mais tarde, finaliza a compra localmente
    // quando o backend confirma.
    return _loja.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: produto),
      autoConsume: false,
    );
  }

  /// Pede a Play Store para reentregar compras ativas (troca de aparelho,
  /// reinstalacao). Cada uma volta pelo `purchaseStream` e e revalidada.
  Future<void> restaurarCompras() async {
    if (_estado == BillingEstado.naoIniciado || _estado == BillingEstado.indisponivel) return;
    await _loja.restorePurchases();
  }

  Future<void> _aoReceberCompras(List<PurchaseDetails> compras) async {
    for (final compra in compras) {
      await _tratar(compra);
    }
  }

  Future<void> _tratar(PurchaseDetails compra) async {
    switch (compra.status) {
      case PurchaseStatus.pending:
        _emitir(EventoBilling(TipoEventoBilling.pendente, compra.productID));
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _validarEConceder(compra);
        return;

      case PurchaseStatus.canceled:
        await _finalizar(compra);
        _emitir(EventoBilling(TipoEventoBilling.cancelada, compra.productID));
        return;

      case PurchaseStatus.error:
        await _finalizar(compra);
        _emitir(EventoBilling(
          TipoEventoBilling.erro,
          compra.productID,
          mensagem: compra.error?.message,
        ));
        return;
    }
  }

  Future<void> _validarEConceder(PurchaseDetails compra) async {
    final resultado = await _validador.validar(
      CompraParaValidar(
        produtoId: compra.productID,
        // No Android este campo carrega o `purchaseToken` da Play Store.
        tokenCompra: compra.verificationData.serverVerificationData,
        assinatura: BillingCatalogo.ehAssinatura(compra.productID),
        orderId: compra.purchaseID,
      ),
    );

    final destino = decidirDestinoDaCompra(resultado);

    // A finalizacao segue a decisao, nunca o contrario: `adiar` e o unico caso
    // em que a compra NAO e finalizada, para que a Play Store a reentregue.
    if (deveFinalizarCompra(destino)) {
      await _finalizar(compra);
    }

    switch (destino) {
      case DestinoDaCompra.conceder:
        // Nada e creditado aqui. O backend ja creditou (uma unica vez, mesmo se
        // esta for a segunda entrega do mesmo token) e tambem ja consumiu o
        // token quando o produto e consumivel. Este evento so avisa a UI para
        // reler o saldo.
        _emitir(EventoBilling(
          TipoEventoBilling.concedida,
          compra.productID,
          detalhes: resultado.detalhes,
        ));
      case DestinoDaCompra.adiar:
        _emitir(EventoBilling(
          TipoEventoBilling.adiada,
          compra.productID,
          mensagem: resultado.motivo,
        ));
      case DestinoDaCompra.recusar:
        _emitir(EventoBilling(
          TipoEventoBilling.recusada,
          compra.productID,
          mensagem: resultado.motivo,
        ));
    }
  }

  Future<void> _finalizar(PurchaseDetails compra) async {
    if (!compra.pendingCompletePurchase) return;
    await _loja.completePurchase(compra);
  }

  void _emitir(EventoBilling e) {
    debugPrint('[billing] $e');
    if (!_eventos.isClosed) _eventos.add(e);
  }

  Future<void> encerrar() async {
    await _assinaturaDoFluxo?.cancel();
    _assinaturaDoFluxo = null;
    await _eventos.close();
  }
}
