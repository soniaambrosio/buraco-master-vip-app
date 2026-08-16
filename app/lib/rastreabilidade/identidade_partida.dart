// identidade_partida.dart — A IDENTIDADE ÚNICA E IMUTÁVEL DE UMA PARTIDA.
//
// O QUE JÁ EXISTIA, E POR ISSO NÃO É REINVENTADO AQUI:
//   * `SolicitacaoPartida.matchId`, gerado pelo torneio (`matchIdDaMesa`, em
//     seating.dart, como `match-<mesaId>`);
//   * `MotorPartida.partidaId`, que é o mesmo texto, recebido na abertura;
//   * `VinculoDeMesa.matchId`, que carrega o mesmo texto até o resultado.
//
// Ou seja: no caminho de TORNEIO a identidade já nascia uma vez só, do lado de
// quem tem autoridade, e sobrevivia à reconexão porque o `RegistroDePartidas`
// devolve a mesa existente em vez de abrir outra. Este arquivo NÃO cria um
// segundo namespace para isso — ele ADOTA aquele `matchId` e acrescenta o que
// faltava:
//
//   1. as partidas que NÃO nascem de torneio (casual, privada, treino, robôs)
//      não tinham identificador nenhum;
//   2. não havia validação do formato, então nada impedia o cliente de propor
//      um `matchId` privilegiado ou com dado sensível embutido;
//   3. não havia registro de QUEM cunhou o id — e "server-owned" que não se
//      consegue provar depois não é server-owned, é convenção.
//
// REGRA CENTRAL DESTE ARQUIVO: o cliente nunca escolhe o `matchId`. Existe uma
// única porta de entrada para texto vindo de fora ([IdentidadePartida.doCliente])
// e ela recusa SEMPRE. Não é uma checagem que alguém pode esquecer de chamar: é
// o tipo que não tem construtor público.

/// De onde veio o `matchId`.
///
/// Não é decoração: é o que permite responder, meses depois, "quem cunhou este
/// id?". Um id sem origem declarada é indistinguível de um id inventado.
enum OrigemDaIdentidade {
  /// O Motor de Torneios cunhou o id ao formar a mesa (`matchIdDaMesa`). Este é
  /// o caminho que já existia antes desta OS.
  torneio('torneio'),

  /// A autoridade da partida (o servidor Node/Railway) cunhou o id ao abrir uma
  /// mesa que não pertence a torneio nenhum.
  servidor('servidor'),

  /// Partida local, sem servidor: treino contra robôs no próprio aparelho. O id
  /// existe para o histórico do jogador ter o que referenciar, e é declarado
  /// como local justamente para NUNCA ser confundido com um id autoritativo.
  ///
  /// Uma identidade local não pode alterar ranking — ver [TipoDePartida].
  local('local');

  final String wire;
  const OrigemDaIdentidade(this.wire);

  /// A identidade foi cunhada por quem tem autoridade sobre a competição?
  bool get autoritativa => this != local;

  static OrigemDaIdentidade? porWire(String wire) {
    for (final o in OrigemDaIdentidade.values) {
      if (o.wire == wire) return o;
    }
    return null;
  }
}

/// A natureza competitiva da partida (§6 da OS).
///
/// O tipo é DADO DE CRIAÇÃO, não conclusão. Nada neste arquivo — nem em
/// [RegistroDePartida] — deduz "ranqueada" a partir do resultado, do placar ou
/// da presença de um torneio no id. Quem sabe o tipo é quem abriu a mesa, e ele
/// precisa dizer.
enum TipoDePartida {
  /// Sala pública, sem efeito no ranking.
  publicaCasual('publica_casual'),

  /// Sala pública que vale pontuação competitiva.
  publicaRanqueada('publica_ranqueada'),

  /// Sala fechada, criada por convite/código. Não vale ranking: o dono da sala
  /// escolhe os adversários, o que torna a pontuação combinável por construção.
  privada('privada'),

  /// Mesa de torneio. Vale pontuação, e a autoridade sobre ela é do Motor de
  /// Torneios (classificação, fase, premiação) — ver match_contract.dart.
  torneio('torneio'),

  /// Treino/tutorial. Nunca pontua.
  treinamento('treinamento'),

  /// Partida cujos adversários são robôs oficiais. Nunca pontua — e isso é
  /// deliberado: uma mesa contra bots que valesse ranking seria a forma mais
  /// barata de farmar pontuação que existe.
  contraRobos('contra_robos');

  final String wire;
  const TipoDePartida(this.wire);

  /// Esta partida pode produzir lançamento no ledger competitivo?
  ///
  /// Lista fechada e explícita, escrita para ser conferida de relance. Ela é a
  /// ÚNICA fonte de "isto vale ranking" no sistema — nenhuma outra camada
  /// decide isso por conta própria.
  bool get alteraRanking =>
      this == TipoDePartida.publicaRanqueada || this == TipoDePartida.torneio;

  /// Robôs são esperados nesta modalidade?
  ///
  /// Informativo: serve para o sinal antifraude "bot em mesa que pontua" saber
  /// quando a presença de robô é normal e quando é digna de nota.
  bool get roboEsperado => this == TipoDePartida.contraRobos ||
      this == TipoDePartida.treinamento;

  static TipoDePartida? porWire(String wire) {
    for (final t in TipoDePartida.values) {
      if (t.wire == wire) return t;
    }
    return null;
  }
}

/// Por que uma identidade de partida foi recusada.
class IdentidadeInvalida implements Exception {
  final String motivo;
  const IdentidadeInvalida(this.motivo);

  @override
  String toString() => 'IdentidadeInvalida: $motivo';
}

/// Identidade única e imutável de uma partida.
///
/// Construída UMA vez, por quem tem autoridade, e daí em diante só lida. Não há
/// setter, não há `copiarCom` que troque o `matchId` e não há caminho que
/// aceite um id proposto pelo cliente.
class IdentidadePartida {
  /// O `matchId`. Mesmo texto que `MotorPartida.partidaId`,
  /// `VinculoDeMesa.matchId` e `ResultadoPartida.matchId` — um namespace só.
  final String matchId;

  final TipoDePartida tipo;

  final OrigemDaIdentidade origem;

  /// `ABERTO` | `FECHADO` | `SBTL`, como `Jogo.modalidade`. Viaja com a
  /// identidade porque o histórico precisa dela e ela não muda no meio da
  /// partida.
  final String modalidade;

  /// Instante da cunhagem, em UTC. Recebido por parâmetro: esta camada não lê
  /// relógio, pelo mesmo motivo que o Motor de Partidas não lê.
  final DateTime criadaEm;

  /// Versão do protocolo/formato deste registro de identidade. Aparece no
  /// JSON para que um leitor futuro saiba o que esperar.
  static const int versaoFormato = 1;

  /// Prefixos que o cliente não pode usar nem por acidente.
  ///
  /// Um `matchId` começando com `admin-` num log de suporte seria lido como
  /// "partida administrativa" por quem estivesse investigando. O id é opaco por
  /// contrato, mas humanos leem strings — e é barato tirar a ambiguidade.
  static const Set<String> prefixosReservados = {
    'admin-',
    'sistema-',
    'srv-',
    'suporte-',
  };

  /// Formato aceito: minúsculas, dígitos, `-` e `_`, de 8 a 64 caracteres,
  /// começando por letra ou dígito.
  ///
  /// A faixa não é estética. O piso de 8 impede colisão por id curto demais
  /// (`m1`); o teto de 64 impede um id-payload que carregasse dado inteiro
  /// dentro da chave. Os caracteres permitidos excluem `@`, `.`, `/` e `:` —
  /// exatamente os que apareceriam num e-mail, num caminho ou numa URL, que é a
  /// forma mais comum de dado sensível vazar para dentro de um identificador.
  static final RegExp formato = RegExp(r'^[a-z0-9][a-z0-9_-]{7,63}$');

  IdentidadePartida._({
    required this.matchId,
    required this.tipo,
    required this.origem,
    required this.modalidade,
    required DateTime criadaEm,
  }) : criadaEm = criadaEm.toUtc();

  /// Cunha uma identidade a partir de um `matchId` que a AUTORIDADE produziu.
  ///
  /// Usado em dois lugares, e só neles:
  ///   * pela ponte do servidor, ao abrir uma mesa;
  ///   * pela camada de integração, para adotar o `matchId` que o torneio já
  ///     tinha gerado (ver [IdentidadePartida.deTorneio]).
  ///
  /// [matchId] é validado mesmo vindo de dentro: o servidor também erra, e um id
  /// malformado gravado uma vez fica no histórico para sempre.
  factory IdentidadePartida.cunhada({
    required String matchId,
    required TipoDePartida tipo,
    required OrigemDaIdentidade origem,
    required String modalidade,
    required DateTime criadaEm,
  }) {
    final limpo = matchId.trim();
    if (limpo.isEmpty) {
      throw const IdentidadeInvalida('matchId vazio.');
    }
    if (limpo != matchId) {
      throw IdentidadeInvalida(
          'matchId com espaço nas bordas ("$matchId") — id não se normaliza em '
          'silêncio, porque a versão normalizada seria uma SEGUNDA identidade '
          'para a mesma partida.');
    }
    if (!formato.hasMatch(matchId)) {
      throw IdentidadeInvalida(
          'matchId "$matchId" fora do formato aceito (${formato.pattern}).');
    }
    for (final reservado in prefixosReservados) {
      if (matchId.startsWith(reservado)) {
        throw IdentidadeInvalida(
            'matchId "$matchId" usa o prefixo reservado "$reservado".');
      }
    }
    if (modalidade.isEmpty) {
      throw const IdentidadeInvalida('modalidade não pode ser vazia.');
    }
    if (tipo.alteraRanking && !origem.autoritativa) {
      // Uma partida que pontua e cuja identidade nasceu no próprio aparelho é a
      // definição de pontuação forjável. Recusar aqui é mais barato que
      // descobrir depois, no ledger.
      throw IdentidadeInvalida(
          'partida ${tipo.wire} não pode ter identidade de origem '
          '${origem.wire}: pontuação competitiva exige id cunhado por '
          'autoridade.');
    }
    return IdentidadePartida._(
      matchId: matchId,
      tipo: tipo,
      origem: origem,
      modalidade: modalidade,
      criadaEm: criadaEm,
    );
  }

  /// Adota o `matchId` que o Motor de Torneios já gerou.
  ///
  /// Este é o ponto que garante UM namespace só (§3 da OS: "se já existir
  /// identificador equivalente, reutilizar"). Não há tradução, não há prefixo
  /// novo, não há mapa de-para: o texto é o mesmo que viaja em
  /// `SolicitacaoPartida`, `MotorPartida.partidaId` e `ResultadoPartida`.
  factory IdentidadePartida.deTorneio({
    required String matchId,
    required String modalidade,
    required DateTime criadaEm,
  }) =>
      IdentidadePartida.cunhada(
        matchId: matchId,
        tipo: TipoDePartida.torneio,
        origem: OrigemDaIdentidade.torneio,
        modalidade: modalidade,
        criadaEm: criadaEm,
      );

  /// A porta pela qual um `matchId` proposto pelo CLIENTE entraria — e não entra.
  ///
  /// Existe como função, e não como comentário, para que a recusa seja
  /// testável e para que quem for ligar um endpoint novo encontre um símbolo
  /// com este nome em vez de improvisar. Sempre lança.
  ///
  /// A alternativa — aceitar o id do cliente "só quando parecer bem formado" —
  /// é a falha clássica: o atacante manda um id bem formado que colide com uma
  /// partida alheia e passa a escrever no registro dela.
  static Never doCliente(String? proposto) {
    throw IdentidadeInvalida(
        'o cliente não escolhe matchId (proposto: '
        '${proposto == null ? '<nulo>' : '"$proposto"'}). A identidade nasce na '
        'autoridade da partida — use IdentidadePartida.cunhada no servidor.');
  }

  /// Esta partida pode gerar lançamento competitivo? Delegado ao tipo, de
  /// propósito: existe UMA definição de "vale ranking" no sistema.
  bool get alteraRanking => tipo.alteraRanking;

  /// Identidade da rodada [rodada] desta partida. Derivada, nunca cunhada
  /// separadamente — ver [IdentidadeRodada].
  IdentidadeRodada rodada(int numero, {required int versaoEstado}) =>
      IdentidadeRodada(
        matchId: matchId,
        numero: numero,
        versaoEstado: versaoEstado,
      );

  Map<String, Object?> toJson() => {
        'matchId': matchId,
        'tipo': tipo.wire,
        'origem': origem.wire,
        'modalidade': modalidade,
        'criadaEm': criadaEm.toIso8601String(),
        'versaoFormato': versaoFormato,
      };

  /// Relê uma identidade persistida, revalidando tudo.
  ///
  /// Revalidar em vez de confiar no banco é a mesma disciplina de
  /// `VinculoDeMesa.fromMap`: um registro corrompido é justamente o caso em que
  /// ninguém quer descobrir o problema pela classificação.
  static IdentidadePartida deJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('identidade: objeto esperado.');
    }
    final matchId = raw['matchId'];
    if (matchId is! String) {
      throw FormatException('identidade: matchId ausente (recebido: $matchId).');
    }
    final tipo = TipoDePartida.porWire('${raw['tipo']}');
    if (tipo == null) {
      throw FormatException('identidade $matchId: tipo desconhecido "${raw['tipo']}".');
    }
    final origem = OrigemDaIdentidade.porWire('${raw['origem']}');
    if (origem == null) {
      throw FormatException(
          'identidade $matchId: origem desconhecida "${raw['origem']}".');
    }
    final modalidade = raw['modalidade'];
    if (modalidade is! String || modalidade.isEmpty) {
      throw FormatException('identidade $matchId: modalidade ausente.');
    }
    final criadaEm = DateTime.tryParse('${raw['criadaEm']}');
    if (criadaEm == null) {
      throw FormatException(
          'identidade $matchId: criadaEm não é ISO-8601 (recebido: ${raw['criadaEm']}).');
    }
    try {
      return IdentidadePartida.cunhada(
        matchId: matchId,
        tipo: tipo,
        origem: origem,
        modalidade: modalidade,
        criadaEm: criadaEm,
      );
    } on IdentidadeInvalida catch (e) {
      throw FormatException('identidade $matchId: ${e.motivo}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is IdentidadePartida &&
      other.matchId == matchId &&
      other.tipo == tipo &&
      other.origem == origem &&
      other.modalidade == modalidade &&
      other.criadaEm == criadaEm;

  @override
  int get hashCode => Object.hash(matchId, tipo, origem, modalidade, criadaEm);

  @override
  String toString() => 'IdentidadePartida($matchId ${tipo.wire} via ${origem.wire})';
}

/// Identidade de uma rodada dentro da partida (§4 da OS).
///
/// DERIVADA, NÃO CUNHADA. A OS pede rastreabilidade de rodada e permite
/// explicitamente reutilizar o contrato atual — e o contrato atual já tem tudo
/// de que se precisa: `Jogo.rodada` numera a mão e `MotorPartida.versaoEstado`
/// diz o ponto exato da linha do tempo. Criar um `roundId` sorteado exigiria
/// mudar o protocolo do Motor para carregá-lo, que é justamente o que §4 proíbe.
///
/// O texto de [roundId] é uma FUNÇÃO desses dois números. Duas máquinas chegam
/// ao mesmo id sem se falarem, e o id sobrevive a reinício de servidor sem
/// precisar ser persistido.
class IdentidadeRodada {
  final String matchId;

  /// Número da rodada, como `Jogo.rodada` a conta. Começa em 1.
  final int numero;

  /// `MotorPartida.versaoEstado` no momento em que a rodada foi observada.
  ///
  /// Não entra no [roundId] de propósito: o id precisa ser estável durante a
  /// rodada inteira, e a versão sobe a cada jogada. Ele viaja ao lado, para a
  /// auditoria saber sobre que instante o registro foi tirado.
  final int versaoEstado;

  IdentidadeRodada({
    required this.matchId,
    required this.numero,
    required this.versaoEstado,
  }) {
    if (matchId.isEmpty) {
      throw const IdentidadeInvalida('rodada sem matchId.');
    }
    if (numero < 1) {
      throw IdentidadeInvalida('rodada $numero: a numeração de Jogo começa em 1.');
    }
    if (versaoEstado < 0) {
      throw IdentidadeInvalida('rodada $numero: versaoEstado negativa.');
    }
  }

  /// `<matchId>#r<numero>`. O `#` não pertence ao alfabeto de [IdentidadePartida.formato],
  /// então um `roundId` nunca pode ser confundido com um `matchId` — nem por um
  /// humano lendo log, nem por uma consulta que receba o campo errado.
  String get roundId => '$matchId#r$numero';

  Map<String, Object?> toJson() => {
        'roundId': roundId,
        'matchId': matchId,
        'numero': numero,
        'versaoEstado': versaoEstado,
      };

  @override
  bool operator ==(Object other) =>
      other is IdentidadeRodada &&
      other.matchId == matchId &&
      other.numero == numero &&
      other.versaoEstado == versaoEstado;

  @override
  int get hashCode => Object.hash(matchId, numero, versaoEstado);

  @override
  String toString() => 'IdentidadeRodada($roundId @v$versaoEstado)';
}
