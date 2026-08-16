// escopo_ranking.dart — como as telas alcançam o ranking real.
//
// Mesmo desenho de `sessao/escopo_sessao.dart`, e pela mesma razão: com escopo,
// "Home e Perfil leem a mesma coisa" é propriedade da árvore de widgets, e não
// promessa de disciplina.
//
// A VERSÃO TOLERANTE É O PONTO IMPORTANTE. Fora do escopo, [talvezDe] devolve
// `null`, e quem consome cai em [rankingDaCascaPublicavel] — "não sei". É o que
// mantém honestas as dezenas de telas e testes que montam o Perfil sem casca:
// sem escopo não há autoridade, e sem autoridade não se afirma nada. O que NÃO
// pode existir é o caminho oposto — a ausência de escopo virar uma liga padrão.

import 'package:flutter/widgets.dart';

import 'estado_ranking.dart';
import 'ranking_da_sessao.dart';

/// Pendura o [RankingDaSessao] na árvore.
class EscopoRanking extends InheritedNotifier<RankingDaSessao> {
  const EscopoRanking({
    super.key,
    required RankingDaSessao ranking,
    required super.child,
  }) : super(notifier: ranking);

  /// O ranking do escopo, ou `null` fora dele.
  static RankingDaSessao? talvezDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EscopoRanking>()?.notifier;

  /// O estado competitivo do jogador logado visto deste ponto da árvore.
  ///
  /// Fora do escopo devolve [rankingDaCascaPublicavel]: não há autoridade
  /// alcançável, e essa é a leitura correta — a mesma que valia antes de existir
  /// leitor.
  static EstadoRanking meuEstadoDe(BuildContext context) =>
      talvezDe(context)?.meuEstado ?? rankingDaCascaPublicavel;
}
