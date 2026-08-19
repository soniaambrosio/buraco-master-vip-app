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

import 'credencial_de_sessao.dart';
import 'fonte_identidade.dart';
import 'fonte_identidade_firebase.dart';
import 'papel_de_sessao.dart';
import 'sessao_do_jogador.dart';

/// A credencial de produção: o ID Token de quem está logado no Firebase.
///
/// `getIdToken()` devolve o token em cache e só vai à rede quando ele já expirou
/// ou está perto disso — então pedir a cada tentativa de conexão é barato e
/// garante credencial fresca na reconexão.
///
/// É o ÚNICO ponto do app que sabe extrair um token do Firebase. O transporte
/// (`services/online_service.dart`) não importa `firebase_auth`, e há teste
/// estrutural que falha se voltar a importar: dois lugares capazes de emitir
/// credencial são dois donos de autenticação, e o segundo nunca conhece a
/// geração da sessão.
class CredencialDoFirebase implements FonteDeCredencial {
  const CredencialDoFirebase();

  @override
  Future<String?> obterToken() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return null;
      return await u.getIdToken();
    } catch (_) {
      // Firebase ausente ou indisponível vale como "não há credencial" — a
      // mesma tolerância que `criarSessaoDoJogador` já pratica abaixo.
      return null;
    }
  }
}

/// O papel de produção: o custom claim `admin` do ID Token de quem está logado.
///
/// LÊ, NÃO DECIDE. O claim é gravado pelo backend com o Admin SDK e vem ASSINADO
/// dentro do token — o cliente consegue conferi-lo e não consegue forjá-lo. É a
/// mesma autoridade que `firebase/firestore.rules` exige em `ehAdmin()` e que
/// `exigirAdmin()` das Cloud Functions confere; trazê-la até a interface é
/// alinhar a tela ao portão que já existe, não criar um portão novo.
///
/// POR ISSO A INTERFACE NUNCA É O PORTÃO. Mesmo que este leitor errasse para
/// mais, quem recusa a operação continua sendo a regra e a Function. O que a
/// tela decide é só o que DESENHAR — e, por [ehAdministrador] falhar fechado,
/// o pior erro possível dela é esconder de quem tinha direito.
///
/// `getIdTokenResult()` devolve o token em cache e só vai à rede quando ele
/// expirou. Consequência que fica registrada: um claim concedido AGORA só
/// aparece para o aplicativo na próxima renovação do token (ou depois de
/// reentrar). Isso é comportamento do Firebase, não desta classe — e é o lado
/// seguro do atraso: papel concedido demora a aparecer, papel revogado também
/// demora a sumir da TELA, mas nunca do backend, que confere o claim a cada
/// chamada.
class PapelDoFirebase implements FonteDePapel {
  const PapelDoFirebase();

  @override
  Future<bool> ehAdministrador() async {
    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return false;
      final resultado = await u.getIdTokenResult();
      // `== true` e não `as bool`: o claim pode vir ausente, nulo ou de outro
      // tipo, e nenhum desses casos é uma autorização.
      return resultado.claims?['admin'] == true;
    } catch (_) {
      // Firebase ausente ou indisponível vale como "não administra" — a mesma
      // tolerância que [CredencialDoFirebase] pratica, e com o mesmo sinal:
      // para o lado fechado.
      return false;
    }
  }
}

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
    credenciais: const CredencialDoFirebase(),
    papeis: const PapelDoFirebase(),
  );
}
