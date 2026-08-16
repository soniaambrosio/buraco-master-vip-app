// autenticacao_firebase.dart — o adaptador de produção dos comandos de entrar
// e sair.
//
// Separado do contrato pelo mesmo motivo que `sessao_firebase.dart` é separado
// de `sessao_do_jogador.dart`: sem essa divisão, encenar um login cancelado num
// teste de widget exigiria Firebase inicializado.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO NÃO FAZ
// ---------------------------------------------------------------------------
//
// Não lê `currentUser`, não assina `authStateChanges()`, não guarda uid, token,
// nome ou e-mail, e não devolve nada disso para quem chamou. Ele aciona o
// provedor e responde "entrou / cancelou / falhou". Quem descobre QUEM entrou é
// a `SessaoDoJogador`, pelo fluxo de autenticação que ela já observa — e é por
// isso que este objeto pode existir sem virar um segundo dono de sessão.
//
// A única coisa que ele sabe sobre a conta é o suficiente para decidir se há
// provedor operacional neste build.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

// `redacao_segredos.dart` é função pura de texto, sem estado e sem I/O — não é
// a camada de transporte que `sessao/` evita conhecer. Ela entra aqui porque a
// redação tem que acontecer na ORIGEM: uma exceção de login carrega e-mail e
// pedaços de credencial, e deixar para redigir na tela significa que o texto em
// claro existiu, foi copiado e pode ter sido registrado no caminho.
import '../services/redacao_segredos.dart';
import 'comandos_de_autenticacao.dart';

/// Client ID do Firebase (Web) usado como `serverClientId` do Google Sign-In.
///
/// NÃO É SEGREDO: identifica o aplicativo, não autoriza nada sozinho, e vai
/// gravado em qualquer APK publicado. Fica configurável mesmo assim porque é
/// CONFIGURAÇÃO — muda quando o projeto Firebase muda, e o código não.
const String kServerClientIdGoogle = String.fromEnvironment(
  'BMV_GOOGLE_SERVER_CLIENT_ID',
  defaultValue:
      '203886484007-a5e1ob9b7uequoffj6u76h5vltici9a4.apps.googleusercontent.com',
);

/// Entrar e sair, de verdade.
class AutenticacaoFirebase implements ComandosDeAutenticacao {
  AutenticacaoFirebase({GoogleSignIn? google})
    : _google =
          google ??
          GoogleSignIn(
            scopes: const ['email'],
            serverClientId: kServerClientIdGoogle,
          );

  final GoogleSignIn _google;

  /// Há provedor operacional neste build?
  ///
  /// A resposta é sobre o AMBIENTE, não sobre a pessoa: se o Firebase não subiu
  /// (o `main()` tolera isso de propósito), nenhum login vai funcionar, e a tela
  /// pública precisa saber disso ANTES de desenhar um botão.
  @override
  List<ProvedorDeLogin> get provedoresDisponiveis {
    if (kServerClientIdGoogle.isEmpty) return const [];
    try {
      if (Firebase.apps.isEmpty) return const [];
    } catch (_) {
      return const [];
    }
    return const [ProvedorDeLogin.google];
  }

  @override
  Future<ResultadoDeLogin> entrar(ProvedorDeLogin provedor) async {
    if (!provedoresDisponiveis.contains(provedor)) {
      return const ResultadoDeLogin.falhou(
        'este aplicativo está sem serviço de contas configurado',
      );
    }
    return switch (provedor) {
      ProvedorDeLogin.google => _entrarComGoogle(),
    };
  }

  Future<ResultadoDeLogin> _entrarComGoogle() async {
    try {
      final conta = await _google.signIn();
      // `null` é a pessoa fechando o seletor de contas. Não é falha, e tratar
      // como falha encheria a tela de vermelho por uma desistência.
      if (conta == null) return const ResultadoDeLogin.cancelado();

      final autenticacao = await conta.authentication;
      final credencial = GoogleAuthProvider.credential(
        idToken: autenticacao.idToken,
        accessToken: autenticacao.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credencial);

      // NADA do usuário é lido aqui, nem devolvido. A sessão já está sendo
      // avisada pelo fluxo de autenticação neste exato instante.
      return const ResultadoDeLogin.entrou();
    } catch (e) {
      // A exceção do login costuma trazer o e-mail tentado e pedaços da
      // credencial. Redigir ANTES de construir a mensagem é o que garante que o
      // texto em claro nunca chegue a existir fora deste `catch`.
      return ResultadoDeLogin.falhou('Não consegui entrar: ${redigirObjeto(e)}');
    }
  }

  @override
  Future<void> sair() async {
    // As duas saídas são independentes e nenhuma pode impedir a outra: deixar o
    // Google conectado depois de sair do Firebase faria o próximo login pular o
    // seletor de contas e reentrar na MESMA conta — que é, para quem está
    // trocando de conta, indistinguível de o logout não ter funcionado.
    try {
      await _google.signOut();
    } catch (_) {
      // Sem plugin do Google (navegador de teste): não há sessão de Google a
      // encerrar, e o que importa é o passo abaixo.
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Sem Firebase não havia sessão para encerrar. O estado já é o desejado.
    }
  }
}
