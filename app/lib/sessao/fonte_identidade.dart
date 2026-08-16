// fonte_identidade.dart — a PORTA por onde a identidade pública entra no app.
//
// Uma interface de um método só. O motivo de ela existir não é abstração por
// gosto: é que o controller da sessão (`sessao_do_jogador.dart`) precisa ser
// testável nos quinze casos da OS — resposta atrasada, troca de usuário, falha
// transitória, retry, deduplicação — e nenhum desses casos é encenável contra
// uma Cloud Function real.
//
// O adaptador de verdade mora em `fonte_identidade_firebase.dart` e é o ÚNICO
// arquivo do módulo que conhece `cloud_functions`.

import 'identidade_publica_sessao.dart';

/// De onde a identidade pública canônica vem.
///
/// Só existe UMA operação porque só existe UMA entrada: `obterMinhaIdentidade`.
/// Não há aqui `garantir...`, `criar...` nem `inicializar...` — a ausência é o
/// ponto. O cliente não tem vocabulário para criar identidade, então nenhuma
/// tela pode chamá-lo por engano.
abstract class FonteDeIdentidade {
  /// Obtém a identidade pública de quem está autenticado.
  ///
  /// A criação na primeira vez é responsabilidade e decisão do BACKEND
  /// (`obterMinhaIdentidade` é get-or-create e idempotente). Do lado do
  /// cliente isto é uma LEITURA: nada aqui decide que uma identidade deve
  /// nascer.
  ///
  /// Lança [FalhaIdentidade] — e apenas ela — quando não consegue.
  Future<IdentidadePublica> obterMinhaIdentidade();
}
