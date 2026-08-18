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
  ///
  /// [vinculoDaConta] e o identificador opaco que o backend concedeu a conta
  /// autenticada. E OBRIGATORIO: sem ele a Google nao tem como dizer, mais
  /// tarde, de quem e a compra — e o backend recusa. Ver `vinculo.dart`.
  Future<bool> comprarAssinatura(
    ProductDetails produto, {
    String? ofertaPlanoBase,
    required String vinculoDaConta,
  });

  /// Abre o fluxo de compra de um produto unico consumivel.
  Future<bool> comprarConsumivel(
    ProductDetails produto, {
    required String vinculoDaConta,
  });

  /// Pede a Play Store para reentregar as compras ativas desta conta. Cada uma
  /// volta pelo [fluxoDeCompras] e e revalidada.
  Future<void> restaurar();

  /// Encerra a compra junto a Play Store, parando a reentrega.
  ///
  /// SO PODE SER CHAMADO DEPOIS DE UM VEREDITO. Ver `deveFinalizarCompra`.
  Future<void> finalizar(PurchaseDetails compra);
}

/// O TRANSPORTE ate o plugin, e nada alem disso.
///
/// POR QUE ESTA SEGUNDA PORTA EXISTE, JA HAVENDO [LojaPlay]
///
/// [LojaPlay] tornou o SERVICO testavel: um duble no lugar dela prova tudo que
/// `ServicoBilling` decide. O que ela nao alcanca e a ultima seta —
/// `LojaPlayReal -> plugin` —, porque aquela classe chamava
/// `InAppPurchase.instance` direto. A consequencia pratica foi medida: apagar
/// `applicationUserName` de dentro dela deixava os quinze testes de vinculo
/// VERDES, e so um teste que le o proprio codigo-fonte acusava.
///
/// Esta porta existe para tornar aquela seta observavel, e para mais nada. Ela
/// NAO conhece uid, sessao, entitlement, vinculo nem propriedade da compra: os
/// metodos tem os nomes do PLUGIN, de proposito, para que a leitura de
/// [LojaPlayReal] mostre o mapeamento 1:1 e nao dissimule uma segunda camada de
/// decisao onde so ha encanamento.
abstract class PluginDaPlay {
  Future<bool> isAvailable();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    required bool autoConsume,
  });
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

/// O plugin de verdade. `const`, e cada metodo resolve o singleton no momento da
/// CHAMADA — construir esta classe nao registra nem exige plataforma nenhuma.
class PluginDaPlayReal implements PluginDaPlay {
  const PluginDaPlayReal();

  @override
  Future<bool> isAvailable() => InAppPurchase.instance.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      InAppPurchase.instance.purchaseStream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      InAppPurchase.instance.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    required bool autoConsume,
  }) =>
      InAppPurchase.instance
          .buyConsumable(purchaseParam: purchaseParam, autoConsume: autoConsume);

  @override
  Future<void> restorePurchases() => InAppPurchase.instance.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      InAppPurchase.instance.completePurchase(purchase);
}

/// A implementacao real, sobre `package:in_app_purchase`.
///
/// O parametro [plugin] tem valor padrao `const PluginDaPlayReal()`: producao
/// continua indo ao `InAppPurchase.instance` de sempre, `const LojaPlayReal()`
/// continua valendo, e `ServicoBilling(loja: null)` continua montando esta
/// classe sem configuracao nenhuma. O parametro existe para o teste, e o teste e
/// o unico que o informa.
class LojaPlayReal implements LojaPlay {
  const LojaPlayReal({PluginDaPlay plugin = const PluginDaPlayReal()})
      : _plugin = plugin;

  final PluginDaPlay _plugin;

  @override
  Future<bool> disponivel() => _plugin.isAvailable();

  @override
  Stream<List<PurchaseDetails>> get fluxoDeCompras => _plugin.purchaseStream;

  @override
  Future<ProductDetailsResponse> consultarProdutos(Set<String> ids) =>
      _plugin.queryProductDetails(ids);

  @override
  Future<bool> comprarAssinatura(
    ProductDetails produto, {
    String? ofertaPlanoBase,
    required String vinculoDaConta,
  }) {
    // Assinatura usa `buyNonConsumable`: ela nao se "gasta". Quem controla o
    // ciclo de vida (renovacao, cancelamento, carencia, pausa) e a Play Store, e
    // quem o reflete aqui e a RTDN, nao o cliente.
    //
    // `applicationUserName` E A AMARRA DA CONTA, e o nome do parametro engana.
    // Ele nao e um nome de usuario e nao pode conter nada legivel: na versao
    // pinada (`in_app_purchase_android` 0.5.0) ele desce por
    // `in_app_purchase_android_platform.dart:184` como `accountId:`, vira
    // `PlatformBillingFlowParams.accountId` e termina em
    // `MethodCallHandlerImpl.java:333` como
    // `BillingFlowParams.setObfuscatedAccountId`. O proprio plugin avisa, na
    // documentacao de `launchBillingFlow`, que passar dado em claro aqui faz a
    // Google BLOQUEAR a compra — por isso o valor e um identificador opaco
    // concedido pelo backend, e nunca uid, e-mail ou apelido.
    //
    // E o mesmo objeto que carrega `changeSubscriptionParam`, entao upgrade e
    // downgrade passam por este mesmo caminho — nao ha um segundo lugar onde a
    // amarra pudesse ser esquecida.
    return _plugin.buyNonConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: produto,
        offerToken: ofertaPlanoBase,
        applicationUserName: vinculoDaConta,
      ),
    );
  }

  @override
  Future<bool> comprarConsumivel(
    ProductDetails produto, {
    required String vinculoDaConta,
  }) {
    // `autoConsume: false` e a decisao mais importante deste arquivo.
    //
    // Consumir e o que libera o token para ser comprado de novo. Se o cliente
    // consumisse, consumiria ANTES de o backend creditar — e o cliente pode ser
    // morto a qualquer instante. O jogador pagaria e nao receberia.
    //
    // Quem consome e o backend, em `fecharComAGoogle`, via
    // `purchases.products.consume`, e so DEPOIS de creditar. Aqui o app apenas
    // abre o fluxo e, mais tarde, encerra a compra localmente quando ha veredito.
    // O consumivel tambem leva a amarra: `ProductPurchase` devolve o
    // identificador na RAIZ da resposta, e o backend o confere igual. Deixar o
    // avulso de fora abriria a mesma porta em metade do catalogo.
    return _plugin.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: produto,
        applicationUserName: vinculoDaConta,
      ),
      autoConsume: false,
    );
  }

  @override
  Future<void> restaurar() => _plugin.restorePurchases();

  @override
  Future<void> finalizar(PurchaseDetails compra) =>
      _plugin.completePurchase(compra);
}
