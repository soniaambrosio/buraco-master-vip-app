// online_service.dart — FATIA A1 do online nativo (Trilha A).
// Camada de conexão do app Flutter com o SERVIDOR que já está no ar (Railway).
// Fala o mesmo protocolo do servidor web (servidor/servidor.js):
//   cliente → servidor:  criarMesa / entrarMesa / iniciarPartida / jogada / sair
//   servidor → cliente:  entrou{codigo,assento} · estado{visao} · erro{motivo}
// A "visao" é a verdade do servidor por assento (lobby OU jogo). A UI só lê isso.
//
// Esta fatia entrega SÓ a conexão + protocolo + estado reativo (ChangeNotifier).
// A fatia A2 liga essa `visao` na tela da mesa. Não mexe no jogo local.
//
// Requer o pacote `web_socket_channel` (o build declara: flutter pub add web_socket_channel).

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum OnlineStatus { desconectado, conectando, conectado, erro }

class OnlineService extends ChangeNotifier {
  // Servidor de produção já no ar (ver NO-AR.md). Trocável se mudar de host.
  static const String servidorUrl =
      'wss://buraco-servidor-production.up.railway.app';

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _sub;

  OnlineStatus status = OnlineStatus.desconectado;
  String? erro; // última mensagem de erro (conexão ou do servidor)

  // Estado da sessão online (vem do servidor)
  int? meuAssento; // assento do jogador nesta mesa
  String? codigo; // código da mesa
  Map<String, dynamic>? visao; // lobby OU visão de jogo do assento

  // Mensagens a enviar assim que a conexão abrir (ex.: criarMesa logo após conectar)
  final List<Map<String, dynamic>> _pendentes = [];

  // Reconexão automática (backoff simples)
  bool _querConectado = false;
  int _tentativas = 0;
  Timer? _reconectarTimer;

  bool get conectado => status == OnlineStatus.conectado;
  bool get noLobby => visao != null && visao!['lobby'] == true;
  bool get emJogo => visao != null && visao!['lobby'] != true;

  /// Abre a conexão com o servidor. Idempotente.
  void conectar() {
    _querConectado = true;
    _abrir();
  }

  Future<void> _abrir() async {
    if (status == OnlineStatus.conectando || status == OnlineStatus.conectado) {
      return;
    }
    status = OnlineStatus.conectando;
    erro = null;
    notifyListeners();
    try {
      _canal = WebSocketChannel.connect(Uri.parse(servidorUrl));
      await _canal!.ready; // espera a conexão ficar pronta (lança se falhar)
    } catch (e) {
      status = OnlineStatus.erro;
      erro = 'não foi possível conectar ao servidor';
      notifyListeners();
      _agendarReconexao();
      return;
    }

    status = OnlineStatus.conectado;
    _tentativas = 0;
    notifyListeners();

    _sub = _canal!.stream.listen(
      _aoReceber,
      onDone: _aoCair,
      onError: (Object e) {
        erro = 'conexão instável';
        _aoCair();
      },
      cancelOnError: true,
    );

    // Se caímos e voltamos com uma mesa aberta, tenta reentrar na mesma mesa.
    if (codigo != null && _pendentes.isEmpty) {
      _enviar({'tipo': 'entrarMesa', 'codigo': codigo, 'apelido': _meuApelido});
    }
    // Envia o que estava na fila (ex.: criarMesa disparado antes de conectar).
    final fila = List<Map<String, dynamic>>.from(_pendentes);
    _pendentes.clear();
    for (final m in fila) {
      _enviar(m);
    }
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
    _reconectarTimer?.cancel();
    _sub?.cancel();
    _canal?.sink.close();
    _canal = null;
    status = OnlineStatus.desconectado;
    notifyListeners();
  }

  // ---------- Interno ----------

  void _enviar(Map<String, dynamic> msg) {
    if (status != OnlineStatus.conectado || _canal == null) {
      _pendentes.add(msg); // guarda pra enviar quando conectar
      conectar();
      return;
    }
    _canal!.sink.add(jsonEncode(msg));
  }

  void _aoReceber(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return; // mensagem malformada: ignora (o servidor é a verdade)
    }
    switch (msg['tipo']) {
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
        erro = (msg['motivo'] as String?) ?? 'erro no servidor';
        break;
      default:
        return;
    }
    notifyListeners();
  }

  void _aoCair() {
    _sub?.cancel();
    _sub = null;
    _canal = null;
    if (status == OnlineStatus.conectado) {
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
      if (_querConectado) _abrir();
    });
  }

  @override
  void dispose() {
    desligar();
    super.dispose();
  }
}
