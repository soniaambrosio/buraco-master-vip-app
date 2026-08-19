// sessao.dart — a PORTA de identidade do jogador.
//
// POR QUE O CLIENTE PRECISA SABER SE HA SESSAO, SE QUEM MANDA E O SERVIDOR
//
// A titularidade da compra e decidida no backend, por `request.auth.uid`, e o
// app nao envia uid nenhum — isso nao muda. O portao daqui resolve outro
// problema, e ele e de DINHEIRO, nao de seguranca:
//
// Sem sessao, `validarCompraPlay` responde `unauthenticated`. Se o cliente
// tratasse isso como veredito, finalizaria a compra na Play Store e o jogador
// que acabou de pagar ficaria sem nada, sem reentrega e sem recurso automatico.
//
// Conferir a sessao ANTES da chamada transforma esse caso num adiamento
// explicito e barato: a compra permanece pendente na Play Store e volta pelo
// `purchaseStream` na proxima abertura, quando houver login. Ver
// `servico_billing.dart` e o teste BILLING-FLUTTER-12.
//
// A porta tambem mantem `firebase_auth` fora do servico, pelo mesmo motivo que
// `loja_play.dart` mantem o plugin da Play fora: `FirebaseAuth.instance` exige
// app inicializado e nao existe em `flutter test`.
library;


/// Quem esta logado agora.
abstract class SessaoJogador {
  /// O uid do Firebase Auth, ou `null` se nao ha sessao.
  ///
  /// Nao e enviado ao backend e nao serve de autoridade: serve para o cliente
  /// saber se vale a pena gastar a chamada. A identidade que conta e a que o
  /// callable extrai do token verificado.
  String? get uid;
}

/// LÁPIDE — `SessaoFirebase` foi REMOVIDA na composição canônica.
///
/// Ela lia `FirebaseAuth.instance.currentUser?.uid` daqui, e era o SEGUNDO dono
/// de autenticação do aplicativo: a auditoria da casca de produção (`não existe
/// segundo dono de autenticação`) a apontava nominalmente. Só a camada de sessão
/// fala com `firebase_auth`.
///
/// Quem monta o billing passa o uid da sessão CANÔNICA — em produção,
/// `EscopoSessao.identidadeDe(context).uid` — através de [SessaoFixa]. Não há
/// mais valor padrão: o serviço exige a porta, e exigir é o que impede alguém de
/// reabrir o atalho sem perceber.

/// Sessao fixa, para teste e para composicao.
class SessaoFixa implements SessaoJogador {
  const SessaoFixa(this.uid);

  @override
  final String? uid;
}
