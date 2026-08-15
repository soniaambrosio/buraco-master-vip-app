// gerenciar_assinatura.dart — o caminho ate a tela de assinaturas da Play.
//
// PURO: sem Flutter, sem Firebase, sem `url_launcher`. E o que permite provar
// cada decisao deste arquivo com `flutter test` e sem aparelho — mesma fronteira
// que `exclusao_de_conta.dart` estabelece para o vocabulario da exclusao.
//
// ===========================================================================
// POR QUE ESTE ARQUIVO EXISTE
// ===========================================================================
//
// Excluir a conta NAO cancela a assinatura na Google Play. Isso ja estava dito
// em `kAvisosQueNaoVemDaMatriz`, e continua dito. O que faltava era a SAIDA: um
// aviso que informa "voce vai continuar sendo cobrado" e nao oferece para onde
// ir e um aviso pela metade.
//
// A documentacao do Google Play Billing pede que o aplicativo ofereca, nas
// preferencias, um caminho para o jogador gerenciar a propria assinatura, e
// admite deep link direto para a assinatura correspondente.
//
// ===========================================================================
// A REGRA QUE GOVERNA O LINK: NA DUVIDA, A CENTRAL GERAL
// ===========================================================================
//
// O deep link especifico tem a forma
//
//     .../store/account/subscriptions?sku=<produtoId>&package=<pacote>
//
// e ele so ajuda quando os DOIS parametros estao certos. Um `package` que nao
// corresponde ao aplicativo instalado, ou um `sku` que nao existe na conta,
// leva a uma tela de erro — pior do que a lista geral de assinaturas, que ao
// menos mostra a assinatura certa uma linha abaixo.
//
// Por isso [linkDeGerenciamentoDeAssinatura] so monta o deep link quando os dois
// valores sao confiaveis, e cai na central geral em qualquer outro caso. E a
// aplicacao literal da regra da OS: "se nao for possivel resolver com seguranca
// a assinatura especifica, abrir a central geral de assinaturas do Google Play".
//
// ===========================================================================
// O QUE ESTE ARQUIVO NAO FAZ
// ===========================================================================
//
// NAO CANCELA NADA. Nao ha, aqui nem em lugar nenhum deste repositorio, caminho
// que cancele assinatura em nome do jogador — nem pelo cliente, nem pelo backend
// de exclusao. Cancelar e um ato entre a pessoa e a Google, e transforma-lo em
// efeito colateral da exclusao seria mexer no contrato dela sem pedir.
//
// NAO BLOQUEIA A EXCLUSAO. Ter assinatura viva nao e impedimento: quem quer sair
// sai, avisado. Exigir o cancelamento antes seria inventar um requisito para o
// exercicio de um direito.

import 'package:flutter/foundation.dart';

import '../elegibilidade/entitlement.dart';

/// A central de assinaturas do Google Play, sem produto nomeado.
///
/// E o destino de fallback, e o unico que nao pode dar errado: nao depende de
/// `sku` nem de `package`, entao nao tem como apontar para produto inexistente.
const String kCentralDeAssinaturasPlay =
    'https://play.google.com/store/account/subscriptions';

/// O `applicationId` OFICIAL do aplicativo na Google Play.
///
/// NAO E INVENCAO DESTE ARQUIVO. E o mesmo valor declarado em
/// `.github/workflows/release-aab.yml` (`BMV_APPLICATION_ID`), que e o pacote
/// registrado na Play Console e conferido pelo backend de billing. Um teste
/// LE aquele arquivo e falha se os dois divergirem — porque um pacote errado
/// aqui nao quebra compilacao nenhuma, so produz um deep link morto que ninguem
/// descobre ate um assinante reclamar.
const String kPacotePlayOficial = 'io.github.soniaambrosio.buracomastervip';

/// Formato aceito pelo Google Play para `applicationId` e para `productId`.
///
/// Mesmo criterio de `CatalogoBilling.formatoValido` (`billing/catalogo.dart`):
/// comeca por letra minuscula ou digito, segue com minusculas, digitos, ponto e
/// underline. Serve de portao — um valor fora do formato nao vira deep link,
/// vira central geral.
final RegExp kFormatoIdentificadorPlay = RegExp(r'^[a-z0-9][a-z0-9._]*$');

// ===========================================================================
// A SITUACAO
// ===========================================================================

/// Em que pe esta a assinatura, do ponto de vista de "da para gerenciar isto na
/// Play AGORA?".
///
/// TRES VALORES, E NAO UM BOOLEANO, e a diferenca entre os dois primeiros e o
/// ponto inteiro desta enum. "Tem VIP" e "a Google tem uma assinatura sua" NAO
/// sao a mesma pergunta:
///
///   Um jogador em `SUBSCRIPTION_STATE_ON_HOLD` perdeu o acesso VIP (a carencia
///   acabou) e a Google CONTINUA tentando cobrar dele. Se a tela so oferecesse
///   o gerenciamento a quem tem acesso, esse jogador — que e exatamente quem
///   mais precisa da tela — nao veria botao nenhum, excluiria a conta e
///   continuaria sendo cobrado por um aplicativo que ja nao tem.
///
/// Foi para nao produzir esse silencio que [gerenciavel] existe separada de
/// [vigente].
enum SituacaoDaAssinatura {
  /// Nao ha assinatura a gerenciar: nunca houve compra, ou o que houve terminou
  /// de forma que nao deixa relacao viva com a Google (expirada, revogada,
  /// reembolsada).
  ///
  /// A tela NAO oferece "Gerenciar assinatura" aqui, e essa ausencia e a
  /// resposta certa: um botao de gerenciar assinatura para quem nunca assinou e
  /// estado enganoso, nao gentileza.
  nenhuma,

  /// Nao ha acesso VIP agora, e a Google ainda tem uma assinatura registrada —
  /// em espera, pausada ou pendente de pagamento.
  ///
  /// Sem acesso e sem deixar de ser cobrado: o caso em que o caminho para a
  /// Play e mais urgente, e nao menos.
  gerenciavel,

  /// Ha acesso VIP agora (ativa, em carencia, ou cancelada dentro do periodo
  /// pago).
  vigente;

  /// A tela deve oferecer o caminho para a Play?
  bool get ofereceGerenciamento => this != SituacaoDaAssinatura.nenhuma;
}

/// O que a tela de exclusao precisa saber sobre a assinatura, e nada alem.
///
/// NAO CARREGA `purchaseToken`, hash nem `orderId`: esses moram em
/// `playerEntitlements/{uid}/interno/billing`, fechado para todo cliente. O que
/// chega aqui e o que ja e legivel pelo dono.
@immutable
class AssinaturaParaGerenciar {
  final SituacaoDaAssinatura situacao;

  /// O produto da Play que originou o direito. `null` quando nao ha, ou quando
  /// o valor gravado nao respeita o formato da Play.
  final String? produtoId;

  /// A Google vai cobrar de novo?
  ///
  /// E o que separa "a cobranca continua se voce nao cancelar" de "o periodo
  /// pago termina e acabou". As duas frases sao verdadeiras em situacoes
  /// diferentes, e dizer a errada e o tipo de erro que aparece na fatura.
  final bool renovacaoAutomatica;

  /// Ate quando o periodo atual vale. `null` quando desconhecido.
  final DateTime? expiraEm;

  const AssinaturaParaGerenciar({
    required this.situacao,
    this.produtoId,
    this.renovacaoAutomatica = false,
    this.expiraEm,
  });

  /// O estado de quem nao tem nada a gerenciar.
  ///
  /// E TAMBEM O PADRAO SEGURO de toda leitura que falha: uma consulta de
  /// entitlement que nao respondeu vira "nenhuma", e nao "talvez". Prometer uma
  /// tela de gerenciamento que nao existe e pior do que nao prometer.
  static const AssinaturaParaGerenciar nenhuma = AssinaturaParaGerenciar(
    situacao: SituacaoDaAssinatura.nenhuma,
  );

  bool get ofereceGerenciamento => situacao.ofereceGerenciamento;

  /// Deriva a situacao do entitlement consolidado que o Billing escreve.
  ///
  /// O RELOGIO VEM DE FORA, pela mesma razao de [EntitlementVip.vigenteEm]: uma
  /// operacao inteira precisa enxergar o mesmo instante.
  ///
  /// NAO REIMPLEMENTA A VIGENCIA. Quem responde "tem VIP agora?" continua sendo
  /// `vigenteEm`, chamado aqui. O que este metodo acrescenta e a segunda
  /// pergunta, que a vigencia nao responde: "a Google ainda tem uma assinatura
  /// desta pessoa?".
  factory AssinaturaParaGerenciar.doEntitlement(
    EntitlementVip entitlement,
    DateTime agora,
  ) {
    final produto = entitlement.produtoId;
    final produtoValido =
        produto != null && kFormatoIdentificadorPlay.hasMatch(produto)
            ? produto
            : null;

    final situacao = _situacaoDe(entitlement, agora);
    return AssinaturaParaGerenciar(
      situacao: situacao,
      produtoId: situacao == SituacaoDaAssinatura.nenhuma ? null : produtoValido,
      renovacaoAutomatica: entitlement.renovacaoAutomatica,
      expiraEm: entitlement.expiraEm,
    );
  }

  static SituacaoDaAssinatura _situacaoDe(
    EntitlementVip entitlement,
    DateTime agora,
  ) {
    if (entitlement.vigenteEm(agora)) return SituacaoDaAssinatura.vigente;

    switch (entitlement.estado) {
      // A GOOGLE AINDA TEM A ASSINATURA. Nenhum destes tres da acesso, e nos
      // tres a relacao com a loja continua de pe: `em_espera` e cobranca
      // falhando, `pausado` e pausa que o proprio jogador retoma, `pendente` e
      // compra aguardando pagamento.
      case EstadoEntitlement.emEspera:
      case EstadoEntitlement.pausado:
      case EstadoEntitlement.pendente:
        return SituacaoDaAssinatura.gerenciavel;

      // A ASSINATURA AINDA PODE ESTAR VIVA MESMO SEM CONCEDER ACESSO. Cai aqui
      // o documento incoerente — estado que concede acesso mas `vipAtivo:
      // false`, ou sem `expiraEm`. `vigenteEm` ja recusou o acesso, e recusar
      // TAMBEM o caminho para a Play seria punir duas vezes por um defeito de
      // dado que nao e do jogador.
      case EstadoEntitlement.ativo:
      case EstadoEntitlement.emCarencia:
      case EstadoEntitlement.canceladoVigente:
        return SituacaoDaAssinatura.gerenciavel;

      // NAO HA RELACAO VIVA. `expirado` terminou, `revogado` e `reembolsado`
      // sao terminais, `nunca_teve` nunca comecou.
      case EstadoEntitlement.expirado:
      case EstadoEntitlement.revogado:
      case EstadoEntitlement.reembolsado:
      case EstadoEntitlement.nuncaTeve:
        return SituacaoDaAssinatura.nenhuma;

      // ESTADO QUE ESTE CODIGO NAO CONHECE. Oferecer o caminho para a Play e o
      // lado seguro do desconhecido: mandar a pessoa conferir na loja nao
      // concede direito nenhum e nao cobra nada. Silenciar poderia esconder uma
      // cobranca.
      case EstadoEntitlement.desconhecido:
        return SituacaoDaAssinatura.gerenciavel;
    }
  }

  @override
  String toString() =>
      'AssinaturaParaGerenciar(${situacao.name}, produtoId: $produtoId, '
      'renovacaoAutomatica: $renovacaoAutomatica)';
}

// ===========================================================================
// O LINK
// ===========================================================================

/// Para onde mandar o jogador que quer gerenciar a assinatura.
///
/// Devolve o deep link do produto quando — e SOMENTE quando — os dois
/// parametros sao confiaveis; a central geral em qualquer outro caso. Nunca
/// devolve `null`: nao existe estado em que a resposta certa seja "nao ha para
/// onde ir", porque a central geral sempre existe.
Uri linkDeGerenciamentoDeAssinatura({
  String? produtoId,
  String pacote = kPacotePlayOficial,
}) {
  final produto = produtoId?.trim() ?? '';
  final pkg = pacote.trim();

  final resolvido = produto.isNotEmpty &&
      pkg.isNotEmpty &&
      kFormatoIdentificadorPlay.hasMatch(produto) &&
      kFormatoIdentificadorPlay.hasMatch(pkg);

  if (!resolvido) return Uri.parse(kCentralDeAssinaturasPlay);

  return Uri.parse(kCentralDeAssinaturasPlay).replace(
    queryParameters: <String, String>{'sku': produto, 'package': pkg},
  );
}

/// Abre um endereco fora do aplicativo. `true` se alguem atendeu.
///
/// CALLBACK, E NAO IMPORT DE `url_launcher`, pela mesma razao que
/// `ReautenticarJogador` nao importa `firebase_auth`: o controlador precisa ser
/// encenavel sem aparelho, e o caso que mais importa aqui — a Play Store nao
/// abrir — e justamente o que nao acontece num teste que chama a biblioteca de
/// verdade.
typedef AberturaDeLinkExterno = Future<bool> Function(Uri destino);

/// Le a situacao da assinatura de quem esta logado.
///
/// Callback pelo mesmo motivo acima: quem sabe ler `playerEntitlements/{uid}` e
/// o host, que ja conhece `FirebaseAuth` e o repositorio.
typedef LeituraDaAssinatura = Future<AssinaturaParaGerenciar> Function();
