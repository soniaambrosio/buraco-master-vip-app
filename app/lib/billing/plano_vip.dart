// plano_vip.dart — os planos VIP como a PLAY os descreve.
//
// POR QUE ESTE ARQUIVO EXISTE, E POR QUE ELE NAO TEM NENHUM PRECO
//
// No Google Play, mensal / trimestral / anual sao PLANOS-BASE dentro de um
// produto de assinatura, e nao produtos separados. O `in_app_purchase` reflete
// isso de um jeito que e facil ler errado: `queryProductDetails` devolve UMA
// entrada por plano-base, mas todas elas carregam o MESMO `ProductDetails.id` —
// que e o id do PRODUTO. Quem distingue mensal de anual e o `basePlanId`, que
// mora um nivel abaixo, em `subscriptionOfferDetails[subscriptionIndex]`.
//
// Confundir os dois tem consequencia direta no backend: `validarCompraPlay`
// recebe `produtoId` e procura em `configuracao/billing`. Se os tres planos
// forem planos-base de um produto so, o servidor ve UM produtoId nas tres
// compras e nao consegue distinguir plano nenhum. Ver a secao "Identificador"
// em `docs/PLAY-BILLING-CLIENTE-FLUTTER.md`.
//
// NENHUM PRECO E ESCRITO AQUI. Todo valor exibido vem de `formattedPrice`, que a
// Play devolve JA localizado e convertido para a moeda e o pais da conta do
// jogador. Preco em codigo seria uma segunda autoridade comercial, divergiria da
// Play no primeiro reajuste, e mentiria para qualquer jogador fora do pais de
// referencia. O preco por mes e a economia sao DERIVADOS desses valores por
// aritmetica — nao sao dados novos.
library;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

/// Um plano-base de assinatura, do jeito que a Play o descreve agora.
class PlanoVipDisponivel {
  const PlanoVipDisponivel({
    required this.produtoId,
    required this.basePlanId,
    required this.precoFormatado,
    required this.precoBruto,
    required this.moeda,
    required this.periodo,
    required this.produto,
    this.simboloMoeda,
    this.ofertaToken,
  });

  /// O id do PRODUTO de assinatura na Play Console.
  ///
  /// E este — e nao o [basePlanId] — que viaja como `produtoId` para
  /// `validarCompraPlay` e que precisa existir em `configuracao/billing`.
  final String produtoId;

  /// O id do PLANO-BASE (mensal, trimestral, anual).
  ///
  /// O backend grava este valor em `compras/{hash}.concessao.planoBase`, lido da
  /// resposta da Google. Hoje ele e registro historico: nenhuma regra economica
  /// do servidor decide por ele.
  final String basePlanId;

  /// Preco JA formatado e localizado pela Play. A unica autoridade de preco.
  final String precoFormatado;

  /// O mesmo preco em numero, para calculos derivados.
  final double precoBruto;

  final String moeda;
  final String? simboloMoeda;

  /// Periodo de cobranca em ISO-8601 (`P1M`, `P3M`, `P1Y`).
  final String periodo;

  /// Token da oferta deste plano-base. E o que faz a Play abrir o fluxo do plano
  /// ESCOLHIDO em vez do padrao do produto.
  final String? ofertaToken;

  /// O `ProductDetails` de origem, para entregar a `ServicoBilling.comprar`.
  final ProductDetails produto;

  /// Quantos meses o periodo cobre. `null` para um periodo que este codigo nao
  /// conhece — e ai nada derivado dele e exibido, em vez de exibir um chute.
  int? get mesesDoPeriodo => _mesesDe(periodo);

  /// Preco por mes, DERIVADO. `null` quando o periodo e desconhecido.
  double? get precoPorMes {
    final meses = mesesDoPeriodo;
    if (meses == null || meses <= 0) return null;
    return precoBruto / meses;
  }

  @override
  String toString() =>
      'PlanoVipDisponivel($produtoId/$basePlanId, $periodo, $precoFormatado)';
}

/// Converte `P1M`, `P3M`, `P1Y` em meses.
///
/// Deliberadamente estreito: so os periodos que a Play oferece para assinatura
/// mensal, trimestral e anual. Um periodo desconhecido devolve `null` para que o
/// preco por mes simplesmente nao apareca, em vez de aparecer errado.
int? _mesesDe(String periodo) {
  final m = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$')
      .firstMatch(periodo);
  if (m == null) return null;
  final anos = int.tryParse(m.group(1) ?? '0') ?? 0;
  final meses = int.tryParse(m.group(2) ?? '0') ?? 0;
  // Semanas e dias nao viram mes: um plano semanal nao tem "preco por mes"
  // honesto, e inventar um seria pior que omitir.
  final semanas = int.tryParse(m.group(3) ?? '0') ?? 0;
  final dias = int.tryParse(m.group(4) ?? '0') ?? 0;
  if (semanas > 0 || dias > 0) return null;
  final total = anos * 12 + meses;
  return total > 0 ? total : null;
}

/// Extrai os planos-base de tudo que a Play devolveu.
///
/// Entradas que nao sejam de assinatura do Google Play sao IGNORADAS em vez de
/// virarem plano torto: consumivel nao e plano, e uma entrada de outra
/// plataforma nao tem plano-base nenhum.
List<PlanoVipDisponivel> planosVipDe(List<ProductDetails> produtos) {
  final planos = <PlanoVipDisponivel>[];

  for (final p in produtos) {
    if (p is! GooglePlayProductDetails) continue;

    final indice = p.subscriptionIndex;
    final ofertas = p.productDetails.subscriptionOfferDetails;
    if (indice == null || ofertas == null || indice >= ofertas.length) {
      // Produto unico (consumivel) ou entrada sem oferta: nao e plano VIP.
      continue;
    }

    final oferta = ofertas[indice];
    final fase = oferta.pricingPhases.isEmpty ? null : oferta.pricingPhases.first;
    if (fase == null) continue;

    planos.add(PlanoVipDisponivel(
      produtoId: p.id,
      basePlanId: oferta.basePlanId,
      precoFormatado: p.price,
      precoBruto: p.rawPrice,
      moeda: p.currencyCode,
      simboloMoeda: p.currencySymbol,
      periodo: fase.billingPeriod,
      ofertaToken: p.offerToken,
      produto: p,
    ));
  }

  // Ordena do periodo mais curto para o mais longo, para a vitrine sair estavel
  // independentemente da ordem em que a Play respondeu. Periodo desconhecido vai
  // para o fim.
  planos.sort((a, b) {
    final ma = a.mesesDoPeriodo ?? 1 << 20;
    final mb = b.mesesDoPeriodo ?? 1 << 20;
    if (ma != mb) return ma.compareTo(mb);
    return a.basePlanId.compareTo(b.basePlanId);
  });

  return List<PlanoVipDisponivel>.unmodifiable(planos);
}

/// Quantos por cento este plano economiza por mes em relacao ao MENSAL.
///
/// DERIVADO dos precos da Play, nunca digitado. Devolve `null` quando nao ha
/// plano mensal na lista, quando o periodo e desconhecido, ou quando nao ha
/// economia — nesses casos a vitrine simplesmente nao mostra selo, em vez de
/// mostrar um desconto inventado.
///
/// Existe porque a alternativa era o que estava no codigo antes: `'-16%'` e
/// `'MELHOR VALOR · -37%'` escritos a mao numa maquete. Selo de desconto e
/// afirmacao comercial; esta funcao a torna uma consequencia aritmetica dos
/// precos vigentes na Play.
int? economiaPercentual(PlanoVipDisponivel plano, List<PlanoVipDisponivel> todos) {
  final mensal = todos.where((p) => p.mesesDoPeriodo == 1);
  if (mensal.isEmpty) return null;

  final base = mensal.first.precoPorMes;
  final deste = plano.precoPorMes;
  if (base == null || deste == null || base <= 0) return null;

  final economia = ((base - deste) / base * 100).round();
  return economia > 0 ? economia : null;
}
