// home_de_producao.dart — a tela inicial do aplicativo publicável.
//
// ---------------------------------------------------------------------------
// O QUE ESTA TELA PODE AFIRMAR
// ---------------------------------------------------------------------------
//
// Só o que tem fonte. Hoje a única autoridade que o cliente alcança é a
// identidade pública da sessão — apelido e avatar. Não há autoridade de saldo,
// de liga, de temporada nem de gente online, então esses lugares ficam VAZIOS.
//
// O host anterior preenchia todos eles com `InicioVM.mock()`, e o resultado era
// uma Home que dizia, para qualquer pessoa que instalasse o aplicativo, que ela
// se chamava pelo nome e pelo e-mail da dona do projeto, tinha mil moedas e
// jogava na Liga Diamante. Nada disso vinha de lugar nenhum.
//
// A regra que substitui aquilo é simples: dado sem fonte não é desenhado. Não
// vira zero, não vira travessão com cara de valor e não vira "carregando" para
// sempre — o elemento inteiro sai da tela.
//
// ---------------------------------------------------------------------------
// MENU: O QUE EXISTE E O QUE AINDA NÃO
// ---------------------------------------------------------------------------
//
// Quatro destinos são reais: Perfil, Jogar, Como jogar e Ajustes. Os outros
// quatro apontavam para prévias visuais — Ranking, Recompensas, Amigos e Loja
// mostram dados inventados e nenhum deles tem backend ligado no cliente. Eles
// continuam na grade, apagados e com selo, e o toque avisa. Sumir com o item
// esconderia o plano; abrir a prévia venderia maquete como funcionalidade.

import 'package:flutter/material.dart';

// `mesa.dart`, e não `screens/mesa_screen.dart`: a primeira é a mesa JOGÁVEL,
// com o motor de partidas dentro; a segunda é a camada visual pura, que recebe
// um `MesaVM` pronto e não sabe jogar nada.
import '../mesa.dart' show MesaScreen;
import '../pages/perfil_page.dart';
import '../ranking/estado_ranking.dart';
import '../screens/como_jogar_screen.dart';
import '../screens/inicio_screen.dart';
import '../screens/perfil_screen.dart' show NavDestino;
import '../sessao/escopo_sessao.dart';
import '../sessao/identidade_publica_sessao.dart';
import 'configuracoes_de_producao.dart';
import 'onde_jogar_de_producao.dart';

class HomeDeProducao extends StatelessWidget {
  const HomeDeProducao({super.key});

  @override
  Widget build(BuildContext context) {
    final identidade = EscopoSessao.identidadeDe(context);

    return InicioScreen(
      vm: _vmDaSessao(identidade),
      // A fase da identidade MANDA na tela, do mesmo jeito que no Ranking:
      // enquanto ela carrega, a Home mostra o esqueleto; se falhou, mostra erro
      // com retry. O que ela não faz em nenhum dos dois é seguir em frente com
      // um cabeçalho preenchido por conta própria.
      estado: switch (identidade.fase) {
        FaseIdentidade.carregando ||
        FaseIdentidade.naoCarregada => InicioEstado.carregando,
        FaseIdentidade.falha => InicioEstado.erro,
        FaseIdentidade.naoAutenticado ||
        FaseIdentidade.disponivel => InicioEstado.normal,
      },
      mensagemErro: identidade.fase == FaseIdentidade.falha
          ? 'Não consegui carregar seu perfil de jogador agora. Tenta de novo?'
          : null,
      onJogar: () => _abrirOndeJogar(context),
      onAbrirPerfil: () => _abrirPerfil(context),
      onHistorico: () => _aindaNao(context, 'Histórico de partidas'),
      // `temporada` e `lobby` são nulos nesta Home, então estes dois nunca
      // chegam a ser acionados. Continuam preenchidos porque um callback vazio
      // viraria, no dia em que a fonte existir, um botão silencioso.
      onAbrirTemporada: () => _aindaNao(context, 'Temporadas'),
      onAbrirLobby: () => _aindaNao(context, 'Saguão'),
      onMenuTap: (id) => _menu(context, id),
      // Retry EXPLÍCITO, nascido do gesto. `recarregar` é deduplicada: apertar
      // duas vezes não abre duas chamadas.
      onRecarregar: () => EscopoSessao.talvezDe(context)?.recarregar(),
      onNavTap: (destino) => _nav(context, destino),
    );
  }

  // ---------------------------------------------------------------------------
  // O VM
  // ---------------------------------------------------------------------------

  InicioVM _vmDaSessao(EstadoIdentidadeSessao estado) {
    final identidade = estado.identidade;
    return InicioVM(
      jogador: CabecalhoJogador(
        nome: _nomeDeApresentacao(identidade),
        // O e-mail da conta NÃO é exibido. Ele não acrescenta nada a quem já
        // está logado e é dado pessoal numa tela que qualquer um do lado vê.
        email: '',
        avatar: identidade?.avatarRef ?? '👑',
        moldura: null,
        // Sem autoridade de economia no cliente.
        moedas: null,
        // A liga vem do estado canônico de ranking, e não de um `null` escrito
        // aqui. O valor final é o mesmo — hoje não há autoridade, e a Home
        // omite a linha. O que muda é QUEM decide: a Home passa a ler a mesma
        // constante que o `PerfilService`, em vez de as duas telas concluírem
        // por conta própria o que significa "sem ranking". Era exatamente essa
        // decisão duplicada que deixava a Home honesta e o Perfil inventando
        // Bronze a partir do mesmo nada.
        liga: rankingDaCascaPublicavel.liga,
      ),
      // Sem autoridade de temporada nem de saguão.
      temporada: null,
      lobby: null,
      menu: const [
        MenuItem(
          id: 'perfil',
          label: 'Perfil',
          icone: 'assets/inicio/menu_perfil.webp',
        ),
        MenuItem(
          id: 'ranking',
          label: 'Ranking',
          icone: 'assets/inicio/menu_ranking.webp',
          disponivel: false,
        ),
        MenuItem(
          id: 'recompensas',
          label: 'Recompensas',
          icone: 'assets/inicio/menu_recompensas.webp',
          disponivel: false,
        ),
        MenuItem(
          id: 'amigos',
          label: 'Amigos',
          icone: 'assets/inicio/menu_amigos.webp',
          disponivel: false,
        ),
        MenuItem(
          id: 'loja',
          label: 'Loja VIP',
          icone: 'assets/inicio/menu_loja_vip.webp',
          disponivel: false,
        ),
        MenuItem(
          id: 'jogar',
          label: 'Jogar',
          icone: 'assets/inicio/menu_jogar.webp',
        ),
        MenuItem(
          id: 'tutorial',
          label: 'Como jogar',
          icone: 'assets/inicio/menu_como_jogar.webp',
        ),
        MenuItem(
          id: 'ajustes',
          label: 'Ajustes',
          icone: 'assets/inicio/menu_ajustes.webp',
        ),
      ],
    );
  }

  /// Como chamar a pessoa no cabeçalho.
  ///
  /// FALLBACK DE APRESENTAÇÃO, e não de identidade — a distinção é a mesma que
  /// `IdentidadePublica.apelido` documenta. O `publicId` entra quando não há
  /// apelido escolhido porque ele É o identificador público dela; 'Jogador(a)'
  /// entra quando não há identidade nenhuma, e é um rótulo, não um nome: ninguém
  /// consegue buscar por ele e ele não é gravado em lugar nenhum.
  ///
  /// O que nunca aparece aqui é o `uid`, e nunca aparece um nome inventado.
  String _nomeDeApresentacao(IdentidadePublica? identidade) {
    final apelido = identidade?.apelido.trim() ?? '';
    if (apelido.isNotEmpty) return apelido;
    final publico = identidade?.publicId ?? '';
    if (publico.isNotEmpty) return publico;
    return 'Jogador(a)';
  }

  // ---------------------------------------------------------------------------
  // Navegação
  // ---------------------------------------------------------------------------

  void _menu(BuildContext context, String id) {
    switch (id) {
      case 'perfil':
        _abrirPerfil(context);
      case 'jogar':
        _abrirOndeJogar(context);
      case 'tutorial':
        _abrirComoJogar(context);
      case 'ajustes':
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ConfiguracoesDeProducao(),
          ),
        );
      case 'ranking':
        _aindaNao(context, 'Ranking');
      case 'recompensas':
        _aindaNao(context, 'Recompensas');
      case 'amigos':
        _aindaNao(context, 'Amigos');
      case 'loja':
        _aindaNao(context, 'Loja VIP');
      default:
        _aindaNao(context, id);
    }
  }

  void _nav(BuildContext context, NavDestino destino) {
    switch (destino) {
      case NavDestino.inicio:
        break; // já estamos aqui
      case NavDestino.perfil:
        _abrirPerfil(context);
      case NavDestino.ranking:
        _aindaNao(context, 'Ranking');
      case NavDestino.loja:
        _aindaNao(context, 'Loja VIP');
    }
  }

  void _abrirPerfil(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PerfilPage()));

  void _abrirOndeJogar(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const OndeJogarDeProducao()));

  void _abrirComoJogar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (rota) => ComoJogarScreen(
          onVoltar: () => Navigator.of(rota).maybePop(),
          onJogarTreino: () => Navigator.of(rota).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const MesaScreen()),
          ),
        ),
      ),
    );
  }

  /// O aviso honesto. Não é "em breve" com data: é "ainda não existe".
  void _aindaNao(BuildContext context, String assunto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$assunto ainda não está disponível nesta versão.'),
          duration: const Duration(milliseconds: 1600),
          backgroundColor: const Color(0xFF2A1B0E),
        ),
      );
  }
}
