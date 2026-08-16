// historico_e_consulta.dart — AS DUAS VISÕES DO MESMO FATO (§11, §14, §15).
//
// O registro técnico de uma partida NÃO é público. §15 pede a separação, e ela
// está neste arquivo, em dois tipos com nomes que dizem para quem são:
//
//   [EntradaHistorico]     — o que o JOGADOR vê do próprio histórico.
//   [VisaoAdministrativa]  — o que o SUPORTE/ADMIN vê investigando um matchId.
//
// A separação não é filtro de tela: são PROJEÇÕES diferentes do mesmo
// [RegistroDePartida], construídas por funções distintas. Uma tela que quisesse
// mostrar dado administrativo ao jogador teria de chamar a função errada de
// propósito — não basta esquecer um `if`.
//
// O QUE O JOGADOR NUNCA VÊ, mesmo do próprio histórico:
//   * `impressaoEstado` — impressão digital do estado interno do motor;
//   * `versaoEstadoFinal` — posição na linha do tempo do servidor;
//   * `autoridadeDoEncerramento` — qual processo/admin encerrou;
//   * eventos técnicos, sinais antifraude e o ledger de terceiros.
//
// O QUE O JOGADOR VÊ DO PARCEIRO E DOS ADVERSÁRIOS: apenas que existiram, o
// lado e o assento. Nomes e UIDs de terceiros NÃO entram aqui — quem resolve
// apelido é a camada de perfil, com a política de privacidade dela, e não uma
// consulta de histórico que qualquer um faria em massa.

import '../motor/desfecho_partida.dart';
import 'eventos_auditaveis.dart';
import 'identidade_partida.dart';
import 'ledger_competitivo.dart';
import 'registro_partida.dart';
import 'sinais_antifraude.dart';

/// Como a partida terminou, do ponto de vista de UM jogador.
enum ResultadoDoJogador {
  vitoria('vitoria'),
  derrota('derrota'),

  /// A partida foi anulada/cancelada: não conta para ninguém.
  semEfeito('sem_efeito');

  final String wire;
  const ResultadoDoJogador(this.wire);
}

/// Uma linha do histórico do jogador (§11).
///
/// Construída por [projetarParaJogador], nunca à mão: o construtor é privado
/// justamente para que ninguém monte uma entrada com campo administrativo
/// dentro.
class EntradaHistorico {
  /// `matchId` — o mesmo id público. Aparece porque o jogador precisa
  /// conseguir citá-lo ao abrir um chamado; conhecê-lo NÃO dá acesso
  /// administrativo nenhum (§14).
  final String matchId;

  final DateTime data;
  final TipoDePartida tipo;

  /// `ABERTO` | `FECHADO` | `SBTL`.
  final String modalidade;

  final ResultadoDoJogador resultado;

  /// Pontos do lado do jogador na partida (placar da mesa, não ranking).
  final int pontosMeuLado;
  final int pontosOutroLado;

  /// Variação de ranking, quando houve. `null` em partida que não pontua —
  /// e `null` significa "não se aplica", nunca zero.
  final int? rankingDelta;

  /// A partida terminou por abandono declarado?
  final bool houveAbandono;

  /// O abandono foi do próprio jogador? `null` quando não houve abandono.
  ///
  /// Existe porque a diferença importa para quem lê o próprio histórico, e
  /// porque escondê-la faria o jogador achar que a penalidade veio do nada.
  final bool? abandonoFoiMeu;

  /// Assento do jogador. Útil para ele reconhecer a partida; inofensivo.
  final int assento;

  /// Lado do jogador: `nos` | `eles`.
  final String lado;

  /// Quantos competidores havia, e quantos eram robôs. Contagem, não identidade.
  final int competidores;
  final int robos;

  /// Identificadores do torneio, quando foi partida de torneio. São públicos —
  /// a central de torneios já os mostra.
  final String? tournamentId;
  final String? editionId;

  const EntradaHistorico._({
    required this.matchId,
    required this.data,
    required this.tipo,
    required this.modalidade,
    required this.resultado,
    required this.pontosMeuLado,
    required this.pontosOutroLado,
    required this.rankingDelta,
    required this.houveAbandono,
    required this.abandonoFoiMeu,
    required this.assento,
    required this.lado,
    required this.competidores,
    required this.robos,
    required this.tournamentId,
    required this.editionId,
  });

  bool get venceu => resultado == ResultadoDoJogador.vitoria;

  Map<String, Object?> toJson() => {
        'matchId': matchId,
        'data': data.toIso8601String(),
        'tipo': tipo.wire,
        'modalidade': modalidade,
        'resultado': resultado.wire,
        'pontosMeuLado': pontosMeuLado,
        'pontosOutroLado': pontosOutroLado,
        'rankingDelta': rankingDelta,
        'houveAbandono': houveAbandono,
        'abandonoFoiMeu': abandonoFoiMeu,
        'assento': assento,
        'lado': lado,
        'competidores': competidores,
        'robos': robos,
        'tournamentId': tournamentId,
        'editionId': editionId,
      };

  @override
  String toString() =>
      'EntradaHistorico($matchId ${resultado.wire} ${tipo.wire})';
}

/// Por que uma projeção de histórico não pôde ser feita.
class HistoricoIndisponivel implements Exception {
  final String motivo;
  const HistoricoIndisponivel(this.motivo);

  @override
  String toString() => 'HistoricoIndisponivel: $motivo';
}

/// Projeta o registro no histórico de UM jogador (§11).
///
/// [lancamento] é o lançamento competitivo daquele jogador naquela partida, ou
/// `null`. Ele entra por parâmetro em vez de ser buscado aqui porque esta
/// função é pura — quem lê o ledger é o servidor, que já tem a transação aberta.
///
/// Falha alto quando o jogador não competiu: uma entrada de histórico para
/// quem não jogou é a forma mais direta de vazar a existência de uma partida
/// alheia para quem só chutou um `matchId`.
EntradaHistorico projetarParaJogador({
  required RegistroDePartida registro,
  required String userId,
  LancamentoCompetitivo? lancamento,
}) {
  final participante = registro.porUserId(userId);
  if (participante == null || !participante.classe.competidor) {
    throw HistoricoIndisponivel(
        'o jogador não competiu na partida ${registro.matchId}; não há histórico '
        'dele a projetar.');
  }
  if (!registro.estado.terminal) {
    throw HistoricoIndisponivel(
        'a partida ${registro.matchId} ainda está ${registro.estado.wire} — '
        'histórico é de partida concluída.');
  }
  if (lancamento != null && lancamento.userId != userId) {
    throw HistoricoIndisponivel(
        'o lançamento é de ${lancamento.userId} e a projeção é de $userId.');
  }

  final meuLado = participante.lado!;
  final outroLado = meuLado == 'nos' ? 'eles' : 'nos';

  final resultado = switch (registro.estado) {
    EstadoDaPartida.cancelada => ResultadoDoJogador.semEfeito,
    _ when registro.ladoVencedor == null => ResultadoDoJogador.semEfeito,
    _ when registro.ladoVencedor == meuLado => ResultadoDoJogador.vitoria,
    _ => ResultadoDoJogador.derrota,
  };

  final houveAbandono =
      registro.motivoEncerramento == MotivoEncerramento.abandono;

  return EntradaHistorico._(
    matchId: registro.matchId,
    data: registro.encerradaEm ?? registro.criadaEm,
    tipo: registro.tipo,
    modalidade: registro.identidade.modalidade,
    resultado: resultado,
    pontosMeuLado: registro.placarDe(meuLado)?.pontos ?? 0,
    pontosOutroLado: registro.placarDe(outroLado)?.pontos ?? 0,
    // `null` quando não houve lançamento — e §11 pede exatamente isso: partida
    // casual não mostra "0 pontos de ranking", mostra que ranking não se aplica.
    rankingDelta: lancamento?.delta,
    houveAbandono: houveAbandono,
    // O lado que PERDEU por abandono é o que abandonou: `capturarDesfecho`
    // registra o vencedor declarado pela autoridade, e em abandono o vencedor é
    // quem ficou. Leitura, não dedução nova.
    abandonoFoiMeu:
        houveAbandono ? registro.ladoVencedor != meuLado : null,
    assento: participante.assento!,
    lado: meuLado,
    competidores: registro.competidores.length,
    robos: registro.competidores
        .where((p) => p.classe == ClasseDeParticipante.robo)
        .length,
    tournamentId: registro.tournamentId,
    editionId: registro.editionId,
  );
}

// ---------------------------------------------------------------------------
// VISÃO ADMINISTRATIVA (§14)
// ---------------------------------------------------------------------------

/// Quanto do registro alguém pode ver.
///
/// Três níveis, e a diferença entre os dois superiores é deliberada: o suporte
/// resolve chamado (precisa do que aconteceu), a administração investiga
/// integridade (precisa também dos sinais e do ledger de todos).
enum NivelAcesso {
  /// Jogador comum. Só enxerga a própria entrada de histórico.
  jogador('jogador'),

  /// Atendimento. Vê o resumo técnico e os eventos, sem sinais antifraude.
  suporte('suporte'),

  /// Administração. Vê tudo do registro.
  administrador('administrador');

  final String wire;
  const NivelAcesso(this.wire);

  bool get veEventos => this != jogador;
  bool get veSinais => this == administrador;
  bool get veLedgerDeTerceiros => this == administrador;
}

/// Por que a consulta administrativa foi negada.
enum RecusaConsulta {
  naoAutenticado('nao_autenticado'),
  semPermissao('sem_permissao'),
  partidaInexistente('partida_inexistente');

  final String wire;
  const RecusaConsulta(this.wire);
}

/// Consulta administrativa negada.
class ConsultaNegada implements Exception {
  final RecusaConsulta recusa;
  const ConsultaNegada(this.recusa);

  @override
  String toString() => 'ConsultaNegada(${recusa.wire})';
}

/// O que uma consulta por `matchId` devolve a quem tem autorização (§14).
class VisaoAdministrativa {
  final NivelAcesso nivel;
  final RegistroDePartida registro;

  /// Eventos críticos. Vazio para quem não tem [NivelAcesso.veEventos].
  final List<EventoAuditavel> eventos;

  /// Lançamentos competitivos da partida. Vazio para quem não pode vê-los.
  final List<LancamentoCompetitivo> lancamentos;

  /// Sinais antifraude associados. Vazio para quem não é administrador.
  ///
  /// SINAL NÃO É VEREDITO. Ver `sinais_antifraude.dart`.
  final List<SinalAntifraude> sinais;

  VisaoAdministrativa._({
    required this.nivel,
    required this.registro,
    required List<EventoAuditavel> eventos,
    required List<LancamentoCompetitivo> lancamentos,
    required List<SinalAntifraude> sinais,
  })  : eventos = List.unmodifiable(eventos),
        lancamentos = List.unmodifiable(lancamentos),
        sinais = List.unmodifiable(sinais);

  String get matchId => registro.matchId;

  /// Eventos de desconexão, reconexão e abandono — a pergunta mais frequente do
  /// suporte, num getter só.
  List<EventoAuditavel> get eventosDeConexao => List.unmodifiable(
        eventos
            .where((e) =>
                e.tipo == TipoEventoAuditavel.desconexao ||
                e.tipo == TipoEventoAuditavel.reconexao ||
                e.tipo == TipoEventoAuditavel.abandono)
            .toList(),
      );

  Map<String, Object?> toJson() => {
        'nivel': nivel.wire,
        'partida': registro.toJson(),
        'eventos': [for (final e in eventos) e.toJson()],
        'lancamentos': [for (final l in lancamentos) l.toJson()],
        'sinais': [for (final s in sinais) s.toJson()],
      };
}

/// Monta a visão administrativa de uma partida, aplicando o nível de acesso.
///
/// ESTE É O PONTO DE §14: "o jogador comum não deve ganhar acesso administrativo
/// só por conhecer um matchId". [NivelAcesso.jogador] é recusado aqui, sem
/// exceção — não existe combinação de parâmetros que devolva registro técnico a
/// um jogador comum, nem quando ele participou da partida. Para o histórico dele
/// existe [projetarParaJogador], que é outra função e outra saída.
///
/// [autenticado] entra separado do nível porque "não autenticado" e "autenticado
/// sem permissão" são recusas diferentes, e confundi-las esconde o caso em que
/// o token expirou.
VisaoAdministrativa montarVisaoAdministrativa({
  required bool autenticado,
  required NivelAcesso nivel,
  required RegistroDePartida? registro,
  List<EventoAuditavel> eventos = const [],
  List<LancamentoCompetitivo> lancamentos = const [],
  List<SinalAntifraude> sinais = const [],
}) {
  if (!autenticado) {
    throw const ConsultaNegada(RecusaConsulta.naoAutenticado);
  }
  if (nivel == NivelAcesso.jogador) {
    throw const ConsultaNegada(RecusaConsulta.semPermissao);
  }
  if (registro == null) {
    // Recusa uniforme: "não existe" e "existe e você não pode ver" precisam ser
    // indistinguíveis para quem não tem permissão. Como aqui já se sabe que
    // quem pergunta é suporte ou admin, a distinção é segura e útil.
    throw const ConsultaNegada(RecusaConsulta.partidaInexistente);
  }
  return VisaoAdministrativa._(
    nivel: nivel,
    registro: registro,
    eventos: nivel.veEventos ? eventos : const [],
    lancamentos: nivel.veLedgerDeTerceiros ? lancamentos : const [],
    sinais: nivel.veSinais ? sinais : const [],
  );
}

/// Um índice de partidas por `matchId`, com as consultas que §27 exige.
///
/// Em produção é a coleção `matches` do Firestore, e cada método aqui
/// corresponde a uma consulta indexada — os índices estão declarados em
/// `firebase/firestore.indexes.json`. Esta classe é a versão em memória, e
/// serve para provar em teste que nenhuma consulta precisa varrer tudo.
class IndicePartidas {
  final Map<String, RegistroDePartida> _porMatchId = {};

  /// Índice invertido: UID → matchIds. É o que impede o histórico do jogador de
  /// depender de baixar a coleção inteira (§36).
  final Map<String, List<String>> _porJogador = {};

  int get tamanho => _porMatchId.length;

  /// Grava ou atualiza o registro. Idempotente por `matchId`.
  void gravar(RegistroDePartida registro) {
    final novo = !_porMatchId.containsKey(registro.matchId);
    _porMatchId[registro.matchId] = registro;
    if (!novo) return;
    for (final uid in registro.userIdsCompetidores) {
      (_porJogador[uid] ??= []).add(registro.matchId);
    }
  }

  /// §14: localizar uma partida por `matchId`.
  RegistroDePartida? porMatchId(String matchId) => _porMatchId[matchId];

  /// §11 e §36: histórico de um jogador, paginado, mais recente primeiro.
  ///
  /// [depoisDe] é o cursor — o `matchId` da última entrada da página anterior.
  /// Cursor, e não `offset`, porque `offset` piora linearmente à medida que o
  /// jogador acumula partidas, que é exatamente o crescimento que §36 antecipa.
  List<RegistroDePartida> historicoDe(
    String userId, {
    int limite = 20,
    String? depoisDe,
  }) {
    final ids = _porJogador[userId] ?? const <String>[];
    final registros = [
      for (final id in ids)
        if (_porMatchId[id]!.estado.terminal) _porMatchId[id]!,
    ]..sort((a, b) => (b.encerradaEm ?? b.criadaEm)
        .compareTo(a.encerradaEm ?? a.criadaEm));

    var inicio = 0;
    if (depoisDe != null) {
      final i = registros.indexWhere((r) => r.matchId == depoisDe);
      inicio = i < 0 ? registros.length : i + 1;
    }
    final fim = (inicio + limite).clamp(0, registros.length);
    return List.unmodifiable(registros.sublist(inicio.clamp(0, registros.length), fim));
  }

  /// §27: partidas entre dois jogadores. É a consulta que alimenta o sinal de
  /// "repetição anormal das mesmas duplas".
  List<RegistroDePartida> entre(String userA, String userB) {
    final a = (_porJogador[userA] ?? const <String>[]).toSet();
    final b = (_porJogador[userB] ?? const <String>[]).toSet();
    final comuns = a.intersection(b).toList()..sort();
    return List.unmodifiable([for (final id in comuns) _porMatchId[id]!]);
  }

  /// §27: partidas num período, opcionalmente filtradas por tipo.
  List<RegistroDePartida> noPeriodo(
    DateTime de,
    DateTime ate, {
    TipoDePartida? tipo,
  }) {
    final l = _porMatchId.values.where((r) {
      final quando = r.encerradaEm ?? r.criadaEm;
      if (quando.isBefore(de) || quando.isAfter(ate)) return false;
      return tipo == null || r.tipo == tipo;
    }).toList()
      ..sort((a, b) => (a.encerradaEm ?? a.criadaEm)
          .compareTo(b.encerradaEm ?? b.criadaEm));
    return List.unmodifiable(l);
  }
}
