// homologacao_casca_v2_test.dart — os casos da matriz de homologação que a
// suíte da entrega não cobria.
//
// ---------------------------------------------------------------------------
// POR QUE UM ARQUIVO SEPARADO
// ---------------------------------------------------------------------------
//
// `casca_producao_test.dart` prova o que a entrega se propôs a fazer. Este prova
// o que a homologação foi conferir, e a diferença entre as duas listas é o valor
// de auditar: são os casos em que o comportamento certo depende de detalhes que
// ninguém escreveu de propósito, e que uma refatoração distraída desfaz sem
// quebrar nada visível.
//
// Sete perguntas, e nenhuma delas tinha resposta escrita antes:
//
//   * o botão VOLTAR do aparelho recupera a tela privada depois do logout?
//   * a troca de conta sem logout herda a navegação da conta anterior?
//   * abrir o lobby marca um ancestral como sujo no meio do `build`?
//   * o logout cancela uma RECONEXÃO já agendada, e não só um socket de pé?
//   * o logout no meio da autenticação fecha o socket que estava abrindo?
//   * um servidor que exige atualização para de tentar, ou fica em laço?
//   * descartar a raiz solta o ouvinte da ponte, ou ele continua mandando no
//     transporte de um aplicativo que já não existe?
//
// A bancada é a mesma da suíte irmã, e de propósito: o que está sendo exercitado
// é a `RaizDoAplicativo` de verdade, com a `SessaoDoJogador`, a
// `PonteSessaoOnline` e o `OnlineService` de verdade. Falsas são só as pontas do
// mundo — fluxo de autenticação, fonte de identidade, provedor de credencial e
// canal WebSocket.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:buraco_master_vip/casca/configuracoes_de_producao.dart';
import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/onde_jogar_de_producao.dart';
import 'package:buraco_master_vip/casca/raiz_do_aplicativo.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/services/ponte_sessao_online.dart';
import 'package:buraco_master_vip/sessao/comandos_de_autenticacao.dart';
import 'package:buraco_master_vip/sessao/credencial_de_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Pontas do mundo
// ===========================================================================

class _FonteFalsa implements FonteDeIdentidade {
  String apelido = 'Ana';
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    return Future<IdentidadePublica>.value(
      IdentidadePublica(
        publicId: 'P0A1B2C3D4E5',
        apelido: apelido,
        avatarRef: null,
        criada: false,
        estado: EstadoPerfil.ativo,
        limites: LimitesSociais.desconhecidos,
        edicao: MetadadosDeEdicao.desconhecidos,
      ),
    );
  }
}

class _CredencialFalsa implements FonteDeCredencial {
  String? token = 'token-de-teste';

  @override
  Future<String?> obterToken() async => token;
}

class _AutenticacaoFalsa implements ComandosDeAutenticacao {
  _AutenticacaoFalsa(this._fluxo);

  final StreamController<String?> _fluxo;
  int saidas = 0;

  @override
  List<ProvedorDeLogin> get provedoresDisponiveis =>
      const [ProvedorDeLogin.google];

  @override
  Future<ResultadoDeLogin> entrar(ProvedorDeLogin provedor) async {
    _fluxo.add('uid-A');
    return const ResultadoDeLogin.entrou();
  }

  @override
  Future<void> sair() async {
    saidas++;
    _fluxo.add(null);
  }
  @override
  /// O dublê não reautentica: nenhum teste desta casca exerce exclusão de
  /// conta, e devolver `false` é o que impede um caminho de exclusão de
  /// seguir por engano dentro de um teste que não pediu isso.
  Future<bool> reautenticar() async => false;
}

class _CanalFalso extends StreamChannelMixin implements WebSocketChannel {
  final _doServidor = StreamController<dynamic>.broadcast();
  final List<String> enviadas = [];
  bool fechado = false;

  void servidorEnvia(Map<String, dynamic> msg) =>
      _doServidor.add(jsonEncode(msg));

  /// O servidor derruba a conexão. É o que arma a reconexão automática.
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

const String kEndpointDeTeste = 'wss://servidor-de-teste.invalido';

// ===========================================================================
// A bancada
// ===========================================================================

class _Bancada {
  _Bancada({String? uidInicial}) {
    sessao = SessaoDoJogador(
      fonte: fonte,
      uids: fluxo.stream,
      uidInicial: uidInicial,
      credenciais: credenciais,
    );
    online = criarOnlineServiceDaSessao(
      sessao,
      endpoint: Uri.parse(kEndpointDeTeste),
      abrirCanal: (_) {
        aberturas++;
        final c = _CanalFalso();
        canais.add(c);
        return c;
      },
    );
    autenticacao = _AutenticacaoFalsa(fluxo);
  }

  final fluxo = StreamController<String?>.broadcast();
  final fonte = _FonteFalsa();
  final credenciais = _CredencialFalsa();
  final List<_CanalFalso> canais = [];

  /// Quantas vezes o transporte tentou ABRIR um canal. É o número que responde
  /// "conectou duas vezes?" e "reconectou depois do logout?".
  int aberturas = 0;

  late final SessaoDoJogador sessao;
  late final OnlineService online;
  late final _AutenticacaoFalsa autenticacao;

  _CanalFalso get canal => canais.last;

  Widget get aplicativo => RaizDoAplicativo(
    sessao: sessao,
    autenticacao: autenticacao,
    online: online,
    duracaoDaSplash: const Duration(milliseconds: 20),
    somNaSplash: false,
    limiteDeResolucao: const Duration(seconds: 8),
  );

  void fechar() {
    online.dispose();
    sessao.dispose();
    fluxo.close();
  }

  /// Silencia o transporte DENTRO do corpo do teste.
  ///
  /// Ver a mesma nota em `test/casca/bancada_online.dart`: desde a OS 38.2
  /// toda tela autenticada tem transporte vivo, e o `flutter_test` confere
  /// temporizadores pendentes AO FIM DO CORPO, antes dos `addTearDown`.
  void aquietar() => online.desligar();
}

Future<void> _abrirAplicativo(WidgetTester tester, _Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
}

Future<void> _passarAAbertura(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

/// Home → Jogar → Mesa por código. O caminho real até o transporte.
Future<void> _irAoLobby(WidgetTester tester) async {
  await tester.tap(find.text('Jogar').first);
  await tester.pumpAndSettle();
  expect(find.byType(OndeJogarDeProducao), findsOneWidget);
  await tester.tap(find.text('Mesa por código'));
  await tester.pumpAndSettle();
  expect(find.byType(LobbyOnline), findsOneWidget);
}

/// Home → Ajustes. É a rota privada empilhada que a matriz de navegação pede.
Future<void> _empilharAjustes(WidgetTester tester) async {
  await tester.tap(find.text('Ajustes'));
  await tester.pumpAndSettle();
  expect(find.byType(ConfiguracoesDeProducao), findsOneWidget);
}

void main() {
  // =========================================================================
  // §4.3 — navegação e isolamento
  // =========================================================================
  group('navegação não sobrevive à troca de sessão', () {
    testWidgets('o botão voltar não recupera a rota privada depois do logout', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _empilharAjustes(tester);

      await b.autenticacao.sair();
      await tester.pumpAndSettle();
      expect(find.byType(LoginDeProducao), findsOneWidget);

      // A PROVA: não basta a tela privada ter saído da vista — a pilha inteira
      // precisa ter morrido. Se a rota de Ajustes ainda estivesse lá embaixo (ou
      // em cima), o navegador teria para onde voltar.
      final navegador = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      expect(
        navegador.canPop(),
        isFalse,
        reason: 'uma pilha com rota de outra sessão é uma pilha que volta',
      );

      // E o botão do aparelho, que é o caminho por onde isso apareceria de
      // verdade, não muda nada.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.byType(ConfiguracoesDeProducao), findsNothing);
      expect(find.byType(HomeDeProducao), findsNothing);
      b.aquietar();
    });

    testWidgets('a troca de conta não herda a navegação da conta anterior', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _empilharAjustes(tester);

      // B entra sem passar por logout. É o caso que o `popUntil` de uma tela de
      // saída jamais cobriria: ninguém saiu, então ninguém navegaria.
      b.fonte.apelido = 'Bruno';
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(
        find.byType(ConfiguracoesDeProducao),
        findsNothing,
        reason: 'a rota privada de A não é rota de B',
      );
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.text('Bruno'), findsOneWidget);

      final navegador = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      expect(navegador.canPop(), isFalse);
      b.aquietar();
    });

    testWidgets('é a GERAÇÃO que derruba a pilha, e não a troca de tela', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _empilharAjustes(tester);

      final geracaoAntes = b.sessao.geracao;

      // A troca A→B mantém a MESMA tela de baixo: Home antes, Home depois. Se a
      // invalidação dependesse da troca de `home`, nada aconteceria aqui — e a
      // rota de Ajustes de A continuaria empilhada sobre a Home de B.
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(b.sessao.geracao, greaterThan(geracaoAntes));
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(ConfiguracoesDeProducao), findsNothing);
      b.aquietar();
    });
  });

  // =========================================================================
  // §4.1 — nenhuma tela privada antes de a sessão se pronunciar
  // =========================================================================
  testWidgets('a Home não pisca em quadro nenhum antes da sessão responder', (
    tester,
  ) async {
    final b = _Bancada();
    addTearDown(b.fechar);

    await _abrirAplicativo(tester, b);

    // Trinta quadros com o fluxo de autenticação calado. O `autenticado` é falso
    // em todos eles — e falso significa as duas coisas: "não há ninguém" e
    // "ainda não sabemos". Uma casca que não distinguisse mostraria o Login aqui.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(HomeDeProducao), findsNothing);
      expect(
        find.byType(LoginDeProducao),
        findsNothing,
        reason: 'quadro $i: a tela pública também é uma resposta, e ainda não '
            'houve resposta',
      );
    }

    b.fluxo.add('uid-A');
    await tester.pumpAndSettle();
    expect(find.byType(HomeDeProducao), findsOneWidget);
      b.aquietar();
    });

  // =========================================================================
  // §4.4 — transporte
  // =========================================================================
  group('transporte', () {
    testWidgets('abrir o lobby não notifica ancestral durante o build', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      // `conectar()` muda o status e notifica, e quem ouve é o `EscopoTransporte`
      // — um ANCESTRAL desta tela. Chamado de dentro de `didChangeDependencies`,
      // isso é "setState() ou markNeedsBuild() chamado durante o build", e o
      // framework acusa. Por isso o pedido sai num `addPostFrameCallback`.
      await tester.tap(find.text('Jogar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mesa por código'));
      await tester.pump(); // o quadro em que o lobby monta

      expect(
        tester.takeException(),
        isNull,
        reason: 'montar a tela do lobby não pode sujar um ancestral',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(b.aberturas, 1);

      // Fecha a autenticação para o limite de espera não ficar pendurado além
      // do teste. Deixá-lo armado seria ruído de bancada: em produção quem o
      // cancela é o `dispose` do transporte, que a raiz faz por ter sido ela a
      // construí-lo — e aqui o transporte foi injetado.
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      b.aquietar();
    });

    testWidgets('sair e voltar ao lobby não abre um segundo socket', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _irAoLobby(tester);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.aberturas, 1);

      // Sair da tela do lobby NÃO é sair do jogo online: o transporte é da raiz
      // e continua de pé. Voltar dispara outro `conectar()` — e ele precisa ser
      // inerte, porque já estamos conectados.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mesa por código'));
      await tester.pumpAndSettle();

      expect(
        b.aberturas,
        1,
        reason: 'um transporte por aplicativo, não um por visita à tela',
      );
      expect(b.canais, hasLength(1));
      expect(b.online.status, OnlineStatus.conectado);
      b.aquietar();
    });

    testWidgets('o logout cancela uma reconexão JÁ AGENDADA', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _irAoLobby(tester);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.online.status, OnlineStatus.conectado);

      // O servidor cai. O ciclo automático agenda a volta — e é ESSE timer,
      // pendurado no futuro, que o logout precisa cancelar. Um logout que só
      // fechasse o socket de pé deixaria a reconexão acordar depois, pedir
      // credencial e abrir socket para uma sessão que já acabou.
      b.canal.servidorDerruba();
      await tester.pump();
      expect(b.online.querConectado, isTrue, reason: 'a volta está agendada');

      await b.autenticacao.sair();
      await tester.pumpAndSettle();

      // Tempo de sobra para o backoff inteiro da primeira tentativa acordar.
      await tester.pump(const Duration(seconds: 3));

      expect(
        b.aberturas,
        1,
        reason: 'nenhum socket novo depois de a sessão acabar',
      );
      expect(b.online.querConectado, isFalse);
      expect(b.online.status, OnlineStatus.desconectado);
      expect(find.byType(LoginDeProducao), findsOneWidget);
      b.aquietar();
    });

    testWidgets('o logout no meio da autenticação fecha o socket em aberto', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _irAoLobby(tester);

      // O socket abriu, a credencial foi apresentada e o servidor ainda não
      // respondeu. É a janela em que o app tem conexão de pé sem sessão
      // reconhecida — e é onde um logout costuma deixar socket órfão.
      expect(b.online.status, OnlineStatus.autenticando);
      final canalEmAberto = b.canal;

      await b.autenticacao.sair();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      expect(canalEmAberto.fechado, isTrue);
      expect(b.aberturas, 1);
      expect(b.online.status, OnlineStatus.desconectado);
      expect(find.byType(LoginDeProducao), findsOneWidget);
      b.aquietar();
    });

    testWidgets('protocolo incompatível é terminal — não vira laço', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _irAoLobby(tester);

      b.canal.servidorEnvia({
        'tipo': 'atualizacaoObrigatoria',
        'motivo': 'atualize o aplicativo para continuar jogando online',
      });
      await tester.pumpAndSettle();
      // Tempo em que seis tentativas de backoff caberiam com folga.
      await tester.pump(const Duration(minutes: 2));

      expect(b.online.status, OnlineStatus.atualizacaoObrigatoria);
      expect(b.online.falhaTerminal, isTrue);
      expect(
        b.aberturas,
        1,
        reason: 'nenhuma tentativa de rede conserta um aplicativo velho',
      );
      // E a pessoa não fica olhando para um estado sem saída: a tela oferece o
      // botão, mesmo sabendo que quem resolve é a loja.
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      b.aquietar();
    });

    testWidgets('o recado de estado terminal cabe na linha — REGRESSÃO', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _irAoLobby(tester);

      // Um `erro` genérico durante a autenticação é o servidor que ainda não
      // fala o protocolo 2 — e é o estado cujo recado é o MAIS LONGO da lista
      // ('servidor em atualização — tente mais tarde', 41 caracteres).
      //
      // O texto ficava solto num `Row`, sem restrição de largura. Cabia por
      // pouco na fonte e na largura de referência, e deixava de caber em
      // qualquer aparelho mais estreito ou com o ajuste de fonte grande do
      // sistema — que é exatamente quem mais precisa ler um recado de erro. O
      // que se via era a faixa de estouro, e o recado cortado.
      b.canal.servidorEnvia({'tipo': 'erro', 'motivo': 'comando desconhecido'});
      await tester.pumpAndSettle();

      expect(b.online.status, OnlineStatus.servidorDesatualizado);
      expect(
        tester.takeException(),
        isNull,
        reason: 'o recado do estado terminal não pode estourar a linha',
      );
      expect(find.text('servidor em atualização — tente mais tarde'),
          findsOneWidget);
      b.aquietar();
    });

    testWidgets('descartar a raiz solta o ouvinte da ponte', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await _irAoLobby(tester);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.online.status, OnlineStatus.conectado);

      // A raiz sai da árvore. A sessão e o transporte foram INJETADOS, então
      // continuam vivos — é o que permite perguntar o que sobrou da ponte.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Uma troca de sessão agora. Se a ponte ainda estivesse escutando, ela
      // chamaria `encerrarSessao()` e derrubaria o transporte de um aplicativo
      // que não está mais na tela.
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(
        b.online.status,
        OnlineStatus.conectado,
        reason: 'a ponte descartada não manda mais em transporte nenhum',
      );
      expect(b.aberturas, 1);
      b.aquietar();
    });
  });

  // =========================================================================
  // §4.5 — "Em breve" não tem rota
  // =========================================================================
  //
  // ERAM QUATRO, E VIRARAM TRÊS. A Loja saiu desta lista quando ganhou
  // destino de produção: ela deixou de apontar para a maquete de
  // `_LojaPreviewHost` e passou a abrir `LojaDeProducao`, que só desenha o
  // selo VIP de `playerEntitlements/{uid}` e os planos que a Play devolveu.
  // O que provava que ela NÃO navegava agora prova o contrário, e mudou de
  // arquivo: `test/casca/loja_de_producao_test.dart`.
  //
  // Os três que sobraram continuam sem backend ligado no cliente, e o caso
  // continua sendo o que impede que qualquer um deles vire rota por descuido.
  testWidgets('os três bloqueados avisam, e nenhum deles navega', (
    tester,
  ) async {
    final b = _Bancada(uidInicial: 'uid-A');
    addTearDown(b.fechar);

    await _abrirAplicativo(tester, b);
    await _passarAAbertura(tester);

    for (final rotulo in ['Ranking', 'Recompensas', 'Amigos']) {
      final alvo = find.text(rotulo).first;
      await tester.ensureVisible(alvo);
      await tester.pumpAndSettle();
      await tester.tap(alvo);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(HomeDeProducao),
        findsOneWidget,
        reason: '$rotulo tirou alguém da Home',
      );
      expect(
        find.textContaining('ainda não está disponível'),
        findsOneWidget,
        reason: '$rotulo não avisou',
      );

      // O aviso some antes do próximo, senão o `findsOneWidget` seguinte mede a
      // sobra deste.
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }
      b.aquietar();
    });
}
