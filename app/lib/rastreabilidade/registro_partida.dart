// registro_partida.dart — O QUE FICA GRAVADO SOBRE UMA PARTIDA (§5, §7, §22, §23).
//
// Este é o registro que responde à pergunta final da OS:
//
//   "O que aconteceu nesta partida, quem participou, qual foi o resultado?"
//
// TODOS OS CAMPOS SÃO SERVER-OWNED. Não existe construtor que aceite um mapa
// arbitrário do cliente: a única porta de entrada de dado externo é
// `ingestao.dart`, que valida campo a campo e recusa chave desconhecida. Aqui o
// tipo já chega pronto.
//
// O QUE ESTE ARQUIVO NÃO FAZ:
//   * não calcula placar — copia de `DesfechoCanonicoPartida`;
//   * não decide vencedor — copia;
//   * não decide abandono — só a autoridade declara (ver `OrdemDeEncerramento`);
//   * não altera ranking — isso é `ledger_competitivo.dart`, e é outra escrita.
//
// IMUTABILIDADE DO RESULTADO (§23): uma vez em estado terminal, a única
// transição permitida é... nenhuma. [RegistroDePartida.transicionarPara] recusa
// qualquer saída de terminal, e não há setter para placar, vencedor,
// participantes ou tipo. Correção administrativa é fluxo próprio, auditável, e
// não foi implementada nesta OS de propósito — ver a documentação.

import '../motor/desfecho_partida.dart';
import 'identidade_partida.dart';

/// O que uma pessoa (ou robô) é dentro da partida (§7).
///
/// A distinção existe para que nenhuma consulta some espectador com competidor,
/// e para que um sinal antifraude sobre "partidas contra bot" tenha como
/// separar bot de humano sem adivinhar pelo apelido.
enum ClasseDeParticipante {
  /// Jogador humano autenticado. É o único que tem `userId`.
  humano('humano'),

  /// Robô oficial conduzido pelo motor (`MotorPartida.conduzirRobo`).
  robo('robo'),

  /// Convidado sem conta, se o produto vier a oferecer isso. Ocupa assento e
  /// joga, mas não tem identidade persistente — logo, não pontua.
  convidado('convidado'),

  /// Assiste. NÃO ocupa assento e NUNCA aparece como competidor.
  espectador('espectador');

  final String wire;
  const ClasseDeParticipante(this.wire);

  /// Disputa a partida? Espectador não.
  bool get competidor => this != ClasseDeParticipante.espectador;

  /// Tem `userId` de conta autenticada?
  bool get autenticado => this == ClasseDeParticipante.humano;

  /// Pode receber lançamento no ledger competitivo?
  ///
  /// Só humano autenticado. Robô não tem ranking, convidado não tem conta onde
  /// gravar, espectador não jogou.
  bool get pontuavel => this == ClasseDeParticipante.humano;

  static ClasseDeParticipante? porWire(String wire) {
    for (final c in ClasseDeParticipante.values) {
      if (c.wire == wire) return c;
    }
    return null;
  }
}

/// Um participante da partida, como o registro o conhece.
class ParticipantePartida {
  final ClasseDeParticipante classe;

  /// UID da conta, presente apenas em [ClasseDeParticipante.humano].
  final String? userId;

  /// Identificador do robô oficial, presente apenas em
  /// [ClasseDeParticipante.robo]. Texto opaco (`bot-facil-3`), nunca um UID.
  final String? botId;

  /// Assento 0..3, como `Jogo` os numera. `null` para espectador.
  final int? assento;

  /// `participanteId` do torneio, quando a partida é de torneio. Vem do
  /// `VinculoDeMesa` — não é deduzido daqui.
  final String? participanteId;

  ParticipantePartida({
    required this.classe,
    this.userId,
    this.botId,
    this.assento,
    this.participanteId,
  }) {
    if (classe.competidor) {
      if (assento == null) {
        throw ArgumentError.value(assento, 'assento',
            '${classe.wire} é competidor e precisa de assento');
      }
      if (assento! < 0 || assento! > 3) {
        throw ArgumentError.value(assento, 'assento', 'fora de 0..3');
      }
    } else if (assento != null) {
      // A confusão que esta linha impede: um espectador com assento entraria em
      // toda consulta "quem jogou nesta mesa" e apareceria na classificação
      // como se tivesse disputado.
      throw ArgumentError.value(
          assento, 'assento', 'espectador não ocupa assento');
    }

    switch (classe) {
      case ClasseDeParticipante.humano:
      case ClasseDeParticipante.espectador:
        if (userId == null || userId!.isEmpty) {
          throw ArgumentError.value(
              userId, 'userId', '${classe.wire} exige userId');
        }
        if (botId != null) {
          throw ArgumentError.value(
              botId, 'botId', '${classe.wire} não tem botId');
        }
      case ClasseDeParticipante.robo:
        if (botId == null || botId!.isEmpty) {
          throw ArgumentError.value(botId, 'botId', 'robô exige botId');
        }
        // Um robô com `userId` seria um humano disfarçado no relatório — e é
        // exatamente a troca que §7 proíbe o cliente de fazer.
        if (userId != null) {
          throw ArgumentError.value(
              userId, 'userId', 'robô não tem conta de usuário');
        }
      case ClasseDeParticipante.convidado:
        if (userId != null) {
          throw ArgumentError.value(
              userId, 'userId', 'convidado não tem conta autenticada');
        }
        if (botId != null) {
          throw ArgumentError.value(botId, 'botId', 'convidado não é robô');
        }
    }
  }

  /// `nos` | `eles`, pela lei de assentos de `Jogo`: pares são `nos`, ímpares
  /// são `eles`. `null` para espectador. Não é convenção desta camada — é
  /// leitura da mesa, e por isso não é parametrizável.
  String? get lado =>
      assento == null ? null : (assento!.isEven ? 'nos' : 'eles');

  /// Como este participante aparece em log e consulta: `userId` para humano,
  /// `botId` para robô, `participanteId` para convidado sem nenhum dos dois.
  String get chave => userId ?? botId ?? participanteId ?? 'assento-$assento';

  Map<String, Object?> toJson() => {
        'classe': classe.wire,
        'userId': userId,
        'botId': botId,
        'assento': assento,
        'lado': lado,
        'participanteId': participanteId,
      };

  static ParticipantePartida deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('participante: objeto esperado.');
    }
    final classe = ClasseDeParticipante.porWire('${raw['classe']}');
    if (classe == null) {
      throw FormatException('participante: classe desconhecida "${raw['classe']}".');
    }
    final assento = raw['assento'];
    if (assento != null && assento is! num) {
      throw FormatException('participante: assento deve ser numérico (recebido: $assento).');
    }
    try {
      return ParticipantePartida(
        classe: classe,
        userId: raw['userId'] as String?,
        botId: raw['botId'] as String?,
        assento: assento == null ? null : (assento as num).toInt(),
        participanteId: raw['participanteId'] as String?,
      );
    } on ArgumentError catch (e) {
      throw FormatException('participante: ${e.message}');
    }
  }

  @override
  String toString() =>
      'ParticipantePartida(${classe.wire} $chave${assento == null ? '' : ' @$assento'})';
}

/// Estados formais da partida (§22).
///
/// Cada um corresponde a algo que a arquitetura JÁ distingue — nenhum estado
/// foi inventado para preencher a lista da OS:
///
///   criada        → `RegistroDePartidas.abrir` devolveu o motor, ninguém sentou
///   aguardando    → há assento vazio esperando jogador
///   ativa         → `Jogo` em disputa
///   reconectando  → `MapaPresenca` tem assento não-terminal fora de `online`
///   finalizada    → `DesfechoCanonicoPartida.conclusivo` com motivo natural/admin
///   abandonada    → idem, com `MotivoEncerramento.abandono`
///   cancelada     → `RegistroDePartidas.cancelar` ou `MotivoEncerramento.anulada`
enum EstadoDaPartida {
  criada('criada'),
  aguardando('aguardando'),
  ativa('ativa'),
  reconectando('reconectando'),
  finalizada('finalizada'),
  abandonada('abandonada'),
  cancelada('cancelada');

  final String wire;
  const EstadoDaPartida(this.wire);

  /// Depois deste estado não há mais nada. §23: resultado imutável.
  bool get terminal =>
      this == EstadoDaPartida.finalizada ||
      this == EstadoDaPartida.abandonada ||
      this == EstadoDaPartida.cancelada;

  /// Este desfecho contou como partida disputada? `cancelada` não.
  bool get valeu => this == EstadoDaPartida.finalizada ||
      this == EstadoDaPartida.abandonada;

  static EstadoDaPartida? porWire(String wire) {
    for (final e in EstadoDaPartida.values) {
      if (e.wire == wire) return e;
    }
    return null;
  }

  /// O grafo. Escrito por extenso para ser conferido de relance, e não montado
  /// por regra implícita.
  static const Map<EstadoDaPartida, List<EstadoDaPartida>> transicoes = {
    criada: [aguardando, ativa, cancelada],
    aguardando: [ativa, cancelada, abandonada],
    // `ativa → aguardando` NÃO existe: um assento que esvaziou no meio da
    // partida é `reconectando`, e virar `aguardando` de novo faria a mesa
    // parecer que nunca começou.
    ativa: [reconectando, finalizada, abandonada, cancelada],
    reconectando: [ativa, finalizada, abandonada, cancelada],
    finalizada: [],
    abandonada: [],
    cancelada: [],
  };

  bool podeIrPara(EstadoDaPartida destino) =>
      (transicoes[this] ?? const []).contains(destino);
}

/// Por que uma transição foi recusada.
class TransicaoInvalida implements Exception {
  final EstadoDaPartida de;
  final EstadoDaPartida para;
  final String motivo;
  const TransicaoInvalida(this.de, this.para, this.motivo);

  @override
  String toString() =>
      'TransicaoInvalida(${de.wire} → ${para.wire}): $motivo';
}

/// Placar final de um lado, copiado do desfecho canônico.
class PlacarDoLado {
  /// `nos` | `eles`.
  final String lado;
  final int pontos;
  final int canastrasLimpas;
  final List<int> assentos;

  PlacarDoLado({
    required this.lado,
    required this.pontos,
    required this.canastrasLimpas,
    required List<int> assentos,
  }) : assentos = List.unmodifiable(assentos);

  /// Lê direto do desfecho do Motor de Partidas. Cópia, não recálculo.
  factory PlacarDoLado.doDesfecho(LadoDaMesa lado) => PlacarDoLado(
        lado: lado.lado,
        pontos: lado.pontos,
        canastrasLimpas: lado.canastrasLimpas,
        assentos: lado.assentos,
      );

  Map<String, Object?> toJson() => {
        'lado': lado,
        'pontos': pontos,
        'canastrasLimpas': canastrasLimpas,
        'assentos': assentos,
      };

  static PlacarDoLado deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('placar: objeto esperado.');
    }
    final pontos = raw['pontos'];
    final canastras = raw['canastrasLimpas'];
    if (pontos is! num) {
      throw FormatException('placar: pontos deve ser numérico (recebido: $pontos).');
    }
    if (canastras is! num || canastras < 0) {
      throw FormatException('placar: canastrasLimpas >= 0 esperado (recebido: $canastras).');
    }
    final assentos = raw['assentos'];
    return PlacarDoLado(
      lado: '${raw['lado']}',
      pontos: pontos.toInt(),
      canastrasLimpas: canastras.toInt(),
      assentos: [
        if (assentos is List)
          for (final a in assentos)
            if (a is num) a.toInt(),
      ],
    );
  }
}

/// O registro auditável de uma partida (§5).
///
/// Imutável: toda mudança devolve uma NOVA instância. Isso não é preferência de
/// estilo — é o que torna impossível uma camada de cima "corrigir" o placar de
/// um registro que outra camada já leu.
class RegistroDePartida {
  final IdentidadePartida identidade;
  final EstadoDaPartida estado;

  /// Participantes, competidores e espectadores. Congelado na criação e nunca
  /// reescrito: §23 e §26 proíbem o cliente de inserir participante depois.
  final List<ParticipantePartida> participantes;

  /// Quando a mesa abriu (a partida existe). Sempre presente.
  final DateTime criadaEm;

  /// Quando a disputa começou de fato. `null` enquanto ninguém jogou.
  final DateTime? iniciadaEm;

  /// Quando encerrou. `null` até o encerramento.
  final DateTime? encerradaEm;

  /// Motivo canônico do encerramento, copiado do Motor de Partidas. `null`
  /// enquanto a partida vive.
  final MotivoEncerramento? motivoEncerramento;

  /// Quem declarou o encerramento não-natural, copiado de
  /// `OrdemDeEncerramento.autoridade`. `null` em encerramento por meta.
  final String? autoridadeDoEncerramento;

  /// `nos` | `eles`. `null` em partida viva, anulada ou cancelada.
  final String? ladoVencedor;

  /// Placar final por lado. Vazio enquanto a partida não encerrou.
  final List<PlacarDoLado> placar;

  /// Meta de pontos que valia. Copiada do desfecho.
  final int metaPontos;

  /// Quantas rodadas a partida teve.
  final int rodadas;

  /// `MotorPartida.versaoEstado` no encerramento — o ponto exato da linha do
  /// tempo em que este registro foi tirado.
  final int versaoEstadoFinal;

  /// `MotorPartida.impressaoPartida`. É o que permite provar, depois, que o
  /// registro corresponde ao estado que o motor tinha — e não a uma versão
  /// reescrita.
  final String? impressaoEstado;

  /// Assento 0..3 de quem executou a batida que encerrou a última rodada
  /// apurada, copiado de `DesfechoCanonicoPartida.assentoQueBateuUltimaRodada`.
  ///
  /// `null` significa "não houve batida legal na última rodada" OU "o desfecho
  /// não trouxe o campo" — e as duas coisas se leem igual de propósito: nenhuma
  /// delas autoriza afirmar quem bateu. Quem decide conquista trata ausência
  /// como recusa, nunca como permissão.
  ///
  /// Combinado com [ladoVencedor] e [estado], é o que distingue "bateu na
  /// rodada que encerrou a partida e venceu" de "bateu numa rodada qualquer" e
  /// de "a dupla venceu, mas quem bateu foi o parceiro".
  final int? assentoQueBateuFinal;

  /// Vínculo com o torneio, quando houver. Só os identificadores.
  final String? tournamentId;
  final String? editionId;
  final String? faseId;
  final String? mesaId;

  /// Versão do formato deste registro.
  static const int versaoFormato = 1;

  RegistroDePartida._({
    required this.identidade,
    required this.estado,
    required List<ParticipantePartida> participantes,
    required this.criadaEm,
    required this.iniciadaEm,
    required this.encerradaEm,
    required this.motivoEncerramento,
    required this.autoridadeDoEncerramento,
    required this.ladoVencedor,
    required List<PlacarDoLado> placar,
    required this.metaPontos,
    required this.rodadas,
    required this.versaoEstadoFinal,
    required this.impressaoEstado,
    required this.assentoQueBateuFinal,
    required this.tournamentId,
    required this.editionId,
    required this.faseId,
    required this.mesaId,
  })  : participantes = List.unmodifiable(participantes),
        placar = List.unmodifiable(placar);

  /// Abre o registro de uma partida recém-criada.
  ///
  /// Valida as invariantes de composição da mesa, que são as que §7 e §26
  /// protegem: assento único, sem duplicata de conta, e o competidor humano
  /// jamais confundido com robô.
  factory RegistroDePartida.abrir({
    required IdentidadePartida identidade,
    required List<ParticipantePartida> participantes,
    required int metaPontos,
    String? tournamentId,
    String? editionId,
    String? faseId,
    String? mesaId,
  }) {
    if (metaPontos < 1) {
      throw ArgumentError.value(metaPontos, 'metaPontos', 'deve ser >= 1');
    }

    final assentos = <int, ParticipantePartida>{};
    final contas = <String>{};
    for (final p in participantes) {
      if (p.assento != null) {
        final dono = assentos[p.assento];
        if (dono != null) {
          throw ArgumentError.value(p.assento, 'assento',
              'assento ${p.assento} declarado para ${p.chave} e para ${dono.chave}');
        }
        assentos[p.assento!] = p;
      }
      if (p.userId != null && !contas.add(p.userId!)) {
        // A mesma conta em dois assentos é a forma mais simples de auto-jogo:
        // dois "jogadores" que são a mesma pessoa, um entregando a partida ao
        // outro. Recusar na abertura é mais barato que detectar no ledger.
        throw ArgumentError.value(p.userId, 'userId',
            'a conta ${p.userId} aparece mais de uma vez na mesma partida');
      }
    }

    if (identidade.tipo == TipoDePartida.torneio) {
      if (tournamentId == null || editionId == null || faseId == null || mesaId == null) {
        throw ArgumentError.value(
            identidade.tipo.wire,
            'tipo',
            'partida de torneio exige tournamentId, editionId, faseId e mesaId — '
                'sem eles o resultado não sabe a que competição pertence');
      }
    } else if (tournamentId != null || editionId != null) {
      // O caminho inverso importa tanto quanto: uma partida casual carimbada
      // com torneio entraria em consultas de classificação.
      throw ArgumentError.value(tournamentId, 'tournamentId',
          'partida ${identidade.tipo.wire} não pertence a torneio');
    }

    return RegistroDePartida._(
      identidade: identidade,
      estado: EstadoDaPartida.criada,
      participantes: participantes,
      criadaEm: identidade.criadaEm,
      iniciadaEm: null,
      encerradaEm: null,
      motivoEncerramento: null,
      autoridadeDoEncerramento: null,
      ladoVencedor: null,
      placar: const [],
      metaPontos: metaPontos,
      rodadas: 0,
      versaoEstadoFinal: 0,
      impressaoEstado: null,
      // Partida recém-aberta não teve batida nenhuma.
      assentoQueBateuFinal: null,
      tournamentId: tournamentId,
      editionId: editionId,
      faseId: faseId,
      mesaId: mesaId,
    );
  }

  String get matchId => identidade.matchId;
  TipoDePartida get tipo => identidade.tipo;

  /// Esta partida pode gerar lançamento competitivo?
  ///
  /// Duas condições, e as DUAS precisam valer: o tipo tem que pontuar E a
  /// partida tem que ter valido (§ anulada/cancelada não pontua para ninguém).
  bool get alteraRanking => identidade.alteraRanking && estado.valeu;

  /// Competidores, na ordem dos assentos. Espectador fica de fora — é o
  /// critério de §7 aplicado em um lugar só.
  List<ParticipantePartida> get competidores {
    final l = participantes.where((p) => p.classe.competidor).toList()
      ..sort((a, b) => a.assento! - b.assento!);
    return List.unmodifiable(l);
  }

  List<ParticipantePartida> get espectadores => List.unmodifiable(
      participantes.where((p) => !p.classe.competidor).toList());

  bool get temRobo =>
      participantes.any((p) => p.classe == ClasseDeParticipante.robo);

  ParticipantePartida? porAssento(int assento) {
    for (final p in participantes) {
      if (p.assento == assento) return p;
    }
    return null;
  }

  ParticipantePartida? porUserId(String userId) {
    for (final p in participantes) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  /// O lado do jogador nesta partida, ou `null` se ele não competiu.
  String? ladoDe(String userId) {
    final p = porUserId(userId);
    return p != null && p.classe.competidor ? p.lado : null;
  }

  PlacarDoLado? placarDe(String lado) {
    for (final p in placar) {
      if (p.lado == lado) return p;
    }
    return null;
  }

  /// Move o registro no grafo de estados.
  ///
  /// IDEMPOTENTE por construção: transicionar para o estado em que já se está
  /// devolve o mesmo registro, sem erro. É o que faz um callback repetido
  /// convergir em vez de estourar (§20).
  RegistroDePartida transicionarPara(
    EstadoDaPartida destino, {
    DateTime? em,
  }) {
    if (destino == estado) return this;
    if (estado.terminal) {
      throw TransicaoInvalida(estado, destino,
          'partida em estado terminal não muda mais — §23, resultado imutável');
    }
    if (!estado.podeIrPara(destino)) {
      throw TransicaoInvalida(estado, destino, 'transição não prevista no grafo');
    }
    return _copiar(
      estado: destino,
      iniciadaEm: destino == EstadoDaPartida.ativa && iniciadaEm == null
          ? (em ?? criadaEm)
          : iniciadaEm,
    );
  }

  /// Grava o encerramento a partir do desfecho canônico do Motor de Partidas.
  ///
  /// TUDO É CÓPIA. Nenhum número é recalculado, nenhum vencedor é deduzido: o
  /// desfecho já resolveu isso e ele é a autoridade (ver `capturarDesfecho`).
  ///
  /// IDEMPOTENTE: aplicar duas vezes o MESMO desfecho devolve o registro já
  /// encerrado, sem erro e sem alteração. Aplicar um desfecho DIFERENTE sobre
  /// um registro encerrado é recusado — é a corrida de §20 sendo resolvida a
  /// favor de quem chegou primeiro, que é o único critério que converge.
  RegistroDePartida encerrarCom(DesfechoCanonicoPartida desfecho) {
    if (desfecho.partidaId != matchId) {
      throw ArgumentError.value(desfecho.partidaId, 'partidaId',
          'o desfecho é da partida ${desfecho.partidaId} e o registro é da $matchId');
    }
    if (!desfecho.conclusivo) {
      throw ArgumentError.value(desfecho.estado.wire, 'estado',
          'desfecho em andamento não encerra registro');
    }

    final destino = switch (desfecho.motivo!) {
      MotivoEncerramento.metaAtingida => EstadoDaPartida.finalizada,
      MotivoEncerramento.encerradaPorAdmin => EstadoDaPartida.finalizada,
      MotivoEncerramento.abandono => EstadoDaPartida.abandonada,
      MotivoEncerramento.anulada => EstadoDaPartida.cancelada,
    };

    if (estado.terminal) {
      // Reenvio. Convergente se for o mesmo desfecho; recusa alta se for outro,
      // porque aceitar o segundo reescreveria um resultado já publicado.
      if (estado == destino &&
          motivoEncerramento == desfecho.motivo &&
          ladoVencedor == desfecho.ladoVencedor &&
          impressaoEstado == desfecho.impressaoEstado) {
        return this;
      }
      throw TransicaoInvalida(estado, destino,
          'a partida $matchId já encerrou como ${estado.wire}'
          '${motivoEncerramento == null ? '' : ' (${motivoEncerramento!.wire})'}; '
          'um segundo desfecho divergente não reescreve resultado publicado');
    }

    return _copiar(
      estado: destino,
      encerradaEm: desfecho.encerradaEm,
      // Uma partida que encerra sem nunca ter sido marcada como ativa (a
      // autoridade anulou antes de começar) ganha `iniciadaEm` nulo, e isso é
      // informação, não lacuna: ela realmente não começou.
      iniciadaEm: iniciadaEm,
      motivoEncerramento: desfecho.motivo,
      autoridadeDoEncerramento: desfecho.ordem?.autoridade,
      ladoVencedor: desfecho.ladoVencedor,
      placar: [for (final l in desfecho.lados) PlacarDoLado.doDesfecho(l)],
      rodadas: desfecho.rodada,
      versaoEstadoFinal: desfecho.versaoEstado,
      impressaoEstado: desfecho.impressaoEstado,
      assentoQueBateuFinal: desfecho.assentoQueBateuUltimaRodada,
    );
  }

  RegistroDePartida _copiar({
    EstadoDaPartida? estado,
    DateTime? iniciadaEm,
    DateTime? encerradaEm,
    MotivoEncerramento? motivoEncerramento,
    String? autoridadeDoEncerramento,
    String? ladoVencedor,
    List<PlacarDoLado>? placar,
    int? rodadas,
    int? versaoEstadoFinal,
    String? impressaoEstado,
    int? assentoQueBateuFinal,
  }) =>
      RegistroDePartida._(
        identidade: identidade,
        estado: estado ?? this.estado,
        participantes: participantes,
        criadaEm: criadaEm,
        iniciadaEm: iniciadaEm ?? this.iniciadaEm,
        encerradaEm: encerradaEm ?? this.encerradaEm,
        motivoEncerramento: motivoEncerramento ?? this.motivoEncerramento,
        autoridadeDoEncerramento:
            autoridadeDoEncerramento ?? this.autoridadeDoEncerramento,
        ladoVencedor: ladoVencedor ?? this.ladoVencedor,
        placar: placar ?? this.placar,
        metaPontos: metaPontos,
        rodadas: rodadas ?? this.rodadas,
        versaoEstadoFinal: versaoEstadoFinal ?? this.versaoEstadoFinal,
        impressaoEstado: impressaoEstado ?? this.impressaoEstado,
        assentoQueBateuFinal: assentoQueBateuFinal ?? this.assentoQueBateuFinal,
        tournamentId: tournamentId,
        editionId: editionId,
        faseId: faseId,
        mesaId: mesaId,
      );

  /// UIDs dos humanos que competiram. É o campo pelo qual o histórico do
  /// jogador é consultado — ver `firestore.indexes.json`.
  List<String> get userIdsCompetidores {
    final l = <String>[
      for (final p in competidores)
        if (p.userId != null) p.userId!,
    ]..sort();
    return List.unmodifiable(l);
  }

  Map<String, Object?> toJson() => {
        'matchId': matchId,
        'identidade': identidade.toJson(),
        'estado': estado.wire,
        'tipo': tipo.wire,
        'participantes': [for (final p in participantes) p.toJson()],
        // Denormalizado de propósito: `array-contains` não alcança campo dentro
        // de objeto aninhado, e sem esta lista o histórico do jogador só sairia
        // varrendo a coleção inteira — que é o que §36 proíbe.
        'userIdsCompetidores': userIdsCompetidores,
        'criadaEm': criadaEm.toIso8601String(),
        'iniciadaEm': iniciadaEm?.toIso8601String(),
        'encerradaEm': encerradaEm?.toIso8601String(),
        'motivoEncerramento': motivoEncerramento?.wire,
        'autoridadeDoEncerramento': autoridadeDoEncerramento,
        'ladoVencedor': ladoVencedor,
        'placar': [for (final p in placar) p.toJson()],
        'metaPontos': metaPontos,
        'rodadas': rodadas,
        'versaoEstadoFinal': versaoEstadoFinal,
        'impressaoEstado': impressaoEstado,
        'assentoQueBateuFinal': assentoQueBateuFinal,
        'temRobo': temRobo,
        'alteraRanking': alteraRanking,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'faseId': faseId,
        'mesaId': mesaId,
        'versaoFormato': versaoFormato,
      };

  /// Relê um registro persistido, revalidando a estrutura.
  static RegistroDePartida deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('registro de partida: objeto esperado.');
    }
    final identidade = IdentidadePartida.deJson(raw['identidade']);
    final estado = EstadoDaPartida.porWire('${raw['estado']}');
    if (estado == null) {
      throw FormatException(
          'registro ${identidade.matchId}: estado desconhecido "${raw['estado']}".');
    }
    final brutos = raw['participantes'];
    if (brutos is! List) {
      throw FormatException(
          'registro ${identidade.matchId}: participantes deve ser lista.');
    }
    DateTime? data(String campo) {
      final v = raw[campo];
      if (v == null) return null;
      final d = DateTime.tryParse('$v');
      if (d == null) {
        throw FormatException(
            'registro ${identidade.matchId}: $campo não é ISO-8601 (recebido: $v).');
      }
      return d.toUtc();
    }

    int inteiro(String campo, int padrao) {
      final v = raw[campo];
      if (v == null) return padrao;
      if (v is! num) {
        throw FormatException(
            'registro ${identidade.matchId}: $campo deve ser numérico (recebido: $v).');
      }
      return v.toInt();
    }

    final motivoBruto = raw['motivoEncerramento'];
    MotivoEncerramento? motivo;
    if (motivoBruto != null) {
      motivo = MotivoEncerramento.porWire('$motivoBruto');
      if (motivo == null) {
        throw FormatException(
            'registro ${identidade.matchId}: motivo desconhecido "$motivoBruto".');
      }
    }
    final placarBruto = raw['placar'];
    // Sem `inteiro(...)`: ali "ausente" e "zero" viram a mesma coisa, e aqui
    // zero é um assento REAL. Ausência precisa continuar sendo nula até a
    // decisão, que é quem sabe o que fazer com "não sei".
    final assentoBatida = raw['assentoQueBateuFinal'];
    if (assentoBatida != null && assentoBatida is! num) {
      throw FormatException('registro ${identidade.matchId}: '
          'assentoQueBateuFinal deve ser numérico ou nulo (recebido: $assentoBatida).');
    }

    return RegistroDePartida._(
      identidade: identidade,
      estado: estado,
      participantes: [for (final p in brutos) ParticipantePartida.deJson(p)],
      criadaEm: data('criadaEm') ?? identidade.criadaEm,
      iniciadaEm: data('iniciadaEm'),
      encerradaEm: data('encerradaEm'),
      motivoEncerramento: motivo,
      autoridadeDoEncerramento: raw['autoridadeDoEncerramento'] as String?,
      ladoVencedor: raw['ladoVencedor'] as String?,
      placar: [
        if (placarBruto is List)
          for (final p in placarBruto) PlacarDoLado.deJson(p),
      ],
      metaPontos: inteiro('metaPontos', 1),
      rodadas: inteiro('rodadas', 0),
      versaoEstadoFinal: inteiro('versaoEstadoFinal', 0),
      impressaoEstado: raw['impressaoEstado'] as String?,
      assentoQueBateuFinal: (assentoBatida as num?)?.toInt(),
      tournamentId: raw['tournamentId'] as String?,
      editionId: raw['editionId'] as String?,
      faseId: raw['faseId'] as String?,
      mesaId: raw['mesaId'] as String?,
    );
  }

  @override
  String toString() =>
      'RegistroDePartida($matchId ${tipo.wire} ${estado.wire})';
}
