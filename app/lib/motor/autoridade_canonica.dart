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
import '../rules/abertura/abertura.dart';
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/meld/meld_validator.dart' show validarJogoMesa;
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

// C10 — limites EXPLÍCITOS da geração (sem "silent cap"): melds gerados têm até
// _kMeldMax cartas (canastra) e a abertura vulnerável é aumentada com até
// _kAugMax melds extra. Para as mãos reais (≤ ~14) isso cobre toda combinação
// jogável; se um dia truncar, é aqui — documentado, não escondido.
const int _kMeldMax = 7;
const int _kAugMax = 2;

/// Subconjuntos de índices [0..n) com tamanho em [lo, hi], em ordem canônica
/// (determinística, crescente por índice). Base da GERAÇÃO de candidatos.
List<List<int>> _subconjuntos(int n, int lo, int hi) {
  final out = <List<int>>[];
  void rec(int start, List<int> cur) {
    if (cur.length >= lo) out.add(List<int>.from(cur));
    if (cur.length >= hi) return;
    for (var i = start; i < n; i++) {
      cur.add(i);
      rec(i + 1, cur);
      cur.removeLast();
    }
  }

  rec(0, <int>[]);
  return out;
}

/// Assinatura semântica de uma compra (jogos + extensões), independente da ordem
/// das cartas e dos jogos — para DEDUPLICAR e ORDENAR de forma determinística.
String _sigCompra(List<List<CartaId>> jogos, List<Extensao> exts) {
  final js = [
    for (final j in jogos) (List<CartaId>.from(j)..sort()).join('-')
  ]..sort();
  final es = [
    for (final e in exts)
      '${e.indiceJogo}:${(List<CartaId>.from(e.cartas)..sort()).join('-')}'
  ]..sort();
  return 'J[${js.join('|')}]X[${es.join('|')}]';
}

/// C10 — DERIVAÇÃO de TODOS os candidatos ATÔMICOS de compra do lixo Fechado/STBL
/// construíveis EXCLUSIVAMENTE com o topo visível + a mão atual + os jogos já
/// expostos da dupla. Cartas ENTERRADAS ficam completamente fora (nem geração
/// nem autorização). Auto-derivar ≠ auto-decidir: o motor ENUMERA e VALIDA,
/// mas NÃO escolhe estrategicamente pelo jogador. Contrato do consumidor:
///   0 candidatos → recusa; 1 → executa; 2+ → o jogador escolhe.
/// Suporta jogo novo de tamanho variável, extensão com topo (+ cartas da mão),
/// múltiplos jogos/extensões numa compra atômica e a abertura vulnerável cujo
/// primeiro meld isolado fica abaixo do mínimo mas o CONJUNTO alcança +75/+90.
/// A legalidade da MESA vem do validador canônico congelado (`validarJogoMesa`)
/// só para GERAR candidatos; a legalidade da TRANSAÇÃO (topo usado, mínimo de
/// abertura, enterradas fora, sem reuso de carta) é decidida pela AUTORIDADE
/// canônica (`avaliarComprarLixo`) — nada de regra/tabela de pontos duplicado
/// aqui. Resultado determinístico, sem duplicatas semânticas e independente da
/// ordem em que as combinações foram encontradas.
List<ComprarLixo> derivarCandidatosCompraLixoFechado(
    EstadoJogo estado, int assento, RuleSpec spec) {
  if (estado.lixo.isEmpty) return const <ComprarLixo>[];
  final topo = estado.lixo.last;
  final topoId = topo.id;
  final dupla = assento % 2 == 0 ? 'nos' : 'eles';
  final melds = estado.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[];
  final mao = estado.maos[assento];

  final vistos = <String>{};
  final out = <ComprarLixo>[];
  void tentar(List<List<CartaId>> jogos, List<Extensao> exts) {
    // VERIFICADOR FINAL: só entra quem a AUTORIDADE canônica aceita.
    final r = avaliarComprarLixo(estado, assento, spec,
        topoDeclarado: topoId, jogosNovos: jogos, extensoes: exts);
    if (!r.valido) return;
    if (vistos.add(_sigCompra(jogos, exts))) {
      out.add(ComprarLixo(
          topoDeclarado: topoId, jogosNovos: jogos, extensoes: exts));
    }
  }

  // (1) MELDS NOVOS que CONTÊM o topo (só validade de meld; o mínimo é da
  //     transação). Tamanho variável: topo + 2.._kMeldMax-1 cartas da mão.
  final novosComTopo = <List<CartaId>>[];
  for (final s in _subconjuntos(mao.length, 2, _kMeldMax - 1)) {
    final cartas = <CartaSnapshot>[topo, for (final i in s) mao[i]];
    if (validarJogoMesa(cartas, spec).valido) {
      novosComTopo.add([topoId, for (final i in s) mao[i].id]);
    }
  }
  // (2) EXTENSÕES que CONTÊM o topo (topo + eventuais cartas da mão), por meld
  //     já exposto da dupla.
  final extsComTopo = <Extensao>[];
  for (var k = 0; k < melds.length; k++) {
    final alvo = melds[k];
    for (final s in _subconjuntos(mao.length, 0, _kMeldMax)) {
      final add = <CartaSnapshot>[topo, for (final i in s) mao[i]];
      if (validarJogoMesa([...alvo, ...add], spec).valido) {
        extsComTopo.add(Extensao(k, [topoId, for (final i in s) mao[i].id]));
      }
    }
  }
  // (3) MELDS EXTRA (SEM o topo), da mão — para AUMENTAR a abertura vulnerável
  //     até o conjunto atômico alcançar o mínimo.
  final extras = <List<CartaId>>[];
  for (final s in _subconjuntos(mao.length, 3, _kMeldMax)) {
    final cartas = <CartaSnapshot>[for (final i in s) mao[i]];
    if (validarJogoMesa(cartas, spec).valido) {
      extras.add([for (final i in s) mao[i].id]);
    }
  }
  final combosExtra = <List<List<CartaId>>>[
    for (final combo in _subconjuntos(extras.length, 1, _kAugMax))
      [for (final i in combo) extras[i]]
  ];

  // BASE: cada uso do topo sozinho (o verificador rejeita se abaixo do mínimo).
  for (final m in novosComTopo) {
    tentar([m], const []);
  }
  for (final e in extsComTopo) {
    tentar(const [], [e]);
  }
  // AUMENTO: uso do topo + 1.._kAugMax melds extra (o verificador rejeita reuso
  // de carta e conjuntos abaixo do mínimo).
  for (final m in novosComTopo) {
    for (final ce in combosExtra) {
      tentar([m, ...ce], const []);
    }
  }
  for (final e in extsComTopo) {
    for (final ce in combosExtra) {
      tentar([...ce], [e]);
    }
  }

  out.sort((a, b) => _sigCompra(a.jogosNovos, a.extensoes)
      .compareTo(_sigCompra(b.jogosNovos, b.extensoes)));
  return out;
}

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
