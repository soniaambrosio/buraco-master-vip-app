// escopo_autenticacao.dart — como as telas alcançam os comandos de entrar e sair.
//
// Irmão de `sessao/escopo_sessao.dart`, e pelo mesmo motivo dele: com escopo, "só
// existe um caminho para sair da conta" é uma propriedade da árvore, não uma
// promessa de disciplina. Uma tela que quisesse sair por conta própria teria de
// importar `firebase_auth` — e há teste estrutural que reprova isso.
//
// `InheritedWidget` simples, e não `InheritedNotifier`: os comandos não têm
// estado, então não há o que notificar. Quem notifica mudança de sessão é a
// `SessaoDoJogador`.

import 'package:flutter/widgets.dart';

import '../sessao/comandos_de_autenticacao.dart';

class EscopoAutenticacao extends InheritedWidget {
  const EscopoAutenticacao({
    super.key,
    required this.comandos,
    required super.child,
  });

  final ComandosDeAutenticacao comandos;

  /// Os comandos deste ponto da árvore, ou `null` fora do escopo.
  ///
  /// Fora do escopo é o caso das pré-visualizações isoladas de tela. Devolver
  /// `null` ali é honesto: sem raiz, não há como entrar nem sair.
  static ComandosDeAutenticacao? talvezDe(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<EscopoAutenticacao>()
      ?.comandos;

  /// Os comandos, ou os de um ambiente que não sabe autenticar.
  ///
  /// Nunca lança e nunca devolve um dublê que finge ter funcionado:
  /// [SemAutenticacao] recusa o login com mensagem explícita.
  static ComandosDeAutenticacao de(BuildContext context) =>
      talvezDe(context) ?? const SemAutenticacao();

  @override
  bool updateShouldNotify(EscopoAutenticacao anterior) =>
      comandos != anterior.comandos;
}
