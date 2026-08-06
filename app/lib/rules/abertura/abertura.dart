// C5 (corrigido) — jogada atômica: abertura múltipla, extensões e COMPRA DO
// LIXO, sobre o EstadoJogo imutável. SEM comportamento de produção: só a suíte
// de testes usa isto; o motor antigo (class Jogo) continua ativo em runtime.
//
// INFORMAÇÃO OCULTA (Fechado/STBL): a legalidade da compra do lixo é avaliada
// vendo APENAS a mão, o TOPO real/visível do lixo (lixo.last) e os jogos já
// baixados (para extensão pelo topo). As cartas ENTERRADAS do lixo NÃO entram
// na avaliação — só vão para a mão DEPOIS de a compra ser aprovada.
import '../estado.dart';
import '../acoes.dart';
import '../rule_spec.dart';
import '../meld/meld_validator.dart';
import '../pontuacao_canonica.dart' show valorCarta;

String _duplaDoAssento(int a) => a % 2 == 0 ? 'nos' : 'eles';

class ResultadoAbertura {
  final bool valido;
  final String? motivo;
  final int pontosAbertura; // soma dos pontos das cartas dos jogos NOVOS
  final int minimoExigido;
  final bool sujeitoAoMinimo; // houve abertura vulnerável com mínimo > 0
  final bool atingiuMinimo; // requisito de mínimo satisfeito (vacuamente true se não sujeito)
  final EstadoJogo? proximoEstado; // preenchido só se válido (aplicar puro)

  const ResultadoAbertura({
    required this.valido,
    this.motivo,
    this.pontosAbertura = 0,
    this.minimoExigido = 0,
    this.sujeitoAoMinimo = false,
    this.atingiuMinimo = false,
    this.proximoEstado,
  });

  factory ResultadoAbertura.recusa(String motivo,
          {int pontos = 0, int minimo = 0}) =>
      ResultadoAbertura(
        valido: false,
        motivo: motivo,
        pontosAbertura: pontos,
        minimoExigido: minimo,
        atingiuMinimo: false,
      );
}

/// Núcleo: resolve/valida jogos e extensões, checa mínimo e aplica tudo-ou-nada.
/// [disponiveis] = cartas utilizáveis nos jogos (mão +, na compra do lixo, SÓ o
/// topo visível). [lixoConsumir] = lixo a mover para a mão APÓS aprovação (null
/// = sem compra). [topoObrigatorioId] = id do topo que DEVE ser usado
/// (Fechado/STBL) ou null. [permitirVazio] = permite ação sem baixar (compra do
/// lixo no Aberto).
ResultadoAbertura _avaliar(
  EstadoJogo estado,
  int assento,
  RuleSpec spec, {
  required List<List<CartaId>> jogosNovos,
  required List<Extensao> extensoes,
  required List<CartaSnapshot> disponiveis,
  List<CartaSnapshot>? lixoConsumir,
  String? topoObrigatorioId,
  bool permitirVazio = false,
}) {
  final dupla = _duplaDoAssento(assento);
  final indiceCarta = <String, CartaSnapshot>{
    for (final c in disponiveis) c.id: c
  };

  // 1) coletar ids; duplicidade e existência (existência = mão + topo visível;
  //    cartas enterradas do lixo NÃO estão no índice, logo são recusadas).
  final usados = <String>[];
  for (final jogo in jogosNovos) {
    usados.addAll(jogo);
  }
  for (final ext in extensoes) {
    usados.addAll(ext.cartas);
  }
  if (usados.isEmpty && !permitirVazio) {
    return ResultadoAbertura.recusa('nenhuma carta na jogada');
  }
  final vistos = <String>{};
  for (final id in usados) {
    if (!vistos.add(id)) {
      return ResultadoAbertura.recusa(
          'mesma carta usada em mais de um jogo: $id');
    }
    if (!indiceCarta.containsKey(id)) {
      return ResultadoAbertura.recusa(
          'carta inexistente, oculta ou já baixada: $id');
    }
  }

  // 2) validar cada JOGO NOVO individualmente.
  final jogosResolvidos = <List<CartaSnapshot>>[];
  for (final jogo in jogosNovos) {
    if (jogo.length < 3) {
      return ResultadoAbertura.recusa('um jogo tem no mínimo 3 cartas');
    }
    final cartas = [for (final id in jogo) indiceCarta[id]!];
    final r = validarJogoMesa(cartas, spec);
    if (!r.valido) {
      return ResultadoAbertura.recusa('jogo inválido: ${r.motivo}');
    }
    jogosResolvidos.add(cartas);
  }

  // 3) extensões AGRUPADAS por indiceJogo; valida [alvo + todas] uma vez.
  final jogosDupla = estado.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[];
  final extensoesPorIndice = <int, List<CartaSnapshot>>{};
  for (final ext in extensoes) {
    if (ext.indiceJogo < 0 || ext.indiceJogo >= jogosDupla.length) {
      return ResultadoAbertura.recusa(
          'jogo a estender não existe: ${ext.indiceJogo}');
    }
    if (ext.cartas.isEmpty) {
      return ResultadoAbertura.recusa('extensão sem cartas');
    }
    (extensoesPorIndice[ext.indiceJogo] ??= <CartaSnapshot>[])
        .addAll([for (final id in ext.cartas) indiceCarta[id]!]);
  }
  for (final e in extensoesPorIndice.entries) {
    final alvo = jogosDupla[e.key];
    final r = validarJogoMesa([...alvo, ...e.value], spec);
    if (!r.valido) {
      return ResultadoAbertura.recusa('extensão inválida: ${r.motivo}');
    }
  }

  // 3b) EXIGÊNCIA DO TOPO (Fechado/STBL): o topo precisa aparecer em ALGUM jogo
  //     ou extensão desta ação (avaliado só com mão + topo visível).
  if (topoObrigatorioId != null && !vistos.contains(topoObrigatorioId)) {
    return ResultadoAbertura.recusa(
        'o topo do lixo precisa ter uso imediato em pelo menos um jogo ou extensão');
  }

  // 4) mínimo de abertura — só na 1ª baixada da dupla, sobre os jogos NOVOS.
  final abrindo = !(estado.primeiraBaixadaFeita[dupla] ?? false);
  final pontosAbertura = jogosResolvidos.fold<int>(
      0, (s, j) => s + j.fold<int>(0, (t, c) => t + valorCarta(c)));
  final minimo = (abrindo && jogosNovos.isNotEmpty)
      ? spec.vulnerabilidade.minimoParaDescer(
          rodadasVulneravel: estado.rodadasVulneravel[dupla] ?? 0,
          jaAbriuNaRodada: false,
        )
      : 0;
  final sujeitoAoMinimo = minimo > 0;
  if (sujeitoAoMinimo && pontosAbertura < minimo) {
    return ResultadoAbertura(
      valido: false,
      motivo:
          'vulnerável: a abertura precisa somar $minimo pts (esta soma $pontosAbertura)',
      pontosAbertura: pontosAbertura,
      minimoExigido: minimo,
      sujeitoAoMinimo: true,
      atingiuMinimo: false,
    );
  }

  // 5) tudo-ou-nada: só AGORA produzimos o próximo estado (clone profundo).
  final proximo = estado.cloneProfundo();
  proximo.maos[assento].removeWhere((c) => vistos.contains(c.id));
  // Compra do lixo: as cartas NÃO usadas do lixo (enterradas + topo não usado)
  // vão para a mão SÓ AGORA (após a aprovação); o lixo esvazia.
  if (lixoConsumir != null) {
    for (final c in lixoConsumir) {
      if (!vistos.contains(c.id)) proximo.maos[assento].add(c.copia());
    }
    proximo.lixo.clear();
  }
  final melds = proximo.jogosDupla[dupla]!;
  for (final e in extensoesPorIndice.entries) {
    melds[e.key] = [...melds[e.key], ...e.value];
  }
  for (final j in jogosResolvidos) {
    melds.add(j);
  }
  // Só a ABERTURA (jogos novos) marca primeiraBaixadaFeita; extensão isolada não.
  if (jogosNovos.isNotEmpty) {
    proximo.primeiraBaixadaFeita[dupla] = true;
  }

  return ResultadoAbertura(
    valido: true,
    pontosAbertura: pontosAbertura,
    minimoExigido: minimo,
    sujeitoAoMinimo: sujeitoAoMinimo,
    atingiuMinimo: !sujeitoAoMinimo || pontosAbertura >= minimo,
    proximoEstado: proximo,
  );
}

/// Baixar simples (SEM compra do lixo). `topoLixoConsumido` deve ser null — a
/// compra do lixo passa por `avaliarComprarLixo`.
ResultadoAbertura avaliarBaixar(
    EstadoJogo estado, int assento, Baixar acao, RuleSpec spec) {
  if (acao.topoLixoConsumido != null) {
    return ResultadoAbertura.recusa(
        'compra do lixo deve usar avaliarComprarLixo (não Baixar.topoLixoConsumido)');
  }
  return _avaliar(
    estado,
    assento,
    spec,
    jogosNovos: acao.jogosNovos,
    extensoes: acao.extensoes,
    disponiveis: estado.maos[assento],
  );
}

/// Compra do lixo canônica (Fechado/STBL e Aberto). Autoriza vendo APENAS a mão,
/// o TOPO real e os jogos já baixados. As cartas ENTERRADAS só entram na mão
/// depois da aprovação. No Fechado/STBL o topo deve ter uso imediato; no Aberto
/// a compra é livre (pode ocorrer sem baixar).
ResultadoAbertura avaliarComprarLixo(
  EstadoJogo estado,
  int assento,
  RuleSpec spec, {
  String? topoDeclarado,
  List<List<CartaId>> jogosNovos = const [],
  List<Extensao> extensoes = const [],
}) {
  final lixo = estado.lixo;
  if (lixo.isEmpty) {
    return ResultadoAbertura.recusa('lixo vazio: não há topo para comprar');
  }
  final topo = lixo.last;
  // Impede declarar um topo diferente do topo real/visível (id enterrado etc.).
  if (topoDeclarado != null && topoDeclarado != topo.id) {
    return ResultadoAbertura.recusa(
        'topo declarado ($topoDeclarado) não é o topo real do lixo (${topo.id})');
  }
  final exige = spec.exigeUsoDoTopoNoLixo;
  return _avaliar(
    estado,
    assento,
    spec,
    jogosNovos: jogosNovos,
    extensoes: extensoes,
    // Autorização vê SOMENTE a mão + o topo visível (enterradas ficam de fora).
    disponiveis: <CartaSnapshot>[...estado.maos[assento], topo],
    lixoConsumir: lixo,
    topoObrigatorioId: exige ? topo.id : null,
    permitirVazio: !exige, // Aberto: compra do lixo pode ocorrer sem baixar.
  );
}
