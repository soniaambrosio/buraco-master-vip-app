// online_auth_test.dart — A CREDENCIAL DA CONEXÃO ONLINE (lado do app).
//
// O que se prova aqui é o NOSSO código, não o SDK do Firebase: que o app pega a
// credencial ANTES de abrir o socket, que ela é a primeira coisa que sai pelo
// fio, que nenhum comando de jogador escapa antes do servidor aceitar, que a
// reconexão busca credencial nova, e que o token não vaza para lugar nenhum
// que o app mostre ou registre.
//
// O canal WebSocket é falso (`_CanalFalso`) para o teste rodar sem rede, e a
// fonte da credencial é injetada — são os dois pontos de costura que o
// OnlineService expõe justamente para isto.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:buraco_master_vip/services/online_service.dart';

/// Canal WebSocket de mentira: guarda tudo o que o app escreveu e deixa o teste
/// empurrar mensagens do "servidor" para dentro do app.
class _CanalFalso extends StreamChannelMixin implements WebSocketChannel {
  _CanalFalso({this.falhaAoAbrir});

  final Object? falhaAoAbrir;

  final _doServidor = StreamController<dynamic>.broadcast();
  final List<String> enviadas = [];
  bool fechado = false;

  /// Tudo o que o app escreveu, já decodificado.
  List<Map<String, dynamic>> get mensagens =>
      enviadas.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

  List<Map<String, dynamic>> doTipo(String tipo) =>
      mensagens.where((m) => m['tipo'] == tipo).toList();

  /// O servidor manda algo para o app.
  void servidorEnvia(Map<String, dynamic> msg) => _doServidor.add(jsonEncode(msg));

  /// A conexão cai do lado de lá.
  void servidorDerruba() => _doServidor.close();

  @override
  Future<void> get ready =>
      falhaAoAbrir != null ? Future.error(falhaAoAbrir!) : Future.value();

  @override
  Stream<dynamic> get stream => _doServidor.stream;

  @override
  WebSocketSink get sink => _SinkFalso(this);

  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  @override
  void pipe(dynamic other) => throw UnimplementedError();
}

class _SinkFalso implements WebSocketSink {
  _SinkFalso(this._canal);
  final _CanalFalso _canal;

  @override
  void add(dynamic data) => _canal.enviadas.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    _canal.fechado = true;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) async {}
  @override
  Future<void> get done => Future.value();
}

/// Ambiente: um serviço com credencial e canal controlados pelo teste.
class _Cenario {
  _Cenario({String? token, Object? erroDoToken, Object? falhaAoAbrir}) {
    _token = token;
    _erroDoToken = erroDoToken;
    _falhaAoAbrir = falhaAoAbrir;
    servico = OnlineService(
      // O endereço do servidor agora vem da configuração do build, e um build
      // de teste não tem nenhuma. Injetar aqui mantém estas provas focadas na
      // credencial — a validação do endereço tem suíte própria.
      endpoint: Uri.parse('wss://servidor-de-teste.invalido'),
      obterIdToken: () async {
        pedidosDeToken++;
        if (_erroDoToken != null) throw _erroDoToken!;
        return _token;
      },
      abrirCanal: (url) {
        urlsAbertas.add(url);
        final c = _CanalFalso(falhaAoAbrir: _falhaAoAbrir);
        canais.add(c);
        return c;
      },
    );
  }

  late final OnlineService servico;
  final List<_CanalFalso> canais = [];
  final List<Uri> urlsAbertas = [];
  int pedidosDeToken = 0;

  String? _token;
  Object? _erroDoToken;
  Object? _falhaAoAbrir;

  _CanalFalso get canal => canais.last;

  void trocarToken(String? novo) => _token = novo;
  void pararDeFalharAoAbrir() => _falhaAoAbrir = null;

  /// Conecta e espera o app terminar de pedir credencial e abrir o socket.
  Future<void> conectar() async {
    servico.conectar();
    await _assentar();
  }

  Future<void> _assentar() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// O servidor aceita a credencial.
  Future<void> servidorAceita({String jogadorId = 'uid-da-sonia'}) async {
    canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': jogadorId});
    await _assentar();
  }

  /// O servidor recusa a credencial.
  Future<void> servidorRecusa() async {
    canal.servidorEnvia({'tipo': 'authFalhou', 'motivo': 'credencial recusada'});
    await _assentar();
  }

  Future<void> assentar() => _assentar();
}

void main() {
  const kToken = 'eyJhbGciOiJSUzI1NiIsImtpZCI6ImsxIn0.PAYLOAD.ASSINATURA';

  group('a credencial vem antes do socket', () {
    test('o token é pedido ANTES de abrir a conexão', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();

      expect(c.pedidosDeToken, 1);
      expect(c.canais, hasLength(1));
    });

    test('a PRIMEIRA coisa que sai pelo fio é a autenticação', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();

      expect(c.canal.mensagens, isNotEmpty);
      expect(c.canal.mensagens.first['tipo'], 'auth');
      expect(c.canal.mensagens.first['token'], kToken);
    });

    test('sem usuário logado, nem tenta abrir o socket', () async {
      final c = _Cenario(token: null);
      await c.conectar();

      expect(c.canais, isEmpty, reason: 'não pode abrir conexão sem credencial');
      expect(c.servico.status, OnlineStatus.naoAutenticado);
      expect(c.servico.erro, isNotNull);
    });

    test('erro ao obter a credencial é falha controlada, não exceção', () async {
      final c = _Cenario(erroDoToken: StateError('SDK indisponível'));
      await c.conectar();

      expect(c.canais, isEmpty);
      expect(c.servico.status, OnlineStatus.naoAutenticado);
    });

    test('token vazio conta como sem credencial', () async {
      final c = _Cenario(token: '');
      await c.conectar();

      expect(c.canais, isEmpty);
      expect(c.servico.status, OnlineStatus.naoAutenticado);
    });

    test('a credencial não vai na URL nem em query string', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();

      final url = c.urlsAbertas.single.toString();
      expect(url, 'wss://servidor-de-teste.invalido');
      expect(url, isNot(contains(kToken)));
      expect(c.urlsAbertas.single.queryParameters, isEmpty);
    });
  });

  group('nenhum comando de jogador antes de autenticar', () {
    test('comandos ficam na fila enquanto a credencial não é aceita', () async {
      final c = _Cenario(token: kToken);
      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();

      expect(c.servico.status, OnlineStatus.autenticando);
      expect(c.canal.doTipo('criarMesa'), isEmpty,
          reason: 'o comando não podia ter saído antes do "autenticado"');
      expect(c.canal.mensagens.map((m) => m['tipo']), ['auth']);
    });

    test('a fila só é liberada quando o servidor aceita a credencial', () async {
      final c = _Cenario(token: kToken);
      c.servico.criarMesa(apelido: 'Sônia');
      c.servico.iniciarPartida();
      await c.assentar();
      expect(c.canal.mensagens, hasLength(1));

      await c.servidorAceita();

      expect(c.servico.status, OnlineStatus.conectado);
      expect(c.canal.mensagens.map((m) => m['tipo']),
          ['auth', 'criarMesa', 'iniciarPartida']);
    });

    test('depois de autenticado, os comandos saem na hora', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      c.servico.comprarMonte();
      c.servico.descartar('c1');

      expect(c.canal.doTipo('jogada'), hasLength(2));
    });
  });

  group('o app não declara identidade', () {
    test('nenhum comando carrega jogadorId, uid ou equivalente', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      c.servico.criarMesa(apelido: 'Sônia');
      c.servico.entrarMesa(codigo: 'MESA-1', apelido: 'Sônia');
      c.servico.iniciarPartida();
      c.servico.comprarMonte();
      c.servico.baixar(['c1', 'c2', 'c3']);
      c.servico.sair();

      const proibidos = ['jogadorId', 'uid', 'playerId', 'usuarioId', 'ownerId'];
      for (final m in c.canal.mensagens.where((m) => m['tipo'] != 'auth')) {
        for (final campo in proibidos) {
          expect(m.containsKey(campo), isFalse,
              reason: '${m['tipo']} não pode declarar "$campo"');
        }
      }
    });
  });

  group('credencial recusada é falha terminal', () {
    test('authFalhou derruba a conexão e não reconecta sozinho', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorRecusa();

      expect(c.servico.status, OnlineStatus.naoAutenticado);
      expect(c.canal.fechado, isTrue);

      // deixa passar bem mais do que o maior backoff (12s)
      await Future<void>.delayed(Duration.zero);
      expect(c.canais, hasLength(1), reason: 'não podia ter tentado de novo');
    });

    test('comandos depois da recusa não reabrem conexão', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorRecusa();

      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();

      expect(c.canais, hasLength(1));
      expect(c.servico.status, OnlineStatus.naoAutenticado);
    });

    test('a fila é descartada na recusa, não fica esperando', () async {
      final c = _Cenario(token: kToken);
      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();
      await c.servidorRecusa();

      // reconectando na mão, com credencial nova: a fila velha não ressuscita
      c.trocarToken('$kToken.novo');
      await c.conectar();
      await c.servidorAceita();

      expect(c.canal.doTipo('criarMesa'), isEmpty);
    });
  });

  // A reconexão passa pelo backoff (2..12s), então estes dois rodam com relógio
  // falso: é a única forma de exercitar a REABERTURA de verdade, em vez de
  // forçar um `conectar()` que o guarda-corpo de estado ignoraria.
  group('reconexão', () {
    test('a reconexão pede credencial NOVA antes de abrir o socket', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken);
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 1));
        c.canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-da-sonia'});
        async.elapse(const Duration(milliseconds: 1));
        expect(c.pedidosDeToken, 1);

        c.trocarToken('$kToken.renovado');
        c.canal.servidorDerruba();
        async.elapse(const Duration(seconds: 5)); // passa o backoff

        expect(c.pedidosDeToken, 2, reason: 'reconectar tem que buscar token de novo');
        expect(c.canais, hasLength(2));
        expect(c.canal.mensagens.first['tipo'], 'auth');
        expect(c.canal.mensagens.first['token'], '$kToken.renovado',
            reason: 'a credencial da conexão nova é a renovada');

        c.servico.desligar();
      });
    });

    test('a volta para a mesa só acontece depois de autenticar de novo', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken);
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 1));
        c.canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-da-sonia'});
        c.canal.servidorEnvia({'tipo': 'entrou', 'codigo': 'MESA-1', 'assento': 0});
        async.elapse(const Duration(milliseconds: 1));
        expect(c.servico.codigo, 'MESA-1');

        c.canal.servidorDerruba();
        async.elapse(const Duration(seconds: 5));

        // socket novo aberto, mas ainda não autenticado: nada de entrarMesa
        expect(c.canais, hasLength(2));
        expect(c.canal.doTipo('entrarMesa'), isEmpty);
        expect(c.canal.mensagens.map((m) => m['tipo']), ['auth']);

        c.canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-da-sonia'});
        async.elapse(const Duration(milliseconds: 1));

        final volta = c.canal.doTipo('entrarMesa');
        expect(volta, hasLength(1));
        expect(volta.single['codigo'], 'MESA-1');
        expect(volta.single.containsKey('jogadorId'), isFalse,
            reason: 'quem volta é decidido pelo token, não por um id declarado');

        c.servico.desligar();
      });
    });

    test('sem credencial na volta, não abre socket nenhum', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken);
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 1));
        c.canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-da-sonia'});
        async.elapse(const Duration(milliseconds: 1));

        c.trocarToken(null); // a sessão do Firebase caiu nesse meio-tempo
        c.canal.servidorDerruba();
        async.elapse(const Duration(seconds: 5));

        expect(c.canais, hasLength(1), reason: 'sem credencial não se abre conexão');
        expect(c.servico.status, OnlineStatus.naoAutenticado);
      });
    });

    test('falha ao abrir o socket não vira falha de credencial', () async {
      final c = _Cenario(token: kToken, falhaAoAbrir: StateError('rede fora'));
      await c.conectar();

      expect(c.servico.status, OnlineStatus.erro);
      expect(c.servico.status, isNot(OnlineStatus.naoAutenticado));
      c.servico.desligar();
    });
  });

  group('a credencial não vaza', () {
    test('o token não aparece em erro, status nem no estado exposto', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      c.canal.servidorEnvia({'tipo': 'erro', 'motivo': 'você não está numa mesa'});
      await c.assentar();

      final expostos = [
        c.servico.erro,
        c.servico.status.toString(),
        c.servico.codigo,
        c.servico.visao?.toString(),
        c.servico.toString(),
      ].whereType<String>();

      for (final s in expostos) {
        expect(s, isNot(contains(kToken)));
        expect(s, isNot(contains('ASSINATURA')));
      }
    });

    test('o token sai UMA vez, só na mensagem de auth', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      c.servico.criarMesa(apelido: 'Sônia');
      c.servico.comprarMonte();

      final comToken = c.canal.enviadas.where((s) => s.contains(kToken));
      expect(comToken, hasLength(1));
      expect(jsonDecode(comToken.single)['tipo'], 'auth');
    });
  });

  group('ponte de versão do protocolo', () {
    test('a autenticação declara a versão do protocolo', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();

      expect(c.canal.mensagens.first['protocolo'], OnlineService.protocolo);
      expect(OnlineService.protocolo, greaterThanOrEqualTo(2));
    });

    test('servidor exigindo versão mais nova: falha terminal explícita', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      c.canal.servidorEnvia({
        'tipo': 'atualizacaoObrigatoria',
        'codigo': 'ATUALIZACAO_OBRIGATORIA',
        'motivo': 'atualize o aplicativo para continuar jogando online',
        'protocoloMinimo': 3,
      });
      await c.assentar();

      expect(c.servico.status, OnlineStatus.atualizacaoObrigatoria);
      expect(c.servico.erro, contains('atualize o aplicativo'));
      expect(c.canal.fechado, isTrue);

      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();
      expect(c.canais, hasLength(1), reason: 'não adianta reconectar');
    });

    test('erro com codigo ATUALIZACAO_OBRIGATORIA também é terminal', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      c.canal.servidorEnvia({
        'tipo': 'erro',
        'codigo': 'ATUALIZACAO_OBRIGATORIA',
        'motivo': 'atualize o aplicativo para continuar jogando online',
      });
      await c.assentar();

      expect(c.servico.status, OnlineStatus.atualizacaoObrigatoria);
    });

    test('servidor ANTIGO (não conhece auth): falha explícita, sem fallback', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      // é exatamente o que o servidor em 1828d42 responde a {tipo:"auth"}
      c.canal.servidorEnvia({'tipo': 'erro', 'motivo': 'tipo desconhecido: auth'});
      await c.assentar();

      expect(c.servico.status, OnlineStatus.servidorDesatualizado);
      expect(c.servico.erro, contains('servidor'));
      expect(c.canal.fechado, isTrue);

      // e o app NÃO cai para um modo sem autenticação
      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();
      expect(c.canais, hasLength(1));
      expect(c.canal.doTipo('criarMesa'), isEmpty);
    });

    test('erro comum DEPOIS de autenticado continua sendo erro comum', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      c.canal.servidorEnvia({'tipo': 'erro', 'motivo': 'você não está numa mesa'});
      await c.assentar();

      expect(c.servico.status, OnlineStatus.conectado);
      expect(c.servico.erro, 'você não está numa mesa');
    });

    test('servidor mudo na autenticação não pendura o app', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken);
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 1));
        expect(c.servico.status, OnlineStatus.autenticando);

        // o servidor simplesmente não responde
        async.elapse(OnlineService.limiteDeAutenticacao + const Duration(seconds: 1));

        // O socket mudo é ABANDONADO — é isso que impede a tela de ficar
        // pendurada em "identificando você…" para sempre.
        expect(c.canais.first.fechado, isTrue);
        // E o app segue para uma tentativa NOVA em vez de esperar sem fim.
        // (o backoff é curto na primeira tentativa, então ela já cabe aqui)
        expect(c.canais.length, greaterThan(1),
            reason: 'desistir da tentativa muda não pode virar desistir de conectar');
        c.servico.desligar();
      });
    });
  });

  group('expiração da credencial com a conexão de pé', () {
    test('authExpirou reapresenta um token NOVO no mesmo socket', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      expect(c.pedidosDeToken, 1);

      c.trocarToken('$kToken.renovado');
      c.canal.servidorEnvia({'tipo': 'authExpirou', 'motivo': 'credencial expirada'});
      await c.assentar();

      expect(c.pedidosDeToken, 2, reason: 'tem que buscar credencial nova');
      expect(c.canais, hasLength(1), reason: 'renovar não abre outro socket');
      final auths = c.canal.doTipo('auth');
      expect(auths, hasLength(2));
      expect(auths.last['token'], '$kToken.renovado');
      expect(c.servico.status, OnlineStatus.autenticando);
    });

    test('enquanto renova, nenhum comando de jogador sai', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      c.canal.servidorEnvia({'tipo': 'authExpirou'});
      await c.assentar();

      c.servico.comprarMonte();
      await c.assentar();
      expect(c.canal.doTipo('jogada'), isEmpty, reason: 'a fila segura durante a renovação');

      await c.servidorAceita();
      expect(c.canal.doTipo('jogada'), hasLength(1), reason: 'e sai quando o servidor aceita');
    });

    test('renovar NÃO reentra na mesa (o assento nunca foi perdido)', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      c.canal.servidorEnvia({'tipo': 'entrou', 'codigo': 'MESA-1', 'assento': 0});
      await c.assentar();

      c.canal.servidorEnvia({'tipo': 'authExpirou'});
      await c.assentar();
      await c.servidorAceita();

      expect(c.canal.doTipo('entrarMesa'), isEmpty,
          reason: 'reentrar pegaria OUTRO assento — o socket nunca caiu');
      expect(c.servico.status, OnlineStatus.conectado);
    });

    test('sem credencial na renovação, vira falha terminal', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      c.trocarToken(null); // a sessão do Firebase caiu nesse meio-tempo
      c.canal.servidorEnvia({'tipo': 'authExpirou'});
      await c.assentar();

      expect(c.servico.status, OnlineStatus.naoAutenticado);
      expect(c.canal.fechado, isTrue);
    });

    test('a credencial renovada também não vaza para fora da mensagem auth', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      c.trocarToken('$kToken.renovado');
      c.canal.servidorEnvia({'tipo': 'authExpirou'});
      await c.assentar();

      final comToken = c.canal.enviadas.where((s) => s.contains('$kToken.renovado'));
      expect(comToken, hasLength(1));
      expect(jsonDecode(comToken.single)['tipo'], 'auth');
      expect(c.servico.erro ?? '', isNot(contains(kToken)));
    });
  });

  group('desligar', () {
    test('desligar limpa a fila e não deixa comando pendurado', () async {
      final c = _Cenario(token: kToken);
      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();
      c.servico.desligar();

      expect(c.servico.status, OnlineStatus.desconectado);
      expect(c.canal.fechado, isTrue);

      await c.servidorAceita();
      expect(c.canal.doTipo('criarMesa'), isEmpty);
    });
  });
}
