// C7 — GERADOR ÚNICO de ações legais, sobre o EstadoJogo imutável. SEM
// comportamento de produção: só a suíte de testes usa isto; o motor antigo
// (class Jogo) continua ativo em runtime.
//
// Ajuste 3 (C1): a LEGALIDADE é SEMPRE decidida aqui — mesma autoridade para
// jogador e bot. A ENUMERAÇÃO completa de candidatos pode ser do bot, mas cada
// candidato é filtrado por esta MESMA função. Assim a paridade é estrutural.
//
// DUAS TRAVAS GLOBAIS (valem para gerar E para aplicar QUALQUER ação):
//   1) assento != estado.vez        -> nenhuma ação é gerada nem aplicada;
//   2) estado.rodadaEncerrada == true -> nenhuma ação é gerada nem aplicada.
//
// Escopo: este commit é o portão de turno/rodada e o roteamento único para os
// avaliadores canônicos já existentes (monte, lixo, baixar/estender, descarte,
// morto, batida). A ORDENAÇÃO de fases dentro do turno (comprar antes de
// descartar) e a enumeração combinatória de todas as baixadas possíveis ficam
// para o fluxo/bot (commits seguintes) — não são silenciosamente omitidas.
import '../estado.dart';
import '../acoes.dart';
import '../rule_spec.dart';
import '../abertura/abertura.dart';
import '../morto/morto.dart';

/// Resultado de aplicar (puro) uma ação pelo gerador único.
class ResultadoJogada {
  final bool legal;
  final String? motivo;
  final EstadoJogo? proximoEstado; // preenchido só se legal (aplicar puro)
  const ResultadoJogada({required this.legal, this.motivo, this.proximoEstado});

  factory ResultadoJogada.recusa(String motivo) =>
      ResultadoJogada(legal: false, motivo: motivo);
}

/// É a vez do assento e a rodada segue aberta? (as duas travas globais juntas)
bool ehVezDe(EstadoJogo estado, int assento) =>
    !estado.rodadaEncerrada && assento == estado.vez;

/// APLICA uma ação de forma ATÔMICA, passando pelas duas travas globais e
/// roteando para o avaliador canônico. Nunca muta o estado recebido: em caso
/// de recusa, `proximoEstado` é null; em caso de sucesso, é um novo estado.
ResultadoJogada aplicarLegal(
    EstadoJogo estado, int assento, Acao acao, RuleSpec spec) {
  // TRAVA 1 — fora da vez: nada é aplicado (checada ANTES de qualquer conteúdo).
  if (assento != estado.vez) {
    return ResultadoJogada.recusa(
        'não é a vez do assento $assento (vez = ${estado.vez})');
  }
  // TRAVA 2 — rodada encerrada: nada é aplicado.
  if (estado.rodadaEncerrada) {
    return ResultadoJogada.recusa('a rodada já foi encerrada');
  }

  if (acao is ComprarMonte) {
    if (estado.monte.isEmpty) {
      return ResultadoJogada.recusa('monte vazio: não há carta para comprar');
    }
    final prox = estado.cloneProfundo();
    final topo = prox.monte.removeLast(); // topo do monte = último
    prox.maos[assento].add(topo);
    return ResultadoJogada(legal: true, proximoEstado: prox);
  }

  if (acao is ComprarLixo) {
    final r = avaliarComprarLixo(estado, assento, spec);
    return r.valido
        ? ResultadoJogada(legal: true, proximoEstado: r.proximoEstado)
        : ResultadoJogada.recusa(r.motivo ?? 'compra do lixo ilegal');
  }

  if (acao is Baixar) {
    final r = avaliarBaixar(estado, assento, acao, spec);
    return r.valido
        ? ResultadoJogada(legal: true, proximoEstado: r.proximoEstado)
        : ResultadoJogada.recusa(r.motivo ?? 'baixada ilegal');
  }

  if (acao is Descartar) {
    final mao = estado.maos[assento];
    if (!mao.any((c) => c.id == acao.carta)) {
      return ResultadoJogada.recusa('carta não está na mão: ${acao.carta}');
    }
    final prox = estado.cloneProfundo();
    final idx = prox.maos[assento].indexWhere((c) => c.id == acao.carta);
    final carta = prox.maos[assento].removeAt(idx);
    prox.lixo.add(carta); // vai para o topo do lixo
    // Descarte encerra o turno: a vez passa ao próximo assento.
    return ResultadoJogada(
        legal: true, proximoEstado: prox.copyWith(vez: (assento + 1) % 4));
  }

  if (acao is PegarMorto) {
    final r = pegarMorto(estado, assento, viaDescarte: acao.viaDescarte);
    return r.valido
        ? ResultadoJogada(legal: true, proximoEstado: r.proximoEstado)
        : ResultadoJogada.recusa(r.motivo ?? 'não pode pegar o morto');
  }

  if (acao is Bater) {
    final r = avaliarBatida(estado, assento, spec);
    return r.valido
        ? ResultadoJogada(legal: true, proximoEstado: r.proximoEstado)
        : ResultadoJogada.recusa(r.motivo ?? 'não pode bater');
  }

  return ResultadoJogada.recusa('ação desconhecida');
}

/// LEGALIDADE pura de uma ação — a MESMA autoridade que jogador e bot usam.
/// Por construção coincide com `aplicarLegal(...).legal` (não muta o estado).
bool acaoEhLegal(
        EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
    aplicarLegal(estado, assento, acao, spec).legal;

/// GERADOR ÚNICO: as ações legais do `assento` neste `estado`. Fora da vez ou
/// com a rodada encerrada, retorna lista VAZIA (trava global). Filtra tanto as
/// ações atômicas de base quanto os `candidatos` propostos (baixadas do bot)
/// pela MESMA legalidade — daí a paridade jogador/bot.
List<Acao> gerarAcoesLegais(EstadoJogo estado, int assento, RuleSpec spec,
    {List<Acao> candidatos = const []}) {
  if (assento != estado.vez || estado.rodadaEncerrada) {
    return const <Acao>[];
  }
  final base = <Acao>[
    const ComprarMonte(),
    const ComprarLixo(),
    const PegarMorto(), // direto
    const PegarMorto(viaDescarte: true), // indireto
    const Bater(),
    for (final c in estado.maos[assento]) Descartar(c.id),
    ...candidatos, // baixadas/extensões propostas pelo jogador ou pelo bot
  ];
  return [
    for (final a in base)
      if (acaoEhLegal(estado, assento, a, spec)) a,
  ];
}
