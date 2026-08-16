// escopo_sessao.dart — como as telas ALCANÇAM o estado canônico.
//
// `InheritedNotifier`, e não um singleton global, por uma razão que a OS cobra
// diretamente: com singleton, "todos compartilham o mesmo estado" é uma promessa
// de disciplina; com escopo, é uma propriedade do widget tree. Um teste de
// widget monta o escopo com uma sessão falsa e a tela real consome — que é como
// os casos B, C e D são provados sem Firebase.
//
// Não há `EscopoSessao.criar(...)` nem nada que uma tela possa chamar para
// materializar identidade. O escopo só ENTREGA o que a raiz já pendurou.

import 'package:flutter/widgets.dart';

import 'identidade_publica_sessao.dart';
import 'sessao_do_jogador.dart';

/// Pendura a [SessaoDoJogador] na árvore para que qualquer tela a leia.
class EscopoSessao extends InheritedNotifier<SessaoDoJogador> {
  const EscopoSessao({
    super.key,
    required SessaoDoJogador sessao,
    required super.child,
  }) : super(notifier: sessao);

  /// A sessão do escopo, ou `null` fora dele.
  ///
  /// A versão tolerante existe porque o app tem telas que também rodam em
  /// pré-visualização isolada; devolver `null` ali é honesto, e quem consome
  /// trata como "identidade não disponível" — nunca como pretexto para
  /// fabricar uma.
  static SessaoDoJogador? talvezDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EscopoSessao>()?.notifier;

  static SessaoDoJogador de(BuildContext context) {
    final sessao = talvezDe(context);
    assert(sessao != null, 'EscopoSessao ausente acima deste widget');
    return sessao!;
  }

  /// O estado canônico visto deste ponto da árvore.
  ///
  /// Fora do escopo devolve [EstadoIdentidadeSessao.deslogado] — "não há
  /// identidade", que é a leitura correta e a única segura.
  static EstadoIdentidadeSessao identidadeDe(BuildContext context) =>
      talvezDe(context)?.estado ?? EstadoIdentidadeSessao.deslogado;
}
