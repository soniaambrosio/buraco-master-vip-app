import 'package:cloud_functions/cloud_functions.dart';

import 'billing_validacao.dart';

/// Implementacao real do [ValidadorDeCompra]: Cloud Function chamavel do projeto
/// `buraco-master-vip`.
///
/// Usa `httpsCallable`, e nao um endpoint HTTP aberto, porque o callable ja
/// carrega o token do Firebase Auth do jogador. O backend sabe QUEM esta
/// comprando sem que o app precise mandar um uid — que seria falsificavel.
///
/// Fica isolada em seu proprio arquivo para que `billing_validacao.dart`
/// continue livre de dependencia de plugin e possa ser testado em Dart puro.
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
