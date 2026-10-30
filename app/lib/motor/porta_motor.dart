// C9-A — CONTRATO (interface tipada) da porta do motor de regras.
//
// APENAS a interface: nenhuma implementação concreta, nenhum mapeamento
// Jogo <-> EstadoJogo (isso é C9-B), nenhuma dependência de `mesa.dart`.
// Espelha 1:1 a superfície canônica JÁ implementada em `rules/gerador`
// (ehVezDe / gerarAcoesLegais / acaoEhLegal / aplicarLegal), para que os
// adaptadores concretos do C9-B DELEGUEM sem reimplementar regra e sem tocar
// em métodos não implementados. Tipada em termos canônicos; sem `dynamic`.
import '../rules/estado.dart';
import '../rules/acoes.dart';
import '../rules/rule_spec.dart';
import '../rules/gerador/gerador.dart' show ResultadoJogada;

/// Porta ÚNICA pela qual o runtime consultará/aplicará regra (a partir do
/// C9-B/C9-D). Em C9-A é só o contrato — não há implementação concreta aqui.
abstract interface class PortaMotor {
  /// As DUAS travas globais juntas (é a vez do assento E a rodada segue aberta).
  bool ehVez(EstadoJogo estado, int assento);

  /// Ações legais do `assento` neste `estado` (gerador único). `candidatos`
  /// permite propor baixadas/extensões (jogador ou bot), filtradas pela MESMA
  /// legalidade.
  List<Acao> acoesLegais(EstadoJogo estado, int assento, RuleSpec spec,
      {List<Acao> candidatos});

  /// Legalidade PURA de uma ação — a mesma autoridade de jogador e bot.
  bool ehLegal(EstadoJogo estado, int assento, Acao acao, RuleSpec spec);

  /// Aplica a ação de forma ATÔMICA; nunca muta o estado recebido (em recusa,
  /// `proximoEstado` é null; em sucesso, é um novo estado).
  ResultadoJogada aplicar(
      EstadoJogo estado, int assento, Acao acao, RuleSpec spec);
}
