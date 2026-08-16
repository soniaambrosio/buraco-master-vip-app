// ledger_competitivo.dart — POR QUE ESTE JOGADOR ESTÁ COM ESTA PONTUAÇÃO (§12, §13).
//
// A pergunta que este arquivo existe para responder não é "quantos pontos ele
// tem" — isso um campo `pontos` no perfil responderia. É:
//
//   "Por que ele tem esses pontos?"
//
// E essa só se responde com a SEQUÊNCIA de alterações. Por isso o modelo é
// ledger e não saldo: cada partida que mexe na pontuação vira um lançamento
// imutável com `antes`, `delta`, `depois`, motivo e `matchId`. O saldo é a
// dobra da sequência, e não o contrário.
//
// ESCOPO, E ELE É ESTREITO DE PROPÓSITO (§13): aqui só entra PONTUAÇÃO
// COMPETITIVA / RANKING. Fichas, economia, entitlement, VIP e catálogo NÃO
// passam por este arquivo e não têm nada a ver com ele — quem cuida daquilo é o
// Play Billing, em `functions-billing/`, e esta OS não o tocou.
//
// O QUE ESTE ARQUIVO NÃO FAZ:
//   * não calcula quanto vale uma vitória — a fórmula é decisão de produto e
//     ainda NÃO EXISTE (ver [PoliticaDeRanking]);
//   * não confia em `delta` enviado pelo cliente — a única porta de entrada é
//     `ingestao.dart`, e ela exige que o delta venha de uma política registrada;
//   * não aplica lançamento de partida que não pontua — [TipoDePartida.alteraRanking]
//     é a única definição de "vale ranking" no sistema.

import 'identidade_partida.dart';
import 'registro_partida.dart';

/// Por que a pontuação mudou.
///
/// Enum, e não texto livre, porque um motivo digitado à mão vira dez grafias
/// diferentes da mesma coisa e a auditoria deixa de conseguir agrupar.
enum MotivoLancamento {
  /// A partida terminou normalmente e o resultado valeu.
  resultadoDePartida('resultado_de_partida'),

  /// Abandono declarado pela autoridade. O sinal do delta é decisão de produto,
  /// não deste arquivo.
  abandonoDeclarado('abandono_declarado'),

  /// Correção manual, sempre por fluxo administrativo auditável.
  ///
  /// Existe no enum porque §23 diz que correções futuras devem ocorrer por
  /// fluxo separado e auditável — e um fluxo auditável precisa de um motivo com
  /// nome. O fluxo em si NÃO foi implementado nesta OS.
  correcaoAdministrativa('correcao_administrativa'),

  /// Estorno de um lançamento anterior, por anulação da partida.
  estorno('estorno');

  final String wire;
  const MotivoLancamento(this.wire);

  /// Este motivo exige uma autoridade declarada?
  bool get exigeAutoridade =>
      this == correcaoAdministrativa || this == estorno;

  static MotivoLancamento? porWire(String wire) {
    for (final m in MotivoLancamento.values) {
      if (m.wire == wire) return m;
    }
    return null;
  }
}

/// Identificação da regra que produziu o delta.
///
/// Viaja com o lançamento porque a fórmula de ranking VAI mudar, e quando
/// mudar ninguém vai conseguir explicar um lançamento antigo sem saber qual
/// regra valia na época. Guardar a versão é mais barato que reconstruir o
/// histórico da fórmula.
class PoliticaDeRanking {
  /// Nome estável da política (`temporada-2026-v1`).
  final String id;

  /// Versão dentro da política.
  final int versao;

  const PoliticaDeRanking({required this.id, required this.versao});

  /// "Ainda não decidido", como VALOR.
  ///
  /// Continua existindo e continua sendo legítima: uma temporada pode ser aberta
  /// declaradamente sem regra, e nesse caso ela não pontua ninguém e acumula
  /// resultados em `rankingBacklog` até que uma política exista. É o que se faz
  /// para segurar partidas enquanto uma política nova é preparada.
  ///
  /// O QUE MUDOU COM A POLÍTICA COMPETITIVA V1: ela deixou de ser a resposta do
  /// projeto. Até então não havia fórmula em lugar nenhum, e esta constante era
  /// uma pendência declarada. Agora há — ver [competitivaV1].
  static const PoliticaDeRanking pendente =
      PoliticaDeRanking(id: 'nao_definida', versao: 0);

  /// A Política Competitiva v1: Elo em dupla, sete Ligas, colocação e soft reset.
  ///
  /// O TEXTO DESTE ID PRECISA BATER COM O DO SERVIDOR, e é por isso que a
  /// constante existe aqui: os dois lados gravam no MESMO documento
  /// (`rankingLedger`), e uma divergência de `id` ou `versao` só apareceria
  /// meses depois, como um lançamento que ninguém consegue explicar. O par
  /// canônico está em `functions-ranking/src/competicao.ts`
  /// (`POLITICA_COMPETITIVA_V1`).
  ///
  /// A FÓRMULA NÃO ESTÁ AQUI, E NÃO DEVE FICAR. Esta é uma constante de
  /// IDENTIFICAÇÃO, não de cálculo. Quem calcula delta é a autoridade —
  /// `functions-ranking` — e a §28 da OS é explícita: o cliente não decide se a
  /// partida é ranqueada, nem resultado, nem delta, nem rating, nem Liga. O
  /// `typedef CalculoDeDelta` abaixo continua sem implementação de produção
  /// pelo mesmo motivo.
  static const PoliticaDeRanking competitivaV1 =
      PoliticaDeRanking(id: 'competitiva', versao: 1);

  bool get definida => this != pendente;

  Map<String, Object?> toJson() => {'id': id, 'versao': versao};

  static PoliticaDeRanking deJson(Object? raw) {
    if (raw is! Map) return pendente;
    final versao = raw['versao'];
    return PoliticaDeRanking(
      id: '${raw['id']}',
      versao: versao is num ? versao.toInt() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PoliticaDeRanking && other.id == id && other.versao == versao;

  @override
  int get hashCode => Object.hash(id, versao);

  @override
  String toString() => 'PoliticaDeRanking($id v$versao)';
}

/// Um lançamento no ledger competitivo. Imutável.
///
/// A invariante `antes + delta == depois` é conferida no construtor, não
/// documentada e torcida para dar certo: um lançamento incoerente gravado uma
/// vez envenena todo saldo calculado a partir dele, e o erro só apareceria como
/// "a soma não bate" meses depois.
class LancamentoCompetitivo {
  /// `matchId|userId|motivo`. Determinística: o mesmo resultado reenviado
  /// produz a MESMA chave, e a segunda gravação é a mesma escrita.
  ///
  /// O `motivo` entra na chave para que estorno e resultado da mesma partida
  /// sejam lançamentos distintos — sem ele, um estorno seria recusado como
  /// duplicata do lançamento que ele estorna.
  final String chaveIdempotencia;

  final String matchId;
  final String userId;
  final MotivoLancamento motivo;

  /// Pontuação ANTES deste lançamento.
  final int antes;

  /// Variação. Pode ser negativa; pode ser zero (uma partida ranqueada que, pela
  /// política, não moveu nada — e registrar o zero é melhor que não registrar,
  /// porque prova que a partida foi avaliada).
  final int delta;

  /// Pontuação DEPOIS. Redundante com `antes + delta` por escolha: é o valor que
  /// a consulta lê sem precisar refazer a soma, e a redundância é justamente o
  /// que permite detectar corrupção.
  final int depois;

  /// Instante do lançamento, em UTC, carimbado pelo servidor.
  final DateTime registradoEm;

  final PoliticaDeRanking politica;

  /// Quem autorizou, nos motivos que exigem autoridade. `null` nos automáticos.
  final String? autoridade;

  static const int versaoFormato = 1;

  LancamentoCompetitivo({
    required this.matchId,
    required this.userId,
    required this.motivo,
    required this.antes,
    required this.delta,
    required this.depois,
    required DateTime registradoEm,
    required this.politica,
    this.autoridade,
  })  : registradoEm = registradoEm.toUtc(),
        chaveIdempotencia = '$matchId|$userId|${motivo.wire}' {
    if (matchId.isEmpty) {
      throw ArgumentError.value(matchId, 'matchId', 'lançamento sem partida não é auditável');
    }
    if (userId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'lançamento sem jogador');
    }
    if (antes + delta != depois) {
      // A checagem que dá nome ao arquivo.
      throw ArgumentError.value(
          depois,
          'depois',
          'incoerente: $antes + $delta = ${antes + delta}, mas o lançamento diz $depois');
    }
    if (motivo.exigeAutoridade && (autoridade == null || autoridade!.isEmpty)) {
      throw ArgumentError.value(autoridade, 'autoridade',
          '${motivo.wire} exige autoridade declarada — correção sem responsável '
          'não é auditável');
    }
    if (!motivo.exigeAutoridade && autoridade != null) {
      throw ArgumentError.value(autoridade, 'autoridade',
          '${motivo.wire} é automático e não tem autoridade a declarar');
    }
  }

  /// Constrói o lançamento a partir do saldo atual e do delta da política.
  ///
  /// É o construtor que o servidor usa: ele conhece `antes` (lido do ledger) e
  /// o `delta` (calculado pela política), e `depois` é consequência — não há
  /// como o chamador informar um `depois` que não feche.
  factory LancamentoCompetitivo.aplicando({
    required String matchId,
    required String userId,
    required MotivoLancamento motivo,
    required int saldoAtual,
    required int delta,
    required DateTime registradoEm,
    required PoliticaDeRanking politica,
    String? autoridade,
  }) =>
      LancamentoCompetitivo(
        matchId: matchId,
        userId: userId,
        motivo: motivo,
        antes: saldoAtual,
        delta: delta,
        depois: saldoAtual + delta,
        registradoEm: registradoEm,
        politica: politica,
        autoridade: autoridade,
      );

  Map<String, Object?> toJson() => {
        'chaveIdempotencia': chaveIdempotencia,
        'matchId': matchId,
        'userId': userId,
        'motivo': motivo.wire,
        'rankingBefore': antes,
        'rankingDelta': delta,
        'rankingAfter': depois,
        'registradoEm': registradoEm.toIso8601String(),
        'politica': politica.toJson(),
        'autoridade': autoridade,
        'versaoFormato': versaoFormato,
      };

  /// Relê um lançamento persistido, revalidando a coerência.
  ///
  /// A revalidação é o ponto: um lançamento adulterado no banco (alguém subiu
  /// `rankingAfter` sem mexer no delta) é recusado na leitura em vez de virar
  /// saldo.
  static LancamentoCompetitivo deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('lançamento: objeto esperado.');
    }
    final motivo = MotivoLancamento.porWire('${raw['motivo']}');
    if (motivo == null) {
      throw FormatException('lançamento: motivo desconhecido "${raw['motivo']}".');
    }
    int inteiro(String campo) {
      final v = raw[campo];
      if (v is! num || v != v.toInt()) {
        throw FormatException('lançamento: $campo deve ser inteiro (recebido: $v).');
      }
      return v.toInt();
    }

    final quando = DateTime.tryParse('${raw['registradoEm']}');
    if (quando == null) {
      throw FormatException(
          'lançamento: registradoEm não é ISO-8601 (recebido: ${raw['registradoEm']}).');
    }
    try {
      final lancamento = LancamentoCompetitivo(
        matchId: '${raw['matchId']}',
        userId: '${raw['userId']}',
        motivo: motivo,
        antes: inteiro('rankingBefore'),
        delta: inteiro('rankingDelta'),
        depois: inteiro('rankingAfter'),
        registradoEm: quando,
        politica: PoliticaDeRanking.deJson(raw['politica']),
        autoridade: raw['autoridade'] as String?,
      );
      final chave = raw['chaveIdempotencia'];
      if (chave is String && chave != lancamento.chaveIdempotencia) {
        throw FormatException(
            'lançamento: chaveIdempotencia gravada ("$chave") não corresponde aos '
            'campos (esperada: "${lancamento.chaveIdempotencia}").');
      }
      return lancamento;
    } on ArgumentError catch (e) {
      throw FormatException('lançamento: ${e.message}');
    }
  }

  @override
  String toString() =>
      'LancamentoCompetitivo($userId $antes${delta >= 0 ? '+' : ''}$delta=$depois '
      'por ${motivo.wire} em $matchId)';
}

/// Por que um lançamento foi recusado.
enum RecusaLancamento {
  /// A partida não altera ranking (casual, privada, treino, contra robôs) ou
  /// não valeu (anulada/cancelada).
  partidaNaoPontua('partida_nao_pontua'),

  /// O jogador não foi competidor nesta partida.
  jogadorNaoCompetiu('jogador_nao_competiu'),

  /// O jogador competiu, mas não é uma conta autenticada (robô, convidado).
  jogadorNaoPontuavel('jogador_nao_pontuavel'),

  /// Já existe lançamento com esta chave. Recusa BENIGNA: o efeito aconteceu.
  jaLancado('ja_lancado'),

  /// A política de ranking ainda não foi definida pelo produto.
  politicaNaoDefinida('politica_nao_definida');

  final String wire;
  const RecusaLancamento(this.wire);

  /// A recusa é benigna — o efeito desejado já existe.
  bool get idempotente => this == jaLancado;
}

/// Veredito de uma tentativa de lançamento.
class VereditoLancamento {
  final LancamentoCompetitivo? aplicado;
  final RecusaLancamento? recusa;

  const VereditoLancamento._(this.aplicado, this.recusa);
  const VereditoLancamento.aplicado(LancamentoCompetitivo l) : this._(l, null);
  const VereditoLancamento.recusado(RecusaLancamento r) : this._(null, r);

  bool get lancou => aplicado != null;

  @override
  String toString() => lancou
      ? 'VereditoLancamento.aplicado(${aplicado!.chaveIdempotencia})'
      : 'VereditoLancamento.recusado(${recusa!.wire})';
}

/// O ledger de um jogador: a sequência auditável que explica o saldo.
///
/// Em produção é uma coleção do Firestore cujo id de documento É a
/// `chaveIdempotencia`, e o saldo corrente vive denormalizado no perfil para a
/// leitura ser barata. Esta classe é a versão em memória e, mais importante, é
/// onde a REGRA de aplicação mora — a Function grava o que ela decidir.
class LedgerCompetitivo {
  final String userId;
  final Map<String, LancamentoCompetitivo> _porChave = {};
  final List<String> _ordem = [];

  /// Saldo inicial da temporada. Explícito porque "começou em zero" é uma
  /// afirmação sobre o produto, não uma constante da matemática.
  final int saldoInicial;

  LedgerCompetitivo(this.userId, {this.saldoInicial = 0});

  /// Reconstrói o ledger a partir de lançamentos persistidos, na ordem dada.
  ///
  /// Recusa uma cadeia que não encadeia: o `antes` de cada lançamento tem que
  /// ser o `depois` do anterior. É o que transforma "a soma bate" em "a
  /// SEQUÊNCIA bate", que é a afirmação forte.
  factory LedgerCompetitivo.reconstruir(
    String userId,
    Iterable<LancamentoCompetitivo> lancamentos, {
    int saldoInicial = 0,
  }) {
    final ledger = LedgerCompetitivo(userId, saldoInicial: saldoInicial);
    var esperado = saldoInicial;
    for (final l in lancamentos) {
      if (l.userId != userId) {
        throw ArgumentError.value(l.userId, 'userId',
            'lançamento de ${l.userId} não entra no ledger de $userId');
      }
      if (l.antes != esperado) {
        throw StateError(
            'ledger de $userId: o lançamento ${l.chaveIdempotencia} parte de '
            '${l.antes}, mas a sequência estava em $esperado — cadeia rompida');
      }
      ledger._porChave[l.chaveIdempotencia] = l;
      ledger._ordem.add(l.chaveIdempotencia);
      esperado = l.depois;
    }
    return ledger;
  }

  List<LancamentoCompetitivo> get lancamentos =>
      List.unmodifiable([for (final c in _ordem) _porChave[c]!]);

  int get tamanho => _ordem.length;

  /// O saldo é a dobra da sequência. Não há campo `_saldo` a ser mantido em
  /// sincronia — o que não existe não pode divergir.
  int get saldo => _ordem.isEmpty ? saldoInicial : _porChave[_ordem.last]!.depois;

  bool contem(String chave) => _porChave.containsKey(chave);

  LancamentoCompetitivo? porMatchId(String matchId) {
    for (final c in _ordem) {
      final l = _porChave[c]!;
      if (l.matchId == matchId && l.motivo == MotivoLancamento.resultadoDePartida) {
        return l;
      }
    }
    return null;
  }

  /// Registra o resultado de uma partida no ledger deste jogador.
  ///
  /// TODAS as guardas de §12 e §13 estão aqui, e nesta ordem:
  ///
  ///   1. a partida pontua? (tipo E desfecho)
  ///   2. o jogador competiu, como conta autenticada?
  ///   3. já foi lançado? → recusa benigna, sem efeito
  ///   4. a política existe?
  ///
  /// A ordem importa: a idempotência vem ANTES da política, para que um
  /// reprocessamento de partida antiga seja reportado como "já lançado" em vez
  /// de estourar por uma política que mudou desde então.
  VereditoLancamento registrarResultado({
    required RegistroDePartida registro,
    required int delta,
    required DateTime registradoEm,
    required PoliticaDeRanking politica,
    MotivoLancamento motivo = MotivoLancamento.resultadoDePartida,
  }) {
    if (!registro.alteraRanking) {
      return const VereditoLancamento.recusado(RecusaLancamento.partidaNaoPontua);
    }
    final participante = registro.porUserId(userId);
    if (participante == null || !participante.classe.competidor) {
      return const VereditoLancamento.recusado(RecusaLancamento.jogadorNaoCompetiu);
    }
    if (!participante.classe.pontuavel) {
      return const VereditoLancamento.recusado(RecusaLancamento.jogadorNaoPontuavel);
    }

    final chave = '${registro.matchId}|$userId|${motivo.wire}';
    if (_porChave.containsKey(chave)) {
      // ESTA É A LINHA QUE IMPEDE RANKING APLICADO DUAS VEZES. Retry, callback
      // duplicado, reconexão e reprocessamento chegam todos aqui.
      return const VereditoLancamento.recusado(RecusaLancamento.jaLancado);
    }
    if (!politica.definida) {
      return const VereditoLancamento.recusado(RecusaLancamento.politicaNaoDefinida);
    }

    final lancamento = LancamentoCompetitivo.aplicando(
      matchId: registro.matchId,
      userId: userId,
      motivo: motivo,
      saldoAtual: saldo,
      delta: delta,
      registradoEm: registradoEm,
      politica: politica,
    );
    _porChave[chave] = lancamento;
    _ordem.add(chave);
    return VereditoLancamento.aplicado(lancamento);
  }

  /// Estorna o lançamento de uma partida anulada.
  ///
  /// NÃO apaga o lançamento original — apaga histórico é o oposto de ledger. O
  /// estorno é um lançamento novo, de sinal contrário, com autoridade declarada.
  VereditoLancamento estornar({
    required String matchId,
    required DateTime registradoEm,
    required String autoridade,
  }) {
    final original = porMatchId(matchId);
    if (original == null) {
      return const VereditoLancamento.recusado(RecusaLancamento.jogadorNaoCompetiu);
    }
    final chave = '$matchId|$userId|${MotivoLancamento.estorno.wire}';
    if (_porChave.containsKey(chave)) {
      return const VereditoLancamento.recusado(RecusaLancamento.jaLancado);
    }
    final lancamento = LancamentoCompetitivo.aplicando(
      matchId: matchId,
      userId: userId,
      motivo: MotivoLancamento.estorno,
      saldoAtual: saldo,
      delta: -original.delta,
      registradoEm: registradoEm,
      politica: original.politica,
      autoridade: autoridade,
    );
    _porChave[chave] = lancamento;
    _ordem.add(chave);
    return VereditoLancamento.aplicado(lancamento);
  }

  /// A sequência está íntegra?
  ///
  /// Existe para o suporte poder afirmar "o saldo deste jogador é explicável"
  /// sem ler linha por linha. Devolve o primeiro ponto de ruptura, ou `null`.
  String? conferir() {
    var esperado = saldoInicial;
    for (final c in _ordem) {
      final l = _porChave[c]!;
      if (l.antes != esperado) {
        return 'lançamento $c parte de ${l.antes} e a sequência estava em $esperado';
      }
      if (l.antes + l.delta != l.depois) {
        return 'lançamento $c: ${l.antes} + ${l.delta} != ${l.depois}';
      }
      esperado = l.depois;
    }
    return null;
  }
}

/// Onde o delta vai ser calculado quando a política existir.
///
/// Assinatura declarada agora, implementação deliberadamente ausente: §17 da OS
/// proíbe inventar regra sem validação, e "quanto vale uma vitória" é decisão de
/// produto tanto quanto "quanto custa um abandono".
///
/// Deixar a assinatura escrita tem uma função: quem for implementar a fórmula
/// encontra o formato esperado — entra o registro e o jogador, sai um inteiro —
/// e não é tentado a espalhar o cálculo por dentro da ingestão.
typedef CalculoDeDelta = int Function({
  required RegistroDePartida registro,
  required String userId,
  required int saldoAtual,
});

/// Política nula: tudo vale zero.
///
/// NÃO é a fórmula do jogo e não deve virar uma. Serve a um caso só: provar,
/// em teste, que a mecânica de lançamento funciona sem que a ausência de regra
/// de produto vire um número inventado no meio do ledger.
int deltaZero({
  required RegistroDePartida registro,
  required String userId,
  required int saldoAtual,
}) =>
    0;

/// Atalho de leitura: os UIDs que receberiam lançamento por esta partida.
///
/// Um lugar só decide isso, e é este — para nenhuma camada de cima "esquecer"
/// de excluir o robô ou incluir o espectador.
List<String> elegiveisALancamento(RegistroDePartida registro) {
  if (!registro.alteraRanking) return const [];
  final l = <String>[
    for (final p in registro.competidores)
      if (p.classe.pontuavel && p.userId != null) p.userId!,
  ]..sort();
  return List.unmodifiable(l);
}

/// Re-exporta para quem consome só o ledger.
typedef TipoDaPartida = TipoDePartida;
