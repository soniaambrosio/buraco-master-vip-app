// enforcement_vip_ui_test.dart — o enforcement onde ele e visivel: nas telas.
//
// `portao_vip_test.dart` prova que o PORTAO decide certo. Esta suite prova as
// duas outras metades, que sao as que a auditoria encontrou abertas:
//
//   1. os MOCKS nao concedem autorizacao (o defeito era `ehVip = true` como
//      valor padrao de `ConfigMesaVM.mock` e `SaguaoVM.mock`, herdado pelos
//      hosts que nao passavam o parametro);
//   2. as TELAS barram de verdade quando `ehVip` e falso — o Salao VIP e a
//      escolha de mesa VIP/ranqueada/privada;
//   3. o ESCOPO entrega bloqueio para quem esta fora dele, para quem esta
//      carregando e para quem trocou de conta.
//
// Sobre a superficie: `flutter_test` monta uma janela de 800x600, e estas telas
// sao de telefone. Sem redimensionar, o layout estoura e o teste falha por um
// motivo que nao tem nada a ver com VIP.

import 'dart:async';

import 'package:buraco_master_vip/billing/acesso_vip.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:buraco_master_vip/screens/configurar_mesa_screen.dart';
import 'package:buraco_master_vip/screens/onde_jogar_screen.dart';
import 'package:buraco_master_vip/screens/saguao_screen.dart';
import 'package:buraco_master_vip/widgets/escopo_vip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _agora = DateTime.utc(2026, 8, 15, 12);

EntitlementVip _vigente(String uid) => EntitlementVip(
      uid: uid,
      vipAtivo: true,
      estado: EstadoEntitlement.ativo,
      produtoId: 'vip_assinatura',
      origem: 'play',
      expiraEm: _agora.add(const Duration(days: 20)),
    );

/// Da a tela uma superficie de telefone.
///
/// Sem isto o `flutter_test` monta 800x600 — paisagem — e telas desenhadas para
/// telefone quebram por motivo que nada tem a ver com VIP.
Future<void> _telefone(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Descarta o estouro de layout causado pela FONTE SUBSTITUTA do `flutter_test`.
///
/// `ConfigurarMesaScreen` tem uma caixa de largura fixa ("Custo criar") que
/// estoura por 44px sob a fonte de teste — o mesmo valor em qualquer superficie,
/// porque a caixa nao depende da largura da tela. Com a fonte real, no aparelho,
/// nao estoura.
///
/// O descarte e CONDICIONAL de proposito: a assercao abaixo garante que so um
/// overflow e engolido. Qualquer outra excecao — inclusive uma que o proprio
/// enforcement produza — continua derrubando o teste.
void _descartarOverflowDaFonteDeTeste(WidgetTester tester) {
  final excecao = tester.takeException();
  if (excecao == null) return;
  expect(
    excecao.toString(),
    contains('overflowed'),
    reason: 'so o estouro de layout da fonte substituta pode ser descartado',
  );
}

/// Deixa um evento de stream chegar ate o `setState` e virar quadro.
///
/// Um `pump()` so nao basta: entre `add` no controlador e a arvore reconstruida
/// ha a entrega ao portao, a republicacao em `mudancas` e o `setState` do
/// escopo. O segundo quadro e o que torna a assercao deterministica.
Future<void> _assentar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  // =========================================================================
  group('MOCK — um mock nao autoriza (criterio de reprovacao 3)', () {
    test('MOCK-01 ConfigMesaVM.mock() nasce SEM VIP', () {
      // O defeito literal da auditoria: o padrao era `true`, e o host construia
      // a VM sem passar o parametro. Se alguem devolver o padrao permissivo,
      // este teste cai.
      expect(ConfigMesaVM.mock().ehVip, isFalse);
      expect(ConfigMesaVM.mock(tipo: TipoMesa.vip).ehVip, isFalse);
      expect(ConfigMesaVM.mock(tipo: TipoMesa.privada).ehVip, isFalse);
      expect(ConfigMesaVM.mock(tipo: TipoMesa.publica).ehVip, isFalse);
    });

    test('MOCK-02 SaguaoVM.mock() nasce SEM VIP', () {
      expect(SaguaoVM.mock().ehVip, isFalse);
      expect(SaguaoVM.mock(sala: SalaSaguao.vip).ehVip, isFalse);
      expect(SaguaoVM.mock(sala: SalaSaguao.publico).ehVip, isFalse);
    });

    test('MOCK-03 os demais mocks de tela com ehVip tambem nascem sem VIP', () {
      expect(OndeJogarVM.mock().ehVip, isFalse);
    });

    test('MOCK-04 quem precisa de VIP em teste declara explicitamente', () {
      // O mock continua servindo para preview e teste — o que ele nao pode e
      // conceder por OMISSAO.
      expect(ConfigMesaVM.mock(ehVip: true).ehVip, isTrue);
      expect(SaguaoVM.mock(ehVip: true).ehVip, isTrue);
    });
  });

  // =========================================================================
  group('SALAO — o Salao VIP (criterio de reprovacao 1)', () {
    testWidgets('SALAO-01 sem VIP, tocar na aba VIP NAO troca de sala',
        (tester) async {
      await _telefone(tester);

      var trocas = <SalaSaguao>[];
      var bloqueios = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SaguaoScreen(
            vm: SaguaoVM.mock(sala: SalaSaguao.publico),
            onVoltar: () {},
            onTrocarSala: trocas.add,
            onVipBloqueado: () => bloqueios++,
            onEnviarFala: (_, __) {},
            onEnviarEmoji: (_) {},
            onPresentearSalao: (_) {},
            onPresentearJogador: (_) {},
            onConvidar: (_) {},
            onAssistir: (_) {},
            onEntrarMesa: (_) {},
          ),
        ),
      );

      await tester.tap(find.textContaining('VIP', findRichText: true).first);
      await tester.pump();

      expect(trocas, isEmpty, reason: 'nao pode entrar no Salao VIP sem direito');
      expect(bloqueios, greaterThan(0), reason: 'o gate precisa ter disparado');
    });

    testWidgets('SALAO-02 a aba VIP aparece com CADEADO para quem nao tem',
        (tester) async {
      await _telefone(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: SaguaoScreen(
            vm: SaguaoVM.mock(sala: SalaSaguao.publico),
            onVoltar: () {},
            onTrocarSala: (_) {},
            onVipBloqueado: () {},
            onEnviarFala: (_, __) {},
            onEnviarEmoji: (_) {},
            onPresentearSalao: (_) {},
            onPresentearJogador: (_) {},
            onConvidar: (_) {},
            onAssistir: (_) {},
            onEntrarMesa: (_) {},
          ),
        ),
      );

      expect(find.textContaining('🔒'), findsWidgets);
    });

    testWidgets('SALAO-03 com VIP, tocar na aba VIP TROCA de sala',
        (tester) async {
      await _telefone(tester);

      final trocas = <SalaSaguao>[];
      var bloqueios = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SaguaoScreen(
            vm: SaguaoVM.mock(sala: SalaSaguao.publico, ehVip: true),
            onVoltar: () {},
            onTrocarSala: trocas.add,
            onVipBloqueado: () => bloqueios++,
            onEnviarFala: (_, __) {},
            onEnviarEmoji: (_) {},
            onPresentearSalao: (_) {},
            onPresentearJogador: (_) {},
            onConvidar: (_) {},
            onAssistir: (_) {},
            onEntrarMesa: (_) {},
          ),
        ),
      );

      await tester.tap(find.textContaining('VIP', findRichText: true).first);
      await tester.pump();

      // O enforcement nao pode ser "bloquear sempre": quem paga tem que entrar.
      expect(trocas, contains(SalaSaguao.vip));
      expect(bloqueios, 0);
    });
  });

  // =========================================================================
  // =========================================================================
  // APOSENTADO — MESA-01 e MESA-02 (bloqueio de tipos pagos na tela)
  // =========================================================================
  //
  // O QUE ELES PROTEGIAM, e continua protegido: sem VIP, os tipos pagos não
  // podem ser escolhidos; com VIP, podem.
  //
  // POR QUE SAÍRAM DAQUI: eles tocavam em "VIP" dentro de `ConfigurarMesaScreen`
  // e liam o callback `onTipoBloqueado`. Aquela tela deixou de ESCOLHER o tipo —
  // hoje ela configura um tipo já escolhido, e o seu título é "Configurar Mesa
  // VIP". O callback continuava declarado e nunca era invocado, então estes dois
  // casos passaram a medir uma responsabilidade que mudou de endereço. Mantê-los
  // verdes exigiria devolver o seletor para cá, que é justamente o que a
  // composição decidiu não fazer.
  //
  // ONDE A PROVA VIVE AGORA, e são DUAS camadas:
  //
  //   UX ............. test/mesa/gate_vip_selecao_test.dart
  //                    SEL-01 (sem VIP não prossegue), SEL-02 (com VIP prossegue),
  //                    SEL-03 (o gate é da opção paga, não um cadeado geral),
  //                    SEL-04 (mock não concede por omissão),
  //                    SEL-05 (estado desconhecido falha fechado).
  //
  //   AUTORIDADE ..... functions-mesas/test/elegibilidade.test.js
  //                    functions-mesas/test/decisao.test.js
  //                    functions-mesas/test/politica.test.js
  //                    É ela que recusa cliente adulterado, deep link e mensagem
  //                    forjada — coisas que teste de widget nunca provou.
  //
  //   AS DUAS JUNTAS . CRUZ-01, no mesmo arquivo de UX.
  //
  // Nenhum teste de backend foi removido ou enfraquecido nesta migração.

  // =========================================================================
  group('ESCOPO — o portao visto pela arvore de widgets', () {
    /// Monta um escopo dirigivel e devolve como ler o acesso de dentro dele.
    Future<AcessoVip Function()> montarEscopo(
      WidgetTester tester, {
      required StreamController<String?> sessoes,
      required StreamController<EntitlementVip> documentos,
      bool comEscopo = true,
    }) async {
      final portao = PortaoVip(
        fonte: (_) => documentos.stream,
        relogio: () => _agora,
      );
      addTearDown(portao.encerrar);

      late AcessoVip visto;
      final leitor = Builder(
        builder: (context) {
          visto = EscopoVip.de(context);
          return const SizedBox.shrink();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: comEscopo
              ? EscopoVip(
                  portao: portao,
                  sessoes: sessoes.stream,
                  child: leitor,
                )
              : leitor,
        ),
      );
      return () => visto;
    }

    testWidgets('ESC-01 fora do escopo, o acesso e BLOQUEADO', (tester) async {
      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final ler = await montarEscopo(
        tester,
        sessoes: sessoes,
        documentos: docs,
        comEscopo: false,
      );

      // Um widget montado por engano fora da arvore do escopo PERDE o VIP.
      // Nunca ganha — a direcao certa da falha.
      expect(ler().liberado, isFalse);
    });

    testWidgets('ESC-02 com sessao e sem documento, ainda bloqueado (sem flicker)',
        (tester) async {
      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final ler = await montarEscopo(tester, sessoes: sessoes, documentos: docs);

      sessoes.add('jogador-a');
      await _assentar(tester);

      expect(ler().liberado, isFalse);
      expect(ler().carregando, isTrue);
    });

    testWidgets('ESC-03 o documento vigente acende o VIP na arvore',
        (tester) async {
      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final ler = await montarEscopo(tester, sessoes: sessoes, documentos: docs);

      sessoes.add('jogador-a');
      await _assentar(tester);
      docs.add(_vigente('jogador-a'));
      await _assentar(tester);

      expect(ler().liberado, isTrue);
    });

    testWidgets('ESC-04 logout APAGA o VIP da arvore', (tester) async {
      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final ler = await montarEscopo(tester, sessoes: sessoes, documentos: docs);

      sessoes.add('jogador-a');
      await _assentar(tester);
      docs.add(_vigente('jogador-a'));
      await _assentar(tester);
      expect(ler().liberado, isTrue);

      sessoes.add(null);
      await _assentar(tester);

      expect(ler().liberado, isFalse);
      expect(ler().situacao, SituacaoVip.semSessao);
    });

    testWidgets('ESC-05 B entrando depois de A nao herda o VIP na arvore',
        (tester) async {
      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final ler = await montarEscopo(tester, sessoes: sessoes, documentos: docs);

      sessoes.add('jogador-a');
      await _assentar(tester);
      docs.add(_vigente('jogador-a'));
      await _assentar(tester);
      expect(ler().liberado, isTrue);

      sessoes.add('jogador-b');
      await _assentar(tester);

      expect(ler().liberado, isFalse, reason: 'B nao herda o direito de A');
      expect(ler().uid, 'jogador-b');
    });

    testWidgets('ESC-06 falha na leitura bloqueia, e nao vira VIP',
        (tester) async {
      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final ler = await montarEscopo(tester, sessoes: sessoes, documentos: docs);

      sessoes.add('jogador-a');
      await _assentar(tester);
      docs.addError('firestore fora do ar');
      await _assentar(tester);

      expect(ler().liberado, isFalse);
      expect(ler().situacao, SituacaoVip.erro);
    });
  });

  // =========================================================================
  group('ASSINAR — o botao de assinatura (criterio de reprovacao 4)', () {
    testWidgets(
        'ASSIN-01 tocar em Assinar NAO acende o VIP: so o backend acende',
        (tester) async {
      await _telefone(tester);

      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final portao = PortaoVip(
        fonte: (_) => docs.stream,
        relogio: () => _agora,
      );
      addTearDown(portao.encerrar);

      // A tela de exemplo reproduz o padrao dos hosts de `main.dart`: `ehVip`
      // e DERIVADO do escopo a cada build, e o callback de assinatura nao tem
      // como escrever nele. O que existia antes — `setState(ehVip = true)` — e
      // literalmente inexprimivel aqui.
      var toquesEmAssinar = 0;
      late AcessoVip acesso;

      await tester.pumpWidget(
        MaterialApp(
          home: EscopoVip(
            portao: portao,
            sessoes: sessoes.stream,
            child: Builder(
              builder: (context) {
                acesso = EscopoVip.de(context);
                return Scaffold(
                  body: Column(
                    children: [
                      Text(acesso.liberado ? 'VIP ATIVO' : 'SEM VIP'),
                      ElevatedButton(
                        onPressed: () => toquesEmAssinar++,
                        child: const Text('Assinar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      sessoes.add('jogador-a');
      await _assentar(tester);
      docs.add(const EntitlementVip.ausente('jogador-a'));
      await _assentar(tester);
      expect(find.text('SEM VIP'), findsOneWidget);

      // 1) o jogador toca em Assinar
      await tester.tap(find.text('Assinar'));
      await tester.pump();
      expect(toquesEmAssinar, 1);

      // 2) a compra NAO concluiu — nada mudou no backend
      expect(find.text('SEM VIP'), findsOneWidget);
      expect(acesso.liberado, isFalse);

      // 3) mesmo tocando varias vezes
      await tester.tap(find.text('Assinar'));
      await tester.tap(find.text('Assinar'));
      await tester.pump();
      expect(find.text('SEM VIP'), findsOneWidget);

      // 4) o backend confirma e grava o entitlement
      docs.add(_vigente('jogador-a'));
      await _assentar(tester);

      // 5) SO AGORA o VIP acende
      expect(find.text('VIP ATIVO'), findsOneWidget);
      expect(acesso.liberado, isTrue);
    });

    testWidgets('ASSIN-02 compra que fica pendente nao libera nada',
        (tester) async {
      await _telefone(tester);

      final sessoes = StreamController<String?>.broadcast();
      final docs = StreamController<EntitlementVip>.broadcast();
      addTearDown(sessoes.close);
      addTearDown(docs.close);

      final portao = PortaoVip(fonte: (_) => docs.stream, relogio: () => _agora);
      addTearDown(portao.encerrar);

      late AcessoVip acesso;
      await tester.pumpWidget(
        MaterialApp(
          home: EscopoVip(
            portao: portao,
            sessoes: sessoes.stream,
            child: Builder(
              builder: (context) {
                acesso = EscopoVip.de(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      sessoes.add('jogador-a');
      await _assentar(tester);

      // A Play aceitou o pedido mas o pagamento nao se concretizou: o backend
      // grava `pendente`, que nao concede.
      docs.add(
        EntitlementVip(
          uid: 'jogador-a',
          vipAtivo: false,
          estado: EstadoEntitlement.pendente,
          expiraEm: _agora.add(const Duration(days: 30)),
        ),
      );
      await tester.pump();

      expect(acesso.liberado, isFalse);
    });
  });
}
