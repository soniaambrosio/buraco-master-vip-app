// annual_closing.dart — torneio de encerramento do ano: registro de
// classificados, multiplas classificacoes e convites
// (OS 02 secoes 16, 17 e 18).
//
// Camada pura: sem Firestore, sem UI e sem relogio.
//
// AS DUAS ENTIDADES, E POR QUE SAO DUAS:
// - [RegistroClassificacaoAnual] e o FATO: "no dia 12/03 fulano ganhou vaga por
//   ter sido campeao da Copa". Um por conquista. Nunca some, nunca funde.
// - [ConviteEncerramento] e o DIREITO: "fulano esta convidado para o encerramento
//   de 2026". Um por jogador por temporada. E ele que a UI mostra.
//
// Essa separacao e o que resolve a OS 02 secao 17. Um jogador que se classifica
// tres vezes gera TRES registros e UM convite: o historico de todas as
// classificacoes fica preservado, e nao ha convite duplicado. Se as duas coisas
// fossem a mesma tabela, guardar o historico exigiria criar convites repetidos, e
// evitar convites repetidos exigiria apagar historico.
//
// O QUE NAO ESTA AQUI, DE PROPOSITO: a regra de redistribuicao da vaga repetida.
// A OS 02 secao 17 e explicita — "nao inventar regra para redistribuicao de vaga
// se isso nao estiver definido. Apenas preparar a estrutura correta". Os registros
// excedentes ficam marcados e consultaveis por [registrosExcedentes]; quando a
// administracao definir a regra, ela le essa lista. Nada aqui decide por ela.
//
// GERACAO DE ARTE: fora de escopo (OS 02 secao 18). Este arquivo fornece os dados
// que o cartao vai exibir; nao desenha nada.

/// Por que o jogador ganhou direito a vaga.
///
/// Os motivos vem do que a OS 02 secao 16 chama de "origem da classificacao".
/// Nenhum criterio de qualificacao foi inventado: qual colocacao em qual torneio
/// da vaga e configuracao, nao codigo.
enum OrigemClassificacaoAnual {
  /// Campeao de uma edicao.
  campeaoEdicao('campeao_edicao'),

  /// Vice-campeao de uma edicao.
  viceEdicao('vice_edicao'),

  /// Podio (terceiro colocado) de uma edicao.
  podioEdicao('podio_edicao'),

  /// Campeao de um Campeonato Mensal.
  campeaoMensal('campeao_mensal'),

  /// Indicacao administrativa, fora dos criterios automaticos.
  indicacaoAdministrativa('indicacao_administrativa');

  final String wire;
  const OrigemClassificacaoAnual(this.wire);

  static OrigemClassificacaoAnual? porWire(String wire) {
    for (final o in OrigemClassificacaoAnual.values) {
      if (o.wire == wire) return o;
    }
    return null;
  }
}

/// Estado do convite ao torneio de encerramento (OS 02 secao 18).
enum StatusConvite {
  /// Ganhou o direito; o convite ainda nao foi criado.
  elegivel('elegivel'),

  /// Criacao do convite enfileirada.
  convitePendente('convite_pendente'),

  /// Convite criado, ainda nao entregue.
  conviteGerado('convite_gerado'),

  /// Entregue ao jogador.
  conviteEnviado('convite_enviado'),

  conviteAceito('convite_aceito'),
  conviteRecusado('convite_recusado'),

  /// Presenca confirmada na edicao de encerramento.
  confirmado('confirmado'),

  /// Jogou.
  participou('participou'),

  /// Confirmou e nao compareceu.
  ausencia('ausencia');

  final String wire;
  const StatusConvite(this.wire);

  /// Nao ha transicao de saida.
  bool get terminal =>
      this == conviteRecusado || this == participou || this == ausencia;

  static StatusConvite? porWire(String wire) {
    for (final s in StatusConvite.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Grafo de transicoes do convite. Declarado como dado, pelo mesmo motivo de
/// tournament_lifecycle.dart: o conjunto de caminhos legais fica inspecionavel.
const Map<StatusConvite, Set<StatusConvite>> transicoesConvite = {
  StatusConvite.elegivel: {StatusConvite.convitePendente},
  StatusConvite.convitePendente: {StatusConvite.conviteGerado},
  StatusConvite.conviteGerado: {StatusConvite.conviteEnviado},
  StatusConvite.conviteEnviado: {
    StatusConvite.conviteAceito,
    StatusConvite.conviteRecusado,
  },
  StatusConvite.conviteAceito: {
    StatusConvite.confirmado,
    // Aceitou e desistiu antes de confirmar presenca.
    StatusConvite.conviteRecusado,
  },
  StatusConvite.confirmado: {StatusConvite.participou, StatusConvite.ausencia},
  StatusConvite.conviteRecusado: {},
  StatusConvite.participou: {},
  StatusConvite.ausencia: {},
};

bool podeTransicionarConvite(StatusConvite de, StatusConvite para) =>
    (transicoesConvite[de] ?? const <StatusConvite>{}).contains(para);

/// O FATO: uma conquista de vaga, registrada quando aconteceu.
///
/// OS 02 secao 16 lista o conteudo minimo; todos os campos exigidos estao aqui.
class RegistroClassificacaoAnual {
  final String userId;

  /// Temporada a que a vaga pertence (ex.: "2026").
  final String temporada;

  /// Torneio que gerou a vaga.
  final String tournamentId;

  /// Edicao que gerou a vaga.
  final String editionId;

  final OrigemClassificacaoAnual origem;

  /// Colocacao obtida, quando a origem for de colocacao. >= 1.
  final int? colocacao;

  /// Texto livre para indicacao administrativa, ou observacao de auditoria.
  final String? motivo;

  /// Instante da conquista, em UTC.
  final DateTime registradoEm;

  RegistroClassificacaoAnual({
    required this.userId,
    required this.temporada,
    required this.tournamentId,
    required this.editionId,
    required this.origem,
    this.colocacao,
    this.motivo,
    required DateTime registradoEm,
  }) : registradoEm = registradoEm.toUtc() {
    if (userId.isEmpty || temporada.isEmpty) {
      throw ArgumentError('registro anual: userId e temporada sao obrigatorios');
    }
    if (colocacao != null && colocacao! < 1) {
      throw ArgumentError.value(colocacao, 'colocacao', 'deve ser >= 1');
    }
    if (origem == OrigemClassificacaoAnual.indicacaoAdministrativa &&
        (motivo == null || motivo!.isEmpty)) {
      // Indicacao sem justificativa e exatamente o que a auditoria precisa
      // encontrar depois; exigir o texto agora e mais barato que reconstruir a
      // intencao daqui a um ano.
      throw ArgumentError.value(motivo, 'motivo',
          'obrigatorio em indicacao_administrativa');
    }
  }

  /// `temporada + tournamentId + editionId + userId`.
  ///
  /// A edicao entra na chave DE PROPOSITO: e ela que permite ao mesmo jogador ter
  /// varios registros na mesma temporada (OS 02 secao 17) sem que nenhum deles
  /// seja lido como repeticao do outro. Reprocessar a mesma edicao, por outro
  /// lado, nao cria registro novo.
  String get chaveIdempotencia =>
      '$temporada|$tournamentId|$editionId|$userId';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'temporada': temporada,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'origem': origem.wire,
        'colocacao': colocacao,
        'motivo': motivo,
        'registradoEm': registradoEm.toIso8601String(),
        'chaveIdempotencia': chaveIdempotencia,
      };

  factory RegistroClassificacaoAnual.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('registro anual: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    final origem = OrigemClassificacaoAnual.porWire(texto('origem'));
    if (origem == null) {
      throw FormatException('registro anual: origem desconhecida "${json['origem']}".');
    }
    final registradoEmBruto = texto('registradoEm');
    final registradoEm = DateTime.tryParse(registradoEmBruto);
    if (registradoEm == null || !registradoEm.isUtc) {
      throw FormatException(
          'registro anual: registradoEm deve ser ISO-8601 em UTC (recebido: $registradoEmBruto).');
    }
    try {
      return RegistroClassificacaoAnual(
        userId: texto('userId'),
        temporada: texto('temporada'),
        tournamentId: texto('tournamentId'),
        editionId: texto('editionId'),
        origem: origem,
        colocacao: json['colocacao'] as int?,
        motivo: json['motivo'] as String?,
        registradoEm: registradoEm,
      );
    } on ArgumentError catch (e) {
      throw FormatException('registro anual: registro invalido ($e).');
    }
  }

  @override
  String toString() => 'RegistroClassificacaoAnual($chaveIdempotencia)';
}

/// O DIREITO: um convite por jogador por temporada.
class ConviteEncerramento {
  final String userId;
  final String temporada;
  final StatusConvite status;

  /// Registro que originou o convite — o PRIMEIRO, cronologicamente.
  final String registroOrigemChave;

  /// Quantas vezes o jogador se classificou nesta temporada. >= 1.
  ///
  /// Projecao de leitura, como o contador de reward_grants.dart: a fonte continua
  /// sendo a lista de registros. Existe para a tela mostrar "classificou 3x" sem
  /// varrer o historico inteiro.
  final int classificacoes;

  final DateTime criadoEm;
  final DateTime atualizadoEm;

  ConviteEncerramento({
    required this.userId,
    required this.temporada,
    required this.status,
    required this.registroOrigemChave,
    required this.classificacoes,
    required DateTime criadoEm,
    required DateTime atualizadoEm,
  })  : criadoEm = criadoEm.toUtc(),
        atualizadoEm = atualizadoEm.toUtc() {
    if (classificacoes < 1) {
      throw ArgumentError.value(classificacoes, 'classificacoes', 'deve ser >= 1');
    }
  }

  /// `temporada + userId`. Sem edicao: e essa ausencia que garante um unico
  /// convite por jogador por temporada (OS 02 secao 17).
  String get chaveIdempotencia => '$temporada|$userId';

  ConviteEncerramento comStatus(StatusConvite novo, {required DateTime em}) =>
      ConviteEncerramento(
        userId: userId,
        temporada: temporada,
        status: novo,
        registroOrigemChave: registroOrigemChave,
        classificacoes: classificacoes,
        criadoEm: criadoEm,
        atualizadoEm: em,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'temporada': temporada,
        'status': status.wire,
        'registroOrigemChave': registroOrigemChave,
        'classificacoes': classificacoes,
        'criadoEm': criadoEm.toIso8601String(),
        'atualizadoEm': atualizadoEm.toIso8601String(),
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() =>
      'ConviteEncerramento($chaveIdempotencia ${status.wire} x$classificacoes)';
}

/// Por que o registro de classificacao foi recusado.
enum RecusaRegistroAnual {
  /// Ja existe registro para esta temporada/torneio/edicao/jogador.
  registroDuplicado('registro_duplicado');

  final String wire;
  const RecusaRegistroAnual(this.wire);
}

/// Veredito de [registrarClassificacaoAnual].
class ResultadoRegistroAnual {
  final RegistroClassificacaoAnual? registro;
  final RecusaRegistroAnual? recusa;

  const ResultadoRegistroAnual._(this.registro, this.recusa);

  const ResultadoRegistroAnual.registrado(RegistroClassificacaoAnual registro)
      : this._(registro, null);

  const ResultadoRegistroAnual.recusado(RecusaRegistroAnual recusa)
      : this._(null, recusa);

  bool get registrado => registro != null;

  @override
  String toString() => registrado
      ? 'ResultadoRegistroAnual.registrado(${registro!.chaveIdempotencia})'
      : 'ResultadoRegistroAnual.recusado(${recusa!.wire})';
}

/// Registra uma conquista de vaga ao encerramento anual (OS 02 secao 16).
///
/// Funcao pura e idempotente. Segunda classificacao do MESMO jogador em OUTRA
/// edicao e aceita — e exatamente o caso da OS 02 secao 17.
ResultadoRegistroAnual registrarClassificacaoAnual({
  required String userId,
  required String temporada,
  required String tournamentId,
  required String editionId,
  required OrigemClassificacaoAnual origem,
  required DateTime agora,
  int? colocacao,
  String? motivo,
  Iterable<RegistroClassificacaoAnual> registros =
      const <RegistroClassificacaoAnual>[],
}) {
  final registro = RegistroClassificacaoAnual(
    userId: userId,
    temporada: temporada,
    tournamentId: tournamentId,
    editionId: editionId,
    origem: origem,
    colocacao: colocacao,
    motivo: motivo,
    registradoEm: agora,
  );
  if (registros.any((r) => r.chaveIdempotencia == registro.chaveIdempotencia)) {
    return const ResultadoRegistroAnual.recusado(RecusaRegistroAnual.registroDuplicado);
  }
  return ResultadoRegistroAnual.registrado(registro);
}

/// Consolida os registros da temporada em um convite por jogador
/// (OS 02 secoes 17 e 18).
///
/// Funcao pura e deterministica: mesma entrada, mesma saida, na mesma ordem.
/// Convites ja existentes sao PRESERVADOS com o status que tinham — reconsolidar
/// nao pode rebaixar para `elegivel` um convite que o jogador ja aceitou. So o
/// contador de classificacoes e reprojetado, porque ele e derivado.
List<ConviteEncerramento> consolidarConvites({
  required String temporada,
  required Iterable<RegistroClassificacaoAnual> registros,
  required DateTime agora,
  Iterable<ConviteEncerramento> existentes = const <ConviteEncerramento>[],
}) {
  final daTemporada = registros
      .where((r) => r.temporada == temporada)
      .toList(growable: false)
    ..sort((a, b) {
      final porData = a.registradoEm.compareTo(b.registradoEm);
      if (porData != 0) return porData;
      // Empate exato de instante: cai na chave, que e unica. Sem isso, duas
      // conquistas gravadas no mesmo milissegundo trocariam de "primeira" entre
      // duas leituras, e o `registroOrigemChave` do convite ficaria instavel.
      return a.chaveIdempotencia.compareTo(b.chaveIdempotencia);
    });

  final porUsuario = <String, List<RegistroClassificacaoAnual>>{};
  for (final r in daTemporada) {
    porUsuario.putIfAbsent(r.userId, () => []).add(r);
  }

  final anteriores = {
    for (final c in existentes)
      if (c.temporada == temporada) c.userId: c,
  };

  final convites = <ConviteEncerramento>[];
  final usuarios = porUsuario.keys.toList(growable: false)..sort();
  for (final userId in usuarios) {
    final lista = porUsuario[userId]!;
    final anterior = anteriores[userId];
    convites.add(ConviteEncerramento(
      userId: userId,
      temporada: temporada,
      status: anterior?.status ?? StatusConvite.elegivel,
      registroOrigemChave: lista.first.chaveIdempotencia,
      classificacoes: lista.length,
      criadoEm: anterior?.criadoEm ?? agora,
      atualizadoEm: agora,
    ));
  }
  return convites;
}

/// Classificacoes alem da primeira, por jogador (OS 02 secao 17).
///
/// A vaga repetida NAO e redistribuida aqui: a regra nao foi definida pelo
/// projeto. Esta funcao apenas torna a lista consultavel para quando ela for.
List<RegistroClassificacaoAnual> registrosExcedentes({
  required String temporada,
  required Iterable<RegistroClassificacaoAnual> registros,
}) {
  final daTemporada = registros
      .where((r) => r.temporada == temporada)
      .toList(growable: false)
    ..sort((a, b) {
      final porData = a.registradoEm.compareTo(b.registradoEm);
      if (porData != 0) return porData;
      return a.chaveIdempotencia.compareTo(b.chaveIdempotencia);
    });

  final primeiraVista = <String>{};
  final excedentes = <RegistroClassificacaoAnual>[];
  for (final r in daTemporada) {
    if (!primeiraVista.add(r.userId)) excedentes.add(r);
  }
  return excedentes;
}

/// Por que a mudanca de status do convite foi recusada.
enum RecusaConvite {
  conviteInexistente('convite_inexistente'),
  transicaoInexistente('transicao_inexistente'),
  statusTerminal('status_terminal'),
  transicaoNula('transicao_nula');

  final String wire;
  const RecusaConvite(this.wire);
}

/// Veredito de [transicionarConvite].
class ResultadoConviteTransicao {
  final ConviteEncerramento? convite;
  final RecusaConvite? recusa;

  const ResultadoConviteTransicao._(this.convite, this.recusa);

  const ResultadoConviteTransicao.aceita(ConviteEncerramento convite)
      : this._(convite, null);

  const ResultadoConviteTransicao.recusada(RecusaConvite recusa)
      : this._(null, recusa);

  bool get aceita => convite != null;

  @override
  String toString() => aceita
      ? 'ResultadoConviteTransicao.aceita(${convite!.chaveIdempotencia} ${convite!.status.wire})'
      : 'ResultadoConviteTransicao.recusada(${recusa!.wire})';
}

/// Move o convite para o proximo estado (OS 02 secao 18).
///
/// Funcao pura. A geracao de imagem/cartao nao acontece aqui: este motor so
/// fornece o estado e os dados.
ResultadoConviteTransicao transicionarConvite({
  required ConviteEncerramento? convite,
  required StatusConvite para,
  required DateTime agora,
}) {
  if (convite == null) {
    return const ResultadoConviteTransicao.recusada(RecusaConvite.conviteInexistente);
  }
  if (convite.status == para) {
    return const ResultadoConviteTransicao.recusada(RecusaConvite.transicaoNula);
  }
  if (convite.status.terminal) {
    return const ResultadoConviteTransicao.recusada(RecusaConvite.statusTerminal);
  }
  if (!podeTransicionarConvite(convite.status, para)) {
    return const ResultadoConviteTransicao.recusada(RecusaConvite.transicaoInexistente);
  }
  return ResultadoConviteTransicao.aceita(convite.comStatus(para, em: agora));
}
