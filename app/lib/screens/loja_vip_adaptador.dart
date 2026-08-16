// loja_vip_adaptador.dart — traduz os planos que a Play devolveu para o modelo
// de exibicao da Loja.
//
// A DIRECAO DA DEPENDENCIA E DE PROPOSITO: a tela conhece o Billing, o Billing
// nao conhece a tela. `lib/billing/` nao importa nada de `lib/screens/`, e por
// isso continua testavel sem widget.
//
// NENHUM PRECO NASCE AQUI. `preco` e o `formattedPrice` da Play, ja localizado.
// `porMes` e `selo` sao DERIVADOS por aritmetica dos precos vigentes — nao sao
// valores digitados. Foi isto que substituiu os `'R$ 19,90'`, `'-16%'` e
// `'MELHOR VALOR · -37%'` que estavam escritos a mao em `LojaVM.mock()`: aqueles
// eram texto de maquete, e exibi-los como oferta seria afirmar um preco que
// ninguem aprovou e que estaria errado para qualquer jogador fora do Brasil.
library;

import '../billing/plano_vip.dart';
import 'loja_screen.dart';

/// Nome de exibicao do plano, a partir do periodo que a Play informou.
///
/// Cai no proprio `basePlanId` quando o periodo e desconhecido — mostrar o
/// identificador tecnico e feio, mas e verdade; inventar "Mensal" para um plano
/// que nao e mensal seria pior.
String nomeDoPlano(PlanoVipDisponivel plano) {
  switch (plano.mesesDoPeriodo) {
    case 1:
      return 'Mensal';
    case 3:
      return 'Trimestral';
    case 6:
      return 'Semestral';
    case 12:
      return 'Anual';
    default:
      return plano.basePlanId;
  }
}

/// Formata o preco por mes usando o simbolo de moeda que a PLAY devolveu.
///
/// `null` quando o periodo e desconhecido — a vitrine entao mostra so o preco
/// total, em vez de um "por mes" calculado sobre um periodo que ninguem sabe
/// qual e.
String? precoPorMesFormatado(PlanoVipDisponivel plano) {
  final valor = plano.precoPorMes;
  if (valor == null) return null;
  final simbolo = plano.simboloMoeda ?? plano.moeda;
  // Duas casas, separador decimal por virgula. O `formattedPrice` da Play cobre
  // o preco REAL; isto aqui e um derivado de apoio, e assumir virgula seria
  // errado fora do pt-BR — por isso o simbolo vem da Play e nao daqui.
  final texto = valor.toStringAsFixed(2).replaceAll('.', ',');
  return '$simbolo $texto/mês';
}

/// Converte os planos da Play no modelo que `LojaScreen` desenha.
///
/// Lista vazia entra e lista vazia sai — e `_PlanosGrid` ja trata isso com um
/// `SizedBox.shrink()`. E o estado de hoje: catalogo vazio, nada a oferecer.
List<PlanoVipLoja> planosParaLoja(List<PlanoVipDisponivel> planos) {
  // O maior periodo e o destaque, quando ha mais de um plano. E uma decisao de
  // apresentacao derivada da lista, nao uma promessa comercial: nao afirma
  // "melhor valor", so posiciona o plano mais longo.
  final maiorPeriodo = planos.fold<int>(
    0,
    (maior, p) => (p.mesesDoPeriodo ?? 0) > maior ? (p.mesesDoPeriodo ?? 0) : maior,
  );

  return planos.map((p) {
    final economia = economiaPercentual(p, planos);
    return PlanoVipLoja(
      // O identificador de exibicao e o PLANO-BASE, porque e ele que distingue
      // mensal de anual. O produto e o mesmo nos tres quando eles sao
      // planos-base de uma assinatura so.
      id: p.basePlanId,
      nome: nomeDoPlano(p),
      preco: p.precoFormatado,
      porMes: precoPorMesFormatado(p) ?? p.precoFormatado,
      selo: economia != null ? '-$economia%' : null,
      destaque: planos.length > 1 &&
          p.mesesDoPeriodo != null &&
          p.mesesDoPeriodo == maiorPeriodo,
    );
  }).toList(growable: false);
}
