// catalogo.dart — os IDs de produto do Google Play, do lado do cliente.
//
// O CATALOGO OFICIAL ESTA VAZIO DE PROPOSITO, E O VAZIO E FUNCIONAL.
//
// A Play Console so libera a area de produtos depois de processar uma versao que
// contenha a Google Play Billing Library. Enquanto isso nao acontece nao existem
// IDs oficiais, e a regra da OS e explicita: nenhum ID e nenhum preco provisorio
// entram no codigo. Um `master_vip_mensal` chutado hoje vira produto fantasma
// amanha — IDs de produto do Google Play sao IMUTAVEIS e nao podem ser apagados
// depois de criados, apenas desativados.
//
// Com o conjunto vazio, `configurado` e `false`, o servico nunca consulta a Play
// Store e a interface mostra "nenhum produto disponivel" em vez de uma vitrine
// quebrada. E esse o comportamento que o primeiro AAB precisa exibir.
//
// POR QUE E UM VALOR INJETAVEL, E NAO UMA CLASSE ESTATICA
//
// Se os IDs fossem `static const`, o unico catalogo possivel em teste seria o
// vazio — e o caminho "produto carregado corretamente" (BILLING-FLUTTER-03), que
// e o caminho que a primeira compra real vai percorrer, ficaria sem cobertura
// ate o dia em que os IDs existissem. Injetar permite exercitar hoje o codigo de
// amanha, sem inventar ID nenhum no catalogo de producao.
//
// ONDE ESTE ARQUIVO SE ENCAIXA NA CADEIA DE AUTORIDADE
//
// Ele NAO decide o que cada produto concede. Ele e so a lista do que o app pede
// a Play Store. Quem decide o que um produto vale e `configuracao/billing` no
// Firestore, lido por `validarCompraPlay`. Os dois precisam concordar:
//
//     Play Console          ->  IDs reais criados
//     [CatalogoBilling.oficial]  ->  os mesmos IDs, para consultar a vitrine
//     configuracao/billing  ->  os mesmos IDs, com o que cada um concede
//
// Se o app listar um ID que o servidor nao conhece, a compra volta com
// `failed-precondition` e — por decisao de `validacao.dart` — NAO e descartada:
// fica pendente ate o catalogo do servidor ser corrigido. Divergencia de
// configuracao nao custa a compra do jogador.
library;

/// Os IDs de produto que o app consulta na Play Store.
class CatalogoBilling {
  const CatalogoBilling({
    this.assinaturas = const <String>{},
    this.consumiveis = const <String>{},
  });

  /// O CATALOGO DE PRODUCAO. Vazio ate a Play Console liberar a area de
  /// produtos.
  ///
  /// Quando os IDs reais existirem, e AQUI que eles entram — num lugar so. Nada
  /// mais no aplicativo precisa mudar: o servico consulta o que estiver
  /// declarado neste valor.
  ///
  /// Previsto (nao criado): um unico produto de assinatura, com mensal /
  /// trimestral / anual como PLANOS-BASE dentro dele. No Google Play a
  /// periodicidade nao gera produtos separados — um produto de assinatura
  /// carrega varios base plans, e cada um chega ao app como uma oferta dentro do
  /// mesmo `ProductDetails`. Por isso [assinaturas] tende a ter um elemento so.
  static const CatalogoBilling oficial = CatalogoBilling();

  /// IDs de assinatura.
  final Set<String> assinaturas;

  /// IDs de produto unico consumivel (pacotes de fichas).
  final Set<String> consumiveis;

  /// Tudo que deve ser consultado na Play Store numa unica ida.
  Set<String> get todos => <String>{...assinaturas, ...consumiveis};

  /// `false` enquanto nao houver IDs. A interface usa isto para nao prometer o
  /// que ainda nao existe.
  bool get configurado => todos.isNotEmpty;

  bool ehAssinatura(String id) => assinaturas.contains(id);

  bool ehConsumivel(String id) => consumiveis.contains(id);

  /// O valor que vai no campo `assinatura` da chamada a `validarCompraPlay`.
  ///
  /// O servidor confere este campo contra `configuracao/billing` e recusa com
  /// `invalid-argument` se divergir. Um ID desconhecido responde `false`, mas
  /// nao chega a ser enviado: o app so compra o que consultou, e so consulta o
  /// que esta declarado aqui.
  bool declaradoComoAssinatura(String id) => assinaturas.contains(id);

  /// Formato aceito pelo Google Play para IDs de produto: comeca por letra
  /// minuscula ou digito, e segue com minusculas, digitos, ponto e underline.
  ///
  /// Portao para o dia em que os IDs reais forem colados aqui: um ID fora deste
  /// formato e recusado pela Play Console no cadastro, e descobrir isso num
  /// teste custa menos do que descobrir num upload.
  static final RegExp formatoValido = RegExp(r'^[a-z0-9][a-z0-9._]*$');

  /// Todo ID declarado respeita o formato da Play?
  bool get formatoIntegro => todos.every(formatoValido.hasMatch);
}
