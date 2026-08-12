// validacao_firebase.dart — o transporte da validacao: a callable
// `validarCompraPlay`, em `us-central1`.
//
// Fica isolado num arquivo proprio para que `validacao.dart` — onde mora a
// decisao que custa dinheiro — continue livre de plugin e testavel em Dart puro.
//
// POR QUE CALLABLE, E NAO HTTP ABERTO
//
// O `httpsCallable` ja carrega o token do Firebase Auth do jogador. O backend
// descobre QUEM esta comprando por `request.auth.uid`, sem que o app precise
// mandar um uid — que seria falsificavel. Ver o passo 1 de `validarCompraPlay`.
//
// CONTRATO CONFERIDO CONTRA `functions-billing/index.js`:
//
//   entrada   { produtoId: string, tokenCompra: string,
//               assinatura: bool, orderId?: string }
//
//   saida     { aprovada: bool,
//               jaProcessada?: bool,
//               motivo?: string,
//               detalhes?: map,
//               entitlement?: { estado: string, vipAtivo: bool } }
//
//   erros     unauthenticated      sem sessao
//             invalid-argument     payload malformado ou tipo divergente
//             failed-precondition  produto fora de `configuracao/billing`
//             permission-denied    token de outra conta
//             unavailable          Play Developer API instavel / refresco falhou
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'validacao.dart';

/// Chama `validarCompraPlay` e traduz a resposta para [ResultadoValidacao].
class ValidadorFirebase implements ValidadorDeCompra {
  ValidadorFirebase({
    String regiao = 'us-central1',
    String nomeDaFuncao = 'validarCompraPlay',
    FirebaseFunctions? funcoes,
  })  : _regiao = regiao,
        _nomeDaFuncao = nomeDaFuncao,
        _funcoes = funcoes;

  final String _regiao;
  final String _nomeDaFuncao;
  final FirebaseFunctions? _funcoes;

  FirebaseFunctions get _instancia =>
      _funcoes ?? FirebaseFunctions.instanceFor(region: _regiao);

  @override
  Future<ResultadoValidacao> validar(CompraParaValidar compra) async {
    try {
      final resposta = await _instancia
          .httpsCallable(_nomeDaFuncao)
          .call<Map<String, dynamic>>(compra.paraPayload());

      final dados = resposta.data;
      final entitlement = dados['entitlement'];

      return ResultadoValidacao(
        aprovada: dados['aprovada'] == true,
        motivo: dados['motivo'] as String?,
        jaProcessada: dados['jaProcessada'] == true,
        detalhes: Map<String, dynamic>.from(
          (dados['detalhes'] as Map?) ?? const <String, dynamic>{},
        ),
        entitlementEcoado: entitlement is Map
            ? Map<String, dynamic>.from(entitlement)
            : null,
      );
    } on FirebaseFunctionsException catch (e) {
      // `redigirToken` e rede de seguranca: `e.message` e escrito pelo SDK, e um
      // erro de serializacao pode ecoar o payload que recebeu — payload esse que
      // contem o `purchaseToken`.
      final motivo = redigirToken(
        'backend recusou: ${e.code} ${e.message ?? ''}'.trim(),
        compra.tokenCompra,
      );

      // A classificacao mora em `validacao.dart`, escrita e justificada. Aqui so
      // se obedece: definitivo vira recusa, todo o resto vira adiamento.
      return codigoEDefinitivo(e.code)
          ? ResultadoValidacao.recusada(motivo)
          : ResultadoValidacao.indisponivel(motivo);
    } catch (e) {
      // Rede fora, timeout, funcao ainda nao publicada. NUNCA e recusa: a compra
      // continua pendente na Play Store e o app tenta de novo depois.
      //
      // So o TIPO da excecao entra na mensagem. Interpolar `$e` arrastaria para
      // o log o texto de um erro de terceiros, que pode conter o payload.
      return ResultadoValidacao.indisponivel(
        'validacao indisponivel: ${e.runtimeType}',
      );
    }
  }
}
