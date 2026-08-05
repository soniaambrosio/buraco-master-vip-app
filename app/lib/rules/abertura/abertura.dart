// C4 — jogada atômica: abertura de VÁRIOS jogos novos + VÁRIAS extensões numa
// única ação, tudo-ou-nada, sobre o EstadoJogo imutável. SEM comportamento de
// produção: só a suíte de testes usa isto; o motor antigo continua ativo.
//
// Garantias:
//  - cada meld novo é validado individualmente (validarJogoMesa);
//  - cada extensão é validada como [alvo + novas] inteiro;
//  - nenhuma carta pode ser usada em dois lugares; toda carta precisa existir na mão;
//  - o mínimo (+75/+90) é exigido sobre a SOMA dos jogos NOVOS da abertura;
//  - o próximo estado só é produzido se TUDO validar (nenhuma mutação parcial);
//  - em qualquer falha, o estado de entrada permanece intacto (é imutável);
//  - os IDs das cartas são conservados (mão -> mesa), sem sumiço/duplicação.
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

/// Avalia e (se válida) aplica a jogada atômica `Baixar` para o assento dado.
/// Retorna o próximo estado apenas quando tudo é válido; caso contrário
/// `proximoEstado` é null e o estado de entrada não é tocado.
ResultadoAbertura avaliarBaixar(
    EstadoJogo estado, int assento, Baixar acao, RuleSpec spec) {
  final dupla = _duplaDoAssento(assento);
  final mao = estado.maos[assento];

  // Compra do lixo (Fechado/STBL): `topoLixoConsumido != null` sinaliza a
  // compra; o topo entra na jogada e (no Fechado/STBL) deve ter uso imediato.
  final comprandoLixo = acao.topoLixoConsumido != null;
  final lixo = estado.lixo;
  if (comprandoLixo) {
    if (lixo.isEmpty) {
      return ResultadoAbertura.recusa('lixo vazio: não há topo para comprar');
    }
    if (lixo.last.id != acao.topoLixoConsumido) {
      return ResultadoAbertura.recusa(
          'topo declarado (${acao.topoLixoConsumido}) não é o topo real do lixo (${lixo.last.id})');
    }
  }
  // Cartas disponíveis para os jogos: a mão e, na compra do lixo, o lixo inteiro.
  final disponiveis =
      comprandoLixo ? <CartaSnapshot>[...mao, ...lixo] : mao;
  final indiceCarta = <String, CartaSnapshot>{
    for (final c in disponiveis) c.id: c
  };

  // 1) coletar todos os ids usados; checar duplicidade e existência na mão.
  final usados = <String>[];
  for (final jogo in acao.jogosNovos) {
    usados.addAll(jogo);
  }
  for (final ext in acao.extensoes) {
    usados.addAll(ext.cartas);
  }
  if (usados.isEmpty) {
    return ResultadoAbertura.recusa('nenhuma carta na jogada');
  }
  final vistos = <String>{};
  for (final id in usados) {
    if (!vistos.add(id)) {
      return ResultadoAbertura.recusa(
          'mesma carta usada em mais de um jogo: $id');
    }
    if (!indiceCarta.containsKey(id)) {
      return ResultadoAbertura.recusa('carta inexistente ou já baixada: $id');
    }
  }

  // 2) validar cada JOGO NOVO individualmente.
  final jogosResolvidos = <List<CartaSnapshot>>[];
  for (final jogo in acao.jogosNovos) {
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

  // 3) AGRUPAR todas as cartas de extensão por indiceJogo e validar o meld
  //    FINAL [alvo + TODAS as cartas do índice] UMA ÚNICA vez. Corrige o caso
  //    de duas extensões individualmente válidas, mas ilegais em conjunto.
  final jogosDupla = estado.jogosDupla[dupla] ?? const <List<CartaSnapshot>>[];
  final extensoesPorIndice = <int, List<CartaSnapshot>>{};
  for (final ext in acao.extensoes) {
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

  // 3b) EXIGÊNCIA DO TOPO (Fechado/STBL): o topo precisa aparecer em ALGUM
  //     jogo ou extensão desta ação. Em Aberto não se aplica (regra própria).
  if (comprandoLixo && spec.exigeUsoDoTopoNoLixo) {
    if (!vistos.contains(acao.topoLixoConsumido)) {
      return ResultadoAbertura.recusa(
          'o topo do lixo precisa ter uso imediato em pelo menos um jogo ou extensão');
    }
  }

  // 4) mínimo de abertura — só na 1ª baixada da dupla, sobre os jogos NOVOS.
  final abrindo = !(estado.primeiraBaixadaFeita[dupla] ?? false);
  final pontosAbertura = jogosResolvidos.fold<int>(
      0, (s, j) => s + j.fold<int>(0, (t, c) => t + valorCarta(c)));
  final minimo = (abrindo && acao.jogosNovos.isNotEmpty)
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
  // Compra do lixo: as cartas NÃO usadas do lixo vão para a mão; o lixo esvazia.
  if (comprandoLixo) {
    for (final c in lixo) {
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
  if (acao.jogosNovos.isNotEmpty) {
    proximo.primeiraBaixadaFeita[dupla] = true;
  }

  return ResultadoAbertura(
    valido: true,
    pontosAbertura: pontosAbertura,
    minimoExigido: minimo,
    sujeitoAoMinimo: sujeitoAoMinimo,
    // vacuamente satisfeito quando não houve abertura sujeita a mínimo:
    atingiuMinimo: !sujeitoAoMinimo || pontosAbertura >= minimo,
    proximoEstado: proximo,
  );
}
