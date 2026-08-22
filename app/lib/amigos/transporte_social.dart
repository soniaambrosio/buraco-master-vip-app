// transporte_social.dart — a PORTA por onde o grafo social entra no aplicativo.
//
// Interface pura, sem Flutter e sem Firebase, pelo mesmo motivo de
// `sessao/fonte_identidade.dart`: os casos que a tela precisa tratar — busca
// truncada, resposta vencida, ação recusada por bloqueio, repetição idempotente
// — não são encenáveis contra uma Cloud Function de verdade.
//
// O adaptador real mora em `transporte_social_firebase.dart` e é o ÚNICO
// arquivo deste módulo que conhece `cloud_functions`.
//
// ---------------------------------------------------------------------------
// O QUE ESTA PORTA NÃO TEM, E A AUSÊNCIA É O CONTRATO
// ---------------------------------------------------------------------------
//
// Não há `listarTodos`, não há `carregarGrafo`, não há `sincronizar`. As três
// seriam maneiras de o cliente montar uma cópia do grafo social, e a cópia
// diverge do original no primeiro pedido aceito noutro aparelho.
//
// Não há `garantirIdentidade` nem nada que CRIE identidade: a única entrada de
// identidade continua sendo `social:obterMinhaIdentidade`, em
// `sessao/fonte_identidade.dart`. Este módulo lê identidade de TERCEIROS e
// opera relações; ele não cunha nada.
//
// E não há um método que aceite `uid`. O vocabulário inteiro é `publicId`,
// porque é o único identificador que atravessa a fronteira pública — o backend
// resolve `publicId -> uid` do lado dele, e `publicIdIndex` é negado a todo
// cliente justamente para que esse caminho de volta não exista aqui.

import 'estado_social.dart';

/// De onde a descoberta social e o grafo de amizade vêm.
///
/// Todos os métodos lançam [FalhaSocial] — e apenas ela — quando não conseguem.
abstract class TransporteSocial {
  /// Procura jogadores pelo apelido público.
  ///
  /// [termo] vai CRU, como a pessoa digitou. Normalizar aqui (dobrar acento,
  /// baixar caixa) seria uma segunda implementação da `chaveDeBusca` do
  /// servidor, e a busca deixaria de encontrar exatamente aquilo que a gravação
  /// indexou no dia em que as duas divergissem.
  ///
  /// [modo] é `'prefixo'` ou `'exato'`. Nulo deixa o servidor escolher o padrão.
  Future<ResultadosDeBusca> buscarPorApelido(
    String termo, {
    String? modo,
    int? limite,
  });

  /// A apresentação pública de um jogador MAIS a vista da relação com ele.
  ///
  /// É a autoridade sobre "que botões esta tela pode desenhar". Chamada depois
  /// de cada ação bem-sucedida, porque o desfecho da ação devolve o estado do
  /// BANCO, e o estado do banco não conhece bloqueio nem sanção.
  Future<ResultadoSocial> verPerfilPublico(String publicId);

  /// A lista de amigos, paginada e ordenada por apelido.
  Future<PaginaSocial> listarAmigos({String? cursor, int? limite});

  /// As solicitações pendentes RECEBIDAS, mais recentes primeiro.
  Future<PaginaSocial> listarSolicitacoesRecebidas({
    String? cursor,
    int? limite,
  });

  /// As solicitações pendentes ENVIADAS, mais recentes primeiro.
  Future<PaginaSocial> listarSolicitacoesEnviadas({
    String? cursor,
    int? limite,
  });

  /// Executa uma ação sobre a relação com [publicId].
  ///
  /// UM MÉTODO PARA AS CINCO OPERAÇÕES, e não cinco métodos. O motivo é que a
  /// tela nunca escolhe a operação: ela desenha os botões que
  /// [ResultadoSocial.acoes] trouxe e devolve o que foi tocado. Com cinco
  /// métodos haveria um `switch` na tela mapeando ação em chamada — e esse
  /// `switch` é exatamente o lugar onde alguém escreveria "aceitar" para um
  /// botão que o servidor rotulou "cancelar".
  ///
  /// [AcaoSocial.bloquear], [AcaoSocial.desbloquear] e [AcaoSocial.editarPerfil]
  /// NÃO passam por aqui: as duas primeiras são do domínio de MODERAÇÃO (fonte
  /// canônica `users/{uid}/blocks`, e o social apenas REAGE a ela por gatilho),
  /// e a terceira é do próprio perfil. Pedi-las a este transporte lança
  /// [ArgumentError] — falha de programação, não de rede.
  Future<DesfechoSocial> agir(AcaoSocial acao, String publicId);
}

/// As ações que [TransporteSocial.agir] sabe executar.
///
/// PÚBLICA E CONSTANTE de propósito: a tela usa esta lista para decidir quais
/// botões ela consegue ATENDER, e um teste a confere contra o vocabulário do
/// enum sem precisar encenar um toque.
const Set<AcaoSocial> kAcoesDeAmizade = {
  AcaoSocial.adicionarAmigo,
  AcaoSocial.cancelarSolicitacao,
  AcaoSocial.aceitarSolicitacao,
  AcaoSocial.recusarSolicitacao,
  AcaoSocial.removerAmigo,
};
