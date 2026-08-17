// lobby_online.dart — criar ou entrar numa mesa no servidor.
//
// ---------------------------------------------------------------------------
// A TELA NÃO É MAIS DONA DO TRANSPORTE
// ---------------------------------------------------------------------------
//
// Antes ela construía o `OnlineService` e a `PonteSessaoOnline` no
// `didChangeDependencies`, e os destruía ao sair. Duas coisas quebravam nisso, e
// as duas são exigência desta OS:
//
//   * um logout disparado FORA daqui — pela tela de Ajustes, que é onde o botão
//     de sair fica — não encontrava ponte nenhuma montada para derrubar o
//     socket. Ele morria junto com a tela, se a tela estivesse aberta, e por
//     acidente de ciclo de vida;
//
//   * duas rotas do lobby empilhadas construiriam dois transportes.
//
// Agora o transporte vem do escopo, montado uma vez pela raiz. Esta tela só faz
// duas coisas com ele: pede para conectar quando monta, e escuta para
// redesenhar. Não o desliga ao sair — sair da tela do lobby não é sair do jogo
// online, e derrubar a conexão aqui tiraria a pessoa da mesa por navegação.
//
// NÃO EXISTE AQUI um vigia de `FirebaseAuth.authStateChanges()`. A folha da
// conexão publicável tinha um: ao ver logout, chamava `encerrarPorLogout()`
// direto. Numa árvore com sessão canônica isso é um SEGUNDO dono de
// autenticação — uma tela com opinião própria sobre quem está logado, sem noção
// da geração da sessão. Quem observa a sessão e traduz cada troca numa única
// transição do transporte é a `PonteSessaoOnline`, montada na raiz. Ela cobre
// logout, login e troca de conta; o vigia cobria só logout.
//
// ---------------------------------------------------------------------------
// LOBBY → MESA É UMA TROCA DE CORPO, NÃO UMA ROTA NOVA
// ---------------------------------------------------------------------------
//
// Quando a visão deixa de dizer `lobby: true`, esta tela passa a desenhar a
// mesa completa NO MESMO LUGAR da pilha de navegação. Não há `push`.
//
// A alternativa imperativa — empurrar a mesa como rota quando a partida começa
// — tem três defeitos, e os três aparecem em produção antes de aparecer em
// teste. Primeiro: `OnlineService` notifica a cada mensagem do servidor, e um
// `push` dentro do ouvinte empilha uma mesa por atualização recebida. Dá para
// remendar com uma bandeira "já empurrei", e aí vem o segundo: um `pop` (o
// gesto de voltar do Android, que ninguém precisa de permissão para fazer)
// devolve a pessoa a um lobby cuja mesa já começou — uma tela que afirma
// "aguardando jogadores" sobre uma partida em andamento. O terceiro é a volta:
// rodada encerrada, queda, retomada e fim de partida viram, cada um, uma
// decisão de empilhar ou desempilhar, espalhada por vários pontos.
//
// Sendo o corpo desta rota, nada disso existe. O estado do servidor determina o
// que se desenha, e voltar significa a mesma coisa que sempre significou: sair
// da tela do online. É o mesmo raciocínio que `casca_de_producao.dart` usa para
// escolher entre Login e Home, e pelo mesmo motivo.
//
// ---------------------------------------------------------------------------
// ESTA TELA É A DONA DO EFEITO TERMINAL
// ---------------------------------------------------------------------------
//
// `OnlineService.aoEncerrar` é UM slot, chamado uma vez por encerramento
// autoritativo, e quem o ocupa é este objeto. A escolha não é de conveniência:
// o dono do efeito tem de ser quem já é dono do ciclo de vida da mesa, e é
// aqui que a mesa nasce (o corpo desta rota), aqui que ela troca de transporte
// e aqui que ela morre.
//
// A `MesaOnlineScreen` não serviria — ela é apresentação pura, é reconstruída a
// cada visão e some quando a partida volta ao lobby; uma assinatura ali nasceria
// e morreria junto com o desenho. A raiz também não: ela não sabe quando a
// pessoa está olhando a mesa, e um diálogo despachado de lá apareceria sobre a
// tela que estivesse por cima.
//
// O vínculo nasce no `didChangeDependencies` — nunca no `build`, que roda
// muitas vezes e criaria uma assinatura por quadro — e nasce ANTES de o
// transporte começar a entregar mensagens: o `conectar()` logo abaixo é
// disparado depois do quadro, e a assinatura já está de pé quando ele sai.
//
// ---------------------------------------------------------------------------
// O SLOT CUTUCA; O LIVRO É QUE MANDA
// ---------------------------------------------------------------------------
//
// Assinar `aoEncerrar` não basta, e a entrega anterior registrou por quê: entre
// o `dispose` de um vínculo e o `didChangeDependencies` do seguinte o slot fica
// vazio, e a pessoa pode simplesmente não estar na rota da mesa quando o
// servidor declara o fim. Um efeito entregue SÓ pelo slot desapareceria nessas
// janelas — sem erro, sem log e sem teste vermelho.
//
// Então o slot deixou de ser o caminho do efeito e virou um aviso de que talvez
// haja o que fazer. O que fazer está no livro (`OnlineService.efeitosTerminais`),
// que guarda cada encerramento como pendente até alguém APRESENTÁ-LO. Esta tela
// drena o livro em dois momentos, e os dois são o mesmo método:
//
//   * quando o transporte cutuca (o fim chegou com a tela montada);
//   * quando a tela assina (o fim já tinha chegado, e não havia quem o visse).
//
// O consumidor instalado no slot IGNORA o encerramento que recebe de parâmetro.
// Apresentar o que veio pela cutucada, e não o que está pendente no livro, seria
// voltar a ter duas fontes para o mesmo efeito — e a que chega pelo slot é
// justamente a que não sobrevive às janelas acima.
//
// A apresentação tem três tempos, e nenhum deles pode ser encurtado:
//
//   REIVINDICAR   antes de esperar o quadro. É o que impede que uma segunda
//                 cutucada, uma reconstrução ou uma reentrada abram um segundo
//                 diálogo para o mesmo fim enquanto o primeiro está a caminho.
//   APRESENTAR    depois do quadro, com tudo reconferido.
//   CONFIRMAR     só depois de o apresentador dizer que o aviso ENTROU na
//                 árvore. Se ele recusar, se ESTOURAR, ou se a rota morrer
//                 antes, a reivindicação é devolvida e o efeito volta a ficar
//                 pendente: adiado, não perdido.

import 'package:flutter/material.dart';

import '../services/online_service.dart';
import 'escopo_transporte.dart';
import 'mesa_online/encerramento_da_mesa.dart';
import 'mesa_online/estado_mesa_online.dart';
import 'mesa_online/mesa_online_screen.dart';
import 'mesa_online/porta_de_comandos_online.dart';

class LobbyOnline extends StatefulWidget {
  const LobbyOnline({super.key, this.apresentador});

  /// Quem apresenta o encerramento. Nulo em produção — e aí vale o diálogo da
  /// mesa. O teste injeta um contador, para provar QUANTAS vezes o efeito
  /// aconteceu sem depender de diálogo desenhado.
  final ApresentadorDeEncerramento? apresentador;

  @override
  State<LobbyOnline> createState() => _LobbyOnlineState();
}

class _LobbyOnlineState extends State<LobbyOnline> {
  OnlineService? _srv;
  bool _pediuConexao = false;

  /// A porta por onde as ações da mesa saem.
  ///
  /// Nasce e morre com o transporte que esta tela está usando — ela é um
  /// ouvinte dele, e uma porta apontando para um `OnlineService` trocado seria
  /// um ouvinte pendurado num objeto que já não é o da árvore.
  PortaDeComandosOnline? _porta;

  /// O consumidor do efeito terminal que ESTE objeto instalou, e a geração do
  /// vínculo.
  ///
  /// Os dois existem para a mesma pergunta: um `aoEncerrar` que chega agora
  /// ainda é meu? O slot é do transporte, que vive mais do que esta tela e
  /// pode ser trocado por baixo dela; sem identidade, um callback preso numa
  /// closure antiga continuaria abrindo diálogo depois de a mesa ter acabado —
  /// ou sobre a mesa de outra sessão.
  ///
  /// A geração sobe a cada vínculo criado E a cada vínculo solto, então
  /// desmontar já basta para tornar inerte tudo o que estava em voo.
  void Function(EncerramentoAutoritativo)? _consumidorDeEncerramento;
  int _geracaoDoConsumidor = 0;

  /// Com que identidade este vínculo reivindica avisos no livro dos efeitos.
  ///
  /// A geração acima não serve para isso, e a diferença é o ponto: ela é um
  /// número desta tela, e o livro vive no transporte, que sobrevive a ela. Uma
  /// tela nova começaria a contar do zero e teria a mesma geração de uma morta
  /// — passando a poder confirmar e liberar reivindicações que não são suas. A
  /// posse é um objeto, e dois objetos nunca são o mesmo por coincidência.
  PosseDoEfeito? _posse;

  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _apelido = TextEditingController(text: 'Você');

  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);
  static const _texto = Color(0xFFEFE3CC);
  static const _mut = Color(0xFF9A8C6C);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final srv = EscopoTransporte.talvezDe(context);
    if (identical(srv, _srv)) return;
    // O VÍNCULO ANTERIOR MORRE ANTES DE O NOVO NASCER. Trocar a ordem deixaria,
    // por um instante, dois consumidores válidos — e o antigo é justamente o que
    // aponta para uma mesa que já não é a desta tela.
    _soltarOEncerramento(_srv);
    _srv?.removeListener(_atualizar);
    _porta?.removeListener(_atualizar);
    _porta?.dispose();
    _porta = null;
    _srv = srv;
    _srv?.addListener(_atualizar);
    if (srv != null) {
      _ligarAoEncerramento(srv);
      // A porta também notifica: intenção pendente e recusa são estado dela, e
      // sem este ouvinte o botão travado nunca destravaria na tela.
      _porta = PortaDeComandosOnline(srv)..addListener(_atualizar);
    }

    // O PEDIDO DE CONEXÃO É DA PESSOA, e acontece uma vez: abrir esta tela é o
    // gesto de querer jogar online. A trava importa porque
    // `didChangeDependencies` roda de novo a cada notificação do escopo — sem
    // ela, cada mudança de status viraria um `conectar()` a mais.
    //
    // DEPOIS DO QUADRO, e não aqui dentro: `conectar()` muda o status na hora e
    // notifica, e o ouvinte desse aviso é o `EscopoTransporte`, que fica ACIMA
    // desta tela. Marcar um ancestral como sujo enquanto um descendente está
    // sendo construído é erro de framework — o Flutter constrói de cima para
    // baixo e já passou por ele.
    if (srv != null && !_pediuConexao) {
      _pediuConexao = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) srv.conectar();
      });
    }
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // O efeito terminal
  // -------------------------------------------------------------------------

  ApresentadorDeEncerramento get _apresentador =>
      widget.apresentador ?? const DialogoDeEncerramento();

  /// Ocupa o ponto de saída de [srv]. UM vínculo, sempre — o slot é um só, e
  /// esta tela nunca escreve nele sem antes soltar o que tinha.
  void _ligarAoEncerramento(OnlineService srv) {
    final geracao = ++_geracaoDoConsumidor;
    final posse = PosseDoEfeito();
    _posse = posse;
    // O PARÂMETRO É IGNORADO DE PROPÓSITO. O que se apresenta é o que está
    // pendente no livro, não o que veio pela cutucada — ver o cabeçalho. Manter
    // o parâmetro na assinatura é do contrato do slot, e um apresentador de
    // diagnóstico que o assine continua recebendo o aviso.
    void consumidor(EncerramentoAutoritativo _) => _drenar(srv, geracao, posse);
    _consumidorDeEncerramento = consumidor;
    srv.aoEncerrar = consumidor;

    // DRENA JÁ, sem esperar cutucada nenhuma. Este é o caminho de quem chegou
    // depois do fim: o servidor pode ter declarado o encerramento enquanto não
    // havia consumidor — a pessoa fora da rota da mesa, ou a janela entre este
    // vínculo e o anterior —, e o aviso está esperando no livro desde então.
    _drenar(srv, geracao, posse);
  }

  /// Devolve o ponto de saída, se ele ainda for nosso.
  ///
  /// A conferência de identidade não é zelo: o slot é público e o teste da
  /// suíte irmã escreve nele de propósito para medir o transporte. Zerar sem
  /// olhar apagaria a assinatura de quem chegou depois de nós.
  void _soltarOEncerramento(OnlineService? srv) {
    final meu = _consumidorDeEncerramento;
    if (srv != null && meu != null && identical(srv.aoEncerrar, meu)) {
      srv.aoEncerrar = null;
    }

    // A REIVINDICAÇÃO VOLTA AO LIVRO, e volta SEMPRE — inclusive quando o slot
    // já era de outro dono, porque a reivindicação continua sendo nossa. Um
    // aviso que esta tela assumiu e não chegou a apresentar ficaria travado em
    // `reivindicado` por um dono que não existe mais: ninguém o apresentaria e
    // ninguém o liberaria, que é o defeito original de volta pela porta nova.
    //
    // ANTES de a geração subir: quem lê isto na ordem inversa acha que a ordem
    // não importa, e importa — a partir daqui a posse deixa de ser alcançável.
    final posse = _posse;
    if (srv != null && posse != null) srv.efeitosTerminais.liberarTudoDe(posse);
    _posse = null;

    _consumidorDeEncerramento = null;
    // Sobe a geração: o que estiver em voo com o crachá antigo morre aqui.
    _geracaoDoConsumidor++;
  }

  /// Há efeito terminal esperando? Então este vínculo o assume e o apresenta.
  ///
  /// Chamado de dois lugares — a cutucada do transporte e a assinatura do
  /// vínculo —, e por isso não recebe encerramento nenhum: a fonte é o livro.
  ///
  /// A CUTUCADA CHEGA DENTRO do processamento da mensagem do servidor: a visão
  /// terminal já foi guardada, mas a tela ainda não redesenhou com ela, e
  /// ninguém foi notificado. Apresentar aqui poria o aviso sobre a mesa anterior
  /// — e, pior, abriria rota durante a entrega de uma mensagem de socket.
  ///
  /// Por isso o efeito espera o quadro — e PEDE o quadro, em vez de contar com
  /// o de outra pessoa. Hoje o `OnlineService` notifica os ouvintes logo depois
  /// desta chamada, e essa notificação sujaria a tela de qualquer jeito; mas
  /// `addPostFrameCallback` não agenda quadro nenhum, então um encerramento que
  /// chegasse sem redesenho junto ficaria pendurado para sempre — sem diálogo,
  /// sem erro e sem nada a investigar. O efeito não pode depender de um vizinho
  /// para acontecer.
  ///
  /// A REIVINDICAÇÃO ACONTECE AGORA, e não depois do quadro. No intervalo entre
  /// agendar e o quadro chegar cabe outra cutucada (o servidor reenvia), outra
  /// reconstrução e uma reentrada — e cada uma delas agendaria a sua própria
  /// apresentação do MESMO fim. Reivindicando antes, a segunda encontra o livro
  /// sem pendente e vai embora.
  void _drenar(OnlineService dono, int geracao, PosseDoEfeito posse) {
    if (!_aindaSouEuOuvindo(dono, geracao)) return;
    final encerramento = dono.efeitosTerminais.reivindicar(posse);
    if (encerramento == null) return;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _apresentar(dono, geracao, posse, encerramento),
    );
  }

  /// O quadro chegou: confere tudo de novo, apresenta, e SÓ ENTÃO confirma.
  ///
  /// Quem esperou pode ter sido desmontado, trocado de transporte ou saído da
  /// mesa. Em qualquer desses casos a reivindicação é devolvida — o efeito volta
  /// a pendente e espera a próxima entrada legítima. É a diferença entre um
  /// aviso adiado e um aviso perdido.
  ///
  /// A CONFIRMAÇÃO É A ÚLTIMA COISA, e depende do que o apresentador respondeu.
  /// Confirmar antes — no recebimento, na cutucada, no agendamento ou na
  /// reivindicação — marcaria como visto um aviso que ninguém viu, que é o
  /// defeito inteiro que esta tela existe para não ter.
  Future<void> _apresentar(
    OnlineService dono,
    int geracao,
    PosseDoEfeito posse,
    EncerramentoAutoritativo encerramento,
  ) async {
    final livro = dono.efeitosTerminais;
    if (!_aindaSouEuOuvindo(dono, geracao)) {
      livro.liberar(posse, encerramento);
      return;
    }

    final porta = _porta;
    final ResultadoDaApresentacao resultado;
    try {
      resultado = await _apresentador.apresentar(
        context,
        encerramento,
        aoSairDaMesa: () {
          // A saída também confere: o aviso pode ficar aberto enquanto a
          // sessão vira por baixo dele.
          if (_aindaSouEuOuvindo(dono, geracao)) porta?.sairDaMesa();
        },
      );
    } catch (erro, pilha) {
      // UM APRESENTADOR QUE ESTOURA É UMA APRESENTAÇÃO QUE NÃO ACONTECEU, e o
      // efeito não pode pagar por isso. Sem este `catch`, a exceção sobe por um
      // `addPostFrameCallback` — para um futuro que ninguém aguarda — e leva
      // junto a reivindicação: o aviso fica travado em `reivindicado` por um
      // dono vivo que já desistiu dele. Ninguém apresenta e ninguém libera, que
      // é a mesma perda silenciosa desta OS, só que por outra porta.
      //
      // As DUAS formas de estouro passam por aqui, e são caminhos diferentes de
      // verdade: um `throw` antes de o futuro existir acontece na própria
      // chamada, e um futuro que completa com erro acontece no `await`. O `try`
      // envolve a chamada inteira justamente para não escolher entre os dois.
      //
      // A DEVOLUÇÃO VEM PRIMEIRO, e só depois o relato. Se o relato falhar — e
      // `onError` é um gancho que a aplicação instala —, o efeito já está de
      // volta no livro.
      livro.liberar(posse, encerramento);
      // RELATAR, E NÃO REGISTRAR EM LOG: por esta camada passam ids de carta, e
      // a auditoria proíbe log aqui com razão. `reportError` é o canal do
      // próprio framework, vai para onde a aplicação mandar os erros, e não
      // escreve nada por conta própria. Engolir em silêncio seria esconder um
      // defeito do apresentador — exatamente a classe de falha muda que esta
      // entrega existe para acabar.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: erro,
          stack: pilha,
          library: 'casca da mesa online',
          context: ErrorDescription('ao apresentar o encerramento da partida'),
        ),
      );
      return;
    }

    if (resultado != ResultadoDaApresentacao.apresentado) {
      livro.liberar(posse, encerramento);
      return;
    }
    // `confirmar` recusa quando a posse já não é a que reivindicou — um
    // `dispose` no meio do caminho devolveu o efeito ao livro, e insistir aqui
    // encerraria um aviso de que outro dono agora é responsável.
    if (!livro.confirmar(posse, encerramento)) return;

    // Duas emissões terminais distintas na mesma mesa são raras e possíveis. A
    // segunda não pode ficar esperando por uma cutucada que não vem: o livro já
    // a conhece, e reenvio de fim conhecido não cutuca ninguém.
    if (livro.temPendente) _drenar(dono, geracao, posse);
  }

  /// O vínculo que trouxe este aviso ainda é o vínculo vivo desta tela?
  ///
  /// Três perguntas, e as três são necessárias: a tela pode ter sido desmontada
  /// (`mounted`), o vínculo pode ter sido solto e refeito (`geracao`), e o
  /// transporte pode ter sido trocado por outro (`dono`).
  bool _aindaSouEuOuvindo(OnlineService dono, int geracao) =>
      mounted && geracao == _geracaoDoConsumidor && identical(dono, _srv);

  @override
  void dispose() {
    // O ponto de saída volta a ficar livre. Sem isto, o transporte — que é da
    // raiz e continua vivo — guardaria uma closure desta tela morta, e o efeito
    // terminal da partida seguinte tentaria abrir diálogo por um `context` que
    // não está mais na árvore.
    _soltarOEncerramento(_srv);
    // Só solta o ouvinte. O transporte continua vivo — ele é da raiz.
    _srv?.removeListener(_atualizar);
    // A porta, ao contrário, é DESTA tela: ela foi construída aqui e morre
    // aqui. Descartá-la também solta o ouvinte que ela mantém no transporte.
    _porta?.removeListener(_atualizar);
    _porta?.dispose();
    _codigo.dispose();
    _apelido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final srv = _srv;
    if (srv == null) {
      // Fora da casca de produção (pré-visualização isolada). Não há transporte
      // e não se constrói um aqui — seria um segundo socket sem ponte.
      return const _MolduraDoLobby(
        corpo: [
          Text(
            'O jogo online não está disponível nesta visualização.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mut, fontSize: 13),
          ),
        ],
      );
    }

    // A LEITURA DA VISÃO ACONTECE UMA VEZ, AQUI. Nenhum dos ramos abaixo lê o
    // mapa cru por conta própria — o que chega neles é ou um estado validado,
    // ou uma recusa com motivo.
    final leitura = AdaptadorVisaoOnline.ler(
      srv.visao,
      assentoDaConexao: srv.meuAssento,
    );

    // PARTIDA EM ANDAMENTO: esta rota deixa de ser o lobby e passa a ser a
    // mesa. Sem `push` — ver o cabeçalho do arquivo.
    if (leitura is VisaoDeJogo) {
      final porta = _porta;
      if (porta != null) {
        return MesaOnlineScreen(
          estado: leitura.estado,
          porta: porta,
          conectado: srv.status == OnlineStatus.conectado,
          avisoDeConexao: _avisoDeConexao(srv),
          onSair: () {
            porta.sairDaMesa();
            // Sair da MESA não é sair da tela do online: a pessoa volta para a
            // entrada, onde pode criar outra mesa ou entrar num código. Quem
            // decide sair da tela é o gesto de voltar.
          },
        );
      }
    }

    final v = srv.visao;
    final List<Widget> corpo;
    if (v == null) {
      corpo = _entrada(srv);
    } else if (leitura is VisaoDeLobby) {
      corpo = _lobby(srv, v);
    } else if (leitura is VisaoRecusada) {
      // O servidor mandou algo que não descreve uma mesa. Dizer isso, e dar uma
      // saída, é o oposto de desenhar uma mesa com os buracos preenchidos por
      // zero.
      corpo = _visaoIlegivel(srv, leitura);
    } else {
      // `VisaoDeJogo` sem porta montada: só acontece fora da casca de produção.
      corpo = _semTransporteParaJogar();
    }

    return _MolduraDoLobby(
      corpo: [
        _statusChip(srv),
        if (srv.erro != null) ...[
          const SizedBox(height: 12),
          _erroBox(srv.erro!),
        ],
        if (srv.falhaTerminal) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: srv.tentarNovamente,
              child: const Text(
                'Tentar de novo',
                style: TextStyle(
                  color: _ouroClaro,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        ...corpo,
      ],
    );
  }

  Widget _statusChip(OnlineService srv) {
    final (cor, txt) = switch (srv.status) {
      OnlineStatus.conectado => (
        const Color(0xFF27AE60),
        'conectado ao servidor',
      ),
      OnlineStatus.conectando => (_ouro, 'conectando…'),
      // a conexão está aberta, mas o servidor ainda não aceitou a credencial —
      // nenhum comando de jogador roda nesse intervalo
      OnlineStatus.autenticando => (_ouro, 'identificando você…'),
      OnlineStatus.erro => (const Color(0xFFE05B5B), 'sem conexão'),
      OnlineStatus.naoAutenticado => (
        const Color(0xFFE05B5B),
        'entre na sua conta para jogar online',
      ),
      OnlineStatus.atualizacaoObrigatoria => (
        const Color(0xFFE05B5B),
        'atualize o aplicativo para jogar online',
      ),
      OnlineStatus.servidorDesatualizado => (
        const Color(0xFFE05B5B),
        'servidor em atualização — tente mais tarde',
      ),
      // este build saiu sem endereço de servidor utilizável — nenhuma tentativa
      // de rede conserta isso, então a mensagem aponta para o build, não para a
      // rede
      OnlineStatus.configuracaoInvalida => (
        const Color(0xFFE05B5B),
        'este aplicativo está mal configurado',
      ),
      // o ciclo automático desistiu: melhor dizer isso do que girar para sempre
      OnlineStatus.semConexao => (
        const Color(0xFFE05B5B),
        'sem conexão — toque para tentar de novo',
      ),
      OnlineStatus.desconectado => (_mut, 'desconectado'),
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        // FLEXÍVEL, e não solto: a frase mais longa desta lista tem 41
        // caracteres, e sobram 302 pontos para ela (430 de largura máxima, ou a
        // do aparelho se for menor, menos os 20 de padding de cada lado, menos
        // os 18 do ponto colorido). Em negrito de 13 isso cabe raspando — e
        // deixa de caber assim que o aparelho é mais estreito ou a pessoa usa o
        // ajuste de fonte grande do sistema, que é justamente quem mais precisa
        // ler o recado. Sem restrição, o texto estoura a linha e some cortado;
        // com ela, quebra em duas.
        Flexible(
          child: Text(
            txt,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _erroBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x33E05B5B),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x55E05B5B)),
    ),
    child: Text(
      msg,
      style: const TextStyle(color: Color(0xFFF6C9C9), fontSize: 12.5),
    ),
  );

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _mut),
    filled: true,
    fillColor: const Color(0xFF1C130C),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0x33EFB94A)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _ouro),
    ),
  );

  String get _apelidoEscolhido =>
      _apelido.text.trim().isEmpty ? 'Você' : _apelido.text.trim();

  // Ainda não entrou numa mesa: criar ou entrar por código.
  List<Widget> _entrada(OnlineService srv) {
    final pronto = srv.conectado;
    return [
      TextField(
        controller: _apelido,
        style: const TextStyle(color: _texto),
        decoration: _dec('Seu apelido'),
      ),
      const SizedBox(height: 16),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _ouro,
          foregroundColor: const Color(0xFF1C130C),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: pronto
            ? () => srv.criarMesa(apelido: _apelidoEscolhido)
            : null,
        child: const Text(
          'Criar mesa',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(child: Divider(color: Color(0x33EFB94A))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('ou', style: TextStyle(color: _mut)),
            ),
            Expanded(child: Divider(color: Color(0x33EFB94A))),
          ],
        ),
      ),
      TextField(
        controller: _codigo,
        style: const TextStyle(color: _texto, letterSpacing: 1.5),
        textCapitalization: TextCapitalization.characters,
        onChanged: (_) => setState(() {}),
        decoration: _dec('Código da mesa (ex.: BURACO-0001)'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ouroClaro,
          side: const BorderSide(color: _ouro),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: pronto && _codigo.text.trim().isNotEmpty
            ? () => srv.entrarMesa(
                codigo: _codigo.text.trim().toUpperCase(),
                apelido: _apelidoEscolhido,
              )
            : null,
        child: const Text(
          'Entrar por código',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ];
  }

  // Na sala, aguardando os jogadores.
  List<Widget> _lobby(OnlineService srv, Map<String, dynamic> v) {
    final assentos = (v['assentos'] as List?) ?? const [];
    final ehCriador = v['criador'] == true;
    return [
      const Text(
        'Código da mesa',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mut, fontSize: 12),
      ),
      const SizedBox(height: 4),
      SelectableText(
        '${v['codigo'] ?? '—'}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ouroClaro,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Compartilhe o código com quem vai jogar 🃏',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mut, fontSize: 12),
      ),
      const SizedBox(height: 18),
      ...List.generate(assentos.length, (i) {
        final a = assentos[i] as Map?;
        final vazio = a == null || a['vazio'] == true;
        final nome = vazio
            ? 'aguardando…'
            : (a['apelido'] ?? 'jogador').toString();
        final ehVoce = !vazio && a['ehVoce'] == true;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C130C),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ehVoce ? _ouro : const Color(0x22EFB94A)),
          ),
          child: Row(
            children: [
              Text(
                'Cadeira ${i + 1}',
                style: const TextStyle(color: _mut, fontSize: 12),
              ),
              const Spacer(),
              Text(
                nome + (ehVoce ? ' (você)' : ''),
                style: TextStyle(
                  color: vazio ? _mut : _texto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }),
      const SizedBox(height: 12),
      if (ehCriador)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ouro,
            foregroundColor: const Color(0xFF1C130C),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: srv.iniciarPartida,
          child: const Text(
            'Iniciar partida',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        )
      else
        const Text(
          'O criador da mesa inicia a partida.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _mut, fontSize: 12),
        ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: srv.sair,
        child: const Text('Sair da mesa', style: TextStyle(color: _mut)),
      ),
    ];
  }

  /// O que dizer sobre a conexão enquanto a mesa está aberta.
  ///
  /// Nulo quando não há nada a dizer — e é assim que a faixa some. Uma faixa
  /// permanente dizendo "conectado" é ruído sobre a mesa.
  String? _avisoDeConexao(OnlineService srv) => switch (srv.status) {
    OnlineStatus.conectado => null,
    OnlineStatus.conectando =>
      'reconectando… as ações voltam quando a mesa voltar',
    OnlineStatus.autenticando => 'identificando você…',
    OnlineStatus.naoAutenticado =>
      'sua sessão terminou — entre de novo para jogar',
    OnlineStatus.semConexao =>
      'sem conexão — a mesa está congelada como você a deixou',
    _ => 'sem conexão com o servidor',
  };

  /// A visão chegou e não descreve uma mesa.
  ///
  /// Nenhuma tentativa de desenhar o que deu para entender: uma mesa meio lida
  /// é indistinguível, para quem olha, de uma mesa em que se está perdendo.
  List<Widget> _visaoIlegivel(OnlineService srv, VisaoRecusada recusa) => [
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x33E05B5B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x55E05B5B)),
      ),
      child: Column(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 10),
          const Text(
            'Não consegui entender a mesa',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ouroClaro,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recusa.motivo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF6C9C9),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 14),
    OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _ouroClaro,
        side: const BorderSide(color: _ouro),
        padding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onPressed: srv.sair,
      child: const Text(
        'Sair da mesa',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  ];

  /// Visão de partida sem porta de comandos montada. Só alcançável fora da
  /// casca de produção — a mesma situação em que não há transporte.
  List<Widget> _semTransporteParaJogar() => const [
    Text(
      'O jogo online não está disponível nesta visualização.',
      textAlign: TextAlign.center,
      style: TextStyle(color: _mut, fontSize: 13),
    ),
  ];
}

class _MolduraDoLobby extends StatelessWidget {
  const _MolduraDoLobby({required this.corpo});

  final List<Widget> corpo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A06),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C130C),
        foregroundColor: const Color(0xFFF6E2A6),
        title: const Text('Jogar Online'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: corpo,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
