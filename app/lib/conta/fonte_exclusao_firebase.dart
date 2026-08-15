// fonte_exclusao_firebase.dart — o adaptador real das duas callables.
//
// É o ÚNICO arquivo do módulo de conta que importa `cloud_functions`. Todo o
// resto (tipos, controlador, tela) fica puro e testável sem emulador — mesma
// fronteira que `fonte_identidade_firebase.dart` estabelece para a sessão.
//
// A REGIÃO PRECISA CASAR com a declarada em `functions-conta/src/index.ts`
// (`opcoesCliente.region`). Chamar a região errada devolve `not-found` — que
// aqui é especialmente perigoso, porque num fluxo de exclusão "não encontrado" é
// fácil de ler como "conta já removida". São coisas opostas, e confundi-las
// faria o aplicativo encerrar a sessão de uma conta que continua existindo.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'exclusao_de_conta.dart';
import 'fonte_exclusao.dart';

/// Região das Functions de conta. Casa com `functions-conta/src/index.ts`.
const String kRegiaoFuncoesConta = 'southamerica-east1';

const String kCallableResumirExclusao = 'resumirExclusaoDeConta';
const String kCallableExcluirMinhaConta = 'excluirMinhaConta';

class FonteDeExclusaoFirebase implements FonteDeExclusaoDeConta {
  FonteDeExclusaoFirebase({FirebaseFunctions? functions}) : _injetado = functions;

  FirebaseFunctions? _injetado;

  /// Resolvido na primeira chamada, e não no construtor — `instanceFor` exige
  /// `Firebase.initializeApp()` já executado, e a tela pode ser construída
  /// antes disso no ambiente de teste.
  FirebaseFunctions get _functions =>
      _injetado ??= FirebaseFunctions.instanceFor(region: kRegiaoFuncoesConta);

  @override
  Future<ResumoDaExclusao> resumir() async {
    return _chamar(kCallableResumirExclusao, null, (dados) {
      return ResumoDaExclusao.doWire(dados);
    });
  }

  @override
  Future<ResultadoDaExclusao> excluir({required String confirmacao}) async {
    // O PAYLOAD LEVA A PALAVRA, E NADA ALÉM DELA. Mandar o uid "para ajudar" não
    // ajudaria: o servidor RECUSA o pedido que traz alvo, de propósito, para que
    // a tentativa fique registrada em vez de ser ignorada em silêncio.
    return _chamar(kCallableExcluirMinhaConta, {'confirmacao': confirmacao}, (
      dados,
    ) {
      return ResultadoDaExclusao.doWire(dados);
    });
  }

  Future<T> _chamar<T>(
    String nome,
    Map<String, Object?>? payload,
    T Function(Map<Object?, Object?>) converter,
  ) async {
    try {
      final chamada = _functions.httpsCallable(nome);
      final resposta = payload == null
          ? await chamada.call<Object?>()
          : await chamada.call<Object?>(payload);
      final dados = resposta.data;
      if (dados is! Map) {
        throw const FalhaExclusao(
          MotivoFalhaExclusao.desconhecida,
          'resposta não é um objeto',
        );
      }
      return converter(dados);
    } on FalhaExclusao {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw _traduzir(e);
    } on FirebaseException catch (e) {
      throw FalhaExclusao(
        _porCodigoGenerico(e.code),
        e.message ?? e.code,
      );
    }
  }

  /// Traduz a recusa do servidor para o vocabulário do domínio.
  ///
  /// LÊ `details.recusa`, E NÃO A MENSAGEM. O backend põe o código em
  /// `details.recusa` exatamente para que o cliente possa distinguir os casos
  /// sem depender do texto — mesma decisão do módulo social (§35 do contrato de
  /// identidade pública). Um `switch` sobre `e.message` quebraria na primeira
  /// vez que alguém melhorasse uma frase.
  static FalhaExclusao _traduzir(FirebaseFunctionsException e) {
    final detalhes = e.details;
    final recusa = detalhes is Map ? detalhes['recusa'] : null;

    if (recusa is String) {
      switch (recusa) {
        case 'reautenticacaoNecessaria':
          return FalhaExclusao(
            MotivoFalhaExclusao.reautenticacaoNecessaria,
            e.message ?? recusa,
          );
        case 'confirmacaoInvalida':
          return FalhaExclusao(
            MotivoFalhaExclusao.confirmacaoInvalida,
            e.message ?? recusa,
          );
        case 'torneioEmAndamento':
          return FalhaExclusao(
            MotivoFalhaExclusao.torneioEmAndamento,
            e.message ?? recusa,
            bloqueios: _bloqueios(detalhes),
          );
        case 'exclusaoParcial':
          return FalhaExclusao(MotivoFalhaExclusao.parcial, e.message ?? recusa);
        // `alvoNoPayloadRecusado` NÃO tem motivo próprio de propósito: se ele
        // chegar aqui, é defeito DESTE aplicativo (nenhuma tela deveria mandar
        // alvo), e não algo que o jogador possa resolver. Cai em `desconhecida`,
        // que é o balde certo para "isto não deveria acontecer".
      }
    }

    return FalhaExclusao(_porCodigoGenerico(e.code), e.message ?? e.code);
  }

  static List<BloqueioDeTorneio> _bloqueios(Object? detalhes) {
    if (detalhes is! Map) return const [];
    final bruto = detalhes['bloqueios'];
    if (bruto is! List) return const [];
    return bruto
        .map(BloqueioDeTorneio.doWire)
        .whereType<BloqueioDeTorneio>()
        .toList(growable: false);
  }

  /// `internal` entra em [MotivoFalhaExclusao.indisponivel] pela mesma razão que
  /// no módulo de sessão: é o código de exceção não tratada, que costuma ser
  /// transitório. A exceção é a exclusão parcial, que o servidor manda como
  /// `internal` COM `details.recusa` — e por isso o `switch` acima vem antes.
  static MotivoFalhaExclusao _porCodigoGenerico(String codigo) =>
      switch (codigo) {
        'unauthenticated' => MotivoFalhaExclusao.naoAutenticado,
        'unavailable' ||
        'deadline-exceeded' ||
        'aborted' ||
        'resource-exhausted' ||
        'internal' => MotivoFalhaExclusao.indisponivel,
        _ => MotivoFalhaExclusao.desconhecida,
      };
}
