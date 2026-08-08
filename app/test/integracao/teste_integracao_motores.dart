// PORTÃO DE QUALIDADE — INTEGRAÇÃO MOTOR DE PARTIDAS ↔ MOTOR DE TORNEIOS.
//
// As outras três suítes provam cada motor por dentro. Esta prova a FRONTEIRA:
// que o resultado que sai da mesa é o mesmo que entra na classificação, que
// ninguém vira campeão por causa de ordem de lista, e que rede ruim não vira
// abandono.
//
// Convenções:
//   * nada aqui espera tempo real passar — todo instante entra por parâmetro;
//   * nenhum teste recalcula ponto ou canastra: o valor esperado é lido do
//     próprio Motor de Partidas, porque o que está sendo testado é a CÓPIA;
//   * "queda" nunca é sinônimo de saída: os testes de rede provam justamente
//     que o desfecho não muda.

import 'package:flutter_test/flutter_test.dart';

import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/comando_partida.dart';
import 'package:buraco_master_vip/motor/desfecho_partida.dart';
import 'package:buraco_master_vip/motor/motor_partida.dart';
import 'package:buraco_master_vip/motor/presenca.dart';
import 'package:buraco_master_vip/integracao/adaptador_partida_torneio.dart';
import 'package:buraco_master_vip/integracao/registro_partidas.dart';
import 'package:buraco_master_vip/integracao/vinculo_mesa.dart';
import 'package:buraco_master_vip/torneios/match_contract.dart';
import 'package:buraco_master_vip/torneios/participants.dart';

// ============================== ferramentas ==============================

final DateTime t0 = DateTime.utc(2026, 8, 7, 12, 0, 0);
final DateTime tFim = DateTime.utc(2026, 8, 7, 13, 30, 0);

SolicitacaoPartida solicitacaoIndividual({
  String matchId = 'match-e1-fase-1-mesa-1',
  String tournamentId = 'quarta-master',
  String editionId = 'e1',
  String faseId = 'e1-fase-1',
  String mesaId = 'e1-fase-1-mesa-1',
  String jogadorA = 'ana',
  String jogadorB = 'bruno',
  String modalidade = 'ABERTO',
  int metaPontos = 100,
}) =>
    SolicitacaoPartida(
      matchId: matchId,
      tournamentId: tournamentId,
      editionId: editionId,
      faseId: faseId,
      mesaId: mesaId,
      assentos: [
        Participante.individual(jogadorA),
        Participante.individual(jogadorB),
      ],
      modalidade: modalidade,
      metaPontos: metaPontos,
      solicitadaEm: t0,
    );

SolicitacaoPartida solicitacaoDupla({
  String matchId = 'match-e1-fase-1-mesa-2',
  int metaPontos = 100,
}) =>
    SolicitacaoPartida(
      matchId: matchId,
      tournamentId: 'quarta-master',
      editionId: 'e1',
      faseId: 'e1-fase-1',
      mesaId: 'e1-fase-1-mesa-2',
      assentos: [
        // membros ficam ordenados alfabeticamente pelo próprio Participante:
        // ana+carla e bruno+diego.
        Participante.dupla('carla', 'ana'),
        Participante.dupla('diego', 'bruno'),
      ],
      modalidade: 'ABERTO',
      metaPontos: metaPontos,
      solicitadaEm: t0,
    );

/// Joga a partida com robôs até a mesa encerrar sozinha.
///
/// Não force nada aqui: o encerramento tem que vir de `Jogo.encerrada`, senão o
/// teste passaria a provar o atalho em vez do fluxo.
void jogarAteEncerrar(MotorPartida m, {int limite = 4000}) {
  for (var t = 0; t < limite; t++) {
    if (m.jogo.encerrada) return;
    if (m.jogo.rodadaEncerrada) {
      m.apurarRodada();
      if (m.jogo.encerrada) return;
      m.iniciarNovaRodada();
      continue;
    }
    m.conduzirRobo(m.jogo.vez, eventoId: 'robo-$t');
  }
  fail('a partida não encerrou em $limite turnos');
}

/// Joga alguns turnos sem deixar a partida acabar.
void jogarUmPouco(MotorPartida m, {int turnos = 10}) {
  for (var t = 0; t < turnos; t++) {
    if (m.jogo.encerrada || m.jogo.rodadaEncerrada) return;
    m.conduzirRobo(m.jogo.vez, eventoId: 'meio-$t');
  }
}

/// Monta um estado exato preservando as 108 cartas reais do baralho.
///
/// Versão enxuta do utilitário da suíte de resiliência — só o que estes testes
/// precisam: uma canastra limpa na mesa de uma dupla e uma carta na mão para
/// descartar.
Jogo comCanastraLimpa(String dupla) {
  final j = Jogo(const ['A', 'B', 'C', 'D'], const ['a', 'b', 'c', 'd'],
      const ['🐶', '🐰', '🦊', '🐱']);
  j.metaPontos = 100;
  final pool = <Carta>[
    ...j.monte,
    ...j.lixo,
    for (final m in j.mortos) ...m,
    for (final m in j.maos) ...m,
  ];
  Carta pega(String valor, String naipe) {
    final i = pool.indexWhere((c) => c.valor == valor && c.naipe == naipe);
    if (i < 0) throw StateError('carta $valor/$naipe esgotada');
    return pool.removeAt(i);
  }

  // 4..10 de copas: sete cartas naturais, sem curinga — canastra LIMPA.
  final canastra = [
    for (final v in ['4', '5', '6', '7', '8', '9', '10']) pega(v, 'copas')
  ];
  final descarte = pega('K', 'paus');

  final assentoQueBate = dupla == 'nos' ? 0 : 1;
  j.maos = [[], [], [], []];
  j.maos[assentoQueBate] = [descarte];
  j.jogosDupla = {
    'nos': dupla == 'nos' ? [canastra] : [],
    'eles': dupla == 'eles' ? [canastra] : [],
  };
  j.lixo = [];
  j.mortos = [pool.sublist(0, 11), pool.sublist(11, 22)];
  j.monte = pool.sublist(22);
  j.vez = assentoQueBate;
  j.jaComprou = true;
  j.mortoPego = {'nos': dupla == 'nos', 'eles': dupla == 'eles'};
  return j;
}

/// Adaptador + registro + histórico, prontos.
class Bancada {
  final RegistroDePartidasEmMemoria registro;
  final AdaptadorMotorDePartidas adaptador;
  final HistoricoEmMemoria historico;

  factory Bancada.nova() {
    final r = RegistroDePartidasEmMemoria();
    return Bancada._(r, AdaptadorMotorDePartidas(registro: r), HistoricoEmMemoria());
  }

  Bancada._(this.registro, this.adaptador, this.historico);
}

void main() {
  // ======================================================================
  // 1. PARTIDA NORMAL INDIVIDUAL
  // ======================================================================

  group('INT-01 — partida normal individual', () {
    test('o fluxo inteiro vai da solicitação à aceitação na classificação',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();

      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      expect(motor.jogo.modalidade, 'ABERTO');
      expect(motor.jogo.metaPontos, 100);

      jogarAteEncerrar(motor);

      final resultado = await b.adaptador.encerrarEProduzirResultado(
        matchId: sol.matchId,
        encerradaEm: tFim,
      );
      expect(resultado, isNotNull);
      expect(resultado!.desfecho, DesfechoPartida.normal);
      expect(resultado.matchId, sol.matchId);
      expect(resultado.tournamentId, sol.tournamentId);
      expect(resultado.editionId, sol.editionId);
      expect(resultado.faseId, sol.faseId);
      expect(resultado.mesaId, sol.mesaId);
      expect(resultado.encerradaEm, tFim);
      expect(resultado.lados.map((l) => l.participanteId).toSet(),
          {'ana', 'bruno'});
      expect(resultado.vencedorId, isNotNull);

      final veredito = await entregarResultado(
        resultado: resultado,
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(veredito.processado, isTrue);
      expect(veredito.aceito!.chaveIdempotencia,
          'quarta-master|e1|match-e1-fase-1-mesa-1');
    });

    test('o vencedor é o lado que o Motor de Partidas apontou, não o que o '
        'adaptador acharia', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarAteEncerrar(motor);

      final ladoVencedorNoMotor =
          motor.jogo.placar['nos']! > motor.jogo.placar['eles']! ? 'nos' : 'eles';
      final vinculo = b.registro.vinculoDe(sol.matchId)!;
      final esperado = vinculo.porLado(ladoVencedorNoMotor)!.participanteId;

      final resultado = await b.adaptador
          .encerrarEProduzirResultado(matchId: sol.matchId, encerradaEm: tFim);
      expect(resultado!.vencedorId, esperado);
    });
  });

  // ======================================================================
  // 2. PARTIDA DE DUPLA — ASSOCIAÇÃO EXPLÍCITA
  // ======================================================================

  group('INT-02 — dupla: cada membro no assento certo', () {
    test('os dois membros do participante ficam no mesmo lado, em assentos '
        'próprios', () async {
      final b = Bancada.nova();
      final sol = solicitacaoDupla();
      await b.adaptador.solicitarPartida(sol);

      final v = b.registro.vinculoDe(sol.matchId)!;
      final ladoA = v.porParticipante('ana+carla')!;
      final ladoB = v.porParticipante('bruno+diego')!;

      expect(ladoA.membros, ['ana', 'carla']);
      expect(ladoB.membros, ['bruno', 'diego']);
      expect(ladoA.lado, 'nos');
      expect(ladoB.lado, 'eles');
      expect(ladoA.assentos, [0, 2]);
      expect(ladoB.assentos, [1, 3]);

      // A pergunta que importa: dado um jogador, qual assento? E dado um
      // assento, qual participante? As duas direções, sem índice de lista.
      expect(assentoDoJogador(v, 'ana'), 0);
      expect(assentoDoJogador(v, 'carla'), 2);
      expect(assentoDoJogador(v, 'bruno'), 1);
      expect(assentoDoJogador(v, 'diego'), 3);
      expect(v.participanteNoAssento(0), 'ana+carla');
      expect(v.participanteNoAssento(2), 'ana+carla');
      expect(v.participanteNoAssento(1), 'bruno+diego');
      expect(v.participanteNoAssento(3), 'bruno+diego');
    });

    test('individual deixa o assento parceiro sem dono no torneio', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final v = b.registro.vinculoDe(sol.matchId)!;

      expect(v.assentosAtribuidos, [0, 1]);
      expect(v.participanteNoAssento(0), 'ana');
      expect(v.participanteNoAssento(1), 'bruno');
      // 2 e 3 existem na mesa, mas o torneio não inscreveu ninguém para eles.
      expect(v.participanteNoAssento(2), isNull);
      expect(v.participanteNoAssento(3), isNull);
    });

    test('o vínculo sobrevive à persistência sem perder a associação', () {
      final sol = solicitacaoDupla();
      final original = montarVinculoPadrao(sol);
      final volta = VinculoDeMesa.fromMap(
          Map<String, dynamic>.from(original.toJson()));

      expect(volta.toJson(), original.toJson());
      expect(assentoDoJogador(volta, 'carla'), 2);
      expect(volta.porParticipante('bruno+diego')!.lado, 'eles');
    });

    test('dupla com membros em lados opostos é recusada na montagem', () {
      final sol = solicitacaoDupla();
      expect(
        () => VinculoDeMesa.declarar(
          solicitacao: sol,
          assentosPorParticipante: {
            // ana no lado "nos", carla no lado "eles": a dupla pontuaria contra
            // si mesma.
            'ana+carla': {'ana': 0, 'carla': 1},
            'bruno+diego': {'bruno': 2, 'diego': 3},
          },
        ),
        throwsA(isA<VinculoInvalido>()),
      );
    });

    test('assento declarado para quem não é membro é recusado', () {
      final sol = solicitacaoDupla();
      expect(
        () => VinculoDeMesa.declarar(
          solicitacao: sol,
          assentosPorParticipante: {
            'ana+carla': {'ana': 0, 'diego': 2},
            'bruno+diego': {'bruno': 1, 'carla': 3},
          },
        ),
        throwsA(isA<VinculoInvalido>()),
      );
    });

    test('o mesmo assento para dois jogadores é recusado', () {
      final sol = solicitacaoDupla();
      expect(
        () => VinculoDeMesa.declarar(
          solicitacao: sol,
          assentosPorParticipante: {
            'ana+carla': {'ana': 0, 'carla': 2},
            'bruno+diego': {'bruno': 0, 'diego': 3},
          },
        ),
        throwsA(isA<VinculoInvalido>()),
      );
    });
  });

  // ======================================================================
  // 3. REENVIO IDÊNTICO
  // ======================================================================

  group('INT-03 — reenvio idêntico não produz efeito novo', () {
    test('solicitar duas vezes não abre uma segunda mesa nem redistribui',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();

      await b.adaptador.solicitarPartida(sol);
      final primeira = b.registro.buscar(sol.matchId)!;
      jogarUmPouco(primeira);
      final impressaoAntes = primeira.impressao;
      final versaoAntes = primeira.versaoEstado;

      await b.adaptador.solicitarPartida(sol);

      expect(b.registro.abertas, 1);
      expect(identical(b.registro.buscar(sol.matchId), primeira), isTrue);
      expect(primeira.impressao, impressaoAntes,
          reason: 'reenvio não pode redistribuir cartas de uma mesa em curso');
      expect(primeira.versaoEstado, versaoAntes);
    });

    test('o mesmo resultado entregue duas vezes é recusado como jaProcessado',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);

      final resultado = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;

      final primeira = await entregarResultado(
        resultado: resultado,
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      final segunda = await entregarResultado(
        resultado: resultado,
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );

      expect(primeira.processado, isTrue);
      expect(segunda.processado, isFalse);
      expect(segunda.recusa, RecusaResultado.jaProcessado);
      expect(segunda.idempotente, isTrue,
          reason: 'reenvio é recusa benigna, não erro de transporte');
      expect(b.historico.processados().length, 1,
          reason: 'um resultado, um registro — nunca dois históricos');
    });

    test('reproduzir o desfecho duas vezes dá o mesmo resultado, byte a byte',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);

      final a = await b.adaptador
          .encerrarEProduzirResultado(matchId: sol.matchId, encerradaEm: tFim);
      final c = await b.adaptador
          .encerrarEProduzirResultado(matchId: sol.matchId, encerradaEm: tFim);
      expect(c!.toJson(), a!.toJson());
    });
  });

  // ======================================================================
  // 4, 5, 6. RESULTADO QUE NÃO BATE COM A SOLICITAÇÃO
  // ======================================================================

  group('INT-04/05/06 — coerência com a solicitação', () {
    late Bancada b;
    late SolicitacaoPartida sol;
    late ResultadoPartida bom;

    setUp(() async {
      b = Bancada.nova();
      sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);
      bom = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;
    });

    ResultadoPartida variar({
      String? matchId,
      String? tournamentId,
      String? editionId,
      String? faseId,
      String? mesaId,
      List<LadoResultado>? lados,
      String? vencedorId,
    }) =>
        ResultadoPartida(
          matchId: matchId ?? bom.matchId,
          tournamentId: tournamentId ?? bom.tournamentId,
          editionId: editionId ?? bom.editionId,
          faseId: faseId ?? bom.faseId,
          mesaId: mesaId ?? bom.mesaId,
          lados: lados ?? bom.lados,
          vencedorId: vencedorId ?? bom.vencedorId,
          desfecho: bom.desfecho,
          encerradaEm: bom.encerradaEm,
        );

    test('INT-04 matchId errado é recusado', () async {
      final r = await entregarResultado(
        resultado: variar(matchId: 'match-de-outra-mesa'),
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(r.recusa, RecusaResultado.partidaDesconhecida);
      expect(b.historico.processados(), isEmpty);
    });

    test('INT-04 matchId que a edição não conhece é recusado', () async {
      final r = await entregarResultado(
        resultado: bom,
        solicitacao: null, // o torneio não achou solicitação para este matchId
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(r.recusa, RecusaResultado.partidaDesconhecida);
    });

    test('INT-05 tournamentId errado é recusado', () async {
      final r = await entregarResultado(
        resultado: variar(tournamentId: 'sexta-master'),
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(r.recusa, RecusaResultado.partidaDesconhecida);
    });

    test('INT-05 editionId errado é recusado', () async {
      final r = await entregarResultado(
        resultado: variar(editionId: 'e2'),
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(r.recusa, RecusaResultado.partidaDesconhecida);
    });

    test('INT-05 a chave de idempotência isola as edições', () async {
      // O mesmo matchId em outra edição tem outra chave: processar um não pode
      // marcar o outro como processado.
      await entregarResultado(
        resultado: bom,
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(b.historico.processados(),
          {'quarta-master|e1|match-e1-fase-1-mesa-1'});
      expect(
        b.historico.processados().contains('quarta-master|e2|match-e1-fase-1-mesa-1'),
        isFalse,
      );
    });

    test('INT-05 fase e mesa erradas são recusadas com o motivo próprio',
        () async {
      final porFase = await entregarResultado(
        resultado: variar(faseId: 'e1-fase-9'),
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(porFase.recusa, RecusaResultado.faseIncorreta);

      final porMesa = await entregarResultado(
        resultado: variar(mesaId: 'e1-fase-1-mesa-77'),
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(porMesa.recusa, RecusaResultado.mesaIncorreta);
    });

    test('INT-06 participantes divergentes são recusados', () async {
      final r = await entregarResultado(
        resultado: variar(
          lados: [
            LadoResultado(
                participanteId: 'ana',
                pontos: bom.lados.first.pontos,
                canastrasLimpas: bom.lados.first.canastrasLimpas),
            const LadoResultado(
                participanteId: 'intruso', pontos: 0, canastrasLimpas: 0),
          ],
          vencedorId: 'ana',
        ),
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(r.recusa, RecusaResultado.participantesDivergentes);
      expect(b.historico.processados(), isEmpty);
    });

    test('INT-06 edição fora de disputa é recusada', () async {
      final r = await entregarResultado(
        resultado: bom,
        solicitacao: sol,
        edicaoEmDisputa: false,
        historico: b.historico,
      );
      expect(r.recusa, RecusaResultado.edicaoForaDeDisputa);
    });

    test('vínculo de outra partida não traduz desfecho', () async {
      final outroSol = solicitacaoDupla();
      final outroVinculo = montarVinculoPadrao(outroSol);
      final motor = b.registro.buscar(sol.matchId)!;
      final desfecho = capturarDesfecho(motor, encerradaEm: tFim);

      expect(
        () => traduzirDesfecho(desfecho: desfecho, vinculo: outroVinculo),
        throwsA(isA<DesfechoNaoTraduzivel>()),
      );
    });
  });

  // ======================================================================
  // 7. PARTIDA ANULADA
  // ======================================================================

  group('INT-07 — partida anulada', () {
    test('anulação não tem vencedor e não pontua', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarUmPouco(b.registro.buscar(sol.matchId)!);

      final resultado = await b.adaptador.encerrarEProduzirResultado(
        matchId: sol.matchId,
        encerradaEm: tFim,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.anulada,
          autoridade: 'admin-sonia',
          declaradaEm: tFim,
          observacao: 'mesa reaberta por falha de infraestrutura',
        ),
      );

      expect(resultado!.desfecho, DesfechoPartida.anulada);
      expect(resultado.vencedorId, isNull);
      expect(resultado.desfecho.pontua, isFalse);
    });

    test('anular declarando vencedor é recusado na origem', () {
      expect(
        () => OrdemDeEncerramento(
          motivo: MotivoEncerramento.anulada,
          autoridade: 'admin-sonia',
          declaradaEm: tFim,
          ladoVencedor: 'nos',
        ),
        throwsArgumentError,
      );
    });

    test('a anulação vale mesmo com a mesa ainda viva', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarUmPouco(motor);
      expect(motor.jogo.encerrada, isFalse);

      final r = await b.adaptador.encerrarEProduzirResultado(
        matchId: sol.matchId,
        encerradaEm: tFim,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.anulada,
          autoridade: 'srv-01',
          declaradaEm: tFim,
        ),
      );
      expect(r, isNotNull);
      expect(r!.desfecho, DesfechoPartida.anulada);
    });
  });

  // ======================================================================
  // 8. ENCERRAMENTO ADMINISTRATIVO E ABANDONO DECLARADO
  // ======================================================================

  group('INT-08 — encerramento por autoridade', () {
    test('encerramento administrativo vira encerradaPorAdmin com o vencedor '
        'que a autoridade declarou', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarUmPouco(b.registro.buscar(sol.matchId)!);

      final r = await b.adaptador.encerrarEProduzirResultado(
        matchId: sol.matchId,
        encerradaEm: tFim,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.encerradaPorAdmin,
          ladoVencedor: 'eles',
          autoridade: 'admin-sonia',
          declaradaEm: tFim,
        ),
      );

      expect(r!.desfecho, DesfechoPartida.encerradaPorAdmin);
      // "eles" é o lado do segundo participante da mesa — e quem diz isso é o
      // vínculo, não a posição na lista de lados do resultado.
      final vinculo = b.registro.vinculoDe(sol.matchId)!;
      expect(r.vencedorId, vinculo.porLado('eles')!.participanteId);
      expect(r.vencedorId, 'bruno');
    });

    test('abandono declarado pela autoridade vira DesfechoPartida.abandono',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarUmPouco(b.registro.buscar(sol.matchId)!);

      // O registro que a autoridade produz (presenca.dart) é o que justifica a
      // ordem; a ordem é o que o adaptador aceita.
      const saida = RegistroAbandono(
        partidaId: 'match-e1-fase-1-mesa-1',
        assento: 1,
        motivo: MotivoSaida.ausenciaProlongada,
        emMs: 1770000000000,
        rodada: 1,
      );
      expect(saida.motivo, MotivoSaida.ausenciaProlongada);

      final r = await b.adaptador.encerrarEProduzirResultado(
        matchId: sol.matchId,
        encerradaEm: tFim,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.abandono,
          ladoVencedor: 'nos', // o lado que ficou
          autoridade: 'srv-railway-01',
          declaradaEm: tFim,
        ),
      );

      expect(r!.desfecho, DesfechoPartida.abandono);
      expect(r.vencedorId, 'ana');
    });

    test('autoridade que encerra sem dizer o vencedor falha alto', () {
      for (final motivo in [
        MotivoEncerramento.abandono,
        MotivoEncerramento.encerradaPorAdmin,
      ]) {
        expect(
          () => OrdemDeEncerramento(
            motivo: motivo,
            autoridade: 'srv-01',
            declaradaEm: tFim,
          ),
          throwsArgumentError,
          reason: '$motivo sem lado vencedor não pode ser adivinhado pelo placar',
        );
      }
    });

    test('ordem sem autoridade identificada é recusada', () {
      expect(
        () => OrdemDeEncerramento(
          motivo: MotivoEncerramento.encerradaPorAdmin,
          ladoVencedor: 'nos',
          autoridade: '',
          declaradaEm: tFim,
        ),
        throwsArgumentError,
      );
    });

    test('meta atingida não se declara por ordem', () {
      expect(
        () => OrdemDeEncerramento(
          motivo: MotivoEncerramento.metaAtingida,
          ladoVencedor: 'nos',
          autoridade: 'admin',
          declaradaEm: tFim,
        ),
        throwsArgumentError,
      );
    });

    test('a ordem viaja no desfecho para a auditoria', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      final ordem = OrdemDeEncerramento(
        motivo: MotivoEncerramento.encerradaPorAdmin,
        ladoVencedor: 'nos',
        autoridade: 'admin-sonia',
        declaradaEm: tFim,
      );
      final d = capturarDesfecho(motor, encerradaEm: tFim, ordem: ordem);
      expect(d.ordem!.autoridade, 'admin-sonia');
      expect(d.toJson()['ordem'], ordem.toJson());
      expect(d.versaoEstado, motor.versaoEstado);
      expect(d.impressaoEstado, motor.impressao);
    });
  });

  // ======================================================================
  // 9. QUEDA E RECONEXÃO NÃO VIRAM ABANDONO
  // ======================================================================

  group('INT-09 — desconexão não é abandono', () {
    test('assento ausente há muito tempo não produz abandono', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarUmPouco(motor);

      // Silêncio de meia hora no assento 1 — muito além do prazo de abandono.
      motor.presenca.registrarHeartbeat(1, 0);
      motor.presenca.reavaliarLocalmente(1800000);
      expect(motor.presenca.estadoDe(1), EstadoPresenca.ausente);
      expect(motor.presenca.msAteAbandonoPossivel(1, 1800000), 0);

      final d = capturarDesfecho(motor, encerradaEm: tFim);
      expect(d.motivo, isNot(MotivoEncerramento.abandono));
      expect(d.estado, EstadoEncerramento.emAndamento);
      expect(d.conclusivo, isFalse);

      final r = await b.adaptador
          .encerrarEProduzirResultado(matchId: sol.matchId, encerradaEm: tFim);
      expect(r, isNull, reason: 'ausência não encerra partida');
    });

    test('a presença não muda o desfecho: duas mesas idênticas, uma com '
        'jogador sumido, produzem o mesmo motivo', () async {
      Future<MotivoEncerramento?> motivoCom({required bool comQueda}) async {
        final b = Bancada.nova();
        final sol = solicitacaoIndividual();
        await b.adaptador.solicitarPartida(sol);
        final motor = b.registro.buscar(sol.matchId)!;
        if (comQueda) {
          motor.presenca.registrarHeartbeat(0, 0);
          motor.presenca.registrarHeartbeat(1, 0);
          motor.presenca.reavaliarLocalmente(3600000);
        }
        jogarAteEncerrar(motor);
        return capturarDesfecho(motor, encerradaEm: tFim).motivo;
      }

      expect(await motivoCom(comQueda: true), MotivoEncerramento.metaAtingida);
      expect(await motivoCom(comQueda: false), MotivoEncerramento.metaAtingida);
    });

    test('reconexão com reenvio do mesmo eventoId não muda o desfecho',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;

      // Uma jogada real, "perdida" na queda e reenviada com o MESMO eventoId.
      final assento = motor.jogo.vez;
      final primeira = motor.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'queda-1', assento: assento));
      expect(primeira.status, StatusComando.aplicado);
      final impressao = motor.impressao;
      final reenvio = motor.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'queda-1', assento: assento));
      expect(reenvio.status, StatusComando.duplicado);
      expect(motor.impressao, impressao);

      final d = capturarDesfecho(motor, encerradaEm: tFim);
      expect(d.estado, EstadoEncerramento.emAndamento);
      expect(d.motivo, isNull);
    });

    test('a partida retomada de snapshot continua sem motivo de abandono', () {
      final motor = MotorPartida(
        partidaId: 'match-e1-fase-1-mesa-1',
        jogo: Jogo(const ['A', 'B', 'C', 'D'], const ['a', 'b', 'c', 'd'],
            const ['🐶', '🐰', '🦊', '🐱'])
          ..metaPontos = 100,
      );
      jogarUmPouco(motor);
      final volta = MotorPartida.restaurar(motor.snapshot());

      final d = capturarDesfecho(volta, encerradaEm: tFim);
      expect(d.estado, EstadoEncerramento.emAndamento);
      expect(d.motivo, isNull);
    });

    test('MotivoEncerramento.abandono só existe via OrdemDeEncerramento', () {
      // Prova estrutural: os motivos que não são "meta atingida" exigem
      // autoridade, e OrdemDeEncerramento é o único tipo que os carrega.
      expect(MotivoEncerramento.abandono.exigeAutoridade, isTrue);
      expect(MotivoEncerramento.encerradaPorAdmin.exigeAutoridade, isTrue);
      expect(MotivoEncerramento.anulada.exigeAutoridade, isTrue);
      expect(MotivoEncerramento.metaAtingida.exigeAutoridade, isFalse);

      // E os estados que o app consegue calcular sozinho não incluem nenhum
      // terminal — a trava vive em presenca.dart e continua de pé.
      const politica = PoliticaPresenca();
      for (final silencio in [0, 13000, 50000, 3600000]) {
        final e = politica.classificar(
            ultimoHeartbeatMs: 0, agoraMs: silencio);
        expect(e.ehTerminal, isFalse, reason: 'silêncio de $silencio ms');
      }
    });
  });

  // ======================================================================
  // 10. SNAPSHOT ANTES DO ENCERRAMENTO
  // ======================================================================

  group('INT-10 — estado intermediário não vira resultado', () {
    test('desfecho de partida em andamento não é conclusivo', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarUmPouco(motor);

      final d = capturarDesfecho(motor, encerradaEm: tFim);
      expect(d.conclusivo, isFalse);
      expect(d.motivo, isNull);
      expect(d.ladoVencedor, isNull);
      // Mas os números do estado corrente estão lá, para a UI acompanhar.
      expect(d.porLado('nos')!.pontos, motor.jogo.placar['nos']);
    });

    test('traduzir um desfecho em andamento falha alto', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarUmPouco(motor);

      final d = capturarDesfecho(motor, encerradaEm: tFim);
      expect(
        () => traduzirDesfecho(
            desfecho: d, vinculo: b.registro.vinculoDe(sol.matchId)!),
        throwsA(isA<DesfechoNaoTraduzivel>()),
      );
    });

    test('o adaptador devolve null em vez de inventar resultado', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarUmPouco(b.registro.buscar(sol.matchId)!);

      expect(
        await b.adaptador
            .encerrarEProduzirResultado(matchId: sol.matchId, encerradaEm: tFim),
        isNull,
      );
      expect(b.historico.processados(), isEmpty);
    });

    test('rodada apurada no meio da partida ainda não encerra nada', () async {
      final b = Bancada.nova();
      // Meta alta: a primeira rodada apurada não chega perto.
      final sol = solicitacaoIndividual(metaPontos: 5000);
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;

      for (var t = 0; t < 500 && !motor.jogo.rodadaEncerrada; t++) {
        motor.conduzirRobo(motor.jogo.vez, eventoId: 'r$t');
      }
      expect(motor.jogo.rodadaEncerrada, isTrue,
          reason: 'a rodada precisa fechar para o teste fazer sentido');
      expect(motor.apurarRodada(), isTrue);
      expect(motor.jogo.encerrada, isFalse);

      expect(
        await b.adaptador
            .encerrarEProduzirResultado(matchId: sol.matchId, encerradaEm: tFim),
        isNull,
      );
    });

    test('partida que nunca foi aberta falha alto em vez de devolver null',
        () async {
      final b = Bancada.nova();
      expect(
        () => b.adaptador.encerrarEProduzirResultado(
            matchId: 'match-inexistente', encerradaEm: tFim),
        throwsA(isA<DesfechoNaoTraduzivel>()),
      );
    });
  });

  // ======================================================================
  // 11 e 12. OS NÚMEROS SÃO COPIADOS, NUNCA RECALCULADOS
  // ======================================================================

  group('INT-11/12 — pontuação e canastras vêm prontas do Motor de Partidas',
      () {
    test('INT-11 a pontuação do torneio é exatamente Jogo.placar', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarAteEncerrar(motor);

      final r = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;
      final vinculo = b.registro.vinculoDe(sol.matchId)!;

      for (final lado in ['nos', 'eles']) {
        final participante = vinculo.porLado(lado)!.participanteId;
        expect(r.ladoDe(participante)!.pontos, motor.jogo.placar[lado],
            reason: 'lado $lado');
      }
    });

    test('INT-12 as canastras limpas do torneio são exatamente as do motor',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;
      jogarAteEncerrar(motor);

      final r = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;
      final vinculo = b.registro.vinculoDe(sol.matchId)!;

      for (final lado in ['nos', 'eles']) {
        final participante = vinculo.porLado(lado)!.participanteId;
        expect(r.ladoDe(participante)!.canastrasLimpas,
            motor.canastrasLimpas[lado],
            reason: 'lado $lado');
      }
    });

    test('INT-12 uma canastra limpa real atravessa a fronteira com o valor 1',
        () {
      final sol = solicitacaoIndividual();
      final vinculo = montarVinculoPadrao(sol);

      final jogo = comCanastraLimpa('nos');
      final motor = MotorPartida(partidaId: sol.matchId, jogo: jogo);

      // Bate: descarta a última carta com canastra limpa e morto já pego.
      final erro = jogo.descartar(0, jogo.maos[0].first.id);
      expect(erro, isNull, reason: 'a batida precisa acontecer de verdade');
      expect(jogo.rodadaEncerrada, isTrue);
      expect(motor.apurarRodada(), isTrue);

      // O número vem do domínio da partida, não deste teste.
      expect(jogo.canastrasLimpasNaRodada('nos'), 1);
      expect(jogo.canastrasLimpasNaRodada('eles'), 0);
      expect(motor.canastrasLimpas['nos'], 1);
      expect(jogo.encerrada, isTrue,
          reason: 'a canastra limpa passa da meta de 100 pontos');

      final r = traduzirDesfecho(
        desfecho: capturarDesfecho(motor, encerradaEm: tFim),
        vinculo: vinculo,
      );
      expect(r.ladoDe('ana')!.canastrasLimpas, 1);
      expect(r.ladoDe('bruno')!.canastrasLimpas, 0);
      expect(r.ladoDe('ana')!.pontos, jogo.placar['nos']);
      expect(r.vencedorId, 'ana');
    });

    test('o acumulado de canastras atravessa o snapshot', () {
      final jogo = comCanastraLimpa('eles');
      final motor = MotorPartida(partidaId: 'p1', jogo: jogo);
      jogo.descartar(1, jogo.maos[1].first.id);
      motor.apurarRodada();
      expect(motor.canastrasLimpas['eles'], 1);

      final volta = MotorPartida.restaurar(motor.snapshot());
      expect(volta.canastrasLimpas, motor.canastrasLimpas,
          reason: 'servidor reiniciado não pode zerar o desempate');
    });

    test('reapurar a mesma rodada não soma canastra duas vezes', () {
      final jogo = comCanastraLimpa('nos');
      final motor = MotorPartida(partidaId: 'p1', jogo: jogo);
      jogo.descartar(0, jogo.maos[0].first.id);

      expect(motor.apurarRodada(), isTrue);
      final depoisDaPrimeira = motor.canastrasLimpas['nos'];
      expect(motor.apurarRodada(), isFalse);
      expect(motor.canastrasLimpas['nos'], depoisDaPrimeira);
    });

    test('canastra suja não entra na conta', () {
      final jogo = comCanastraLimpa('nos');
      // Troca uma carta natural da canastra por um curinga: vira suja.
      final canastra = jogo.jogosDupla['nos']!.first;
      final natural = canastra.removeLast();
      final joker = jogo.monte.firstWhere((c) => c.ehCoringa);
      jogo.monte.remove(joker);
      canastra.add(joker);
      jogo.monte.add(natural);

      final motor = MotorPartida(partidaId: 'p1', jogo: jogo);
      jogo.rodadaEncerrada = true;
      jogo.duplaQueBateu = 'nos';
      motor.apurarRodada();
      expect(motor.canastrasLimpas['nos'], 0);
    });

    test('sem rodada apurada o acumulado é zero, não um palpite', () {
      final motor = MotorPartida(
        partidaId: 'p1',
        jogo: Jogo(const ['A', 'B', 'C', 'D'], const ['a', 'b', 'c', 'd'],
            const ['🐶', '🐰', '🦊', '🐱']),
      );
      expect(motor.canastrasLimpas, {'nos': 0, 'eles': 0});
      expect(motor.jogo.canastrasLimpasNaRodada('nos'), 0);
    });
  });

  // ======================================================================
  // 13. CONCORRÊNCIA NA FRONTEIRA
  // ======================================================================

  group('INT-13 — dois processamentos simultâneos', () {
    test('só um dos dois produz efeito; o outro é jaProcessado', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);
      final resultado = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;

      // Disparados juntos, sem await entre eles: os dois leem o histórico VAZIO
      // antes de qualquer gravação. É exatamente a corrida que a fronteira
      // precisa aguentar — quem decide é a gravação atômica, não a leitura.
      final vereditos = await Future.wait([
        entregarResultado(
          resultado: resultado,
          solicitacao: sol,
          edicaoEmDisputa: true,
          historico: b.historico,
        ),
        entregarResultado(
          resultado: resultado,
          solicitacao: sol,
          edicaoEmDisputa: true,
          historico: b.historico,
        ),
      ]);

      final aceitos = vereditos.where((v) => v.processado).length;
      final recusados =
          vereditos.where((v) => v.recusa == RecusaResultado.jaProcessado).length;

      expect(aceitos, 1, reason: 'dois efeitos seria ponto somado duas vezes');
      expect(recusados, 1);
      expect(b.historico.processados().length, 1);
    });

    test('cinco chegadas simultâneas continuam produzindo um efeito só',
        () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);
      final resultado = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;

      final vereditos = await Future.wait([
        for (var i = 0; i < 5; i++)
          entregarResultado(
            resultado: resultado,
            solicitacao: sol,
            edicaoEmDisputa: true,
            historico: b.historico,
          )
      ]);

      expect(vereditos.where((v) => v.processado).length, 1);
      expect(b.historico.processados().length, 1);
    });

    test('resultado recusado não ocupa a chave de idempotência', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);
      final resultado = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;

      // Chega antes da hora: a edição ainda não estava em disputa.
      final recusado = await entregarResultado(
        resultado: resultado,
        solicitacao: sol,
        edicaoEmDisputa: false,
        historico: b.historico,
      );
      expect(recusado.processado, isFalse);
      expect(b.historico.processados(), isEmpty,
          reason: 'gravar aqui impediria a mesa de reenviar o resultado certo');

      // E depois entra normalmente.
      final aceito = await entregarResultado(
        resultado: resultado,
        solicitacao: sol,
        edicaoEmDisputa: true,
        historico: b.historico,
      );
      expect(aceito.processado, isTrue);
    });

    test('as duas camadas de idempotência são independentes', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      final motor = b.registro.buscar(sol.matchId)!;

      // Camada do Motor de Partidas: eventoId.
      final assento = motor.jogo.vez;
      motor.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'e1', assento: assento));
      expect(motor.eventosAplicados, contains('e1'));
      final r = motor.aplicar(
          ComandoPartida.comprarMonte(eventoId: 'e1', assento: assento));
      expect(r.status, StatusComando.duplicado);

      // Camada do torneio: tournamentId|editionId|matchId. Nenhuma sabe da
      // outra, e nenhuma cobre o buraco da outra.
      jogarAteEncerrar(motor);
      final resultado = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;
      expect(resultado.chaveIdempotencia,
          '${sol.tournamentId}|${sol.editionId}|${sol.matchId}');
      expect(b.historico.processados(), isEmpty,
          reason: 'a camada do motor não grava nada na camada do torneio');
    });
  });

  // ======================================================================
  // FRONTEIRA — o que cada motor NÃO pode ter aprendido
  // ======================================================================

  group('FRONTEIRA — os domínios continuam separados', () {
    test('o desfecho canônico não fala de torneio', () {
      final motor = MotorPartida(
        partidaId: 'p1',
        jogo: Jogo(const ['A', 'B', 'C', 'D'], const ['a', 'b', 'c', 'd'],
            const ['🐶', '🐰', '🦊', '🐱']),
      );
      final json = capturarDesfecho(motor, encerradaEm: tFim).toJson();
      final texto = json.toString();
      for (final palavra in [
        'participante',
        'tournament',
        'edition',
        'fase',
        'classificacao',
        'premiacao',
      ]) {
        expect(texto.toLowerCase(), isNot(contains(palavra)),
            reason: 'o Motor de Partidas não pode ter aprendido "$palavra"');
      }
      // Os lados são "nos"/"eles" — vocabulário da mesa, não do torneio.
      expect(json['lados'], isA<List>());
      expect((json['lados'] as List).map((l) => (l as Map)['lado']).toList(),
          ['nos', 'eles']);
    });

    test('o resultado do torneio não fala de baralho', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      jogarAteEncerrar(b.registro.buscar(sol.matchId)!);
      final r = (await b.adaptador.encerrarEProduzirResultado(
          matchId: sol.matchId, encerradaEm: tFim))!;

      final texto = r.toJson().toString().toLowerCase();
      for (final palavra in [
        'carta',
        'monte',
        'lixo',
        'morto',
        'curinga',
        'assento',
        'baixar',
        'descart',
      ]) {
        expect(texto, isNot(contains(palavra)),
            reason: 'o Motor de Torneios não pode ter aprendido "$palavra"');
      }
    });

    test('o adaptador implementa o contrato declarado em torneios', () {
      final adaptador =
          AdaptadorMotorDePartidas(registro: RegistroDePartidasEmMemoria());
      expect(adaptador, isA<MotorDePartidas>());
    });

    test('cancelar uma partida inexistente é silencioso', () async {
      final b = Bancada.nova();
      await b.adaptador.cancelarPartida('match-que-nunca-existiu');
      expect(b.registro.abertas, 0);
    });

    test('cancelar desfaz a mesa e o vínculo juntos', () async {
      final b = Bancada.nova();
      final sol = solicitacaoIndividual();
      await b.adaptador.solicitarPartida(sol);
      expect(b.registro.abertas, 1);

      await b.adaptador.cancelarPartida(sol.matchId);
      expect(b.registro.abertas, 0);
      expect(b.registro.vinculoDe(sol.matchId), isNull,
          reason: 'vínculo órfão apontaria para uma partida que não existe');
    });
  });
}
