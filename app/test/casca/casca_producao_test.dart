// casca_producao_test.dart — o comportamento da casca de produção.
//
// O QUE ESTÁ SENDO EXERCITADO É CÓDIGO DE PRODUÇÃO. A raiz é a
// `RaizDoAplicativo` de verdade, a sessão é a `SessaoDoJogador` de verdade, a
// ponte é a `PonteSessaoOnline` de verdade e o transporte é o `OnlineService`
// de verdade. Falsas são só as pontas do mundo — o fluxo de autenticação, a
// fonte de identidade, o provedor de credencial e o canal WebSocket —, que são
// exatamente as costuras que a arquitetura já expunha.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
// de desktop e faz telas desenhadas para celular estourarem em overflow. Todas
// as telas daqui são de celular.

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
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
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/screens/splash_oficial_screen.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/services/ponte_sessao_online.dart';
import 'package:buraco_master_vip/sessao/comandos_de_autenticacao.dart';
import 'package:buraco_master_vip/sessao/credencial_de_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Fakes das pontas do mundo
// ===========================================================================

class _FonteFalsa implements FonteDeIdentidade {
  String apelido = 'Ana';
  int chamadas = 0;
  final List<Completer<IdentidadePublica>> pendentes = [];

  /// Responde na hora, sem passar pela lista de pendentes.
  bool automatica = true;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() {
    chamadas++;
    if (automatica) {
      return Future<IdentidadePublica>.value(_identidade(apelido));
    }
    final c = Completer<IdentidadePublica>();
    pendentes.add(c);
    return c.future;
  }

  void responder({String? apelido}) =>
      pendentes.removeAt(0).complete(_identidade(apelido ?? this.apelido));
}

IdentidadePublica _identidade(String apelido) => IdentidadePublica(
  publicId: 'P0A1B2C3D4E5',
  apelido: apelido,
  avatarRef: null,
  criada: false,
  estado: EstadoPerfil.ativo,
  limites: LimitesSociais.desconhecidos,
  edicao: MetadadosDeEdicao.desconhecidos,
);

class _CredencialFalsa implements FonteDeCredencial {
  String? token = 'token-de-teste';
  int pedidos = 0;

  @override
  Future<String?> obterToken() async {
    pedidos++;
    return token;
  }
}

/// Os comandos de entrar e sair, encenados.
///
/// O ponto importante: [entrar] e [sair] só mexem no FLUXO DE AUTENTICAÇÃO —
/// é assim que o provedor de verdade funciona, e é o que permite provar que a
/// tela de login não precisa navegar e que a de Ajustes não precisa dar `pop`.
class _AutenticacaoFalsa implements ComandosDeAutenticacao {
  _AutenticacaoFalsa(
    this._fluxo, {
    this.provedores = const [ProvedorDeLogin.google],
  });

  final StreamController<String?> _fluxo;
  final List<ProvedorDeLogin> provedores;

  int entradas = 0;
  int saidas = 0;
  String uidQueVaiEntrar = 'uid-A';

  /// Quando preenchido, [entrar] falha com esta mensagem em vez de logar.
  String? falharCom;

  /// Quando `true`, [entrar] devolve cancelamento.
  bool cancelar = false;

  @override
  List<ProvedorDeLogin> get provedoresDisponiveis => provedores;

  @override
  Future<ResultadoDeLogin> entrar(ProvedorDeLogin provedor) async {
    entradas++;
    if (cancelar) return const ResultadoDeLogin.cancelado();
    final falha = falharCom;
    if (falha != null) return ResultadoDeLogin.falhou(falha);
    _fluxo.add(uidQueVaiEntrar);
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

  List<Map<String, dynamic>> get mensagens =>
      enviadas.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();

  void servidorEnvia(Map<String, dynamic> msg) =>
      _doServidor.add(jsonEncode(msg));

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

/// Endereço sintético. Não existe, não é resolvido e nenhum teste toca a rede.
const String kEndpointDeTeste = 'wss://servidor-de-teste.invalido';

// ===========================================================================
// A bancada
// ===========================================================================

class _Bancada {
  _Bancada({
    String? uidInicial,
    List<ProvedorDeLogin> provedores = const [ProvedorDeLogin.google],
  }) {
    sessao = SessaoDoJogador(
      fonte: fonte,
      uids: fluxo.stream,
      uidInicial: uidInicial,
      credenciais: credenciais,
    );
    online = criarOnlineServiceDaSessao(
      sessao,
      endpoint: Uri.parse(kEndpointDeTeste),
      abrirCanal: (url) {
        aberturas++;
        final c = _CanalFalso();
        canais.add(c);
        return c;
      },
    );
    autenticacao = _AutenticacaoFalsa(fluxo, provedores: provedores);
  }

  final fluxo = StreamController<String?>.broadcast();
  final fonte = _FonteFalsa();
  final credenciais = _CredencialFalsa();
  final List<_CanalFalso> canais = [];

  /// Quantas vezes o transporte tentou ABRIR um canal — inclusive as que
  /// falharam. É o número que responde "abriu socket duplicado?".
  int aberturas = 0;

  late final SessaoDoJogador sessao;
  late final OnlineService online;
  late final _AutenticacaoFalsa autenticacao;

  _CanalFalso get canal => canais.last;

  Widget get aplicativo => RaizDoAplicativo(
    sessao: sessao,
    autenticacao: autenticacao,
    online: online,
    // Abertura curta e muda: o teste não tem plugin de áudio, e esperar 3,8s
    // de animação em cada caso multiplicaria o tempo da suíte por nada.
    duracaoDaSplash: const Duration(milliseconds: 20),
    somNaSplash: false,
    limiteDeResolucao: const Duration(seconds: 8),
  );

  void fechar() {
    online.dispose();
    sessao.dispose();
    fluxo.close();
  }
}

/// Monta o aplicativo numa superfície de telefone e atravessa a abertura.
Future<void> _abrirAplicativo(WidgetTester tester, _Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump(); // primeiro quadro da splash
}

/// Deixa a abertura terminar e o roteamento assentar.
Future<void> _passarAAbertura(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

void main() {
  // =========================================================================
  // 1 e 2 — partida fria
  // =========================================================================
  group('partida fria', () {
    testWidgets('sem sessão: Splash e depois Login', (tester) async {
      final b = _Bancada();
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      expect(find.byType(SplashOficialScreen), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);

      // O fluxo se pronuncia: não há ninguém.
      b.fluxo.add(null);
      await _passarAAbertura(tester);

      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);
      expect(find.byType(SplashOficialScreen), findsNothing);
    });

    testWidgets('com sessão válida: Splash e depois Home', (tester) async {
      // `uidInicial` é o aplicativo subindo com sessão já restaurada — o caso
      // em que a resposta chega antes de o stream emitir.
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      expect(find.byType(SplashOficialScreen), findsOneWidget);

      await _passarAAbertura(tester);

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);
    });

    testWidgets('a Splash cobre a espera inteira, não só a animação', (
      tester,
    ) async {
      final b = _Bancada();
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      // A animação termina...
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump();

      // ...e a splash continua, porque a sessão ainda não respondeu. É a prova
      // de que a espera é pela SESSÃO, e não pelo relógio da abertura.
      expect(find.byType(SplashOficialScreen), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);

      b.fluxo.add(null);
      await tester.pumpAndSettle();
      expect(find.byType(LoginDeProducao), findsOneWidget);
    });

    testWidgets('sessão que nunca responde vira estado explícito com saída', (
      tester,
    ) async {
      final b = _Bancada();
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      // Ninguém emite nada. Passado o teto, a casca para de esperar calada.
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();

      expect(find.text('Não consegui iniciar sua sessão'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      // E continua NÃO havendo sessão: o estado terminal não inventa uma.
      expect(b.sessao.estado.autenticado, isFalse);
      expect(find.byType(HomeDeProducao), findsNothing);
    });
  });

  // =========================================================================
  // 3 — resolução concorrente
  // =========================================================================
  group('resolução da sessão', () {
    testWidgets('reconstruções em rajada não duplicam a resolução', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      // Vinte quadros de reconstrução da árvore inteira.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        b.fonte.chamadas,
        1,
        reason: 'a identidade é resolvida uma vez por sessão, não por quadro',
      );
    });

    testWidgets('o mesmo uid reemitido não abre segunda resolução', (
      tester,
    ) async {
      final b = _Bancada();
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      b.fluxo.add('uid-A');
      await _passarAAbertura(tester);
      expect(b.fonte.chamadas, 1);

      // O fluxo de autenticação repete o mesmo uid a cada renovação de token.
      b.fluxo
        ..add('uid-A')
        ..add('uid-A');
      await tester.pumpAndSettle();

      expect(b.fonte.chamadas, 1);
      expect(b.sessao.geracao, 1, reason: 'reemissão não é troca de sessão');
      expect(find.byType(HomeDeProducao), findsOneWidget);
    });
  });

  // =========================================================================
  // 4, 5, 7, 8 — login, logout e troca de conta
  // =========================================================================
  group('login e logout', () {
    testWidgets('login concluído leva à Home sem a tela navegar', (
      tester,
    ) async {
      final b = _Bancada();
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      b.fluxo.add(null);
      await _passarAAbertura(tester);
      expect(find.byType(LoginDeProducao), findsOneWidget);

      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();

      expect(b.autenticacao.entradas, 1);
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);
      // UMA resolução de identidade. Se houvesse um segundo observador do fluxo
      // de autenticação em algum canto da árvore, este número seria outro.
      expect(b.fonte.chamadas, 1);
    });

    testWidgets('login cancelado não vira mensagem de erro', (tester) async {
      final b = _Bancada();
      addTearDown(b.fechar);
      b.autenticacao.cancelar = true;

      await _abrirAplicativo(tester, b);
      b.fluxo.add(null);
      await _passarAAbertura(tester);

      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.textContaining('Não consegui'), findsNothing);
    });

    testWidgets('logout volta ao Login', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      expect(find.byType(HomeDeProducao), findsOneWidget);

      await b.autenticacao.sair();
      await tester.pumpAndSettle();

      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);
    });

    testWidgets('logout pelos Ajustes descarta a pilha de rotas privadas', (
      tester,
    ) async {
      // A tela de Ajustes lê preferências do disco; sem isto o plugin lança e a
      // carga vira exceção assíncrona no meio do teste.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      // O caminho REAL: Home → Ajustes → Sair da conta → confirmar.
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfiguracoesDeProducao), findsOneWidget);

      // `scrollUntilVisible` para assim que o finder ENCONTRA o widget, e isso
      // acontece um pouco antes de ele estar de fato dentro da tela.
      await tester.scrollUntilVisible(find.text('Sair da conta'), 200);
      await tester.ensureVisible(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
      await tester.pumpAndSettle();

      expect(b.autenticacao.saidas, 1);
      expect(find.byType(LoginDeProducao), findsOneWidget);
      // A PROVA QUE IMPORTA: a tela privada não sobrou por cima da pública.
      // Trocar a tela de baixo não removeria uma rota empurrada por `push`.
      expect(find.byType(ConfiguracoesDeProducao), findsNothing);
      expect(find.byType(HomeDeProducao), findsNothing);
    });

    testWidgets('resposta anterior ao logout não ressuscita o usuário', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      b.fonte.automatica = false; // a identidade fica em voo

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      expect(b.fonte.pendentes, hasLength(1));

      await b.autenticacao.sair();
      await tester.pumpAndSettle();
      expect(find.byType(LoginDeProducao), findsOneWidget);

      // A resposta da sessão ANTIGA chega agora, depois do logout.
      b.fonte.responder(apelido: 'Ana');
      await tester.pumpAndSettle();

      expect(
        find.byType(LoginDeProducao),
        findsOneWidget,
        reason: 'a resposta atrasada pertence a uma sessão que não existe mais',
      );
      expect(b.sessao.estado.autenticado, isFalse);
      expect(b.sessao.publicId, isNull);
      expect(find.text('Ana'), findsNothing);
    });

    testWidgets('troca de conta não reapresenta os dados da anterior', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      b.fonte.automatica = false;

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      b.fonte.responder(apelido: 'Ana');
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);

      // Jogador B entra sem passar por logout — troca direta de conta.
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      expect(
        find.text('Ana'),
        findsNothing,
        reason: 'o cabeçalho não pode segurar o apelido do jogador anterior',
      );

      b.fonte.responder(apelido: 'Bruno');
      await tester.pumpAndSettle();
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Ana'), findsNothing);
    });
  });

  // =========================================================================
  // 9 e 10 — a Home não inventa dado
  // =========================================================================
  group('a Home só afirma o que tem fonte', () {
    InicioScreen telaInicial(WidgetTester tester) =>
        tester.widget<InicioScreen>(find.byType(InicioScreen));

    testWidgets('o VM da Home não é o InicioVM.mock()', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      final vm = telaInicial(tester).vm;
      final maquete = InicioVM.mock();

      expect(vm.jogador.nome, 'Ana');
      expect(vm.jogador.nome, isNot(maquete.jogador.nome));
      expect(vm.jogador.email, isEmpty);
      expect(vm.jogador.moedas, isNot(maquete.jogador.moedas));
      expect(vm.jogador.liga, isNot(maquete.jogador.liga));
    });

    testWidgets('sem autoridade, o dado fica ausente — não vira zero', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      final vm = telaInicial(tester).vm;
      expect(
        vm.jogador.moedas,
        isNull,
        reason: 'não há autoridade de economia',
      );
      expect(vm.jogador.liga, isNull, reason: 'não há autoridade de ranking');
      expect(vm.temporada, isNull);
      expect(vm.lobby, isNull);

      // E nada disso é desenhado com um valor de mentira.
      expect(find.textContaining('Liga '), findsNothing);
      expect(find.textContaining('online agora'), findsNothing);
    });

    testWidgets('identidade em voo mostra carregamento, não cabeçalho', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);
      b.fonte.automatica = false;

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      expect(telaInicial(tester).estado, InicioEstado.carregando);
      expect(find.text('Jogador(a)'), findsNothing);
    });

    testWidgets('o menu não oferece destino que não existe', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      final menu = {
        for (final item in telaInicial(tester).vm.menu)
          item.id: item.disponivel,
      };
      expect(menu['perfil'], isTrue);
      expect(menu['jogar'], isTrue);
      expect(menu['tutorial'], isTrue);
      expect(menu['ajustes'], isTrue);
      // A Loja passou para cá quando ganhou host de produção: o item deixou
      // de abrir a maquete e passou a abrir `LojaDeProducao`, que só exibe o
      // que tem autoridade — o selo VIP do backend e os planos da Play. O
      // comportamento dela é provado em `loja_de_producao_test.dart`; aqui
      // interessa só que a grade parou de apagá-la, porque enquanto
      // `disponivel` era `false` nenhum dedo alcançava a rota nova.
      expect(menu['loja'], isTrue);
      // Estes três só têm prévia visual, e a prévia não é destino.
      expect(menu['ranking'], isFalse);
      expect(menu['recompensas'], isFalse);
      expect(menu['amigos'], isFalse);
    });

    testWidgets('tocar num item indisponível avisa e não navega', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      // `.first` porque "Ranking" aparece na grade e na barra de baixo — e as
      // duas precisam avisar em vez de navegar.
      await tester.tap(find.text('Ranking').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.textContaining('ainda não está disponível'), findsOneWidget);
    });
  });

  // =========================================================================
  // 5 e 10 — o Perfil ALCANÇÁVEL também só afirma o que tem fonte
  //
  // Absorvido de `casca-producao-auth-roteamento-v2-9c41ae @ b246c07`, e o
  // motivo de estar aqui e não na suíte de ranking é o adjetivo: a suíte de
  // ranking monta `PerfilScreen` e `PerfilPage` na mão, o que prova a TELA. O
  // que estes casos provam é o Perfil que a pessoa realmente abre — pela grade
  // da Home, com a raiz de produção, a sessão de verdade e a identidade real
  // atravessando tudo. Um VM correto que ninguém alcança não protege ninguém.
  //
  // A liga é o único ponto em que a folha absorvida foi REJEITADA: ela apagava
  // a linha inteira, e a linha canônica mantém `💎 Liga —`, que é uma ausência
  // admitida e não desloca o cabeçalho. Os casos abaixo travam essa decisão nos
  // dois sentidos — o travessão fica, `Bronze` e `#0` não voltam.
  // =========================================================================
  group('o Perfil alcançável só afirma o que tem fonte', () {
    Future<void> abrirPerfil(WidgetTester tester, _Bancada b) async {
      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      // Pela GRADE da Home, e não construindo a página na mão.
      //
      // `warnIfMissed: false` porque o alvo do toque é o `InkWell` do item, e
      // não o `Text` que o localiza — o aviso do `flutter_test` é sobre o
      // widget encontrado, não sobre o gesto. A prova de que o toque funcionou
      // é a asserção seguinte: o `PerfilPage` está na árvore.
      await tester.tap(find.text('Perfil').first, warnIfMissed: false);
      await tester.pump();
      // O serviço simula 350ms de I/O antes de responder.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    PerfilVM vmNaTela(WidgetTester tester) =>
        tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;

    /// Todo o texto desenhado, concatenado — pega o literal mesmo quando ele foi
    /// partido entre dois `Text` vizinhos.
    String textoDaTela(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' | ');

    testWidgets('o Perfil é alcançável a partir da Home', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirPerfil(tester, b);

      expect(find.byType(PerfilPage), findsOneWidget);
      // E a identidade REAL da sessão chega até lá.
      expect(find.text('Ana'), findsWidgets);
    });

    testWidgets('sem autoridade de ranking, nada de Bronze nem de #0', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirPerfil(tester, b);

      final vm = vmNaTela(tester);
      expect(vm.ranking.liga, isNull, reason: 'não há autoridade de ranking');
      expect(
        vm.ranking.posicaoMundial,
        isNull,
        reason: 'ninguém classificou ninguém',
      );

      final texto = textoDaTela(tester);
      expect(texto, isNot(contains('Bronze')));
      expect(texto, isNot(contains('#0')));
      expect(texto, isNot(contains('no mundo')));
      // O rótulo fica, com a ausência admitida no lugar do valor — é o estado
      // neutro aprovado na linha canônica, e não a linha apagada.
      expect(find.text('💎 Liga'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('progressão, estatísticas e conquistas ficam ausentes', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirPerfil(tester, b);

      final vm = vmNaTela(tester);
      expect(vm.nivel, isNull, reason: 'não há sistema de XP ligado');
      expect(vm.xpAtual, isNull);
      expect(vm.xpProximo, isNull);
      expect(vm.titulo, isNull, reason: 'título é concedido, não presumido');
      expect(vm.tituloEmoji, isNull);
      expect(vm.stats, isNull, reason: 'nada grava resultado de partida');
      expect(vm.presentesCount, isNull);
      expect(
        vm.conquistas,
        isNull,
        reason: 'quem sabe o que foi desbloqueado é o backend de recompensas',
      );

      // E nenhum deles vira um zero desenhado.
      final texto = textoDaTela(tester);
      expect(texto, isNot(contains('XP')));
      expect(texto, isNot(contains('Novato')));
      expect(texto, isNot(contains('CONQUISTAS')));
      expect(texto, isNot(contains('Vitórias')));
      expect(texto, isNot(contains('Partidas')));
      expect(texto, isNot(contains('Canastras')));
      expect(texto, isNot(contains('presentes que você recebeu')));
      // Nem no recado de estado vazio: "ainda sem conquistas" é uma frase sobre
      // a vida da pessoa, e ninguém conferiu.
      expect(texto, isNot(contains('Ainda sem conquistas')));
    });

    testWidgets('o convite copiado do Perfil alcançável não inventa nada', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirPerfil(tester, b);

      final texto = PerfilPage.textoDeCompartilhamento(vmNaTela(tester));
      expect(texto, contains('Ana'), reason: 'o dado que TEM fonte continua');
      expect(texto, contains('Buraco Master VIP'));
      expect(texto, isNot(contains('Nível')));
      expect(texto, isNot(contains('Liga')));
      expect(texto, isNot(contains('Bronze')));
      expect(texto, isNot(contains('#')));
      expect(texto, isNot(contains('—')), reason: 'nem o travessão vaza');
    });

    testWidgets('o VM do Perfil alcançável não é a maquete', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirPerfil(tester, b);

      final vm = vmNaTela(tester);
      final maquete = PerfilVM.mock();
      expect(vm.nome, isNot(maquete.nome));
      expect(vm.nivel, isNot(maquete.nivel));
      expect(vm.ranking, isNot(maquete.ranking));
      expect(vm.stats, isNot(maquete.stats));
      expect(vm.conquistas, isNot(maquete.conquistas));
    });
  });

  // =========================================================================
  // 11 e 13 — estados terminais e erro de login
  // =========================================================================
  group('estados honestos da tela pública', () {
    testWidgets('build sem provedor operacional é terminal e sem botão', (
      tester,
    ) async {
      final b = _Bancada(provedores: const []);
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      b.fluxo.add(null);
      await _passarAAbertura(tester);

      expect(find.text('Este aplicativo está mal configurado'), findsOneWidget);
      expect(find.text('Entrar com Google'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('erro de login aparece redigido', (tester) async {
      final b = _Bancada();
      addTearDown(b.fechar);
      // O adaptador de produção redige na origem; aqui a bancada entrega o
      // texto como ele chegaria depois disso, e o que se prova é que a tela
      // mostra ESTE texto e não constrói outro por conta própria.
      b.autenticacao.falharCom = 'Não consegui entrar: [REDIGIDO]';

      await _abrirAplicativo(tester, b);
      b.fluxo.add(null);
      await _passarAAbertura(tester);

      await tester.tap(find.text('Entrar com Google'));
      await tester.pumpAndSettle();

      expect(find.text('Não consegui entrar: [REDIGIDO]'), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsOneWidget);
    });
  });

  // =========================================================================
  // 6, 12, 14, 17 — transporte
  // =========================================================================
  group('transporte', () {
    /// Caminho REAL até o lobby: Home → Jogar → Mesa por código.
    Future<void> irAoLobby(WidgetTester tester) async {
      await tester.tap(find.text('Jogar').first);
      await tester.pumpAndSettle();
      expect(find.byType(OndeJogarDeProducao), findsOneWidget);
      await tester.tap(find.text('Mesa por código'));
      await tester.pumpAndSettle();
      expect(find.byType(LobbyOnline), findsOneWidget);
    }

    testWidgets('inicialização autenticada não abre socket nenhum', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);

      expect(
        b.aberturas,
        0,
        reason: 'subir o transporte na raiz não é conectar',
      );
      expect(b.online.querConectado, isFalse);
    });

    testWidgets('abrir o lobby conecta UMA vez, mesmo com o status mudando', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await irAoLobby(tester);

      expect(b.aberturas, 1);
      // O servidor aceita a credencial: o status muda, e cada mudança
      // reconstrói a tela. Nenhuma dessas reconstruções pode abrir outro
      // socket.
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.aberturas, 1);
      expect(b.canais, hasLength(1));
    });

    testWidgets('logout fecha o socket e cancela a reconexão', (tester) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await irAoLobby(tester);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();
      expect(b.online.status, OnlineStatus.conectado);

      final canalDaSessao = b.canal;
      await b.autenticacao.sair();
      await tester.pumpAndSettle();

      expect(b.autenticacao.saidas, 1);
      expect(canalDaSessao.fechado, isTrue);
      expect(b.online.status, OnlineStatus.desconectado);
      expect(
        b.online.querConectado,
        isFalse,
        reason: 'sem sessão não há credencial: insistir só produz erro em loop',
      );
      expect(
        b.online.visao,
        isNull,
        reason: 'a projeção do jogador some junto',
      );
      expect(find.byType(LoginDeProducao), findsOneWidget);
    });

    testWidgets('a credencial não aparece em lugar nenhum da interface', (
      tester,
    ) async {
      final b = _Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await _abrirAplicativo(tester, b);
      await _passarAAbertura(tester);
      await irAoLobby(tester);
      b.canal.servidorEnvia({'tipo': 'autenticado'});
      await tester.pumpAndSettle();

      final token = b.credenciais.token!;
      // O token sai UMA vez, e só dentro da mensagem `auth`.
      final comToken = b.canal.enviadas.where((m) => m.contains(token));
      expect(comToken, hasLength(1));
      expect(b.canal.mensagens.single['tipo'], 'auth');

      // E não está em nenhum texto desenhado, nem na URL do socket.
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}');
      for (final texto in textos) {
        expect(texto.contains(token), isFalse, reason: 'texto na tela: $texto');
      }
      expect(kEndpointDeTeste.contains(token), isFalse);
    });
  });

  // =========================================================================
  // 12 — o teto de tentativas, visto pela casca
  // =========================================================================
  test('sem conexão, o ciclo automático desiste e diz isso', () {
    fakeAsync((relogio) {
      final fluxo = StreamController<String?>.broadcast();
      final fonte = _FonteFalsa();
      final sessao = SessaoDoJogador(
        fonte: fonte,
        uids: fluxo.stream,
        uidInicial: 'uid-A',
        credenciais: _CredencialFalsa(),
      );
      var aberturas = 0;
      final online = criarOnlineServiceDaSessao(
        sessao,
        endpoint: Uri.parse(kEndpointDeTeste),
        abrirCanal: (_) {
          aberturas++;
          throw StateError('rede fora');
        },
      );
      final ponte = PonteSessaoOnline(sessao: sessao, online: online);
      addTearDown(() {
        ponte.dispose();
        online.dispose();
        sessao.dispose();
        fluxo.close();
      });

      online.conectar();
      // Tempo de sobra para o backoff inteiro rodar até o fim.
      relogio.elapse(const Duration(minutes: 10));

      expect(online.status, OnlineStatus.semConexao);
      expect(
        aberturas,
        lessThanOrEqualTo(OnlineService.limiteDeTentativas + 1),
        reason: 'o teto existe para o aplicativo não girar a noite inteira',
      );
      expect(online.falhaTerminal, isTrue);
    });
  });

  // =========================================================================
  // 11 — configuração inválida do endereço, que é terminal de verdade
  // =========================================================================
  test('endereço de servidor inválido é falha terminal, não tentativa', () {
    fakeAsync((relogio) {
      final fluxo = StreamController<String?>.broadcast();
      final sessao = SessaoDoJogador(
        fonte: _FonteFalsa(),
        uids: fluxo.stream,
        uidInicial: 'uid-A',
        credenciais: _CredencialFalsa(),
      );
      var aberturas = 0;
      final online = OnlineService(
        obterIdToken: sessao.obterCredencial,
        // Endereço local: um aplicativo publicado com isto não alcança
        // servidor nenhum, e nenhuma tentativa de rede conserta o build.
        endpoint: null,
        abrirCanal: (_) {
          aberturas++;
          return _CanalFalso();
        },
      );
      addTearDown(() {
        online.dispose();
        sessao.dispose();
        fluxo.close();
      });

      online.conectar();
      relogio.elapse(const Duration(minutes: 2));

      expect(online.status, OnlineStatus.configuracaoInvalida);
      expect(aberturas, 0, reason: 'não se abre socket para endereço inválido');
      expect(online.falhaTerminal, isTrue);
    });
  });
}
