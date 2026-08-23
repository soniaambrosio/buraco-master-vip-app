// entitlement.dart — o direito VIP do jogador, do lado de QUEM CONSOME.
//
// Este arquivo NAO concede nada e nao fala com a Google. Ele apenas interpreta o
// documento consolidado que o Billing escreve em `playerEntitlements/{uid}` e
// responde a unica pergunta que os consumidores fazem: **este jogador tem VIP
// AGORA?**
//
// POR QUE A PERGUNTA E TEMPORAL, E NAO UM BOOLEANO GRAVADO
//
// O defeito P0-3 da homologacao integrada era exatamente este: o entitlement era
// monotonico. Uma vez `vip: true`, nada o removia. Se o consumidor confiasse so
// no booleano do documento, bastaria o job de expiracao atrasar cinco minutos —
// ou falhar por uma semana — para um assinante expirado continuar entrando em
// torneio VIP.
//
// Por isso a vigencia e avaliada NA LEITURA, contra o relogio da operacao:
//
//     vigente = vipAtivo && estado concede acesso && agora < expiraEm
//
// As tres condicoes juntas, e nao qualquer uma delas. `vipAtivo` e o veredito do
// Billing no instante da ultima verificacao autoritativa; `estado` diz de que
// natureza era esse veredito; `expiraEm` e o limite que a Google devolveu. Um
// documento meio escrito (estado `revogado` com `vipAtivo` verdadeiro, por
// exemplo) nao concede acesso — a divergencia recusa, nao autoriza.
//
// UMA UNICA DEFINICAO DE VIGENCIA, E ELA MORA AQUI
//
// O Billing (JavaScript) escreve os FATOS: em que estado a Google diz que a
// assinatura esta e ate quando ela vale. Ele nao reimplementa este predicado —
// a varredura de expiracao dele e uma CONSULTA ao Firestore
// (`vipAtivo == true && expiraEm <= agora`), nao uma segunda copia da regra.
// Assim nao existe um segundo "o que e ser VIP" para divergir do primeiro, que e
// o risco que `visao_espectador.dart` documenta no seu proprio cabecalho.
//
// O RELOGIO VEM DE FORA, pela mesma razao que em `moderacao/sancao.dart`: uma
// operacao inteira precisa enxergar o mesmo instante, senao a primeira checagem
// diz "VIP" e a segunda, milissegundos depois, diz "expirado".

/// Versao do formato de `playerEntitlements/{uid}`.
const int kEsquemaEntitlement = 1;

/// As origens que produzem VIP INTEGRAL, e a lista e FECHADA.
///
/// Ela nao e uma preferencia: cada nome aqui tem um PRODUTOR nesta arvore, e
/// nenhum nome sem produtor entrou.
///
///   play             `functions-billing/rtdn.js` e `reconciliacao.js`
///                    escrevem a partir da Play Developer API, e
///                    `index.js` reescreve o vencimento preservando a origem.
///   legado_usuarios  `functions-billing/migracaoLegado.js`, a migracao da
///                    populacao que ja tinha VIP antes do Billing.
///
/// FECHADA POR LISTA, E NAO POR `else`. A diferenca decide o caso que esta
/// constante existe para decidir: `administrativa` esta DOCUMENTADA em
/// [EntitlementVip.origem] e nao tem produtor nenhum — e e exatamente sob
/// ela que uma assinatura PRESENTEADA seria escrita no dia em que alguem a
/// implementasse. Uma verificacao escrita como "nao e cortesia" deixaria esse
/// documento passar; uma lista fechada obriga quem criar a origem nova a vir
/// aqui e DECIDIR, no diff, se ela concede acesso a Torneio.
///
/// O mesmo vale para o rotulo que ninguem previu: origem ausente, vazia ou
/// desconhecida nao esta na lista, entao recusa. Ausencia nao vira VIP.
const Set<String> kOrigensVipIntegral = {'play', 'legado_usuarios'};

/// Em que situacao a assinatura esta, segundo a ultima verificacao autoritativa.
///
/// Os nomes espelham os estados que a Play Developer API devolve em
/// `purchases.subscriptionsv2.get` mais os dois desfechos que chegam por
/// notificacao (revogacao e reembolso). Nenhum estado foi inventado.
enum EstadoEntitlement {
  /// Nunca houve compra, ou o documento nao existe.
  nuncaTeve('nunca_teve'),

  /// `SUBSCRIPTION_STATE_ACTIVE`. Assinatura em dia.
  ativo('ativo'),

  /// `SUBSCRIPTION_STATE_IN_GRACE_PERIOD`. O pagamento falhou, mas a Google
  /// mantem o acesso enquanto tenta cobrar de novo. Vale como VIP.
  emCarencia('em_carencia'),

  /// `SUBSCRIPTION_STATE_CANCELED`. O jogador desligou a renovacao, e o periodo
  /// JA PAGO continua valendo ate `expiraEm`.
  ///
  /// Este e o estado do caso G da OS: cancelar nao e perder na hora. Tirar o
  /// acesso aqui seria cobrar por um mes e entregar meio.
  canceladoVigente('cancelado_vigente'),

  /// `SUBSCRIPTION_STATE_ON_HOLD`. Cobranca falhou e a carencia acabou. Sem
  /// acesso ate a Google recuperar o pagamento.
  emEspera('em_espera'),

  /// `SUBSCRIPTION_STATE_PAUSED`. Pausa pedida pelo jogador. Sem acesso.
  pausado('pausado'),

  /// `SUBSCRIPTION_STATE_PENDING`. A compra existe mas ainda nao foi paga
  /// (boleto, aprovacao de responsavel). Direito nenhum ate confirmar.
  pendente('pendente'),

  /// `SUBSCRIPTION_STATE_EXPIRED`, ou vencimento constatado pelo relogio.
  expirado('expirado'),

  /// `SUBSCRIPTION_REVOKED` (tipo 12 da notificacao). Acesso retirado na hora,
  /// sem esperar o fim do periodo.
  revogado('revogado'),

  /// Compra anulada (`voidedPurchaseNotification`): estorno ou chargeback.
  reembolsado('reembolsado'),

  /// A Google devolveu um estado que este codigo nao conhece.
  ///
  /// Existe para que um estado novo da plataforma vire RECUSA explicita e
  /// registravel, e nao um `else` que concede por descuido.
  desconhecido('desconhecido');

  final String wire;
  const EstadoEntitlement(this.wire);

  /// Este estado, por si, e compativel com ter acesso VIP?
  ///
  /// Nao basta para conceder: a vigencia ainda depende do relogio. Serve para
  /// que um documento incoerente (revogado + `vipAtivo: true`) nao passe.
  bool get concedeAcesso =>
      this == ativo || this == emCarencia || this == canceladoVigente;

  /// Desfecho do qual nao se volta com o MESMO `purchaseToken`.
  ///
  /// Uma nova compra (outro token) comeca um entitlement novo e nao esbarra
  /// nisto — quem governa a identidade do direito e o token, nao o usuario.
  bool get terminal => this == revogado || this == reembolsado;

  static EstadoEntitlement porWire(String? wire) {
    if (wire == null) return EstadoEntitlement.desconhecido;
    for (final e in EstadoEntitlement.values) {
      if (e.wire == wire) return e;
    }
    return EstadoEntitlement.desconhecido;
  }
}

/// O documento `playerEntitlements/{uid}`, ja interpretado.
///
/// So os campos que um consumidor pode ver. `purchaseToken`, hash, `orderId` e
/// metadados de verificacao NAO moram aqui: eles ficam em
/// `playerEntitlements/{uid}/interno/billing`, fechado para todo cliente. A
/// separacao e a mesma que a moderacao usa entre `reports` (interno) e
/// `reportReceipts` (do denunciante): regra do Firestore libera o DOCUMENTO
/// INTEIRO, entao esconder campo so e possivel gravando dois documentos.
class EntitlementVip {
  final String uid;

  /// Veredito do Billing no instante da ultima verificacao autoritativa.
  final bool vipAtivo;

  final EstadoEntitlement estado;

  /// Produto da Play que originou o direito. `null` antes da primeira compra.
  final String? produtoId;

  /// Quem produziu este documento: `play`, `legado_usuarios` ou
  /// `administrativa`. Fica legivel para que uma divergencia tenha de onde ser
  /// investigada sem abrir o documento interno.
  final String origem;

  final DateTime? inicioEm;

  /// Ate quando o direito vale. `null` significa "sem prazo conhecido" e, por
  /// decisao explicita, NAO concede acesso: o unico produto VIP do catalogo e
  /// assinatura, e assinatura sempre tem vencimento. Um documento sem prazo e
  /// dado incompleto, e dado incompleto recusa.
  final DateTime? expiraEm;

  final bool renovacaoAutomatica;
  final DateTime? atualizadoEm;

  const EntitlementVip({
    required this.uid,
    this.vipAtivo = false,
    this.estado = EstadoEntitlement.nuncaTeve,
    this.produtoId,
    this.origem = 'desconhecida',
    this.inicioEm,
    this.expiraEm,
    this.renovacaoAutomatica = false,
    this.atualizadoEm,
  });

  /// O jogador sem nenhum documento de entitlement.
  ///
  /// Ausencia e recusa, e nao "ainda nao sei": um consumidor que tratasse
  /// documento ausente como talvez-VIP entregaria acesso pago a quem nunca
  /// comprou.
  const EntitlementVip.ausente(this.uid)
      : vipAtivo = false,
        estado = EstadoEntitlement.nuncaTeve,
        produtoId = null,
        origem = 'ausente',
        inicioEm = null,
        expiraEm = null,
        renovacaoAutomatica = false,
        atualizadoEm = null;

  /// O jogador tem VIP em [agora]?
  ///
  /// ESTA e a definicao. Qualquer consumidor que precise da resposta chama
  /// daqui; nenhum deles reimplanta a conta.
  bool vigenteEm(DateTime agora) {
    if (!agora.isUtc) {
      throw ArgumentError.value(agora, 'agora', 'instante precisa estar em UTC');
    }
    if (!vipAtivo) return false;
    if (!estado.concedeAcesso) return false;
    final ate = expiraEm;
    if (ate == null) return false;
    return agora.isBefore(ate);
  }

  /// A origem deste direito e uma das que produzem VIP INTEGRAL?
  ///
  /// Pergunta SEPARADA de [vigenteEm] porque as duas respondem coisas
  /// diferentes: `vigenteEm` diz se o direito VALE AGORA, e esta diz DE ONDE
  /// ele veio. Um passe de cortesia e um presente podem ser perfeitamente
  /// vigentes; o que eles nao sao e assinatura integral.
  bool get origemDeVipIntegral => kOrigensVipIntegral.contains(origem);

  /// O jogador tem VIP INTEGRAL vigente em [agora]?
  ///
  /// [vigenteEm] mais [origemDeVipIntegral], nesta ordem — e a ordem importa:
  /// `vigenteEm` e quem recusa instante sem fuso, e curto-circuitar a origem
  /// antes dele faria um documento de origem estranha silenciar a exigencia
  /// de UTC, que e uma exigencia de TODOS os chamadores.
  ///
  /// POR QUE ESTE PREDICADO E OUTRO, E NAO UM ENDURECIMENTO DE [vigenteEm]
  ///
  /// `vigenteEm` responde "tem VIP agora?" para a loja, para o selo, para a
  /// comunicacao e para o Billing — consumidores para os quais um direito
  /// administrativo ou presenteado, se um dia existir, DEVE valer. Mudar a
  /// resposta deles para fechar a porta de Torneios seria decidir, de
  /// carona, uma politica que ninguem arbitrou.
  ///
  /// Torneios V1 pede mais: la o acesso e pago e ranqueado, e a politica
  /// congelada e "somente assinatura integral vigente". Quem quer essa
  /// resposta chama ESTE metodo. Continua havendo UMA definicao de vigencia
  /// — a de [vigenteEm], reutilizada aqui — e nao duas contas paralelas.
  bool integralVigenteEm(DateTime agora) =>
      vigenteEm(agora) && origemDeVipIntegral;

  /// Le o documento como ele chega do Firestore.
  ///
  /// Tolerante a campo ausente e a documento nulo — o que NAO significa
  /// tolerante a conceder: todo caminho de duvida cai em "sem VIP".
  static EntitlementVip fromMap(String uid, Map<String, Object?>? m) {
    if (m == null || m.isEmpty) return EntitlementVip.ausente(uid);

    DateTime? instante(String chave) {
      final v = m[chave];
      if (v is! String || v.isEmpty) return null;
      return DateTime.parse(v).toUtc();
    }

    return EntitlementVip(
      // O uid do caminho vence o do corpo: quem identifica o documento e onde
      // ele esta, nao um campo que pode ter sido copiado de outro registro.
      uid: uid,
      vipAtivo: m['vipAtivo'] == true,
      estado: EstadoEntitlement.porWire(m['estado'] as String?),
      produtoId: m['produtoId'] as String?,
      origem: (m['origem'] as String?) ?? 'desconhecida',
      inicioEm: instante('inicioEm'),
      expiraEm: instante('expiraEm'),
      renovacaoAutomatica: m['renovacaoAutomatica'] == true,
      atualizadoEm: instante('atualizadoEm'),
    );
  }

  Map<String, Object?> toJson() => {
        'uid': uid,
        'vipAtivo': vipAtivo,
        'estado': estado.wire,
        'produtoId': produtoId,
        'origem': origem,
        'inicioEm': inicioEm?.toIso8601String(),
        'expiraEm': expiraEm?.toIso8601String(),
        'renovacaoAutomatica': renovacaoAutomatica,
        'atualizadoEm': atualizadoEm?.toIso8601String(),
        'esquema': kEsquemaEntitlement,
      };

  @override
  String toString() =>
      'EntitlementVip($uid, ${estado.wire}, vipAtivo: $vipAtivo, '
      'expiraEm: ${expiraEm?.toIso8601String()})';
}
