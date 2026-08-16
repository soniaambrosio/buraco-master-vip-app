// online_service.dart — FATIA A1 do online nativo (Trilha A).
// Camada de conexão do app Flutter com o SERVIDOR que já está no ar (Railway).
// Fala o mesmo protocolo do servidor web (servidor/servidor.js):
//   cliente → servidor:  auth / criarMesa / entrarMesa / iniciarPartida / jogada / sair
//   servidor → cliente:  autenticado · authFalhou · authExpirou ·
//                        atualizacaoObrigatoria · entrou{codigo,assento} ·
//                        estado{visao} · erro{motivo}
// A "visao" é a verdade do servidor por assento (lobby OU jogo). A UI só lê isso.
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
//   conectar → validar endereço → obter ID Token → abrir socket →
//   {tipo:"auth"} → esperar "autenticado" → SÓ ENTÃO soltar a fila de comandos
//
// Sem usuário do Firebase, nem tenta conectar. Com credencial recusada, para de
// reconectar — insistir com token ruim só gera loop. E o token nunca aparece em
// log, mensagem de erro ou `toString()`.
//
// ENDEREÇO DO SERVIDOR — vem da configuração do build, não do código. Ver
// `endpoint_servidor.dart`: um build publicável apontando para `localhost` ou
// falando `ws://` é recusado antes de abrir socket nenhum.
//
// GERAÇÃO DE SESSÃO — cada abertura de conexão recebe um número. Retorno tardio
// (token que demorou, mensagem de um socket que já caiu, timer de uma tentativa
// antiga) confere a geração e desiste se ela não for mais a atual. É isso que
// impede socket órfão depois de rebuild/rotação e mensagem de sessão velha
// entrando na sessão nova.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'endpoint_servidor.dart';
import 'redacao_segredos.dart';

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

  /// Este build não tem endereço de servidor utilizável (não configurado,
  /// apontando para máquina local, ou sem TLS). Falha terminal: nenhuma
  /// tentativa de rede conserta um build mal configurado.
  configuracaoInvalida,

  /// Acabaram as tentativas de reconexão. Falha terminal do ciclo automático —
  /// a pessoa pode mandar tentar de novo, mas o app parou de insistir sozinho.
  semConexao,
}

/// Fonte da credencial da conexão. Assinatura própria (e não o `User` do
/// Firebase) para o teste conseguir exercitar o nosso código sem subir o SDK.
typedef ObterIdToken = Future<String?> Function();

/// Fábrica do canal. Existe pelo mesmo motivo: o teste troca por um canal falso.
typedef AbrirCanal = WebSocketChannel Function(Uri url);

class OnlineService extends ChangeNotifier {
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

  /// Quantas reconexões automáticas seguidas antes de desistir. Existe porque
  /// "tentar para sempre" é, para quem olha a tela, indistinguível de um app
  /// travado — e queima bateria e dados a noite inteira.
  static const int limiteDeTentativas = 6;

  /// Primeira espera do backoff. Dobra a cada tentativa, com teto.
  static const Duration esperaBase = Duration(milliseconds: 500);
  static const Duration esperaMaxima = Duration(seconds: 30);

  OnlineService({
    ObterIdToken? obterIdToken,
    AbrirCanal? abrirCanal,
    Uri? endpoint,
    Random? aleatorio,
  })  : _obterIdToken = obterIdToken ?? _idTokenDoFirebase,
        _abrirCanal = abrirCanal ?? WebSocketChannel.connect,
        _endpointFixo = endpoint,
        _aleatorio = aleatorio ?? Random();

  final ObterIdToken _obterIdToken;
  final AbrirCanal _abrirCanal;

  /// Endereço injetado (teste/homologação). Quando nulo, sai da configuração
  /// do build — que é o caminho do app publicado.
  final Uri? _endpointFixo;

  /// Fonte do jitter do backoff. Injetável para o teste conseguir prever a
  /// espera sem depender de sorteio.
  final Random _aleatorio;

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

  // Reconexão automática (backoff exponencial com jitter e teto de tentativas)
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

  // Renovação de credencial em curso. É a coordenação que impede tempestade de
  // refresh: o servidor pode repetir `authExpirou` e a UI pode disparar vários
  // comandos ao mesmo tempo, mas só UM pedido de token novo fica em voo.
  bool _renovando = false;

  /// Número da conexão atual. Toda abertura incrementa; todo retorno tardio
  /// confere. Ver o cabeçalho do arquivo.
  int _geracao = 0;

  Timer? _limiteAuthTimer;

  bool get conectado => status == OnlineStatus.conectado;
  bool get autenticado => status == OnlineStatus.conectado;
  bool get noLobby => visao != null && visao!['lobby'] == true;
  bool get emJogo => visao != null && visao!['lobby'] != true;

  /// Estado do qual o ciclo automático não sai sozinho. A UI usa isto para
  /// decidir entre "aguarde" e "faça alguma coisa".
  bool get falhaTerminal => _estadoTerminal;

  /// Geração da conexão atual. Exposta para diagnóstico e teste.
  @visibleForTesting
  int get geracao => _geracao;

  /// Abre a conexão com o servidor. Idempotente.
  void conectar() {
    _querConectado = true;
    _abrir();
  }

  /// Recomeça depois de uma falha terminal — é o "tentar de novo" da tela.
  /// Zera o contador, senão o backoff voltaria já no teto.
  void tentarNovamente() {
    _tentativas = 0;
    erro = null;
    if (_estadoTerminal) {
      status = OnlineStatus.desconectado;
      notifyListeners();
    }
    conectar();
  }

  Future<void> _abrir() async {
    if (_abrindo ||
        status == OnlineStatus.autenticando ||
        status == OnlineStatus.conectado) {
      return;
    }
    _abrindo = true;
    final geracao = ++_geracao;
    try {
      status = OnlineStatus.conectando;
      erro = null;
      notifyListeners();

      // 0) ENDEREÇO. Antes de qualquer coisa: um build mal configurado não
      //    melhora tentando de novo, então é falha terminal e não entra no
      //    backoff.
      final Uri endpoint;
      try {
        endpoint = _endpointFixo ?? EndpointServidor.resolver();
      } on EndpointInvalido catch (e) {
        _falhaTerminal(OnlineStatus.configuracaoInvalida, e.motivo);
        return;
      }

      // 1) CREDENCIAL. Sem ela não faz sentido abrir socket: o servidor não
      //    aceita comando de conexão não autenticada. É aqui que a reconexão
      //    pega token FRESCO — nunca reaproveita identidade anterior.
      String? token;
      try {
        token = await _obterIdToken();
      } catch (_) {
        token = null; // qualquer erro do SDK vale como "não tem credencial"
      }
      // O token pode ter demorado. Se enquanto isso a conexão foi desligada ou
      // reaberta, esta tentativa não vale mais — e abrir socket agora deixaria
      // um órfão.
      if (geracao != _geracao) return;
      if (token == null || token.isEmpty) {
        _falhaDeCredencial('entre na sua conta para jogar online');
        return;
      }

      // 2) SOCKET.
      final WebSocketChannel canal;
      try {
        canal = _abrirCanal(endpoint);
        _canal = canal;
        await canal.ready; // espera a conexão ficar pronta (lança se falhar)
      } catch (e) {
        if (geracao != _geracao) return;
        _canal = null;
        status = OnlineStatus.erro;
        // Mensagem própria, e não a da exceção: a do transporte costuma trazer
        // a URL e o que mais ele quiser junto.
        erro = 'não foi possível conectar ao servidor';
        notifyListeners();
        _agendarReconexao();
        return;
      }
      if (geracao != _geracao) {
        // Desligaram durante o handshake: fecha este socket em vez de deixá-lo
        // aberto sem ninguém escutando.
        try {
          canal.sink.close();
        } catch (_) {}
        return;
      }

      // 3) CREDENCIAL NA PRIMEIRA MENSAGEM. Até o servidor responder
      //    "autenticado", nada mais é enviado.
      _jaAutenticouNestaConexao = false;

      _sub = canal.stream.listen(
        (raw) {
          if (geracao != _geracao) return; // mensagem de sessão antiga
          _aoReceber(raw);
        },
        onDone: () {
          if (geracao != _geracao) return;
          _aoCair();
        },
        onError: (Object e) {
          if (geracao != _geracao) return;
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

    final geracao = _geracao;
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = Timer(limiteDeAutenticacao, () {
      if (geracao != _geracao) return;
      _aoEstourarLimiteDeAuth();
    });

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
    _renovando = false;
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
    _limparProjecao();
    codigo = null;
    notifyListeners();
  }

  /// Fecha tudo (sair da tela online).
  void desligar() {
    _querConectado = false;
    _geracao++; // invalida tudo que estiver em voo
    _reconectarTimer?.cancel();
    _reconectarTimer = null;
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _renovando = false;
    _abrindo = false;
    _sub?.cancel();
    _sub = null;
    _canal?.sink.close();
    _canal = null;
    _pendentes.clear();
    status = OnlineStatus.desconectado;
    notifyListeners();
  }

  /// A pessoa saiu da conta. Além de fechar a conexão, apaga tudo que pertencia
  /// à identidade anterior: a mesa e a projeção do assento não podem sobreviver
  /// à troca de usuário — quem entrar depois veria dado que não é dele.
  void encerrarPorLogout() {
    desligar();
    codigo = null;
    _meuApelido = 'Você';
    _limparProjecao();
    erro = null;
    notifyListeners();
  }

  // ---------- Interno ----------

  void _limparProjecao() {
    meuAssento = null;
    visao = null;
  }

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
        // A visão é a projeção DO SEU ASSENTO, calculada pelo servidor. Uma
        // conexão sem assento não recebe visão nenhuma dele (o servidor filtra
        // por `assento != null`); se uma chegar assim mesmo, é mensagem fora de
        // contexto — descartar é o certo, mostrar seria exibir a projeção de
        // outra pessoa.
        if (meuAssento == null) return;
        final bruta = msg['visao'];
        if (bruta is! Map) return;
        visao = bruta.cast<String, dynamic>();
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
        // O motivo vem do servidor e vai para a tela: passa pela redação, que é
        // barata, para o caso de ele ecoar algo que não devia.
        erro = redigir((msg['motivo'] as String?) ?? 'erro no servidor');
        break;
      default:
        return;
    }
    notifyListeners();
  }

  /// A credencial venceu com a conexão de pé: pega um token novo e reapresenta
  /// no MESMO socket. Enquanto isso o status volta a `autenticando`, então os
  /// comandos voltam para a fila — igual à primeira autenticação.
  ///
  /// UMA renovação por vez: o servidor pode repetir o aviso, e sem esta trava
  /// cada repetição viraria um pedido de token — a tempestade de refresh.
  ///
  /// A trava só cai quando a renovação TERMINA (o servidor aceita, ou tudo
  /// falha), não quando o token chega. Soltá-la ao receber o token deixava uma
  /// janela em que os avisos seguintes disparavam pedidos novos — que é
  /// exatamente a tempestade, só que mais curta.
  Future<void> _renovarCredencial() async {
    if (_renovando) return;
    if (_canal == null) return;
    _renovando = true;
    final geracao = _geracao;

    status = OnlineStatus.autenticando;
    notifyListeners();

    String? token;
    try {
      token = await _obterIdToken();
    } catch (_) {
      token = null;
    }
    if (geracao != _geracao) return; // caiu/reabriu enquanto buscava o token
    if (_canal == null) {
      _renovando = false;
      return;
    }
    if (token == null || token.isEmpty) {
      // `_falhaTerminal` solta a trava.
      _falhaDeCredencial('entre na sua conta para continuar jogando online');
      return;
    }
    // A trava continua de pé até `_aoAutenticar` (ou uma falha) resolvê-la.
    _mandarCredencial(token);
  }

  /// Credencial aceita: a conexão passa a valer e a fila é liberada.
  void _aoAutenticar() {
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _renovando = false;

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
      // A projeção guardada é de ANTES da queda. O servidor vai mandar a visão
      // nova; até lá não se mostra a velha como se fosse o estado atual.
      _limparProjecao();
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
  /// demais, servidor velho demais, build mal configurado, tentativas esgotadas.
  void _falhaTerminal(OnlineStatus novo, String mensagem) {
    _querConectado = false;
    _geracao++; // nada que estiver em voo pode reanimar a conexão
    _reconectarTimer?.cancel();
    _reconectarTimer = null;
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _renovando = false;
    _sub?.cancel();
    _sub = null;
    _canal?.sink.close();
    _canal = null;
    _pendentes.clear();
    // A projeção do assento deixa de estar autorizada no instante em que a
    // credencial deixa de valer. Guardá-la seria mostrar dado de uma sessão que
    // o servidor já não reconhece.
    if (novo == OnlineStatus.naoAutenticado) _limparProjecao();
    status = novo;
    erro = redigir(mensagem);
    notifyListeners();
  }

  bool get _estadoTerminal =>
      status == OnlineStatus.naoAutenticado ||
      status == OnlineStatus.atualizacaoObrigatoria ||
      status == OnlineStatus.servidorDesatualizado ||
      status == OnlineStatus.configuracaoInvalida ||
      status == OnlineStatus.semConexao;

  void _aoCair() {
    _limiteAuthTimer?.cancel();
    _limiteAuthTimer = null;
    _renovando = false;
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
    if (_tentativas >= limiteDeTentativas) {
      // Parar de tentar é uma decisão, não um acidente: a tela mostra "sem
      // conexão" com um botão, em vez de girar a noite inteira.
      _falhaTerminal(
        OnlineStatus.semConexao,
        'não foi possível falar com o servidor — verifique sua internet',
      );
      return;
    }
    _tentativas++;
    final espera = esperaDaTentativa(_tentativas);
    final geracao = _geracao;
    _reconectarTimer = Timer(espera, () {
      // toda reconexão passa pelo _abrir(), que busca credencial de novo antes
      // de abrir o socket: reconectar NUNCA reaproveita identidade anterior.
      if (geracao != _geracao) return; // desligaram no meio da espera
      if (_querConectado) _abrir();
    });
  }

  /// Espera antes da tentativa [tentativa] (1-based).
  ///
  /// Exponencial com teto e **jitter**: metade do intervalo é fixa e metade é
  /// sorteada. O jitter não é enfeite — sem ele, uma queda do servidor faz
  /// todos os aparelhos voltarem no mesmo milissegundo e derrubarem de novo o
  /// que acabou de subir.
  @visibleForTesting
  Duration esperaDaTentativa(int tentativa) {
    final expoente = (tentativa - 1).clamp(0, 20);
    final cru = esperaBase.inMilliseconds * (1 << expoente);
    final teto = cru.clamp(0, esperaMaxima.inMilliseconds);
    final metade = teto ~/ 2;
    return Duration(milliseconds: metade + _aleatorio.nextInt(metade + 1));
  }

  @override
  void dispose() {
    desligar();
    super.dispose();
  }
}
