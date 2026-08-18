// cadeia_autoritativa_test.dart — a corrente inteira, do motor até o veredito.
//
// O teste de `primeira_batida_real_test.dart` prova a REGRA sobre fatos
// montados à mão. Este prova que os fatos que a regra recebe são de verdade os
// que o motor produz: `Jogo` → `capturarDesfecho` → `RegistroDePartida.
// encerrarCom` → `toJson()` → `FatosDoEncerramento.doRegistroJson` → veredito.
//
// Sem ele, a regra poderia estar perfeita sobre um vocabulário que ninguém
// fala — que é exatamente o defeito que um recorte de campos costuma criar.

import 'package:buraco_master_vip/conquistas/primeira_batida_real.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/desfecho_partida.dart';
import 'package:buraco_master_vip/rastreabilidade/registro_partida.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rastreabilidade/ferramentas.dart';

/// Registro aberto e já encerrado com o desfecho dado.
RegistroDePartida encerrado(DesfechoCanonicoPartida desfecho,
        {Map<int, ParticipantePartida>? assentos}) =>
    registroRanqueado(assentos: assentos)
        .transicionarPara(EstadoDaPartida.ativa, em: agora)
        .encerrarCom(desfecho);

/// O caminho real: registro → JSON → fatos → veredito.
VeredictoPrimeiraBatidaReal vereditoDe(RegistroDePartida registro) =>
    avaliarPrimeiraBatidaReal(
        FatosDoEncerramento.doRegistroJson(registro.toJson()));

void main() {
  group('invariante do motor: o assento só existe se a batida foi legal', () {
    test('BOT joga até bater — o assento vem preenchido e coerente', () {
      // Roda partidas inteiras de robô até uma delas terminar em batida. Não é
      // fixture forçada: é o motor de verdade aprovando a batida pela regra.
      var achou = false;
      for (var tentativa = 0; tentativa < 12 && !achou; tentativa++) {
        final j = jogoNovo();
        for (var i = 0; i < 400 && !j.rodadaEncerrada; i++) {
          j.botJoga(j.vez);
        }
        if (j.duplaQueBateu == null) continue;
        achou = true;

        // 1. quem bateu está identificado por ASSENTO, e não só por dupla;
        expect(j.assentoQueBateu, isNotNull,
            reason: 'rodada terminou por batida sem registrar o assento');
        // 2. o assento pertence à dupla que bateu;
        final ladoDoAssento = j.assentoQueBateu! % 2 == 0 ? 'nos' : 'eles';
        expect(ladoDoAssento, j.duplaQueBateu);
        // 3. e a batida era legal — é a prova de que o campo carrega legalidade.
        expect(j.duplaPodeBater(j.duplaQueBateu!), isTrue);
      }
      expect(achou, isTrue,
          reason: 'nenhuma das 12 partidas de robô terminou em batida');
    });

    test('rodada que acaba sem batida deixa o assento nulo', () {
      final j = jogoNovo();
      // Esvazia monte e mortos: a próxima compra encerra a rodada sem batida.
      j.monte.clear();
      j.mortos.clear();
      j.comprarMonte(j.vez);
      expect(j.rodadaEncerrada, isTrue);
      expect(j.duplaQueBateu, isNull);
      expect(j.assentoQueBateu, isNull);
    });

    test('rodada nova zera o assento da anterior', () {
      // Importa para a conquista: sem esta limpeza, uma batida de rodada
      // intermediária ficaria pendurada no estado e seria lida, no fim da
      // partida, como se tivesse sido a batida final.
      final j = jogoNovo();
      j.duplaQueBateu = 'nos';
      j.assentoQueBateu = 2;
      j.rodadaEncerrada = true;
      expect(motorDe(j).iniciarNovaRodada(), isTrue);
      expect(j.assentoQueBateu, isNull,
          reason: 'o assento da rodada anterior não pode vazar para a nova');
      expect(j.duplaQueBateu, isNull);
    });
  });

  group('a corrente até o veredito', () {
    /// Jogo encerrado por meta, com a batida final atribuída a [assento].
    Jogo jogoEncerradoComBatida(int assento) {
      final j = jogoNovo();
      encerrarJogo(j, nos: 1520, eles: 1180);
      j.duplaQueBateu = assento % 2 == 0 ? 'nos' : 'eles';
      j.assentoQueBateu = assento;
      return j;
    }

    DesfechoCanonicoPartida desfechoComBatida(int assento) => capturarDesfecho(
          motorDe(jogoEncerradoComBatida(assento)),
          encerradaEm: depois,
        );

    test('capturarDesfecho não descarta mais o assento', () {
      expect(desfechoComBatida(2).assentoQueBateuUltimaRodada, 2);
      expect(desfechoComBatida(2).duplaQueBateuUltimaRodada, 'nos');
    });

    test('encerrarCom copia o assento para o registro', () {
      expect(encerrado(desfechoComBatida(0)).assentoQueBateuFinal, 0);
    });

    test('o assento sobrevive à ida e volta de JSON do registro', () {
      final registro = encerrado(desfechoComBatida(2));
      final relido = RegistroDePartida.deJson(registro.toJson());
      expect(relido.assentoQueBateuFinal, 2);
    });

    test('ponta a ponta: quem bateu e venceu recebe', () {
      // `nos` vence (1520 x 1180) e quem bateu foi o assento 0 = uid-a.
      final v = vereditoDe(encerrado(desfechoComBatida(0)));
      expect(v.elegivel, isTrue);
      expect(v.userId, 'uid-a');
      expect(v.assento, 0);
    });

    test('ponta a ponta: o parceiro que não bateu não recebe', () {
      // Assento 2 (uid-c) bateu; o parceiro uid-a venceu igual e não recebe.
      final v = vereditoDe(encerrado(desfechoComBatida(2)));
      expect(v.userId, 'uid-c');
      expect(v.userId, isNot('uid-a'));
    });

    test('ponta a ponta: bateu o lado perdedor → ninguém recebe', () {
      // `nos` vence no placar, mas quem bateu foi o assento 1 (`eles`).
      final v = vereditoDe(encerrado(desfechoComBatida(1)));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.batidaDoLadoPerdedor);
    });

    test('ponta a ponta: robô que bate não recebe', () {
      // Assentos 2 e 3 são robôs; o 2 bate e a dupla `nos` vence.
      final v =
          vereditoDe(encerrado(desfechoComBatida(2), assentos: doisHumanosDoisRobos()));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.executorNaoHumano);
    });

    test('ponta a ponta: partida encerrada sem batida não concede', () {
      // `desfechoNormal` é o fixture já existente: meta atingida, sem batida
      // atribuída. Ele continua válido, e agora chega com assento nulo.
      final desfecho = desfechoNormal();
      expect(desfecho.assentoQueBateuUltimaRodada, isNull);
      final v = vereditoDe(encerrado(desfecho));
      expect(v.motivo, MotivoInelegibilidade.semBatidaFinalConhecida);
    });

    test('ponta a ponta: abandono com batida registrada não concede', () {
      final j = jogoEncerradoComBatida(0);
      final desfecho = capturarDesfecho(
        motorDe(j),
        encerradaEm: depois,
        ordem: OrdemDeEncerramento(
          motivo: MotivoEncerramento.abandono,
          ladoVencedor: 'nos',
          autoridade: 'srv-1',
          declaradaEm: depois,
        ),
      );
      // O assento viaja — o registro é honesto sobre o que houve —, mas o
      // motivo do encerramento barra a concessão.
      expect(desfecho.assentoQueBateuUltimaRodada, 0);
      final v = vereditoDe(encerrado(desfecho));
      expect(v.elegivel, isFalse);
      expect(v.motivo, MotivoInelegibilidade.partidaNaoFinalizada);
    });

    test('ponta a ponta: partida ainda ativa não concede', () {
      final registro = registroRanqueado()
          .transicionarPara(EstadoDaPartida.ativa, em: agora);
      final v = vereditoDe(registro);
      expect(v.motivo, MotivoInelegibilidade.partidaNaoFinalizada);
    });
  });

  group('coerência do envelope, na construção do desfecho', () {
    test('assento que não pertence ao lado declarado é recusado', () {
      final j = jogoNovo();
      encerrarJogo(j, nos: 1520, eles: 1180);
      j.duplaQueBateu = 'nos';
      j.assentoQueBateu = 1; // 1 é de `eles`
      expect(() => capturarDesfecho(motorDe(j), encerradaEm: depois),
          throwsA(isA<ArgumentError>()));
    });

    test('assento sem dupla declarada é recusado', () {
      final j = jogoNovo();
      encerrarJogo(j, nos: 1520, eles: 1180);
      j.assentoQueBateu = 0;
      expect(() => capturarDesfecho(motorDe(j), encerradaEm: depois),
          throwsA(isA<ArgumentError>()));
    });

    test('desfecho com assento fora de 0..3 é recusado na leitura', () {
      final cru = desfechoComBatidaJson(9);
      expect(() => DesfechoCanonicoPartida.deJson(cru),
          throwsA(isA<FormatException>()));
    });
  });
}

/// JSON de desfecho válido, com o assento trocado à mão — para exercitar a
/// validação de leitura sem passar pelo construtor.
Map<String, Object?> desfechoComBatidaJson(int assento) {
  final j = jogoNovo();
  encerrarJogo(j, nos: 1520, eles: 1180);
  j.duplaQueBateu = 'nos';
  j.assentoQueBateu = 0;
  final json = capturarDesfecho(motorDe(j), encerradaEm: depois).toJson();
  return {...json, 'assentoQueBateuUltimaRodada': assento};
}
