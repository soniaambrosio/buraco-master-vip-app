// bonus_boas_vindas.dart — o lado do cliente do bônus de boas-vindas.
//
// O QUE ESTE ARQUIVO FAZ: pede. Só isso.
//
// O QUE ELE NUNCA FAZ: decidir se o jogador tem direito, saber quanto vale o
// bônus, escrever saldo, guardar "já recebi" em disco, ou impedir a segunda
// chamada. As quatro coisas são do servidor, e a razão é a mesma para todas:
// qualquer memória de "já recebi" que viva no aparelho é apagável — basta
// reinstalar — e qualquer decisão que viva aqui é editável por um aplicativo
// modificado.
//
// POR QUE CHAMAR SEMPRE, E NÃO SÓ UMA VEZ
//
// `garantirBonusDeBoasVindas` é idempotente no servidor: o recibo
// `economiaLedger/boas_vindas|{uid}` é criado na MESMA transação que credita, e
// quem chegar depois encontra o recibo e não credita de novo. Com essa garantia
// do outro lado, a estratégia certa aqui é a mais burra possível — chamar a cada
// entrada de sessão e ignorar o resultado.
//
// A alternativa (lembrar que já chamou) trocaria uma chamada barata por um
// estado local que pode divergir, e divergiria justamente nos casos que a OS
// lista: reinstalação, troca de aparelho, restauração de backup. Um jogador que
// perdesse esse estado ficaria sem as 100 fichas dele para sempre, porque o app
// nunca mais perguntaria.
//
// CONTAS ANTIGAS entram por esta mesma porta. Uma conta criada antes desta OS
// simplesmente ainda não tem recibo, então a primeira chamada credita as 100
// dela. Não há migração, e não há como creditar duas vezes.
//
// FALHA NÃO É FATAL. Rede fora, função ainda não publicada, timeout: o jogador
// entra normalmente e a próxima sessão tenta de novo. Bloquear a entrada do jogo
// por causa de um bônus seria trocar um problema pequeno por um grande.
library;

import 'package:cloud_functions/cloud_functions.dart';

/// O que o servidor respondeu.
///
/// `concedido` é falso tanto quando o bônus já havia sido dado quanto quando a
/// chamada falhou — e a distinção existe em [falhou] porque só uma das duas
/// merece nova tentativa nesta sessão.
class ResultadoBoasVindas {
  const ResultadoBoasVindas({
    required this.concedido,
    required this.valor,
    this.erro,
  });

  /// O bônus foi creditado AGORA. Falso na segunda chamada em diante.
  final bool concedido;

  /// Quanto vale o bônus, segundo o servidor. Vem sempre, tenha sido creditado
  /// agora ou não: é o número que a tela mostra ao dizer "suas 100 fichas".
  final int valor;

  /// Tipo da falha, quando houve. `null` quando o servidor respondeu.
  final String? erro;

  bool get falhou => erro != null;

  /// Resposta de quem não conseguiu falar com o servidor.
  const ResultadoBoasVindas.indisponivel(String motivo)
      : concedido = false,
        valor = 0,
        erro = motivo;

  @override
  String toString() => falhou
      ? 'ResultadoBoasVindas.indisponivel($erro)'
      : 'ResultadoBoasVindas(concedido: $concedido, valor: $valor)';
}

/// A porta para o servidor. Interface para a tela poder ser testada sem plugin.
abstract class PortaBoasVindas {
  Future<ResultadoBoasVindas> garantir();
}

/// Chama `garantirBonusDeBoasVindas`, em `southamerica-east1`.
///
/// CONTRATO CONFERIDO CONTRA `functions-economia/index.js`:
///
///   entrada   nenhuma. A função ignora `request.data` inteiro — não existe
///             campo por onde informar valor, saldo ou "ainda não recebi". A
///             identidade sai do token do Firebase Auth que o callable já
///             carrega, pela mesma razão de `ValidadorFirebase`: uid mandado
///             pelo cliente seria falsificável.
///
///   saída     { concedido: bool, valor: int }
///
///   erros     unauthenticated      sem sessão
///             failed-precondition  saldo gravado ilegível (defeito de dado)
///             internal             movimento mal formado
class BoasVindasFirebase implements PortaBoasVindas {
  BoasVindasFirebase({
    String regiao = 'southamerica-east1',
    String nomeDaFuncao = 'garantirBonusDeBoasVindas',
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
  Future<ResultadoBoasVindas> garantir() async {
    try {
      final resposta = await _instancia
          .httpsCallable(_nomeDaFuncao)
          // Mapa vazio, e não `null`: o callable aceita ambos, e mandar um mapa
          // vazio deixa explícito no código que não há nada a enviar.
          .call<Map<String, dynamic>>(const <String, dynamic>{});

      final dados = resposta.data;
      final valor = dados['valor'];
      return ResultadoBoasVindas(
        concedido: dados['concedido'] == true,
        valor: valor is num ? valor.toInt() : 0,
      );
    } on FirebaseFunctionsException catch (e) {
      return ResultadoBoasVindas.indisponivel('backend recusou: ${e.code}');
    } catch (e) {
      // Rede fora, timeout, função ainda não publicada. Só o TIPO da exceção
      // entra na mensagem, pela mesma disciplina de `ValidadorFirebase`.
      return ResultadoBoasVindas.indisponivel(
        'bonus indisponivel: ${e.runtimeType}',
      );
    }
  }
}

/// Pede o bônus uma vez por sessão do aplicativo.
///
/// A dedução aqui é de CHAMADA, não de crédito: ela existe só para a tela
/// inicial não disparar cinco requisições iguais ao reconstruir. A garantia de
/// que o crédito não dobra é do servidor, e não depende disto.
///
/// O estado é de memória e morre com o processo — de propósito. Nada é gravado
/// em disco, então não há o que restaurar de um backup nem o que apagar numa
/// reinstalação.
class GarantiaDeBoasVindas {
  GarantiaDeBoasVindas(this._porta);

  final PortaBoasVindas _porta;
  Future<ResultadoBoasVindas>? _emVoo;
  ResultadoBoasVindas? _ultimo;

  /// Garante o bônus da sessão atual.
  ///
  /// Chamadas simultâneas compartilham a mesma requisição. Uma tentativa que
  /// FALHOU não é memorizada — a próxima chamada tenta de novo, porque falha de
  /// rede não é resposta.
  Future<ResultadoBoasVindas> garantir() {
    final concluido = _ultimo;
    if (concluido != null && !concluido.falhou) {
      return Future<ResultadoBoasVindas>.value(concluido);
    }
    return _emVoo ??= _porta.garantir().then((r) {
      _ultimo = r;
      _emVoo = null;
      return r;
    }, onError: (Object e) {
      // A porta já converte tudo em `ResultadoBoasVindas`; este ramo cobre uma
      // implementação de porta que estoure mesmo assim, para o `_emVoo` não
      // ficar preso e travar todas as tentativas seguintes da sessão.
      _emVoo = null;
      return ResultadoBoasVindas.indisponivel('falha inesperada: ${e.runtimeType}');
    });
  }

  /// O que a última chamada bem-sucedida respondeu, ou `null`.
  ResultadoBoasVindas? get ultimo => _ultimo;
}
