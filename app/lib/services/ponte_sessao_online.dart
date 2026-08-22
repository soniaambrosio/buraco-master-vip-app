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
// A INICIATIVA MORA AQUI — E ISTO MUDOU NA OS 38.2
// ---------------------------------------------------------------------------
//
// ANTES: a ponte não conectava nada. Quem tomava a iniciativa era a tela do
// lobby, ao montar. A justificativa estava escrita e era boa para o que se
// sabia então — "uma raiz que conectasse sozinha abriria socket para quem só
// queria treinar contra os robôs".
//
// O QUE MUDOU: passou a existir uma pergunta que só o servidor responde e que
// a Home faz antes de qualquer tela de jogo — QUANTAS PESSOAS ESTÃO ONLINE. A
// resposta vem da presença agregada (OS 38.1), e presença é, por definição,
// uma afirmação sobre quem está no aplicativo AGORA.
//
// Com a iniciativa na tela do lobby, essa afirmação ficava impossível de fazer
// com honestidade: uma pessoa com o aplicativo aberto na Home não estaria
// conectada, logo não seria contada — e o número que a Home mostra estaria
// errado exatamente sobre quem está olhando para ele. Pior: o número só
// passaria a incluir a pessoa DEPOIS de ela visitar o Lobby, o que faz o total
// subir por causa de navegação, e não de gente chegando.
//
// Então a iniciativa subiu para cá, que é o lugar que o comentário anterior já
// apontava ("essa iniciativa é da Casca de Produção, quando existir"). Ela
// existe, e é esta ponte.
//
// O QUE NÃO MUDOU, e continua valendo:
//
//   * SÓ COM SESSÃO AUTENTICADA. Sem credencial não há o que apresentar, e
//     insistir produziria "entre na sua conta" em laço. Logout NÃO religa.
//   * UMA TRANSIÇÃO POR TROCA. Numa troca de conta a ponte derruba tudo e só
//     então religa — do zero, com credencial nova, sem nada do jogador
//     anterior em mãos.
//   * A PONTE NÃO CONHECE TELA. Ela observa a sessão e fala com o transporte.
//     Nenhuma rota, nenhum widget e nenhum `BuildContext` entram aqui.
//
// O treino contra robôs continua sem depender disto: ele roda no aparelho, e
// um socket aberto não o afeta. O que se paga é uma conexão para quem está
// logado e não vai jogar online — e é exatamente essa conexão que a presença
// precisa para não mentir.

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
    // [DESCOBERTA §3.1] PARTIDA FRIA COM SESSÃO JÁ RESTAURADA.
    //
    // O aplicativo sobe, a sessão já vem autenticada e a Home é a primeira
    // tela. Nesse caminho a sessão NÃO notifica — ela já estava no estado
    // final quando a ponte foi construída —, então esperar pela notificação
    // deixaria a presença desligada até a pessoa fazer logout e login.
    //
    // É o caso mais comum que existe: toda abertura de aplicativo de quem já
    // usou uma vez.
    _talvezConectar();
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

    // UMA chamada, que faz tudo: derruba socket, cancela reconexão e refresh
    // pendentes, esvazia a fila, sobe a geração do transporte, apaga o estado
    // privado do jogador anterior e APAGA O RETRATO DA DESCOBERTA.
    //
    // `querConectado` deixou de ser lido aqui, e isso não é descuido: desde
    // esta OS a conexão não depende mais de o jogador ter pedido. Ela depende
    // de haver sessão autenticada, e é a linha abaixo que decide isso.
    online.encerrarSessao();

    // E só então, se há com quem autenticar, a conexão volta — do zero, com
    // credencial nova, sem nada do jogador anterior em mãos. Logout cai no
    // `else` implícito: fica desconectado, que é o certo.
    _talvezConectar();
  }

  /// Liga o transporte SE — e só se — há sessão autenticada.
  ///
  /// Ponto único: a construção e a troca de sessão passam pelos dois pelo mesmo
  /// caminho, então não há como uma delas ganhar uma regra que a outra não tem.
  void _talvezConectar() {
    if (_descartada) return;
    if (!sessao.estado.autenticado) return;
    online.conectar();
  }

  void dispose() {
    _descartada = true;
    sessao.removeListener(_aoMudarSessao);
  }
}
