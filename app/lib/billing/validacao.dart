// validacao.dart — o contrato da validacao server-side e a DECISAO do cliente
// sobre o veredito. Dart puro: nao importa Firebase, nao importa o plugin da
// Play, e por isso a parte que custa dinheiro roda em teste sem emulador.
//
// A REGRA INEGOCIAVEL
//
// O aplicativo nunca concede VIP nem fichas. Ele recebe da Play Store um
// `purchaseToken`, manda esse token para `validarCompraPlay`, e o backend — que
// fala com a Google Play Developer API usando uma conta de servico que nunca sai
// de la — decide se a compra e real e o que ela concede. O que o jogador ganhou,
// o app descobre LENDO `playerEntitlements/{uid}`, nunca deduzindo da resposta
// da Play Store.
//
// O motivo e que o retorno da Play Store chega dentro do aparelho do jogador, e
// aparelho de jogador nao e ambiente confiavel: um aparelho com root ou um app
// de "compra gratis" forja um retorno de sucesso. O token nao da para forjar.
//
// A DECISAO QUE ESTE ARQUIVO EXISTE PARA PROTEGER
//
// Depois do veredito, o cliente escolhe entre tres destinos, e o erro em
// qualquer direcao custa dinheiro:
//
//   - finalizar (`completePurchase`) uma compra que NAO foi validada faz a Play
//     Store parar de reentrega-la. O jogador pagou e nunca recebe. Irreversivel
//     sem suporte manual.
//   - nao finalizar uma compra recusada de verdade faz a Play reentregar para
//     sempre, e o app fica reprocessando lixo a cada abertura.
//
// Por isso a classificacao dos codigos de erro esta ESCRITA, e nao improvisada
// no `catch`. E por isso a direcao do erro, quando ha duvida, e SEMPRE guardar a
// compra: `_DEFINITIVOS` e uma lista fechada e curta; tudo que nao estiver nela
// e tratado como transitorio.
library;

import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;

/// Compra que a Play Store devolveu e que precisa ser confirmada pelo servidor.
///
/// Os nomes dos campos sao os do contrato de `validarCompraPlay`
/// (`functions-billing/index.js`, passo 2): `produtoId`, `tokenCompra`,
/// `assinatura`, `orderId`. Nao ha `uid` de proposito — o callable tira a
/// identidade de `request.auth.uid`, e um uid mandado pelo cliente seria
/// falsificavel.
class CompraParaValidar {
  const CompraParaValidar({
    required this.produtoId,
    required this.tokenCompra,
    required this.assinatura,
    this.orderId,
  });

  /// ID do produto na Play Console.
  final String produtoId;

  /// `purchaseToken` da Play Store. No Android o `in_app_purchase` o entrega em
  /// `PurchaseDetails.verificationData.serverVerificationData`.
  ///
  /// DADO SENSIVEL. Nao imprimir, nao registrar, nao persistir. Ver
  /// [rotuloDoToken], que e a unica forma autorizada de mencionar uma compra em
  /// diagnostico.
  final String tokenCompra;

  /// `true` para assinatura (o servidor consulta `purchases.subscriptionsv2`),
  /// `false` para produto unico (`purchases.products`).
  ///
  /// O servidor confere este campo contra `configuracao/billing` e recusa com
  /// `invalid-argument` se divergir.
  final bool assinatura;

  /// Identificador do pedido, quando a Play Store informa.
  final String? orderId;

  /// O rotulo curto e mascarado desta compra, para log. Ver [rotuloDoToken].
  String get rotulo => rotuloDoToken(tokenCompra);

  Map<String, dynamic> paraPayload() => <String, dynamic>{
        'produtoId': produtoId,
        'tokenCompra': tokenCompra,
        'assinatura': assinatura,
        if (orderId != null) 'orderId': orderId,
      };

  /// NUNCA imprime o token. Existe para que um `print` distraido de um
  /// `CompraParaValidar` inteiro nao vaze a credencial da compra.
  @override
  String toString() =>
      'CompraParaValidar($produtoId, assinatura: $assinatura, token: $rotulo)';
}

/// O rotulo curto de um `purchaseToken`, para correlacionar app e servidor.
///
/// E deliberadamente o MESMO calculo que o backend usa em
/// `functions-billing/entitlement.js`: `rotuloToken(hash)` devolve os oito
/// primeiros caracteres do SHA-256 hexadecimal do token. Assim uma linha de log
/// do app e uma do servidor falam da mesma compra sem que o token exista em
/// nenhuma das duas.
///
/// Oito caracteres hex sao 32 bits: suficiente para casar duas linhas de log de
/// um mesmo jogador, e curto demais para reverter em token.
String rotuloDoToken(String? token) {
  if (token == null || token.isEmpty) return 'sem-token';
  return sha256.convert(utf8.encode(token)).toString().substring(0, 8);
}

/// Apaga [token] de um texto de diagnostico, trocando-o pelo rotulo.
///
/// Rede de seguranca, nao a defesa principal. A defesa principal e nao colocar o
/// token em texto nenhum; isto existe porque mensagens de excecao sao escritas
/// por codigo de terceiros (plugin, SDK do Firebase) e podem, sem aviso, ecoar o
/// payload que receberam.
String redigirToken(String texto, String? token) {
  if (token == null || token.isEmpty) return texto;
  return texto.replaceAll(token, '<token:${rotuloDoToken(token)}>');
}

/// Veredito do backend sobre uma compra.
class ResultadoValidacao {
  const ResultadoValidacao({
    required this.aprovada,
    this.motivo,
    this.jaProcessada = false,
    this.repetivel = false,
    this.detalhes = const <String, dynamic>{},
    this.entitlementEcoado,
  });

  /// Recusa DEFINITIVA: o backend olhou e disse que esta compra nao vale, ou
  /// que ela nao pertence a esta conta. Repetir a mesma chamada devolveria a
  /// mesma coisa, entao a compra e finalizada e descartada.
  const ResultadoValidacao.recusada(String this.motivo)
      : aprovada = false,
        jaProcessada = false,
        repetivel = false,
        detalhes = const <String, dynamic>{},
        entitlementEcoado = null;

  /// Falha TRANSITORIA: nao deu para obter um veredito. Rede fora, funcao ainda
  /// nao publicada, sessao expirada, catalogo do servidor ainda vazio.
  ///
  /// A compra continua PENDENTE na Play Store de proposito, para ser reentregue
  /// e revalidada. Nada e concedido e nada e perdido.
  const ResultadoValidacao.indisponivel(String this.motivo)
      : aprovada = false,
        jaProcessada = false,
        repetivel = true,
        detalhes = const <String, dynamic>{},
        entitlementEcoado = null;

  /// `true` = o backend confirmou a compra e ja gravou o que ela concede.
  ///
  /// ATENCAO: isto NAO significa "o jogador e VIP". Significa "o servidor
  /// aceitou esta compra". Quem responde se o jogador tem VIP agora e
  /// `EntitlementVip.vigenteEm`, lido de `playerEntitlements/{uid}`. Ver
  /// `estado_ui.dart`.
  final bool aprovada;

  /// Diagnostico, nao texto de interface.
  final String? motivo;

  /// O backend reconheceu um token que ja havia processado. Nao e erro: e o
  /// caminho normal de uma reentrega da Play Store, e de um `restore`. Vale como
  /// sucesso, e nada e creditado de novo porque quem credita e o backend, que e
  /// idempotente por token.
  final bool jaProcessada;

  /// Vale a pena tentar de novo mais tarde. Ver [ResultadoValidacao.indisponivel].
  final bool repetivel;

  /// O que o backend registrou que esta compra concedeu (campo `detalhes`).
  /// Historico da compra, nao estado do direito.
  final Map<String, dynamic> detalhes;

  /// O eco de `{estado, vipAtivo}` que `validarCompraPlay` devolve para
  /// assinatura. GUARDADO PARA DIAGNOSTICO, nunca para decidir a interface: o
  /// documento do Firestore e a autoridade, e ele pode ter mudado depois desta
  /// resposta (uma RTDN pode chegar no meio). Ver `estado_ui.dart`.
  final Map<String, dynamic>? entitlementEcoado;
}

/// Contrato do validador. Abstrato para que a mesa de testes injete um duble sem
/// subir Firebase, e para que trocar o transporte amanha nao encoste na decisao.
abstract class ValidadorDeCompra {
  Future<ResultadoValidacao> validar(CompraParaValidar compra);
}

/// O que fazer com a compra depois do veredito.
enum DestinoDaCompra {
  /// Backend confirmou (ou reconheceu reentrega ja processada). Finaliza na
  /// Play Store para parar a reentrega.
  conceder,

  /// Nao houve veredito. NAO finaliza: a compra fica pendente de proposito, para
  /// a Play Store reentregar e o app revalidar.
  adiar,

  /// Recusa definitiva. Finaliza para a Play parar de reentregar, sem conceder
  /// nada.
  recusar,
}

/// Decisao pura sobre o veredito.
///
/// `jaProcessada` entra junto de `aprovada` de proposito: reentrega de compra ja
/// creditada e SUCESSO. O credito nao se repete porque o backend e idempotente
/// por token (`compras/{hash}`, transacao do passo 7 de `validarCompraPlay`).
DestinoDaCompra decidirDestinoDaCompra(ResultadoValidacao r) {
  if (r.aprovada || r.jaProcessada) return DestinoDaCompra.conceder;
  if (r.repetivel) return DestinoDaCompra.adiar;
  return DestinoDaCompra.recusar;
}

/// A compra deve ser finalizada (`completePurchase`) na Play Store?
///
/// INVARIANTE DE SEGURANCA DO CLIENTE: nunca finalizar o que nao foi validado.
bool deveFinalizarCompra(DestinoDaCompra destino) =>
    destino != DestinoDaCompra.adiar;

/// Codigos de erro do callable que valem como RECUSA DEFINITIVA.
///
/// Lista fechada, curta, e justificada item a item. Tudo que NAO esta aqui e
/// transitorio — a direcao segura, porque tratar transitorio como definitivo
/// descarta compra paga, e o contrario apenas adia.
///
///   permission-denied  o backend provou que este `purchaseToken` pertence a
///                      OUTRA conta Firebase (`decidirSobreRegistroExistente` ->
///                      CONFLITO). Repetir com a mesma conta devolve o mesmo
///                      conflito para sempre. Nada a esperar.
///
///   invalid-argument   payload malformado (`produtoId`/`tokenCompra` ausentes)
///                      ou tipo divergente do catalogo do servidor. Reenviar o
///                      MESMO payload devolve o mesmo erro.
///
/// O QUE FICOU DELIBERADAMENTE DE FORA, E POR QUE:
///
///   unauthenticated    a sessao do Firebase caiu entre a compra e a validacao.
///                      A compra e boa e o jogador pagou; o que falta e login.
///                      Tratar como definitivo QUEIMARIA a compra. Fica
///                      pendente e revalida quando houver sessao (ver o portao
///                      de sessao em `servico_billing.dart`).
///
///   failed-precondition  o produto nao esta em `configuracao/billing`. Durante
///                      todo o bootstrap desta OS o catalogo do servidor esta
///                      VAZIO, entao este e o erro esperado — e uma lacuna de
///                      configuracao que um administrador preenche depois, nao
///                      um veredito sobre a compra. Descartar aqui perderia a
///                      primeira compra real de teste.
///
///   not-found / unimplemented  a funcao ainda nao foi publicada. Estado normal
///                      antes do deploy.
///
///   unavailable / deadline-exceeded / internal / aborted / resource-exhausted
///                      infraestrutura.
const Set<String> _DEFINITIVOS = <String>{
  'permission-denied',
  'invalid-argument',
};

/// Classifica um codigo de erro do callable.
///
/// Devolve `true` quando o erro e um VEREDITO do backend sobre a compra, e
/// `false` quando ele e uma condicao passageira do ambiente.
bool codigoEDefinitivo(String? codigo) {
  if (codigo == null) return false;
  return _DEFINITIVOS.contains(codigo);
}
