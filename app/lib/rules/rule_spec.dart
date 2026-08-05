// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// RuleSpec: as decisões canônicas congeladas viram DADOS (não `if` espalhados),
// versionadas por modalidade.
import 'modalidade.dart';

/// Ajuste obrigatório 1 — faixas EXATAS de vulnerabilidade (+75/+90).
/// Nada de descrição genérica nem `metaPontos/2` solto: os valores são
/// explícitos e a regra de degrau (0 / 75 / 90) é replicada aqui.
class FaixaVulnerabilidade {
  /// Placar ACUMULADO da PARTIDA a partir do qual a dupla fica vulnerável.
  /// Canônico: metaPontos ~/ 2  (750 na meta 1500; 1500 na meta 3000).
  final int limiarAcumulado;

  /// Mínimo quando NÃO vulnerável, ou quando a dupla já abriu nesta rodada.
  final int minimoLivre;

  /// Mínimo na 1ª rodada vulnerável.
  final int minimoPrimeiraRodada;

  /// Mínimo da 2ª rodada vulnerável consecutiva em diante (teto).
  final int minimoRodadasSeguintes;

  const FaixaVulnerabilidade({
    required this.limiarAcumulado,
    this.minimoLivre = 0,
    this.minimoPrimeiraRodada = 75,
    this.minimoRodadasSeguintes = 90,
  });

  /// Mínimo exato para a 1ª baixada da rodada, replicando a regra canônica
  /// congelada (idêntico a Jogo.minimoParaDescer do motor antigo).
  ///
  /// [rodadasVulneravel]: 0 = não vulnerável; 1 = 1ª rodada vulnerável;
  ///                      >= 2 = rodadas vulneráveis seguintes (teto 90).
  /// [jaAbriuNaRodada]: a dupla já fez a 1ª baixada nesta rodada.
  int minimoParaDescer({
    required int rodadasVulneravel,
    required bool jaAbriuNaRodada,
  }) {
    if (jaAbriuNaRodada) return minimoLivre;
    if (rodadasVulneravel <= 0) return minimoLivre;
    return rodadasVulneravel == 1
        ? minimoPrimeiraRodada
        : minimoRodadasSeguintes;
  }
}

/// Especificação canônica de regras, versionada e por modalidade.
class RuleSpec {
  /// Carimbo de versão da spec (entra no replay determinístico — ajuste 8).
  static const String versaoCanonica = 'bmv-regras-2026.08';

  final String versao;
  final Modalidade modalidade;
  final int metaPontos;
  final FaixaVulnerabilidade vulnerabilidade;

  // ----- decisões congeladas (dados, não condicionais espalhados) -----
  /// Trinca existe nesta modalidade? (decisão: trinca só no Fechado.)
  final bool trincaPermitida;

  /// Trinca aceita curinga? Joker e 2 NÃO entram como curinga em trinca.
  final bool trincaAceitaCuringa;

  /// Máximo de curingas por SEQUÊNCIA.
  final int maxCuringasPorSequencia;

  /// Exige uso do topo do lixo para comprá-lo (Aberto = livre).
  final bool exigeUsoDoTopoNoLixo;

  /// Vários jogos podem compor uma única abertura (atômica).
  final bool aberturaMultiplaAtomica;

  const RuleSpec({
    required this.versao,
    required this.modalidade,
    required this.metaPontos,
    required this.vulnerabilidade,
    required this.trincaPermitida,
    required this.trincaAceitaCuringa,
    required this.maxCuringasPorSequencia,
    required this.exigeUsoDoTopoNoLixo,
    required this.aberturaMultiplaAtomica,
  });

  /// Spec canônica atual (decisões congeladas pela Sônia).
  factory RuleSpec.canonica(Modalidade mod, {int metaPontos = 1500}) {
    final fechado = mod == Modalidade.fechado;
    return RuleSpec(
      versao: versaoCanonica,
      modalidade: mod,
      metaPontos: metaPontos,
      vulnerabilidade:
          FaixaVulnerabilidade(limiarAcumulado: metaPontos ~/ 2),
      trincaPermitida: fechado, // trinca só no Fechado
      trincaAceitaCuringa: false, // Joker e 2 fora da trinca
      maxCuringasPorSequencia: 1,
      exigeUsoDoTopoNoLixo: mod != Modalidade.aberto,
      aberturaMultiplaAtomica: true,
    );
  }
}
