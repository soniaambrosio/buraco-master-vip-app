// antifraude_test.dart — §35 da OS: TESTES ANTIFRAUDE.
//
// Apenas sobre a INFRAESTRUTURA de sinais, como a seção manda:
//   * sinal é associado ao matchId;
//   * sinal contém timestamp server-side;
//   * jogador não cria flag administrativa contra terceiros;
//   * sinal NÃO gera punição automaticamente;
//   * evidência pode ser relacionada à partida;
//   * retry não duplica sinal idempotente.
//
// O teste AFR-04 é o mais importante do arquivo: ele varre a API pública de
// `sinais_antifraude.dart` procurando qualquer coisa que decida sobre uma
// pessoa, e falha se aparecer.

import 'package:buraco_master_vip/rastreabilidade/historico_e_consulta.dart';
import 'package:buraco_master_vip/rastreabilidade/identidade_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/ingestao.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/sinais_antifraude.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ferramentas.dart';

SinalAntifraude sinalDeExemplo({String matchId = kMatchId}) => SinalAntifraude(
      matchId: matchId,
      tipo: TipoDeSinal.abandonoAoPerder,
      alvos: const ['uid-b'],
      observadoEm: depois,
      origem: 'detector-teste-v1',
      observacao: '7 de 8 abandonos ocorreram com o placar desfavorável.',
      intensidade: IntensidadeSinal.media,
      evidencia: const {'abandonosPerdendo': 7, 'abandonosTotais': 8},
    );

void main() {
  group('AFR — infraestrutura de sinais (§16, §35)', () {
    test('AFR-01 o sinal é sempre associado a um matchId', () {
      expect(sinalDeExemplo().matchId, kMatchId);
      expect(matchIdDoSinal(sinalDeExemplo()), kMatchId);
      expect(
        () => SinalAntifraude(
          matchId: '',
          tipo: TipoDeSinal.abandonoAoPerder,
          alvos: const ['uid-b'],
          observadoEm: depois,
          origem: 'x',
          observacao: 'y',
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'sinal sem partida não é investigável',
      );
    });

    test('AFR-02 o timestamp é server-side e em UTC', () {
      final local = DateTime(2026, 8, 11, 15);
      final sinal = SinalAntifraude(
        matchId: kMatchId,
        tipo: TipoDeSinal.sequenciaImprovavel,
        alvos: const ['uid-a'],
        observadoEm: local,
        origem: 'detector-teste-v1',
        observacao: 'observação de teste.',
      );
      expect(sinal.observadoEm.isUtc, isTrue);
      expect(sinal.observadoEm, local.toUtc());
    });

    test('AFR-03 sinal sem alvo, sem origem ou sem observação é recusado', () {
      SinalAntifraude construir({
        List<String> alvos = const ['uid-a'],
        String origem = 'd',
        String observacao = 'o',
      }) =>
          SinalAntifraude(
            matchId: kMatchId,
            tipo: TipoDeSinal.contasCorrelacionadas,
            alvos: alvos,
            observadoEm: depois,
            origem: origem,
            observacao: observacao,
          );

      expect(() => construir(alvos: const []), throwsA(isA<ArgumentError>()));
      expect(() => construir(origem: ''), throwsA(isA<ArgumentError>()));
      expect(() => construir(observacao: ''), throwsA(isA<ArgumentError>()));
    });

    test('AFR-04 NENHUM símbolo desta camada produz punição', () {
      // A afirmação estrutural, gravada no próprio documento.
      expect(SinalAntifraude.geraPunicao, isFalse);
      expect(sinalDeExemplo().toJson()['geraPunicao'], false);

      // O vocabulário do tipo é descritivo, nunca de veredito.
      for (final t in TipoDeSinal.values) {
        for (final proibido in [
          'fraude',
          'fraudador',
          'trapaca',
          'trapaceiro',
          'culpado',
          'banido',
          'punicao',
          'suspenso',
        ]) {
          expect(t.wire.contains(proibido), isFalse,
              reason: '"${t.wire}" descreve o dado, não a pessoa');
        }
      }

      // O envelope gravado usa `suspectedPattern`, e não um booleano de culpa.
      final json = sinalDeExemplo().toJson();
      expect(json.containsKey('suspectedPattern'), isTrue);
      for (final proibido in [
        'userIsFraudster',
        'culpado',
        'punicao',
        'suspender',
        'banir',
        'bloqueado',
      ]) {
        expect(json.containsKey(proibido), isFalse);
      }

      // E o registro não sabe fazer nada com um jogador além de listar sinais.
      final registro = RegistroDeSinais()..registrar(sinalDeExemplo());
      expect(registro.sobre('uid-b').length, 1,
          reason: 'listar é o máximo que a infraestrutura faz');
    });

    test('AFR-05 a evidência é relacionável à partida e não carrega dado '
        'privado', () {
      final sinal = SinalAntifraude(
        matchId: kMatchId,
        tipo: TipoDeSinal.resultadosConcentrados,
        alvos: const ['uid-a', 'uid-b'],
        observadoEm: depois,
        origem: 'detector-teste-v1',
        observacao: 'observação de teste.',
        evidencia: const {
          'vitoriasSeguidas': 9,
          'cartas': 'AS,KH',
          'email': 'alice@exemplo.com',
          'ip': '10.0.0.1',
          'senha': 'x',
        },
      );
      expect(sinal.evidencia['vitoriasSeguidas'], 9);
      for (final proibido in ['cartas', 'email', 'ip', 'senha']) {
        expect(sinal.evidencia[proibido], '<omitido>');
      }
      expect(sinal.matchId, kMatchId);
    });

    test('AFR-06 retry não duplica sinal idempotente', () {
      final registro = RegistroDeSinais();
      expect(registro.registrar(sinalDeExemplo()), isTrue);
      expect(registro.registrar(sinalDeExemplo()), isFalse);
      expect(registro.registrar(sinalDeExemplo()), isFalse);
      expect(registro.tamanho, 1);

      // Sinal do mesmo tipo em OUTRA partida é outro sinal.
      expect(registro.registrar(sinalDeExemplo(matchId: kOutroMatchId)), isTrue);
      expect(registro.tamanho, 2);
    });

    test('AFR-07 a chave de idempotência independe da ordem dos alvos', () {
      SinalAntifraude com(List<String> alvos) => SinalAntifraude(
            matchId: kMatchId,
            tipo: TipoDeSinal.mesmaDuplaRecorrente,
            alvos: alvos,
            observadoEm: depois,
            origem: 'd',
            observacao: 'o',
          );
      expect(com(['uid-b', 'uid-a']).chaveIdempotencia,
          com(['uid-a', 'uid-b']).chaveIdempotencia);
    });

    test('AFR-08 o sinal sobrevive ao round-trip JSON', () {
      final lido = SinalAntifraude.deJson(sinalDeExemplo().toJson());
      expect(lido.toJson(), sinalDeExemplo().toJson());
      expect(lido.tipo, TipoDeSinal.abandonoAoPerder);
    });
  });

  group('OBS — observadores (§16)', () {
    test('OBS-01 robô em partida que pontua vira sinal; em partida de robôs, '
        'não', () {
      final ranqueadaComRobo = registroRanqueado(assentos: doisHumanosDoisRobos())
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());

      final sinal = observarRoboEmPartidaPontuada(
          registro: ranqueadaComRobo, observadoEm: depois);
      expect(sinal, isNotNull);
      expect(sinal!.tipo, TipoDeSinal.roboEmPartidaPontuada);
      expect(sinal.alvos, ['uid-a', 'uid-b'],
          reason: 'os alvos são os humanos; o robô não tem conta');
      expect(sinal.evidencia['robos'], 2);

      // Mesma composição, mas numa modalidade em que robô é esperado.
      final contraRobos = RegistroDePartida.abrir(
        identidade: IdentidadePartida.cunhada(
          matchId: kOutroMatchId,
          tipo: TipoDePartida.contraRobos,
          origem: OrigemDaIdentidade.servidor,
          modalidade: 'ABERTO',
          criadaEm: agora,
        ),
        participantes: doisHumanosDoisRobos().values.toList(),
        metaPontos: 1500,
      )
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal(matchId: kOutroMatchId));
      expect(
          observarRoboEmPartidaPontuada(
              registro: contraRobos, observadoEm: depois),
          isNull);
    });

    test('OBS-02 partida ranqueada só de humanos não gera sinal', () {
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());
      expect(observarRoboEmPartidaPontuada(registro: r, observadoEm: depois),
          isNull);
    });

    test('OBS-03 dupla recorrente: abaixo do limiar ou da amostra, não há '
        'sinal', () {
      SinalAntifraude? observar(int juntos, int totais) =>
          observarMesmaDuplaRecorrente(
            matchId: kMatchId,
            userA: 'uid-a',
            userB: 'uid-b',
            partidasJuntos: juntos,
            partidasTotais: totais,
            observadoEm: depois,
          );

      expect(observar(8, 9), isNull, reason: 'amostra menor que o mínimo');
      expect(observar(5, 20), isNull, reason: 'proporção abaixo do limiar');
      expect(observar(0, 40), isNull);

      final forte = observar(38, 40);
      expect(forte, isNotNull);
      expect(forte!.intensidade, IntensidadeSinal.alta);
      expect(forte.evidencia['partidasJuntos'], 38);
      expect(forte.alvos, ['uid-a', 'uid-b']);

      final media = observar(31, 40);
      expect(media!.intensidade, IntensidadeSinal.media);
    });

    test('OBS-04 a intensidade descreve a observação, não a culpa', () {
      // Uma proporção altíssima ainda é apenas "alta": não existe grau que
      // signifique "confirmado".
      final s = observarMesmaDuplaRecorrente(
        matchId: kMatchId,
        userA: 'uid-a',
        userB: 'uid-b',
        partidasJuntos: 100,
        partidasTotais: 100,
        observadoEm: depois,
      );
      expect(s!.intensidade, IntensidadeSinal.alta);
      expect(IntensidadeSinal.values.length, 3,
          reason: 'não há um quarto grau de "culpado"');
    });

    test('OBS-05 recusa que sugere manipulação vira sinal; falha benigna não',
        () {
      for (final recusa in RecusaIngestao.values) {
        final sinal = sinalDeRecusa(
          recusa: recusa,
          matchId: kMatchId,
          userId: 'uid-a',
          emServidor: depois,
        );
        if (recusa.sugereManipulacao) {
          expect(sinal, isNotNull, reason: '${recusa.wire} deveria sinalizar');
          expect(sinal!.tipo, TipoDeSinal.manipulacaoDeEventoTentada);
          expect(sinal.evidencia['recusa'], recusa.wire);
        } else {
          expect(sinal, isNull,
              reason: '${recusa.wire} pode ser app desatualizado');
        }
      }
    });

    test('OBS-06 não autenticado e campo faltando NÃO viram suspeita', () {
      expect(RecusaIngestao.naoAutenticado.sugereManipulacao, isFalse);
      expect(RecusaIngestao.campoInvalido.sugereManipulacao, isFalse);
      expect(RecusaIngestao.jaIngerido.sugereManipulacao, isFalse);
      expect(RecusaIngestao.partidaInexistente.sugereManipulacao, isFalse);
    });

    test('OBS-07 a ingestão anexa os sinais ao plano, sem punir ninguém', () {
      final plano = ingerirEncerramento(
        desfecho: desfechoNormal(),
        registroAtual: registroRanqueado(assentos: doisHumanosDoisRobos())
            .transicionarPara(EstadoDaPartida.ativa),
        chamador: servidor,
        emServidor: depois,
      );
      expect(plano.sinais.length, 1);
      expect(plano.sinais.single.tipo, TipoDeSinal.roboEmPartidaPontuada);
      // O registro segue normal: nada foi bloqueado, ninguém foi marcado.
      expect(plano.registro.estado, EstadoDaPartida.finalizada);
      expect(plano.registro.toJson().containsKey('suspeito'), isFalse);
    });
  });

  group('VIS — sinais na consulta administrativa (§14, §35)', () {
    test('VIS-01 só o administrador vê sinais', () {
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());
      final sinais = [sinalDeExemplo()];

      final suporte = montarVisaoAdministrativa(
        autenticado: true,
        nivel: NivelAcesso.suporte,
        registro: r,
        sinais: sinais,
      );
      expect(suporte.sinais, isEmpty);

      final admin = montarVisaoAdministrativa(
        autenticado: true,
        nivel: NivelAcesso.administrador,
        registro: r,
        sinais: sinais,
      );
      expect(admin.sinais.single.matchId, kMatchId);
    });

    test('VIS-02 os sinais de uma partida são recuperáveis pelo matchId', () {
      final registro = RegistroDeSinais()
        ..registrar(sinalDeExemplo())
        ..registrar(sinalDeExemplo(matchId: kOutroMatchId));
      expect(registro.porMatchId(kMatchId).length, 1);
      expect(registro.porMatchId(kMatchId).single.matchId, kMatchId);
    });
  });
}
