// seguranca.test.js — prova as regras e a idempotencia contra os emuladores.
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
// DUAS SUITES NUM ARQUIVO SO, e a divisao esta marcada no meio:
//
//   REGRAS ..... rodam com `--only firestore`. Nao chamam Function nenhuma.
//   FUNCTIONS .. o bloco `claimPioneerKit`, que roda SOMENTE quando
//                `FUNCTIONS_EMULATOR_HOST` existe. E o que prova idempotencia,
//                concorrencia e o UID do payload ignorado — coisas que regra
//                nenhuma alcanca.
//
// O `skip` do bloco de Function nao basta para que ele rode: como
// `emulators:exec` NAO exporta `FUNCTIONS_EMULATOR_HOST` (so FIRESTORE_*, AUTH_*
// e GCLOUD_PROJECT), quem sobe o emulador pela via normal pula o bloco em
// silencio e ve a suite verde. Quem exporta a variavel — e FALHA se a porta 5001
// nao atender, ou se sobrar qualquer caso pulado — e `com-functions.js`, atras
// de `npm run emulador:colecoes`.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador-regras                 # so as regras (Function pulada)
//   npm run emulador:colecoes               # regras + claimPioneerKit de verdade
//
// Numa maquina sem Java no PATH mas com Android Studio instalado:
//   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run emulador:colecoes

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

// O projeto vem do emulador quando ha um: `firebase emulators:exec` exporta
// GCLOUD_PROJECT para o processo filho. Fixar o id aqui fazia as chamadas de
// Cloud Function irem para um projeto que o emulador nao servia — a resposta era
// 404, que o SDK entrega como `not-found`, e o bloco claimPioneerKit inteiro
// reprovava sem tocar em regra nenhuma. O valor antigo fica como padrao para
// quem rodar o harness contra um emulador ja de pe.
const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';
const CAMPANHA = 'pioneiros_2026';
const DONO = 'uid_dono';
const ALHEIO = 'uid_alheio';
const ADMIN = 'uid_admin';

// Os CINCO caminhos que o ruleset de producao (era FlutterFlow) abria e que a
// RC1 nao declara. OS PRE-HOM-BMV-RC1-B2-RULES-C1, bloqueador R2: a decisao e
// LEGADO-ENCERRAR para os cinco, e e ESTA lista que a impede de ser desfeita
// por descuido. O id semeado de cada um e o id REAL do documento que existe em
// producao, para que o caso exercite o caminho que de fato existe la.
const LEGADOS = [
  { colecao: 'global_chat', id: 'msg_semente' },
  { colecao: 'tables', id: 'mesa_semente' },
  { colecao: 'seasons', id: '2026_S1' },
  { colecao: 'leaderboards', id: '2026_S1' },
  { colecao: 'store_products', id: 'pack_starter' },
];

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
      // Sem `eligibilityMode` a funcao recusa com
      // "eligibilityMode desconhecido: undefined" antes de olhar a evidencia —
      // o fixture nao satisfazia o contrato da propria funcao. `allowlist` e o
      // modo do seed de producao (campanha_pioneiros_2026.seed.json) e o unico
      // coerente com o `naAllowlist: true` semeado logo abaixo.
      eligibilityMode: 'allowlist',
      // `gravarItens` grava `collectionId: campanha.collectionId` em cada item
      // do inventario; sem o campo, a transacao morre com "Cannot use
      // 'undefined' as a Firestore value". O seed de producao
      // (campanha_pioneiros_2026.seed.json) traz "collectionId":
      // "pioneiros_2026", que e exatamente o valor de CAMPANHA — a constante ja
      // usada nas semeaduras de inventario logo abaixo.
      collectionId: CAMPANHA,
      featureFlag: 'kitPioneiros2026Enabled', rewardIds: ITENS,
    });
    await setDoc(doc(db, `campaigns/${CAMPANHA}/eligible/${DONO}`), { naAllowlist: true });
    await setDoc(doc(db, 'config/featureFlags'), { kitPioneiros2026Enabled: true });
    await setDoc(doc(db, `users/${DONO}/inventory/pioneer_2026_crown`), {
      userId: DONO, itemId: 'pioneer_2026_crown', collectionId: CAMPANHA,
      source: 'campanha', campaignId: CAMPANHA, campaignVersion: 1,
      unlockedAt: new Date(), equipped: false,
    });

    // O DOCUMENTO RAIZ `users/{uid}`, semeado DE PROPOSITO.
    //
    // Um caso que so prova negacao sobre documento inexistente e fraco: o
    // Firestore nega leitura de documento ausente de qualquer jeito, e o teste
    // passaria mesmo com a regra aberta. Semeado, `assertFails` so pode vir da
    // REGRA. O conteudo imita o unico documento que existe em producao neste
    // caminho — `users/teste_user`, com `displayName` e nada mais —, e
    // acrescenta um campo de aparencia sensivel para que o caso de escrita
    // tenha o que tentar adulterar.
    await setDoc(doc(db, `users/${DONO}`), {
      displayName: 'Dono Legado',
      vip: true,
    });

    // Os cinco caminhos do legado, com os ids que existem em producao. Mesmo
    // motivo: negacao sobre documento que existe e a unica que prova regra.
    for (const { colecao, id } of LEGADOS) {
      await setDoc(doc(db, `${colecao}/${id}`), { semente: true });
    }
  });
});

after(async () => {
  await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoAlheio = () => ambiente.authenticatedContext(ALHEIO).firestore();
const comoAdmin = () => ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
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

// ===========================================================================
// RAIZ-U — o documento raiz `users/{uid}`
// OS PRE-HOM-BMV-RC1-B2-RULES-C1, bloqueador R1.
// ===========================================================================
//
// A regra de producao anterior concedia `read, write` ao dono aqui. A RC1 nega
// a todos, e agora nega EXPLICITAMENTE. Estes casos provam as duas metades da
// decisao — que a porta fechou, e que fechar esta porta nao fechou nenhuma das
// oito subcolecoes que penduram deste documento.
//
// O CONTROLE POSITIVO abre o bloco de proposito. Sem ele, um emulador que
// tivesse subido sem carregar as regras faria TODO `assertFails` "passar", e a
// suite inteira daria verde provando nada. Se a primeira afirmacao falhar, o
// que esta quebrado e a bancada, nao a regra.
describe('RAIZ-U — `users/{uid}` e negado a todos', () => {
  test('RAIZ-U-00 controle positivo: a bancada carregou as regras', async () => {
    // Um caminho que a RC1 DECLARA como legivel pelo autenticado. Se isto
    // falha, nenhum `assertFails` abaixo significa coisa alguma.
    await assertSucceeds(getDoc(doc(comoDono(), 'config/featureFlags')));
  });

  test('RAIZ-U-01 o dono nao le o proprio documento raiz', async () => {
    await assertFails(getDoc(doc(comoDono(), `users/${DONO}`)));
  });

  test('RAIZ-U-02 outro jogador nao le o documento raiz alheio', async () => {
    await assertFails(getDoc(doc(comoAlheio(), `users/${DONO}`)));
  });

  test('RAIZ-U-03 nao autenticado nao le', async () => {
    await assertFails(getDoc(doc(semLogin(), `users/${DONO}`)));
  });

  test('RAIZ-U-04 nem o admin le pelo cliente', async () => {
    // Nao ha excecao de admin neste caminho, e a ausencia e deliberada: o
    // suporte que precisar do documento usa o Admin SDK, que nao passa por aqui.
    await assertFails(getDoc(doc(comoAdmin(), `users/${DONO}`)));
  });

  test('RAIZ-U-05 ninguem varre a colecao `users`', async () => {
    // O `list` e o caso que mais doeria: os ids DESTA colecao sao os UIDs.
    for (const db of [comoDono(), comoAlheio(), comoAdmin(), semLogin()]) {
      await assertFails(getDocs(collection(db, 'users')));
    }
  });

  test('RAIZ-U-06 o dono nao escreve nem campo inocente', async () => {
    // `displayName` e exatamente o campo que o unico documento de producao tem.
    // Negado do mesmo jeito: sem produtor, nao existe campo legitimo aqui.
    await assertFails(updateDoc(doc(comoDono(), `users/${DONO}`), {
      displayName: 'outro nome',
    }));
  });

  test('RAIZ-U-07 o dono nao adultera campo de aparencia sensivel', async () => {
    await assertFails(updateDoc(doc(comoDono(), `users/${DONO}`), { vip: true }));
    await assertFails(setDoc(doc(comoDono(), `users/${DONO}`), {
      displayName: 'Dono Legado', vip: true,
    }));
  });

  test('RAIZ-U-08 o dono nao cria documento raiz novo', async () => {
    await assertFails(setDoc(doc(comoDono(), `users/${ALHEIO}`), { displayName: 'x' }));
    await assertFails(setDoc(doc(comoAlheio(), `users/${ALHEIO}`), { displayName: 'x' }));
  });

  test('RAIZ-U-09 ninguem apaga o documento raiz', async () => {
    // Apagar e do Admin SDK, na exclusao de conta (`conta.usersRaiz`).
    for (const db of [comoDono(), comoAlheio(), comoAdmin(), semLogin()]) {
      await assertFails(deleteDoc(doc(db, `users/${DONO}`)));
    }
  });
});

// As subcolecoes NAO foram atingidas. Este bloco e a contraprova do anterior:
// regra do Firestore se avalia por documento e se soma por OR, entao um
// `if false` em `match /users/{uid}` nao pode remover concessao de bloco
// nenhum. "Nao pode" por leitura do modelo; aqui isso vira medida.
describe('RAIZ-U — o `if false` do raiz nao desceu para as subcolecoes', () => {
  test('RAIZ-U-10 o dono continua lendo o proprio inventario', async () => {
    await assertSucceeds(
      getDoc(doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_crown`))
    );
    await assertSucceeds(
      getDocs(collection(comoDono(), `users/${DONO}/inventory`))
    );
  });

  test('RAIZ-U-11 o dono continua ligando `equipped`', async () => {
    await assertSucceeds(
      updateDoc(doc(comoDono(), `users/${DONO}/inventory/pioneer_2026_crown`), {
        equipped: true,
      })
    );
  });

  test('RAIZ-U-12 o dono continua criando e apagando o proprio silencio', async () => {
    // `mutes` e a unica subcolecao de `users/{uid}` em que o cliente ESCREVE.
    // Se o `if false` do pai tivesse descido, seria aqui que apareceria.
    await assertSucceeds(
      setDoc(doc(comoDono(), `users/${DONO}/mutes/${ALHEIO}`), {
        alvoUid: ALHEIO, criadoEm: new Date(),
      })
    );
    await assertSucceeds(deleteDoc(doc(comoDono(), `users/${DONO}/mutes/${ALHEIO}`)));
  });

  test('RAIZ-U-13 e o isolamento entre jogadores continua de pe', async () => {
    await assertFails(
      getDoc(doc(comoAlheio(), `users/${DONO}/inventory/pioneer_2026_crown`))
    );
  });
});

// ===========================================================================
// LEGADO — os cinco caminhos do ruleset de producao que a RC1 encerra
// OS PRE-HOM-BMV-RC1-B2-RULES-C1, bloqueador R2.
// ===========================================================================
//
// `global_chat`, `tables`, `seasons`, `leaderboards` e `store_products` eram
// abertos pelo ruleset da era FlutterFlow e NAO sao declarados neste arquivo de
// regras: caem no fecho `match /{documento=**}`. A decisao desta OS e
// LEGADO-ENCERRAR para os cinco, e e ESTE bloco que a torna irreversivel por
// descuido — nao o comentario no arquivo de regras.
//
// OS CINCO DOCUMENTOS ESTAO SEMEADOS com os ids que existem em producao. Negar
// leitura de documento que nao existe nao prova regra nenhuma; negar leitura de
// documento que existe, prova.
describe('LEGADO — os cinco caminhos da era anterior ficam fechados', () => {
  test('LEGADO-00 controle positivo: um caminho declarado continua legivel', async () => {
    // Mesma funcao do RAIZ-U-00, e repetido de proposito: este bloco tem que
    // poder ser lido e executado sozinho sem herdar a garantia do vizinho.
    await assertSucceeds(getDoc(doc(comoDono(), `campaigns/${CAMPANHA}`)));
  });

  for (const { colecao, id } of LEGADOS) {
    const caminho = `${colecao}/${id}`;

    test(`LEGADO-${colecao}-le ninguem le`, async () => {
      for (const db of [comoDono(), comoAlheio(), comoAdmin(), semLogin()]) {
        await assertFails(getDoc(doc(db, caminho)));
      }
    });

    test(`LEGADO-${colecao}-varre ninguem varre`, async () => {
      for (const db of [comoDono(), comoAlheio(), comoAdmin(), semLogin()]) {
        await assertFails(getDocs(collection(db, colecao)));
      }
    });

    test(`LEGADO-${colecao}-escreve ninguem escreve`, async () => {
      for (const db of [comoDono(), comoAlheio(), comoAdmin(), semLogin()]) {
        // Sobre o documento que existe...
        await assertFails(updateDoc(doc(db, caminho), { semente: false }));
        await assertFails(setDoc(doc(db, caminho), { semente: false }));
        // ...e sobre um que nao existe, que e como colecao morta volta a ganhar
        // conteudo sem ninguem decidir.
        await assertFails(setDoc(doc(db, `${colecao}/forjado`), { x: 1 }));
      }
    });

    test(`LEGADO-${colecao}-apaga ninguem apaga`, async () => {
      for (const db of [comoDono(), comoAlheio(), comoAdmin(), semLogin()]) {
        await assertFails(deleteDoc(doc(db, caminho)));
      }
    });
  }

  test('LEGADO-tables nao confunde a subcolecao de torneio', async () => {
    // Existe um `tables` NESTE arquivo de regras, e ele e outro caminho:
    // `tournaments/{t}/editions/{e}/tables`, legivel pelo autenticado. A decisao
    // de encerrar a colecao de PRIMEIRO NIVEL nao o alcanca, e este caso e o que
    // separa os dois — se alguem "cumprir" o encerramento mexendo no bloco de
    // torneios, este caso quebra.
    await assertSucceeds(
      getDoc(doc(comoDono(), 'tournaments/t1/editions/e1/tables/mesa1'))
    );
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

  const REGIAO = 'southamerica-east1';
  const [HOST_FN, PORTA_FN] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');

  /** Callable ligado ao emulador, sem sessao nenhuma. */
  function callableAnonimo(instancia, nome, regiao = REGIAO) {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, instancia);
    const fn = getFunctions(app, regiao);
    connectFunctionsEmulator(fn, HOST_FN, Number(PORTA_FN));
    return httpsCallable(fn, nome);
  }

  /**
   * Um jogador novo, anonimo, ja marcado como elegivel. Cada caso que precisa do
   * CAMINHO DE PRIMEIRO RESGATE pede o seu: reaproveitar o UID de um caso
   * anterior faria a funcao sair pelo atalho do comprovante existente, e o teste
   * mediria outra coisa sem avisar.
   */
  async function jogadorElegivel(instancia) {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, instancia);
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`);
    const uid = (await signInAnonymously(auth)).user.uid;

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `campaigns/${CAMPANHA}/eligible/${uid}`), {
        naAllowlist: true,
      });
    });

    const fn = getFunctions(app, REGIAO);
    connectFunctionsEmulator(fn, HOST_FN, Number(PORTA_FN));
    return { uid, chamar: httpsCallable(fn, 'claimPioneerKit') };
  }

  /**
   * Estado gravado, lido com as regras DESLIGADAS: o que a Function deixou.
   *
   * O resultado sai por variavel, e nao pelo `return` do callback:
   * `withSecurityRulesDisabled` resolve com `undefined` e NAO repassa o que o
   * callback devolveu.
   */
  async function estado(uid) {
    let lido;
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      const inv = await getDocs(collection(db, `users/${uid}/inventory`));
      const comprovantes = await getDocs(collection(db, `users/${uid}/campaign_claims`));
      lido = {
        itens: inv.docs.map((d) => d.id).sort(),
        comprovantes: comprovantes.docs.map((d) => ({ id: d.id, ...d.data() })),
      };
    });
    return lido;
  }

  let chamar;
  let uid;

  before(async () => {
    ({ uid, chamar } = await jogadorElegivel('funcoes'));
  });

  // §13 — a chamada tem que acertar A FUNCAO, e nao um endereco qualquer que
  // devolva erro. O par abaixo prova as duas metades no mesmo caso: na regiao
  // exportada o emulador ENTRA na funcao (e recusa por autenticacao, que so a
  // primeira linha do corpo produz); numa regiao onde ela nao existe o emulador
  // devolve `not-found`. Se o projeto ou a porta estivessem errados, os dois
  // lados dariam o MESMO erro e a assercao cairia.
  test('a chamada acerta claimPioneerKit em southamerica-east1, e nao outro endereco', async () => {
    const naRegiaoCerta = callableAnonimo('regiao-certa', 'claimPioneerKit');
    const erroCerto = await naRegiaoCerta().then(() => null, (e) => e);
    assert.equal(
      erroCerto && erroCerto.code, 'functions/unauthenticated',
      'na regiao exportada a Function precisa ser ALCANCADA e recusar por autenticacao',
    );

    const naRegiaoErrada = callableAnonimo('regiao-errada', 'claimPioneerKit', 'us-central1');
    const erroErrado = await naRegiaoErrada().then(() => null, (e) => e);
    assert.equal(
      erroErrado && erroErrado.code, 'functions/not-found',
      'numa regiao sem a Function o emulador precisa dizer not-found — e o que separa '
      + '"recusou" de "nem existe"',
    );
  });

  test('sem autenticacao, recusa', async () => {
    const semSessao = callableAnonimo('anonimo', 'claimPioneerKit');
    const erro = await semSessao().then(() => null, (e) => e);

    assert.ok(erro, 'chamada sem autenticacao nao pode ter sido aceita');
    // Igualdade, e nao predicado booleano: `not-found`, `internal`,
    // `deadline-exceeded` e `unavailable` sao os quatro desfechos que ja
    // apareceram por endereco errado ou emulador fora do ar, e nenhum deles
    // prova autenticacao. A mensagem do assert mostra qual veio.
    assert.equal(erro.code, 'functions/unauthenticated');
  });

  test('elegivel recebe exatamente dez itens', async () => {
    const r = await chamar();
    assert.equal(r.data.status, 'claimed');
    assert.equal(r.data.gravados, 10);
    assert.deepEqual([...r.data.itemIds].sort(), [...ITENS].sort());

    // A resposta e o que a funcao DIZ. O inventario e o que ela FEZ.
    const depois = await estado(uid);
    assert.deepEqual(depois.itens, [...ITENS].sort());
    assert.equal(depois.comprovantes.length, 1);

    const [c] = depois.comprovantes;
    assert.equal(c.id, CAMPANHA);
    assert.equal(c.userId, uid);
    assert.equal(c.campaignId, CAMPANHA);
    assert.equal(c.campaignVersion, 1);
    assert.deepEqual([...c.itemIds].sort(), [...ITENS].sort());
  });

  test('a segunda chamada devolve alreadyClaimed sem gravar nada', async () => {
    const antes = await estado(uid);
    const claimedAtAntes = antes.comprovantes[0].claimedAt.toMillis();

    const r = await chamar();
    assert.equal(r.data.status, 'alreadyClaimed');
    assert.equal(r.data.gravados, 0);

    const depois = await estado(uid);
    // Os ids sao deterministas: contar dez documentos nao distingue "nao gravou"
    // de "gravou por cima dos mesmos dez". `claimedAt` distingue — um segundo
    // `tx.set` no comprovante moveria o carimbo do servidor.
    assert.deepEqual(depois.itens, antes.itens);
    assert.equal(depois.comprovantes.length, 1);
    assert.equal(depois.comprovantes[0].claimedAt.toMillis(), claimedAtAntes,
      'a segunda chamada regravou o comprovante');
  });

  test('UID no payload e ignorado: quem vale e o contexto autenticado', async () => {
    // UID NOVO de proposito. Com um UID que ja resgatou, a funcao sai no atalho
    // do comprovante existente e nunca chega no trecho que decide QUEM recebe —
    // o caso passaria sem ter exercitado a concessao.
    const forjador = await jogadorElegivel('payload-forjado');
    const antesDoAlheio = await estado(ALHEIO);
    assert.deepEqual(antesDoAlheio.itens, [], 'o alvo forjado precisa comecar vazio');

    const r = await forjador.chamar({ uid: ALHEIO, userId: ALHEIO });

    // Metade positiva: a concessao ACONTECEU, e foi para quem estava autenticado.
    assert.equal(r.data.status, 'claimed');
    const doAutenticado = await estado(forjador.uid);
    assert.deepEqual(doAutenticado.itens, [...ITENS].sort());
    assert.equal(doAutenticado.comprovantes.length, 1);
    assert.equal(doAutenticado.comprovantes[0].userId, forjador.uid);

    // Metade negativa: o UID do payload nao ganhou nada.
    const doAlheio = await estado(ALHEIO);
    assert.deepEqual(doAlheio.itens, [], 'nada pode ter sido gravado para o UID do payload');
    assert.deepEqual(doAlheio.comprovantes, [], 'nem comprovante para o UID do payload');
  });

  test('cinco chamadas SIMULTANEAS: uma concede, quatro convergem', async () => {
    const { uid: novoUid, chamar: chamar3 } = await jogadorElegivel('corrida');

    // Disparadas juntas de proposito: e o cenario de toque duplo no botao, ou de
    // retry automatico logo apos um timeout.
    const respostas = await Promise.allSettled([
      chamar3(), chamar3(), chamar3(), chamar3(), chamar3(),
    ]);

    const recusadas = respostas.filter((r) => r.status === 'rejected');
    assert.deepEqual(
      recusadas.map((r) => r.reason && r.reason.code), [],
      'nenhuma das cinco pode falhar: a corrida e o caminho feliz do toque duplo',
    );

    const dados = respostas.map((r) => r.value.data);
    const situacoes = dados.map((d) => d.status).sort();

    // O CORACAO DESTE CASO. Conferir so `inventory.size === 10` nao denunciaria
    // execucao dupla: os ids de item sao deterministas e a gravacao e `merge`,
    // entao duas concessoes convergiriam nos MESMOS dez documentos e o teste
    // ficaria verde. Quem denuncia e o resultado das chamadas: um segundo
    // `claimed` significa que o corpo da transacao concedeu duas vezes.
    assert.deepEqual(
      situacoes,
      ['alreadyClaimed', 'alreadyClaimed', 'alreadyClaimed', 'alreadyClaimed', 'claimed'],
      `esperado exatamente um claimed e quatro alreadyClaimed; veio ${situacoes.join(', ')}`,
    );
    assert.equal(
      dados.reduce((soma, d) => soma + d.gravados, 0), 10,
      'a soma das gravacoes das cinco chamadas precisa ser um kit, e nao dois',
    );

    const depois = await estado(novoUid);
    assert.deepEqual(depois.itens, [...ITENS].sort());
    assert.equal(depois.comprovantes.length, 1, 'um unico comprovante canonico');

    const [c] = depois.comprovantes;
    assert.equal(c.id, CAMPANHA);
    assert.equal(c.userId, novoUid, 'o comprovante pertence ao UID autenticado');
    assert.equal(c.campaignId, CAMPANHA);
    assert.equal(c.campaignVersion, 1);
    assert.deepEqual([...c.itemIds].sort(), [...ITENS].sort());
  });
});
