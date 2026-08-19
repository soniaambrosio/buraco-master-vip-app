// escopo_social.dart — como as telas alcançam o grafo social real.
//
// Mesmo desenho de `ranking/escopo_ranking.dart` e de `sessao/escopo_sessao.dart`,
// e pela mesma razão: com escopo, "a tela de Amigos e o Perfil visitado leem a
// MESMA autoridade" é propriedade da árvore de widgets, e não promessa de
// disciplina de quem escreve a próxima tela.
//
// A VERSÃO TOLERANTE É O PONTO. Fora do escopo, [talvezDe] devolve `null`, e
// quem consome trata como "não há a quem perguntar" — que é a leitura certa
// numa pré-visualização isolada de tela ou num teste que monta só o widget.
// O que NUNCA pode acontecer é o caminho oposto: a ausência de escopo virar
// pretexto para a tela construir um transporte próprio (um leitor por tela é um
// grafo por tela) ou para exibir uma lista de maquete.

import 'package:flutter/widgets.dart';

import 'leitor_social.dart';

/// Pendura o [LeitorSocial] canônico na árvore.
///
/// `InheritedNotifier` porque o leitor É um `ChangeNotifier`: quem depende dele
/// reconstrói quando uma lista chega, sem precisar de listener próprio e sem
/// que a tela tenha de saber quando pedir `setState`.
class EscopoSocial extends InheritedNotifier<LeitorSocial> {
  const EscopoSocial({
    super.key,
    required LeitorSocial social,
    required super.child,
  }) : super(notifier: social);

  /// O leitor social deste ponto da árvore, ou `null` fora do escopo.
  static LeitorSocial? talvezDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EscopoSocial>()?.notifier;
}
