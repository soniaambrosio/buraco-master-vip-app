// portao_vip_test.dart — o PORTAO do cliente, estado por estado.
//
// O QUE ESTA SUITE PROVA, EM UMA FRASE
//
// Nao existe entrada neste objeto capaz de produzir acesso VIP a nao ser um
// documento de `playerEntitlements/{uid}` vigente. Todo o resto — ausencia de
// sessao, documento ainda nao chegado, leitura com erro, direito expirado,
// revogado, pausado, em espera, pendente, documento de OUTRO jogador — bloqueia.
//
// A suite e escrita contra os criterios de reprovacao da OS, e nao contra a
// implementacao: cada grupo abaixo corresponde a um item da lista de reprovacao,
// e o nome do teste diz qual.

import 'dart:async';

import 'package:buraco_master_vip/billing/acesso_vip.dart';
import 'package:buraco_master_vip/elegibilidade/entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

/// O instante de referencia de toda a suite. Fixo, porque vigencia e uma conta
/// contra o relogio e um `DateTime.now()` solto tornaria os casos de borda
/// irreprodutiveis.
final DateTime _agora = DateTime.utc(2026, 8, 15, 12);

/// Uma fonte de entitlement roteirizada, no lugar do Firestore.
class _FonteFalsa {
  final Map<String, StreamController<EntitlementVip>> _canais = {};

  /// Quantas escutas foram abertas por uid. E o contador que prova que a troca
  /// de sessao NAO reaproveita a escuta do jogador anterior.
  final Map<String, int> escutasPorUid = {};

  Stream<EntitlementVip> observar(String uid) {
    escutasPorUid[uid] = (escutasPorUid[uid] ?? 0) + 1;
    final canal = _canais.putIfAbsent(
      uid,
      () => StreamController<EntitlementVip>.broadcast(),
    );
    return canal.stream;
  }

  void entregar(String uid, EntitlementVip documento) {
    _canais[uid]?.add(documento);
  }

  void falhar(String uid, [Object erro = 'firestore indisponivel']) {
    _canais[uid]?.addError(erro);
  }

  Future<void> fechar() async {
    for (final c in _canais.values) {
      await c.close();
    }
  }
}

/// Um direito VIP em dia.
EntitlementVip _vigente(String uid) => EntitlementVip(
      uid: uid,
      vipAtivo: true,
      estado: EstadoEntitlement.ativo,
      produtoId: 'vip_assinatura',
      origem: 'play',
      inicioEm: _agora.subtract(const Duration(days: 10)),
      expiraEm: _agora.add(const Duration(days: 20)),
      renovacaoAutomatica: true,
    );

void main() {
  late _FonteFalsa fonte;
  late PortaoVip portao;

  setUp(() {
    fonte = _FonteFalsa();
    portao = PortaoVip(fonte: fonte.observar, relogio: () => _agora);
  });

  tearDown(() async {
    await portao.encerrar();
    await fonte.fechar();
  });

  // =========================================================================
  group('PVIP — o estado inicial (criterio de reprovacao 5: loading concede)',
      () {
    test('PVIP-01 recem-criado, sem sessao, NAO libera', () {
      expect(portao.atual.situacao, SituacaoVip.semSessao);
      expect(portao.atual.liberado, isFalse);
    });

    test('PVIP-02 com sessao e sem documento ainda, NAO libera', () {
      portao.usarSessao('jogador-a');
      expect(portao.atual.situacao, SituacaoVip.carregando);
      expect(portao.atual.liberado, isFalse);
    });

    test('PVIP-03 carregando e DISTINGUIVEL de sem direito', () {
      portao.usarSessao('jogador-a');
      // A tela precisa poder mostrar espera em vez de empurrar a loja para
      // alguem que talvez ja seja assinante.
      expect(portao.atual.carregando, isTrue);
      expect(portao.atual.podeOferecerAssinatura, isFalse);
    });
  });

  // =========================================================================
  group('PVIP — o direito vigente e a UNICA coisa que libera', () {
    test('PVIP-04 documento vigente do proprio uid libera', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();

      expect(portao.atual.situacao, SituacaoVip.liberado);
      expect(portao.atual.liberado, isTrue);
      expect(portao.atual.uid, 'jogador-a');
    });

    test('PVIP-05 entitlement ausente NAO libera', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', const EntitlementVip.ausente('jogador-a'));
      await pumpEventQueue();

      expect(portao.atual.situacao, SituacaoVip.semDireito);
      expect(portao.atual.liberado, isFalse);
      // Aqui, e SO aqui, oferecer assinatura faz sentido.
      expect(portao.atual.podeOferecerAssinatura, isTrue);
    });

    test('PVIP-06 direito EXPIRADO nao libera, mesmo com vipAtivo gravado',
        () async {
      portao.usarSessao('jogador-a');
      // O caso que a varredura de vencimento do backend pode nao ter fechado
      // ainda: `vipAtivo: true` no documento, prazo ja vencido no relogio.
      fonte.entregar(
        'jogador-a',
        EntitlementVip(
          uid: 'jogador-a',
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: _agora.subtract(const Duration(minutes: 1)),
        ),
      );
      await pumpEventQueue();

      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.situacao, SituacaoVip.semDireito);
    });

    test('PVIP-07 direito sem prazo nao libera', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar(
        'jogador-a',
        const EntitlementVip(
          uid: 'jogador-a',
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          // expiraEm ausente: dado incompleto recusa.
        ),
      );
      await pumpEventQueue();

      expect(portao.atual.liberado, isFalse);
    });

    test('PVIP-08 os estados que NAO concedem acesso bloqueiam, um a um',
        () async {
      portao.usarSessao('jogador-a');

      for (final estado in [
        EstadoEntitlement.revogado,
        EstadoEntitlement.reembolsado,
        EstadoEntitlement.emEspera,
        EstadoEntitlement.pausado,
        EstadoEntitlement.pendente,
        EstadoEntitlement.expirado,
        EstadoEntitlement.nuncaTeve,
        EstadoEntitlement.desconhecido,
      ]) {
        fonte.entregar(
          'jogador-a',
          EntitlementVip(
            uid: 'jogador-a',
            // vipAtivo VERDADEIRO de proposito: um documento incoerente
            // (revogado + ativo) nao pode passar pela porta.
            vipAtivo: true,
            estado: estado,
            expiraEm: _agora.add(const Duration(days: 30)),
          ),
        );
        await pumpEventQueue();

        expect(
          portao.atual.liberado,
          isFalse,
          reason: 'estado ${estado.wire} nao pode conceder acesso',
        );
      }
    });

    test('PVIP-09 os estados que concedem acesso liberam, um a um', () async {
      portao.usarSessao('jogador-a');

      for (final estado in [
        EstadoEntitlement.ativo,
        EstadoEntitlement.emCarencia,
        EstadoEntitlement.canceladoVigente,
      ]) {
        fonte.entregar(
          'jogador-a',
          EntitlementVip(
            uid: 'jogador-a',
            vipAtivo: true,
            estado: estado,
            expiraEm: _agora.add(const Duration(days: 30)),
          ),
        );
        await pumpEventQueue();

        expect(
          portao.atual.liberado,
          isTrue,
          reason: 'estado ${estado.wire} deveria conceder acesso',
        );
      }
    });

    test('PVIP-10 vipAtivo falso nao libera nem com prazo no futuro', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar(
        'jogador-a',
        EntitlementVip(
          uid: 'jogador-a',
          vipAtivo: false,
          estado: EstadoEntitlement.ativo,
          expiraEm: _agora.add(const Duration(days: 30)),
        ),
      );
      await pumpEventQueue();

      expect(portao.atual.liberado, isFalse);
    });
  });

  // =========================================================================
  group('PVIP — a vigencia e recalculada, nao guardada', () {
    test('PVIP-11 o mesmo documento deixa de liberar quando o relogio passa',
        () async {
      // O portao guarda FATOS e nao o veredito. Se ele guardasse `liberado`,
      // um direito que vence com a tela aberta continuaria valendo ate algum
      // evento novo chegar — e expiracao nao produz escrita no Firestore no
      // segundo exato do vencimento.
      var agora = DateTime.utc(2026, 8, 15, 12);
      final relogioMovel = PortaoVip(
        fonte: fonte.observar,
        relogio: () => agora,
      );
      addTearDown(relogioMovel.encerrar);

      relogioMovel.usarSessao('jogador-a');
      fonte.entregar(
        'jogador-a',
        EntitlementVip(
          uid: 'jogador-a',
          vipAtivo: true,
          estado: EstadoEntitlement.ativo,
          expiraEm: agora.add(const Duration(hours: 1)),
        ),
      );
      await pumpEventQueue();
      expect(relogioMovel.atual.liberado, isTrue);

      // Nenhum evento novo. Só o tempo.
      agora = agora.add(const Duration(hours: 2));
      expect(relogioMovel.atual.liberado, isFalse);
      expect(relogioMovel.atual.situacao, SituacaoVip.semDireito);
    });
  });

  // =========================================================================
  group('PVIP — erro (criterio de reprovacao 5 e 7: erro/fallback concede)',
      () {
    test('PVIP-12 falha na leitura NAO libera', () async {
      portao.usarSessao('jogador-a');
      fonte.falhar('jogador-a');
      await pumpEventQueue();

      expect(portao.atual.situacao, SituacaoVip.erro);
      expect(portao.atual.liberado, isFalse);
    });

    test('PVIP-13 falha DERRUBA um direito que ja estava valendo', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);

      fonte.falhar('jogador-a');
      await pumpEventQueue();

      // Manter o ultimo valor bom deixaria um jogador cujo documento ficou
      // ilegivel seguir VIP por tempo indeterminado.
      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.situacao, SituacaoVip.erro);
    });

    test('PVIP-14 erro nao e confundido com ausencia de direito', () async {
      portao.usarSessao('jogador-a');
      fonte.falhar('jogador-a');
      await pumpEventQueue();

      // A tela deve oferecer "tentar de novo", nunca "assine de novo".
      expect(portao.atual.podeOferecerAssinatura, isFalse);
      expect(portao.atual.entitlement, isNull);
    });

    test('PVIP-15 um documento bom depois do erro reabre o acesso', () async {
      portao.usarSessao('jogador-a');
      fonte.falhar('jogador-a');
      await pumpEventQueue();
      expect(portao.atual.situacao, SituacaoVip.erro);

      // Erro nao e permanente: o backend voltando a responder restabelece o
      // direito de quem o tem.
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();

      expect(portao.atual.liberado, isTrue);
    });
  });

  // =========================================================================
  group('PVIP — logout e troca de conta (criterio de reprovacao 6)', () {
    test('PVIP-16 logout apaga o direito imediatamente', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);

      portao.usarSessao(null);

      // SINCRONO: nao ha ida a rede entre o logout e a perda de acesso.
      expect(portao.atual.situacao, SituacaoVip.semSessao);
      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.entitlement, isNull);
    });

    test('PVIP-17 B NAO herda o VIP de A — e nem por um instante', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);

      // A troca acontece. O documento de B ainda NAO chegou — `snapshots()` nao
      // entrega de forma sincrona, e e nesse intervalo que o defeito viveria.
      portao.usarSessao('jogador-b');

      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.situacao, SituacaoVip.carregando);
      expect(portao.atual.uid, 'jogador-b');
      expect(portao.atual.entitlement, isNull);
    });

    test('PVIP-18 o direito de B so aparece quando o documento de B chega',
        () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();

      portao.usarSessao('jogador-b');
      await pumpEventQueue();
      expect(portao.atual.liberado, isFalse);

      fonte.entregar('jogador-b', const EntitlementVip.ausente('jogador-b'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.situacao, SituacaoVip.semDireito);

      fonte.entregar('jogador-b', _vigente('jogador-b'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);
      expect(portao.atual.uid, 'jogador-b');
    });

    test('PVIP-19 evento ATRASADO da escuta de A nao decide nada para B',
        () async {
      portao.usarSessao('jogador-a');
      portao.usarSessao('jogador-b');

      // A escuta de A foi cancelada, mas um broadcast pendente ainda podia
      // chegar. Ele nao pode virar VIP para B.
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();

      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.uid, 'jogador-b');
    });

    test('PVIP-20 documento cujo uid nao e o da sessao nunca libera', () async {
      portao.usarSessao('jogador-b');
      // Um documento de A entregue no canal de B — a corrida que a trava final
      // do portao existe para cobrir.
      fonte.entregar('jogador-b', _vigente('jogador-a'));
      await pumpEventQueue();

      expect(portao.atual.liberado, isFalse);
      expect(portao.atual.situacao, SituacaoVip.carregando);
    });

    test('PVIP-21 a troca abre escuta NOVA, e nao reaproveita a de A', () {
      portao.usarSessao('jogador-a');
      portao.usarSessao('jogador-b');

      expect(fonte.escutasPorUid['jogador-a'], 1);
      expect(fonte.escutasPorUid['jogador-b'], 1);
    });

    test('PVIP-22 repetir o mesmo uid nao reinicia a escuta nem derruba o VIP',
        () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);

      // `authStateChanges()` reemite em refresh de token. Derrubar o direito
      // aqui reabriria a janela de espera sem nenhum motivo.
      portao.usarSessao('jogador-a');

      expect(portao.atual.liberado, isTrue);
      expect(fonte.escutasPorUid['jogador-a'], 1);
    });

    test('PVIP-23 A volta depois de B, e le o direito de A de novo', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();

      portao.usarSessao('jogador-b');
      await pumpEventQueue();
      expect(portao.atual.liberado, isFalse);

      portao.usarSessao('jogador-a');
      // De novo em espera: o direito de A nao ficou guardado em canto nenhum.
      expect(portao.atual.situacao, SituacaoVip.carregando);
      expect(portao.atual.liberado, isFalse);

      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);
    });
  });

  // =========================================================================
  group('PVIP — quem observa ve a queda', () {
    test('PVIP-24 a perda de direito e PUBLICADA, nao apenas legivel',
        () async {
      final vistos = <SituacaoVip>[];
      portao.mudancas.listen((a) => vistos.add(a.situacao));

      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      portao.usarSessao(null);
      await pumpEventQueue();

      expect(vistos, contains(SituacaoVip.carregando));
      expect(vistos, contains(SituacaoVip.liberado));
      expect(vistos.last, SituacaoVip.semSessao);
    });

    test('PVIP-25 encerrar() nao volta a conceder nada', () async {
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isTrue);

      await portao.encerrar();
      expect(portao.atual.liberado, isFalse);

      // Depois de encerrado, nem uma nova sessao reabre o portao.
      portao.usarSessao('jogador-a');
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      expect(portao.atual.liberado, isFalse);
    });
  });

  // =========================================================================
  group('PVIP — a superficie do objeto (criterio de reprovacao 1, 3, 4, 7)',
      () {
    test('PVIP-26 AcessoVip.indefinido bloqueia', () {
      const fora = AcessoVip.indefinido();
      expect(fora.liberado, isFalse);
      expect(fora.bloqueado, isTrue);
      expect(fora.carregando, isTrue);
    });

    test('PVIP-27 toda situacao ALCANCAVEL que nao seja `liberado` bloqueia',
        () async {
      // Percorre as situacoes pelos caminhos REAIS que as produzem e conferem
      // que so uma delas concede. E a rede que pega um estado novo adicionado
      // amanha sem gate correspondente: ele cairia aqui como nao coberto.
      final alcancadas = <SituacaoVip, bool>{};

      void anotar() => alcancadas[portao.atual.situacao] = portao.atual.liberado;

      anotar(); // semSessao
      portao.usarSessao('jogador-a');
      anotar(); // carregando
      fonte.entregar('jogador-a', const EntitlementVip.ausente('jogador-a'));
      await pumpEventQueue();
      anotar(); // semDireito
      fonte.falhar('jogador-a');
      await pumpEventQueue();
      anotar(); // erro
      fonte.entregar('jogador-a', _vigente('jogador-a'));
      await pumpEventQueue();
      anotar(); // liberado

      expect(
        alcancadas.keys.toSet(),
        SituacaoVip.values.toSet(),
        reason: 'toda situacao declarada precisa ser alcancavel e coberta aqui',
      );
      alcancadas.forEach((situacao, liberou) {
        expect(
          liberou,
          situacao == SituacaoVip.liberado,
          reason: '${situacao.name} concedeu acesso e nao deveria',
        );
      });
    });
  });
}
