/// Contrato da validacao de compra no servidor — SEM dependencia de Firebase.
///
/// A implementacao concreta vive em `billing_validacao_firebase.dart`. A
/// separacao existe para que a decisao critica (conceder / adiar / recusar)
/// possa ser testada em Dart puro, sem subir plugin nenhum.
///
/// REGRA INEGOCIAVEL: o aplicativo **nunca** concede VIP nem fichas. Ele recebe
/// da Play Store um token de compra, manda esse token para o backend, e o
/// backend — que fala com a Google Play Developer API usando uma conta de
/// servico — decide se a compra e real e o que conceder.
///
/// O motivo e simples: o retorno da Play Store chega dentro do dispositivo do
/// jogador, e dispositivo do jogador nao e ambiente confiavel. Um aparelho com
/// root ou um app de "compra gratis" consegue forjar um retorno de sucesso.
/// O token, por outro lado, so pode ser confirmado por quem tem a credencial da
/// conta de servico — que vive no backend e nunca sai de la.
///
/// O saldo/VIP resultante e escrito pelo backend no Firestore. O app apenas le.
library;

/// Compra que a Play Store devolveu e que precisa ser confirmada.
class CompraParaValidar {
  const CompraParaValidar({
    required this.produtoId,
    required this.tokenCompra,
    required this.assinatura,
    this.orderId,
  });

  /// ID do produto na Play Console.
  final String produtoId;

  /// `purchaseToken` da Play Store. No `in_app_purchase` do Android ele chega em
  /// `PurchaseDetails.verificationData.serverVerificationData`.
  final String tokenCompra;

  /// `true` para assinatura (`purchases.subscriptionsv2.get`),
  /// `false` para produto unico (`purchases.products.get`).
  final bool assinatura;

  /// Identificador do pedido, quando a Play Store informa. Serve de chave de
  /// idempotencia adicional no backend.
  final String? orderId;

  Map<String, dynamic> paraPayload() => <String, dynamic>{
        'produtoId': produtoId,
        'tokenCompra': tokenCompra,
        'assinatura': assinatura,
        if (orderId != null) 'orderId': orderId,
      };
}

/// Veredito do backend.
class ResultadoValidacao {
  const ResultadoValidacao({
    required this.aprovada,
    this.motivo,
    this.jaProcessada = false,
    this.repetivel = false,
    this.detalhes = const <String, dynamic>{},
  });

  /// Recusa DEFINITIVA: o backend olhou o token e disse que nao vale. Nao
  /// adianta tentar de novo — a compra deve ser finalizada e descartada.
  const ResultadoValidacao.recusada(String this.motivo)
      : aprovada = false,
        jaProcessada = false,
        repetivel = false,
        detalhes = const <String, dynamic>{};

  /// Falha TEMPORARIA: nao conseguimos nem perguntar (rede fora, funcao ainda
  /// nao publicada, timeout). A compra continua pendente na Play Store de
  /// proposito, para ser reentregue e revalidada depois.
  const ResultadoValidacao.indisponivel(String this.motivo)
      : aprovada = false,
        jaProcessada = false,
        repetivel = true,
        detalhes = const <String, dynamic>{};

  /// `true` = o backend confirmou a compra e ja gravou a concessao.
  final bool aprovada;

  /// Por que foi recusada, quando foi. Texto de diagnostico, nao de UI.
  final String? motivo;

  /// `true` quando o backend reconheceu um token que ja havia sido processado.
  /// Nao e erro: e o caminho normal de uma reentrega da Play Store. O app trata
  /// como sucesso e apenas finaliza a compra — **sem** creditar de novo, porque
  /// quem credita e o backend, e ele ja creditou uma unica vez.
  final bool jaProcessada;

  /// `true` quando vale a pena revalidar mais tarde. Ver [ResultadoValidacao.indisponivel].
  final bool repetivel;

  /// O que o backend concedeu (ex.: validade do VIP, fichas creditadas).
  final Map<String, dynamic> detalhes;
}

/// Contrato do validador — abstrato de proposito, para que a mesa de testes
/// possa injetar um duble sem subir Firebase.
abstract class ValidadorDeCompra {
  Future<ResultadoValidacao> validar(CompraParaValidar compra);
}

/// O que fazer com uma compra depois do veredito do backend.
enum DestinoDaCompra {
  /// Backend confirmou (ou reconheceu uma reentrega ja processada). Finaliza a
  /// compra na Play Store.
  conceder,

  /// Nao deu para validar agora. **Nao finaliza**: a compra fica pendente de
  /// proposito para a Play Store reentregar e revalidar.
  adiar,

  /// Recusa definitiva. Finaliza para a Play parar de reentregar, sem conceder
  /// nada.
  recusar,
}

/// Decisao pura sobre o veredito do backend.
///
/// Fica separada do [ValidadorDeCompra] e do servico porque e o ponto onde um
/// erro custa dinheiro do jogador ou do projeto: tratar uma falha de rede como
/// recusa perde a compra paga; tratar uma recusa como falha temporaria faz a
/// Play reentregar para sempre.
DestinoDaCompra decidirDestinoDaCompra(ResultadoValidacao r) {
  // `jaProcessada` entra aqui junto de `aprovada` de proposito: uma reentrega de
  // compra ja creditada e SUCESSO, nao erro. O credito nao se repete porque o
  // backend e idempotente por token — o app so limpa a pendencia.
  if (r.aprovada || r.jaProcessada) return DestinoDaCompra.conceder;
  if (r.repetivel) return DestinoDaCompra.adiar;
  return DestinoDaCompra.recusar;
}

/// Se a compra deve ser finalizada (`completePurchase`) na Play Store.
///
/// Invariante de seguranca do cliente: **nunca finalizar o que nao foi
/// validado**. Finalizar uma compra que nao conseguimos confirmar faz a Play
/// Store parar de reentrega-la, e o jogador que pagou fica sem receber.
bool deveFinalizarCompra(DestinoDaCompra destino) =>
    destino != DestinoDaCompra.adiar;
