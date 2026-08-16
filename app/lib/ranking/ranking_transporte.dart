// ranking_transporte.dart — a fronteira por onde o ranking REAL entra no app.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO É, E O QUE ELE DELIBERADAMENTE NÃO É
// ---------------------------------------------------------------------------
//
// É domínio puro: não importa Flutter, não importa Firebase, não lê relógio e
// não faz I/O. Mesma fronteira que `sessao/fonte_identidade.dart` estabelece
// para a identidade pública — e pela mesma razão: os casos de concorrência,
// payload malformado e troca de conta precisam ser encenáveis sem emulador.
//
// NÃO é o lugar onde se decide o que a tela mostra. [FotografiaRanking] carrega
// o que o servidor disse, CRU, inclusive um `posicao: 0` ou uma `liga: ''`. Quem
// interpreta é `EstadoRanking`, e num lugar só. Se a tradução morasse aqui,
// passariam a existir duas opiniões sobre o que significa ausência — que é
// exatamente o defeito que a OS anterior fechou.
//
// ---------------------------------------------------------------------------
// O CONTRATO REAL, MEDIDO EM `functions-ranking/src/index.ts` @ 0b0aa63
// ---------------------------------------------------------------------------
//
// `abrirRanking({ escopo, limite? })`
//   exige autenticação (`unauthenticated` sem ela) e App Check — que, quando
//   falha, devolve O MESMO `unauthenticated`, e não `permission-denied`. Ver
//   [MotivoFalhaRanking.credencialOuAtestacao].
//   devolve `{ resumo: { escopo, temporadaId, temporadaNome, faixaTempo, fimEm,
//                        divisao, podio[], escadaLigas[], eu }, primeiraPagina }`
//   `resumo.eu` é `JogadorPublicado | null` — NULO quando o jogador ainda não
//   pontuou na temporada. Não é erro: é a resposta correta para quem não entrou
//   na tabela.
//   `failed-precondition` quando não há temporada vigente.
//
// `consultarJogadorPorIdPublico({ publicPlayerId })`
//   devolve `{ id, temporadaId, classificado, jogador }`, com `jogador` nulo
//   quando `classificado == false`. `not-found` quando o id não existe;
//   `invalid-argument` quando o formato é inválido.
//
// `JogadorPublicado.liga` é RÓTULO PRONTO PARA A TELA, e não um código: o
// backend já devolve `'Bronze'`, `'Em colocacao'` ou `''`. Por isso NÃO existe
// tabela local de nomes de liga neste app — ver a seção "Caso A" em
// docs/LEITOR-RANKING-REAL-V1.md. `ligaId` (`bronze`, `prata`, …) vem separado e
// é `null` justamente quando o rótulo não é uma Liga, mas um estado de
// qualificação.
//
// `JogadorPublicado.posicao` publica `0` para quem ainda não foi apurado
// (`POSICAO_NAO_APURADA` em `functions-ranking/src/projecao.ts`). O zero chega
// aqui como zero, de propósito: quem o transforma em ausência é o
// `EstadoRanking`, que já fazia isso antes de existir backend.

/// Por que uma leitura de ranking falhou.
///
/// O vocabulário é de DOMÍNIO, e não de transporte: quem consome decide o que
/// fazer com `naoAutenticado` sem saber que existe um código `unauthenticated`
/// do Firebase do outro lado.
enum MotivoFalhaRanking {
  /// A autoridade recusou por CREDENCIAL OU ATESTAÇÃO, sem dizer qual das duas
  /// (`unauthenticated`).
  ///
  /// -------------------------------------------------------------------------
  /// O NOME É COMPRIDO PORQUE O CÓDIGO É AMBÍGUO, E ESCONDER ISSO CUSTOU CARO
  /// -------------------------------------------------------------------------
  ///
  /// Este motivo já se chamou `naoAutenticado`, e o nome era uma conclusão que
  /// o código recebido não autoriza. Em `firebase-functions` 6.x — a faixa que
  /// `functions-ranking/package.json` declara — uma callable com
  /// `enforceAppCheck: true` responde `unauthenticated` em TRÊS situações
  /// diferentes (`lib/common/providers/https.js`):
  ///
  ///   - o token de autenticação é inválido;
  ///   - o token de App Check é INVÁLIDO;
  ///   - o token de App Check está AUSENTE.
  ///
  /// Nos dois últimos a sessão do jogador está viva e intacta. Traduzir isso
  /// para "sua sessão expirou" é afirmar um fato que ninguém provou — e mandar
  /// a pessoa entrar de novo numa conta em que ela já está.
  ///
  /// O TRANSPORTE NÃO DESFAZ A AMBIGUIDADE, porque não tem como. Quem decide é
  /// a camada que sabe se existe sessão local: ver
  /// [EstadoRanking.daFalha].
  credencialOuAtestacao,

  /// A autoridade respondeu que não há temporada de ranking em andamento
  /// (`failed-precondition`). Não é falha técnica — é ausência declarada, e a
  /// tela diz que o ranking ainda não está sendo publicado.
  semTemporada,

  /// O identificador público consultado não existe (`not-found`), ou tem
  /// formato inválido (`invalid-argument`).
  naoEncontrado,

  /// Veio resposta, mas ela não tem a forma do contrato. Sempre um defeito —
  /// nosso ou do servidor —, nunca algo a consertar em silêncio na UI.
  respostaInvalida,

  /// Soluço transitório: indisponibilidade, timeout, contenção, cold start.
  /// É o único motivo em que insistir faz sentido por si só.
  indisponivel,

  /// A autoridade recusou a leitura para esta conta (`permission-denied`).
  ///
  /// Também não prova sessão morta: prova que ESTA leitura foi negada. Cai no
  /// mesmo estado neutro de [credencialOuAtestacao] quando há sessão local.
  recusado,

  /// Código que este cliente não conhece. Tratado como falha, e não como
  /// ausência: um erro não entendido não pode virar "sem ranking".
  desconhecida,
}

/// Falha de leitura de ranking, no vocabulário do domínio.
class FalhaRanking implements Exception {
  const FalhaRanking(this.motivo, this.detalhe);

  final MotivoFalhaRanking motivo;

  /// Texto técnico para diagnóstico. NUNCA recebe token, uid, e-mail ou
  /// payload — só o código e a mensagem que a autoridade já publica.
  final String detalhe;

  @override
  String toString() => 'FalhaRanking(${motivo.name}: $detalhe)';
}

/// O que a autoridade disse sobre o estado competitivo de UM jogador.
///
/// Os campos são CRUS. `rotuloLiga` pode ser vazio, `posicao` pode ser zero, e
/// os dois chegam assim até `EstadoRanking`, que é quem tem o direito de
/// concluir que aquilo é ausência.
class FotografiaRanking {
  const FotografiaRanking({
    required this.temporadaId,
    required this.rotuloLiga,
    required this.ligaId,
    required this.posicao,
    required this.classificado,
  });

  /// O jogador tem resposta da autoridade, mas não está na tabela.
  ///
  /// É o `resumo.eu == null` de `abrirRanking` e o `classificado: false` de
  /// `consultarJogadorPorIdPublico`. Resposta legítima, e não erro.
  const FotografiaRanking.semColocacao({required this.temporadaId})
    : rotuloLiga = '',
      ligaId = null,
      posicao = 0,
      classificado = false;

  /// A temporada a que esta fotografia pertence, quando a autoridade a informa.
  ///
  /// NULO é um valor legítimo do contrato (`temporadaVigente()` devolve `null`
  /// em `consultarJogadorPorIdPublico`), e não uma temporada a inventar.
  final String? temporadaId;

  /// O rótulo, exatamente como veio. Pode ser `'Bronze'`, `'Em colocacao'`
  /// ou `''`.
  final String rotuloLiga;

  /// O id estável da Liga, ou `null` quando o rótulo não é uma Liga.
  final String? ligaId;

  /// A colocação, exatamente como veio. `0` significa "ainda não apurada".
  final int posicao;

  /// Se a autoridade considera este jogador classificado na temporada.
  final bool classificado;

  /// Lê `abrirRanking` → `resumo`.
  ///
  /// LANÇA [FalhaRanking] com [MotivoFalhaRanking.respostaInvalida] quando a
  /// forma não bate. Não há caminho em que uma resposta estranha vire uma
  /// fotografia meio preenchida: metade de uma fotografia é uma afirmação
  /// falsa sobre a outra metade.
  factory FotografiaRanking.daAbertura(Object? bruto) {
    final raiz = _mapa(bruto, 'resposta de abrirRanking');
    final resumo = _mapa(raiz['resumo'], 'resumo');
    final temporadaId = _textoOpcional(resumo['temporadaId']);

    final eu = resumo['eu'];
    // NULO É RESPOSTA, E NÃO AUSÊNCIA DE RESPOSTA. O jogador que ainda não
    // pontuou recebe `eu: null` — e é justamente esse caso que, antes, o
    // cliente traduzia em Liga Bronze e #0.
    if (eu == null) {
      return FotografiaRanking.semColocacao(temporadaId: temporadaId);
    }
    return FotografiaRanking._doJogador(
      _mapa(eu, 'resumo.eu'),
      temporadaId: temporadaId,
      classificado: true,
    );
  }

  /// Lê `consultarJogadorPorIdPublico`.
  factory FotografiaRanking.doPerfilPublico(Object? bruto) {
    final raiz = _mapa(bruto, 'resposta de consultarJogadorPorIdPublico');
    final temporadaId = _textoOpcional(raiz['temporadaId']);
    final classificado = raiz['classificado'];
    if (classificado is! bool) {
      throw const FalhaRanking(
        MotivoFalhaRanking.respostaInvalida,
        'campo classificado ausente ou de outro tipo',
      );
    }
    final jogador = raiz['jogador'];
    // O contrato acopla os dois: `classificado: false` vem com `jogador: null`.
    // Aceitar as combinações cruzadas seria deixar o cliente escolher em qual
    // dos dois campos acreditar.
    if (!classificado || jogador == null) {
      if (classificado && jogador == null) {
        throw const FalhaRanking(
          MotivoFalhaRanking.respostaInvalida,
          'classificado sem jogador',
        );
      }
      return FotografiaRanking.semColocacao(temporadaId: temporadaId);
    }
    return FotografiaRanking._doJogador(
      _mapa(jogador, 'jogador'),
      temporadaId: temporadaId,
      classificado: true,
    );
  }

  factory FotografiaRanking._doJogador(
    Map<Object?, Object?> j, {
    required String? temporadaId,
    required bool classificado,
  }) {
    final liga = j['liga'];
    final posicao = j['posicao'];
    if (liga is! String) {
      throw const FalhaRanking(
        MotivoFalhaRanking.respostaInvalida,
        'campo liga ausente ou de outro tipo',
      );
    }
    if (posicao is! int) {
      throw const FalhaRanking(
        MotivoFalhaRanking.respostaInvalida,
        'campo posicao ausente ou de outro tipo',
      );
    }
    return FotografiaRanking(
      temporadaId: temporadaId,
      rotuloLiga: liga,
      ligaId: _textoOpcional(j['ligaId']),
      posicao: posicao,
      classificado: classificado,
    );
  }

  static Map<Object?, Object?> _mapa(Object? bruto, String onde) {
    if (bruto is Map) return bruto;
    throw FalhaRanking(
      MotivoFalhaRanking.respostaInvalida,
      '$onde não é um objeto',
    );
  }

  /// Texto opcional: só uma string NÃO VAZIA conta como valor presente.
  ///
  /// `''` vira `null` já aqui porque, para um identificador, string vazia não é
  /// um id curto — é a ausência dele. Vale para `temporadaId` e `ligaId`; NÃO
  /// vale para `rotuloLiga`, que é texto de exibição e chega cru.
  static String? _textoOpcional(Object? bruto) {
    if (bruto is! String) return null;
    final limpo = bruto.trim();
    return limpo.isEmpty ? null : limpo;
  }

  @override
  String toString() =>
      'FotografiaRanking(temporada: $temporadaId, liga: "$rotuloLiga", '
      'ligaId: $ligaId, posicao: $posicao, classificado: $classificado)';
}

/// A porta por onde o ranking real entra. Uma implementação fala com o
/// Firebase; as dos testes falam com o que o caso precisar.
///
/// As duas leituras são separadas de propósito: são callables diferentes, com
/// autorizações e erros diferentes, e juntá-las num método só obrigaria quem
/// implementa a adivinhar qual das duas o chamador queria.
abstract class TransporteRanking {
  const TransporteRanking();

  /// O ranking do JOGADOR AUTENTICADO (`abrirRanking`).
  ///
  /// Não recebe identificador: o servidor tira o uid do contexto autenticado, e
  /// é por isso que não há como o cliente pedir o ranking de outra pessoa por
  /// esta porta.
  Future<FotografiaRanking> meuRanking();

  /// O ranking de um jogador pelo id PÚBLICO
  /// (`consultarJogadorPorIdPublico`).
  Future<FotografiaRanking> rankingPorIdPublico(String publicId);
}
