// comandos_de_autenticacao.dart — a contraparte de ESCRITA da sessão.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO NÃO É UM SEGUNDO DONO DE SESSÃO
// ---------------------------------------------------------------------------
//
// `SessaoDoJogador` é dona do ESTADO: ela observa o fluxo de autenticação, sabe
// quem está logado, mantém a geração e emite a credencial. O que ela não tem —
// e de propósito — é vocabulário para MUDAR quem está logado. Entrar e sair são
// comandos, e comando é ação, não estado.
//
// Antes desta OS esse vocabulário existia solto: a tela de menu chamava
// `GoogleSignIn().signIn()` e `FirebaseAuth.instance.signInWithCredential()`
// direto no `initState`, e a de Ajustes chamava `signOut()` por conta própria.
// Duas telas com opinião própria sobre autenticação são dois donos, mesmo que
// nenhuma guarde estado: cada uma decide sozinha o que fazer com a falha, o que
// mostrar e quando.
//
// Aqui há um objeto só, e ele é deliberadamente ESTÉRIL:
//
//   * não guarda usuário, uid, token nem perfil;
//   * não assina `authStateChanges()` — quem assina é a sessão, e só ela;
//   * não sabe se deu certo, exceto pelo que o provedor devolveu na hora.
//
// O efeito do comando chega a todo mundo pelo mesmo caminho de sempre: o
// provedor muda o usuário corrente, o fluxo emite, `SessaoDoJogador` sobe a
// geração, a `PonteSessaoOnline` traduz isso no transporte e a raiz troca de
// tela. Ninguém aqui devolve "o usuário logado" para a UI usar — se devolvesse,
// a UI teria uma segunda fonte de verdade sobre a identidade.
//
// ---------------------------------------------------------------------------
// ESTE ARQUIVO É DOMÍNIO PURO
// ---------------------------------------------------------------------------
//
// Nenhum import de Flutter, Firebase ou Google. É o que permite ao teste de
// widget encenar login, cancelamento e falha sem SDK nenhum. O adaptador de
// produção mora em `autenticacao_firebase.dart`.

/// Um jeito de entrar, tal como este build o oferece.
///
/// A lista é FECHADA de propósito: um provedor que o app não sabe acionar não
/// pode virar botão. §4.3 proíbe o botão que parece funcionar e não funciona.
enum ProvedorDeLogin {
  /// Conta Google, via Firebase Authentication.
  google;

  /// Rótulo de apresentação. Mora aqui, e não na tela, porque é a mesma palavra
  /// em qualquer superfície que ofereça o provedor.
  String get rotulo => switch (this) {
    ProvedorDeLogin.google => 'Entrar com Google',
  };
}

/// Como um pedido de login terminou.
enum DesfechoDeLogin {
  /// A credencial foi aceita. A troca de tela NÃO acontece por causa disto —
  /// acontece porque a sessão viu o fluxo de autenticação mudar. Este valor
  /// serve só para a tela parar de mostrar "entrando…".
  entrou,

  /// A pessoa desistiu (fechou o seletor de conta). Não é erro, e não deve
  /// virar mensagem vermelha.
  cancelado,

  /// Não deu. A mensagem já vem redigida.
  falhou,
}

/// O resultado de [ComandosDeAutenticacao.entrar].
class ResultadoDeLogin {
  const ResultadoDeLogin._(this.desfecho, this.mensagem);

  const ResultadoDeLogin.entrou() : this._(DesfechoDeLogin.entrou, null);
  const ResultadoDeLogin.cancelado() : this._(DesfechoDeLogin.cancelado, null);

  /// [mensagem] é o que a pessoa vai ler. Quem constrói este valor é
  /// responsável por já tê-la redigido — ver `redigirObjeto`.
  const ResultadoDeLogin.falhou(String mensagem)
    : this._(DesfechoDeLogin.falhou, mensagem);

  final DesfechoDeLogin desfecho;

  /// Texto para a interface, ou `null` quando não há o que dizer.
  ///
  /// NUNCA carrega credencial: o adaptador redige antes de construir o
  /// resultado, para que o texto em claro não chegue nem a existir.
  final String? mensagem;

  bool get entrou => desfecho == DesfechoDeLogin.entrou;
}

/// Entrar e sair. Nada mais.
abstract class ComandosDeAutenticacao {
  /// Os provedores que este build consegue REALMENTE acionar.
  ///
  /// Vazio é resposta legítima: um build sem Firebase configurado não tem como
  /// autenticar ninguém, e a tela pública precisa dizer isso em vez de oferecer
  /// um botão que não leva a lugar nenhum.
  List<ProvedorDeLogin> get provedoresDisponiveis;

  /// Aciona [provedor]. Não lança: toda falha volta em [ResultadoDeLogin].
  Future<ResultadoDeLogin> entrar(ProvedorDeLogin provedor);

  /// Encerra a sessão no provedor.
  ///
  /// Não mexe em socket, em cache nem em tela: quem derruba o transporte é a
  /// `PonteSessaoOnline`, ao ver a geração da sessão subir. Um `sair()` que
  /// também fechasse o socket seria um segundo caminho de encerramento, e os
  /// dois divergiriam no primeiro dia em que alguém corrigisse só um.
  Future<void> sair();

  /// Reafirma, AGORA, que quem está na frente do aparelho é o dono da conta.
  ///
  /// Existe para a exclusão de conta, que é operação irreversível e que o
  /// Firebase só aceita com credencial recente. `true` = a identidade foi
  /// reafirmada; `false` = não foi, por desistência no seletor ou por recusa do
  /// provedor — e os dois dão no mesmo para quem chama: não prossiga.
  ///
  /// MORA AQUI, e não na tela, porque reautenticar é operação de SESSÃO. Uma
  /// tela que falasse com `FirebaseAuth.instance` e com o Google por conta
  /// própria seria a segunda autoridade de sessão do aplicativo — exatamente o
  /// que a casca de produção existe para não ter.
  Future<bool> reautenticar();
}

/// Os comandos de um ambiente que não sabe autenticar ninguém.
///
/// É o que a raiz usa quando o provedor de autenticação não subiu. Honesto por
/// construção: sem provedor disponível, a tela pública não desenha botão de
/// entrada nenhum.
class SemAutenticacao implements ComandosDeAutenticacao {
  const SemAutenticacao();

  @override
  List<ProvedorDeLogin> get provedoresDisponiveis => const [];

  @override
  Future<ResultadoDeLogin> entrar(ProvedorDeLogin provedor) async =>
      const ResultadoDeLogin.falhou(
        'este aplicativo está sem serviço de contas configurado',
      );

  @override
  Future<void> sair() async {}

  @override
  /// Sem provedor não há identidade a reafirmar. `false` é a resposta
  /// honesta, e é a que impede a exclusão de seguir sem prova.
  Future<bool> reautenticar() async => false;
}
