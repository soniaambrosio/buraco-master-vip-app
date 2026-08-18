// dubles.dart — a mesa de teste do cliente Billing.
//
// Nenhum plugin e nenhum Firebase sobem aqui. `LojaPlay`, `ValidadorDeCompra` e
// `SessaoJogador` sao portas declaradas pelo proprio modulo justamente para que
// a parte que decide o destino de uma compra paga possa ser exercitada sem
// aparelho, sem rede e sem Play Store.
//
// Os tipos `ProductDetails` e `PurchaseDetails` vem do plugin e sao construidos
// diretamente: sao classes de dados, sem canal de plataforma.

import 'dart:async';

import 'package:buraco_master_vip/billing/loja_play.dart';
import 'package:buraco_master_vip/billing/validacao.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Uma Play Store roteirizada.
class LojaPlayFalsa implements LojaPlay {
  LojaPlayFalsa({
    this.estaDisponivel = true,
    this.disponivelLanca = false,
  });

  final _fluxo = StreamController<List<PurchaseDetails>>.broadcast();

  bool estaDisponivel;
  bool disponivelLanca;

  /// O que [consultarProdutos] devolve. `null` = resposta vazia sem erro.
  ProductDetailsResponse? respostaDoCatalogo;
  bool consultaLanca = false;

  /// Compras que [restaurar] reentrega pelo fluxo.
  List<PurchaseDetails> reentregasNoRestore = const <PurchaseDetails>[];
  bool restauraLanca = false;

  // --- o que o servico fez -------------------------------------------------
  final List<PurchaseDetails> finalizadas = <PurchaseDetails>[];
  final List<Set<String>> consultas = <Set<String>>[];
  int assinaturasAbertas = 0;
  int consumiveisAbertos = 0;
  int restauracoes = 0;

  /// Quantas vezes o fluxo foi assinado. E o contador de BILLING-FLUTTER-13:
  /// dois listeners fariam a Play entregar cada compra duas vezes.
  int escutasAbertas = 0;

  /// Entrega compras como se a Play Store as tivesse mandado.
  void entregar(List<PurchaseDetails> compras) => _fluxo.add(compras);

  /// Empurra um erro pelo fluxo.
  void falharNoFluxo(Object erro) => _fluxo.addError(erro);

  Future<void> descartar() => _fluxo.close();

  @override
  Future<bool> disponivel() async {
    if (disponivelLanca) throw StateError('sem implementacao de plataforma');
    return estaDisponivel;
  }

  @override
  Stream<List<PurchaseDetails>> get fluxoDeCompras {
    escutasAbertas += 1;
    return _fluxo.stream;
  }

  @override
  Future<ProductDetailsResponse> consultarProdutos(Set<String> ids) async {
    consultas.add(ids);
    if (consultaLanca) throw StateError('consulta falhou');
    return respostaDoCatalogo ??
        ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: ids.toList(),
        );
  }

  /// Todo vinculo que chegou a Play, na ordem. E o registro do que o aplicativo
  /// REALMENTE entregou — nao do que ele pretendia entregar.
  final List<String> vinculosRecebidos = <String>[];

  @override
  Future<bool> comprarAssinatura(
    ProductDetails produto, {
    String? ofertaPlanoBase,
    required String vinculoDaConta,
  }) async {
    assinaturasAbertas += 1;
    vinculosRecebidos.add(vinculoDaConta);
    return true;
  }

  @override
  Future<bool> comprarConsumivel(
    ProductDetails produto, {
    required String vinculoDaConta,
  }) async {
    consumiveisAbertos += 1;
    vinculosRecebidos.add(vinculoDaConta);
    return true;
  }

  @override
  Future<void> restaurar() async {
    restauracoes += 1;
    if (restauraLanca) throw StateError('restauracao falhou');
    for (final compra in reentregasNoRestore) {
      _fluxo.add(<PurchaseDetails>[compra]);
    }
    // A Play real entrega as reentregas antes de `restorePurchases()` completar.
    // Ceder ao laco de eventos aqui reproduz essa ordem.
    await _cederAoLaco();
  }

  @override
  Future<void> finalizar(PurchaseDetails compra) async {
    finalizadas.add(compra);
  }
}

/// Deixa o laco de eventos entregar o que esta na fila do fluxo.
Future<void> _cederAoLaco() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Cede o laco de eventos, para os testes.
Future<void> cederAoLaco() => _cederAoLaco();

/// Um backend roteirizado.
class ValidadorRoteirizado implements ValidadorDeCompra {
  ValidadorRoteirizado(this.resposta);

  /// Constroi a resposta a partir da compra recebida.
  ResultadoValidacao Function(CompraParaValidar) resposta;

  /// Toda compra que chegou. Serve para provar que NAO houve chamada duplicada.
  final List<CompraParaValidar> recebidas = <CompraParaValidar>[];

  /// Quando maior que zero, a resposta so sai depois de liberada por [liberar].
  Completer<void>? portao;

  int get chamadas => recebidas.length;

  @override
  Future<ResultadoValidacao> validar(CompraParaValidar compra) async {
    recebidas.add(compra);
    final p = portao;
    if (p != null) await p.future;
    return resposta(compra);
  }

  void liberar() {
    portao?.complete();
    portao = null;
  }
}

/// Um produto como a Play Store o devolveria.
ProductDetails produtoFalso(String id, {String preco = 'R\$ 0,00'}) =>
    ProductDetails(
      id: id,
      title: 'Produto $id',
      description: 'descricao de $id',
      price: preco,
      rawPrice: 0,
      currencyCode: 'BRL',
    );

/// Uma compra como a Play Store a entregaria.
///
/// [token] e o `purchaseToken`: no Android ele chega em
/// `verificationData.serverVerificationData`.
PurchaseDetails compraFalsa(
  String produtoId, {
  required String token,
  PurchaseStatus status = PurchaseStatus.purchased,
  String? pedido = 'GPA.0000-0000-0000-00000',
  bool pendente = true,
  IAPError? erro,
}) {
  final c = PurchaseDetails(
    purchaseID: pedido,
    productID: produtoId,
    verificationData: PurchaseVerificationData(
      localVerificationData: token,
      serverVerificationData: token,
      source: 'google_play',
    ),
    transactionDate: '1700000000000',
    status: status,
  );
  c.pendingCompletePurchase = pendente;
  c.error = erro;
  return c;
}
