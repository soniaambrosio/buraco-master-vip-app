// C9-C — MODO SOMBRA + COMPARADOR. Roda o motor LEGADO (autoritativo) e o
// CANÔNICO sobre o MESMO estado projetado, compara os resultados normalizados e
// classifica divergências. NÃO tem autoridade (nunca decide o jogo real) e NÃO
// tem efeito na UI/comportamento: opera sobre CLONES reconstruídos a partir da
// projeção (com EnvelopeRuntime COMPLETO). Separado da autoridade: a flag de
// SOMBRA (`MotorConfig.sombraAtiva`) governa se um chamador de runtime o invoca;
// o comparador em si é puro e sem efeito colateral. NÃO altera regra nem a spec.
//
// Pipeline (Adendo 6 do PLANO-C9): (1) execução dupla; (2) normalização;
// (3) comparação; (4) classificação (CONVERGE | EXC-01..04 | INESPERADA);
// (5) diff estruturado; (6) Replay automático (por snapshot, Ajuste 3) para
// qualquer divergência INESPERADA.
import '../mesa.dart';
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/gerador/gerador.dart';
import '../rules/modalidade.dart';
import '../rules/replay.dart';
import '../rules/rule_spec.dart';
import '../rules/sombra.dart';
import 'envelope_runtime.dart';
import 'motor_config.dart';
import 'projecao_estado.dart';

/// Classificação da comparação de UMA transação.
/// (`canonicoRecusou` foi aposentado no C9-C2b: recusa agora é comparada por
/// estado — ambos recusam ⇒ CONVERGE; assimétrico ⇒ INESPERADA/EXC. Mantido no
/// enum por compatibilidade; não é mais produzido.)
enum ClassificacaoSombra { converge, excecao, inesperada, canonicoRecusou }

/// Diferença estruturada de um campo entre o pós-legado e o pós-canônico.
class CampoDiff {
  final String campo;
  final String legado;
  final String canonico;
  const CampoDiff(this.campo, this.legado, this.canonico);
  Map<String, Object?> toJson() =>
      {'campo': campo, 'legado': legado, 'canonico': canonico};
}

/// Relatório da comparação de uma transação (uma linha da paridade).
class RelatorioSombra {
  final String rotulo;
  final ClassificacaoSombra classificacao;
  final bool iguais;
  final String assinaturaLegado;
  final String assinaturaCanonico;
  final List<CampoDiff> diff;
  final String? idExcecao; // preenchido quando classificacao == excecao
  final Map<String, dynamic>? replayJson; // preenchido quando inesperada
  // Campos OPERACIONAIS relevantes do EnvelopeRuntime comparados pós-transação
  // (C9-C2a-fix). Hoje: 'mortosConvertidos' — o único efeito operacional que a
  // transação canônica produz/transporta. Outros campos do envelope são
  // legado-runtime/UI (o canônico não os modela) e por isso NÃO entram na
  // comparação (declarado, não silencioso).
  final Map<String, String> envRelevanteLegado;
  final Map<String, String> envRelevanteCanonico;
  // Legalidade EXPLÍCITA de cada motor (C9-C2b-fix): quem APLICOU a transação.
  // A legalidade NÃO é deduzida da igualdade de estado — é capturada direto.
  final bool legadoAplicou;
  final bool canonicoAplicou;
  const RelatorioSombra({
    required this.rotulo,
    required this.classificacao,
    required this.iguais,
    required this.assinaturaLegado,
    required this.assinaturaCanonico,
    required this.diff,
    required this.idExcecao,
    required this.replayJson,
    required this.envRelevanteLegado,
    required this.envRelevanteCanonico,
    required this.legadoAplicou,
    required this.canonicoAplicou,
  });

  bool get legadoRecusou => !legadoAplicou;
  bool get canonicoRecusou => !canonicoAplicou;

  bool get inesperada => classificacao == ClassificacaoSombra.inesperada;
}

/// Uma TRANSAÇÃO semântica a comparar: como rodá-la no legado (uma chamada) e a
/// sequência canônica equivalente. `excEsperada` declara a divergência esperada
/// (null => tem de CONVERGIR; 'EXC-0x' => divergência conhecida e declarada).
class TransacaoSombra {
  final String rotulo;
  final int assento;
  final RuleSpec spec;
  final String? excEsperada;
  final bool Function(Jogo jogo) aplicarLegado;
  final List<Acao> Function(EstadoJogo pre) acoesCanonicas;
  const TransacaoSombra({
    required this.rotulo,
    required this.assento,
    required this.spec,
    required this.excEsperada,
    required this.aplicarLegado,
    required this.acoesCanonicas,
  });

  /// Comprar o monte (transação simples).
  static TransacaoSombra comprarMonte(int assento, RuleSpec spec) =>
      TransacaoSombra(
        rotulo: 'comprarMonte@$assento',
        assento: assento,
        spec: spec,
        excEsperada: null,
        aplicarLegado: (j) => j.comprarMonte(assento),
        acoesCanonicas: (e) => const [ComprarMonte()],
      );

  /// Descartar uma carta. Se o descarte esvaziar a mão com morto disponível, a
  /// ESTABILIZAÇÃO do comparador resolve o morto indireto (mortoPendente ->
  /// PegarMorto(viaDescarte)), espelhando o que o legado dobra em `descartar`.
  static TransacaoSombra descartar(int assento, String cartaId, RuleSpec spec,
          {String? excEsperada}) =>
      TransacaoSombra(
        rotulo: 'descartar($cartaId)@$assento',
        assento: assento,
        spec: spec,
        excEsperada: excEsperada,
        aplicarLegado: (j) => j.descartar(assento, cartaId) == null,
        acoesCanonicas: (e) => [Descartar(cartaId)],
      );

  /// Baixar um jogo novo (transação semântica). Se a baixada ESVAZIAR a mão, a
  /// estabilização do comparador resolve o que o legado dobra em `baixar`:
  /// morto DIRETO (PegarMorto direto) se houver morto, ou BATIDA (Bater). Não é
  /// comparação de chamada crua: legado `baixar` × canônico `Baixar` + estabiliza.
  static TransacaoSombra baixar(int assento, List<CartaId> ids, RuleSpec spec,
          {String? excEsperada}) =>
      TransacaoSombra(
        rotulo: 'baixar(${ids.length})@$assento',
        assento: assento,
        spec: spec,
        excEsperada: excEsperada,
        aplicarLegado: (j) => j.baixar(assento, ids)['ok'] == true,
        acoesCanonicas: (e) => [
          Baixar(jogosNovos: [ids])
        ],
      );
}

class _ResCanonico {
  final bool recusou;
  final String? motivo;
  final EstadoJogo estado;
  final int conversoes; // nº de mortos convertidos em monte na transação
  const _ResCanonico(this.recusou, this.motivo, this.estado, this.conversoes);
}

// Campos OPERACIONAIS do EnvelopeRuntime que a transação canônica é capaz de
// produzir/transportar e que, portanto, ENTRAM na comparação de paridade.
Map<String, String> _envRelevante({required int mortosConvertidos}) =>
    {'mortosConvertidos': '$mortosConvertidos'};

/// Comparador do modo sombra.
class ModoSombra {
  const ModoSombra();

  /// Separação da autoridade: só roda quando a flag de SOMBRA está ligada.
  /// (A autoridade — MotorConfig.canonicoAtivo — é irrelevante aqui.)
  bool habilitado(MotorConfig config) => config.sombraAtiva;

  /// Compara UMA transação. `pre` traz o estado canônico + o EnvelopeRuntime
  /// COMPLETO, do qual o clone legado é reconstruído fielmente.
  RelatorioSombra comparar(ProjecaoBMV pre, TransacaoSombra tx) {
    // ---------- (1) EXECUÇÃO DUPLA ----------
    // LEGADO (autoritativo) sobre um clone reconstruído COM envelope completo.
    final jl = Jogo.paraCostura(
      apelidos: pre.envelope.apelidos,
      avatares: pre.envelope.avatares,
      mascotes: pre.envelope.mascotes,
    );
    aplicarEmJogo(jl, pre.canonico, pre.envelope);
    // LEGALIDADE do legado CAPTURADA explicitamente (não descartada).
    final legadoAplicou = tx.aplicarLegado(jl);
    // Espelha AdaptadorLegado._saida: limpa o transporte de fase (setado na
    // montagem) para que a fase PÓS-legado derive do jaComprou pós-operação.
    jl.costuraFaseCanonica = null;
    final posLegadoProj = paraCanonico(jl);
    final posLegado = posLegadoProj.canonico;

    // CANÔNICO: aplica a sequência semântica e ESTABILIZA antes de comparar.
    final rc = _rodarCanonico(pre.canonico, tx);
    final canonicoAplicou = !rc.recusou; // legalidade EXPLÍCITA do canônico
    final posCanonico = rc.estado;

    // ---------- ENVELOPE operacional relevante (C9-C2a-fix) ----------
    final envLeg = _envRelevante(
        mortosConvertidos: posLegadoProj.envelope.mortosConvertidos);
    final envCan = _envRelevante(
        mortosConvertidos: pre.envelope.mortosConvertidos + rc.conversoes);
    final diffEnv = <CampoDiff>[
      for (final k in envLeg.keys)
        if (envLeg[k] != envCan[k]) CampoDiff('env.$k', envLeg[k]!, envCan[k]!),
    ];

    final aL = posLegado.assinatura();
    final aC = posCanonico.assinatura();
    final diffEstadoEnv = <CampoDiff>[
      ..._diff(posLegado, posCanonico),
      ...diffEnv,
    ];
    final excConhecida = tx.excEsperada != null &&
        excecoesSombra.any((e) => e.id == tx.excEsperada);

    RelatorioSombra mk(ClassificacaoSombra c,
            {required bool iguais,
            required List<CampoDiff> diff,
            String? idExc,
            Map<String, dynamic>? replay}) =>
        RelatorioSombra(
          rotulo: tx.rotulo,
          classificacao: c,
          iguais: iguais,
          assinaturaLegado: aL,
          assinaturaCanonico: aC,
          diff: diff,
          idExcecao: idExc,
          replayJson: replay,
          envRelevanteLegado: envLeg,
          envRelevanteCanonico: envCan,
          legadoAplicou: legadoAplicou,
          canonicoAplicou: canonicoAplicou,
        );

    // ---------- QUADRANTES DE LEGALIDADE (explícitos) ----------
    // Legalidade NÃO é deduzida da igualdade de estado.
    if (legadoAplicou != canonicoAplicou) {
      // ASSIMETRIA: um aplicou, o outro recusou -> SEMPRE divergência, mesmo que
      // os estados finais coincidam. EXC só se declarada+conhecida; senão
      // INESPERADA + Replay completo.
      final diffAssim = <CampoDiff>[
        CampoDiff('legalidade', legadoAplicou ? 'aplicou' : 'recusou',
            canonicoAplicou ? 'aplicou' : 'recusou'),
        ...diffEstadoEnv,
      ];
      return excConhecida
          ? mk(ClassificacaoSombra.excecao,
              iguais: false, diff: diffAssim, idExc: tx.excEsperada)
          : mk(ClassificacaoSombra.inesperada,
              iguais: false,
              diff: diffAssim,
              replay: _replay(pre, tx).toJson());
    }

    // SIMÉTRICO (ambos aplicam OU ambos recusam): compara estado + envelope.
    if (diffEstadoEnv.isEmpty) {
      return mk(ClassificacaoSombra.converge, iguais: true, diff: const []);
    }
    return excConhecida
        ? mk(ClassificacaoSombra.excecao,
            iguais: false, diff: diffEstadoEnv, idExc: tx.excEsperada)
        : mk(ClassificacaoSombra.inesperada,
            iguais: false,
            diff: diffEstadoEnv,
            replay: _replay(pre, tx).toJson());
  }

  /// Roda um lote de transações e retorna a paridade (uma linha por transação).
  List<RelatorioSombra> compararLote(
          List<(ProjecaoBMV, TransacaoSombra)> casos) =>
      [for (final c in casos) comparar(c.$1, c.$2)];

  // ----- canônico: aplica a sequência e estabiliza mortoPendente -----
  _ResCanonico _rodarCanonico(EstadoJogo pre, TransacaoSombra tx) {
    var cur = pre;
    var conversoes = 0;
    for (final a in tx.acoesCanonicas(pre)) {
      // §8.1: ComprarMonte com monte vazio + morto disponível CONVERTERIA o
      // morto em monte. Só conta o efeito (mortosConvertidos +1) se a ação for
      // EFETIVAMENTE aplicada — se aplicarLegal recusar por outra precondição
      // (fora da vez / fase errada / rodada encerrada), NÃO houve conversão.
      final vaiConverter =
          a is ComprarMonte && cur.monte.isEmpty && cur.mortos.isNotEmpty;
      final r = aplicarLegal(cur, tx.assento, a, tx.spec);
      if (!r.legal) return _ResCanonico(true, r.motivo, cur, conversoes);
      if (vaiConverter) conversoes++;
      cur = r.proximoEstado!;
    }
    // ESTABILIZA as transições compostas que o legado DOBRA numa só chamada:
    //  - mortoPendente (descarte indireto) -> PegarMorto(viaDescarte:true);
    //  - mão vazia em fase JOGO (esvaziou BAIXANDO) -> morto DIRETO
    //    (PegarMorto direto, se morto disponível) OU BATIDA (Bater).
    // (limite de segurança contra laço).
    var guarda = 0;
    while (guarda < 6 && !cur.rodadaEncerrada) {
      guarda++;
      if (cur.fase == FaseTurno.mortoPendente) {
        final r = aplicarLegal(
            cur, tx.assento, const PegarMorto(viaDescarte: true), tx.spec);
        if (!r.legal) break;
        cur = r.proximoEstado!;
        continue;
      }
      if (cur.fase == FaseTurno.jogo && cur.maos[tx.assento].isEmpty) {
        final dupla = tx.assento % 2 == 0 ? 'nos' : 'eles';
        final mortoDisp =
            !(cur.mortoPego[dupla] ?? false) && cur.mortos.isNotEmpty;
        // morto DIRETO deixa a mão cheia (morto) -> o laço para na iteração
        // seguinte; BATIDA encerra a rodada -> o laço sai pela condição.
        final r = aplicarLegal(cur, tx.assento,
            mortoDisp ? const PegarMorto() : const Bater(), tx.spec);
        if (!r.legal) break;
        cur = r.proximoEstado!;
        continue;
      }
      break;
    }
    return _ResCanonico(false, null, cur, conversoes);
  }

  Replay _replay(ProjecaoBMV pre, TransacaoSombra tx) => Replay(
        // seed NULA: produção não tem seed reproduzível -> snapshot COMPLETO
        // (EstadoJogo canônico + EnvelopeRuntime completo). Sem o envelope, uma
        // divergência dependente dele (ex.: lixoTopoObrigatorio) não reproduz.
        versaoSpec: RuleSpec.versaoCanonica,
        modalidade: pre.canonico.modalidade,
        metaPontos: pre.canonico.metaPontos,
        acoes: tx.acoesCanonicas(pre.canonico),
        estadoInicialSerializado: serializarProjecao(pre),
        faseInicial: pre.canonico.fase,
      );
}

// ========================= diff estruturado =========================
Map<String, String> _campos(EstadoJogo e0) {
  final n = e0.normalizar();
  String zona(List<CartaSnapshot> l) => l.map((c) => c.chave).join(',');
  String matriz(List<List<CartaSnapshot>> m) => m.map(zona).join(' | ');
  return {
    'modalidade': n.modalidade.texto,
    'metaPontos': '${n.metaPontos}',
    'vez': '${n.vez}',
    'monte': zona(n.monte),
    'lixo': zona(n.lixo),
    'mortos': matriz(n.mortos),
    'maos': matriz(n.maos),
    'nos': matriz(n.jogosDupla['nos'] ?? const []),
    'eles': matriz(n.jogosDupla['eles'] ?? const []),
    'rodadasVulneravel': '${n.rodadasVulneravel}',
    'primeiraBaixadaFeita': '${n.primeiraBaixadaFeita}',
    'mortoPego': '${n.mortoPego}',
    'rodadaEncerrada': '${n.rodadaEncerrada}',
    'duplaQueBateu': '${n.duplaQueBateu}',
    'fase': n.fase.name,
  };
}

List<CampoDiff> _diff(EstadoJogo legado, EstadoJogo canonico) {
  final a = _campos(legado);
  final b = _campos(canonico);
  final out = <CampoDiff>[];
  for (final k in a.keys) {
    if (a[k] != b[k]) out.add(CampoDiff(k, a[k]!, b[k]!));
  }
  return out;
}

// ==================== serialização de EstadoJogo (Replay snapshot) ====================
Map<String, Object?> _cartaJ(CartaSnapshot c) =>
    {'id': c.id, 'naipe': c.naipe, 'valor': c.valor, 'cur': c.curinga};
CartaSnapshot _cartaD(Map m) => CartaSnapshot(
    m['id'] as String, m['naipe'] as String?, m['valor'] as String, m['cur'] as bool);
List<Object?> _zonaJ(List<CartaSnapshot> l) => [for (final c in l) _cartaJ(c)];
List<CartaSnapshot> _zonaD(List l) => [for (final m in l) _cartaD(m as Map)];
List<Object?> _matJ(List<List<CartaSnapshot>> m) => [for (final z in m) _zonaJ(z)];
List<List<CartaSnapshot>> _matD(List m) => [for (final z in m) _zonaD(z as List)];

/// Serializa um EstadoJogo canônico para o snapshot do Replay (Ajuste 3).
Map<String, Object?> serializarEstado(EstadoJogo e) => {
      'modalidade': e.modalidade.texto,
      'metaPontos': e.metaPontos,
      'monte': _zonaJ(e.monte),
      'lixo': _zonaJ(e.lixo),
      'mortos': _matJ(e.mortos),
      'maos': _matJ(e.maos),
      'jogosDupla': {
        for (final en in e.jogosDupla.entries) en.key: _matJ(en.value)
      },
      'rodadasVulneravel': {...e.rodadasVulneravel},
      'primeiraBaixadaFeita': {...e.primeiraBaixadaFeita},
      'vez': e.vez,
      'mortoPego': {...e.mortoPego},
      'rodadaEncerrada': e.rodadaEncerrada,
      'duplaQueBateu': e.duplaQueBateu,
      'fase': e.fase.name,
    };

FaseTurno _faseDeName(String s) {
  switch (s) {
    case 'jogo':
      return FaseTurno.jogo;
    case 'mortoPendente':
      return FaseTurno.mortoPendente;
    default:
      return FaseTurno.compra;
  }
}

// ---- EnvelopeRuntime: serialização COMPLETA (runtime + sidecar) ----
Map<String, Object?> serializarEnvelope(EnvelopeRuntime e) => {
      'cont': e.cont,
      'lixoUnicoCompradoId': e.lixoUnicoCompradoId,
      'mortosConvertidos': e.mortosConvertidos,
      'iniciadorRodada': e.iniciadorRodada,
      'rodadaContada': e.rodadaContada,
      'lixoTopoObrigatorio': e.lixoTopoObrigatorio,
      'integridadeErro': e.integridadeErro,
      'assentoQueBateu': e.assentoQueBateu,
      'rodada': e.rodada,
      'placar': {...e.placar},
      'encerrada': e.encerrada,
      'pontosRodada': e.pontosRodada == null
          ? null
          : {for (final en in e.pontosRodada!.entries) en.key: en.value},
      'apelidos': [...e.apelidos],
      'avatares': [...e.avatares],
      'mascotes': [...e.mascotes],
    };

EnvelopeRuntime desserializarEnvelope(Map m) => EnvelopeRuntime(
      cont: m['cont'] as int,
      lixoUnicoCompradoId: m['lixoUnicoCompradoId'] as String?,
      mortosConvertidos: m['mortosConvertidos'] as int,
      iniciadorRodada: m['iniciadorRodada'] as int,
      rodadaContada: m['rodadaContada'] as bool,
      lixoTopoObrigatorio: m['lixoTopoObrigatorio'] as String?,
      integridadeErro: m['integridadeErro'] as String?,
      assentoQueBateu: m['assentoQueBateu'] as int?,
      rodada: m['rodada'] as int,
      placar:
          (m['placar'] as Map).map((k, v) => MapEntry(k as String, v as int)),
      encerrada: m['encerrada'] as bool,
      pontosRodada: m['pontosRodada'] == null
          ? null
          : (m['pontosRodada'] as Map)
              .map((k, v) => MapEntry(k as String, v as Object?)),
      apelidos: [for (final x in (m['apelidos'] as List)) x as String],
      avatares: [for (final x in (m['avatares'] as List)) x as String],
      mascotes: [for (final x in (m['mascotes'] as List)) x as String],
    );

/// Snapshot COMPLETO da projeção (estado canônico + envelope), com as chaves
/// exigidas por `Replay.chavesSnapshotRuntime`.
Map<String, Object?> serializarProjecao(ProjecaoBMV p) => {
      'canonico': serializarEstado(p.canonico),
      'envelope': serializarEnvelope(p.envelope),
    };

/// Reconstrói a projeção COMPLETA a partir do snapshot do Replay.
ProjecaoBMV desserializarProjecao(Map m) => ProjecaoBMV(
      desserializarEstado(m['canonico'] as Map),
      desserializarEnvelope(m['envelope'] as Map),
    );

/// Reconstrói um EstadoJogo a partir do snapshot do Replay (reprodução).
EstadoJogo desserializarEstado(Map m) => EstadoJogo(
      modalidade: Modalidade.deTexto(m['modalidade'] as String),
      metaPontos: m['metaPontos'] as int,
      monte: _zonaD(m['monte'] as List),
      lixo: _zonaD(m['lixo'] as List),
      mortos: _matD(m['mortos'] as List),
      maos: _matD(m['maos'] as List),
      jogosDupla: {
        for (final en in (m['jogosDupla'] as Map).entries)
          en.key as String: _matD(en.value as List)
      },
      rodadasVulneravel: (m['rodadasVulneravel'] as Map)
          .map((k, v) => MapEntry(k as String, v as int)),
      primeiraBaixadaFeita: (m['primeiraBaixadaFeita'] as Map)
          .map((k, v) => MapEntry(k as String, v as bool)),
      vez: m['vez'] as int,
      mortoPego:
          (m['mortoPego'] as Map).map((k, v) => MapEntry(k as String, v as bool)),
      rodadaEncerrada: m['rodadaEncerrada'] as bool,
      duplaQueBateu: m['duplaQueBateu'] as String?,
      fase: _faseDeName(m['fase'] as String),
    );
