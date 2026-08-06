// seguranca.test.js — prova as regras e a idempotencia contra os emuladores.
//
// NAO FOI EXECUTADO NESTA ENTREGA: exige os emuladores do Firebase de pe e um
// `npm install` nesta pasta. Esta versionado para que a verificacao seja um
// comando, e nao uma inspecao no olho. Ver firebase/testes/README.md.
//
// Cobre, um caso por afirmacao da secao de seguranca:
//   - o cliente NAO cria, apaga nem altera item de inventario, exceto `equipped`;
//   - `equipped` so muda sozinho: junto de outro campo, e recusado;
//   - ninguem le o inventario de terceiros;
//   - ninguem se marca elegivel, nem varre a lista de elegiveis;
//   - catalogo e campanha sao somente leitura para o aplicativo;
//   - `claimPioneerKit` exige autenticacao e ignora UID vindo no payload;
//   - chamadas repetidas e SIMULTANEAS continuam entregando dez itens.
//
// Uso:
//   cd firebase/testes && npm install
//   firebase emulators:exec --only firestore,functions,auth "npm test"

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

const PROJETO = 'buraco-master-vip-testes';
const CAMPANHA = 'pioneiros_2026';
const DONO = 'uid_dono';
const ALHEIO = 'uid_alheio';

const ITENS = [
  'pioneer_2026_crown', 'pioneer_2026_chest', 'pioneer_2026_mascot_bulldog',
  'pioneer_2026_mascot_owl', 'pioneer_2026_emblem', 'pioneer_2026_throne',
  'pioneer_2026_medallion', 'pioneer_2026_mascot_dragon', 'pioneer_2026_vortex',
  'pioneer_2026_statue',
];

let ambiente;

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // Semeia com as regras DESLIGADAS, imitando o que so o backend pode gravar.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `campaigns/${CAMPANHA}`), {
      campaignId: CAMPANHA, version: 1, status: 'active',
      featureFlag: 'kitPioneiros2026Enabled', rewardIds: ITENS,
    });
    await setDoc(doc(db, `campaigns/${CAMPANHA}/eligible/${DONO}`), { naAllowlist: true });
    await setDoc(doc(db, 'config/featureFlags'), { kitPioneiros2026Enabled: true });
    await setDoc(doc(db, `users/${DONO}/inventory/pioneer_2026_crown`), {
      userId: DONO, itemId: 'pioneer_2026_crown', collectionId: CAMPANHA,
      source: 'campanha', campaignId: CAMPANHA, campaignVersion: 1,
      unlockedAt: new Date(), equipped: false,
    });
  });
});

after(async () => {
  await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoAlheio = () => ambiente.authenticatedContext(ALHEIO).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

describe('inventario: o cliente nao concede itens', () => {
  test('nao cria item no proprio inventario', async () => {
    await assertFails(
      setDoc(doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_statue`), {
        userId: DONO, itemId: 'pioneer_2026_statue', collectionId: CAMPANHA,
        source: 'campanha', campaignId: CAMPANHA, campaignVersion: 1,
        unlockedAt: new Date(), equipped: false,
      }),
    );
  });

  test('nao apaga item do proprio inventario', async () => {
    await assertFails(deleteDoc(doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_crown`)));
  });

  test('nao altera source, campaignId nem unlockedAt', async () => {
    const ref = doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_crown`);
    await assertFails(updateDoc(ref, { source: 'administrativa' }));
    await assertFails(updateDoc(ref, { campaignId: 'outra_campanha' }));
    await assertFails(updateDoc(ref, { unlockedAt: new Date(0) }));
    await assertFails(updateDoc(ref, { campaignVersion: 99 }));
  });

  test('altera SO `equipped` — e so ele sozinho', async () => {
    const ref = doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_crown`);
    await assertSucceeds(updateDoc(ref, { equipped: true }));

    // Carona: `equipped` junto de outro campo tem que ser recusado, senao a
    // equipagem viraria porta para forjar procedencia.
    await assertFails(updateDoc(ref, { equipped: false, source: 'administrativa' }));
  });

  test('`equipped` precisa ser booleano', async () => {
    const ref = doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_crown`);
    await assertFails(updateDoc(ref, { equipped: 'sim' }));
  });
});

describe('inventario: isolamento entre jogadores', () => {
  test('nao le o inventario de terceiros', async () => {
    await assertFails(getDoc(doc(comoAlheio(), `users/${DONO}/inventory/pioneer_2026_crown`)));
    await assertFails(getDocs(collection(comoAlheio(), `users/${DONO}/inventory`)));
  });

  test('nao escreve no inventario de terceiros', async () => {
    await assertFails(
      updateDoc(doc(comoAlheio(), `users/${DONO}/inventory/pioneer_2026_crown`), { equipped: true }),
    );
  });

  test('nao le o comprovante de terceiros', async () => {
    await assertFails(getDoc(doc(comoAlheio(), `users/${DONO}/campaign_claims/${CAMPANHA}`)));
  });

  test('sem login nao le nada', async () => {
    await assertFails(getDoc(doc(semLogin(), `users/${DONO}/inventory/pioneer_2026_crown`)));
    await assertFails(getDoc(doc(semLogin(), `campaigns/${CAMPANHA}`)));
  });
});

describe('elegibilidade', () => {
  test('ninguem se marca elegivel', async () => {
    await assertFails(
      setDoc(doc(comoAlheio(), `campaigns/${CAMPANHA}/eligible/${ALHEIO}`), { naAllowlist: true }),
    );
    await assertFails(
      updateDoc(doc(comoDono(), `campaigns/${CAMPANHA}/eligible/${DONO}`), {
        concessaoAdministrativa: true,
      }),
    );
  });

  test('le o proprio documento, nao o dos outros', async () => {
    await assertSucceeds(getDoc(doc(comoDono(), `campaigns/${CAMPANHA}/eligible/${DONO}`)));
    await assertFails(getDoc(doc(comoAlheio(), `campaigns/${CAMPANHA}/eligible/${DONO}`)));
  });

  test('nao varre a lista de elegiveis', async () => {
    // Listar revelaria quem foi convidado antes do anuncio.
    await assertFails(getDocs(collection(comoDono(), `campaigns/${CAMPANHA}/eligible`)));
  });
});

describe('catalogo e campanha', () => {
  test('autenticado le, ninguem escreve', async () => {
    await assertSucceeds(getDoc(doc(comoDono(), `campaigns/${CAMPANHA}`)));
    await assertFails(updateDoc(doc(comoDono(), `campaigns/${CAMPANHA}`), { status: 'active' }));
    await assertFails(setDoc(doc(comoDono(), 'config/featureFlags'), {
      kitPioneiros2026Enabled: true,
    }));
    await assertFails(setDoc(doc(comoDono(), `collections/${CAMPANHA}`), { purchasable: true }));
  });

  test('auditoria nao e legivel nem gravavel pelo aplicativo', async () => {
    await assertFails(getDocs(collection(comoDono(), 'audit')));
    await assertFails(setDoc(doc(comoDono(), 'audit/forjado'), { acao: 'nada' }));
  });
});

// ---------------------------------------------------------------------------
// A partir daqui e preciso o emulador de FUNCTIONS, alem do de Firestore.
// ---------------------------------------------------------------------------

describe('claimPioneerKit', { skip: !process.env.FUNCTIONS_EMULATOR_HOST }, () => {
  const { initializeApp } = require('firebase/app');
  const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
  const {
    getFunctions, connectFunctionsEmulator, httpsCallable,
  } = require('firebase/functions');

  let chamar;
  let uid;

  before(async () => {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, 'funcoes');
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`);
    const cred = await signInAnonymously(auth);
    uid = cred.user.uid;

    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(fn, host, Number(porta));
    chamar = httpsCallable(fn, 'claimPioneerKit');

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `campaigns/${CAMPANHA}/eligible/${uid}`), {
        naAllowlist: true,
      });
    });
  });

  test('sem autenticacao, recusa', async () => {
    const { initializeApp: init2 } = require('firebase/app');
    const app2 = init2({ projectId: PROJETO, apiKey: 'fake' }, 'anonimo');
    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn2 = getFunctions(app2, 'southamerica-east1');
    connectFunctionsEmulator(fn2, host, Number(porta));
    await assert.rejects(
      () => httpsCallable(fn2, 'claimPioneerKit')(),
      (e) => e.code === 'functions/unauthenticated',
    );
  });

  test('elegivel recebe exatamente dez itens', async () => {
    const r = await chamar();
    assert.equal(r.data.status, 'claimed');
    assert.equal(r.data.itemIds.length, 10);
  });

  test('a segunda chamada devolve alreadyClaimed sem gravar nada', async () => {
    const r = await chamar();
    assert.equal(r.data.status, 'alreadyClaimed');
    assert.equal(r.data.gravados, 0);
  });

  test('UID no payload e ignorado: quem vale e o contexto autenticado', async () => {
    // Se a funcao lesse o payload, este pedido concederia o kit a OUTRA pessoa.
    await chamar({ uid: ALHEIO, userId: ALHEIO });
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const alheio = await getDocs(collection(ctx.firestore(), `users/${ALHEIO}/inventory`));
      assert.equal(alheio.size, 0, 'nada pode ter sido gravado para o UID do payload');
    });
  });

  test('cinco chamadas SIMULTANEAS ainda deixam dez itens', async () => {
    let novoUid;
    const { initializeApp: init3 } = require('firebase/app');
    const app3 = init3({ projectId: PROJETO, apiKey: 'fake' }, 'corrida');
    const auth3 = getAuth(app3);
    connectAuthEmulator(auth3, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`);
    novoUid = (await signInAnonymously(auth3)).user.uid;

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `campaigns/${CAMPANHA}/eligible/${novoUid}`), {
        naAllowlist: true,
      });
    });

    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn3 = getFunctions(app3, 'southamerica-east1');
    connectFunctionsEmulator(fn3, host, Number(porta));
    const chamar3 = httpsCallable(fn3, 'claimPioneerKit');

    // Disparadas juntas de proposito: e o cenario de toque duplo no botao, ou de
    // retry automatico logo apos um timeout.
    await Promise.all([chamar3(), chamar3(), chamar3(), chamar3(), chamar3()]);

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const inv = await getDocs(collection(ctx.firestore(), `users/${novoUid}/inventory`));
      assert.equal(inv.size, 10, 'chamadas simultaneas nao podem duplicar o kit');
    });
  });
});
