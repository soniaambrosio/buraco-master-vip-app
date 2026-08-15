// loja_play.dart — a PORTA para a Google Play Billing Library.
//
// POR QUE EXISTE UMA PORTA, E NAO UMA CHAMADA DIRETA AO PLUGIN
//
// `InAppPurchase.instance` e um singleton que resolve para
// `InAppPurchasePlatform.instance`, e esse getter LANCA quando nao ha plataforma
// registrada — que e exatamente a situacao de `flutter test`. Chamar o plugin
// direto do servico tornaria intestavel justo a parte que decide o destino de
// uma compra paga.
//
// A porta e estreita de proposito: sete metodos, todos os que o fluxo usa e nada
// alem. Quem implementa em producao e [LojaPlayReal], que so toca no singleton
// DENTRO dos metodos — construir a classe nao dispara nada. Quem implementa no
// teste e um duble que devolve compras roteirizadas.
//
// E a mesma disciplina de `criarStore({db, carimbo})` no backend: a dependencia
// de infraestrutura entra por parametro, e a regra fica alcancavel por teste.
//
// OS TIPOS ATRAVESSAM A PORTA SEM TRADUCAO. `ProductDetails` e `PurchaseDetails`
// vem do plugin, e nao sao reembrulhados: sao classes de dados puras, sem canal
// de plataforma, construiveis em teste. Reembrulhar so criaria um segundo modelo
// para divergir do primeiro.
library;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// O que o cliente precisa da Play Store.
abstract class LojaPlay {
  /// A plataforma de pagamento esta pronta? `false` em aparelho sem Play
  /// Services, em emulador sem Play, e em qualquer plataforma nao suportada.
  Future<bool> disponivel();

  /// Onde a Play Store entrega compras — as novas E as pendentes de sessoes
  /// anteriores. E por aqui que uma compra interrompida volta.
  Stream<List<PurchaseDetails>> get fluxoDeCompras;

  /// Consulta a vitrine. Assinaturas e produtos unicos vao na mesma ida: a
  /// implementacao Android do plugin ja pergunta pelos dois tipos internamente.
  Future<ProductDetailsResponse> consultarProdutos(Set<String> ids);

  /// Abre o fluxo de compra de uma assinatura.
  ///
  /// [ofertaPlanoBase] e o `offerToken` do plano-base escolhido (mensal,
  /// trimestral, anual). Ele vem de
  /// `(produto as GooglePlayProductDetails).productDetails.subscriptionOfferDetails`.
  /// Sem ele a Play Store usa a oferta padrao do produto.
  Future<bool> comprarAssinatura(ProductDetails produto, {String? ofertaPlanoBase});

  /// Abre o fluxo de compra de um produto unico consumivel.
  Future<bool> comprarConsumivel(ProductDetails produto);

  /// Pede a Play Store para reentregar as compras ativas desta conta. Cada uma
  /// volta pelo [fluxoDeCompras] e e revalidada.
  Future<void> restaurar();

  /// Encerra a compra junto a Play Store, parando a reentrega.
  ///
  /// SO PODE SER CHAMADO DEPOIS DE UM VEREDITO. Ver `deveFinalizarCompra`.
  Future<void> finalizar(PurchaseDetails compra);
}

/// A implementacao real, sobre `package:in_app_purchase`.
class LojaPlayReal implements LojaPlay {
  const LojaPlayReal();

  @override
  Future<bool> disponivel() => InAppPurchase.instance.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get fluxoDeCompras =>
      InAppPurchase.instance.purchaseStream;

  @override
  Future<ProductDetailsResponse> consultarProdutos(Set<String> ids) =>
      InAppPurchase.instance.queryProductDetails(ids);

  @override
  Future<bool> comprarAssinatura(
    ProductDetails produto, {
    String? ofertaPlanoBase,
  }) {
    // Assinatura usa `buyNonConsumable`: ela nao se "gasta". Quem controla o
    // ciclo de vida (renovacao, cancelamento, carencia, pausa) e a Play Store, e
    // quem o reflete aqui e a RTDN, nao o cliente.
    return InAppPurchase.instance.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: produto,
        offerToken: ofertaPlanoBase,
      ),
    );
  }

  @override
  Future<bool> comprarConsumivel(ProductDetails produto) {
    // `autoConsume: false` e a decisao mais importante deste arquivo.
    //
    // Consumir e o que libera o token para ser comprado de novo. Se o cliente
    // consumisse, consumiria ANTES de o backend creditar — e o cliente pode ser
    // morto a qualquer instante. O jogador pagaria e nao receberia.
    //
    // Quem consome e o backend, em `fecharComAGoogle`, via
    // `purchases.products.consume`, e so DEPOIS de creditar. Aqui o app apenas
    // abre o fluxo e, mais tarde, encerra a compra localmente quando ha veredito.
    return InAppPurchase.instance.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: produto),
      autoConsume: false,
    );
  }

  @override
  Future<void> restaurar() => InAppPurchase.instance.restorePurchases();

  @override
  Future<void> finalizar(PurchaseDetails compra) =>
      InAppPurchase.instance.completePurchase(compra);
}
