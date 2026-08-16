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
// O app NÃO diz ao servidor quem ele é. Ele APRESENTA uma credencial e o
// servidor decide a identidade a partir dela. Não existe mais campo
// `jogadorId` saindo daqui: mandar um seria, no melhor caso, redundante e, no
// pior, recusado pelo servidor como identidade divergente.
//
//   conectar → pedir credencial à SESSÃO → abrir socket → {tipo:"auth"} →
//   esperar "autenticado" → SÓ ENTÃO soltar a fila de comandos
//
// Sem credencial, nem tenta conectar. Com credencial recusada, para de
// reconectar — insistir com token ruim só gera loop. E o token nunca aparece em
// log, mensagem de erro ou `toString()`.
//
// ---------------------------------------------------------------------------
// DE ONDE VEM A CREDENCIAL — e por que não é do Firebase, aqui.
// ---------------------------------------------------------------------------
//
// Este arquivo NÃO importa `firebase_auth`, e há teste estrutural que falha se
// alguém voltar a importar. A credencial chega por [ObterIdToken], e em
// produção esse callback é `SessaoDoJogador.obterCredencial` — o mesmo objeto
// que é dono da identidade pública e da geração de sessão.
//
// O motivo é concreto: ler `FirebaseAuth.instance` aqui criaria um SEGUNDO dono
// de autenticação, com relógio próprio e sem noção de geração. Entre pedir o
// token e usá-lo existe um await, e um logout cabe inteiro nele — o token que
// voltasse seria do jogador que ACABOU de sair. Pedindo à sessão, essa resposta
// atrasada volta `null` e morre antes de virar um `auth` no fio.
//
// A ponte que liga os dois ciclos de vida mora em `ponte_sessao_online.dart`.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

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
/// Firebase) por duas razões: o teste consegue exercitar o nosso código sem
/// subir o SDK, e a produção pluga `SessaoDoJogador.obterCredencial` sem que
/// este arquivo precise conhecer a camada de sessão.
///
/// O contrato é o mesmo dos dois lados: devolve a credencial atual, ou `null`
/// quando não há credencial válida a apresentar — incluindo o caso em que a
/// sessão virou enquanto o token estava a caminho.
typedef ObterIdToken = Future<String?> Function();

/// Fábrica do canal. Existe pelo mesmo motivo: o teste troca por um canal falso.
typedef AbrirCanal = WebSocketChannel Function(Uri url);

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

  /// [obterIdToken] é OBRIGATÓRIO, e essa obrigatoriedade é o mecanismo.
  ///
  /// Enquanto havia um padrão que lia o Firebase sozinho, `OnlineService()`
  /// solto em qualquer canto do app já nascia sabendo autenticar — e nascia
  /// como um segundo dono de credencial, sem vínculo com a sessão. Sem padrão,
  /// todo ponto de construção precisa dizer DE ONDE vem a credencial, e a única
  /// resposta certa é `SessaoDoJogador.obterCredencial`.
  ///
  /// Ver `criarOnlineServiceDaSessao` em `ponte_sessao_online.dart`, que é como
  /// a produção monta este objeto.
  OnlineService({required ObterIdToken obterIdToken, AbrirCanal? abrirCanal})
      : _obterIdToken = obterIdToken,
        _abrirCanal = abrirCanal ?? WebSocketChannel.connect;

  final ObterIdToken _obterIdToken;
  final AbrirCanal _abrirCanal;

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _sub;

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

  // Geração do TRANSPORTE. Sobe toda vez que esta conexão é encerrada de forma
  // deliberada — [desligar], [encerrarSessao] ou uma falha terminal.
  //
  // Espelha, do lado do socket, a geração que a sessão mantém do lado da
  // identidade, e existe pelo mesmo motivo: `_abrir` e `_renovarCredencial`
  // esperam um `await` para a credencial chegar, e nesse intervalo cabe um
  // logout inteiro. Sem crachá, a continuação do await abriria um socket (ou
  // apresentaria um token) para uma sessão que já não existe.
  //
  // A sessão devolvendo `null` já barra a maior parte disso; esta geração fecha
  // o resto — o caso em que a credencial VOLTOU válida logo antes de o jogador
  // sair, e a continuação seguiria em frente com ela na mão.
  int _geracaoTransporte = 0;

  bool get conectado => status == OnlineStatus.conectado;
  bool get autenticado => status == OnlineStatus.conectado;

  /// O jogador PEDIU para estar online? (independe de já estar).
  ///
  /// Continua verdadeiro enquanto o backoff tenta voltar, e falso depois de
  /// [desligar] ou de uma falha terminal. Quem lê isto é a ponte de sessão, e o
  /// motivo está lá: numa troca de conta ela precisa saber se restabelece a
  /// conexão sob a identidade nova ou se deixa o jogador desconectado.
  bool get querConectado => _querConectado;
  bool get noLobby => visao != null && visao!['lobby'] == true;
  bool get emJogo => visao != null && visao!['lobby'] != true;

  /// Abre a conexão com o servidor. Idempotente.
  void conectar() {
    _querConectado = true;
    _abrir();
  }

  Future<void> _abrir() async {
    if (_abrindo ||
        status == OnlineStatus.autenticando ||
        status == OnlineStatus.conectado) {
      return;
    }
    _abrindo = true;
    // O crachá desta tentativa, capturado ANTES do primeiro await.
    final geracao = _geracaoTransporte;
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
        token = null; // qualquer erro do provedor vale como "não tem credencial"
      }
      // LOGOUT DURANTE A BUSCA DA CREDENCIAL. A tentativa morre calada: não
      // vira falha (ninguém falhou — o jogador saiu), não abre socket e não
      // mexe no status, que `desligar` já acertou.
      if (geracao != _geracaoTransporte || !_querConectado) return;
      if (token == null || token.isEmpty) {
        _falhaDeCredencial('entre na sua conta para jogar online');
        return;
      }

      // 2) SOCKET. O canal fica numa variável LOCAL até estar pronto e ainda
      //    ser desta geração: um canal publicado em `_canal` antes disso seria
      //    visível para o resto da classe enquanto ainda não serve para nada,
      //    e sobreviveria a um `desligar` que já tivesse passado por aqui.
      final WebSocketChannel canal;
      try {
        canal = _abrirCanal(Uri.parse(servidorUrl));
        await canal.ready; // espera a conexão ficar pronta (lança se falhar)
      } catch (e) {
        if (geracao != _geracaoTransporte) return;
        _canal = null;
        status = OnlineStatus.erro;
        erro = 'não foi possível conectar ao servidor';
        notifyListeners();
        _agendarReconexao();
        return;
      }

      // LOGOUT ENQUANTO O SOCKET ABRIA. O socket existe e é nosso, então é
      // nossa a obrigação de fechá-lo — `desligar` não podia tê-lo visto.
      if (geracao != _geracaoTransporte || !_querConectado) {
        canal.sink.close();
        return;
      }
      _canal = canal;

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
    // O crachá sobe ANTES de qualquer outra coisa: é o que faz uma busca de
    // credencial ou uma abertura de socket já em voo desistirem ao voltar.
    _geracaoTransporte++;
    _reconectarTimer?.cancel();
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _sub?.cancel();
    _sub = null;
    _canal?.sink.close();
    _canal = null;
    _pendentes.clear();
    status = OnlineStatus.desconectado;
    notifyListeners();
  }

  /// A sessão do jogador virou: logout, login ou troca de conta.
  ///
  /// Vai além de [desligar] porque desligar é sobre a CONEXÃO e isto é sobre a
  /// PESSOA. Além de derrubar socket, reconexão e fila, apaga o estado privado
  /// que sobraria do jogador anterior — código da mesa, assento, visão e
  /// apelido.
  ///
  /// Sem isto, o jogador B que entrasse depois de A reconectaria e mandaria
  /// `entrarMesa` com o código da mesa de A: não é vazamento de credencial, mas
  /// é o app levando alguém para dentro de uma mesa que não é dele.
  ///
  /// O estado final é [OnlineStatus.desconectado] — e não `naoAutenticado` — de
  /// propósito: `desconectado` é um estado do qual `conectar()` volta a
  /// funcionar, e quem acabou de entrar precisa conseguir jogar.
  ///
  /// Quem chama isto é a ponte (`ponte_sessao_online.dart`), uma vez por
  /// geração de sessão. Nenhuma tela precisa saber que isto existe.
  void encerrarSessao() {
    codigo = null;
    meuAssento = null;
    visao = null;
    erro = null;
    _meuApelido = 'Você';
    _tentativas = 0;
    _jaAutenticouNestaConexao = false;
    desligar(); // sobe a geração, derruba tudo e notifica uma vez só
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
    final canal = _canal;
    if (canal == null) return;
    final geracao = _geracaoTransporte;

    status = OnlineStatus.autenticando;
    notifyListeners();

    String? token;
    try {
      token = await _obterIdToken();
    } catch (_) {
      token = null;
    }
    // Caiu, foi desligado ou a sessão virou enquanto o token vinha. A renovação
    // morre calada: apresentar credencial nova num socket que já não é o nosso
    // é o mesmo vazamento entre contas, só que mais difícil de ver.
    if (geracao != _geracaoTransporte || !identical(_canal, canal)) return;
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
    _geracaoTransporte++; // nada que estiver em voo pode ressuscitar isto
    _reconectarTimer?.cancel();
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _sub?.cancel();
    _sub = null;
    _canal?.sink.close();
    _canal = null;
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
