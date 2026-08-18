// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — §5 CandidateGenerator.
//
// Monta PLANOS COMPLETOS DE TURNO, não decisões isoladas. Um plano da fase de
// jogo é `(baixada atômica opcional) + (descarte)`, e é comparado pelo ESTADO
// FINAL — inclusive pelo descarte que sobra. Foi para isso que ele existe: uma
// baixada legal que obriga a largar a carta perigosa tem de PERDER para não
// baixar (§4), e isso só aparece se o descarte fizer parte do plano.
//
// SUBORDINAÇÃO TOTAL À AUTORIDADE (§ princípio arquitetural):
//   • quem diz se um meld é válido é `validarJogoMesa`;
//   • quem diz se a baixada/descarte é legal é `aplicarLegal`;
//   • quem estabiliza morto/batida é a mesma sequência do motor.
// Este arquivo ENUMERA e PODA; ele nunca conclui que algo é legal por conta
// própria. Todo plano devolvido já passou pela autoridade, e o executor manda
// as ações de volta para ela na hora de aplicar de verdade.
//
// INFORMAÇÃO (§7): o plano guarda a `VisaoInformacao` MASCARADA do estado final,
// nunca o `EstadoJogo` cru. O estado cru existe só dentro deste arquivo, como
// sandbox de simulação, e morre aqui. Quando o plano PEGA O MORTO, a visão final
// nasce com a mão OCULTA: pontuar as 11 cartas novas seria ler o futuro.
//
// CAPS NUNCA SILENCIOSOS: a busca tem orçamento de nós e um corte de largura na
// avaliação completa. Se qualquer um dos dois morder, o resultado vem com
// `truncado = true` e o executor carimba `Razao.buscaTruncada` no rastro.
import '../rules/acoes.dart';
import '../rules/estado.dart';
import '../rules/gerador/gerador.dart' show aplicarLegal;
import '../rules/meld/meld_validator.dart';
import '../rules/pontuacao_canonica.dart' show valorCarta;
import '../rules/rule_spec.dart';
import 'analise_mao.dart';
import 'leitura_meld.dart';
import 'orcamento_busca.dart';
import 'pesos.dart';
import 'risco_descarte.dart';
import 'visao_informacao.dart';

/// Um plano completo de turno já VALIDADO pela autoridade canônica.
class PlanoTurno {
  /// Baixada atômica (jogos novos + extensões). `null` = não baixar nada.
  final Baixar? baixada;

  /// Descarte que encerra o turno. `null` quando o plano zera a mão (o turno
  /// termina em morto direto ou batida, e não há descarte).
  final Descartar? descarte;

  /// Visão MASCARADA do estado final. Nunca há `EstadoJogo` cru aqui.
  final VisaoInformacao visaoFinal;

  /// Carta descartada (cópia; `null` quando não há descarte).
  final CartaSnapshot? cartaDescartada;

  // ---- fatos do plano (todos derivados de informação pública/própria) ----
  final bool pegouMorto;
  final bool bateu;
  final bool abriu;
  final bool sujeitoAoMinimo;
  final int pontosBaixados;
  final int cartasExpostasEmJogosNovos;
  final int curingasComprometidos;
  final int curingasGratuitos;
  final bool sujaJogoLimpo;
  final int canastrasNovas;
  final int canastrasLimpasNovas;
  final int progressoCanastra;

  /// BECO SEM SAÍDA do motor: a baixada é legal, mas depois dela NENHUM descarte
  /// é legal (sobrou 1 carta, sem morto a pegar e sem canastra para bater) — e o
  /// turno termina sem passar a vez.
  ///
  /// O plano existe porque às vezes ele é a única forma de a dupla ABRIR sob o
  /// mínimo de vulnerabilidade, e era o que o C10 já fazia. Mas ele carrega um
  /// custo pesado no avaliador: só vence quando o ganho é grande demais para
  /// recusar. O buraco em si é do motor, não do bot — está registrado no
  /// relatório para decisão.
  final bool turnoIncompleto;

  const PlanoTurno({
    required this.baixada,
    required this.descarte,
    required this.visaoFinal,
    required this.cartaDescartada,
    required this.pegouMorto,
    required this.bateu,
    required this.abriu,
    required this.sujeitoAoMinimo,
    required this.pontosBaixados,
    required this.cartasExpostasEmJogosNovos,
    required this.curingasComprometidos,
    required this.curingasGratuitos,
    required this.sujaJogoLimpo,
    required this.canastrasNovas,
    required this.canastrasLimpasNovas,
    required this.progressoCanastra,
    this.turnoIncompleto = false,
  });

  /// Ações na ordem em que a autoridade deve aplicá-las.
  List<Acao> get acoes => <Acao>[?baixada, ?descarte];

  /// GANHO DECISIVO (§3): os únicos desfechos que justificam comprometer
  /// curinga ou sujar um jogo limpo. Fechar canastra NÃO entra: fechar uma
  /// canastra SUJA às custas de uma limpa em formação é exatamente a troca que
  /// a diretriz chama de burrice.
  bool get ganhoDecisivo => pegouMorto || bateu || (abriu && sujeitoAoMinimo);

  /// Assinatura semântica estável (desempate determinístico).
  String get assinatura {
    final b = baixada == null ? '-' : _sigBaixar(baixada!);
    final d = descarte?.carta ?? '-';
    return 'B[$b]D[$d]';
  }

  static String _sigBaixar(Baixar b) {
    final js = [
      for (final j in b.jogosNovos) (List<String>.from(j)..sort()).join('-')
    ]..sort();
    final es = [
      for (final e in b.extensoes)
        '${e.indiceJogo}:${(List<String>.from(e.cartas)..sort()).join('-')}'
    ]..sort();
    return '${js.join('|')}/${es.join('|')}';
  }
}

/// Resultado da geração: os planos + a evidência de cobertura.
class ResultadoGeracao {
  final List<PlanoTurno> planos;

  /// A busca bateu o orçamento OU o corte de largura. Nunca silencioso.
  final bool truncado;

  /// Nós visitados (instrumentação, sem teto semântico).
  final int nos;

  /// TODAS as cartas legalmente descartáveis eram curinga (§2). O executor
  /// trata isso como IMPASSE explícito, não como permissão implícita.
  final bool impasseDescarteSoCuringa;

  const ResultadoGeracao({
    required this.planos,
    required this.truncado,
    required this.nos,
    required this.impasseDescarteSoCuringa,
  });
}

/// Uma unidade de baixada candidata: jogo novo OU extensão de jogo exposto.
class _Unidade {
  final List<CartaId>? jogoNovo;
  final Extensao? extensao;
  final Set<CartaId> ids;

  /// A unidade suja um jogo que estava LIMPO (curinga numa sequência sem curinga).
  final bool sujaLimpo;

  const _Unidade.jogo(List<CartaId> j, this.ids, this.sujaLimpo)
      : jogoNovo = j,
        extensao = null;
  const _Unidade.ext(Extensao e, this.ids, this.sujaLimpo)
      : jogoNovo = null,
        extensao = e;

  int? get indiceExt => extensao?.indiceJogo;
}

class GeradorPlanos {
  final RuleSpec spec;
  final ConfiguracaoBot cfg;

  /// OS 4 — CONTADOR ÚNICO da decisão, criado pelo `ExecutorBot` e passado
  /// para cá. Antes o gerador guardava o seu próprio `_nos`, um contador
  /// PARALELO: a fase de compra gastava trabalho que este número não via.
  /// Quem não passa orçamento recebe um ilimitado — o comportamento histórico,
  /// preservado para teste e para a comparação com a base.
  final OrcamentoBuscaBot orcamento;

  bool _truncado = false;

  GeradorPlanos(this.spec, this.cfg, {OrcamentoBuscaBot? orcamento})
      : orcamento = orcamento ?? OrcamentoBuscaBot(cfg.limitesBusca);

  /// Modelo de risco do turno corrente (memoizado), criado em `planosDeJogo`.
  /// Serve só ao corte de largura do descarte — a pontuação de verdade é do
  /// avaliador, que tem o seu próprio modelo.
  late ModeloAdversario _risco;

  /// Gasta UM nó da fase indicada. `true` quando não há mais orçamento.
  bool _semOrcamento(FaseBusca fase) {
    if (orcamento.gastarNo(fase)) return false;
    _truncado = true;
    return true;
  }

  /// DFS STREAMING de subconjuntos que formam meld válido com `base`.
  ///
  /// Mesma poda estrutural da autoridade (`autoridade_canonica._dfsSelecao`):
  /// naturais nunca podem passar a ter 2+ naipes E 2+ valores ao mesmo tempo
  /// (aí não é nem sequência nem trinca), e o número de JOKERs respeita a spec.
  /// A poda nunca descarta um meld legal; o validador canônico é o juiz final.
  void _dfsSelecao(
    List<CartaSnapshot> base,
    List<CartaSnapshot> pool,
    int minSel,
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
      if (_semOrcamento(FaseBusca.enumeracaoUnidades)) return;
      if (esc.length >= minSel) {
        final cartas = <CartaSnapshot>[...base, for (final i in esc) pool[i]];
        if (validarJogoMesa(cartas, spec).valido) onOk(List<int>.from(esc));
      }
      for (var i = start; i < n; i++) {
        final c = pool[i];
        final ehJoker = c.valor == 'JOKER';
        if (ehJoker && jokers >= spec.maxCuringasPorSequencia) continue;
        var nn = naipes, nv = valores;
        if (!ehCuringaEstrategico(c)) {
          nn = {...naipes, c.naipe!};
          nv = {...valores, c.valor};
          if (nn.length >= 2 && nv.length >= 2) continue;
        }
        esc.add(i);
        rec(i + 1, nn, nv, jokers + (ehJoker ? 1 : 0));
        esc.removeLast();
        if (_truncado) return;
      }
    }

    rec(0, {...naipes0}, {...valores0}, jokers0);
  }

  /// Gera os planos completos da FASE DE JOGO para `assento`.
  ResultadoGeracao planosDeJogo(EstadoJogo estado, int assento) {
    // O orçamento NÃO é reiniciado aqui: ele nasce com a decisão, no executor,
    // e atravessa compra e jogo. Zerá-lo por fase devolveria o defeito que
    // esta OS corrige — cada fase gastando um teto próprio, sem ninguém
    // olhando o total.
    _truncado = orcamento.esgotado;

    final visaoInicial = VisaoInformacao.doEstado(estado, assento);
    _risco = ModeloAdversario(visaoInicial, spec);
    final mao = estado.maos[assento];
    final meldsProprios = visaoInicial.meldsProprios;

    // ---- unidades: jogos NOVOS possíveis a partir da mão ----
    final unidades = <_Unidade>[];
    _dfsSelecao(const [], mao, 3, (esc) {
      final cartas = [for (final i in esc) mao[i]];
      final ids = <CartaId>[for (final c in cartas) c.id];
      unidades.add(_Unidade.jogo(ids, ids.toSet(), false));
    });

    // ---- unidades: EXTENSÕES dos jogos já expostos da dupla ----
    for (var k = 0; k < meldsProprios.length; k++) {
      final alvo = meldsProprios[k];
      final alvoLimpo = ehLimpoAindaQuePequeno(alvo, spec);
      _dfsSelecao(alvo, mao, 1, (esc) {
        final cartas = [for (final i in esc) mao[i]];
        final ids = <CartaId>[for (final c in cartas) c.id];
        // Sujar um jogo LIMPO com curinga: a unidade é marcada, não descartada
        // aqui. O filtro por ganho decisivo acontece no nível do PLANO — usar o
        // curinga para pegar o morto ou bater continua permitido (§3).
        final suja =
            alvoLimpo && cartas.any(ehCuringaEstrategico);
        unidades.add(_Unidade.ext(Extensao(k, ids), ids.toSet(), suja));
      });
    }

    // ---- combinações DISJUNTAS de unidades (inclui o conjunto VAZIO) ----
    final baixadas = <Baixar?>[null];
    final vistos = <String>{};
    final selec = <_Unidade>[];
    final cartasUsadas = <CartaId>{};
    final indicesUsados = <int>{};

    void combinar(int start) {
      if (_semOrcamento(FaseBusca.combinacaoBaixadas)) return;
      if (selec.isNotEmpty) {
        final b = Baixar(
          jogosNovos: [
            for (final u in selec)
              if (u.jogoNovo != null) u.jogoNovo!
          ],
          extensoes: [
            for (final u in selec)
              if (u.extensao != null) u.extensao!
          ],
        );
        if (vistos.add(PlanoTurno._sigBaixar(b))) baixadas.add(b);
      }
      for (var k = start; k < unidades.length; k++) {
        final u = unidades[k];
        if (u.ids.any(cartasUsadas.contains)) continue;
        // Duas extensões do MESMO jogo na mesma transação: a autoridade agrupa e
        // revalida, mas enumerar as duas ordens só produziria duplicata.
        if (u.indiceExt != null && indicesUsados.contains(u.indiceExt)) continue;
        selec.add(u);
        cartasUsadas.addAll(u.ids);
        if (u.indiceExt != null) indicesUsados.add(u.indiceExt!);
        combinar(k + 1);
        if (u.indiceExt != null) indicesUsados.remove(u.indiceExt!);
        cartasUsadas.removeAll(u.ids);
        selec.removeLast();
        if (_truncado) return;
      }
    }

    combinar(0);

    // ---- corte de largura: pré-score barato, cap explícito ----
    final ordenadas = _ordenarPorPreScore(baixadas, estado, assento);
    List<Baixar?> selecionadas = ordenadas;
    if (ordenadas.length > cfg.maxBaixadasAvaliadas) {
      selecionadas = ordenadas.take(cfg.maxBaixadasAvaliadas).toList();
      // "Não baixar" é sempre avaliado: é a alternativa que a §4 existe para
      // proteger, e cortá-la por largura enviesaria a comparação inteira.
      if (!selecionadas.contains(null)) selecionadas.add(null);
      _truncado = true;
    }

    // ---- expansão em PLANOS completos (baixada + descarte) ----
    final planos = <PlanoTurno>[];
    var impasse = false;
    for (final b in selecionadas) {
      // A expansao NAO consome o orcamento de nos. Ela consome largura (o cap
      // de baixadas) e, mais adiante, o orcamento de PLANOS AVALIADOS. Cobrar
      // nos aqui fazia a enumeracao — que sempre gasta o teto primeiro numa
      // mao grande — impedir que qualquer plano completo nascesse.
      if (!orcamento.podeExpandir()) {
        _truncado = true;
        break;
      }
      final r = _expandir(estado, assento, b, visaoInicial);
      planos.addAll(r.planos);
      impasse = impasse || r.impasse;
    }

    // §3 — PROTEÇÃO DA LIMPA como FILTRO, não como peso. Sujar com curinga um
    // jogo que estava limpo só é alternativa quando o plano pega o morto, bate
    // ou cumpre o mínimo de vulnerabilidade. Fora disso a alternativa nem chega
    // a ser pontuada: "por conveniência" deixa de existir como opção.
    final filtrados = cfg.regras.protegeCanastraLimpa
        ? [
            for (final p in planos)
              if (!p.sujaJogoLimpo || p.ganhoDecisivo) p
          ]
        : planos;

    // Ordem estável: a decisão não pode depender da ordem de enumeração.
    filtrados.sort((a, z) => a.assinatura.compareTo(z.assinatura));

    return ResultadoGeracao(
      planos: filtrados,
      truncado: _truncado,
      nos: orcamento.nos,
      // Só é impasse de verdade se NENHUM plano legal sobrou.
      impasseDescarteSoCuringa: impasse && filtrados.isEmpty,
    );
  }

  /// Pré-score barato para o corte de largura: prioriza o que a rodada precisa
  /// (esvaziar a mão) e depois o volume de pontos NATURAIS.
  ///
  /// "Naturais" é o detalhe que importa: rankear por pontos brutos põe todo
  /// plano que queima o Joker (50 pontos sozinho) no topo da fila, e os planos
  /// naturais equivalentes caem fora da largura antes mesmo de serem pontuados.
  /// O corte passaria a decidir a favor do curinga sem que peso nenhum dissesse
  /// isso. Aqui o curinga não conta pontos para ENTRAR na avaliação; o custo
  /// dele continua sendo cobrado pelo avaliador, que é quem decide.
  List<Baixar?> _ordenarPorPreScore(
      List<Baixar?> baixadas, EstadoJogo estado, int assento) {
    final mao = estado.maos[assento];
    int cartasDe(Baixar? b) => b == null
        ? 0
        : b.jogosNovos.fold<int>(0, (s, j) => s + j.length) +
            b.extensoes.fold<int>(0, (s, e) => s + e.cartas.length);
    // O mapa da mao e construido UMA vez. Antes ele nascia dentro de
    // pontosDe, isto e, a cada comparacao do sort: com milhares de baixadas
    // isso multiplicava o custo da ordenacao por |mao| sem mudar o resultado.
    final porIdMao = {for (final c in mao) c.id: c};
    int pontosDe(Baixar? b) {
      if (b == null) return 0;
      final porId = porIdMao;
      var p = 0;
      void somar(String id) {
        final c = porId[id]!;
        if (!ehCuringaEstrategico(c)) p += valorCarta(c);
      }

      for (final j in b.jogosNovos) {
        for (final id in j) {
          somar(id);
        }
      }
      for (final e in b.extensoes) {
        for (final id in e.cartas) {
          somar(id);
        }
      }
      return p;
    }

    final lista = [...baixadas];
    lista.sort((a, z) {
      // 1) esvaziar a mão (morto/batida) vem primeiro
      final ea = cartasDe(a) >= mao.length ? 1 : 0;
      final ez = cartasDe(z) >= mao.length ? 1 : 0;
      if (ea != ez) return ez - ea;
      // 2) mais pontos (o mínimo de vulnerabilidade é medido em pontos)
      final pa = pontosDe(a), pz = pontosDe(z);
      if (pa != pz) return pz - pa;
      // 3) mais cartas
      final ca = cartasDe(a), cz = cartasDe(z);
      if (ca != cz) return cz - ca;
      // 4) desempate determinístico
      final sa = a == null ? '' : PlanoTurno._sigBaixar(a);
      final sz = z == null ? '' : PlanoTurno._sigBaixar(z);
      return sa.compareTo(sz);
    });
    return lista;
  }

  /// Aplica a baixada candidata pela AUTORIDADE e expande os descartes legais.
  ({List<PlanoTurno> planos, bool impasse}) _expandir(
    EstadoJogo estado,
    int assento,
    Baixar? baixada,
    VisaoInformacao visaoInicial,
  ) {
    var pos = estado;
    if (baixada != null) {
      final r = aplicarLegal(estado, assento, baixada, spec);
      // Recusa de REGRA: o candidato simplesmente não existe. Nada de "quase
      // legal" — a autoridade é quem diz, e ela disse não.
      if (!r.legal) return (planos: const <PlanoTurno>[], impasse: false);
      pos = r.proximoEstado!;
    }

    final dupla = duplaDoAssento(assento);
    var pegouMorto = false;
    var bateu = false;

    // ---- a baixada ZEROU a mão: o turno termina em morto DIRETO ou BATIDA ----
    // Mesma estabilização do motor (`_rodarEestabiliza`), pela mesma autoridade.
    if (pos.maos[assento].isEmpty) {
      final mortoDisp =
          !(pos.mortoPego[dupla] ?? false) && pos.mortos.isNotEmpty;
      final r = aplicarLegal(
          pos, assento, mortoDisp ? const PegarMorto() : const Bater(), spec);
      if (!r.legal) return (planos: const <PlanoTurno>[], impasse: false);
      pos = r.proximoEstado!;
      pegouMorto = mortoDisp;
      bateu = !mortoDisp;
      return (
        planos: <PlanoTurno>[
          _montar(
            estado: estado,
            assento: assento,
            baixada: baixada,
            descarte: null,
            cartaDescartada: null,
            pos: pos,
            pegouMorto: pegouMorto,
            bateu: bateu,
            visaoInicial: visaoInicial,
          )
        ],
        impasse: false,
      );
    }

    // ---- descartes candidatos ----
    final maoPos = pos.maos[assento];
    final naturais = [
      for (final c in maoPos)
        if (!ehCuringaEstrategico(c)) c
    ];
    // §2 — POLÍTICA APROVADA: 2 e Joker não vão ao lixo. Não é peso: é filtro.
    final pool = cfg.regras.proibeDescartarCuringa ? naturais : maoPos;

    // CORTE DE LARGURA do descarte, com os MESMOS sinais da pontuação final:
    // menor dano estrutural primeiro, depois menor risco, depois mais pontos
    // aliviados. O que cai fora é a cauda das cartas obviamente piores — e o
    // corte é registrado como truncamento, nunca engolido.
    final analise = AnaliseMao.analisar(maoPos, spec);
    final ordenados = [...pool]..sort((a, b) {
        final da = analise.dano(a.id), db = analise.dano(b.id);
        if (da != db) return da - db;
        final ra = _risco.avaliar(a).nota, rb = _risco.avaliar(b).nota;
        if (ra != rb) return ra - rb;
        final pa = valorCarta(a), pb = valorCarta(b);
        if (pa != pb) return pb - pa;
        return a.id.compareTo(b.id);
      });
    var candidatosDescarte = ordenados;
    if (ordenados.length > cfg.maxDescartesPorBaixada) {
      candidatosDescarte = ordenados.take(cfg.maxDescartesPorBaixada).toList();
      _truncado = true;
    }

    final planos = <PlanoTurno>[];
    for (final c in candidatosDescarte) {
      final r = aplicarLegal(pos, assento, Descartar(c.id), spec);
      if (!r.legal) continue;
      var fim = r.proximoEstado!;
      var m = pegouMorto, b = bateu;
      // Descarte que esvaziou a mão: morto INDIRETO (a autoridade decide).
      if (fim.fase == FaseTurno.mortoPendente) {
        final rm = aplicarLegal(
            fim, assento, const PegarMorto(viaDescarte: true), spec);
        if (!rm.legal) continue;
        fim = rm.proximoEstado!;
        m = true;
      } else if (fim.rodadaEncerrada) {
        b = true;
      }
      planos.add(_montar(
        estado: estado,
        assento: assento,
        baixada: baixada,
        descarte: Descartar(c.id),
        cartaDescartada: c.copia(),
        pos: fim,
        pegouMorto: m,
        bateu: b,
        visaoInicial: visaoInicial,
      ));
    }

    // BECO SEM SAÍDA: a baixada passou, mas NENHUM descarte é legal depois dela
    // (sobrou 1 carta, sem morto a pegar e sem canastra para bater). Em vez de
    // sumir com o candidato — o que faria o robô nunca abrir sob o mínimo —, o
    // plano é emitido MARCADO, e o avaliador cobra caro por ele.
    if (planos.isEmpty &&
        baixada != null &&
        maoPos.isNotEmpty &&
        naturais.isNotEmpty) {
      planos.add(_montar(
        estado: estado,
        assento: assento,
        baixada: baixada,
        descarte: null,
        cartaDescartada: null,
        pos: pos,
        pegouMorto: false,
        bateu: false,
        visaoInicial: visaoInicial,
        turnoIncompleto: true,
      ));
    }

    // Impasse (§2): existia descarte legal, mas TODO ele era curinga.
    final impasse = planos.isEmpty &&
        cfg.regras.proibeDescartarCuringa &&
        naturais.isEmpty &&
        maoPos.isNotEmpty;
    return (planos: planos, impasse: impasse);
  }

  PlanoTurno _montar({
    required EstadoJogo estado,
    required int assento,
    required Baixar? baixada,
    required Descartar? descarte,
    required CartaSnapshot? cartaDescartada,
    required EstadoJogo pos,
    required bool pegouMorto,
    required bool bateu,
    required VisaoInformacao visaoInicial,
    bool turnoIncompleto = false,
  }) {
    final porId = {for (final c in estado.maos[assento]) c.id: c};
    final jogosNovos = baixada?.jogosNovos ?? const <List<CartaId>>[];
    final extensoes = baixada?.extensoes ?? const <Extensao>[];

    var pontos = 0;
    var curingas = 0;
    var expostas = 0;
    for (final j in jogosNovos) {
      expostas += j.length;
      for (final id in j) {
        final c = porId[id]!;
        pontos += valorCarta(c);
        if (ehCuringaEstrategico(c)) curingas++;
      }
    }
    for (final e in extensoes) {
      for (final id in e.cartas) {
        final c = porId[id]!;
        pontos += valorCarta(c);
        if (ehCuringaEstrategico(c)) curingas++;
      }
    }

    // CURINGA GRATUITO (§3): a combinação fecharia sem ele. Medido pelo próprio
    // validador — tira os curingas do jogo novo e pergunta se ainda é meld.
    var gratuitos = 0;
    for (final j in jogosNovos) {
      final cartas = [for (final id in j) porId[id]!];
      final semCuringa = [
        for (final c in cartas)
          if (!ehCuringaEstrategico(c)) c
      ];
      if (semCuringa.length == cartas.length) continue;
      if (semCuringa.length >= 3 && validarJogoMesa(semCuringa, spec).valido) {
        gratuitos += cartas.length - semCuringa.length;
      }
    }

    // Sujou um jogo que estava limpo?
    var sujou = false;
    for (final e in extensoes) {
      final alvo = visaoInicial.meldsProprios[e.indiceJogo];
      if (!ehLimpoAindaQuePequeno(alvo, spec)) continue;
      if (e.cartas.any((id) => ehCuringaEstrategico(porId[id]!))) sujou = true;
    }

    // Canastras e progresso: contagem PÚBLICA (jogos expostos antes x depois).
    final antesMelds = visaoInicial.meldsProprios;
    final dupla = duplaDoAssento(assento);
    final depoisMelds = pos.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[];
    int contarCanastras(List<List<CartaSnapshot>> ms) =>
        ms.where((m) => ehCanastra(m, spec)).length;
    int contarLimpas(List<List<CartaSnapshot>> ms) =>
        ms.where((m) => ehCanastraLimpa(m, spec)).length;
    int progresso(List<List<CartaSnapshot>> ms) =>
        ms.fold<int>(0, (s, m) => s + (m.length >= 7 ? 7 : m.length));

    final abriu = !visaoInicial.abriuPropria && jogosNovos.isNotEmpty;
    final minimo = spec.vulnerabilidade.minimoParaDescer(
      rodadasVulneravel: visaoInicial.rodadasVulneravelPropria,
      jaAbriuNaRodada: visaoInicial.abriuPropria,
    );

    return PlanoTurno(
      baixada: baixada,
      descarte: descarte,
      // MÁSCARA: o `pos` cru morre aqui. Se o plano pegou o morto, a mão nasce
      // OCULTA — as 11 cartas novas são futuro do baralho na hora de decidir.
      visaoFinal:
          VisaoInformacao.doEstado(pos, assento, maoOculta: pegouMorto),
      cartaDescartada: cartaDescartada,
      pegouMorto: pegouMorto,
      bateu: bateu,
      abriu: abriu,
      sujeitoAoMinimo: abriu && minimo > 0,
      pontosBaixados: pontos,
      cartasExpostasEmJogosNovos: expostas,
      curingasComprometidos: curingas,
      curingasGratuitos: gratuitos,
      sujaJogoLimpo: sujou,
      canastrasNovas:
          contarCanastras(depoisMelds) - contarCanastras(antesMelds),
      canastrasLimpasNovas:
          contarLimpas(depoisMelds) - contarLimpas(antesMelds),
      progressoCanastra: progresso(depoisMelds) - progresso(antesMelds),
      turnoIncompleto: turnoIncompleto,
    );
  }
}
