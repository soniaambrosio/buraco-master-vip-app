// registro_partidas.dart — ONDE AS PARTIDAS SOLICITADAS PASSAM A EXISTIR.
//
// O contrato de torneios diz "o torneio solicita uma partida" e para por aí, de
// propósito: como a partida nasce é assunto do Motor de Partidas. Este arquivo é
// a porta entre os dois — recebe a solicitação já traduzida e devolve uma
// partida viva, idempotente por `matchId`.
//
// IDEMPOTÊNCIA POR matchId. O `matchId` é derivado do `mesaId` lá em
// seating.dart justamente para isto: solicitar duas vezes a mesma mesa devolve a
// MESMA partida, com o mesmo baralho e o mesmo placar, em vez de abrir uma
// segunda mesa que ninguém saberia qual valia. É a camada externa da
// idempotência; a interna, por `eventoId`, continua sendo do `MotorPartida`.
//
// ESTE ARQUIVO NÃO CLASSIFICA NINGUÉM e não conhece fase, ponto corrido ou
// premiação — ele guarda partidas.

import 'dart:async';

import '../mesa.dart';
import '../motor/diagnostico.dart';
import '../motor/motor_partida.dart';
import 'vinculo_mesa.dart';

/// O que o Motor de Partidas precisa saber para abrir uma mesa.
///
/// Nada de torneio entra aqui além dos identificadores necessários para a
/// idempotência: modalidade e meta de pontos são parâmetros que a mesa já
/// entende, e o vínculo viaja junto porque é ele que diz quem senta onde.
class AberturaDePartida {
  /// Igual ao `matchId` do torneio. A partida e a mesa são um-para-um.
  final String partidaId;

  /// `ABERTO` | `FECHADO` | `SBTL`, como `Jogo.modalidade`.
  final String modalidade;

  final int metaPontos;

  final VinculoDeMesa vinculo;

  /// Apelidos por assento, quando a camada de aplicação os conhece. A mesa
  /// precisa de quatro; o que faltar vira rótulo neutro, nunca o `userId` — id
  /// de jogador em tela é vazamento, não é nome.
  final List<String> apelidos;

  AberturaDePartida({
    required this.partidaId,
    required this.modalidade,
    required this.metaPontos,
    required this.vinculo,
    List<String>? apelidos,
  }) : apelidos = List.unmodifiable(
          apelidos ?? const ['Assento 1', 'Assento 2', 'Assento 3', 'Assento 4'],
        ) {
    if (partidaId.isEmpty) {
      throw ArgumentError.value(partidaId, 'partidaId', 'não pode ser vazio');
    }
    if (partidaId != vinculo.matchId) {
      throw ArgumentError.value(partidaId, 'partidaId',
          'não corresponde ao vínculo (${vinculo.matchId})');
    }
    if (metaPontos < 1) {
      throw ArgumentError.value(metaPontos, 'metaPontos', 'deve ser >= 1');
    }
    if (this.apelidos.length != 4) {
      throw ArgumentError.value(
          this.apelidos.length, 'apelidos', 'a mesa tem quatro assentos');
    }
  }
}

/// Onde as partidas abertas ficam.
///
/// Interface, e não classe concreta, porque em produção isto é o servidor
/// Node/Railway (ver docs/MOTOR-PARTIDAS-PROTOCOLO-SERVIDOR.md) e em teste é
/// memória. O adaptador depende só do formato.
abstract interface class RegistroDePartidas {
  /// Abre a partida, ou devolve a que já existe com o mesmo `partidaId`.
  ///
  /// OBRIGATORIAMENTE idempotente: chamar duas vezes com a mesma abertura não
  /// pode produzir duas mesas nem redistribuir cartas de uma mesa em andamento.
  FutureOr<MotorPartida> abrir(AberturaDePartida abertura);

  /// A partida em curso, ou `null` se nunca foi aberta (ou já foi cancelada).
  FutureOr<MotorPartida?> buscar(String partidaId);

  /// O vínculo declarado na abertura. Guardado junto da partida porque é ele que
  /// traduz o desfecho de volta para o torneio, e uma partida sem vínculo é um
  /// resultado que não se sabe de quem é.
  FutureOr<VinculoDeMesa?> vinculoDe(String partidaId);

  /// Desfaz uma partida ainda não encerrada. Silencioso quando o id não existe.
  FutureOr<void> cancelar(String partidaId);
}

/// Registro em memória.
///
/// Serve ao app (uma partida por vez, na própria máquina) e aos testes. O
/// servidor autoritativo tem a sua própria implementação, com o mesmo contrato.
class RegistroDePartidasEmMemoria implements RegistroDePartidas {
  final Map<String, MotorPartida> _partidas = {};
  final Map<String, VinculoDeMesa> _vinculos = {};

  /// Fonte de tempo repassada aos motores criados. Injetável pelo mesmo motivo
  /// de sempre: teste não espera relógio.
  final FonteDeTempo? agora;

  RegistroDePartidasEmMemoria({this.agora});

  /// Quantas partidas estão abertas. Só para diagnóstico e teste.
  int get abertas => _partidas.length;

  @override
  MotorPartida abrir(AberturaDePartida abertura) {
    final existente = _partidas[abertura.partidaId];
    if (existente != null) {
      // Reenvio da solicitação. Devolver a mesa em curso é o comportamento
      // exigido pelo contrato: recriar aqui apagaria uma partida que já pode ter
      // rodadas jogadas, e o jogador veria as cartas trocarem na mão.
      return existente;
    }
    final jogo = Jogo(
      abertura.apelidos,
      const ['A', 'B', 'C', 'D'],
      const ['🐶', '🐰', '🦊', '🐱'],
    )
      ..modalidade = abertura.modalidade
      ..metaPontos = abertura.metaPontos;

    final motor = MotorPartida(
      partidaId: abertura.partidaId,
      jogo: jogo,
      diario: DiarioPartida(abertura.partidaId),
      agora: agora,
    );
    _partidas[abertura.partidaId] = motor;
    _vinculos[abertura.partidaId] = abertura.vinculo;
    return motor;
  }

  @override
  MotorPartida? buscar(String partidaId) => _partidas[partidaId];

  @override
  VinculoDeMesa? vinculoDe(String partidaId) => _vinculos[partidaId];

  @override
  void cancelar(String partidaId) {
    _partidas.remove(partidaId);
    _vinculos.remove(partidaId);
  }
}
