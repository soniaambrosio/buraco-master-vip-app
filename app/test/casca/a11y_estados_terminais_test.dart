// a11y_estados_terminais_test.dart — os estados terminais da casca lidos por
// quem não vê a tela.
//
// ---------------------------------------------------------------------------
// O QUE ESTÁ SENDO EXERCITADO
// ---------------------------------------------------------------------------
//
// `CascaDeProducao` de verdade, com a `SessaoDoJogador` de verdade. Falsa é só
// a ponta do mundo — a fonte de identidade —, e o fluxo de autenticação é um
// `StreamController` que NUNCA emite: é assim que o teto de espera estoura sem
// gastar oito segundos de relógio de parede.
//
// Os dois estados terminais desta casca:
//
//   _AvisoTerminal    — não há sessão montada acima. Sem ação: não se sai dele
//                       tentando de novo, porque o defeito é do build.
//   _EsperaEstourada  — a sessão não respondeu dentro do teto. Tem ação.
//
// ---------------------------------------------------------------------------
// POR QUE A ÁRVORE SEMÂNTICA, E NÃO `find.text`
// ---------------------------------------------------------------------------
//
// `find.text('⏳')` continua achando a ampulheta depois da correção: o widget
// segue lá, desenhado, e é isso mesmo que se quer — ela sai da LEITURA, não da
// tela. A única prova que distingue as duas coisas é a árvore de semântica, e é
// contra ela que este arquivo afirma.

import 'dart:async';
// `Tristate` é o tipo em que papel e estado passaram a ser respondidos: um
// controle sem estado de habilitação devolve `none`, e não `false`.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/casca/casca_de_producao.dart';
import 'package:buraco_master_vip/screens/splash_oficial_screen.dart';
import 'package:buraco_master_vip/sessao/escopo_sessao.dart';
import 'package:buraco_master_vip/sessao/fonte_identidade.dart';
import 'package:buraco_master_vip/sessao/identidade_publica_sessao.dart';
import 'package:buraco_master_vip/sessao/sessao_do_jogador.dart';

// ===========================================================================
// Bancada
// ===========================================================================

/// Nunca responde. A identidade não é o que está sob teste aqui, e uma fonte
/// que respondesse resolveria a sessão e apagaria o estado sob teste.
class _FonteMuda implements FonteDeIdentidade {
  @override
  Future<IdentidadePublica> obterMinhaIdentidade() =>
      Completer<IdentidadePublica>().future;
}

const Duration _kTeto = Duration(seconds: 8);

/// Passa do teto com folga, sem depender do valor exato.
const Duration _kAlemDoTeto = Duration(seconds: 9);

const String _kMensagemDaEspera =
    'A verificação da sua conta está demorando mais que o normal. '
    'Confira sua conexão e tente de novo.';

const String _kTituloDoAviso = 'Aplicativo mal configurado';
const String _kDetalheDoAviso = 'A sessão do jogador não foi montada na abertura.';

Widget _casca({SessaoDoJogador? sessao}) {
  final Widget app = MaterialApp(
    home: CascaDeProducao(
      aberturaTerminou: true,
      onAberturaConcluida: () {},
      somNaSplash: false,
      duracaoDaSplash: const Duration(milliseconds: 10),
      limiteDeResolucao: _kTeto,
    ),
  );
  // Sem escopo acima, a casca cai no aviso terminal — que é justamente um dos
  // dois casos sob teste.
  if (sessao == null) return app;
  return EscopoSessao(sessao: sessao, child: app);
}

/// Superfície de telefone em retrato.
///
/// O padrão do `flutter_test` é 800x600 — paisagem de desktop —, e nele estas
/// telas não se parecem com o que o aparelho mostra.
void _telefone(WidgetTester t, {double escala = 1.0}) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Roda o corpo com a árvore de semântica ligada.
///
/// O `dispose` fica no `finally`, e não em `addTearDown`, porque o
/// `flutter_test` confere se sobrou `SemanticsHandle` ANTES de rodar os
/// tearDowns — registrado lá, o descarte chega tarde e todo teste do arquivo
/// falha por vazamento, escondendo o que realmente estava sendo provado.
Future<void> _lendoATela(
  WidgetTester t,
  Future<void> Function() corpo,
) async {
  final SemanticsHandle h = t.ensureSemantics();
  try {
    await corpo();
  } finally {
    h.dispose();
  }
}

/// Uma sessão que nunca se pronuncia: o fluxo não emite e ninguém o fecha.
SessaoDoJogador _sessaoMuda() {
  final fluxo = StreamController<String?>.broadcast();
  final s = SessaoDoJogador(fonte: _FonteMuda(), uids: fluxo.stream);
  addTearDown(() {
    s.dispose();
    fluxo.close();
  });
  return s;
}

/// Monta a casca e atravessa o teto, deixando a espera estourada em pé.
Future<void> _atravessarOTeto(WidgetTester t, SessaoDoJogador s) async {
  await t.pumpWidget(_casca(sessao: s));
  await t.pump();
  await t.pump(_kAlemDoTeto);
  await t.pump();
}

// ===========================================================================
// Leitura da árvore semântica
// ===========================================================================

/// Todos os rótulos do estado, na ordem em que um leitor de tela os percorre.
///
/// É esta ordem — e não a ordem do `Column` — que responde "o título vem antes
/// da mensagem?".
///
/// A varredura começa no nó da moldura rolável, e não na raiz da árvore, para
/// que o que se afirma seja o CONTEÚDO DO ESTADO — e não o que o `MaterialApp`
/// por acaso pendura acima dele.
List<String> _rotulosEmOrdem(WidgetTester t) {
  final saida = <String>[];
  void andar(SemanticsNode n) {
    final rotulo = n.label.trim();
    if (rotulo.isNotEmpty) saida.add(rotulo);
    n.visitChildren((filho) {
      andar(filho);
      return true;
    });
  }

  andar(t.getSemantics(find.byType(SingleChildScrollView)));
  return saida;
}

/// Este nó é cabeçalho?
bool _ehCabecalho(SemanticsNode n) => n.flagsCollection.isHeader;

/// Captura o que a casca manda dizer em voz alta.
///
/// `SemanticsService.announce` vira uma mensagem no canal de acessibilidade da
/// plataforma; interceptá-lo é a única forma de CONTAR anúncios sem um leitor
/// de tela de verdade do outro lado — e contar é o ponto, porque o defeito que
/// se quer impedir é falar duas vezes.
List<String> _capturarAnuncios(WidgetTester t) {
  final ditos = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (dynamic mensagem) async {
      final m = mensagem as Map<dynamic, dynamic>;
      if (m['type'] == 'announce') {
        final dados = m['data'] as Map<dynamic, dynamic>;
        ditos.add(dados['message'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return ditos;
}

void main() {
  // =========================================================================
  // 1 — espera estourada: o estado que TEM ação
  // =========================================================================
  group('espera estourada', () {
    testWidgets('o título é anunciado, e como cabeçalho', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final no = t.getSemantics(find.text(kTituloDaEsperaEstourada));
        expect(no.label, kTituloDaEsperaEstourada);
        // PROVA NEGATIVA: tirar `header: true` da casca derruba exatamente
        // esta linha, e nenhuma outra.
        expect(
          _ehCabecalho(no),
          isTrue,
          reason: 'o título do estado precisa ser cabeçalho',
        );
      });
    });

    testWidgets('o cabeçalho é ÚNICO — a mensagem não é cabeçalho', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        expect(
          _ehCabecalho(t.getSemantics(find.text(_kMensagemDaEspera))),
          isFalse,
          reason: 'dois cabeçalhos no mesmo estado é o mesmo que nenhum',
        );
      });
    });

    testWidgets('a mensagem chega inteira e sem jargão', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        expect(_rotulosEmOrdem(t), contains(_kMensagemDaEspera));
      });
    });

    testWidgets('a ampulheta NÃO entra na árvore', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        // Ela continua desenhada — o que mudou é a leitura, não a tela.
        expect(find.text('⏳'), findsOneWidget);
        // PROVA NEGATIVA: devolver o `ExcludeSemantics` para `Text` puro põe
        // um rótulo "⏳" na árvore e derruba esta linha.
        expect(
          _rotulosEmOrdem(t).where((r) => r.contains('⏳')),
          isEmpty,
          reason: 'emoji decorativo não pode ser anunciado',
        );
      });
    });

    testWidgets('nada de gráfico sobra sem descrição', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        // Não há ícone informativo neste estado: TODA a informação é texto. A
        // prova é que os rótulos da árvore são exatamente os três textos — nem
        // um a mais, que seria decoração falando; nem um a menos, que seria
        // informação perdida.
        expect(_rotulosEmOrdem(t), const <String>[
          kTituloDaEsperaEstourada,
          _kMensagemDaEspera,
          'Tentar de novo',
        ]);
      });
    });

    testWidgets('a ordem de foco é título, mensagem, ação', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final r = _rotulosEmOrdem(t);
        expect(
          r.indexOf(kTituloDaEsperaEstourada),
          lessThan(r.indexOf(_kMensagemDaEspera)),
        );
        expect(
          r.indexOf(_kMensagemDaEspera),
          lessThan(r.indexOf('Tentar de novo')),
        );
      });
    });

    testWidgets('a ação tem nome, papel e estado', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final no = t.getSemantics(find.text('Tentar de novo'));
        expect(no.label, 'Tentar de novo');
        expect(no.flagsCollection.isButton, isTrue, reason: 'papel');
        // Um controle SEM estado de habilitação responde `none` — e um botão
        // que não diz se está ligado não é operável por quem não o vê.
        expect(
          no.flagsCollection.isEnabled,
          Tristate.isTrue,
          reason: 'papel sem estado de habilitação não é ação',
        );
        expect(
          no.flagsCollection.isFocused,
          isNot(Tristate.none),
          reason: 'focável',
        );
        // Sem a AÇÃO, o botão é um rótulo bonito que ninguém consegue apertar
        // pelo leitor de tela.
        expect(no.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      });
    });

    testWidgets('o callback continua sendo o de antes: volta a esperar', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final s = _sessaoMuda();
        await _atravessarOTeto(t, s);
        expect(find.text(kTituloDaEsperaEstourada), findsOneWidget);

        await t.tap(find.text('Tentar de novo'));
        await t.pump();

        // O DESTINO NÃO MUDOU: "tentar de novo" volta a esperar a sessão — não
        // navega para lugar nenhum, não inventa login e não resolve sessão.
        expect(find.byType(SplashOficialScreen), findsOneWidget);
        expect(find.text(kTituloDaEsperaEstourada), findsNothing);
        expect(s.resolvida, isFalse);
        expect(s.estado.autenticado, isFalse);

        // E o teto volta a valer: passado de novo, o estado retorna.
        await t.pump(_kAlemDoTeto);
        await t.pump();
        expect(find.text(kTituloDaEsperaEstourada), findsOneWidget);
      });
    });

    testWidgets('nada de sensível na árvore', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await _atravessarOTeto(t, _sessaoMuda());

        final tudo = _rotulosEmOrdem(t).join(' | ').toLowerCase();
        for (final proibido in const <String>[
          'uid',
          'token',
          'credencial',
          'publicid',
          'firebase',
          'exception',
          'stack',
          'null',
        ]) {
          expect(
            tudo.contains(proibido),
            isFalse,
            reason: 'a leitura do estado expôs "$proibido"',
          );
        }
      });
    });
  });

  // =========================================================================
  // 2 — a transição, dita uma vez só
  // =========================================================================
  group('mudança dinâmica', () {
    testWidgets('a transição é anunciada — e UMA vez', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);
        final s = _sessaoMuda();

        await t.pumpWidget(_casca(sessao: s));
        await t.pump();
        // Antes do teto não há o que anunciar: a abertura está fazendo o seu
        // trabalho, e dizer isso seria ruído.
        expect(ditos, isEmpty);

        await t.pump(_kAlemDoTeto);
        await t.pump();
        expect(ditos, <String>[kTituloDaEsperaEstourada]);

        // PROVA NEGATIVA DA REPETIÇÃO. Não basta bombear: `pump` sem nada a
        // mudar não reconstrói a casca, e um teste assim passa mesmo com o
        // anúncio solto no `build`. O que reconstrói de verdade é o pai
        // entregar um widget novo — que é exatamente o que a raiz de produção
        // faz a cada notificação da sessão, via `ListenableBuilder`.
        for (var i = 0; i < 3; i++) {
          await t.pumpWidget(_casca(sessao: s));
          await t.pump();
        }
        await t.pump(const Duration(seconds: 30));
        await t.pump();
        expect(
          ditos,
          <String>[kTituloDaEsperaEstourada],
          reason: 'o anúncio repetiu a cada reconstrução',
        );
      });
    });

    testWidgets('o estado de abertura da rota NÃO é anunciado por cima', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);

        // Aviso terminal: primeiro quadro da rota. O leitor de tela já anuncia
        // a rota que abre — um `announce` aqui seria a mesma coisa duas vezes.
        await t.pumpWidget(_casca());
        await t.pump();
        await t.pump(_kAlemDoTeto);
        await t.pump();

        expect(find.text(_kTituloDoAviso), findsOneWidget);
        expect(ditos, isEmpty);
      });
    });

    testWidgets('descartada antes do teto, a casca não fala depois', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);

        await t.pumpWidget(_casca(sessao: _sessaoMuda()));
        await t.pump();

        // Sai da árvore ANTES de o teto estourar.
        await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await t.pump();

        // O relógio segue correndo no mundo, mas não há mais tela a descrever.
        await t.pump(_kAlemDoTeto);
        await t.pump();
        await t.pump(const Duration(seconds: 30));

        expect(
          ditos,
          isEmpty,
          reason: 'anúncio atrasado descreve uma tela que foi embora',
        );
      });
    });

    testWidgets('descartada depois de falar, não repete', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        final ditos = _capturarAnuncios(t);

        await _atravessarOTeto(t, _sessaoMuda());
        expect(ditos, hasLength(1));

        await t.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await t.pump(const Duration(seconds: 30));

        expect(ditos, hasLength(1));
      });
    });
  });

  // =========================================================================
  // 3 — aviso terminal: o estado que NÃO tem ação
  // =========================================================================
  group('aviso terminal', () {
    testWidgets('título é cabeçalho, detalhe não, e nenhuma ação é oferecida', (
      t,
    ) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await t.pumpWidget(_casca());
        await t.pump();

        expect(
          _ehCabecalho(t.getSemantics(find.text(_kTituloDoAviso))),
          isTrue,
        );
        expect(
          _ehCabecalho(t.getSemantics(find.text(_kDetalheDoAviso))),
          isFalse,
        );

        // NÃO SE INVENTA SAÍDA: deste estado não se sai tentando de novo, e a
        // leitura não pode sugerir que se sai.
        expect(_rotulosEmOrdem(t), const <String>[
          _kTituloDoAviso,
          _kDetalheDoAviso,
        ]);
        expect(find.byType(FilledButton), findsNothing);
      });
    });

    testWidgets('o triângulo NÃO entra na árvore', (t) async {
      await _lendoATela(t, () async {
        _telefone(t);
        await t.pumpWidget(_casca());
        await t.pump();

        expect(find.text('⚠️'), findsOneWidget);
        expect(_rotulosEmOrdem(t).where((r) => r.contains('⚠')), isEmpty);
      });
    });
  });

  // =========================================================================
  // 4 — escala de texto: o PASS que já existia continua valendo
  // =========================================================================
  group('escala de texto', () {
    for (final escala in const <double>[1.0, 1.5, 2.0]) {
      final rotulo = '${(escala * 100).toInt()}%';

      testWidgets('espera estourada em $rotulo: sem estouro, e operável', (
        t,
      ) async {
        await _lendoATela(t, () async {
          _telefone(t, escala: escala);
          await _atravessarOTeto(t, _sessaoMuda());

          // Um overflow de layout vira exceção do framework durante o quadro.
          expect(
            t.takeException(),
            isNull,
            reason: 'layout estourou em $rotulo',
          );

          // A correção semântica não pode ter tirado nada da tela.
          expect(find.text(kTituloDaEsperaEstourada), findsOneWidget);
          expect(find.text('Tentar de novo'), findsOneWidget);
          expect(
            _ehCabecalho(t.getSemantics(find.text(kTituloDaEsperaEstourada))),
            isTrue,
            reason: 'o cabeçalho não pode depender da escala',
          );

          // E a ação continua alcançável e apertável. Em 200% ela desce para
          // fora da dobra — o que é esperado e já era assim: a moldura ROLA. O
          // que não pode é ela ficar inalcançável, e é isso que o
          // `ensureVisible` afirma.
          await t.ensureVisible(find.text('Tentar de novo'));
          await t.pump();
          await t.tap(find.text('Tentar de novo'));
          await t.pump();
          expect(find.byType(SplashOficialScreen), findsOneWidget);
        });
      });

      testWidgets('aviso terminal em $rotulo: sem estouro', (t) async {
        await _lendoATela(t, () async {
          _telefone(t, escala: escala);
          await t.pumpWidget(_casca());
          await t.pump();

          expect(
            t.takeException(),
            isNull,
            reason: 'layout estourou em $rotulo',
          );
          expect(find.text(_kTituloDoAviso), findsOneWidget);
          expect(
            _ehCabecalho(t.getSemantics(find.text(_kTituloDoAviso))),
            isTrue,
            reason: 'o cabeçalho não pode depender da escala',
          );
        });
      });
    }
  });
}
