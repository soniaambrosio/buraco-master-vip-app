// ranking_transporte_firebase.dart — o adaptador real das duas callables.
//
// É o ÚNICO arquivo do módulo de ranking que importa `cloud_functions`. Todo o
// resto (fotografia, estado, leitor, telas) fica puro e testável sem emulador —
// mesma fronteira de `sessao/fonte_identidade_firebase.dart` e de
// `colecoes/colecao_firebase.dart`.
//
// A REGIÃO PRECISA CASAR com a declarada em `functions-ranking/src/index.ts`
// (`opcoesCliente.region`). Chamar a região errada devolve `not-found` — que
// aqui viraria "jogador não encontrado", indistinguível de um id que realmente
// não existe. Confundir os dois é como se inventa um fallback.
//
// APP CHECK: `opcoesCliente` do backend traz `enforceAppCheck: true`. O app
// declara `firebase_app_check` no pubspec mas NÃO o ativa (ver a nota no
// próprio pubspec: a ativação acontece antes da abertura pública). Enquanto
// estiver assim, as duas callables recusam em produção — exatamente como já
// acontece com `obterMinhaIdentidade`, que tem a mesma exigência.
//
// A RECUSA CHEGA COMO `unauthenticated`, E NÃO COMO `permission-denied`. Este
// cabeçalho já afirmou o contrário, e a homologação independente mostrou que
// era leitura errada do contrato: em `firebase-functions` 6.x
// (`lib/common/providers/https.js`), token de App Check AUSENTE ou INVÁLIDO com
// `enforceAppCheck` lança `HttpsError("unauthenticated")` — o mesmíssimo código
// de uma credencial recusada. Os dois são indistinguíveis daqui, e por isso o
// motivo se chama `credencialOuAtestacao` em vez de fingir saber qual foi.
//
// Quem resolve a ambiguidade é a camada que conhece a sessão: com sessão local
// viva, o estado é o neutro `acessoRecusado`, com botão de tentar de novo e sem
// afirmar que a sessão expirou. Nenhum dado é inventado por causa disso; é uma
// pendência de ativação, não de código, e está registrada no laudo.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import 'ranking_transporte.dart';

/// Região das Functions de ranking. Casa com `functions-ranking/src/index.ts`.
const String kRegiaoFuncoesRanking = 'southamerica-east1';

/// Nome da callable que abre o escopo do jogador autenticado.
const String kCallableAbrirRanking = 'abrirRanking';

/// Nome da callable que lê o perfil competitivo por id público.
const String kCallableConsultarJogadorPorIdPublico =
    'consultarJogadorPorIdPublico';

/// O escopo pedido a `abrirRanking`.
///
/// `temporada` e não `global`: o Perfil mostra a colocação do jogador na
/// TEMPORADA vigente, que é o recorte a que pertencem a liga e a fotografia. O
/// escopo `amigos` é recusado pelo backend de propósito (não há grafo social no
/// domínio competitivo) e por isso não aparece aqui.
const String kEscopoRankingDoPerfil = 'temporada';

class TransporteRankingFirebase extends TransporteRanking {
  TransporteRankingFirebase({FirebaseFunctions? functions})
    : _injetado = functions;

  FirebaseFunctions? _injetado;

  /// Resolvido na primeira chamada, e não no construtor.
  ///
  /// `FirebaseFunctions.instanceFor` exige `Firebase.initializeApp()` já
  /// executado, e a casca constrói os escopos antes de qualquer tela.
  FirebaseFunctions get _functions => _injetado ??=
      FirebaseFunctions.instanceFor(region: kRegiaoFuncoesRanking);

  @override
  Future<AberturaRanking> abrirRanking() => _chamar(
    kCallableAbrirRanking,
    // `limite` continua de fora: quem escolhe o tamanho da primeira página é a
    // autoridade (`normalizarLimite`), e mandar um número daqui seria o cliente
    // opinando sobre paginação sem ter nenhuma informação que o servidor não
    // tenha.
    const {'escopo': kEscopoRankingDoPerfil},
    AberturaRanking.daResposta,
  );

  @override
  Future<FotografiaRanking> rankingPorIdPublico(String publicId) => _chamar(
    kCallableConsultarJogadorPorIdPublico,
    {'publicPlayerId': publicId},
    FotografiaRanking.doPerfilPublico,
  );

  Future<T> _chamar<T>(
    String nome,
    Map<String, Object?> payload,
    T Function(Object?) ler,
  ) async {
    try {
      final chamada = _functions.httpsCallable(nome);
      final resposta = await chamada.call<Object?>(payload);
      return ler(resposta.data);
    } on FalhaRanking {
      // Já é do vocabulário do domínio (veio do parser). Traduzir de novo
      // perderia o motivo `respostaInvalida`, que é o único que aponta defeito
      // em vez de circunstância.
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw FalhaRanking(_traduzir(e.code), _detalhe(nome, e.code, e.message));
    } on FirebaseException catch (e) {
      throw FalhaRanking(_traduzir(e.code), _detalhe(nome, e.code, e.message));
    }
  }

  /// Detalhe técnico SEM payload.
  ///
  /// O que entra é o nome da callable e o código; a mensagem do servidor entra
  /// porque ela é texto que a própria autoridade publica. O `publicPlayerId`
  /// NÃO entra: é identificador de jogador, e diagnóstico não é lugar de
  /// identificar terceiro.
  static String _detalhe(String nome, String codigo, String? mensagem) =>
      '$nome/$codigo${mensagem == null ? '' : ': $mensagem'}';

  /// Traduz o código do Firebase para o motivo de domínio.
  ///
  /// `failed-precondition` é o código que `exigirTemporada()` usa para dizer
  /// "não há temporada em andamento" — e por isso ele NÃO é uma falha genérica:
  /// vira [MotivoFalhaRanking.semTemporada], que a tela mostra como ausência
  /// honesta em vez de erro.
  ///
  /// `internal` entra em [MotivoFalhaRanking.indisponivel] pela mesma razão que
  /// em `fonte_identidade_firebase.dart`: é o código de exceção não tratada, e
  /// costuma ser transitório.
  ///
  /// `unauthenticated` NÃO é traduzido para uma conclusão sobre a sessão: o
  /// mesmo código chega de credencial recusada e de App Check ausente ou
  /// inválido. A tradução para aqui preserva a ambiguidade; desfazê-la é
  /// trabalho de quem sabe se existe sessão local.
  static MotivoFalhaRanking _traduzir(String codigo) => switch (codigo) {
    'unauthenticated' => MotivoFalhaRanking.credencialOuAtestacao,
    'failed-precondition' => MotivoFalhaRanking.semTemporada,
    'not-found' || 'invalid-argument' => MotivoFalhaRanking.naoEncontrado,
    'permission-denied' => MotivoFalhaRanking.recusado,
    'unavailable' ||
    'deadline-exceeded' ||
    'aborted' ||
    'resource-exhausted' ||
    'internal' => MotivoFalhaRanking.indisponivel,
    _ => MotivoFalhaRanking.desconhecida,
  };
}
