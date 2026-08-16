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

/// Conta logada no aparelho, de mentira.
///
/// Reproduz o que importa de `authStateChanges`: é broadcast, e quem assina
/// DEPOIS recebe imediatamente o último valor emitido. Sem essa retenção o
/// serviço nunca leria o estado inicial — ele só assina no `conectar()`.
class _ContaLocalFalsa {
  final _controlador = StreamController<String?>.broadcast();
  String? _ultimo;
  bool _temUltimo = false;

  void add(String? uid) {
    _ultimo = uid;
    _temUltimo = true;
    _controlador.add(uid);
  }

  Stream<String?> get stream {
    if (!_temUltimo) return _controlador.stream;
    return Stream<String?>.value(_ultimo).followedBy(_controlador.stream);
  }
}

extension _Concatenar<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> outro) async* {
    yield* this;
    yield* outro;
  }
}

/// Ambiente: um serviço com credencial e canal controlados pelo teste.
class _Cenario {
  _Cenario({
    String? token,
    Object? erroDoToken,
    Object? falhaAoAbrir,
    String? uidInicial,
  }) {
    _token = token;
    _erroDoToken = erroDoToken;
    _falhaAoAbrir = falhaAoAbrir;
    servico = OnlineService(
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
      // Espelha `authStateChanges`: entrega o estado ATUAL a quem assina, e
      // depois cada mudança. O `_contaLocal` é broadcast com valor semeado.
      obterIdentidade: () => _contaLocal.stream,
    );
    _contaLocal.add(uidInicial);
  }

  late final OnlineService servico;
  final List<_CanalFalso> canais = [];
  final List<Uri> urlsAbertas = [];
  int pedidosDeToken = 0;

  /// Conta logada NESTE aparelho, ao longo do tempo.
  final _contaLocal = _ContaLocalFalsa();

  String? _token;
  Object? _erroDoToken;
  Object? _falhaAoAbrir;

  _CanalFalso get canal => canais.last;

  void trocarToken(String? novo) => _token = novo;
  void pararDeFalharAoAbrir() => _falhaAoAbrir = null;

  /// A pessoa entra, sai ou troca de conta no aparelho.
  Future<void> contaLocalPassaASer(String? uid) async {
    _contaLocal.add(uid);
    await _assentar();
  }

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
      expect(url, OnlineService.servidorUrl);
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

        expect(c.servico.status, isNot(OnlineStatus.autenticando));
        expect(c.canal.fechado, isTrue);
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

  // Os dois grupos abaixo cobrem os casos 6 e 7 da OS de composição
  // operacional: sair da conta, e trocar de conta no MESMO processo. Os dois
  // eram o mesmo buraco — o socket já autenticado continuava valendo no
  // servidor até o token vencer, porque a identidade foi derivada no `auth` e
  // nada do lado do app avisava que a conta local tinha mudado.

  group('sair da conta invalida a sessão online', () {
    test('logout com a conexão de pé derruba o socket', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      expect(c.servico.status, OnlineStatus.conectado);

      await c.contaLocalPassaASer(null);

      expect(c.canal.fechado, isTrue);
      expect(c.servico.status, OnlineStatus.naoAutenticado);
    });

    test('logout é falha TERMINAL, não vira reconexão infinita', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken, uidInicial: 'uid-a');
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 10));
        c.canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-a'});
        async.elapse(const Duration(milliseconds: 10));

        c.contaLocalPassaASer(null);
        async.elapse(const Duration(milliseconds: 10));
        final aberturasAposLogout = c.canais.length;

        // Muito além do maior backoff (12s).
        async.elapse(const Duration(minutes: 2));

        expect(c.canais.length, aberturasAposLogout,
            reason: 'não pode abrir socket novo depois do logout');
        expect(c.servico.status, OnlineStatus.naoAutenticado);
      });
    });

    test('depois do logout, comandos não reabrem a conexão', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      await c.contaLocalPassaASer(null);

      final antes = c.canais.length;
      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();

      expect(c.canais.length, antes);
    });

    test('a mesa do dono anterior é esquecida no logout', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      c.canal.servidorEnvia({'tipo': 'entrou', 'codigo': 'MESA7', 'assento': 1});
      await c.assentar();
      expect(c.servico.codigo, 'MESA7');

      await c.contaLocalPassaASer(null);

      expect(c.servico.codigo, isNull);
      expect(c.servico.meuAssento, isNull);
      expect(c.servico.visao, isNull);
    });

    test('voltar a entrar tira o serviço do estado terminal', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      await c.contaLocalPassaASer(null);
      expect(c.servico.status, OnlineStatus.naoAutenticado);

      await c.contaLocalPassaASer('uid-a');

      expect(c.servico.status, isNot(OnlineStatus.naoAutenticado));
      expect(c.servico.erro, isNull);
    });
  });

  group('troca de usuário no mesmo processo', () {
    test('o socket do usuário anterior é derrubado', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      final canalDeA = c.canal;

      await c.contaLocalPassaASer('uid-b');

      expect(canalDeA.fechado, isTrue,
          reason: 'a conexão de A não pode continuar valendo para B');
    });

    test('a conexão de B é aberta com credencial NOVA', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      final canaisAntes = c.canais.length;
      final pedidosAntes = c.pedidosDeToken;

      const tokenDeB = 'eyJhbGciOiJSUzI1NiIsImtpZCI6ImsyIn0.OUTRO.ASSINATURA';
      c.trocarToken(tokenDeB);
      await c.contaLocalPassaASer('uid-b');

      expect(c.canais.length, canaisAntes + 1);
      expect(c.pedidosDeToken, greaterThan(pedidosAntes));
      final auth = c.canal.doTipo('auth');
      expect(auth, hasLength(1));
      expect(auth.single['token'], tokenDeB,
          reason: 'B não pode ser autenticado com a credencial de A');
      expect(auth.single['protocolo'], 2);
    });

    test('a credencial de A não sai pelo socket de B', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');

      c.trocarToken('token-de-b');
      await c.contaLocalPassaASer('uid-b');

      for (final m in c.canal.enviadas) {
        expect(m, isNot(contains(kToken)));
      }
    });

    test('B não é mandado para a mesa de A', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      await c.conectar();
      await c.servidorAceita(jogadorId: 'uid-a');
      c.canal.servidorEnvia({'tipo': 'entrou', 'codigo': 'MESA7', 'assento': 1});
      await c.assentar();

      c.trocarToken('token-de-b');
      await c.contaLocalPassaASer('uid-b');
      await c.servidorAceita(jogadorId: 'uid-b');

      expect(c.canal.doTipo('entrarMesa'), isEmpty,
          reason: 'reentrar em MESA7 usaria o código do dono anterior');
      expect(c.servico.meuAssento, isNull);
    });

    test('comandos de A na fila não são entregues em nome de B', () async {
      final c = _Cenario(token: kToken, uidInicial: 'uid-a');
      c.servico.criarMesa(apelido: 'Sônia'); // fila, antes de autenticar
      await c.assentar();

      c.trocarToken('token-de-b');
      await c.contaLocalPassaASer('uid-b');
      await c.servidorAceita(jogadorId: 'uid-b');

      expect(c.canal.doTipo('criarMesa'), isEmpty);
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
