// C9-D — AUTORIDADE canônica atrás da flag (troca REAL de autoridade).
//
// Quando `MotorConfig.canonicoAtivo` está ligado, o caminho canônico DECIDE e
// aplica o estado real do jogo, como uma TRANSAÇÃO SEMÂNTICA E ATÔMICA:
//   (1) projeta o estado prévio (só leitura do `Jogo`);
//   (2) aplica/valida a sequência canônica sobre SNAPSHOTS imutáveis (+ estabiliza
//       as transições que o legado dobra: morto direto/indireto e batida);
//   (3) só então COMMITA o pós-estado ÍNTEGRO de volta no `Jogo`.
//
// Fronteira ATÔMICA: o `Jogo` NUNCA é mutado aos poucos enquanto o canônico
// decide. Todo o pós-estado nasce em snapshots; o `Jogo` só é tocado no COMMIT
// final (`aplicarEmJogo`), e apenas depois de uma PROVA de transporte num clone
// (garante que o commit real não pode falhar no meio). Em recusa ou falha antes
// do commit, o estado original permanece intacto.
//
// Recusa canônica é decisão de REGRA (autoridade ON) — NÃO há fallback legado.
// É PROIBIDO fallback semântico: nunca rodar o legado porque o canônico recusou,
// divergiu, encontrou EXC ou "ficaria mais compatível". A divergência aparece.
//
// Fallback é SOMENTE TÉCNICO: falha operacional clara de costura/projeção/
// transporte, ANTES de qualquer efeito canônico observável. Gera diagnóstico
// explícito (telemetria) e Replay quando possível. O roteamento nos métodos
// legados só cai no legado nesse caso técnico — nunca por recusa de regra.
//
// Quadrantes de legalidade: a legalidade é CAPTURADA explicitamente pelo
// desfecho (aplicou × recusaCanonica), nunca deduzida da igualdade de estado.
//
// C9-C2 é premissa FECHADA: reusa a mesma projeção/envelope (matriz do PLANO-C9)
// e a MESMA estabilização do modo sombra (morto direto/indireto, batida,
// conversão §8.1, exaustão). RuleSpec `bmv-regras-2026.08` inalterada.
import '../mesa.dart';
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/replay.dart';
import '../rules/rule_spec.dart';
import '../rules/gerador/gerador.dart';
import 'envelope_runtime.dart';
import 'modo_sombra.dart' show serializarProjecao;
import 'projecao_estado.dart';

/// Desfecho EXPLÍCITO de uma jogada com autoridade canônica (quadrante).
enum DesfechoAutoridade {
  /// Canônico aplicou; o pós-estado íntegro foi COMMITADO no `Jogo`.
  aplicou,

  /// Canônico recusou por REGRA. `Jogo` INTACTO. NUNCA aciona fallback legado.
  recusaCanonica,

  /// Falha TÉCNICA (costura/projeção/transporte) antes de efeito observável.
  /// `Jogo` INTACTO. Só ESTE desfecho permite o fallback técnico previsto.
  falhaTecnica,
}

/// Resultado da autoridade canônica sobre uma jogada.
class ResultadoAutoridade {
  final DesfechoAutoridade desfecho;
  final String? motivo;

  /// Mortos convertidos em monte (§8.1) durante a jogada (paridade de envelope).
  final int conversoes;

  /// Evidência da falha técnica: Replay completo `{canonico,envelope}` quando o
  /// pré-estado foi projetado, ou telemetria mínima quando nem isso foi possível
  /// (falha de projeção). Nulo fora do desfecho técnico.
  final Map<String, dynamic>? evidencia;

  const ResultadoAutoridade(
    this.desfecho, {
    this.motivo,
    this.conversoes = 0,
    this.evidencia,
  });

  bool get aplicou => desfecho == DesfechoAutoridade.aplicou;
  bool get recusaCanonica => desfecho == DesfechoAutoridade.recusaCanonica;
  bool get falhaTecnica => desfecho == DesfechoAutoridade.falhaTecnica;
}

/// Assinatura do projetor (injetável para testar a FALHA técnica de projeção;
/// produção usa `paraCanonico`). Tear-off de função top-level é constante.
typedef Projetor = ProjecaoBMV Function(Jogo);

class _RunCanonico {
  final bool recusou;
  final String? motivo;
  final EstadoJogo estado;
  final int conversoes;
  const _RunCanonico(this.recusou, this.motivo, this.estado, this.conversoes);
}

/// Aplica a sequência canônica sobre o snapshot imutável `pre` e ESTABILIZA as
/// transições compostas que o legado dobra numa só chamada. Espelha fielmente o
/// `_rodarCanonico` do modo sombra (C9-C2, premissa fechada) — mesma autoridade
/// (`aplicarLegal`), mesma estabilização (morto indireto → PegarMorto viaDescarte;
/// mão vazia baixando → morto DIRETO ou BATIDA), mesma contagem de conversão §8.1.
_RunCanonico _rodarEestabiliza(
    EstadoJogo pre, int assento, List<Acao> acoes, RuleSpec spec) {
  var cur = pre;
  var conversoes = 0;
  for (final a in acoes) {
    final vaiConverter =
        a is ComprarMonte && cur.monte.isEmpty && cur.mortos.isNotEmpty;
    final r = aplicarLegal(cur, assento, a, spec);
    if (!r.legal) return _RunCanonico(true, r.motivo, cur, conversoes);
    if (vaiConverter) conversoes++;
    cur = r.proximoEstado!;
  }
  var guarda = 0;
  while (guarda < 6 && !cur.rodadaEncerrada) {
    guarda++;
    if (cur.fase == FaseTurno.mortoPendente) {
      final r = aplicarLegal(
          cur, assento, const PegarMorto(viaDescarte: true), spec);
      if (!r.legal) break;
      cur = r.proximoEstado!;
      continue;
    }
    if (cur.fase == FaseTurno.jogo && cur.maos[assento].isEmpty) {
      final dupla = assento % 2 == 0 ? 'nos' : 'eles';
      final mortoDisp =
          !(cur.mortoPego[dupla] ?? false) && cur.mortos.isNotEmpty;
      final r = aplicarLegal(
          cur, assento, mortoDisp ? const PegarMorto() : const Bater(), spec);
      if (!r.legal) break;
      cur = r.proximoEstado!;
      continue;
    }
    break;
  }
  return _RunCanonico(false, null, cur, conversoes);
}

/// Envelope pós-jogada: preserva TODOS os campos (matriz do PLANO-C9); só
/// `mortosConvertidos` é atualizado pela conversão §8.1 efetivamente aplicada.
/// Não se inventa equivalência para campo que o canônico não modela — os campos
/// operacionais só mudam por seus próprios setters (que, sob autoridade ON,
/// também roteiam pelo canônico), então o pass-through mantém a paridade.
EnvelopeRuntime _envelopePos(EnvelopeRuntime pre, int conversoes) =>
    EnvelopeRuntime(
      cont: pre.cont,
      lixoUnicoCompradoId: pre.lixoUnicoCompradoId,
      mortosConvertidos: pre.mortosConvertidos + conversoes,
      iniciadorRodada: pre.iniciadorRodada,
      rodadaContada: pre.rodadaContada,
      lixoTopoObrigatorio: pre.lixoTopoObrigatorio,
      integridadeErro: pre.integridadeErro,
      assentoQueBateu: pre.assentoQueBateu,
      rodada: pre.rodada,
      placar: {...pre.placar},
      encerrada: pre.encerrada,
      pontosRodada: pre.pontosRodada,
      apelidos: pre.apelidos,
      avatares: pre.avatares,
      mascotes: pre.mascotes,
    );

/// Replay COMPLETO `{canonico,envelope}` da jogada (evidência de falha técnica
/// pós-projeção). Sem seed (produção não tem seed reproduzível) — reproduz-se
/// pelo snapshot completo, como no C9-C.
Map<String, dynamic> _replayAutoridade(
        ProjecaoBMV pre, List<Acao> acoes) =>
    Replay(
      versaoSpec: RuleSpec.versaoCanonica,
      modalidade: pre.canonico.modalidade,
      metaPontos: pre.canonico.metaPontos,
      acoes: acoes,
      estadoInicialSerializado: serializarProjecao(pre),
      faseInicial: pre.canonico.fase,
    ).toJson();

/// APLICA uma jogada canônica com AUTORIDADE sobre `alvo`, de forma atômica.
///
/// A `spec` é derivada da PRÓPRIA projeção (RuleSpec canônica congelada
/// `bmv-regras-2026.08`) — a autoridade não aceita spec injetada, para que a
/// regra seja fonte única. `projetar` é injetável APENAS para exercitar a falha
/// técnica de projeção nos testes (produção usa `paraCanonico`).
ResultadoAutoridade aplicarComAutoridade(
  Jogo alvo,
  int assento,
  List<Acao> acoes, {
  Projetor projetar = paraCanonico,
}) {
  // (1) PROJEÇÃO — só leitura do alvo. Falha aqui é TÉCNICA, antes de efeito.
  final ProjecaoBMV pre;
  try {
    pre = projetar(alvo);
  } catch (e) {
    return ResultadoAutoridade(
      DesfechoAutoridade.falhaTecnica,
      motivo: 'projeção falhou: $e',
      evidencia: {'falhaTecnica': 'projecao', 'erro': '$e'},
    );
  }

  final spec = RuleSpec.canonica(pre.canonico.modalidade,
      metaPontos: pre.canonico.metaPontos);

  // (2) APLICAÇÃO CANÔNICA sobre snapshots imutáveis + estabilização. A regra
  // canônica NÃO lança em recusa (retorna legal:false); uma EXCEÇÃO aqui é falha
  // TÉCNICA de adaptação — o alvo ainda está INTACTO (só snapshots tocados).
  final _RunCanonico run;
  try {
    run = _rodarEestabiliza(pre.canonico, assento, acoes, spec);
  } catch (e) {
    return ResultadoAutoridade(
      DesfechoAutoridade.falhaTecnica,
      motivo: 'aplicação canônica lançou: $e',
      evidencia: _replayAutoridade(pre, acoes),
    );
  }

  // (3) RECUSA CANÔNICA (decisão de REGRA) — alvo INTACTO, SEM fallback legado.
  if (run.recusou) {
    return ResultadoAutoridade(DesfechoAutoridade.recusaCanonica,
        motivo: run.motivo);
  }

  // (4) Envelope pós (paridade: mortosConvertidos += conversões §8.1).
  final envPos = _envelopePos(pre.envelope, run.conversoes);

  // (5) PROVA de transporte num CLONE descartável: se o commit lançasse, seria
  // falha técnica AQUI — com o alvo ainda intacto. Se a prova passa, o commit
  // real (dados idênticos) não pode falhar no meio -> atomicidade garantida.
  final prova = Jogo.paraCostura(
    apelidos: pre.envelope.apelidos,
    avatares: pre.envelope.avatares,
    mascotes: pre.envelope.mascotes,
  );
  try {
    aplicarEmJogo(prova, run.estado, envPos);
  } catch (e) {
    return ResultadoAutoridade(
      DesfechoAutoridade.falhaTecnica,
      motivo: 'transporte falhou (prova): $e',
      evidencia: _replayAutoridade(pre, acoes),
    );
  }

  // (6) COMMIT ÍNTEGRO (atômico): idêntico à prova -> não falha no meio.
  aplicarEmJogo(alvo, run.estado, envPos);
  return ResultadoAutoridade(DesfechoAutoridade.aplicou,
      conversoes: run.conversoes);
}
