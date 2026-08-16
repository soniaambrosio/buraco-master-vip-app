// fonte_identidade_firebase.dart — o adaptador real de `obterMinhaIdentidade`.
//
// É o ÚNICO arquivo do módulo de sessão que importa `cloud_functions`. Todo o
// resto (estado, controller, escopo, telas) fica puro e testável sem emulador —
// mesma fronteira que `colecoes/colecao_firebase.dart` já estabelece para o
// módulo de coleções.
//
// A REGIÃO PRECISA CASAR com a declarada em `functions-social/src/index.ts`
// (`opcoesCliente.region`). Chamar a região errada devolve `not-found`, que é
// fácil de confundir com "jogador sem identidade" — e confundir os dois é
// exatamente o erro que faria alguém inventar um fallback.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'fonte_identidade.dart';
import 'identidade_publica_sessao.dart';

/// Região das Functions sociais. Casa com `functions-social/src/index.ts`.
const String kRegiaoFuncoesSociais = 'southamerica-east1';

/// Nome da callable. É a ENTRADA NORMAL do cliente para identidade pública.
///
/// A antiga `ranking:garantirIdentidadePublica` foi removida do backend na OS
/// de autoridade única (ver o obituário em `functions-ranking/src/index.ts` e
/// docs/AUTORIDADE-DE-IDENTIDADE-PUBLICA.md). Não há substituto local: o
/// cliente não cunha identidade.
const String kCallableObterMinhaIdentidade = 'obterMinhaIdentidade';

class FonteDeIdentidadeFirebase implements FonteDeIdentidade {
  FonteDeIdentidadeFirebase({FirebaseFunctions? functions})
    : _injetado = functions;

  FirebaseFunctions? _injetado;

  /// Resolvido na primeira chamada, e não no construtor.
  ///
  /// `FirebaseFunctions.instanceFor` exige `Firebase.initializeApp()` já
  /// executado, e o app constrói a sessão antes de qualquer tela — inclusive
  /// no ambiente de teste web em que `main()` engole a falha de inicialização.
  FirebaseFunctions get _functions => _injetado ??=
      FirebaseFunctions.instanceFor(region: kRegiaoFuncoesSociais);

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async {
    try {
      final chamada = _functions.httpsCallable(kCallableObterMinhaIdentidade);
      // Sem payload de propósito: a função tira o UID do contexto autenticado.
      // Nada que o cliente mande influencia qual identidade volta — e é por
      // isso que não há como o cliente pedir a identidade de outra pessoa.
      final resposta = await chamada.call<Object?>();
      final dados = resposta.data;
      if (dados is! Map) {
        throw const FalhaIdentidade(
          MotivoFalhaIdentidade.respostaInvalida,
          'resposta não é um objeto',
        );
      }
      return IdentidadePublica.doWire(dados);
    } on FalhaIdentidade {
      // Já é do vocabulário do domínio (veio de `doWire`). Passa reto — traduzir
      // de novo perderia o motivo `respostaInvalida`.
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw FalhaIdentidade(_traduzir(e.code), e.message ?? e.code);
    } on FirebaseException catch (e) {
      throw FalhaIdentidade(_traduzir(e.code), e.message ?? e.code);
    }
  }

  /// Traduz o código do Firebase para o motivo de domínio.
  ///
  /// `internal` entra em [MotivoFalhaIdentidade.indisponivel] por escolha: é o
  /// código que a Function devolve quando estoura uma exceção não tratada, e
  /// isso costuma ser transitório (cold start, contenção). Negar o retry
  /// deixaria o jogador sem identidade por um soluço do servidor.
  static MotivoFalhaIdentidade _traduzir(String codigo) => switch (codigo) {
    'unauthenticated' => MotivoFalhaIdentidade.naoAutenticado,
    'permission-denied' => MotivoFalhaIdentidade.recusado,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' ||
    'resource-exhausted' ||
    'internal' => MotivoFalhaIdentidade.indisponivel,
    _ => MotivoFalhaIdentidade.desconhecida,
  };
}
