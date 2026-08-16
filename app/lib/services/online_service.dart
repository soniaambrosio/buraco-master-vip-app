// online_service.dart — FATIA A1 do online nativo (Trilha A).
// Camada de conexão do app Flutter com o SERVIDOR que já está no ar (Railway).
// Fala o mesmo protocolo do servidor web (servidor/servidor.js):
//   cliente → servidor:  auth / criarMesa / entrarMesa / iniciarPartida / jogada / sair
//   servidor → cliente:  autenticado · authFalhou · entrou{codigo,assento} ·
//                        estado{visao} · erro{motivo}
// A "visao" é a verdade do servidor por assento (lobby OU jogo). A UI só lê isso.
//
// Esta fatia entrega SÓ a conexão + protocolo + estado reativo (ChangeNotifier).
// A fatia A2 liga essa `visao` na tela da mesa. Não mexe no jogo local.
//
// Requer o pacote `web_socket_channel` (o build declara: flutter pub add web_socket_channel).
//
// ---------------------------------------------------------------------------
// IDENTIDADE — leia antes de mexer aqui.
//
// O app NÃO diz ao servidor quem ele é. Ele APRESENTA uma credencial (o ID
// Token do Firebase Auth) e o servidor decide a identidade a partir dela. Não
// existe mais campo `jogadorId` saindo daqui: mandar um seria, no melhor caso,
// redundante e, no pior, recusado pelo servidor como identidade divergente.
//
//   conectar → obter ID Token → abrir socket → {tipo:"auth"} →
//   esperar "autenticado" → SÓ ENTÃO soltar a fila de comandos
//
// Sem usuário do Firebase, nem tenta conectar. Com credencial recusada, para de
// reconectar — insistir com token ruim só gera loop. E o token nunca aparece em
// log, mensagem de erro ou `toString()`.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum OnlineStatus {
  desconectado,
  conectando,
  /// Socket aberto, credencial ainda não aceita (primeira autenticação OU
  /// renovação depois do token vencer). Nenhum comando roda aqui.
  autenticando,
  conectado,
  erro,
  /// Não há usuário logado no Firebase, ou o servidor recusou a credencial.
  /// Falha terminal: não adianta reconectar sozinho.
  naoAutenticado,
  /// O servidor exige uma versão de protocolo mais nova que a deste app.
  /// Falha terminal: só sai daqui atualizando o aplicativo.
  atualizacaoObrigatoria,
  /// O servidor ainda não foi atualizado e não fala o protocolo autenticado.
  /// Falha terminal — de propósito: jogar assim exigiria voltar a declarar
  /// identidade pelo cliente, que é exatamente o buraco que foi fechado.
  servidorDesatualizado,
}

/// Fonte da credencial da conexão. Assinatura própria (e não o `User` do
/// Firebase) para o teste conseguir exercitar o nosso código sem subir o SDK.
typedef ObterIdToken = Future<String?> Function();

/// Fábrica do canal. Existe pelo mesmo motivo: o teste troca por um canal falso.
typedef AbrirCanal = WebSocketChannel Function(Uri url);

/// Quem está logado NESTE aparelho, ao longo do tempo. Emite o uid, ou `null`
/// quando não há ninguém.
///
/// É uma FUNÇÃO que devolve o stream, e não o stream pronto, de propósito: o
/// padrão toca em `FirebaseAuth.instance`, e construir um `OnlineService` não
/// pode exigir Firebase inicializado. A assinatura só acontece no `conectar()`.
typedef ObterIdentidade = Stream<String?> Function();

class OnlineService extends ChangeNotifier {
  // Servidor de produção já no ar (ver NO-AR.md). Trocável se mudar de host.
  static const String servidorUrl =
      'wss://buraco-servidor-production.up.railway.app';

  /// Versão do protocolo de conexão que este app fala.
  ///   1 = antigo, sem autenticação (identidade declarada pelo cliente)
  ///   2 = este: apresenta credencial, o servidor deriva a identidade
  /// Vai junto com a credencial para o servidor conseguir recusar cliente
  /// incompatível com uma resposta que a pessoa entenda.
  static const int protocolo = 2;

  /// Quanto se espera o servidor responder à autenticação antes de desistir
  /// desta tentativa. Sem isso, um servidor que ignora o `auth` deixaria o app
  /// pendurado em "identificando você…" para sempre.
  static const Duration limiteDeAutenticacao = Duration(seconds: 15);

  OnlineService({
    ObterIdToken? obterIdToken,
    AbrirCanal? abrirCanal,
    ObterIdentidade? obterIdentidade,
  })  : _obterIdToken = obterIdToken ?? _idTokenDoFirebase,
        _abrirCanal = abrirCanal ?? WebSocketChannel.connect,
        _obterIdentidade = obterIdentidade ?? _identidadeDoFirebase;

  final ObterIdToken _obterIdToken;
  final AbrirCanal _abrirCanal;
  final ObterIdentidade _obterIdentidade;

  /// Credencial padrão: o ID Token do usuário logado no Firebase.
  ///
  /// `getIdToken()` devolve o token em cache e só vai à rede quando ele já
  /// expirou ou está perto disso — então chamar a cada tentativa de conexão é
  /// barato e garante credencial fresca na reconexão.
  static Future<String?> _idTokenDoFirebase() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return u.getIdToken();
  }

  /// Identidade padrão: quem o Firebase Auth diz que está logado, ao longo do
  /// tempo. `authStateChanges` emite o estado atual assim que se assina, e
  /// depois a cada login, logout ou troca de conta.
  static Stream<String?> _identidadeDoFirebase() =>
      FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _sub;

  /// Vigilância da conta local. Sem ela, um socket já autenticado como A
  /// continuaria de pé — e continuaria valendo no servidor até o token vencer —
  /// depois de a pessoa sair da conta ou entrar com outra.
  StreamSubscription<String?>? _identidadeSub;

  /// Último uid observado neste processo. Não vem do servidor nem sai daqui:
  /// serve só para reconhecer a TRANSIÇÃO de conta.
  String? _uidLocal;
  bool _uidLocalConhecido = false;

  OnlineStatus status = OnlineStatus.desconectado;
  String? erro; // última mensagem de erro (conexão ou do servidor)

  // Estado da sessão online (vem do servidor)
  int? meuAssento; // assento do jogador nesta mesa
  String? codigo; // código da mesa
  Map<String, dynamic>? visao; // lobby OU visão de jogo do assento

  // Mensagens a enviar assim que a conexão estiver AUTENTICADA (ex.: criarMesa
  // disparado antes de conectar). Nada aqui sai antes do "autenticado" — o
  // servidor recusaria com NAO_AUTENTICADO de qualquer forma.
  final List<Map<String, dynamic>> _pendentes = [];

  // Reconexão automática (backoff simples)
  bool _querConectado = false;
  int _tentativas = 0;
  Timer? _reconectarTimer;

  // Trava de abertura em curso.
  //
  // Antes esta guarda era `status == conectando`, e isso deixava a reconexão
  // MORTA: `_aoCair()` põe o status em `conectando` e só então agenda o
  // backoff, então o timer chamava `_abrir()` e ele voltava na primeira linha,
  // sempre. Era defeito pré-existente, e ele precisa estar de pé aqui: se a
  // reconexão não roda, ela também não reautentica.
  bool _abrindo = false;

  // Esta conexão já teve UMA autenticação aceita? Distingue a primeira
  // autenticação (que precisa reentrar na mesa) da renovação de credencial
  // (que não precisa: o assento continua lá, a conexão nunca caiu).
  bool _jaAutenticouNestaConexao = false;

  Timer? _limiteAuthTimer;

  bool get conectado => status == OnlineStatus.conectado;
  bool get autenticado => status == OnlineStatus.conectado;
  bool get noLobby => visao != null && visao!['lobby'] == true;
  bool get emJogo => visao != null && visao!['lobby'] != true;

  /// Abre a conexão com o servidor. Idempotente.
  void conectar() {
    _querConectado = true;
    _vigiarIdentidade();
    _abrir();
  }

  /// Assina a conta local na PRIMEIRA conexão, e não no construtor: o padrão
  /// toca em `FirebaseAuth.instance`, que nem sempre está inicializado quando um
  /// `OnlineService` é criado (uma tela pode ser construída antes do Firebase).
  ///
  /// Falha aqui é silenciosa e não impede jogar: sem Firebase disponível não há
  /// troca de conta a vigiar, porque também não haveria credencial para
  /// apresentar — `_abrir()` cai em `naoAutenticado` logo em seguida.
  void _vigiarIdentidade() {
    if (_identidadeSub != null) return;
    try {
      _identidadeSub = _obterIdentidade().listen(_aoMudarIdentidade);
    } catch (_) {
      _identidadeSub = null;
    }
  }

  /// A conta LOCAL mudou. Duas transições importam, e as duas invalidam a
  /// conexão atual — o servidor derivou a identidade do token apresentado no
  /// `auth`, então o socket continua sendo de quem o abriu.
  ///
  ///   uid -> null ..... a pessoa saiu da conta. Falha TERMINAL: reconectar
  ///                     sozinho não tem o que apresentar, e ficar tentando
  ///                     mostraria "conexão instável" para sempre.
  ///   uid -> outro .... entrou outra conta no mesmo processo. Derruba o socket
  ///                     do anterior e reabre do zero, com credencial nova.
  ///
  /// A PRIMEIRA emissão nunca derruba nada: `authStateChanges` entrega o estado
  /// atual assim que se assina, e isso não é transição.
  void _aoMudarIdentidade(String? uid) {
    final anterior = _uidLocal;
    final haviaLeitura = _uidLocalConhecido;
    _uidLocal = uid;
    _uidLocalConhecido = true;

    if (!haviaLeitura) return; // primeira leitura: só registra
    if (uid == anterior) return; // nada mudou

    // A mesa era do dono anterior. Esquecer é o que impede `_aoAutenticar()` de
    // mandar `entrarMesa` com o código dele em nome de quem acabou de entrar.
    _esquecerMesa();

    if (uid == null) {
      _falhaTerminal(OnlineStatus.naoAutenticado, 'você saiu da conta');
      return;
    }

    _derrubarSocket();
    _pendentes.clear();
    _tentativas = 0;
    _jaAutenticouNestaConexao = false;
    // O erro anterior era da conta anterior. Quem entrou agora ainda não
    // fracassou em nada.
    erro = null;
    if (_querConectado) {
      status = OnlineStatus.conectando;
      notifyListeners();
      _abrir();
    } else {
      status = OnlineStatus.desconectado;
      notifyListeners();
    }
  }

  /// Descarta o que pertencia à sessão anterior nesta mesa.
  void _esquecerMesa() {
    codigo = null;
    meuAssento = null;
    visao = null;
  }

  /// Fecha socket, assinatura e temporizadores, sem decidir status nem
  /// reconexão — quem chama decide.
  void _derrubarSocket() {
    _reconectarTimer?.cancel();
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _sub?.cancel();
    _sub = null;
    _canal?.sink.close();
    _canal = null;
  }

  Future<void> _abrir() async {
    if (_abrindo ||
        status == OnlineStatus.autenticando ||
        status == OnlineStatus.conectado) {
      return;
    }
    _abrindo = true;
    try {
      status = OnlineStatus.conectando;
      erro = null;
      notifyListeners();

      // 1) CREDENCIAL PRIMEIRO. Sem ela não faz sentido abrir socket: o
      //    servidor não aceita comando de conexão não autenticada. É aqui que
      //    a reconexão pega token FRESCO — nunca reaproveita identidade
      //    anterior.
      String? token;
      try {
        token = await _obterIdToken();
      } catch (_) {
        token = null; // qualquer erro do SDK vale como "não tem credencial"
      }
      if (token == null || token.isEmpty) {
        _falhaDeCredencial('entre na sua conta para jogar online');
        return;
      }

      // 2) SOCKET.
      try {
        _canal = _abrirCanal(Uri.parse(servidorUrl));
        await _canal!.ready; // espera a conexão ficar pronta (lança se falhar)
      } catch (e) {
        _canal = null;
        status = OnlineStatus.erro;
        erro = 'não foi possível conectar ao servidor';
        notifyListeners();
        _agendarReconexao();
        return;
      }

      // 3) CREDENCIAL NA PRIMEIRA MENSAGEM. Até o servidor responder
      //    "autenticado", nada mais é enviado.
      _jaAutenticouNestaConexao = false;

      _sub = _canal!.stream.listen(
        _aoReceber,
        onDone: _aoCair,
        onError: (Object e) {
          erro = 'conexão instável';
          _aoCair();
        },
        cancelOnError: true,
      );

      _mandarCredencial(token);
    } finally {
      _abrindo = false;
    }
  }

  /// Escreve a credencial no socket e arma o limite de espera. Serve tanto para
  /// a primeira autenticação quanto para a renovação depois do token vencer.
  void _mandarCredencial(String token) {
    status = OnlineStatus.autenticando;
    notifyListeners();

    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = Timer(limiteDeAutenticacao, _aoEstourarLimiteDeAuth);

    _bruto({'tipo': 'auth', 'token': token, 'protocolo': protocolo});
  }

  /// O servidor não respondeu à autenticação. Pode ser rede ruim ou servidor
  /// que ignora o `auth` — em qualquer caso não dá para jogar nesta conexão.
  /// Fecha e deixa o backoff tentar de novo; não é falha terminal.
  void _aoEstourarLimiteDeAuth() {
    if (status != OnlineStatus.autenticando) return;
    _sub?.cancel();
    _sub = null;
    _canal?.sink.close();
    _canal = null;
    status = OnlineStatus.erro;
    erro = 'o servidor não respondeu à identificação';
    notifyListeners();
    if (_querConectado) _agendarReconexao();
  }

  String _meuApelido = 'Você';

  // ---------- API pública (ações do jogador) ----------

  void criarMesa({
    required String apelido,
    int metaPontos = 3000,
    String modalidade = 'aberto',
  }) {
    _meuApelido = apelido;
    _enviar({
      'tipo': 'criarMesa',
      'apelido': apelido,
      'metaPontos': metaPontos,
      'modalidade': modalidade,
    });
  }

  void entrarMesa({required String codigo, required String apelido}) {
    _meuApelido = apelido;
    _enviar({'tipo': 'entrarMesa', 'codigo': codigo, 'apelido': apelido});
  }

  void iniciarPartida() => _enviar({'tipo': 'iniciarPartida'});

  /// Envia uma jogada crua no formato do motor:
  /// {tipo:'comprarMonte'} · {tipo:'comprarLixo'} · {tipo:'descartar', id}
  /// {tipo:'baixar', ids:[...]} · {tipo:'estender', indiceJogo, ids:[...]}
  void enviarJogada(Map<String, dynamic> jogada) =>
      _enviar({'tipo': 'jogada', 'jogada': jogada});

  // Atalhos convenientes (espelham o motor):
  void comprarMonte() => enviarJogada({'tipo': 'comprarMonte'});
  void comprarLixo() => enviarJogada({'tipo': 'comprarLixo'});
  void descartar(String id) => enviarJogada({'tipo': 'descartar', 'id': id});
  void baixar(List<String> ids) => enviarJogada({'tipo': 'baixar', 'ids': ids});
  void estender(int indiceJogo, List<String> ids) =>
      enviarJogada({'tipo': 'estender', 'indiceJogo': indiceJogo, 'ids': ids});

  void sair() {
    _enviar({'tipo': 'sair'});
    codigo = null;
    meuAssento = null;
    visao = null;
    notifyListeners();
  }

  /// Fecha tudo (sair da tela online).
  void desligar() {
    _querConectado = false;
    _derrubarSocket();
    _identidadeSub?.cancel();
    _identidadeSub = null;
    _pendentes.clear();
    status = OnlineStatus.desconectado;
    notifyListeners();
  }

  // ---------- Interno ----------

  /// Comando de jogador: só sai depois de AUTENTICADO. Antes disso vai para a
  /// fila — que é liberada no "autenticado", nunca no "socket abriu".
  void _enviar(Map<String, dynamic> msg) {
    if (status != OnlineStatus.conectado || _canal == null) {
      if (_estadoTerminal) return; // insistir não ajuda
      _pendentes.add(msg); // guarda pra enviar quando autenticar
      conectar();
      return;
    }
    _bruto(msg);
  }

  /// Escrita crua no socket. O ÚNICO caminho por onde o `auth` pode sair sem
  /// passar pela fila. O conteúdo não é logado — ele carrega a credencial.
  void _bruto(Map<String, dynamic> msg) {
    final canal = _canal;
    if (canal == null) return;
    canal.sink.add(jsonEncode(msg));
  }

  void _aoReceber(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return; // mensagem malformada: ignora (o servidor é a verdade)
    }
    switch (msg['tipo']) {
      case 'autenticado':
        _aoAutenticar();
        return;
      case 'authFalhou':
        // Falha terminal: o servidor não diz o motivo de propósito, e reconectar
        // com a mesma credencial ruim só daria laço.
        _falhaDeCredencial('não foi possível validar sua conta');
        return;
      case 'authExpirou':
        // A credencial venceu com a conexão de pé. O servidor dá uma carência
        // curta para apresentar um token novo — sem derrubar ninguém da mesa.
        _renovarCredencial();
        return;
      case 'atualizacaoObrigatoria':
        _falhaTerminal(
          OnlineStatus.atualizacaoObrigatoria,
          (msg['motivo'] as String?) ??
              'atualize o aplicativo para continuar jogando online',
        );
        return;
      case 'entrou':
        if (msg['codigo'] != null) codigo = msg['codigo'] as String;
        meuAssento = msg['assento'] as int?;
        erro = null;
        break;
      case 'estado':
        visao = (msg['visao'] as Map).cast<String, dynamic>();
        erro = null;
        break;
      case 'erro':
        if (msg['codigo'] == 'ATUALIZACAO_OBRIGATORIA') {
          _falhaTerminal(
            OnlineStatus.atualizacaoObrigatoria,
            (msg['motivo'] as String?) ??
                'atualize o aplicativo para continuar jogando online',
          );
          return;
        }
        // Servidor ANTIGO: ele não conhece o tipo `auth` e responde com um erro
        // genérico. Não existe caminho de jogo aqui — jogar contra ele exigiria
        // voltar a declarar identidade pelo cliente. Falha explícita, então.
        if (status == OnlineStatus.autenticando) {
          _falhaTerminal(
            OnlineStatus.servidorDesatualizado,
            'o servidor ainda não foi atualizado — tente de novo mais tarde',
          );
          return;
        }
        erro = (msg['motivo'] as String?) ?? 'erro no servidor';
        break;
      default:
        return;
    }
    notifyListeners();
  }

  /// A credencial venceu com a conexão de pé: pega um token novo e reapresenta
  /// no MESMO socket. Enquanto isso o status volta a `autenticando`, então os
  /// comandos voltam para a fila — igual à primeira autenticação.
  Future<void> _renovarCredencial() async {
    if (_canal == null) return;
    status = OnlineStatus.autenticando;
    notifyListeners();

    String? token;
    try {
      token = await _obterIdToken();
    } catch (_) {
      token = null;
    }
    if (_canal == null) return; // caiu enquanto buscava o token
    if (token == null || token.isEmpty) {
      _falhaDeCredencial('entre na sua conta para continuar jogando online');
      return;
    }
    _mandarCredencial(token);
  }

  /// Credencial aceita: a conexão passa a valer e a fila é liberada.
  void _aoAutenticar() {
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;

    final primeiraDestaConexao = !_jaAutenticouNestaConexao;
    _jaAutenticouNestaConexao = true;

    status = OnlineStatus.conectado;
    _tentativas = 0;
    erro = null;
    notifyListeners();

    // Se caímos e voltamos com uma mesa aberta, tenta reentrar na mesma mesa.
    // Quem essa reentrada pertence é decidido pelo servidor, a partir do token —
    // o código da mesa aqui só diz PARA ONDE voltar, não QUEM está voltando.
    //
    // Só na PRIMEIRA autenticação da conexão: numa renovação de credencial o
    // socket nunca caiu e o assento continua nosso — reentrar pegaria outro.
    if (primeiraDestaConexao && codigo != null && _pendentes.isEmpty) {
      _bruto({'tipo': 'entrarMesa', 'codigo': codigo, 'apelido': _meuApelido});
    }
    final fila = List<Map<String, dynamic>>.from(_pendentes);
    _pendentes.clear();
    for (final m in fila) {
      _bruto(m);
    }
  }

  /// Sem credencial ou credencial recusada.
  void _falhaDeCredencial(String mensagem) =>
      _falhaTerminal(OnlineStatus.naoAutenticado, mensagem);

  /// Estado terminal: derruba o socket, esvazia a fila e NÃO agenda reconexão.
  /// Usado quando insistir não resolveria — credencial recusada, app velho
  /// demais, servidor velho demais.
  void _falhaTerminal(OnlineStatus novo, String mensagem) {
    _querConectado = false;
    _derrubarSocket();
    // A vigilância da conta NÃO é cancelada aqui, e a diferença importa: depois
    // de `você saiu da conta`, quem volta a entrar precisa tirar o serviço do
    // estado terminal — e é o stream de identidade que avisa.
    _pendentes.clear();
    status = novo;
    erro = mensagem;
    notifyListeners();
  }

  bool get _estadoTerminal =>
      status == OnlineStatus.naoAutenticado ||
      status == OnlineStatus.atualizacaoObrigatoria ||
      status == OnlineStatus.servidorDesatualizado;

  void _aoCair() {
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _sub?.cancel();
    _sub = null;
    _canal = null;
    if (_estadoTerminal) return; // insistir não resolveria
    if (status == OnlineStatus.conectado ||
        status == OnlineStatus.autenticando) {
      status = OnlineStatus.conectando; // vamos tentar voltar
      notifyListeners();
    }
    if (_querConectado) _agendarReconexao();
  }

  void _agendarReconexao() {
    _reconectarTimer?.cancel();
    _tentativas = (_tentativas + 1).clamp(1, 6);
    final segundos = _tentativas * 2; // 2,4,6,… até 12s
    _reconectarTimer = Timer(Duration(seconds: segundos), () {
      // toda reconexão passa pelo _abrir(), que busca credencial de novo antes
      // de abrir o socket: reconectar NUNCA reaproveita identidade anterior.
      if (_querConectado) _abrir();
    });
  }

  @override
  void dispose() {
    desligar();
    super.dispose();
  }
}
