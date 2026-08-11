import 'dart:async';

import '../lib/hall/hall_contract.dart';
import '../lib/ranking/ranking_contract.dart';
import '../lib/services/hall_service.dart';
import '../lib/services/ranking_service.dart';

/// Dado de exemplo de Ranking e Hall.
///
/// Vive AQUI, e só aqui: as `factory .mock()` que existiam em
/// `lib/screens/ranking_screen.dart` e `lib/screens/hall_screen.dart` foram
/// retiradas na integração justamente para não viajarem dentro do APK.

RankingJogador jogador(
  int posicao, {
  String? id,
  String? apelido,
  String liga = 'Diamante',
  int? pontos,
  RankingDirecao direcao = RankingDirecao.estavel,
  int delta = 0,
  String? selo,
  bool souEu = false,
}) {
  return RankingJogador(
    id: id ?? 'uid-$posicao',
    apelido: apelido ?? 'Jogador $posicao',
    avatar: '🐱',
    liga: liga,
    pontos: pontos ?? (5000 - posicao),
    posicao: posicao,
    direcao: direcao,
    delta: delta,
    selo: selo,
    souEu: souEu,
  );
}

RankingResumo resumo({
  RankingEscopo escopo = RankingEscopo.temporada,
  String faixaTempo = 'Temporada acaba em 12d 6h',
  RankingDivisao? divisao,
  List<RankingJogador> podio = const [],
  List<RankingLigaDegrau> escadaLigas = const [],
}) {
  return RankingResumo(
    escopo: escopo,
    faixaTempo: faixaTempo,
    divisao: divisao,
    podio: podio,
    escadaLigas: escadaLigas,
  );
}

const RankingDivisao divisaoDemo = RankingDivisao(
  nome: 'Diamante III',
  icone: 'assets/ranking/divisao_diamante.webp',
  pontos: 1240,
  pontosProxima: 1500,
  faltamPontos: 260,
  proximaDivisao: 'Diamante II',
  posicaoLiga: 12,
);

const List<RankingLigaDegrau> escadaDemo = [
  RankingLigaDegrau(
      nome: 'Bronze', icone: 'assets/ranking/liga_bronze.webp', atual: false),
  RankingLigaDegrau(
      nome: 'Prata', icone: 'assets/ranking/liga_prata.webp', atual: false),
  RankingLigaDegrau(
      nome: 'Diamante', icone: 'assets/ranking/liga_diamante.webp', atual: true),
];

RankingPagina pagina(
  List<RankingJogador> itens, {
  String? cursorProxima,
  bool fim = false,
}) {
  return RankingPagina(itens: itens, cursorProxima: cursorProxima, fim: fim);
}

RankingAbertura abertura({
  RankingResumo? cabecalho,
  List<RankingJogador> itens = const [],
  String? cursorProxima,
  bool fim = false,
}) {
  return RankingAbertura(
    resumo: cabecalho ?? resumo(),
    primeiraPagina:
        pagina(itens, cursorProxima: cursorProxima, fim: fim),
  );
}

/// Fonte de Ranking com controle manual: cada chamada devolve um [Completer]
/// que o teste completa quando quiser.
///
/// É isso que torna determinístico verificar “mostrou o esqueleto antes da
/// resposta” e “duas chamadas concorrentes viraram uma busca só”.
class RankingFonteFake extends RankingService {
  RankingFonteFake();

  /// Uma entrada por chamada de [abrir], na ordem.
  final List<Completer<RankingAbertura>> aberturas = [];

  /// Uma entrada por chamada de [proximaPagina], na ordem.
  final List<Completer<RankingPagina>> paginacoes = [];

  final List<RankingEscopo> escoposAbertos = [];
  final List<String> cursoresPedidos = [];

  @override
  Future<RankingAbertura> abrir(RankingEscopo escopo) {
    escoposAbertos.add(escopo);
    final completer = Completer<RankingAbertura>();
    aberturas.add(completer);
    return completer.future;
  }

  @override
  Future<RankingPagina> proximaPagina(RankingEscopo escopo, String cursor) {
    cursoresPedidos.add(cursor);
    final completer = Completer<RankingPagina>();
    paginacoes.add(completer);
    return completer.future;
  }
}

HallHonrado honrado(
  HallCategoria categoria, {
  String? id,
  String? nome,
  String avatar = '👑',
  String? avatar2,
  List<String> estatisticas = const ['342', '18', '68%'],
}) {
  return HallHonrado(
    categoria: categoria,
    id: id ?? 'uid-${categoria.name}',
    nome: nome ?? 'Honrado ${categoria.name}',
    avatar: avatar,
    avatar2: avatar2,
    estatisticas: estatisticas,
  );
}

/// Fonte do Hall com controle manual, no mesmo desenho da [RankingFonteFake].
class HallFonteFake extends HallService {
  HallFonteFake();

  final List<Completer<HallQuadro>> consultas = [];

  @override
  Future<HallQuadro> quadro() {
    final completer = Completer<HallQuadro>();
    consultas.add(completer);
    return completer.future;
  }
}
