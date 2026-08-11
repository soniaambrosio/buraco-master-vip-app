/**
 * costura_p0_runtime.js — a costura P0 provada DENTRO DE UM RUNTIME SO.
 *
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * `app/test/elegibilidade/costura_p0_test.dart` prova a costura do lado da
 * MODERACAO com o produtor de verdade (`avaliarSancao` + `consolidar`), mas do
 * lado do BILLING ele usa LITERAIS — porque o produtor do entitlement e
 * JavaScript e nao roda dentro de um teste Dart. A correcao declarou isso
 * abertamente: e um contrato espelhado, com estopim nos dois lados, e nao uma
 * prova automatica unica.
 *
 * Este harness fecha exatamente esse vao. Aqui os dois lados rodam juntos:
 *
 *   functions-billing/entitlement.js          <- o produtor REAL (JS)
 *     consolidarAssinatura / consolidarTerminal
 *     documentosDeEntitlement
 *              |
 *              v  documento playerEntitlements/{uid}, campo por campo
 *              |
 *   functions/lib/domain_bundle.js            <- o consumidor REAL (Dart -> JS)
 *     comporElegibilidade  ->  inscrever
 *              |
 *              v
 *        aceita / recusa
 *
 * O template do torneio vem do SEED APROVADO (`tournamentTemplates.seed.json`),
 * e nao de um objeto montado para o teste: e o mesmo torneio VIP que vai abrir
 * inscricao. Nenhuma flag e construida a mao — `assinaturaAtiva` e `suspenso`
 * nascem dos documentos.
 *
 * O QUE ELE NAO E: nao fala com a Google, nao sobe emulador e nao substitui as
 * suites. As respostas da Play Developer API entram como literais no formato
 * documentado de `purchases.subscriptionsv2`.
 *
 * PRE-REQUISITO: o bundle e artefato gerado (`.gitignore` cobre `functions/lib/`).
 * Rode antes:  npm run build:domain
 *
 * Uso:  npm run test:costura      (a partir de functions/)
 */
'use strict';

const path = require('path');
const fs = require('fs');
const assert = require('node:assert');

const RAIZ = path.resolve(__dirname, '..', '..');
const BUNDLE = path.join(RAIZ, 'functions', 'lib', 'domain_bundle.js');

if (!fs.existsSync(BUNDLE)) {
  console.error(
    `bundle ausente: ${BUNDLE}\n` +
      'Ele e artefato gerado. Rode `npm run build:domain` antes deste harness.'
  );
  process.exit(2);
}

const {
  ESTADO,
  consolidarAssinatura,
  consolidarTerminal,
  documentosDeEntitlement,
} = require(path.join(RAIZ, 'functions-billing', 'entitlement.js'));

require(BUNDLE);
const ponte = globalThis.bmvTorneios;
assert.ok(ponte, 'o bundle nao exportou bmvTorneios');
assert.strictEqual(typeof ponte.comporElegibilidade, 'function');
assert.strictEqual(typeof ponte.inscrever, 'function');

// ---------------------------------------------------------------------------
// Instantes. Os mesmos do teste Dart, de proposito: os dois lados descrevem o
// mesmo cenario, e uma divergencia de fuso apareceria aqui.
// ---------------------------------------------------------------------------

const UID = 'jogadora-ana';
const PRODUTO = 'master_vip_mensal';
const AGORA = '2026-08-11T20:00:00.000Z';
const INICIO = '2026-08-06T20:00:00.000Z';
const FUTURO = '2026-08-31T20:00:00.000Z';
const PASSADO = '2026-08-06T20:00:00.000Z';
const HASH = 'c'.repeat(64);

// ---------------------------------------------------------------------------
// Produtor real do lado do Billing
// ---------------------------------------------------------------------------

function respostaPlay(estado, expiry, autoRenew) {
  return {
    subscriptionState: estado,
    startTime: INICIO,
    lineItems: [
      {
        productId: PRODUTO,
        expiryTime: expiry,
        autoRenewingPlan: { autoRenewEnabled: autoRenew },
      },
    ],
  };
}

function docAssinatura(estadoPlay, expiry, autoRenew) {
  const consolidado = consolidarAssinatura(respostaPlay(estadoPlay, expiry, autoRenew), AGORA);
  return documentosDeEntitlement(null, {
    uid: UID,
    ...consolidado,
    origem: 'play',
    purchaseTokenHash: HASH,
    purchaseToken: 'token-cru',
    verificadoEm: AGORA,
    fonte: 'validacao',
  }).publico;
}

function docTerminal(terminal) {
  return documentosDeEntitlement(
    { purchaseTokenHash: HASH, produtoId: PRODUTO, purchaseToken: 'token-cru' },
    {
      uid: UID,
      ...consolidarTerminal(terminal, AGORA),
      origem: 'play',
      purchaseTokenHash: HASH,
      purchaseToken: 'token-cru',
      verificadoEm: AGORA,
      fonte: 'rtdn',
    }
  ).publico;
}

/// Documento que o Billing NAO grava: escrita parcial / adulteracao simulada.
/// Serve para provar que estado terminal recusa sozinho, sem depender do prazo.
function docIncoerente(terminal) {
  return { ...docTerminal(terminal), vipAtivo: true, expiraEm: FUTURO };
}

// ---------------------------------------------------------------------------
// Consumidor real: template do seed aprovado
// ---------------------------------------------------------------------------

const seed = require(path.join(RAIZ, 'app', 'data', 'torneios', 'tournamentTemplates.seed.json'));
const acessoDe = (t) => (t.acesso && t.acesso.tipo ? t.acesso.tipo : t.acesso);
const VIPS = seed.templates.filter((t) => acessoDe(t) === 'vip');
const PUBLICO = seed.templates.find((t) => acessoDe(t) === 'publico');
assert.ok(VIPS.length > 0, 'o seed aprovado nao tem torneio VIP');
const TEMPLATE_VIP = VIPS[0];

function edicao(templateId) {
  return {
    tournamentId: templateId,
    editionId: 'ed-2026-08-14',
    numeroEdicao: 7,
    temporada: '2026',
    status: 'inscricoes_abertas',
    inicioPrevisto: '2026-08-12T00:00:00.000Z',
    inscricoesAbremEm: '2026-08-07T00:00:00.000Z',
    inscricoesFechamEm: '2026-08-11T23:30:00.000Z',
    modalidade: 'aberto',
    numeroFases: 2,
    formato: 'misto',
    metaPontos: 1500,
    regraVersao: 1,
    criadoEm: '2026-07-12T00:00:00.000Z',
    atualizadoEm: AGORA,
  };
}

/// A travessia inteira. Nao existe atalho para "montar um perfil": todo caso
/// passa por `comporElegibilidade`, senao volta a ser o teste que a homologacao
/// P0 reprovou.
function comporEInscrever(entitlement, moderacao, template) {
  const perfil = JSON.parse(
    ponte.comporElegibilidade(
      JSON.stringify({
        userId: UID,
        agora: AGORA,
        moderacao: moderacao || null,
        entitlement: entitlement || null,
      })
    )
  );
  assert.ok(!perfil.erro, `comporElegibilidade falhou: ${perfil.erro}`);

  const t = template || TEMPLATE_VIP;
  const resultado = JSON.parse(
    ponte.inscrever(
      JSON.stringify({
        edicao: edicao(t.templateId),
        template: t,
        perfil,
        vagas: { limite: (t.vagas && t.vagas.max) || 16, listaEspera: false, custoEntrada: 0 },
        agora: AGORA,
        saldoFichas: 0,
        inscricoes: [],
      })
    )
  );
  assert.ok(!resultado.erro, `inscrever falhou: ${resultado.erro}`);
  return { perfil, resultado };
}

// ---------------------------------------------------------------------------
// Documentos de moderacao, no formato que `consolidarSancoes` grava.
// O produtor de verdade e Dart e ja e exercitado em costura_p0_test.dart
// (A-01..A-06); aqui eles entram para provar que a COMPOSICAO le os dois lados.
// ---------------------------------------------------------------------------

const modBase = {
  userId: UID,
  suspensoAte: null,
  suspensaoPermanente: false,
  chatSilenciadoAte: null,
  sancoesVigentes: ['sancao-1'],
  atualizadoEm: AGORA,
};
const MOD_SUSPENSO = { ...modBase, suspensoAte: '2026-08-14T20:00:00.000Z' };
const MOD_VENCIDA = { ...modBase, suspensoAte: '2026-08-10T20:00:00.000Z' };
const MOD_BANIDO = { ...modBase, suspensaoPermanente: true };
const MOD_MUTE = { ...modBase, chatSilenciadoAte: '2026-08-14T20:00:00.000Z' };

// ---------------------------------------------------------------------------
// Casos
// ---------------------------------------------------------------------------

const CASOS = [
  // [rotulo, entitlement, moderacao, template, aceita?]
  ['A  suspenso, com VIP em dia', docAssinatura('SUBSCRIPTION_STATE_ACTIVE', FUTURO, true), MOD_SUSPENSO, null, false],
  ['A2 banido (permanente)', docAssinatura('SUBSCRIPTION_STATE_ACTIVE', FUTURO, true), MOD_BANIDO, null, false],
  ['A3 suspensao ja vencida', docAssinatura('SUBSCRIPTION_STATE_ACTIVE', FUTURO, true), MOD_VENCIDA, null, true],
  ['A5 so silencio de chat', docAssinatura('SUBSCRIPTION_STATE_ACTIVE', FUTURO, true), MOD_MUTE, null, true],
  ['B  VIP valido', docAssinatura('SUBSCRIPTION_STATE_ACTIVE', FUTURO, true), null, null, true],
  ['C  sem entitlement', null, null, null, false],
  ['D  VIP expirado, vipAtivo ainda gravado', { ...docAssinatura('SUBSCRIPTION_STATE_ACTIVE', FUTURO, true), expiraEm: PASSADO }, null, null, false],
  ['D2 expirado apos a varredura', docAssinatura('SUBSCRIPTION_STATE_EXPIRED', PASSADO, false), null, null, false],
  ['E  VIP revogado', docTerminal(ESTADO.REVOGADO), null, null, false],
  ['E2 revogado com prazo futuro', docIncoerente(ESTADO.REVOGADO), null, null, false],
  ['F  VIP reembolsado', docTerminal(ESTADO.REEMBOLSADO), null, null, false],
  ['F2 reembolsado com prazo futuro', docIncoerente(ESTADO.REEMBOLSADO), null, null, false],
  ['G  cancelado, periodo ainda pago', docAssinatura('SUBSCRIPTION_STATE_CANCELED', FUTURO, false), null, null, true],
  ['G2 cancelado, periodo vencido', docAssinatura('SUBSCRIPTION_STATE_CANCELED', PASSADO, false), null, null, false],
  ['H1 carencia', docAssinatura('SUBSCRIPTION_STATE_IN_GRACE_PERIOD', FUTURO, true), null, null, true],
  ['H2 conta em espera', docAssinatura('SUBSCRIPTION_STATE_ON_HOLD', FUTURO, true), null, null, false],
  ['H3 pausado', docAssinatura('SUBSCRIPTION_STATE_PAUSED', FUTURO, true), null, null, false],
  ['H4 pendente, nao pago', docAssinatura('SUBSCRIPTION_STATE_PENDING', FUTURO, true), null, null, false],
  ['I  torneio publico sem VIP', null, null, PUBLICO, true],
];

let falhas = 0;
console.log(`torneio VIP do seed: ${TEMPLATE_VIP.templateId}   (VIPs no seed aprovado: ${VIPS.length})`);
console.log('');
console.log('caso                                    | estado gravado    | vipAtivo | suspenso | assinaturaAtiva | inscricao');
console.log('----------------------------------------|-------------------|----------|----------|-----------------|-----------');

for (const [rotulo, ent, mod, tpl, esperado] of CASOS) {
  const { perfil, resultado } = comporEInscrever(ent, mod, tpl);
  const ok = resultado.aceita === esperado;
  if (!ok) falhas += 1;
  console.log(
    `${rotulo.padEnd(39)} | ${String(ent ? ent.estado : '(ausente)').padEnd(17)} | ` +
      `${String(ent ? ent.vipAtivo : false).padEnd(8)} | ${String(perfil.suspenso).padEnd(8)} | ` +
      `${String(perfil.assinaturaAtiva).padEnd(15)} | ` +
      `${resultado.aceita ? 'ACEITA' : 'recusa:' + resultado.recusa}${ok ? '' : '   <<< DIVERGENTE'}`
  );
}

console.log('');
if (falhas > 0) {
  console.error(`${falhas} caso(s) divergente(s) — a costura P0 NAO confere.`);
  process.exit(1);
}
console.log(`${CASOS.length} casos, 0 divergencias — a costura P0 confere ponta a ponta.`);
