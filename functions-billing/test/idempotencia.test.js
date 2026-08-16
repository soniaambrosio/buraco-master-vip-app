/**
 * Testes da idempotência da validação de compra.
 *
 * `node --test`, sem dependências e sem emulador — a lógica de decisão é pura
 * de propósito justamente para permitir isto.
 *
 * O caso que mais importa está em "concorrência": duas execuções do MESMO token
 * disputando a transação de concessão. É o cenário real de reentrega da Play
 * Store, e é onde um crédito duplicado custaria dinheiro.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  ESTADO,
  ACAO,
  conferirTitularidade,
  decidirSobreRegistroExistente,
  podeConceder,
} = require('../idempotencia');

const CTX = { uid: 'jogador-1', produtoId: 'master_vip', assinatura: true };

function registro(extra = {}) {
  return {
    uid: 'jogador-1',
    produtoId: 'master_vip',
    assinatura: true,
    estado: ESTADO.EM_VALIDACAO,
    ...extra,
  };
}

test('titularidade: registro correspondente é aceito', () => {
  assert.deepStrictEqual(conferirTitularidade(registro(), CTX), { ok: true });
});

test('titularidade: token de outro jogador é recusado', () => {
  const r = conferirTitularidade(registro({ uid: 'jogador-2' }), CTX);
  assert.strictEqual(r.ok, false);
  assert.match(r.motivo, /outro jogador/);
});

test('titularidade: token registrado para outro produto é recusado', () => {
  const r = conferirTitularidade(registro({ produtoId: 'outro_produto' }), CTX);
  assert.strictEqual(r.ok, false);
  assert.match(r.motivo, /outro produto/);
});

test('titularidade: token registrado com outro tipo de compra é recusado', () => {
  const r = conferirTitularidade(registro({ assinatura: false }), CTX);
  assert.strictEqual(r.ok, false);
  assert.match(r.motivo, /outro tipo/);
});

test('titularidade: tipo é comparado por valor booleano, não por identidade', () => {
  // O Firestore pode devolver o campo ausente (undefined) num documento antigo.
  const r = conferirTitularidade(
    registro({ assinatura: undefined }),
    { ...CTX, assinatura: false }
  );
  assert.strictEqual(r.ok, true);
});

test('reentrega de compra já concedida devolve a concessão, sem reprocessar', () => {
  const d = decidirSobreRegistroExistente(
    registro({ estado: ESTADO.CONCEDIDA, concessao: { fichasCreditadas: 1000 } }),
    CTX
  );
  assert.strictEqual(d.acao, ACAO.JA_CONCEDIDA);
  assert.deepStrictEqual(d.concessao, { fichasCreditadas: 1000 });
});

test('token já recusado não é readmitido', () => {
  const d = decidirSobreRegistroExistente(
    registro({ estado: ESTADO.RECUSADA, motivo: 'purchaseState 1' }),
    CTX
  );
  assert.strictEqual(d.acao, ACAO.JA_RECUSADA);
  assert.strictEqual(d.motivo, 'purchaseState 1');
});

test('registro preso em em_validacao é revalidado', () => {
  const d = decidirSobreRegistroExistente(registro(), CTX);
  assert.strictEqual(d.acao, ACAO.PROSSEGUIR);
});

test('titularidade é conferida ANTES do estado', () => {
  // Um token de outro jogador que por acaso esteja `concedida` não pode
  // devolver a concessão alheia — precisa dar conflito.
  const d = decidirSobreRegistroExistente(
    registro({ uid: 'jogador-2', estado: ESTADO.CONCEDIDA, concessao: { vip: true } }),
    CTX
  );
  assert.strictEqual(d.acao, ACAO.CONFLITO);
  assert.strictEqual(d.concessao, undefined);
});

test('podeConceder: documento ausente ou em validação libera; concedida bloqueia', () => {
  assert.strictEqual(podeConceder(null), true);
  assert.strictEqual(podeConceder(registro()), true);
  assert.strictEqual(podeConceder(registro({ estado: ESTADO.RECUSADA })), true);
  assert.strictEqual(podeConceder(registro({ estado: ESTADO.CONCEDIDA })), false);
});

/**
 * Simula a transação de concessão do index.js: relê o documento, consulta
 * `podeConceder` e, se liberar, credita e marca `concedida` na MESMA escrita.
 *
 * O Firestore serializa transações concorrentes sobre o mesmo documento e faz a
 * perdedora repetir a leitura. Este fake reproduz essa serialização para provar
 * que o guardião funciona.
 */
function criarBancoFake() {
  const estado = { doc: null, saldoFichas: 0, creditos: 0 };
  return {
    estado,
    // Uma "transação": lê o estado atual e aplica a decisão atomicamente.
    conceder(fichas) {
      const registroAtual = estado.doc;
      if (!podeConceder(registroAtual)) {
        return { jaConcedida: true, concessao: registroAtual.concessao };
      }
      const concessao = { fichasCreditadas: fichas };
      estado.saldoFichas += fichas;
      estado.creditos += 1;
      estado.doc = { ...(registroAtual || registro()), estado: ESTADO.CONCEDIDA, concessao };
      return { concedidaAgora: true, concessao };
    },
  };
}

test('concorrência: duas entregas do mesmo token creditam UMA vez', () => {
  const banco = criarBancoFake();
  banco.estado.doc = registro({ assinatura: false, produtoId: 'pacote_fichas' });

  const primeira = banco.conceder(1000);
  const segunda = banco.conceder(1000);

  assert.strictEqual(primeira.concedidaAgora, true);
  assert.strictEqual(segunda.jaConcedida, true);
  assert.strictEqual(banco.estado.creditos, 1, 'creditou mais de uma vez');
  assert.strictEqual(banco.estado.saldoFichas, 1000, 'saldo duplicado');
  assert.deepStrictEqual(segunda.concessao, { fichasCreditadas: 1000 });
});

test('concorrência: reentregas repetidas não acumulam saldo', () => {
  const banco = criarBancoFake();
  banco.estado.doc = registro({ assinatura: false, produtoId: 'pacote_fichas' });

  for (let i = 0; i < 10; i++) banco.conceder(500);

  assert.strictEqual(banco.estado.creditos, 1);
  assert.strictEqual(banco.estado.saldoFichas, 500);
});

test('concorrência: documento inexistente ainda credita uma vez só', () => {
  const banco = criarBancoFake();
  banco.estado.doc = null;

  banco.conceder(250);
  banco.conceder(250);

  assert.strictEqual(banco.estado.creditos, 1);
  assert.strictEqual(banco.estado.saldoFichas, 250);
});
