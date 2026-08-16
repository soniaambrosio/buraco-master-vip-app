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

  /// Lê um lado da rede/persistência. Recusa envelope malformado — nunca
  /// completa com zero, porque `canastrasLimpas` ausente não é "nenhuma
  /// canastra": é dado perdido, e ele decide desempate de torneio.
  static LadoDaMesa deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('lado da mesa: objeto esperado.');
    }
    final lado = raw['lado'];
    if (lado is! String) {
      throw FormatException('lado da mesa: "lado" ausente (recebido: $lado).');
    }
    final pontos = raw['pontos'];
    if (pontos is! num) {
      throw FormatException('lado $lado: pontos deve ser numérico (recebido: $pontos).');
    }
    final canastras = raw['canastrasLimpas'];
    if (canastras is! num || canastras < 0) {
      throw FormatException(
          'lado $lado: canastrasLimpas deve ser >= 0 (recebido: $canastras).');
    }
    final assentos = raw['assentos'];
    if (assentos is! List) {
      throw FormatException('lado $lado: assentos deve ser lista (recebido: $assentos).');
    }
    return LadoDaMesa(
      lado: lado,
      assentos: [
        for (final a in assentos)
          if (a is num) a.toInt() else throw FormatException('lado $lado: assento não numérico ($a).'),
      ],
      pontos: pontos.toInt(),
      canastrasLimpas: canastras.toInt(),
    );
  }

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

  /// Meta de pontos que valia nesta partida (1500, 3000...).
  ///
  /// Viaja porque "1520 x 1180" só quer dizer alguma coisa contra a meta: sem
  /// ela, quem lê o desfecho depois não sabe se a partida era curta ou longa.
  final int metaPontos;

  /// `ABERTO` | `FECHADO` | `SBTL` — a modalidade jogada.
  final String modalidade;

  /// Quantas rodadas a partida teve até aqui.
  final int rodada;

  /// `nos` | `eles` | null — quem bateu na ÚLTIMA rodada apurada.
  ///
  /// Estritamente INFORMATIVO, e é por isso que ele não aparece em lugar nenhum
  /// da decisão de [ladoVencedor]: uma dupla pode bater a última rodada e ainda
  /// perder a partida no placar. Existe para o suporte reconstruir a narrativa
  /// ("acabou com batida de quem?"), nunca para decidir competição.
  final String? duplaQueBateuUltimaRodada;

  /// Assento 0..3 de QUEM bateu na última rodada apurada, ou `null` se a rodada
  /// terminou sem batida (baralho esgotado, abandono, anulação).
  ///
  /// POR QUE ELE EXISTE, já havendo [duplaQueBateuUltimaRodada]: a dupla não
  /// identifica a pessoa. Perguntas individuais — "foi você quem bateu?" — não
  /// têm resposta a partir do lado, e respondê-las por dedução premiaria o
  /// parceiro que não bateu. O motor já sabe o assento (`Jogo.assentoQueBateu`);
  /// até aqui ele era descartado na captura, e este campo é o que para de
  /// descartá-lo.
  ///
  /// É PROVA DE LEGALIDADE, e não só de autoria. `Jogo` só o preenche depois de
  /// aprovar a batida pela regra da modalidade (`duplaPodeBater`, que exige
  /// canastra — limpa no Aberto/STBL, qualquer uma no Fechado) e depois de
  /// esgotado o morto da dupla. As rodadas que terminam sem batida legal —
  /// baralho esgotado, monte e mortos vazios — deixam o campo nulo. Logo
  /// `assentoQueBateuUltimaRodada != null` é, por construção, "houve batida
  /// válida, e foi deste assento".
  ///
  /// CONTINUA FORA DA DECISÃO DE [ladoVencedor], pela mesma razão que o campo da
  /// dupla: bater a última rodada não é vencer a partida. Quem quiser as duas
  /// coisas juntas precisa checar as duas, e é exatamente isso que a conquista
  /// `primeira_batida_real` faz.
  ///
  /// Nulo também em desfecho antigo, gravado antes deste campo existir. Quem
  /// consome deve tratar ausência como "não sei", nunca como "não houve" — ver
  /// o fail-closed em `app/lib/conquistas/primeira_batida_real.dart`.
  final int? assentoQueBateuUltimaRodada;

  DesfechoCanonicoPartida({
    required this.partidaId,
    required this.estado,
    required this.motivo,
    required List<LadoDaMesa> lados,
    required this.ladoVencedor,
    required DateTime encerradaEm,
    required this.versaoEstado,
    required this.impressaoEstado,
    required this.metaPontos,
    required this.modalidade,
    required this.rodada,
    this.duplaQueBateuUltimaRodada,
    this.assentoQueBateuUltimaRodada,
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
    // Coerência do executor da batida. Vale em QUALQUER estado, inclusive em
    // andamento: um assento incoerente já é envelope corrompido antes de virar
    // resultado, e adiar a recusa só faria o erro aparecer mais longe da origem.
    final assentoBatida = assentoQueBateuUltimaRodada;
    if (assentoBatida != null) {
      if (assentoBatida < 0 || assentoBatida > 3) {
        throw ArgumentError.value(assentoBatida, 'assentoQueBateuUltimaRodada',
            'assento fora de 0..3');
      }
      if (duplaQueBateuUltimaRodada == null) {
        // Assento sem lado seria um executor que não pertence a dupla nenhuma —
        // e é justamente o par (quem, por qual lado) que a conquista confere.
        throw ArgumentError.value(
            assentoBatida,
            'assentoQueBateuUltimaRodada',
            'há assento que bateu mas nenhuma dupla declarada');
      }
      final ladoDaBatida = porLado(duplaQueBateuUltimaRodada!);
      if (ladoDaBatida == null) {
        throw ArgumentError.value(duplaQueBateuUltimaRodada,
            'duplaQueBateuUltimaRodada', 'não é um dos lados da mesa');
      }
      if (!ladoDaBatida.assentos.contains(assentoBatida)) {
        // A incoerência mais cara que existe aqui: creditar a batida a alguém do
        // lado adversário. Recusar é a única saída — não há como saber qual dos
        // dois campos está errado.
        throw ArgumentError.value(
            assentoBatida,
            'assentoQueBateuUltimaRodada',
            'o assento $assentoBatida não pertence ao lado '
                '${duplaQueBateuUltimaRodada!} (assentos ${ladoDaBatida.assentos})');
      }
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
        'metaPontos': metaPontos,
        'modalidade': modalidade,
        'rodada': rodada,
        'duplaQueBateuUltimaRodada': duplaQueBateuUltimaRodada,
        'assentoQueBateuUltimaRodada': assentoQueBateuUltimaRodada,
        'ordem': ordem?.toJson(),
      };

  /// Lê um desfecho da rede/persistência, validando o envelope.
  ///
  /// Recusa em vez de completar: um desfecho é o que decide classificação de
  /// torneio, então "veio pela metade" precisa parar aqui e não virar resultado
  /// silenciosamente errado. Toda recusa é [FormatException] — inclusive as
  /// incoerências que o construtor pega (vencedor que não é um dos lados,
  /// encerrada sem motivo), reembrulhadas para quem lê a rede ter UM tipo de
  /// erro a tratar.
  static DesfechoCanonicoPartida deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('desfecho: objeto esperado.');
    }
    final partidaId = raw['partidaId'];
    if (partidaId is! String || partidaId.isEmpty) {
      throw FormatException('desfecho: partidaId ausente (recebido: $partidaId).');
    }
    final estado = EstadoEncerramento.porWire('${raw['estado']}');
    if (estado == null) {
      throw FormatException('desfecho $partidaId: estado desconhecido "${raw['estado']}".');
    }
    final motivoBruto = raw['motivo'];
    MotivoEncerramento? motivo;
    if (motivoBruto != null) {
      motivo = MotivoEncerramento.porWire('$motivoBruto');
      if (motivo == null) {
        throw FormatException('desfecho $partidaId: motivo desconhecido "$motivoBruto".');
      }
    }
    final lados = raw['lados'];
    if (lados is! List) {
      throw FormatException('desfecho $partidaId: lados deve ser lista.');
    }
    final quando = DateTime.tryParse('${raw['encerradaEm']}');
    if (quando == null) {
      throw FormatException(
          'desfecho $partidaId: encerradaEm não é ISO-8601 (recebido: ${raw['encerradaEm']}).');
    }
    final versao = raw['versaoEstado'];
    if (versao is! num || versao < 0) {
      throw FormatException('desfecho $partidaId: versaoEstado inválida (recebido: $versao).');
    }
    final impressao = raw['impressaoEstado'];
    if (impressao is! String || impressao.isEmpty) {
      throw FormatException('desfecho $partidaId: impressaoEstado ausente.');
    }
    int inteiro(String chave) {
      final v = raw[chave];
      if (v is! num) {
        throw FormatException('desfecho $partidaId: $chave deve ser numérico (recebido: $v).');
      }
      return v.toInt();
    }

    final modalidade = raw['modalidade'];
    if (modalidade is! String || modalidade.isEmpty) {
      throw FormatException('desfecho $partidaId: modalidade ausente.');
    }
    final bateu = raw['duplaQueBateuUltimaRodada'];
    if (bateu != null && bateu != 'nos' && bateu != 'eles') {
      throw FormatException(
          'desfecho $partidaId: duplaQueBateuUltimaRodada deve ser nos|eles|null (recebido: $bateu).');
    }
    final ladoVencedor = raw['ladoVencedor'];
    if (ladoVencedor != null && ladoVencedor is! String) {
      throw FormatException('desfecho $partidaId: ladoVencedor deve ser texto ou nulo.');
    }
    // Ausente é aceito: desfecho gravado antes deste campo existir continua
    // legível. Presente e não-inteiro é recusado — um assento "2" em texto ou
    // um `true` são envelope corrompido, não campo opcional.
    final assentoBatida = raw['assentoQueBateuUltimaRodada'];
    if (assentoBatida != null && assentoBatida is! num) {
      throw FormatException('desfecho $partidaId: assentoQueBateuUltimaRodada '
          'deve ser numérico ou nulo (recebido: $assentoBatida).');
    }
    try {
      return DesfechoCanonicoPartida(
        partidaId: partidaId,
        estado: estado,
        motivo: motivo,
        lados: [for (final l in lados) LadoDaMesa.deJson(l)],
        ladoVencedor: ladoVencedor as String?,
        encerradaEm: quando,
        versaoEstado: versao.toInt(),
        impressaoEstado: impressao,
        metaPontos: inteiro('metaPontos'),
        modalidade: modalidade,
        rodada: inteiro('rodada'),
        duplaQueBateuUltimaRodada: bateu as String?,
        assentoQueBateuUltimaRodada: (assentoBatida as num?)?.toInt(),
        ordem: raw['ordem'] == null ? null : OrdemDeEncerramento.deJson(raw['ordem']),
      );
    } on ArgumentError catch (e) {
      throw FormatException('desfecho $partidaId: envelope incoerente — ${e.message}');
    }
  }

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
        // `impressaoPartida`, e não `impressao`: canastras limpas decidem
        // desempate de torneio e não estão no `Jogo`. Com a impressão só do
        // jogo, dois desfechos com o mesmo placar e canastras diferentes
        // teriam a mesma identidade — ver `MotorPartida.impressaoPartida`.
        impressaoEstado: motor.impressaoPartida,
        metaPontos: jogo.metaPontos,
        modalidade: jogo.modalidade,
        rodada: jogo.rodada,
        // Informativo. Note que ele NÃO participa de nenhuma decisão abaixo.
        duplaQueBateuUltimaRodada: jogo.duplaQueBateu,
        // O assento vem do MESMO ponto do motor que a dupla, no MESMO instante,
        // e por isso os dois não podem discordar: `Jogo` grava os dois juntos,
        // numa atribuição só, nos dois únicos caminhos em que aprova batida.
        // Copiar um e deduzir o outro é que criaria divergência.
        assentoQueBateuUltimaRodada: jogo.assentoQueBateu,
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
