// primeira_batida_real_test.dart — a regra de elegibilidade da conquista.
//
// Cobre a lista da OS §13 "Elegibilidade", um teste por afirmação, mais as
// incoerências de envelope que a decisão precisa recusar em vez de contornar.
//
// A idempotência NÃO é testada aqui, e isso é de propósito: ela não é regra de
// elegibilidade, é propriedade da gravação, e está provada onde a gravação mora
// (`firebase/testes/conquistas.test.js`, contra o emulador).

import 'package:flutter_test/flutter_test.dart';

import '../../lib/conquistas/primeira_batida_real.dart';

/// Mesa padrão: nós = assentos 0 e 2, eles = 1 e 3.
const _assentosPadrao = {
  'nos': [0, 2],
  'eles': [1, 3],
};

/// Quatro humanos autenticados, um por assento.
List<ParticipanteNoEncerramento> _quatroHumanos() => const [
      ParticipanteNoEncerramento(classe: 'humano', userId: 'uid-0', assento: 0),
      ParticipanteNoEncerramento(classe: 'humano', userId: 'uid-1', assento: 1),
      ParticipanteNoEncerramento(classe: 'humano', userId: 'uid-2', assento: 2),
      ParticipanteNoEncerramento(classe: 'humano', userId: 'uid-3', assento: 3),
    ];

/// Encerramento válido por padrão; cada teste estraga UM fato de cada vez.
FatosDoEncerramento _fatos({
  String estado = 'finalizada',
  String? motivo = 'meta_atingida',
  String origem = 'servidor',
  String tipo = 'publica_ranqueada',
  String? ladoVencedor = 'nos',
  int? assentoQueBateu = 0,
  Map<String, List<int>> assentos = _assentosPadrao,
  List<ParticipanteNoEncerramento>? participantes,
}) =>
    FatosDoEncerramento(
      estado: estado,
      motivoEncerramento: motivo,
      origemIdentidade: origem,
      tipo: tipo,
      ladoVencedor: ladoVencedor,
      assentoQueBateuFinal: assentoQueBateu,
      assentosPorLado: assentos,
      participantes: participantes ?? _quatroHumanos(),
    );

void main() {
  group('concede', () {
    test('1. batida final válida + dupla vencedora → concede ao executor', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(assentoQueBateu: 0));
      expect(v.elegivel, isTrue);
      expect(v.userId, 'uid-0');
      expect(v.assento, 0);
      expect(v.motivo, isNull);
    });

    test('concede ao assento 2 quando foi ele quem bateu, e não ao 0', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(assentoQueBateu: 2));
      expect(v.userId, 'uid-2');
    });

    test('vale nos quatro tipos que contam', () {
      for (final tipo in tiposQueContamParaConquista) {
        final v = avaliarPrimeiraBatidaReal(_fatos(tipo: tipo));
        expect(v.elegivel, isTrue, reason: 'tipo $tipo deveria contar');
      }
    });

    test('origem torneio também é autoridade', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(origem: 'torneio'));
      expect(v.userId, 'uid-0');
    });
  });

  group('não concede', () {
    test('2. o PARCEIRO vencedor que não bateu não recebe', () {
      // O assento 2 é da mesma dupla vencedora e tem `uid-2`. O veredito é um
      // só, e é o do assento que bateu.
      final v = avaliarPrimeiraBatidaReal(_fatos(assentoQueBateu: 0));
      expect(v.userId, 'uid-0');
      expect(v.userId, isNot('uid-2'));
    });

    test('3. bateu mas a dupla dele perdeu', () {
      final v = avaliarPrimeiraBatidaReal(
          _fatos(ladoVencedor: 'nos', assentoQueBateu: 1));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.batidaDoLadoPerdedor);
    });

    test('4. a dupla venceu, mas o envelope não atribui batida a ninguém', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(assentoQueBateu: null));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.semBatidaFinalConhecida);
    });

    test('5. batida que encerrou apenas uma rodada, com a partida ainda viva',
        () {
      // Rodada intermediária: o registro nunca chega a `finalizada`.
      final v = avaliarPrimeiraBatidaReal(_fatos(estado: 'ativa', motivo: null));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.partidaNaoFinalizada);
    });

    test('6. abandono não concede, mesmo com batida e vencedor declarados', () {
      final v = avaliarPrimeiraBatidaReal(
          _fatos(estado: 'abandonada', motivo: 'abandono'));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.partidaNaoFinalizada);
    });

    test('7. cancelamento/anulação não concede', () {
      final v = avaliarPrimeiraBatidaReal(
          _fatos(estado: 'cancelada', motivo: 'anulada', ladoVencedor: null));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.partidaNaoFinalizada);
    });

    test('8. WO / encerrada por admin não concede', () {
      // O estado é `finalizada` — este é o caso que passaria batido se a regra
      // olhasse só o estado.
      final v = avaliarPrimeiraBatidaReal(
          _fatos(estado: 'finalizada', motivo: 'encerrada_por_admin'));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.encerramentoNaoNatural);
    });

    test('9. empate (sem lado vencedor) não concede', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(ladoVencedor: null));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.semVencedor);
    });

    test('10. partida inválida: identidade cunhada localmente', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(origem: 'local'));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.partidaNaoAutoritativa);
    });

    test('11. treino/tutorial não concede', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(tipo: 'treinamento'));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.tipoNaoConta);
    });

    test('11b. mesa contra robôs não concede nem para o humano que bateu', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(tipo: 'contra_robos'));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.tipoNaoConta);
    });

    test('11c. tipo desconhecido não entra sozinho na lista', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(tipo: 'modo_novo_de_amanha'));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.tipoNaoConta);
    });

    test('12. robô executor não recebe', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(
        assentoQueBateu: 0,
        participantes: const [
          ParticipanteNoEncerramento(classe: 'robo', assento: 0),
          ParticipanteNoEncerramento(
              classe: 'humano', userId: 'uid-2', assento: 2),
        ],
      ));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.executorNaoHumano);
    });

    test('12b. um humano na mesa NÃO herda a conquista do robô que bateu', () {
      // A mesa tem humano vencedor (assento 2), mas quem bateu foi o robô.
      final v = avaliarPrimeiraBatidaReal(_fatos(
        assentoQueBateu: 0,
        participantes: const [
          ParticipanteNoEncerramento(classe: 'robo', assento: 0),
          ParticipanteNoEncerramento(
              classe: 'humano', userId: 'uid-2', assento: 2),
        ],
      ));
      expect(v.userId, isNull);
    });

    test('13. convidado sem conta não recebe', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(
        participantes: const [
          ParticipanteNoEncerramento(classe: 'convidado', assento: 0),
        ],
      ));
      expect(v.motivo, MotivoInelegibilidade.executorNaoHumano);
    });

    test('13b. humano sem userId não tem onde receber', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(
        participantes: const [
          ParticipanteNoEncerramento(classe: 'humano', assento: 0),
        ],
      ));
      expect(v.motivo, MotivoInelegibilidade.executorSemIdentidade);
    });

    test('13c. humano com userId vazio também não', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(
        participantes: const [
          ParticipanteNoEncerramento(classe: 'humano', userId: '', assento: 0),
        ],
      ));
      expect(v.motivo, MotivoInelegibilidade.executorSemIdentidade);
    });
  });

  group('14. envelope alterado ou incompleto — recusa sem conceder', () {
    test('assento que bateu não corresponde a competidor nenhum', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(
        assentoQueBateu: 2,
        participantes: const [
          ParticipanteNoEncerramento(
              classe: 'humano', userId: 'uid-0', assento: 0),
        ],
      ));
      expect(v.motivo, MotivoInelegibilidade.assentoSemParticipante);
    });

    test('dois participantes no mesmo assento não deixam escolher', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(
        assentoQueBateu: 0,
        participantes: const [
          ParticipanteNoEncerramento(
              classe: 'humano', userId: 'uid-a', assento: 0),
          ParticipanteNoEncerramento(
              classe: 'humano', userId: 'uid-b', assento: 0),
        ],
      ));
      expect(v.motivo, MotivoInelegibilidade.envelopeIncoerente);
      expect(v.userId, isNull);
    });

    test('lado vencedor que não existe no placar', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(ladoVencedor: 'ninguem'));
      expect(v.motivo, MotivoInelegibilidade.envelopeIncoerente);
    });

    test('placar sem assentos declarados', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(assentos: const {'nos': []}));
      expect(v.motivo, MotivoInelegibilidade.envelopeIncoerente);
    });

    test('espectador não é confundido com o ocupante do assento', () {
      // Espectador chega com assento nulo e não pode casar com assento 0.
      final v = avaliarPrimeiraBatidaReal(_fatos(
        assentoQueBateu: 0,
        participantes: const [
          ParticipanteNoEncerramento(classe: 'espectador', userId: 'uid-x'),
        ],
      ));
      expect(v.motivo, MotivoInelegibilidade.assentoSemParticipante);
    });
  });

  group('leitura do registro (fail-closed em ausência)', () {
    Map<String, Object?> registroBase() => {
          'estado': 'finalizada',
          'tipo': 'publica_ranqueada',
          'motivoEncerramento': 'meta_atingida',
          'ladoVencedor': 'nos',
          'assentoQueBateuFinal': 0,
          'identidade': {'origem': 'servidor', 'tipo': 'publica_ranqueada'},
          'placar': [
            {'lado': 'nos', 'assentos': [0, 2]},
            {'lado': 'eles', 'assentos': [1, 3]},
          ],
          'participantes': [
            {'classe': 'humano', 'userId': 'uid-0', 'assento': 0},
          ],
        };

    test('registro completo concede', () {
      final v = avaliarPrimeiraBatidaReal(
          FatosDoEncerramento.doRegistroJson(registroBase()));
      expect(v.userId, 'uid-0');
    });

    test('registro SEM o campo de assento recusa — não assume assento 0', () {
      // É o registro de um produtor antigo, gravado antes do campo existir.
      final cru = registroBase()..remove('assentoQueBateuFinal');
      final v =
          avaliarPrimeiraBatidaReal(FatosDoEncerramento.doRegistroJson(cru));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.semBatidaFinalConhecida);
    });

    test('assento 0 explícito é assento real, e não "ausente"', () {
      final v = avaliarPrimeiraBatidaReal(FatosDoEncerramento.doRegistroJson(
          registroBase()..['assentoQueBateuFinal'] = 0));
      expect(v.userId, 'uid-0');
    });

    test('assento em texto é envelope corrompido, não conversão silenciosa', () {
      expect(
        () => FatosDoEncerramento.doRegistroJson(
            registroBase()..['assentoQueBateuFinal'] = '0'),
        throwsA(isA<FormatException>()),
      );
    });

    test('registro sem identidade não vira partida sem origem', () {
      expect(
        () => FatosDoEncerramento.doRegistroJson(
            registroBase()..remove('identidade')),
        throwsA(isA<FormatException>()),
      );
    });

    test('registro sem participantes recusa', () {
      expect(
        () => FatosDoEncerramento.doRegistroJson(
            registroBase()..remove('participantes')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('contrato publicado', () {
    test('o identificador é o texto canônico', () {
      expect(conquistaPrimeiraBatidaReal, 'primeira_batida_real');
    });

    test('o veredito de concessão publica id, versão e origem', () {
      final v = avaliarPrimeiraBatidaReal(_fatos());
      final json = v.toJson();
      expect(json['elegivel'], isTrue);
      expect(json['userId'], 'uid-0');
      expect(json['conquistaId'], 'primeira_batida_real');
      expect(json['versaoContrato'], 1);
      expect(json['origem'], 'encerramento_autoritativo_v1');
      expect(json['motivo'], isNull);
    });

    test('a recusa publica o motivo em wire estável', () {
      final v = avaliarPrimeiraBatidaReal(_fatos(ladoVencedor: null));
      expect(v.toJson()['motivo'], 'sem_vencedor');
      expect(MotivoInelegibilidade.porWire('sem_vencedor'),
          MotivoInelegibilidade.semVencedor);
    });

    test('todo motivo tem wire único', () {
      final wires = MotivoInelegibilidade.values.map((m) => m.wire).toSet();
      expect(wires.length, MotivoInelegibilidade.values.length);
    });
  });
}
