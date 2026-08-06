/// Catalogo de produtos do Google Play — camada de dados pura.
///
/// ESTA CLASSE ESTA PROPOSITALMENTE VAZIA.
///
/// A Play Console so libera a area de produtos depois de processar uma versao
/// publicada que contenha a Google Play Billing Library. Ate la nao existem IDs
/// oficiais, e a regra do projeto e clara: **nenhum ID nem preco provisorio
/// entra no codigo**. Um `master_vip_mensal` chutado hoje vira um produto
/// fantasma amanha — IDs de produto do Google Play sao imutaveis e nao podem
/// ser apagados depois de criados, so desativados.
///
/// Quando a Play Console liberar, o cadastro previsto e:
///   - assinatura `master_vip`, com os planos-base mensal, trimestral e anual;
///   - pacotes consumiveis de fichas.
///
/// Para ligar o catalogo, basta preencher os dois conjuntos abaixo com os IDs
/// que a Play Console devolver. Nada mais no app precisa mudar: [BillingService]
/// consulta o que estiver declarado aqui.
///
/// Sobre os planos-base: no Google Play, mensal/trimestral/anual sao
/// *planos-base* DENTRO da assinatura `master_vip` — nao sao produtos separados.
/// Por isso [assinaturas] recebe o ID da assinatura (um so), e os planos-base
/// chegam como ofertas dentro do `ProductDetails` correspondente.
class BillingCatalogo {
  const BillingCatalogo._();

  /// IDs de assinatura. Previsto: um unico ID, `master_vip`.
  ///
  /// Vazio ate a Play Console liberar a area de produtos.
  static const Set<String> assinaturas = <String>{};

  /// IDs de produto unico consumivel. Previsto: os pacotes de fichas.
  ///
  /// Vazio ate a Play Console liberar a area de produtos.
  static const Set<String> consumiveis = <String>{};

  /// Tudo que deve ser consultado na Play Store numa unica ida.
  static Set<String> get todos => <String>{...assinaturas, ...consumiveis};

  /// `false` enquanto a Play Console nao devolver os IDs oficiais.
  ///
  /// A UI usa isto para nao prometer o que ainda nao existe: sem catalogo, os
  /// botoes de compra ficam desabilitados em vez de abrir uma loja vazia.
  static bool get configurado => todos.isNotEmpty;

  static bool ehAssinatura(String id) => assinaturas.contains(id);

  static bool ehConsumivel(String id) => consumiveis.contains(id);

  /// Formato aceito pelo Google Play para IDs de produto: comeca com letra
  /// minuscula ou digito, e segue com minusculas, digitos, ponto e underline.
  static final RegExp formatoValido = RegExp(r'^[a-z0-9][a-z0-9._]*$');
}
