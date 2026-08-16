// seguranca_test.dart — §34 da OS: TESTES OBRIGATÓRIOS — SEGURANÇA.
// Cobre também §25 (validação server-side) e §26 (anti-tampering).
//
//   * cliente não altera resultado;
//   * cliente não altera ranking;
//   * cliente não cria histórico competitivo falso;
//   * cliente não apaga partida;
//   * cliente não consulta histórico administrativo alheio;
//   * UID adulterado é rejeitado;
//   * matchId inexistente retorna erro seguro;
//   * usuário não autenticado falha quando necessário.
//
// A metade que vive nas Firestore Rules (apagar documento, escrever direto na
// coleção) é provada em `firebase/testes/rastreabilidade.test.js`, contra o
// emulador. Aqui prova-se a metade que vive no domínio.

import 'package:buraco_master_vip/rastreabilidade/eventos_auditaveis.dart';
import 'package:buraco_master_vip/rastreabilidade/historico_e_consulta.dart';
import 'package:buraco_master_vip/rastreabilidade/identidade_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/ingestao.dart';
import 'package:buraco_master_vip/rastreabilidade/ledger_competitivo.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ferramentas.dart';

Map<String, Object?> envelopeValido({String matchId = kMatchId}) => {
      'matchId': matchId,
      'desfecho': desfechoNormal(matchId: matchId).toJson(),
    };

void main() {
  group('SEG — autenticação e autoridade (§25)', () {
    test('SEG-01 usuário não autenticado é recusado', () {
      expect(
        () => validarEnvelope(envelopeValido(), chamador: anonimo),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.naoAutenticado)),
      );
    });

    test('SEG-02 jogador autenticado NÃO tem autoridade para encerrar partida',
        () {
      expect(jogadorComum.temAutoridade, isFalse);
      expect(
        () => validarEnvelope(envelopeValido(), chamador: jogadorComum),
        throwsA(predicate((e) =>
            e is IngestaoRecusada && e.recusa == RecusaIngestao.semAutoridade)),
      );
      expect(
        () => ingerirEncerramento(
          desfecho: desfechoNormal(),
          registroAtual:
              registroRanqueado().transicionarPara(EstadoDaPartida.ativa),
          chamador: jogadorComum,
          emServidor: depois,
        ),
        throwsA(predicate((e) =>
            e is IngestaoRecusada && e.recusa == RecusaIngestao.semAutoridade)),
      );
    });

    test('SEG-03 só os papéis declarados têm autoridade', () {
      expect(ChamadorAutorizado.papeisDeAutoridade, {'motorDePartidas', 'admin'});
      for (final papel in ['jogador', 'suporte', 'vip', '', 'Admin']) {
        expect(
          ChamadorAutorizado(autenticado: true, papel: papel, id: 'x')
              .temAutoridade,
          isFalse,
          reason: 'o papel "$papel" não pode encerrar partida',
        );
      }
      expect(servidor.temAutoridade, isTrue);
    });
  });

  group('VAL — validação do envelope (§25, §26)', () {
    test('VAL-01 campo desconhecido é RECUSA, não é ignorado', () {
      expect(
        () => validarEnvelope(
            {...envelopeValido(), 'vencedorId': 'uid-a'}, chamador: servidor),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.campoDesconhecido)),
      );
      expect(
        () => validarEnvelope({...envelopeValido(), 'rankingDelta': 9999},
            chamador: servidor),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.campoDesconhecido)),
      );
    });

    test('VAL-02 envelope sem matchId ou sem desfecho é recusado', () {
      expect(
        () => validarEnvelope({'desfecho': desfechoNormal().toJson()},
            chamador: servidor),
        throwsA(predicate(
            (e) => e is IngestaoRecusada && e.recusa == RecusaIngestao.campoInvalido)),
      );
      expect(
        () => validarEnvelope({'matchId': kMatchId}, chamador: servidor),
        throwsA(predicate(
            (e) => e is IngestaoRecusada && e.recusa == RecusaIngestao.campoInvalido)),
      );
      expect(
        () => validarEnvelope('não sou objeto', chamador: servidor),
        throwsA(predicate(
            (e) => e is IngestaoRecusada && e.recusa == RecusaIngestao.campoInvalido)),
      );
    });

    test('VAL-03 matchId do envelope diferente do desfecho é recusado — '
        'resultado de uma partida não se aplica a outra', () {
      expect(
        () => validarEnvelope({
          'matchId': kOutroMatchId,
          'desfecho': desfechoNormal(matchId: kMatchId).toJson(),
        }, chamador: servidor),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.matchIdDivergente)),
      );
    });

    test('VAL-04 desfecho malformado é recusado, não completado', () {
      final bom = desfechoNormal().toJson();
      for (final chave in [
        'estado',
        'lados',
        'versaoEstado',
        'impressaoEstado',
        'modalidade',
      ]) {
        final ruim = {...bom}..remove(chave);
        expect(
          () => validarEnvelope({'matchId': kMatchId, 'desfecho': ruim},
              chamador: servidor),
          throwsA(isA<IngestaoRecusada>()),
          reason: 'desfecho sem "$chave" não pode virar resultado',
        );
      }
    });

    test('VAL-05 o envelope válido atravessa e devolve o desfecho canônico', () {
      final desfecho = validarEnvelope(envelopeValido(), chamador: servidor);
      expect(desfecho.partidaId, kMatchId);
      expect(desfecho.conclusivo, isTrue);
      expect(desfecho.ladoVencedor, 'nos');
    });
  });

  group('TAM — anti-tampering (§26)', () {
    test('TAM-01 o cliente não escolhe o vencedor: um desfecho forjado com '
        'vencedor inconsistente é recusado', () {
      final forjado = desfechoNormal().toJson();
      // "eles" não é o lado vencedor coerente com um desfecho por meta cujo
      // placar é 1520x1180, mas a recusa é ainda mais cedo: o construtor
      // canônico exige que o lado exista e o de meta é decidido pelo motor.
      forjado['ladoVencedor'] = 'ninguem';
      expect(
        () => validarEnvelope(
            {'matchId': kMatchId, 'desfecho': forjado}, chamador: servidor),
        throwsA(isA<IngestaoRecusada>()),
      );
    });

    test('TAM-02 o cliente não troca o matchId para escrever em partida alheia',
        () {
      final registroDeOutro = registroRanqueado(matchId: kOutroMatchId)
          .transicionarPara(EstadoDaPartida.ativa);
      expect(
        () => ingerirEncerramento(
          desfecho: desfechoNormal(matchId: kMatchId),
          registroAtual: registroDeOutro,
          chamador: servidor,
          emServidor: depois,
        ),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.matchIdDivergente)),
      );
    });

    test('TAM-03 um desfecho que põe o assento no lado errado é recusado', () {
      // Monta um registro em que o assento 1 é `eles` (lei de Jogo) e força um
      // desfecho que o coloca em `nos`.
      final registro =
          registroRanqueado().transicionarPara(EstadoDaPartida.ativa);
      final adulterado = desfechoNormal().toJson();
      (adulterado['lados'] as List)[0] = {
        'lado': 'nos',
        'assentos': [0, 1], // 1 é "eles"
        'pontos': 1520,
        'canastrasLimpas': 0,
      };
      final desfecho = validarEnvelope(
          {'matchId': kMatchId, 'desfecho': adulterado}, chamador: servidor);

      expect(
        () => ingerirEncerramento(
          desfecho: desfecho,
          registroAtual: registro,
          chamador: servidor,
          emServidor: depois,
        ),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.estadoDivergente)),
      );
    });

    test('TAM-04 o cliente não reaplica um resultado antigo numa partida nova',
        () {
      final nova = registroRanqueado(matchId: 'match-nova-0001')
          .transicionarPara(EstadoDaPartida.ativa);
      expect(
        () => ingerirEncerramento(
          desfecho: desfechoNormal(matchId: kMatchId),
          registroAtual: nova,
          chamador: servidor,
          emServidor: depois,
        ),
        throwsA(predicate((e) =>
            e is IngestaoRecusada &&
            e.recusa == RecusaIngestao.matchIdDivergente)),
      );
    });

    test('TAM-05 o cliente não altera o tipo da partida depois de criada', () {
      final r = registroRanqueado();
      // Não existe setter nem método que mude o tipo. A prova é a ausência —
      // o que se pode afirmar é que o tipo sobrevive a toda a vida do registro.
      final encerrado =
          r.transicionarPara(EstadoDaPartida.ativa).encerrarCom(desfechoNormal());
      expect(encerrado.tipo, r.tipo);
      expect(encerrado.identidade, r.identidade);

      // E um registro persistido com tipo trocado à mão volta com o tipo
      // gravado, sem virar outra coisa: a fraude teria de passar pelas Rules,
      // que negam escrita do cliente (ver rastreabilidade.test.js).
      final json = encerrado.toJson();
      (json['identidade'] as Map)['tipo'] = 'publica_casual';
      expect(RegistroDePartida.deJson(json).tipo, TipoDePartida.publicaCasual,
          reason: 'o domínio lê o que está gravado; quem impede a gravação são '
              'as Rules e o backend');
    });

    test('TAM-06 não existe caminho no domínio que apague uma partida', () {
      final indice = IndicePartidas();
      indice.gravar(registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal()));
      expect(indice.tamanho, 1);
      // `IndicePartidas` expõe gravar/consultar. Não há remover.
      expect(indice.porMatchId(kMatchId), isNotNull);
    });
  });

  group('ACS — acesso à consulta administrativa (§14, §34)', () {
    RegistroDePartida encerrado() => registroRanqueado()
        .transicionarPara(EstadoDaPartida.ativa)
        .encerrarCom(desfechoNormal());

    test('ACS-01 jogador comum NÃO ganha acesso administrativo por conhecer o '
        'matchId', () {
      expect(
        () => montarVisaoAdministrativa(
          autenticado: true,
          nivel: NivelAcesso.jogador,
          registro: encerrado(),
        ),
        throwsA(predicate((e) =>
            e is ConsultaNegada && e.recusa == RecusaConsulta.semPermissao)),
      );
    });

    test('ACS-02 nem o participante da partida vê a visão administrativa dela',
        () {
      // `uid-a` competiu. Ainda assim, o caminho administrativo é negado — o
      // dele é `projetarParaJogador`.
      expect(
        () => montarVisaoAdministrativa(
          autenticado: true,
          nivel: NivelAcesso.jogador,
          registro: encerrado(),
        ),
        throwsA(isA<ConsultaNegada>()),
      );
      expect(
          projetarParaJogador(registro: encerrado(), userId: 'uid-a').matchId,
          kMatchId);
    });

    test('ACS-03 não autenticado é recusado antes de qualquer leitura', () {
      expect(
        () => montarVisaoAdministrativa(
          autenticado: false,
          nivel: NivelAcesso.administrador,
          registro: encerrado(),
        ),
        throwsA(predicate((e) =>
            e is ConsultaNegada && e.recusa == RecusaConsulta.naoAutenticado)),
      );
    });

    test('ACS-04 matchId inexistente devolve erro seguro, sem vazar nada', () {
      expect(
        () => montarVisaoAdministrativa(
          autenticado: true,
          nivel: NivelAcesso.administrador,
          registro: null,
        ),
        throwsA(predicate((e) =>
            e is ConsultaNegada &&
            e.recusa == RecusaConsulta.partidaInexistente)),
      );
    });

    test('ACS-05 o suporte vê eventos, mas não sinais nem ledger de terceiros',
        () {
      final visao = montarVisaoAdministrativa(
        autenticado: true,
        nivel: NivelAcesso.suporte,
        registro: encerrado(),
        eventos: EventoAuditavel.doDesfecho(
          desfechoNormal(),
          identidade: identidadeRanqueada(),
          emServidor: depois,
        ),
        lancamentos: [
          LancamentoCompetitivo(
              matchId: kMatchId,
              userId: 'uid-a',
              motivo: MotivoLancamento.resultadoDePartida,
              antes: 0,
              delta: 10,
              depois: 10,
              registradoEm: depois,
              politica: politicaDeTeste),
        ],
        sinais: const [],
      );
      expect(visao.lancamentos, isEmpty,
          reason: 'ledger de terceiros é do administrador');
      expect(visao.sinais, isEmpty);
      expect(visao.nivel.veEventos, isTrue);
      expect(visao.eventos, isNotEmpty);
    });

    test('ACS-06 o administrador vê o conjunto completo', () {
      final lancamento = LancamentoCompetitivo(
          matchId: kMatchId,
          userId: 'uid-a',
          motivo: MotivoLancamento.resultadoDePartida,
          antes: 0,
          delta: 10,
          depois: 10,
          registradoEm: depois,
          politica: politicaDeTeste);
      final visao = montarVisaoAdministrativa(
        autenticado: true,
        nivel: NivelAcesso.administrador,
        registro: encerrado(),
        lancamentos: [lancamento],
      );
      expect(visao.lancamentos.single.chaveIdempotencia,
          lancamento.chaveIdempotencia);
      expect(visao.matchId, kMatchId);
      expect(visao.registro.impressaoEstado, isNotNull);
    });
  });

  group('UID — identidade de usuário adulterada (§34)', () {
    test('UID-01 o histórico é projetado pelo UID do registro, nunca por um '
        'UID enviado junto', () {
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());
      // Um UID que não está no registro não produz histórico, mesmo bem
      // formado — não há caminho por onde "pedir o histórico como outra pessoa"
      // devolva dado.
      expect(() => projetarParaJogador(registro: r, userId: 'uid-forjado'),
          throwsA(isA<HistoricoIndisponivel>()));
    });

    test('UID-02 um lançamento não pode ser projetado no histórico de outro '
        'jogador', () {
      final r = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());
      final deB = LancamentoCompetitivo(
          matchId: kMatchId,
          userId: 'uid-b',
          motivo: MotivoLancamento.resultadoDePartida,
          antes: 0,
          delta: 50,
          depois: 50,
          registradoEm: depois,
          politica: politicaDeTeste);

      expect(
        () => projetarParaJogador(
            registro: r, userId: 'uid-a', lancamento: deB),
        throwsA(isA<HistoricoIndisponivel>()),
      );
    });

    test('UID-03 o ledger de um jogador não aceita lançamento de outro', () {
      final deB = LancamentoCompetitivo(
          matchId: kMatchId,
          userId: 'uid-b',
          motivo: MotivoLancamento.resultadoDePartida,
          antes: 0,
          delta: 50,
          depois: 50,
          registradoEm: depois,
          politica: politicaDeTeste);
      expect(() => LedgerCompetitivo.reconstruir('uid-a', [deB]),
          throwsA(isA<ArgumentError>()));
    });
  });
}
