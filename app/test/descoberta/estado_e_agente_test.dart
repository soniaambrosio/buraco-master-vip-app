// estado_e_agente_test.dart — geração, revisão e RITMO (OS 38.2 §7 e §8.3).
//
// O que está sob julgamento aqui é a única parte da descoberta que o cliente
// decide sozinho: QUANDO um retrato substitui o outro, e QUANDO um pedido sai.
//
// As duas coisas são de estado puro — sem socket, sem tela, sem Firebase — e
// por isso são provadas na primitiva. Um caso que precisasse montar aplicativo
// para afirmar "revisão menor é descartada" estaria medindo a árvore de widgets
// e não a regra.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/descoberta/adaptador_descoberta.dart';
import 'package:buraco_master_vip/descoberta/agente_descoberta.dart';
import 'package:buraco_master_vip/descoberta/contrato_descoberta.dart';
import 'package:buraco_master_vip/descoberta/estado_descoberta.dart';

import 'retrato_de_teste.dart';

void main() {
  // =========================================================================
  group('§7 — GERAÇÃO E REVISÃO', () {
    // =======================================================================

    test('ES-01 o primeiro retrato de uma geração é aceito', () {
      final e = EstadoDaDescoberta();
      expect(e.retrato, isNull);
      expect(e.fase, FaseDaDescoberta.ociosa);

      expect(_aplicar(e, retratoDeMesas(revisao: 7)), isTrue);
      expect(e.retrato!.revisao, 7);
      expect(e.fase, FaseDaDescoberta.disponivel);
      expect(e.ultimaRecusa, isNull);
    });

    test('ES-02 mesma geração e revisão MAIOR: aceita', () {
      final e = _comRetrato(revisao: 3);
      expect(_aplicar(e, retratoDeMesas(revisao: 4)), isTrue);
      expect(e.retrato!.revisao, 4);
    });

    test('ES-03 mesma geração e revisão IGUAL: descarta', () {
      final e = _comRetrato(revisao: 3, mesas: [mesa(codigo: 'M-01')]);
      expect(_aplicar(e, retratoDeMesas(revisao: 3)), isFalse);
      expect(e.ultimaRecusa, MotivoDeDescarte.revisaoAtrasada);
      // E o retrato ANTERIOR continua — descartar não é esvaziar.
      expect(e.retrato!.mesas, hasLength(1));
    });

    test('ES-04 mesma geração e revisão MENOR: descarta', () {
      final e = _comRetrato(revisao: 9, mesas: [mesa(codigo: 'M-01')]);
      expect(_aplicar(e, retratoDeMesas(revisao: 2)), isFalse);
      expect(e.ultimaRecusa, MotivoDeDescarte.revisaoAtrasada);
      expect(e.retrato!.revisao, 9);
    });

    test('ES-05 RESPOSTA ATRASADA: o retrato velho não desfaz o novo', () {
      final e = EstadoDaDescoberta();
      // A rede entrega fora de ordem: o retrato 5 chega antes do 4.
      expect(
        _aplicar(
          e,
          retratoDeMesas(revisao: 5, mesas: [mesa(codigo: 'A'), mesa(codigo: 'B')]),
        ),
        isTrue,
      );
      expect(
        _aplicar(e, retratoDeMesas(revisao: 4, mesas: [mesa(codigo: 'A')])),
        isFalse,
      );
      expect(e.retrato!.revisao, 5);
      expect(e.retrato!.mesas, hasLength(2));
    });

    test('ES-06 GERAÇÃO DIFERENTE substitui integralmente, mesmo indo para trás', () {
      final e = _comRetrato(
        geracao: 'ger-antiga',
        revisao: 4812,
        mesas: [mesa(codigo: 'A'), mesa(codigo: 'B')],
      );
      // O servidor reiniciou: geração nova, revisão baixa. Comparar números
      // aqui descartaria tudo para sempre.
      expect(
        _aplicar(
          e,
          retratoDeMesas(geracao: 'ger-nova', revisao: 1, mesas: [mesa(codigo: 'Z')]),
        ),
        isTrue,
      );
      expect(e.retrato!.geracao, 'ger-nova');
      expect(e.retrato!.revisao, 1);
      expect(e.retrato!.mesas.single.codigo, 'Z');
    });

    test('ES-07 TRANSPORTE ANTERIOR: descartado antes de qualquer leitura', () {
      final e = EstadoDaDescoberta()..definirGeracaoDeTransporte(2);
      final aceitou = e.aplicar(
        retratoDeMesas(revisao: 99),
        geracaoDeTransporte: 1,
      );
      expect(aceitou, isFalse);
      expect(e.ultimaRecusa, MotivoDeDescarte.transporteAnterior);
      expect(e.retrato, isNull);
    });

    test('ES-08 retrato INVÁLIDO não substitui o válido anterior', () {
      final e = _comRetrato(revisao: 2, mesas: [mesa(codigo: 'M-01')]);
      final podre = retratoDeMesas(revisao: 3)..['esquema'] = 'outro';
      expect(_aplicar(e, podre), isFalse);
      expect(e.ultimaRecusa, MotivoDeDescarte.retratoInvalido);
      expect(e.detalheDaRecusa, RecusaDeRetrato.esquemaDesconhecido);
      // O que estava na tela continua.
      expect(e.retrato!.revisao, 2);
      expect(e.retrato!.mesas, hasLength(1));
      expect(e.fase, FaseDaDescoberta.disponivel);
    });

    test('ES-09 sem retrato anterior, um inválido vira estado explícito', () {
      final e = EstadoDaDescoberta();
      expect(_aplicar(e, retratoDeMesas()..['esquema'] = 'outro'), isFalse);
      expect(e.fase, FaseDaDescoberta.retratoInvalido);
      expect(e.retrato, isNull);
    });

    test('ES-10 LOGOUT apaga tudo — é o único caminho que apaga', () {
      final e = _comRetrato(mesas: [mesa(codigo: 'M-01')]);
      expect(e.retrato, isNotNull);
      e.encerrarSessao();
      expect(e.retrato, isNull);
      expect(e.fase, FaseDaDescoberta.sessaoEncerrada);
      expect(e.jogadoresOnlineTotal, isNull);
    });

    test('ES-11 TROCA A→B: nada de A sobrevive, nem por revisão alta', () {
      final e = _comRetrato(
        geracao: 'ger-A',
        revisao: 500,
        mesas: [mesa(codigo: 'DE-A')],
      );
      // Logout de A e login de B: transporte novo, estado zerado.
      e.encerrarSessao();
      e.definirGeracaoDeTransporte(2);
      // Uma resposta ATRASADA de A ainda em voo não pode voltar a valer.
      expect(
        e.aplicar(
          retratoDeMesas(geracao: 'ger-A', revisao: 501, mesas: [mesa(codigo: 'DE-A')]),
          geracaoDeTransporte: 1,
        ),
        isFalse,
      );
      expect(e.retrato, isNull);
      // O primeiro retrato de B entra normalmente.
      expect(
        e.aplicar(
          retratoDeMesas(geracao: 'ger-B', revisao: 1, mesas: [mesa(codigo: 'DE-B')]),
          geracaoDeTransporte: 2,
        ),
        isTrue,
      );
      expect(e.retrato!.mesas.single.codigo, 'DE-B');
    });

    test('ES-12 desconhecido NÃO é zero', () {
      final e = EstadoDaDescoberta();
      expect(e.jogadoresOnlineTotal, isNull);
      // Zero REAL é zero, e é diferente de não saber.
      _aplicar(e, retratoDeMesas(mesas: const [], jogadoresOnlineTotal: 0));
      expect(e.jogadoresOnlineTotal, 0);
    });

    test('ES-13 vazio real e sem-ingressáveis são estados distintos', () {
      final vazio = _comRetrato(mesas: const []);
      expect(vazio.vazioReal, isTrue);
      expect(vazio.semIngressaveis, isFalse);

      final cheio = _comRetrato(
        mesas: [mesa(codigo: 'M-01', humanos: 1, bots: 3, iniciada: true)],
      );
      expect(cheio.vazioReal, isFalse);
      expect(cheio.semIngressaveis, isTrue);

      final semRetrato = EstadoDaDescoberta();
      expect(semRetrato.vazioReal, isFalse, reason: 'não saber não é estar vazio');
    });

    test('ES-14 fases de transporte preservam o retrato', () {
      final e = _comRetrato(mesas: [mesa(codigo: 'M-01')]);
      e.marcarReconectando();
      expect(e.fase, FaseDaDescoberta.reconectando);
      expect(e.retrato, isNotNull);
      e.marcarServidorIndisponivel();
      expect(e.fase, FaseDaDescoberta.servidorIndisponivel);
      expect(e.retrato, isNotNull);
      e.marcarAguardandoRetrato();
      expect(e.fase, FaseDaDescoberta.disponivel);
    });

    test('ES-15 pedido em voo vira "carregando" só quando não há retrato', () {
      final vazio = EstadoDaDescoberta()..marcarPedidoEmVoo();
      expect(vazio.fase, FaseDaDescoberta.carregando);
      expect(vazio.atualizando, isTrue);

      final comRetrato = _comRetrato(mesas: [mesa(codigo: 'M-01')])
        ..marcarPedidoEmVoo();
      expect(comRetrato.fase, FaseDaDescoberta.disponivel);
      expect(comRetrato.atualizando, isTrue);
    });
  });

  // =========================================================================
  group('§8.3 — RITMO', () {
    // =======================================================================

    test('AG-16 iniciar pede a lista e pulsa IMEDIATAMENTE', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        expect(a.pedidosDeMesasEnviados, 1);
        expect(a.pulsosEnviados, 1);
        a.descartar();
      });
    });

    test('AG-17 iniciar DUAS vezes não cria dois pares de timers', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        a.iniciar();
        a.iniciar();
        expect(a.pedidosDeMesasEnviados, 1, reason: 'tempestade de reconstrução');
        tempo.elapse(const Duration(seconds: 5));
        expect(a.pedidosDeMesasEnviados, 2, reason: 'um período, um pedido');
        a.descartar();
      });
    });

    test('AG-18 a lista é pedida no período, e não a cada quadro', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        tempo.elapse(const Duration(seconds: 16));
        // 1 imediato + 3 períodos de 5 s.
        expect(a.pedidosDeMesasEnviados, 4);
        a.descartar();
      });
    });

    test('AG-19 o botão Atualizar respeita o piso de 1 s do servidor', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        final base = a.pedidosDeMesasEnviados;
        // Dez toques em sequência.
        for (var i = 0; i < 10; i++) {
          a.solicitarMesas();
        }
        expect(
          a.pedidosDeMesasEnviados,
          base,
          reason: 'apertar dez vezes não manda dez pedidos',
        );
        tempo.elapse(ContratoDaDescoberta.ritmoMinimoDeMesas);
        expect(a.solicitarMesas(), isTrue);
        expect(a.pedidosDeMesasEnviados, base + 1);
        a.descartar();
      });
    });

    test('AG-20 o pulso respeita o piso de 5 s', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        expect(a.pulsosEnviados, 1);
        tempo.elapse(const Duration(seconds: 4));
        expect(a.pulsosEnviados, 1);
        tempo.elapse(const Duration(seconds: 2));
        expect(a.pulsosEnviados, 2);
        a.descartar();
      });
    });

    test('AG-21 o intervalo do pulso passa a ser o SUGERIDO pelo servidor', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        a.aoReceberRecibo(intervaloSugerido: const Duration(seconds: 15));
        expect(a.intervaloDePulso, const Duration(seconds: 15));
        final base = a.pulsosEnviados;
        tempo.elapse(const Duration(seconds: 14));
        expect(a.pulsosEnviados, base);
        tempo.elapse(const Duration(seconds: 2));
        expect(a.pulsosEnviados, base + 1);
        a.descartar();
      });
    });

    test('AG-22 sugestão abaixo do piso é elevada ao piso', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        a.aoReceberRecibo(intervaloSugerido: const Duration(milliseconds: 10));
        expect(a.intervaloDePulso, ContratoDaDescoberta.ritmoMinimoDePulso);
        a.descartar();
      });
    });

    test('AG-23 parar cancela os DOIS timers — nenhum órfão', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        final mesas = a.pedidosDeMesasEnviados;
        final pulsos = a.pulsosEnviados;
        a.parar();
        tempo.elapse(const Duration(minutes: 5));
        expect(a.pedidosDeMesasEnviados, mesas);
        expect(a.pulsosEnviados, pulsos);
        expect(a.ligado, isFalse);
        a.descartar();
      });
    });

    test('AG-24 depois de DESCARTAR, iniciar não religa nada', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        final mesas = a.pedidosDeMesasEnviados;
        a.descartar();
        a.iniciar();
        expect(a.ligado, isFalse);
        expect(a.solicitarMesas(forcado: true), isFalse);
        tempo.elapse(const Duration(minutes: 5));
        expect(a.pedidosDeMesasEnviados, mesas);
      });
    });

    test('AG-25 parar e iniciar de novo volta a pedir, sem duplicar', () {
      fakeAsync((tempo) {
        final a = _agente(tempo);
        a.iniciar();
        a.parar();
        tempo.elapse(const Duration(seconds: 30));
        a.iniciar();
        final base = a.pedidosDeMesasEnviados;
        tempo.elapse(const Duration(seconds: 5));
        expect(a.pedidosDeMesasEnviados, base + 1);
        a.descartar();
      });
    });
  });
}

// ---------------------------------------------------------------------------
// auxiliares
// ---------------------------------------------------------------------------

/// O agente com o relógio AMARRADO ao `fakeAsync` que o envolve.
///
/// `DateTime.now()` NÃO anda dentro de `fakeAsync` — só os timers andam. Um
/// agente com o relógio real mediria sempre "zero tempo passou", e todo caso de
/// limite de frequência ficaria verde sem exercitar o limite: `solicitarMesas`
/// seria recusada para sempre, e o caso que espera recusa passaria pelo motivo
/// errado.
///
/// `tempo.elapsed` é o relógio do próprio `fakeAsync`, então avançar os timers
/// avança o relógio do agente na mesma medida — que é o que acontece de
/// verdade quando o aparelho fica ligado.
AgenteDeDescoberta _agente(FakeAsync tempo) {
  final base = DateTime.utc(2026, 1, 1);
  return AgenteDeDescoberta(
    pedirMesas: () {},
    pulsar: () {},
    relogio: () => base.add(tempo.elapsed),
  );
}

EstadoDaDescoberta _comRetrato({
  String geracao = 'ger-1',
  int revisao = 1,
  List<Map<String, Object?>> mesas = const [],
}) {
  final e = EstadoDaDescoberta();
  final ok = e.aplicar(
    retratoDeMesas(geracao: geracao, revisao: revisao, mesas: mesas),
    geracaoDeTransporte: 0,
  );
  expect(ok, isTrue, reason: 'o arnês precisa de um retrato válido de partida');
  return e;
}

bool _aplicar(EstadoDaDescoberta e, Object? bruto) =>
    e.aplicar(bruto, geracaoDeTransporte: e.geracaoDeTransporte);
