// resultado_test.dart — §30 da OS: TESTES OBRIGATÓRIOS — RESULTADO.
// Cobre também §20 (concorrência) e §21 (finalização atômica).
//
//   * encerramento normal;
//   * vencedor correto é persistido;
//   * placar final é persistido;
//   * resultado não pode ser sobrescrito pelo cliente;
//   * callback duplicado não duplica resultado;
//   * retry não duplica ranking;
//   * dois encerramentos concorrentes convergem corretamente.

import 'package:buraco_master_vip/motor/desfecho_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/eventos_auditaveis.dart';
import 'package:buraco_master_vip/rastreabilidade/ingestao.dart';
import 'package:buraco_master_vip/rastreabilidade/ledger_competitivo.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ferramentas.dart';

/// Encerra pela ingestão, que é a porta real, e devolve o plano.
PlanoDeEncerramento ingerir({
  RegistroDePartida? registro,
  DesfechoCanonicoPartida? desfecho,
  Map<String, LedgerCompetitivo> ledgers = const {},
  CalculoDeDelta? delta,
  PoliticaDeRanking politica = politicaDeTeste,
  ChamadorAutorizado chamador = servidor,
}) =>
    ingerirEncerramento(
      desfecho: desfecho ?? desfechoNormal(),
      registroAtual:
          registro ?? registroRanqueado().transicionarPara(EstadoDaPartida.ativa),
      chamador: chamador,
      emServidor: depois,
      ledgers: ledgers,
      calcularDelta: delta,
      politica: politica,
    );

void main() {
  group('RES — encerramento e resultado', () {
    test('RES-01 encerramento normal persiste estado, vencedor e placar', () {
      final plano = ingerir();
      final r = plano.registro;

      expect(r.estado, EstadoDaPartida.finalizada);
      expect(r.motivoEncerramento, MotivoEncerramento.metaAtingida);
      expect(r.ladoVencedor, 'nos');
      expect(r.placarDe('nos')!.pontos, 1520);
      expect(r.placarDe('eles')!.pontos, 1180);
      expect(r.encerradaEm, depois);
      expect(plano.houveMudanca, isTrue);
      expect(plano.conferir(), isNull);
    });

    test('RES-02 o vencedor é COPIADO do desfecho, não deduzido do placar', () {
      // Abandono com o lado de MENOR placar declarado vencedor pela autoridade.
      // Se alguma camada deduzisse pelo placar, este caso quebraria.
      final desfecho = desfechoAbandono(ladoVencedor: 'eles');
      final plano = ingerir(desfecho: desfecho);

      expect(plano.registro.placarDe('nos')!.pontos, 300);
      expect(plano.registro.placarDe('eles')!.pontos, 120);
      expect(plano.registro.ladoVencedor, 'eles',
          reason: 'quem venceu é quem a autoridade declarou');
      expect(plano.registro.estado, EstadoDaPartida.abandonada);
      expect(plano.registro.autoridadeDoEncerramento, 'srv-1');
    });

    test('RES-03 canastras limpas e impressão do estado viajam para o registro',
        () {
      final plano = ingerir();
      final desfecho = desfechoNormal();
      expect(plano.registro.impressaoEstado, desfecho.impressaoEstado);
      expect(plano.registro.versaoEstadoFinal, desfecho.versaoEstado);
      expect(plano.registro.placarDe('nos')!.canastrasLimpas,
          desfecho.porLado('nos')!.canastrasLimpas);
    });

    test('RES-04 gera os dois eventos de encerramento: fecho e resultado', () {
      final plano = ingerir();
      final tipos = plano.eventos.map((e) => e.tipo).toSet();
      expect(tipos, contains(TipoEventoAuditavel.encerramento));
      expect(tipos, contains(TipoEventoAuditavel.resultado));

      final resultado = plano.eventos
          .firstWhere((e) => e.tipo == TipoEventoAuditavel.resultado);
      expect(resultado.dados['ladoVencedor'], 'nos');
      expect(resultado.dados['pontos_nos'], 1520);
      expect(resultado.matchId, kMatchId);
    });

    test('RES-05 abandono produz evento de abandono, não de encerramento comum',
        () {
      final plano = ingerir(desfecho: desfechoAbandono());
      final tipos = plano.eventos.map((e) => e.tipo).toSet();
      expect(tipos, contains(TipoEventoAuditavel.abandono));
      expect(tipos, isNot(contains(TipoEventoAuditavel.encerramento)));
    });

    test('RES-06 desfecho de partida viva não encerra nada', () {
      expect(
        () => ingerir(desfecho: desfechoEmAndamento()),
        throwsA(isA<ArgumentError>()),
      );
      // E pela porta de validação de envelope, vira recusa com motivo.
      expect(
        () => validarEnvelope({
          'matchId': kMatchId,
          'desfecho': desfechoEmAndamento().toJson(),
        }, chamador: servidor),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.desfechoNaoConclusivo)),
      );
    });
  });

  group('DUP — callback duplicado e retry (§10, §20)', () {
    test('DUP-01 o mesmo desfecho ingerido duas vezes não muda nada na segunda',
        () {
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final desfecho = desfechoNormal();

      final primeiro = ingerir(registro: aberto, desfecho: desfecho);
      final segundo =
          ingerir(registro: primeiro.registro, desfecho: desfecho);

      expect(primeiro.houveMudanca, isTrue);
      expect(segundo.houveMudanca, isFalse,
          reason: 'reenvio não regrava — é o caminho do retry');
      expect(segundo.eventos, isEmpty);
      expect(segundo.lancamentos, isEmpty);
      expect(segundo.registro.ladoVencedor, 'nos');
    });

    test('DUP-02 um segundo desfecho DIVERGENTE é recusado', () {
      final primeiro = ingerir();
      expect(
        () => ingerir(
          registro: primeiro.registro,
          desfecho: desfechoNormal(nos: 1180, eles: 1520),
        ),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.desfechoDivergente)),
      );
      // O registro publicado continua o mesmo.
      expect(primeiro.registro.ladoVencedor, 'nos');
      expect(primeiro.registro.placarDe('nos')!.pontos, 1520);
    });

    test('DUP-03 dois encerramentos CONCORRENTES do mesmo estado convergem', () {
      // Simula a corrida: dois callbacks partem do MESMO registro aberto e do
      // mesmo desfecho. O primeiro grava; o segundo lê o registro já gravado.
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final desfecho = desfechoNormal();

      final a = ingerir(registro: aberto, desfecho: desfecho);
      final b = ingerir(registro: aberto, desfecho: desfecho);
      // Ambos produzem o mesmo registro — a gravação é convergente.
      expect(a.registro.toJson(), b.registro.toJson());
      // E os eventos têm o MESMO eventId, então gravar os dois lotes é a
      // mesma escrita.
      expect(a.eventos.map((e) => e.eventId).toList(),
          b.eventos.map((e) => e.eventId).toList());

      final trilha = TrilhaDeEventos(kMatchId);
      expect(trilha.registrarTodos(a.eventos), a.eventos.length);
      expect(trilha.registrarTodos(b.eventos), 0,
          reason: 'o segundo lote é idempotente por eventId');
      expect(trilha.tamanho, a.eventos.length);
    });

    test('DUP-04 retry NÃO aplica ranking duas vezes', () {
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final ledgers = {
        for (final uid in ['uid-a', 'uid-b', 'uid-c', 'uid-d'])
          uid: LedgerCompetitivo(uid),
      };

      final primeiro = ingerir(
        registro: aberto,
        ledgers: ledgers,
        delta: deltaPorResultado(),
      );
      expect(primeiro.lancamentos.length, 4);
      expect(ledgers['uid-a']!.saldo, 25);
      expect(ledgers['uid-b']!.saldo, -15);

      // Retry: mesma ingestão, mesmos ledgers já com o lançamento dentro.
      final segundo = ingerir(
        registro: primeiro.registro,
        ledgers: ledgers,
        delta: deltaPorResultado(),
      );
      expect(segundo.lancamentos, isEmpty);
      expect(ledgers['uid-a']!.saldo, 25, reason: 'não somou de novo');
      expect(ledgers['uid-a']!.tamanho, 1);
    });

    test('DUP-05 mesmo que a ingestão fosse chamada com registro ainda aberto, '
        'o ledger recusa o segundo lançamento', () {
      // Cinto e suspensório: a barreira do ledger é independente da barreira do
      // registro. Aqui o registro é "esquecido" (volta a aberto), e ainda assim
      // o ranking não dobra.
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final ledgers = {'uid-a': LedgerCompetitivo('uid-a')};

      ingerir(registro: aberto, ledgers: ledgers, delta: deltaFixo(30));
      final segundo =
          ingerir(registro: aberto, ledgers: ledgers, delta: deltaFixo(30));

      expect(ledgers['uid-a']!.saldo, 30);
      expect(segundo.lancamentos.where((l) => l.userId == 'uid-a'), isEmpty);
    });
  });

  group('ATM — finalização atômica (§21)', () {
    test('ATM-01 o plano é coerente: estado, placar, vencedor, eventos e '
        'lançamentos nascem juntos', () {
      final plano = ingerir(
        ledgers: {
          for (final uid in ['uid-a', 'uid-b', 'uid-c', 'uid-d'])
            uid: LedgerCompetitivo(uid),
        },
        delta: deltaPorResultado(),
      );
      expect(plano.conferir(), isNull);
      expect(plano.registro.estado.terminal, isTrue);
      expect(plano.registro.placar, isNotEmpty);
      expect(plano.registro.ladoVencedor, isNotNull);
      expect(plano.eventos, isNotEmpty);
      expect(plano.lancamentos.length, 4);
    });

    test('ATM-02 partida que não pontua não gera lançamento nenhum', () {
      final casual =
          registroCasual().transicionarPara(EstadoDaPartida.ativa);
      final plano = ingerir(
        registro: casual,
        ledgers: {'uid-a': LedgerCompetitivo('uid-a')},
        delta: deltaFixo(50),
      );
      expect(plano.registro.alteraRanking, isFalse);
      expect(plano.lancamentos, isEmpty);
      expect(plano.registro.estado, EstadoDaPartida.finalizada);
    });

    test('ATM-03 sem política de ranking definida, nenhum delta é inventado',
        () {
      final plano = ingerir(
        ledgers: {'uid-a': LedgerCompetitivo('uid-a')},
        delta: deltaFixo(50),
        politica: PoliticaDeRanking.pendente,
      );
      expect(plano.lancamentos, isEmpty,
          reason: 'a fórmula é decisão de produto pendente');
      expect(plano.registro.estado, EstadoDaPartida.finalizada,
          reason: 'a partida ainda encerra normalmente');
    });

    test('ATM-04 partida anulada vira cancelada e não pontua para ninguém', () {
      final plano = ingerir(
        desfecho: desfechoAnulado(),
        ledgers: {'uid-a': LedgerCompetitivo('uid-a')},
        delta: deltaFixo(50),
      );
      expect(plano.registro.estado, EstadoDaPartida.cancelada);
      expect(plano.registro.ladoVencedor, isNull);
      expect(plano.registro.alteraRanking, isFalse);
      expect(plano.lancamentos, isEmpty);
    });

    test('ATM-05 o desfecho de uma partida não encerra outra', () {
      expect(
        () => ingerir(desfecho: desfechoNormal(matchId: kOutroMatchId)),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.matchIdDivergente)),
      );
    });

    test('ATM-06 resultado de partida que não existe não cria partida', () {
      expect(
        () => ingerirEncerramento(
          desfecho: desfechoNormal(),
          registroAtual: null,
          chamador: servidor,
          emServidor: depois,
        ),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.partidaInexistente)),
      );
    });
  });

  group('EST — estados da partida (§22, §23)', () {
    test('EST-01 o grafo recusa transição não prevista', () {
      final r = registroRanqueado();
      expect(r.estado, EstadoDaPartida.criada);
      expect(() => r.transicionarPara(EstadoDaPartida.reconectando),
          throwsA(isA<TransicaoInvalida>()));
      expect(
          r
              .transicionarPara(EstadoDaPartida.ativa)
              .transicionarPara(EstadoDaPartida.reconectando)
              .estado,
          EstadoDaPartida.reconectando);
    });

    test('EST-02 transicionar para o mesmo estado é idempotente', () {
      final r = registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      expect(identical(r.transicionarPara(EstadoDaPartida.ativa), r), isTrue);
    });

    test('EST-03 estado terminal não muda mais — §23', () {
      final encerrado = ingerir().registro;
      for (final destino in EstadoDaPartida.values) {
        if (destino == encerrado.estado) continue;
        expect(() => encerrado.transicionarPara(destino),
            throwsA(isA<TransicaoInvalida>()),
            reason: 'terminal não vai para ${destino.wire}');
      }
    });

    test('EST-04 iniciadaEm é carimbado na primeira ida para ativa', () {
      final r = registroRanqueado();
      expect(r.iniciadaEm, isNull);
      final ativo = r.transicionarPara(EstadoDaPartida.ativa, em: agora);
      expect(ativo.iniciadaEm, agora);
      // Voltar de reconectando para ativa não reescreve o início.
      final voltou = ativo
          .transicionarPara(EstadoDaPartida.reconectando)
          .transicionarPara(EstadoDaPartida.ativa, em: depois);
      expect(voltou.iniciadaEm, agora);
    });

    test('EST-05 o registro sobrevive ao round-trip JSON', () {
      final original = ingerir().registro;
      final lido = RegistroDePartida.deJson(original.toJson());
      expect(lido.toJson(), original.toJson());
      expect(lido.matchId, original.matchId);
      expect(lido.ladoVencedor, original.ladoVencedor);
      expect(lido.competidores.length, original.competidores.length);
    });
  });
}
