// estado_ui.dart — os estados que a interface de compra precisa saber
// distinguir. Dart puro, sem widget e sem plugin.
//
// A DISTINCAO QUE ESTE ARQUIVO EXISTE PARA IMPOR
//
// "A compra foi concluida na Play Store" e "o jogador tem VIP" sao coisas
// diferentes, separadas por uma ida ao servidor que pode falhar, demorar ou
// recusar. Misturar as duas e o defeito que a OS lista como criterio de
// reprovacao: interface que diz "VIP ativado" so porque a Play respondeu
// `purchased`.
//
// Por isso o estado da COMPRA e o estado do DIREITO moram em campos separados de
// [PainelBilling], e a unica funcao que responde "mostrar como VIP?" —
// [PainelBilling.mostrarComoVip] — nao olha para o estado da compra em momento
// nenhum. Ela pergunta ao `EntitlementVip` lido de `playerEntitlements/{uid}`,
// que e escrito exclusivamente pelo backend.
//
// Um jogador pode estar em [EstadoCompra.validada] e NAO ser VIP: assinatura em
// `ON_HOLD`, direito ja expirado, documento ainda nao propagado. E pode ser VIP
// sem nenhuma compra nesta sessao — que e o caso normal de quem so abriu o app.
library;

import '../elegibilidade/entitlement.dart';

/// Situacao da vitrine.
enum EstadoCatalogo {
  /// Antes de `iniciar()`.
  naoIniciado,

  /// Consultando a Play Store.
  carregando,

  /// Sem Play Billing: plataforma nao suportada, aparelho sem Play Services,
  /// ou a Play Store respondeu que nao esta disponivel.
  indisponivel,

  /// A Play respondeu, mas nao ha produtos — porque o catalogo do cliente esta
  /// vazio (situacao de hoje, antes de a Play Console liberar a area de
  /// produtos) ou porque nenhum dos IDs declarados foi encontrado.
  ///
  /// NAO E ERRO. E o estado que o primeiro AAB precisa exibir sem quebrar.
  semProdutos,

  /// Ha produtos consultaveis.
  pronto,
}

/// Situacao da compra em curso.
///
/// A ordem dos valores acompanha o caminho normal, mas o fluxo nao e linear:
/// uma reentrega da Play Store entra direto em [aguardandoValidacao] sem passar
/// por [emAndamento].
enum EstadoCompra {
  /// Nenhuma compra em curso.
  ociosa,

  /// O fluxo da Play Store foi aberto e o jogador esta decidindo.
  emAndamento,

  /// A Play Store aceitou o pedido mas o pagamento ainda nao se concretizou
  /// (boleto, aprovacao de responsavel). Nada e concedido aqui.
  pendente,

  /// O jogador desistiu.
  cancelada,

  /// A propria Play Store devolveu erro. Nao houve compra.
  erroDaPlay,

  /// A compra existe e o token foi enviado ao backend. O veredito nao chegou.
  aguardandoValidacao,

  /// O backend aceitou a compra e ja gravou o que ela concede.
  ///
  /// ISTO NAO E "O JOGADOR E VIP". Ver [PainelBilling.mostrarComoVip].
  validada,

  /// O backend recusou de forma DEFINITIVA. A compra foi encerrada na Play
  /// Store e nada foi concedido.
  recusada,

  /// Nao houve veredito (rede, sessao caida, catalogo do servidor ainda vazio).
  ///
  /// A COMPRA NAO FOI PERDIDA: ela continua pendente na Play Store de proposito
  /// e volta a ser validada na proxima entrega. E o estado que a interface deve
  /// explicar sem alarmar e sem prometer.
  aguardandoRevalidacao,
}

/// Situacao da restauracao.
enum EstadoRestauracao {
  ociosa,
  emAndamento,

  /// A Play reentregou compras e elas foram revalidadas.
  concluida,

  /// A Play nao tinha nenhuma compra restauravel para esta conta.
  nadaARestaurar,
}

/// O retrato completo que a interface consome.
class PainelBilling {
  const PainelBilling({
    this.catalogo = EstadoCatalogo.naoIniciado,
    this.compra = EstadoCompra.ociosa,
    this.restauracao = EstadoRestauracao.ociosa,
    this.entitlement,
    this.produtoEmFoco,
    this.diagnostico,
  });

  final EstadoCatalogo catalogo;
  final EstadoCompra compra;
  final EstadoRestauracao restauracao;

  /// O direito lido de `playerEntitlements/{uid}`. `null` enquanto a leitura nao
  /// chegou — e ausencia NAO concede nada.
  final EntitlementVip? entitlement;

  /// O produto que a ultima transicao de compra dizia respeito.
  final String? produtoEmFoco;

  /// Texto tecnico do ultimo problema. Para log e suporte, nao para a tela.
  /// Nunca contem `purchaseToken` — ver `redigirToken` em `validacao.dart`.
  final String? diagnostico;

  /// O jogador deve ser APRESENTADO como VIP em [agora]?
  ///
  /// ESTA E A UNICA PERGUNTA QUE AUTORIZA O SELO VIP NA INTERFACE, e ela nao
  /// olha [compra]. A conta inteira mora em [EntitlementVip.vigenteEm], que e a
  /// mesma definicao que os torneios usam — nao ha uma segunda nocao de "ser
  /// VIP" neste projeto para divergir desta.
  ///
  /// Entitlement ausente responde `false`: quem nunca comprou, e quem comprou e
  /// cujo documento ainda nao chegou, sao tratados igual. Duvida nao concede.
  bool mostrarComoVip(DateTime agora) {
    final e = entitlement;
    if (e == null) return false;
    return e.vigenteEm(agora);
  }

  /// Ha uma compra paga que ainda nao virou direito?
  ///
  /// Serve para a interface explicar a espera em vez de mostrar um estado morto.
  /// E o par honesto de [mostrarComoVip]: "pagamos, o servidor ainda nao
  /// confirmou" e uma situacao real e precisa ter texto proprio.
  bool get aguardandoServidor =>
      compra == EstadoCompra.aguardandoValidacao ||
      compra == EstadoCompra.aguardandoRevalidacao;

  /// A vitrine pode oferecer compra agora?
  bool get podeComprar =>
      catalogo == EstadoCatalogo.pronto &&
      compra != EstadoCompra.emAndamento &&
      compra != EstadoCompra.aguardandoValidacao;

  PainelBilling copiarCom({
    EstadoCatalogo? catalogo,
    EstadoCompra? compra,
    EstadoRestauracao? restauracao,
    EntitlementVip? entitlement,
    String? produtoEmFoco,
    String? diagnostico,
    bool limparDiagnostico = false,
  }) {
    return PainelBilling(
      catalogo: catalogo ?? this.catalogo,
      compra: compra ?? this.compra,
      restauracao: restauracao ?? this.restauracao,
      entitlement: entitlement ?? this.entitlement,
      produtoEmFoco: produtoEmFoco ?? this.produtoEmFoco,
      diagnostico: limparDiagnostico ? null : (diagnostico ?? this.diagnostico),
    );
  }

  @override
  String toString() => 'PainelBilling(catalogo: $catalogo, compra: $compra, '
      'restauracao: $restauracao, entitlement: ${entitlement?.estado.wire})';
}
