// loja_play_real_test.dart — a ULTIMA seta, agora observavel.
//
// O QUE ESTA SUITE PROVA, E POR QUE ELA PRECISOU EXISTIR
//
// `vinculo_compra_test.dart` prova que o SERVICO entrega o vinculo a porta
// `LojaPlay`. Isso e metade do caminho. A outra metade — o que `LojaPlayReal`
// monta e entrega ao plugin — nao tinha prova de comportamento nenhuma, porque
// aquela classe chamava `InAppPurchase.instance` direto.
//
// A lacuna nao foi teorizada: a prova negativa C6 da composicao mediu. Apagar
// `applicationUserName` de `loja_play.dart` deixava os quinze testes de vinculo
// VERDES, e so `VINC-4c` — que le o proprio codigo-fonte — acusava. Uma garantia
// que depende de alguem ler o arquivo e mais fraca do que uma que executa.
//
// Agora `LojaPlayReal` recebe a porta `PluginDaPlay` por parametro, com o
// singleton de sempre como padrao. Estes testes injetam um dublê, executam os
// SETE metodos e inspecionam o objeto realmente construido.
//
// O QUE ESTA SUITE **NAO** PROVA, e a distincao importa:
//
//   - que a Play Store real recebeu o campo;
//   - que a Google devolvera `externalAccountIdentifiers.obfuscatedExternalAccountId`
//     na forma esperada.
//
// A fronteira provada aqui e Dart -> plugin. O outro lado continua reservado a
// uma compra licenciada controlada, e a composicao ja registra que a resposta
// real da Google nunca foi observada. Nada aqui e alegacao de integracao.

import 'dart:async';

import 'package:buraco_master_vip/billing/loja_play.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Identificador opaco, no formato que `prepararCompraPlay` emite.
///
/// 48 hexadecimais, e nao algo como `uid123`: um defeito que trocasse o vinculo
/// pelo uid poderia passar despercebido contra um valor curto e parecido com
/// identificador de usuario. A comparacao e texto a texto.
const _vinculo = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718';

const _oferta = 'oferta-plano-mensal-token';

final _produtoAssinatura = ProductDetails(
  id: 'assinatura.de.teste',
  title: 'VIP',
  description: 'assinatura de teste',
  price: 'R\$ 19,90',
  rawPrice: 19.90,
  currencyCode: 'BRL',
);

final _produtoConsumivel = ProductDetails(
  id: 'fichas.de.teste',
  title: 'Fichas',
  description: 'pacote de teste',
  price: 'R\$ 9,90',
  rawPrice: 9.90,
  currencyCode: 'BRL',
);

PurchaseDetails _compraFalsa(String id) => PurchaseDetails(
      productID: id,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'token_sintetico_seam',
        serverVerificationData: 'token_sintetico_seam',
        source: 'google_play',
      ),
      transactionDate: null,
      status: PurchaseStatus.purchased,
    );

/// Uma chamada capturada na fronteira do plugin.
class _Chamada {
  _Chamada(this.operacao, {this.param, this.autoConsume, this.ids, this.compra});

  final String operacao;
  final PurchaseParam? param;
  final bool? autoConsume;
  final Set<String>? ids;
  final PurchaseDetails? compra;
}

/// O plugin, de mentira, registrando TUDO que atravessa a fronteira.
///
/// E o instrumento central desta suite: se algum metodo de `LojaPlayReal`
/// contornar a porta e falar com o singleton, este dublê nao registra nada — e a
/// assercao de contagem fica vermelha. O seam nao pode ser acrescentado e depois
/// ignorado em silencio.
class PluginFalso implements PluginDaPlay {
  PluginFalso({this.disponivelResponde = true});

  final bool disponivelResponde;
  final List<_Chamada> chamadas = <_Chamada>[];
  final StreamController<List<PurchaseDetails>> controle =
      StreamController<List<PurchaseDetails>>.broadcast();
  ProductDetailsResponse? respostaDaConsulta;

  List<String> get operacoes => chamadas.map((c) => c.operacao).toList();

  @override
  Future<bool> isAvailable() async {
    chamadas.add(_Chamada('isAvailable'));
    return disponivelResponde;
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    chamadas.add(_Chamada('purchaseStream'));
    return controle.stream;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    chamadas.add(_Chamada('queryProductDetails', ids: identifiers));
    return respostaDaConsulta ??
        ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: identifiers.toList(),
        );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    chamadas.add(_Chamada('buyNonConsumable', param: purchaseParam));
    return true;
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    required bool autoConsume,
  }) async {
    chamadas.add(_Chamada('buyConsumable', param: purchaseParam, autoConsume: autoConsume));
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    chamadas.add(_Chamada('restorePurchases'));
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    chamadas.add(_Chamada('completePurchase', compra: purchase));
  }
}

void main() {
  late PluginFalso plugin;
  late LojaPlayReal loja;

  setUp(() {
    plugin = PluginFalso();
    loja = LojaPlayReal(plugin: plugin);
  });

  tearDown(() => plugin.controle.close());

  // =========================================================================
  group('SEAM-1..4 — a assinatura, capturada na fronteira do plugin', () {
    test('1. o parametro entregue e um GooglePlayPurchaseParam', () async {
      // O tipo importa: `PurchaseParam` puro nao carrega `offerToken` nem
      // `changeSubscriptionParam`, e a assinatura precisa dos dois.
      await loja.comprarAssinatura(_produtoAssinatura, vinculoDaConta: _vinculo);

      expect(plugin.operacoes, <String>['buyNonConsumable']);
      expect(plugin.chamadas.single.param, isA<GooglePlayPurchaseParam>());
    });

    test('2. o produto entregue e exatamente o solicitado', () async {
      await loja.comprarAssinatura(_produtoAssinatura, vinculoDaConta: _vinculo);

      expect(
        identical(plugin.chamadas.single.param!.productDetails, _produtoAssinatura),
        isTrue,
        reason: 'o produto foi substituido ou reconstruido no caminho',
      );
    });

    test('3. applicationUserName e o vinculo, caractere a caractere', () async {
      // A prova central desta OS. Sem hash adicional, sem prefixo, sem trim: o
      // backend compara com o indice, e qualquer transformacao aqui faria a
      // compra ser recusada por `vinculo_desconhecido` depois de cobrada.
      await loja.comprarAssinatura(_produtoAssinatura, vinculoDaConta: _vinculo);

      final param = plugin.chamadas.single.param!;
      expect(param.applicationUserName, _vinculo);
      // E nada de identificavel viajou no lugar dele.
      expect(param.applicationUserName, isNot(contains('@')));
      expect(param.applicationUserName, isNot(contains('token_sintetico')));
      expect(RegExp(r'^[0-9a-f]{48}$').hasMatch(param.applicationUserName!), isTrue);
    });

    test('4. offerToken e preservado quando ha plano-base, e nao inventado quando nao ha',
        () async {
      await loja.comprarAssinatura(
        _produtoAssinatura,
        ofertaPlanoBase: _oferta,
        vinculoDaConta: _vinculo,
      );
      final comOferta = plugin.chamadas.single.param! as GooglePlayPurchaseParam;
      expect(comOferta.offerToken, _oferta);
      // E a amarra continua junto: escolher plano nao pode custar a propriedade.
      expect(comOferta.applicationUserName, _vinculo);

      plugin.chamadas.clear();
      await loja.comprarAssinatura(_produtoAssinatura, vinculoDaConta: _vinculo);
      final semOferta = plugin.chamadas.single.param! as GooglePlayPurchaseParam;
      expect(semOferta.offerToken, isNull,
          reason: 'sem plano-base escolhido, nao se inventa oferta');
      expect(semOferta.applicationUserName, _vinculo);
    });
  });

  // =========================================================================
  group('SEAM-5..7 — o consumivel', () {
    test('5. produto e vinculo chegam corretos', () async {
      await loja.comprarConsumivel(_produtoConsumivel, vinculoDaConta: _vinculo);

      expect(plugin.operacoes, <String>['buyConsumable']);
      final param = plugin.chamadas.single.param!;
      expect(identical(param.productDetails, _produtoConsumivel), isTrue);
      expect(param.applicationUserName, _vinculo);
    });

    test('6. autoConsume e FALSE, e isso e dinheiro', () async {
      // Consumir e o que libera o token para nova compra. Se o cliente
      // consumisse, consumiria ANTES de o backend creditar — e o cliente pode
      // ser morto a qualquer instante. O jogador pagaria e nao receberia.
      // Quem consome e o backend, em `fecharComAGoogle`, depois de creditar.
      await loja.comprarConsumivel(_produtoConsumivel, vinculoDaConta: _vinculo);

      expect(plugin.chamadas.single.autoConsume, isFalse);
    });

    test('7. o consumivel nao vira GooglePlayPurchaseParam por engano', () async {
      // Produto unico nao tem plano-base. Mandar `offerToken` num avulso e erro
      // de contrato do lado da Play.
      await loja.comprarConsumivel(_produtoConsumivel, vinculoDaConta: _vinculo);

      expect(plugin.chamadas.single.param, isNot(isA<GooglePlayPurchaseParam>()));
    });
  });

  // =========================================================================
  group('SEAM-8..12 — as outras cinco operacoes atravessam a mesma fronteira', () {
    test('8. disponivel devolve exatamente o que a porta respondeu', () async {
      expect(await loja.disponivel(), isTrue);

      final indisponivel = LojaPlayReal(plugin: PluginFalso(disponivelResponde: false));
      expect(await indisponivel.disponivel(), isFalse);
      expect(plugin.operacoes, <String>['isAvailable']);
    });

    test('9. fluxoDeCompras expoe o stream da porta, e nao outro', () async {
      final recebidas = <List<PurchaseDetails>>[];
      final assinatura = loja.fluxoDeCompras.listen(recebidas.add);
      addTearDown(assinatura.cancel);

      final entregue = <PurchaseDetails>[_compraFalsa('assinatura.de.teste')];
      plugin.controle.add(entregue);
      await Future<void>.delayed(Duration.zero);

      expect(plugin.operacoes, <String>['purchaseStream']);
      expect(recebidas, hasLength(1));
      expect(identical(recebidas.single, entregue), isTrue);
    });

    test('10. consultarProdutos encaminha o conjunto de ids sem alterar', () async {
      final ids = <String>{'assinatura.de.teste', 'fichas.de.teste'};

      await loja.consultarProdutos(ids);

      expect(plugin.operacoes, <String>['queryProductDetails']);
      expect(plugin.chamadas.single.ids, ids);
    });

    test('11. restaurar chama a porta UMA vez', () async {
      await loja.restaurar();

      expect(plugin.operacoes, <String>['restorePurchases'],
          reason: 'restore duplicado faria a Play reentregar tudo duas vezes');
    });

    test('12. finalizar entrega exatamente a compra recebida', () async {
      final compra = _compraFalsa('assinatura.de.teste');

      await loja.finalizar(compra);

      expect(plugin.operacoes, <String>['completePurchase']);
      expect(identical(plugin.chamadas.single.compra, compra), isTrue,
          reason: 'finalizar outra compra deixaria a original reentregando para sempre');
    });
  });

  // =========================================================================
  group('SEAM-13..15 — o seam nao pode ser contornado nem exigir plataforma', () {
    test('13. NENHUMA das sete operacoes toca o singleton', () async {
      // O teste de bypass. Em `flutter test` nao ha plataforma registrada, entao
      // `InAppPurchase.instance` LANCA. Se qualquer metodo contornasse a porta,
      // este teste morreria na excecao — e, se por acaso nao morresse, o dublê
      // registraria menos de sete operacoes.
      final assinatura = loja.fluxoDeCompras.listen((_) {});
      addTearDown(assinatura.cancel);

      await loja.disponivel();
      await loja.consultarProdutos(<String>{'x'});
      await loja.comprarAssinatura(_produtoAssinatura, vinculoDaConta: _vinculo);
      await loja.comprarConsumivel(_produtoConsumivel, vinculoDaConta: _vinculo);
      await loja.restaurar();
      await loja.finalizar(_compraFalsa('assinatura.de.teste'));

      expect(plugin.operacoes, <String>[
        'purchaseStream',
        'isAvailable',
        'queryProductDetails',
        'buyNonConsumable',
        'buyConsumable',
        'restorePurchases',
        'completePurchase',
      ], reason: 'alguma operacao contornou a porta e foi direto ao plugin');
    });

    test('14. construir LojaPlayReal nao toca a plataforma', () async {
      // A propriedade ja era intencao declarada no cabecalho do arquivo; aqui ela
      // vira teste. Construir a implementacao REAL — com o plugin real como
      // padrao — nao pode resolver `InAppPurchase.instance`, senao o servico
      // deixaria de ser construivel em `flutter test`.
      expect(() => const LojaPlayReal(), returnsNormally);
      expect(() => const PluginDaPlayReal(), returnsNormally);

      // E o padrao continua sendo o plugin real: a classe e construivel como
      // constante, o que so vale se nenhum trabalho acontecer no construtor.
      const uma = LojaPlayReal();
      const outra = LojaPlayReal();
      expect(identical(uma, outra), isTrue,
          reason: 'const LojaPlayReal() deixou de ser canonizavel');
    });

    test('15. o padrao de producao continua sendo o plugin real', () async {
      // A contraprova de 13 e 14: sem porta injetada, a chamada vai ao singleton
      // — e em `flutter test` isso FALHA. E exatamente isso que se quer, porque
      // significa que producao nao ficou apontando para um dublê.
      const real = LojaPlayReal();

      await expectLater(
        real.disponivel(),
        throwsA(anything),
        reason: 'sem plataforma registrada, o caminho de producao tem de falhar; '
            'se passasse, o padrao teria virado um duble',
      );
    });
  });
}
