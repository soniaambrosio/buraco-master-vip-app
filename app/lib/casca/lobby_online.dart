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

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../services/online_service.dart';
import 'anuncio_de_transicao.dart';
import 'escopo_transporte.dart';
import 'mesa_online/estado_mesa_online.dart';
import 'mesa_online/mesa_online_screen.dart';
import 'mesa_online/porta_de_comandos_online.dart';

class LobbyOnline extends StatefulWidget {
  const LobbyOnline({super.key});

  @override
  State<LobbyOnline> createState() => _LobbyOnlineState();
}

class _LobbyOnlineState extends State<LobbyOnline> {
  OnlineService? _srv;
  bool _pediuConexao = false;

  /// O status do transporte, como ele estava no último aviso.
  ///
  /// A GERAÇÃO é a chave, e é ela que separa duas coisas que o status sozinho
  /// confunde. A queda de rede acontece DENTRO da geração corrente
  /// (`conectado` → `conectando`), e é notícia. Logout, troca de conta e cada
  /// tentativa nova do ciclo de reconexão SOBEM a geração — e aí o estado
  /// anterior é de uma sessão que já não existe. Comparar através dessa
  /// fronteira faria o app dizer "conexão perdida" para quem acabou de sair da
  /// conta de propósito, e repetir "reconectando" a cada disparo do
  /// temporizador de tentativas.
  final SentinelaDeTransicao<OnlineStatus> _sentinelaDoStatus =
      SentinelaDeTransicao<OnlineStatus>();

  /// A falha terminal é observada FORA da geração — justamente porque é ela
  /// que sobe a geração ao acontecer, e sem isto a desistência do ciclo
  /// automático seria a única notícia que ninguém receberia.
  final SentinelaDeTransicao<bool> _sentinelaDaFalha =
      SentinelaDeTransicao<bool>();

  /// Esta tela já viu o transporte de pé alguma vez.
  ///
  /// Sem isto a PRIMEIRA conexão da sessão seria anunciada como uma volta, e
  /// ninguém tinha ido a lugar nenhum.
  bool _jaConectou = false;

  /// A queda já foi dita. Impede que "restaurada" saia sem uma perda antes, e
  /// que a perda saia duas vezes no mesmo ciclo de tentativas.
  bool _disseQueCaiu = false;

  /// A recusa que está no transporte, como esta tela a viu da última vez.
  ///
  /// ANCORADA NA CHEGADA, e é isso que ela existe para fazer. `erro` é a
  /// resposta à última pergunta feita ao servidor, e ela sobrevive à saída
  /// desta rota: quem digita um código inexistente, volta para a Home e entra
  /// de novo no lobby encontra o recado ainda ali. Ver a caixa é razoável — o
  /// texto explica por que a mesa não abriu. Ser INTERROMPIDO por ela não é:
  /// ninguém acabou de perguntar nada.
  final SentinelaDeTransicao<String?> _sentinelaDaRecusa =
      SentinelaDeTransicao<String?>();

  /// A recusa na tela chegou DEPOIS desta tela? Só ela é região viva.
  ///
  /// Região viva é a marca de "isto acabou de mudar". Uma recusa que já estava
  /// no transporte quando esta rota nasceu não mudou nada — ela é histórico, e
  /// histórico se lê quando se quer, não se ouve quando chega.
  bool _recusaEhNoticia = false;

  /// A porta por onde as ações da mesa saem.
  ///
  /// Nasce e morre com o transporte que esta tela está usando — ela é um
  /// ouvinte dele, e uma porta apontando para um `OnlineService` trocado seria
  /// um ouvinte pendurado num objeto que já não é o da árvore.
  PortaDeComandosOnline? _porta;

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
    _srv?.removeListener(_atualizar);
    _porta?.removeListener(_atualizar);
    _porta?.dispose();
    _porta = null;
    _srv = srv;
    _srv?.addListener(_atualizar);
    if (srv != null) {
      // A porta também notifica: intenção pendente e recusa são estado dela, e
      // sem este ouvinte o botão travado nunca destravaria na tela.
      _porta = PortaDeComandosOnline(srv)..addListener(_atualizar);
    }

    // A ÂNCORA. O que já estava no transporte quando esta tela chegou é o
    // ponto de partida, não uma transição — a mesma regra que vale para o
    // status da conexão, aplicada à recusa.
    _sentinelaDaRecusa.ancorar(srv?.erro);
    _recusaEhNoticia = false;

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
    if (!mounted) return;
    final srv = _srv;
    if (srv != null) {
      _falarDaConexao(srv);
      // A recusa mudou de valor: ou chegou uma, e é notícia, ou a pergunta
      // nova apagou a anterior, e a próxima começa do zero.
      if (_sentinelaDaRecusa.mudou(srv.erro)) {
        _recusaEhNoticia = srv.erro != null;
      }
    }
    setState(() {});
  }

  /// O que dizer em voz alta sobre a conexão, e quando.
  ///
  /// ---------------------------------------------------------------------
  /// POR QUE AQUI, E NÃO NA MESA
  /// ---------------------------------------------------------------------
  ///
  /// Esta tela é a única dona do `OnlineService` nas duas superfícies: quando
  /// há partida, o corpo desta rota É a mesa. Um segundo observador dentro da
  /// mesa faria a queda ser anunciada duas vezes com a mesa aberta e nenhuma
  /// com ela fechada — e a mesa passaria a ter opinião sobre transporte, que é
  /// justamente o que a arquitetura desta pasta não tem.
  ///
  /// ---------------------------------------------------------------------
  /// POR QUE NÃO É REGIÃO VIVA
  /// ---------------------------------------------------------------------
  ///
  /// Porque metade da notícia é um DESAPARECIMENTO. A faixa de aviso e o texto
  /// do chip somem quando a conexão volta, e um nó que some não fala. Marcá-los
  /// como região viva resolveria a ida e perderia a volta — que é a metade que
  /// importa, porque é ela que devolve as ações à pessoa.
  void _falarDaConexao(OnlineService srv) {
    // 1) FALHA DEFINITIVA. O ciclo automático desistiu, ou a credencial foi
    //    recusada. Não adianta esperar, e o chip que a explica é o único aviso
    //    hoje. Vem antes de tudo porque também sobe a geração.
    if (_sentinelaDaFalha.mudou(srv.falhaTerminal) && srv.falhaTerminal) {
      _disseQueCaiu = false;
      final frase = _fraseDaFalha(srv.status);
      if (frase != null) {
        anunciar(context, frase, urgencia: Assertiveness.assertive);
      }
      return;
    }

    if (!_sentinelaDoStatus.mudou(srv.status, geracao: srv.geracao)) return;

    switch (srv.status) {
      case OnlineStatus.conectado:
        _jaConectou = true;
        if (!_disseQueCaiu) return; // a primeira conexão não é uma volta
        _disseQueCaiu = false;
        anunciar(context, 'conexão restaurada');
      case OnlineStatus.conectando:
      case OnlineStatus.erro:
        if (!_jaConectou || _disseQueCaiu) return;
        _disseQueCaiu = true;
        anunciar(
          context,
          'conexão perdida — reconectando',
          urgencia: Assertiveness.assertive,
        );
      // `autenticando` é etapa interna do aperto de mão, e `desconectado` é
      // saída deliberada. Nenhum dos dois é notícia para quem está jogando.
      case OnlineStatus.autenticando:
      case OnlineStatus.desconectado:
      case OnlineStatus.naoAutenticado:
      case OnlineStatus.atualizacaoObrigatoria:
      case OnlineStatus.servidorDesatualizado:
      case OnlineStatus.configuracaoInvalida:
      case OnlineStatus.semConexao:
        return;
    }
  }

  /// A frase de uma falha terminal, ou nulo quando o estado não é terminal.
  ///
  /// O texto é o mesmo do chip que fica na tela — e é de propósito: quem ouve e
  /// quem lê têm de estar falando da mesma coisa.
  String? _fraseDaFalha(OnlineStatus status) => switch (status) {
    OnlineStatus.semConexao => 'sem conexão — toque para tentar de novo',
    OnlineStatus.naoAutenticado => 'entre na sua conta para jogar online',
    OnlineStatus.atualizacaoObrigatoria =>
      'atualize o aplicativo para jogar online',
    OnlineStatus.servidorDesatualizado =>
      'servidor em atualização — tente mais tarde',
    OnlineStatus.configuracaoInvalida => 'este aplicativo está mal configurado',
    _ => null,
  };

  @override
  void dispose() {
    // QUEM CALA A TELA É A GUARDA DE `mounted`, no alto de `_atualizar`. Uma
    // versão anterior deste comentário dava o crédito a esta linha; a OS 37
    // mediu o contrário — sem o `removeListener`, sair da tela e deixar o
    // servidor mandar mesa nova e derrubar a conexão continua produzindo ZERO
    // anúncio, porque o ouvinte devolve antes de falar.
    //
    // Isto aqui é HIGIENE, e é obrigatório pelo motivo de sempre: o transporte
    // é da raiz e vive muito mais que esta rota, então um ouvinte que não sai
    // fica pendurado nele até o fim da sessão, uma cópia por visita ao lobby.
    // Não desliga o transporte — sair da tela do lobby não é sair do jogo
    // online.
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
          _erroBox(srv.erro!, viva: _recusaEhNoticia),
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

  /// A recusa do servidor a um comando do lobby — código que não existe, mesa
  /// cheia, entrada negada.
  ///
  /// REGIÃO VIVA, e não anúncio: aqui a notícia É um texto que fica. Ele
  /// aparece, o leitor de tela o lê no instante em que entra, e continua no
  /// mesmo lugar para quem quiser voltar a ele.
  ///
  /// A marca e o rótulo precisam mesmo cair no MESMO nó — região viva sem
  /// rótulo não tem o que anunciar. O que não é verdade é que o
  /// `MergeSemantics` seja quem garante isso: `Semantics` sobre um `Text`
  /// único já funde, e a OS 37 mediu o nó com e sem ele, idêntico nos dois
  /// casos. Ele fica como reserva para o dia em que esta caixa tiver dois
  /// filhos faláveis.
  ///
  /// E A REGIÃO VIVA SÓ FALA QUANDO O CONTEÚDO MUDA. Duas recusas idênticas
  /// seguidas seriam uma notícia e um silêncio se o texto anterior continuasse
  /// pendurado; quem resolve isso não é esta caixa, é
  /// `OnlineService._perguntaNova`, que apaga a resposta velha no instante em
  /// que a pessoa faz a pergunta nova.
  /// [viva] é falso para a recusa que esta tela ENCONTROU pronta ao nascer.
  /// O texto é o mesmo e continua legível; o que não acontece é a
  /// interrupção.
  Widget _erroBox(String msg, {required bool viva}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0x33E05B5B),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x55E05B5B)),
    ),
    child: MergeSemantics(
      child: Semantics(
        liveRegion: viva,
        child: Text(
          msg,
          style: const TextStyle(color: Color(0xFFF6C9C9), fontSize: 12.5),
        ),
      ),
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
    OnlineStatus.conectando => 'reconectando… as ações voltam quando a mesa voltar',
    OnlineStatus.autenticando => 'identificando você…',
    OnlineStatus.naoAutenticado => 'sua sessão terminou — entre de novo para jogar',
    OnlineStatus.semConexao => 'sem conexão — a mesa está congelada como você a deixou',
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
