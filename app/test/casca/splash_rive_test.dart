// splash_rive_test.dart — a abertura alternativa da Rive, sob prova.
//
// ===========================================================================
// O QUE ESTA SUÍTE EXISTE PARA IMPEDIR
// ===========================================================================
//
// Uma abertura bonita que decide para onde o aplicativo vai. É o defeito
// natural desta OS, porque é o desenho mais fácil de escrever: a animação
// termina, ela navega. Funciona na máquina de quem escreveu e falha em toda
// máquina onde a arte demora, falha ou não existe — e falha do pior jeito, com
// o aplicativo aberto e parado, sem nada para apertar.
//
// Então a suíte prova as duas metades:
//
//   * COMPORTAMENTO — com a variante da Rive ligada, o destino continua sendo
//     decidido pela sessão, inclusive quando a arte falha, demora para sempre
//     ou nunca existiu;
//   * AUSÊNCIA — a tela da Rive não conhece autenticação, não navega pela
//     casca, não alcança maquete, e o pacote da Rive continua contido num
//     arquivo só.
//
// O QUE É CÓDIGO DE PRODUÇÃO AQUI: a raiz, a casca, a sessão, a ponte, o
// transporte e a própria `SplashRiveScreen`. Falsa é só a FONTE DA ARTE, que é
// a porta estreita criada exatamente para isto — o runtime nativo da Rive não
// aceita instruções sobre como falhar, e sem uma costura os quatro casos de
// falha desta OS seriam indemonstráveis.
//
// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, paisagem de
// desktop, e faz tela de celular estourar em overflow.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/home_de_producao.dart';
import 'package:buraco_master_vip/casca/login_de_producao.dart';
import 'package:buraco_master_vip/casca/raiz_do_aplicativo.dart';
import 'package:buraco_master_vip/casca/splash/fonte_da_animacao_rive.dart';
import 'package:buraco_master_vip/casca/splash/splash_rive_screen.dart';
import 'package:buraco_master_vip/casca/splash/variante_de_splash.dart';
import 'package:buraco_master_vip/screens/splash_oficial_screen.dart';
import 'package:buraco_master_vip/services/online_service.dart';
import 'package:buraco_master_vip/services/ponte_sessao_online.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

import 'bancada_online.dart';

// ===========================================================================
// As fontes de arte encenadas
// ===========================================================================

/// A arte que o teste enxerga quando ela entra na tela.
class _ArteFalsa extends StatelessWidget {
  const _ArteFalsa();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// Uma fonte cujo comportamento o teste escolhe.
///
/// Um objeto só para os cinco casos, em vez de cinco classes, porque o que
/// muda entre eles é uma decisão — e o CONTADOR precisa ser o mesmo em todos
/// para que "carregou uma vez" seja uma pergunta respondível.
class _FonteEncenada extends FonteDaAnimacaoRive {
  _FonteEncenada.entrega() : _modo = _Modo.entrega;
  _FonteEncenada.falha([this.motivo = 'asset ausente']) : _modo = _Modo.falha;
  _FonteEncenada.explode() : _modo = _Modo.explode;
  _FonteEncenada.nuncaResponde() : _modo = _Modo.nuncaResponde;
  _FonteEncenada.sobDemanda() : _modo = _Modo.sobDemanda;

  final _Modo _modo;
  String motivo = '';

  /// Quantas vezes alguém pediu a arte. É o número de "carregado uma só vez".
  int pedidos = 0;

  /// Quantas vezes a arte entregue foi devolvida ao sistema.
  int descartes = 0;

  final List<Completer<AnimacaoRivePronta>> _pendentes = [];

  @override
  Future<AnimacaoRivePronta> carregar() {
    pedidos++;
    switch (_modo) {
      case _Modo.entrega:
        return Future<AnimacaoRivePronta>.value(_arte());
      case _Modo.falha:
        return Future<AnimacaoRivePronta>.error(FalhaAoCarregarRive(motivo));
      case _Modo.explode:
        // De propósito NÃO é `FalhaAoCarregarRive`: prova que a tela cobre
        // também o que a porta não prometeu.
        return Future<AnimacaoRivePronta>.error(StateError('runtime explodiu'));
      case _Modo.nuncaResponde:
        return Completer<AnimacaoRivePronta>().future;
      case _Modo.sobDemanda:
        final c = Completer<AnimacaoRivePronta>();
        _pendentes.add(c);
        return c.future;
    }
  }

  /// Entrega a arte de uma chamada que ficou pendurada.
  void entregarAgora() => _pendentes.removeAt(0).complete(_arte());

  AnimacaoRivePronta _arte() => AnimacaoRivePronta(
    construir: (_) => const _ArteFalsa(),
    descartar: () => descartes++,
  );
}

enum _Modo { entrega, falha, explode, nuncaResponde, sobDemanda }

// ===========================================================================
// A bancada, com a variante escolhível
// ===========================================================================

class _BancadaDaSplash {
  _BancadaDaSplash({
    String? uidInicial,
    required this.fonteDaArte,
    this.variante = VarianteDeSplash.rive,
    this.duracaoDaAbertura = const Duration(milliseconds: 20),
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
      abrirCanal: (_) => CanalFalso(),
    );
    autenticacao = AutenticacaoFalsa(fluxo);
  }

  final fluxo = StreamController<String?>.broadcast();
  final fonte = FonteFalsa();
  final credenciais = CredencialFalsa();
  final _FonteEncenada fonteDaArte;
  final VarianteDeSplash variante;
  final Duration duracaoDaAbertura;

  late final SessaoDoJogador sessao;
  late final OnlineService online;
  late final AutenticacaoFalsa autenticacao;

  /// A última medição publicada pela abertura. Nula até ela terminar.
  MedicaoDaSplashRive? medicao;

  /// Quantas medições chegaram. Uma abertura publica exatamente uma.
  int medicoes = 0;

  Widget get aplicativo => RaizDoAplicativo(
    sessao: sessao,
    autenticacao: autenticacao,
    online: online,
    duracaoDaSplash: duracaoDaAbertura,
    somNaSplash: false,
    limiteDeResolucao: const Duration(seconds: 8),
    varianteDaSplash: variante,
    fonteDaSplashRive: fonteDaArte,
    onMedicaoDaSplash: (m) {
      medicoes++;
      medicao = m;
    },
  );

  void fechar() {
    online.dispose();
    sessao.dispose();
    fluxo.close();
  }
}

Future<void> _abrir(WidgetTester tester, _BancadaDaSplash b) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(b.aplicativo);
  await tester.pump(); // primeiro quadro da abertura
}

/// Deixa a abertura terminar e o roteamento assentar.
Future<void> _passarAAbertura(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 40));
  await tester.pumpAndSettle();
}

// ===========================================================================
// Ferramentas da auditoria estrutural
// ===========================================================================

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

/// O arquivo SEM comentários, respeitando aspas.
///
/// A mesma técnica de `auditoria_casca_test.dart`, e pelo mesmo motivo: este
/// próprio módulo explica em prosa o que é proibido, e uma varredura ingênua
/// acusaria a explicação como violação. Pior: o jeito de "consertar" seria
/// apagar a documentação.
String _codigo(File f) {
  final fonte = f.readAsStringSync();
  final saida = StringBuffer();
  var i = 0;
  String? aspa;
  while (i < fonte.length) {
    final c = fonte[i];
    final proximo = i + 1 < fonte.length ? fonte[i + 1] : '';

    if (aspa != null) {
      saida.write(c);
      if (c == r'\') {
        if (proximo.isNotEmpty) saida.write(proximo);
        i += 2;
        continue;
      }
      if (c == aspa) aspa = null;
      i++;
      continue;
    }

    if (c == '/' && proximo == '/') {
      while (i < fonte.length && fonte[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && proximo == '*') {
      i += 2;
      while (i < fonte.length &&
          !(fonte[i] == '*' && i + 1 < fonte.length && fonte[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') aspa = c;
    saida.write(c);
    i++;
  }
  return saida.toString();
}

List<File> _fontesDoCliente() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final n = _barras(f.path);
          return !n.contains('/social/') &&
              !n.contains('/moderacao/') &&
              !n.endsWith('js_bridge.dart');
        })
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

const _arquivosDaSplashRive = [
  'lib/casca/splash/variante_de_splash.dart',
  'lib/casca/splash/fonte_da_animacao_rive.dart',
  'lib/casca/splash/fonte_rive_real.dart',
  'lib/casca/splash/splash_rive_screen.dart',
];

void main() {
  // =========================================================================
  // 1 — o destino continua sendo da sessão
  // =========================================================================
  group('com a Rive ligada, quem decide o destino é a sessão', () {
    testWidgets('não autenticado vai para o Login', (tester) async {
      final b = _BancadaDaSplash(fonteDaArte: _FonteEncenada.entrega());
      addTearDown(b.fechar);

      await _abrir(tester, b);
      expect(find.byType(SplashRiveScreen), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);

      b.fluxo.add(null); // o fluxo se pronuncia: não há ninguém
      await _passarAAbertura(tester);

      expect(find.byType(LoginDeProducao), findsOneWidget);
      expect(find.byType(HomeDeProducao), findsNothing);
      expect(find.byType(SplashRiveScreen), findsNothing);
    });

    testWidgets('autenticado vai para a Home', (tester) async {
      final b = _BancadaDaSplash(
        uidInicial: 'uid-A',
        fonteDaArte: _FonteEncenada.entrega(),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      expect(find.byType(SplashRiveScreen), findsOneWidget);

      await _passarAAbertura(tester);

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);
    });

    testWidgets('a arte FALHA e o roteamento continua igual', (tester) async {
      final arte = _FonteEncenada.falha('o runtime não subiu');
      final b = _BancadaDaSplash(uidInicial: 'uid-A', fonteDaArte: arte);
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await _passarAAbertura(tester);

      // O caso inteiro numa linha: a arte não entrou, e a pessoa chegou onde a
      // sessão dela mandava.
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(b.medicao?.usouFallback, isTrue);
      expect(b.medicao?.motivoDaFalha, 'o runtime não subiu');
    });

    testWidgets('a arte EXPLODE com erro não previsto e o destino é o mesmo', (
      tester,
    ) async {
      final b = _BancadaDaSplash(
        uidInicial: 'uid-A',
        fonteDaArte: _FonteEncenada.explode(),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await _passarAAbertura(tester);

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(b.medicao?.usouFallback, isTrue);
      expect(b.medicao?.motivoDaFalha, contains('falha inesperada'));
    });

    testWidgets('a arte NUNCA RESPONDE e a abertura termina assim mesmo', (
      tester,
    ) async {
      // O caso que separa uma abertura de um travamento. Não há evento nenhum
      // vindo da arte — nem sucesso, nem falha. O relógio é o único mecanismo
      // que pode concluir, e é ele que conclui.
      final b = _BancadaDaSplash(
        uidInicial: 'uid-A',
        fonteDaArte: _FonteEncenada.nuncaResponde(),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      expect(find.byType(SplashRiveScreen), findsOneWidget);

      await _passarAAbertura(tester);

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(find.byType(SplashRiveScreen), findsNothing);
      expect(b.medicao?.usouFallback, isTrue);
      expect(b.medicao?.ateAArte, isNull);
    });
  });

  // =========================================================================
  // 2 — o fallback, e a ausência de tela branca
  // =========================================================================
  group('fallback', () {
    testWidgets('asset ausente desenha o fallback estático, não vazio', (
      tester,
    ) async {
      final b = _BancadaDaSplash(
        fonteDaArte: _FonteEncenada.falha('asset ausente'),
        duracaoDaAbertura: const Duration(seconds: 4),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await tester.pump(const Duration(milliseconds: 16));

      // A arte não está lá, e mesmo assim há conteúdo desenhado.
      expect(find.byType(_ArteFalsa), findsNothing);
      expect(find.byType(SplashRiveScreen), findsOneWidget);
      expect(find.text('BURACO MASTER VIP'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('o fallback já está no PRIMEIRO quadro, antes de carregar', (
      tester,
    ) async {
      // Sem isto, o arranque frio pisca branco — justamente quando o
      // carregamento demora mais.
      final arte = _FonteEncenada.sobDemanda();
      final b = _BancadaDaSplash(
        fonteDaArte: arte,
        duracaoDaAbertura: const Duration(seconds: 4),
      );
      addTearDown(b.fechar);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(b.aplicativo);

      // UM único quadro. A arte ainda está pendurada.
      expect(find.byType(_ArteFalsa), findsNothing);
      expect(find.text('BURACO MASTER VIP'), findsOneWidget);
    });

    testWidgets('quando a arte chega, ela entra por cima do fallback', (
      tester,
    ) async {
      final arte = _FonteEncenada.sobDemanda();
      final b = _BancadaDaSplash(
        fonteDaArte: arte,
        duracaoDaAbertura: const Duration(seconds: 4),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      expect(find.byType(_ArteFalsa), findsNothing);

      arte.entregarAgora();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(_ArteFalsa), findsOneWidget);
      // O fallback continua embaixo — é ele que preenche o que a arte não
      // cobrir, e some junto com a tela.
      expect(find.text('BURACO MASTER VIP'), findsOneWidget);
    });
  });

  // =========================================================================
  // 3 — o relógio conclui a APRESENTAÇÃO, e nada além disso
  // =========================================================================
  group('o relógio não decide autenticação', () {
    testWidgets('a abertura termina e a espera continua, sem sessão', (
      tester,
    ) async {
      // O relógio disse "a animação acabou". Se ele decidisse destino, o
      // aplicativo iria para o Login aqui — e mostraria Login para quem talvez
      // esteja logada, porque a sessão ainda não respondeu.
      final b = _BancadaDaSplash(fonteDaArte: _FonteEncenada.entrega());
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));

      expect(b.medicoes, 1, reason: 'a abertura terminou');
      expect(b.sessao.resolvida, isFalse, reason: 'e a sessão não respondeu');

      expect(find.byType(SplashRiveScreen), findsOneWidget);
      expect(find.byType(LoginDeProducao), findsNothing);
      expect(find.byType(HomeDeProducao), findsNothing);

      // Só agora, com a resposta da sessão, o destino aparece.
      b.fluxo.add('uid-A');
      await _passarAAbertura(tester);
      expect(find.byType(HomeDeProducao), findsOneWidget);
    });

    testWidgets('a sessão responde ANTES da abertura e não há corrida', (
      tester,
    ) async {
      // A ordem inversa da anterior. A abertura toca até o fim de qualquer
      // jeito: cortá-la porque a resposta chegou cedo faria a abertura durar um
      // tempo diferente a cada partida do aplicativo.
      final b = _BancadaDaSplash(
        uidInicial: 'uid-A',
        fonteDaArte: _FonteEncenada.entrega(),
        duracaoDaAbertura: const Duration(milliseconds: 300),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await tester.pump(const Duration(milliseconds: 50));

      expect(b.sessao.resolvida, isTrue, reason: 'a sessão já respondeu');
      expect(
        find.byType(SplashRiveScreen),
        findsOneWidget,
        reason: 'e a abertura continua, porque ela não foi cortada',
      );
      expect(b.medicoes, 0);

      await _passarAAbertura(tester);
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(b.medicoes, 1);
    });

    testWidgets('a abertura publica UMA medição, não uma por quadro', (
      tester,
    ) async {
      final b = _BancadaDaSplash(
        uidInicial: 'uid-A',
        fonteDaArte: _FonteEncenada.entrega(),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await _passarAAbertura(tester);

      expect(b.medicoes, 1);
    });
  });

  // =========================================================================
  // 4 — a arte é lida uma vez, e devolvida
  // =========================================================================
  group('o asset é carregado uma única vez', () {
    testWidgets('reconstruir a árvore não relê a arte', (tester) async {
      final arte = _FonteEncenada.entrega();
      final b = _BancadaDaSplash(
        fonteDaArte: arte,
        duracaoDaAbertura: const Duration(seconds: 4),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      expect(arte.pedidos, 1);

      // Vários quadros, e uma notificação da sessão que reconstrói a casca.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      b.fonte.apelido = 'Outra';
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(arte.pedidos, 1, reason: 'reconstruir não é recarregar');
    });

    testWidgets('sair da abertura devolve o que a arte tomou', (tester) async {
      final arte = _FonteEncenada.entrega();
      final b = _BancadaDaSplash(uidInicial: 'uid-A', fonteDaArte: arte);
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await _passarAAbertura(tester);

      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(arte.descartes, 1, reason: 'a arte não pode ficar pendurada');
    });

    testWidgets('a arte que chega depois da tela morrer é descartada', (
      tester,
    ) async {
      // A corrida real: a arte termina de carregar quando a abertura já saiu da
      // tela. Sem o descarte, isso vaza a cada partida do aplicativo.
      final arte = _FonteEncenada.sobDemanda();
      final b = _BancadaDaSplash(uidInicial: 'uid-A', fonteDaArte: arte);
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await _passarAAbertura(tester);
      expect(find.byType(SplashRiveScreen), findsNothing);

      arte.entregarAgora();
      await tester.pump();

      expect(arte.descartes, 1);
    });
  });

  // =========================================================================
  // 5 — a sessão não reinicia, e não há segundo dono
  // =========================================================================
  group('a abertura não mexe na sessão', () {
    testWidgets('reconstruir o aplicativo não reinicia a sessão', (
      tester,
    ) async {
      final arte = _FonteEncenada.entrega();
      final b = _BancadaDaSplash(uidInicial: 'uid-A', fonteDaArte: arte);
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await _passarAAbertura(tester);

      final geracao = b.sessao.geracao;
      final identidades = b.fonte.chamadas;

      // A MESMA árvore, montada de novo: é o que o framework faz a cada
      // reconstrução do widget de cima.
      await tester.pumpWidget(b.aplicativo);
      await tester.pump(const Duration(milliseconds: 40));

      expect(b.sessao.geracao, geracao, reason: 'a sessão não trocou');
      expect(b.fonte.chamadas, identidades, reason: 'ninguém pediu de novo');
      expect(find.byType(HomeDeProducao), findsOneWidget);
      expect(
        find.byType(SplashRiveScreen),
        findsNothing,
        reason: 'a abertura não toca de novo depois de ter tocado',
      );
    });

    testWidgets('a abertura não pede credencial nem identidade', (
      tester,
    ) async {
      final b = _BancadaDaSplash(
        fonteDaArte: _FonteEncenada.entrega(),
        duracaoDaAbertura: const Duration(seconds: 4),
      );
      addTearDown(b.fechar);

      await _abrir(tester, b);
      await tester.pump(const Duration(milliseconds: 100));

      // Enquanto a abertura está na tela e a sessão não respondeu, nada foi
      // perguntado ao provedor por causa da animação.
      expect(find.byType(SplashRiveScreen), findsOneWidget);
      expect(b.fonte.chamadas, 0);
      expect(b.credenciais.pedidos, 0);
      expect(b.autenticacao.entradas, 0);
      expect(b.autenticacao.saidas, 0);
    });
  });

  // =========================================================================
  // 6 — A/B: as duas aberturas, o mesmo contrato
  // =========================================================================
  group('comparação A/B', () {
    testWidgets('a variante oficial continua sendo o padrão', (tester) async {
      // Sem `varianteDaSplash`, a raiz usa o que o build definiu — e o build
      // sem `--dart-define` é a oficial. Um padrão trocado por descuido
      // publicaria a alternativa sem ninguém ter decidido.
      final b = _BancadaDaSplash(fonteDaArte: _FonteEncenada.entrega());
      addTearDown(b.fechar);

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RaizDoAplicativo(
          sessao: b.sessao,
          autenticacao: b.autenticacao,
          online: b.online,
          duracaoDaSplash: const Duration(milliseconds: 20),
          somNaSplash: false,
        ),
      );
      await tester.pump();

      expect(find.byType(SplashOficialScreen), findsOneWidget);
      expect(find.byType(SplashRiveScreen), findsNothing);
      expect(varianteDeSplashDoBuild, VarianteDeSplash.oficial);
    });

    testWidgets('as duas variantes chegam ao MESMO destino', (tester) async {
      // É isto que faz a comparação ser sobre a arte, e não sobre duas
      // arquiteturas diferentes disputando.
      for (final variante in VarianteDeSplash.values) {
        final b = _BancadaDaSplash(
          uidInicial: 'uid-A',
          fonteDaArte: _FonteEncenada.entrega(),
          variante: variante,
        );
        addTearDown(b.fechar);

        await _abrir(tester, b);
        await _passarAAbertura(tester);

        expect(
          find.byType(HomeDeProducao),
          findsOneWidget,
          reason: 'variante $variante levou a outro lugar',
        );
      }
    });

    testWidgets('escrita errada no build cai na oficial', (tester) async {
      expect(varianteDeSplashDoTexto('rive'), VarianteDeSplash.rive);
      expect(varianteDeSplashDoTexto('Rive'), VarianteDeSplash.oficial);
      expect(varianteDeSplashDoTexto('rivé'), VarianteDeSplash.oficial);
      expect(varianteDeSplashDoTexto(''), VarianteDeSplash.oficial);
      expect(varianteDeSplashDoTexto(null), VarianteDeSplash.oficial);
    });
  });

  // =========================================================================
  // 7 — AUSÊNCIA: o que não pode existir nesta camada
  // =========================================================================
  group('auditoria da abertura em Rive', () {
    test('a suíte tem o que ler', () {
      for (final caminho in _arquivosDaSplashRive) {
        expect(
          File(caminho).existsSync(),
          isTrue,
          reason: 'sem $caminho a auditoria inteira seria um verde falso',
        );
      }
    });

    test('a camada da splash não conhece autenticação', () {
      final infratores = <String>[];
      for (final caminho in _arquivosDaSplashRive) {
        final conteudo = _codigo(File(caminho));
        for (final termo in [
          'firebase_auth',
          'FirebaseAuth',
          'google_sign_in',
          'authStateChanges',
          'currentUser',
          'signOut(',
          'SessaoDoJogador',
          'EscopoSessao',
        ]) {
          if (conteudo.contains(termo)) infratores.add('$caminho: $termo');
        }
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'uma abertura que sabe ler sessão é uma abertura que pode decidir '
            'destino, mesmo sem hoje decidir',
      );
    });

    test('a tela da Rive não navega por conta própria pela casca', () {
      // `Navigator` existe no arquivo, e é o modo `proximaTela` — o antigo, que
      // a casca NÃO usa. O que a auditoria prende é a casca ter passado a usá-lo.
      final casca = _codigo(File('lib/casca/casca_de_producao.dart'));
      expect(
        casca,
        isNot(contains('proximaTela')),
        reason:
            'a casca precisa montar as duas aberturas pelo modo que AVISA; '
            'com proximaTela, quem escolhe a próxima tela é a animação',
      );
      expect('proximaTela'.allMatches(casca), isEmpty);
      expect(casca, contains('onConcluida: widget.onAberturaConcluida'));
    });

    test('a casca monta as DUAS aberturas, e nenhuma sumiu', () {
      final casca = _codigo(File('lib/casca/casca_de_producao.dart'));
      expect(casca, contains('SplashOficialScreen('));
      expect(casca, contains('SplashRiveScreen('));
    });

    test('o pacote rive é importado num arquivo só do cliente', () {
      final importadores = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('package:rive/')) {
          importadores.add(_barras(f.path));
        }
      }
      expect(
        importadores,
        hasLength(1),
        reason:
            'a Rive está em AVALIAÇÃO; espalhada pela casca, desistir dela '
            'vira uma caçada em vez de apagar um arquivo',
      );
      expect(importadores.single, endsWith('lib/casca/splash/fonte_rive_real.dart'));
    });

    test('a tela da abertura não conhece o pacote rive', () {
      // É o que permite provar falha, lentidão e ausência de asset sem um
      // runtime nativo quebrado dentro do `flutter test`.
      final tela = _codigo(File('lib/casca/splash/splash_rive_screen.dart'));
      expect(tela, isNot(contains('package:rive/')));
      expect(tela, isNot(contains('RiveNative')));
    });

    test('o Firebase continua sendo inicializado num lugar só', () {
      final inicializadores = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains('Firebase.initializeApp')) {
          inicializadores.add(_barras(f.path));
        }
      }
      expect(
        inicializadores,
        hasLength(1),
        reason: 'uma segunda inicialização é um segundo aplicativo Firebase',
      );
      expect(inicializadores.single, endsWith('lib/main.dart'));
    });

    test('a porta de entrada não mudou por causa desta OS', () {
      // `main.dart` tem teto de 120 linhas na auditoria da casca, e já estava
      // em 117. Uma escolha de variante escrita ali teria estourado o teto — e
      // é por isso que ela mora em `splash/variante_de_splash.dart`.
      final raiz = _codigo(File('lib/main.dart'));
      expect(raiz, isNot(contains('Splash')));
      expect(raiz, isNot(contains('rive')));
      expect(raiz, isNot(contains('Rive')));
    });

    test('nenhum arquivo da splash alcança maquete', () {
      final chamada = RegExp(r'\b[A-Z]\w*\.mock\s*\(');
      for (final caminho in _arquivosDaSplashRive) {
        expect(
          chamada.firstMatch(_codigo(File(caminho))),
          isNull,
          reason: '$caminho alcança dado de maquete',
        );
      }
    });

    test('a camada da splash não escreve em registro de saída', () {
      final infratores = <String>[];
      for (final caminho in _arquivosDaSplashRive) {
        final conteudo = _codigo(File(caminho));
        for (final termo in [r'\bprint\(', r'\bdebugPrint\(', r'\blog\(']) {
          if (RegExp(termo).hasMatch(conteudo)) {
            infratores.add('$caminho: $termo');
          }
        }
      }
      expect(infratores, isEmpty);
    });

    test('o caminho do asset é declarado num lugar só', () {
      // A constante é pública para que o `pubspec` e o portão a afirmem sem
      // uma segunda cópia literal — que é como um asset renomeado passa até
      // alguém abrir o aplicativo publicado.
      expect(kAssetDaSplashRive, 'assets/splash/splash.riv');

      final literais = <String>[];
      for (final f in _fontesDoCliente()) {
        if (_codigo(f).contains("'assets/splash/splash.riv'")) {
          literais.add(_barras(f.path));
        }
      }
      expect(literais, hasLength(1));
      expect(literais.single, endsWith('fonte_da_animacao_rive.dart'));
    });

    test('a pasta do asset está declarada no pubspec', () {
      // Sem a linha, a arte não entra no pacote e a abertura cai no fallback
      // para sempre, sem nenhum erro de compilação avisar.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/splash/'));
      expect(pubspec, contains('rive:'));
    });
  });
}
