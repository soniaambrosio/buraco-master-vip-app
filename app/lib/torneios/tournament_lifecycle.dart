// tournament_lifecycle.dart — ciclo de vida da edicao de torneio (OS 02 secao 4).
//
// Camada pura: sem Firestore, sem Cloud Functions, sem UI e sem relogio. Aqui se
// decide QUAIS transicoes de status existem e QUEM pode dispara-las. Quem
// persiste, agenda ou desenha vem depois.
//
// ESCOPO: este arquivo governa o status da EDICAO. O status do PARTICIPANTE mora
// em registrations.dart e o da FASE mora em phases.dart. A separacao e
// deliberada: "fase concluida" nao e um estado do torneio inteiro, e tratar os
// tres no mesmo enum tornaria impossivel ter duas fases em estados diferentes.
//
// NOMES: os identificadores repetem, um a um, os de `TorneioStatus` em
// app/lib/screens/torneios_models.dart. Sao dois enums porque aquele importa
// package:flutter/foundation.dart e o dominio nao pode depender de Flutter — mas
// a correspondencia e 1:1 e esta fixada por teste, entao renomear de um lado sem
// o outro quebra o portao antes de chegar na tela.

/// Quem esta pedindo a transicao.
///
/// OS 02 secao 21: jogador nao altera status de torneio. O ator entra na
/// assinatura em vez de ficar implicito para que a recusa seja um valor
/// auditavel, e nao um `if` esquecido em alguma rota.
enum AtorTransicao {
  /// Automacao do proprio motor (abertura por calendario, fechamento por lotacao,
  /// avanco por resultado). Ver automation.dart.
  sistema('sistema'),

  /// Operacao humana autenticada com papel administrativo.
  administracao('administracao'),

  /// Cliente do jogador. Nunca autorizado a mover o status.
  jogador('jogador');

  final String wire;
  const AtorTransicao(this.wire);
}

/// Status da edicao de um torneio.
enum EdicaoStatus {
  /// Existe no banco, ainda nao publicada. Invisivel para jogadores.
  rascunho('rascunho'),

  /// Publicada com data marcada, ainda sem anuncio.
  agendado('agendado'),

  /// Anunciada aos jogadores; inscricoes ainda nao abriram.
  anunciado('anunciado'),

  inscricoesAbertas('inscricoes_abertas'),
  inscricoesEncerradas('inscricoes_encerradas'),

  /// Janela de confirmacao de presenca.
  checkinAberto('checkin_aberto'),

  /// Preparacao: mesas sendo formadas. OS 02 secao 4 chama de "preparacao".
  preparandoMesas('preparando_mesas'),

  emAndamento('em_andamento'),

  /// Todas as fases fecharam; o resultado final ainda nao foi homologado.
  aguardandoValidacao('aguardando_validacao'),

  /// Terminal. OS 02 secao 4 chama de "concluido".
  encerrado('encerrado'),

  /// Terminal.
  cancelado('cancelado'),

  /// Pausa administrativa. Nao e terminal: retoma para o status de origem.
  suspenso('suspenso');

  final String wire;
  const EdicaoStatus(this.wire);

  /// Nao existe transicao de saida. Reprocessar uma conclusao nao pode reabrir a
  /// edicao — e o que impede um segundo campeao (OS 02 secao 12).
  bool get terminal => this == encerrado || this == cancelado;

  /// A edicao aparece nas listagens publicas.
  bool get publico => this != rascunho;

  /// Aceita novas inscricoes. Consultado por registrations.dart.
  bool get aceitaInscricao => this == inscricoesAbertas;

  /// Ja saiu do papel: existe disputa em andamento ou concluida.
  bool get emDisputa =>
      this == preparandoMesas || this == emAndamento || this == aguardandoValidacao;

  static EdicaoStatus? porWire(String wire) {
    for (final s in EdicaoStatus.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Por que a transicao foi recusada. Estado explicito e serializavel: recusa
/// silenciosa impede auditoria depois.
enum RecusaTransicao {
  /// O par (origem, destino) nao existe no grafo.
  transicaoInexistente('transicao_inexistente'),

  /// A origem e terminal: nao ha saida.
  origemTerminal('origem_terminal'),

  /// Transicao valida, mas fechada para este ator (tipicamente o jogador).
  atorNaoAutorizado('ator_nao_autorizado'),

  /// Destino igual a origem. Nao e erro de dados, mas tambem nao e transicao —
  /// devolver "permitida" faria um reprocessamento parecer progresso.
  transicaoNula('transicao_nula'),

  /// Retomada de `suspenso` sem saber para onde voltar.
  retomadaSemOrigem('retomada_sem_origem'),

  /// Retomada de `suspenso` apontando para um status que nao pode receber a
  /// edicao de volta.
  retomadaInvalida('retomada_invalida');

  final String wire;
  const RecusaTransicao(this.wire);
}

/// Veredito de [avaliarTransicao].
class ResultadoTransicao {
  /// Status resultante; null quando houve recusa.
  final EdicaoStatus? destino;

  /// null quando a transicao foi permitida.
  final RecusaTransicao? recusa;

  const ResultadoTransicao._(this.destino, this.recusa);

  const ResultadoTransicao.permitida(EdicaoStatus destino) : this._(destino, null);

  const ResultadoTransicao.recusada(RecusaTransicao recusa) : this._(null, recusa);

  bool get permitida => destino != null;

  @override
  bool operator ==(Object other) =>
      other is ResultadoTransicao && other.destino == destino && other.recusa == recusa;

  @override
  int get hashCode => Object.hash(destino, recusa);

  @override
  String toString() => permitida
      ? 'ResultadoTransicao.permitida(${destino!.wire})'
      : 'ResultadoTransicao.recusada(${recusa!.wire})';
}

/// Grafo de transicoes da edicao.
///
/// Declarado como dado, nao como cadeia de `if`: assim o conjunto de caminhos
/// legais e inspecionavel, testavel exaustivamente e alteravel sem reescrever
/// regra espalhada.
///
/// `suspenso` NAO aparece aqui como destino. Suspender e retomar sao operacoes
/// proprias ([avaliarSuspensao] e [avaliarRetomada]) porque dependem de guardar
/// o status de origem — colocar no mesmo mapa perderia essa informacao.
const Map<EdicaoStatus, Set<EdicaoStatus>> transicoesEdicao = {
  EdicaoStatus.rascunho: {
    EdicaoStatus.agendado,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.agendado: {
    EdicaoStatus.anunciado,
    // Torneio sem fase de anuncio abre inscricao direto do agendamento.
    EdicaoStatus.inscricoesAbertas,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.anunciado: {
    EdicaoStatus.inscricoesAbertas,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.inscricoesAbertas: {
    EdicaoStatus.inscricoesEncerradas,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.inscricoesEncerradas: {
    EdicaoStatus.checkinAberto,
    // Formato sem check-in vai direto para a formacao de mesas.
    EdicaoStatus.preparandoMesas,
    // Reabertura administrativa: OS 02 secao 27 pede que a acao de admin
    // `reabrirInscricoes` exista. Continua fechada para o ator jogador.
    EdicaoStatus.inscricoesAbertas,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.checkinAberto: {
    EdicaoStatus.preparandoMesas,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.preparandoMesas: {
    EdicaoStatus.emAndamento,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.emAndamento: {
    EdicaoStatus.aguardandoValidacao,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.aguardandoValidacao: {
    EdicaoStatus.encerrado,
    // Resultado reprovado na homologacao volta para a disputa.
    EdicaoStatus.emAndamento,
    EdicaoStatus.cancelado,
  },
  EdicaoStatus.encerrado: {},
  EdicaoStatus.cancelado: {},
  // Saidas de `suspenso` passam por [avaliarRetomada].
  EdicaoStatus.suspenso: {},
};

/// Transicoes que a automacao pode disparar sozinha.
///
/// O complemento (cancelar, reabrir inscricoes, reprovar homologacao) exige
/// [AtorTransicao.administracao]: sao decisoes com custo humano, e deixar o
/// agendador tomar qualquer uma delas transformaria um bug de relogio em
/// cancelamento de torneio.
const Map<EdicaoStatus, Set<EdicaoStatus>> transicoesAutomaticas = {
  EdicaoStatus.agendado: {EdicaoStatus.anunciado, EdicaoStatus.inscricoesAbertas},
  EdicaoStatus.anunciado: {EdicaoStatus.inscricoesAbertas},
  EdicaoStatus.inscricoesAbertas: {EdicaoStatus.inscricoesEncerradas},
  EdicaoStatus.inscricoesEncerradas: {
    EdicaoStatus.checkinAberto,
    EdicaoStatus.preparandoMesas,
  },
  EdicaoStatus.checkinAberto: {EdicaoStatus.preparandoMesas},
  EdicaoStatus.preparandoMesas: {EdicaoStatus.emAndamento},
  EdicaoStatus.emAndamento: {EdicaoStatus.aguardandoValidacao},
  EdicaoStatus.aguardandoValidacao: {EdicaoStatus.encerrado},
};

/// Status a partir dos quais suspender faz sentido.
///
/// Rascunho fica de fora porque ja e invisivel, e os terminais ficam de fora
/// porque nao ha o que pausar.
const Set<EdicaoStatus> suspensiveis = {
  EdicaoStatus.agendado,
  EdicaoStatus.anunciado,
  EdicaoStatus.inscricoesAbertas,
  EdicaoStatus.inscricoesEncerradas,
  EdicaoStatus.checkinAberto,
  EdicaoStatus.preparandoMesas,
  EdicaoStatus.emAndamento,
  EdicaoStatus.aguardandoValidacao,
};

/// Avalia uma transicao comum da edicao.
///
/// Funcao pura: nao le relogio, nao persiste e nao consulta rede. A ordem das
/// checagens e estavel para que a recusa reportada seja sempre a mesma diante do
/// mesmo estado.
ResultadoTransicao avaliarTransicao({
  required EdicaoStatus de,
  required EdicaoStatus para,
  required AtorTransicao ator,
}) {
  // Jogador nao move status em hipotese alguma (OS 02 secao 21). Checado antes de
  // qualquer outra coisa para que a recusa seja sempre `atorNaoAutorizado`,
  // independente de o caminho existir — nao vale vazar o desenho do grafo pela
  // mensagem de erro.
  if (ator == AtorTransicao.jogador) {
    return const ResultadoTransicao.recusada(RecusaTransicao.atorNaoAutorizado);
  }
  if (de == para) {
    return const ResultadoTransicao.recusada(RecusaTransicao.transicaoNula);
  }
  if (de.terminal) {
    return const ResultadoTransicao.recusada(RecusaTransicao.origemTerminal);
  }

  final destinos = transicoesEdicao[de] ?? const <EdicaoStatus>{};
  if (!destinos.contains(para)) {
    return const ResultadoTransicao.recusada(RecusaTransicao.transicaoInexistente);
  }

  if (ator == AtorTransicao.sistema) {
    final automaticas = transicoesAutomaticas[de] ?? const <EdicaoStatus>{};
    if (!automaticas.contains(para)) {
      return const ResultadoTransicao.recusada(RecusaTransicao.atorNaoAutorizado);
    }
  }

  return ResultadoTransicao.permitida(para);
}

/// Avalia a suspensao administrativa da edicao.
///
/// Exclusiva da administracao: a automacao nao pausa torneio, e o jogador muito
/// menos.
ResultadoTransicao avaliarSuspensao({
  required EdicaoStatus de,
  required AtorTransicao ator,
}) {
  if (ator != AtorTransicao.administracao) {
    return const ResultadoTransicao.recusada(RecusaTransicao.atorNaoAutorizado);
  }
  if (de == EdicaoStatus.suspenso) {
    return const ResultadoTransicao.recusada(RecusaTransicao.transicaoNula);
  }
  if (de.terminal) {
    return const ResultadoTransicao.recusada(RecusaTransicao.origemTerminal);
  }
  if (!suspensiveis.contains(de)) {
    return const ResultadoTransicao.recusada(RecusaTransicao.transicaoInexistente);
  }
  return const ResultadoTransicao.permitida(EdicaoStatus.suspenso);
}

/// Avalia a retomada de uma edicao suspensa.
///
/// [statusAnterior] e o status guardado no momento da suspensao. Nao ha default:
/// adivinhar para onde voltar poderia reabrir inscricoes de um torneio que ja
/// estava em quadra.
ResultadoTransicao avaliarRetomada({
  required EdicaoStatus de,
  required EdicaoStatus? statusAnterior,
  required AtorTransicao ator,
}) {
  if (ator != AtorTransicao.administracao) {
    return const ResultadoTransicao.recusada(RecusaTransicao.atorNaoAutorizado);
  }
  if (de != EdicaoStatus.suspenso) {
    return const ResultadoTransicao.recusada(RecusaTransicao.transicaoInexistente);
  }
  if (statusAnterior == null) {
    return const ResultadoTransicao.recusada(RecusaTransicao.retomadaSemOrigem);
  }
  if (!suspensiveis.contains(statusAnterior)) {
    return const ResultadoTransicao.recusada(RecusaTransicao.retomadaInvalida);
  }
  return ResultadoTransicao.permitida(statusAnterior);
}

/// Registro auditavel de uma transicao efetivada.
///
/// OS 02 secao 4 exige transicoes controladas; controle sem trilha nao e
/// verificavel depois. Cada transicao aceita vira uma linha destas.
class EventoTransicao {
  final String tournamentId;
  final String editionId;
  final EdicaoStatus de;
  final EdicaoStatus para;
  final AtorTransicao ator;

  /// Sempre em UTC, pelo mesmo motivo de reward_grants.dart: comparar em fuso
  /// local tornaria a auditoria dependente do relogio do aparelho.
  final DateTime em;

  /// Identidade de quem operou, quando o ator for humano. null para
  /// [AtorTransicao.sistema].
  final String? operadorId;

  /// Justificativa livre para cancelamento, suspensao e reabertura.
  final String? motivo;

  EventoTransicao({
    required this.tournamentId,
    required this.editionId,
    required this.de,
    required this.para,
    required this.ator,
    required DateTime em,
    this.operadorId,
    this.motivo,
  }) : em = em.toUtc();

  /// Chave determinista: a mesma transicao, no mesmo instante, da mesma edicao,
  /// nao vira duas linhas se o gatilho for reprocessado (OS 02 secao 19).
  String get chaveIdempotencia =>
      '$tournamentId|$editionId|${de.wire}>${para.wire}|${em.toIso8601String()}';

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'editionId': editionId,
        'de': de.wire,
        'para': para.wire,
        'ator': ator.wire,
        'em': em.toIso8601String(),
        'operadorId': operadorId,
        'motivo': motivo,
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'EventoTransicao($chaveIdempotencia)';
}
