// raiz_do_aplicativo.dart — o widget mais alto do aplicativo publicável.
//
// ---------------------------------------------------------------------------
// O QUE MUDOU, E POR QUE
// ---------------------------------------------------------------------------
//
// A raiz anterior montava a sessão certo e, logo abaixo, entregava a tela a um
// host de PRÉ-VISUALIZAÇÃO: `SplashOficialScreen(proximaTela: _InicioPreviewHost)`,
// e o host construía `InicioVM.mock()`. O aplicativo publicável abria numa
// maquete — com nome, e-mail, saldo e liga de uma pessoa real escritos no
// código-fonte — e a sessão canônica ficava pendurada acima sem mandar em nada.
//
// Agora a raiz constrói os quatro objetos de que o aplicativo inteiro depende e
// os pendura na árvore. Ela não chama nenhum deles: não há `initState` de
// identidade aqui, não há `authStateChanges()` e não há decisão de tela. Quem
// decide o destino é `CascaDeProducao`, lendo a sessão.
//
//   SessaoDoJogador        — quem está logado, a geração, a credencial
//   ComandosDeAutenticacao — entrar e sair (só isso)
//   OnlineService          — o transporte, desligado até alguém pedir
//   PonteSessaoOnline      — traduz troca de sessão em transição do transporte
//   RankingDaSessao        — a liga e a colocação reais de quem está logado
//
// A ORDEM IMPORTA: a ponte é montada aqui, e não na tela do lobby, porque um
// logout disparado na tela de Ajustes precisa derrubar o socket mesmo que o
// lobby nunca tenha sido aberto.
//
// ---------------------------------------------------------------------------
// AS COSTURAS DE TESTE
// ---------------------------------------------------------------------------
//
// Todos os quatro podem ser injetados. Não é conveniência: sem isso, provar
// "partida fria com sessão válida abre a Home" exigiria Firebase inicializado
// dentro do `flutter test`, e o caso simplesmente não seria testado. Quem
// injeta é dono do que injetou — a raiz só descarta o que ela mesma criou.

import 'package:flutter/material.dart';

import '../ranking/escopo_ranking.dart';
import '../ranking/leitor_ranking.dart';
import '../ranking/ranking_da_sessao.dart';
import '../ranking/ranking_transporte.dart';
import '../ranking/ranking_transporte_firebase.dart';
import '../services/online_service.dart';
import '../services/ponte_sessao_online.dart';
import '../sessao/autenticacao_firebase.dart';
import '../sessao/comandos_de_autenticacao.dart';
import '../sessao/escopo_sessao.dart';
import '../sessao/sessao_do_jogador.dart';
import '../sessao/sessao_firebase.dart';
import 'casca_de_producao.dart';
import 'escopo_autenticacao.dart';
import 'escopo_transporte.dart';
import 'splash/fonte_da_animacao_rive.dart';
import 'splash/splash_rive_screen.dart';
import 'splash/variante_de_splash.dart';

class RaizDoAplicativo extends StatefulWidget {
  const RaizDoAplicativo({
    super.key,
    this.sessao,
    this.autenticacao,
    this.online,
    this.transporteRanking,
    this.duracaoDaSplash,
    this.somNaSplash = true,
    this.limiteDeResolucao,
    this.varianteDaSplash = varianteDeSplashDoBuild,
    this.fonteDaSplashRive,
    this.onMedicaoDaSplash,
  });

  /// A sessão canônica. Nula em produção — a raiz monta a de Firebase.
  final SessaoDoJogador? sessao;

  /// Os comandos de entrar e sair. Nulos em produção.
  final ComandosDeAutenticacao? autenticacao;

  /// O transporte. Nulo em produção — a raiz o monta amarrado à sessão.
  final OnlineService? online;

  /// O transporte de ranking. Nulo em produção — a raiz monta o de Firebase.
  ///
  /// Injetável pela mesma razão dos outros três: sem isto, provar "a Home mostra
  /// a liga que a autoridade devolveu" exigiria Firebase dentro do
  /// `flutter test`, e o caso não seria testado.
  final TransporteRanking? transporteRanking;

  /// Repassados à casca. Ver `casca_de_producao.dart`.
  final Duration? duracaoDaSplash;
  final bool somNaSplash;
  final Duration? limiteDeResolucao;

  /// Qual das duas aberturas mostrar, e de onde a arte da alternativa vem.
  ///
  /// Atravessam a raiz sem que ela os leia: a escolha é da configuração de
  /// build e o destino continua sendo da sessão. A raiz não decide tela — nem
  /// esta.
  final VarianteDeSplash varianteDaSplash;
  final FonteDaAnimacaoRive? fonteDaSplashRive;
  final void Function(MedicaoDaSplashRive)? onMedicaoDaSplash;

  @override
  State<RaizDoAplicativo> createState() => _RaizDoAplicativoState();
}

class _RaizDoAplicativoState extends State<RaizDoAplicativo> {
  late final SessaoDoJogador _sessao;
  late final ComandosDeAutenticacao _autenticacao;
  late final OnlineService _online;
  late final PonteSessaoOnline _ponte;
  late final RankingDaSessao _ranking;

  // Só o que esta raiz criou é descartado por ela.
  late final bool _sessaoEhMinha;
  late final bool _onlineEhMeu;

  /// A abertura já tocou nesta execução do aplicativo.
  ///
  /// MORA AQUI, e não na casca, porque a casca é reconstruída do zero a cada
  /// troca de sessão (ver a chave do `MaterialApp` abaixo). Se o estado
  /// morasse lá, a animação de abertura tocaria de novo depois de cada login e
  /// de cada logout.
  bool _aberturaTerminou = false;

  @override
  void initState() {
    super.initState();

    _sessaoEhMinha = widget.sessao == null;
    _sessao = widget.sessao ?? criarSessaoDoJogador();

    _autenticacao = widget.autenticacao ?? AutenticacaoFirebase();

    _onlineEhMeu = widget.online == null;
    // `criarOnlineServiceDaSessao` é a única forma de o transporte obter
    // credencial: ele não sabe falar com o provedor de autenticação, e é para
    // continuar não sabendo.
    _online = widget.online ?? criarOnlineServiceDaSessao(_sessao);

    // A ponte não conecta nada. Ela só garante que uma troca de sessão vire UMA
    // transição do transporte — inclusive quando a troca é um logout.
    _ponte = PonteSessaoOnline(sessao: _sessao, online: _online);

    _ranking = RankingDaSessao(
      leitor: LeitorDeRanking(
        transporte: widget.transporteRanking ?? TransporteRankingFirebase(),
      ),
    );
    // Mesmo desenho da ponte acima: a sessão manda, o ranking obedece. Um
    // listener, e não uma chamada do `build`, porque `aoMudarSessao` publica
    // "carregando" na hora — e notificar durante a construção da árvore é erro
    // de framework, não detalhe de estilo.
    _sessao.addListener(_sincronizarRanking);
    // A primeira sincronização não pode esperar a próxima notificação: numa
    // partida fria com sessão já resolvida, ela nunca viria.
    _sincronizarRanking();
  }

  @override
  void dispose() {
    _sessao.removeListener(_sincronizarRanking);
    _ranking.dispose();
    _ponte.dispose();
    if (_onlineEhMeu) _online.dispose();
    if (_sessaoEhMinha) _sessao.dispose();
    super.dispose();
  }

  /// Traduz o estado da sessão em "pergunte o ranking desta pessoa".
  ///
  /// [RankingDaSessao.aoMudarSessao] ignora repetição, então uma notificação
  /// que só mudou a fase da identidade não vira consulta nova.
  void _sincronizarRanking() {
    _ranking.aoMudarSessao(
      geracao: _sessao.geracao,
      publicId: _sessao.estado.publicId,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Os quatro escopos ficam ACIMA do `MaterialApp` de propósito: as rotas
    // empurradas pelo `Navigator` herdam daqui, e é isso que permite a uma tela
    // aberta por `push` ler a sessão, sair da conta e usar o mesmo transporte.
    // Eles também ficam acima da chave abaixo, então sobrevivem à troca de
    // sessão — quem morre é a navegação, não a sessão.
    return EscopoSessao(
      sessao: _sessao,
      child: EscopoAutenticacao(
        comandos: _autenticacao,
        child: EscopoTransporte(
          online: _online,
          child: EscopoRanking(
            ranking: _ranking,
            child: ListenableBuilder(
              listenable: _sessao,
              builder: (context, _) => MaterialApp(
                // A CHAVE É O QUE APAGA A PILHA DE NAVEGAÇÃO NA TROCA DE SESSÃO.
                //
                // Trocar a tela de baixo não basta: `Navigator.push` empilha
                // rotas SOBRE a `home`, e trocar a `home` deixa as de cima
                // intactas. Sem isto, alguém que saísse da conta com a tela de
                // Ajustes ou a do lobby abertas continuaria olhando para elas —
                // telas privadas, de uma sessão que acabou.
                //
                // O jeito imperativo seria a tela de logout dar `popUntil`. Isso
                // devolve a decisão de navegação para quem saiu, exige que TODA
                // superfície futura de logout se lembre de fazer o mesmo, e não
                // cobre a troca de conta sem logout — em que a pilha do jogador
                // anterior também tem de morrer.
                //
                // A geração sobe uma vez por troca de sessão, e não quando só a
                // fase da identidade muda: um Ranking carregando não derruba a
                // navegação de ninguém.
                key: ValueKey<int>(_sessao.geracao),
                title: 'Buraco Master VIP',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.dark,
                ),
                home: CascaDeProducao(
                  aberturaTerminou: _aberturaTerminou,
                  onAberturaConcluida: () {
                    if (mounted && !_aberturaTerminou) {
                      setState(() => _aberturaTerminou = true);
                    }
                  },
                  duracaoDaSplash: widget.duracaoDaSplash,
                  somNaSplash: widget.somNaSplash,
                  limiteDeResolucao: widget.limiteDeResolucao,
                  varianteDaSplash: widget.varianteDaSplash,
                  fonteDaSplashRive: widget.fonteDaSplashRive,
                  onMedicaoDaSplash: widget.onMedicaoDaSplash,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
