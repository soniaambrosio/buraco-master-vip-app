// sessao_firebase.dart — a montagem de produção da sessão.
//
// Separado de `sessao_do_jogador.dart` de propósito: o controller não pode
// importar `firebase_auth`, senão os testes dos quinze casos precisariam de
// Firebase inicializado só para encenar um logout.
//
// Aqui mora a única linha que liga o fluxo de autenticação do Firebase ao
// controller — e é ela que faz "a identidade pertence à sessão autenticada"
// deixar de ser prosa e virar código.

import 'package:firebase_auth/firebase_auth.dart';

import 'fonte_identidade.dart';
import 'fonte_identidade_firebase.dart';
import 'sessao_do_jogador.dart';

/// Constrói a [SessaoDoJogador] de produção.
///
/// TOLERA FIREBASE AUSENTE. `main()` já engole a falha de
/// `Firebase.initializeApp()` para que o jogo rode no navegador de teste sem
/// configuração de Android; se a sessão explodisse aqui, essa blindagem cairia
/// junto. Sem Firebase, o app fica permanentemente não autenticado — que é a
/// verdade daquele ambiente, e não um estado inventado.
SessaoDoJogador criarSessaoDoJogador({FonteDeIdentidade? fonte}) {
  Stream<String?> uids;
  String? uidInicial;
  try {
    final auth = FirebaseAuth.instance;
    uidInicial = auth.currentUser?.uid;
    uids = auth.authStateChanges().map((u) => u?.uid);
  } catch (_) {
    uids = const Stream<String?>.empty();
    uidInicial = null;
  }

  return SessaoDoJogador(
    fonte: fonte ?? FonteDeIdentidadeFirebase(),
    uids: uids,
    uidInicial: uidInicial,
  );
}
