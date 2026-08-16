// identidade_test.dart — §29 da OS: TESTES OBRIGATÓRIOS — IDENTIDADE.
//
// Cobre, um caso por exigência da seção:
//   * partida recebe matchId único;
//   * reconnect mantém matchId;
//   * duas partidas recebem IDs diferentes;
//   * cliente não escolhe matchId privilegiado;
//   * matchId permanece após mudança de rodada;
//   * participante não consegue trocar identidade.

import 'package:buraco_master_vip/integracao/registro_partidas.dart';
import 'package:buraco_master_vip/integracao/vinculo_mesa.dart';
import 'package:buraco_master_vip/rastreabilidade/identidade_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/ponte_integracao.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ferramentas.dart';

void main() {
  group('ID — identidade única da partida', () {
    test('ID-01 a partida recebe matchId único e imutável', () {
      final r = registroRanqueado();
      expect(r.matchId, kMatchId);
      expect(r.identidade.matchId, kMatchId);
      // Imutável por ausência de setter: o registro só muda por métodos que
      // devolvem cópia, e nenhum deles aceita matchId.
      final encerrado = r
          .transicionarPara(EstadoDaPartida.ativa)
          .encerrarCom(desfechoNormal());
      expect(encerrado.matchId, kMatchId);
    });

    test('ID-02 duas partidas recebem identidades diferentes', () {
      final a = registroRanqueado(matchId: kMatchId);
      final b = registroRanqueado(matchId: kOutroMatchId);
      expect(a.matchId, isNot(b.matchId));
      expect(a.identidade, isNot(b.identidade));
    });

    test('ID-03 reabrir a mesma mesa devolve a MESMA partida — reconexão não '
        'cria segunda identidade', () {
      // Este é o comportamento que já existia em RegistroDePartidasEmMemoria e
      // que a rastreabilidade ADOTA em vez de recriar. O teste está aqui para
      // que uma mudança lá quebre aqui também.
      final registro = RegistroDePartidasEmMemoria();
      final vinculo = vinculoDeDupla();
      final abertura = AberturaDePartida(
        partidaId: kMatchId,
        modalidade: 'ABERTO',
        metaPontos: 1500,
        vinculo: vinculo,
      );
      final primeiro = registro.abrir(abertura);
      final segundo = registro.abrir(abertura);

      expect(identical(primeiro, segundo), isTrue);
      expect(registro.abertas, 1);
      expect(matchIdDaAbertura(abertura), kMatchId);
      expect(matchIdDoMotor(segundo), kMatchId);
    });

    test('ID-04 o cliente não escolhe matchId — a porta sempre recusa', () {
      expect(() => IdentidadePartida.doCliente('match-qualquer'),
          throwsA(isA<IdentidadeInvalida>()));
      expect(() => IdentidadePartida.doCliente(null),
          throwsA(isA<IdentidadeInvalida>()));
    });

    test('ID-05 prefixo privilegiado é recusado', () {
      for (final reservado in IdentidadePartida.prefixosReservados) {
        expect(
          () => IdentidadePartida.cunhada(
            matchId: '${reservado}minha-partida',
            tipo: TipoDePartida.publicaCasual,
            origem: OrigemDaIdentidade.servidor,
            modalidade: 'ABERTO',
            criadaEm: agora,
          ),
          throwsA(isA<IdentidadeInvalida>()),
          reason: 'o prefixo "$reservado" deveria ser recusado',
        );
      }
    });

    test('ID-06 formato inválido é recusado — curto, maiúsculo, com e-mail, '
        'com espaço', () {
      for (final ruim in [
        'm1', // curto demais
        'MATCH-ABC-123', // maiúsculas
        'alice@exemplo.com-partida', // dado sensível embutido
        'match/f1/mesa1', // caminho
        ' match-f1-mesa-1', // espaço na borda
        '_match-f1-mesa', // não começa por letra/dígito
        'x' * 65, // longo demais
      ]) {
        expect(
          () => IdentidadePartida.cunhada(
            matchId: ruim,
            tipo: TipoDePartida.publicaCasual,
            origem: OrigemDaIdentidade.servidor,
            modalidade: 'ABERTO',
            criadaEm: agora,
          ),
          throwsA(isA<IdentidadeInvalida>()),
          reason: 'o id "$ruim" deveria ser recusado',
        );
      }
    });

    test('ID-07 identidade local não pode valer ranking', () {
      expect(
        () => IdentidadePartida.cunhada(
          matchId: 'match-local-0001',
          tipo: TipoDePartida.publicaRanqueada,
          origem: OrigemDaIdentidade.local,
          modalidade: 'ABERTO',
          criadaEm: agora,
        ),
        throwsA(isA<IdentidadeInvalida>()),
      );
      // O caminho legítimo: treino local não pontua e é aceito.
      final treino = IdentidadePartida.cunhada(
        matchId: 'match-local-0001',
        tipo: TipoDePartida.treinamento,
        origem: OrigemDaIdentidade.local,
        modalidade: 'ABERTO',
        criadaEm: agora,
      );
      expect(treino.alteraRanking, isFalse);
    });

    test('ID-08 a identidade sobrevive ao round-trip JSON', () {
      final original = identidadeRanqueada();
      final lida = IdentidadePartida.deJson(original.toJson());
      expect(lida, original);
      expect(lida.matchId, original.matchId);
      expect(lida.tipo, original.tipo);
      expect(lida.origem, original.origem);
    });

    test('ID-09 identidade persistida com tipo desconhecido é recusada', () {
      final json = identidadeRanqueada().toJson();
      json['tipo'] = 'ranqueada_turbo';
      expect(() => IdentidadePartida.deJson(json),
          throwsA(isA<FormatException>()));
    });
  });

  group('ROD — identidade de rodada (§4)', () {
    test('ROD-01 o roundId deriva do matchId e do número da rodada', () {
      final identidade = identidadeRanqueada();
      final r1 = identidade.rodada(1, versaoEstado: 10);
      final r2 = identidade.rodada(2, versaoEstado: 40);

      expect(r1.roundId, '$kMatchId#r1');
      expect(r2.roundId, '$kMatchId#r2');
      expect(r1.matchId, r2.matchId,
          reason: 'mudar de rodada NÃO muda a identidade da partida');
    });

    test('ROD-02 o matchId permanece após mudança de rodada, lido do motor', () {
      final jogo = jogoNovo();
      final motor = motorDe(jogo);
      final identidade = identidadeRanqueada();

      final antes = rodadaCorrente(motor, identidade);
      // `iniciarNovaRodada` é a porta pública do motor para virar a mão.
      expect(motor.iniciarNovaRodada(), isTrue);
      final depoisDaVirada = rodadaCorrente(motor, identidade);

      expect(depoisDaVirada.matchId, antes.matchId);
      expect(depoisDaVirada.matchId, kMatchId);
      expect(depoisDaVirada.numero, greaterThan(antes.numero));
      expect(depoisDaVirada.roundId, isNot(antes.roundId));
    });

    test('ROD-03 o roundId não pode ser confundido com um matchId', () {
      final rodada = identidadeRanqueada().rodada(3, versaoEstado: 1);
      expect(IdentidadePartida.formato.hasMatch(rodada.roundId), isFalse,
          reason: 'o "#" está fora do alfabeto de matchId de propósito');
    });

    test('ROD-04 rodada zero ou negativa é recusada', () {
      final identidade = identidadeRanqueada();
      expect(() => identidade.rodada(0, versaoEstado: 1),
          throwsA(isA<IdentidadeInvalida>()));
      expect(() => identidade.rodada(-1, versaoEstado: 1),
          throwsA(isA<IdentidadeInvalida>()));
    });

    test('ROD-05 rodada de motor de outra partida é recusada', () {
      final motor = motorDe(jogoNovo(), partidaId: kOutroMatchId);
      expect(() => rodadaCorrente(motor, identidadeRanqueada()),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('PART — participante não troca de identidade (§7, §29)', () {
    test('PART-01 robô não pode carregar userId, humano não pode carregar botId',
        () {
      expect(
        () => ParticipantePartida(
            classe: ClasseDeParticipante.robo,
            botId: 'bot-1',
            userId: 'uid-a',
            assento: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ParticipantePartida(
            classe: ClasseDeParticipante.humano,
            userId: 'uid-a',
            botId: 'bot-1',
            assento: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('PART-02 espectador não ocupa assento e não é competidor', () {
      expect(
        () => ParticipantePartida(
            classe: ClasseDeParticipante.espectador,
            userId: 'uid-x',
            assento: 2),
        throwsA(isA<ArgumentError>()),
      );
      final r = registroRanqueado(espectadores: const ['uid-x']);
      expect(r.competidores.length, 4);
      expect(r.espectadores.single.userId, 'uid-x');
      expect(r.userIdsCompetidores, isNot(contains('uid-x')));
    });

    test('PART-03 a mesma conta não pode ocupar dois assentos', () {
      expect(
        () => RegistroDePartida.abrir(
          identidade: identidadeRanqueada(),
          participantes: [
            ParticipantePartida(
                classe: ClasseDeParticipante.humano,
                userId: 'uid-a',
                assento: 0),
            ParticipantePartida(
                classe: ClasseDeParticipante.humano,
                userId: 'uid-a',
                assento: 1),
          ],
          metaPontos: 1500,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('PART-04 dois participantes não podem declarar o mesmo assento', () {
      expect(
        () => RegistroDePartida.abrir(
          identidade: identidadeRanqueada(),
          participantes: [
            ParticipantePartida(
                classe: ClasseDeParticipante.humano,
                userId: 'uid-a',
                assento: 0),
            ParticipantePartida(
                classe: ClasseDeParticipante.robo, botId: 'bot-1', assento: 0),
          ],
          metaPontos: 1500,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('PART-05 o assento de um participante do torneio não pode virar robô',
        () {
      final vinculo = vinculoDeDupla();
      expect(
        () => registroDeTorneio(
          vinculo: vinculo,
          modalidade: 'ABERTO',
          metaPontos: 1500,
          criadaEm: agora,
          // O assento 0 é do participante `uid-a+uid-c`.
          assentosDeRobo: const {0: 'bot-1'},
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('PART-06 o registro de torneio adota o matchId e o vínculo declarado',
        () {
      final vinculo = vinculoDeDupla();
      final r = registroDeTorneio(
        vinculo: vinculo,
        modalidade: 'ABERTO',
        metaPontos: 1500,
        criadaEm: agora,
      );

      expect(r.matchId, kMatchId, reason: 'mesmo namespace, sem tradução');
      expect(r.tipo, TipoDePartida.torneio);
      expect(r.tournamentId, 't1');
      expect(r.competidores.length, 4);
      expect(r.porAssento(0)!.userId, 'uid-a');
      expect(r.porAssento(0)!.participanteId, kParticipanteNos);
      expect(r.porAssento(1)!.participanteId, kParticipanteEles);
      expect(r.ladoDe('uid-a'), 'nos');
      expect(r.ladoDe('uid-b'), 'eles');
    });

    test('PART-07 o vínculo é a fonte do assento, não a ordem da lista', () {
      // Declara os assentos ao contrário do padrão e confere que o registro
      // segue a DECLARAÇÃO, não a posição na lista.
      final invertido = VinculoDeMesa.declarar(
        solicitacao: solicitacaoDeDupla(),
        assentosPorParticipante: {
          kParticipanteNos: {'uid-a': 2, 'uid-c': 0},
          kParticipanteEles: {'uid-b': 3, 'uid-d': 1},
        },
      );
      final r = registroDeTorneio(
        vinculo: invertido,
        modalidade: 'ABERTO',
        metaPontos: 1500,
        criadaEm: agora,
      );
      expect(r.porAssento(2)!.userId, 'uid-a');
      expect(r.porAssento(0)!.userId, 'uid-c');
      // Continuam do mesmo lado: 0 e 2 são ambos `nos`.
      expect(r.ladoDe('uid-a'), 'nos');
      expect(r.ladoDe('uid-c'), 'nos');
    });

    test('PART-08 partida de torneio exige os ids do torneio; partida casual '
        'não pode carregá-los', () {
      expect(
        () => RegistroDePartida.abrir(
          identidade: IdentidadePartida.deTorneio(
              matchId: kMatchId, modalidade: 'ABERTO', criadaEm: agora),
          participantes: quatroHumanos().values.toList(),
          metaPontos: 1500,
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'torneio sem tournamentId não sabe a que competição pertence',
      );
      expect(
        () => registroAvulso(
          identidade: identidadeCasual(),
          assentos: quatroHumanos(),
          metaPontos: 1500,
        ).tournamentId,
        returnsNormally,
      );
    });
  });
}
