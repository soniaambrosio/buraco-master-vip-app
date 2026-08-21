// a11y_alvos_da_casca_test.dart — todo alvo tocável de Home, Onde jogar e
// Perfil é uma AÇÃO NOMEADA, com disponibilidade verdadeira e alvo seguro.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO MEDE, E POR QUE NÃO É BUSCA DE TEXTO
// ---------------------------------------------------------------------------
//
// Nenhum caso aqui procura `Semantics(` no código-fonte. O que ele faz é
// montar a tela, ligar a árvore de acessibilidade com `ensureSemantics()` e
// LER OS NÓS que o Flutter realmente produziu — rótulo, papel, estado e
// retângulo em pontos lógicos. É a diferença entre provar que alguém escreveu
// a anotação e provar que ela chegou na árvore: `excludeSemantics` num lugar
// errado, um `Semantics` que não vira nó porque o pai o absorveu, ou um piso
// de toque que o layout de cima esmaga — nada disso aparece numa varredura de
// texto, e tudo isso aparece aqui.
//
// A MEDIDA É EM PONTOS LÓGICOS. A bancada roda com `devicePixelRatio` 3, então
// o retângulo cru vem em pixels físicos; [_nos] divide pela razão antes de
// comparar com [kAlvoMinimoDeToque]. Sem isso, 48 pontos "medem" 144 e todo
// caso passa por engano.
//
// SUPERFÍCIE ALTA (1080x6000, dpr 3 = 360x2000 lógicos): telefone na largura,
// para o layout ser o real, e alta o bastante para a tela inteira ser
// construída. Nó fora da viewport não existe — medir num 360x800 daria verde
// sobre metade do Perfil.

import 'dart:convert' show LineSplitter;
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/lobby_online.dart';
import 'package:buraco_master_vip/casca/onde_jogar_de_producao.dart';
import 'package:buraco_master_vip/casca/raiz_do_aplicativo.dart';
import 'package:buraco_master_vip/mesa.dart' show MesaScreen;
import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/onde_jogar_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/widgets/alvo_minimo.dart';

import '../amigos/bancada_social.dart';
import 'bancada_online.dart';

// ===========================================================================
// A régua
// ===========================================================================

/// Um nó da árvore de acessibilidade, já traduzido para o que esta OS julga.
class _Alvo {
  _Alvo({
    required this.id,
    required this.label,
    required this.tooltip,
    required this.area,
    required this.ehBotao,
    required this.habilitado,
    required this.selecionado,
    required this.aciona,
    required this.ordem,
  });

  final int id;
  final String label;
  final String tooltip;

  /// Em PONTOS LÓGICOS, já dividido pelo `devicePixelRatio`.
  final Rect area;

  final bool ehBotao;
  final Tristate habilitado;
  final Tristate selecionado;

  /// O nó aceita a ação de toque? É o que um leitor de tela dispara ao
  /// "clicar" — e é diferente de ter um `GestureDetector` por baixo.
  final bool aciona;

  /// A posição na travessia da árvore: a ordem em que o leitor de tela anda.
  final int ordem;

  /// O nome acessível: `label` e, se ele for vazio, o `tooltip`.
  ///
  /// `IconButton(tooltip:)` e `Tooltip(message:)` põem o nome em `tooltip`, e
  /// não em `label`. Um portão que olhasse só `label` acusaria de anônimo um
  /// botão que já está certo.
  String get nome => label.trim().isNotEmpty ? label.trim() : tooltip.trim();

  /// A primeira linha do nome. O cartão do jogador anuncia "Seu perfil" e,
  /// na linha seguinte, de quem ele é — o inventário compara pela primeira.
  String get primeiraLinha => const LineSplitter().convert(nome).first.trim();

  bool get desabilitado => habilitado == Tristate.isFalse;

  @override
  String toString() =>
      '#$id "$nome" botao=$ehBotao habilitado=$habilitado toque=$aciona '
      '${area.width.toStringAsFixed(1)}x${area.height.toStringAsFixed(1)} em '
      '${area.left.toStringAsFixed(1)},${area.top.toStringAsFixed(1)}';
}

/// A raiz da árvore de acessibilidade.
///
/// Sobe a partir do `MaterialApp`, e NÃO a partir da tela: com um modal aberto
/// o Flutter tira a rota de baixo da árvore inteira, e ancorar na tela devolve
/// um nó de uma subárvore descartada — que ainda responde, e ainda tem os
/// filhos antigos.
SemanticsNode _raiz(WidgetTester tester) {
  var no = tester.getSemantics(find.byType(MaterialApp));
  while (no.parent != null) {
    no = no.parent!;
  }
  return no;
}

/// Todos os nós da árvore, na ordem em que o leitor de tela os encontra.
List<_Alvo> _nos(WidgetTester tester) {
  final dpr = tester.view.devicePixelRatio;
  final saida = <_Alvo>[];

  void anda(SemanticsNode no, Matrix4 acumulado) {
    final m = acumulado.clone();
    if (no.transform != null) m.multiply(no.transform!);
    final fisico = MatrixUtils.transformRect(m, no.rect);
    final d = no.getSemanticsData();
    saida.add(
      _Alvo(
        id: no.id,
        label: d.label,
        tooltip: d.tooltip,
        area: Rect.fromLTWH(
          fisico.left / dpr,
          fisico.top / dpr,
          fisico.width / dpr,
          fisico.height / dpr,
        ),
        ehBotao: d.flagsCollection.isButton,
        habilitado: d.flagsCollection.isEnabled,
        selecionado: d.flagsCollection.isSelected,
        aciona: d.hasAction(SemanticsAction.tap),
        ordem: saida.length,
      ),
    );
    no.visitChildren((filho) {
      anda(filho, m);
      return true;
    });
  }

  anda(_raiz(tester), Matrix4.identity());
  return saida;
}

/// Só os nós que respondem a toque — os que esta OS julga.
List<_Alvo> _alvos(WidgetTester tester) =>
    _nos(tester).where((a) => a.aciona).toList();

_Alvo _porNome(List<_Alvo> alvos, String nome) => alvos.firstWhere(
  (a) => a.nome == nome || a.primeiraLinha == nome,
  orElse: () => throw StateError(
    'nenhum alvo chamado "$nome"; havia ${alvos.map((a) => a.nome).toList()}',
  ),
);

/// A barreira do modal, que o Flutter cria e nomeia sozinho.
///
/// Ela não é um controle desta casca: nasce dentro do `showModalBottomSheet`,
/// cobre a tela inteira e existe para fechar a folha ao toque de fora. Fica de
/// fora das medidas de tamanho e de sobreposição porque nenhuma decisão desta
/// OS a governa — e porque um alvo que É a tela inteira, de propósito,
/// atravessa qualquer regra de interseção.
bool _ehDoFramework(_Alvo a) => a.nome == 'Scrim' || a.nome == 'Dialog';
// ===========================================================================
// As bancadas
// ===========================================================================

/// Liga a árvore de acessibilidade e a desliga DENTRO do corpo do caso.
///
/// `addTearDown(h.dispose)` não serve: o `flutter_test` confere se sobrou
/// `SemanticsHandle` no fim do corpo, ANTES de rodar os tear-downs, e o
/// resultado é todo caso reprovando com "A SemanticsHandle was active" — um
/// erro de arnês que se disfarça de defeito do produto.
Future<void> _comSemantica(
  WidgetTester tester,
  Future<void> Function() corpo,
) async {
  final handle = tester.ensureSemantics();
  try {
    await corpo();
  } finally {
    handle.dispose();
  }
}

void _telefoneAlto(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

Future<Bancada> _naHome(WidgetTester tester) async {
  final b = Bancada(uidInicial: 'uid-A');
  addTearDown(b.fechar);
  _telefoneAlto(tester);
  await tester.pumpWidget(b.aplicativo);
  await _assentar(tester);
  expect(find.byType(HomeDeProducao), findsOneWidget);
  return b;
}

Future<Bancada> _emOndeJogar(WidgetTester tester) async {
  final b = await _naHome(tester);
  // Pela GRADE do menu, e não construindo a tela na mão.
  await tester.tap(find.text('Jogar').last, warnIfMissed: false);
  await tester.pumpAndSettle();
  expect(find.byType(OndeJogarScreen), findsOneWidget);
  return b;
}

Future<Bancada> _noPerfil(WidgetTester tester) async {
  final b = await _naHome(tester);
  await tester.tap(find.text('Perfil').first, warnIfMissed: false);
  await tester.pump();
  // O serviço simula I/O antes de responder.
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  expect(find.byType(PerfilPage), findsOneWidget);
  return b;
}

/// O Perfil de OUTRA pessoa, com a faixa social desenhada.
///
/// É a única superfície desta OS onde os controles sociais existem, e eles não
/// moram na tela: nascem em `perfil_page.dart`, a partir das ações que a
/// AUTORIDADE ofereceu. Por isso a bancada monta a raiz de produção com um
/// transporte social falso em vez de fabricar a faixa na mão — o que está sob
/// medida é o botão que o jogador toca, e não uma réplica dele.
Future<void> _noPerfilVisitado(WidgetTester tester) async {
  final b = Bancada(uidInicial: 'uid-A');
  addTearDown(b.fechar);
  _telefoneAlto(tester);
  await tester.pumpWidget(
    RaizDoAplicativo(
      sessao: b.sessao,
      autenticacao: b.autenticacao,
      online: b.online,
      transporteSocial: TransporteSocialFalso(),
      duracaoDaSplash: const Duration(milliseconds: 20),
      somNaSplash: false,
      limiteDeResolucao: const Duration(seconds: 8),
    ),
  );
  await _assentar(tester);

  tester.state<NavigatorState>(find.byType(Navigator).last).push(
    MaterialPageRoute<void>(
      builder: (_) => const PerfilPage(publicIdVisitado: 'P000000000001'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  expect(find.byType(PerfilPage), findsOneWidget);
}

/// O Perfil COM as seções que dependem de fonte — presentes e conquistas.
///
/// A casca de produção não as desenha, porque não há autoridade que as informe
/// (ver `PerfilVM`), e a folha de presentes é justamente um dos alvos que esta
/// OS tem de corrigir. Então estes casos montam a MESMA `PerfilScreen` de
/// produção com um VM que as tem: o que muda é o conteúdo, não a tela.
Future<List<String>> _perfilCompleto(WidgetTester tester) async {
  _telefoneAlto(tester);
  final apertados = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        vm: PerfilVM.mock(),
        navIndisponiveis: const {NavDestino.loja},
        onVoltar: () => apertados.add('voltar'),
        onAbrirConfig: () => apertados.add('config'),
        onTrocarAvatar: () => apertados.add('trocarAvatar'),
        onEditarNick: () => apertados.add('editarNick'),
        onEditarPerfil: () => apertados.add('editarPerfil'),
        onAbrirPresentes: () => apertados.add('abrirPresentes'),
        onFecharPresentes: () => apertados.add('fecharPresentes'),
        onVerTodasConquistas: () => apertados.add('todasConquistas'),
        onVerConquista: (id) => apertados.add('conquista:$id'),
        onVerUltimaConquista: () => apertados.add('ultimaConquista'),
        onTrocarVitrine: () => apertados.add('trocarVitrine'),
        onCompartilhar: () => apertados.add('compartilhar'),
        onRecarregar: () => apertados.add('recarregar'),
        onNavTap: (d) => apertados.add('nav:${d.name}'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return apertados;
}

/// Dispara a ação de toque PELA ÁRVORE DE ACESSIBILIDADE.
///
/// Não é `tester.tap`: este é o caminho que o leitor de tela usa, e é o único
/// que denuncia um nó com papel de botão e sem ação — que é exatamente o que
/// `excludeSemantics` produz quando fica sozinho. Um teste de gesto passaria
/// por cima disso sem perceber.
///
/// `SemanticsNode.owner` a partir da raiz, e não `pipelineOwner`: o segundo
/// está depreciado, e `rootPipelineOwner.semanticsOwner` devolve nulo.
/// Tira a árvore do ar antes do fim do caso.
///
/// A Mesa e o Lobby deixam temporizadores longos ligados — a partida tem
/// cronômetro, e o transporte tem a espera de 15 segundos da reconexão. O
/// `flutter_test` confere "nenhum Timer pendente" ANTES dos tear-downs, então
/// um caso que termina dentro dessas telas reprova por encenação, e a mensagem
/// não diz isso. Desmontar dispara os `dispose` que cancelam tudo.
Future<void> _desmontar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void _acionarPelaSemantica(WidgetTester tester, _Alvo alvo) {
  _raiz(tester).owner!.performAction(alvo.id, SemanticsAction.tap);
}
// ===========================================================================
// Os casos
// ===========================================================================

void main() {
  // -------------------------------------------------------------------------
  // HOME
  // -------------------------------------------------------------------------
  group('Home', () {
    /// Os quinze alvos da Home de produção, na ordem em que o leitor de tela
    /// os encontra. A lista é literal de propósito: ela É o inventário, e um
    /// alvo novo que entre sem nome quebra este caso antes de qualquer outro.
    const esperados = <String>[
      'Seu perfil',
      'Histórico',
      'Jogar',
      'Perfil',
      'Ranking',
      'Recompensas',
      'Amigos',
      'Loja VIP',
      'Jogar',
      'Como jogar',
      'Ajustes',
      'Início',
      'Ranking',
      'Loja',
      'Perfil',
    ];

    testWidgets(
      '1 — todo alvo acionável possui nome',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);

        final alvos = _alvos(tester);
        expect(alvos, hasLength(esperados.length));
        for (final a in alvos) {
          expect(a.nome, isNotEmpty, reason: 'alvo sem nome: $a');
        }
        expect(alvos.map((a) => a.primeiraLinha).toList(), esperados);
        // E o cartão do jogador diz de quem é o perfil.
        expect(_porNome(alvos, 'Seu perfil').nome, contains('Ana'));
      }),
    );

    testWidgets(
      '2 — cartão, grade e barra inferior declaram papel de botão',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);
        final alvos = _alvos(tester);

        for (final a in alvos) {
          expect(a.ehBotao, isTrue, reason: 'sem papel de botão: $a');
        }
        // E os dois que a auditoria pegou usando controle sem papel nenhum.
        expect(_porNome(alvos, 'Seu perfil').ehBotao, isTrue);
        expect(_porNome(alvos, 'Início').ehBotao, isTrue);
      }),
    );

    testWidgets(
      '3 — destino indisponível anuncia estado desabilitado',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);
        final alvos = _alvos(tester);

        // A grade: os três itens sem tela neste build.
        for (final nome in ['Ranking', 'Recompensas', 'Loja VIP']) {
          final item = alvos.firstWhere(
            (a) => a.primeiraLinha == nome && a.area.top < 900,
          );
          expect(item.desabilitado, isTrue, reason: 'devia desabilitar: $item');
        }
        // A barra inferior: os dois destinos que a Home não alcança.
        final barra = alvos.where((a) => a.area.top > 900).toList();
        expect(barra, hasLength(4));
        expect(
          {for (final a in barra) a.nome: a.desabilitado},
          {'Início': false, 'Ranking': true, 'Loja': true, 'Perfil': false},
        );
      }),
    );

    testWidgets(
      '4 — destino disponível continua habilitado',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);
        final alvos = _alvos(tester);

        for (final nome in [
          'Seu perfil',
          'Histórico',
          'Amigos',
          'Como jogar',
          'Ajustes',
        ]) {
          expect(
            _porNome(alvos, nome).habilitado,
            Tristate.isTrue,
            reason: 'devia estar habilitado: ${_porNome(alvos, nome)}',
          );
        }
        // E NENHUM alvo desta tela fica sem declarar a disponibilidade: numa
        // tela onde parte dos destinos se anuncia indisponível, o silêncio dos
        // outros vira ambiguidade.
        for (final a in alvos) {
          expect(
            a.habilitado,
            isNot(Tristate.none),
            reason: 'não declara disponibilidade: $a',
          );
        }
      }),
    );

    testWidgets(
      '5 — Histórico e a barra inferior têm 48 pontos de alvo',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);
        final alvos = _alvos(tester);

        final historico = _porNome(alvos, 'Histórico');
        expect(historico.area.width, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        expect(historico.area.height, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        // A barra media 47, e 47 não era escolha de ninguém.
        for (final a in alvos.where((a) => a.area.top > 900)) {
          expect(
            a.area.height,
            greaterThanOrEqualTo(kAlvoMinimoDeToque),
            reason: '$a',
          );
        }
      }),
    );

    testWidgets(
      '6 — os callbacks continuam os mesmos',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);

        // Disponível navega...
        await tester.tap(find.text('Jogar').last, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(OndeJogarScreen), findsOneWidget);
        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeDeProducao), findsOneWidget);

        // ...e indisponível avisa, sem sair da Home.
        await tester.tap(find.text('Recompensas'), warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(milliseconds: 120));
        expect(find.byType(HomeDeProducao), findsOneWidget);
        expect(find.textContaining('ainda não está disponível'), findsOneWidget);
      }),
    );

    testWidgets(
      '6b — o estado anunciado é o MESMO que decide o destino',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);
        final menu = tester
            .widget<InicioScreen>(find.byType(InicioScreen))
            .vm
            .menu;

        for (final item in menu) {
          final alvo = _alvos(tester).firstWhere(
            (a) => a.nome == _nomeDoItem(item) && a.area.top < 900,
          );
          expect(
            alvo.desabilitado,
            !item.disponivel,
            reason: 'anúncio e desenho divergem em ${item.id}: $alvo',
          );

          await tester.tap(find.text(item.label).first, warnIfMissed: false);
          await tester.pumpAndSettle(const Duration(milliseconds: 120));
          final naHome = find.byType(HomeDeProducao).evaluate().isNotEmpty;
          if (item.disponivel) {
            expect(naHome, isFalse, reason: '${item.id} devia ter navegado');
            tester.state<NavigatorState>(find.byType(Navigator).first).pop();
            await tester.pumpAndSettle();
          } else {
            expect(naHome, isTrue, reason: '${item.id} não devia navegar');
            expect(
              find.textContaining('ainda não está disponível'),
              findsOneWidget,
              reason: '${item.id} devia avisar',
            );
          }
        }
      }),
    );

    testWidgets(
      '6c — o botão anunciado aciona pelo leitor de tela',
      (tester) => _comSemantica(tester, () async {
        await _naHome(tester);

        _acionarPelaSemantica(tester, _porNome(_alvos(tester), 'Como jogar'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeDeProducao), findsNothing);
      }),
    );
  });

  // -------------------------------------------------------------------------
  // ONDE JOGAR
  // -------------------------------------------------------------------------
  group('Onde jogar', () {
    testWidgets(
      '7 — Voltar anuncia "Voltar"',
      (tester) => _comSemantica(tester, () async {
        await _emOndeJogar(tester);

        final voltar = _porNome(_alvos(tester), 'Voltar');
        expect(voltar.ehBotao, isTrue);
        expect(voltar.area.width, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        expect(voltar.area.height, greaterThanOrEqualTo(kAlvoMinimoDeToque));
      }),
    );

    testWidgets(
      '8 — os quatro cartões declaram papel de botão',
      (tester) => _comSemantica(tester, () async {
        await _emOndeJogar(tester);

        final cartoes = _alvos(tester).where((a) => a.nome != 'Voltar').toList();
        expect(cartoes, hasLength(4));
        for (final c in cartoes) {
          expect(c.ehBotao, isTrue, reason: 'sem papel de botão: $c');
          expect(c.nome, isNotEmpty);
        }
        expect(
          cartoes.map((c) => c.nome.split('.').first).toList(),
          ['Treino', 'Mesa por código', 'Mesa Pública', 'Mesa VIP'],
        );
      }),
    );

    testWidgets(
      '9 — modalidade bloqueada anuncia estado desabilitado',
      (tester) => _comSemantica(tester, () async {
        await _emOndeJogar(tester);

        final vm = tester
            .widget<OndeJogarScreen>(find.byType(OndeJogarScreen))
            .vm;
        final alvos = _alvos(tester);
        for (final opcao in vm.opcoes) {
          final cartao = alvos.firstWhere((a) => a.nome.startsWith(opcao.titulo));
          expect(
            cartao.desabilitado,
            opcao.bloqueado,
            reason: 'o anúncio de ${opcao.id} não bate com `bloqueado`: $cartao',
          );
        }
        // E as duas que a casca de produção lista bloqueadas, nominalmente.
        expect(
          alvos.firstWhere((a) => a.nome.startsWith('Mesa Pública')).desabilitado,
          isTrue,
        );
        expect(
          alvos.firstWhere((a) => a.nome.startsWith('Mesa VIP')).desabilitado,
          isTrue,
        );
      }),
    );

    testWidgets(
      '10 — Treino continua acionável, e o toque sai com o id certo',
      (tester) => _comSemantica(tester, () async {
        // A TELA com o CATÁLOGO DE PRODUÇÃO, e um espião no lugar do host.
        //
        // Não é a mesa que está sob julgamento aqui, é o alvo: o que precisa
        // ser provado é que o nó anunciado como botão habilitado entrega
        // `treino` — o mesmo id de antes — ao `onEscolher`. Abrir a mesa de
        // verdade traria junto o laço de bots do `mesa.dart`, que agenda
        // `Future.delayed` sem olhar `mounted` e deixa temporizador pendente
        // depois do fim do caso; o teste reprovaria por encenação, e num
        // arquivo que não tem nada a ver com a partida.
        final escolhidos = <String>[];
        _telefoneAlto(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: OndeJogarScreen(
              vm: OndeJogarDeProducao.catalogo,
              onVoltar: () {},
              onEscolher: escolhidos.add,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final treino = _alvos(tester).firstWhere(
          (a) => a.nome.startsWith('Treino'),
        );
        expect(treino.habilitado, Tristate.isTrue);

        _acionarPelaSemantica(tester, treino);
        await tester.pump();
        expect(escolhidos, ['treino']);
      }),
    );

    testWidgets(
      '10b — e o host continua mandando Treino para a mesa',
      (tester) => _comSemantica(tester, () async {
        await _emOndeJogar(tester);
        await tester.tap(find.text('Treino'), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MesaScreen), findsOneWidget);

        // O laço de bots do `mesa.dart` roda em `Future.delayed` e não olha
        // `mounted`: ele termina quando a vez volta a ser do jogador. Deixar o
        // tempo virtual correr COM A ÁRVORE DE PÉ o esgota; desmontar antes
        // disso o deixaria batendo num estado morto.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await _desmontar(tester);
      }),
    );

    testWidgets(
      '11 — a semântica não liberou nem bloqueou nenhum destino',
      (tester) => _comSemantica(tester, () async {
        final b = await _emOndeJogar(tester);

        // Bloqueada: avisa e NÃO navega.
        await tester.tap(find.text('Mesa Pública'), warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(milliseconds: 120));
        expect(find.byType(OndeJogarScreen), findsOneWidget);
        expect(find.textContaining('ainda não está disponível'), findsOneWidget);

        await tester.tap(find.text('Mesa VIP'), warnIfMissed: false);
        await tester.pumpAndSettle(const Duration(milliseconds: 120));
        expect(find.byType(OndeJogarScreen), findsOneWidget);

        // Liberada: navega para o LOBBY ONLINE, e não para outro lugar.
        await tester.tap(find.text('Mesa por código'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(LobbyOnline), findsOneWidget);

        // O lobby CONECTA, e o transporte arma uma espera de 15 segundos pelo
        // "autenticado" do servidor. Ela mora no `OnlineService`, e não na
        // árvore — desmontar não a cancela. Responder cancela.
        b.canal.servidorEnvia({'tipo': 'autenticado'});
        await tester.pumpAndSettle();
        await _desmontar(tester);
      }),
    );
  });

  // -------------------------------------------------------------------------
  // PERFIL
  // -------------------------------------------------------------------------
  group('Perfil', () {
    testWidgets(
      '12 — trocar avatar tem nome e alvo mínimo',
      (tester) => _comSemantica(tester, () async {
        await _noPerfil(tester);

        final alvo = _porNome(_alvos(tester), 'Trocar avatar');
        expect(alvo.ehBotao, isTrue);
        expect(alvo.area.width, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        expect(alvo.area.height, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        // O nome diz a AÇÃO, e não a forma do ícone.
        expect(alvo.nome.toLowerCase(), isNot(contains('câmera')));
      }),
    );

    testWidgets(
      '13 — editar apelido tem nome e alvo mínimo',
      (tester) => _comSemantica(tester, () async {
        await _noPerfil(tester);

        final alvo = _porNome(_alvos(tester), 'Editar apelido');
        expect(alvo.ehBotao, isTrue);
        expect(alvo.area.width, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        expect(alvo.area.height, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        expect(alvo.nome.toLowerCase(), isNot(contains('lápis')));
      }),
    );

    testWidgets(
      '14 — fechar presentes tem nome e alvo mínimo',
      (tester) => _comSemantica(tester, () async {
        await _perfilCompleto(tester);
        await tester.tap(find.text('🎁 Meus Presentes'), warnIfMissed: false);
        await tester.pumpAndSettle();

        final fechar = _porNome(_alvos(tester), 'Fechar presentes');
        expect(fechar.ehBotao, isTrue);
        expect(fechar.area.width, greaterThanOrEqualTo(kAlvoMinimoDeToque));
        expect(fechar.area.height, greaterThanOrEqualTo(kAlvoMinimoDeToque));
      }),
    );

    testWidgets(
      '15 — os botões superiores têm alvo mínimo',
      (tester) => _comSemantica(tester, () async {
        await _noPerfil(tester);
        final alvos = _alvos(tester);

        for (final nome in ['Voltar', 'Configurações']) {
          final a = _porNome(alvos, nome);
          expect(a.ehBotao, isTrue, reason: '$a');
          expect(
            a.area.width,
            greaterThanOrEqualTo(kAlvoMinimoDeToque),
            reason: '$a',
          );
          expect(
            a.area.height,
            greaterThanOrEqualTo(kAlvoMinimoDeToque),
            reason: '$a',
          );
        }
      }),
    );

    testWidgets(
      '16 — a tela cheia respeita o piso: presentes, conquistas e ações',
      (tester) => _comSemantica(tester, () async {
        await _perfilCompleto(tester);

        final alvos = _alvos(tester).where((a) => !_ehDoFramework(a)).toList();
        // Presentes, última conquista, oito troféus, duas ações de seção,
        // dois botões, quatro da barra e os três do topo/herói.
        expect(alvos.length, greaterThan(15));
        for (final a in alvos) {
          expect(
            a.area.height,
            greaterThanOrEqualTo(kAlvoMinimoDeToque),
            reason: '$a',
          );
          expect(
            a.area.width,
            greaterThanOrEqualTo(kAlvoMinimoDeToque),
            reason: '$a',
          );
        }
      }),
    );

    testWidgets(
      '16b — os controles sociais do perfil visitado respeitam o piso',
      (tester) => _comSemantica(tester, () async {
        await _noPerfilVisitado(tester);

        // A faixa social só existe no perfil de OUTRA pessoa, e o botão que
        // ela desenha vem das ações que a autoridade ofereceu.
        final social = _porNome(_alvos(tester), 'Adicionar');
        expect(social.ehBotao, isTrue);
        expect(
          social.area.height,
          greaterThanOrEqualTo(kAlvoMinimoDeToque),
          reason: 'o botão social mede menos que o piso: $social',
        );
        expect(social.area.width, greaterThanOrEqualTo(kAlvoMinimoDeToque));
      }),
    );

    testWidgets(
      '17 — abrir e fechar a folha de presentes continua funcionando',
      (tester) => _comSemantica(tester, () async {
        final apertados = await _perfilCompleto(tester);

        await tester.tap(find.text('🎁 Meus Presentes'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(apertados, contains('abrirPresentes'));
        expect(
          find.text('Presentes que você recebeu dos amigos e fãs 💜'),
          findsOneWidget,
        );

        // Fecha PELO LEITOR DE TELA — o caminho que a correção tocou.
        _acionarPelaSemantica(
          tester,
          _porNome(_alvos(tester), 'Fechar presentes'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Presentes que você recebeu dos amigos e fãs 💜'),
          findsNothing,
        );
        expect(apertados, contains('fecharPresentes'));
      }),
    );

    testWidgets(
      '17b — os callbacks do Perfil continuam os mesmos',
      (tester) => _comSemantica(tester, () async {
        final apertados = await _perfilCompleto(tester);
        final alvos = _alvos(tester);

        for (final par in const <List<String>>[
          ['Trocar avatar', 'trocarAvatar'],
          ['Editar apelido', 'editarNick'],
          ['Voltar', 'voltar'],
          ['Configurações', 'config'],
          ['Editar perfil', 'editarPerfil'],
          ['Compartilhar', 'compartilhar'],
        ]) {
          _acionarPelaSemantica(tester, _porNome(alvos, par[0]));
          await tester.pump();
          expect(apertados, contains(par[1]), reason: 'o toque em ${par[0]} sumiu');
        }
      }),
    );
  });

  // -------------------------------------------------------------------------
  // TROCAR AVATAR — O ALVO REAL, MEDIDO COM O DEDO  (OS 36-C1)
  // -------------------------------------------------------------------------
  //
  // POR QUE ESTE GRUPO EXISTE, SE O CASO 14 JÁ MEDIA 48
  //
  // Porque o caso 14 mede o RETÂNGULO DO NÓ SEMÂNTICO, e retângulo não é área
  // tocável. Este botão declarava 48x48 e entregava 42x45: a caixa estava
  // deslocada para fora do `Stack` de 126 pontos por um `Positioned` negativo,
  // e `clipBehavior: Clip.none` deixa PINTAR fora do pai mas não deixa RECEBER
  // TOQUE fora dele. Três dos quatro cantos não chegavam ao callback, e nenhuma
  // medida de retângulo — nem `SemanticsAction.tap` disparada na árvore — vê
  // isso. Só o dedo vê.
  //
  // A RÉGUA AQUI É LITERAL, E ISSO É PARTE DO CONTRATO
  //
  // Todo número deste grupo é escrito à mão: `48.0` e `34.0`. É PROIBIDO trocar
  // qualquer um deles por `kAlvoMinimoDeToque`, por um getter de produção ou
  // pelo tamanho medido do próprio widget. O motivo é aritmético: se a régua for
  // o mesmo símbolo que dimensiona a caixa, baixá-lo de 48 para 46 encolhe o
  // produto E a expectativa na mesma proporção, e o portão aprova a própria
  // derrota. Foi assim que a folha anterior passou com 46.
  //
  // OBRIGAÇÃO PENDENTE, PARA QUEM COMPUSER ESTA FOLHA
  //
  // Apagar este arquivo continua deixando o CI verde: o agregador do
  // `ci-os-integracao.yml` trata suíte ausente como NÃO EXECUTADO e não soma
  // falha. Isso é dívida da base, e não se conserta aqui — consertá-la exigiria
  // um verificador paralelo, que esta OS proíbe. Na composição, este arquivo
  // TEM de entrar na fonte única de gates da arquitetura P
  // (`scripts/ci/gates_os_integracao.txt`, com `suite`, `sha256`, `provas` e
  // `casos`), que é onde a ausência e o esvaziamento passam a reprovar.
  group('Trocar avatar — alvo real', () {
    /// O piso, escrito à mão. Não importar de `lib/`. Ver o comentário acima.
    const piso = 48.0;

    /// O diâmetro do disco dourado, escrito à mão.
    const disco = 34.0;

    /// Quanto para dentro da borda os toques caem.
    ///
    /// Meio ponto: perto o bastante da borda matemática para não tocá-la, e
    /// pequeno o bastante para que uma caixa de 46 deixe os cantos de fora — é
    /// esta folga que faz a mutação 48 → 46 ficar vermelha pelo TOQUE, e não só
    /// pela conta.
    const dentro = 0.5;

    /// Os cinco pontos de uma caixa de [piso] centrada em [centro].
    ///
    /// A caixa é construída com o literal, e não com o tamanho medido: quando o
    /// controle encolhe, os pontos continuam onde um alvo de 48 os teria, e o
    /// toque cai fora.
    List<Offset> cincoPontos(Offset centro) {
      final r = Rect.fromCenter(center: centro, width: piso, height: piso);
      return <Offset>[
        r.center,
        Offset(r.left + dentro, r.top + dentro),
        Offset(r.right - dentro, r.top + dentro),
        Offset(r.left + dentro, r.bottom - dentro),
        Offset(r.right - dentro, r.bottom - dentro),
      ];
    }

    Finder oIcone() => find.byIcon(Icons.photo_camera_rounded);

    testWidgets(
      '25 — um nó só, com nome, papel e disponibilidade',
      (tester) => _comSemantica(tester, () async {
        await _perfilCompleto(tester);
        final alvos = _alvos(tester);

        final comEsseNome =
            alvos.where((a) => a.nome == 'Trocar avatar').toList();
        expect(
          comEsseNome,
          hasLength(1),
          reason: 'o alvo aumentado não pode virar dois nós: $comEsseNome',
        );
        final alvo = comEsseNome.single;
        expect(alvo.nome, 'Trocar avatar');
        expect(alvo.ehBotao, isTrue);
        expect(alvo.habilitado, Tristate.isTrue);
        expect(alvo.aciona, isTrue);
      }),
    );

    testWidgets(
      '26 — o alvo anunciado mede 48 e cabe inteiro dentro do pai',
      (tester) => _comSemantica(tester, () async {
        await _perfilCompleto(tester);
        final alvo = _porNome(_alvos(tester), 'Trocar avatar');

        // Literais. Ver o cabeçalho do grupo.
        expect(alvo.area.width, greaterThanOrEqualTo(piso), reason: '$alvo');
        expect(alvo.area.height, greaterThanOrEqualTo(piso), reason: '$alvo');

        // E cabe dentro da caixa que hit-testa: um `Stack` recusa o toque fora
        // do próprio `size`, e é isso que transformava 48 declarados em 42x45.
        final pai = tester.getRect(
          find.ancestor(of: oIcone(), matching: find.byType(Stack)).first,
        );
        expect(
          _contem(pai, alvo.area),
          isTrue,
          reason: 'o alvo $alvo transborda o pai hit-testável $pai',
        );
      }),
    );

    testWidgets(
      '27 — os quatro cantos e o centro respondem ao DEDO, uma vez cada',
      (tester) => _comSemantica(tester, () async {
        final apertados = await _perfilCompleto(tester);
        final alvo = _porNome(_alvos(tester), 'Trocar avatar');

        final pontos = cincoPontos(alvo.area.center);
        for (final p in pontos) {
          apertados.clear();
          // `tapAt`, e nunca `performAction`: a ação semântica é entregue pelo
          // id do nó e passa por cima do teste de toque. Ela responderia certo
          // com o defeito de pé.
          await tester.tapAt(p);
          await tester.pump();
          expect(
            apertados,
            ['trocarAvatar'],
            reason:
                'toque em $p devia acionar Trocar avatar exatamente uma vez, '
                'e sem acionar vizinho; veio $apertados',
          );
        }
        expect(pontos, hasLength(5));
      }),
    );

    testWidgets(
      '28 — toque imediatamente fora não aciona o controle',
      (tester) => _comSemantica(tester, () async {
        final apertados = await _perfilCompleto(tester);
        final r = _porNome(_alvos(tester), 'Trocar avatar').area;

        final fora = <Offset>[
          Offset(r.left - 1, r.center.dy),
          Offset(r.right + 1, r.center.dy),
          Offset(r.center.dx, r.top - 1),
          Offset(r.center.dx, r.bottom + 1),
        ];
        for (final p in fora) {
          apertados.clear();
          await tester.tapAt(p);
          await tester.pump();
          expect(
            apertados,
            isEmpty,
            reason: 'o ponto $p está fora do alvo e mesmo assim acionou '
                '$apertados',
          );
        }
      }),
    );

    testWidgets(
      '29 — o disco continua com 34 e no mesmo lugar',
      (tester) => _comSemantica(tester, () async {
        await _perfilCompleto(tester);

        final rDisco = tester.getRect(
          find.ancestor(of: oIcone(), matching: find.byType(Container)).first,
        );
        final rPai = tester.getRect(
          find.ancestor(of: oIcone(), matching: find.byType(Stack)).first,
        );

        // Tamanho: literal.
        expect(rDisco.width, disco);
        expect(rDisco.height, disco);
        // Posição dentro do pai: o disco sempre esteve a 4 do topo e a 1 da
        // direita. Crescer o alvo não pode movê-lo nem meio ponto.
        expect(rDisco.top - rPai.top, 4.0);
        expect(rPai.right - rDisco.right, 1.0);
        // E o disco está inteiro dentro do alvo tocável.
        final alvo = _porNome(_alvos(tester), 'Trocar avatar').area;
        expect(_contem(alvo, rDisco), isTrue, reason: '$alvo não cobre $rDisco');
      }),
    );

    testWidgets(
      '30 — foco real: teclado alcança e Enter aciona',
      (tester) => _comSemantica(tester, () async {
        final apertados = await _perfilCompleto(tester);

        final ink =
            find.ancestor(of: oIcone(), matching: find.byType(InkWell)).first;
        final focos = find.descendant(of: ink, matching: find.byType(Focus));
        expect(
          focos,
          findsWidgets,
          reason: 'o controle perdeu o nó de foco: sem teclado, sem D-pad, '
              'sem switch access',
        );

        final no = Focus.of(tester.element(oIcone()));
        expect(no.canRequestFocus, isTrue);
        expect(no.skipTraversal, isFalse);

        no.requestFocus();
        await tester.pump();
        expect(no.hasPrimaryFocus, isTrue);

        apertados.clear();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(apertados, ['trocarAvatar'], reason: 'Enter não acionou');
      }),
    );

    testWidgets(
      '31 — na casca de produção, os cinco pontos abrem o aviso',
      (tester) => _comSemantica(tester, () async {
        await _noPerfil(tester);
        final alvo = _porNome(_alvos(tester), 'Trocar avatar');
        expect(alvo.area.width, greaterThanOrEqualTo(piso));
        expect(alvo.area.height, greaterThanOrEqualTo(piso));

        for (final p in cincoPontos(alvo.area.center)) {
          await tester.tapAt(p);
          await tester.pump();
          expect(
            find.textContaining('Trocar avatar'),
            findsOneWidget,
            reason: 'o toque em $p não chegou ao callback de produção',
          );
          // O aviso some sozinho; esperar para o próximo ponto começar limpo.
          await tester.pumpAndSettle(const Duration(milliseconds: 1400));
        }
      }),
    );
  });

  // -------------------------------------------------------------------------
  // MATRIZ COMUM — o mesmo julgamento nas três superfícies
  // -------------------------------------------------------------------------
  //
  // Um caso POR TELA, e não um caso que atravessa as três: montar três
  // aplicativos dentro do mesmo `testWidgets` deixa o segundo herdando os
  // temporizadores do primeiro, e o que reprova é o arnês.
  for (final tela in const ['Home', 'Onde jogar', 'Perfil']) {
    group('matriz comum — $tela', () {
      Future<void> abrir(WidgetTester tester) async {
        switch (tela) {
          case 'Home':
            await _naHome(tester);
          case 'Onde jogar':
            await _emOndeJogar(tester);
          default:
            await _noPerfil(tester);
        }
      }

      testWidgets(
        '18 — nenhum alvo tocável tem rótulo vazio',
        (tester) => _comSemantica(tester, () async {
          await abrir(tester);
          final alvos = _alvos(tester);
          expect(alvos, isNotEmpty, reason: '$tela sem alvo nenhum?');
          for (final a in alvos) {
            expect(a.nome, isNotEmpty, reason: '$tela: alvo anônimo $a');
          }
        }),
      );

      testWidgets(
        '19 — nenhum alvo tocável deixa de declarar o papel',
        (tester) => _comSemantica(tester, () async {
          await abrir(tester);
          for (final a in _alvos(tester)) {
            expect(a.ehBotao, isTrue, reason: '$tela: sem papel $a');
          }
        }),
      );

      testWidgets(
        '20 — nenhum alvo mede menos de 48 pontos',
        (tester) => _comSemantica(tester, () async {
          await abrir(tester);
          for (final a in _alvos(tester).where((a) => !_ehDoFramework(a))) {
            expect(
              a.area.height,
              greaterThanOrEqualTo(kAlvoMinimoDeToque),
              reason: '$tela: baixo demais $a',
            );
            expect(
              a.area.width,
              greaterThanOrEqualTo(kAlvoMinimoDeToque),
              reason: '$tela: estreito demais $a',
            );
          }
        }),
      );

      testWidgets(
        '21 — nenhuma sobreposição desvia o toque',
        (tester) => _comSemantica(tester, () async {
          await abrir(tester);
          final uteis = _alvos(tester).where((a) => !_ehDoFramework(a)).toList();
          for (var i = 0; i < uteis.length; i++) {
            for (var j = i + 1; j < uteis.length; j++) {
              final a = uteis[i].area;
              final b = uteis[j].area;
              // Conter é legítimo — o Histórico mora DENTRO do cartão do
              // jogador, e o Flutter entrega o toque ao mais interno. O que
              // não pode existir é interseção PARCIAL: ali o dedo cai num dos
              // dois sem que o desenho diga em qual.
              if (_contem(a, b) || _contem(b, a)) continue;
              expect(
                a.overlaps(b),
                isFalse,
                reason: '$tela: ${uteis[i]} e ${uteis[j]} se cruzam',
              );
            }
          }
        }),
      );

      testWidgets(
        '22 — nenhum anúncio duplicado',
        (tester) => _comSemantica(tester, () async {
          await abrir(tester);
          final alvos = _alvos(tester);

          // (a) Um controle, um nó. Dois nós acionáveis no mesmo retângulo
          // são o mesmo botão anunciado duas vezes.
          for (var i = 0; i < alvos.length; i++) {
            for (var j = i + 1; j < alvos.length; j++) {
              expect(
                alvos[i].area == alvos[j].area,
                isFalse,
                reason: '$tela: ${alvos[i]} e ${alvos[j]} são o mesmo alvo',
              );
            }
          }

          // (b) O estado não é dito duas vezes. Um nó já anunciado como
          // desabilitado não repete "em breve" nem "ainda não disponível" no
          // rótulo — foi o selo entrando na leitura junto com o estado.
          for (final a in alvos.where((a) => a.desabilitado)) {
            final texto = a.nome.toLowerCase();
            expect(texto, isNot(contains('em breve')), reason: '$tela: $a');
            expect(
              texto,
              isNot(contains('ainda não disponível')),
              reason: '$tela: $a',
            );
          }
        }),
      );

      testWidgets(
        '23 — a ordem de foco segue a ordem visual',
        (tester) => _comSemantica(tester, () async {
          await abrir(tester);
          final uteis = _alvos(tester).where((a) => !_ehDoFramework(a)).toList();
          for (var i = 1; i < uteis.length; i++) {
            final antes = uteis[i - 1].area;
            final agora = uteis[i].area;
            // Ou desce, ou é filho do anterior — o Histórico, dentro do
            // cartão, é a única exceção legítima das três telas.
            expect(
              agora.top >= antes.top - 0.5 || _contem(antes, agora),
              isTrue,
              reason: '$tela: ${uteis[i]} vem depois de ${uteis[i - 1]}',
            );
          }
        }),
      );
    });
  }

  testWidgets(
    '24 — as três telas continuam desenhando o que desenhavam',
    (tester) => _comSemantica(tester, () async {
      await _naHome(tester);
      expect(find.text('MENU'), findsOneWidget);
      expect(find.text('Ana'), findsWidgets);
      expect(find.text('em breve'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    '24b — Onde jogar continua desenhando o cadeado e as quatro opções',
    (tester) => _comSemantica(tester, () async {
      await _emOndeJogar(tester);
      expect(find.text('Onde jogar'), findsOneWidget);
      expect(find.text('Escolha a mesa pra começar a partida 🃏'), findsOneWidget);
      expect(find.text('🔒 Ainda não disponível'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }),
  );

  testWidgets(
    '24c — o Perfil continua desenhando a vitrine e o nome',
    (tester) => _comSemantica(tester, () async {
      await _noPerfil(tester);
      expect(find.text('VITRINE EQUIPADA'), findsOneWidget);
      expect(find.text('Ana'), findsWidgets);
      expect(tester.takeException(), isNull);
    }),
  );
}

/// `a` contém `b` por inteiro?
bool _contem(Rect a, Rect b) =>
    b.left >= a.left - 0.01 &&
    b.top >= a.top - 0.01 &&
    b.right <= a.right + 0.01 &&
    b.bottom <= a.bottom + 0.01;

/// O nome com que a grade anuncia um item — a mesma regra do rótulo da tela.
String _nomeDoItem(MenuItem item) {
  final badge = item.badge;
  if (badge == null || badge.isEmpty) return item.label;
  return '${item.label}, $badge';
}
