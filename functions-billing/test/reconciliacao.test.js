/**
 * Testes da RECONCILIACAO — o nucleo que todo caminho autoritativo atravessa.
 *
 * O QUE JA ESTAVA COBERTO, E O QUE NAO ESTAVA
 *
 * `entitlement.test.js` cobre exaustivamente as duas PECAS que a reconciliacao
 * usa: `consolidarAssinatura` (traduzir a resposta da Google) nos casos CV-*, e
 * `decidirAtualizacao` (a proposta entra?) nos casos DA-*. O que nao tinha suite
 * propria era o ENCADEAMENTO — `criarReconciliador`, que junta as duas com a
 * consulta a Google e a gravacao.
 *
 * A distincao importa porque o encadeamento tem invariantes que as pecas nao
 * podem ter sozinhas:
 *
 *   ORDEM       o carimbo `consultadoEm` e capturado ANTES da chamada de rede.
 *               Uma resposta que demorou dez segundos descreve o mundo de dez
 *               segundos atras; carimba-la com o instante da VOLTA a faria
 *               ganhar de uma consulta mais nova que respondeu rapido.
 *   FALHA       quando a Google nao responde, a excecao SOBE e nada e gravado.
 *               Metade do tratamento de falha transitoria do RTDN e exatamente
 *               isto (a outra metade e `retry: true` no gatilho).
 *   IDENTIDADE  o hash gravado e derivado do token consultado, e nao de um
 *               parametro solto.
 *
 * Nenhuma validacao existente foi relaxada para estes testes passarem.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const { criarReconciliador } = require('../reconciliacao');
const { ESTADO, decidirAtualizacao } = require('../entitlement');
const { chaveDaCompra } = require('../entitlementStore');
const { identificadorDaResposta, vinculoBemFormado } = require('../propriedade');

const AGORA = '2026-08-15T12:00:00.000Z';
const TOKEN = 'token-de-assinatura-abc';

/** O dono das compras desta suite. Era o `uid` solto das chamadas; virou uma
 *  IDENTIDADE, resolvida pela mesma autoridade que roda em producao. */
const UID_DONO = 'jogador-a';

/** Vinculo opaco do dono. Hexadecimal de 32, que e a forma que
 *  `vinculoBemFormado` aceita — nao um texto qualquer que passasse por
 *  descuido. */
const VINCULO_DONO = 'a1'.repeat(16);

/** Vinculo de OUTRA conta, bem formado e desconhecido do indice. */
const VINCULO_ALHEIO = 'b2'.repeat(16);

/**
 * Poe o vinculo opaco na resposta da Google, no lugar onde ela o entrega.
 *
 * `SubscriptionPurchaseV2` carrega o identificador em
 * `externalAccountIdentifiers.obfuscatedExternalAccountId`. Uma compra REAL
 * sempre o traz — foi por isso que a correcao de propriedade pode exigi-lo —,
 * e as respostas desta suite nasceram antes dele existir. Injetar aqui devolve
 * as fixtures a forma de producao SEM tocar no que cada teste mede.
 *
 * So injeta se a resposta ainda nao tiver identificador: um caso que declare o
 * seu (ou que declare NENHUM, de proposito) manda.
 */
function comVinculo(resposta, vinculo) {
  if (vinculo === null) return resposta;
  if (!resposta || typeof resposta !== 'object' || Array.isArray(resposta)) return resposta;
  if (identificadorDaResposta(resposta) !== null) return resposta;
  return { ...resposta, externalAccountIdentifiers: { obfuscatedExternalAccountId: vinculo } };
}

/** Resposta da Play Developer API para uma assinatura em dia. */
function respostaAtiva(ate = '2026-12-01T00:00:00.000Z') {
  return {
    subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
    lineItems: [{ expiryTime: ate, productId: 'vip_assinatura' }],
  };
}

/**
 * Uma mesa de reconciliacao: Google roteirizada + store que obedece a regra
 * REAL de precedencia.
 */
function montar({
  resposta = respostaAtiva(),
  lanca = null,
  existente = null,
  vinculo = VINCULO_DONO,
  indice = { [VINCULO_DONO]: UID_DONO },
} = {}) {
  const consultas = [];
  const gravacoes = [];
  const vinculosConsultados = [];
  let atual = existente;

  // A AUTORIDADE DE PROPRIEDADE, e nao um atalho.
  //
  // Espelha `criarStore(...).uidDoVinculo` linha a linha: guarda de FORMA,
  // consulta ao indice `billingAccountIndex`, e `null` quando o documento nao
  // existe ou nao tem uid. Um `async () => UID_DONO` faria os 14 casos abaixo
  // passarem sem que propriedade nenhuma fosse resolvida — e a suite passaria a
  // provar o contrario do que a correcao P0 fechou.
  const uidDoVinculo = async (contaOfuscada) => {
    vinculosConsultados.push(contaOfuscada);
    if (!vinculoBemFormado(contaOfuscada)) return null;
    const uid = indice[contaOfuscada];
    return typeof uid === 'string' && uid !== '' ? uid : null;
  };

  const reconciliador = criarReconciliador({
    agora: () => AGORA,
    uidDoVinculo,
    consultarAssinatura: async (token) => {
      consultas.push(token);
      if (lanca) throw lanca;
      return comVinculo(typeof resposta === 'function' ? resposta() : resposta, vinculo);
    },
    aplicarProposta: async (proposta) => {
      gravacoes.push(proposta);
      const decisao = decidirAtualizacao(atual, proposta);
      if (decisao.aplicar) {
        // O documento GRAVADO chama de `ultimaVerificacaoEm` o que a PROPOSTA
        // chama de `verificadoEm` (ver `documentosDeEntitlement`), e e esse
        // campo que `decidirAtualizacao` compara para ordenar. Guardar a
        // proposta crua faria toda releitura parecer nova, e a suite passaria a
        // provar o oposto do que pretende.
        atual = { ...proposta, ultimaVerificacaoEm: proposta.verificadoEm };
      }
      return {
        aplicado: decisao.aplicar,
        motivo: decisao.motivo,
        estado: proposta.estado,
        vipAtivo: proposta.vipAtivo,
      };
    },
  });

  return {
    reconciliador,
    consultas,
    gravacoes,
    vinculosConsultados,
    get estado() {
      return atual;
    },
  };
}

// ---------------------------------------------------------------------------

test('REC-01 compra valida: consulta a Google e grava o que ela respondeu', async () => {
  const mesa = montar();

  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    produtoId: 'vip_assinatura',
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  assert.equal(mesa.consultas.length, 1);
  assert.equal(mesa.consultas[0], TOKEN, 'consultou com o token CRU');
  assert.equal(r.aplicado, true);
  assert.equal(r.estado, ESTADO.ATIVO);
  assert.equal(r.vipAtivo, true);
});

test('REC-02 o hash gravado deriva do token consultado', async () => {
  const mesa = montar();

  await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  const p = mesa.gravacoes[0];
  assert.equal(p.purchaseTokenHash, chaveDaCompra(TOKEN));
  // O token CRU tambem vai — para o documento INTERNO, que e a unica razao pela
  // qual ele e guardado (reconsulta administrativa).
  assert.equal(p.purchaseToken, TOKEN);
  assert.equal(p.origem, 'play');
});

test('REC-03 compra INEXISTENTE para a Google nao concede nada', async () => {
  // A Play responde sem `lineItems`: sem prazo, sem direito.
  const mesa = montar({ resposta: { subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE' } });

  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  assert.equal(r.vipAtivo, false);
  assert.equal(mesa.estado.vipAtivo, false);
});

test('REC-04 estado EXPIRADO na Google fecha o direito', async () => {
  const mesa = montar({
    resposta: {
      subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
      lineItems: [{ expiryTime: '2026-07-01T00:00:00.000Z' }],
    },
  });

  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'reconciliacao',
  });

  assert.equal(r.estado, ESTADO.EXPIRADO);
  assert.equal(r.vipAtivo, false);
});

test('REC-05 prazo vencido nao concede, mesmo com a Google dizendo ACTIVE', async () => {
  // O relogio desmente o estado. E a mesma regra que o cliente aplica em
  // `EntitlementVip.vigenteEm` — uma definicao so, nao duas.
  const mesa = montar({ resposta: respostaAtiva('2026-08-01T00:00:00.000Z') });

  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'reconciliacao',
  });

  assert.equal(r.vipAtivo, false);
});

test('REC-06 renovacao ESTENDE o prazo do direito ja existente', async () => {
  const mesa = montar({
    existente: {
      uidEsperado: UID_DONO,
      estado: ESTADO.ATIVO,
      vipAtivo: true,
      expiraEm: '2026-09-01T00:00:00.000Z',
      purchaseTokenHash: chaveDaCompra(TOKEN),
      ultimaVerificacaoEm: '2026-08-01T00:00:00.000Z',
      origem: 'play',
    },
    resposta: respostaAtiva('2026-12-01T00:00:00.000Z'),
  });

  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'rtdn',
  });

  assert.equal(r.aplicado, true);
  assert.equal(mesa.estado.expiraEm, '2026-12-01T00:00:00.000Z');
});

test('REC-07 revogacao entra e derruba o direito vigente', async () => {
  const mesa = montar({
    existente: {
      uidEsperado: UID_DONO,
      estado: ESTADO.ATIVO,
      vipAtivo: true,
      expiraEm: '2026-12-01T00:00:00.000Z',
      purchaseTokenHash: chaveDaCompra(TOKEN),
      ultimaVerificacaoEm: '2026-08-01T00:00:00.000Z',
      origem: 'play',
    },
    resposta: {
      subscriptionState: 'SUBSCRIPTION_STATE_EXPIRED',
      lineItems: [{ expiryTime: '2026-12-01T00:00:00.000Z' }],
    },
  });

  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'rtdn',
  });

  assert.equal(r.aplicado, true);
  assert.equal(mesa.estado.vipAtivo, false);
});

test('REC-08 chamada REPETIDA converge: o estado final e o mesmo', async () => {
  const mesa = montar();

  await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });
  const depoisDe1 = { ...mesa.estado };

  const segunda = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  // Mesmo carimbo de verificacao: nao ha efeito NOVO, e o estado nao muda.
  assert.equal(segunda.aplicado, false, 'reprocessar a mesma verificacao nao aplica');
  assert.deepEqual(mesa.estado, depoisDe1);
  assert.equal(mesa.consultas.length, 2, 'mas a Google foi consultada de novo');
});

test('REC-09 falha da Google SOBE e nao grava nada', async () => {
  const mesa = montar({ lanca: new Error('Play Developer API indisponivel') });

  await assert.rejects(
    mesa.reconciliador.reconsultarEAplicar({
      uidEsperado: UID_DONO,
      tokenCompra: TOKEN,
      fonte: 'rtdn',
    }),
    /indisponivel/
  );

  // A metade do tratamento de falha transitoria que mora aqui: sem gravacao, e
  // sem conceder por conta propria. `retry: true` no gatilho e a outra metade.
  assert.equal(mesa.gravacoes.length, 0);
  assert.equal(mesa.estado, null);
});

test('REC-10 falha externa nao derruba um direito que ja valia', async () => {
  const existente = {
    uidEsperado: UID_DONO,
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    expiraEm: '2026-12-01T00:00:00.000Z',
    ultimaVerificacaoEm: '2026-08-01T00:00:00.000Z',
    origem: 'play',
  };
  const mesa = montar({ lanca: new Error('timeout'), existente });

  await assert.rejects(
    mesa.reconciliador.reconsultarEAplicar({
      uidEsperado: UID_DONO,
      tokenCompra: TOKEN,
      fonte: 'reconciliacao',
    })
  );

  assert.deepEqual(mesa.estado, existente, 'o direito bom seguiu intacto');
});

test('REC-11 o carimbo e capturado ANTES da chamada de rede', async () => {
  // Se `consultadoEm` fosse tirado da VOLTA, uma resposta lenta ganharia de uma
  // consulta mais nova que respondeu rapido — e `decidirAtualizacao` compara
  // exatamente esse carimbo. Inverter as duas linhas de `reconciliacao.js`
  // reintroduz o defeito sem que nenhum teste de dominio perceba.
  const instantes = ['2026-08-15T12:00:00.000Z', '2026-08-15T12:00:09.000Z'];
  let i = 0;

  const gravacoes = [];
  const reconciliador = criarReconciliador({
    agora: () => instantes[i++],
    // Mesma autoridade de propriedade do `montar`, e pelo mesmo motivo: este
    // caso monta o seu proprio reconciliador para controlar o relogio, e nao
    // para escapar da propriedade.
    uidDoVinculo: async (conta) =>
      (vinculoBemFormado(conta) && conta === VINCULO_DONO ? UID_DONO : null),
    consultarAssinatura: async () => {
      // A "rede" consome o segundo instante: se o carimbo fosse lido depois da
      // consulta, ele seria o das 12:00:09.
      i += 0;
      return comVinculo(respostaAtiva(), VINCULO_DONO);
    },
    aplicarProposta: async (p) => {
      gravacoes.push(p);
      return { aplicado: true, motivo: 'ok', estado: p.estado, vipAtivo: p.vipAtivo };
    },
  });

  await reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  assert.equal(gravacoes[0].verificadoEm, '2026-08-15T12:00:00.000Z');
});

test('REC-12 o produtoId do parametro so preenche o que a Google nao disse', async () => {
  // A Google e a autoridade. O parametro e recurso de ultimo caso, para quando a
  // resposta nao traz o produto.
  const comProduto = montar({ resposta: respostaAtiva() });
  await comProduto.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    produtoId: 'produto_do_parametro',
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });
  assert.equal(comProduto.gravacoes[0].produtoId, 'vip_assinatura');

  const semProduto = montar({
    resposta: {
      subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
      lineItems: [{ expiryTime: '2026-12-01T00:00:00.000Z' }],
    },
  });
  await semProduto.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    produtoId: 'produto_do_parametro',
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });
  assert.equal(semProduto.gravacoes[0].produtoId, 'produto_do_parametro');
});

test('REC-13 a fonte e os metadados do evento chegam na proposta', async () => {
  const mesa = montar();

  await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'rtdn',
    eventoEm: '2026-08-15T11:59:00.000Z',
    eventoTipo: 2,
  });

  const p = mesa.gravacoes[0];
  assert.equal(p.fonte, 'rtdn');
  assert.equal(p.eventoEm, '2026-08-15T11:59:00.000Z');
  assert.equal(p.eventoTipo, 2);
});

// ---------------------------------------------------------------------------
// PROPRIEDADE — os casos que a composicao trouxe, e que esta suite nao tinha.
//
// Ela nasceu antes de a compra ter dono comprovavel: o `uid` era um parametro
// solto, e quem apresentasse o token primeiro ficava com o VIP. A correcao P0
// amarrou a compra a conta por um identificador opaco, e `reconsultarEAplicar`
// passou a resolver propriedade ANTES de gravar qualquer coisa.
//
// Os quatro casos abaixo exercitam as quatro respostas de `decidirPropriedade`.
// Sem eles, adaptar o arnes teria sido so fazer os REC-* pararem de reclamar.
// ---------------------------------------------------------------------------

test('REC-P1 resposta SEM vinculo nao grava nada', async () => {
  // Compra sem identificador de conta e compra sem dono. Antes da correcao, o
  // dono virava o parametro; agora nao ha a quem atribuir, e recusar e a unica
  // resposta honesta.
  const mesa = montar({ vinculo: null });
  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  assert.equal(r.aplicado, false);
  assert.equal(r.motivo, 'vinculo_ausente');
  assert.equal(mesa.gravacoes.length, 0, 'nada pode ser gravado sem dono');
  assert.equal(mesa.estado, null);
});

test('REC-P2 vinculo MALFORMADO nao passa pela guarda de forma', async () => {
  // Forma e a primeira barreira: um identificador que nao tem a forma que ESTA
  // autoridade emite nao foi emitido por nos, e trata-lo como "provavelmente e
  // nosso" reabriria a porta pelo lado de dentro.
  for (const ruim of ['nao-e-hex', 'A1'.repeat(16), 'a1', 'a1'.repeat(40), '']) {
    const mesa = montar({
      resposta: { ...respostaAtiva(), obfuscatedExternalAccountId: ruim },
      indice: { [ruim]: UID_DONO },
    });
    const r = await mesa.reconciliador.reconsultarEAplicar({
      uidEsperado: UID_DONO,
      tokenCompra: TOKEN,
      fonte: 'validacao',
    });
    assert.equal(r.aplicado, false, 'aceitou vinculo malformado: [' + ruim + ']');
    assert.equal(mesa.gravacoes.length, 0);
  }
});

test('REC-P3 vinculo bem formado mas DESCONHECIDO do indice recusa', async () => {
  // O identificador tem a forma certa e mesmo assim nao pertence a conta
  // nenhuma. E o caso de um token vazado com vinculo forjado na forma correta.
  const mesa = montar({ vinculo: VINCULO_ALHEIO });
  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  assert.equal(r.aplicado, false);
  assert.equal(r.motivo, 'vinculo_desconhecido');
  assert.equal(mesa.gravacoes.length, 0);
  assert.deepEqual(mesa.vinculosConsultados, [VINCULO_ALHEIO], 'consultou o indice de verdade');
});

test('REC-P4 compra de OUTRA conta nao entra na sessao autenticada', async () => {
  // O defeito original, no seu formato exato: quem tem o token da vitima chama
  // com a propria sessao. O indice resolve o dono VERDADEIRO, e a divergencia
  // com a sessao recusa.
  const mesa = montar({
    vinculo: VINCULO_ALHEIO,
    indice: { [VINCULO_DONO]: UID_DONO, [VINCULO_ALHEIO]: 'jogador-vitima' },
  });
  const r = await mesa.reconciliador.reconsultarEAplicar({
    uidEsperado: UID_DONO,
    tokenCompra: TOKEN,
    fonte: 'validacao',
  });

  assert.equal(r.aplicado, false);
  assert.equal(r.motivo, 'vinculo_divergente');
  assert.equal(mesa.gravacoes.length, 0, 'o atacante nao grava nada');
});

test('REC-P5 sem sessao (RTDN), o dono e quem o indice resolveu', async () => {
  // O caminho da notificacao nao tem sessao. O dono nao pode ser "quem pediu" —
  // nao ha quem pediu. Sai do indice, e o entitlement e gravado sob ELE.
  const mesa = montar({
    vinculo: VINCULO_ALHEIO,
    indice: { [VINCULO_ALHEIO]: 'jogador-dono-real' },
  });
  const r = await mesa.reconciliador.reconsultarEAplicar({
    tokenCompra: TOKEN,
    fonte: 'rtdn',
  });

  assert.equal(r.aplicado, true);
  assert.equal(mesa.gravacoes.length, 1);
  assert.equal(mesa.gravacoes[0].uid, 'jogador-dono-real');
});
