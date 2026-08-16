// conquistas.test.js — prova o bloco `playerAchievements` do firestore.rules
// contra o emulador.
//
// A divisao e a mesma do resto do projeto:
//
//   dominio  -> QUEM merece a conquista (app/test/conquistas/, em Dart)
//   rules    -> QUEM o banco deixa ler e escrever (este arquivo)
//
// Cobre, um caso por afirmacao da OS secao 13 "Seguranca":
//   - o titular autenticado le a propria conquista;
//   - o cliente NAO cria conquista;
//   - o cliente NAO edita conquista (inclusive a data de obtencao);
//   - o cliente NAO apaga conquista;
//   - outro UID NAO le a conquista alheia, nem por get nem por list;
//   - o anonimo nao le nada;
//   - o backend autorizado (Admin SDK) concede.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador:conquistas

'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
} = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

/// Porta do emulador. As suites anteriores fixam 8080; aqui ela e configuravel
/// para que uma segunda sessao possa rodar em paralelo sem disputar a porta —
/// `FIRESTORE_EMULATOR_HOST` e a mesma variavel que o proprio `emulators:exec`
/// exporta. O padrao continua sendo 8080, entao nada muda para quem so roda
/// `npm run emulador:conquistas`.
const PORTA = Number(
  (process.env.FIRESTORE_EMULATOR_HOST || '').split(':')[1] || 8080,
);

const DONO = 'uid_dono';
const ALHEIO = 'uid_alheio';
const ADMIN = 'uid_admin';
const CONQUISTA = 'primeira_batida_real';
const MATCH = 'match-f1-mesa-1';

let ambiente;

/// O documento como `registrarEncerramentoPartida` o grava.
const CONCESSAO = {
  id: CONQUISTA,
  obtidaEm: new Date('2026-08-11T16:00:00.000Z'),
  partidaId: MATCH,
  origem: 'encerramento_autoritativo_v1',
  versaoContrato: 1,
  assento: 0,
};

const caminho = (uid) => ['playerAchievements', uid, 'items', CONQUISTA];

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
      host: '127.0.0.1',
      port: PORTA,
    },
  });

  // `withSecurityRulesDisabled` e o equivalente do Admin SDK aqui — e assim que
  // a Cloud Function popula esta colecao em producao.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, ...caminho(DONO)), CONCESSAO);
    await setDoc(doc(db, ...caminho(ALHEIO)), { ...CONCESSAO, assento: 1 });
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoAlheio = () => ambiente.authenticatedContext(ALHEIO).firestore();
const comoAdmin = () =>
  ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

describe('playerAchievements — leitura', () => {
  test('o titular autenticado le a PROPRIA conquista', async () => {
    const snap = await assertSucceeds(getDoc(doc(comoDono(), ...caminho(DONO))));
    assert.equal(snap.exists(), true);
    assert.equal(snap.data().id, CONQUISTA);
    assert.equal(snap.data().origem, 'encerramento_autoritativo_v1');
  });

  test('o titular lista as proprias conquistas', async () => {
    const snap = await assertSucceeds(
      getDocs(collection(comoDono(), 'playerAchievements', DONO, 'items')),
    );
    assert.equal(snap.size, 1);
  });

  test('outro UID NAO le a conquista alheia', async () => {
    await assertFails(getDoc(doc(comoAlheio(), ...caminho(DONO))));
  });

  test('outro UID NAO varre a colecao alheia', async () => {
    await assertFails(
      getDocs(collection(comoAlheio(), 'playerAchievements', DONO, 'items')),
    );
  });

  test('o anonimo nao le conquista nenhuma', async () => {
    await assertFails(getDoc(doc(semLogin(), ...caminho(DONO))));
    await assertFails(
      getDocs(collection(semLogin(), 'playerAchievements', DONO, 'items')),
    );
  });

  test('o admin le para dar suporte', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), ...caminho(DONO))));
  });
});

describe('playerAchievements — escrita fechada para o cliente', () => {
  test('o jogador NAO cria a propria conquista', async () => {
    await assertFails(
      setDoc(
        doc(comoDono(), 'playerAchievements', DONO, 'items', 'conquista_forjada'),
        CONCESSAO,
      ),
    );
  });

  test('o jogador NAO se autoconcede a primeira_batida_real', async () => {
    // O caso que interessa: o documento ja existe para o DONO, entao esta
    // tentativa e um `update` disfarcado de `set`. As duas portas sao negadas.
    await assertFails(setDoc(doc(comoDono(), ...caminho(DONO)), CONCESSAO));
  });

  test('o jogador NAO antedata a propria conquista', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), ...caminho(DONO)), {
        obtidaEm: new Date('2020-01-01T00:00:00.000Z'),
      }),
    );
  });

  test('o jogador NAO troca a partida de origem nem o assento', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), ...caminho(DONO)), { partidaId: 'match-outra' }),
    );
    await assertFails(
      updateDoc(doc(comoDono(), ...caminho(DONO)), { assento: 3 }),
    );
  });

  test('o jogador NAO apaga a conquista para ganhar de novo', async () => {
    // Apagar seria a forma de burlar o id fixo: sem documento, a proxima
    // vitoria criaria um segundo `obtidaEm`.
    await assertFails(deleteDoc(doc(comoDono(), ...caminho(DONO))));
  });

  test('o jogador NAO escreve na conquista alheia', async () => {
    await assertFails(setDoc(doc(comoDono(), ...caminho(ALHEIO)), CONCESSAO));
    await assertFails(deleteDoc(doc(comoDono(), ...caminho(ALHEIO))));
  });

  test('nem o admin escreve pelo cliente', async () => {
    // Concessao manual, se um dia existir, e Cloud Function auditavel — nao
    // uma escrita direta que nao deixa rastro.
    await assertFails(setDoc(doc(comoAdmin(), ...caminho(DONO)), CONCESSAO));
    await assertFails(deleteDoc(doc(comoAdmin(), ...caminho(DONO))));
  });

  test('o documento-pai tambem nao e espaco de escrita livre', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'playerAchievements', DONO), { qualquer: 1 }),
    );
  });
});

describe('playerAchievements — o backend concede', () => {
  test('o Admin SDK grava, e o titular passa a ler', async () => {
    const novo = 'uid_recem_premiado';
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), ...caminho(novo)), CONCESSAO);
    });
    const db = ambiente.authenticatedContext(novo).firestore();
    const snap = await assertSucceeds(getDoc(doc(db, ...caminho(novo))));
    assert.equal(snap.data().versaoContrato, 1);
  });
});
