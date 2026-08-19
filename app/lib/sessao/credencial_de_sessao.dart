// credencial_de_sessao.dart — a PORTA por onde a credencial da sessão sai.
//
// Irmã de `fonte_identidade.dart`, e pelo mesmo motivo: o controller da sessão
// não pode importar `firebase_auth`, senão nenhum dos casos de troca de usuário
// e logout seria encenável sem SDK. O adaptador de verdade mora em
// `sessao_firebase.dart`.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO EXISTE, EM VEZ DE O TRANSPORTE PERGUNTAR AO FIREBASE
// ---------------------------------------------------------------------------
//
// A camada de transporte (`services/online_service.dart`) nasceu lendo
// `FirebaseAuth.instance.currentUser` por conta própria. Funcionava, e mesmo
// assim estava errado: passava a existir um SEGUNDO dono de autenticação no
// app, com um relógio próprio, sem nenhum vínculo com a geração de sessão que
// `SessaoDoJogador` mantém.
//
// A consequência não é teórica. Entre "pedir o token" e "usá-lo" existe um
// await; se um logout acontecer nesse intervalo, o token que volta é do jogador
// que ACABOU DE SAIR — e o transporte, que não conhece geração nenhuma, o
// apresentaria ao servidor com toda a confiança.
//
// Com esta porta, a credencial passa a sair pelo mesmo objeto que sabe quando a
// sessão virou, e a resposta atrasada morre onde nasceu.

/// De onde vem a credencial que prova quem está jogando.
///
/// Um método só, e de propósito: não há aqui `renovar`, `revogar` nem
/// `invalidar`. O ciclo de vida da credencial é do provedor de autenticação,
/// não do app — e um cliente com vocabulário para mexer nele acabaria mexendo.
abstract class FonteDeCredencial {
  /// A credencial atual de quem está autenticado, ou `null` quando não há.
  ///
  /// `null` é resposta legítima e significa exatamente "não há credencial".
  /// Não devolve string vazia, não devolve uid e não inventa substituto: quem
  /// consome trata `null` como "não dá para autenticar", que é a verdade.
  Future<String?> obterToken();
}

/// A fonte que não tem credencial nenhuma para dar.
///
/// É o padrão de [SessaoDoJogador] construída sem provedor — o caso dos testes
/// de identidade da Folha A, que encenam login e logout sem nunca falar de
/// token. Devolver `null` deixa o transporte em "não autenticado", que é a
/// leitura correta de uma sessão que não sabe emitir credencial.
class SemCredencial implements FonteDeCredencial {
  const SemCredencial();

  @override
  Future<String?> obterToken() async => null;
}
