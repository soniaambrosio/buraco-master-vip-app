// desfecho_partida.dart — O QUE O MOTOR DE PARTIDAS DIZ QUANDO A PARTIDA ACABA.
//
// Este arquivo é a saída canônica do Motor de Partidas, e nada mais. Ele NÃO
// conhece torneio: aqui não existe participante, fase, classificação, desempate
// nem premiação. Quem traduz isto para o vocabulário esportivo é a camada de
// integração (lib/integracao), e é ela que importa os dois lados — nunca este
// arquivo.
//
// Também não existe regra de buraco aqui. Nenhuma pontuação é calculada, nenhuma
// canastra é contada: os números são LIDOS de `Jogo`/`MotorPartida`, que já os
// apuraram. Se um dia este arquivo precisar somar alguma coisa, a conta está no
// lugar errado.
//
// A DECISÃO MAIS IMPORTANTE DESTE ARQUIVO É O QUE ELE NÃO SABE FAZER:
// não há caminho, em lugar nenhum, que transforme queda de rede, app em segundo
// plano, presença `ausente` ou reconexão em [MotivoEncerramento.abandono].
// Abandono, encerramento administrativo e anulação só entram por
// [OrdemDeEncerramento], que é produzida por autoridade explícita — o servidor
// ou a administração. É a mesma fronteira que `presenca.dart` já desenha:
// "o cliente pode desconfiar, só o servidor pode declarar".

import 'motor_partida.dart';

/// A partida chegou ao fim?
enum EstadoEncerramento {
  /// Ainda em disputa. Um desfecho neste estado NÃO é resultado final e não
  /// pode virar resultado de torneio.
  emAndamento('em_andamento'),

  /// Encerramento consumado.
  encerrada('encerrada');

  final String wire;
  const EstadoEncerramento(this.wire);

  static EstadoEncerramento? porWire(String wire) {
    for (final e in EstadoEncerramento.values) {
      if (e.wire == wire) return e;
    }
    return null;
  }
}

/// Por que a partida acabou, no vocabulário do Motor de Partidas.
///
/// Deliberadamente NÃO é o enum do torneio: são domínios diferentes e a tradução
/// é explícita na camada de integração. Se fossem o mesmo tipo, o Motor de
/// Partidas passaria a importar torneios e a seta do contrato inverteria.
enum MotivoEncerramento {
  /// A própria mesa terminou: alguém cruzou a meta de pontos sem empate exato
  /// (`Jogo.encerrada`). O único motivo que o motor produz sozinho.
  metaAtingida('meta_atingida'),

  /// Um lado saiu e a autoridade declarou. Ver `presenca.dart`:
  /// `RegistroAbandono` é quem carrega essa declaração.
  abandono('abandono'),

  /// A administração encerrou a partida sem disputa completa.
  encerradaPorAdmin('encerrada_por_admin'),

  /// A partida foi anulada: não vale para ninguém.
  anulada('anulada');

  final String wire;
  const MotivoEncerramento(this.wire);

  /// O motivo nasce de decisão externa, não da mesa.
  bool get exigeAutoridade => this != metaAtingida;

  static MotivoEncerramento? porWire(String wire) {
    for (final m in MotivoEncerramento.values) {
      if (m.wire == wire) return m;
    }
    return null;
  }
}

/// Ordem autoritativa de encerramento não-natural.
///
/// Existe para que abandono, encerramento administrativo e anulação tenham UMA
/// porta de entrada, rastreável e assinada. Nada em `presenca.dart`,
/// `sessao_reconexao.dart` ou `relogio_turno.dart` constrói este objeto — o app
/// não tem como fabricá-lo a partir de silêncio de rede, que é exatamente a
/// confusão entre desconexão e abandono que a OS proíbe.
class OrdemDeEncerramento {
  final MotivoEncerramento motivo;

  /// Lado vencedor no vocabulário da mesa: `nos` | `eles`.
  ///
  /// Obrigatório em [MotivoEncerramento.abandono] e
  /// [MotivoEncerramento.encerradaPorAdmin] — se a autoridade encerrou sem dizer
  /// quem venceu, o dado que falta é dela, e adivinhar aqui pelo placar seria
  /// decidir a competição em silêncio.
  ///
  /// Proibido em [MotivoEncerramento.anulada]: partida anulada não tem vencedor.
  final String? ladoVencedor;

  /// Quem declarou. Texto opaco de propósito: pode ser o id do servidor
  /// (`srv-...`), do administrador ou do processo automático que a autoridade
  /// executou. O motor não interpreta, só registra para auditoria.
  final String autoridade;

  /// Instante da declaração, em UTC. Recebido por parâmetro — este arquivo não
  /// lê relógio.
  final DateTime declaradaEm;

  /// Motivo em texto livre para o log/suporte. Nunca é regra.
  final String? observacao;

  OrdemDeEncerramento({
    required this.motivo,
    required this.autoridade,
    required DateTime declaradaEm,
    this.ladoVencedor,
    this.observacao,
  }) : declaradaEm = declaradaEm.toUtc() {
    if (!motivo.exigeAutoridade) {
      throw ArgumentError.value(motivo, 'motivo',
          'meta atingida é decisão da mesa e não se declara por ordem');
    }
    if (autoridade.isEmpty) {
      throw ArgumentError.value(autoridade, 'autoridade',
          'ordem de encerramento sem autoridade não é rastreável');
    }
    if (motivo == MotivoEncerramento.anulada) {
      if (ladoVencedor != null) {
        throw ArgumentError.value(
            ladoVencedor, 'ladoVencedor', 'partida anulada não tem vencedor');
      }
    } else {
      if (ladoVencedor != 'nos' && ladoVencedor != 'eles') {
        throw ArgumentError.value(ladoVencedor, 'ladoVencedor',
            'em ${motivo.wire} a autoridade precisa declarar o lado vencedor (nos|eles)');
      }
    }
  }

  Map<String, Object?> toJson() => {
        'motivo': motivo.wire,
        'ladoVencedor': ladoVencedor,
        'autoridade': autoridade,
        'declaradaEm': declaradaEm.toIso8601String(),
        'observacao': observacao,
      };

  static OrdemDeEncerramento deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('ordem de encerramento: objeto esperado.');
    }
    final motivo = MotivoEncerramento.porWire('${raw['motivo']}');
    if (motivo == null) {
      throw FormatException(
          'ordem de encerramento: motivo desconhecido "${raw['motivo']}".');
    }
    final quando = DateTime.tryParse('${raw['declaradaEm']}');
    if (quando == null) {
      throw FormatException(
          'ordem de encerramento: declaradaEm não é ISO-8601 (recebido: ${raw['declaradaEm']}).');
    }
    return OrdemDeEncerramento(
      motivo: motivo,
      ladoVencedor: raw['ladoVencedor'] as String?,
      autoridade: raw['autoridade'] is String ? raw['autoridade'] as String : '',
      declaradaEm: quando,
      observacao: raw['observacao'] as String?,
    );
  }

  @override
  String toString() => 'OrdemDeEncerramento(${motivo.wire} por $autoridade)';
}

/// Como um lado da mesa terminou. Só números já apurados.
class LadoDaMesa {
  /// `nos` | `eles`, como `Jogo` nomeia as duplas.
  final String lado;

  /// Assentos que compõem o lado: `[0, 2]` para `nos`, `[1, 3]` para `eles`.
  final List<int> assentos;

  /// Placar final, exatamente como `Jogo.placar` o deixou.
  final int pontos;

  /// Canastras limpas da PARTIDA, exatamente como `MotorPartida` as acumulou.
  final int canastrasLimpas;

  LadoDaMesa({
    required this.lado,
    required List<int> assentos,
    required this.pontos,
    required this.canastrasLimpas,
  }) : assentos = List.unmodifiable(assentos) {
    if (lado != 'nos' && lado != 'eles') {
      throw ArgumentError.value(lado, 'lado', 'deve ser "nos" ou "eles"');
    }
    if (canastrasLimpas < 0) {
      throw ArgumentError.value(
          canastrasLimpas, 'canastrasLimpas', 'não pode ser negativo');
    }
  }

  Map<String, Object?> toJson() => {
        'lado': lado,
        'assentos': assentos,
        'pontos': pontos,
        'canastrasLimpas': canastrasLimpas,
      };

  @override
  String toString() => 'LadoDaMesa($lado $pontos pts, $canastrasLimpas limpas)';
}

/// Desfecho canônico de uma partida. Somente leitura.
///
/// É o único formato pelo qual o Motor de Partidas fala do fim de uma partida
/// com o mundo. Tudo aqui já foi decidido em outro lugar: nada é calculado na
/// construção.
class DesfechoCanonicoPartida {
  final String partidaId;
  final EstadoEncerramento estado;

  /// `null` enquanto [estado] é [EstadoEncerramento.emAndamento] — partida que
  /// não acabou não tem motivo de ter acabado.
  final MotivoEncerramento? motivo;

  final List<LadoDaMesa> lados;

  /// `nos` | `eles`. `null` em partida anulada e em partida em andamento.
  final String? ladoVencedor;

  /// Instante do encerramento, em UTC, recebido por parâmetro.
  final DateTime encerradaEm;

  /// Versão do estado no momento da captura. Prova, junto de [impressaoEstado],
  /// sobre qual estado exato este desfecho foi tirado.
  final int versaoEstado;

  /// Impressão digital do estado do jogo (`MotorPartida.impressao`).
  final String impressaoEstado;

  /// A ordem que produziu o encerramento, quando houve. Viaja junto para a
  /// auditoria conseguir responder "quem mandou encerrar esta partida?".
  final OrdemDeEncerramento? ordem;

  DesfechoCanonicoPartida({
    required this.partidaId,
    required this.estado,
    required this.motivo,
    required List<LadoDaMesa> lados,
    required this.ladoVencedor,
    required DateTime encerradaEm,
    required this.versaoEstado,
    required this.impressaoEstado,
    this.ordem,
  })  : lados = List.unmodifiable(lados),
        encerradaEm = encerradaEm.toUtc() {
    if (partidaId.isEmpty) {
      throw ArgumentError.value(partidaId, 'partidaId', 'não pode ser vazio');
    }
    if (lados.length != 2) {
      throw ArgumentError.value(
          lados.length, 'lados', 'a mesa de buraco tem exatamente dois lados');
    }
    if (lados[0].lado == lados[1].lado) {
      throw ArgumentError.value(lados, 'lados', 'lado repetido');
    }
    if (estado == EstadoEncerramento.emAndamento) {
      if (motivo != null) {
        throw ArgumentError.value(
            motivo, 'motivo', 'partida em andamento não tem motivo de encerramento');
      }
      if (ladoVencedor != null) {
        throw ArgumentError.value(
            ladoVencedor, 'ladoVencedor', 'partida em andamento não tem vencedor');
      }
      return;
    }
    if (motivo == null) {
      throw ArgumentError.value(motivo, 'motivo',
          'partida encerrada sem motivo canônico — falha alta em vez de chute');
    }
    if (motivo == MotivoEncerramento.anulada) {
      if (ladoVencedor != null) {
        throw ArgumentError.value(
            ladoVencedor, 'ladoVencedor', 'partida anulada não tem vencedor');
      }
    } else if (ladoVencedor == null) {
      throw ArgumentError.value(
          ladoVencedor, 'ladoVencedor', 'obrigatório em ${motivo!.wire}');
    } else if (!lados.any((l) => l.lado == ladoVencedor)) {
      throw ArgumentError.value(
          ladoVencedor, 'ladoVencedor', 'não é um dos lados da mesa');
    }
  }

  /// Este desfecho pode virar resultado final?
  bool get conclusivo => estado == EstadoEncerramento.encerrada;

  LadoDaMesa? porLado(String lado) {
    for (final l in lados) {
      if (l.lado == lado) return l;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'partidaId': partidaId,
        'estado': estado.wire,
        'motivo': motivo?.wire,
        'lados': [for (final l in lados) l.toJson()],
        'ladoVencedor': ladoVencedor,
        'encerradaEm': encerradaEm.toIso8601String(),
        'versaoEstado': versaoEstado,
        'impressaoEstado': impressaoEstado,
        'ordem': ordem?.toJson(),
      };

  @override
  String toString() =>
      'DesfechoCanonicoPartida($partidaId ${estado.wire}${motivo == null ? '' : ' ${motivo!.wire}'})';
}

/// Tira o desfecho canônico de um [MotorPartida].
///
/// [encerradaEm] entra por parâmetro: este arquivo não lê relógio, pelo mesmo
/// motivo que o resto do motor não lê — teste não pode depender de esperar.
///
/// [ordem] é a única porta para encerramento não-natural. Sem ela, o desfecho só
/// pode ser [MotivoEncerramento.metaAtingida], e SÓ quando `Jogo.encerrada` for
/// verdadeiro. Se a mesa ainda está viva e não veio ordem nenhuma, o resultado é
/// [EstadoEncerramento.emAndamento] — nunca um encerramento inventado.
///
/// Repare no que NÃO é consultado: presença, heartbeat, relógio de turno,
/// comandos pendentes. Uma partida cujo jogador sumiu há dez minutos e outra em
/// que todos estão online produzem exatamente o mesmo desfecho enquanto a meta
/// não cair e ninguém declarar nada.
DesfechoCanonicoPartida capturarDesfecho(
  MotorPartida motor, {
  required DateTime encerradaEm,
  OrdemDeEncerramento? ordem,
}) {
  final jogo = motor.jogo;

  List<LadoDaMesa> montarLados() => [
        LadoDaMesa(
          lado: 'nos',
          assentos: const [0, 2],
          pontos: jogo.placar['nos'] ?? 0,
          canastrasLimpas: motor.canastrasLimpas['nos'] ?? 0,
        ),
        LadoDaMesa(
          lado: 'eles',
          assentos: const [1, 3],
          pontos: jogo.placar['eles'] ?? 0,
          canastrasLimpas: motor.canastrasLimpas['eles'] ?? 0,
        ),
      ];

  DesfechoCanonicoPartida construir({
    required EstadoEncerramento estado,
    required MotivoEncerramento? motivo,
    required String? ladoVencedor,
  }) =>
      DesfechoCanonicoPartida(
        partidaId: motor.partidaId,
        estado: estado,
        motivo: motivo,
        lados: montarLados(),
        ladoVencedor: ladoVencedor,
        encerradaEm: encerradaEm,
        versaoEstado: motor.versaoEstado,
        impressaoEstado: motor.impressao,
        ordem: ordem,
      );

  if (ordem != null) {
    // A autoridade falou. Vale mesmo com a mesa ainda viva — é justamente para
    // isso que encerramento administrativo e anulação existem.
    return construir(
      estado: EstadoEncerramento.encerrada,
      motivo: ordem.motivo,
      ladoVencedor: ordem.motivo == MotivoEncerramento.anulada
          ? null
          : ordem.ladoVencedor,
    );
  }

  if (!jogo.encerrada) {
    return construir(
      estado: EstadoEncerramento.emAndamento,
      motivo: null,
      ladoVencedor: null,
    );
  }

  // `Jogo.encerrada` só vira true quando alguém cruzou a meta E o placar não
  // está empatado (§9.2 de mesa.dart), então o vencedor é o maior placar e a
  // comparação não pode dar empate. Não há decisão nova sendo tomada aqui.
  final nos = jogo.placar['nos'] ?? 0;
  final eles = jogo.placar['eles'] ?? 0;
  if (nos == eles) {
    throw StateError(
        'partida ${motor.partidaId} marcada como encerrada com placar empatado '
        '($nos x $eles) — estado impossível, não há vencedor a deduzir');
  }
  return construir(
    estado: EstadoEncerramento.encerrada,
    motivo: MotivoEncerramento.metaAtingida,
    ladoVencedor: nos > eles ? 'nos' : 'eles',
  );
}
