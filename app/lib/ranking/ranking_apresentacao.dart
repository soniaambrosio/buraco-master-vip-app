// ranking_apresentacao.dart — tradução do que a fonte publicou para o que a
// tela desenha. Só isso.
//
// A regra que este arquivo tem de respeitar, e que o teste
// `ranking_autoridade_test.dart` verifica: **a ordem e a posição saem daqui
// exatamente como entraram**. Nada de ordenar por pontos, renumerar, recalcular
// delta ou decidir liga — se a fonte publicar uma lista fora de sequência, a
// tela mostra fora de sequência, porque a classificação é dela.

import '../screens/ranking_screen.dart';
import 'ranking_contract.dart';

/// Molduras do pódio: pura decoração, escolhida pela posição recebida.
const Map<int, String> _molduras = {
  1: 'assets/ranking/podio_ouro.webp',
  2: 'assets/ranking/podio_prata.webp',
  3: 'assets/ranking/podio_bronze.webp',
};

RankingAba abaDoEscopo(RankingEscopo escopo) {
  switch (escopo) {
    case RankingEscopo.temporada:
      return RankingAba.temporada;
    case RankingEscopo.global:
      return RankingAba.global;
    case RankingEscopo.amigos:
      return RankingAba.amigos;
  }
}

RankingEscopo escopoDaAba(RankingAba aba) {
  switch (aba) {
    case RankingAba.temporada:
      return RankingEscopo.temporada;
    case RankingAba.global:
      return RankingEscopo.global;
    case RankingAba.amigos:
      return RankingEscopo.amigos;
  }
}

Direcao _direcao(RankingDirecao direcao) {
  switch (direcao) {
    case RankingDirecao.subiu:
      return Direcao.subiu;
    case RankingDirecao.desceu:
      return Direcao.desceu;
    case RankingDirecao.estavel:
      return Direcao.estavel;
  }
}

RankingRow linhaDoJogador(RankingJogador jogador) {
  return RankingRow(
    posicao: jogador.posicao,
    nome: jogador.apelido,
    avatar: jogador.avatar,
    liga: jogador.liga,
    pontos: jogador.pontos,
    direcao: _direcao(jogador.direcao),
    delta: jogador.delta,
    ehVoce: jogador.souEu,
    selo: jogador.selo,
    jogadorId: jogador.id,
  );
}

PodioEntry podioDoJogador(RankingJogador jogador) {
  return PodioEntry(
    posicao: jogador.posicao,
    nome: jogador.apelido,
    avatar: jogador.avatar,
    moldura: _molduras[jogador.posicao] ?? 'assets/ranking/podio_bronze.webp',
    pontos: jogador.pontos,
    ehVoce: jogador.souEu,
    jogadorId: jogador.id,
  );
}

DivisaoAtual? divisaoAtual(RankingDivisao? divisao) {
  if (divisao == null) return null;
  return DivisaoAtual(
    nome: divisao.nome,
    icone: divisao.icone,
    pontos: divisao.pontos,
    pontosProxima: divisao.pontosProxima,
    faltamPontos: divisao.faltamPontos,
    proximaDivisao: divisao.proximaDivisao,
    posicaoLiga: divisao.posicaoLiga,
  );
}

LigaEscada _degrau(RankingLigaDegrau degrau) {
  return LigaEscada(
    nome: degrau.nome,
    icone: degrau.icone,
    atual: degrau.atual,
  );
}

/// Monta o view-model da tela. `itens` é a lista já acumulada pelo paginador,
/// na ordem em que a fonte devolveu.
RankingVM montarRankingVM({
  required RankingEscopo escopo,
  required RankingResumo? resumo,
  required List<RankingJogador> itens,
  bool mostrarHall = true,
}) {
  return RankingVM(
    aba: abaDoEscopo(escopo),
    faixaTempo: resumo?.faixaTempo ?? '',
    mostrarHall: mostrarHall,
    divisao: divisaoAtual(resumo?.divisao),
    podio: [for (final j in resumo?.podio ?? const <RankingJogador>[]) podioDoJogador(j)],
    lista: [for (final j in itens) linhaDoJogador(j)],
    escadaLigas: [
      for (final d in resumo?.escadaLigas ?? const <RankingLigaDegrau>[]) _degrau(d),
    ],
  );
}

/// View-model de esqueleto, para o estado de carregando: a tela desenha o
/// skeleton e nada deste conteúdo aparece.
RankingVM vmVazio(RankingEscopo escopo, {bool mostrarHall = true}) {
  return montarRankingVM(
    escopo: escopo,
    resumo: null,
    itens: const [],
    mostrarHall: mostrarHall,
  );
}

/// Resolve `posição → id público` na página que a tela tem em mãos.
///
/// É o que permite manter `onVerJogador(int posicao)` — a API aprovada da tela —
/// sem que a posição vire chave de navegação. Devolve `null` quando a fonte não
/// publicou id, e aí não se navega para lugar nenhum.
String? idNaPosicao(
  int posicao, {
  required RankingResumo? resumo,
  required List<RankingJogador> itens,
}) {
  for (final j in resumo?.podio ?? const <RankingJogador>[]) {
    if (j.posicao == posicao) return j.id.isEmpty ? null : j.id;
  }
  for (final j in itens) {
    if (j.posicao == posicao) return j.id.isEmpty ? null : j.id;
  }
  return null;
}
