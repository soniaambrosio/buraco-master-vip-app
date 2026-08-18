/**
 * conquista_idempotencia.test.js — a concessao acontece UMA vez, e so uma.
 *
 * Roda o CODIGO REAL (`lib/rastreabilidade.js`, compilado de src/) contra o
 * Firestore do EMULADOR, dentro de transacoes de verdade. Nao ha Firestore
 * falso aqui de proposito: o que se prova nesta suite — colisao de `create`,
 * reexecucao de transacao sob contencao, convergencia de chamadas simultaneas —
 * e exatamente o comportamento que um duble nao reproduz.
 *
 * Nao sobe o emulador de Functions: `planejarPrimeiraBatidaReal` e
 * `aplicarPlanoDeConquista` sao chamadas diretamente, dentro de
 * `db.runTransaction`, que e como `registrarEncerramentoPartida` as chama. O que
 * fica de fora e so o invólucro `onCall` (autenticacao e claim), coberto pelas
 * Rules e pela checagem `exigirAutoridadeDePartida`.
 *
 * As duas moram em `src/conquistas.ts`, e nao em `src/rastreabilidade.ts`,
 * porque `index.ts` reexporta este ultimo e o Firebase trata cada export do
 * entrypoint como funcao a implantar.
 *
 * Uso (a partir de functions/):
 *   npm run build:domain && npm run build
 *   npm run emulador:conquistas
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'bmv-conquistas-teste';

initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const {
  planejarPrimeiraBatidaReal,
  aplicarPlanoDeConquista,
} = require('../lib/conquistas.js');

const db = getFirestore();

const CONQUISTA = 'primeira_batida_real';

/// Registro elegivel, no formato de `RegistroDePartida.toJson()`.
function registroElegivel(uid, matchId, assento = 0) {
  return {
    matchId,
    estado: 'finalizada',
    tipo: 'publica_ranqueada',
    motivoEncerramento: 'meta_atingida',
    ladoVencedor: 'nos',
    assentoQueBateuFinal: assento,
    identidade: { origem: 'servidor', tipo: 'publica_ranqueada' },
    placar: [
      { lado: 'nos', assentos: [0, 2] },
      { lado: 'eles', assentos: [1, 3] },
    ],
    participantes: [
      { classe: 'humano', userId: uid, assento },
      { classe: 'humano', userId: `${uid}-parceiro`, assento: assento + 2 },
    ],
  };
}

/// Uma passada do encerramento, como a Function a executa.
function processar(registro, matchId) {
  return db.runTransaction(async (tx) => {
    const plano = await planejarPrimeiraBatidaReal(tx, registro, matchId);
    aplicarPlanoDeConquista(tx, plano);
    return plano.resultado;
  });
}

const itens = (uid) =>
  db.collection('playerAchievements').doc(uid).collection('items');

async function contar(uid) {
  const snap = await itens(uid).get();
  return snap.size;
}

async function limpar(uid) {
  const snap = await itens(uid).get();
  await Promise.all(snap.docs.map((d) => d.ref.delete()));
}

test('1. primeira vez concede exatamente um documento', async () => {
  const uid = 'uid-primeira-vez';
  await limpar(uid);

  assert.equal(await processar(registroElegivel(uid, 'match-1'), 'match-1'), 'concedida');
  assert.equal(await contar(uid), 1);

  const doc = await itens(uid).doc(CONQUISTA).get();
  assert.equal(doc.data().id, CONQUISTA);
  assert.equal(doc.data().partidaId, 'match-1');
  assert.equal(doc.data().origem, 'encerramento_autoritativo_v1');
  assert.equal(doc.data().versaoContrato, 1);
  assert.equal(doc.data().assento, 0);
  // Carimbo do servidor, e nao data enviada por quem chamou.
  assert.ok(doc.data().obtidaEm, 'obtidaEm precisa existir');
  assert.ok(typeof doc.data().obtidaEm.toDate === 'function');
});

test('2. o MESMO encerramento processado duas vezes nao duplica', async () => {
  const uid = 'uid-mesmo-evento';
  await limpar(uid);
  const registro = registroElegivel(uid, 'match-2');

  assert.equal(await processar(registro, 'match-2'), 'concedida');
  assert.equal(await processar(registro, 'match-2'), 'ja_existente');
  assert.equal(await contar(uid), 1);
});

test('3. retry apos sucesso nao reescreve a data da primeira vez', async () => {
  const uid = 'uid-retry';
  await limpar(uid);
  const registro = registroElegivel(uid, 'match-3');

  await processar(registro, 'match-3');
  const primeira = (await itens(uid).doc(CONQUISTA).get()).data().obtidaEm;

  // Espera o relogio andar, para que uma reescrita fosse detectavel.
  await new Promise((r) => setTimeout(r, 50));
  assert.equal(await processar(registro, 'match-3'), 'ja_existente');

  const depois = (await itens(uid).doc(CONQUISTA).get()).data().obtidaEm;
  assert.equal(
    depois.toMillis(),
    primeira.toMillis(),
    'obtidaEm foi reescrita — a conquista deixaria de ser o marco daquele dia',
  );
});

test('4. chamadas CONCORRENTES resultam em um registro so', async () => {
  const uid = 'uid-concorrente';
  await limpar(uid);
  const registro = registroElegivel(uid, 'match-4');

  // Oito transacoes disparadas juntas, sobre o mesmo documento inexistente.
  // Sem o `create` dentro da transacao, varias passariam pela leitura ao mesmo
  // tempo e escreveriam por cima umas das outras.
  const resultados = await Promise.all(
    Array.from({ length: 8 }, () => processar(registro, 'match-4')),
  );

  assert.equal(await contar(uid), 1);
  assert.equal(
    resultados.filter((r) => r === 'concedida').length,
    1,
    `esperava exatamente uma concessao, veio ${JSON.stringify(resultados)}`,
  );
});

test('5. partidas POSTERIORES com novas batidas nao concedem de novo', async () => {
  const uid = 'uid-varias-vitorias';
  await limpar(uid);

  assert.equal(await processar(registroElegivel(uid, 'match-5a'), 'match-5a'), 'concedida');
  assert.equal(await processar(registroElegivel(uid, 'match-5b'), 'match-5b'), 'ja_existente');
  assert.equal(await processar(registroElegivel(uid, 'match-5c'), 'match-5c'), 'ja_existente');

  assert.equal(await contar(uid), 1);
  // E o marco continua apontando para a PRIMEIRA partida.
  const doc = await itens(uid).doc(CONQUISTA).get();
  assert.equal(doc.data().partidaId, 'match-5a');
});

test('6. quem ja possuia a conquista antes nao ganha duplicata', async () => {
  const uid = 'uid-ja-tinha';
  await limpar(uid);
  await itens(uid).doc(CONQUISTA).set({
    id: CONQUISTA,
    obtidaEm: new Date('2026-01-01T00:00:00.000Z'),
    partidaId: 'match-antiga',
    origem: 'encerramento_autoritativo_v1',
    versaoContrato: 1,
    assento: 2,
  });

  assert.equal(await processar(registroElegivel(uid, 'match-6'), 'match-6'), 'ja_existente');
  assert.equal(await contar(uid), 1);
  assert.equal((await itens(uid).doc(CONQUISTA).get()).data().partidaId, 'match-antiga');
});

test('7. encerramento inelegivel nao cria documento nenhum', async () => {
  const uid = 'uid-inelegivel';
  await limpar(uid);

  const derrota = registroElegivel(uid, 'match-7');
  derrota.ladoVencedor = 'eles'; // bateu, mas o lado dele perdeu

  assert.equal(await processar(derrota, 'match-7'), 'inelegivel');
  assert.equal(await contar(uid), 0);
});

test('8. envelope sem o assento nao concede — fail-closed ate o banco', async () => {
  const uid = 'uid-sem-assento';
  await limpar(uid);

  const antigo = registroElegivel(uid, 'match-8');
  delete antigo.assentoQueBateuFinal;

  assert.equal(await processar(antigo, 'match-8'), 'inelegivel');
  assert.equal(await contar(uid), 0);
});

test('9. envelope ilegivel nao derruba o encerramento nem grava', async () => {
  const uid = 'uid-ilegivel';
  await limpar(uid);

  // Sem `identidade`: o dominio recusa ler. A transacao precisa sobreviver —
  // perder o registro da partida por causa da conquista seria trocar o dado
  // importante pelo acessorio.
  const resultado = await processar({ estado: 'finalizada' }, 'match-9');
  assert.equal(resultado, 'inelegivel');
  assert.equal(await contar(uid), 0);
});

test('10. o parceiro do executor nao recebe nada', async () => {
  const uid = 'uid-executor';
  await limpar(uid);
  await limpar(`${uid}-parceiro`);

  await processar(registroElegivel(uid, 'match-10'), 'match-10');

  assert.equal(await contar(uid), 1);
  assert.equal(await contar(`${uid}-parceiro`), 0);
});
