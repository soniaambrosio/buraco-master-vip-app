// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — BotExecutor.
//
// O ponto único onde a camada estratégica CONCLUI alguma coisa. O ciclo é
// sempre o mesmo e sempre nesta ordem:
//
//   observar (VisaoInformacao mascarada)
//     -> gerar alternativas (CandidateGenerator, já validadas pela autoridade)
//     -> pontuar (HeuristicEvaluator)
//     -> escolher UMA intenção
//     -> devolver as ações para a AUTORIDADE CANÔNICA validar e aplicar.
//
// O executor NÃO aplica nada. Ele devolve `DecisaoBot`; quem aplica é o `Jogo`,
// pelas mesmas entradas que o humano usa, e a autoridade continua livre para
// recusar. Nenhum "porque o bot acha melhor" fura o motor.
//
// FAIL-SAFE (§9): se a decisão estratégica não produzir plano nenhum, o
// executor devolve `semPlanoLegal` e NADA acontece. Ele não tem rota paralela
// de regra para "resolver" o impasse, e não deve ganhar uma.
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/gerador/gerador.dart' show aplicarLegal;
import '../rules/pontuacao_canonica.dart' show valorCarta;
import '../rules/rule_spec.dart';
import 'analise_mao.dart';
import 'avaliador_heuristico.dart';
import 'gerador_candidatos.dart';
import 'modelo_parceiro.dart';
import 'pesos.dart';
import 'razoes.dart';
import 'risco_descarte.dart';
import 'visao_informacao.dart';

/// A decisão estratégica, com o rastro que a explica (§8).
class DecisaoBot {
  /// Ações a submeter à autoridade, na ordem. Vazio = não decidir nada.
  final List<Acao> acoes;

  /// Código primário da razão (vocabulário de `Razao`).
  final String razao;

  /// Códigos secundários (o que mais pesou).
  final List<String> razoesSecundarias;

  final double score;

  /// Decomposição do score da alternativa vencedora.
  final Map<String, double> features;

  /// Quantas alternativas foram efetivamente pontuadas.
  final int candidatosConsiderados;

  /// A busca foi truncada por orçamento/largura (nunca silencioso).
  final bool truncado;

  /// Estado excepcional: só restavam curingas para descartar (§2).
  final bool impasse;

  /// Texto do impasse, para o relatório e para a decisão da Sônia.
  final String? diagnosticoImpasse;

  /// Plano vencedor da fase de jogo (null na fase de compra).
  final PlanoTurno? plano;

  /// Assinatura do PÚBLICO em que a decisão foi tomada + versão dos pesos.
  /// É a prova de determinismo: mesma assinatura + mesma config => mesma saída.
  final String assinaturaDecisao;

  const DecisaoBot({
    required this.acoes,
    required this.razao,
    this.razoesSecundarias = const <String>[],
    this.score = 0,
    this.features = const <String, double>{},
    this.candidatosConsiderados = 0,
    this.truncado = false,
    this.impasse = false,
    this.diagnosticoImpasse,
    this.plano,
    this.assinaturaDecisao = '',
  });

  bool get vazia => acoes.isEmpty;

  /// Rastro compacto para telemetria/log (não é contrato de UI).
  Map<String, dynamic> toJson() => {
        'razao': razao,
        if (razoesSecundarias.isNotEmpty) 'razoes': razoesSecundarias,
        'score': score,
        'features': features,
        'candidatos': candidatosConsiderados,
        'truncado': truncado,
        if (impasse) 'impasse': diagnosticoImpasse,
        'acoes': [for (final a in acoes) a.toJson()],
      };
}

class ExecutorBot {
  final RuleSpec spec;
  final ConfiguracaoBot cfg;

  ExecutorBot(this.spec, {this.cfg = ConfiguracaoBot.v1});

  AvaliadorHeuristico get _avaliador => AvaliadorHeuristico(spec, cfg);

  /// Hash determinístico (FNV-1a 32 bits) usado APENAS no desempate entre
  /// alternativas de score idêntico. Não sorteia carta, não altera legalidade e
  /// não favorece ninguém: é só uma ordem estável parametrizada pela semente.
  static int _hash(String s, int seed) {
    var h = 0x811C9DC5 ^ seed;
    for (var i = 0; i < s.length; i++) {
      h = (h ^ s.codeUnitAt(i)) & 0xFFFFFFFF;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  // =====================================================================
  // FASE DE COMPRA
  // =====================================================================

  /// Decide MONTE x LIXO.
  ///
  /// `candidatosLixo` são os usos ATÔMICOS do topo já derivados pela autoridade
  /// (`derivarCandidatosCompraLixoFechado`). O executor não os inventa e não os
  /// amplia: ele escolhe DENTRO da lista, que é a fronteira do §7 — todo
  /// candidato foi montado só com o topo visível, a mão e os jogos expostos.
  DecisaoBot decidirCompra(
    EstadoJogo estado,
    int assento, {
    List<ComprarLixo> candidatosLixo = const <ComprarLixo>[],
  }) {
    final visao = VisaoInformacao.doEstado(estado, assento);
    final parceiro = ModeloParceiro.observar(visao, spec);
    final assinatura = '${visao.assinaturaPublica()}\npesos=${cfg.pesos.versao}';

    final monte =
        _avaliador.avaliarCompraMonte(tamanhoMaoAtual: visao.tamanhoMao);
    var melhorScore = monte.score;
    var melhorFeatures = monte.features;
    var melhorRazao = Razao.compraMonte;
    List<Acao> melhorAcoes = const [ComprarMonte()];
    var considerados = 1;

    if (spec.exigeUsoDoTopoNoLixo) {
      if (candidatosLixo.isEmpty) {
        // Sem uso legal do topo, o lixo nem é alternativa (a autoridade recusa).
        return DecisaoBot(
          acoes: const [ComprarMonte()],
          razao: Razao.compraMonteSemUsoDoTopo,
          score: monte.score,
          features: monte.features,
          candidatosConsiderados: 1,
          assinaturaDecisao: assinatura,
        );
      }
      for (final cand in candidatosLixo) {
        considerados++;
        final a = _avaliarCandidatoLixo(visao, cand);
        if (_vence(a.score, melhorScore,
            _sigLixo(cand), _sigDe(melhorAcoes))) {
          melhorScore = a.score;
          melhorFeatures = a.features;
          melhorRazao = Razao.compraLixoEstrutura;
          melhorAcoes = <Acao>[cand];
        }
      }
    } else if (visao.lixoTopo != null) {
      considerados++;
      final a = _avaliador.avaliarCompraLixoAberto(
          inicial: visao, parceiro: parceiro);
      if (_vence(a.score, melhorScore, 'lixoAberto', _sigDe(melhorAcoes))) {
        melhorScore = a.score;
        melhorFeatures = a.features;
        melhorRazao = Razao.compraLixoVolume;
        melhorAcoes = const <Acao>[ComprarLixo()];
      }
    }

    return DecisaoBot(
      acoes: melhorAcoes,
      razao: melhorRazao,
      score: melhorScore,
      features: melhorFeatures,
      candidatosConsiderados: considerados,
      assinaturaDecisao: assinatura,
    );
  }

  /// Precifica um candidato de compra do lixo SEM aplicá-lo.
  ///
  /// Aplicar para medir traria as cartas ENTERRADAS para a mão do estado
  /// simulado, e pontuar por elas seria decidir com informação que ainda não é
  /// legítima (§7). Então a conta sai da DESCRIÇÃO do candidato — topo + mão +
  /// jogos expostos —, que é exatamente o que a autoridade usou para autorizá-lo.
  Avaliacao _avaliarCandidatoLixo(VisaoInformacao visao, ComprarLixo cand) {
    final porId = <String, CartaSnapshot>{
      for (final c in visao.mao) c.id: c,
      if (visao.lixoTopo != null) visao.lixoTopo!.id: visao.lixoTopo!,
    };
    var cartas = 0, curingas = 0;
    final novos = <List<CartaSnapshot>>[];
    for (final j in cand.jogosNovos) {
      final meld = <CartaSnapshot>[];
      for (final id in j) {
        final c = porId[id];
        if (c == null) continue;
        meld.add(c);
        cartas++;

        if (ehCuringaEstrategico(c)) curingas++;
      }
      novos.add(meld);
    }
    final estendidos = <int, List<CartaSnapshot>>{};
    for (final e in cand.extensoes) {
      final alvo = e.indiceJogo < visao.meldsProprios.length
          ? visao.meldsProprios[e.indiceJogo]
          : const <CartaSnapshot>[];
      final add = <CartaSnapshot>[];
      for (final id in e.cartas) {
        final c = porId[id];
        if (c == null) continue;
        add.add(c);
        cartas++;

        if (ehCuringaEstrategico(c)) curingas++;
      }
      estendidos[e.indiceJogo] = [...(estendidos[e.indiceJogo] ?? alvo), ...add];
    }

    final antes = visao.meldsProprios;
    final depois = <List<CartaSnapshot>>[
      for (var i = 0; i < antes.length; i++) estendidos[i] ?? antes[i],
      ...novos,
    ];

    final abre = !visao.abriuPropria && cand.jogosNovos.isNotEmpty;
    final minimo = spec.vulnerabilidade.minimoParaDescer(
      rodadasVulneravel: visao.rodadasVulneravelPropria,
      jaAbriuNaRodada: visao.abriuPropria,
    );

    return _avaliador.avaliarCompraLixo(
      inicial: visao,
      cartasNaMesa: cartas,
      mesaDepois: depois,
      curingasComprometidos: curingas,
      abre: abre,
      sujeitoAoMinimo: abre && minimo > 0,
    );
  }

  // =====================================================================
  // FASE DE JOGO
  // =====================================================================

  /// Decide o resto do turno: baixar/estender (ou não) e o que descartar.
  DecisaoBot decidirJogo(EstadoJogo estado, int assento) {
    final visao = VisaoInformacao.doEstado(estado, assento);
    final parceiro = ModeloParceiro.observar(visao, spec);
    final adversario = ModeloAdversario(visao, spec);
    final assinatura = '${visao.assinaturaPublica()}\npesos=${cfg.pesos.versao}';

    final ger = GeradorPlanos(spec, cfg).planosDeJogo(estado, assento);

    if (ger.planos.isEmpty) {
      if (ger.impasseDescarteSoCuringa) {
        return _impasseCuringa(estado, assento, assinatura, ger);
      }
      return DecisaoBot(
        acoes: const <Acao>[],
        razao: Razao.semPlanoLegal,
        truncado: ger.truncado,
        assinaturaDecisao: assinatura,
      );
    }

    PlanoTurno? melhor;
    Avaliacao? melhorAv;
    final avaliados = <PlanoTurno, Avaliacao>{};
    for (final p in ger.planos) {
      final a = _avaliador.avaliarPlano(p, visao, parceiro, adversario);
      avaliados[p] = a;
      if (melhor == null ||
          _vence(a.score, melhorAv!.score, p.assinatura, melhor.assinatura)) {
        melhor = p;
        melhorAv = a;
      }
    }

    final vencedor = melhor!;
    final av = melhorAv!;
    final secundarias = <String>[
      ..._razoesSecundarias(vencedor, ger.planos, avaliados, parceiro,
          adversario, visao),
      if (ger.truncado) Razao.buscaTruncada,
    ];

    return DecisaoBot(
      acoes: vencedor.acoes,
      razao: _razaoPrimaria(vencedor, ger.planos),
      razoesSecundarias: secundarias,
      score: av.score,
      features: av.features,
      candidatosConsiderados: ger.planos.length,
      truncado: ger.truncado,
      plano: vencedor,
      assinaturaDecisao: assinatura,
    );
  }

  /// Vitória por score, com desempate DETERMINÍSTICO pela assinatura + semente.
  bool _vence(double score, double melhor, String sig, String sigMelhor) {
    if (score > melhor) return true;
    if (score < melhor) return false;
    return _hash(sig, cfg.seed) < _hash(sigMelhor, cfg.seed);
  }

  String _sigLixo(ComprarLixo c) {
    final js = [
      for (final j in c.jogosNovos) (List<String>.from(j)..sort()).join('-')
    ]..sort();
    final es = [
      for (final e in c.extensoes)
        '${e.indiceJogo}:${(List<String>.from(e.cartas)..sort()).join('-')}'
    ]..sort();
    return 'L[${js.join('|')}/${es.join('|')}]';
  }

  String _sigDe(List<Acao> acoes) {
    if (acoes.length == 1 && acoes.first is ComprarLixo) {
      final c = acoes.first as ComprarLixo;
      return c.jogosNovos.isEmpty && c.extensoes.isEmpty
          ? 'lixoAberto'
          : _sigLixo(c);
    }
    return 'monte';
  }

  String _razaoPrimaria(PlanoTurno v, List<PlanoTurno> todos) {
    if (v.pegouMorto) return Razao.baixaMorto;
    if (v.bateu) return Razao.baixaBatida;
    if (v.abriu) {
      return v.sujeitoAoMinimo ? Razao.baixaAberturaMinima : Razao.baixaAbertura;
    }
    if (v.canastrasNovas > 0) return Razao.baixaCanastra;
    if (v.baixada != null) return Razao.baixaGanhoLiquido;
    // Não baixou. Se havia baixada legal na mesa de alternativas, a escolha foi
    // PRESERVAR — e isso precisa aparecer com nome próprio (§4).
    if (todos.any((p) => p.baixada != null)) return Razao.preservaEstrutura;
    return Razao.descarteMenorDano;
  }

  List<String> _razoesSecundarias(
    PlanoTurno v,
    List<PlanoTurno> todos,
    Map<PlanoTurno, Avaliacao> avaliados,
    ModeloParceiro parceiro,
    ModeloAdversario adversario,
    VisaoInformacao visao,
  ) {
    final out = <String>[];
    if (v.baixada != null && todos.any((p) => p.baixada == null)) {
      // baixou tendo a opção de não baixar: o ganho líquido venceu
      out.add(Razao.baixaGanhoLiquido);
    }
    if (!v.bateu && todos.any((p) => p.bateu) && parceiro.batidaPrematura()) {
      out.add(Razao.adiaPorParceiro);
    }
    final c = v.cartaDescartada;
    if (c != null) {
      // "Seguro" é comparativo, não absoluto: quase toda carta de 10 pontos tem
      // algum risco residual. O que interessa é ter escolhido a MENOS arriscada
      // existindo alternativa pior.
      final risco = adversario.avaliar(c).nota;
      final piorAlternativa = todos.fold<int>(
          0,
          (m, p) => p.cartaDescartada == null
              ? m
              : (adversario.avaliar(p.cartaDescartada!).nota > m
                  ? adversario.avaliar(p.cartaDescartada!).nota
                  : m));
      if (risco < piorAlternativa) out.add(Razao.descarteSeguro);
      if (!parceiro.utilAosJogosDaDupla(c) &&
          !parceiro.adjacenteAosJogosDaDupla(c) &&
          todos.any((p) =>
              p.cartaDescartada != null &&
              (parceiro.utilAosJogosDaDupla(p.cartaDescartada!) ||
                  parceiro.adjacenteAosJogosDaDupla(p.cartaDescartada!)))) {
        out.add(Razao.descartePreservaParceiro);
      }
      if (!out.contains(Razao.descarteSeguro)) out.add(Razao.descarteMenorDano);
      // OS 3 — a memória pública do parceiro só vira razão quando foi DECISIVA.
      if (_memoriaFoiDecisiva(v, avaliados)) {
        out.add(Razao.descarteMemoriaParceiro);
      }
    }
    return out;
  }

  /// O sinal da memória pública MUDOU o vencedor?
  ///
  /// Refaz o argmax descontando de cada alternativa a contribuição da feature
  /// e compara o vencedor contrafactual com o real. Usa o MESMO desempate
  /// (`_vence` com a assinatura do plano e a semente), senão a comparação
  /// mediria a ordem de iteração em vez do sinal.
  ///
  /// Custo: uma passada linear sobre alternativas já avaliadas. Sai cedo quando
  /// nenhuma alternativa recebeu contribuição — que é o caso comum.
  bool _memoriaFoiDecisiva(
    PlanoTurno vencedor,
    Map<PlanoTurno, Avaliacao> avaliados,
  ) {
    var houveSinal = false;
    for (final a in avaliados.values) {
      if ((a.features[featureMemoriaDescarteParceiro] ?? 0) != 0) {
        houveSinal = true;
        break;
      }
    }
    if (!houveSinal) return false;

    PlanoTurno? semSinal;
    var melhorScore = 0.0;
    for (final e in avaliados.entries) {
      final s = e.value.score -
          (e.value.features[featureMemoriaDescarteParceiro] ?? 0);
      if (semSinal == null ||
          _vence(s, melhorScore, e.key.assinatura, semSinal.assinatura)) {
        semSinal = e.key;
        melhorScore = s;
      }
    }
    return semSinal != vencedor;
  }

  /// IMPASSE DOCUMENTADO (§2). Só restam curingas descartáveis: a política
  /// aprovada proíbe mandá-los ao lixo, e o turno não pode ficar pendurado.
  ///
  /// A saída NÃO é silenciosa. A decisão vem marcada com `impasse = true` e com
  /// o diagnóstico completo; quem consome é obrigado a registrar. A carta
  /// escolhida é a de MENOR perda estratégica (um "2" antes de um Joker), e
  /// segue sendo aplicada pela autoridade como qualquer outra.
  DecisaoBot _impasseCuringa(
    EstadoJogo estado,
    int assento,
    String assinatura,
    ResultadoGeracao ger,
  ) {
    final mao = estado.maos[assento];
    final ordenada = [...mao]..sort((a, b) {
        final va = a.valor == 'JOKER' ? 1 : 0;
        final vb = b.valor == 'JOKER' ? 1 : 0;
        if (va != vb) return va - vb; // "2" antes de Joker
        final pa = valorCarta(a), pb = valorCarta(b);
        if (pa != pb) return pa - pb;
        return a.id.compareTo(b.id);
      });
    for (final c in ordenada) {
      final r = aplicarLegal(estado, assento, Descartar(c.id), spec);
      if (!r.legal) continue;
      return DecisaoBot(
        acoes: <Acao>[Descartar(c.id)],
        razao: Razao.impasseDescarteSoCuringa,
        candidatosConsiderados: ger.planos.length,
        truncado: ger.truncado,
        impasse: true,
        diagnosticoImpasse:
            'todas as cartas legalmente descartáveis do assento $assento são '
            'curinga; a política da OS proíbe descartar 2/Joker. Descartado '
            '${c.valor}${c.naipe == null ? '' : ' de ${c.naipe}'} (${c.id}) '
            'como menor perda, com o caso registrado para decisão.',
        assinaturaDecisao: assinatura,
      );
    }
    return DecisaoBot(
      acoes: const <Acao>[],
      razao: Razao.semPlanoLegal,
      truncado: ger.truncado,
      assinaturaDecisao: assinatura,
    );
  }
}
