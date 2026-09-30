// anuncio_de_transicao.dart — dizer UMA vez o que mudou.
//
// ===========================================================================
// POR QUE UM ANÚNCIO, E NÃO UMA REGIÃO VIVA, NA MAIORIA DOS CASOS
// ===========================================================================
//
// Região viva (`Semantics(liveRegion: true)`) é a ferramenta certa quando a
// notícia É um texto que fica na tela: a mensagem aparece, o leitor lê, e ela
// continua ali para quem quiser voltar. Foi assim que a falha de login e a
// recusa do lobby foram resolvidas.
//
// Ela não serve quando a notícia é uma TRANSIÇÃO cujo texto some, ou cujo
// texto nem existe. "A conexão voltou" não tem widget: o que acontece é uma
// faixa DESAPARECER, e um nó que some não fala. "É a sua vez" tem texto, mas o
// mesmo trecho também escreve "Vez de Bia" — marcá-lo como região viva faria o
// leitor narrar cada troca de vez da mesa inteira, que é ruído em cima de um
// jogo de quatro pessoas.
//
// Nesses casos o anúncio explícito é o mecanismo, e ele tem um preço: como não
// há nó na árvore, nada impede que ele saia duas vezes. É esse preço que esta
// classe paga.
//
// ===========================================================================
// O QUE ESTA CLASSE GARANTE
// ===========================================================================
//
//   * UMA VEZ POR TRANSIÇÃO. Reconstruir a tela com o mesmo valor não fala.
//     A tela do lobby é reconstruída a cada aviso do transporte — e o
//     transporte avisa a cada mensagem do servidor.
//
//   * NADA NA PRIMEIRA VEZ. O primeiro valor é ANCORAGEM, não transição:
//     montar uma tela que já está no estado X não é a notícia de ter chegado
//     em X.
//
//   * GERAÇÃO NOVA NÃO É TRANSIÇÃO. Quando a sessão vira — logout, troca de
//     conta, transporte religado — o valor anterior pertence a uma sessão que
//     não existe mais. Comparar através dessa fronteira faria o app anunciar
//     "conexão perdida" para quem acabou de sair da conta por vontade própria.
//     A geração nova reancora em silêncio.
//
// NÃO EXISTE AQUI UM "DESCARTAR", e a ausência é deliberada. A tentação é
// óbvia: um interruptor que cale a sentinela quando a tela morre, para o caso
// de um aviso atrasado. Só que os dois donos de sentinela deste aplicativo a
// guardam atrás de um ouvinte que eles mesmos soltam no `dispose`, e de um
// `didUpdateWidget` que não roda em widget desmontado. O interruptor guardaria
// um caminho que não existe — e um guarda que nenhum teste consegue derrubar
// não é proteção, é a impressão de proteção. Quem precisar de um que o
// escreva junto com o caso que o mata.

import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// Diz [frase] ao leitor de tela agora, na janela de [contexto].
///
/// `sendAnnouncement`, e não `announce`: o segundo está obsoleto desde
/// 3.35 porque assume que existe uma janela só, e o aplicativo não tem por que
/// carregar essa suposição. A janela sai do próprio contexto de quem fala.
///
/// Frase vazia não vira anúncio: um anúncio em branco interrompe o que o leitor
/// estava dizendo e não coloca nada no lugar.
///
/// [urgencia] hoje só muda alguma coisa no motor web; nas outras plataformas
/// ela é declaração de intenção, e fica escrita para o dia em que passar a
/// valer.
void anunciar(
  BuildContext contexto,
  String frase, {
  Assertiveness urgencia = Assertiveness.polite,
}) {
  if (frase.isEmpty) return;
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(contexto),
      frase,
      TextDirection.ltr,
      assertiveness: urgencia,
    ),
  );
}

/// Guarda o último valor visto de um estado e responde uma pergunta só: isto
/// aqui é NOVIDADE?
class SentinelaDeTransicao<T> {
  T? _ultimo;
  bool _ancorada = false;
  int _geracao = 0;

  /// O último valor visto, ou nulo enquanto nada foi visto.
  T? get ultimo => _ultimo;

  /// Fixa [valor] como ponto de partida SEM considerá-lo transição.
  void ancorar(T valor, {int geracao = 0}) {
    _ultimo = valor;
    _ancorada = true;
    _geracao = geracao;
  }

  /// `true` só quando [valor] difere do anterior DENTRO da mesma [geracao].
  bool mudou(T valor, {int geracao = 0}) {
    if (!_ancorada || _geracao != geracao) {
      ancorar(valor, geracao: geracao);
      return false;
    }
    if (_ultimo == valor) return false;
    _ultimo = valor;
    return true;
  }
}
