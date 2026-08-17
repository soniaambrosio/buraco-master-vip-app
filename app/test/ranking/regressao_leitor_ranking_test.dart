// regressao_leitor_ranking_test.dart — os dois defeitos que a homologação
// independente reprovou, virados em portão permanente.
//
// ---------------------------------------------------------------------------
// POR QUE ESTA SUÍTE EXISTE SEPARADA DA OUTRA
// ---------------------------------------------------------------------------
//
// `leitor_ranking_real_test.dart` prova o que o leitor SABIA fazer. Esta prova
// o que ele NÃO sabia — e os dois casos são de uma espécie que só aparece
// quando alguém tenta quebrar de propósito, então merecem ficar visíveis em
// arquivo próprio, com o nome do defeito na frente.
//
//   DEFEITO A — a proteção de ordem era POR CHAVE. Duas chaves em voo, uma
//   virada de temporada no meio, e a resposta VENCIDA da temporada anterior era
//   devolvida como se fosse atual — e ainda despejava do cache a fotografia boa
//   da temporada nova. A guarda de sequência não via nada de errado: cada
//   resposta era, na sua própria chave, a mais recente.
//
//   DEFEITO B — `unauthenticated` era lido como "a sessão do jogador acabou".
//   Na versão contratual auditada (`firebase-functions` 6.x com
//   `enforceAppCheck: true`), esse MESMO código chega também quando o token de
//   App Check está ausente ou inválido — situação em que a sessão do jogador
//   está perfeitamente viva. A tela mandava a pessoa entrar de novo na conta e
//   escondia o botão de tentar de novo: a única ação errada, e nenhuma das
//   certas.
//
// NENHUM ATRASO REAL. O transporte falso resolve quando o teste manda, e é o
// que torna "a resposta antiga chega depois da nova" determinístico.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/ranking/leitor_ranking.dart';
import 'package:buraco_master_vip/ranking/ranking_transporte.dart';
// `EstadoRanking` e `FaseRanking` chegam pelo `export` de `perfil_screen.dart`,
// que é a superfície que a própria casca declara. Importar `estado_ranking.dart`
// de novo seria import redundante — e o analyzer diz isso.
import 'package:buraco_master_vip/screens/perfil_screen.dart';

// ===========================================================================
// Ferramentas
// ===========================================================================

const contaA = 'P0A1B2C3D4E5';
const contaB = 'P9Z8Y7X6W5V4';
const alvoX = 'PXX1XX2XX3XX';
const alvoY = 'PYY1YY2YY3YY';
const alvoZ = 'PZZ1ZZ2ZZ3ZZ';

FotografiaRanking foto({
  required String? temporadaId,
  String liga = 'Ouro',
  String? ligaId = 'ouro',
  int posicao = 7,
}) => FotografiaRanking(
  temporadaId: temporadaId,
  rotuloLiga: liga,
  ligaId: ligaId,
  posicao: posicao,
  classificado: true,
);

/// Transporte que só responde quando o teste manda, e por chamada nomeada.
class _TransporteManual extends TransporteRanking {
  final Map<String, List<Completer<FotografiaRanking>>> _fila =
      <String, List<Completer<FotografiaRanking>>>{};

  /// Quantas chamadas de cada tipo foram emitidas de verdade.
  final List<String> emitidas = <String>[];

  Future<FotografiaRanking> _abrir(String chave) {
    emitidas.add(chave);
    final c = Completer<FotografiaRanking>();
    (_fila[chave] ??= <Completer<FotografiaRanking>>[]).add(c);
    return c.future;
  }

  @override
  Future<FotografiaRanking> meuRanking() => _abrir('proprio');

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) =>
      _abrir('publico:$publicId');

  /// O pedido mais antigo ainda pendente daquela chave.
  Completer<FotografiaRanking> pendente(String chave) =>
      _fila[chave]!.firstWhere((c) => !c.isCompleted);

  void responder(String chave, FotografiaRanking f) =>
      pendente(chave).complete(f);

  void falhar(String chave, MotivoFalhaRanking motivo) =>
      pendente(chave).completeError(FalhaRanking(motivo, 'teste'));

  int emitidasDe(String chave) => emitidas.where((e) => e == chave).length;
}

PerfilVM _vmCom(EstadoRanking ranking) => PerfilVM.mock().comRanking(ranking);

Future<void> montarPerfil(WidgetTester tester, EstadoRanking ranking) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilScreen(
        vm: _vmCom(ranking),
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

void main() {
  late _TransporteManual t;
  late LeitorDeRanking leitor;

  setUp(() {
    t = _TransporteManual();
    leitor = LeitorDeRanking(transporte: t);
  });

  // =========================================================================
  // DEFEITO A — a temporada vencida entre chaves diferentes
  // =========================================================================
  group('A — resposta de temporada vencida, entre chaves diferentes', () {
    test('A1 — a resposta atrasada de T1 não é devolvida nem armazenada, e o '
        'cache de T2 fica intacto', () async {
      // 1. pedido público de T1 fica em voo.
      final vooT1 = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      final pendenteT1 = t.pendente('publico:$alvoX');

      // 2. pedido próprio POSTERIOR responde T2, e é aplicado.
      final vooT2 = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Ouro'));
      expect((await vooT2)!.temporadaId, 'T2');
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');

      // 3. só agora a resposta de T1 chega.
      pendenteT1.complete(
        foto(temporadaId: 'T1', liga: 'Prata', ligaId: 'prata', posicao: 50),
      );

      // 4. ela NÃO é devolvida ao consumidor...
      expect(await vooT1, isNull);
      // ...NÃO é armazenada...
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNull,
      );
      // 5. ...e NÃO despeja a fotografia boa de T2.
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');
      expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Ouro');
    });

    test('A2 — o cenário inverso: o pedido posterior INAUGURA T2', () async {
      // T1 estabelecida por um pedido antigo, já respondido.
      final primeiro = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      t.responder('publico:$alvoX', foto(temporadaId: 'T1', liga: 'Prata'));
      await primeiro;
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNotNull,
      );

      // Um pedido REALMENTE posterior traz T2: tem de ser aceito.
      final segundo = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Ouro'));
      final novo = await segundo;

      expect(novo, isNotNull);
      expect(novo!.temporadaId, 'T2');
      // E só as fotografias INCOMPATÍVEIS saem.
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNull,
        reason: 'a fotografia de T1 sobreviveu à virada',
      );
      expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T2');
    });

    test('A3 — três chaves simultâneas, a do meio inaugura T2', () async {
      final vX = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoX,
      );
      final vY = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoY,
      );
      final vZ = leitor.rankingPublico(
        contaPublicId: contaA,
        alvoPublicId: alvoZ,
      );
      final pX = t.pendente('publico:$alvoX');

      // Y (emitido depois de X) inaugura T2.
      t.responder('publico:$alvoY', foto(temporadaId: 'T2', liga: 'Ouro'));
      expect((await vY)!.temporadaId, 'T2');

      // Z (emitido depois de Y) na mesma T2: vale.
      t.responder('publico:$alvoZ', foto(temporadaId: 'T2', liga: 'Prata'));
      expect((await vZ)!.temporadaId, 'T2');

      // X, emitido ANTES de Y, chega por último com T1: vencido.
      pX.complete(foto(temporadaId: 'T1', liga: 'Bronze'));
      expect(await vX, isNull);

      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
        isNull,
      );
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoY),
        isNotNull,
      );
      expect(
        leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoZ),
        isNotNull,
      );
    });

    test(
      'A4 — a MESMA temporada em chaves diferentes continua válida',
      () async {
        final vX = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        );
        final vP = leitor.meuRanking(contaPublicId: contaA);
        final pX = t.pendente('publico:$alvoX');

        // O pedido posterior responde primeiro, na MESMA temporada.
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
        expect((await vP)!.temporadaId, 'T1');

        // A resposta anterior, também de T1, NÃO pode ser descartada: ela não
        // está vencida, só chegou fora de ordem — e é sobre outra pessoa.
        pX.complete(foto(temporadaId: 'T1', liga: 'Prata', ligaId: 'prata'));
        final tardia = await vX;
        expect(tardia, isNotNull);
        expect(tardia!.liga, 'Prata');
        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
          isNotNull,
        );
        expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Ouro');
      },
    );

    test(
      'A5 — temporada nula não apaga a conhecida nem envenena o cache',
      () async {
        final vP = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
        await vP;

        // `consultarJogadorPorIdPublico` devolve `temporadaId: null` quando não há
        // temporada vigente. Isso não é uma temporada NOVA.
        final vX = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        );
        t.responder(
          'publico:$alvoX',
          FotografiaRanking.semColocacao(temporadaId: null),
        );
        expect(await vX, isNotNull);

        // A fotografia de T1 sobrevive...
        expect(leitor.emCache(contaPublicId: contaA)!.temporadaId, 'T1');
        // ...e a temporada aceita continua sendo T1: uma resposta de T1 que chegue
        // depois disto ainda vale.
        final vY = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoY,
        );
        t.responder('publico:$alvoY', foto(temporadaId: 'T1', liga: 'Prata'));
        expect((await vY)!.temporadaId, 'T1');
      },
    );

    test(
      'A6 — logout durante as chamadas descarta tudo o que estava em voo',
      () async {
        final vX = leitor.rankingPublico(
          contaPublicId: contaA,
          alvoPublicId: alvoX,
        );
        final vP = leitor.meuRanking(contaPublicId: contaA);

        leitor.aoMudarSessao(1); // logout

        t.responder('publico:$alvoX', foto(temporadaId: 'T1'));
        t.responder('proprio', foto(temporadaId: 'T2'));

        expect(await vX, isNull);
        expect(await vP, isNull);
        expect(leitor.emCache(contaPublicId: contaA), isNull);
        expect(
          leitor.emCache(contaPublicId: contaA, alvoPublicId: alvoX),
          isNull,
        );
      },
    );

    test('A7 — a troca de jogador zera também a autoridade temporal', () async {
      // A conta A conhece T2.
      final vA = leitor.meuRanking(contaPublicId: contaA);
      t.responder('proprio', foto(temporadaId: 'T2', liga: 'Ouro'));
      await vA;

      // Troca de conta. A temporada aceita era um fato sobre a sessão anterior.
      leitor.aoMudarSessao(1);

      // A conta B recebe T1 — que, para ela, é a primeira notícia de temporada.
      // Se a autoridade temporal tivesse sobrevivido à troca, esta resposta
      // seria descartada como "vencida", e a conta B ficaria sem ranking.
      final vB = leitor.meuRanking(contaPublicId: contaB);
      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Prata'));
      final estadoB = await vB;

      expect(estadoB, isNotNull);
      expect(estadoB!.temporadaId, 'T1');
      expect(leitor.emCache(contaPublicId: contaB)!.liga, 'Prata');
      expect(leitor.emCache(contaPublicId: contaA), isNull);
    });

    test(
      'A8 — resposta antiga da MESMA chave continua sendo descartada',
      () async {
        // Primeiro voo, respondido: libera a chave.
        final v1 = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Bronze'));
        await v1;

        // Segundo voo fica pendente...
        final v2 = leitor.meuRanking(contaPublicId: contaA);
        final p2 = t.pendente('proprio');
        // ...e some do mapa de voos só quando responder. Para encenar "pedido mais
        // novo na mesma chave", respondemos o 2 e emitimos o 3 antes de olhar.
        p2.complete(foto(temporadaId: 'T1', liga: 'Prata', ligaId: 'prata'));
        await v2;

        final v3 = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
        await v3;

        expect(leitor.emCache(contaPublicId: contaA)!.liga, 'Ouro');
      },
    );

    test(
      'A9 — isolamento entre contas sobrevive à proteção temporal',
      () async {
        final vA = leitor.meuRanking(contaPublicId: contaA);
        t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
        await vA;

        expect(leitor.emCache(contaPublicId: contaA), isNotNull);
        expect(leitor.emCache(contaPublicId: contaB), isNull);
      },
    );
  });

  // =========================================================================
  // DEFEITO B — `unauthenticated` não prova sessão morta
  // =========================================================================
  group('B — credencial ou atestação recusada', () {
    test('B1 — sem sessão local, `unauthenticated` É sessão inválida', () async {
      // Sem conta não há a quem pertencer a sessão: aqui a afirmação é honesta.
      final voo = leitor.meuRanking(contaPublicId: '');
      t.falhar('proprio', MotivoFalhaRanking.credencialOuAtestacao);
      final estado = await voo;

      expect(estado!.fase, FaseRanking.sessaoInvalida);
      expect(estado.podeTentarDeNovo, isFalse);
    });

    test('B2 — com sessão local ativa, `unauthenticated` é acesso recusado, e '
        'NÃO sessão expirada', () async {
      final voo = leitor.meuRanking(contaPublicId: contaA);
      t.falhar('proprio', MotivoFalhaRanking.credencialOuAtestacao);
      final estado = await voo;

      expect(estado!.fase, FaseRanking.acessoRecusado);
      expect(
        estado.fase,
        isNot(FaseRanking.sessaoInvalida),
        reason: 'a sessão local está viva; afirmar que expirou é mentira',
      );
      expect(estado.podeTentarDeNovo, isTrue);
    });

    test(
      'B3 — a falha de App Check é INDISTINGUÍVEL da de credencial, e cai no '
      'mesmo estado neutro',
      () async {
        // O backend com `enforceAppCheck: true` devolve `unauthenticated` para
        // token de App Check ausente E para token inválido E para credencial
        // recusada. O transporte preserva essa ambiguidade num motivo só; quem
        // decide é a camada que sabe da sessão.
        final voo = leitor.meuRanking(contaPublicId: contaA);
        t.falhar('proprio', MotivoFalhaRanking.credencialOuAtestacao);
        expect((await voo)!.fase, FaseRanking.acessoRecusado);
      },
    );

    test('B4 — `permission-denied` com sessão ativa também é neutro', () async {
      final voo = leitor.meuRanking(contaPublicId: contaA);
      t.falhar('proprio', MotivoFalhaRanking.recusado);
      final estado = await voo;
      expect(estado!.fase, FaseRanking.acessoRecusado);
      expect(estado.podeTentarDeNovo, isTrue);
    });

    test('B5 — falhas recuperáveis continuam sendo falha com retry', () async {
      final voo = leitor.meuRanking(contaPublicId: contaA);
      t.falhar('proprio', MotivoFalhaRanking.indisponivel);
      final estado = await voo;
      expect(estado!.fase, FaseRanking.falha);
      expect(estado.podeTentarDeNovo, isTrue);
    });

    test('B6 — payload inválido é falha, e não ausência', () async {
      final voo = leitor.meuRanking(contaPublicId: contaA);
      t.falhar('proprio', MotivoFalhaRanking.respostaInvalida);
      final estado = await voo;
      expect(estado!.fase, FaseRanking.falha);
    });

    test('B7 — nenhuma falha entra no cache', () async {
      for (final motivo in MotivoFalhaRanking.values) {
        final t2 = _TransporteManual();
        final l2 = LeitorDeRanking(transporte: t2);
        final voo = l2.meuRanking(contaPublicId: contaA);
        t2.falhar('proprio', motivo);
        await voo;
        expect(l2.emCache(contaPublicId: contaA), isNull, reason: '$motivo');
      }
    });

    test('B8 — nenhuma fase de falha carrega liga ou posição', () async {
      for (final motivo in MotivoFalhaRanking.values) {
        final t2 = _TransporteManual();
        final l2 = LeitorDeRanking(transporte: t2);
        final voo = l2.meuRanking(contaPublicId: contaA);
        t2.falhar('proprio', motivo);
        final estado = (await voo)!;
        expect(estado.liga, isNull, reason: '$motivo');
        expect(estado.posicaoMundial, isNull, reason: '$motivo');
      }
    });

    test('B9 — três toques no retry produzem UMA chamada nova', () async {
      // Primeira tentativa, que falha.
      final v1 = leitor.meuRanking(contaPublicId: contaA);
      t.falhar('proprio', MotivoFalhaRanking.credencialOuAtestacao);
      expect((await v1)!.fase, FaseRanking.acessoRecusado);
      expect(t.emitidasDe('proprio'), 1);

      // Três toques seguidos no botão: o dedupe por chave dá uma chamada só.
      final a = leitor.meuRanking(contaPublicId: contaA);
      final b = leitor.meuRanking(contaPublicId: contaA);
      final c = leitor.meuRanking(contaPublicId: contaA);
      expect(t.emitidasDe('proprio'), 2, reason: 'três toques, uma chamada');
      expect(identical(a, b), isTrue);
      expect(identical(b, c), isTrue);

      t.responder('proprio', foto(temporadaId: 'T1', liga: 'Ouro'));
      expect((await a)!.liga, 'Ouro');
    });
  });

  // =========================================================================
  // B — o que a tela diz, e o que ela oferece
  // =========================================================================
  group('B — a tela não promete o que o botão não cumpre', () {
    testWidgets('B10 — o acesso recusado tem mensagem neutra', (tester) async {
      final handle = tester.ensureSemantics();
      await montarPerfil(tester, const EstadoRanking.acessoRecusado());
      expect(
        find.bySemanticsLabel(
          'Não foi possível acessar sua classificação. Tente novamente.',
        ),
        findsOneWidget,
      );
      // E NÃO manda ninguém entrar na conta de novo.
      expect(
        find.bySemanticsLabel(
          'Classificação indisponível: entre na sua conta de novo.',
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets(
      'B11 — o acesso recusado oferece tentar de novo, e o botão da tela é o '
      'que cumpre a promessa',
      (tester) async {
        // A oferta é o `podeTentarDeNovo` mais a frase que aponta para ela. O
        // botão físico é o da tela (`onRecarregar`), que `PerfilPage` liga ao
        // recarregamento das DUAS coisas — perfil e ranking.
        expect(const EstadoRanking.acessoRecusado().podeTentarDeNovo, isTrue);

        var toques = 0;
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: PerfilScreen(
              vm: _vmCom(const EstadoRanking.acessoRecusado()),
              estado: PerfilEstado.erro,
              mensagemErro: 'falhou',
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
              onRecarregar: () => toques++,
              onNavTap: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tentar de novo'), findsOneWidget);
        await tester.tap(find.text('Tentar de novo'));
        expect(toques, 1);
      },
    );

    testWidgets(
      'B12 — a sessão realmente inválida continua sem prometer retry',
      (tester) async {
        final handle = tester.ensureSemantics();
        await montarPerfil(tester, const EstadoRanking.sessaoInvalida());
        expect(
          find.bySemanticsLabel(
            'Classificação indisponível: entre na sua conta de novo.',
          ),
          findsOneWidget,
        );
        expect(const EstadoRanking.sessaoInvalida().podeTentarDeNovo, isFalse);
        handle.dispose();
      },
    );

    test('B13 — nenhum estado de falha afirma liga, nem para exibição', () {
      const estados = <EstadoRanking>[
        EstadoRanking.acessoRecusado(),
        EstadoRanking.sessaoInvalida(),
        EstadoRanking.falha(),
      ];
      for (final e in estados) {
        expect(e.temLiga, isFalse);
        expect(e.temPosicao, isFalse);
        expect(e.ligaParaExibicao, '—');
      }
    });
  });
}
