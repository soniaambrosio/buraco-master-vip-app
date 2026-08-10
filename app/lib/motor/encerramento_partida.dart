// encerramento_partida.dart — PORTA CANÔNICA DE ENCERRAMENTO (OS §3 / §4).
//
// A doc `MOTOR-PARTIDAS-ARQUITETURA.md` fechou a OS-01 com uma regra vinculante
// para quem consome o motor — em especial o adaptador de torneios:
//
//   > Um consumidor NÃO importa `mesa.dart` e NÃO lê `MotorPartida.jogo`.
//   > Ele consome exclusivamente a porta pública canônica de encerramento (DTO).
//
// Até aqui essa porta era um "contrato declarado, não imposto pelo compilador":
// a classe leitora de `partidaEncerrada` fora deliberadamente adiada para a OS
// de ligação (DECISÃO 4 do protocolo). Este arquivo cria essa porta.
//
// Por que importa: um adaptador que lê `MotorPartida.jogo` para saber quem
// venceu está lendo mão, monte e mortos — informação que ele não precisa e não
// deveria alcançar. Qualquer evolução das regras do buraco viraria quebra em
// cascata em módulos que nada têm a ver com buraco. O DTO derrama SÓ o desfecho:
// placar, meta, modalidade e a dupla vencedora — nenhuma carta.

import '../mesa.dart';

/// Desfecho de uma partida, pronto para trafegar e persistir.
///
/// Imutável. Só é construído a partir do resultado PÚBLICO do [Jogo] e só
/// quando a partida realmente encerrou — ver [doJogo].
class EncerramentoPartida {
  final String partidaId;

  /// Versão do estado no instante do encerramento (trava/idempotência).
  final int versaoEstado;

  /// 'nos' | 'eles' — a dupla vencedora da PARTIDA.
  ///
  /// Determinística: `mesa.dart` (§9.2) só marca a partida encerrada quando uma
  /// dupla cruza a meta E não há empate exato (empate força rodada extra). Logo,
  /// quando há encerramento, sempre existe um vencedor único.
  final String duplaVencedora;

  final int placarNos;
  final int placarEles;
  final int metaPontos;

  /// 'ABERTO' | 'FECHADO' | 'SBTL'.
  final String modalidade;

  /// Quantas rodadas foram jogadas até o encerramento.
  final int rodada;

  /// 'nos' | 'eles' | null — quem bateu na última rodada apurada. Informativo:
  /// NÃO é necessariamente o vencedor da partida (ver [duplaVencedora]).
  final String? duplaQueBateuUltimaRodada;

  const EncerramentoPartida({
    required this.partidaId,
    required this.versaoEstado,
    required this.duplaVencedora,
    required this.placarNos,
    required this.placarEles,
    required this.metaPontos,
    required this.modalidade,
    required this.rodada,
    this.duplaQueBateuUltimaRodada,
  });

  /// Lê o desfecho a partir do resultado público do [jogo].
  ///
  /// Retorna `null` enquanto a partida não tiver encerrado — o consumidor nunca
  /// recebe um desfecho inventado. Não toca em mão, monte, lixo nem mortos.
  static EncerramentoPartida? doJogo(
    Jogo jogo, {
    required String partidaId,
    required int versaoEstado,
  }) {
    if (!jogo.encerrada) return null;
    final nos = jogo.placar['nos'] ?? 0;
    final eles = jogo.placar['eles'] ?? 0;
    // `encerrada` garante nos != eles; o desempate defensivo abaixo nunca cai no
    // caso de igualdade, mas mantém a função total.
    final vencedora = nos >= eles ? 'nos' : 'eles';
    return EncerramentoPartida(
      partidaId: partidaId,
      versaoEstado: versaoEstado,
      duplaVencedora: vencedora,
      placarNos: nos,
      placarEles: eles,
      metaPontos: jogo.metaPontos,
      modalidade: jogo.modalidade,
      rodada: jogo.rodada,
      duplaQueBateuUltimaRodada: jogo.duplaQueBateu,
    );
  }

  Map<String, Object?> toJson() => {
        'partidaId': partidaId,
        'versaoEstado': versaoEstado,
        'duplaVencedora': duplaVencedora,
        'placarNos': placarNos,
        'placarEles': placarEles,
        'metaPontos': metaPontos,
        'modalidade': modalidade,
        'rodada': rodada,
        if (duplaQueBateuUltimaRodada != null)
          'duplaQueBateuUltimaRodada': duplaQueBateuUltimaRodada,
      };

  /// Lê um desfecho da rede/persistência. Retorna `null` para envelope
  /// irreconhecível — identidade ausente ou vencedora fora de {'nos','eles'}.
  static EncerramentoPartida? deJson(Object? raw) {
    if (raw is! Map) return null;
    final partidaId = raw['partidaId'];
    final versao = raw['versaoEstado'];
    final vencedora = raw['duplaVencedora'];
    if (partidaId is! String || partidaId.trim().isEmpty) return null;
    if (versao is! num) return null;
    if (vencedora != 'nos' && vencedora != 'eles') return null;
    int comoInt(Object? v) => v is num ? v.toInt() : 0;
    final modalidade = raw['modalidade'];
    final bateu = raw['duplaQueBateuUltimaRodada'];
    return EncerramentoPartida(
      partidaId: partidaId,
      versaoEstado: versao.toInt(),
      duplaVencedora: vencedora as String,
      placarNos: comoInt(raw['placarNos']),
      placarEles: comoInt(raw['placarEles']),
      metaPontos: comoInt(raw['metaPontos']),
      modalidade: modalidade is String ? modalidade : 'ABERTO',
      rodada: comoInt(raw['rodada']),
      duplaQueBateuUltimaRodada: bateu is String ? bateu : null,
    );
  }

  @override
  String toString() =>
      'EncerramentoPartida($partidaId, vencedora=$duplaVencedora, '
      '$placarNos x $placarEles, v$versaoEstado)';
}
