/**
 * Testes do CAMINHO da Real-time Developer Notification.
 *
 * O QUE ESTE ARQUIVO ACRESCENTA A `entitlement.test.js`
 *
 * Aquele arquivo prova as DECISOES puras: dado um estado e uma proposta, aplicar
 * ou nao. Este prova o CAMINHO INTEIRO de uma notificacao — do payload base64 do
 * Pub/Sub ate os documentos gravados — incluindo as tres coisas que nao existem
 * no nivel puro e que sao justamente onde um RTDN quebra na pratica:
 *
 *   1. a TRANSACAO, com contencao de verdade (ver `apoio/firestore_falso.js`);
 *   2. a FALHA da Play Developer API, que precisa virar reentrega e nao decisao;
 *   3. o VAZAMENTO do `purchaseToken` para log ou para documento de cliente.
 *
 * FRONTEIRA DECLARADA, para nao chamar de integracao o que nao e:
 *
 *   PROVADO AQUI
 *     A orquestracao de `rtdn.js`, `reconciliacao.js` e `entitlementStore.js`
 *     contra um Firestore falso com concorrencia otimista. As respostas da Play
 *     Developer API entram como LITERAIS, no formato documentado de
 *     `purchases.subscriptionsv2`.
 *
 *   NAO PROVADO AQUI, e nao se finge o contrario
 *     Que o topico Pub/Sub existe e entrega; que a Play Console esta apontada
 *     para ele; que as regras de `firestore.rules` recusam o que se espera; que a
 *     resposta REAL da Google tem os campos que este codigo le. Nada disso e
 *     alcancavel sem projeto implantado e credencial de conta de servico, e o
 *     relatorio da OS lista cada um como pendencia de ambiente.
 *
 * A numeracao RTDN-01..18 e a da OS, para conferencia direta.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { ESTADO, NOTIFICACAO } = require('../entitlement');
const { chaveDaCompra, criarStore } = require('../entitlementStore');
const { criarReconciliador } = require('../reconciliacao');
const { criarProcessadorRtdn } = require('../rtdn');
const { FirestoreFalso, CARIMBO } = require('./apoio/firestore_falso');

const PACOTE = 'io.github.soniaambrosio.buracomastervip';
const UID = 'jogador-1';
const PRODUTO = 'master_vip_mensal';

const TOKEN = 'purchase-token-VIGENTE-nao-pode-vazar-9f3a';
const HASH = chaveDaCompra(TOKEN);
const TOKEN_VELHO = 'purchase-token-DA-ASSINATURA-ANTERIOR-11bc';
const HASH_VELHO = chaveDaCompra(TOKEN_VELHO);

const T1 = '2026-08-01T13:00:00.000Z';
const T2 = '2026-08-01T14:00:00.000Z';
const T3 = '2026-08-01T15:00:00.000Z';
const FUTURO = '2026-09-01T12:00:00.000Z';
const FUTURO_ESTENDIDO = '2026-10-01T12:00:00.000Z';
const PASSADO = '2026-07-01T12:00:00.000Z';

const DOC_PUBLICO = `playerEntitlements/${UID}`;
const DOC_INTERNO = `playerEntitlements/${UID}/interno/billing`;

// ---------------------------------------------------------------- utilidades

/** Resposta de `purchases.subscriptionsv2.get`, no formato documentado. */
function respostaPlay(estado, expiryTime, { autoRenew = true } = {}) {
  return {
    subscriptionState: estado,
    startTime: PASSADO,
    lineItems: [
      { productId: PRODUTO, expiryTime, autoRenewingPlan: { autoRenewEnabled: autoRenew } },
    ],
  };
}

function ativa(expiry = FUTURO) {
  return respostaPlay('SUBSCRIPTION_STATE_ACTIVE', expiry);
}

/** Envelope do Pub/Sub: o corpo vai em base64, como a Google entrega. */
function mensagem(corpo, messageId = 'msg-1') {
  return { messageId, data: Buffer.from(JSON.stringify(corpo), 'utf8').toString('base64') };
}

function notificacaoAssinatura(tipo, { token = TOKEN, eventTimeMillis = 1000 } = {}) {
  return {
    version: '1.0',
    packageName: PACOTE,
    eventTimeMillis: String(eventTimeMillis),
    subscriptionNotification: {
      version: '1.0',
      notificationType: tipo,
      purchaseToken: token,
      subscriptionId: PRODUTO,
    },
  };
}

function notificacaoAnulacao({ token = TOKEN, eventTimeMillis = 1000 } = {}) {
  return {
    version: '1.0',
    packageName: PACOTE,
    eventTimeMillis: String(eventTimeMillis),
    voidedPurchaseNotification: { purchaseToken: token, orderId: 'GPA.1', productType: 1 },
  };
}

/** Porta assincrona, para interleaving deterministico. */
function porta() {
  let abrir;
  const aberta = new Promise((r) => {
    abrir = r;
  });
  return { aberta, abrir };
}

/**
 * Monta o cenario inteiro: banco falso + store + reconciliador + processador.
 *
 * `respostas` recebe o token e devolve a resposta da Play — ou LANCA, que e como
 * se representa a indisponibilidade da API. `relogio` e uma lista de instantes
 * consumida em ordem; o ultimo se repete.
 */
function montar({ respostas, relogio = [T1], titular = true } = {}) {
  const db = new FirestoreFalso();

  if (titular) {
    db.semear(`compras/${HASH}`, {
      uid: UID,
      produtoId: PRODUTO,
      assinatura: true,
      estado: 'concedida',
    });
    db.semear(`compras/${HASH_VELHO}`, {
      uid: UID,
      produtoId: PRODUTO,
      assinatura: true,
      estado: 'concedida',
    });
  }

  const instantes = [...relogio];
  const agora = () => (instantes.length > 1 ? instantes.shift() : instantes[0]);

  const chamadasPlay = [];
  const consultarAssinatura = async (token) => {
    chamadasPlay.push(token);
    const r = respostas ? respostas(token) : ativa();
    if (r instanceof Error) throw r;
    return r;
  };

  const registros = [];
  const log = {
    info: (...a) => registros.push({ nivel: 'info', a }),
    warn: (...a) => registros.push({ nivel: 'warn', a }),
    error: (...a) => registros.push({ nivel: 'error', a }),
  };

  const store = criarStore({ db, carimbo: () => CARIMBO });
  const reconciliador = criarReconciliador({
    consultarAssinatura,
    aplicarProposta: store.aplicarProposta,
    agora,
  });
  const rtdn = criarProcessadorRtdn({ pacote: PACOTE, store, reconciliador, log, agora });

  return { db, store, reconciliador, rtdn, chamadasPlay, registros, agora };
}

/** Semeia um entitlement ja consolidado, como se um evento anterior o tivesse escrito. */
function semearEntitlement(db, { estado, vipAtivo, expiraEm, hash = HASH, verificadoEm = T1 }) {
  db.semear(DOC_PUBLICO, {
    uid: UID,
    vipAtivo,
    estado,
    produtoId: PRODUTO,
    origem: 'play',
    inicioEm: PASSADO,
    expiraEm,
    renovacaoAutomatica: true,
    atualizadoEm: verificadoEm,
    esquema: 1,
  });
  db.semear(DOC_INTERNO, {
    uid: UID,
    purchaseTokenHash: hash,
    purchaseToken: hash === HASH ? TOKEN : TOKEN_VELHO,
    produtoId: PRODUTO,
    assinatura: true,
    fonte: 'rtdn',
    ultimaVerificacaoEm: verificadoEm,
    ultimoEventoEm: null,
    ultimoEventoTipo: null,
    esquema: 1,
  });
}

// ==================================================== RTDN-01 a RTDN-06 ESTADO

test('RTDN-01 assinatura ativa: o evento manda perguntar, e a resposta vira direito', async () => {
  const { db, rtdn, chamadasPlay } = montar({ respostas: () => ativa() });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.PURCHASED))
  );

  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(r.estado, ESTADO.ATIVO);
  assert.strictEqual(r.vipAtivo, true);
  // A consulta autoritativa ACONTECEU: o payload sozinho nao decidiu nada.
  assert.deepStrictEqual(chamadasPlay, [TOKEN]);

  const pub = db.ver(DOC_PUBLICO);
  assert.strictEqual(pub.vipAtivo, true);
  assert.strictEqual(pub.estado, ESTADO.ATIVO);
  assert.strictEqual(pub.expiraEm, FUTURO);
  assert.strictEqual(pub.uid, UID);
});

test('RTDN-02 renovacao ESTENDE o prazo (o defeito P0-3 era o prazo congelado)', async () => {
  const { db, rtdn } = montar({
    respostas: () => ativa(FUTURO_ESTENDIDO),
    relogio: [T2],
  });
  semearEntitlement(db, {
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: FUTURO,
    verificadoEm: T1,
  });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED))
  );

  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(db.ver(DOC_PUBLICO).expiraEm, FUTURO_ESTENDIDO);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
});

test('RTDN-03 cancelada com periodo pago MANTEM o VIP ate o prazo', async () => {
  const { db, rtdn } = montar({
    respostas: () => respostaPlay('SUBSCRIPTION_STATE_CANCELED', FUTURO, { autoRenew: false }),
  });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.CANCELED))
  );

  assert.strictEqual(r.estado, ESTADO.CANCELADO_VIGENTE);
  assert.strictEqual(r.vipAtivo, true);
  const pub = db.ver(DOC_PUBLICO);
  assert.strictEqual(pub.vipAtivo, true);
  assert.strictEqual(pub.renovacaoAutomatica, false);
});

test('RTDN-04 expirada nao concede, e o documento passa a contar isso', async () => {
  const { db, rtdn } = montar({
    respostas: () => respostaPlay('SUBSCRIPTION_STATE_EXPIRED', PASSADO, { autoRenew: false }),
    relogio: [T2],
  });
  semearEntitlement(db, {
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: FUTURO,
    verificadoEm: T1,
  });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.EXPIRED)),
  );

  assert.strictEqual(r.estado, ESTADO.EXPIRADO);
  assert.strictEqual(r.vipAtivo, false);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, false);
});

test('RTDN-05 revogada e terminal TIRADA DO EVENTO — sem consultar a Play', async () => {
  const { db, rtdn, chamadasPlay } = montar({ respostas: () => ativa() });
  semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.REVOKED))
  );

  assert.strictEqual(r.estado, ESTADO.REVOGADO);
  assert.strictEqual(r.vipAtivo, false);
  // A consulta NAO expressa "revogado": esperar por ela deixaria uma janela em
  // que o revogado continua VIP.
  assert.deepStrictEqual(chamadasPlay, []);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, false);
  // O direito acaba AGORA, e nao no fim do periodo pago.
  assert.strictEqual(db.ver(DOC_PUBLICO).expiraEm, T1);
});

test('RTDN-06 reembolso (voidedPurchase) e terminal, mesmo com prazo futuro gravado', async () => {
  const { db, rtdn, chamadasPlay } = montar({ respostas: () => ativa() });
  semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });

  const r = await rtdn.processarNotificacao(mensagem(notificacaoAnulacao()));

  assert.strictEqual(r.estado, ESTADO.REEMBOLSADO);
  assert.strictEqual(r.vipAtivo, false);
  assert.deepStrictEqual(chamadasPlay, []);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, false);
  assert.strictEqual(db.ver(DOC_INTERNO).terminalEm, T1);
});

// ============================================ RTDN-07 a RTDN-10 ENTREGA E ORDEM

test('RTDN-07 evento duplicado nao produz efeito novo nem gasta consulta', async () => {
  const { db, rtdn, chamadasPlay } = montar({
    respostas: () => ativa(),
    relogio: [T1, T2],
  });
  const msg = mensagem(notificacaoAssinatura(NOTIFICACAO.PURCHASED), 'msg-repetida');

  const primeira = await rtdn.processarNotificacao(msg);
  const antes = db.ver(DOC_PUBLICO);
  const segunda = await rtdn.processarNotificacao(msg);

  assert.strictEqual(primeira.aplicado, true);
  assert.strictEqual(segunda.decisao, 'evento_repetido');
  assert.strictEqual(segunda.aplicado, false);
  // O atalho barato poupou a chamada de rede.
  assert.deepStrictEqual(chamadasPlay, [TOKEN]);
  // E o documento nao se mexeu.
  assert.deepStrictEqual(db.ver(DOC_PUBLICO), antes);
  assert.strictEqual(db.ver('billingEvents/msg-repetida').estado, 'concluido');
});

test('RTDN-07b a barreira real e a transacao: reentrega sem o atalho ainda nao duplica', async () => {
  // Mesmo messageId, mas o atalho e neutralizado — e o caso em que duas copias
  // da mensagem correm juntas e as duas passam pela checagem barata.
  const { db, store, rtdn } = montar({ respostas: () => ativa(), relogio: [T1, T2] });
  const original = store.eventoConcluido;
  store.eventoConcluido = async () => false;

  const msg = mensagem(notificacaoAssinatura(NOTIFICACAO.PURCHASED), 'msg-corrida');
  await rtdn.processarNotificacao(msg);
  const segunda = await rtdn.processarNotificacao(msg);
  store.eventoConcluido = original;

  // A transacao releu `billingEvents/{id}` e viu que ja estava concluido.
  assert.strictEqual(segunda.decisao, 'evento_repetido');
  assert.strictEqual(segunda.aplicado, false);
});

test('RTDN-08 evento antigo que chega depois NAO regride o estado', async () => {
  // O evento antigo produz uma consulta NOVA, e e o carimbo da consulta que
  // decide. Aqui a consulta antiga (T1) chega ao banco depois da nova (T2).
  const { db, rtdn } = montar({ respostas: () => ativa(FUTURO_ESTENDIDO), relogio: [T2] });
  semearEntitlement(db, {
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: FUTURO_ESTENDIDO,
    verificadoEm: T3, // ja houve verificacao mais nova
  });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED, { eventTimeMillis: 1 }), 'msg-atrasada')
  );

  assert.strictEqual(r.aplicado, false);
  assert.strictEqual(r.decisao, 'verificacao_antiga');
  assert.strictEqual(db.ver(DOC_INTERNO).ultimaVerificacaoEm, T3);
});

test('RTDN-09 dois eventos concorrentes: quem consultou depois vence, sem regressao', async () => {
  const { db, rtdn } = montar({
    // A consulta de A devolve o prazo curto; a de B, o estendido.
    respostas: () => (db.__b ? ativa(FUTURO_ESTENDIDO) : ativa(FUTURO)),
    relogio: [T1, T2],
  });

  const chegou = porta();
  const liberado = porta();
  let primeira = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeira) return;
    primeira = false;
    chegou.abrir();
    await liberado.aberta;
  };

  // A entra primeiro, consulta em T1 e para na porta do commit.
  const pA = rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-A')
  );
  await chegou.aberta;

  // B corre inteiro por dentro, consultando em T2.
  db.__b = true;
  const rB = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-B')
  );

  liberado.abrir();
  const rA = await pA;

  assert.strictEqual(rB.aplicado, true);
  // A perdeu a corrida, releu o documento e reconheceu que sua leitura envelheceu.
  assert.strictEqual(rA.aplicado, false);
  assert.strictEqual(rA.decisao, 'verificacao_antiga');
  assert.ok(db.conflitos >= 1, 'a contencao precisa ter acontecido de verdade');

  // Estado final: o de B. Nada regrediu.
  assert.strictEqual(db.ver(DOC_PUBLICO).expiraEm, FUTURO_ESTENDIDO);
  assert.strictEqual(db.ver(DOC_INTERNO).ultimaVerificacaoEm, T2);
});

test('RTDN-10 RTDN concorrendo com a validacao normal converge, sem perder o mais novo', async () => {
  const { db, store, rtdn } = montar({ respostas: () => ativa(FUTURO), relogio: [T1] });

  const chegou = porta();
  const liberado = porta();
  let primeira = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeira) return;
    primeira = false;
    chegou.abrir();
    await liberado.aberta;
  };

  // RTDN entra primeiro, com consulta de T1.
  const pRtdn = rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-rtdn')
  );
  await chegou.aberta;

  // `validarCompraPlay` chega no meio, com consulta mais NOVA (T2) — o jogador
  // abriu o app e o proprio aparelho trouxe o retorno de compra.
  const rValidacao = await store.aplicarProposta({
    uid: UID,
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    produtoId: PRODUTO,
    inicioEm: PASSADO,
    expiraEm: FUTURO_ESTENDIDO,
    renovacaoAutomatica: true,
    origem: 'play',
    purchaseTokenHash: HASH,
    purchaseToken: TOKEN,
    verificadoEm: T2,
    fonte: 'validacao',
  });

  liberado.abrir();
  const rRtdn = await pRtdn;

  assert.strictEqual(rValidacao.aplicado, true);
  assert.strictEqual(rRtdn.aplicado, false);
  assert.strictEqual(rRtdn.decisao, 'verificacao_antiga');
  // Convergente: um unico estado, o mais recentemente verificado.
  assert.strictEqual(db.ver(DOC_PUBLICO).expiraEm, FUTURO_ESTENDIDO);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
});

// ================================================= RTDN-11 a RTDN-13 DEFEITOS

test('RTDN-11 falha transitoria da Play API SOBE, para o Pub/Sub reentregar', async () => {
  let falhar = true;
  const { db, rtdn } = montar({
    respostas: () => (falhar ? new Error('backendError: 503') : ativa()),
    relogio: [T1, T2],
  });
  semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });
  const msg = mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-instavel');

  await assert.rejects(() => rtdn.processarNotificacao(msg), /503/);

  // NADA foi decidido por ausencia de resposta: o direito continua o que era...
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
  assert.strictEqual(db.ver(DOC_PUBLICO).estado, ESTADO.ATIVO);
  // ...e o evento NAO foi marcado como concluido, senao a reentrega seria
  // descartada pelo atalho e o estado nunca mais seria conferido.
  assert.strictEqual(db.ver('billingEvents/msg-instavel'), null);

  // A reentrega encontra trabalho a fazer.
  falhar = false;
  const r = await rtdn.processarNotificacao(msg);
  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(db.ver('billingEvents/msg-instavel').estado, 'concluido');
});

test('RTDN-12 payload invalido nao altera entitlement e nao vaza conteudo', async () => {
  const { db, rtdn, chamadasPlay, registros } = montar({ respostas: () => ativa() });
  semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });
  const antes = db.ver(DOC_PUBLICO);

  const r = await rtdn.processarNotificacao({
    messageId: 'msg-lixo',
    data: Buffer.from('isto nao e json', 'utf8').toString('base64'),
  });

  assert.strictEqual(r.decisao, 'corpo_ilegivel');
  assert.strictEqual(r.aplicado, false);
  assert.deepStrictEqual(db.ver(DOC_PUBLICO), antes);
  assert.deepStrictEqual(chamadasPlay, []);
  // A trilha registra que a mensagem passou, sem carregar o corpo.
  const trilha = db.ver('billingEvents/msg-lixo');
  assert.strictEqual(trilha.decisao, 'corpo_ilegivel');
  assert.strictEqual(trilha.aplicado, false);
  const dump = JSON.stringify(registros);
  assert.ok(!dump.includes('isto nao e json'), 'o corpo cru nao pode ir para o log');
});

test('RTDN-12b payload truncado no meio do token nao imprime o token no log', async () => {
  // O caso que da nome ao risco: JSON cortado pela metade, com o token dentro do
  // trecho que o `SyntaxError` do V8 cita. Logar `e.message` aqui vazaria a
  // credencial de consulta inteira.
  const truncado = `{"packageName":"${PACOTE}","subscriptionNotification":{"purchaseToken":"${TOKEN}"`;
  const { db, rtdn, registros } = montar({ respostas: () => ativa() });

  const r = await rtdn.processarNotificacao({
    messageId: 'msg-truncada',
    data: Buffer.from(truncado, 'utf8').toString('base64'),
  });

  assert.strictEqual(r.decisao, 'corpo_ilegivel');
  const dump = JSON.stringify(registros);
  assert.ok(!dump.includes(TOKEN), 'o token vazou pelo texto da excecao de parsing');
  assert.ok(!dump.includes(TOKEN.slice(0, 24)), 'ate um prefixo do token e demais');
  // O diagnostico continua possivel: da para saber que chegou e que era ilegivel.
  assert.ok(dump.includes('msg-truncada'));
  const trilha = JSON.stringify(db.ver('billingEvents/msg-truncada'));
  assert.ok(!trilha.includes(TOKEN));
});

test('RTDN-13 evento desconhecido, de teste ou de outro pacote nao altera entitlement', async () => {
  const casos = [
    ['secao_desconhecida', { packageName: PACOTE, eventTimeMillis: '1', novidadeDaPlay: {} }, 'sem_secao_reconhecida'],
    ['notificacao_de_teste', { packageName: PACOTE, eventTimeMillis: '1', testNotification: { version: '1.0' } }, 'notificacao_de_teste'],
    ['produto_avulso', { packageName: PACOTE, eventTimeMillis: '1', oneTimeProductNotification: { purchaseToken: TOKEN } }, 'produto_avulso'],
    ['pacote_alheio', { ...notificacaoAssinatura(NOTIFICACAO.RENEWED), packageName: 'com.outro.app' }, 'pacote_alheio'],
  ];

  for (const [nome, corpo, esperado] of casos) {
    const { db, rtdn, chamadasPlay } = montar({ respostas: () => ativa() });
    semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });
    const antes = db.ver(DOC_PUBLICO);

    const r = await rtdn.processarNotificacao(mensagem(corpo, `msg-${nome}`));

    assert.strictEqual(r.decisao, esperado, nome);
    assert.strictEqual(r.aplicado, false, nome);
    assert.deepStrictEqual(db.ver(DOC_PUBLICO), antes, nome);
    assert.deepStrictEqual(chamadasPlay, [], nome);
  }
});

// ================================================== RTDN-14 a RTDN-16 SEGREDO

test('RTDN-14 o purchaseToken NUNCA aparece nos logs, em nenhum caminho', async () => {
  // Percorre os caminhos que logam: sucesso, terminal, sem titular, ilegivel.
  const caminhos = [
    ['sucesso', () => mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'm1'), true],
    ['terminal', () => mensagem(notificacaoAssinatura(NOTIFICACAO.REVOKED), 'm2'), true],
    ['anulacao', () => mensagem(notificacaoAnulacao(), 'm3'), true],
    ['sem_titular', () => mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'm4'), false],
  ];

  for (const [nome, construir, temTitular] of caminhos) {
    const { rtdn, registros } = montar({ respostas: () => ativa(), titular: temTitular });
    await rtdn.processarNotificacao(construir());

    const dump = JSON.stringify(registros);
    assert.ok(dump.length > 0, `${nome}: o caminho precisa ter logado algo`);
    assert.ok(!dump.includes(TOKEN), `${nome}: token cru vazou para o log`);
    assert.ok(!dump.includes(HASH), `${nome}: hash inteiro vazou para o log`);
    // O rotulo curto ESTA la — sem ele nao da para correlacionar duas linhas.
    assert.ok(dump.includes(HASH.slice(0, 8)), `${nome}: falta o rotulo de correlacao`);
  }
});

test('RTDN-15 o purchaseToken nao alcanca o documento que o cliente le', async () => {
  const { db, rtdn } = montar({ respostas: () => ativa() });

  await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.PURCHASED), 'msg-segredo')
  );

  const publico = JSON.stringify(db.ver(DOC_PUBLICO));
  assert.ok(!publico.includes(TOKEN), 'token cru no documento do jogador');
  assert.ok(!publico.includes(HASH), 'hash do token no documento do jogador');
  assert.strictEqual(db.ver(DOC_PUBLICO).purchaseToken, undefined);
  assert.strictEqual(db.ver(DOC_PUBLICO).purchaseTokenHash, undefined);

  // O token existe — no documento interno, que `firestore.rules` fecha para
  // cliente E para admin (`allow read, write: if false`).
  assert.strictEqual(db.ver(DOC_INTERNO).purchaseToken, TOKEN);

  // A trilha de eventos e legivel por operacao: so o rotulo curto vai para la.
  const trilha = JSON.stringify(db.ver('billingEvents/msg-segredo'));
  assert.ok(!trilha.includes(TOKEN));
  assert.ok(!trilha.includes(HASH));
  assert.strictEqual(db.ver('billingEvents/msg-segredo').token, HASH.slice(0, 8));
});

test('RTDN-16 RTDN nao contorna moderacao: nao escreve fora do seu dominio', async () => {
  const { db, rtdn } = montar({ respostas: () => ativa() });
  // O jogador esta suspenso — estado que pertence a moderacao, nao ao billing.
  db.semear(`playerModeration/${UID}`, {
    userId: UID,
    suspensaoPermanente: true,
    suspensoAte: null,
  });
  const moderacaoAntes = db.ver(`playerModeration/${UID}`);

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.PURCHASED), 'msg-suspenso')
  );

  // O direito ECONOMICO e reconhecido — a assinatura foi paga, e fingir que nao
  // foi seria mentir sobre o dinheiro...
  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);

  // ...mas o RTDN nao tocou, e nao tem como tocar, no estado de moderacao. Quem
  // decide ACESSO e `comporPerfil` (app/lib/elegibilidade/composicao.dart), que
  // compoe os dois documentos e faz a suspensao vencer. A prova dessa composicao
  // e do lado Dart, em `app/test/elegibilidade/costura_p0_test.dart`; a prova
  // daqui e que o billing nao escreve no dominio alheio.
  assert.deepStrictEqual(db.ver(`playerModeration/${UID}`), moderacaoAntes);

  const escritos = db.caminhos().filter((c) => !c.startsWith('compras/'));
  for (const caminho of escritos) {
    assert.ok(
      caminho.startsWith('playerEntitlements/') ||
        caminho.startsWith('billingEvents/') ||
        caminho.startsWith('playerModeration/'),
      `o RTDN escreveu fora do seu dominio: ${caminho}`
    );
  }
});

// ============================================= RTDN-17 e RTDN-18 AUTORIDADE

test('RTDN-17 estado terminal nao e revertido por evento economico antigo', async () => {
  // A Play ainda responde ACTIVE — leitura atrasada, comum depois de um estorno.
  const { db, rtdn } = montar({ respostas: () => ativa(FUTURO_ESTENDIDO), relogio: [T3] });
  semearEntitlement(db, {
    estado: ESTADO.REEMBOLSADO,
    vipAtivo: false,
    expiraEm: T1,
    verificadoEm: T1,
  });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-tardia')
  );

  assert.strictEqual(r.aplicado, false);
  assert.strictEqual(r.decisao, 'terminal_preservado');
  assert.strictEqual(db.ver(DOC_PUBLICO).estado, ESTADO.REEMBOLSADO);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, false);
});

test('RTDN-17b evento sobre token superado nao derruba a assinatura vigente', async () => {
  const { db, rtdn } = montar({
    respostas: () => respostaPlay('SUBSCRIPTION_STATE_EXPIRED', PASSADO, { autoRenew: false }),
    relogio: [T2],
  });
  // O direito vigente e do token NOVO.
  semearEntitlement(db, {
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: FUTURO,
    hash: HASH,
  });

  // Chega a expiracao da assinatura ANTERIOR.
  const r = await rtdn.processarNotificacao(
    mensagem(
      notificacaoAssinatura(NOTIFICACAO.EXPIRED, { token: TOKEN_VELHO }),
      'msg-token-velho'
    )
  );

  assert.strictEqual(r.aplicado, false);
  assert.strictEqual(r.decisao, 'token_superado');
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
});

test('RTDN-18 a Play e a autoridade: o estado consultado vence o que o evento sugere', async () => {
  // O evento diz CANCELED (tipo 3). A consulta, feita depois, mostra que o
  // jogador ja reativou: ACTIVE com prazo estendido. Quem vale e a consulta.
  const { db, rtdn, chamadasPlay } = montar({
    respostas: () => ativa(FUTURO_ESTENDIDO),
    relogio: [T2],
  });
  semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.CANCELED), 'msg-desatualizada')
  );

  assert.deepStrictEqual(chamadasPlay, [TOKEN]);
  assert.strictEqual(r.aplicado, true);
  // NAO virou `cancelado_vigente`, que e o que o payload sugeria.
  assert.strictEqual(r.estado, ESTADO.ATIVO);
  assert.strictEqual(db.ver(DOC_PUBLICO).expiraEm, FUTURO_ESTENDIDO);
  assert.strictEqual(db.ver(DOC_PUBLICO).renovacaoAutomatica, true);
  // E o tipo do evento fica registrado, para a trilha nao perder o que chegou.
  assert.strictEqual(db.ver(DOC_INTERNO).ultimoEventoTipo, NOTIFICACAO.CANCELED);
});

// ================================================== TITULARIDADE E FRONTEIRAS

test('RTDN-19 notificacao sobre token sem titular comprovavel e descartada', async () => {
  const { db, rtdn, chamadasPlay } = montar({ respostas: () => ativa(), titular: false });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-orfa')
  );

  assert.strictEqual(r.decisao, 'compra_desconhecida');
  assert.strictEqual(r.aplicado, false);
  // Nao se atribui direito por palpite, e nao se gasta consulta por um token
  // que este sistema nunca viu.
  assert.deepStrictEqual(chamadasPlay, []);
  assert.strictEqual(db.ver(DOC_PUBLICO), null);
  assert.strictEqual(db.ver('billingEvents/msg-orfa').decisao, 'compra_desconhecida');
});

test('RTDN-20 mensagem sem messageId ainda produz efeito, sem trilha de deduplicacao', async () => {
  const { db, rtdn } = montar({ respostas: () => ativa() });

  const r = await rtdn.processarNotificacao({
    messageId: null,
    data: mensagem(notificacaoAssinatura(NOTIFICACAO.PURCHASED)).data,
  });

  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
  // Sem id nao ha o que deduplicar: nenhum documento de trilha foi criado.
  assert.deepStrictEqual(db.caminhos().filter((c) => c.startsWith('billingEvents/')), []);
});

test('RTDN-21 o carimbo da consulta e capturado ANTES da chamada de rede', async () => {
  // Se `consultadoEm` fosse capturado na VOLTA, uma resposta lenta ganharia de
  // uma consulta mais nova que respondeu rapido — o defeito de ordem que
  // `decidirAtualizacao` nao tem como perceber, porque recebe o carimbo pronto.
  const instantes = [T1, T2];
  let durante = null;
  const db = new FirestoreFalso();
  db.semear(`compras/${HASH}`, { uid: UID, produtoId: PRODUTO, assinatura: true });

  const agora = () => (instantes.length > 1 ? instantes.shift() : instantes[0]);
  const store = criarStore({ db, carimbo: () => CARIMBO });
  const reconciliador = criarReconciliador({
    consultarAssinatura: async () => {
      // O relogio avanca DURANTE a chamada de rede.
      durante = agora();
      return ativa();
    },
    aplicarProposta: store.aplicarProposta,
    agora,
  });
  const rtdn = criarProcessadorRtdn({ pacote: PACOTE, store, reconciliador, agora });

  await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RENEWED), 'msg-relogio')
  );

  assert.strictEqual(durante, T2, 'o relogio precisa ter avancado durante a rede');
  // O gravado e o instante da PERGUNTA, nao o da resposta.
  assert.strictEqual(db.ver(DOC_INTERNO).ultimaVerificacaoEm, T1);
});

// ============================================ RTDN-22 a RTDN-26 CICLO DE VIDA
//
// O QUE ESTE BLOCO ACRESCENTA
//
// Os casos acima provam cada desfecho isolado. Faltavam quatro estados que a OS
// de prontidao nomeia e que so aparecem no MEIO de uma assinatura real —
// carencia, espera, pausa e recuperacao —, e faltava a propriedade que nenhum
// caso isolado alcanca: que a SEQUENCIA inteira converge, com o mesmo token,
// sem que um estado deixe residuo no seguinte.
//
// Carencia e espera sao o par que costuma ser confundido, e a diferenca vale
// dinheiro: em CARENCIA a Google ainda esta tentando cobrar e o jogador CONTINUA
// com acesso; em ESPERA a cobranca ja falhou de vez e o acesso ACABA. Trocar os
// dois entrega VIP de graca ou tira VIP de quem pagou.

/**
 * Instantes estritamente crescentes, comecando DEPOIS de `T1`.
 *
 * O `depois de T1` nao e detalhe de arrumacao: `semearEntitlement` grava
 * `ultimaVerificacaoEm: T1`, e `decidirAtualizacao` recusa proposta cuja
 * verificacao nao seja ESTRITAMENTE mais nova (`verificacao_antiga`). Um relogio
 * comecando no proprio T1 faria o primeiro evento de cada cenario ser descartado
 * — e o teste acusaria o codigo de producao por um empate que so o teste criou.
 */
function relogioCrescente(quantidade) {
  const base = Date.parse(T1) + 3600_000;
  return Array.from({ length: quantidade }, (_, i) =>
    new Date(base + i * 3600_000).toISOString()
  );
}

test('RTDN-22 carencia: a cobranca falhou e a Google ainda tenta — o VIP CONTINUA', async () => {
  const { db, rtdn } = montar({
    respostas: () => respostaPlay('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', FUTURO),
  });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.IN_GRACE_PERIOD))
  );

  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(r.estado, ESTADO.EM_CARENCIA);
  // O ponto do caso: carencia NAO corta acesso.
  assert.strictEqual(r.vipAtivo, true);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
});

test('RTDN-23 espera: a carencia acabou sem pagamento — o acesso ACABA, com prazo futuro', async () => {
  const { db, rtdn } = montar({
    respostas: () => respostaPlay('SUBSCRIPTION_STATE_ON_HOLD', FUTURO),
    relogio: relogioCrescente(2),
  });
  semearEntitlement(db, { estado: ESTADO.EM_CARENCIA, vipAtivo: true, expiraEm: FUTURO });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.ON_HOLD), 'msg-hold')
  );

  assert.strictEqual(r.estado, ESTADO.EM_ESPERA);
  // O prazo AINDA E FUTURO e mesmo assim nao ha acesso: quem decide aqui e o
  // estado economico, nao o relogio. Confundir com carencia daria VIP de graca.
  assert.strictEqual(r.vipAtivo, false);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, false);
});

test('RTDN-24 recuperacao: o pagamento entrou depois da espera e o direito VOLTA', async () => {
  const { db, rtdn, chamadasPlay } = montar({
    respostas: () => ativa(FUTURO_ESTENDIDO),
    relogio: relogioCrescente(2),
  });
  semearEntitlement(db, { estado: ESTADO.EM_ESPERA, vipAtivo: false, expiraEm: FUTURO });

  const r = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RECOVERED), 'msg-recovered')
  );

  assert.strictEqual(r.aplicado, true);
  assert.strictEqual(r.estado, ESTADO.ATIVO);
  assert.strictEqual(r.vipAtivo, true);
  // Recuperacao nao e excecao de desenho: ela passa pela MESMA reconsulta.
  assert.deepStrictEqual(chamadasPlay, [TOKEN]);
  // E traz prazo novo — recuperar sem estender deixaria o jogador pagando por um
  // periodo ja vencido.
  assert.strictEqual(db.ver(DOC_PUBLICO).expiraEm, FUTURO_ESTENDIDO);
});

test('RTDN-25 pausa e retomada: pausado nao tem acesso, retomado volta a ter', async () => {
  const respostasPorVez = ['SUBSCRIPTION_STATE_PAUSED', 'SUBSCRIPTION_STATE_ACTIVE'];
  let vez = 0;
  const { db, rtdn } = montar({
    respostas: () => respostaPlay(respostasPorVez[vez++], FUTURO_ESTENDIDO),
    relogio: relogioCrescente(3),
  });
  semearEntitlement(db, { estado: ESTADO.ATIVO, vipAtivo: true, expiraEm: FUTURO });

  const pausado = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.PAUSED), 'msg-paused')
  );
  assert.strictEqual(pausado.estado, ESTADO.PAUSADO);
  assert.strictEqual(pausado.vipAtivo, false);

  const retomado = await rtdn.processarNotificacao(
    mensagem(notificacaoAssinatura(NOTIFICACAO.RESTARTED), 'msg-restarted')
  );
  assert.strictEqual(retomado.estado, ESTADO.ATIVO);
  assert.strictEqual(retomado.vipAtivo, true);
  assert.strictEqual(db.ver(DOC_PUBLICO).vipAtivo, true);
});

test('RTDN-26 a assinatura inteira, na ordem, com um token so: cada passo conclui o seguinte', async () => {
  // Compra -> renovacao -> carencia -> espera -> recuperacao -> cancelamento ->
  // expiracao. E a unica prova de que os estados COMPOEM: nenhum caso isolado
  // mostra que a espera nao deixa residuo que impeca a recuperacao, nem que o
  // cancelamento preserva o prazo que a expiracao depois consome.
  const roteiro = [
    [NOTIFICACAO.PURCHASED, 'SUBSCRIPTION_STATE_ACTIVE', FUTURO, ESTADO.ATIVO, true],
    [NOTIFICACAO.RENEWED, 'SUBSCRIPTION_STATE_ACTIVE', FUTURO_ESTENDIDO, ESTADO.ATIVO, true],
    [NOTIFICACAO.IN_GRACE_PERIOD, 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', FUTURO_ESTENDIDO, ESTADO.EM_CARENCIA, true],
    [NOTIFICACAO.ON_HOLD, 'SUBSCRIPTION_STATE_ON_HOLD', FUTURO_ESTENDIDO, ESTADO.EM_ESPERA, false],
    [NOTIFICACAO.RECOVERED, 'SUBSCRIPTION_STATE_ACTIVE', FUTURO_ESTENDIDO, ESTADO.ATIVO, true],
    [NOTIFICACAO.CANCELED, 'SUBSCRIPTION_STATE_CANCELED', FUTURO_ESTENDIDO, ESTADO.CANCELADO_VIGENTE, true],
    [NOTIFICACAO.EXPIRED, 'SUBSCRIPTION_STATE_EXPIRED', PASSADO, ESTADO.EXPIRADO, false],
  ];

  let passo = 0;
  const { db, rtdn } = montar({
    respostas: () => respostaPlay(roteiro[passo][1], roteiro[passo][2]),
    relogio: relogioCrescente(roteiro.length + 1),
  });

  for (; passo < roteiro.length; passo += 1) {
    const [tipo, , , estadoEsperado, vipEsperado] = roteiro[passo];
    const r = await rtdn.processarNotificacao(
      mensagem(notificacaoAssinatura(tipo), `msg-ciclo-${passo}`)
    );
    assert.strictEqual(r.estado, estadoEsperado, `passo ${passo}: estado`);
    assert.strictEqual(r.vipAtivo, vipEsperado, `passo ${passo}: acesso`);
  }

  // No fim, o documento conta a historia inteira e nao guarda residuo de estado
  // intermediario: um `set` sem merge por passo e o que garante isso.
  const pub = db.ver(DOC_PUBLICO);
  assert.strictEqual(pub.estado, ESTADO.EXPIRADO);
  assert.strictEqual(pub.vipAtivo, false);
  // O token nunca mudou, entao o direito e o MESMO o tempo todo — e por isso
  // nenhum passo caiu em `token_superado`.
  assert.strictEqual(db.ver(DOC_INTERNO).purchaseTokenHash, HASH);
});
