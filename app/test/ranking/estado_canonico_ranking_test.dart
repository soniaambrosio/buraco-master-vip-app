// estado_canonico_ranking_test.dart — a prova de que a casca não inventa
// posição competitiva.
//
// ---------------------------------------------------------------------------
// O QUE ESTA SUÍTE PERSEGUE
// ---------------------------------------------------------------------------
//
// Um jogador que nunca disputou nada abria o Perfil e lia `💎 Liga Bronze ·
// #0 no mundo`. Nenhum dos dois valores vinha de autoridade alguma: eram o que
// os tipos `String` e `int` exigiam de um produtor que não tinha o dado. E o
// botão de compartilhar copiava a mesma afirmação para fora do aparelho.
//
// Os grupos abaixo cobrem as três camadas por onde aquilo passava — o valor, as
// telas e o texto público — mais as duas travas de sessão (logout e troca de
// conta) e a auditoria estrutural que impede o literal de voltar.
//
// A auditoria despoja comentários antes de varrer, pela mesma razão de
// `casca/auditoria_casca_test.dart`: este próprio arquivo cita `'Bronze'` e
// `#0` em prosa, e uma varredura ingênua acusaria a explicação como violação.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/pages/perfil_page.dart';
import 'package:buraco_master_vip/ranking/estado_ranking.dart';
import 'package:buraco_master_vip/screens/inicio_screen.dart';
import 'package:buraco_master_vip/screens/perfil_screen.dart';
import 'package:buraco_master_vip/services/perfil_service.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

/// Um [PerfilVM] com o ranking que o caso quer, e o resto irrelevante.
PerfilVM _vmCom(EstadoRanking ranking, {String nome = 'Sônia', int nivel = 7}) {
  return PerfilVM(
    ehMeuPerfil: true,
    nome: nome,
    avatar: '👑',
    mascote: '🦊',
    moldura: 'assets/perfil/vitrine_moldura.webp',
    dorso: 'assets/perfil/vitrine_dorso.webp',
    efeito: 'assets/perfil/vitrine_efeito.webp',
    nivel: nivel,
    xpAtual: 0,
    xpProximo: 1000,
    titulo: 'Novato(a)',
    tituloEmoji: '🃏',
    ranking: ranking,
    stats: const PerfilStats(
      vitorias: 0,
      partidas: 0,
      canastras: 0,
      aproveitamento: 0,
    ),
    ultimaConquista: null,
    presentesCount: 0,
    conquistas: const [],
    vitrine: const [],
    presentes: const [],
  );
}

/// Monta o [PerfilScreen] cru, sem sessão, numa superfície de telefone.
///
/// SUPERFÍCIE DE TELEFONE: o padrão do `flutter_test` é 800x600, que é paisagem
/// de desktop e faz uma tela desenhada para celular estourar em overflow.
Future<void> _montarPerfil(WidgetTester tester, PerfilVM vm) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        vm: vm,
        onVoltar: () {},
        onAbrirConfig: () {},
        onTrocarAvatar: () {},
        onEditarNick: () {},
        onEditarPerfil: () {},
        onAbrirPresentes: () {},
        onFecharPresentes: () {},
        onVerTodasConquistas: () {},
        onVerConquista: (_) {},
        onVerUltimaConquista: () {},
        onTrocarVitrine: () {},
        onCompartilhar: () {},
        onRecarregar: () {},
        onNavTap: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Todo o texto desenhado na tela, concatenado.
///
/// Afirmar sobre a string inteira é mais forte do que procurar um `find.text`
/// exato: pega o literal onde quer que ele tenha sido montado, inclusive
/// partido entre dois `Text` vizinhos.
String _textoDaTela(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

/// Fonte de identidade cuja resposta o teste troca entre as chamadas — é o que
/// torna a troca de conta A→B encenável.
class _FonteRegulavel implements FonteDeIdentidade {
  // Campos mutáveis com valor inicial, e não parâmetros de construtor: quem usa
  // esta fonte sempre começa na conta A e a REGULA para a B no meio do teste.
  String publicId = 'P0A1B2C3D4E5';
  String apelido = 'Sônia';
  int chamadas = 0;

  @override
  Future<IdentidadePublica> obterMinhaIdentidade() async {
    chamadas++;
    return IdentidadePublica(
      publicId: publicId,
      apelido: apelido,
      avatarRef: null,
      criada: false,
      estado: EstadoPerfil.ativo,
      limites: LimitesSociais.desconhecidos,
      edicao: MetadadosDeEdicao.desconhecidos,
    );
  }
}

/// O arquivo SEM comentários, respeitando aspas.
///
/// Mesma técnica de `casca/auditoria_casca_test.dart`: uma auditoria que lê
/// comentário se auto-sabota, e o jeito de "consertar" seria apagar a
/// documentação que explica o defeito.
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

/// Deixa o relógio do teste correr até a sessão responder e o [PerfilService]
/// terminar os 350ms de I/O simulado.
///
/// `pumpAndSettle` SOZINHO NÃO BASTA, e a razão é instrutiva: ele para no
/// primeiro quadro em que nada mais está agendado. O que mantinha o laço vivo
/// nesta tela era o carregamento dos oito ícones de conquista e do baú de
/// presentes — elementos que só existiam porque o Perfil desenhava dado sem
/// fonte. Retirá-los é o objetivo desta linhagem, e o efeito colateral é que o
/// tempo passou a ter de ser bombeado de propósito.
///
/// Nenhuma asserção mudou por causa disto: o que mudou é o teste parar de
/// depender, sem saber, de um elemento de tela que não deveria estar lá.
Future<void> _assentar(WidgetTester tester) async {
  // São DUAS esperas encadeadas, e não uma: a fonte de identidade responde por
  // `Future`, e só DEPOIS disso o Perfil descobre que o `publicId` mudou e
  // começa os 350ms do serviço. Bombear em rodadas cobre a cadeia inteira sem
  // depender da ordem exata em que os dois futuros se resolvem.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

String _barras(String caminho) => caminho.replaceAll(r'\', '/');

String _resolver(String deQuem, String importado) {
  if (importado.startsWith('package:buraco_master_vip/')) {
    return 'lib/${importado.substring('package:buraco_master_vip/'.length)}';
  }
  final base = _barras(deQuem).split('/')..removeLast();
  for (final parte in importado.split('/')) {
    if (parte == '.' || parte.isEmpty) continue;
    if (parte == '..') {
      if (base.isNotEmpty) base.removeLast();
      continue;
    }
    base.add(parte);
  }
  return base.join('/');
}

final RegExp _import = RegExp(r'''import\s+['"]([^'"]+)['"]''');

/// O fecho transitivo dos imports a partir de `lib/main.dart` — o que o binário
/// publicado consegue chegar a executar partindo de `main()`.
Set<String> _alcancaveisDaRaiz() {
  final vistos = <String>{};
  final fila = <String>['lib/main.dart'];
  while (fila.isNotEmpty) {
    final atual = fila.removeLast();
    if (!vistos.add(atual)) continue;
    final f = File(atual);
    if (!f.existsSync()) continue;
    for (final m in _import.allMatches(_codigo(f))) {
      final alvo = m.group(1)!;
      if (alvo.startsWith('dart:')) continue;
      if (alvo.startsWith('package:') &&
          !alvo.startsWith('package:buraco_master_vip/')) {
        continue;
      }
      fila.add(_resolver(atual, alvo));
    }
  }
  return vistos;
}

void main() {
  // =========================================================================
  // 1, 2 e 3 — o VALOR. Ausência não vira Bronze, nem zero vira colocação.
  // =========================================================================
  group('EstadoRanking — ausência é ausência', () {
    test('liga ausente não vira Bronze nem liga nenhuma', () {
      for (final estado in const [
        EstadoRanking.indisponivel(),
        EstadoRanking.carregando(),
        EstadoRanking.falha(),
        EstadoRanking.disponivel(),
      ]) {
        expect(estado.liga, isNull, reason: '$estado inventou liga');
        expect(estado.temLiga, isFalse);
        expect(
          estado.ligaParaExibicao,
          isNot(equalsIgnoringCase('Bronze')),
          reason: 'nenhuma fase pode render o fallback que esta OS removeu',
        );
        expect(estado.ligaParaExibicao, '—');
      }
    });

    test('posição ausente não vira zero', () {
      for (final estado in const [
        EstadoRanking.indisponivel(),
        EstadoRanking.carregando(),
        EstadoRanking.falha(),
        EstadoRanking.disponivel(),
      ]) {
        expect(
          estado.posicaoMundial,
          isNull,
          reason: '$estado inventou posição',
        );
        expect(estado.temPosicao, isFalse);
        expect(estado.posicaoMundial, isNot(0));
      }
    });

    test('posição zero ou negativa não é colocação válida', () {
      // O `0` era literalmente o valor que o serviço usava para dizer "não sei".
      // Se ele chegar de um backend futuro, morre AQUI — e não na tela.
      for (final crua in const [0, -1, -128]) {
        final estado = EstadoRanking.disponivel(posicaoMundial: crua);
        expect(
          estado.posicaoMundial,
          isNull,
          reason: '$crua não é uma colocação',
        );
        expect(estado.temPosicao, isFalse);
      }
    });

    test('liga vazia ou só de espaços não é liga', () {
      for (final crua in const ['', '   ', '\t']) {
        expect(EstadoRanking.disponivel(liga: crua).liga, isNull);
      }
    });

    test('fase disponível sem dado nenhum é resposta legítima, e não afirma', () {
      // O jogador recém-chegado que a autoridade conhece e que ainda não entrou
      // na tabela: há resposta, e mesmo assim não há o que exibir.
      const estado = EstadoRanking.disponivel();
      expect(estado.fase, FaseRanking.disponivel);
      expect(estado.temAlgumDado, isFalse);
    });

    test('dados reais atravessam intactos', () {
      const estado = EstadoRanking.disponivel(
        liga: 'Diamante',
        posicaoMundial: 128,
      );
      expect(estado.liga, 'Diamante');
      expect(estado.ligaParaExibicao, 'Diamante');
      expect(estado.posicaoMundial, 128);
      expect(estado.temAlgumDado, isTrue);
    });

    test('liga real sem posição preserva só a informação válida', () {
      const estado = EstadoRanking.disponivel(liga: 'Ouro');
      expect(estado.liga, 'Ouro');
      expect(estado.posicaoMundial, isNull);
      expect(estado.temAlgumDado, isTrue);
    });

    test('as quatro fases são distintas', () {
      // Não pode ser `const`: um `Set` constante exige igualdade primitiva, e
      // `EstadoRanking` define a sua própria — que é justamente o que o teste
      // quer exercitar.
      final fases = <EstadoRanking>{
        const EstadoRanking.indisponivel(),
        const EstadoRanking.carregando(),
        const EstadoRanking.falha(),
        const EstadoRanking.disponivel(),
      };
      expect(
        fases,
        hasLength(4),
        reason: 'colapsar fases foi o que gerou o defeito',
      );
    });
  });

  // =========================================================================
  // 4, 5 e 6 — a TELA do Perfil.
  // =========================================================================
  group('PerfilScreen — o que é desenhado', () {
    testWidgets(
      'ranking indisponível produz estado neutro, sem Bronze nem #0',
      (tester) async {
        await _montarPerfil(tester, _vmCom(const EstadoRanking.indisponivel()));

        final texto = _textoDaTela(tester);
        expect(texto, isNot(contains('Bronze')));
        expect(texto, isNot(contains('#0')));
        expect(texto, isNot(contains('no mundo')));
        // O rótulo fica no lugar — a ausência é admitida, não escondida.
        expect(find.text('💎 Liga'), findsOneWidget);
        expect(find.text('—'), findsWidgets);
      },
    );

    testWidgets('carregando e falha também não afirmam nada', (tester) async {
      for (final estado in const [
        EstadoRanking.carregando(),
        EstadoRanking.falha(),
      ]) {
        await _montarPerfil(tester, _vmCom(estado));
        final texto = _textoDaTela(tester);
        expect(texto, isNot(contains('Bronze')), reason: '$estado');
        expect(texto, isNot(contains('no mundo')), reason: '$estado');
      }
    });

    testWidgets('liga real sem posição mostra só a liga', (tester) async {
      await _montarPerfil(
        tester,
        _vmCom(const EstadoRanking.disponivel(liga: 'Ouro')),
      );

      expect(find.text('Ouro'), findsOneWidget);
      expect(_textoDaTela(tester), isNot(contains('no mundo')));
    });

    testWidgets('liga e posição reais são exibidas', (tester) async {
      await _montarPerfil(
        tester,
        _vmCom(
          const EstadoRanking.disponivel(liga: 'Diamante', posicaoMundial: 128),
        ),
      );

      expect(find.text('Diamante'), findsOneWidget);
      expect(find.text('· #128 no mundo'), findsOneWidget);
    });

    testWidgets('posição zero vinda de um produtor distraído não é desenhada', (
      tester,
    ) async {
      // A regressão direta contra o Gate zero: mesmo que alguém volte a montar
      // o VM com `posicaoMundial: 0`, a tela não tem como escrever `#0`.
      await _montarPerfil(
        tester,
        _vmCom(
          const EstadoRanking.disponivel(liga: 'Prata', posicaoMundial: 0),
        ),
      );

      expect(find.text('Prata'), findsOneWidget);
      expect(_textoDaTela(tester), isNot(contains('#0')));
      expect(_textoDaTela(tester), isNot(contains('no mundo')));
    });

    testWidgets('a tela não guarda o ranking anterior ao ser reconstruída', (
      tester,
    ) async {
      await _montarPerfil(
        tester,
        _vmCom(
          const EstadoRanking.disponivel(liga: 'Diamante', posicaoMundial: 128),
        ),
      );
      expect(find.text('Diamante'), findsOneWidget);

      await _montarPerfil(tester, _vmCom(const EstadoRanking.indisponivel()));

      final texto = _textoDaTela(tester);
      expect(texto, isNot(contains('Diamante')));
      expect(texto, isNot(contains('128')));
    });
  });

  // =========================================================================
  // A ORIGEM — o serviço que produzia 'Bronze' e 0.
  // =========================================================================
  group('PerfilService — o produtor', () {
    test('a chave de demonstração segue desligada', () {
      expect(PerfilService.statsDemo, isFalse);
    });

    test('o perfil publicável não recebe liga nem colocação', () async {
      final vm = await const PerfilService().carregar(
        identidade: IdentidadePublica(
          publicId: 'P0A1B2C3D4E5',
          apelido: 'Sônia',
          avatarRef: null,
          criada: false,
          estado: EstadoPerfil.ativo,
          limites: LimitesSociais.desconhecidos,
          edicao: MetadadosDeEdicao.desconhecidos,
        ),
      );

      expect(vm.nome, 'Sônia', reason: 'o dado que TEM fonte continua vindo');
      expect(vm.ranking, rankingDaCascaPublicavel);
      expect(vm.ranking.liga, isNull);
      expect(vm.ranking.posicaoMundial, isNull);
      expect(vm.ranking.ligaParaExibicao, isNot('Bronze'));
    });

    test('o VM de carregamento diz carregando, e não indisponível', () {
      // Estados diferentes: um é "estou perguntando", o outro é "não há a quem
      // perguntar". Colapsá-los é o começo do caminho de volta ao Bronze.
      expect(
        const PerfilService().vmPlaceholder().ranking.fase,
        FaseRanking.carregando,
      );
    });
  });

  // =========================================================================
  // 7 e 8 — o COMPARTILHAMENTO. O único que sai do aparelho.
  // =========================================================================
  group('compartilhamento', () {
    test('sem ranking, o convite não cita liga nem colocação', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        _vmCom(const EstadoRanking.indisponivel(), nome: 'Sônia', nivel: 3),
      );

      expect(texto, isNot(contains('Bronze')));
      expect(texto, isNot(contains('#0')));
      expect(texto, isNot(contains('#')));
      expect(texto, isNot(contains('Liga')));
      expect(texto, isNot(contains('—')), reason: 'nem o travessão vaza');
      // E continua sendo um convite: perdeu a linha, não a função.
      expect(texto, contains('Sônia'));
      expect(texto, contains('Nível 3'));
      expect(texto, contains('Buraco Master VIP'));
    });

    test('com ranking real, liga e colocação são preservadas', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        _vmCom(
          const EstadoRanking.disponivel(liga: 'Diamante', posicaoMundial: 128),
          nome: 'Aurora',
          nivel: 24,
        ),
      );

      expect(texto, contains('Aurora'));
      expect(texto, contains('Nível 24'));
      expect(texto, contains('Liga Diamante'));
      expect(texto, contains('#128 no mundo'));
    });

    test('liga real sem colocação compartilha só a liga', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        _vmCom(const EstadoRanking.disponivel(liga: 'Ouro')),
      );

      expect(texto, contains('Liga Ouro'));
      expect(texto, isNot(contains('#')));
    });

    test('colocação zero não vira #0 no texto público', () {
      final texto = PerfilPage.textoDeCompartilhamento(
        _vmCom(const EstadoRanking.disponivel(posicaoMundial: 0)),
      );

      expect(texto, isNot(contains('#0')));
      expect(texto, isNot(contains('#')));
    });

    test('sem VM carregado, o convite não afirma nem nome', () {
      final texto = PerfilPage.textoDeCompartilhamento(null);

      expect(texto, contains('Buraco Master VIP'));
      expect(texto, isNot(contains('Bronze')));
      expect(texto, isNot(contains('Nível')));
      expect(texto, isNot(contains('#')));
    });
  });

  // =========================================================================
  // 9 — COERÊNCIA. Home e Perfil interpretam o mesmo estado do mesmo jeito.
  // =========================================================================
  group('Home e Perfil leem a mesma interpretação', () {
    test(
      'a casca publicável não tem autoridade de ranking, e diz isso uma vez só',
      () {
        expect(rankingDaCascaPublicavel.fase, FaseRanking.indisponivel);
        expect(rankingDaCascaPublicavel.liga, isNull);
        expect(rankingDaCascaPublicavel.posicaoMundial, isNull);
      },
    );

    test('o que a Home põe no cabeçalho é o que o Perfil recebe', () async {
      // A Home passa `rankingDaCascaPublicavel.liga` ao `CabecalhoJogador`; o
      // Perfil recebe o próprio estado. As duas leituras têm de concordar, e é
      // exatamente aqui que elas divergiam: `null` de um lado, Bronze do outro.
      final doPerfil = (await const PerfilService().carregar()).ranking;
      const daHome = CabecalhoJogador(
        nome: 'Sônia',
        email: '',
        avatar: '👑',
        moldura: null,
        moedas: null,
        liga: null,
      );

      expect(daHome.liga, rankingDaCascaPublicavel.liga);
      expect(doPerfil.liga, daHome.liga);
      expect(doPerfil, rankingDaCascaPublicavel);
    });

    testWidgets('a Home não desenha liga, e o Perfil não desenha Bronze', (
      tester,
    ) async {
      await _montarPerfil(tester, _vmCom(rankingDaCascaPublicavel));
      final noPerfil = _textoDaTela(tester);

      expect(noPerfil, isNot(contains('Bronze')));
      // A Home omite a linha inteira porque `liga` é nulo — o teste da casca
      // (`casca/casca_producao_test.dart`) já afirma o `findsNothing`; aqui o
      // que importa é que a MESMA fonte produz as duas decisões.
      expect(rankingDaCascaPublicavel.liga, isNull);
    });
  });

  // =========================================================================
  // 11 e 12 — SESSÃO. Logout e troca de conta não deixam resíduo competitivo.
  // =========================================================================
  group('sessão — nada sobrevive à troca', () {
    late _FonteRegulavel fonte;
    late StreamController<String?> auth;
    late SessaoDoJogador sessao;

    setUp(() {
      fonte = _FonteRegulavel();
      auth = StreamController<String?>.broadcast();
    });

    tearDown(() => auth.close());

    // A sessão é aberta DENTRO do corpo do teste: `testWidgets` roda num zone de
    // tempo falso e o `setUp` roda fora dele — um stream assinado lá nunca
    // entregaria o login para o relógio do `pump`.
    void abrirSessao() {
      sessao = SessaoDoJogador(fonte: fonte, uids: auth.stream);
      addTearDown(sessao.dispose);
    }

    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        EscopoSessao(
          sessao: sessao,
          child: const MaterialApp(home: PerfilPage()),
        ),
      );
      await _assentar(tester);
    }

    PerfilVM vmNaTela(WidgetTester tester) =>
        tester.widget<PerfilScreen>(find.byType(PerfilScreen)).vm;

    testWidgets('logout não deixa estado competitivo anterior', (tester) async {
      abrirSessao();
      await tester.pumpWidget(const SizedBox.shrink());
      auth.add('uid-A');
      await tester.pump();
      await tester.pump();

      await montar(tester);
      expect(vmNaTela(tester).nome, 'Sônia');
      expect(vmNaTela(tester).ranking.temAlgumDado, isFalse);

      // Logout.
      auth.add(null);
      await _assentar(tester);

      final depois = vmNaTela(tester);
      expect(depois.ranking.liga, isNull);
      expect(depois.ranking.posicaoMundial, isNull);
      expect(_textoDaTela(tester), isNot(contains('Bronze')));
      expect(_textoDaTela(tester), isNot(contains('no mundo')));
    });

    testWidgets(
      'troca de conta sem logout não reaproveita nada da geração anterior',
      (tester) async {
        abrirSessao();
        await tester.pumpWidget(const SizedBox.shrink());
        auth.add('uid-A');
        await tester.pump();
        await tester.pump();

        await montar(tester);
        expect(vmNaTela(tester).nome, 'Sônia');
        final geracaoA = sessao.geracao;

        // A→B DIRETO, sem passar por deslogado. A fonte passa a responder outra
        // pessoa, como responderia em produção.
        fonte
          ..publicId = 'P9Z8Y7X6W5V4'
          ..apelido = 'Aurora';
        auth.add('uid-B');
        await _assentar(tester);

        expect(sessao.geracao, greaterThan(geracaoA));
        final depois = vmNaTela(tester);
        // A identidade acompanhou a troca...
        expect(depois.nome, 'Aurora');
        // ...e não veio liga nem colocação junto, de nenhuma das duas gerações.
        expect(depois.ranking.liga, isNull);
        expect(depois.ranking.posicaoMundial, isNull);
        expect(depois.ranking, rankingDaCascaPublicavel);

        final texto = _textoDaTela(tester);
        expect(texto, isNot(contains('Bronze')));
        expect(texto, isNot(contains('#0')));
        expect(texto, isNot(contains('no mundo')));
      },
    );

    testWidgets('o compartilhamento após a troca também não afirma nada', (
      tester,
    ) async {
      abrirSessao();
      await tester.pumpWidget(const SizedBox.shrink());
      auth.add('uid-A');
      await tester.pump();
      await tester.pump();
      await montar(tester);

      fonte
        ..publicId = 'P9Z8Y7X6W5V4'
        ..apelido = 'Aurora';
      auth.add('uid-B');
      await _assentar(tester);

      final texto = PerfilPage.textoDeCompartilhamento(vmNaTela(tester));
      expect(texto, contains('Aurora'));
      expect(texto, isNot(contains('Bronze')));
      expect(texto, isNot(contains('Liga')));
      expect(texto, isNot(contains('#')));
    });
  });

  // =========================================================================
  // 10 e a regressão do Gate zero — a prova de AUSÊNCIA, no código-fonte.
  // =========================================================================
  group('auditoria — o literal não pode voltar', () {
    late Set<String> alcancaveis;

    setUpAll(() {
      alcancaveis = _alcancaveisDaRaiz();
      // Sem isto, o grupo inteiro seria um verde falso.
      expect(alcancaveis, contains('lib/main.dart'));
      expect(alcancaveis, contains('lib/services/perfil_service.dart'));
      expect(alcancaveis.length, greaterThan(5));
    });

    test('nenhum arquivo alcançável escreve Bronze como liga', () {
      final infratores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (_codigo(f).contains('Bronze')) infratores.add(caminho);
      }
      expect(
        infratores,
        isEmpty,
        reason:
            'ausência de ranking não é Liga Bronze — se o literal voltou, '
            'voltou junto a afirmação que esta OS removeu',
      );
    });

    test('o texto de compartilhamento não tem fallback de liga', () {
      final fonte = _codigo(File('lib/pages/perfil_page.dart'));
      expect(fonte, isNot(contains('Bronze')));
      expect(
        fonte,
        isNot(contains("?? 'Bronze'")),
        reason: 'era o fallback que copiava a mentira para fora do aparelho',
      );
    });

    test(
      'nenhum arquivo alcançável interpola posição sem checar se ela existe',
      () {
        // O literal exato do Gate zero: `'· #${vm.posicaoMundial} no mundo'`
        // desenhado incondicionalmente. Hoje o campo `posicaoMundial` do VM nem
        // existe mais — o que existe é `vm.ranking.posicaoMundial`, e ele é
        // anulável, então uma interpolação crua imprimiria `null` e não `#0`.
        for (final caminho in alcancaveis) {
          final f = File(caminho);
          if (!f.existsSync()) continue;
          expect(
            _codigo(f),
            isNot(contains(r'#${vm.posicaoMundial}')),
            reason: '$caminho voltou a desenhar a colocação sem guarda',
          );
        }
      },
    );

    test('a demonstração do Perfil não é alcançável pela raiz publicável', () {
      // `statsDemo` só pode ser LIDA dentro do próprio serviço, e a maquete
      // `PerfilVM.mock()` não pode ser construída por nada que nasça em
      // `main()`. As duas são as portas por onde liga e colocação inventadas
      // reentrariam na casca.
      final leemADemo = <String>[];
      final constroemMaquete = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        final codigo = _codigo(f);
        if (codigo.contains('statsDemo')) leemADemo.add(caminho);
        // A DECLARAÇÃO do factory não conta: ela mora na tela, que é catálogo
        // visual e material dos outros testes. O que não pode existir é uma
        // CHAMADA a partir de algo que nasça em `main()` — é a chamada que põe
        // Liga Diamante e #128 na frente de um jogador de verdade.
        if (codigo
            .replaceAll('factory PerfilVM.mock', '')
            .contains('PerfilVM.mock')) {
          constroemMaquete.add(caminho);
        }
      }

      expect(leemADemo, ['lib/services/perfil_service.dart']);
      expect(
        constroemMaquete,
        isEmpty,
        reason: 'a maquete tem Liga Diamante e #128 escritos dentro dela',
      );
    });

    test('a interpretação de "sem ranking" mora num lugar só', () {
      // Se duas superfícies voltarem a decidir por conta própria o que fazer
      // com a ausência, o defeito volta — foi assim que a Home ficou honesta e
      // o Perfil não. Quem produz o estado da casca é a constante, e só ela.
      final produtores = <String>[];
      for (final caminho in alcancaveis) {
        final f = File(caminho);
        if (!f.existsSync()) continue;
        if (_codigo(f).contains('EstadoRanking.indisponivel()')) {
          produtores.add(caminho);
        }
      }
      expect(
        produtores,
        ['lib/ranking/estado_ranking.dart'],
        reason:
            'a ausência de ranking é declarada em `rankingDaCascaPublicavel`; '
            'quem precisa dela LÊ a constante em vez de reconstruí-la',
      );
    });
  });
}
