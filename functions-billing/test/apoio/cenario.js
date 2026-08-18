/**
 * cenario.js — o mundo de um caso adversarial, montado de uma vez.
 *
 * DOIS CAMINHOS, E A DIFERENCA IMPORTA
 *
 *   cenarioDeModulo()  liga store + reconciliador + processador de RTDN com um
 *                      RELOGIO INJETADO. E o unico caminho em que o instante de
 *                      cada consulta e ditado, e por isso e onde os casos de
 *                      ORDEM (D, U) e de CONCORRENCIA (Q) sao provados.
 *
 *   cenarioDeIndex()   carrega `index.js` inteiro com as portas trocadas (ver
 *                      `carga_index.js`). Alcanca o catalogo, o credito de
 *                      fichas, as duas varreduras administrativas e os logs
 *                      daquele arquivo — que o caminho de modulo nao ve. Em
 *                      compensacao NAO tem relogio injetavel: `index.js` chama
 *                      `new Date()` direto. Isso esta declarado, e nenhum caso de
 *                      ordem depende dele.
 *
 * TOKENS SINTETICOS, SEMPRE. Todo token deste harness comeca com
 * `token_sintetico_`. Nenhum `purchaseToken` da Google tem esse formato, entao
 * uma varredura por segredo no diff ou nos logs capturados nunca precisa julgar
 * se aquilo era credencial de verdade.
 */

'use strict';

const { chaveDaCompra, criarStore } = require('../../entitlementStore');
const { criarReconciliador } = require('../../reconciliacao');
const { criarProcessadorRtdn } = require('../../rtdn');
const { FirestoreAdversarial, CARIMBO } = require('./firestore_adversarial');
const { criarPlayFalsa } = require('./play_falsa');
const { RelogioFalso } = require('./relogio_falso');
const { carregarIndex } = require('./carga_index');

const PACOTE = 'io.github.soniaambrosio.buracomastervip';
const PRODUTO = 'master_vip_mensal';
const PRODUTO_ANUAL = 'master_vip_anual';
const PRODUTO_FICHAS = 'pacote_fichas_1000';

const U1 = 'jogador_sintetico_1';
const U2 = 'jogador_sintetico_2';

/**
 * Os identificadores de vinculacao das contas de teste.
 *
 * Hexadecimais de 48 caracteres, como os que `gerarVinculo` emite, e visualmente
 * distinguiveis para que uma falha diga de cara qual conta estava envolvida. Um
 * valor com outra forma e recusado por `vinculoBemFormado` antes de virar
 * leitura — e ha teste para isso.
 */
const VINCULO_U1 = '11'.repeat(24);
const VINCULO_U2 = '22'.repeat(24);
/** Bem formado, porem nao registrado por ninguem. */
const VINCULO_ORFAO = '99'.repeat(24);

const TOKEN_A = 'token_sintetico_A';
const TOKEN_B = 'token_sintetico_B';
const TOKEN_C = 'token_sintetico_C';
const HASH_A = chaveDaCompra(TOKEN_A);
const HASH_B = chaveDaCompra(TOKEN_B);
const HASH_C = chaveDaCompra(TOKEN_C);

const T0 = '2026-08-16T10:00:00.000Z';
const T1 = '2026-08-16T11:00:00.000Z';
const T2 = '2026-08-16T12:00:00.000Z';
const T3 = '2026-08-16T13:00:00.000Z';
const T4 = '2026-08-16T14:00:00.000Z';
const PASSADO = '2026-07-16T10:00:00.000Z';
const FUTURO = '2026-09-16T10:00:00.000Z';
const FUTURO_LONGE = '2026-10-16T10:00:00.000Z';

/**
 * As duas pontas da vinculacao, semeadas juntas — como a transacao de
 * `garantirVinculo` as escreve. Semear so uma delas produziria meia relacao, que
 * e um estado que a producao nao consegue criar e que faria o teste provar um
 * mundo que nao existe.
 */
function semearVinculo(db, uid, contaOfuscada) {
  db.semear(`playerBillingIdentity/${uid}`, { uid, contaOfuscada });
  db.semear(`billingAccountIndex/${contaOfuscada}`, { uid, contaOfuscada });
}

const publicoDe = (uid) => `playerEntitlements/${uid}`;
const internoDe = (uid) => `playerEntitlements/${uid}/interno/billing`;
const eventoDe = (id) => `billingEvents/${id}`;
const compraDe = (hash) => `compras/${hash}`;

// ---------------------------------------------------------------- envelopes

/** Envelope do Pub/Sub: o corpo vai em base64, como a Google entrega. */
function mensagem(corpo, messageId = 'msg_1') {
  return {
    messageId,
    data: Buffer.from(JSON.stringify(corpo), 'utf8').toString('base64'),
  };
}

/** Envelope com `data` cru — para payload que nem chega a ser JSON. */
function mensagemCrua(dataBase64, messageId = 'msg_1') {
  return { messageId, data: dataBase64 };
}

function corpoAssinatura(tipo, { token = TOKEN_A, produtoId = PRODUTO, eventoMs = 1000, pacote = PACOTE } = {}) {
  const corpo = { version: '1.0', eventTimeMillis: String(eventoMs) };
  if (pacote !== null) corpo.packageName = pacote;
  corpo.subscriptionNotification = { version: '1.0', notificationType: tipo, purchaseToken: token };
  if (produtoId !== null) corpo.subscriptionNotification.subscriptionId = produtoId;
  return corpo;
}

function corpoAnulacao({ token = TOKEN_A, eventoMs = 1000, pacote = PACOTE } = {}) {
  const corpo = { version: '1.0', eventTimeMillis: String(eventoMs) };
  if (pacote !== null) corpo.packageName = pacote;
  corpo.voidedPurchaseNotification = { purchaseToken: token, orderId: 'GPA.SINTETICO', productType: 1 };
  return corpo;
}

// --------------------------------------------------------- cenario de modulo

/**
 * @param {object} [opcoes]
 * @param {string} [opcoes.inicio]         instante inicial do relogio
 * @param {number} [opcoes.maxTentativas]  orcamento de retry da transacao
 */
function cenarioDeModulo({ inicio = T0, maxTentativas, vincular = true } = {}) {
  const db = new FirestoreAdversarial({ maxTentativas });
  const relogio = new RelogioFalso(inicio);
  const play = criarPlayFalsa();

  // As duas contas ja preparadas, porque na vida real elas estariam: o vinculo
  // nasce em `prepararCompraPlay`, ANTES de o dialogo da Play abrir. Os testes
  // que precisam do contrario passam `vincular: false` ou um identificador
  // explicito na resposta da Play.
  if (vincular) {
    semearVinculo(db, U1, VINCULO_U1);
    semearVinculo(db, U2, VINCULO_U2);
  }

  // `contaOfuscada` passa a ter um padrao: sem ele, toda programacao de resposta
  // teria de repetir o identificador e o ponto do teste se perderia no ruido.
  // Quem exercita propriedade — ausente, orfa, alheia — informa o valor.
  const definirAssinatura = play.definirAssinatura;
  play.definirAssinatura = (token, opcoes) => definirAssinatura(token, {
    contaOfuscada: VINCULO_U1,
    ...opcoes,
  });

  const registros = [];
  const anotar = (nivel) => (...args) => registros.push({ nivel, args });
  const log = { info: anotar('info'), warn: anotar('warn'), error: anotar('error') };

  const store = criarStore({ db, carimbo: () => CARIMBO });
  const reconciliador = criarReconciliador({
    consultarAssinatura: play.consultarAssinatura,
    uidDoVinculo: store.uidDoVinculo,
    aplicarProposta: store.aplicarProposta,
    agora: relogio.porta(),
  });
  const rtdn = criarProcessadorRtdn({
    pacote: PACOTE,
    store,
    reconciliador,
    log,
  });

  return {
    db,
    relogio,
    play,
    store,
    reconciliador,
    rtdn,
    registros,
    /** Tudo que foi para o log, num texto so — para buscar segredo dentro. */
    textoDosLogs: () => JSON.stringify(registros),
    /** Registra (ou substitui) o vinculo de uma conta, como a preparacao faria. */
    vincular(uid, contaOfuscada) {
      semearVinculo(db, uid, contaOfuscada);
      return this;
    },
    /** O registro de "esta compra ja foi creditada". NAO decide mais o dono. */
    registrarCompra(hash, { uid = U1, produtoId = PRODUTO, assinatura = true, estado = 'concedida' } = {}) {
      db.semear(compraDe(hash), { uid, produtoId, assinatura, estado });
      return this;
    },
    /** Um entitlement ja consolidado, como se um evento anterior o tivesse escrito. */
    semearEntitlement(uid, { estado, vipAtivo, expiraEm, hash, token, verificadoEm = T0, produtoId = PRODUTO }) {
      db.semear(publicoDe(uid), {
        uid,
        vipAtivo,
        estado,
        produtoId,
        origem: 'play',
        inicioEm: PASSADO,
        expiraEm,
        renovacaoAutomatica: true,
        atualizadoEm: verificadoEm,
        esquema: 1,
      });
      db.semear(internoDe(uid), {
        uid,
        purchaseTokenHash: hash,
        purchaseToken: token,
        produtoId,
        assinatura: true,
        fonte: 'rtdn',
        ultimaVerificacaoEm: verificadoEm,
        ultimoEventoEm: null,
        ultimoEventoTipo: null,
        esquema: 1,
      });
      return this;
    },
    publico: (uid = U1) => db.ver(publicoDe(uid)),
    interno: (uid = U1) => db.ver(internoDe(uid)),
    evento: (id) => db.ver(eventoDe(id)),
  };
}

// ---------------------------------------------------------- cenario de index

/**
 * `index.js` carregado com portas falsas. Ver o cabecalho de `carga_index.js`
 * para o que exatamente foi trocado e por que nada disto alcanca a rede.
 */
function cenarioDeIndex({ maxTentativas, catalogo, vincular = true } = {}) {
  const { modulo, db, play } = carregarIndex({ maxTentativas });

  if (vincular) {
    semearVinculo(db, U1, VINCULO_U1);
    semearVinculo(db, U2, VINCULO_U2);
  }

  // Mesmo padrao do cenario de modulo: sem ele, cada teste teria de repetir o
  // identificador em toda programacao de resposta.
  const definirAssinatura = play.definirAssinatura;
  play.definirAssinatura = (token, opcoes) => definirAssinatura(token, {
    contaOfuscada: VINCULO_U1,
    ...opcoes,
  });
  const definirProduto = play.definirProduto;
  play.definirProduto = (token, opcoes) => definirProduto(token, {
    contaOfuscada: VINCULO_U1,
    ...opcoes,
  });

  if (catalogo !== null) {
    db.semear('configuracao/billing', {
      produtos: catalogo || {
        [PRODUTO]: { assinatura: true },
        [PRODUTO_ANUAL]: { assinatura: true },
        [PRODUTO_FICHAS]: { assinatura: false, fichas: 1000 },
      },
    });
  }

  return {
    modulo,
    db,
    play,
    /** Chama o callable como o runtime chamaria, com identidade ja verificada. */
    chamar(nome, { uid, admin = false, dados = {} } = {}) {
      const auth = uid ? { uid, token: admin ? { admin: true } : {} } : null;
      return modulo[nome].run({ auth, data: dados, rawRequest: {}, acceptsStreaming: false });
    },
    /** Entrega uma mensagem ao gatilho do Pub/Sub, no formato do CloudEvent. */
    entregar(corpo, messageId = 'msg_1') {
      return modulo.notificacoesPlay.run({
        id: messageId,
        data: { message: mensagem(corpo, messageId) },
      });
    },
    vincular(uid, contaOfuscada) {
      semearVinculo(db, uid, contaOfuscada);
      return this;
    },
    publico: (uid = U1) => db.ver(publicoDe(uid)),
    interno: (uid = U1) => db.ver(internoDe(uid)),
    compra: (hash) => db.ver(compraDe(hash)),
    usuario: (uid = U1) => db.ver(`usuarios/${uid}`),
    vinculo: (uid = U1) => db.ver(`playerBillingIdentity/${uid}`),
  };
}

module.exports = {
  PACOTE,
  PRODUTO,
  PRODUTO_ANUAL,
  PRODUTO_FICHAS,
  U1,
  U2,
  TOKEN_A,
  TOKEN_B,
  TOKEN_C,
  VINCULO_U1,
  VINCULO_U2,
  VINCULO_ORFAO,
  HASH_A,
  HASH_B,
  HASH_C,
  T0,
  T1,
  T2,
  T3,
  T4,
  PASSADO,
  FUTURO,
  FUTURO_LONGE,
  publicoDe,
  internoDe,
  eventoDe,
  compraDe,
  mensagem,
  mensagemCrua,
  corpoAssinatura,
  corpoAnulacao,
  cenarioDeModulo,
  cenarioDeIndex,
};
