// conexao_producao_test.dart — O PORTÃO DA CONEXÃO PUBLICÁVEL.
//
// A suíte `online_auth_test.dart` prova a CREDENCIAL. Esta aqui prova o que
// falta para o app publicado conseguir manter a sessão real do servidor:
//
//   · o endereço do servidor vem do build e é validado (nada de localhost nem
//     ws:// num app de loja);
//   · o handshake anuncia protocolo 2 e respeita a recusa do servidor;
//   · a renovação de credencial é coordenada — nada de tempestade de refresh;
//   · nenhum comando carrega identidade autodeclarada;
//   · segredo nenhum sobrevive à redação;
//   · a reconexão tem jitter, tem teto e para quando mandam parar;
//   · rebuild/rotação não deixa socket órfão;
//   · mensagem de uma sessão antiga não entra na sessão nova;
//   · sem assento não existe projeção autorizada — e ela não é exibida.
//
// Tudo contra um servidor FALSO. Nenhum teste toca a rede.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:buraco_master_vip/services/endpoint_servidor.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/services/redacao_segredos.dart';

/// Canal WebSocket de mentira: guarda o que o app escreveu e deixa o teste
/// empurrar mensagens do "servidor" para dentro do app.
class _CanalFalso extends StreamChannelMixin implements WebSocketChannel {
  _CanalFalso({this.falhaAoAbrir});

  final Object? falhaAoAbrir;

  final _doServidor = StreamController<dynamic>.broadcast();
  final List<String> enviadas = [];
  bool fechado = false;

  List<Map<String, dynamic>> get mensagens =>
      enviadas.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

  List<Map<String, dynamic>> doTipo(String tipo) =>
      mensagens.where((m) => m['tipo'] == tipo).toList();

  void servidorEnvia(Map<String, dynamic> msg) =>
      _doServidor.add(jsonEncode(msg));

  void servidorDerruba() {
    if (!_doServidor.isClosed) _doServidor.close();
  }

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

/// Sorteio previsível: o jitter vira sempre o piso do intervalo, então o teste
/// consegue afirmar tempo exato sem ficar refém do acaso.
class _SorteioFixo implements Random {
  @override
  int nextInt(int max) => 0;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

const String kEndpointDeTeste = 'wss://servidor-de-teste.invalido';
const String kToken =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6ImsxIn0.UEFZTE9BRA.QVNTSU5BVFVSQQ';
const String kTokenNovo =
    'eyJhbGciOiJSUzI1NiIsImtpZCI6ImsyIn0.T1VUUk8.T1VUUkFBU1NJTg';

class _Cenario {
  _Cenario({String? token, Object? falhaAoAbrir, Duration? demoraDoToken}) {
    _token = token;
    _falhaAoAbrir = falhaAoAbrir;
    _demoraDoToken = demoraDoToken;
    servico = OnlineService(
      endpoint: Uri.parse(kEndpointDeTeste),
      aleatorio: _SorteioFixo(),
      obterIdToken: () async {
        pedidosDeToken++;
        if (_demoraDoToken != null) {
          await Future<void>.delayed(_demoraDoToken!);
        }
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
  Object? _falhaAoAbrir;
  Duration? _demoraDoToken;

  _CanalFalso get canal => canais.last;

  void trocarToken(String? novo) => _token = novo;
  void pararDeFalharAoAbrir() => _falhaAoAbrir = null;

  Future<void> conectar() async {
    servico.conectar();
    await assentar();
  }

  Future<void> assentar() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> servidorAceita() async {
    canal.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-da-sonia'});
    await assentar();
  }

  /// Leva a conexão até uma mesa com assento — o estado em que existe projeção
  /// autorizada para mostrar.
  Future<void> sentarNaMesa({String codigo = 'MESA-1', int assento = 0}) async {
    canal.servidorEnvia(
        {'tipo': 'entrou', 'codigo': codigo, 'assento': assento});
    await assentar();
  }

  /// Todas as mensagens que o app já escreveu, em todos os sockets.
  List<Map<String, dynamic>> get tudoQueSaiu =>
      canais.expand((c) => c.mensagens).toList();
}

void main() {
  // =========================================================================
  group('1. endereço do servidor por perfil de build', () {
    test('release exige endereço configurado — vazio é recusado', () {
      expect(
        () => EndpointServidor.validar('', perfil: PerfilDeBuild.release),
        throwsA(isA<EndpointInvalido>()),
      );
    });

    test('release recusa localhost, loopback e emulador', () {
      for (final ruim in [
        'wss://localhost',
        'wss://127.0.0.1:8080',
        'wss://127.10.20.30',
        'wss://0.0.0.0',
        'wss://10.0.2.2:3000', // emulador Android
        'wss://10.0.3.2', // Genymotion
        'wss://maquina-da-sonia.local',
      ]) {
        expect(
          () => EndpointServidor.validar(ruim, perfil: PerfilDeBuild.release),
          throwsA(isA<EndpointInvalido>()),
          reason: '$ruim não pode passar num build publicável',
        );
      }
    });

    test('release recusa esquema inseguro', () {
      for (final ruim in ['ws://servidor.tld', 'http://servidor.tld']) {
        expect(
          () => EndpointServidor.validar(ruim, perfil: PerfilDeBuild.release),
          throwsA(isA<EndpointInvalido>()),
        );
      }
    });

    test('release ignora a autorização de inseguro — ela não vale na loja', () {
      expect(
        () => EndpointServidor.validar(
          'ws://localhost:3000',
          perfil: PerfilDeBuild.release,
          permitirInseguro: true,
        ),
        throwsA(isA<EndpointInvalido>()),
        reason: 'ligar a chave por engano não pode publicar app inseguro',
      );
    });

    test('release aceita wss externo, e normaliza https', () {
      expect(
        EndpointServidor.validar('wss://servidor.tld', perfil: PerfilDeBuild.release)
            .toString(),
        'wss://servidor.tld',
      );
      expect(
        EndpointServidor.validar('https://servidor.tld/',
                perfil: PerfilDeBuild.release)
            .toString(),
        'wss://servidor.tld',
        reason: 'quem configura copia o https do painel de hospedagem',
      );
    });

    test('desenvolvimento só aceita local com autorização EXPLÍCITA', () {
      expect(
        () => EndpointServidor.validar('ws://localhost:3000',
            perfil: PerfilDeBuild.desenvolvimento),
        throwsA(isA<EndpointInvalido>()),
        reason: 'por omissão, nem em desenvolvimento',
      );
      expect(
        EndpointServidor.validar('ws://localhost:3000',
                perfil: PerfilDeBuild.desenvolvimento, permitirInseguro: true)
            .toString(),
        'ws://localhost:3000',
      );
    });

    test('credencial na URL é recusada em TODO perfil', () {
      for (final perfil in PerfilDeBuild.values) {
        expect(
          () => EndpointServidor.validar('wss://servidor.tld?token=abc',
              perfil: perfil, permitirInseguro: true),
          throwsA(isA<EndpointInvalido>()),
        );
        expect(
          () => EndpointServidor.validar('wss://user:senha@servidor.tld',
              perfil: perfil, permitirInseguro: true),
          throwsA(isA<EndpointInvalido>()),
        );
      }
    });

    test('endereço inválido vira estado seguro, não crash nem spinner',
        () async {
      final servico = OnlineService(
        endpoint: null, // força a configuração do build, que em teste é vazia
        obterIdToken: () async => kToken,
        abrirCanal: (_) => throw StateError('não pode abrir socket nenhum'),
      );
      servico.conectar();
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(servico.status, OnlineStatus.configuracaoInvalida);
      expect(servico.falhaTerminal, isTrue);
      expect(servico.erro, isNotNull);
    });
  });

  // =========================================================================
  group('2. versão do protocolo', () {
    test('o handshake anuncia protocolo 2 — nunca 1', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();

      final auth = c.canal.doTipo('auth').single;
      expect(auth['protocolo'], 2);
      expect(auth['protocolo'], isNot(1));
      expect(OnlineService.protocolo, 2);
    });

    test('servidor que exige versão mais nova para o app, sem laço', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();

      c.canal.servidorEnvia({
        'tipo': 'atualizacaoObrigatoria',
        'codigo': 'ATUALIZACAO_OBRIGATORIA',
        'motivo': 'atualize o aplicativo para continuar jogando online',
        'protocoloMinimo': 2,
      });
      await c.assentar();

      expect(c.servico.status, OnlineStatus.atualizacaoObrigatoria);
      expect(c.servico.falhaTerminal, isTrue);
      expect(c.canal.fechado, isTrue);
    });

    test('protocolo aceito segue para a sessão normal', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      expect(c.servico.status, OnlineStatus.conectado);
    });
  });

  // =========================================================================
  group('3. credencial: válida, recusada, vencida e renovação concorrente', () {
    test('token válido autentica e libera a fila', () async {
      final c = _Cenario(token: kToken);
      c.servico.criarMesa(apelido: 'Sônia');
      await c.assentar();
      expect(c.canal.doTipo('criarMesa'), isEmpty, reason: 'ainda não autenticou');

      await c.servidorAceita();
      expect(c.canal.doTipo('criarMesa'), hasLength(1));
    });

    test('sem credencial não abre socket nenhum', () async {
      final c = _Cenario(token: null);
      await c.conectar();
      expect(c.canais, isEmpty);
      expect(c.servico.status, OnlineStatus.naoAutenticado);
    });

    test('credencial recusada é terminal — não fica reconectando', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken);
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 1));
        c.canal.servidorEnvia({'tipo': 'authFalhou', 'motivo': 'recusada'});
        async.elapse(const Duration(minutes: 5));

        expect(c.servico.status, OnlineStatus.naoAutenticado);
        expect(c.canais, hasLength(1),
            reason: 'insistir com credencial ruim só daria laço');
      });
    });

    test('authExpirou renova UMA vez, mesmo repetido — sem tempestade',
        () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      expect(c.pedidosDeToken, 1);

      c.trocarToken(kTokenNovo);
      // o servidor repete o aviso cinco vezes seguidas
      for (var i = 0; i < 5; i++) {
        c.canal.servidorEnvia({'tipo': 'authExpirou'});
      }
      await c.assentar();

      expect(c.pedidosDeToken, 2,
          reason: 'cinco avisos não podem virar cinco pedidos de token');
      expect(c.canal.doTipo('auth'), hasLength(2));
      expect(c.canal.doTipo('auth').last['token'], kTokenNovo);
      expect(c.canais, hasLength(1), reason: 'renovação é no MESMO socket');
    });

    test('renovação sem credencial vira falha terminal', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      c.trocarToken(null);
      c.canal.servidorEnvia({'tipo': 'authExpirou'});
      await c.assentar();

      expect(c.servico.status, OnlineStatus.naoAutenticado);
    });
  });

  // =========================================================================
  group('4. nenhuma identidade autodeclarada sai do app', () {
    const proibidos = [
      'jogadorId',
      'uid',
      'playerId',
      'usuarioId',
      'ownerId',
      'sub',
      'email',
    ];

    test('nenhum comando carrega campo de identidade', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      // exercita TODO o vocabulário que o app sabe falar
      c.servico.criarMesa(apelido: 'Sônia');
      c.servico.entrarMesa(codigo: 'MESA-1', apelido: 'Sônia');
      c.servico.iniciarPartida();
      c.servico.comprarMonte();
      c.servico.comprarLixo();
      c.servico.descartar('c-1');
      c.servico.baixar(['c-1', 'c-2']);
      c.servico.estender(0, ['c-3']);
      c.servico.sair();
      await c.assentar();

      for (final msg in c.tudoQueSaiu) {
        for (final campo in proibidos) {
          expect(msg.containsKey(campo), isFalse,
              reason: 'o campo "$campo" reapareceu em ${msg['tipo']} — '
                  'o servidor decide quem é a pessoa, o app não declara');
        }
      }
    });

    test('a reentrada após queda também não declara identidade', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();

      c.canal.servidorDerruba();
      await c.assentar();
      await Future<void>.delayed(const Duration(seconds: 1));
      await c.assentar();
      if (c.canais.length > 1) {
        await c.servidorAceita();
      }

      for (final msg in c.tudoQueSaiu.where((m) => m['tipo'] == 'entrarMesa')) {
        for (final campo in proibidos) {
          expect(msg.containsKey(campo), isFalse);
        }
        expect(msg['codigo'], isNotNull,
            reason: 'o código diz PARA ONDE voltar, não QUEM está voltando');
      }
    });
  });

  // =========================================================================
  group('5. redação de segredos', () {
    test('apaga JWT, e-mail, uid, purchaseToken e chaves', () {
      final casos = <String>[
        'falha com token $kToken no meio',
        'Authorization: Bearer $kToken',
        '{"idToken":"$kToken"}',
        '{"purchaseToken":"gpa.1234-5678-9012-34567"}',
        '{"uid":"AbCdEf123456"}',
        'contato: soniia.ambrosio@gmail.com',
        'apiKey=AIzaSyD-segredo-de-verdade',
        '{"password":"minhasenha"}',
        'https://servidor.tld/ws?token=abc123&uid=xyz',
      ];
      for (final bruto in casos) {
        final limpo = redigir(bruto);
        expect(limpo, contains(marcaDeRedacao), reason: 'não redigiu: $bruto');
      }
    });

    test('o token não sobrevive à redação', () {
      expect(redigir('erro: $kToken'), isNot(contains(kToken)));
      expect(redigir('Bearer $kToken'), isNot(contains(kToken)));
    });

    test('e-mail e purchaseToken não sobrevivem', () {
      expect(redigir('user soniia.ambrosio@gmail.com'),
          isNot(contains('soniia.ambrosio@gmail.com')));
      expect(redigir('{"purchaseToken":"gpa.9999-8888"}'),
          isNot(contains('gpa.9999-8888')));
    });

    test('texto sem segredo passa intacto', () {
      const limpo = 'você não está numa mesa';
      expect(redigir(limpo), limpo);
    });

    test('o token não aparece em erro, status nem na projeção', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();
      c.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': true, 'jogadores': []},
      });
      c.canal.servidorEnvia({'tipo': 'erro', 'motivo': 'mesa cheia'});
      await c.assentar();

      final exposto = [
        c.servico.erro ?? '',
        c.servico.status.toString(),
        jsonEncode(c.servico.visao ?? {}),
        c.servico.codigo ?? '',
      ].join(' | ');
      expect(exposto, isNot(contains(kToken)));
    });

    test('motivo vindo do servidor é redigido antes de chegar à tela',
        () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      // um servidor mal comportado ecoando a credencial de volta
      c.canal.servidorEnvia({'tipo': 'erro', 'motivo': 'token ruim: $kToken'});
      await c.assentar();

      expect(c.servico.erro, isNot(contains(kToken)));
      expect(c.servico.erro, contains(marcaDeRedacao));
    });
  });

  // =========================================================================
  group('6. queda, reconexão, limite e cancelamento', () {
    test('a espera cresce, tem teto e tem jitter', () {
      final servico = OnlineService(
        endpoint: Uri.parse(kEndpointDeTeste),
        aleatorio: _SorteioFixo(),
        obterIdToken: () async => kToken,
        abrirCanal: (_) => _CanalFalso(),
      );
      // com o sorteio no piso, a espera é metade do intervalo exponencial
      expect(servico.esperaDaTentativa(1), const Duration(milliseconds: 250));
      expect(servico.esperaDaTentativa(2), const Duration(milliseconds: 500));
      expect(servico.esperaDaTentativa(3), const Duration(seconds: 1));
      // teto: não cresce para sempre
      expect(servico.esperaDaTentativa(20),
          const Duration(milliseconds: 15000));

      // com sorteio de verdade, duas esperas da MESMA tentativa diferem —
      // é isso que espalha a volta de todo mundo depois de uma queda
      final comAcaso = OnlineService(
        endpoint: Uri.parse(kEndpointDeTeste),
        obterIdToken: () async => kToken,
        abrirCanal: (_) => _CanalFalso(),
      );
      final amostras = <int>{};
      for (var i = 0; i < 40; i++) {
        amostras.add(comAcaso.esperaDaTentativa(6).inMilliseconds);
      }
      expect(amostras.length, greaterThan(1),
          reason: 'sem jitter todo aparelho volta no mesmo milissegundo');
      servico.dispose();
      comAcaso.dispose();
    });

    test('queda durante o jogo reconecta e reautentica', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();
      expect(c.pedidosDeToken, 1);

      c.canal.servidorDerruba();
      await c.assentar();
      await Future<void>.delayed(const Duration(seconds: 1));
      await c.assentar();

      expect(c.canais.length, 2, reason: 'abriu socket novo');
      expect(c.pedidosDeToken, 2, reason: 'reconexão pega credencial FRESCA');
      expect(c.canais.last.doTipo('auth'), hasLength(1));
    });

    test('a reconexão desiste depois do limite, sem girar para sempre', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken, falhaAoAbrir: StateError('sem rede'));
        c.servico.conectar();
        async.elapse(const Duration(minutes: 10));

        expect(c.servico.status, OnlineStatus.semConexao);
        expect(c.servico.falhaTerminal, isTrue);
        expect(c.canais.length,
            lessThanOrEqualTo(OnlineService.limiteDeTentativas + 1),
            reason: 'o teto de tentativas tem que valer');
      });
    });

    test('depois de desistir, "tentar de novo" recomeça do zero', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken, falhaAoAbrir: StateError('sem rede'));
        c.servico.conectar();
        async.elapse(const Duration(minutes: 10));
        expect(c.servico.status, OnlineStatus.semConexao);
        final ateAqui = c.canais.length;

        c.pararDeFalharAoAbrir();
        c.servico.tentarNovamente();
        async.elapse(const Duration(milliseconds: 10));

        expect(c.canais.length, greaterThan(ateAqui));
        expect(c.servico.status, OnlineStatus.autenticando);
        c.servico.desligar();
      });
    });

    test('sair da tela cancela a reconexão agendada', () {
      fakeAsync((async) {
        final c = _Cenario(token: kToken, falhaAoAbrir: StateError('sem rede'));
        c.servico.conectar();
        async.elapse(const Duration(milliseconds: 10));
        final ateAqui = c.canais.length;

        c.servico.desligar();
        async.elapse(const Duration(minutes: 10));

        expect(c.canais.length, ateAqui,
            reason: 'nenhuma tentativa nova depois de desligar');
        expect(c.servico.status, OnlineStatus.desconectado);
      });
    });

    test('logout derruba a conexão e apaga o que era da conta anterior',
        () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa(codigo: 'MESA-9', assento: 2);
      c.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': false, 'mao': ['c-1']},
      });
      await c.assentar();
      expect(c.servico.visao, isNotNull);

      c.servico.encerrarPorLogout();

      expect(c.servico.status, OnlineStatus.desconectado);
      expect(c.servico.visao, isNull, reason: 'projeção era da conta que saiu');
      expect(c.servico.meuAssento, isNull);
      expect(c.servico.codigo, isNull);
      expect(c.canais.first.fechado, isTrue);
    });

    test('depois do logout, reconectar não reentra na mesa antiga', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa(codigo: 'MESA-9');

      c.servico.encerrarPorLogout();
      c.trocarToken(kTokenNovo);
      await c.conectar();
      await c.servidorAceita();

      expect(c.canais.last.doTipo('entrarMesa'), isEmpty,
          reason: 'a mesa pertencia a quem saiu da conta');
    });
  });

  // =========================================================================
  group('7. uma conexão por contexto — sem socket órfão', () {
    test('conectar várias vezes abre UM socket só', () async {
      final c = _Cenario(token: kToken);
      c.servico.conectar();
      c.servico.conectar();
      c.servico.conectar();
      await c.assentar();
      expect(c.canais, hasLength(1));
    });

    test('comandos em rajada antes de conectar não multiplicam socket',
        () async {
      final c = _Cenario(token: kToken);
      c.servico.criarMesa(apelido: 'Sônia');
      c.servico.iniciarPartida();
      c.servico.comprarMonte();
      await c.assentar();
      expect(c.canais, hasLength(1));
    });

    test('desligar no meio da abertura não deixa socket aberto', () async {
      final c = _Cenario(
        token: kToken,
        demoraDoToken: const Duration(milliseconds: 50),
      );
      c.servico.conectar();
      // desliga ENQUANTO o token ainda está sendo buscado
      c.servico.desligar();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await c.assentar();

      // ou nem abriu, ou abriu e fechou — o que não pode é ficar aberto
      for (final canal in c.canais) {
        expect(canal.fechado, isTrue,
            reason: 'socket órfão sobrevivendo ao desligar');
      }
      expect(c.servico.status, OnlineStatus.desconectado);
    });

    test('dispose (rebuild/rotação) fecha tudo', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      c.servico.dispose();
      expect(c.canais.single.fechado, isTrue);
    });
  });

  // =========================================================================
  group('8. mensagem de sessão antiga é descartada', () {
    test('o socket velho não fala mais depois da reconexão', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();
      final velho = c.canais.first;

      // A tela foi reconstruída (rotação, voltar para a mesa): desliga e
      // reconecta. O socket velho continua VIVO do lado de lá — é justamente
      // esse o caso perigoso, porque ele ainda consegue falar.
      c.servico.desligar();
      await c.conectar();
      expect(c.canais.length, 2);
      await c.servidorAceita();
      await c.sentarNaMesa(codigo: 'MESA-NOVA', assento: 1);

      // agora chega, atrasada, uma mensagem da sessão ANTIGA
      velho.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': false, 'fantasma': true},
      });
      await c.assentar();

      expect(c.servico.visao?['fantasma'], isNull,
          reason: 'projeção de uma sessão que já morreu não pode entrar');
      expect(c.servico.codigo, 'MESA-NOVA');
    });

    test('mensagem antiga não ressuscita conexão desligada', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      final velho = c.canais.first;

      c.servico.desligar();
      velho.servidorEnvia({'tipo': 'autenticado', 'jogadorId': 'uid-da-sonia'});
      velho.servidorDerruba();
      await c.assentar();

      expect(c.servico.status, OnlineStatus.desconectado);
      expect(c.canais, hasLength(1), reason: 'nada reagendou reconexão');
    });

    test('mensagem malformada é ignorada sem derrubar a sessão', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();

      c.canal.servidorEnvia(const {'tipo': 'coisa-que-nao-existe'});
      await c.assentar();

      expect(c.servico.status, OnlineStatus.conectado);
    });
  });

  // =========================================================================
  group('9. só projeção autorizada é exibida', () {
    // O servidor congelado (seguranca/ws-auth-identidade @ 71199e8) só manda
    // `estado` para conexão com assento E credencial válida agora. Não existe
    // papel de espectador: quem não tem assento não recebe projeção nenhuma.
    // O app espelha a mesma regra em vez de inventar uma visão.
    test('sem assento, nenhuma projeção é aceita', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      expect(c.servico.meuAssento, isNull);

      c.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': false, 'mao': ['carta-de-outro']},
      });
      await c.assentar();

      expect(c.servico.visao, isNull,
          reason: 'conexão sem assento não tem projeção autorizada');
    });

    test('com assento, a projeção do servidor é aceita como está', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa(assento: 3);

      c.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': false, 'mao': ['c-1', 'c-2']},
      });
      await c.assentar();

      expect(c.servico.meuAssento, 3);
      expect(c.servico.visao?['mao'], ['c-1', 'c-2']);
    });

    test('sair da mesa apaga a projeção na hora', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();
      c.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': false, 'mao': ['c-1']},
      });
      await c.assentar();
      expect(c.servico.visao, isNotNull);

      c.servico.sair();

      expect(c.servico.visao, isNull);
      expect(c.servico.meuAssento, isNull);
      expect(c.servico.codigo, isNull);
    });

    test('credencial recusada apaga a projeção', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();
      c.canal.servidorEnvia({
        'tipo': 'estado',
        'visao': {'lobby': false, 'mao': ['c-1']},
      });
      await c.assentar();

      c.canal.servidorEnvia({'tipo': 'authFalhou', 'motivo': 'recusada'});
      await c.assentar();

      expect(c.servico.status, OnlineStatus.naoAutenticado);
      expect(c.servico.visao, isNull,
          reason: 'sem credencial válida não há projeção autorizada');
      expect(c.servico.meuAssento, isNull);
    });

    test('visão malformada não vira projeção', () async {
      final c = _Cenario(token: kToken);
      await c.conectar();
      await c.servidorAceita();
      await c.sentarNaMesa();

      c.canal.servidorEnvia({'tipo': 'estado', 'visao': 'isto não é um mapa'});
      await c.assentar();

      expect(c.servico.visao, isNull);
      expect(c.servico.status, OnlineStatus.conectado);
    });
  });
}
