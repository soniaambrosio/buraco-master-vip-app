/**
 * Testes do CICLO DE VIDA do entitlement VIP.
 *
 * `node --test`, sem emulador, sem rede e sem relogio real — a decisao inteira e
 * pura de proposito, pela mesma razao que `idempotencia.test.js`: o que se prova
 * aqui (reembolso, revogacao, evento fora de ordem, corrida entre duas
 * verificacoes) e caro demais para so aparecer em producao.
 *
 * FRONTEIRA DECLARADA, para nao chamar de integracao o que nao e:
 *
 *   TESTE UNITARIO (este arquivo)
 *     A logica de decisao. As respostas da Play Developer API entram como
 *     LITERAIS — copiadas do formato documentado de `purchases.subscriptionsv2`.
 *     Nao ha chamada de rede, nao ha mock de cliente HTTP, e nao se afirma nada
 *     sobre a API real responder assim hoje.
 *
 *   TESTE DE CONTRATO (nao existe neste repositorio)
 *     Provaria que a resposta real da Google tem os campos que este codigo le.
 *     Exigiria credencial de conta de servico e uma compra de teste na Play
 *     Console.
 *
 *   TESTE DE AMBIENTE EXTERNO (fora de alcance)
 *     RTDN de verdade chegando por Pub/Sub, com topico configurado na Play
 *     Console. Exige projeto Firebase implantado.
 *
 * O que este arquivo NAO cobre, e nao finge cobrir: a gravacao no Firestore. Ela
 * mora em `aplicarProposta` (index.js), que e transacao de infraestrutura.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  ESTADO,
  NOTIFICACAO,
  consolidarAssinatura,
  consolidarTerminal,
  interpretarNotificacao,
  decidirAtualizacao,
  documentosDeEntitlement,
  rotuloToken,
} = require('../entitlement');

const PACOTE = 'io.github.soniaambrosio.buracomastervip';
const UID = 'jogador-1';
const HASH = 'a'.repeat(64);
const HASH_OUTRO = 'b'.repeat(64);
const PRODUTO = 'master_vip_mensal';

const T0 = '2026-08-01T12:00:00.000Z';
const T1 = '2026-08-01T13:00:00.000Z';
const T2 = '2026-08-01T14:00:00.000Z';
const FUTURO = '2026-09-01T12:00:00.000Z';
const PASSADO = '2026-07-01T12:00:00.000Z';

/** Resposta de `purchases.subscriptionsv2.get`, no formato documentado. */
function respostaPlay(estado, expiryTime, { autoRenew = true } = {}) {
  return {
    subscriptionState: estado,
    startTime: '2026-07-01T12:00:00.000Z',
    lineItems: [
      {
        productId: PRODUTO,
        expiryTime,
        autoRenewingPlan: { autoRenewEnabled: autoRenew },
      },
    ],
  };
}

function proposta(extra = {}) {
  return {
    uid: UID,
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    produtoId: PRODUTO,
    inicioEm: PASSADO,
    expiraEm: FUTURO,
    renovacaoAutomatica: true,
    origem: 'play',
    purchaseTokenHash: HASH,
    purchaseToken: 'token-cru',
    verificadoEm: T1,
    eventoEm: null,
    fonte: 'rtdn',
    ...extra,
  };
}

function gravado(extra = {}) {
  return {
    uid: UID,
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: PRODUTO,
    expiraEm: FUTURO,
    purchaseTokenHash: HASH,
    purchaseToken: 'token-cru',
    ultimaVerificacaoEm: T1,
    ...extra,
  };
}

// ===================================================== CONSOLIDACAO DA PLAY

test('CV-01 assinatura ACTIVE dentro do prazo concede VIP', () => {
  const c = consolidarAssinatura(respostaPlay('SUBSCRIPTION_STATE_ACTIVE', FUTURO), T0);
  assert.strictEqual(c.estado, ESTADO.ATIVO);
  assert.strictEqual(c.vipAtivo, true);
  assert.strictEqual(c.expiraEm, FUTURO);
  assert.strictEqual(c.produtoId, PRODUTO);
  assert.strictEqual(c.renovacaoAutomatica, true);
});

test('CV-02 carencia (pagamento falhou, Google ainda tenta) mantem o VIP', () => {
  const c = consolidarAssinatura(
    respostaPlay('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', FUTURO),
    T0
  );
  assert.strictEqual(c.estado, ESTADO.EM_CARENCIA);
  assert.strictEqual(c.vipAtivo, true);
});

test('CV-03 CANCELADO com periodo ainda pago MANTEM o VIP ate expirar', () => {
  // Caso G da OS. Desligar a renovacao nao e perder o que ja foi pago.
  const c = consolidarAssinatura(
    respostaPlay('SUBSCRIPTION_STATE_CANCELED', FUTURO, { autoRenew: false }),
    T0
  );
  assert.strictEqual(c.estado, ESTADO.CANCELADO_VIGENTE);
  assert.strictEqual(c.vipAtivo, true);
  assert.strictEqual(c.renovacaoAutomatica, false);
  assert.strictEqual(c.expiraEm, FUTURO);
});

test('CV-04 CANCELADO com periodo ja vencido vira expirado', () => {
  const c = consolidarAssinatura(
    respostaPlay('SUBSCRIPTION_STATE_CANCELED', PASSADO, { autoRenew: false }),
    T0
  );
  assert.strictEqual(c.estado, ESTADO.EXPIRADO);
  assert.strictEqual(c.vipAtivo, false);
});

test('CV-05 ACTIVE com prazo vencido nao concede: o relogio desmente o estado', () => {
  const c = consolidarAssinatura(respostaPlay('SUBSCRIPTION_STATE_ACTIVE', PASSADO), T0);
  assert.strictEqual(c.estado, ESTADO.EXPIRADO);
  assert.strictEqual(c.vipAtivo, false);
});

test('CV-06 EXPIRED, ON_HOLD, PAUSED e PENDING nao concedem', () => {
  const casos = [
    ['SUBSCRIPTION_STATE_EXPIRED', ESTADO.EXPIRADO],
    ['SUBSCRIPTION_STATE_ON_HOLD', ESTADO.EM_ESPERA],
    ['SUBSCRIPTION_STATE_PAUSED', ESTADO.PAUSADO],
    ['SUBSCRIPTION_STATE_PENDING', ESTADO.PENDENTE],
    ['SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED', ESTADO.EXPIRADO],
  ];
  for (const [bruto, esperado] of casos) {
    const c = consolidarAssinatura(respostaPlay(bruto, FUTURO), T0);
    assert.strictEqual(c.estado, esperado, bruto);
    assert.strictEqual(c.vipAtivo, false, bruto);
  }
});

test('CV-07 estado que a Google inventar amanha recusa, nao concede', () => {
  const c = consolidarAssinatura(respostaPlay('SUBSCRIPTION_STATE_QUALQUER', FUTURO), T0);
  assert.strictEqual(c.estado, ESTADO.DESCONHECIDO);
  assert.strictEqual(c.vipAtivo, false);
});

test('CV-08 resposta sem lineItems nao concede (sem prazo, sem direito)', () => {
  const c = consolidarAssinatura({ subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE' }, T0);
  assert.strictEqual(c.vipAtivo, false);
  assert.strictEqual(c.expiraEm, null);
});

test('CV-09 com dois itens vence o prazo mais distante', () => {
  const resposta = {
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [
      { productId: 'plano_antigo', expiryTime: '2026-08-15T12:00:00.000Z' },
      { productId: PRODUTO, expiryTime: FUTURO },
    ],
  };
  const c = consolidarAssinatura(resposta, T0);
  assert.strictEqual(c.expiraEm, FUTURO);
  assert.strictEqual(c.produtoId, PRODUTO);
});

test('CV-10 renovacao estende o prazo (era o defeito: prazo congelado)', () => {
  const antes = consolidarAssinatura(
    respostaPlay('SUBSCRIPTION_STATE_ACTIVE', '2026-08-15T12:00:00.000Z'),
    T0
  );
  const depois = consolidarAssinatura(
    respostaPlay('SUBSCRIPTION_STATE_ACTIVE', FUTURO),
    T1
  );
  assert.ok(new Date(depois.expiraEm) > new Date(antes.expiraEm));
  assert.strictEqual(depois.vipAtivo, true);
});

test('CV-11 terminal encerra o direito AGORA, e nao no fim do periodo', () => {
  for (const alvo of [ESTADO.REVOGADO, ESTADO.REEMBOLSADO]) {
    const c = consolidarTerminal(alvo, T1);
    assert.strictEqual(c.estado, alvo);
    assert.strictEqual(c.vipAtivo, false);
    assert.strictEqual(c.expiraEm, T1);
  }
});

// ===================================================== LEITURA DA NOTIFICACAO

test('RT-01 renovacao manda RECONSULTAR, nao confiar no payload', () => {
  const r = interpretarNotificacao(
    {
      packageName: PACOTE,
      eventTimeMillis: Date.parse(T1),
      subscriptionNotification: {
        notificationType: NOTIFICACAO.RENEWED,
        purchaseToken: 'token-cru',
        subscriptionId: PRODUTO,
      },
    },
    PACOTE
  );
  assert.strictEqual(r.acao, 'reconciliar');
  assert.strictEqual(r.purchaseToken, 'token-cru');
  assert.strictEqual(r.eventoEm, T1);
});

test('RT-02 revogacao e desfecho terminal tirado do proprio evento', () => {
  const r = interpretarNotificacao(
    {
      packageName: PACOTE,
      eventTimeMillis: Date.parse(T1),
      subscriptionNotification: {
        notificationType: NOTIFICACAO.REVOKED,
        purchaseToken: 'token-cru',
      },
    },
    PACOTE
  );
  assert.strictEqual(r.acao, 'aplicar_terminal');
  assert.strictEqual(r.terminal, ESTADO.REVOGADO);
});

test('RT-03 compra anulada (estorno) e terminal de reembolso', () => {
  const r = interpretarNotificacao(
    {
      packageName: PACOTE,
      eventTimeMillis: Date.parse(T1),
      voidedPurchaseNotification: { purchaseToken: 'token-cru', refundType: 1 },
    },
    PACOTE
  );
  assert.strictEqual(r.acao, 'aplicar_terminal');
  assert.strictEqual(r.terminal, ESTADO.REEMBOLSADO);
});

test('RT-04 notificacao de outro applicationId e ignorada', () => {
  const r = interpretarNotificacao(
    {
      packageName: 'com.outro.app',
      subscriptionNotification: { notificationType: 2, purchaseToken: 'x' },
    },
    PACOTE
  );
  assert.strictEqual(r.acao, 'ignorar');
  assert.strictEqual(r.motivo, 'pacote_alheio');
});

test('RT-05 notificacao de teste e produto avulso nao mexem em entitlement', () => {
  const teste = interpretarNotificacao(
    { packageName: PACOTE, testNotification: { version: '1.0' } },
    PACOTE
  );
  assert.strictEqual(teste.acao, 'ignorar');

  const avulso = interpretarNotificacao(
    {
      packageName: PACOTE,
      oneTimeProductNotification: { purchaseToken: 'x', notificationType: 1 },
    },
    PACOTE
  );
  assert.strictEqual(avulso.acao, 'ignorar');
  assert.strictEqual(avulso.motivo, 'produto_avulso');
});

test('RT-06 corpo irreconhecivel nao vira concessao', () => {
  assert.strictEqual(interpretarNotificacao(null, PACOTE).acao, 'ignorar');
  assert.strictEqual(interpretarNotificacao({}, PACOTE).acao, 'ignorar');
});

// ===================================================== DECISAO DE GRAVAR

test('DA-01 primeiro registro sempre entra', () => {
  const d = decidirAtualizacao(null, proposta());
  assert.strictEqual(d.aplicar, true);
  assert.strictEqual(d.motivo, 'primeiro_registro');
});

test('DA-02 verificacao mais nova substitui a anterior', () => {
  const d = decidirAtualizacao(gravado(), proposta({ verificadoEm: T2 }));
  assert.strictEqual(d.aplicar, true);
});

test('DA-03 EVENTO ANTIGO NAO REGRIDE O ESTADO', () => {
  // A consulta que produziu esta proposta e mais velha que a ja gravada: ela
  // descreve um mundo anterior.
  const d = decidirAtualizacao(
    gravado({ ultimaVerificacaoEm: T2 }),
    proposta({ estado: ESTADO.EXPIRADO, vipAtivo: false, verificadoEm: T0 })
  );
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'verificacao_antiga');
});

test('DA-04 reprocessar a mesma verificacao nao produz efeito novo', () => {
  const d = decidirAtualizacao(gravado({ ultimaVerificacaoEm: T1 }), proposta({ verificadoEm: T1 }));
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'verificacao_antiga');
});

test('DA-05 evento sobre token superado nao derruba a assinatura vigente', () => {
  // Assinou de novo (token novo); a expiracao da compra ANTERIOR chega depois.
  const d = decidirAtualizacao(
    gravado({ purchaseTokenHash: HASH_OUTRO }),
    proposta({ estado: ESTADO.EXPIRADO, vipAtivo: false, verificadoEm: T2 })
  );
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'token_superado');
});

test('DA-06 compra nova validada SUBSTITUI o direito anterior', () => {
  const d = decidirAtualizacao(
    gravado({ purchaseTokenHash: HASH_OUTRO, estado: ESTADO.EXPIRADO, vipAtivo: false }),
    proposta({ fonte: 'validacao', verificadoEm: T2 })
  );
  assert.strictEqual(d.aplicar, true);
});

test('DA-07 reembolso entra mesmo com verificacao mais antiga', () => {
  const d = decidirAtualizacao(
    gravado({ ultimaVerificacaoEm: T2 }),
    proposta({ estado: ESTADO.REEMBOLSADO, vipAtivo: false, verificadoEm: T0 })
  );
  assert.strictEqual(d.aplicar, true);
  assert.strictEqual(d.motivo, 'terminal');
});

test('DA-08 LEITURA ATRASADA NAO RESSUSCITA DIREITO ESTORNADO', () => {
  // O caso que separa "ciclo de vida" de "sequencia de escritas": uma consulta
  // em voo antes do estorno volta dizendo ACTIVE depois dele.
  const d = decidirAtualizacao(
    gravado({ estado: ESTADO.REEMBOLSADO, vipAtivo: false, ultimaVerificacaoEm: T1 }),
    proposta({ verificadoEm: T2 })
  );
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'terminal_preservado');
});

test('DA-09 revogacao repetida converge sem efeito novo', () => {
  const d = decidirAtualizacao(
    gravado({ estado: ESTADO.REVOGADO, vipAtivo: false }),
    proposta({ estado: ESTADO.REVOGADO, vipAtivo: false, verificadoEm: T2 })
  );
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'terminal_repetido');
});

test('DA-10 compra NOVA depois de um estorno volta a valer', () => {
  // O terminal prende o direito daquele token, nao o jogador.
  const d = decidirAtualizacao(
    gravado({ estado: ESTADO.REEMBOLSADO, vipAtivo: false, purchaseTokenHash: HASH_OUTRO }),
    proposta({ fonte: 'validacao', verificadoEm: T2 })
  );
  assert.strictEqual(d.aplicar, true);
});

test('DA-11 legado nunca sobrescreve entitlement ja verificado', () => {
  const d = decidirAtualizacao(gravado(), proposta({ fonte: 'migracao', verificadoEm: T2 }));
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'legado_nao_sobrescreve');
});

test('DA-12 legado entra onde nao ha nada', () => {
  const d = decidirAtualizacao(null, proposta({ fonte: 'migracao' }));
  assert.strictEqual(d.aplicar, true);
});

test('DA-13 proposta sem carimbo de verificacao e recusada', () => {
  const d = decidirAtualizacao(gravado(), proposta({ verificadoEm: null }));
  assert.strictEqual(d.aplicar, false);
  assert.strictEqual(d.motivo, 'proposta_sem_verificacao');
});

test('DA-14 duas verificacoes concorrentes: vence quem consultou depois', () => {
  // As duas leem o MESMO estado inicial (e o que a transacao garante ao reler).
  const inicial = gravado({ ultimaVerificacaoEm: T0 });
  const rtdn = proposta({ fonte: 'rtdn', verificadoEm: T1, estado: ESTADO.EM_CARENCIA });
  const manual = proposta({ fonte: 'reconciliacao', verificadoEm: T2 });

  // Ordem A: a mais antiga commita primeiro.
  assert.strictEqual(decidirAtualizacao(inicial, rtdn).aplicar, true);
  const depoisDeRtdn = gravado({ ultimaVerificacaoEm: T1, estado: ESTADO.EM_CARENCIA });
  assert.strictEqual(decidirAtualizacao(depoisDeRtdn, manual).aplicar, true);

  // Ordem B: a mais nova commita primeiro. A antiga NAO desfaz.
  assert.strictEqual(decidirAtualizacao(inicial, manual).aplicar, true);
  const depoisDeManual = gravado({ ultimaVerificacaoEm: T2 });
  assert.strictEqual(decidirAtualizacao(depoisDeManual, rtdn).aplicar, false);
});

// ===================================================== DOCUMENTOS GRAVADOS

test('DOC-01 o documento do jogador nao carrega token nem metadado interno', () => {
  const { publico } = documentosDeEntitlement(null, proposta());
  const proibidos = [
    'purchaseToken',
    'purchaseTokenHash',
    'ultimaVerificacaoEm',
    'ultimoEventoEm',
    'ultimoEventoTipo',
    'orderId',
  ];
  for (const campo of proibidos) {
    assert.ok(!(campo in publico), `${campo} vazou para o documento publico`);
  }
  assert.deepStrictEqual(Object.keys(publico).sort(), [
    'atualizadoEm',
    'esquema',
    'estado',
    'expiraEm',
    'inicioEm',
    'origem',
    'produtoId',
    'renovacaoAutomatica',
    'uid',
    'vipAtivo',
  ]);
});

test('DOC-02 o token fica no documento interno, e so nele', () => {
  const { interno } = documentosDeEntitlement(null, proposta());
  assert.strictEqual(interno.purchaseToken, 'token-cru');
  assert.strictEqual(interno.purchaseTokenHash, HASH);
});

test('DOC-03 carimbo de evento so anda para a frente', () => {
  const { interno } = documentosDeEntitlement(
    { ultimoEventoEm: T2, purchaseTokenHash: HASH },
    proposta({ eventoEm: T0 })
  );
  assert.strictEqual(interno.ultimoEventoEm, T2);
});

test('DOC-04 varredura por relogio preserva o token do mesmo direito', () => {
  // A varredura conclui pela data e nao tem token na mao. Perde-lo inviabilizaria
  // a reconciliacao manual depois.
  const { interno, publico } = documentosDeEntitlement(
    gravado(),
    proposta({
      fonte: 'relogio',
      estado: ESTADO.EXPIRADO,
      vipAtivo: false,
      purchaseToken: null,
      produtoId: null,
      verificadoEm: T2,
    })
  );
  assert.strictEqual(interno.purchaseToken, 'token-cru');
  assert.strictEqual(publico.produtoId, PRODUTO);
  assert.strictEqual(publico.vipAtivo, false);
});

test('DOC-05 nao se herda token de um direito diferente', () => {
  const { interno } = documentosDeEntitlement(
    gravado({ purchaseTokenHash: HASH_OUTRO, purchaseToken: 'token-alheio' }),
    proposta({ purchaseToken: null, fonte: 'relogio' })
  );
  assert.strictEqual(interno.purchaseToken, null);
});

// ================================================ CONTRATO COM O CONSUMIDOR

/**
 * O ESPELHO. Estes documentos sao, literalmente, os que
 * `app/test/elegibilidade/costura_p0_test.dart` usa para provar quem entra e
 * quem nao entra num torneio VIP.
 *
 * A duplicacao existe porque o produtor e JavaScript e o consumidor e Dart, e
 * nao ha runtime que rode os dois. O que ela NAO e: uma copia solta que alguem
 * lembra de atualizar. Cada documento aqui e construido pelo produtor de
 * verdade (`consolidarAssinatura`/`consolidarTerminal` + `documentosDeEntitlement`)
 * e comparado campo a campo com o literal do outro lado. Mudar um nome de campo,
 * um formato de data ou um valor de `estado` quebra este arquivo — e e ai que se
 * descobre, e nao em producao com o assinante barrado na porta.
 *
 * Se um destes assertivos falhar, o conserto NAO e ajustar o literal daqui: e
 * conferir se o teste Dart correspondente ainda descreve a verdade.
 */

const C_UID = 'jogadora-ana';
const C_PRODUTO = 'master_vip_mensal';
const C_AGORA = '2026-08-11T20:00:00.000Z';
const C_INICIO = '2026-08-06T20:00:00.000Z';
const C_FUTURO = '2026-08-31T20:00:00.000Z';
const C_PASSADO = '2026-08-06T20:00:00.000Z';
const C_HASH = 'c'.repeat(64);

function respostaContrato(estado, expiryTime, autoRenew) {
  return {
    subscriptionState: estado,
    startTime: C_INICIO,
    lineItems: [
      { productId: C_PRODUTO, expiryTime, autoRenewingPlan: { autoRenewEnabled: autoRenew } },
    ],
  };
}

function publicoDeAssinatura(estadoPlay, expiryTime, autoRenew) {
  const consolidado = consolidarAssinatura(
    respostaContrato(estadoPlay, expiryTime, autoRenew),
    C_AGORA
  );
  return documentosDeEntitlement(null, {
    uid: C_UID,
    ...consolidado,
    origem: 'play',
    purchaseTokenHash: C_HASH,
    purchaseToken: 'token-cru',
    verificadoEm: C_AGORA,
    fonte: 'validacao',
  }).publico;
}

function esperado(extra) {
  return {
    uid: C_UID,
    vipAtivo: false,
    estado: null,
    produtoId: C_PRODUTO,
    origem: 'play',
    inicioEm: C_INICIO,
    expiraEm: null,
    renovacaoAutomatica: false,
    atualizadoEm: C_AGORA,
    esquema: 1,
    ...extra,
  };
}

test('CT-01 [Dart B/D] assinatura ativa — o documento que concede', () => {
  assert.deepStrictEqual(
    publicoDeAssinatura('SUBSCRIPTION_STATE_ACTIVE', C_FUTURO, true),
    esperado({ vipAtivo: true, estado: 'ativo', expiraEm: C_FUTURO, renovacaoAutomatica: true })
  );
});

test('CT-02 [Dart G/G-2] cancelado com periodo pago', () => {
  assert.deepStrictEqual(
    publicoDeAssinatura('SUBSCRIPTION_STATE_CANCELED', C_FUTURO, false),
    esperado({ vipAtivo: true, estado: 'cancelado_vigente', expiraEm: C_FUTURO })
  );
});

test('CT-03 [Dart H] carencia concede, conta em atraso nao', () => {
  assert.deepStrictEqual(
    publicoDeAssinatura('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', C_FUTURO, true),
    esperado({ vipAtivo: true, estado: 'em_carencia', expiraEm: C_FUTURO, renovacaoAutomatica: true })
  );
  assert.deepStrictEqual(
    publicoDeAssinatura('SUBSCRIPTION_STATE_ON_HOLD', C_FUTURO, true),
    esperado({ estado: 'em_espera', expiraEm: C_FUTURO, renovacaoAutomatica: true })
  );
});

test('CT-04 [Dart D-2] expirado', () => {
  assert.deepStrictEqual(
    publicoDeAssinatura('SUBSCRIPTION_STATE_EXPIRED', C_PASSADO, false),
    esperado({ estado: 'expirado', expiraEm: C_PASSADO })
  );
});

test('CT-05 [Dart E/F] revogado e reembolsado', () => {
  for (const alvo of [ESTADO.REVOGADO, ESTADO.REEMBOLSADO]) {
    const publico = documentosDeEntitlement(
      { purchaseTokenHash: C_HASH, produtoId: C_PRODUTO, purchaseToken: 'token-cru' },
      {
        uid: C_UID,
        ...consolidarTerminal(alvo, C_AGORA),
        origem: 'play',
        purchaseTokenHash: C_HASH,
        purchaseToken: 'token-cru',
        verificadoEm: C_AGORA,
        fonte: 'rtdn',
      }
    ).publico;

    // Sem `inicioEm`, e com o prazo encerrado no instante do evento: um
    // desfecho terminal descreve o fim, nao o periodo.
    assert.deepStrictEqual(
      publico,
      esperado({ estado: alvo, expiraEm: C_AGORA, inicioEm: null }),
      alvo
    );
  }
});

test('DOC-06 rotulo de log nunca devolve o hash inteiro', () => {
  assert.strictEqual(rotuloToken(HASH).length, 8);
  assert.notStrictEqual(rotuloToken(HASH), HASH);
  assert.strictEqual(rotuloToken(null), 'sem-token');
  assert.strictEqual(rotuloToken(''), 'sem-token');
});
