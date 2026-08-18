/**
 * entitlement.js — CICLO DE VIDA do direito VIP. Logica pura, sem Firestore.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * Ate a homologacao P0 integrada, o Billing so sabia CONCEDER. `validarCompraPlay`
 * gravava `vip: true` e ninguem nunca mais reavaliava: renovacao nao estendia
 * prazo, expiracao nao removia acesso, reembolso e revogacao nao tinham efeito.
 * O entitlement era *write-only e monotonico* — o defeito P0-3.
 *
 * O conserto nao e um `if` a mais na validacao: e modelar o direito como ESTADO
 * COM PRAZO, alimentado por eventos que chegam fora de ordem, repetidos e
 * concorrentes. Toda a decisao disso mora aqui, pura, para que `node --test`
 * consiga exercitar reembolso, revogacao, evento antigo e corrida sem emulador,
 * sem rede e sem relogio real — mesma disciplina de `idempotencia.js`.
 *
 * O QUE ESTE ARQUIVO NAO FAZ
 *
 * Nao fala com a Google, nao escreve no Firestore e NAO decide se um jogador tem
 * VIP agora. A ultima pergunta e do CONSUMIDOR e a resposta vive em
 * `app/lib/elegibilidade/entitlement.dart` — uma unica definicao de vigencia, em
 * um unico lugar. Aqui se decide qual FATO gravar; la se decide o que o fato
 * significa no instante da leitura.
 *
 * AS TRES GARANTIAS
 *
 * 1. ORDEM — um evento antigo nao regride o estado. Toda proposta carrega o
 *    instante da consulta autoritativa que a produziu (`verificadoEm`), e uma
 *    proposta mais velha que a ultima verificacao gravada e descartada.
 *
 * 2. TITULARIDADE — o direito e identificado pelo `purchaseToken`, nao pelo
 *    usuario. Evento sobre um token que nao e o token vigente nao mexe no
 *    entitlement de ninguem.
 *
 * 3. IRREVERSIBILIDADE DO DESFECHO — revogacao e reembolso do token vigente sao
 *    terminais. Uma leitura atrasada que ainda diga "ACTIVE" nao ressuscita um
 *    direito estornado; ela vira divergencia registrada, nao concessao.
 */

'use strict';

const { MOTIVO } = require('./propriedade');

/** Versao do formato de `playerEntitlements/{uid}`. Espelha kEsquemaEntitlement. */
const ESQUEMA_ENTITLEMENT = 1;

/**
 * Estados do direito. As strings sao o CONTRATO com o consumidor: os mesmos
 * valores estao em `EstadoEntitlement` (Dart). Mudar um nome aqui sem mudar la
 * faz o consumidor cair em `desconhecido` — que recusa, mas recusa em silencio.
 */
const ESTADO = {
  NUNCA_TEVE: 'nunca_teve',
  ATIVO: 'ativo',
  EM_CARENCIA: 'em_carencia',
  CANCELADO_VIGENTE: 'cancelado_vigente',
  EM_ESPERA: 'em_espera',
  PAUSADO: 'pausado',
  PENDENTE: 'pendente',
  EXPIRADO: 'expirado',
  REVOGADO: 'revogado',
  REEMBOLSADO: 'reembolsado',
  DESCONHECIDO: 'desconhecido',
};

/** Estados compativeis com ter acesso. Nao bastam: a vigencia ainda e temporal. */
const ESTADOS_COM_ACESSO = new Set([
  ESTADO.ATIVO,
  ESTADO.EM_CARENCIA,
  ESTADO.CANCELADO_VIGENTE,
]);

/** Desfechos dos quais nao se volta com o MESMO token. */
const ESTADOS_TERMINAIS = new Set([ESTADO.REVOGADO, ESTADO.REEMBOLSADO]);

/**
 * Traducao dos estados que `purchases.subscriptionsv2.get` devolve.
 *
 * Nenhum estado foi inventado e nenhum tem `default` permissivo: o que nao
 * estiver neste mapa vira `desconhecido`, que NAO concede. Um estado novo da
 * plataforma tem que aparecer como recusa investigavel, e nao ser absorvido por
 * um `else` que deixa passar.
 */
const MAPA_PLAY = {
  SUBSCRIPTION_STATE_ACTIVE: ESTADO.ATIVO,
  SUBSCRIPTION_STATE_IN_GRACE_PERIOD: ESTADO.EM_CARENCIA,
  // Cancelado NAO e perdido: a renovacao foi desligada e o periodo ja pago
  // continua valendo. Quem encerra o acesso e `expiraEm`.
  SUBSCRIPTION_STATE_CANCELED: ESTADO.CANCELADO_VIGENTE,
  SUBSCRIPTION_STATE_ON_HOLD: ESTADO.EM_ESPERA,
  SUBSCRIPTION_STATE_PAUSED: ESTADO.PAUSADO,
  SUBSCRIPTION_STATE_PENDING: ESTADO.PENDENTE,
  SUBSCRIPTION_STATE_EXPIRED: ESTADO.EXPIRADO,
  // Compra pendente que foi cancelada antes de ser paga: o direito nunca chegou
  // a valer, e o efeito e o mesmo de expirado — sem acesso.
  SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED: ESTADO.EXPIRADO,
  SUBSCRIPTION_STATE_UNSPECIFIED: ESTADO.DESCONHECIDO,
};

/** Tipos de notificacao de assinatura (RTDN v2). */
const NOTIFICACAO = {
  RECOVERED: 1,
  RENEWED: 2,
  CANCELED: 3,
  PURCHASED: 4,
  ON_HOLD: 5,
  IN_GRACE_PERIOD: 6,
  RESTARTED: 7,
  PRICE_CHANGE_CONFIRMED: 8,
  DEFERRED: 9,
  PAUSED: 10,
  PAUSE_SCHEDULE_CHANGED: 11,
  REVOKED: 12,
  EXPIRED: 13,
  PENDING_PURCHASE_CANCELED: 20,
};

// ---------------------------------------------------------------------------
// Instantes
// ---------------------------------------------------------------------------

/**
 * ISO-8601 em UTC, ou null. O consumidor Dart RECUSA data sem fuso, entao um
 * carimbo mal formado tem que morrer aqui e nao no outro lado da fronteira.
 */
function instante(valor) {
  if (valor == null || valor === '') return null;
  const d = valor instanceof Date ? valor : new Date(valor);
  const t = d.getTime();
  if (Number.isNaN(t)) return null;
  return d.toISOString();
}

/** `a` e estritamente anterior a `b`? Datas nulas nunca comparam verdadeiro. */
function anteriorA(a, b) {
  if (!a || !b) return false;
  return new Date(a).getTime() < new Date(b).getTime();
}

function maisRecente(a, b) {
  if (!a) return b || null;
  if (!b) return a;
  return anteriorA(a, b) ? b : a;
}

// ---------------------------------------------------------------------------
// Consolidacao a partir da resposta autoritativa da Google
// ---------------------------------------------------------------------------

/**
 * Traduz uma resposta de `purchases.subscriptionsv2.get` no estado consolidado.
 *
 * @param {object} resposta corpo devolvido pela Play Developer API
 * @param {string} agora    instante da CONSULTA, em ISO-8601
 * @returns {{estado: string, vipAtivo: boolean, produtoId: string|null,
 *            inicioEm: string|null, expiraEm: string|null,
 *            renovacaoAutomatica: boolean}}
 */
function consolidarAssinatura(resposta, agora) {
  const bruto = (resposta && resposta.subscriptionState) || null;
  let estado = MAPA_PLAY[bruto] || ESTADO.DESCONHECIDO;

  // A colecao so e percorrida depois de existir e ser uma lista, e cada item so
  // e acessado depois de ser um objeto. Era aqui o achado M-1: a linha do laco
  // protegia o item (`item && item.expiryTime`) e a linha logo abaixo do laco
  // usava `itens[0].productId` sem protecao, entao um elemento nulo virava
  // TypeError nao tratado — e a notificacao virava pilula envenenada, reentregue
  // ate a retencao do topico expirar.
  //
  // O filtro aqui e a SEGUNDA linha de defesa. A primeira e
  // `validarRespostaAssinatura` (propriedade.js), que RECUSA a resposta inteira
  // antes de ela chegar a consolidacao. Esta funcao continua defensiva porque e
  // pura e pode ser chamada de outro caminho amanha; defender duas vezes custa
  // um `filter`, e confiar uma vez so ja custou um defeito.
  const itens = Array.isArray(resposta && resposta.lineItems)
    ? resposta.lineItems.filter((i) => i != null && typeof i === 'object' && !Array.isArray(i))
    : [];

  // Vence o item que vale por mais tempo. Uma assinatura com mais de um item
  // (troca de plano no meio do periodo) so deixa de valer quando o ultimo
  // vence — encerrar no primeiro tiraria acesso ja pago.
  let expiraEm = null;
  let produtoId = null;
  // O plano-base e o que distingue mensal de trimestral de anual: com UM produto
  // de assinatura carregando os tres planos, `produtoId` e igual nas tres compras
  // e so `basePlanId` diz qual foi. Quem precisa da distincao e a entrega mensal
  // de fichas, que le este campo do documento em vez de reconsultar a Google a
  // cada tick.
  let planoBase = null;
  let renovacaoAutomatica = false;
  for (const item of itens) {
    const fim = instante(item && item.expiryTime);
    if (fim && (!expiraEm || anteriorA(expiraEm, fim))) {
      expiraEm = fim;
      produtoId = (item && item.productId) || produtoId;
      planoBase = (item && item.offerDetails && item.offerDetails.basePlanId) || null;
    }
    if (item && item.autoRenewingPlan && item.autoRenewingPlan.autoRenewEnabled === true) {
      renovacaoAutomatica = true;
    }
  }
  if (!produtoId && itens.length > 0) produtoId = itens[0].productId || null;
  if (typeof produtoId !== 'string' || produtoId === '') produtoId = null;

  // Coerencia: um estado que concede acesso com prazo vencido e um estado
  // vencido. Gravar `ativo` com `expiraEm` no passado deixaria o documento
  // contando uma historia que o relogio ja desmentiu.
  const dentroDoPrazo = Boolean(expiraEm) && anteriorA(agora, expiraEm);
  if (ESTADOS_COM_ACESSO.has(estado) && !dentroDoPrazo) {
    estado = ESTADO.EXPIRADO;
  }

  return {
    estado,
    vipAtivo: ESTADOS_COM_ACESSO.has(estado) && dentroDoPrazo,
    produtoId,
    planoBase,
    inicioEm: instante(resposta && resposta.startTime),
    expiraEm,
    renovacaoAutomatica,
  };
}

/**
 * Estado consolidado de um desfecho terminal, que nao depende de consulta.
 *
 * Revogacao e anulacao sao FATOS da notificacao: a Google nao devolve um
 * `subscriptionState` que diga "estornado", e esperar a consulta para descobrir
 * deixaria uma janela em que o reembolsado continua VIP.
 */
function consolidarTerminal(estadoTerminal, agora) {
  if (!ESTADOS_TERMINAIS.has(estadoTerminal)) {
    throw new Error(`estado terminal desconhecido: ${estadoTerminal}`);
  }
  return {
    estado: estadoTerminal,
    vipAtivo: false,
    produtoId: null,
    planoBase: null,
    inicioEm: null,
    // O direito acaba AGORA, e nao no fim do periodo pago: e isso que separa
    // revogacao/estorno de um cancelamento comum.
    expiraEm: instante(agora),
    renovacaoAutomatica: false,
  };
}

// ---------------------------------------------------------------------------
// Interpretacao da notificacao (RTDN)
// ---------------------------------------------------------------------------

/**
 * Le o corpo de uma Real-time Developer Notification.
 *
 * NAO decide estado a partir do payload — decide o que PERGUNTAR. A unica
 * excecao sao os desfechos terminais (revogacao e anulacao), que sao fatos que a
 * consulta de estado nao expressa.
 *
 * @param {object} corpo   JSON ja decodificado da mensagem Pub/Sub
 * @param {string} pacote  applicationId esperado
 */
function interpretarNotificacao(corpo, pacote) {
  if (!corpo || typeof corpo !== 'object') {
    return { acao: 'ignorar', motivo: 'corpo_invalido' };
  }

  // ORIGEM: a mensagem tem de ser do NOSSO pacote, e tem de DIZER qual e.
  //
  // Era aqui o achado M-3. A condicao antiga era `corpo.packageName && ...`:
  // pacote alheio era recusado, pacote AUSENTE passava. A conferencia ficava
  // desligada justamente para a mensagem que nao declara origem — e o caminho
  // terminal (revogacao, anulacao) tira o veredito do proprio payload, entao era
  // exatamente ele que chegava com a unica conferencia de origem desativada.
  //
  // Sem pacote configurado o processamento nao acontece: uma configuracao
  // faltando nao pode virar uma conferencia a menos.
  if (typeof pacote !== 'string' || pacote === '') {
    return { acao: 'ignorar', motivo: MOTIVO.PACOTE_DIVERGENTE, detalhe: 'pacote_oficial_ausente' };
  }
  if (corpo.packageName !== pacote) {
    return { acao: 'ignorar', motivo: MOTIVO.PACOTE_DIVERGENTE };
  }

  const eventoEm = instante(
    corpo.eventTimeMillis != null ? Number(corpo.eventTimeMillis) : null
  );

  if (corpo.testNotification) {
    // A Play Console manda uma destas ao configurar o topico. Registrar e
    // ignorar e o comportamento correto: nao ha compra por tras.
    return { acao: 'ignorar', motivo: 'notificacao_de_teste', eventoEm };
  }

  if (corpo.voidedPurchaseNotification) {
    const v = corpo.voidedPurchaseNotification;
    return {
      acao: 'aplicar_terminal',
      terminal: ESTADO.REEMBOLSADO,
      purchaseToken: v.purchaseToken || null,
      produtoId: null,
      eventoEm,
      motivo: 'compra_anulada',
    };
  }

  if (corpo.subscriptionNotification) {
    const s = corpo.subscriptionNotification;
    const tipo = Number(s.notificationType);
    if (tipo === NOTIFICACAO.REVOKED) {
      return {
        acao: 'aplicar_terminal',
        terminal: ESTADO.REVOGADO,
        purchaseToken: s.purchaseToken || null,
        produtoId: s.subscriptionId || null,
        eventoEm,
        tipo,
        motivo: 'assinatura_revogada',
      };
    }
    return {
      acao: 'reconciliar',
      purchaseToken: s.purchaseToken || null,
      produtoId: s.subscriptionId || null,
      eventoEm,
      tipo,
    };
  }

  if (corpo.oneTimeProductNotification) {
    // Produto avulso nao gera entitlement VIP: ele credita fichas na validacao e
    // acaba ali. Nao ha ciclo de vida para acompanhar.
    return { acao: 'ignorar', motivo: 'produto_avulso', eventoEm };
  }

  return { acao: 'ignorar', motivo: 'sem_secao_reconhecida', eventoEm };
}

// ---------------------------------------------------------------------------
// A decisao de gravar
// ---------------------------------------------------------------------------

/**
 * Aplicar esta proposta sobre o estado atual?
 *
 * E o coracao da correcao. Avaliada SEMPRE com o documento relido dentro da
 * transacao — a mesma disciplina que `podeConceder` ja impunha ao credito.
 *
 * @param {object|null} atual    `{...publico, ...interno}` ja unificado, ou null
 * @param {object} proposta      `{estado, vipAtivo, expiraEm, inicioEm,
 *                                renovacaoAutomatica, produtoId, origem,
 *                                purchaseTokenHash, verificadoEm, eventoEm,
 *                                fonte}`
 * @returns {{aplicar: boolean, motivo: string}}
 */
function decidirAtualizacao(atual, proposta) {
  if (!proposta || !proposta.verificadoEm) {
    return { aplicar: false, motivo: 'proposta_sem_verificacao' };
  }
  if (!atual) {
    return { aplicar: true, motivo: 'primeiro_registro' };
  }

  // --- Migracao do legado --------------------------------------------------
  //
  // O documento vindo de `usuarios/{uid}` e a MELHOR informacao disponivel sobre
  // uma compra que nunca passou por este ciclo de vida — e so isso. Ele so vale
  // onde nao ha nada; sobrescrever um entitlement ja verificado com a Google
  // seria trocar fato por lembranca.
  if (proposta.fonte === 'migracao') {
    return { aplicar: false, motivo: 'legado_nao_sobrescreve' };
  }

  const mesmoToken =
    Boolean(atual.purchaseTokenHash) &&
    atual.purchaseTokenHash === proposta.purchaseTokenHash;

  // TROCA DE PLANO. A Google encadeia assinaturas por `linkedPurchaseToken`: o
  // token novo aponta para o que ele substitui. Sem ler isso, um upgrade ficaria
  // parado em `token_superado` — o entitlement guarda o hash do token velho e
  // recusaria o novo — ate alguem abrir o aplicativo.
  //
  // Isto NAO transfere dono. O uid da proposta ja veio do identificador que a
  // Google devolveu na resposta ATUAL; o token ligado so responde "qual
  // entitlement esta sendo substituido", e a resposta so vale dentro do
  // documento daquele mesmo uid.
  const sucedeTokenLigado =
    Boolean(atual.purchaseTokenHash) &&
    atual.purchaseTokenHash === proposta.purchaseTokenHashLigado;

  // --- Titularidade do direito -------------------------------------------
  //
  // Uma compra validada chega com a identidade autenticada do jogador e com a
  // resposta da Google na mao: ela SUBSTITUI o direito anterior, e e assim que
  // uma reassinatura depois de expirar volta a valer.
  //
  // Ja um evento (notificacao ou reconciliacao) sobre um token que NAO e o
  // vigente fala de uma compra superada. Aplicar seria deixar a expiracao da
  // assinatura velha derrubar a assinatura nova.
  if (!mesmoToken && !sucedeTokenLigado && proposta.fonte !== 'validacao') {
    if (atual.purchaseTokenHash) {
      return { aplicar: false, motivo: 'token_superado' };
    }
  }

  // --- Desfecho terminal ---------------------------------------------------
  //
  // Estornado e revogado nao voltam. Uma consulta atrasada que ainda diga
  // "ACTIVE" e informacao velha, nao autorizacao — e o unico caminho de volta e
  // uma COMPRA NOVA, que entra pelo ramo de titularidade acima.
  const terminalVigente = ESTADOS_TERMINAIS.has(atual.estado) && mesmoToken;
  if (terminalVigente) {
    if (ESTADOS_TERMINAIS.has(proposta.estado)) {
      // Reentrega da mesma anulacao: convergente, sem efeito novo.
      return { aplicar: false, motivo: 'terminal_repetido' };
    }
    return { aplicar: false, motivo: 'terminal_preservado' };
  }

  // Um terminal sempre entra, mesmo que a verificacao seja mais antiga: ele nao
  // e leitura de estado, e fato de estorno.
  if (ESTADOS_TERMINAIS.has(proposta.estado)) {
    return { aplicar: true, motivo: 'terminal' };
  }

  // --- Ordem ---------------------------------------------------------------
  //
  // Duas verificacoes em voo (RTDN e reconciliacao, por exemplo) podem terminar
  // fora de ordem. Vence a que consultou a Google por ULTIMO, e nao a que
  // gravou por ultimo.
  if (
    atual.ultimaVerificacaoEm &&
    !anteriorA(atual.ultimaVerificacaoEm, proposta.verificadoEm)
  ) {
    return { aplicar: false, motivo: 'verificacao_antiga' };
  }

  return { aplicar: true, motivo: 'estado_atualizado' };
}

/**
 * Monta os DOIS documentos a partir da proposta aceita.
 *
 * Dois, e nao um, porque regra do Firestore libera o DOCUMENTO INTEIRO: nao ha
 * como conceder leitura de `vipAtivo` e esconder o `purchaseToken` no mesmo
 * lugar. Projetar campo a campo so e possivel gravando separado — a mesma razao
 * pela qual a moderacao separou `reports` de `reportReceipts`.
 *
 *   publico  -> playerEntitlements/{uid}                 (o dono le)
 *   interno  -> playerEntitlements/{uid}/interno/billing  (ninguem le)
 */
function documentosDeEntitlement(atual, proposta) {
  // A varredura por relogio e a migracao do legado nao carregam token — elas
  // concluem pela data, nao por consulta. Preservar o token que ja estava la
  // (quando e o MESMO direito) e o que mantem a reconciliacao manual possivel
  // depois de uma expiracao; herdar de um direito diferente seria pior que
  // perder, entao a heranca exige hash igual.
  const mesmoToken =
    Boolean(atual && atual.purchaseTokenHash) &&
    atual.purchaseTokenHash === proposta.purchaseTokenHash;

  // Mesma heranca do token, e pela mesma razao: um estorno diz QUE o direito
  // acabou, nao QUAL produto era. Perder o produto apagaria a unica pista de
  // qual assinatura o jogador tinha.
  const produtoId =
    proposta.produtoId || (mesmoToken ? atual.produtoId || null : null);

  // Mesma heranca, e por peso maior: sem `planoBase` a entrega mensal de fichas
  // nao sabe QUANTO deve. Perde-lo numa varredura por relogio (que nao consulta a
  // Google e portanto nao traz o campo) suspenderia as parcelas de um jogador
  // adimplente sem nenhum erro aparecer.
  const planoBase =
    proposta.planoBase || (mesmoToken ? (atual && atual.planoBase) || null : null);

  const publico = {
    uid: proposta.uid,
    vipAtivo: proposta.vipAtivo === true,
    estado: proposta.estado,
    produtoId,
    planoBase,
    origem: proposta.origem,
    inicioEm: proposta.inicioEm || null,
    expiraEm: proposta.expiraEm || null,
    renovacaoAutomatica: proposta.renovacaoAutomatica === true,
    atualizadoEm: proposta.verificadoEm,
    esquema: ESQUEMA_ENTITLEMENT,
  };

  const interno = {
    uid: proposta.uid,
    purchaseTokenHash: proposta.purchaseTokenHash || null,
    // O TOKEN EM CLARO, e a decisao e deliberada. Sem ele nao existe consulta
    // autoritativa fora do momento em que a notificacao chega: nem reconciliacao
    // manual de um entitlement travado, nem reprocessamento depois de a Play
    // Developer API ficar indisponivel. `idempotencia.js` nao guarda o token
    // porque la ele so servia de IDENTIFICADOR, e para identificar o hash basta.
    // Aqui ele e CREDENCIAL DE CONSULTA, e hash nao consulta nada.
    //
    // Mitigacoes, todas verificaveis: mora em `playerEntitlements/{uid}/interno`,
    // com `allow read, write: if false` para cliente e para admin — so o Admin
    // SDK alcanca; nao aparece no documento que o jogador le; e nenhum log deste
    // codebase o imprime (todo log usa `rotuloToken`, que corta o HASH em oito
    // caracteres).
    purchaseToken:
      proposta.purchaseToken || (mesmoToken ? atual.purchaseToken || null : null),
    produtoId,
    assinatura: true,
    fonte: proposta.fonte,
    ultimaVerificacaoEm: proposta.verificadoEm,
    // Carimbo de evento so anda para a FRENTE: uma notificacao antiga que
    // chegou depois nao pode fazer o sistema esquecer que ja viu uma mais nova.
    ultimoEventoEm: maisRecente(
      atual && atual.ultimoEventoEm,
      proposta.eventoEm || null
    ),
    ultimoEventoTipo: proposta.eventoTipo != null ? proposta.eventoTipo : null,
    esquema: ESQUEMA_ENTITLEMENT,
  };

  if (ESTADOS_TERMINAIS.has(proposta.estado)) {
    interno.terminalEm = proposta.verificadoEm;
  }

  return { publico, interno };
}

/**
 * Rotulo de log seguro para um token.
 *
 * Nunca o token, nunca o hash inteiro. Oito caracteres bastam para correlacionar
 * duas linhas de log da mesma compra e nao servem para reconstruir nada.
 */
function rotuloToken(hash) {
  if (typeof hash !== 'string' || hash.length === 0) return 'sem-token';
  return hash.slice(0, 8);
}

module.exports = {
  ESQUEMA_ENTITLEMENT,
  ESTADO,
  ESTADOS_COM_ACESSO,
  ESTADOS_TERMINAIS,
  MAPA_PLAY,
  NOTIFICACAO,
  instante,
  anteriorA,
  maisRecente,
  consolidarAssinatura,
  consolidarTerminal,
  interpretarNotificacao,
  decidirAtualizacao,
  documentosDeEntitlement,
  rotuloToken,
};
