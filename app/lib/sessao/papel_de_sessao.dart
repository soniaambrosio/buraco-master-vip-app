// papel_de_sessao.dart — a PORTA por onde o PAPEL de quem está logado sai.
//
// Irmã de `credencial_de_sessao.dart`, e pelo mesmo motivo estrutural: o
// controller da sessão não pode importar `firebase_auth`, senão nenhum caso de
// papel seria encenável sem SDK. O adaptador de verdade mora em
// `sessao_firebase.dart`.
//
// ---------------------------------------------------------------------------
// POR QUE UMA PORTA, E NÃO UM `bool` NA TELA
// ---------------------------------------------------------------------------
//
// A Central de Torneios recebia `mostrarAdmin: true` escrito no código do host.
// Isso não é um papel: é uma AFIRMAÇÃO do cliente sobre si mesmo. Qualquer
// pessoa que instalasse o aplicativo passava a ver — e a acionar — a área de
// gestão, porque o único requisito era o literal estar lá.
//
// O papel administrativo deste projeto já tem dono, e não é o cliente: é o
// custom claim `admin` do Firebase Auth. É ele que `firebase/firestore.rules`
// exige em `ehAdmin()`/`admin()`, é ele que `exigirAdmin()` das Cloud Functions
// confere, e é ele que `functions-ranking` e `functions/src/rastreabilidade.ts`
// leem. Um claim é ASSINADO pelo backend e viaja dentro do ID Token — o cliente
// consegue lê-lo, e não consegue escrevê-lo.
//
// Então esta porta não INVENTA papel: ela transporta, até a interface, a mesma
// autoridade que o backend já enforce. Onde a interface diverge do backend, é a
// interface que está errada — e por isso o único jeito de esta porta errar é
// mostrando de MENOS, nunca de mais.
//
// ---------------------------------------------------------------------------
// O QUE ESTA PORTA NÃO TEM, DE PROPÓSITO
// ---------------------------------------------------------------------------
//
// Não tem `conceder`, não tem `assumir`, não tem `definir`. Um cliente com
// vocabulário para atribuir papel a si mesmo acabaria atribuindo — e a linha
// que fizesse isso pareceria, na revisão, um atalho de teste inofensivo.

/// De onde vem o papel de quem está autenticado.
///
/// Um método só, e booleano: a única pergunta que a interface tem direito de
/// fazer é "esta sessão administra?". Ela não recebe a lista de papéis, não
/// recebe o token e não recebe o claim cru — porque nada disso ela saberia
/// julgar melhor do que quem assinou.
abstract class FonteDePapel {
  /// `true` somente quando a autoridade assinada disser que sim.
  ///
  /// Toda outra resposta é `false`: sem sessão, sem token, sem claim, claim
  /// ausente, provedor indisponível, rede fora. FALHA FECHADA — a dúvida nunca
  /// abre a porta, porque "não deu para confirmar" e "é administradora" só se
  /// confundem numa direção, e é a cara.
  Future<bool> ehAdministrador();
}

/// A fonte que não tem papel nenhum para dar.
///
/// É o padrão de [SessaoDoJogador] construída sem provedor — e é o padrão certo:
/// uma sessão que não sabe consultar papel não é uma sessão administrativa. Vale
/// também para os testes de identidade, que encenam login e logout sem nunca
/// falar de claim.
class SemPapel implements FonteDePapel {
  const SemPapel();

  @override
  Future<bool> ehAdministrador() async => false;
}
