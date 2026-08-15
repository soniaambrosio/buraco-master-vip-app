/**
 * backfillEfeitos.test.js — O QUE MUDA quando `purchaseTokenHash` deixa de ser
 * nulo.
 *
 * POR QUE ESTE ARQUIVO E SEPARADO DE `backfillHash.test.js`
 *
 * Aquele prova que o mecanismo escolhe o hash certo. Este prova a outra metade,
 * que e a que assusta: preencher o campo NAO E INERTE. `purchaseTokenHash`
 * alimenta `mesmoToken`, e `mesmoToken` governa tres decisoes de
 * `decidirAtualizacao` — titularidade (`token_superado`), desfecho terminal
 * (`terminal_preservado`) e heranca de campo em `documentosDeEntitlement`. Um
 * `null` que vira valor muda o que o sistema aceita dali em diante.
 *
 * A FORMA DOS TESTES E O ARGUMENTO
 *
 * Quase todos rodam a MESMA proposta contra o MESMO estado duas vezes — uma com
 * `purchaseTokenHash: null` (hoje) e outra com o hash historico (depois do
 * backfill) — e afirmam as DUAS decisoes. Um teste que so afirmasse o depois
 * provaria que o codigo faz o que faz; afirmar o par prova o que MUDOU, que e a
 * pergunta que a OS faz.
 *
 * O INVENTARIO ESTA EM `IMP-20`: os quatorze cenarios que a OS exige, cada um com
 * o antes e o depois lado a lado, numa tabela que e o mesmo conteudo da secao E
 * de `docs/BACKFILL-PURCHASETOKENHASH.md`. Se o comportamento mudar, o documento
 * fica errado E o teste quebra — que e o unico jeito de os dois nao divergirem.
 *
 * E `IMP-30` a `IMP-34` fecham a pergunta economica: a ficha mensal volta a ser
 * paga, uma vez so por parcela, e o backfill sozinho NAO basta para o direito
 * migrado — ver `IMP-33`, que e um achado desta OS e nao um teste de rotina.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  ESTADO,
  decidirAtualizacao,
  documentosDeEntitlement,
  consolidarTerminal,
} = require('../entitlement');
const { chaveDaCompra } = require('../entitlementStore');
const { criarLivroDeFichas } = require('../fichasStore');
const { concederFichasDeTodosOsAssinantes } = require('../fichasVarredura');
const { anteriorA } = require('../entitlement');
const { FirestoreFalso, CARIMBO, FieldPathFalso } = require('./apoio/firestore_falso');

const TOKEN = 'token-da-assinatura-legada';
const HASH = chaveDaCompra(TOKEN);
const OUTRO_TOKEN = 'token-de-outra-assinatura';
const OUTRO_HASH = chaveDaCompra(OUTRO_TOKEN);

const ONTEM = '2026-08-14T12:00:00.000Z';
const AGORA = '2026-08-15T12:00:00.000Z';
const DEPOIS = '2026-08-16T12:00:00.000Z';
const FUTURO = '2026-12-01T00:00:00.000Z';
const PASSADO = '2026-07-01T00:00:00.000Z';

/**
 * O estado atual de um entitlement legado, nas duas versoes que interessam.
 *
 * `antes` e o documento como a migracao o deixou; `depois` e o mesmo documento
 * com o unico campo que o backfill toca.
 */
function legado(extra = {}) {
  const base = {
    uid: 'u1',
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: 'vip_assinatura',
    planoBase: null,
    origem: 'legado_usuarios',
    expiraEm: FUTURO,
    ultimaVerificacaoEm: ONTEM,
    ...extra,
  };
  return {
    antes: { ...base, purchaseTokenHash: null },
    depois: { ...base, purchaseTokenHash: HASH },
  };
}

/** Uma proposta vinda da Play, com o hash do token que a produziu. */
function proposta(extra = {}) {
  return {
    uid: 'u1',
    estado: ESTADO.ATIVO,
    vipAtivo: true,
    produtoId: 'vip_assinatura',
    planoBase: 'mensal',
    origem: 'play',
    inicioEm: PASSADO,
    expiraEm: FUTURO,
    renovacaoAutomatica: true,
    purchaseTokenHash: HASH,
    purchaseToken: TOKEN,
    verificadoEm: AGORA,
    fonte: 'rtdn',
    ...extra,
  };
}

/**
 * Roda a MESMA proposta contra o mesmo estado, antes e depois do backfill.
 * @returns {{antes: {aplicar: boolean, motivo: string}, depois: ...}}
 */
function antesEDepois(estadoAtual, prop) {
  return {
    antes: decidirAtualizacao(estadoAtual.antes, prop),
    depois: decidirAtualizacao(estadoAtual.depois, prop),
  };
}

// ===========================================================================
// O QUE O CAMPO NULO SIGNIFICA HOJE
// ===========================================================================

test('IMP-01 hoje um entitlement sem hash nao tem protecao de titularidade nenhuma', () => {
  // `if (!mesmoToken && fonte !== "validacao") { if (atual.purchaseTokenHash) ... }`
  // nao dispara quando o campo e nulo. Um evento de QUALQUER token entra.
  const r = decidirAtualizacao(
    legado().antes,
    proposta({ purchaseTokenHash: OUTRO_HASH, purchaseToken: OUTRO_TOKEN })
  );
  assert.equal(r.aplicar, true);
  assert.equal(r.motivo, 'estado_atualizado');
});

test('IMP-02 hoje um entitlement sem hash nao tem protecao de desfecho terminal', () => {
  // `terminalVigente` exige `mesmoToken`. Com hash nulo ele e sempre falso, entao
  // uma leitura atrasada que ainda diga ACTIVE RESSUSCITA um direito estornado.
  const estornado = legado({ estado: ESTADO.REEMBOLSADO, vipAtivo: false });
  const r = antesEDepois(estornado, proposta());

  assert.equal(r.antes.aplicar, true, 'hoje o estorno e ressuscitavel');
  assert.equal(r.depois.aplicar, false);
  assert.equal(r.depois.motivo, 'terminal_preservado');
});

test('IMP-03 preencher o hash LIGA as duas protecoes, e essa e a mudanca', () => {
  const r = antesEDepois(
    legado(),
    proposta({ purchaseTokenHash: OUTRO_HASH, purchaseToken: OUTRO_TOKEN })
  );
  assert.equal(r.antes.aplicar, true);
  assert.equal(r.depois.aplicar, false);
  assert.equal(r.depois.motivo, 'token_superado');
});

// ===========================================================================
// OS QUATORZE CENARIOS
// ===========================================================================

test('IMP-10 (1) entitlement legado sem hash: nenhuma decisao depende de mesmoToken', () => {
  const atual = legado().antes;
  assert.equal(Boolean(atual.purchaseTokenHash), false);
  // Toda proposta nao-terminal e nao-antiga entra, venha de onde vier.
  for (const fonte of ['rtdn', 'reconciliacao', 'relogio', 'validacao']) {
    const r = decidirAtualizacao(atual, proposta({ fonte }));
    assert.equal(r.aplicar, true, `fonte ${fonte}`);
  }
});

test('IMP-11 (2) hash preenchido com o correspondente historico: mesmoToken passa a valer', () => {
  const docs = documentosDeEntitlement(legado().depois, proposta());
  assert.equal(docs.interno.purchaseTokenHash, HASH);
  // E a heranca de campo, que antes nao acontecia, passa a acontecer.
  const semProduto = proposta({ produtoId: null, planoBase: null });
  const herdado = documentosDeEntitlement(
    { ...legado().depois, produtoId: 'vip_assinatura', planoBase: 'anual' },
    semProduto
  );
  assert.equal(herdado.publico.produtoId, 'vip_assinatura');
  assert.equal(herdado.publico.planoBase, 'anual');
});

test('IMP-12 (3) evento posterior do MESMO token continua sendo aceito', () => {
  const r = antesEDepois(legado(), proposta({ verificadoEm: DEPOIS }));
  assert.equal(r.antes.aplicar, true);
  assert.equal(r.depois.aplicar, true);
  assert.equal(r.depois.motivo, 'estado_atualizado');
});

test('IMP-13 (4) evento de token DIFERENTE passa a ser recusado — e essa e a unica regressao', () => {
  const r = antesEDepois(
    legado(),
    proposta({ purchaseTokenHash: OUTRO_HASH, purchaseToken: OUTRO_TOKEN })
  );
  assert.equal(r.antes.aplicar, true);
  assert.equal(r.depois.aplicar, false);
  assert.equal(r.depois.motivo, 'token_superado');

  // E ela NAO alcanca uma compra nova feita pelo app: `fonte: 'validacao'`
  // atravessa o portao de titularidade por desenho, e e assim que uma
  // reassinatura volta a valer.
  const compraNova = decidirAtualizacao(
    legado().depois,
    proposta({
      purchaseTokenHash: OUTRO_HASH,
      purchaseToken: OUTRO_TOKEN,
      fonte: 'validacao',
    })
  );
  assert.equal(compraNova.aplicar, true);
});

test('IMP-14 (5) renovacao do mesmo token entra antes e depois, e estende o prazo', () => {
  const renovacao = proposta({
    expiraEm: '2027-01-01T00:00:00.000Z',
    verificadoEm: DEPOIS,
    eventoTipo: 2,
  });
  const r = antesEDepois(legado(), renovacao);
  assert.equal(r.antes.aplicar, true);
  assert.equal(r.depois.aplicar, true);

  const docs = documentosDeEntitlement(legado().depois, renovacao);
  assert.equal(docs.publico.expiraEm, '2027-01-01T00:00:00.000Z');
  assert.equal(docs.publico.vipAtivo, true);
});

test('IMP-15 (6) cancelamento nao tira acesso, e o backfill nao muda isso', () => {
  const cancelado = proposta({
    estado: ESTADO.CANCELADO_VIGENTE,
    vipAtivo: true,
    renovacaoAutomatica: false,
    verificadoEm: DEPOIS,
    eventoTipo: 3,
  });
  const r = antesEDepois(legado(), cancelado);
  assert.equal(r.antes.aplicar, true);
  assert.equal(r.depois.aplicar, true);

  const docs = documentosDeEntitlement(legado().depois, cancelado);
  assert.equal(docs.publico.estado, ESTADO.CANCELADO_VIGENTE);
  assert.equal(docs.publico.vipAtivo, true, 'cancelado nao e perdido: o prazo manda');
});

test('IMP-16 (7) revogacao entra nos dois casos, e passa a ser IRREVERSIVEL', () => {
  const revogacao = {
    ...proposta({ verificadoEm: DEPOIS, eventoTipo: 12 }),
    ...consolidarTerminal(ESTADO.REVOGADO, DEPOIS),
    purchaseTokenHash: HASH,
    verificadoEm: DEPOIS,
    fonte: 'rtdn',
  };
  const r = antesEDepois(legado(), revogacao);
  assert.equal(r.antes.aplicar, true);
  assert.equal(r.depois.aplicar, true);
  assert.equal(r.depois.motivo, 'terminal');

  // A diferenca aparece no evento SEGUINTE.
  const revogado = {
    ...legado({ estado: ESTADO.REVOGADO, vipAtivo: false }).depois,
    ultimaVerificacaoEm: DEPOIS,
  };
  const atrasada = decidirAtualizacao(
    revogado,
    proposta({ verificadoEm: '2026-08-17T12:00:00.000Z' })
  );
  assert.equal(atrasada.aplicar, false);
  assert.equal(atrasada.motivo, 'terminal_preservado');
});

test('IMP-17 (8) reembolso: idem, e a reentrega do mesmo estorno vira convergencia', () => {
  const estornado = legado({ estado: ESTADO.REEMBOLSADO, vipAtivo: false });
  const reentrega = {
    ...proposta(),
    ...consolidarTerminal(ESTADO.REEMBOLSADO, DEPOIS),
    purchaseTokenHash: HASH,
    verificadoEm: DEPOIS,
    fonte: 'rtdn',
  };
  const r = antesEDepois(estornado, reentrega);
  assert.equal(r.antes.aplicar, true, 'hoje o estorno e reaplicado, e nao reconhecido');
  assert.equal(r.depois.aplicar, false);
  assert.equal(r.depois.motivo, 'terminal_repetido');
});

test('IMP-18 (9) RTDN atrasada: o carimbo de verificacao decide, antes e depois', () => {
  const atrasada = proposta({ verificadoEm: PASSADO });
  const r = antesEDepois(legado(), atrasada);
  assert.equal(r.antes.aplicar, false);
  assert.equal(r.antes.motivo, 'verificacao_antiga');
  assert.equal(r.depois.aplicar, false);
  assert.equal(r.depois.motivo, 'verificacao_antiga');
});

test('IMP-19 (10) evento duplicado e (11) evento fora de ordem: sem mudanca', () => {
  // Duplicado: a mesma consulta, com o mesmo carimbo. `verificacao_antiga` cobre
  // o empate porque a comparacao e ESTRITAMENTE anterior.
  const atual = legado({ ultimaVerificacaoEm: AGORA });
  const duplicado = antesEDepois(atual, proposta({ verificadoEm: AGORA }));
  assert.equal(duplicado.antes.motivo, 'verificacao_antiga');
  assert.equal(duplicado.depois.motivo, 'verificacao_antiga');

  // Fora de ordem: chegou depois, consultou antes. Vence quem consultou por
  // ultimo, e nao quem gravou por ultimo.
  const foraDeOrdem = antesEDepois(
    legado({ ultimaVerificacaoEm: DEPOIS }),
    proposta({ verificadoEm: AGORA })
  );
  assert.equal(foraDeOrdem.antes.aplicar, false);
  assert.equal(foraDeOrdem.depois.aplicar, false);
});

test('IMP-20 o inventario dos quatorze cenarios, com antes e depois lado a lado', () => {
  const terminal = (estadoTerminal, hash) => ({
    ...proposta(),
    ...consolidarTerminal(estadoTerminal, DEPOIS),
    purchaseTokenHash: hash,
    verificadoEm: DEPOIS,
    fonte: 'rtdn',
  });

  const casos = [
    // [nome, estadoAtual, proposta, motivoAntes, motivoDepois]
    ['1 legado sem hash', legado(), proposta({ verificadoEm: DEPOIS }),
      'estado_atualizado', 'estado_atualizado'],
    ['2 hash historico preenchido', legado(), proposta({ verificadoEm: DEPOIS }),
      'estado_atualizado', 'estado_atualizado'],
    ['3 evento posterior do mesmo token', legado(), proposta({ verificadoEm: DEPOIS }),
      'estado_atualizado', 'estado_atualizado'],
    ['4 evento de token diferente', legado(),
      proposta({ purchaseTokenHash: OUTRO_HASH, verificadoEm: DEPOIS }),
      'estado_atualizado', 'token_superado'],
    ['5 renovacao', legado(),
      proposta({ verificadoEm: DEPOIS, expiraEm: '2027-01-01T00:00:00.000Z', eventoTipo: 2 }),
      'estado_atualizado', 'estado_atualizado'],
    ['6 cancelamento', legado(),
      proposta({ verificadoEm: DEPOIS, estado: ESTADO.CANCELADO_VIGENTE, eventoTipo: 3 }),
      'estado_atualizado', 'estado_atualizado'],
    ['7 revogacao', legado(), terminal(ESTADO.REVOGADO, HASH), 'terminal', 'terminal'],
    ['8 reembolso', legado(), terminal(ESTADO.REEMBOLSADO, HASH), 'terminal', 'terminal'],
    ['9 RTDN atrasada', legado(), proposta({ verificadoEm: PASSADO }),
      'verificacao_antiga', 'verificacao_antiga'],
    ['10 evento duplicado', legado({ ultimaVerificacaoEm: AGORA }),
      proposta({ verificadoEm: AGORA }), 'verificacao_antiga', 'verificacao_antiga'],
    ['11 evento fora de ordem', legado({ ultimaVerificacaoEm: DEPOIS }),
      proposta({ verificadoEm: AGORA }), 'verificacao_antiga', 'verificacao_antiga'],
    ['12 entitlement expirado', legado({ estado: ESTADO.EXPIRADO, vipAtivo: false }),
      proposta({ verificadoEm: DEPOIS }), 'estado_atualizado', 'estado_atualizado'],
    ['13 entitlement ativo', legado(), proposta({ verificadoEm: DEPOIS }),
      'estado_atualizado', 'estado_atualizado'],
    ['14 hash conflitante (ja terminal)',
      legado({ estado: ESTADO.REVOGADO, vipAtivo: false }),
      proposta({ purchaseTokenHash: OUTRO_HASH, verificadoEm: DEPOIS }),
      'estado_atualizado', 'token_superado'],
  ];

  const mudaram = [];
  for (const [nome, atual, prop, esperadoAntes, esperadoDepois] of casos) {
    const r = antesEDepois(atual, prop);
    assert.equal(r.antes.motivo, esperadoAntes, `${nome}: antes`);
    assert.equal(r.depois.motivo, esperadoDepois, `${nome}: depois`);
    if (r.antes.aplicar !== r.depois.aplicar) mudaram.push(nome);
  }

  // O INVENTARIO FECHA AQUI: de quatorze cenarios, dois mudam de veredito, os
  // dois na direcao RESTRITIVA (passam a recusar), e os dois envolvem um token
  // que NAO e o do direito. Nenhum cenario passa de recusado para aceito — nao ha
  // como o backfill ressuscitar direito, e nao ha como ele conceder nada.
  assert.deepEqual(mudaram, [
    '4 evento de token diferente',
    '14 hash conflitante (ja terminal)',
  ]);
});

test('IMP-21 nenhum cenario sai de RECUSADO para ACEITO: o backfill so restringe', () => {
  // A varredura exaustiva do que muda de direcao. Se algum dia uma combinacao
  // passar a AFROUXAR, este teste quebra antes de a mudanca chegar em producao.
  const estados = [ESTADO.ATIVO, ESTADO.EXPIRADO, ESTADO.CANCELADO_VIGENTE,
    ESTADO.REVOGADO, ESTADO.REEMBOLSADO, ESTADO.EM_CARENCIA];
  const fontes = ['rtdn', 'reconciliacao', 'relogio', 'validacao'];
  const hashes = [HASH, OUTRO_HASH];
  const carimbos = [PASSADO, AGORA, DEPOIS];

  let afrouxou = 0;
  let restringiu = 0;
  for (const estadoAtual of estados) {
    for (const estadoProposto of estados) {
      for (const fonte of fontes) {
        for (const hash of hashes) {
          for (const verificadoEm of carimbos) {
            const atual = legado({
              estado: estadoAtual,
              vipAtivo: estadoAtual === ESTADO.ATIVO,
            });
            const prop = proposta({
              estado: estadoProposto,
              vipAtivo: estadoProposto === ESTADO.ATIVO,
              purchaseTokenHash: hash,
              fonte,
              verificadoEm,
            });
            const r = antesEDepois(atual, prop);
            if (!r.antes.aplicar && r.depois.aplicar) afrouxou += 1;
            if (r.antes.aplicar && !r.depois.aplicar) restringiu += 1;
          }
        }
      }
    }
  }

  assert.equal(afrouxou, 0, 'o backfill nunca faz uma recusa virar aceite');
  assert.ok(restringiu > 0, 'e ele de fato restringe onde deve');
});

// ===========================================================================
// FICHAS MENSAIS — a pergunta economica
// ===========================================================================

const CATALOGO = {
  vip_assinatura: {
    assinatura: true,
    planos: { mensal: { ativacao: 1500, mensal: 1000 } },
  },
};

/** Um assinante vigente, com plano e inicio conhecidos — so o hash em falta. */
function semearAssinante(db, uid, { hash = null, planoBase = 'mensal', inicioEm = PASSADO } = {}) {
  db.semear(`playerEntitlements/${uid}`, {
    uid,
    vipAtivo: true,
    estado: ESTADO.ATIVO,
    produtoId: 'vip_assinatura',
    planoBase,
    origem: 'play',
    inicioEm,
    expiraEm: FUTURO,
    esquema: 1,
  });
  db.semear(`playerEntitlements/${uid}/interno/billing`, {
    uid,
    purchaseTokenHash: hash,
    produtoId: 'vip_assinatura',
    assinatura: true,
    esquema: 1,
  });
  return db;
}

function rodarFichas(db, agora = AGORA) {
  const livro = criarLivroDeFichas({
    db,
    carimbo: () => CARIMBO,
    // O Firestore falso nao tem `FieldValue.increment`; o sentinel basta, porque
    // o que este teste mede e QUANTAS parcelas foram liquidadas, e nao a soma.
    incremento: (n) => ({ __incremento: n }),
  });
  return concederFichasDeTodosOsAssinantes({
    db,
    FieldPath: FieldPathFalso,
    colecaoEntitlement: 'playerEntitlements',
    catalogo: CATALOGO,
    agora,
    anteriorA,
    lerInterno: async (uid) => {
      const s = await db.doc(`playerEntitlements/${uid}/interno/billing`).get();
      return s.exists ? s.data() : null;
    },
    liquidarParcela: (p) => livro.liquidarParcela(p),
  });
}

test('IMP-30 ANTES do backfill: direito valido, sem hash, e nenhuma concessao mensal', async () => {
  const db = semearAssinante(new FirestoreFalso(), 'u1', { hash: null });
  const r = await rodarFichas(db);

  assert.equal(r.candidatos, 1);
  assert.equal(r.parcelas, 0);
  assert.equal(r.fichas, 0);
  // O jogador cai no ramo `semPlano` — que e onde o codigo poe quem nao tem hash.
  assert.equal(r.semPlano, 1);
  assert.equal(db.caminhos().some((c) => c.startsWith('fichasConcessoes/')), false);
});

test('IMP-31 DEPOIS do backfill: o mesmo entitlement passa a ter chave deterministica e recebe', async () => {
  const db = semearAssinante(new FirestoreFalso(), 'u1', { hash: HASH });
  const r = await rodarFichas(db);

  assert.equal(r.semPlano, 0);
  assert.ok(r.parcelas > 0, 'passou a liquidar parcela');
  // A chave e o hash HISTORICO, e nao algo derivado do uid.
  assert.ok(db.ver(`fichasConcessoes/${HASH}_0`), 'a parcela de ativacao foi anotada');
  assert.equal(db.ver(`fichasConcessoes/${HASH}_0`).uid, 'u1');
  assert.equal(db.ver(`fichasConcessoes/${HASH}_0`).purchaseTokenHash, HASH);
});

test('IMP-32 reexecutar nao duplica, e periodos diferentes geram concessoes distintas', async () => {
  const db = semearAssinante(new FirestoreFalso(), 'u1', {
    hash: HASH,
    inicioEm: '2026-06-15T00:00:00.000Z',
  });

  // 15/06 -> 15/08 sao dois mesversarios completos: indices 0, 1 e 2.
  const primeira = await rodarFichas(db, AGORA);
  assert.equal(primeira.parcelas, 3);

  const segunda = await rodarFichas(db, AGORA);
  assert.equal(segunda.parcelas, 0, 'o mesmo periodo nao paga de novo');

  const terceira = await rodarFichas(db, '2026-09-16T12:00:00.000Z');
  assert.equal(terceira.parcelas, 1, 'o mes seguinte e uma parcela nova');
  assert.ok(db.ver(`fichasConcessoes/${HASH}_3`));

  const linhas = db.caminhos().filter((c) => c.startsWith('fichasConcessoes/'));
  assert.equal(linhas.length, 4, 'uma linha por parcela, e so uma');
});

test('IMP-33 o backfill SOZINHO nao repara o direito MIGRADO: faltam `planoBase` e `inicioEm`', async () => {
  // ACHADO DESTA OS, e nao um teste de rotina. `migrarPaginaDeLegado` grava
  // `inicioEm: null` e nao grava `planoBase` — e as duas ausencias bloqueiam a
  // ficha mensal por caminhos DIFERENTES do hash:
  //
  //   planoBase ausente -> `planoDoCatalogo` devolve null -> ramo `semPlano`
  //   inicioEm  ausente -> `mesesDecorridos` devolve -1   -> nenhum indice devido
  //
  // Preencher o hash e necessario e NAO e suficiente. Quem for executar o
  // backfill precisa saber disso antes de prometer a ficha ao jogador migrado.
  const semPlanoBase = semearAssinante(new FirestoreFalso(), 'u1', {
    hash: HASH,
    planoBase: null,
  });
  const r1 = await rodarFichas(semPlanoBase);
  assert.equal(r1.parcelas, 0);
  assert.equal(r1.semPlano, 1);

  const semInicio = semearAssinante(new FirestoreFalso(), 'u2', {
    hash: HASH,
    inicioEm: null,
  });
  const r2 = await rodarFichas(semInicio);
  assert.equal(r2.parcelas, 0);
  assert.equal(r2.semPlano, 0, 'aqui nem `semPlano` acusa: a ausencia e silenciosa');

  // Com os tres campos no lugar, a mesma varredura paga.
  const completo = semearAssinante(new FirestoreFalso(), 'u3', { hash: HASH });
  assert.ok((await rodarFichas(completo)).parcelas > 0);
});

test('IMP-34 dois assinantes com hashes distintos nao compartilham livro-razao', async () => {
  const db = new FirestoreFalso();
  semearAssinante(db, 'u1', { hash: HASH });
  semearAssinante(db, 'u2', { hash: OUTRO_HASH });

  const r = await rodarFichas(db);
  assert.equal(r.jogadores, 2);
  assert.ok(db.ver(`fichasConcessoes/${HASH}_0`));
  assert.ok(db.ver(`fichasConcessoes/${OUTRO_HASH}_0`));
  assert.equal(db.ver(`fichasConcessoes/${HASH}_0`).uid, 'u1');
  assert.equal(db.ver(`fichasConcessoes/${OUTRO_HASH}_0`).uid, 'u2');
});
