// reconexao_e_abandono_test.dart — §32 e §33 da OS.
//
// §32 RECONEXÃO:
//   * queda e retorno;
//   * múltiplas reconexões;
//   * reconexão durante mudança de rodada;
//   * retry após partida terminar;
//   * fila antiga não cria segundo resultado;
//   * partida encerrada não reabre;
//   * alteração de ranking não reaplica.
//
// §33 ABANDONO:
//   * desconexão breve não vira abandono automaticamente;
//   * abandono confirmado é registrado;
//   * motivo é preservado;
//   * retry não duplica abandono;
//   * abandono e reconexão concorrentes produzem estado consistente.

import 'package:buraco_master_vip/motor/desfecho_partida.dart';
import 'package:buraco_master_vip/motor/presenca.dart';
import 'package:buraco_master_vip/rastreabilidade/eventos_auditaveis.dart';
import 'package:buraco_master_vip/rastreabilidade/ingestao.dart';
import 'package:buraco_master_vip/rastreabilidade/ledger_competitivo.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ferramentas.dart';

void main() {
  group('REC — reconexão (§19, §32)', () {
    test('REC-01 queda e retorno: dois eventos, uma identidade', () {
      final identidade = identidadeRanqueada();
      final trilha = TrilhaDeEventos(kMatchId);

      final queda = registrarSaida(
        identidade: identidade,
        assento: 1,
        classificacao: ClassificacaoDeSaida.quedaDeConexao,
        emServidor: agora,
        versaoEstado: 12,
        rodada: 1,
      );
      final volta = registrarReconexao(
        identidade: identidade,
        assento: 1,
        emServidor: depois,
        versaoEstado: 14,
        rodada: 1,
      );

      expect(trilha.registrar(queda), isTrue);
      expect(trilha.registrar(volta), isTrue);
      expect(queda.tipo, TipoEventoAuditavel.desconexao);
      expect(volta.tipo, TipoEventoAuditavel.reconexao);
      expect(queda.matchId, volta.matchId, reason: 'mesma partida');
      expect(volta.dados['criouPartida'], false);
    });

    test('REC-02 a reconexão NÃO gera segundo matchId', () {
      final identidade = identidadeRanqueada();
      final eventos = [
        for (var t = 1; t <= 5; t++)
          registrarReconexao(
              identidade: identidade,
              assento: 0,
              emServidor: depois,
              versaoEstado: 10 + t,
              tentativa: t),
      ];
      expect(eventos.map((e) => e.matchId).toSet(), {kMatchId});
    });

    test('REC-03 múltiplas reconexões do mesmo assento são eventos distintos',
        () {
      final identidade = identidadeRanqueada();
      final trilha = TrilhaDeEventos(kMatchId);
      for (var t = 1; t <= 3; t++) {
        expect(
          trilha.registrar(registrarReconexao(
              identidade: identidade,
              assento: 2,
              emServidor: depois,
              versaoEstado: 20 + t,
              tentativa: t)),
          isTrue,
          reason: 'a tentativa $t é uma reconexão diferente',
        );
      }
      expect(trilha.tamanho, 3);
    });

    test('REC-04 a MESMA reconexão reenviada é idempotente', () {
      final identidade = identidadeRanqueada();
      final trilha = TrilhaDeEventos(kMatchId);
      final evento = registrarReconexao(
          identidade: identidade,
          assento: 2,
          emServidor: depois,
          versaoEstado: 21,
          tentativa: 1);

      expect(trilha.registrar(evento), isTrue);
      expect(trilha.registrar(evento), isFalse);
      // E reconstruído do zero com os mesmos parâmetros, o eventId é o mesmo.
      expect(
        trilha.registrar(registrarReconexao(
            identidade: identidade,
            assento: 2,
            emServidor: depois,
            versaoEstado: 21,
            tentativa: 1)),
        isFalse,
      );
      expect(trilha.tamanho, 1);
    });

    test('REC-05 reconexão durante mudança de rodada mantém a identidade da '
        'partida e distingue as rodadas', () {
      final identidade = identidadeRanqueada();
      final naRodada1 = registrarReconexao(
          identidade: identidade,
          assento: 0,
          emServidor: agora,
          versaoEstado: 30,
          rodada: 1);
      final naRodada2 = registrarReconexao(
          identidade: identidade,
          assento: 0,
          emServidor: depois,
          versaoEstado: 55,
          rodada: 2);

      expect(naRodada1.matchId, naRodada2.matchId);
      expect(naRodada1.rodada, 1);
      expect(naRodada2.rodada, 2);
      expect(naRodada1.eventId, isNot(naRodada2.eventId));
      expect(identidade.rodada(1, versaoEstado: 30).matchId,
          identidade.rodada(2, versaoEstado: 55).matchId);
    });

    test('REC-06 partida encerrada NÃO reabre com reconexão', () {
      final encerrada = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());

      // Registrar a reconexão é permitido — o cliente que estava offline
      // precisa descobrir que a mesa fechou. O que ela não faz é mudar estado:
      // a função devolve um evento, e não um registro.
      final evento = registrarReconexao(
          identidade: encerrada.identidade,
          assento: 0,
          emServidor: depois,
          versaoEstado: encerrada.versaoEstadoFinal);
      expect(evento, isA<EventoAuditavel>());
      expect(encerrada.estado, EstadoDaPartida.finalizada);
      expect(() => encerrada.transicionarPara(EstadoDaPartida.ativa),
          throwsA(isA<TransicaoInvalida>()));
    });

    test('REC-07 fila antiga reenviada depois do fim não cria segundo '
        'resultado nem reaplica ranking', () {
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final desfecho = desfechoNormal();
      final ledgers = {
        for (final uid in ['uid-a', 'uid-b', 'uid-c', 'uid-d'])
          uid: LedgerCompetitivo(uid),
      };

      final primeiro = ingerirEncerramento(
        desfecho: desfecho,
        registroAtual: aberto,
        chamador: servidor,
        emServidor: depois,
        ledgers: ledgers,
        calcularDelta: deltaPorResultado(),
        politica: politicaDeTeste,
      );
      final saldoDepoisDoPrimeiro = {
        for (final e in ledgers.entries) e.key: e.value.saldo
      };

      // A fila do cliente volta depois da queda, com o MESMO desfecho.
      for (var i = 0; i < 3; i++) {
        final reenvio = ingerirEncerramento(
          desfecho: desfecho,
          registroAtual: primeiro.registro,
          chamador: servidor,
          emServidor: depois,
          ledgers: ledgers,
          calcularDelta: deltaPorResultado(),
          politica: politicaDeTeste,
        );
        expect(reenvio.houveMudanca, isFalse);
        expect(reenvio.lancamentos, isEmpty);
      }

      for (final e in ledgers.entries) {
        expect(e.value.saldo, saldoDepoisDoPrimeiro[e.key],
            reason: 'o ranking de ${e.key} não pode ter mudado no reenvio');
        expect(e.value.tamanho, 1);
      }
    });
  });

  group('ABA — abandono (§18, §33)', () {
    test('ABA-01 desconexão breve NÃO vira abandono automaticamente', () {
      // A política de presença do Motor não sabe produzir estado terminal —
      // esta é a trava que a rastreabilidade herda em vez de refazer.
      const politica = PoliticaPresenca();
      final instavel =
          politica.classificar(ultimoHeartbeatMs: 0, agoraMs: 15000);
      final ausente =
          politica.classificar(ultimoHeartbeatMs: 0, agoraMs: 60000);

      expect(instavel, EstadoPresenca.instavel);
      expect(ausente, EstadoPresenca.ausente);
      expect(instavel.ehTerminal, isFalse);
      expect(ausente.ehTerminal, isFalse);

      // E a classificação de saída correspondente também não é abandono.
      expect(ClassificacaoDeSaida.quedaDeConexao.podeSerAbandono, isFalse);
      expect(ClassificacaoDeSaida.timeoutDeTurno.podeSerAbandono, isFalse);
    });

    test('ABA-02 a queda gera evento de DESCONEXÃO, e ele declara que não '
        'encerra partida', () {
      final evento = registrarSaida(
        identidade: identidadeRanqueada(),
        assento: 3,
        classificacao: ClassificacaoDeSaida.quedaDeConexao,
        emServidor: agora,
        versaoEstado: 8,
      );
      expect(evento.tipo, TipoEventoAuditavel.desconexao);
      expect(evento.dados['podeSerAbandono'], false);
      expect(evento.dados['encerraPartida'], false);
    });

    test('ABA-03 abandono confirmado pela autoridade é registrado com motivo e '
        'responsável', () {
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoAbandono(autoridade: 'srv-arbitro-7'));

      expect(r.estado, EstadoDaPartida.abandonada);
      expect(r.motivoEncerramento, MotivoEncerramento.abandono);
      expect(r.autoridadeDoEncerramento, 'srv-arbitro-7');
    });

    test('ABA-04 o motivo da saída é preservado na trilha', () {
      for (final c in ClassificacaoDeSaida.values) {
        final evento = registrarSaida(
          identidade: identidadeRanqueada(),
          assento: 1,
          classificacao: c,
          emServidor: agora,
          versaoEstado: 5,
          declaradaPor: c.podeSerAbandono ? 'srv-1' : null,
        );
        expect(evento.dados['classificacao'], c.wire);
        expect(evento.dados['podeSerAbandono'], c.podeSerAbandono);
      }
    });

    test('ABA-05 retry não duplica o evento de abandono', () {
      final trilha = TrilhaDeEventos(kMatchId);
      EventoAuditavel gerar() => registrarSaida(
            identidade: identidadeRanqueada(),
            assento: 1,
            classificacao: ClassificacaoDeSaida.naoRetornou,
            emServidor: agora,
            versaoEstado: 42,
            declaradaPor: 'srv-1',
          );

      expect(trilha.registrar(gerar()), isTrue);
      expect(trilha.registrar(gerar()), isFalse);
      expect(trilha.registrar(gerar()), isFalse);
      expect(trilha.tamanho, 1);
    });

    test('ABA-06 abandono e reconexão concorrentes produzem estado consistente',
        () {
      // A corrida: o servidor declarou abandono enquanto o jogador reconectava.
      // O encerramento por ordem vence, porque só a autoridade encerra; a
      // reconexão fica registrada na trilha, sem reabrir nada.
      final aberto = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .transicionarPara(EstadoDaPartida.reconectando);

      final trilha = TrilhaDeEventos(kMatchId);
      trilha.registrar(registrarReconexao(
          identidade: aberto.identidade,
          assento: 1,
          emServidor: agora,
          versaoEstado: 40));

      final plano = ingerirEncerramento(
        desfecho: desfechoAbandono(),
        registroAtual: aberto,
        chamador: servidor,
        emServidor: depois,
      );
      trilha.registrarTodos(plano.eventos);

      expect(plano.registro.estado, EstadoDaPartida.abandonada);
      expect(plano.conferir(), isNull);
      // A trilha conta a história inteira: reconectou e, depois, foi declarado.
      expect(trilha.porTipo(TipoEventoAuditavel.reconexao).length, 1);
      expect(trilha.porTipo(TipoEventoAuditavel.abandono).length, 1);
    });

    test('ABA-07 depois do abandono, uma reconexão não reabre a partida', () {
      final abandonada = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoAbandono());
      expect(() => abandonada.transicionarPara(EstadoDaPartida.ativa),
          throwsA(isA<TransicaoInvalida>()));
      expect(() => abandonada.transicionarPara(EstadoDaPartida.reconectando),
          throwsA(isA<TransicaoInvalida>()));
    });

    test('ABA-08 o abandono ingerido duas vezes converge', () {
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final desfecho = desfechoAbandono();

      final primeiro = ingerirEncerramento(
          desfecho: desfecho,
          registroAtual: aberto,
          chamador: servidor,
          emServidor: depois);
      final segundo = ingerirEncerramento(
          desfecho: desfecho,
          registroAtual: primeiro.registro,
          chamador: servidor,
          emServidor: depois);

      expect(segundo.houveMudanca, isFalse);
      expect(segundo.registro.estado, EstadoDaPartida.abandonada);
    });
  });

  group('EVT — a trilha consome o diário do Motor, sem redefini-lo (§9)', () {
    test('EVT-01 eventos de ciclo de rodada do diário viram eventos '
        'auditáveis; jogada a jogada não', () {
      final motor = motorDe(jogoNovo());
      motor.iniciarNovaRodada();

      final eventos = EventoAuditavel.doDiarioCompleto(motor.diario,
          emServidor: depois);
      final tipos = eventos.map((e) => e.tipo).toSet();

      expect(tipos, contains(TipoEventoAuditavel.inicioRodada));
      // Nenhum comando individual sobrevive.
      expect(eventos.any((e) => e.dados['acao'] == 'DESCARTAR'), isFalse);
      for (final e in eventos) {
        expect(e.matchId, kMatchId);
        expect(e.eventId, startsWith(kMatchId));
      }
    });

    test('EVT-02 converter o mesmo diário duas vezes produz os mesmos eventIds',
        () {
      final motor = motorDe(jogoNovo());
      motor.iniciarNovaRodada();

      final a = EventoAuditavel.doDiarioCompleto(motor.diario, emServidor: depois);
      final b = EventoAuditavel.doDiarioCompleto(motor.diario, emServidor: depois);
      expect(a.map((e) => e.eventId).toList(), b.map((e) => e.eventId).toList());

      final trilha = TrilhaDeEventos(kMatchId);
      expect(trilha.registrarTodos(a), a.length);
      expect(trilha.registrarTodos(b), 0);
    });

    test('EVT-03 o evento auditável nunca carrega conteúdo de carta', () {
      final evento = EventoAuditavel.deCiclo(
        identidade: identidadeRanqueada(),
        tipo: TipoEventoAuditavel.inicio,
        emServidor: depois,
        sufixo: 'x',
        dados: {
          'cartas': ['AS', 'KH'],
          'mao': 'segredo',
          'email': 'alice@exemplo.com',
          'token': 'abc123',
          'monteRestante': 40,
        },
      );
      expect(evento.dados['cartas'], '<omitido>');
      expect(evento.dados['mao'], '<omitido>');
      expect(evento.dados['email'], '<omitido>');
      expect(evento.dados['token'], '<omitido>');
      expect(evento.dados['monteRestante'], 40,
          reason: 'contagem não é conteúdo');
    });

    test('EVT-04 a lista de censura cobre as chaves que o diário do Motor '
        'também protege', () {
      // Dependência declarada em eventos_auditaveis.dart: as duas listas são
      // independentes de propósito (não mexer no Motor), e esta é a prova de
      // que a de persistência não ficou mais frouxa.
      const doMotor = {
        'mao', 'maos', 'cartas', 'monte', 'lixo', 'morto', 'mortos',
        'jogos', 'jogosnos', 'jogoseles', 'baralho',
        'apelido', 'apelidos', 'email', 'uid', 'token',
      };
      expect(EventoAuditavel.chavesCensuradas.containsAll(doMotor), isTrue);
    });

    test('EVT-05 evento de outra partida não entra na trilha', () {
      final trilha = TrilhaDeEventos(kMatchId);
      final alheio = EventoAuditavel.deCiclo(
        identidade: identidadeRanqueada(matchId: kOutroMatchId),
        tipo: TipoEventoAuditavel.inicio,
        emServidor: depois,
        sufixo: 'x',
      );
      expect(() => trilha.registrar(alheio), throwsA(isA<ArgumentError>()));
    });

    test('EVT-06 o evento sobrevive ao round-trip JSON', () {
      final original = EventoAuditavel.deCiclo(
        identidade: identidadeRanqueada(),
        tipo: TipoEventoAuditavel.resultado,
        emServidor: depois,
        sufixo: 'v9',
        rodada: 3,
        versaoEstado: 9,
        dados: const {'ladoVencedor': 'nos'},
      );
      final lido = EventoAuditavel.deJson(original.toJson());
      expect(lido.toJson(), original.toJson());
    });
  });
}
