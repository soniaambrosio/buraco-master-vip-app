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

  /// reasonCode ESTÁVEL da recusa de REGRA, quando a regra define um (hoje só
  /// `reasonCodeSemConclusaoLegal`). Observabilidade: permite distinguir por
  /// máquina a recusa "o turno ficaria sem conclusão legal" de uma recusa
  /// genérica, sem depender do texto do motivo. Nulo nos demais desfechos.
  final String? codigo;

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
    this.codigo,
  });

  bool get aplicou => desfecho == DesfechoAutoridade.aplicou;
  bool get recusaCanonica => desfecho == DesfechoAutoridade.recusaCanonica;
  bool get falhaTecnica => desfecho == DesfechoAutoridade.falhaTecnica;
}

/// Assinatura do projetor (injetável para testar a FALHA técnica de projeção;
/// produção usa `paraCanonico`). Tear-off de função top-level é constante.
typedef Projetor = ProjecaoBMV Function(Jogo);

// C10 — SEM caps semânticos artificiais E SEM materializar 2^n. Os ÚNICOS
// limites são os RECURSOS visíveis reais (topo + mão + jogos expostos) e as
// restrições da própria regra canônica. A geração é LAZY (DFS streaming):
// produz-e-valida cada candidato durante a travessia, com PODA ESTRUTURAL
// precoce (um meld só pode ser mesmo-naipe (sequência) OU mesmo-valor (trinca),
// e no máx. 1 JOKER), e disjunção incremental por carta/índice. Nada é
// enumerado numa lista completa antes de trabalhar. Nada de tabela de pontos ou
// legalidade duplicada: a poda só descarta o que a regra NUNCA aceitaria; o
// validador canônico (`validarJogoMesa`/`avaliarComprarLixo`) é a autoridade
// final. Resultado idêntico (mesmo conjunto legal), determinístico, deduplicado.

/// Diagnóstico estrutural da derivação (evidência de que NÃO houve enumeração
/// materializada de 2^n): nós de DFS de meld/combinação visitados e nº de
/// transações validadas. Sem tetos; só instrumentação.
class DiagnosticoLixo {
  int nosMeld = 0; // nós do DFS de geração de meld/extensão
  int nosCombo = 0; // nós do DFS de combinação atômica
  int transacoesValidadas = 0; // chamadas a avaliarComprarLixo
}

/// Uma UNIDADE de baixada dentro da compra: um jogo novo OU uma extensão de um
/// jogo já exposto (índice `indiceExt`). `ids` = cartas visíveis que ela consome.
class _UnidadeCompra {
  final List<CartaId>? jogoNovo;
  final Extensao? extensao;
  final int? indiceExt;
  final Set<CartaId> ids;
  const _UnidadeCompra.jogo(List<CartaId> j, this.ids)
      : jogoNovo = j,
        extensao = null,
        indiceExt = null;
  _UnidadeCompra.ext(Extensao e, this.ids)
      : jogoNovo = null,
        extensao = e,
        indiceExt = e.indiceJogo;
}

/// Assinatura semântica de uma compra — independente da ordem — p/ deduplicar e
/// ordenar deterministicamente.
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

bool _ehCuringaGen(CartaSnapshot c) => c.valor == 'JOKER' || c.valor == '2';

/// DFS STREAMING de melds/extensões: escolhe um subconjunto de `pool` (opcional-
/// mente com `pool[0]` OBRIGATÓRIO — o topo), valida `[...base, ...escolhidos]`
/// pelo validador canônico e chama `onOk` para cada combinação VÁLIDA de tamanho
/// escolhido ≥ `minSel`. PODA precoce (nunca descarta um meld legal): um natural
/// (não-JOKER, não-"2") só pode ser adicionado se os naturais não passarem a ter
/// ≥2 naipes E ≥2 valores ao mesmo tempo (aí não é nem sequência nem trinca);
/// JOKER nunca aparece 2×. Não materializa subconjuntos: produz durante a
/// travessia (memória O(profundidade)). `base` (ex.: o jogo exposto na extensão)
/// semeia a poda.
void _dfsSelecao(
  List<CartaSnapshot> base,
  List<CartaSnapshot> pool,
  bool fixarPrimeiro,
  int minSel,
  RuleSpec spec,
  DiagnosticoLixo diag,
  void Function(List<int> escolhidos) onOk,
) {
  final n = pool.length;
  final esc = <int>[];
  final naipes0 = <String>{};
  final valores0 = <String>{};
  var jokers0 = 0;
  for (final c in base) {
    if (c.valor == 'JOKER') {
      jokers0++;
    } else if (c.valor != '2' && c.naipe != null) {
      naipes0.add(c.naipe!);
      valores0.add(c.valor);
    }
  }

  void rec(int start, Set<String> naipes, Set<String> valores, int jokers) {
    diag.nosMeld++;
    if (esc.length >= minSel) {
      final cartas = <CartaSnapshot>[...base, for (final i in esc) pool[i]];
      if (validarJogoMesa(cartas, spec).valido) onOk(List<int>.from(esc));
    }
    for (var i = start; i < n; i++) {
      final c = pool[i];
      final ehJoker = c.valor == 'JOKER';
      // Poda de JOKER acoplada à SPEC congelada (não a um "1" mágico): um meld
      // nunca tem mais JOKERs que `maxCuringasPorSequencia`. Se um dia a spec
      // subir esse teto, esta poda acompanha — nenhuma sequência legal é perdida.
      if (ehJoker && jokers >= spec.maxCuringasPorSequencia) continue;
      var nn = naipes, nv = valores;
      if (!_ehCuringaGen(c)) {
        nn = {...naipes, c.naipe!};
        nv = {...valores, c.valor};
        if (nn.length >= 2 && nv.length >= 2) continue; // nem seq nem trinca
      }
      esc.add(i);
      rec(i + 1, nn, nv, jokers + (ehJoker ? 1 : 0));
      esc.removeLast();
    }
  }

  if (fixarPrimeiro) {
    if (n == 0) return;
    esc.add(0);
    final c0 = pool[0];
    final nn = _ehCuringaGen(c0) ? {...naipes0} : {...naipes0, c0.naipe!};
    final nv = _ehCuringaGen(c0) ? {...valores0} : {...valores0, c0.valor};
    if (!(nn.length >= 2 && nv.length >= 2)) {
      rec(1, nn, nv, jokers0 + (c0.valor == 'JOKER' ? 1 : 0));
    }
    esc.removeLast();
  } else {
    rec(0, {...naipes0}, {...valores0}, jokers0);
  }
}

/// C10 — DERIVAÇÃO de TODOS os candidatos ATÔMICOS de compra do lixo Fechado/STBL
/// construíveis EXCLUSIVAMENTE com o topo visível + a mão atual + os jogos já
/// expostos da dupla. Cartas ENTERRADAS ficam 100% fora. Auto-derivar ≠
/// auto-decidir: enumera e valida, mas NÃO escolhe pelo jogador (0 → recusa;
/// 1 → executa; 2+ → o jogador escolhe). Sem caps e SEM materialização de 2^n:
/// DFS lazy com poda estrutural + disjunção incremental; `avaliarComprarLixo` é
/// o verificador final. `diag` (opcional) registra a evidência estrutural.
List<ComprarLixo> derivarCandidatosCompraLixoFechado(
    EstadoJogo estado, int assento, RuleSpec spec,
    {DiagnosticoLixo? diag}) {
  final d = diag ?? DiagnosticoLixo();
  if (estado.lixo.isEmpty) return const <ComprarLixo>[];
  final topo = estado.lixo.last;
  final topoId = topo.id;
  final dupla = assento % 2 == 0 ? 'nos' : 'eles';
  final melds = estado.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[];
  final mao = estado.maos[assento];
  final poolTopo = <CartaSnapshot>[topo, ...mao];

  final vistos = <String>{};
  final out = <ComprarLixo>[];
  void tentar(List<List<CartaId>> jogos, List<Extensao> exts) {
    d.transacoesValidadas++;
    final r = avaliarComprarLixo(estado, assento, spec,
        topoDeclarado: topoId, jogosNovos: jogos, extensoes: exts);
    if (!r.valido) return;
    final acao = ComprarLixo(
        topoDeclarado: topoId, jogosNovos: jogos, extensoes: exts);
    // O que é OFERECIDO tem de ser exatamente o que a autoridade ACEITA. Sem
    // esta linha, uma compra que deixaria o turno sem conclusão legal seria
    // enumerada aqui (o avaliador de compra não conhece o invariante) e só
    // recusada no `aplicarLegal` — com 1 candidato o fluxo executa direto e o
    // jogador levaria uma recusa por uma jogada que a própria mesa ofereceu.
    if (!acaoEhLegal(estado, assento, acao, spec)) return;
    if (vistos.add(_sigCompra(jogos, exts))) out.add(acao);
  }

  // ---- USOS DO TOPO (o topo aparece em exatamente uma unidade) ----
  final usosTopo = <_UnidadeCompra>[];
  _dfsSelecao(const [], poolTopo, true, 3, spec, d, (esc) {
    final ids = <CartaId>[for (final i in esc) poolTopo[i].id];
    usosTopo.add(_UnidadeCompra.jogo(ids, ids.toSet()));
  });
  for (var k = 0; k < melds.length; k++) {
    _dfsSelecao(melds[k], poolTopo, true, 1, spec, d, (esc) {
      final ids = <CartaId>[for (final i in esc) poolTopo[i].id];
      usosTopo.add(_UnidadeCompra.ext(Extensao(k, ids), ids.toSet()));
    });
  }

  // ---- UNIDADES EXTRA (SEM o topo): jogos novos e extensões da mão ----
  final extras = <_UnidadeCompra>[];
  _dfsSelecao(const [], mao, false, 3, spec, d, (esc) {
    final ids = <CartaId>[for (final i in esc) mao[i].id];
    extras.add(_UnidadeCompra.jogo(ids, ids.toSet()));
  });
  for (var k = 0; k < melds.length; k++) {
    _dfsSelecao(melds[k], mao, false, 1, spec, d, (esc) {
      final ids = <CartaId>[for (final i in esc) mao[i].id];
      extras.add(_UnidadeCompra.ext(Extensao(k, ids), ids.toSet()));
    });
  }

  // ---- COMBINAÇÃO ATÔMICA (DFS streaming): cada uso do topo + qualquer conjunto
  //      DISJUNTO de unidades extra. Produz-e-VALIDA cada transação na travessia
  //      (nada de lista completa de combinações). Descarte precoce por carta E
  //      por índice de jogo estendido. avaliarComprarLixo é o verificador final.
  for (final tu in usosTopo) {
    final selec = <_UnidadeCompra>[];
    final cartas = <CartaId>{...tu.ids};
    final indices = <int>{if (tu.indiceExt != null) tu.indiceExt!};
    void rec(int start) {
      d.nosCombo++;
      final jogos = <List<CartaId>>[
        if (tu.jogoNovo != null) tu.jogoNovo!,
        for (final u in selec)
          if (u.jogoNovo != null) u.jogoNovo!
      ];
      final exts = <Extensao>[
        if (tu.extensao != null) tu.extensao!,
        for (final u in selec)
          if (u.extensao != null) u.extensao!
      ];
      tentar(jogos, exts);
      for (var k = start; k < extras.length; k++) {
        final u = extras[k];
        if (u.ids.any(cartas.contains)) continue;
        if (u.indiceExt != null && indices.contains(u.indiceExt)) continue;
        selec.add(u);
        cartas.addAll(u.ids);
        if (u.indiceExt != null) indices.add(u.indiceExt!);
        rec(k + 1);
        if (u.indiceExt != null) indices.remove(u.indiceExt!);
        cartas.removeAll(u.ids);
        selec.removeLast();
      }
    }

    rec(0);
  }

  out.sort((a, b) => _sigCompra(a.jogosNovos, a.extensoes)
      .compareTo(_sigCompra(b.jogosNovos, b.extensoes)));
  return out;
}

/// C10 (rev.1) — PARTIÇÕES ATÔMICAS de uma seleção de cartas em jogos NOVOS.
///
/// O gesto aprovado da mesa é um só: o jogador seleciona as cartas e toca no
/// feltro. Para a abertura MÚLTIPLA existir sem redesenhar a tela, é a seleção
/// que precisa ser interpretada — todas as maneiras legais de repartir
/// EXATAMENTE aquelas cartas em jogos válidos.
///
/// Auto-derivar ≠ auto-decidir, igual ao lixo: 0 partições → recusa;
/// 1 → executa; 2+ → o jogador escolhe. A seleção de UM meld continua dando
/// exatamente uma partição, então o gesto de sempre não muda de comportamento.
///
/// Travessia lazy com poda estrutural (mesma do derivador do lixo) e âncora na
/// carta ainda não usada de menor índice — isso elimina permutações da mesma
/// partição por construção, em vez de deduplicar depois. `avaliarBaixar` é o
/// verificador final: mínimo de vulnerabilidade, trava de esvaziar e tudo mais
/// continuam sendo decididos pela autoridade, nunca aqui.
List<Baixar> derivarParticoesAbertura(
    EstadoJogo estado, int assento, RuleSpec spec, List<CartaId> selecao,
    {DiagnosticoLixo? diag}) {
  final d = diag ?? DiagnosticoLixo();
  if (selecao.length < 3) return const <Baixar>[];
  final mao = estado.maos[assento];
  final porId = <CartaId, CartaSnapshot>{for (final c in mao) c.id: c};
  // Toda carta selecionada precisa estar na mão, sem repetição.
  final vistos = <CartaId>{};
  final cartas = <CartaSnapshot>[];
  for (final id in selecao) {
    if (!vistos.add(id)) return const <Baixar>[];
    final c = porId[id];
    if (c == null) return const <Baixar>[];
    cartas.add(c);
  }

  final n = cartas.length;
  final usada = List<bool>.filled(n, false);
  final atual = <List<CartaId>>[];
  final saida = <Baixar>[];

  void emitir() {
    d.transacoesValidadas++;
    final jogos = [for (final g in atual) List<CartaId>.from(g)];
    final acao = Baixar(jogosNovos: jogos);
    // Mesma razão do derivador do lixo: o conjunto OFERECIDO ao jogador é o
    // conjunto ACEITO pela autoridade. `avaliarBaixar` sozinho não conhece o
    // invariante de conclusão do turno e ofereceria a partição que deixa beco.
    if (acaoEhLegal(estado, assento, acao, spec)) saida.add(acao);
  }

  void rec(int usadas) {
    d.nosCombo++;
    if (usadas == n) {
      emitir();
      return;
    }
    // ÂNCORA: a menor carta ainda livre entra obrigatoriamente no próximo jogo.
    var ancora = 0;
    while (ancora < n && usada[ancora]) {
      ancora++;
    }
    final pool = <int>[
      for (var i = ancora + 1; i < n; i++)
        if (!usada[i]) i
    ];
    final grupo = <int>[ancora];
    usada[ancora] = true;

    void escolher(int k, Set<String> naipes, Set<String> valores, int jokers) {
      d.nosMeld++;
      if (grupo.length >= 3) {
        final meld = <CartaSnapshot>[for (final i in grupo) cartas[i]];
        if (validarJogoMesa(meld, spec).valido) {
          atual.add([for (final i in grupo) cartas[i].id]);
          rec(usadas + grupo.length);
          atual.removeLast();
        }
      }
      for (var p = k; p < pool.length; p++) {
        final i = pool[p];
        if (usada[i]) continue;
        final c = cartas[i];
        final ehJoker = c.valor == 'JOKER';
        if (ehJoker && jokers >= spec.maxCuringasPorSequencia) continue;
        var nn = naipes, nv = valores;
        if (!_ehCuringaGen(c)) {
          nn = {...naipes, c.naipe!};
          nv = {...valores, c.valor};
          // Nem sequência (2+ naipes) nem trinca (2+ valores): poda estrutural
          // que nunca descarta um meld legal.
          if (nn.length >= 2 && nv.length >= 2) continue;
        }
        grupo.add(i);
        usada[i] = true;
        escolher(p + 1, nn, nv, jokers + (ehJoker ? 1 : 0));
        usada[i] = false;
        grupo.removeLast();
      }
    }

    final c0 = cartas[ancora];
    escolher(
      0,
      _ehCuringaGen(c0) ? <String>{} : {c0.naipe!},
      _ehCuringaGen(c0) ? <String>{} : {c0.valor},
      c0.valor == 'JOKER' ? 1 : 0,
    );
    usada[ancora] = false;
  }

  rec(0);
  saida.sort((a, b) =>
      _sigCompra(a.jogosNovos, a.extensoes).compareTo(_sigCompra(b.jogosNovos, b.extensoes)));
  return saida;
}

class _RunCanonico {
  final bool recusou;
  final String? motivo;
  final EstadoJogo estado;
  final int conversoes;

  /// reasonCode da recusa de regra (repassado do gerador único).
  final String? codigo;
  const _RunCanonico(this.recusou, this.motivo, this.estado, this.conversoes,
      {this.codigo});
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
    if (!r.legal) {
      return _RunCanonico(true, r.motivo, cur, conversoes, codigo: r.codigo);
    }
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
        motivo: run.motivo, codigo: run.codigo);
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
