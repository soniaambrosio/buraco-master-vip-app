// C9-B — ADAPTADOR CANÔNICO da porta do motor. SÓ delega às funções canônicas
// já implementadas e testadas em `rules/gerador` — NÃO reimplementa regra,
// NÃO usa `dynamic`, NÃO importa `mesa.dart`. `ehVez` delega ao helper canônico
// `ehVezDe` (as duas travas globais), que o próprio `aplicarLegal` usa.
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/rule_spec.dart';
import '../rules/gerador/gerador.dart';
import 'porta_motor.dart';

class AdaptadorCanonico implements PortaMotor {
  const AdaptadorCanonico();

  @override
  bool ehVez(EstadoJogo estado, int assento) => ehVezDe(estado, assento);

  @override
  List<Acao> acoesLegais(EstadoJogo estado, int assento, RuleSpec spec,
          {List<Acao> candidatos = const []}) =>
      gerarAcoesLegais(estado, assento, spec, candidatos: candidatos);

  @override
  bool ehLegal(EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
      acaoEhLegal(estado, assento, acao, spec);

  @override
  ResultadoJogada aplicar(
          EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
      aplicarLegal(estado, assento, acao, spec);
}
