// teste_encerramento.dart — PORTA CANÔNICA DE ENCERRAMENTO (OS §3 / §4).
//
// Prova que o desfecho da partida é lido por um contrato explícito
// (`DesfechoCanonicoPartida`): que ele só é conclusivo quando a partida acabou,
// que a dupla vencedora vem do PLACAR (não de quem bateu na última rodada), que
// empate é tratado de forma estrita, que o desfecho sobrevive a toJson/deJson,
// que ele entrega os totais de canastras limpas ao contrato de torneio e que
// NÃO carrega nenhum id de carta.
//
// HISTÓRICO: estes casos nasceram sobre `EncerramentoPartida`, um DTO mínimo
// criado pelo Bloco 1. Na consolidação ficou decidido que
// `DesfechoCanonicoPartida` é o contrato canônico único, e os casos foram
// migrados um a um para ele. Duas diferenças de semântica, deliberadas:
//
//   * partida viva devolve `estado: emAndamento` em vez de `null` — o desfecho
//     existe, mas não é conclusivo (`conclusivo == false`, sem vencedor e sem
//     motivo, garantido pelo construtor);
//   * envelope inválido LANÇA `FormatException` em vez de devolver `null`, que
//     é o idioma do contrato sobrevivente: um resultado que decide classificação
//     de torneio não pode virar `null` silencioso.
//
// STATUS DE EXECUÇÃO: EXECUTADA em 10/08/2026 na máquina da Sônia, com o mesmo
// harness do CI (flutter create + overlay de `app/lib`) — Flutter 3.41.4 /
// Dart 3.11.1. O CI (GitHub Actions) segue pendente: neste repositório o
// workflow só é dispachável depois de chegar à branch padrão, e push não
// dispara run (OS §18).

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/desfecho_partida.dart';
import 'package:buraco_master_vip/motor/motor_partida.dart';

// ============================== ferramentas ==============================

final DateTime quando = DateTime.utc(2026, 8, 10, 12, 0, 0);

Jogo novo([String modalidade = 'ABERTO']) {
  final j = Jogo(const ['você', 'B1', 'B2', 'B3'], const ['A', 'B', 'C', 'D'],
      const ['🐶', '🐰', '🦊', '🐱']);
  j.modalidade = modalidade;
  return j;
}

MotorPartida motorDe(Jogo j, {int versaoInicial = 0}) => MotorPartida(
      partidaId: 'p-teste',
      jogo: j,
      agora: () => 1700000000000,
      versaoInicial: versaoInicial,
    );

/// Marca a partida como encerrada com um placar dado, sem simular a partida
/// inteira — os campos de desfecho do Jogo são públicos. Não mexe em cartas, e
/// por isso não quebra a integridade das 108 cartas distribuídas no construtor.
void encerrarCom(
  Jogo j, {
  required int nos,
  required int eles,
  String? bateu,
  int rodada = 3,
}) {
  j.placar['nos'] = nos;
  j.placar['eles'] = eles;
  j.duplaQueBateu = bateu;
  j.rodada = rodada;
  j.encerrada = true;
}

/// Um motor com canastras limpas já acumuladas, pela porta pública: restaura um
/// envelope. Evita ter que simular rodadas inteiras só para ter o número.
MotorPartida motorComCanastras({required int nos, required int eles}) {
  final base = motorDe(novo()).snapshot();
  return MotorPartida.restaurar({
    ...base,
    'canastrasLimpas': {'nos': nos, 'eles': eles},
  });
}

void main() {
  group('ENCERR — porta canônica de encerramento', () {
    test('ENCERR-01 partida não encerrada: desfecho existe, mas não é conclusivo',
        () {
      final j = novo();
      final m = motorDe(j);
      expect(j.encerrada, isFalse);

      final d = capturarDesfecho(m, encerradaEm: quando);
      expect(d.estado, EstadoEncerramento.emAndamento);
      expect(d.conclusivo, isFalse,
          reason: 'não pode virar resultado de torneio');
      expect(d.ladoVencedor, isNull);
      expect(d.motivo, isNull);
    });

    test('ENCERR-02 encerrada: vencedor é a dupla de maior placar (nos)', () {
      final j = novo();
      encerrarCom(j, nos: 1520, eles: 1180, bateu: 'nos');
      final d = capturarDesfecho(motorDe(j, versaoInicial: 42), encerradaEm: quando);

      expect(d.conclusivo, isTrue);
      expect(d.motivo, MotivoEncerramento.metaAtingida);
      expect(d.ladoVencedor, 'nos');
      expect(d.porLado('nos')!.pontos, 1520);
      expect(d.porLado('eles')!.pontos, 1180);
      expect(d.versaoEstado, 42);
      expect(d.partidaId, 'p-teste');
    });

    test('ENCERR-03 vencedor vem do PLACAR, não de quem bateu a última rodada',
        () {
      // Uma dupla pode bater a última rodada e ainda perder a partida.
      final j = novo();
      encerrarCom(j, nos: 1490, eles: 1530, bateu: 'nos');
      final d = capturarDesfecho(motorDe(j), encerradaEm: quando);

      expect(d.ladoVencedor, 'eles');
      expect(d.duplaQueBateuUltimaRodada, 'nos',
          reason: 'viaja como informação, sem decidir nada');
    });

    test('ENCERR-04 metaPontos, modalidade e rodada atravessam para o DTO', () {
      final j = novo('FECHADO');
      encerrarCom(j, nos: 1600, eles: 1200, rodada: 4);
      final d = capturarDesfecho(motorDe(j), encerradaEm: quando);

      expect(d.metaPontos, j.metaPontos);
      expect(d.modalidade, 'FECHADO');
      expect(d.rodada, 4);
      expect(d.duplaQueBateuUltimaRodada, isNull);
    });

    test('ENCERR-05 toJson/deJson ida e volta preserva o desfecho', () {
      final m = motorComCanastras(nos: 2, eles: 1);
      encerrarCom(m.jogo, nos: 1510, eles: 999, bateu: 'nos', rodada: 5);
      m.jogo.modalidade = 'SBTL';
      final d = capturarDesfecho(m, encerradaEm: quando);

      final volta = DesfechoCanonicoPartida.deJson(d.toJson());
      expect(volta.partidaId, d.partidaId);
      expect(volta.estado, d.estado);
      expect(volta.motivo, d.motivo);
      expect(volta.ladoVencedor, d.ladoVencedor);
      expect(volta.versaoEstado, d.versaoEstado);
      expect(volta.impressaoEstado, d.impressaoEstado);
      expect(volta.metaPontos, d.metaPontos);
      expect(volta.modalidade, 'SBTL');
      expect(volta.rodada, 5);
      expect(volta.duplaQueBateuUltimaRodada, 'nos');
      expect(volta.encerradaEm, d.encerradaEm);
      for (final lado in const ['nos', 'eles']) {
        expect(volta.porLado(lado)!.pontos, d.porLado(lado)!.pontos);
        expect(volta.porLado(lado)!.canastrasLimpas,
            d.porLado(lado)!.canastrasLimpas);
        expect(volta.porLado(lado)!.assentos, d.porLado(lado)!.assentos);
      }
    });

    test('ENCERR-06 deJson recusa envelope inválido, em vez de completar', () {
      final j = novo();
      encerrarCom(j, nos: 1520, eles: 1180);
      final bom = capturarDesfecho(motorDe(j), encerradaEm: quando).toJson();

      Map<String, Object?> semA(String chave) =>
          Map<String, Object?>.of(bom)..remove(chave);
      Map<String, Object?> com(String chave, Object? v) =>
          Map<String, Object?>.of(bom)..[chave] = v;

      expect(() => DesfechoCanonicoPartida.deJson(null), throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson('x'), throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(com('partidaId', '')),
          throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(com('estado', 'talvez')),
          throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(com('motivo', 'porque_sim')),
          throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(com('versaoEstado', 'x')),
          throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(semA('impressaoEstado')),
          throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(semA('metaPontos')),
          throwsFormatException);
      expect(() => DesfechoCanonicoPartida.deJson(semA('modalidade')),
          throwsFormatException);
      expect(
          () => DesfechoCanonicoPartida.deJson(
              com('duplaQueBateuUltimaRodada', 'ninguem')),
          throwsFormatException);
      // Envelope bem formado mas incoerente: vencedor que não é um dos lados.
      expect(() => DesfechoCanonicoPartida.deJson(com('ladoVencedor', 'terceiros')),
          throwsFormatException);
      // Canastras ausentes NÃO viram zero: é dado de desempate perdido.
      expect(
          () => DesfechoCanonicoPartida.deJson(com('lados', [
                {'lado': 'nos', 'assentos': [0, 2], 'pontos': 1520},
                {'lado': 'eles', 'assentos': [1, 3], 'pontos': 1180},
              ])),
          throwsFormatException);
      // E o bom continua passando, para o teste não estar provando o vazio.
      expect(DesfechoCanonicoPartida.deJson(bom).ladoVencedor, 'nos');
    });

    test('ENCERR-07 o desfecho NÃO expõe nenhum id de carta (varredura)', () {
      final j = novo();
      encerrarCom(j, nos: 1500, eles: 1234, bateu: 'eles');
      final d = capturarDesfecho(motorDe(j), encerradaEm: quando);

      // `impressaoEstado` sai da varredura, e o motivo importa: é um hash
      // FNV-1a, ou seja, hexadecimal — mais cedo ou mais tarde ele contém um
      // "c" seguido de dígito por puro acaso, e o baralho é embaralhado a cada
      // execução, então a varredura por padrão daria um teste que passa ou
      // falha por sorte. Hash é função de mão única: ele não pode vazar
      // identidade de carta por construção, e que ele é o fingerprint certo já
      // está provado em ENCERR-09 e nos IMPP.
      final payload = d.toJson()..remove('impressaoEstado');
      final texto = payload.toString();

      // 1. Nenhum id REAL desta partida aparece — a pergunta que interessa.
      final cartas = [
        ...j.monte,
        ...j.lixo,
        for (final m in j.mortos) ...m,
        for (final m in j.maos) ...m,
        for (final g in j.jogosDupla['nos']!) ...g,
        for (final g in j.jogosDupla['eles']!) ...g,
      ];
      expect(cartas, hasLength(108), reason: 'a varredura precisa ver o baralho todo');
      for (final c in cartas) {
        expect(texto.contains(c.id), isFalse,
            reason: 'o desfecho carrega o id ${c.id}: $texto');
      }

      // 2. E nenhum id no formato c<numero> sequer — pega campo novo com carta
      //    dentro mesmo que a carta não seja desta partida.
      expect(
        RegExp(r'c\d+').hasMatch(texto),
        isFalse,
        reason: 'o desfecho não deve carregar id de carta: $texto',
      );
    });

    test('ENCERR-08 empate é estrito: nada de vencedor deduzido em silêncio',
        () {
      // Estado impossível pela regra (§9.2 de mesa.dart só encerra com n != e),
      // forjado de propósito: se um dia alguém marcar `encerrada` por fora, o
      // contrato tem que falhar alto em vez de premiar um lado por desempate
      // silencioso.
      final j = novo();
      encerrarCom(j, nos: 1500, eles: 1500);
      expect(() => capturarDesfecho(motorDe(j), encerradaEm: quando),
          throwsStateError);
    });

    test('ENCERR-09 encerramento natural entrega os totais de canastras', () {
      final m = motorComCanastras(nos: 3, eles: 1);
      encerrarCom(m.jogo, nos: 1520, eles: 1180, bateu: 'nos');
      final d = capturarDesfecho(m, encerradaEm: quando);

      expect(d.porLado('nos')!.canastrasLimpas, 3);
      expect(d.porLado('eles')!.canastrasLimpas, 1);
      expect(d.porLado('nos')!.assentos, const [0, 2]);
      expect(d.porLado('eles')!.assentos, const [1, 3]);
      // A impressão do desfecho é a da PARTIDA, que inclui as canastras.
      expect(d.impressaoEstado, m.impressaoPartida);
    });

    test('ENCERR-10 mesmo placar e canastras diferentes: impressões diferentes',
        () {
      final a = motorComCanastras(nos: 3, eles: 1);
      final b = motorComCanastras(nos: 1, eles: 3);
      for (final m in [a, b]) {
        encerrarCom(m.jogo, nos: 1520, eles: 1180, bateu: 'nos');
      }
      final da = capturarDesfecho(a, encerradaEm: quando);
      final db = capturarDesfecho(b, encerradaEm: quando);

      expect(da.ladoVencedor, db.ladoVencedor, reason: 'mesmo placar');
      expect(da.impressaoEstado, isNot(db.impressaoEstado),
          reason: 'o desempate do torneio muda, logo a identidade muda');
    });
  });
}
