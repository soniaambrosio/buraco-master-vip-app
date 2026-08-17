// OS — INTELIGÊNCIA ESTRATÉGICA DO BOT V1 — §1 PartnerModel.
//
// A função de utilidade é DA DUPLA. Este modelo responde, só com informação
// pública, o que a dupla precisa do bot neste momento:
//   • o que os jogos públicos da dupla pedem (extensão legal e adjacência);
//   • quantas cartas o parceiro tem (contagem é pública);
//   • se o parceiro acabou de pegar o morto e precisa de tempo para organizar;
//   • se a dupla já tem canastra que libera batida.
//
// É PROIBIDO inferir a mão oculta do parceiro. Nada aqui lê carta que não esteja
// na mesa: a `VisaoInformacao` nem sequer carrega as mãos alheias.
//
// SINAL DE DESCARTE DO PARCEIRO: LIGADO na OS PROVENIÊNCIA DE DESCARTES V1.
// A autoridade passou a registrar quem descartou cada carta no instante do
// descarte, e `VisaoInformacao.descartesPublicos` transporta esse registro. O
// modelo responde `parceiroDescartou` com o FATO, não com uma dedução: quando a
// autoridade não tem registro (mão nova, lixo de fixture, snapshot antigo), a
// resposta é `false` por AUSÊNCIA DE PROVA — nunca por posição na pilha.
//
// A OS não recalibrou nada. O sinal existe e responde a verdade; nenhum peso e
// nenhum avaliador foram tocados para consumi-lo.
import '../rules/estado.dart';
import '../rules/morto/morto.dart' show duplaPodeBater;
import '../rules/rule_spec.dart';
import 'leitura_meld.dart';
import 'visao_informacao.dart';

class ModeloParceiro {
  final VisaoInformacao visao;
  final RuleSpec spec;

  /// Cartas na mão do parceiro (contagem pública).
  final int cartasDoParceiro;

  /// O parceiro está CARREGADO — muitas cartas, virariam desconto numa batida.
  final bool parceiroCarregado;

  /// O parceiro acabou de pegar o morto (mão cheia, ainda desorganizada).
  final bool parceiroReorganizandoMorto;

  /// A dupla já tem canastra que LIBERA a batida.
  final bool duplaPodeBaterAgora;

  /// A dupla ainda tem morto a pegar.
  final bool mortoPendenteDaDupla;

  ModeloParceiro._({
    required this.visao,
    required this.spec,
    required this.cartasDoParceiro,
    required this.parceiroCarregado,
    required this.parceiroReorganizandoMorto,
    required this.duplaPodeBaterAgora,
    required this.mortoPendenteDaDupla,
  });

  /// A partir de quantas cartas o parceiro é considerado CARREGADO. Espelha o
  /// limiar de prudência já usado pelo robô legado (seção 24 da diretriz).
  static const int limiarCarregado = 8;

  factory ModeloParceiro.observar(VisaoInformacao v, RuleSpec spec) {
    final cartas = v.cartasDoParceiro;
    // "Acabou de pegar o morto" é observável sem ler carta nenhuma: a dupla
    // marcou o morto como pego E o parceiro está com a mão de 11+.
    final reorganizando = v.mortoPegoPropria && cartas >= 11;
    return ModeloParceiro._(
      visao: v,
      spec: spec,
      cartasDoParceiro: cartas,
      parceiroCarregado: cartas > limiarCarregado,
      parceiroReorganizandoMorto: reorganizando,
      duplaPodeBaterAgora: duplaPodeBater(
        EstadoJogoParcial.paraConsultaDeBatida(v),
        v.dupla,
        spec,
      ),
      mortoPendenteDaDupla: v.mortoDisponivelParaDupla,
    );
  }

  // MEMÓRIA por carta: os jogos públicos não mudam durante uma decisão, e cada
  // consulta roda o validador canônico uma vez por jogo exposto.
  final Map<String, bool> _cacheUtil = {};
  final Map<String, bool> _cacheAdjacente = {};

  /// ÍNDICE da memória pública do parceiro: as chaves `valor|naipe` que ele
  /// dispensou nesta mão.
  ///
  /// Construído SOB DEMANDA e derivado exclusivamente de
  /// `visao.descartesPublicos` — a mesma fonte, sem atalho para o estado do
  /// motor e sem estado global. Nasce e morre com o `ModeloParceiro`, isto é,
  /// com a decisão: nada atravessa turnos.
  ///
  /// Existe por custo: o avaliador consulta o sinal uma vez POR PLANO, e a
  /// busca chega a centenas de planos num turno. A varredura linear do
  /// histórico multiplicava planos × descartes; o índice a torna uma consulta
  /// de conjunto, sem mudar nem a semântica nem o contrato público.
  Set<String>? _indiceParceiro;

  static String _chaveEstrategica(CartaSnapshot c) =>
      '${c.valor}|${c.naipe ?? "jk"}';

  Set<String> get _memoriaDoParceiro => _indiceParceiro ??= {
        for (final d in visao.descartesPublicos)
          if (d.assento == visao.parceiro) _chaveEstrategica(d.carta)
      };

  /// A carta ESTENDE um jogo público da dupla? (utilidade imediata)
  bool utilAosJogosDaDupla(CartaSnapshot c) => _cacheUtil.putIfAbsent(c.id, () {
        for (final m in visao.meldsProprios) {
          if (estendeMeld(m, c, spec)) return true;
        }
        return false;
      });

  /// A carta ENCOSTA num jogo público da dupla? (extensão natural futura — o
  /// que a §1 manda preservar quando o parceiro abriu uma sequência)
  bool adjacenteAosJogosDaDupla(CartaSnapshot c) =>
      _cacheAdjacente.putIfAbsent(c.id, () {
        for (final m in visao.meldsProprios) {
          if (adjacenteAoMeld(m, c, spec)) return true;
        }
        return false;
      });

  /// O parceiro descartou esta carta publicamente? Sinal de que ele não a quer.
  ///
  /// Compara por VALOR e NAIPE, não por id: para a estratégia, "o parceiro
  /// dispensou um 8♥" vale para qualquer cópia do 8♥. Quem precisar da carta
  /// exata lê `visao.descartesPublicos`, que preserva id, assento e ordem.
  ///
  /// `false` significa "não há registro de que ele tenha descartado", nunca
  /// "ele não descartou" deduzido de outra coisa.
  bool parceiroDescartou(CartaSnapshot c) =>
      _memoriaDoParceiro.contains(_chaveEstrategica(c));

  /// Bater AGORA prejudica a dupla sem necessidade? (§6 — prudência de batida)
  /// Verdadeiro quando o parceiro está carregado E nenhum adversário ameaça
  /// fechar. Contagem de cartas dos adversários é informação pública.
  bool batidaPrematura() {
    if (!parceiroCarregado) return false;
    return !ameacaAdversariaImediata();
  }

  /// Algum adversário está prestes a fechar? Proxy PÚBLICO: mão curta, ou a
  /// dupla adversária já pegou o morto e tem canastra que libera a batida.
  bool ameacaAdversariaImediata() {
    if (visao.menorMaoAdversaria <= 3) return true;
    if (!visao.mortoPegoAdversaria) return false;
    for (final m in visao.meldsAdversarios) {
      if (ehCanastra(m, spec)) return true;
    }
    return false;
  }
}

/// Adaptador MÍNIMO para consultar `duplaPodeBater` — a autoridade canônica de
/// "esta canastra libera a batida" — usando SÓ os jogos públicos da visão.
///
/// Existe para não duplicar a regra de batida dentro do bot. Constrói um
/// `EstadoJogo` de consulta cujas zonas ocultas estão VAZIAS: nenhuma mão,
/// nenhum monte, nenhum morto. Se algum dia alguém tentar tirar daqui
/// informação oculta, não vai encontrar nada — não há nada para encontrar.
class EstadoJogoParcial {
  EstadoJogoParcial._();

  static EstadoJogo paraConsultaDeBatida(VisaoInformacao v) => EstadoJogo(
        modalidade: v.modalidade,
        metaPontos: v.metaPontos,
        monte: const [],
        lixo: const [],
        mortos: const [],
        maos: const [[], [], [], []],
        jogosDupla: {
          v.dupla: v.meldsProprios,
          v.duplaAdversaria: v.meldsAdversarios,
        },
        rodadasVulneravel: {
          v.dupla: v.rodadasVulneravelPropria,
          v.duplaAdversaria: v.rodadasVulneravelAdversaria,
        },
        primeiraBaixadaFeita: {
          v.dupla: v.abriuPropria,
          v.duplaAdversaria: v.abriuAdversaria,
        },
        vez: v.vez,
        mortoPego: {
          v.dupla: v.mortoPegoPropria,
          v.duplaAdversaria: v.mortoPegoAdversaria,
        },
      );
}
