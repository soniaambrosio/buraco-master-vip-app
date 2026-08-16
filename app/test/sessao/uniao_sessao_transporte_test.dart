// uniao_sessao_transporte_test.dart — o CONTRATO CONJUNTO das duas folhas.
//
// A Folha A provou que a sessão é dona da identidade. A Folha B provou que o
// transporte apresenta credencial em vez de declarar identidade. Cada uma
// passava sozinha, e mesmo assim a UNIÃO delas tinha um defeito que nenhuma das
// duas suítes conseguia enxergar: havia DOIS donos de autenticação no app.
//
// O transporte lia `FirebaseAuth.instance` por conta própria. Sem vínculo com a
// geração de sessão, um logout no meio de um `await` de token deixava o token
// do jogador que ACABOU de sair chegar em mãos e virar um `auth` no fio.
//
// Este arquivo é a prova de que isso acabou. Cobre os treze casos que a OS §8
// pede sobre o contrato conjunto; os itens 14 e 15 (as suítes originais de cada
// folha) continuam onde sempre estiveram, intactos, e são executados como
// estão.
//
// TUDO AQUI É CÓDIGO DE PRODUÇÃO SENDO EXERCITADO. A sessão é a
// `SessaoDoJogador` de verdade, a ponte é a `PonteSessaoOnline` de verdade e o
// transporte é o `OnlineService` de verdade. O que é falso são as duas pontas
// do mundo: a fonte de identidade, a fonte de credencial e o canal WebSocket —
// exatamente os pontos de costura que as duas folhas já expunham.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:buraco_master_vip/sessao/credencial_de_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/services/ponte_sessao_online.dart';

// ===========================================================================
// Fakes das duas pontas do mundo
// ===========================================================================

/// Fonte de identidade com o relógio na mão do teste (mesma ideia da Folha A).
class _FonteFalsa implements FonteDeIdentidade {
  final List<Completer<IdentidadePublica>> pendentes = [];
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    final c = Completer<IdentidadePublica>();
    pendentes.add(c);
    return c.future;
  }

  void responder(String publicId) =>
      pendentes.last.complete(_identidade(publicId));

  void falhar(MotivoFalhaIdentidade motivo) =>
      pendentes.last.completeError(FalhaIdentidade(motivo, 'encenado'));
}

IdentidadePublica _identidade(String publicId) => IdentidadePublica(
  publicId: publicId,
  apelido: 'Jogadora',
  avatarRef: null,
  criada: false,
  estado: EstadoPerfil.ativo,
  limites: LimitesSociais.desconhecidos,
  edicao: MetadadosDeEdicao.desconhecidos,
);

/// Provedor de credencial controlado pelo teste.
///
/// [segurar] é o que permite encenar o caso mais importante deste arquivo: o
/// token que está NO AR quando o jogador desloga.
class _CredencialFalsa implements FonteDeCredencial {
  String? token;
  Object? erro;
  int pedidos = 0;
  Completer<String?>? segurar;

  @override
  Future<String?> obterToken() {
    pedidos++;
    if (erro != null) return Future<String?>.error(erro!);
    final presa = segurar;
    if (presa != null) return presa.future;
    return Future<String?>.value(token);
  }
}

/// Canal WebSocket de mentira: guarda o que o app escreveu e deixa o teste
/// empurrar mensagens do "servidor" para dentro do app.
class _CanalFalso extends StreamChannelMixin implements WebSocketChannel {
  final _doServidor = StreamController<dynamic>.broadcast();
  final List<String> enviadas = [];
  bool fechado = false;

  List<Map<String, dynamic>> get mensagens =>
      enviadas.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

  List<Map<String, dynamic>> doTipo(String tipo) =>
      mensagens.where((m) => m['tipo'] == tipo).toList();

  void servidorEnvia(Map<String, dynamic> msg) =>
      _doServidor.add(jsonEncode(msg));

  void servidorDerruba() => _doServidor.close();

  @override
  Future<void> get ready => Future<void>.value();
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
  Future<void> get done => Future<void>.value();
}

// ===========================================================================
// O ambiente: sessão real + ponte real + transporte real
// ===========================================================================

class _Ambiente {
  _Ambiente() {
    sessao = SessaoDoJogador(
      fonte: fonte,
      uids: auth.stream,
      credenciais: credenciais,
    );
    online = criarOnlineServiceDaSessao(
      sessao,
      abrirCanal: (url) {
        urls.add(url);
        final c = _CanalFalso();
        canais.add(c);
        return c;
      },
    );
    ponte = PonteSessaoOnline(sessao: sessao, online: online);
  }

  final auth = StreamController<String?>.broadcast();
  final fonte = _FonteFalsa();
  final credenciais = _CredencialFalsa();
  final List<_CanalFalso> canais = [];
  final List<Uri> urls = [];

  late final SessaoDoJogador sessao;
  late final OnlineService online;
  late final PonteSessaoOnline ponte;

  _CanalFalso get canal => canais.last;

  void fechar() {
    ponte.dispose();
    online.dispose();
    sessao.dispose();
    auth.close();
  }
}

/// Deixa microtasks e eventos de stream assentarem, sem relógio falso.
Future<void> _assentar() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  const kTokenA = 'eyJhbGciOiJSUzI1NiJ9.PAYLOAD-DA-A.ASSINATURA-A';
  const kTokenB = 'eyJhbGciOiJSUzI1NiJ9.PAYLOAD-DO-B.ASSINATURA-B';

  late _Ambiente amb;

  setUp(() => amb = _Ambiente());
  tearDown(() => amb.fechar());

  /// Login + credencial disponível + conexão aceita pelo servidor.
  Future<void> logarEConectar({
    String uid = 'uid-a',
    String token = kTokenA,
  }) async {
    amb.credenciais.token = token;
    amb.auth.add(uid);
    await _assentar();
    amb.online.conectar();
    await _assentar();
    amb.canal.servidorEnvia({'tipo': 'autenticado'});
    await _assentar();
  }

  // =========================================================================
  // §8.1 e §8.2 — a sessão inicializa uma vez, e concorrência não duplica
  // =========================================================================
  group('§8.1/§8.2 — inicialização única e deduplicada', () {
    test('um login produz UMA chamada de identidade', () async {
      amb.auth.add('uid-a');
      await _assentar();

      expect(amb.sessao.chamadasEmitidas, 1);
      expect(amb.fonte.chamadas, 1);
    });

    test('dois pedidos concorrentes compartilham a MESMA inicialização', () async {
      amb.auth.add('uid-a');
      await _assentar();

      // A sessão já disparou sozinha; dois interessados pedindo ao mesmo tempo
      // pegam carona no voo que já existe, em vez de abrirem dois.
      final a = amb.sessao.garantirCarregada();
      final b = amb.sessao.garantirCarregada();
      await _assentar();

      expect(amb.sessao.chamadasEmitidas, 1);
      amb.fonte.responder('BMV-1');
      await Future.wait([a, b]);
      expect(amb.sessao.publicId, 'BMV-1');
      expect(amb.fonte.chamadas, 1);
    });

    test('o transporte não tem cache próprio: pede à sessão a cada conexão', () async {
      await logarEConectar();
      expect(amb.credenciais.pedidos, 1);

      amb.online.desligar();
      amb.online.conectar();
      await _assentar();

      expect(amb.credenciais.pedidos, 2, reason: 'credencial nova, não guardada');
    });
  });

  // =========================================================================
  // §8.3 e §8.4 — a credencial vem da sessão, e só dela
  // =========================================================================
  group('§8.3/§8.4 — sessão é a única fonte de credencial', () {
    test('sessão válida fornece a credencial que sai no handshake', () async {
      await logarEConectar();

      expect(amb.canais, hasLength(1));
      expect(amb.credenciais.pedidos, 1);
      expect(amb.canal.mensagens.first['tipo'], 'auth');
      expect(amb.canal.mensagens.first['token'], kTokenA);
      expect(amb.online.status, OnlineStatus.conectado);
    });

    test('sessão AUSENTE não abre socket autenticado', () async {
      // Ninguém logado: a sessão não tem de quem emitir credencial.
      amb.credenciais.token = kTokenA; // o provedor até tem token…
      amb.online.conectar();
      await _assentar();

      expect(amb.canais, isEmpty, reason: 'sem sessão não se abre conexão');
      expect(amb.online.status, OnlineStatus.naoAutenticado);
      expect(
        amb.credenciais.pedidos,
        0,
        reason: 'a sessão barra antes de chegar ao provedor',
      );
    });

    test('logout deixa a sessão sem credencial para dar', () async {
      await logarEConectar();
      amb.auth.add(null);
      await _assentar();

      expect(await amb.sessao.obterCredencial(), isNull);
    });

    test('o transporte não conhece firebase_auth', () {
      // Trava estrutural: é o import que criava o segundo dono de autenticação.
      //
      // Lê o CÓDIGO, sem comentários: o cabeçalho do arquivo explica, em prosa,
      // justamente por que `FirebaseAuth.instance` não pode ser lido ali, e uma
      // varredura ingênua acusaria a explicação como violação — deixando o
      // "conserto" ser apagar a documentação. Mesma decisão da auditoria da
      // Folha A.
      final fonte = _semComentarios(
        File('lib/services/online_service.dart').readAsStringSync(),
      );
      expect(
        fonte,
        isNot(contains("import 'package:firebase_auth")),
        reason: 'a credencial entra por ObterIdToken, vinda da sessão',
      );
      expect(fonte, isNot(contains('FirebaseAuth.instance')));
    });
  });

  // =========================================================================
  // §8.5 — credencial vencida com a conexão de pé
  // =========================================================================
  group('§8.5 — renovação e recusa de credencial', () {
    test('authExpirou pega credencial NOVA na sessão, no mesmo socket', () async {
      await logarEConectar();

      amb.credenciais.token = '$kTokenA.renovado';
      amb.canal.servidorEnvia({'tipo': 'authExpirou'});
      await _assentar();

      expect(amb.credenciais.pedidos, 2);
      expect(amb.canais, hasLength(1), reason: 'renovar não abre outro socket');
      final auths = amb.canal.doTipo('auth');
      expect(auths, hasLength(2));
      expect(auths.last['token'], '$kTokenA.renovado');
      expect(amb.online.status, OnlineStatus.autenticando);
    });

    test('credencial recusada pelo servidor é falha terminal', () async {
      await logarEConectar();
      amb.canal.servidorEnvia({'tipo': 'authFalhou'});
      await _assentar();

      expect(amb.online.status, OnlineStatus.naoAutenticado);
      expect(amb.canal.fechado, isTrue);
      expect(
        amb.sessao.estado.autenticado,
        isTrue,
        reason: 'falha de transporte NÃO derruba a sessão do jogador',
      );
    });
  });

  // =========================================================================
  // §8.6 — o caso que só existia na união: logout no meio do await
  // =========================================================================
  group('§8.6 — logout durante conexão ou renovação', () {
    test('logout enquanto o token está NO AR não abre socket nenhum', () async {
      amb.credenciais.token = kTokenA;
      amb.auth.add('uid-a');
      await _assentar();

      // A credencial fica presa no ar…
      final preso = Completer<String?>();
      amb.credenciais.segurar = preso;
      amb.online.conectar();
      await _assentar();
      expect(amb.credenciais.pedidos, 1);
      expect(amb.canais, isEmpty, reason: 'ainda esperando o token');

      // …e o jogador desloga antes de ela voltar.
      amb.auth.add(null);
      await _assentar();

      // O token de A chega ATRASADO. É o momento exato do defeito.
      preso.complete(kTokenA);
      await _assentar();

      expect(
        amb.canais,
        isEmpty,
        reason: 'o token do jogador que saiu não pode virar conexão',
      );
      expect(amb.online.status, isNot(OnlineStatus.conectado));
    });

    test('logout enquanto renova descarta o token atrasado', () async {
      await logarEConectar();

      final preso = Completer<String?>();
      amb.credenciais.segurar = preso;
      amb.canal.servidorEnvia({'tipo': 'authExpirou'});
      await _assentar();
      expect(amb.online.status, OnlineStatus.autenticando);

      amb.auth.add(null); // logout no meio da renovação
      await _assentar();

      preso.complete(kTokenA); // resposta atrasada da sessão anterior
      await _assentar();

      expect(
        amb.canal.doTipo('auth'),
        hasLength(1),
        reason: 'a segunda credencial não podia ter saído',
      );
      expect(amb.canal.fechado, isTrue);
    });

    test('a sessão devolve null para o token que chega depois do logout', () async {
      amb.auth.add('uid-a');
      await _assentar();

      final preso = Completer<String?>();
      amb.credenciais.segurar = preso;
      final pedido = amb.sessao.obterCredencial();

      amb.auth.add(null);
      await _assentar();
      preso.complete(kTokenA);

      expect(await pedido, isNull);
    });
  });

  // =========================================================================
  // §8.7 — logout fecha socket e cancela reconexão
  // =========================================================================
  group('§8.7 — logout encerra o transporte', () {
    test('logout fecha o socket e não reconecta sozinho', () {
      fakeAsync((async) {
        final a = _Ambiente();
        a.credenciais.token = kTokenA;
        a.auth.add('uid-a');
        async.elapse(const Duration(milliseconds: 1));
        a.online.conectar();
        async.elapse(const Duration(milliseconds: 1));
        a.canal.servidorEnvia({'tipo': 'autenticado'});
        async.elapse(const Duration(milliseconds: 1));
        expect(a.online.status, OnlineStatus.conectado);

        a.auth.add(null); // logout
        async.elapse(const Duration(milliseconds: 1));

        expect(a.canal.fechado, isTrue);
        expect(a.online.status, OnlineStatus.desconectado);
        expect(a.online.querConectado, isFalse);

        // muito além do maior backoff (12s)
        async.elapse(const Duration(seconds: 40));
        expect(
          a.canais,
          hasLength(1),
          reason: 'logout cancela a reconexão, não a adia',
        );

        a.fechar();
        async.elapse(const Duration(milliseconds: 1));
      });
    });

    test('logout limpa o estado privado da mesa', () {
      fakeAsync((async) {
        final a = _Ambiente();
        a.credenciais.token = kTokenA;
        a.auth.add('uid-a');
        async.elapse(const Duration(milliseconds: 1));
        a.online.conectar();
        async.elapse(const Duration(milliseconds: 1));
        a.canal.servidorEnvia({'tipo': 'autenticado'});
        a.canal.servidorEnvia({
          'tipo': 'entrou',
          'codigo': 'MESA-DA-A',
          'assento': 2,
        });
        async.elapse(const Duration(milliseconds: 1));
        expect(a.online.codigo, 'MESA-DA-A');

        a.auth.add(null);
        async.elapse(const Duration(milliseconds: 1));

        expect(a.online.codigo, isNull);
        expect(a.online.meuAssento, isNull);
        expect(a.online.visao, isNull);

        a.fechar();
        async.elapse(const Duration(milliseconds: 1));
      });
    });
  });

  // =========================================================================
  // §8.8 — troca de usuário
  // =========================================================================
  group('§8.8 — troca de usuário não reaproveita nada', () {
    test('a conexão de B usa o token de B, e nunca o de A', () {
      fakeAsync((async) {
        final a = _Ambiente();
        a.credenciais.token = kTokenA;
        a.auth.add('uid-a');
        async.elapse(const Duration(milliseconds: 1));
        a.online.conectar();
        async.elapse(const Duration(milliseconds: 1));
        a.canal.servidorEnvia({'tipo': 'autenticado'});
        async.elapse(const Duration(milliseconds: 1));
        expect(a.canal.doTipo('auth').single['token'], kTokenA);

        // Troca de conta.
        a.credenciais.token = kTokenB;
        a.auth.add('uid-b');
        async.elapse(const Duration(milliseconds: 1));

        expect(a.canais, hasLength(2), reason: 'socket novo para a conta nova');
        expect(a.canais.first.fechado, isTrue);
        final authDeB = a.canal.doTipo('auth').single;
        expect(authDeB['token'], kTokenB);
        expect(a.canal.enviadas.join(), isNot(contains(kTokenA)));

        a.fechar();
        async.elapse(const Duration(milliseconds: 1));
      });
    });

    test('B não volta para a mesa que era de A', () {
      fakeAsync((async) {
        final a = _Ambiente();
        a.credenciais.token = kTokenA;
        a.auth.add('uid-a');
        async.elapse(const Duration(milliseconds: 1));
        a.online.conectar();
        async.elapse(const Duration(milliseconds: 1));
        a.canal.servidorEnvia({'tipo': 'autenticado'});
        a.canal.servidorEnvia({
          'tipo': 'entrou',
          'codigo': 'MESA-DA-A',
          'assento': 0,
        });
        async.elapse(const Duration(milliseconds: 1));

        a.credenciais.token = kTokenB;
        a.auth.add('uid-b');
        async.elapse(const Duration(milliseconds: 1));
        a.canal.servidorEnvia({'tipo': 'autenticado'});
        async.elapse(const Duration(milliseconds: 1));

        expect(
          a.canal.doTipo('entrarMesa'),
          isEmpty,
          reason: 'o código da mesa de A morreu junto com a sessão de A',
        );
        expect(a.canal.enviadas.join(), isNot(contains('MESA-DA-A')));

        a.fechar();
        async.elapse(const Duration(milliseconds: 1));
      });
    });

    test('a identidade pública de A não sobrevive à entrada de B', () async {
      amb.auth.add('uid-a');
      await _assentar();
      amb.fonte.responder('BMV-AAAA');
      await _assentar();
      expect(amb.sessao.publicId, 'BMV-AAAA');

      amb.auth.add('uid-b');
      await _assentar();

      expect(amb.sessao.publicId, isNull);
      expect(amb.sessao.estado.uid, 'uid-b');
    });

    test('uma troca de conta propaga UMA transição ao transporte', () async {
      await logarEConectar();
      final antes = amb.ponte.transicoesPropagadas;

      amb.credenciais.token = kTokenB;
      amb.auth.add('uid-b');
      await _assentar();
      // e a identidade de B ainda avança de fase depois disso
      amb.fonte.responder('BMV-BBBB');
      await _assentar();

      expect(amb.ponte.transicoesPropagadas - antes, 1);
    });
  });

  // =========================================================================
  // §8.9 e §8.10 — o handshake
  // =========================================================================
  group('§8.9/§8.10 — protocolo e ausência de identidade autodeclarada', () {
    test('o app fala protocolo 2, e nunca 1', () async {
      await logarEConectar();

      expect(OnlineService.protocolo, 2);
      expect(amb.canal.mensagens.first['protocolo'], 2);
      expect(
        amb.canal.mensagens.first['protocolo'],
        isNot(1),
        reason: 'o protocolo 1 é o que declarava identidade pelo cliente',
      );
    });

    test('servidor que só fala protocolo 1 é recusado, sem fallback', () async {
      amb.credenciais.token = kTokenA;
      amb.auth.add('uid-a');
      await _assentar();
      amb.online.conectar();
      await _assentar();

      // resposta de um servidor que não conhece o tipo `auth`
      amb.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'tipo desconhecido: auth',
      });
      await _assentar();

      expect(amb.online.status, OnlineStatus.servidorDesatualizado);
      amb.online.criarMesa(apelido: 'Sônia');
      await _assentar();
      expect(amb.canais, hasLength(1));
      expect(amb.canal.doTipo('criarMesa'), isEmpty);
    });

    test('nenhuma mensagem carrega uid, publicId ou id autodeclarado', () async {
      await logarEConectar();
      amb.fonte.responder('BMV-AAAA');
      await _assentar();

      amb.online.criarMesa(apelido: 'Sônia');
      amb.online.entrarMesa(codigo: 'MESA-1', apelido: 'Sônia');
      amb.online.iniciarPartida();
      amb.online.comprarMonte();
      amb.online.sair();
      await _assentar();

      const proibidos = [
        'jogadorId',
        'uid',
        'playerId',
        'usuarioId',
        'ownerId',
        'publicId',
      ];
      for (final m in amb.canal.mensagens) {
        for (final campo in proibidos) {
          expect(
            m.containsKey(campo),
            isFalse,
            reason: '${m['tipo']} não pode declarar "$campo"',
          );
        }
      }
      // e os VALORES da identidade também não vazam disfarçados
      final tudo = amb.canal.enviadas.join();
      expect(tudo, isNot(contains('uid-a')));
      expect(tudo, isNot(contains('BMV-AAAA')));
    });
  });

  // =========================================================================
  // §8.11 — rebuild e rotação
  // =========================================================================
  group('§8.11 — rebuild não duplica sessão, listener nem socket', () {
    test('a fase da identidade avançando não mexe no transporte', () async {
      await logarEConectar();
      final transicoes = amb.ponte.transicoesPropagadas;

      // A identidade percorre carregando → disponível, e depois um retry
      // explícito percorre de novo. São várias notificações da sessão.
      amb.fonte.responder('BMV-AAAA');
      await _assentar();
      // O retry é disparado e SÓ ENTÃO respondido: esperar por ele antes de a
      // fonte falsa responder travaria o teste, porque quem resolve o Completer
      // é a linha de baixo.
      final retry = amb.sessao.recarregar();
      await _assentar();
      amb.fonte.responder('BMV-AAAA');
      await retry;
      await _assentar();

      expect(amb.canais, hasLength(1), reason: 'nenhum socket a mais');
      expect(amb.online.status, OnlineStatus.conectado);
      expect(
        amb.ponte.transicoesPropagadas,
        transicoes,
        reason: 'mudou a fase, não a sessão',
      );
    });

    test('o mesmo uid reemitido não é troca de sessão', () async {
      await logarEConectar();
      final transicoes = amb.ponte.transicoesPropagadas;
      final chamadas = amb.sessao.chamadasEmitidas;

      // O fluxo de autenticação repete o uid a cada renovação de token.
      amb.auth.add('uid-a');
      amb.auth.add('uid-a');
      await _assentar();

      expect(amb.ponte.transicoesPropagadas, transicoes);
      expect(amb.sessao.chamadasEmitidas, chamadas);
      expect(amb.canais, hasLength(1));
      expect(amb.online.status, OnlineStatus.conectado);
    });

    test('conectar repetido não abre sockets paralelos', () async {
      await logarEConectar();

      amb.online.conectar();
      amb.online.conectar();
      amb.online.conectar();
      await _assentar();

      expect(amb.canais, hasLength(1));
    });
  });

  // =========================================================================
  // §8.12 — falha transitória e falha permanente são estados distintos
  // =========================================================================
  group('§8.12 — transitória e permanente não se confundem', () {
    test('identidade: indisponível oferece retry, recusado não', () async {
      amb.auth.add('uid-a');
      await _assentar();
      amb.fonte.falhar(MotivoFalhaIdentidade.indisponivel);
      await _assentar();

      expect(amb.sessao.estado.fase, FaseIdentidade.falha);
      expect(amb.sessao.estado.podeTentarDeNovo, isTrue);

      final retry = amb.sessao.recarregar();
      await _assentar();
      amb.fonte.falhar(MotivoFalhaIdentidade.recusado);
      await retry;
      await _assentar();

      expect(amb.sessao.estado.fase, FaseIdentidade.falha);
      expect(amb.sessao.estado.podeTentarDeNovo, isFalse);
    });

    test('transporte: falha de rede reconecta, credencial recusada não', () {
      fakeAsync((async) {
        final a = _Ambiente();
        a.credenciais.token = kTokenA;
        a.auth.add('uid-a');
        async.elapse(const Duration(milliseconds: 1));
        a.online.conectar();
        async.elapse(const Duration(milliseconds: 1));
        a.canal.servidorEnvia({'tipo': 'autenticado'});
        async.elapse(const Duration(milliseconds: 1));

        // TRANSITÓRIA: a conexão cai sozinha.
        a.canal.servidorDerruba();
        async.elapse(const Duration(seconds: 5));
        expect(a.canais, hasLength(2), reason: 'queda de rede reconecta');
        expect(a.online.status, OnlineStatus.autenticando);

        // PERMANENTE: o servidor recusa a credencial.
        a.canal.servidorEnvia({'tipo': 'authFalhou'});
        async.elapse(const Duration(seconds: 40));
        expect(a.online.status, OnlineStatus.naoAutenticado);
        expect(a.canais, hasLength(2), reason: 'recusa não reconecta');

        a.fechar();
        async.elapse(const Duration(milliseconds: 1));
      });
    });

    test('falha de transporte não invalida a sessão do jogador', () async {
      await logarEConectar();
      amb.fonte.responder('BMV-AAAA');
      await _assentar();

      amb.canal.servidorEnvia({'tipo': 'authFalhou'});
      await _assentar();

      expect(amb.online.status, OnlineStatus.naoAutenticado);
      expect(amb.sessao.estado.uid, 'uid-a');
      expect(amb.sessao.publicId, 'BMV-AAAA');
    });
  });

  // =========================================================================
  // §8.13 — redaction adversarial
  // =========================================================================
  group('§8.13 — nada sensível vaza pelas superfícies expostas', () {
    test('token, uid, publicId e segredos não aparecem no estado exposto', () async {
      await logarEConectar();
      amb.fonte.responder('BMV-AAAA');
      await _assentar();

      // superfícies adversariais: erro do servidor, visão, toString de tudo
      amb.canal.servidorEnvia({
        'tipo': 'erro',
        'motivo': 'você não está numa mesa',
      });
      await _assentar();

      final expostos = <String>[
        amb.online.erro ?? '',
        amb.online.status.toString(),
        amb.online.codigo ?? '',
        amb.online.visao?.toString() ?? '',
        amb.online.toString(),
        amb.sessao.toString(),
        amb.sessao.estado.toString(),
        amb.sessao.estado.falha?.toString() ?? '',
      ];

      for (final s in expostos) {
        expect(s, isNot(contains(kTokenA)));
        expect(s, isNot(contains('ASSINATURA-A')));
      }
    });

    test('a falha de identidade não carrega token nem segredo no detalhe', () async {
      amb.auth.add('uid-a');
      await _assentar();
      amb.fonte.falhar(MotivoFalhaIdentidade.naoAutenticado);
      await _assentar();

      final texto = amb.sessao.estado.falha.toString();
      expect(texto, isNot(contains(kTokenA)));
      expect(texto, isNot(contains('ASSINATURA')));
    });

    test('o token sai UMA vez, e só dentro da mensagem auth', () async {
      await logarEConectar();
      amb.online.criarMesa(apelido: 'Sônia');
      amb.online.comprarMonte();
      await _assentar();

      final comToken = amb.canal.enviadas.where((s) => s.contains(kTokenA));
      expect(comToken, hasLength(1));
      expect(jsonDecode(comToken.single)['tipo'], 'auth');
    });

    test('a credencial não vai na URL nem em query string', () async {
      await logarEConectar();

      final url = amb.urls.single;
      expect(url.toString(), OnlineService.servidorUrl);
      expect(url.toString(), isNot(contains(kTokenA)));
      expect(url.queryParameters, isEmpty);
    });

    test('nenhuma fonte do cliente escreve credencial em log', () {
      // Trava estrutural adversarial: `print`/`debugPrint` na camada de sessão
      // ou de transporte é o caminho mais curto para um token em logcat.
      for (final caminho in const [
        'lib/services/online_service.dart',
        'lib/services/ponte_sessao_online.dart',
        'lib/sessao/sessao_do_jogador.dart',
        'lib/sessao/credencial_de_sessao.dart',
        'lib/sessao/sessao_firebase.dart',
      ]) {
        final fonte = _semComentarios(File(caminho).readAsStringSync());
        expect(
          fonte,
          isNot(contains('print(')),
          reason: '$caminho não pode registrar nada em log',
        );
        expect(fonte, isNot(contains('debugPrint')), reason: caminho);
      }
    });
  });
}

/// Remove comentários para que a auditoria estrutural leia CÓDIGO.
///
/// Sem isto, a própria prosa que explica por que não se pode logar credencial
/// seria acusada como violação — e o jeito de "consertar" seria apagar a
/// explicação. Mesma decisão da auditoria da Folha A.
String _semComentarios(String fonte) => fonte
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');
