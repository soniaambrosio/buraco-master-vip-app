// fonte_exclusao.dart — a PORTA por onde a exclusão de conta entra no app.
//
// Duas operações, e a assinatura das duas é a decisão de segurança mais
// importante deste módulo:
//
//     NENHUMA DELAS RECEBE UM UID.
//
// Não é esquecimento nem simplificação. É a mesma disciplina de
// `FonteDeIdentidade`, e pelo mesmo motivo: o cliente não tem vocabulário para
// nomear outra conta, então nenhuma tela pode pedir a exclusão da conta de
// outra pessoa nem por engano. O servidor tira o UID do contexto autenticado, e
// recusa o pedido que traga alvo no payload — ver `camposDeAlvoNoPayload` em
// functions-conta/src/plano.ts.
//
// O adaptador real mora em `fonte_exclusao_firebase.dart` e é o ÚNICO arquivo
// do módulo que conhece `cloud_functions`. A separação não é gosto: `app/test/
// sessao/auditoria_identidade_test.dart` varre `lib/screens/` e `lib/pages/` e
// FALHA se encontrar `httpsCallable` ou `cloud_functions` lá. A porta é o que
// permite a tela existir sem violar essa auditoria — e o que torna os casos da
// OS (reautenticação vencida, falha parcial, chamada duplicada) encenáveis sem
// emulador.

import 'exclusao_de_conta.dart';

abstract class FonteDeExclusaoDeConta {
  /// O que acontece se eu excluir minha conta?
  ///
  /// SÓ LÊ. Alimenta a tela de aviso com a matriz de retenção do servidor, para
  /// que o texto exibido não seja uma lista escrita à mão que envelhece sem
  /// ninguém ver.
  ///
  /// Lança [FalhaExclusao] — e apenas ela — quando não consegue.
  Future<ResumoDaExclusao> resumir();

  /// Executa a exclusão da conta autenticada.
  ///
  /// [confirmacao] é a palavra que o jogador digitou. Vai para o servidor porque
  /// é lá que ela é conferida: o que só a tela confere, um aplicativo modificado
  /// não confere.
  ///
  /// Lança [FalhaExclusao]. O caso que o chamador PRECISA tratar é
  /// [MotivoFalhaExclusao.reautenticacaoNecessaria] — é o único que se resolve
  /// pedindo a credencial de novo e repetindo.
  Future<ResultadoDaExclusao> excluir({required String confirmacao});
}
