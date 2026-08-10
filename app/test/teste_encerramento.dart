// teste_encerramento.dart — PORTA CANÔNICA DE ENCERRAMENTO (OS §3 / §4).
//
// Prova que o desfecho da partida é lido por um contrato explícito
// (EncerramentoPartida): que a porta só existe quando a partida acabou, que a
// dupla vencedora vem do PLACAR (não de quem bateu na última rodada), que o
// desfecho sobrevive a toJson/deJson e que ele NÃO carrega nenhum id de carta.
//
// STATUS DE EXECUÇÃO: EXECUTADA em 10/08/2026 na máquina da Sônia, com o mesmo
// harness do CI (flutter create + overlay de `app/lib`) — Flutter 3.41.4 /
// Dart 3.11.1. 7 testes verdes, junto de teste_motor (132),
// teste_motor_resiliencia (181) e torneios/reward_grants (80), com
// `flutter analyze` sem nenhum ERRO. O CI (GitHub Actions) segue pendente:
// neste repositório o workflow só é dispachável depois de chegar à branch
// padrão, e push não dispara run (OS §18).

import 'package:flutter_test/flutter_test.dart';
import 'package:buraco_master_vip/mesa.dart';
import 'package:buraco_master_vip/motor/motor_partida.dart';
import 'package:buraco_master_vip/motor/encerramento_partida.dart';

// ============================== ferramentas ==============================

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

void main() {
  group('ENCERR — porta canônica de encerramento', () {
    test('ENCERR-01 partida não encerrada: a porta é null', () {
      final j = novo();
      final motor = motorDe(j);
      expect(j.encerrada, isFalse);
      expect(motor.encerramento, isNull);
      expect(
        EncerramentoPartida.doJogo(j, partidaId: 'p', versaoEstado: 0),
        isNull,
      );
    });

    test('ENCERR-02 encerrada: vencedora é a dupla de maior placar (nos)', () {
      final j = novo();
      encerrarCom(j, nos: 1520, eles: 1180, bateu: 'nos');
      final e = motorDe(j, versaoInicial: 42).encerramento;
      expect(e, isNotNull);
      expect(e!.duplaVencedora, 'nos');
      expect(e.placarNos, 1520);
      expect(e.placarEles, 1180);
      expect(e.versaoEstado, 42);
      expect(e.partidaId, 'p-teste');
    });

    test('ENCERR-03 vencedora vem do PLACAR, não de quem bateu na última rodada',
        () {
      // Uma dupla pode bater a última rodada e ainda perder a partida.
      final j = novo();
      encerrarCom(j, nos: 1490, eles: 1530, bateu: 'nos');
      final e = motorDe(j).encerramento!;
      expect(e.duplaVencedora, 'eles');
      expect(e.duplaQueBateuUltimaRodada, 'nos');
    });

    test('ENCERR-04 metaPontos e modalidade atravessam para o DTO', () {
      final j = novo('FECHADO');
      encerrarCom(j, nos: 1600, eles: 1200);
      final e = motorDe(j).encerramento!;
      expect(e.metaPontos, j.metaPontos);
      expect(e.modalidade, 'FECHADO');
      expect(e.duplaQueBateuUltimaRodada, isNull);
    });

    test('ENCERR-05 toJson/deJson ida e volta preserva o desfecho', () {
      final j = novo('SBTL');
      encerrarCom(j, nos: 1510, eles: 999, bateu: 'nos', rodada: 5);
      final e = motorDe(j, versaoInicial: 7).encerramento!;
      final volta = EncerramentoPartida.deJson(e.toJson());
      expect(volta, isNotNull);
      expect(volta!.duplaVencedora, e.duplaVencedora);
      expect(volta.placarNos, e.placarNos);
      expect(volta.placarEles, e.placarEles);
      expect(volta.metaPontos, e.metaPontos);
      expect(volta.modalidade, e.modalidade);
      expect(volta.rodada, e.rodada);
      expect(volta.versaoEstado, e.versaoEstado);
      expect(volta.duplaQueBateuUltimaRodada, 'nos');
    });

    test('ENCERR-06 deJson recusa desfecho inválido', () {
      expect(EncerramentoPartida.deJson(null), isNull);
      expect(EncerramentoPartida.deJson('x'), isNull);
      expect(
        EncerramentoPartida.deJson(
            {'partidaId': '', 'versaoEstado': 0, 'duplaVencedora': 'nos'}),
        isNull,
      );
      expect(
        EncerramentoPartida.deJson(
            {'partidaId': 'p', 'versaoEstado': 0, 'duplaVencedora': 'ninguem'}),
        isNull,
      );
      expect(
        EncerramentoPartida.deJson(
            {'partidaId': 'p', 'versaoEstado': 'x', 'duplaVencedora': 'nos'}),
        isNull,
      );
    });

    test('ENCERR-07 o desfecho NÃO expõe nenhum id de carta (varredura)', () {
      final j = novo();
      encerrarCom(j, nos: 1500, eles: 1234, bateu: 'eles');
      final e = motorDe(j).encerramento!;
      final texto = e.toJson().toString();
      // ids de carta no jogo têm o formato c<numero> (ver visao_assento/comando).
      expect(
        RegExp(r'c\d+').hasMatch(texto),
        isFalse,
        reason: 'o desfecho não deve carregar id de carta: $texto',
      );
    });
  });
}
