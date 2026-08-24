// presenca_na_home_test.dart — O P0 DA OS 38.2 (§3.1 e §14.2).
//
// UMA AFIRMAÇÃO, e ela é o motivo desta OS existir:
//
//   A PRESENÇA ONLINE NASCE NA HOME AUTENTICADA, sem que ninguém abra o Lobby,
//   crie mesa, entre por código ou toque em coisa nenhuma.
//
// Tudo o que está aqui é código de produção: a `RaizDoAplicativo` de verdade, a
// `SessaoDoJogador` de verdade, a `PonteSessaoOnline` de verdade e o
// `OnlineService` de verdade. Falsas são as quatro pontas do mundo — fluxo de
// autenticação, fonte de identidade, provedor de credencial e canal WebSocket.
//
// POR QUE ISTO PRECISA DE TESTE PRÓPRIO, e não cabia na suíte da Casca: o que
// se guarda aqui não é "a tela desenha certo", é UM CAMINHO — sessão → ponte →
// transporte → presença → descoberta. Um caso que montasse `OnlineService`
// direto provaria o transporte e deixaria a ponte de fora, que é justamente
// onde a iniciativa mora.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/escolha_assento_de_producao.dart';
import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/lobby_publico_de_producao.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/descoberta/contrato_descoberta.dart';
import 'package:buraco_master_vip/descoberta/estado_descoberta.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart' show NavDestino;

import '../casca/bancada_online.dart';
import 'retrato_de_teste.dart';

/// Monta o aplicativo numa superfície de telefone e atravessa a abertura.
Future<void> abrirAplicativo(WidgetTester tester, Bancada b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

/// O servidor aceita a credencial. É o instante em que a pessoa passa a
/// existir para ele — e, portanto, o instante em que a presença começa.
Future<void> servidorAceita(WidgetTester tester, Bancada b) async {
  b.canal.servidorEnvia({'tipo': 'autenticado'});
  await tester.pumpAndSettle();
}

/// Silencia o transporte no fim do corpo do teste. Ver a mesma nota em
/// `casca_producao_test.dart`: o `flutter_test` confere temporizadores
/// pendentes ANTES dos `addTearDown`, então `b.fechar` não chega a tempo.
void aquietar(Bancada b) => b.online.desligar();

/// Home -> Onde jogar -> Lobby Público, pelos toques de verdade.
///
/// O botão da Home se chama "Jogar" (e não "JOGAR"): o texto é desenhado em
/// caixa alta pelo estilo, não pelo conteúdo. `find.text` casa com o CONTEÚDO.
Future<void> irAoLobbyPublico(WidgetTester tester) async {
  await tester.tap(find.text('Jogar').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mesa Pública'));
  await tester.pumpAndSettle();
  expect(find.byType(LobbyPublicoDeProducao), findsOneWidget);
}

/// Volta uma rota.
///
/// `tester.pageBack()` NÃO serve: ele procura um botão com o tooltip "Back",
/// em inglês, e as telas daqui nomeiam o Voltar em português. Usar o
/// `Navigator` é o mesmo efeito sem depender do idioma do tooltip.
Future<void> voltar(WidgetTester tester) async {
  final estado = tester.state<NavigatorState>(find.byType(Navigator).last);
  estado.pop();
  await tester.pumpAndSettle();
}

void _ignorar(String _) {}
void _ignorarNav(NavDestino _) {}

List<Map<String, dynamic>> _tipos(Bancada b, String tipo) =>
    b.canal.mensagens.where((m) => m['tipo'] == tipo).toList();

void main() {
  // =========================================================================
  group('§3.1 — A PRESENÇA NASCE NA HOME', () {
    // =======================================================================

    testWidgets('P0-01 partida fria autenticada: conecta, autentica e pede a lista', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);

      // 2. A Home é exibida.
      expect(find.byType(HomeDeProducao), findsOneWidget);
      // 7. Nenhuma visita ao Lobby aconteceu — nem ao antigo, nem ao público.
      expect(find.byType(LobbyOnline), findsNothing);
      expect(find.byType(LobbyPublicoDeProducao), findsNothing);

      // 3. O transporte canônico conectou.
      expect(b.aberturas, 1);
      expect(b.canais, hasLength(1));
      // 4. A credencial veio da sessão canônica.
      final auth = b.canal.mensagens.first;
      expect(auth['tipo'], 'auth');
      expect(auth['token'], 'token-de-teste');
      expect(auth['protocolo'], 2);

      // 5 e 6. Presença estabelecida e descoberta inicial pedida.
      await servidorAceita(tester, b);
      expect(_tipos(b, ContratoDaDescoberta.pulsoDePresenca), hasLength(1));
      expect(_tipos(b, ContratoDaDescoberta.pedidoDeMesas), hasLength(1));
      aquietar(b);
    });

    testWidgets('P0-02 a presença PERMANECE com a Home parada', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      final pulsosIniciais = _tipos(b, ContratoDaDescoberta.pulsoDePresenca).length;

      // Ninguém toca em nada por um bom tempo.
      //
      // VÁRIOS QUADROS, e não um `pump` de 30 s: um único `pump` longo
      // avança o relógio uma vez e dispara cada periódico UMA vez. Trinta
      // segundos de aplicativo aberto são muitos quadros, e é isso que se quer
      // medir — que o pulso continua saindo, e não que ele saiu mais uma vez.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 6));
      }

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(
        _tipos(b, ContratoDaDescoberta.pulsoDePresenca).length,
        greaterThan(pulsosIniciais),
        reason: 'quem está parado na Home continua presente',
      );
      expect(b.canal.fechado, isFalse);
      aquietar(b);
    });

    testWidgets('P0-03 abrir e fechar rotas NÃO cria um segundo socket', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      expect(b.aberturas, 1);

      // Home → Onde jogar → Lobby Público → volta → volta.
      await irAoLobbyPublico(tester);
      await voltar(tester);
      await voltar(tester);
      expect(find.byType(HomeDeProducao), findsOneWidget);

      expect(b.aberturas, 1, reason: 'um transporte pela vida do aplicativo');
      expect(b.canais, hasLength(1));
      aquietar(b);
    });

    testWidgets('P0-04 sair do Lobby não derruba a presença', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      await irAoLobbyPublico(tester);
      await voltar(tester);

      expect(b.canal.fechado, isFalse);
      expect(b.online.descobertaLigada, isTrue);
      aquietar(b);
    });

    testWidgets('P0-05 LOGIN inicia a conexão e a presença', (tester) async {
      final b = Bancada(); // sem sessão
      addTearDown(b.fechar);

      await tester.pumpWidget(b.aplicativo);
      await tester.pump();
      b.fluxo.add(null);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(b.aberturas, 0, reason: 'sem credencial não há o que apresentar');

      // A pessoa entra.
      b.fluxo.add('uid-A');
      await tester.pumpAndSettle();

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(b.aberturas, 1);
      await servidorAceita(tester, b);
      expect(_tipos(b, ContratoDaDescoberta.pedidoDeMesas), isNotEmpty);
      aquietar(b);
    });

    testWidgets('P0-06 LOGOUT encerra a conexão e limpa o retrato', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(mesas: [mesa(codigo: 'M-01', humanos: 2)]),
      );
      await tester.pumpAndSettle();
      expect(b.online.descoberta.retrato, isNotNull);

      final canalDaSessao = b.canal;
      b.fluxo.add(null); // logout
      await tester.pumpAndSettle();

      expect(canalDaSessao.fechado, isTrue);
      expect(b.online.descoberta.retrato, isNull);
      expect(b.online.descoberta.fase, FaseDaDescoberta.sessaoEncerrada);
      expect(b.online.descobertaLigada, isFalse);
      expect(find.byType(LoginDeProducao), findsOneWidget);
    });

    testWidgets('P0-07 TROCA A→B: uma transição, credencial nova, zero de A', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(
          geracao: 'ger-A',
          revisao: 500,
          mesas: [mesa(codigo: 'MESA-DE-A', humanos: 3)],
        ),
      );
      await tester.pumpAndSettle();
      expect(b.online.descoberta.retrato!.mesas.single.codigo, 'MESA-DE-A');

      final canalDeA = b.canal;
      b.fluxo.add('uid-B');
      await tester.pumpAndSettle();

      // Uma única transição, e um socket novo.
      expect(canalDeA.fechado, isTrue);
      expect(b.aberturas, 2);
      expect(b.canais, hasLength(2));
      expect(b.canal, isNot(same(canalDeA)));
      // Nada de A sobreviveu.
      expect(b.online.descoberta.retrato, isNull);

      // E uma RESPOSTA ATRASADA de A, pelo canal velho, não ressuscita nada.
      canalDeA.servidorEnvia(
        retratoDeMesas(
          geracao: 'ger-A',
          revisao: 501,
          mesas: [mesa(codigo: 'MESA-DE-A', humanos: 3)],
        ),
      );
      await tester.pumpAndSettle();
      expect(b.online.descoberta.retrato, isNull);

      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(geracao: 'ger-B', revisao: 1, mesas: [mesa(codigo: 'MESA-DE-B')]),
      );
      await tester.pumpAndSettle();
      expect(b.online.descoberta.retrato!.mesas.single.codigo, 'MESA-DE-B');
      aquietar(b);
    });

    testWidgets('P0-08 nenhuma resposta `mesas` toca a projeção da MESA', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);

      // O jogador está numa mesa: `visao`, `codigo` e `meuAssento` valem.
      b.canal.servidorEnvia({
        'tipo': 'entrou',
        'codigo': 'BURACO-0001',
        'assento': 2,
      });
      b.canal.servidorEnvia({'tipo': 'estado', 'visao': visaoDeLobby(voceAssento: 2)});
      await tester.pumpAndSettle();
      final visaoAntes = b.online.visao;
      expect(visaoAntes, isNotNull);
      expect(b.online.codigo, 'BURACO-0001');
      expect(b.online.meuAssento, 2);

      // Chega uma lista de mesas públicas. Ela NÃO pode mexer em nada disso.
      b.canal.servidorEnvia(
        retratoDeMesas(mesas: [mesa(codigo: 'OUTRA-01', humanos: 3)]),
      );
      await tester.pumpAndSettle();

      expect(b.online.visao, same(visaoAntes));
      expect(b.online.codigo, 'BURACO-0001');
      expect(b.online.meuAssento, 2);
      expect(b.online.descoberta.retrato!.mesas.single.codigo, 'OUTRA-01');
      aquietar(b);
    });

    // ESTE CASO TAMBÉM NASCEU DE UMA MUTAÇÃO QUE ESCAPOU.
    //
    // A campanha fez o host do Lobby passar um `onEscolherMesa` que chama
    // `entrarMesa`, e a suíte ficou verde: o caso que provava "o card não é
    // botão" exercitava a TELA com callback nulo, e não o HOST de produção.
    // Provar a tela isolada não prova quem a monta.
    //
    // A OS 38.3 LIGOU o card, e a afirmação NÃO afrouxou: o que ele abre é o
    // SELETOR de assento, e o Lobby continua sem mandar ingresso nenhum.
    // Entrar direto daqui entraria em QUALQUER lugar — o servidor aplicaria a
    // ordem dele —, e a pessoa descobriria onde sentou depois de sentar.
    testWidgets('P0-08b o Lobby de produção NÃO envia ingresso: abre o seletor', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(
          mesas: [
            mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Beto']),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await irAoLobbyPublico(tester);
      final antes = b.canal.mensagens.length;

      // Toca no card.
      await tester.tap(find.text('Mesa de Ana'));
      await tester.pumpAndSettle();

      // O destino é o SELETOR, e não a mesa.
      expect(find.byType(EscolhaAssentoDeProducao), findsOneWidget);
      expect(find.byType(LobbyOnline), findsNothing);

      // NADA de ingresso saiu — nem `entrarMesa`, nem `criarMesa`.
      for (final m in b.canal.mensagens.skip(antes)) {
        expect(
          m['tipo'],
          anyOf('descobrirMesas', 'presenca_ping'),
          reason: 'o Lobby mandou "${m['tipo']}" — ingresso é a OS 38.3',
        );
      }
      expect(b.online.codigo, isNull);
      expect(b.online.meuAssento, isNull);
      aquietar(b);
    });
  });

  // =========================================================================
  group('§9 — O NÚMERO DA HOME', () {
    // =======================================================================

    testWidgets('HM-09 o total vem do servidor, e é o `jogadoresOnlineTotal`', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(
          mesas: [
            mesa(codigo: 'M-01', humanos: 3, modalidade: 'aberto'),
            mesa(codigo: 'M-02', humanos: 2, modalidade: 'fechado'),
          ],
          jogadoresOnlineTotal: 42,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('42 jogadores online agora'), findsOneWidget);
      // E NÃO é a soma das modalidades, que aqui daria 5.
      expect(find.textContaining('5 jogadores online agora'), findsNothing);
      aquietar(b);
    });

    testWidgets('HM-10 DESCONHECIDO não vira zero — a linha inteira some', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      // O servidor ainda não respondeu a descoberta.

      expect(b.online.descoberta.jogadoresOnlineTotal, isNull);
      expect(find.textContaining('online agora'), findsNothing);
      expect(find.textContaining('0 jogadores'), findsNothing);
      expect(find.byType(HomeDeProducao), findsOneWidget);
      aquietar(b);
    });

    testWidgets('HM-11 ZERO REAL é exibido como zero', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(mesas: const [], jogadoresOnlineTotal: 0),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0 jogadores online agora'), findsOneWidget);
      aquietar(b);
    });

    // ESTE CASO EXISTE PORQUE UMA MUTAÇÃO ESCAPOU.
    //
    // A campanha trocou `online: jogadoresOnline` por
    // `online: jogadoresOnline ?? 0` na Home — "desconhecido vira zero" — e a
    // suíte ficou verde. Não porque a defesa funcionasse: porque a Home tem
    // uma guarda ANTERIOR (`lobby: null` quando não há número), e com ela o
    // cartão nem é construído. O `?? 0` era código morto sob aquele host.
    //
    // A camada VISUAL, porém, é usada por outros hosts e pelo catálogo, e
    // precisa da própria guarda. Aqui ela é exercitada direto, com um
    // `LobbyBanner` de número desconhecido.
    testWidgets('HM-11b a TELA também omite o número quando ele é desconhecido', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: InicioScreen(
            vm: const InicioVM(
              jogador: CabecalhoJogador(
                nome: 'Ana',
                email: '',
                avatar: '👑',
                moldura: null,
                moedas: null,
                liga: null,
              ),
              temporada: null,
              lobby: LobbyBanner(
                titulo: 'Lobby Público',
                subtitulo: 'veja as mesas abertas agora',
                online: null,
                cadeadoVip: false,
              ),
              menu: [],
            ),
            estado: InicioEstado.normal,
            onJogar: () {},
            onAbrirPerfil: () {},
            onHistorico: () {},
            onAbrirTemporada: () {},
            onAbrirLobby: () {},
            onMenuTap: _ignorar,
            onRecarregar: () {},
            onNavTap: _ignorarNav,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // O cartão está lá — quem decide se ele existe é o host.
      expect(find.text('Lobby Público'), findsOneWidget);
      // E o número NÃO está, nem como zero, nem como bolinha verde solta.
      expect(find.textContaining('online agora'), findsNothing);
      expect(find.textContaining('0 jogadores'), findsNothing);
      expect(find.textContaining('🟢'), findsNothing);
    });

    testWidgets('HM-12 singular e plural', (tester) async {
      expect(textoDePresenca(1), '1 jogador online agora');
      expect(textoDePresenca(2), '2 jogadores online agora');
      expect(textoDePresenca(0), '0 jogadores online agora');
    });

    testWidgets('HM-13 um retrato inválido não apaga o número que valia', (
      tester,
    ) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(retratoDeMesas(jogadoresOnlineTotal: 7));
      await tester.pumpAndSettle();
      expect(find.textContaining('7 jogadores online agora'), findsOneWidget);

      // Vem lixo do servidor.
      b.canal.servidorEnvia(
        retratoDeMesas(revisao: 2, jogadoresOnlineTotal: 99)
          ..['esquema'] = 'outro-esquema',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('7 jogadores online agora'), findsOneWidget);
      expect(find.textContaining('99'), findsNothing);
      aquietar(b);
    });

    testWidgets('HM-14 tocar no acesso leva ao Lobby Público', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(retratoDeMesas(jogadoresOnlineTotal: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('3 jogadores online agora'));
      await tester.pumpAndSettle();
      expect(find.byType(LobbyPublicoDeProducao), findsOneWidget);
      aquietar(b);
    });

    testWidgets('HM-15 nenhuma identidade é exibida no acesso', (tester) async {
      final b = Bancada(uidInicial: 'uid-A');
      addTearDown(b.fechar);

      await abrirAplicativo(tester, b);
      await servidorAceita(tester, b);
      b.canal.servidorEnvia(
        retratoDeMesas(
          mesas: [
            mesa(codigo: 'M-01', humanos: 2, apelidos: ['Ana', 'Bruno']),
          ],
          jogadoresOnlineTotal: 2,
        ),
      );
      await tester.pumpAndSettle();

      // O banner mostra número, não gente.
      final textos = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => '${t.data ?? ''}${t.textSpan?.toPlainText() ?? ''}')
          .join(' | ');
      expect(textos.contains('uid-A'), isFalse);
      expect(textos.contains('jogadorId'), isFalse);
      aquietar(b);
    });
  });
}
