/**
 * play_falsa.js — a Google Play Android Publisher API, de mentira e programavel.
 *
 * NENHUMA REDE. Este arquivo nao importa `googleapis`, nao abre socket e nao le
 * credencial. Ele existe para que a homologacao adversarial possa produzir, de
 * forma deterministica, as respostas que a API real produz raramente ou nunca
 * sob demanda: `ON_HOLD`, `PAUSED`, recuperacao, prazo no passado, corpo
 * malformado, estado que a plataforma ainda nao inventou, timeout e erro 5xx.
 *
 * OS TOKENS SAO SINTETICOS DE PROPOSITO. Todos comecam com `token_sintetico_`,
 * um formato que nenhum `purchaseToken` real tem, para que uma busca por segredo
 * no diff ou nos logs capturados nunca precise decidir se aquilo era um token de
 * verdade.
 *
 * O QUE ELE MODELA DE ESSENCIAL
 *
 *   - resposta por TOKEN, e nao por chamada: reconsultar o mesmo token devolve o
 *     mesmo estado, que e o que a API real faz;
 *   - CONTAGEM de chamadas, porque metade das provas de idempotencia e "quantas
 *     vezes a Google foi perguntada", e nao so "o que ficou gravado";
 *   - FALHA como excecao, porque e assim que `googleapis` falha e e a excecao
 *     subindo que vira reentrega do Pub/Sub (ver o cabecalho de `rtdn.js`);
 *   - LATENCIA opcional, para que uma consulta que comecou antes possa terminar
 *     depois de outra — o unico jeito de exercitar a regra de ordem de verdade.
 */

'use strict';

/** Falha transitoria: 5xx, timeout, socket derrubado. Retentar faz sentido. */
class FalhaTransitoriaPlay extends Error {
  constructor(mensagem) {
    super(mensagem);
    this.name = 'FalhaTransitoriaPlay';
    this.transitoria = true;
  }
}

/** Falha terminal: 400/404. Retentar nao melhora. */
class FalhaPermanentePlay extends Error {
  constructor(mensagem) {
    super(mensagem);
    this.name = 'FalhaPermanentePlay';
    this.transitoria = false;
  }
}

const ESTADOS_PLAY = {
  ATIVA: 'SUBSCRIPTION_STATE_ACTIVE',
  CARENCIA: 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  CANCELADA: 'SUBSCRIPTION_STATE_CANCELED',
  ESPERA: 'SUBSCRIPTION_STATE_ON_HOLD',
  PAUSADA: 'SUBSCRIPTION_STATE_PAUSED',
  PENDENTE: 'SUBSCRIPTION_STATE_PENDING',
  EXPIRADA: 'SUBSCRIPTION_STATE_EXPIRED',
  PENDENTE_CANCELADA: 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED',
  NAO_ESPECIFICADA: 'SUBSCRIPTION_STATE_UNSPECIFIED',
};

/**
 * Corpo de `purchases.subscriptionsv2.get`, no formato documentado.
 *
 * @param {object} opcoes
 * @param {string} opcoes.estado        um valor de ESTADOS_PLAY
 * @param {string|null} opcoes.expiraEm ISO-8601 do fim do periodo pago
 * @param {string} opcoes.produtoId
 * @param {boolean} opcoes.autoRenovacao
 * @param {string|null} opcoes.inicioEm
 * @param {Array|null} opcoes.itens     substitui `lineItems` inteiro, para os
 *                                      casos de corpo malformado
 * @param {string|null} opcoes.contaOfuscada
 *        o `obfuscatedExternalAccountId` que a Google devolve. E DELE que sai a
 *        propriedade da compra desde a correcao P0; `null` encena a compra antiga,
 *        feita antes de o aplicativo preparar o vinculo.
 * @param {string|null} opcoes.tokenLigado
 *        `linkedPurchaseToken`: a assinatura que esta substitui, em troca de plano
 */
function corpoAssinatura({
  estado,
  expiraEm,
  produtoId = 'master_vip_mensal',
  autoRenovacao = true,
  inicioEm = null,
  itens = undefined,
  contaOfuscada = null,
  tokenLigado = null,
  planoBase = null,
}) {
  const corpo = { subscriptionState: estado };
  if (inicioEm !== undefined) corpo.startTime = inicioEm;
  if (contaOfuscada) {
    corpo.externalAccountIdentifiers = { obfuscatedExternalAccountId: contaOfuscada };
  }
  if (tokenLigado) corpo.linkedPurchaseToken = tokenLigado;
  corpo.lineItems = itens !== undefined
    ? itens
    : [
      {
        productId: produtoId,
        expiryTime: expiraEm,
        autoRenewingPlan: { autoRenewEnabled: autoRenovacao },
        // Com UM produto carregando tres planos-base, `productId` e igual nas
        // tres compras e so `basePlanId` diz qual foi. Quem precisa da distincao
        // e a entrega mensal de fichas.
        ...(planoBase ? { offerDetails: { basePlanId: planoBase } } : {}),
      },
    ];
  return corpo;
}

/**
 * @param {object} [opcoes]
 * @param {function(number): Promise<void>} [opcoes.aguardar]
 *        usado quando um token tem latencia programada
 */
function criarPlayFalsa({ aguardar } = {}) {
  /** token -> {tipo: 'corpo'|'erro', valor, latencia} */
  const programa = new Map();
  /** Toda consulta feita, na ordem: {token, saida}. */
  const chamadas = [];
  /** Quantas vezes cada token foi consultado. */
  const porToken = new Map();
  /** token -> resposta de `purchases.products.get` */
  const programaProduto = new Map();
  const chamadasProduto = [];
  /** `acknowledge`/`consume`, na ordem em que a Google os recebeu. */
  const fechamentos = [];
  let falhaDeFechamento = null;

  function programar(token, entrada) {
    programa.set(token, entrada);
    return api;
  }

  const api = {
    ESTADOS: ESTADOS_PLAY,

    /** A assinatura deste token responde com este estado. */
    definirAssinatura(token, opcoes) {
      return programar(token, {
        tipo: 'corpo',
        valor: corpoAssinatura(opcoes),
        latencia: opcoes.latencia || 0,
      });
    },

    /** Resposta crua, para corpo malformado ou campo de tipo errado. */
    definirCorpoBruto(token, valor, { latencia = 0 } = {}) {
      return programar(token, { tipo: 'corpo', valor, latencia });
    },

    /** A consulta deste token LANCA. `erro` e a instancia a ser lancada. */
    definirFalha(token, erro, { vezes = Infinity, latencia = 0 } = {}) {
      return programar(token, { tipo: 'erro', valor: erro, vezes, latencia });
    },

    /** Falha nas primeiras `vezes` consultas e depois responde normalmente. */
    definirFalhaSeguidaDeSucesso(token, erro, vezes, opcoesAssinatura) {
      return programar(token, {
        tipo: 'erro',
        valor: erro,
        vezes,
        depois: corpoAssinatura(opcoesAssinatura),
        latencia: 0,
      });
    },

    /** A porta `consultarAssinatura` que `criarReconciliador` espera. */
    async consultarAssinatura(token) {
      const n = (porToken.get(token) || 0) + 1;
      porToken.set(token, n);

      const entrada = programa.get(token);
      if (!entrada) {
        const erro = new FalhaPermanentePlay(`token nao programado: ${token}`);
        chamadas.push({ token, saida: 'nao_programado' });
        throw erro;
      }

      if (entrada.latencia && aguardar) await aguardar(entrada.latencia);

      if (entrada.tipo === 'erro' && n <= entrada.vezes) {
        chamadas.push({ token, saida: 'erro', erro: entrada.valor.name });
        throw entrada.valor;
      }
      if (entrada.tipo === 'erro') {
        chamadas.push({ token, saida: 'corpo' });
        return entrada.depois;
      }

      chamadas.push({ token, saida: 'corpo' });
      return entrada.valor;
    },

    // ------------------------------------------------------- produto avulso
    //
    // `purchases.products.get` e outra superficie da mesma API, e ela existe
    // aqui por um motivo estreito: o caso N (produto desconhecido) e o caso Q
    // (credito unico sob concorrencia) so tem sentido economico no consumivel,
    // onde o efeito e `FieldValue.increment` e nao um estado idempotente.

    /** purchaseState: 0 comprado, 1 cancelado, 2 pendente. */
    definirProduto(token, { purchaseState = 0, produtoId = 'pacote_fichas', contaOfuscada = null } = {}) {
      const valor = { purchaseState, productId: produtoId };
      // Produto avulso traz o identificador NA RAIZ, e nao aninhado como a
      // assinatura. Os dois formatos existem de verdade, e ler so um deles
      // deixaria metade do catalogo sem propriedade verificavel.
      if (contaOfuscada) valor.obfuscatedExternalAccountId = contaOfuscada;
      programaProduto.set(token, { tipo: 'corpo', valor });
      return api;
    },

    definirFalhaDeProduto(token, erro) {
      programaProduto.set(token, { tipo: 'erro', valor: erro });
      return api;
    },

    async consultarProduto(produtoId, token) {
      chamadasProduto.push({ produtoId, token });
      const entrada = programaProduto.get(token);
      if (!entrada) throw new FalhaPermanentePlay(`token de produto nao programado: ${token}`);
      if (entrada.tipo === 'erro') throw entrada.valor;
      return entrada.valor;
    },

    /** `acknowledge` e `consume`: registradas para provar a ORDEM (credito antes). */
    fechamentos,
    async reconhecer(subscriptionId, token) {
      fechamentos.push({ tipo: 'acknowledge', subscriptionId, token });
      if (falhaDeFechamento) throw falhaDeFechamento;
      return {};
    },
    async consumir(produtoId, token) {
      fechamentos.push({ tipo: 'consume', produtoId, token });
      if (falhaDeFechamento) throw falhaDeFechamento;
      return {};
    },
    definirFalhaDeFechamento(erro) {
      falhaDeFechamento = erro;
      return api;
    },

    chamadas,
    chamadasProduto,
    /** Quantas consultas ao todo, ou so as de um token. */
    total(token) {
      return token === undefined ? chamadas.length : porToken.get(token) || 0;
    },
    zerar() {
      chamadas.length = 0;
      chamadasProduto.length = 0;
      fechamentos.length = 0;
      porToken.clear();
    },
  };

  return api;
}

module.exports = {
  ESTADOS_PLAY,
  FalhaTransitoriaPlay,
  FalhaPermanentePlay,
  corpoAssinatura,
  criarPlayFalsa,
};
