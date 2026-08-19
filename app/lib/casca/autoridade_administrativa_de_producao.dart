// autoridade_administrativa_de_producao.dart — a ligação entre a sessão e as
// telas que precisam saber se quem está logado administra.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO É UM ARQUIVO, E NÃO UM `sessao.temAutoridadeAdministrativa`
// DIRETO NA TELA
// ---------------------------------------------------------------------------
//
// `screens/torneios_screens.dart` recebe uma [FonteDePapel] — uma porta com um
// método. Se ela recebesse a `SessaoDoJogador` inteira, a tela passaria a poder
// ler identidade, geração, credencial e o estado de carregamento, e o próximo
// requisito ("mostrar o nome de quem administra") seria atendido lendo mais um
// campo em vez de recebendo mais um dado. É assim que uma tela vira um segundo
// dono de sessão sem ninguém decidir isso em lugar nenhum.
//
// Este adaptador é a peça que impede o encurtamento: a tela pergunta a única
// coisa que tem direito de perguntar, e a resposta continua vindo do objeto que
// conhece a geração da sessão.

import '../sessao/papel_de_sessao.dart';
import '../sessao/sessao_do_jogador.dart';

/// O papel de quem está logado NESTA sessão.
///
/// Delega — não decide. Toda a proteção contra resposta atrasada e troca de
/// conta mora em [SessaoDoJogador.temAutoridadeAdministrativa], e é de lá que a
/// resposta sai; repetir a trava aqui criaria uma segunda regra, que um dia
/// discordaria da primeira.
class AutoridadeAdministrativaDaSessao implements FonteDePapel {
  const AutoridadeAdministrativaDaSessao(this._sessao);

  final SessaoDoJogador _sessao;

  @override
  Future<bool> ehAdministrador() => _sessao.temAutoridadeAdministrativa();

  // A IGUALDADE É POR SESSÃO, e é ela que faz as telas reconsultarem na troca
  // de conta. Elas comparam a fonte recebida (`widget.autoridade !=
  // anterior.autoridade`) para decidir se a resposta em voo ainda vale; sem
  // isto, dois adaptadores da MESMA sessão seriam objetos diferentes e a tela
  // perguntaria de novo a cada reconstrução, e — pior — duas sessões
  // diferentes nunca seriam distinguidas se a igualdade fosse só de tipo.
  @override
  bool operator ==(Object outro) =>
      identical(this, outro) ||
      outro is AutoridadeAdministrativaDaSessao &&
          identical(outro._sessao, _sessao);

  @override
  int get hashCode => identityHashCode(_sessao);
}

/// Açúcar de leitura para o ponto de construção da tela.
///
/// `CentralTorneiosScreen(autoridade: autoridadeAdministrativaDe(sessao))` diz,
/// em uma linha, de onde vem a permissão — e não existe sobrecarga que aceite
/// um `bool`, de propósito.
FonteDePapel autoridadeAdministrativaDe(SessaoDoJogador sessao) =>
    AutoridadeAdministrativaDaSessao(sessao);
