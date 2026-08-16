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

class RaizDoAplicativo extends StatefulWidget {
  const RaizDoAplicativo({
    super.key,
    this.sessao,
    this.autenticacao,
    this.online,
    this.duracaoDaSplash,
    this.somNaSplash = true,
    this.limiteDeResolucao,
  });

  /// A sessão canônica. Nula em produção — a raiz monta a de Firebase.
  final SessaoDoJogador? sessao;

  /// Os comandos de entrar e sair. Nulos em produção.
  final ComandosDeAutenticacao? autenticacao;

  /// O transporte. Nulo em produção — a raiz o monta amarrado à sessão.
  final OnlineService? online;

  /// Repassados à casca. Ver `casca_de_producao.dart`.
  final Duration? duracaoDaSplash;
  final bool somNaSplash;
  final Duration? limiteDeResolucao;

  @override
  State<RaizDoAplicativo> createState() => _RaizDoAplicativoState();
}

class _RaizDoAplicativoState extends State<RaizDoAplicativo> {
  late final SessaoDoJogador _sessao;
  late final ComandosDeAutenticacao _autenticacao;
  late final OnlineService _online;
  late final PonteSessaoOnline _ponte;

  // Só o que esta raiz criou é descartado por ela.
  late final bool _sessaoEhMinha;
  late final bool _onlineEhMeu;

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
  }

  @override
  void dispose() {
    _ponte.dispose();
    if (_onlineEhMeu) _online.dispose();
    if (_sessaoEhMinha) _sessao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Os três escopos ficam ACIMA do `MaterialApp` de propósito: as rotas
    // empurradas pelo `Navigator` herdam daqui, e é isso que permite a uma tela
    // aberta por `push` ler a sessão, sair da conta e usar o mesmo transporte.
    return EscopoSessao(
      sessao: _sessao,
      child: EscopoAutenticacao(
        comandos: _autenticacao,
        child: EscopoTransporte(
          online: _online,
          child: MaterialApp(
            title: 'Buraco Master VIP',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
            home: CascaDeProducao(
              duracaoDaSplash: widget.duracaoDaSplash,
              somNaSplash: widget.somNaSplash,
              limiteDeResolucao: widget.limiteDeResolucao,
            ),
          ),
        ),
      ),
    );
  }
}
