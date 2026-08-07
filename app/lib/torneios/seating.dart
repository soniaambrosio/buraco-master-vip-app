// seating.dart — formacao de mesas e assentos (OS 02 secao 7).
//
// Camada pura: sem Firestore, sem UI e sem relogio.
//
// SORTEIO DETERMINISTICO: as mesas sao sorteadas, mas o sorteio e reproduzivel.
// A semente e um dado da fase, guardado junto com as mesas; rodar a formacao de
// novo com a mesma semente devolve exatamente a mesma distribuicao. Isso e o que
// permite (a) reprocessar a tarefa automatica sem embaralhar mesas ja
// convocadas — OS 02 secao 19 —, (b) testar a formacao, e (c) auditar depois uma
// reclamacao de "por que caí nesta mesa".
//
// O gerador e explicito, e nao `dart:math`: a implementacao de `Random(seed)` nao
// e contratualmente estavel entre versoes do Dart, e uma atualizacao do SDK
// remontaria mesas de edicoes antigas ao reprocessar o historico.
//
// ESTE ARQUIVO NAO JOGA BURACO. Ele decide QUEM senta ONDE; o que acontece na
// mesa e mesa.dart, via o contrato de match_contract.dart.

import 'participants.dart';
import 'registrations.dart';
import 'tournament_model.dart';

/// Gerador xorshift de 32 bits (Marsaglia).
///
/// Pequeno e fixo de proposito: o objetivo nao e qualidade criptografica, e sim
/// que a mesma semente produza a mesma sequencia hoje, no servidor, e daqui a
/// dois anos ao reconstruir o historico.
///
/// POR QUE 32 BITS, E POR QUE SEM MULTIPLICACAO: este codigo roda em tres
/// plataformas — VM (teste), AOT (app) e JavaScript (Cloud Functions, via
/// js_bridge.dart). Em JavaScript um `int` do Dart e um double, entao produto de
/// 64 bits PERDE PRECISAO e um gerador congruente linear divergiria entre o
/// servidor e o aparelho. As mesas sorteadas no backend nao bateriam com as
/// reproduzidas no cliente, e a auditoria de "por que caí nesta mesa" ficaria
/// impossivel. Deslocamento e XOR sobre 32 bits sao exatos nas tres plataformas,
/// entao a sequencia e literalmente a mesma em qualquer uma.
class SorteioDeterministico {
  int _estado;

  SorteioDeterministico(int semente)
      // Xorshift trava em zero: qualquer semente que reduza a 0 em 32 bits vira
      // uma constante nao nula conhecida, em vez de gerar sempre o mesmo indice.
      : _estado = (semente & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : semente & 0xFFFFFFFF;

  int _proximo() {
    var x = _estado;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _estado = x & 0xFFFFFFFF;
    return _estado;
  }

  /// Inteiro em `[0, limite)`.
  int inteiro(int limite) {
    if (limite < 1) {
      throw ArgumentError.value(limite, 'limite', 'deve ser >= 1');
    }
    return _proximo() % limite;
  }

  /// Embaralhamento de Fisher-Yates sobre uma copia.
  List<T> embaralhar<T>(List<T> origem) {
    final lista = List<T>.of(origem);
    for (var i = lista.length - 1; i > 0; i--) {
      final j = inteiro(i + 1);
      final tmp = lista[i];
      lista[i] = lista[j];
      lista[j] = tmp;
    }
    return lista;
  }
}

/// Situacao de uma mesa.
enum StatusMesa {
  /// Formada, aguardando a solicitacao ao Motor de Partidas.
  formada('formada'),

  /// Partida solicitada; aguardando resultado.
  emJogo('em_jogo'),

  /// Resultado recebido e validado.
  encerrada('encerrada'),

  /// Desfeita antes de jogar (edicao cancelada, participante ausente).
  cancelada('cancelada');

  final String wire;
  const StatusMesa(this.wire);

  static StatusMesa? porWire(String wire) {
    for (final s in StatusMesa.values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// Uma mesa de uma fase.
class Mesa {
  final String mesaId;
  final String tournamentId;
  final String editionId;
  final String faseId;

  /// Participantes em ordem de assento. A ordem importa: e ela que vai para
  /// [SolicitacaoPartida.assentos].
  final List<Participante> assentos;

  final StatusMesa status;

  /// Partida associada. null enquanto a mesa nao foi solicitada.
  final String? matchId;

  const Mesa({
    required this.mesaId,
    required this.tournamentId,
    required this.editionId,
    required this.faseId,
    required this.assentos,
    this.status = StatusMesa.formada,
    this.matchId,
  });

  /// Rotulo estavel para a UI ("Mesa 7"). Derivado do sufixo numerico do
  /// [mesaId]; a tela pode enfeitar, mas o numero vem daqui.
  int get numero {
    final m = RegExp(r'(\d+)$').firstMatch(mesaId);
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  bool contem(String userId) => assentos.any((p) => p.contem(userId));

  Mesa comStatus(StatusMesa novo, {String? matchId}) => Mesa(
        mesaId: mesaId,
        tournamentId: tournamentId,
        editionId: editionId,
        faseId: faseId,
        assentos: assentos,
        status: novo,
        matchId: matchId ?? this.matchId,
      );

  Map<String, dynamic> toJson() => {
        'mesaId': mesaId,
        'tournamentId': tournamentId,
        'editionId': editionId,
        'faseId': faseId,
        'assentos': assentos.map((p) => p.participanteId).toList(),
        'status': status.wire,
        'matchId': matchId,
      };

  factory Mesa.fromMap(Map<String, dynamic> json) {
    String texto(String campo) {
      final v = json[campo];
      if (v is! String || v.isEmpty) {
        throw FormatException('mesa: $campo deve ser string nao vazia (recebido: $v).');
      }
      return v;
    }

    final status = StatusMesa.porWire(texto('status'));
    if (status == null) {
      throw FormatException('mesa: status desconhecido "${json['status']}".');
    }
    final assentos = json['assentos'];
    if (assentos is! List || assentos.length < 2) {
      throw FormatException('mesa: assentos deve ser lista com ao menos 2 itens.');
    }
    return Mesa(
      mesaId: texto('mesaId'),
      tournamentId: texto('tournamentId'),
      editionId: texto('editionId'),
      faseId: texto('faseId'),
      assentos:
          assentos.map((e) => Participante.deId(e as String)).toList(growable: false),
      status: status,
      matchId: json['matchId'] as String?,
    );
  }

  @override
  String toString() => 'Mesa($mesaId ${status.wire} ${assentos.length} assentos)';
}

/// Por que a formacao de mesas foi recusada.
enum RecusaFormacao {
  /// Menos participantes do que uma mesa comporta.
  participantesInsuficientes('participantes_insuficientes'),

  /// Torneio de dupla com inscricao sem parceiro definido.
  duplaIncompleta('dupla_incompleta'),

  /// O mesmo jogador aparece em mais de uma unidade. OS 02 secao 7: "evitar
  /// duplicacoes".
  jogadorDuplicado('jogador_duplicado'),

  /// O numero de participantes nao fecha mesas do tamanho pedido e o formato nao
  /// admite sobra.
  sobraDeParticipantes('sobra_de_participantes');

  final String wire;
  const RecusaFormacao(this.wire);
}

/// Veredito de [formarMesas].
class ResultadoFormacao {
  final List<Mesa> mesas;
  final RecusaFormacao? recusa;

  /// Participantes que sobraram por nao fechar mesa. Vazio quando
  /// [permitirSobra] e false, porque nesse caso a formacao inteira e recusada.
  final List<Participante> excedentes;

  const ResultadoFormacao._(this.mesas, this.recusa, this.excedentes);

  const ResultadoFormacao.formadas(List<Mesa> mesas,
      {List<Participante> excedentes = const []})
      : this._(mesas, null, excedentes);

  const ResultadoFormacao.recusada(RecusaFormacao recusa)
      : this._(const [], recusa, const []);

  bool get formada => recusa == null;

  @override
  String toString() => formada
      ? 'ResultadoFormacao.formadas(${mesas.length} mesas, ${excedentes.length} excedentes)'
      : 'ResultadoFormacao.recusada(${recusa!.wire})';
}

/// Reune os participantes a partir das inscricoes (OS 02 secao 7).
///
/// Em torneio de dupla, cada inscricao com parceiro vira UMA unidade; a inscricao
/// do parceiro, quando existir como registro proprio, e absorvida em vez de
/// gerar uma segunda unidade.
///
/// Lanca [StateError] quando encontra o mesmo jogador em duas unidades: seguir
/// adiante colocaria a mesma pessoa em duas mesas ao mesmo tempo.
List<Participante> reunirParticipantes({
  required Iterable<Inscricao> inscricoes,
  required TipoParticipacao participacao,
}) {
  final unidades = <Participante>[];
  final jogadoresVistos = <String>{};

  final aptas = inscricoes.where((i) => i.status.ocupaVaga).toList(growable: false)
    ..sort((a, b) {
      final porData = a.inscritoEm.compareTo(b.inscritoEm);
      if (porData != 0) return porData;
      return a.userId.compareTo(b.userId);
    });

  for (final inscricao in aptas) {
    if (jogadoresVistos.contains(inscricao.userId)) {
      // Ja absorvido como parceiro de outra inscricao — nao e erro.
      continue;
    }
    if (participacao == TipoParticipacao.dupla) {
      final parceiro = inscricao.parceiroId;
      if (parceiro == null) continue; // dupla incompleta: tratada em formarMesas
      if (jogadoresVistos.contains(parceiro)) {
        throw StateError(
            'jogador $parceiro aparece em mais de uma dupla na edicao ${inscricao.editionId}');
      }
      jogadoresVistos.add(inscricao.userId);
      jogadoresVistos.add(parceiro);
      unidades.add(Participante.dupla(inscricao.userId, parceiro));
    } else {
      jogadoresVistos.add(inscricao.userId);
      unidades.add(Participante.individual(inscricao.userId));
    }
  }
  return unidades;
}

/// Forma as mesas de uma fase.
///
/// [semente] torna o sorteio reproduzivel; guarde-a junto com a fase.
/// [ladosPorMesa] e quantas UNIDADES sentam por mesa — em torneio de dupla, 2
/// lados sao 4 jogadores.
///
/// Quando o total nao fecha mesas exatas, [permitirSobra] decide: `true` devolve
/// os excedentes para a camada chamadora tratar (lista de espera, bye, mesa
/// reduzida), `false` recusa a formacao inteira. Nao ha regra automatica de bye
/// aqui — o projeto nao a definiu, e inventa-la decidiria a competicao.
ResultadoFormacao formarMesas({
  required String tournamentId,
  required String editionId,
  required String faseId,
  required List<Participante> participantes,
  required int ladosPorMesa,
  required int semente,
  bool permitirSobra = false,
}) {
  if (ladosPorMesa < 2) {
    throw ArgumentError.value(ladosPorMesa, 'ladosPorMesa', 'deve ser >= 2');
  }

  // Duplicacao de jogador entre unidades e erro de dados, nao de sorteio.
  final vistos = <String>{};
  for (final p in participantes) {
    for (final membro in p.membros) {
      if (!vistos.add(membro)) {
        return const ResultadoFormacao.recusada(RecusaFormacao.jogadorDuplicado);
      }
    }
  }

  if (participantes.length < ladosPorMesa) {
    return const ResultadoFormacao.recusada(RecusaFormacao.participantesInsuficientes);
  }

  final sobra = participantes.length % ladosPorMesa;
  if (sobra != 0 && !permitirSobra) {
    return const ResultadoFormacao.recusada(RecusaFormacao.sobraDeParticipantes);
  }

  // Ordena antes de embaralhar: a lista de entrada pode chegar em qualquer ordem
  // (mapa, query, cache) e, sem essa normalizacao, a mesma semente produziria
  // mesas diferentes conforme a origem dos dados — matando a reprodutibilidade
  // que a semente existe para garantir.
  final normalizados = List<Participante>.of(participantes)
    ..sort((a, b) => a.participanteId.compareTo(b.participanteId));

  final sorteados = SorteioDeterministico(semente).embaralhar(normalizados);
  final aproveitados = sorteados.length - sobra;

  final mesas = <Mesa>[];
  for (var i = 0; i < aproveitados; i += ladosPorMesa) {
    final numero = mesas.length + 1;
    mesas.add(Mesa(
      mesaId: '$faseId-mesa-$numero',
      tournamentId: tournamentId,
      editionId: editionId,
      faseId: faseId,
      assentos: List.unmodifiable(sorteados.sublist(i, i + ladosPorMesa)),
    ));
  }

  return ResultadoFormacao.formadas(
    mesas,
    excedentes: sorteados.sublist(aproveitados),
  );
}

/// Monta a solicitacao de partida de uma mesa formada (OS 02 secao 23).
///
/// O `matchId` e derivado do `mesaId`: a mesa e a partida sao um-para-um dentro
/// da fase, e derivar em vez de sortear torna a solicitacao idempotente — reenviar
/// nao cria uma segunda mesa.
String matchIdDaMesa(Mesa mesa) => 'match-${mesa.mesaId}';
