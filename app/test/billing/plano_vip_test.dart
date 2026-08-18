// plano_vip_test.dart — os planos VIP como a Play os descreve, e a traducao
// deles para a vitrine.
//
// O QUE ESTA SOB TESTE
//
// 1. Que `basePlanId` — e nao `ProductDetails.id` — e o que distingue mensal de
//    anual. Os tres planos-base de um produto de assinatura chegam com o MESMO
//    `id`, e ler o `id` como se fosse o plano faria a vitrine mostrar tres
//    cartoes identicos e o app comprar sempre o mesmo plano.
//
// 2. Que nenhum preco nasce no aplicativo. Todo valor exibido vem de
//    `formattedPrice`, que a Play devolve localizado; o preco por mes e o selo
//    de economia sao aritmetica sobre esses valores.
//
// Os dublês sao construidos com os wrappers reais do plugin e passados por
// `GooglePlayProductDetails.fromProductDetails`, que e a MESMA funcao que a
// plataforma usa para montar a resposta. Nao ha reimplementacao do formato.

import 'package:buraco_master_vip/billing/plano_vip.dart';
import 'package:buraco_master_vip/screens/loja_vip_adaptador.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// Os wrappers da Billing Library (`ProductDetailsWrapper` e companhia) sao
// exportados por este arquivo, e nao pelo `in_app_purchase_android.dart`.
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Um plano-base, como a Play o descreve.
SubscriptionOfferDetailsWrapper _planoBase({
  required String basePlanId,
  required String periodo,
  required String precoFormatado,
  required int precoMicros,
}) =>
    SubscriptionOfferDetailsWrapper(
      basePlanId: basePlanId,
      offerTags: const <String>[],
      offerIdToken: 'token-de-$basePlanId',
      pricingPhases: <PricingPhaseWrapper>[
        PricingPhaseWrapper(
          billingCycleCount: 0,
          billingPeriod: periodo,
          formattedPrice: precoFormatado,
          priceAmountMicros: precoMicros,
          priceCurrencyCode: 'BRL',
          recurrenceMode: RecurrenceMode.infiniteRecurring,
        ),
      ],
    );

/// UM produto de assinatura com os tres planos-base — a modelagem que o Google
/// Play recomenda, e a que torna `id` insuficiente para distinguir plano.
List<ProductDetails> _assinaturaComTresPlanos({
  String produtoId = 'master_vip',
}) {
  final wrapper = ProductDetailsWrapper(
    description: 'Assinatura VIP',
    name: 'Buraco Master VIP',
    productId: produtoId,
    productType: ProductType.subs,
    title: 'Buraco Master VIP',
    subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
      // De proposito fora de ordem, para provar que a ordenacao e nossa.
      _planoBase(
        basePlanId: 'yearly_auto',
        periodo: 'P1Y',
        precoFormatado: r'R$ 149,90',
        precoMicros: 149900000,
      ),
      _planoBase(
        basePlanId: 'monthly_auto',
        periodo: 'P1M',
        precoFormatado: r'R$ 19,90',
        precoMicros: 19900000,
      ),
      _planoBase(
        basePlanId: 'quarterly_auto',
        periodo: 'P3M',
        precoFormatado: r'R$ 49,90',
        precoMicros: 49900000,
      ),
    ],
  );
  return GooglePlayProductDetails.fromProductDetails(wrapper);
}

void main() {
  group('planosVipDe — o que distingue um plano do outro', () {
    test('os tres planos-base chegam com o MESMO ProductDetails.id', () {
      final produtos = _assinaturaComTresPlanos();

      expect(produtos, hasLength(3));
      expect(produtos.map((p) => p.id).toSet(), <String>{'master_vip'},
          reason: 'e por isso que o id do produto nao serve para escolher plano');
    });

    test('o basePlanId separa mensal, trimestral e anual', () {
      final planos = planosVipDe(_assinaturaComTresPlanos());

      expect(planos.map((p) => p.basePlanId),
          ['monthly_auto', 'quarterly_auto', 'yearly_auto'],
          reason: 'ordenado do periodo mais curto para o mais longo');
      expect(planos.map((p) => p.produtoId).toSet(), <String>{'master_vip'});
    });

    test('cada plano carrega o offerToken do SEU plano-base', () {
      final planos = planosVipDe(_assinaturaComTresPlanos());

      // Sem isto a Play cobraria a oferta padrao do produto, e quem escolheu
      // "Anual" poderia acabar assinando o mensal.
      expect(
        planos.map((p) => p.ofertaToken),
        ['token-de-monthly_auto', 'token-de-quarterly_auto', 'token-de-yearly_auto'],
      );
    });

    test('o periodo vem da Play e vira meses', () {
      final planos = planosVipDe(_assinaturaComTresPlanos());

      expect(planos.map((p) => p.periodo), ['P1M', 'P3M', 'P1Y']);
      expect(planos.map((p) => p.mesesDoPeriodo), [1, 3, 12]);
    });

    test('periodo desconhecido nao vira preco por mes inventado', () {
      final wrapper = ProductDetailsWrapper(
        description: 'x',
        name: 'x',
        productId: 'master_vip',
        productType: ProductType.subs,
        title: 'x',
        subscriptionOfferDetails: <SubscriptionOfferDetailsWrapper>[
          _planoBase(
            basePlanId: 'weekly_auto',
            periodo: 'P1W',
            precoFormatado: r'R$ 6,90',
            precoMicros: 6900000,
          ),
        ],
      );
      final planos =
          planosVipDe(GooglePlayProductDetails.fromProductDetails(wrapper));

      expect(planos.single.mesesDoPeriodo, isNull);
      expect(planos.single.precoPorMes, isNull);
      expect(precoPorMesFormatado(planos.single), isNull);
    });

    test('catalogo vazio devolve lista vazia, sem erro', () {
      expect(planosVipDe(const <ProductDetails>[]), isEmpty);
    });

    test('produto unico consumivel nao vira plano VIP', () {
      final wrapper = ProductDetailsWrapper(
        description: 'pacote de fichas',
        name: 'fichas',
        productId: 'fichas_1000',
        productType: ProductType.inapp,
        title: 'fichas',
        oneTimePurchaseOfferDetails: const OneTimePurchaseOfferDetailsWrapper(
          formattedPrice: r'R$ 4,90',
          priceAmountMicros: 4900000,
          priceCurrencyCode: 'BRL',
        ),
      );

      expect(
        planosVipDe(GooglePlayProductDetails.fromProductDetails(wrapper)),
        isEmpty,
      );
    });
  });

  group('preco — a Play e a autoridade', () {
    test('o preco exibido e literalmente o formattedPrice da Play', () {
      final planos = planosVipDe(_assinaturaComTresPlanos());

      expect(planos.map((p) => p.precoFormatado),
          [r'R$ 19,90', r'R$ 49,90', r'R$ 149,90']);
    });

    test('o preco por mes e DERIVADO, nao digitado', () {
      final planos = planosVipDe(_assinaturaComTresPlanos());

      expect(planos[0].precoPorMes, closeTo(19.90, 0.001));
      expect(planos[1].precoPorMes, closeTo(49.90 / 3, 0.001));
      expect(planos[2].precoPorMes, closeTo(149.90 / 12, 0.001));
    });

    test('a economia e aritmetica sobre os precos vigentes', () {
      final planos = planosVipDe(_assinaturaComTresPlanos());

      // Sem plano mensal na lista nao ha base de comparacao — e ai nao ha selo.
      expect(economiaPercentual(planos[0], planos), isNull,
          reason: 'o mensal nao economiza em relacao a si mesmo');
      expect(economiaPercentual(planos[1], planos), 16);
      expect(economiaPercentual(planos[2], planos), 37);

      expect(economiaPercentual(planos[2], <PlanoVipDisponivel>[planos[2]]), isNull,
          reason: 'sem mensal na lista, nenhum desconto pode ser afirmado');
    });
  });

  group('planosParaLoja — a vitrine', () {
    test('nome, preco e selo saem do que a Play devolveu', () {
      final cartoes = planosParaLoja(planosVipDe(_assinaturaComTresPlanos()));

      expect(cartoes.map((c) => c.id),
          ['monthly_auto', 'quarterly_auto', 'yearly_auto']);
      expect(cartoes.map((c) => c.nome), ['Mensal', 'Trimestral', 'Anual']);
      expect(cartoes.map((c) => c.preco),
          [r'R$ 19,90', r'R$ 49,90', r'R$ 149,90']);
      expect(cartoes.map((c) => c.selo), [null, '-16%', '-37%']);
    });

    test('o destaque e o plano mais longo, e so quando ha mais de um', () {
      final cartoes = planosParaLoja(planosVipDe(_assinaturaComTresPlanos()));
      expect(cartoes.map((c) => c.destaque), [false, false, true]);

      final soMensal = planosVipDe(_assinaturaComTresPlanos())
          .where((p) => p.mesesDoPeriodo == 1)
          .toList();
      expect(planosParaLoja(soMensal).single.destaque, isFalse);
    });

    test('sem catalogo, a vitrine sai vazia — o estado de hoje', () {
      expect(planosParaLoja(planosVipDe(const <ProductDetails>[])), isEmpty);
    });

    test('o preco por mes usa o simbolo que a Play informou', () {
      final cartoes = planosParaLoja(planosVipDe(_assinaturaComTresPlanos()));

      // `R$` foi extraido de `formattedPrice` pelo proprio plugin; nao esta
      // escrito em lugar nenhum do nosso codigo.
      expect(cartoes[0].porMes, contains(r'R$'));
      expect(cartoes[2].porMes, contains('12,49'));
    });
  });
}
