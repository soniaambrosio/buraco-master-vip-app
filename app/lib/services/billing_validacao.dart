import 'package:cloud_functions/cloud_functions.dart';

/// Validacao de compra no servidor.
///
/// REGRA INEGOCIAVEL: o aplicativo **nunca** concede VIP nem fichas por conta
/// propria. Ele recebe da Play Store um token de compra, manda esse token para
/// o backend, e o backend — que fala com a Google Play Developer API usando uma
/// conta de servico — decide se a compra e real e o que conceder.
///
/// O motivo e simples: o retorno da Play Store chega dentro do dispositivo do
/// jogador, e dispositivo do jogador nao e ambiente confiavel. Um aparelho com
/// root ou um app de "compra gratis" consegue forjar um retorno de sucesso.
/// O token, por outro lado, so pode ser confirmado por quem tem a credencial da
/// conta de servico — que vive no backend e nunca sai de la.
///
/// O saldo/VIP resultante e escrito pelo backend no Firestore. O app apenas le.

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

  /// `true` quando vale a pena revalidar mais tarde. Ver [ResultadoValidacao.indisponivel].
  final bool repetivel;

  /// `true` quando o backend reconheceu um token que ja havia sido processado.
  /// Nao e erro: e o caminho normal de uma reentrega da Play Store. O app trata
  /// como sucesso e apenas finaliza a compra, sem conceder de novo.
  final bool jaProcessada;

  /// O que o backend concedeu (ex.: validade do VIP, fichas creditadas).
  final Map<String, dynamic> detalhes;
}

/// Contrato do validador — abstrato de proposito, para que a mesa de testes
/// possa injetar um dublê sem subir Firebase.
abstract class ValidadorDeCompra {
  Future<ResultadoValidacao> validar(CompraParaValidar compra);
}

/// Implementacao real: Cloud Function chamavel do projeto `buraco-master-vip`.
///
/// Usa `httpsCallable`, e nao um endpoint HTTP aberto, porque o callable ja
/// carrega o token do Firebase Auth do jogador. O backend sabe QUEM esta
/// comprando sem que o app precise mandar um uid — que seria falsificavel.
class ValidadorFirebase implements ValidadorDeCompra {
  ValidadorFirebase({
    String regiao = 'us-central1',
    String nomeDaFuncao = 'validarCompraPlay',
  })  : _regiao = regiao,
        _nomeDaFuncao = nomeDaFuncao;

  final String _regiao;
  final String _nomeDaFuncao;

  @override
  Future<ResultadoValidacao> validar(CompraParaValidar compra) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: _regiao)
          .httpsCallable(_nomeDaFuncao);
      final resposta = await callable.call<Map<String, dynamic>>(
        compra.paraPayload(),
      );
      final dados = resposta.data;
      return ResultadoValidacao(
        aprovada: dados['aprovada'] == true,
        motivo: dados['motivo'] as String?,
        jaProcessada: dados['jaProcessada'] == true,
        detalhes: Map<String, dynamic>.from(
          (dados['detalhes'] as Map?) ?? const <String, dynamic>{},
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      final motivo = 'backend recusou: ${e.code} ${e.message ?? ''}'.trim();
      // `unavailable`, `deadline-exceeded` e `internal` sao falhas de
      // infraestrutura, nao vereditos sobre a compra: mantem a compra pendente
      // para revalidar. Os demais codigos sao decisao do backend e valem como
      // recusa definitiva.
      const transitorios = <String>{'unavailable', 'deadline-exceeded', 'internal'};
      return transitorios.contains(e.code)
          ? ResultadoValidacao.indisponivel(motivo)
          : ResultadoValidacao.recusada(motivo);
    } catch (e) {
      // Rede fora, funcao ainda nao publicada, timeout. NAO e recusa definitiva:
      // a compra continua pendente na Play Store e o app tenta de novo depois.
      return ResultadoValidacao.indisponivel('validacao indisponivel: $e');
    }
  }
}
