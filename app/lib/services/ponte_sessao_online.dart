// ponte_sessao_online.dart — o SEAM entre a sessão do jogador e o transporte.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO SÓ PARA ISTO
// ---------------------------------------------------------------------------
//
// As duas camadas foram escritas separadas e cada uma resolveu bem o seu lado:
// `SessaoDoJogador` sabe quem está logado e quando isso muda; `OnlineService`
// sabe apresentar credencial e manter socket. Juntá-las tinha exatamente dois
// jeitos errados e um certo.
//
//   ERRADO 1 — a sessão chamar o transporte. A camada de identidade passaria a
//   conhecer WebSocket, e um teste de logout precisaria de socket.
//
//   ERRADO 2 — o transporte observar o Firebase por conta própria. Foi assim
//   que a Folha B nasceu, e é o que cria o segundo dono de autenticação: dois
//   objetos com opinião sobre quem está logado, e nenhum dos dois sabendo da
//   geração do outro.
//
//   CERTO — um terceiro objeto, pequeno e sem estado de domínio, que OBSERVA a
//   sessão e TRADUZ cada troca em uma única transição do transporte. É este.
//
// A direção da dependência é uma só: `services/` conhece `sessao/`, e
// `sessao/` não conhece `services/`. Não há ciclo entre UI, sessão e
// transporte — a UI monta os dois e entrega um ao outro, e nenhum dos dois
// conhece a UI.
//
// ---------------------------------------------------------------------------
// A PONTE NÃO TOMA INICIATIVA — ELA PRESERVA A DO JOGADOR
// ---------------------------------------------------------------------------
//
// Numa troca de conta, a ponte derruba tudo e só então religa a conexão SE o
// jogador já tinha pedido para estar online (`online.querConectado`). Isso não
// é a ponte decidindo conectar: é ela não fazendo o jogador perder um pedido
// que ele já tinha feito.
//
// A alternativa — sempre deixar em `desconectado` — tem um buraco concreto: a
// tela do lobby chama `conectar()` ao montar, e se o login chegar logo depois,
// a tentativa em voo morreria na troca de geração e ninguém a refaria. O
// jogador ficaria olhando "desconectado" sem nada para apertar.
//
// Do outro lado, logout NÃO religa: sem sessão autenticada não há credencial, e
// insistir só produziria "entre na sua conta" em loop.
//
// O que a ponte continua não decidindo: ela nunca conecta um transporte que o
// jogador jamais pediu para conectar. Essa iniciativa é da Casca de Produção,
// quando existir — e é para ela que este seam fica explícito aqui, em vez de
// virar um `conectar()` escondido dentro do transporte.

import '../sessao/sessao_do_jogador.dart';
import 'online_service.dart';

/// Monta o [OnlineService] de produção, amarrado à [sessao] canônica.
///
/// É a resposta à pergunta que o construtor obrigatório do [OnlineService] faz:
/// de onde vem a credencial. Vem de `sessao.obterCredencial` — o método que
/// carrega a trava de geração — e de nenhum outro lugar.
///
/// [endpoint] é a costura do ENDEREÇO, e existe pelo mesmo motivo de
/// [abrirCanal]: em produção fica nulo, e o transporte resolve o endereço pela
/// configuração do build (`EndpointServidor`). O teste injeta um endereço
/// sintético para exercitar credencial e transporte sem depender de
/// `--dart-define` — e sem que volte a existir URL de produção no código.
OnlineService criarOnlineServiceDaSessao(
  SessaoDoJogador sessao, {
  AbrirCanal? abrirCanal,
  Uri? endpoint,
}) => OnlineService(
  obterIdToken: sessao.obterCredencial,
  abrirCanal: abrirCanal,
  endpoint: endpoint,
);

/// Propaga trocas de sessão para o transporte — uma transição por troca.
///
/// Escuta a [SessaoDoJogador] e reage SÓ quando a geração muda. É a distinção
/// que importa: a sessão notifica também quando a identidade pública avança de
/// `carregando` para `disponivel`, e derrubar o socket a cada avanço desses
/// tiraria o jogador da mesa por causa de uma tela de Ranking carregando.
///
/// Login, logout e troca de conta sobem a geração. Reemissão do mesmo uid (o
/// fluxo de autenticação repete a cada renovação de token) não sobe — então
/// renovar credencial não derruba conexão nenhuma.
class PonteSessaoOnline {
  PonteSessaoOnline({required this.sessao, required this.online})
    : _geracao = sessao.geracao {
    sessao.addListener(_aoMudarSessao);
  }

  final SessaoDoJogador sessao;
  final OnlineService online;

  int _geracao;
  bool _descartada = false;

  /// Quantas transições esta ponte já propagou.
  ///
  /// Existe para o teste conseguir afirmar um NÚMERO: "uma troca de jogador
  /// produziu UMA transição" é uma afirmação verificável; "propagou direito"
  /// não é. É o mesmo motivo de `SessaoDoJogador.chamadasEmitidas` existir.
  int get transicoesPropagadas => _transicoes;
  int _transicoes = 0;

  void _aoMudarSessao() {
    if (_descartada) return;
    final agora = sessao.geracao;
    if (agora == _geracao) return; // só a fase da identidade mudou
    _geracao = agora;
    _transicoes++;

    // O pedido do jogador é lido ANTES de encerrar — `encerrarSessao` o apaga.
    final queriaEstarOnline = online.querConectado;

    // UMA chamada, que faz tudo: derruba socket, cancela reconexão e refresh
    // pendentes, esvazia a fila, sobe a geração do transporte e apaga o estado
    // privado do jogador anterior.
    online.encerrarSessao();

    // E só então, se havia pedido e há com quem autenticar, a conexão volta —
    // do zero, com credencial nova, sem nada do jogador anterior em mãos.
    if (queriaEstarOnline && sessao.estado.autenticado) {
      online.conectar();
    }
  }

  void dispose() {
    _descartada = true;
    sessao.removeListener(_aoMudarSessao);
  }
}
