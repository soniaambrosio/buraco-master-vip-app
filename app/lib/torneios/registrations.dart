// registrations.dart — inscricoes em edicao de torneio (OS 02 secao 5).
//
// Camada pura: sem Firestore, sem UI e sem relogio implicito. O historico entra
// por parametro e nada e gravado — cabe a camada de persistencia anexar o
// registro devolvido, como ja acontece em reward_grants.dart.
//
// IDEMPOTENCIA: a chave e `tournamentId + editionId + userId`. Duas chamadas de
// inscricao do mesmo jogador na mesma edicao produzem uma unica vaga, e a chave
// e reproduzivel offline — o cliente deduplica com o mesmo resultado do servidor.
//
// MOTIVOS DE RECUSA: [MotivoRecusaInscricao] repete, um a um, os valores de
// `MotivoInscricaoRecusada` em app/lib/screens/torneios_models.dart. Sao dois
// enums porque aquele importa package:flutter/foundation.dart e o dominio nao
// pode depender de Flutter; a correspondencia esta fixada por teste.

import 'eligibility.dart';
import 'tournament_lifecycle.dart';
import 'tournament_model.dart';

/// Situacao do participante dentro da edicao.
///
/// Espelha `StatusParticipante` de screens/torneios_models.dart, acrescido de
/// [listaEspera] e [cancelado], que sao estados de INSCRICAO e nao tinham
/// representacao na camada de tela.
enum StatusInscricao {
  inscrito('inscrito'),

  /// Vagas esgotadas; aguarda convocacao.
  listaEspera('lista_espera'),

  aguardandoDupla('aguardando_dupla'),
  duplaConfirmada('dupla_confirmada'),
  checkinPendente('checkin_pendente'),
  checkinRealizado('checkin_realizado'),

  /// Nao compareceu ao check-in dentro da janela.
  ausente('ausente'),

  desclassificado('desclassificado'),
  convocadoParaMesa('convocado_para_mesa'),
  emPartida('em_partida'),

  /// Desistiu, ou teve a inscricao cancelada pela administracao.
  cancelado('cancelado');

  final String wire;
  const StatusInscricao(this.wire);

  /// Ocupa vaga na contagem de lotacao.
  ///
  /// Lista de espera nao ocupa (por definicao), e cancelado/ausente/desclassificado
  /// tambem nao — a vaga volta ao bolo. Sem isso, uma edicao com muitas
  /// desistencias ficaria "lotada" com metade das cadeiras vazias.
  bool get ocupaVaga =>
      this != listaEspera &&
      this != cancelado &&
      this != ausente &&
      this != desclassificado;

  /// Continua na disputa.
  bool get ativo =>
      this != cancelado && this != ausente && this != desclassificado;

  static StatusInscricao? porWire(String wire) {
    for (final s in StatusInscricao.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Por que a inscricao foi recusada.
enum MotivoRecusaInscricao {
  semFichas('sem_fichas'),
  lotado('lotado'),
  inscricoesEncerradas('inscricoes_encerradas'),
  jaInscrito('ja_inscrito'),
  parceiroJaInscrito('parceiro_ja_inscrito'),
  requisitoVipNaoAtendido('requisito_vip_nao_atendido'),
  perfilSuspenso('perfil_suspenso'),
  conflitoComOutraPartida('conflito_com_outra_partida'),

  /// Criterio de elegibilidade do torneio nao atendido, fora os casos acima.
  /// A falha detalhada vem em [ResultadoInscricao.avaliacao].
  inelegivel('inelegivel'),

  /// Modalidade de dupla sem parceiro, ou parceiro informado igual ao proprio
  /// jogador.
  parceiroInvalido('parceiro_invalido'),

  /// O template ainda carrega pendencia de configuracao. Deixar correr abriria
  /// uma edicao com lotacao ou premiacao que ninguem decidiu (OS 02 secao 3).
  configuracaoPendente('configuracao_pendente');

  final String wire;
  const MotivoRecusaInscricao(this.wire);
}

/// Registro de uma inscricao. Imutavel.
class Inscricao {
  final String tournamentId;
  final String editionId;
  final String userId;

  /// Parceiro de dupla. null em participacao individual, ou enquanto a dupla nao
  /// foi formada.
  final String? parceiroId;

  final StatusInscricao status;

  /// Instante da inscricao, sempre em UTC (OS 02 secao 5 pede registro de
  /// data/hora).
  final DateTime inscritoEm;

  /// Instante da ultima mudanca de status, em UTC.
  final DateTime atualizadoEm;

  /// Posicao na lista de espera, >= 1. null fora de [StatusInscricao.listaEspera].
  final int? posicaoEspera;

  /// Fichas debitadas na inscricao. 0 em torneio gratuito.
  final int fichasDebitadas;

  Inscricao({
    required this.tournamentId,
    required this.editionId,
    required this.userId,
    this.parceiroId,
    required this.status,
    required DateTime inscritoEm,
    required DateTime atualizadoEm,
    this.posicaoEspera,
    this.fichasDebitadas = 0,
  })  : inscritoEm = inscritoEm.toUtc(),
        atualizadoEm = atualizadoEm.toUtc() {
    if (tournamentId.isEmpty || editionId.isEmpty || userId.isEmpty) {
      throw ArgumentError('inscricao: tournamentId, editionId e userId sao obrigatorios');
    }
    if (parceiroId == userId) {
      throw ArgumentError.value(parceiroId, 'parceiroId', 'nao pode ser o proprio jogador');
    }
    if (status == StatusInscricao.listaEspera && posicaoEspera == null) {
      throw ArgumentError.value(posicaoEspera, 'posicaoEspera',
          'e obrigatoria em lista_espera');
    }
    if (status != StatusInscricao.listaEspera && posicaoEspera != null) {
      throw ArgumentError.value(posicaoEspera, 'posicaoEspera',
          'so vale em lista_espera');
    }
    if (posicaoEspera != null && posicaoEspera! < 1) {
      throw ArgumentError.value(posicaoEspera, 'posicaoEspera', 'deve ser >= 1');
    }
    if (fichasDebitadas < 0) {
      throw ArgumentError.value(fichasDebitadas, 'fichasDebitadas', 'nao pode ser negativo');
    }
  }

  /// `tournamentId + editionId + userId`. Mesma disciplina de
  /// [ChaveIdempotencia] em reward_grants.dart: derivada, nunca recebida pronta.
  String get chaveIdempotencia => '$tournamentId|$editionId|$userId';

  Inscricao comStatus(
    StatusInscricao novo, {
    required DateTime em,
    int? posicaoEspera,
    String? parceiroId,
  }) =>
      Inscricao(
        tournamentId: tournamentId,
        editionId: editionId,
        userId: userId,
        parceiroId: parceiroId ?? this.parceiroId,
        status: novo,
        inscritoEm: inscritoEm,
        atualizadoEm: em,
        posicaoEspera:
            novo == StatusInscricao.listaEspera ? (posicaoEspera ?? this.posicaoEspera) : null,
        fichasDebitadas: fichasDebitadas,
      );

  factory Inscricao.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('inscricao: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    DateTime instante(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('inscricao: $campo deve ser string ISO-8601 em UTC (recebido: $v).');
      }
      final parsed = DateTime.tryParse(v);
      if (parsed == null) {
        throw FormatException('inscricao: $campo nao e ISO-8601 valido (recebido: $v).');
      }
      if (!parsed.isUtc) {
        throw FormatException('inscricao: $campo deve estar em UTC (sufixo Z) (recebido: $v).');
      }
      return parsed;
    }

    final status = StatusInscricao.porWire(texto('status'));
    if (status == null) {
      throw FormatException('inscricao: status desconhecido "${json['status']}".');
    }

    final chave = texto('chaveIdempotencia');
    final esperada = '${texto('tournamentId')}|${texto('editionId')}|${texto('userId')}';
    if (chave != esperada) {
      throw FormatException(
          'inscricao: chaveIdempotencia nao corresponde aos campos do registro (esperada: $esperada, recebida: $chave).');
    }

    try {
      return Inscricao(
        tournamentId: texto('tournamentId'),
        editionId: texto('editionId'),
        userId: texto('userId'),
        parceiroId: json['parceiroId'] as String?,
        status: status,
        inscritoEm: instante('inscritoEm'),
        atualizadoEm: instante('atualizadoEm'),
        posicaoEspera: json['posicaoEspera'] as int?,
        fichasDebitadas: (json['fichasDebitadas'] as int?) ?? 0,
      );
    } on ArgumentError catch (e) {
      throw FormatException('inscricao: registro invalido ($e).');
    }
  }

  Map<String, dynamic> toJson() => {
        'tournamentId': tournamentId,
        'editionId': editionId,
        'userId': userId,
        'parceiroId': parceiroId,
        'status': status.wire,
        'inscritoEm': inscritoEm.toIso8601String(),
        'atualizadoEm': atualizadoEm.toIso8601String(),
        'posicaoEspera': posicaoEspera,
        'fichasDebitadas': fichasDebitadas,
        'chaveIdempotencia': chaveIdempotencia,
      };

  @override
  String toString() => 'Inscricao($chaveIdempotencia ${status.wire})';
}

/// Veredito de [inscrever].
class ResultadoInscricao {
  /// null quando houve recusa.
  final Inscricao? inscricao;

  /// null quando a inscricao foi aceita.
  final MotivoRecusaInscricao? recusa;

  /// Detalhe da elegibilidade, quando [recusa] e
  /// [MotivoRecusaInscricao.inelegivel]. Permite a tela listar tudo o que falta.
  final AvaliacaoElegibilidade? avaliacao;

  const ResultadoInscricao._(this.inscricao, this.recusa, this.avaliacao);

  const ResultadoInscricao.aceita(Inscricao inscricao)
      : this._(inscricao, null, null);

  const ResultadoInscricao.recusada(MotivoRecusaInscricao recusa,
      [AvaliacaoElegibilidade? avaliacao])
      : this._(null, recusa, avaliacao);

  bool get aceita => inscricao != null;

  /// A vaga saiu como lista de espera em vez de inscricao efetiva.
  bool get emEspera => inscricao?.status == StatusInscricao.listaEspera;

  @override
  String toString() => aceita
      ? 'ResultadoInscricao.aceita(${inscricao!.chaveIdempotencia} ${inscricao!.status.wire})'
      : 'ResultadoInscricao.recusada(${recusa!.wire})';
}

/// Contexto de vagas e lista de espera da edicao.
class ConfiguracaoVagas {
  /// Vagas totais. Vem de [TorneioTemplate.limiteParticipantes].
  final int limite;

  /// A edicao aceita lista de espera quando lota.
  final bool listaEspera;

  /// Custo de entrada em fichas. 0 em torneio gratuito.
  final int custoEntrada;

  const ConfiguracaoVagas({
    required this.limite,
    this.listaEspera = false,
    this.custoEntrada = 0,
  });
}

/// Inscreve um jogador, ou explica por que nao inscreveu.
///
/// Encadeia, nesta ordem: configuracao do template, status da edicao, janela de
/// calendario, duplicidade, parceiro, elegibilidade, saldo e lotacao. A ordem e
/// estavel para que a recusa reportada seja sempre a mesma diante do mesmo estado
/// — mesma disciplina de `podeAtivarRecompensa`.
///
/// Funcao pura: [inscricoes] entra por parametro e nada e gravado.
ResultadoInscricao inscrever({
  required EdicaoTorneio edicao,
  required TorneioTemplate template,
  required PerfilElegibilidade perfil,
  required ConfiguracaoVagas vagas,
  required DateTime agora,
  required int saldoFichas,
  String? parceiroId,
  Iterable<Inscricao> inscricoes = const <Inscricao>[],
  bool emOutraPartida = false,
}) {
  if (!template.configuracaoCompleta) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.configuracaoPendente);
  }

  if (!edicao.status.aceitaInscricao) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.inscricoesEncerradas);
  }

  // O status diz que a inscricao esta aberta; o calendario tem que concordar.
  // Sem esta checagem, uma edicao que ficou em `inscricoesAbertas` porque o
  // agendador falhou continuaria aceitando gente depois do prazo.
  if (!edicao.janelaInscricaoAbertaEm(agora)) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.inscricoesEncerradas);
  }

  // Duplicidade antes de qualquer validacao cara: reinscrever nao pode custar
  // uma avaliacao de elegibilidade inteira, nem debitar fichas de novo.
  final jaInscrito = inscricoes.where(
      (i) => i.userId == perfil.userId && i.status.ativo);
  if (jaInscrito.isNotEmpty) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.jaInscrito);
  }

  if (template.participacao == TipoParticipacao.dupla) {
    if (parceiroId != null && parceiroId == perfil.userId) {
      return const ResultadoInscricao.recusada(MotivoRecusaInscricao.parceiroInvalido);
    }
    if (parceiroId != null) {
      final parceiroOcupado = inscricoes.any((i) =>
          i.status.ativo &&
          (i.userId == parceiroId || i.parceiroId == parceiroId));
      if (parceiroOcupado) {
        return const ResultadoInscricao.recusada(MotivoRecusaInscricao.parceiroJaInscrito);
      }
    }
  } else if (parceiroId != null) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.parceiroInvalido);
  }

  if (perfil.suspenso) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.perfilSuspenso);
  }

  if (emOutraPartida) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.conflitoComOutraPartida);
  }

  final avaliacao = template.avaliar(perfil);
  if (!avaliacao.elegivel) {
    // Assinatura tem motivo proprio porque a tela mostra um caminho de compra
    // especifico para ele; os demais criterios caem no motivo generico com o
    // detalhe anexo.
    final soAssinatura = avaliacao.falhas
        .every((f) => f.recusa == RecusaElegibilidade.semAssinatura);
    return ResultadoInscricao.recusada(
      soAssinatura
          ? MotivoRecusaInscricao.requisitoVipNaoAtendido
          : MotivoRecusaInscricao.inelegivel,
      avaliacao,
    );
  }

  if (saldoFichas < vagas.custoEntrada) {
    return const ResultadoInscricao.recusada(MotivoRecusaInscricao.semFichas);
  }

  // Duplas ocupam duas cadeiras: contar inscricoes em vez de assentos deixaria
  // entrar o dobro de gente em torneio de dupla.
  final ocupadas = _assentosOcupados(inscricoes, template.participacao);
  final assentosPedidos = template.participacao == TipoParticipacao.dupla && parceiroId != null
      ? 2
      : 1;

  if (ocupadas + assentosPedidos > vagas.limite) {
    if (!vagas.listaEspera) {
      return const ResultadoInscricao.recusada(MotivoRecusaInscricao.lotado);
    }
    final posicao = inscricoes
            .where((i) => i.status == StatusInscricao.listaEspera)
            .length +
        1;
    return ResultadoInscricao.aceita(Inscricao(
      tournamentId: edicao.tournamentId,
      editionId: edicao.editionId,
      userId: perfil.userId,
      parceiroId: parceiroId,
      status: StatusInscricao.listaEspera,
      inscritoEm: agora,
      atualizadoEm: agora,
      posicaoEspera: posicao,
      // Lista de espera nao debita: a vaga ainda nao existe.
      fichasDebitadas: 0,
    ));
  }

  final status = template.participacao == TipoParticipacao.dupla
      ? (parceiroId == null
          ? StatusInscricao.aguardandoDupla
          : StatusInscricao.duplaConfirmada)
      : StatusInscricao.inscrito;

  return ResultadoInscricao.aceita(Inscricao(
    tournamentId: edicao.tournamentId,
    editionId: edicao.editionId,
    userId: perfil.userId,
    parceiroId: parceiroId,
    status: status,
    inscritoEm: agora,
    atualizadoEm: agora,
    fichasDebitadas: vagas.custoEntrada,
  ));
}

int _assentosOcupados(Iterable<Inscricao> inscricoes, TipoParticipacao participacao) {
  var total = 0;
  for (final i in inscricoes) {
    if (!i.status.ocupaVaga) continue;
    total += participacao == TipoParticipacao.dupla && i.parceiroId != null ? 2 : 1;
  }
  return total;
}

/// Por que o cancelamento foi recusado.
enum RecusaCancelamento {
  /// Nao existe inscricao ativa deste jogador na edicao.
  inscricaoInexistente('inscricao_inexistente'),

  /// A edicao ja saiu da fase de inscricao: cancelar agora deixaria uma mesa
  /// incompleta em quadra.
  foraDaJanela('fora_da_janela'),

  /// Ja cancelada. Recusa em vez de silencio para o reprocessamento nao parecer
  /// um cancelamento novo.
  jaCancelada('ja_cancelada');

  final String wire;
  const RecusaCancelamento(this.wire);
}

/// Veredito de [cancelarInscricao].
class ResultadoCancelamento {
  final Inscricao? inscricao;
  final RecusaCancelamento? recusa;

  /// Fichas a devolver. Zero quando o torneio nao devolve, ou quando nada foi
  /// debitado.
  final int fichasDevolvidas;

  const ResultadoCancelamento._(this.inscricao, this.recusa, this.fichasDevolvidas);

  const ResultadoCancelamento.aceito(Inscricao inscricao, {int fichasDevolvidas = 0})
      : this._(inscricao, null, fichasDevolvidas);

  const ResultadoCancelamento.recusado(RecusaCancelamento recusa)
      : this._(null, recusa, 0);

  bool get aceito => inscricao != null;

  @override
  String toString() => aceito
      ? 'ResultadoCancelamento.aceito(${inscricao!.chaveIdempotencia})'
      : 'ResultadoCancelamento.recusado(${recusa!.wire})';
}

/// Cancela uma inscricao, quando o estado da edicao permite (OS 02 secao 5).
///
/// [devolveFichas] e decisao do template, nao deste motor: alguns torneios
/// devolvem, outros nao, e inventar a politica aqui a esconderia da configuracao.
ResultadoCancelamento cancelarInscricao({
  required EdicaoTorneio edicao,
  required String userId,
  required DateTime agora,
  required Iterable<Inscricao> inscricoes,
  bool devolveFichas = false,
}) {
  Inscricao? alvo;
  for (final i in inscricoes) {
    if (i.userId == userId) {
      alvo = i;
      break;
    }
  }
  if (alvo == null) {
    return const ResultadoCancelamento.recusado(RecusaCancelamento.inscricaoInexistente);
  }
  if (alvo.status == StatusInscricao.cancelado) {
    return const ResultadoCancelamento.recusado(RecusaCancelamento.jaCancelada);
  }
  if (!alvo.status.ativo) {
    return const ResultadoCancelamento.recusado(RecusaCancelamento.inscricaoInexistente);
  }
  // Depois que as mesas comecam a ser formadas, sair deixa de ser cancelamento e
  // vira abandono — regra do template, tratada em outro lugar.
  if (edicao.status != EdicaoStatus.inscricoesAbertas &&
      edicao.status != EdicaoStatus.inscricoesEncerradas &&
      edicao.status != EdicaoStatus.checkinAberto) {
    return const ResultadoCancelamento.recusado(RecusaCancelamento.foraDaJanela);
  }

  return ResultadoCancelamento.aceito(
    alvo.comStatus(StatusInscricao.cancelado, em: agora),
    fichasDevolvidas: devolveFichas ? alvo.fichasDebitadas : 0,
  );
}

/// Convoca o primeiro da lista de espera para a vaga que abriu.
///
/// Devolve null quando a lista esta vazia. A convocacao respeita a ordem de
/// [Inscricao.posicaoEspera]; empate cai para o instante de inscricao, que e
/// unico o bastante na pratica e mantem a funcao deterministica.
Inscricao? convocarDaListaEspera({
  required Iterable<Inscricao> inscricoes,
  required DateTime agora,
  required int custoEntrada,
}) {
  final espera = inscricoes
      .where((i) => i.status == StatusInscricao.listaEspera)
      .toList(growable: false)
    ..sort((a, b) {
      final porPosicao = a.posicaoEspera!.compareTo(b.posicaoEspera!);
      if (porPosicao != 0) return porPosicao;
      final porData = a.inscritoEm.compareTo(b.inscritoEm);
      if (porData != 0) return porData;
      return a.userId.compareTo(b.userId);
    });
  if (espera.isEmpty) return null;

  final primeiro = espera.first;
  return Inscricao(
    tournamentId: primeiro.tournamentId,
    editionId: primeiro.editionId,
    userId: primeiro.userId,
    parceiroId: primeiro.parceiroId,
    status: primeiro.parceiroId == null
        ? StatusInscricao.inscrito
        : StatusInscricao.duplaConfirmada,
    inscritoEm: primeiro.inscritoEm,
    atualizadoEm: agora,
    fichasDebitadas: custoEntrada,
  );
}

/// Lista de participantes que ocupam vaga, em ordem estavel de inscricao
/// (OS 02 secao 5).
List<Inscricao> listaParticipantes(Iterable<Inscricao> inscricoes) {
  final lista = inscricoes.where((i) => i.status.ocupaVaga).toList(growable: false)
    ..sort((a, b) {
      final porData = a.inscritoEm.compareTo(b.inscritoEm);
      if (porData != 0) return porData;
      return a.userId.compareTo(b.userId);
    });
  return lista;
}
