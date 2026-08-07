// champion.dart — conclusao da edicao, campeao e premiacao
// (OS 02 secoes 12 e 13).
//
// Camada pura: sem Firestore, sem UI e sem relogio.
//
// REUSO, NAO REIMPLEMENTACAO: a concessao de recompensa ja existe e esta testada
// em reward_grants.dart. Este arquivo NAO recalcula validade, NAO reimplementa
// chave de idempotencia e NAO decide expiracao — ele apenas traduz "classificacao
// final" em chamadas a `concederRecompensa`. OS 02 secao 1: nao criar uma segunda
// implementacao de algo ja funcional.
//
// IDEMPOTENCIA EM DOIS NIVEIS:
//   1. a EDICAO conclui uma unica vez  -> [ConclusaoEdicao.chaveIdempotencia]
//   2. cada PREMIO sai uma unica vez   -> chave ja existente em reward_grants.dart
// Os dois niveis sao necessarios: sem o primeiro, reprocessar a conclusao criaria
// um segundo campeao; sem o segundo, um reenvio parcial premiaria de novo quem ja
// tinha recebido.

import 'assets_registry.dart';
import 'participants.dart';
import 'reward_grants.dart';
import 'reward_policies.dart';
import 'standings.dart';
import 'tournament_model.dart';

/// Por que a conclusao foi recusada.
enum RecusaConclusao {
  /// A edicao ja tem conclusao registrada. OS 02 secao 12: "impedir dois campeoes
  /// para a mesma edicao".
  jaConcluida('ja_concluida'),

  /// Nao ha classificacao: ninguem jogou.
  semClassificacao('sem_classificacao'),

  /// O primeiro e o segundo empataram em todos os criterios esportivos. Apontar
  /// campeao por ordem alfabetica seria decidir o titulo pelo nome do jogador.
  empateNoTopo('empate_no_topo'),

  /// A edicao nao esta em estado de ser concluida.
  edicaoNaoEncerravel('edicao_nao_encerravel');

  final String wire;
  const RecusaConclusao(this.wire);
}

/// Registro de conclusao de uma edicao. Uma por edicao, para sempre.
class ConclusaoEdicao {
  final String tournamentId;
  final String editionId;

  /// Participante campeao. Em torneio de dupla e o id da dupla.
  final String campeaoId;

  /// Membros do campeao. Um em individual, dois em dupla — OS 02 secao 12 pede
  /// "registrar dupla campea, quando aplicavel".
  final List<String> campeoes;

  /// Vice, quando houve ao menos dois participantes.
  final String? viceId;

  /// Terceiro colocado, quando houve.
  final String? terceiroId;

  /// Classificacao final congelada, na ordem de colocacao.
  final List<String> classificacaoFinal;

  final int totalParticipantes;

  /// Instante da conclusao, em UTC.
  final DateTime concluidaEm;

  ConclusaoEdicao({
    required this.tournamentId,
    required this.editionId,
    required this.campeaoId,
    required this.campeoes,
    this.viceId,
    this.terceiroId,
    required this.classificacaoFinal,
    required this.totalParticipantes,
    required DateTime concluidaEm,
  }) : concluidaEm = concluidaEm.toUtc();

  /// `tournamentId + editionId`. Sem `userId`: a chave e da EDICAO, e e
  /// justamente isso que impede dois campeoes na mesma edicao.
  String get chaveIdempotencia => '$tournamentId|$editionId';

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'editionId': editionId,
        'campeaoId': campeaoId,
        'campeoes': campeoes,
        'viceId': viceId,
        'terceiroId': terceiroId,
        'classificacaoFinal': classificacaoFinal,
        'totalParticipantes': totalParticipantes,
        'concluidaEm': concluidaEm.toIso8601String(),
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'ConclusaoEdicao($chaveIdempotencia campeao=$campeaoId)';
}

/// Veredito de [concluirEdicao].
class ResultadoConclusao {
  final ConclusaoEdicao? conclusao;
  final RecusaConclusao? recusa;

  const ResultadoConclusao._(this.conclusao, this.recusa);

  const ResultadoConclusao.concluida(ConclusaoEdicao conclusao)
      : this._(conclusao, null);

  const ResultadoConclusao.recusada(RecusaConclusao recusa) : this._(null, recusa);

  bool get concluida => conclusao != null;

  /// A recusa e benigna: a conclusao ja tinha acontecido.
  bool get idempotente => recusa == RecusaConclusao.jaConcluida;

  @override
  String toString() => concluida
      ? 'ResultadoConclusao.concluida(${conclusao!.chaveIdempotencia})'
      : 'ResultadoConclusao.recusada(${recusa!.wire})';
}

/// Conclui a edicao a partir da classificacao final (OS 02 secao 12).
///
/// Funcao pura e idempotente: [conclusoes] entra por parametro, e reprocessar
/// devolve `jaConcluida` em vez de um segundo campeao.
ResultadoConclusao concluirEdicao({
  required String tournamentId,
  required String editionId,
  required List<LinhaClassificacao> classificacaoFinal,
  required DateTime agora,
  required bool edicaoEncerravel,
  Iterable<String> conclusoes = const <String>[],
}) {
  final chave = '$tournamentId|$editionId';
  // Idempotencia primeiro: um reprocessamento nao pode nem chegar a reavaliar o
  // empate no topo, senao um resultado ja homologado seria reaberto.
  if (conclusoes.contains(chave)) {
    return const ResultadoConclusao.recusada(RecusaConclusao.jaConcluida);
  }
  if (!edicaoEncerravel) {
    return const ResultadoConclusao.recusada(RecusaConclusao.edicaoNaoEncerravel);
  }
  if (classificacaoFinal.isEmpty) {
    return const ResultadoConclusao.recusada(RecusaConclusao.semClassificacao);
  }
  // Empate no topo nao resolvido pelos criterios esportivos: o campeao sairia do
  // desempate administrativo, que e alfabetico. OS 02 secao 11 manda registrar a
  // pendencia, nao arbitrar.
  if (classificacaoFinal.length > 1 && classificacaoFinal[1].empateNaoResolvido) {
    return const ResultadoConclusao.recusada(RecusaConclusao.empateNoTopo);
  }

  final campeao = classificacaoFinal.first;
  final ordenados =
      classificacaoFinal.map((l) => l.participanteId).toList(growable: false);

  return ResultadoConclusao.concluida(ConclusaoEdicao(
    tournamentId: tournamentId,
    editionId: editionId,
    campeaoId: campeao.participanteId,
    campeoes: Participante.deId(campeao.participanteId).membros,
    viceId: ordenados.length > 1 ? ordenados[1] : null,
    terceiroId: ordenados.length > 2 ? ordenados[2] : null,
    classificacaoFinal: ordenados,
    totalParticipantes: ordenados.length,
    concluidaEm: agora,
  ));
}

/// Uma concessao pendente de gravacao, com o motivo por tras dela.
class PremiacaoPlanejada {
  final ResultadoConcessao resultado;

  /// Jogador contemplado. Em dupla, cada membro recebe a propria concessao.
  final String userId;

  final int colocacao;

  /// Fichas da faixa, quando houver. Concedidas pela camada de carteira, nao por
  /// reward_grants.dart — fichas sao moeda, nao ativo de catalogo.
  final int? fichas;

  const PremiacaoPlanejada({
    required this.resultado,
    required this.userId,
    required this.colocacao,
    this.fichas,
  });

  @override
  String toString() =>
      'PremiacaoPlanejada($userId #$colocacao ${resultado.toString()})';
}

/// Traduz a classificacao final nas concessoes previstas pelo template
/// (OS 02 secao 13).
///
/// Cada MEMBRO recebe a propria concessao, mesmo em torneio de dupla: a coroa e
/// do jogador, e o perfil de cada um precisa mostrar o proprio titulo. A chave de
/// idempotencia ja carrega o `userId`, entao as duas concessoes da dupla nunca
/// colidem entre si.
///
/// Funcao pura: nada e gravado, e o [historico] entra por parametro. Concessoes
/// recusadas (arte pendente, politica indefinida, duplicidade) voltam na lista
/// com o motivo — a camada chamadora decide se registra a pendencia ou ignora,
/// mas nunca fica sem saber.
List<PremiacaoPlanejada> planejarPremiacao({
  required ConclusaoEdicao conclusao,
  required TorneioTemplate template,
  required TorneioAssetsRegistry assets,
  required RewardPoliciesRegistry politicas,
  required DateTime agora,
  DateTime? proximaEdicaoEm,
  Iterable<RecompensaConcessao> historico = const <RecompensaConcessao>[],
}) {
  final planejadas = <PremiacaoPlanejada>[];
  // Copia mutavel do historico: sem ela, duas faixas que concedessem o mesmo
  // ativo ao mesmo jogador passariam as duas — a duplicidade so apareceria na
  // hora de gravar, quando ja seria tarde.
  final acumulado = List<RecompensaConcessao>.of(historico);

  for (var i = 0; i < conclusao.classificacaoFinal.length; i++) {
    final colocacao = i + 1;
    final faixa = template.faixaPara(colocacao);
    if (faixa == null) continue;

    final participante = Participante.deId(conclusao.classificacaoFinal[i]);

    for (final userId in participante.membros) {
      if (faixa.assetId == null) {
        // Faixa so de fichas: nao ha ativo de catalogo a conceder.
        planejadas.add(PremiacaoPlanejada(
          resultado: const ResultadoConcessao.recusada(RecusaConcessao.assetInexistente),
          userId: userId,
          colocacao: colocacao,
          fichas: faixa.fichas,
        ));
        continue;
      }

      final resultado = concederRecompensa(
        // O rewardId identifica a LINHA; a chave de idempotencia identifica o
        // DIREITO. Derivar o rewardId da mesma tupla mantem o registro
        // reproduzivel sem sortear id.
        rewardId: 'grant-${conclusao.tournamentId}-${conclusao.editionId}-$userId-${faixa.assetId}',
        userId: userId,
        tournamentId: conclusao.tournamentId,
        editionId: conclusao.editionId,
        assetId: faixa.assetId!,
        grantedAt: agora,
        motivo: MotivoConcessao.colocacao,
        colocacao: colocacao,
        assets: assets,
        politicas: politicas,
        proximaEdicaoEm: proximaEdicaoEm,
        historico: acumulado,
      );
      if (resultado.concedida) acumulado.add(resultado.concessao!);

      planejadas.add(PremiacaoPlanejada(
        resultado: resultado,
        userId: userId,
        colocacao: colocacao,
        fichas: faixa.fichas,
      ));
    }
  }

  return planejadas;
}
