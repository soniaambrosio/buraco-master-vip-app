// C7 — GERADOR ÚNICO de ações legais, sobre o EstadoJogo imutável. SEM
// comportamento de produção — REVISTO NO C10.
//
// C10 (parte 2): PARTICIPA DO RUNTIME LOCAL. `aplicarLegal` é a autoridade que
// aplica TODA jogada da partida real sob `MotorConfig.producao()`, para o
// jogador e para o robô. O motor antigo só decide sob rollback legado.
//
// Ajuste 3 (C1): a LEGALIDADE é SEMPRE decidida aqui — mesma autoridade para
// jogador e bot. A ENUMERAÇÃO completa de candidatos pode ser do bot, mas cada
// candidato é filtrado por esta MESMA função. Assim a paridade é estrutural.
//
// DUAS TRAVAS GLOBAIS (valem para gerar E para aplicar QUALQUER ação):
//   1) assento != estado.vez        -> nenhuma ação é gerada nem aplicada;
//   2) estado.rodadaEncerrada == true -> nenhuma ação é gerada nem aplicada.
//
// FASE DO TURNO também é regra (C7-fix). Além das duas travas globais, cada
// ação só é legal na fase correta (estado.fase):
//   compra        -> só ComprarMonte / ComprarLixo (não descarta);
//   jogo          -> Baixar/estender, Descartar, morto DIRETO, Bater;
//   mortoPendente -> um descarte esvaziou a mão e há morto: SÓ PegarMorto
//                    (viaDescarte:true) (morto indireto), depois a vez passa.
// Transições: comprar -> jogo; descarte normal -> compra (vez++); descarte que
// esvazia com morto disponível -> mortoPendente (mesma vez); morto direto ->
// jogo (mesma vez, ainda descarta); morto indireto -> compra (vez++).
//
// ESVAZIAR A MÃO É REGRA (usa podeEsvaziarMao/duplaPodeBater como autoridade
// canônica, sem duplicar a condição): QUALQUER ação que zere a mão só é legal se
// terminar num estado legal — morto a pegar OU batida. Senão a PRÓPRIA ação é
// rejeitada; nunca se cria mão vazia com a rodada aberta e sem ação legal.
//   - baixar que zera a mão: aceita só se podeEsvaziarMao (senão recusa);
//   - descarte que zera a mão: morto disponível -> mortoPendente (indireto);
//     morto já cumprido + canastra -> BATIDA (avaliarBatida); nenhum -> recusa.
//
// Escopo ainda deixado para o fluxo/bot (commits seguintes), não silenciosamente
// omitido: a enumeração COMBINATÓRIA de todas as baixadas possíveis (o bot
// propõe candidatos; a legalidade — inclusive a fase — é sempre decidida aqui).
import '../estado.dart';
import '../acoes.dart';
import '../rule_spec.dart';
import '../abertura/abertura.dart';
import '../morto/morto.dart';

/// reasonCode ESTÁVEL da recusa por ausência de conclusão legal do turno
/// (§16 da OS de encerramento). Serve à observabilidade — distingue "ação
/// genericamente inválida" e "regra de jogo violada" de "o estado resultante
/// não teria como concluir o turno". NÃO expõe informação privada do jogo:
/// é uma constante, sem carta, sem mão e sem assento.
const String reasonCodeSemConclusaoLegal =
    'acao_deixaria_turno_sem_conclusao_legal';

/// Mensagem ao JOGADOR para essa recusa. Compreensível e sem internals — o
/// cliente já trata `motivo` como texto de recusa, então não há UI nova.
const String motivoSemConclusaoLegal =
    'Essa jogada deixaria você sem uma forma válida de concluir o turno.';

/// Resultado de aplicar (puro) uma ação pelo gerador único.
class ResultadoJogada {
  final bool legal;
  final String? motivo;
  final EstadoJogo? proximoEstado; // preenchido só se legal (aplicar puro)

  /// reasonCode ESTÁVEL da recusa (observabilidade), quando houver um. Recusas
  /// genéricas de regra seguem só com `motivo` — o código existe para os casos
  /// que precisam ser distinguidos por máquina, não por texto.
  final String? codigo;

  const ResultadoJogada({
    required this.legal,
    this.motivo,
    this.proximoEstado,
    this.codigo,
  });

  factory ResultadoJogada.recusa(String motivo, {String? codigo}) =>
      ResultadoJogada(legal: false, motivo: motivo, codigo: codigo);
}

/// É a vez do assento e a rodada segue aberta? (as duas travas globais juntas)
bool ehVezDe(EstadoJogo estado, int assento) =>
    !estado.rodadaEncerrada && assento == estado.vez;

/// INVARIANTE DE ENCERRAMENTO LEGAL DO TURNO.
///
/// Um estado em que o turno segue ABERTO (rodada aberta e vez ainda no mesmo
/// assento) precisa admitir ao menos UMA transição legal até um desfecho
/// canônico: descarte válido, batida, tomada do morto, encerramento da
/// mão/partida, ou passagem da vez. Um estado sem nenhuma delas é
/// operacionalmente MORTO — a partida trava com a vez parada.
///
/// Isto GENERALIZA a regra do esvaziamento que já existia. "Esvaziar é regra"
/// cobria só o caso mão == 0; o beco real acontece em mão == 1, quando a única
/// carta não tem descarte legal (sem morto a pegar e sem canastra para bater).
/// Os dois são o mesmo defeito: aceitar uma mutação sem verificar se o turno
/// ainda pode terminar.
///
/// TERMINAÇÃO: a verificação avalia as continuações com o próprio invariante
/// DESLIGADO (`_verificarConclusao: false`), portanto há exatamente UM nível —
/// nunca recursão infinita. Um nível basta e é COMPLETO: toda continuação
/// possível a partir de mão ≤ 1 esvazia a mão, e esvaziar já é decidido por
/// `podeEsvaziarMao`/`avaliarBatida` sem depender deste invariante. Com mão ≥ 2
/// algum descarte é sempre legal, então a questão nem se coloca.
bool existeConclusaoLegalDoTurno(
    EstadoJogo estado, int assento, RuleSpec spec) {
  // Desfechos canônicos JÁ alcançados: a mão encerrou, ou a vez passou.
  if (estado.rodadaEncerrada) return true;
  if (estado.vez != assento) return true;

  // Qualquer descarte legal conclui o turno.
  for (final c in estado.maos[assento]) {
    if (_aplicar(estado, assento, Descartar(c.id), spec, false).legal) {
      return true;
    }
  }
  // Mão vazia na fase de jogo: morto DIRETO/INDIRETO ou batida fecham o turno.
  for (final a in const <Acao>[
    PegarMorto(),
    PegarMorto(viaDescarte: true),
    Bater(),
  ]) {
    if (_aplicar(estado, assento, a, spec, false).legal) return true;
  }
  // Última carta que COMPLETA uma canastra por EXTENSÃO: aí esvaziar passa a
  // ser legal e a batida fecha o turno. É jogada legítima — barrá-la seria
  // quebrar o jogo em nome do invariante. (Meld NOVO precisa de 3 cartas, logo
  // é impossível com uma só; por isso só extensões entram aqui.)
  if (estado.maos[assento].length == 1) {
    final dupla = assento % 2 == 0 ? 'nos' : 'eles';
    final id = estado.maos[assento].single.id;
    final melds = estado.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[];
    for (var k = 0; k < melds.length; k++) {
      final ext = Baixar(extensoes: [
        Extensao(k, [id])
      ]);
      if (_aplicar(estado, assento, ext, spec, false).legal) return true;
    }
  }
  return false;
}

/// APLICA uma ação de forma ATÔMICA, passando pelas duas travas globais e
/// roteando para o avaliador canônico. Nunca muta o estado recebido: em caso
/// de recusa, `proximoEstado` é null; em caso de sucesso, é um novo estado.
ResultadoJogada aplicarLegal(
        EstadoJogo estado, int assento, Acao acao, RuleSpec spec) =>
    _aplicar(estado, assento, acao, spec, true);

/// Implementação de `aplicarLegal`. `verificarConclusao` só é `false` na
/// verificação do próprio invariante (ver `existeConclusaoLegalDoTurno`), para
/// que a checagem tenha profundidade 1 e termine sempre.
ResultadoJogada _aplicar(EstadoJogo estado, int assento, Acao acao,
    RuleSpec spec, bool verificarConclusao) {
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
    if (estado.fase != FaseTurno.compra) {
      return ResultadoJogada.recusa(
          'compra do monte só na fase de compra (fase = ${estado.fase.name})');
    }
    final prox = estado.cloneProfundo();
    if (prox.monte.isEmpty) {
      // §8.1 (regra congelada) — monte vazio: o MORTO de menor índice vira o
      // novo monte. Na convenção canônica (topo = último), o pile entra
      // REVERTIDO, para que a próxima compra seja a 1ª carta do morto (idêntico
      // ao motor legado, que compra `monte.removeAt(0)`). Sem morto disponível,
      // não há o que comprar (a rodada encerra por exaustão — tratado no fluxo).
      if (prox.mortos.isEmpty) {
        // §8.x — baralho EXAURIDO (monte E mortos vazios): a rodada ENCERRA por
        // falta de compra — MESMO efeito do legado (que encerra a rodada e não
        // compra carta). Transição LEGAL de fim de rodada, sem carta comprada.
        // (Reconcilia o finding "monte e mortos ambos vazios" do C9-C2.)
        return ResultadoJogada(
            legal: true, proximoEstado: prox.copyWith(rodadaEncerrada: true));
      }
      // `monte` é final no EstadoJogo (snapshot imutável) — muta a lista clonada
      // in-place em vez de reatribuir o campo.
      prox.monte.addAll(prox.mortos.removeAt(0).reversed);
    }
    final topo = prox.monte.removeLast(); // topo do monte = último
    prox.maos[assento].add(topo);
    return ResultadoJogada(
        legal: true, proximoEstado: prox.copyWith(fase: FaseTurno.jogo));
  }

  if (acao is ComprarLixo) {
    if (estado.fase != FaseTurno.compra) {
      return ResultadoJogada.recusa(
          'compra do lixo só na fase de compra (fase = ${estado.fase.name})');
    }
    // C10 — contrato ATÔMICO: repassa o uso do topo (jogos/extensões) para o
    // avaliador congelado. Sem jogos (Aberto), avaliarComprarLixo compra "para a
    // mão"; no Fechado/STBL sem uso do topo, ele mesmo RECUSA (topoObrigatorio).
    final r = avaliarComprarLixo(estado, assento, spec,
        topoDeclarado: acao.topoDeclarado,
        jogosNovos: acao.jogosNovos,
        extensoes: acao.extensoes);
    if (!r.valido) {
      return ResultadoJogada.recusa(r.motivo ?? 'compra do lixo ilegal');
    }
    final prox = r.proximoEstado!.copyWith(fase: FaseTurno.jogo);
    // §12 — o MESMO beco entra por este portão: a compra atômica consome a mão
    // no uso do topo e pode deixar 1 carta órfã sem descarte legal. Mesma regra,
    // mesma recusa, mesmo reasonCode.
    if (verificarConclusao &&
        !existeConclusaoLegalDoTurno(prox, assento, spec)) {
      return ResultadoJogada.recusa(motivoSemConclusaoLegal,
          codigo: reasonCodeSemConclusaoLegal);
    }
    return ResultadoJogada(legal: true, proximoEstado: prox);
  }

  if (acao is Baixar) {
    if (estado.fase != FaseTurno.jogo) {
      return ResultadoJogada.recusa(
          'baixar/estender só na fase de jogo, após comprar');
    }
    final r = avaliarBaixar(estado, assento, acao, spec);
    if (!r.valido) return ResultadoJogada.recusa(r.motivo ?? 'baixada ilegal');
    final prox = r.proximoEstado!;
    // Esvaziar é REGRA: se a baixada zera a mão, só é legal se a dupla puder
    // pegar o morto OU bater (podeEsvaziarMao — autoridade canônica). Senão,
    // rejeita a própria baixada (não deixa a mão vazia em estado impossível).
    if (prox.maos[assento].isEmpty && !podeEsvaziarMao(prox, assento, spec)) {
      return ResultadoJogada.recusa(
          'baixar zeraria a mão sem morto a pegar nem canastra para bater');
    }
    // CONCLUSÃO DO TURNO é REGRA (generaliza a linha acima): a baixada não pode
    // deixar o jogador sem NENHUMA transição legal — tipicamente com 1 carta na
    // mão que não tem descarte legal. Recusa ANTES de qualquer efeito.
    if (verificarConclusao &&
        !existeConclusaoLegalDoTurno(prox, assento, spec)) {
      return ResultadoJogada.recusa(motivoSemConclusaoLegal,
          codigo: reasonCodeSemConclusaoLegal);
    }
    return ResultadoJogada(legal: true, proximoEstado: prox);
  }

  if (acao is Descartar) {
    if (estado.fase != FaseTurno.jogo) {
      return ResultadoJogada.recusa(
          'descarte só após a fase de compra (fase = ${estado.fase.name})');
    }
    final mao = estado.maos[assento];
    if (!mao.any((c) => c.id == acao.carta)) {
      return ResultadoJogada.recusa('carta não está na mão: ${acao.carta}');
    }
    final prox = estado.cloneProfundo();
    final idx = prox.maos[assento].indexWhere((c) => c.id == acao.carta);
    final carta = prox.maos[assento].removeAt(idx);
    prox.lixo.add(carta); // vai para o topo do lixo
    if (prox.maos[assento].isNotEmpty) {
      // Descarte normal encerra o turno: próximo assento inicia em compra.
      return ResultadoJogada(
          legal: true,
          proximoEstado:
              prox.copyWith(vez: (assento + 1) % 4, fase: FaseTurno.compra));
    }
    // O descarte ZEROU a mão. Esvaziar é REGRA: só é legal se a dupla puder
    // pegar o morto OU bater (podeEsvaziarMao). Senão, recusa (estado intacto).
    if (!podeEsvaziarMao(prox, assento, spec)) {
      return ResultadoJogada.recusa(
          'descartar a última carta sem morto a pegar nem canastra para bater');
    }
    final dupla = assento % 2 == 0 ? 'nos' : 'eles';
    final mortoDisponivel =
        !(prox.mortoPego[dupla] ?? false) && prox.mortos.isNotEmpty;
    if (mortoDisponivel) {
      // Morto INDIRETO pendente (mesma vez); única ação legal: PegarMorto(via).
      return ResultadoJogada(
          legal: true,
          proximoEstado: prox.copyWith(fase: FaseTurno.mortoPendente));
    }
    // Morto já cumprido (ou sem morto) + canastra que libera: o descarte é
    // BATIDA (a legalidade é decidida por avaliarBatida — não duplicada aqui).
    final b = avaliarBatida(prox, assento, spec);
    return b.valido
        ? ResultadoJogada(legal: true, proximoEstado: b.proximoEstado)
        : ResultadoJogada.recusa(
            b.motivo ?? 'não pode encerrar o turno com a mão vazia');
  }

  if (acao is PegarMorto) {
    if (acao.viaDescarte) {
      // Morto INDIRETO: só depois de um descarte REAL que esvaziou a mão.
      if (estado.fase != FaseTurno.mortoPendente) {
        return ResultadoJogada.recusa(
            'morto indireto exige um descarte que esvazie a mão antes');
      }
      final r = pegarMorto(estado, assento, viaDescarte: true);
      return r.valido
          ? ResultadoJogada(
              legal: true,
              proximoEstado: r.proximoEstado!.copyWith(fase: FaseTurno.compra))
          : ResultadoJogada.recusa(r.motivo ?? 'não pode pegar o morto');
    }
    // Morto DIRETO: mão esvaziada BAIXANDO, na fase de jogo; mantém a vez e
    // ainda deverá descartar depois.
    if (estado.fase != FaseTurno.jogo) {
      return ResultadoJogada.recusa('morto direto só na fase de jogo');
    }
    final r = pegarMorto(estado, assento, viaDescarte: false);
    return r.valido
        ? ResultadoJogada(
            legal: true,
            proximoEstado: r.proximoEstado!.copyWith(fase: FaseTurno.jogo))
        : ResultadoJogada.recusa(r.motivo ?? 'não pode pegar o morto');
  }

  if (acao is Bater) {
    if (estado.fase != FaseTurno.jogo) {
      return ResultadoJogada.recusa('bater só na fase de jogo');
    }
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
