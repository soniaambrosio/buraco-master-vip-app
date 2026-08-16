// eventos_auditaveis.dart — A TRILHA TÉCNICA DA PARTIDA (§8, §9, §10).
//
// §9 É O ARQUIVO INTEIRO: "se o Motor de Partidas já possui eventId, janela de
// idempotência, versão de estado e trilha técnica, não criar um segundo
// protocolo concorrente".
//
// Ele possui. `DiarioPartida` (motor/diagnostico.dart) já registra ts, ação,
// assento, rodada, vez, eventoId, versão antes/depois, resultado e erro — e já
// censura conteúdo de carta. `MotorPartida` já tem janela de idempotência por
// `eventoId` e `versaoEstado` monotônico.
//
// Então este arquivo NÃO define eventos. Ele é um ADAPTADOR DE PERSISTÊNCIA:
// pega o que o diário já produziu, seleciona o que merece sobreviver ao fim da
// partida, e carimba o que o diário (que é de memória, circular e por partida)
// não tem como saber:
//
//   * `matchId`         — o diário tem `partidaId`; é o mesmo, e viaja adiante;
//   * `tsServidor`      — o diário carimba com a fonte de tempo injetada, que no
//                         cliente é o relógio do aparelho. O carimbo autoritativo
//                         entra AQUI, na ingestão, e é o que vale para auditoria;
//   * `eventId` estável — o diário só tem `eventoId` nos eventos de comando; os
//                         de ciclo (rodada, snapshot) não têm. Ver [_idDerivado];
//   * `esquema`/versão  — para um leitor futuro saber o formato.
//
// O QUE FICA DE FORA, DE PROPÓSITO: as jogadas individuais. §8 diz "não é
// necessário salvar cada detalhe irrelevante", e §15 pede política mínima. A
// linha exata está em [TipoEventoAuditavel.relevante] e é conferível.

import '../motor/desfecho_partida.dart';
import '../motor/diagnostico.dart';
import 'identidade_partida.dart';

/// Categorias de evento que sobrevivem ao fim da partida (§8).
///
/// Enum próprio, e não `TipoEvento` do diário, porque os dois recortes são
/// diferentes: o diário classifica pela NATUREZA técnica (comando, rejeição,
/// duplicado) e a auditoria classifica pelo MOMENTO DA VIDA da partida. Um
/// `TipoEvento.comando` com ação `RODADA_APURADA` é, para a auditoria, um fim de
/// rodada — não "mais um comando".
enum TipoEventoAuditavel {
  criacao('criacao'),
  inicio('inicio'),
  entradaParticipante('entrada_participante'),
  inicioRodada('inicio_rodada'),
  fimRodada('fim_rodada'),
  desconexao('desconexao'),
  reconexao('reconexao'),
  abandono('abandono'),
  encerramento('encerramento'),
  resultado('resultado'),
  alteracaoCompetitiva('alteracao_competitiva'),

  /// A mesa travou na auditoria de integridade do próprio motor
  /// (`Jogo.integridadeErro`). Crítico: é o evento que explica uma partida que
  /// parou sem ninguém ter saído.
  integridade('integridade'),

  /// Estado restaurado de snapshot depois de reinício. Não é reconexão de
  /// jogador — é o servidor voltando.
  restauracao('restauracao');

  final String wire;
  const TipoEventoAuditavel(this.wire);

  static TipoEventoAuditavel? porWire(String wire) {
    for (final t in TipoEventoAuditavel.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Quem provocou o evento.
///
/// Texto opaco com prefixo declarado, para que log e consulta consigam
/// distinguir sem tabela auxiliar. Nunca carrega e-mail nem token.
class AtorDoEvento {
  /// `jogador` | `robo` | `servidor` | `admin` | `sistema`.
  final String classe;

  /// Identificador dentro da classe: UID, botId, id do servidor. `null` quando
  /// o ator é o próprio sistema e não há sujeito.
  final String? id;

  /// Assento, quando o ator estava sentado.
  final int? assento;

  const AtorDoEvento({required this.classe, this.id, this.assento});

  static const AtorDoEvento sistema = AtorDoEvento(classe: 'sistema');

  Map<String, Object?> toJson() => {
        'classe': classe,
        'id': id,
        'assento': assento,
      };

  static AtorDoEvento deJson(Object? raw) {
    if (raw is! Map) return sistema;
    final assento = raw['assento'];
    return AtorDoEvento(
      classe: '${raw['classe']}',
      id: raw['id'] as String?,
      assento: assento is num ? assento.toInt() : null,
    );
  }

  @override
  String toString() => 'AtorDoEvento($classe${id == null ? '' : ':$id'})';
}

/// Um evento auditável, pronto para persistir.
///
/// Imutável. O `eventId` é a CHAVE PRIMÁRIA no armazenamento — gravar duas
/// vezes o mesmo evento é a mesma escrita, e a duplicidade fica impossível por
/// construção em vez de por checagem. É a mesma disciplina que `rewardGrants`
/// já usa em torneios.
class EventoAuditavel {
  /// Único e estável. Ver [EventoAuditavel.doDiario] para como é derivado.
  final String eventId;

  final String matchId;
  final TipoEventoAuditavel tipo;

  /// Carimbo do SERVIDOR, em UTC. Recebido por parâmetro — esta camada não lê
  /// relógio, e o relógio do aparelho não é autoridade.
  final DateTime emServidor;

  /// Carimbo que o diário do motor registrou (epoch ms, fonte injetada).
  /// Guardado ao lado, e não no lugar, porque a diferença entre os dois é
  /// informação: um cliente com relógio muito adiantado é sinal técnico.
  final int? tsMotor;

  final AtorDoEvento ator;

  /// Número da rodada, quando aplicável.
  final int? rodada;

  /// `MotorPartida.versaoEstado` depois do evento.
  final int? versaoEstado;

  /// Metadados mínimos. JÁ SANITIZADOS na origem: o que vem do diário passou
  /// por `EventoDiagnostico._sanitizar`, que remove carta, mão, monte, apelido,
  /// e-mail, uid e token. Aqui só entram escalares — ver [_escalares].
  final Map<String, Object?> dados;

  /// Versão do esquema deste evento.
  static const int esquema = 1;

  EventoAuditavel({
    required this.eventId,
    required this.matchId,
    required this.tipo,
    required DateTime emServidor,
    required this.ator,
    this.tsMotor,
    this.rodada,
    this.versaoEstado,
    Map<String, Object?> dados = const {},
  })  : emServidor = emServidor.toUtc(),
        dados = _escalares(dados) {
    if (eventId.isEmpty) {
      throw ArgumentError.value(eventId, 'eventId', 'evento sem id não é idempotente');
    }
    if (matchId.isEmpty) {
      throw ArgumentError.value(matchId, 'matchId', 'evento sem partida não é rastreável');
    }
  }

  /// Chaves cujo conteúdo nunca é persistido (§15, §37).
  ///
  /// `EventoDiagnostico` tem uma lista equivalente, e esta NÃO a importa: a de
  /// lá é privada e torná-la pública seria mexer no Motor de Partidas, que §1
  /// proíbe. A duplicação é deliberada e as duas listas têm escopos diferentes —
  /// a do diário protege o log EM MEMÓRIA durante a partida, esta protege o que
  /// vai para o banco e fica lá. Por isso esta é um SUPERCONJUNTO: acrescenta
  /// `nome`, `avatar` e `ip`, que só fazem sentido na fronteira de persistência.
  ///
  /// Dependência declarada: se a lista do Motor crescer, esta precisa crescer
  /// junto. Há teste que prova que as chaves conhecidas do diário estão cobertas.
  static const Set<String> chavesCensuradas = {
    'mao', 'maos', 'cartas', 'monte', 'lixo', 'morto', 'mortos',
    'jogos', 'jogosnos', 'jogoseles', 'baralho',
    'apelido', 'apelidos', 'email', 'uid', 'token',
    'nome', 'avatar', 'ip',
  };

  /// Segunda barreira de privacidade (§15, §37).
  ///
  /// O diário já filtra. Repetir aqui não é redundância inútil: eventos também
  /// são construídos por [EventoAuditavel.deCiclo], que NÃO passa pelo diário,
  /// e um mapa aninhado é o caminho mais fácil para um dado privado escapar sem
  /// ninguém perceber.
  static Map<String, Object?> _escalares(Map<String, Object?> entrada) {
    final saida = <String, Object?>{};
    for (final e in entrada.entries) {
      if (chavesCensuradas.contains(e.key.toLowerCase())) {
        saida[e.key] = '<omitido>';
        continue;
      }
      final v = e.value;
      saida[e.key] =
          (v == null || v is num || v is bool || v is String) ? v : '<omitido>';
    }
    return Map.unmodifiable(saida);
  }

  /// Constrói um evento de ciclo de vida, que não nasce do diário do motor
  /// (criação da partida, entrada de participante, resultado, alteração
  /// competitiva). O [eventId] é fornecido por quem sabe torná-lo estável.
  factory EventoAuditavel.deCiclo({
    required IdentidadePartida identidade,
    required TipoEventoAuditavel tipo,
    required DateTime emServidor,
    required String sufixo,
    AtorDoEvento ator = AtorDoEvento.sistema,
    int? rodada,
    int? versaoEstado,
    Map<String, Object?> dados = const {},
  }) =>
      EventoAuditavel(
        eventId: '${identidade.matchId}:${tipo.wire}:$sufixo',
        matchId: identidade.matchId,
        tipo: tipo,
        emServidor: emServidor,
        ator: ator,
        rodada: rodada,
        versaoEstado: versaoEstado,
        dados: dados,
      );

  /// Traduz uma linha do diário do motor em evento auditável, ou devolve `null`
  /// se aquela linha não merece sobreviver.
  ///
  /// ESTE É O PONTO DE §9. O evento não é reinventado: `eventoId`, `versaoAntes`,
  /// `versaoDepois`, `rodada` e `dados` vêm prontos do motor. O que se acrescenta
  /// é o carimbo autoritativo e a classificação por momento de vida.
  static EventoAuditavel? doDiario(
    EventoDiagnostico e, {
    required DateTime emServidor,
    required int sequencia,
  }) {
    final tipo = _classificar(e);
    if (tipo == null) return null;
    return EventoAuditavel(
      eventId: _idDerivado(e, sequencia),
      matchId: e.partidaId,
      tipo: tipo,
      emServidor: emServidor,
      tsMotor: e.ts,
      ator: _ator(e),
      rodada: e.rodada,
      versaoEstado: e.versaoDepois ?? e.versaoAntes,
      dados: {
        'acao': e.acao,
        if (e.resultado != null) 'resultado': e.resultado,
        if (e.erro != null) 'erro': e.erro,
        if (e.versaoAntes != null) 'versaoAntes': e.versaoAntes,
        ...e.dados,
      },
    );
  }

  /// Converte um diário inteiro, na ordem, descartando o que não é auditável.
  ///
  /// [emServidor] é o instante em que a ingestão aconteceu — o mesmo para todos
  /// os eventos do lote, porque é quando o servidor os recebeu. A ordem interna
  /// continua legível por `tsMotor` e `versaoEstado`.
  static List<EventoAuditavel> doDiarioCompleto(
    DiarioPartida diario, {
    required DateTime emServidor,
  }) {
    final saida = <EventoAuditavel>[];
    var i = 0;
    for (final e in diario.eventos) {
      final convertido = doDiario(e, emServidor: emServidor, sequencia: i);
      i++;
      if (convertido != null) saida.add(convertido);
    }
    return saida;
  }

  /// Eventos de encerramento derivados do desfecho canônico.
  ///
  /// São dois, e não um, porque respondem a perguntas diferentes: `encerramento`
  /// diz que a mesa fechou e por quê; `resultado` diz qual foi o placar. Um
  /// suporte investigando "por que a partida acabou" e outro investigando "o
  /// placar está certo?" não deveriam depender do mesmo registro.
  static List<EventoAuditavel> doDesfecho(
    DesfechoCanonicoPartida desfecho, {
    required IdentidadePartida identidade,
    required DateTime emServidor,
  }) {
    if (!desfecho.conclusivo) return const [];
    final ordem = desfecho.ordem;
    final ator = ordem == null
        ? AtorDoEvento.sistema
        : AtorDoEvento(classe: 'servidor', id: ordem.autoridade);

    final encerramento = EventoAuditavel.deCiclo(
      identidade: identidade,
      tipo: desfecho.motivo == MotivoEncerramento.abandono
          ? TipoEventoAuditavel.abandono
          : TipoEventoAuditavel.encerramento,
      emServidor: emServidor,
      // Sufixo pela VERSÃO do estado, não por contador: dois encerramentos
      // concorrentes tirados do mesmo estado produzem o MESMO eventId, e a
      // segunda gravação é a mesma escrita (§20).
      sufixo: 'v${desfecho.versaoEstado}',
      ator: ator,
      rodada: desfecho.rodada,
      versaoEstado: desfecho.versaoEstado,
      dados: {
        'motivo': desfecho.motivo!.wire,
        'impressaoEstado': desfecho.impressaoEstado,
        if (ordem != null) 'autoridade': ordem.autoridade,
        if (ordem != null) 'declaradaEm': ordem.declaradaEm.toIso8601String(),
        if (ordem?.observacao != null) 'observacao': ordem!.observacao,
      },
    );

    final resultado = EventoAuditavel.deCiclo(
      identidade: identidade,
      tipo: TipoEventoAuditavel.resultado,
      emServidor: emServidor,
      sufixo: 'v${desfecho.versaoEstado}',
      ator: ator,
      rodada: desfecho.rodada,
      versaoEstado: desfecho.versaoEstado,
      dados: {
        'ladoVencedor': desfecho.ladoVencedor,
        'metaPontos': desfecho.metaPontos,
        for (final l in desfecho.lados) 'pontos_${l.lado}': l.pontos,
        for (final l in desfecho.lados) 'canastrasLimpas_${l.lado}': l.canastrasLimpas,
      },
    );

    return [encerramento, resultado];
  }

  /// A ação do diário vira qual categoria auditável? `null` = descartar.
  ///
  /// A lista é branca, não preta: uma ação nova do motor cai fora da trilha até
  /// alguém decidir que ela pertence a ela. É a escolha certa para uma trilha
  /// que não pode inchar sozinha (§36) — o risco de perder um evento novo é
  /// menor que o de persistir jogada a jogada de toda partida do sistema.
  static TipoEventoAuditavel? _classificar(EventoDiagnostico e) {
    switch (e.tipo) {
      case TipoEvento.integridade:
        return TipoEventoAuditavel.integridade;
      case TipoEvento.snapshot:
        return TipoEventoAuditavel.restauracao;
      case TipoEvento.reconexao:
        return TipoEventoAuditavel.reconexao;
      case TipoEvento.presenca:
        return TipoEventoAuditavel.desconexao;
      case TipoEvento.rodada:
        if (e.acao == 'RODADA_INICIADA') return TipoEventoAuditavel.inicioRodada;
        if (e.acao == 'RODADA_APURADA') return TipoEventoAuditavel.fimRodada;
        return null;
      case TipoEvento.comando:
      case TipoEvento.rejeicao:
      case TipoEvento.duplicado:
      case TipoEvento.relogio:
      case TipoEvento.partida:
        // Jogada a jogada NÃO entra: são centenas por partida e o valor de
        // auditoria delas é a reclamação em tempo real, que o diário já atende
        // enquanto a partida vive. O que sobrevive é o esqueleto.
        return null;
    }
  }

  static AtorDoEvento _ator(EventoDiagnostico e) {
    if (e.acao == 'TURNO_ROBO') {
      return AtorDoEvento(classe: 'robo', assento: e.assento);
    }
    if (e.assento != null) {
      return AtorDoEvento(classe: 'jogador', assento: e.assento);
    }
    return AtorDoEvento.sistema;
  }

  /// Id estável para uma linha do diário.
  ///
  /// Quando o motor deu um `eventoId` (comandos), ele é reaproveitado — é o
  /// MESMO id que a janela de idempotência do motor usa, então um reenvio
  /// produz o mesmo evento auditável. Quando não deu (ciclo de rodada,
  /// snapshot), o id é derivado de partida + ação + rodada + versão, que é
  /// determinístico e sobrevive a reprocessamento do mesmo diário.
  ///
  /// A [sequencia] entra apenas como desempate final, para o caso de duas
  /// linhas idênticas em tudo — cenário que não deveria existir, mas que, se
  /// existir, não pode fazer dois eventos colidirem em um.
  static String _idDerivado(EventoDiagnostico e, int sequencia) {
    if (e.eventoId != null && e.eventoId!.isNotEmpty) {
      return '${e.partidaId}:motor:${e.eventoId}';
    }
    final versao = e.versaoDepois ?? e.versaoAntes ?? 0;
    final rodada = e.rodada ?? 0;
    return '${e.partidaId}:${e.acao.toLowerCase()}:r$rodada:v$versao:$sequencia';
  }

  Map<String, Object?> toJson() => {
        'eventId': eventId,
        'matchId': matchId,
        'tipo': tipo.wire,
        'emServidor': emServidor.toIso8601String(),
        'tsMotor': tsMotor,
        'ator': ator.toJson(),
        'rodada': rodada,
        'versaoEstado': versaoEstado,
        'dados': dados,
        'esquema': esquema,
      };

  static EventoAuditavel deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('evento auditável: objeto esperado.');
    }
    final tipo = TipoEventoAuditavel.porWire('${raw['tipo']}');
    if (tipo == null) {
      throw FormatException('evento: tipo desconhecido "${raw['tipo']}".');
    }
    final em = DateTime.tryParse('${raw['emServidor']}');
    if (em == null) {
      throw FormatException(
          'evento: emServidor não é ISO-8601 (recebido: ${raw['emServidor']}).');
    }
    final ts = raw['tsMotor'];
    final rodada = raw['rodada'];
    final versao = raw['versaoEstado'];
    final dados = raw['dados'];
    return EventoAuditavel(
      eventId: '${raw['eventId']}',
      matchId: '${raw['matchId']}',
      tipo: tipo,
      emServidor: em,
      tsMotor: ts is num ? ts.toInt() : null,
      ator: AtorDoEvento.deJson(raw['ator']),
      rodada: rodada is num ? rodada.toInt() : null,
      versaoEstado: versao is num ? versao.toInt() : null,
      dados: dados is Map ? Map<String, Object?>.from(dados) : const {},
    );
  }

  @override
  String toString() => 'EventoAuditavel(${tipo.wire} $eventId)';
}

/// Trilha de eventos de uma partida, com idempotência por `eventId`.
///
/// Em produção isto é uma coleção do Firestore cujo id de documento É o
/// `eventId` — a mesma disciplina de `rewardGrants` e `tournamentTasks`. Esta
/// classe é a versão em memória, que serve ao app e aos testes, e que declara o
/// contrato que a coleção precisa honrar.
class TrilhaDeEventos {
  final String matchId;
  final Map<String, EventoAuditavel> _porId = {};
  final List<String> _ordem = [];

  TrilhaDeEventos(this.matchId);

  int get tamanho => _ordem.length;

  List<EventoAuditavel> get eventos =>
      List.unmodifiable([for (final id in _ordem) _porId[id]!]);

  bool contem(String eventId) => _porId.containsKey(eventId);

  /// Grava o evento. Devolve `true` se ESTA chamada foi a que gravou.
  ///
  /// O `false` é o que fecha retry, reconexão e callback repetido (§10): o
  /// chamador sabe que o efeito já existia e não precisa tratar como erro.
  bool registrar(EventoAuditavel e) {
    if (e.matchId != matchId) {
      throw ArgumentError.value(e.matchId, 'matchId',
          'evento da partida ${e.matchId} não entra na trilha de $matchId');
    }
    if (_porId.containsKey(e.eventId)) return false;
    _porId[e.eventId] = e;
    _ordem.add(e.eventId);
    return true;
  }

  /// Grava um lote. Devolve quantos eventos eram novos.
  int registrarTodos(Iterable<EventoAuditavel> lote) {
    var novos = 0;
    for (final e in lote) {
      if (registrar(e)) novos++;
    }
    return novos;
  }

  List<EventoAuditavel> porTipo(TipoEventoAuditavel tipo) =>
      List.unmodifiable(eventos.where((e) => e.tipo == tipo).toList());
}
