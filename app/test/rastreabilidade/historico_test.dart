// historico_test.dart — §31 da OS: TESTES OBRIGATÓRIOS — HISTÓRICO.
// Cobre também §12 (before/delta/after) e §36 (performance/paginação).
//
//   * histórico recebe partida finalizada;
//   * partida aparece uma vez;
//   * partida casual não altera ranking;
//   * ranqueada altera ranking uma vez;
//   * histórico registra delta correto;
//   * before + delta = after;
//   * retry não cria entrada duplicada;
//   * jogador não edita próprio histórico (ver seguranca_test.dart e as Rules).

import 'package:buraco_master_vip/rastreabilidade/historico_e_consulta.dart';
import 'package:buraco_master_vip/rastreabilidade/identidade_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/ingestao.dart';
import 'package:buraco_master_vip/rastreabilidade/ledger_competitivo.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ferramentas.dart';

RegistroDePartida encerrada({
  String matchId = kMatchId,
  bool ranqueada = true,
}) {
  final base = ranqueada
      ? registroRanqueado(matchId: matchId)
      : registroCasual(matchId: matchId);
  return base
      .transicionarPara(EstadoDaPartida.ativa)
      .encerrarCom(desfechoNormal(matchId: matchId));
}

void main() {
  group('HIS — histórico do jogador (§11, §31)', () {
    test('HIS-01 o histórico recebe a partida finalizada, com o resultado do '
        'ponto de vista do jogador', () {
      final r = encerrada();
      final vencedor = projetarParaJogador(registro: r, userId: 'uid-a');
      final perdedor = projetarParaJogador(registro: r, userId: 'uid-b');

      expect(vencedor.matchId, kMatchId);
      expect(vencedor.resultado, ResultadoDoJogador.vitoria);
      expect(vencedor.pontosMeuLado, 1520);
      expect(vencedor.pontosOutroLado, 1180);
      expect(vencedor.lado, 'nos');
      expect(vencedor.assento, 0);

      expect(perdedor.resultado, ResultadoDoJogador.derrota);
      expect(perdedor.pontosMeuLado, 1180);
      expect(perdedor.lado, 'eles');
    });

    test('HIS-02 partida ainda viva não vira histórico', () {
      final viva = registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      expect(() => projetarParaJogador(registro: viva, userId: 'uid-a'),
          throwsA(isA<HistoricoIndisponivel>()));
    });

    test('HIS-03 quem não competiu não tem histórico daquela partida', () {
      final r = encerrada();
      expect(() => projetarParaJogador(registro: r, userId: 'uid-estranho'),
          throwsA(isA<HistoricoIndisponivel>()));
    });

    test('HIS-04 espectador não recebe entrada de histórico competitivo', () {
      final r = registroRanqueado(espectadores: const ['uid-x'])
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());
      expect(() => projetarParaJogador(registro: r, userId: 'uid-x'),
          throwsA(isA<HistoricoIndisponivel>()));
    });

    test('HIS-05 partida casual mostra rankingDelta nulo — "não se aplica", '
        'nunca zero', () {
      final casual = encerrada(ranqueada: false);
      final entrada = projetarParaJogador(registro: casual, userId: 'uid-a');
      expect(casual.alteraRanking, isFalse);
      expect(entrada.rankingDelta, isNull);
      expect(entrada.tipo, TipoDePartida.publicaCasual);
    });

    test('HIS-06 partida anulada aparece como sem efeito', () {
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoAnulado());
      final entrada = projetarParaJogador(registro: r, userId: 'uid-a');
      expect(entrada.resultado, ResultadoDoJogador.semEfeito);
      expect(r.alteraRanking, isFalse);
    });

    test('HIS-07 o histórico do jogador NÃO carrega dado administrativo', () {
      final r = encerrada();
      final json = projetarParaJogador(registro: r, userId: 'uid-a').toJson();

      for (final proibido in [
        'impressaoEstado',
        'versaoEstadoFinal',
        'autoridadeDoEncerramento',
        'participantes',
        'userIdsCompetidores',
      ]) {
        expect(json.containsKey(proibido), isFalse,
            reason: '"$proibido" é administrativo e não vai para o jogador');
      }
      // E não expõe UID de terceiros em lugar nenhum do envelope.
      final texto = json.toString();
      expect(texto.contains('uid-b'), isFalse);
      expect(texto.contains('uid-c'), isFalse);
      // Contagem, sim; identidade, não.
      expect(json['competidores'], 4);
      expect(json['robos'], 0);
    });

    test('HIS-08 abandono do próprio jogador é distinguível do abandono alheio',
        () {
      // `nos` venceu por abandono, logo quem abandonou foi `eles`.
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoAbandono(ladoVencedor: 'nos'));

      final ficou = projetarParaJogador(registro: r, userId: 'uid-a');
      final saiu = projetarParaJogador(registro: r, userId: 'uid-b');

      expect(ficou.houveAbandono, isTrue);
      expect(ficou.abandonoFoiMeu, isFalse);
      expect(saiu.abandonoFoiMeu, isTrue);
    });

    test('HIS-09 partida sem abandono não afirma nada sobre abandono', () {
      final entrada = projetarParaJogador(registro: encerrada(), userId: 'uid-a');
      expect(entrada.houveAbandono, isFalse);
      expect(entrada.abandonoFoiMeu, isNull);
    });
  });

  group('LED — ledger competitivo (§12, §13)', () {
    test('LED-01 before + delta = after, e o contrário é recusado', () {
      final ok = LancamentoCompetitivo(
        matchId: kMatchId,
        userId: 'uid-a',
        motivo: MotivoLancamento.resultadoDePartida,
        antes: 100,
        delta: 25,
        depois: 125,
        registradoEm: depois,
        politica: politicaDeTeste,
      );
      expect(ok.depois, ok.antes + ok.delta);

      expect(
        () => LancamentoCompetitivo(
          matchId: kMatchId,
          userId: 'uid-a',
          motivo: MotivoLancamento.resultadoDePartida,
          antes: 100,
          delta: 25,
          depois: 200,
          registradoEm: depois,
          politica: politicaDeTeste,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('LED-02 ranqueada altera o ranking UMA vez e registra o delta correto',
        () {
      final r = encerrada();
      final ledger = LedgerCompetitivo('uid-a');

      final primeiro = ledger.registrarResultado(
          registro: r,
          delta: 25,
          registradoEm: depois,
          politica: politicaDeTeste);
      expect(primeiro.lancou, isTrue);
      expect(primeiro.aplicado!.antes, 0);
      expect(primeiro.aplicado!.delta, 25);
      expect(primeiro.aplicado!.depois, 25);

      final segundo = ledger.registrarResultado(
          registro: r,
          delta: 25,
          registradoEm: depois,
          politica: politicaDeTeste);
      expect(segundo.lancou, isFalse);
      expect(segundo.recusa, RecusaLancamento.jaLancado);
      expect(segundo.recusa!.idempotente, isTrue);
      expect(ledger.saldo, 25);
      expect(ledger.tamanho, 1);
    });

    test('LED-03 partida casual não gera lançamento', () {
      final ledger = LedgerCompetitivo('uid-a');
      final v = ledger.registrarResultado(
          registro: encerrada(ranqueada: false),
          delta: 25,
          registradoEm: depois,
          politica: politicaDeTeste);
      expect(v.recusa, RecusaLancamento.partidaNaoPontua);
      expect(ledger.saldo, 0);
    });

    test('LED-04 robô e espectador não recebem lançamento', () {
      final r = registroRanqueado(
        assentos: doisHumanosDoisRobos(),
        espectadores: const ['uid-x'],
      )
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());

      expect(elegiveisALancamento(r), ['uid-a', 'uid-b']);
      expect(
          LedgerCompetitivo('uid-x')
              .registrarResultado(
                  registro: r,
                  delta: 10,
                  registradoEm: depois,
                  politica: politicaDeTeste)
              .recusa,
          RecusaLancamento.jogadorNaoCompetiu);
    });

    test('LED-05 a sequência encadeia: o antes de cada um é o depois do anterior',
        () {
      final ledger = LedgerCompetitivo('uid-a', saldoInicial: 500);
      for (final (i, delta) in [30, -12, 45].indexed) {
        final r = encerrada(matchId: 'match-serie-000$i');
        final v = ledger.registrarResultado(
            registro: r,
            delta: delta,
            registradoEm: depois,
            politica: politicaDeTeste);
        expect(v.lancou, isTrue);
      }
      expect(ledger.saldo, 500 + 30 - 12 + 45);
      expect(ledger.conferir(), isNull);

      final lista = ledger.lancamentos;
      expect(lista.first.antes, 500);
      for (var i = 1; i < lista.length; i++) {
        expect(lista[i].antes, lista[i - 1].depois);
      }
    });

    test('LED-06 reconstruir recusa uma cadeia rompida', () {
      final bom = LancamentoCompetitivo(
          matchId: 'match-serie-0000',
          userId: 'uid-a',
          motivo: MotivoLancamento.resultadoDePartida,
          antes: 0,
          delta: 10,
          depois: 10,
          registradoEm: depois,
          politica: politicaDeTeste);
      final rompido = LancamentoCompetitivo(
          matchId: 'match-serie-0001',
          userId: 'uid-a',
          motivo: MotivoLancamento.resultadoDePartida,
          antes: 99, // deveria ser 10
          delta: 5,
          depois: 104,
          registradoEm: depois,
          politica: politicaDeTeste);

      expect(() => LedgerCompetitivo.reconstruir('uid-a', [bom, rompido]),
          throwsA(isA<StateError>()));
      expect(LedgerCompetitivo.reconstruir('uid-a', [bom]).saldo, 10);
    });

    test('LED-07 o estorno é um lançamento novo, não um apagamento', () {
      final ledger = LedgerCompetitivo('uid-a');
      ledger.registrarResultado(
          registro: encerrada(),
          delta: 40,
          registradoEm: depois,
          politica: politicaDeTeste);
      expect(ledger.saldo, 40);

      final estorno = ledger.estornar(
          matchId: kMatchId, registradoEm: depois, autoridade: 'admin-1');
      expect(estorno.lancou, isTrue);
      expect(estorno.aplicado!.delta, -40);
      expect(ledger.saldo, 0);
      expect(ledger.tamanho, 2, reason: 'o original continua no ledger');
      expect(ledger.conferir(), isNull);

      // Estornar de novo não zera duas vezes.
      expect(
          ledger
              .estornar(
                  matchId: kMatchId,
                  registradoEm: depois,
                  autoridade: 'admin-1')
              .recusa,
          RecusaLancamento.jaLancado);
      expect(ledger.saldo, 0);
    });

    test('LED-08 correção administrativa exige autoridade declarada', () {
      expect(
        () => LancamentoCompetitivo(
            matchId: kMatchId,
            userId: 'uid-a',
            motivo: MotivoLancamento.correcaoAdministrativa,
            antes: 0,
            delta: 10,
            depois: 10,
            registradoEm: depois,
            politica: politicaDeTeste),
        throwsA(isA<ArgumentError>()),
      );
      // E o automático não pode fingir ter autoridade.
      expect(
        () => LancamentoCompetitivo(
            matchId: kMatchId,
            userId: 'uid-a',
            motivo: MotivoLancamento.resultadoDePartida,
            antes: 0,
            delta: 10,
            depois: 10,
            registradoEm: depois,
            politica: politicaDeTeste,
            autoridade: 'admin-1'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('LED-09 um lançamento adulterado no banco é recusado na leitura', () {
      final json = LancamentoCompetitivo(
              matchId: kMatchId,
              userId: 'uid-a',
              motivo: MotivoLancamento.resultadoDePartida,
              antes: 100,
              delta: 20,
              depois: 120,
              registradoEm: depois,
              politica: politicaDeTeste)
          .toJson();

      expect(LancamentoCompetitivo.deJson(json).depois, 120);

      // Alguém subiu o "after" sem mexer no delta.
      expect(
          () => LancamentoCompetitivo.deJson({...json, 'rankingAfter': 9999}),
          throwsA(isA<FormatException>()));
      // Ou trocou o dono do lançamento sem refazer a chave.
      expect(
          () => LancamentoCompetitivo.deJson({...json, 'userId': 'uid-b'}),
          throwsA(isA<FormatException>()));
    });

    test('LED-10 sem política definida nenhum lançamento é produzido', () {
      final ledger = LedgerCompetitivo('uid-a');
      final v = ledger.registrarResultado(
          registro: encerrada(),
          delta: 25,
          registradoEm: depois,
          politica: PoliticaDeRanking.pendente);
      expect(v.recusa, RecusaLancamento.politicaNaoDefinida);
      expect(ledger.saldo, 0);
    });
  });

  group('IDX — consulta e paginação (§27, §36)', () {
    IndicePartidas indiceCom(int quantas) {
      final indice = IndicePartidas();
      for (var i = 0; i < quantas; i++) {
        indice.gravar(encerrada(matchId: 'match-hist-${i.toString().padLeft(4, '0')}'));
      }
      return indice;
    }

    test('IDX-01 a partida aparece UMA vez, mesmo gravada duas vezes', () {
      final indice = IndicePartidas();
      final r = encerrada();
      indice.gravar(r);
      indice.gravar(r);

      expect(indice.tamanho, 1);
      expect(indice.historicoDe('uid-a').length, 1);
    });

    test('IDX-02 localizar por matchId — §14', () {
      final indice = indiceCom(5);
      expect(indice.porMatchId('match-hist-0003')!.matchId, 'match-hist-0003');
      expect(indice.porMatchId('match-inexistente'), isNull);
    });

    test('IDX-03 o histórico é paginado por cursor e não varre a coleção', () {
      final indice = indiceCom(25);
      final pagina1 = indice.historicoDe('uid-a', limite: 10);
      expect(pagina1.length, 10);

      final pagina2 =
          indice.historicoDe('uid-a', limite: 10, depoisDe: pagina1.last.matchId);
      expect(pagina2.length, 10);
      expect(pagina2.map((r) => r.matchId).toSet()
          .intersection(pagina1.map((r) => r.matchId).toSet()),
          isEmpty);

      final pagina3 =
          indice.historicoDe('uid-a', limite: 10, depoisDe: pagina2.last.matchId);
      expect(pagina3.length, 5);
    });

    test('IDX-04 partida ainda viva não entra no histórico', () {
      final indice = IndicePartidas();
      indice.gravar(registroRanqueado().transicionarPara(EstadoDaPartida.ativa));
      expect(indice.tamanho, 1);
      expect(indice.historicoDe('uid-a'), isEmpty);
    });

    test('IDX-05 partidas entre dois jogadores — base do sinal de dupla '
        'recorrente', () {
      final indice = indiceCom(3);
      expect(indice.entre('uid-a', 'uid-b').length, 3);
      expect(indice.entre('uid-a', 'uid-estranho'), isEmpty);
    });

    test('IDX-06 consulta por período e por tipo', () {
      final indice = IndicePartidas();
      indice.gravar(encerrada(matchId: 'match-rank-0001'));
      indice.gravar(encerrada(matchId: 'match-casu-0001', ranqueada: false));

      final todas = indice.noPeriodo(agora, depois.add(const Duration(days: 1)));
      expect(todas.length, 2);

      final soRanqueadas = indice.noPeriodo(
          agora, depois.add(const Duration(days: 1)),
          tipo: TipoDePartida.publicaRanqueada);
      expect(soRanqueadas.single.matchId, 'match-rank-0001');

      final foraDaJanela = indice.noPeriodo(
          DateTime.utc(2020), DateTime.utc(2021));
      expect(foraDaJanela, isEmpty);
    });
  });

  group('RET — retry não duplica entrada de histórico (§31)', () {
    test('RET-01 a mesma ingestão repetida não cria segunda entrada', () {
      final indice = IndicePartidas();
      final aberto =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final desfecho = desfechoNormal();

      final primeiro = ingerirEncerramento(
          desfecho: desfecho,
          registroAtual: aberto,
          chamador: servidor,
          emServidor: depois);
      indice.gravar(primeiro.registro);

      final segundo = ingerirEncerramento(
          desfecho: desfecho,
          registroAtual: primeiro.registro,
          chamador: servidor,
          emServidor: depois);
      indice.gravar(segundo.registro);

      expect(segundo.houveMudanca, isFalse);
      expect(indice.tamanho, 1);
      expect(indice.historicoDe('uid-a').length, 1);
    });
  });
}
