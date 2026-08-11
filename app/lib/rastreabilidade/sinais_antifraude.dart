// sinais_antifraude.dart — REGISTRAR EVIDÊNCIA PRIMEIRO, JULGAR DEPOIS (§16, §17).
//
// A REGRA FINAL DA OS, aplicada literalmente: este arquivo não sabe condenar.
// Não existe, em lugar nenhum dele:
//
//   * um campo `culpado`, `fraudador`, `trapaceiro` ou `multiConta`;
//   * uma função que suspenda, bloqueie, remova ou penalize alguém;
//   * um limiar que transforme score em decisão;
//   * qualquer escrita fora de [SinalAntifraude] e [RegistroDeSinais].
//
// O que existe é `suspectedPattern`: um SINAL, com tipo, evidência técnica,
// timestamp de servidor e um score opcional que é apenas a intensidade do
// próprio sinal — nunca uma probabilidade de culpa. Quem lê isso é um humano,
// ou uma regra formal que ainda não foi escrita e que não é assunto desta OS.
//
// POR QUE ISSO IMPORTA TECNICAMENTE, e não só eticamente: um detector
// automático construído sem dado histórico não tem como ser calibrado, e o
// primeiro falso positivo é uma conta legítima banida sem recurso. Coletar
// primeiro é o que torna a regra futura calibrável.
//
// §35 exige que o sinal NÃO gere punição. Há teste que percorre a API pública
// inteira deste arquivo e prova que nenhum símbolo produz efeito disciplinar.

import 'identidade_partida.dart';
import 'registro_partida.dart';

/// Categorias de sinal que a infraestrutura sabe carregar (§16).
///
/// Cada uma corresponde a um PADRÃO OBSERVÁVEL, descrito em termos do que os
/// dados mostram — e não do que se conclui deles. A diferença está nos nomes:
/// `mesmaDuplaRecorrente`, não `conluio`.
enum TipoDeSinal {
  /// As mesmas contas se enfrentam ou se emparelham com frequência acima do
  /// esperado para a população de mesas.
  mesmaDuplaRecorrente('mesma_dupla_recorrente'),

  /// Um par de contas concentra resultados num sentido só.
  resultadosConcentrados('resultados_concentrados'),

  /// Abandonos que acontecem em janela curta entre contas relacionadas.
  abandonoCoordenado('abandono_coordenado'),

  /// A conta abandona muito mais quando está perdendo do que quando está
  /// ganhando.
  abandonoAoPerder('abandono_ao_perder'),

  /// Contas distintas com padrão de uso muito correlacionado (horário, duração,
  /// sequência de mesas).
  contasCorrelacionadas('contas_correlacionadas'),

  /// Ganho de ranking concentrado em mesas de baixa competitividade.
  ganhoDeRankingAtipico('ganho_de_ranking_atipico'),

  /// Sequência de resultados improvável para a distribuição observada.
  sequenciaImprovavel('sequencia_improvavel'),

  /// Partida que altera ranking com robô entre os competidores, fora das
  /// modalidades em que robô é esperado.
  roboEmPartidaPontuada('robo_em_partida_pontuada'),

  /// Tentativas repetidas de enviar evento/resultado recusado pela validação.
  /// É o sinal de manipulação mais direto: o cliente está TENTANDO.
  manipulacaoDeEventoTentada('manipulacao_de_evento_tentada'),

  /// O relógio do cliente diverge muito do carimbo do servidor.
  divergenciaDeRelogio('divergencia_de_relogio');

  final String wire;
  const TipoDeSinal(this.wire);

  static TipoDeSinal? porWire(String wire) {
    for (final t in TipoDeSinal.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Quão forte é a observação — NÃO quão culpado é alguém.
///
/// A escala existe para o operador priorizar a fila de investigação, e o
/// vocabulário foi escolhido para não sugerir veredito: `alta` quer dizer "olhe
/// isto primeiro", não "isto é fraude".
enum IntensidadeSinal {
  baixa('baixa'),
  media('media'),
  alta('alta');

  final String wire;
  const IntensidadeSinal(this.wire);

  static IntensidadeSinal? porWire(String wire) {
    for (final i in IntensidadeSinal.values) {
      if (i.wire == wire) return i;
    }
    return null;
  }
}

/// Um sinal técnico associado a uma partida (§16).
///
/// Imutável, idempotente por [chaveIdempotencia] e SEM efeito disciplinar.
class SinalAntifraude {
  /// `matchId|tipo|alvo`. Determinística: o mesmo sinal recalculado sobre a
  /// mesma partida produz a mesma chave, e a segunda gravação é a mesma escrita.
  final String chaveIdempotencia;

  /// A partida a que o sinal se refere. Obrigatório — §35: "sinal é associado
  /// ao matchId". Um sinal sem partida não é investigável.
  final String matchId;

  final TipoDeSinal tipo;

  /// Contas observadas. Ordenada e sem repetição, para a chave ser estável.
  final List<String> alvos;

  /// Carimbo do SERVIDOR, em UTC. §35 exige explicitamente que seja
  /// server-side: um timestamp de cliente num registro antifraude é o primeiro
  /// dado que um adversário forjaria.
  final DateTime observadoEm;

  final IntensidadeSinal intensidade;

  /// Evidência técnica: os números que produziram a observação.
  ///
  /// Só escalares, e sanitizada — ver [_evidenciaLimpa]. É o que o operador lê
  /// para decidir se a observação se sustenta, e é o que §17 chama de
  /// "evidência técnica" em oposição a veredito.
  final Map<String, Object?> evidencia;

  /// Explicação curta do que foi observado, em linguagem descritiva.
  ///
  /// Convenção de redação, verificada em teste: descreve o DADO, não a pessoa.
  /// "12 das 14 partidas com a mesma dupla" — não "jogador combinando partidas".
  final String observacao;

  /// Quem calculou o sinal (`detector-v1`, `suporte:uid`). Nunca vazio: um
  /// sinal sem procedência não pode ser revisto quando o detector for corrigido.
  final String origem;

  static const int versaoFormato = 1;

  /// AFIRMAÇÃO ESTRUTURAL, e não comentário: este tipo não carrega veredito.
  ///
  /// Existe como constante para que o teste de §35 possa afirmá-la e para que
  /// quem for acrescentar um campo aqui tropece nela antes.
  static const bool geraPunicao = false;

  SinalAntifraude({
    required this.matchId,
    required this.tipo,
    required List<String> alvos,
    required DateTime observadoEm,
    required this.origem,
    required this.observacao,
    this.intensidade = IntensidadeSinal.baixa,
    Map<String, Object?> evidencia = const {},
  })  : alvos = List.unmodifiable(alvos.toSet().toList()..sort()),
        observadoEm = observadoEm.toUtc(),
        evidencia = _evidenciaLimpa(evidencia),
        chaveIdempotencia =
            '$matchId|${tipo.wire}|${(alvos.toSet().toList()..sort()).join(',')}' {
    if (matchId.isEmpty) {
      throw ArgumentError.value(matchId, 'matchId',
          'sinal sem partida não é investigável — §35 exige a associação');
    }
    if (alvos.isEmpty) {
      throw ArgumentError.value(
          alvos, 'alvos', 'sinal precisa dizer sobre quem é a observação');
    }
    if (origem.isEmpty) {
      throw ArgumentError.value(origem, 'origem',
          'sinal sem procedência não pode ser revisto quando o detector mudar');
    }
    if (observacao.isEmpty) {
      throw ArgumentError.value(observacao, 'observacao',
          'sinal sem descrição obriga quem investiga a adivinhar o critério');
    }
  }

  /// Chaves proibidas na evidência.
  ///
  /// Mesmo princípio de `eventos_auditaveis.dart`: uma evidência antifraude é
  /// justamente o lugar onde alguém seria tentado a "guardar tudo por via das
  /// dúvidas", e §15 proíbe repositório indiscriminado de informação privada.
  static const Set<String> chavesProibidas = {
    'cartas', 'mao', 'maos', 'monte', 'lixo', 'morto', 'mortos',
    'email', 'token', 'senha', 'ip', 'dispositivo', 'nome', 'apelido',
  };

  static Map<String, Object?> _evidenciaLimpa(Map<String, Object?> entrada) {
    final saida = <String, Object?>{};
    for (final e in entrada.entries) {
      if (chavesProibidas.contains(e.key.toLowerCase())) {
        saida[e.key] = '<omitido>';
        continue;
      }
      final v = e.value;
      saida[e.key] =
          (v == null || v is num || v is bool || v is String) ? v : '<omitido>';
    }
    return Map.unmodifiable(saida);
  }

  Map<String, Object?> toJson() => {
        'chaveIdempotencia': chaveIdempotencia,
        'matchId': matchId,
        // O nome do campo é `suspectedPattern`, e não `pattern`, exatamente como
        // §17 pede: quem ler o documento cru no banco lê "suspeita", não "fato".
        'suspectedPattern': tipo.wire,
        'alvos': alvos,
        'observadoEm': observadoEm.toIso8601String(),
        'intensidade': intensidade.wire,
        'evidencia': evidencia,
        'observacao': observacao,
        'origem': origem,
        // Gravado no documento de propósito: um leitor futuro (humano ou
        // consulta) não precisa conhecer este arquivo para saber que o registro
        // não é uma condenação.
        'geraPunicao': geraPunicao,
        'versaoFormato': versaoFormato,
      };

  static SinalAntifraude deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('sinal: objeto esperado.');
    }
    final tipo = TipoDeSinal.porWire('${raw['suspectedPattern']}');
    if (tipo == null) {
      throw FormatException(
          'sinal: padrão desconhecido "${raw['suspectedPattern']}".');
    }
    final quando = DateTime.tryParse('${raw['observadoEm']}');
    if (quando == null) {
      throw FormatException(
          'sinal: observadoEm não é ISO-8601 (recebido: ${raw['observadoEm']}).');
    }
    final alvos = raw['alvos'];
    if (alvos is! List) {
      throw const FormatException('sinal: alvos deve ser lista.');
    }
    final evidencia = raw['evidencia'];
    try {
      return SinalAntifraude(
        matchId: '${raw['matchId']}',
        tipo: tipo,
        alvos: [for (final a in alvos) '$a'],
        observadoEm: quando,
        origem: '${raw['origem']}',
        observacao: '${raw['observacao']}',
        intensidade: IntensidadeSinal.porWire('${raw['intensidade']}') ??
            IntensidadeSinal.baixa,
        evidencia:
            evidencia is Map ? Map<String, Object?>.from(evidencia) : const {},
      );
    } on ArgumentError catch (e) {
      throw FormatException('sinal: ${e.message}');
    }
  }

  @override
  String toString() =>
      'SinalAntifraude(${tipo.wire} em $matchId sobre ${alvos.length} conta(s))';
}

/// Onde os sinais ficam, com idempotência por chave (§35).
///
/// Em produção é a coleção `fraudSignals`, id de documento = chave. Aqui é a
/// versão em memória, e é ela que declara o contrato: registrar duas vezes o
/// mesmo sinal não cria dois registros.
class RegistroDeSinais {
  final Map<String, SinalAntifraude> _porChave = {};
  final List<String> _ordem = [];

  int get tamanho => _ordem.length;

  List<SinalAntifraude> get sinais =>
      List.unmodifiable([for (final c in _ordem) _porChave[c]!]);

  bool contem(String chave) => _porChave.containsKey(chave);

  /// Grava o sinal. `true` se esta chamada foi a que gravou.
  bool registrar(SinalAntifraude sinal) {
    if (_porChave.containsKey(sinal.chaveIdempotencia)) return false;
    _porChave[sinal.chaveIdempotencia] = sinal;
    _ordem.add(sinal.chaveIdempotencia);
    return true;
  }

  /// §14: sinais associados a uma partida, para a visão administrativa.
  List<SinalAntifraude> porMatchId(String matchId) => List.unmodifiable(
      sinais.where((s) => s.matchId == matchId).toList());

  /// Sinais que citam uma conta. NÃO é um veredito sobre ela — é a fila de
  /// investigação de quem for olhar.
  List<SinalAntifraude> sobre(String userId) => List.unmodifiable(
      sinais.where((s) => s.alvos.contains(userId)).toList());
}

// ---------------------------------------------------------------------------
// OBSERVADORES — os que a infraestrutura já consegue calcular hoje
// ---------------------------------------------------------------------------
//
// Cada função abaixo é PURA, recebe o que precisa por parâmetro e devolve
// `SinalAntifraude?`. Nenhuma delas lê banco, nenhuma escreve, nenhuma decide
// nada sobre ninguém. São as duas observações que os dados desta OS já
// sustentam sem depender de regra de produto; as outras oito categorias de
// [TipoDeSinal] existem para os detectores que virão, e a estrutura de registro
// delas está pronta e testada.

/// Robô entre os competidores de uma partida que altera ranking.
///
/// Observável AGORA, porque §7 passou a distinguir robô de humano e §6 passou a
/// registrar se a partida pontua. Antes desta OS, a pergunta era irrespondível.
///
/// Não é acusação: há motivos legítimos (substituição autoritativa por ausência,
/// ver `presenca.dart`). É informação para quem for calibrar a regra de "farm
/// contra bot".
SinalAntifraude? observarRoboEmPartidaPontuada({
  required RegistroDePartida registro,
  required DateTime observadoEm,
  String origem = 'detector-estrutural-v1',
}) {
  if (!registro.alteraRanking) return null;
  if (registro.tipo.roboEsperado) return null;
  final robos = registro.competidores
      .where((p) => p.classe == ClasseDeParticipante.robo)
      .toList();
  if (robos.isEmpty) return null;

  final humanos = [
    for (final p in registro.competidores)
      if (p.classe.pontuavel && p.userId != null) p.userId!,
  ];
  if (humanos.isEmpty) return null;

  return SinalAntifraude(
    matchId: registro.matchId,
    tipo: TipoDeSinal.roboEmPartidaPontuada,
    alvos: humanos,
    observadoEm: observadoEm,
    origem: origem,
    intensidade: IntensidadeSinal.baixa,
    observacao:
        '${robos.length} de ${registro.competidores.length} competidores são '
        'robôs numa partida ${registro.tipo.wire}, que altera ranking.',
    evidencia: {
      'robos': robos.length,
      'competidores': registro.competidores.length,
      'tipoPartida': registro.tipo.wire,
      'assentosDeRobo': robos.map((r) => r.assento).join(','),
    },
  );
}

/// Recorrência do mesmo par de contas em partidas que pontuam.
///
/// [partidasJuntos] e [partidasTotais] entram por parâmetro: quem conta é a
/// consulta indexada (`IndicePartidas.entre`), não esta função. Assim o cálculo
/// pesado fica fora do caminho crítico da partida, como §36 pede.
///
/// [limiarProporcao] é o corte da OBSERVAÇÃO, não do julgamento: abaixo dele
/// nem sinal se emite, porque um sinal que aparece para todo mundo não ajuda
/// ninguém a priorizar.
SinalAntifraude? observarMesmaDuplaRecorrente({
  required String matchId,
  required String userA,
  required String userB,
  required int partidasJuntos,
  required int partidasTotais,
  required DateTime observadoEm,
  double limiarProporcao = 0.6,
  int minimoAmostra = 10,
  String origem = 'detector-estrutural-v1',
}) {
  if (partidasTotais < minimoAmostra) return null;
  if (partidasJuntos <= 0) return null;
  final proporcao = partidasJuntos / partidasTotais;
  if (proporcao < limiarProporcao) return null;

  return SinalAntifraude(
    matchId: matchId,
    tipo: TipoDeSinal.mesmaDuplaRecorrente,
    alvos: [userA, userB],
    observadoEm: observadoEm,
    origem: origem,
    // A intensidade é função da própria observação. Não é probabilidade de
    // culpa: é o quanto o número se afasta do corte.
    intensidade: proporcao >= 0.9
        ? IntensidadeSinal.alta
        : (proporcao >= 0.75 ? IntensidadeSinal.media : IntensidadeSinal.baixa),
    observacao:
        '$partidasJuntos de $partidasTotais partidas foram entre as mesmas duas '
        'contas (${(proporcao * 100).toStringAsFixed(1)}%).',
    evidencia: {
      'partidasJuntos': partidasJuntos,
      'partidasTotais': partidasTotais,
      'proporcao': double.parse(proporcao.toStringAsFixed(4)),
      'limiarProporcao': limiarProporcao,
      'minimoAmostra': minimoAmostra,
    },
  );
}

/// Tentativa de manipulação: um envio recusado pela validação server-side.
///
/// É o único sinal que nasce de um EVENTO e não de uma estatística, e o mais
/// direto de todos — o cliente tentou escrever algo que a validação recusou.
/// Ainda assim não pune: uma versão desatualizada do app produz exatamente o
/// mesmo registro.
SinalAntifraude? observarManipulacaoTentada({
  required String matchId,
  required String userId,
  required String recusa,
  required DateTime observadoEm,
  String origem = 'ingestao-v1',
}) {
  if (recusa.isEmpty) return null;
  return SinalAntifraude(
    matchId: matchId,
    tipo: TipoDeSinal.manipulacaoDeEventoTentada,
    alvos: [userId],
    observadoEm: observadoEm,
    origem: origem,
    intensidade: IntensidadeSinal.media,
    observacao: 'envio recusado pela validação server-side ($recusa).',
    evidencia: {'recusa': recusa},
  );
}

/// Atalho para quem só quer saber a que partida um sinal pertence sem
/// desempacotar o objeto. Existe porque a consulta administrativa faz isso o
/// tempo todo.
String matchIdDoSinal(SinalAntifraude s) => s.matchId;

/// Re-exporta para quem consome só a camada de sinais.
typedef IdentidadeDaPartida = IdentidadePartida;
