// ranking_service.dart — a única fronteira por onde a tela de Ranking recebe
// dado. Quem implementa esta interface é quem tem autoridade; a tela consome.
//
// Situação hoje (ver docs/MAPA-INTEGRACAO-RANKING-LIGAS-HALL.md, seção G):
// nenhuma fonte oficial de Ranking existe ao alcance do app. Não há
// `cloud_firestore` nas dependências do CI e o servidor Node de partidas não
// publica ranking. Por isso a implementação embarcada é [RankingSemFonte], que
// declara a ausência em vez de inventar número — a OS proíbe dado fictício no
// caminho de produção e proíbe regra provisória no cliente.
//
// Ligar a fonte real, quando ela existir, é trocar a implementação injetada em
// `RankingPage(service: ...)`. Nada da tela muda.

import '../ranking/ranking_contract.dart';

abstract class RankingService {
  const RankingService();

  /// Abre um escopo: cabeçalho (divisão, pódio, escada de ligas) e a primeira
  /// página da lista, numa ida só.
  ///
  /// Lança [RankingIndisponivel] quando a fonte não responde.
  Future<RankingAbertura> abrir(RankingEscopo escopo);

  /// Página seguinte do mesmo escopo, a partir do cursor devolvido pela
  /// anterior.
  ///
  /// Lança [RankingIndisponivel] quando a fonte não responde.
  Future<RankingPagina> proximaPagina(RankingEscopo escopo, String cursor);
}

/// Implementação de produção **enquanto não houver fonte oficial**.
///
/// Não é um mock: não devolve jogador nenhum, não devolve lista vazia (que a
/// tela leria como “ranking sem ninguém”) e não guarda estado. Ela diz a
/// verdade — o ranking ainda não é publicado por ninguém com autoridade — e a
/// tela mostra o estado de indisponível, com botão de tentar de novo.
class RankingSemFonte extends RankingService {
  const RankingSemFonte();

  static const String motivo =
      'O ranking oficial ainda não está sendo publicado.';

  @override
  Future<RankingAbertura> abrir(RankingEscopo escopo) =>
      Future<RankingAbertura>.error(const RankingIndisponivel(motivo));

  @override
  Future<RankingPagina> proximaPagina(RankingEscopo escopo, String cursor) =>
      Future<RankingPagina>.error(const RankingIndisponivel(motivo));
}
