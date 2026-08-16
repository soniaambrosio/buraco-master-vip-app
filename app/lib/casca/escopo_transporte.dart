// escopo_transporte.dart — o transporte da sessão, pendurado na árvore.
//
// ---------------------------------------------------------------------------
// POR QUE O TRANSPORTE SUBIU PARA A RAIZ
// ---------------------------------------------------------------------------
//
// Ele nascia dentro da tela do lobby: `didChangeDependencies` construía um
// `OnlineService` e uma `PonteSessaoOnline`, e os destruía ao sair da tela. Isso
// funcionava para a tela, e falhava para o aplicativo, em dois pontos que esta
// OS cobra:
//
//   * LOGOUT. Se a pessoa saísse da conta fora do lobby — pela tela de Ajustes,
//     que é onde o botão fica —, não havia ponte montada para ouvir a troca. O
//     socket até morria junto com a tela, mas por acidente de ciclo de vida, e
//     não porque alguém encerrou a sessão.
//
//   * DUPLICAÇÃO. Duas rotas do lobby empilhadas construiriam dois transportes,
//     e nenhum dos dois saberia do outro. Um transporte por tela é um socket por
//     tela.
//
// Aqui existe UM transporte pela vida do aplicativo, com UMA ponte observando a
// sessão. Quem monta é a raiz (`raiz_do_aplicativo.dart`); quem consome só lê.
//
// ---------------------------------------------------------------------------
// SUBIR NÃO É CONECTAR
// ---------------------------------------------------------------------------
//
// O transporte existe desde a abertura e fica DESCONECTADO até alguém pedir. A
// iniciativa continua sendo do jogador: `conectar()` é chamado pela tela do
// lobby, quando ele escolhe jogar online. Uma raiz que conectasse sozinha abriria
// socket para quem só queria treinar contra os robôs — e faria isso na
// inicialização, que é justamente quando ninguém pediu nada.

import 'package:flutter/widgets.dart';

import '../services/online_service.dart';

/// Pendura o [OnlineService] canônico na árvore.
///
/// `InheritedNotifier` porque o transporte É um `ChangeNotifier`: quem depende
/// dele reconstrói quando o status muda, sem precisar de listener próprio.
class EscopoTransporte extends InheritedNotifier<OnlineService> {
  const EscopoTransporte({
    super.key,
    required OnlineService online,
    required super.child,
  }) : super(notifier: online);

  /// O transporte deste ponto da árvore, ou `null` fora do escopo.
  ///
  /// `null` acontece em pré-visualização isolada de tela. Quem consome trata
  /// como "não dá para jogar online daqui" — nunca como pretexto para construir
  /// um transporte próprio, que seria um segundo socket sem ponte.
  static OnlineService? talvezDe(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EscopoTransporte>()?.notifier;
}
