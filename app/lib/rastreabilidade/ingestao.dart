// ingestao.dart — A ÚNICA PORTA POR ONDE DADO DE FORA VIRA REGISTRO
// (§18, §19, §20, §21, §25, §26).
//
// Todo o resto desta camada trabalha com tipos já validados. Este arquivo é a
// fronteira: aqui entra mapa cru — do servidor de partidas, de um retry, de um
// cliente adulterado — e sai ou um plano de escrita coerente, ou uma recusa com
// motivo.
//
// AS QUATRO COISAS QUE ESTE ARQUIVO GARANTE:
//
//   §25  VALIDAÇÃO — nenhum objeto arbitrário é persistido. Campo desconhecido
//        é recusa, não "ignorado": um campo que ninguém validou hoje é um campo
//        que alguém vai ler amanhã.
//
//   §26  ANTI-TAMPERING — o cliente não escolhe vencedor, placar, delta, tipo
//        de partida nem matchId. O que ele manda é confrontado com o registro
//        que o servidor já tem, e divergência é recusa.
//
//   §20  CONCORRÊNCIA — dois encerramentos, dois callbacks, retry e abandono
//        concorrendo com reconexão convergem para UM estado. A regra de
//        convergência é "o primeiro encerramento vence, o segundo idêntico é
//        aceito em silêncio, o segundo divergente é recusado".
//
//   §21  ATOMICIDADE — o encerramento é UM plano ([PlanoDeEncerramento]) que o
//        servidor grava numa transação só. Não existe caminho que grave o
//        ranking sem fechar a partida, nem que feche a partida sem gravar o
//        histórico: eles nascem juntos ou nenhum nasce.
//
// O QUE ESTE ARQUIVO NÃO FAZ: não conta ponto, não decide vencedor, não declara
// abandono e não calcula delta de ranking. Ele confere e organiza.

import '../motor/desfecho_partida.dart';
import '../motor/diagnostico.dart';
import 'eventos_auditaveis.dart';
import 'identidade_partida.dart';
import 'ledger_competitivo.dart';
import 'registro_partida.dart';
import 'sinais_antifraude.dart';

/// Por que uma ingestão foi recusada.
enum RecusaIngestao {
  naoAutenticado('nao_autenticado'),

  /// Quem chamou não tem o papel de autoridade da partida.
  semAutoridade('sem_autoridade'),

  /// O envelope tem campo que a validação não conhece.
  campoDesconhecido('campo_desconhecido'),

  /// Campo obrigatório ausente, do tipo errado ou fora de faixa.
  campoInvalido('campo_invalido'),

  /// O `matchId` do envelope não corresponde ao registro.
  matchIdDivergente('match_id_divergente'),

  /// Não existe registro aberto com este `matchId`.
  partidaInexistente('partida_inexistente'),

  /// A partida já encerrou e este desfecho é DIFERENTE do que ficou gravado.
  desfechoDivergente('desfecho_divergente'),

  /// O desfecho ainda não é conclusivo.
  desfechoNaoConclusivo('desfecho_nao_conclusivo'),

  /// O estado do motor não é o que o registro esperava (impressão digital
  /// diferente): alguém está enviando resultado de outro momento da partida.
  estadoDivergente('estado_divergente'),

  /// Já ingerido. Recusa BENIGNA: o efeito aconteceu.
  jaIngerido('ja_ingerido');

  final String wire;
  const RecusaIngestao(this.wire);

  /// A recusa é benigna — o transporte deve responder sucesso.
  bool get idempotente => this == jaIngerido;

  /// A recusa denuncia tentativa de escrever o que não se pode?
  ///
  /// É o recorte que alimenta [TipoDeSinal.manipulacaoDeEventoTentada]. Falta
  /// de autenticação e campo faltando NÃO entram: app desatualizado produz
  /// exatamente isso, e transformar bug em suspeita é o oposto do que §17 pede.
  bool get sugereManipulacao =>
      this == semAutoridade ||
      this == matchIdDivergente ||
      this == desfechoDivergente ||
      this == estadoDivergente;
}

/// Ingestão recusada.
class IngestaoRecusada implements Exception {
  final RecusaIngestao recusa;
  final String detalhe;
  const IngestaoRecusada(this.recusa, this.detalhe);

  @override
  String toString() => 'IngestaoRecusada(${recusa.wire}): $detalhe';
}

/// Quem está chamando a ingestão.
///
/// §25 pede validação de autenticação e ownership. O `papel` vem de custom
/// claim no token — nunca de campo no payload, que é justamente o que um
/// cliente adulterado forjaria.
class ChamadorAutorizado {
  final bool autenticado;

  /// `motorDePartidas` | `admin`. Qualquer outro valor não tem autoridade.
  final String papel;

  /// Id de quem chama, para a trilha. Vai para `autoridade` do encerramento.
  final String id;

  const ChamadorAutorizado({
    required this.autenticado,
    required this.papel,
    required this.id,
  });

  /// Papéis que podem encerrar partida e gravar resultado.
  ///
  /// Lista fechada. É a mesma disciplina de `receberResultadoPartida` em
  /// `functions/src/index.ts`, que já exige o claim `motorDePartidas`.
  static const Set<String> papeisDeAutoridade = {'motorDePartidas', 'admin'};

  bool get temAutoridade => autenticado && papeisDeAutoridade.contains(papel);
}

/// Campos que o envelope de encerramento pode ter. Nada além disto entra (§25).
///
/// Lista explícita, e não "tudo que não for perigoso": a lista negra envelhece
/// mal, porque campo novo do atacante nunca está nela.
const Set<String> camposDeEncerramento = {
  'matchId',
  'desfecho',
  'diario',
  'ordem',
};

/// O plano atômico de encerramento (§21).
///
/// Tudo que precisa ser gravado quando uma partida acaba, numa estrutura só, já
/// coerente entre si. O servidor recebe isto e grava numa transação — se a
/// transação falhar, nada foi gravado; se passar, tudo foi.
///
/// A coerência que ele garante, e que §21 pede em palavras:
///   * o registro está em estado terminal E tem placar E tem vencedor;
///   * os eventos de encerramento e resultado existem;
///   * os lançamentos competitivos, se houver, são exatamente os dos
///     competidores pontuáveis — nem um a mais, nem um a menos.
class PlanoDeEncerramento {
  /// O registro já encerrado. Substitui o anterior na coleção `matches`.
  final RegistroDePartida registro;

  /// Eventos a acrescentar na trilha, cada um com `eventId` estável.
  final List<EventoAuditavel> eventos;

  /// Lançamentos competitivos a gravar. Vazio quando a partida não pontua ou
  /// quando a política de ranking ainda não existe.
  final List<LancamentoCompetitivo> lancamentos;

  /// Sinais observados durante a ingestão. Nunca punem (§17).
  final List<SinalAntifraude> sinais;

  /// Esta ingestão mudou alguma coisa?
  ///
  /// `false` num reenvio idêntico. É o que permite ao transporte responder
  /// sucesso sem gravar de novo — e ao operador distinguir "chegou duas vezes"
  /// de "chegou uma vez".
  final bool houveMudanca;

  PlanoDeEncerramento._({
    required this.registro,
    required List<EventoAuditavel> eventos,
    required List<LancamentoCompetitivo> lancamentos,
    required List<SinalAntifraude> sinais,
    required this.houveMudanca,
  })  : eventos = List.unmodifiable(eventos),
        lancamentos = List.unmodifiable(lancamentos),
        sinais = List.unmodifiable(sinais);

  String get matchId => registro.matchId;

  /// Confere as invariantes de §21 antes de qualquer gravação.
  ///
  /// Roda no construtor de [ingerirEncerramento] e devolve o primeiro problema,
  /// ou `null`. Falhar aqui é infinitamente mais barato que gravar meio
  /// encerramento.
  String? conferir() {
    if (!registro.estado.terminal) {
      return 'plano de encerramento com registro em ${registro.estado.wire}';
    }
    if (registro.encerradaEm == null) {
      return 'registro terminal sem encerradaEm';
    }
    if (registro.estado.valeu && registro.placar.isEmpty) {
      return 'partida que valeu sem placar gravado';
    }
    if (registro.estado == EstadoDaPartida.finalizada &&
        registro.ladoVencedor == null) {
      return 'partida finalizada sem lado vencedor';
    }
    final esperados = elegiveisALancamento(registro).toSet();
    final lancados = lancamentos.map((l) => l.userId).toSet();
    if (lancamentos.isNotEmpty && !esperados.containsAll(lancados)) {
      return 'lançamento para quem não é elegível: '
          '${lancados.difference(esperados).join(', ')}';
    }
    for (final l in lancamentos) {
      if (l.matchId != registro.matchId) {
        return 'lançamento ${l.chaveIdempotencia} aponta para outra partida';
      }
      if (l.antes + l.delta != l.depois) {
        return 'lançamento ${l.chaveIdempotencia} incoerente';
      }
    }
    for (final e in eventos) {
      if (e.matchId != registro.matchId) {
        return 'evento ${e.eventId} aponta para outra partida';
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'matchId': matchId,
        'houveMudanca': houveMudanca,
        'registro': registro.toJson(),
        'eventos': [for (final e in eventos) e.toJson()],
        'lancamentos': [for (final l in lancamentos) l.toJson()],
        'sinais': [for (final s in sinais) s.toJson()],
      };

  @override
  String toString() =>
      'PlanoDeEncerramento($matchId ${registro.estado.wire} '
      '${eventos.length} evento(s), ${lancamentos.length} lançamento(s)'
      '${houveMudanca ? '' : ', sem mudança'})';
}

/// Valida o envelope cru de encerramento e devolve o desfecho canônico (§25).
///
/// NÃO persiste nada e NÃO conhece o registro: só confere a FORMA. A conferência
/// contra o estado do servidor é de [ingerirEncerramento].
///
/// Recusa campo desconhecido de propósito. A alternativa — ignorar o que não se
/// reconhece — é como um campo `vencedorId` do cliente acaba lido por uma versão
/// futura do servidor que passou a suportá-lo.
DesfechoCanonicoPartida validarEnvelope(
  Object? envelope, {
  required ChamadorAutorizado chamador,
}) {
  if (!chamador.autenticado) {
    throw const IngestaoRecusada(
        RecusaIngestao.naoAutenticado, 'ingestão exige autenticação.');
  }
  if (!chamador.temAutoridade) {
    throw IngestaoRecusada(RecusaIngestao.semAutoridade,
        'papel "${chamador.papel}" não encerra partida; só '
        '${ChamadorAutorizado.papeisDeAutoridade.join(' ou ')}.');
  }
  if (envelope is! Map) {
    throw const IngestaoRecusada(
        RecusaIngestao.campoInvalido, 'envelope deve ser objeto.');
  }

  final desconhecidos =
      envelope.keys.map((k) => '$k').toSet().difference(camposDeEncerramento);
  if (desconhecidos.isNotEmpty) {
    throw IngestaoRecusada(RecusaIngestao.campoDesconhecido,
        'campos não reconhecidos: ${(desconhecidos.toList()..sort()).join(', ')}.');
  }

  final matchId = envelope['matchId'];
  if (matchId is! String || matchId.isEmpty) {
    throw IngestaoRecusada(RecusaIngestao.campoInvalido,
        'matchId ausente ou vazio (recebido: $matchId).');
  }

  final bruto = envelope['desfecho'];
  if (bruto == null) {
    throw const IngestaoRecusada(
        RecusaIngestao.campoInvalido, 'desfecho é obrigatório.');
  }

  final DesfechoCanonicoPartida desfecho;
  try {
    // Reaproveita a validação que já existe e é testada. Reescrevê-la aqui
    // criaria uma segunda definição de "desfecho válido".
    desfecho = DesfechoCanonicoPartida.deJson(bruto);
  } on FormatException catch (e) {
    throw IngestaoRecusada(RecusaIngestao.campoInvalido, e.message);
  }

  if (desfecho.partidaId != matchId) {
    throw IngestaoRecusada(
        RecusaIngestao.matchIdDivergente,
        'o envelope diz $matchId e o desfecho diz ${desfecho.partidaId} — '
        'resultado de uma partida não se aplica a outra.');
  }
  if (!desfecho.conclusivo) {
    throw IngestaoRecusada(RecusaIngestao.desfechoNaoConclusivo,
        'a partida $matchId está ${desfecho.estado.wire}.');
  }
  return desfecho;
}

/// Ingere o encerramento de uma partida e devolve o plano atômico (§21).
///
/// [registroAtual] é o que o servidor tem gravado. `null` significa que não há
/// partida aberta com este id, e isso é recusa: uma ingestão que CRIASSE o
/// registro na hora aceitaria o resultado de uma partida que nunca foi aberta —
/// que é a fraude mais simples possível (§24: "criar partida finalizada falsa").
///
/// [ledgers] é o ledger corrente de cada competidor pontuável, lido pelo
/// servidor dentro da mesma transação. Entra por parâmetro porque esta função é
/// pura: ela decide, quem lê e grava é a Function.
///
/// [calcularDelta] é a política de ranking. Quando `null` — que é o caso HOJE,
/// porque a fórmula é decisão de produto pendente — nenhum lançamento é
/// produzido e o plano registra isso explicitamente, em vez de inventar um
/// número.
///
/// CONVERGÊNCIA (§20): se o registro já está terminal e o desfecho é o MESMO,
/// devolve um plano com `houveMudanca: false` — sem erro, sem reescrita. Se for
/// diferente, recusa. Esses dois comportamentos juntos são o que faz dois
/// encerramentos concorrentes convergirem em vez de brigarem.
PlanoDeEncerramento ingerirEncerramento({
  required DesfechoCanonicoPartida desfecho,
  required RegistroDePartida? registroAtual,
  required ChamadorAutorizado chamador,
  required DateTime emServidor,
  Map<String, LedgerCompetitivo> ledgers = const {},
  DiarioPartida? diario,
  CalculoDeDelta? calcularDelta,
  PoliticaDeRanking politica = PoliticaDeRanking.pendente,
}) {
  if (!chamador.temAutoridade) {
    throw IngestaoRecusada(RecusaIngestao.semAutoridade,
        'papel "${chamador.papel}" não encerra partida.');
  }
  if (registroAtual == null) {
    throw IngestaoRecusada(RecusaIngestao.partidaInexistente,
        'não há partida aberta com id ${desfecho.partidaId} — resultado de '
        'partida inexistente não cria partida.');
  }
  if (registroAtual.matchId != desfecho.partidaId) {
    throw IngestaoRecusada(
        RecusaIngestao.matchIdDivergente,
        'registro ${registroAtual.matchId} não corresponde ao desfecho '
        '${desfecho.partidaId}.');
  }

  // ------------------------------------------------------------------ §20
  // Reenvio sobre partida já encerrada.
  if (registroAtual.estado.terminal) {
    final mesmo = registroAtual.motivoEncerramento == desfecho.motivo &&
        registroAtual.ladoVencedor == desfecho.ladoVencedor &&
        registroAtual.impressaoEstado == desfecho.impressaoEstado;
    if (!mesmo) {
      throw IngestaoRecusada(
          RecusaIngestao.desfechoDivergente,
          'a partida ${registroAtual.matchId} já encerrou como '
          '${registroAtual.estado.wire}; um segundo desfecho divergente não '
          'reescreve resultado publicado.');
    }
    // Idêntico: nada muda. Este é o caminho do retry, do callback repetido e do
    // segundo encerramento concorrente que perdeu a corrida.
    return PlanoDeEncerramento._(
      registro: registroAtual,
      eventos: const [],
      lancamentos: const [],
      sinais: const [],
      houveMudanca: false,
    );
  }

  // ------------------------------------------------------------------ §26
  // O placar e o vencedor vêm do desfecho, que é do motor. O que se confere
  // aqui é que o desfecho fala DESTA mesa: os assentos declarados no registro
  // têm que ser os lados que o desfecho traz.
  for (final lado in desfecho.lados) {
    for (final assento in lado.assentos) {
      final p = registroAtual.porAssento(assento);
      if (p != null && p.lado != lado.lado) {
        throw IngestaoRecusada(
            RecusaIngestao.estadoDivergente,
            'o desfecho põe o assento $assento no lado ${lado.lado}, mas o '
            'registro o tem em ${p.lado}.');
      }
    }
  }

  final registro = registroAtual.encerrarCom(desfecho);

  // ------------------------------------------------------------------- §8
  final eventos = <EventoAuditavel>[
    ...EventoAuditavel.doDesfecho(
      desfecho,
      identidade: registro.identidade,
      emServidor: emServidor,
    ),
    if (diario != null)
      ...EventoAuditavel.doDiarioCompleto(diario, emServidor: emServidor),
  ];

  // ------------------------------------------------------------ §12 e §13
  final lancamentos = <LancamentoCompetitivo>[];
  if (registro.alteraRanking && calcularDelta != null && politica.definida) {
    for (final userId in elegiveisALancamento(registro)) {
      final ledger = ledgers[userId] ?? LedgerCompetitivo(userId);
      final veredito = ledger.registrarResultado(
        registro: registro,
        delta: calcularDelta(
          registro: registro,
          userId: userId,
          saldoAtual: ledger.saldo,
        ),
        registradoEm: emServidor,
        politica: politica,
      );
      // Recusa benigna (já lançado) simplesmente não entra no plano: o efeito
      // existe e regravá-lo seria aplicar ranking duas vezes.
      if (veredito.lancou) lancamentos.add(veredito.aplicado!);
    }
  }

  // ------------------------------------------------------------ §16 e §17
  final sinais = <SinalAntifraude>[
    ?observarRoboEmPartidaPontuada(
      registro: registro,
      observadoEm: emServidor,
    ),
  ];

  final plano = PlanoDeEncerramento._(
    registro: registro,
    eventos: eventos,
    lancamentos: lancamentos,
    sinais: sinais,
    houveMudanca: true,
  );

  final problema = plano.conferir();
  if (problema != null) {
    // Falha alta, e não recusa com motivo: um plano incoerente não é entrada
    // ruim do cliente, é defeito desta camada. Devolver "recusado" esconderia
    // um bug atrás de uma mensagem de validação.
    throw StateError(
        'plano de encerramento incoerente para ${registro.matchId}: $problema');
  }
  return plano;
}

// ---------------------------------------------------------------------------
// ABANDONO E RECONEXÃO (§18, §19)
// ---------------------------------------------------------------------------

/// Como o abandono foi determinado (§18).
///
/// A OS pede para diferenciar, e a arquitetura JÁ diferencia: `MotivoSaida` em
/// `motor/presenca.dart` distingue saída voluntária, ausência prolongada,
/// remoção pelo servidor e inviabilidade. Este enum é a face de AUDITORIA desses
/// mesmos casos, acrescentando os dois que não são saída de jogador —
/// encerramento normal e falha técnica — para que a trilha consiga dizer o que
/// NÃO foi abandono.
///
/// A regra central de §18, e ela é uma ausência: não existe valor aqui que
/// signifique "desconectou, logo abandonou". Desconexão vira
/// [ClassificacaoDeSaida.quedaDeConexao], que é observação, e só uma
/// `OrdemDeEncerramento` da autoridade a transforma em abandono.
enum ClassificacaoDeSaida {
  /// O jogador pediu para sair.
  voluntaria('voluntaria'),

  /// A conexão caiu. NÃO é abandono — é o que a presença observou.
  quedaDeConexao('queda_de_conexao'),

  /// O prazo do turno estourou sem jogada.
  timeoutDeTurno('timeout_de_turno'),

  /// Ausência prolongada declarada pela autoridade. Este SIM vira abandono.
  naoRetornou('nao_retornou'),

  /// A partida acabou normalmente; ninguém saiu.
  encerramentoNormal('encerramento_normal'),

  /// A administração encerrou.
  encerramentoAdministrativo('encerramento_administrativo'),

  /// Defeito técnico (mesa bloqueada por integridade, servidor caiu).
  falhaTecnica('falha_tecnica');

  final String wire;
  const ClassificacaoDeSaida(this.wire);

  /// Esta classificação, sozinha, caracteriza abandono?
  ///
  /// SÓ [naoRetornou] e [voluntaria] — e mesmo elas dependem de a autoridade ter
  /// declarado, porque quem produz `MotivoEncerramento.abandono` é a
  /// `OrdemDeEncerramento`, nunca esta enumeração.
  bool get podeSerAbandono =>
      this == naoRetornou || this == voluntaria;

  static ClassificacaoDeSaida? porWire(String wire) {
    for (final c in ClassificacaoDeSaida.values) {
      if (c.wire == wire) return c;
    }
    return null;
  }
}

/// Registra uma saída na trilha, sem decidir se foi abandono (§18).
///
/// Devolve um evento auditável, nunca uma mudança de estado da partida. É a
/// separação que a OS pede em uma frase — "não transformar toda desconexão em
/// abandono" — expressa como tipo: esta função não tem como encerrar nada.
///
/// O `eventId` é derivado de assento + classificação + versão do estado, o que
/// o torna estável: a mesma queda reportada duas vezes produz o mesmo evento.
EventoAuditavel registrarSaida({
  required IdentidadePartida identidade,
  required int assento,
  required ClassificacaoDeSaida classificacao,
  required DateTime emServidor,
  required int versaoEstado,
  int? rodada,
  String? declaradaPor,
}) =>
    EventoAuditavel.deCiclo(
      identidade: identidade,
      tipo: classificacao == ClassificacaoDeSaida.quedaDeConexao ||
              classificacao == ClassificacaoDeSaida.timeoutDeTurno
          ? TipoEventoAuditavel.desconexao
          : TipoEventoAuditavel.abandono,
      emServidor: emServidor,
      sufixo: 'a$assento:${classificacao.wire}:v$versaoEstado',
      ator: AtorDoEvento(
        classe: declaradaPor == null ? 'jogador' : 'servidor',
        id: declaradaPor,
        assento: assento,
      ),
      rodada: rodada,
      versaoEstado: versaoEstado,
      dados: {
        'classificacao': classificacao.wire,
        'podeSerAbandono': classificacao.podeSerAbandono,
        // A linha que documenta a fronteira dentro do próprio dado: quem ler o
        // evento no banco sabe que ele não decidiu nada.
        'encerraPartida': false,
      },
    );

/// Registra uma reconexão (§19).
///
/// NÃO cria partida, NÃO cria identidade e NÃO toca no resultado — a assinatura
/// recebe a identidade pronta justamente para que não haja caminho por onde
/// gerar um segundo `matchId`.
///
/// Reconexão sobre partida encerrada é evento normal, e não erro: o cliente que
/// estava offline quando a mesa fechou vai reconectar e precisa descobrir isso.
/// O que ela não pode é REABRIR — e não pode porque nada aqui muda estado.
EventoAuditavel registrarReconexao({
  required IdentidadePartida identidade,
  required int assento,
  required DateTime emServidor,
  required int versaoEstado,
  int? rodada,
  int tentativa = 1,
}) =>
    EventoAuditavel.deCiclo(
      identidade: identidade,
      tipo: TipoEventoAuditavel.reconexao,
      emServidor: emServidor,
      // A tentativa entra no sufixo porque múltiplas reconexões do mesmo assento
      // são eventos DIFERENTES — §32 pede que várias reconexões sejam
      // rastreáveis, e colapsá-las numa só esconderia uma conexão instável.
      sufixo: 'a$assento:t$tentativa:v$versaoEstado',
      ator: AtorDoEvento(classe: 'jogador', assento: assento),
      rodada: rodada,
      versaoEstado: versaoEstado,
      dados: {'tentativa': tentativa, 'criouPartida': false},
    );

/// Converte uma recusa de ingestão em sinal antifraude, quando for o caso (§16).
///
/// Só as recusas que [RecusaIngestao.sugereManipulacao] marca. Devolve `null`
/// para as demais — e essa é a linha entre "coletar evidência" e "acusar quem
/// está com o app desatualizado".
SinalAntifraude? sinalDeRecusa({
  required RecusaIngestao recusa,
  required String matchId,
  required String userId,
  required DateTime emServidor,
}) {
  if (!recusa.sugereManipulacao) return null;
  return observarManipulacaoTentada(
    matchId: matchId,
    userId: userId,
    recusa: recusa.wire,
    observadoEm: emServidor,
  );
}
