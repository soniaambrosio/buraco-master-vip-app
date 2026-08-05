// C1 — andaime do RulesEngine canônico. SEM comportamento de produção.
//
// Fachada canônica. Em C1 é APENAS o contrato: as implementações chegam em
// C2..C6. O motor antigo (class Jogo em mesa.dart) continua PADRÃO e
// autoritativo até a virada atrás de flag (C9) e a aposentadoria (C10).
import 'acoes.dart';
import 'estado.dart';
import 'rule_spec.dart';

class RulesEngine {
  final RuleSpec spec;
  const RulesEngine(this.spec);

  /// LEGALIDADE — compartilhada por jogador E bot (ajuste 3).
  /// Puro: NÃO muta o estado. Diz se a ação é válida e, se for, a pontuação
  /// PARCIAL da rodada e se atingiu o mínimo.
  ResultadoAcao avaliar(EstadoJogo estado, Acao acao) {
    throw UnimplementedError('RulesEngine.avaliar: implementado em C2..C6');
  }

  /// APLICA tudo-ou-nada: só produz próximo estado se a ação for válida;
  /// em caso de falha o estado permanece idêntico (sem mutação parcial).
  ResultadoAcao aplicar(EstadoJogo estado, Acao acao) {
    throw UnimplementedError('RulesEngine.aplicar: implementado em C4');
  }
}

/// Ajuste 3 — LEGALIDADE separada da ENUMERAÇÃO.
/// O gerador COMPLETO de candidatos pode ser específico do bot; a legalidade
/// de cada candidato é SEMPRE decidida pelo RulesEngine (mesma autoridade para
/// jogador e bot). Assim a paridade é estrutural, não coincidência.
abstract interface class GeradorCandidatos {
  List<Acao> candidatos(EstadoJogo estado, RulesEngine engine);
}
