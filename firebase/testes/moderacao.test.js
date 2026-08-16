// moderacao.test.js — prova as regras do BLOCO 4/4 (OS de Moderacao §14 e §21).
//
// O QUE ESTE ARQUIVO PROVA, e que o teste em Dart nao consegue provar: quem LE e
// quem ESCREVE. O dominio Dart decide se uma denuncia e valida; a regra decide
// se o denunciado consegue chegar nela. Sao perguntas diferentes, e so esta
// segunda protege a identidade de quem denunciou.
//
// Tres casos da secao 13 da OS (payload privado por endpoint direto, por UID de
// terceiro e por parametro adulterado) tambem vivem aqui, na secao ESPECTADOR do
// fim: eles sao de autorizacao, e nao de recorte.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador
//
// Numa maquina sem Java no PATH mas com Android Studio instalado:
//   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run emulador

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

const DENUNCIANTE = 'uidDenunciante';
const DENUNCIADO = 'uidDenunciado';
const TERCEIRO = 'uidTerceiro';
const ADMIN = 'uidAdmin';

const REPORT_ID = `${DENUNCIANTE}|intent1`;
const SANCAO_ID = `${ADMIN}|sanc1`;

let ambiente;

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // Semeia como o backend semearia: regras desligadas.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, `reports/${REPORT_ID}`), {
      reportId: REPORT_ID,
      denuncianteUid: DENUNCIANTE,
      denunciadoUid: DENUNCIADO,
      tipo: 'mensagem',
      categoria: 'insulto',
      comentario: 'me xingou na mesa',
      status: 'recebida',
      createdAt: new Date().toISOString(),
      esquema: 1,
    });

    await setDoc(doc(db, `users/${DENUNCIANTE}/reportReceipts/${REPORT_ID}`), {
      protocolo: REPORT_ID,
      tipo: 'mensagem',
      categoria: 'insulto',
      status: 'emAnalise',
      criadoEm: new Date().toISOString(),
      esquema: 1,
    });

    await setDoc(doc(db, `users/${DENUNCIANTE}/blocks/${DENUNCIADO}`), {
      bloqueadorUid: DENUNCIANTE,
      bloqueadoUid: DENUNCIADO,
      criadoEm: new Date(),
      esquema: 1,
    });

    await setDoc(doc(db, `sanctions/${SANCAO_ID}`), {
      sancaoId: SANCAO_ID,
      userId: DENUNCIADO,
      tipo: 'muteTemporario',
      motivo: 'assedio',
      inicio: new Date().toISOString(),
      fim: new Date(Date.now() + 864e5).toISOString(),
      responsavel: ADMIN,
      status: 'ativa',
    });

    await setDoc(doc(db, `playerModeration/${DENUNCIADO}`), {
      userId: DENUNCIADO,
      chatSilenciadoAte: new Date(Date.now() + 864e5).toISOString(),
      socialRestritoAte: null,
      suspensoAte: null,
      suspensaoPermanente: false,
    });

    await setDoc(doc(db, 'moderationAudit/evento1'), {
      acao: 'denuncia_registrada', ator: DENUNCIANTE, alvo: DENUNCIADO,
      em: new Date().toISOString(),
    });

    await setDoc(doc(db, `moderationTasks/${REPORT_ID}`), {
      chave: REPORT_ID, tarefa: 'registrarDenuncia', ator: DENUNCIANTE,
      alvo: DENUNCIADO, executadaEm: new Date().toISOString(), resultado: 'ok',
    });
  });
});

after(async () => {
  await ambiente.cleanup();
});

const comoDenunciante = () => ambiente.authenticatedContext(DENUNCIANTE).firestore();
const comoDenunciado = () => ambiente.authenticatedContext(DENUNCIADO).firestore();
const comoTerceiro = () => ambiente.authenticatedContext(TERCEIRO).firestore();
const comoAdmin = () =>
  ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

// ===========================================================================
describe('denuncia: a identidade do denunciante nao vaza', () => {
  test('o DENUNCIADO nao le a denuncia que recai sobre ele', async () => {
    // O caso central da secao 6 da OS. O documento contem `denuncianteUid`;
    // se esta linha passasse a permitir leitura, a retaliacao viria de graca.
    await assertFails(getDoc(doc(comoDenunciado(), `reports/${REPORT_ID}`)));
  });

  test('o proprio DENUNCIANTE nao le o registro administrativo', async () => {
    // Ele ve o comprovante, nao o registro: o registro carrega evidencia e
    // status interno da investigacao.
    await assertFails(getDoc(doc(comoDenunciante(), `reports/${REPORT_ID}`)));
  });

  test('terceiro nao varre a colecao de denuncias', async () => {
    await assertFails(getDocs(collection(comoTerceiro(), 'reports')));
    await assertFails(getDocs(collection(comoDenunciado(), 'reports')));
  });

  test('sem login nao le nada de moderacao', async () => {
    await assertFails(getDoc(doc(semLogin(), `reports/${REPORT_ID}`)));
    await assertFails(getDoc(doc(semLogin(), `playerModeration/${DENUNCIADO}`)));
  });

  test('admin le', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), `reports/${REPORT_ID}`)));
  });

  test('ninguem cria denuncia direto no banco, nem em nome proprio', async () => {
    // Criar aqui deixaria o cliente escolher `createdAt`, `status` e o
    // `denuncianteUid` — os tres campos que a Function deriva do servidor.
    await assertFails(
      setDoc(doc(comoDenunciante(), 'reports/forjada'), {
        reportId: 'forjada', denuncianteUid: DENUNCIANTE,
        denunciadoUid: DENUNCIADO, tipo: 'perfil', categoria: 'outro',
        status: 'procedente', createdAt: new Date().toISOString(),
      }),
    );
  });

  test('o denunciado nao altera nem apaga a denuncia (nem a evidencia)', async () => {
    await assertFails(
      updateDoc(doc(comoDenunciado(), `reports/${REPORT_ID}`), { status: 'arquivada' }),
    );
    await assertFails(deleteDoc(doc(comoDenunciado(), `reports/${REPORT_ID}`)));
  });

  test('nem o admin altera a denuncia pelo cliente', async () => {
    // Triagem passa por Function, para que a mudanca de status sempre grave
    // auditoria junto.
    await assertFails(
      updateDoc(doc(comoAdmin(), `reports/${REPORT_ID}`), { status: 'procedente' }),
    );
  });
});

// ===========================================================================
describe('comprovante: o denunciante ve o proprio protocolo', () => {
  test('le o proprio comprovante', async () => {
    const s = await assertSucceeds(
      getDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/reportReceipts/${REPORT_ID}`)),
    );
    // E o comprovante NAO carrega quem foi denunciado nem o comentario.
    assert.equal(s.data().denunciadoUid, undefined);
    assert.equal(s.data().comentario, undefined);
    assert.equal(s.data().evidencia, undefined);
  });

  test('terceiro nao le o comprovante alheio', async () => {
    await assertFails(
      getDoc(doc(comoTerceiro(), `users/${DENUNCIANTE}/reportReceipts/${REPORT_ID}`)),
    );
    await assertFails(
      getDocs(collection(comoTerceiro(), `users/${DENUNCIANTE}/reportReceipts`)),
    );
  });

  test('o denunciante nao forja um comprovante', async () => {
    await assertFails(
      setDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/reportReceipts/forjado`), {
        protocolo: 'forjado', status: 'concluida',
      }),
    );
  });
});

// ===========================================================================
describe('bloqueio: server-authoritative', () => {
  test('o dono le a propria lista', async () => {
    await assertSucceeds(
      getDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/blocks/${DENUNCIADO}`)),
    );
    await assertSucceeds(
      getDocs(collection(comoDenunciante(), `users/${DENUNCIANTE}/blocks`)),
    );
  });

  test('o BLOQUEADO nao descobre que foi bloqueado lendo o banco', async () => {
    await assertFails(
      getDoc(doc(comoDenunciado(), `users/${DENUNCIANTE}/blocks/${DENUNCIADO}`)),
    );
  });

  test('ninguem escreve na propria lista de bloqueio pelo cliente', async () => {
    // O teto de bloqueios e uma contagem, e regra nao conta documentos: sem a
    // Function, o limite nao existiria.
    await assertFails(
      setDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/blocks/${TERCEIRO}`), {
        bloqueadorUid: DENUNCIANTE, bloqueadoUid: TERCEIRO, criadoEm: new Date(),
      }),
    );
  });

  test('ninguem altera a lista de bloqueio de TERCEIRO', async () => {
    // O ataque real: me remover da lista de quem me bloqueou.
    await assertFails(
      deleteDoc(doc(comoDenunciado(), `users/${DENUNCIANTE}/blocks/${DENUNCIADO}`)),
    );
    await assertFails(
      setDoc(doc(comoTerceiro(), `users/${DENUNCIANTE}/blocks/${TERCEIRO}`), {
        bloqueadorUid: DENUNCIANTE, bloqueadoUid: TERCEIRO,
      }),
    );
  });
});

// ===========================================================================
describe('mute pessoal: o cliente escreve, dentro da forma', () => {
  test('cria e apaga o proprio mute', async () => {
    const ref = doc(comoDenunciante(), `users/${DENUNCIANTE}/mutes/${TERCEIRO}`);
    await assertSucceeds(setDoc(ref, { alvoUid: TERCEIRO, criadoEm: new Date() }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('auto-mute e recusado pela propria regra', async () => {
    await assertFails(
      setDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/mutes/${DENUNCIANTE}`), {
        alvoUid: DENUNCIANTE, criadoEm: new Date(),
      }),
    );
  });

  test('campo extra e recusado', async () => {
    // Sem `apenasCampos`, daria para pendurar `sancao: true` aqui e torcer para
    // alguem ler isso como estado disciplinar.
    await assertFails(
      setDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/mutes/${TERCEIRO}`), {
        alvoUid: TERCEIRO, criadoEm: new Date(), sancao: 'muteTemporario',
      }),
    );
  });

  test('alvoUid tem que bater com o id do documento', async () => {
    await assertFails(
      setDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/mutes/${TERCEIRO}`), {
        alvoUid: DENUNCIADO, criadoEm: new Date(),
      }),
    );
  });

  test('ninguem mexe no mute de terceiro', async () => {
    await assertFails(
      setDoc(doc(comoDenunciado(), `users/${DENUNCIANTE}/mutes/${TERCEIRO}`), {
        alvoUid: TERCEIRO, criadoEm: new Date(),
      }),
    );
    await assertFails(
      getDocs(collection(comoDenunciado(), `users/${DENUNCIANTE}/mutes`)),
    );
  });
});

// ===========================================================================
describe('sancao: o cliente comum nao altera a propria punicao', () => {
  test('o sancionado le o EFEITO que recai sobre ele', async () => {
    await assertSucceeds(
      getDoc(doc(comoDenunciado(), `playerModeration/${DENUNCIADO}`)),
    );
  });

  test('o sancionado NAO apaga nem afrouxa o proprio estado', async () => {
    const ref = doc(comoDenunciado(), `playerModeration/${DENUNCIADO}`);
    await assertFails(updateDoc(ref, { chatSilenciadoAte: null }));
    await assertFails(deleteDoc(ref));
    await assertFails(setDoc(ref, { userId: DENUNCIADO, suspensaoPermanente: false }));
  });

  test('ninguem le o estado disciplinar de terceiro (anti-enumeracao)', async () => {
    await assertFails(getDoc(doc(comoTerceiro(), `playerModeration/${DENUNCIADO}`)));
    await assertFails(getDocs(collection(comoTerceiro(), 'playerModeration')));
  });

  test('o historico de sancoes e so do admin', async () => {
    await assertFails(getDoc(doc(comoDenunciado(), `sanctions/${SANCAO_ID}`)));
    await assertFails(getDocs(collection(comoTerceiro(), 'sanctions')));
    await assertSucceeds(getDoc(doc(comoAdmin(), `sanctions/${SANCAO_ID}`)));
  });

  test('ninguem cria sancao pelo cliente, nem o admin', async () => {
    await assertFails(
      setDoc(doc(comoDenunciado(), 'sanctions/forjada'), {
        userId: DENUNCIADO, tipo: 'advertencia', status: 'revogada',
      }),
    );
    await assertFails(
      setDoc(doc(comoAdmin(), 'sanctions/forjada'), {
        userId: DENUNCIADO, tipo: 'advertencia', status: 'ativa',
      }),
    );
  });
});

// ===========================================================================
describe('trilha administrativa', () => {
  test('auditoria e tarefas: so admin le, ninguem escreve', async () => {
    await assertFails(getDocs(collection(comoDenunciante(), 'moderationAudit')));
    await assertFails(getDocs(collection(comoDenunciado(), 'moderationTasks')));
    await assertSucceeds(getDoc(doc(comoAdmin(), 'moderationAudit/evento1')));
    await assertSucceeds(getDoc(doc(comoAdmin(), `moderationTasks/${REPORT_ID}`)));
  });

  test('nem o admin limpa a trilha que ele mesmo gerou', async () => {
    await assertFails(deleteDoc(doc(comoAdmin(), 'moderationAudit/evento1')));
    await assertFails(
      setDoc(doc(comoAdmin(), 'moderationAudit/forjado'), { acao: 'nada' }),
    );
  });
});

// ===========================================================================
// A partir daqui e preciso o emulador de FUNCTIONS, alem do de Firestore.
// Cobre o que a REGRA nao alcanca: o que a Function faz com o payload.
// ===========================================================================

describe('registrarDenuncia', { skip: !process.env.FUNCTIONS_EMULATOR_HOST }, () => {
  const { initializeApp } = require('firebase/app');
  const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
  const {
    getFunctions, connectFunctionsEmulator, httpsCallable,
  } = require('firebase/functions');

  let denunciar, bloquear, desbloquear, contato, uid;

  before(async () => {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, 'moderacao');
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`);
    uid = (await signInAnonymously(auth)).user.uid;

    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(fn, host, Number(porta));
    denunciar = httpsCallable(fn, 'registrarDenuncia');
    bloquear = httpsCallable(fn, 'bloquearJogador');
    desbloquear = httpsCallable(fn, 'desbloquearJogador');
    contato = httpsCallable(fn, 'consultarContato');
  });

  test('sem autenticacao, recusa', async () => {
    const { initializeApp: init2 } = require('firebase/app');
    const app2 = init2({ projectId: PROJETO, apiKey: 'fake' }, 'moderacao-anonimo');
    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn2 = getFunctions(app2, 'southamerica-east1');
    connectFunctionsEmulator(fn2, host, Number(porta));
    await assert.rejects(
      () => httpsCallable(fn2, 'registrarDenuncia')({
        denunciadoUid: DENUNCIADO, tipo: 'perfil', categoria: 'outro',
        reportIntentId: 'i1',
      }),
      (e) => e.code === 'functions/unauthenticated',
    );
  });

  test('denuncia valida e registrada e devolve protocolo', async () => {
    const r = await denunciar({
      denunciadoUid: DENUNCIADO, tipo: 'perfil', categoria: 'nomeOfensivo',
      reportIntentId: 'valida1', comentario: 'apelido ofensivo',
    });
    assert.equal(r.data.registrada, true);
    assert.equal(r.data.jaRegistrada, false);
    assert.equal(r.data.protocolo, `${uid}|valida1`);
  });

  test('RETRY: a segunda chamada NAO cria segundo registro', async () => {
    // Toque duplo no botao, ou retry apos timeout. Tem que devolver sucesso —
    // erro faria o cliente tentar de novo, e a proxima tambem "falharia".
    const r = await denunciar({
      denunciadoUid: DENUNCIADO, tipo: 'perfil', categoria: 'nomeOfensivo',
      reportIntentId: 'valida1', comentario: 'apelido ofensivo',
    });
    assert.equal(r.data.registrada, true);
    assert.equal(r.data.jaRegistrada, true);

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDocs(collection(ctx.firestore(), 'reports'));
      const minhas = s.docs.filter((d) => d.data().denuncianteUid === uid);
      assert.equal(minhas.length, 1, 'retry nao pode duplicar a denuncia');
    });
  });

  test('CONCORRENCIA: cinco chamadas simultaneas deixam UM registro', async () => {
    const pedido = {
      denunciadoUid: DENUNCIADO, tipo: 'partida', categoria: 'combinacao',
      reportIntentId: 'corrida1', matchId: 'm1',
    };
    await Promise.all([
      denunciar(pedido), denunciar(pedido), denunciar(pedido),
      denunciar(pedido), denunciar(pedido),
    ]);

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDoc(doc(ctx.firestore(), `reports/${uid}|corrida1`));
      assert.equal(s.exists(), true);
      const todas = await getDocs(collection(ctx.firestore(), 'reports'));
      const dessa = todas.docs.filter((d) => d.id === `${uid}|corrida1`);
      assert.equal(dessa.length, 1);
    });
  });

  test('UID no payload e IGNORADO: vale o contexto autenticado', async () => {
    // Se a funcao lesse o payload, esta chamada denunciaria em nome de outra
    // pessoa — e a retaliacao cairia sobre quem nao denunciou nada.
    await denunciar({
      denuncianteUid: TERCEIRO, uid: TERCEIRO,
      denunciadoUid: DENUNCIADO, tipo: 'perfil', categoria: 'outro',
      reportIntentId: 'forjada1',
    });
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const forjada = await getDoc(doc(ctx.firestore(), `reports/${TERCEIRO}|forjada1`));
      assert.equal(forjada.exists(), false, 'nada pode ser gravado para o UID do payload');
      const real = await getDoc(doc(ctx.firestore(), `reports/${uid}|forjada1`));
      assert.equal(real.data().denuncianteUid, uid);
    });
  });

  test('auto-denuncia e recusada pelo servidor', async () => {
    await assert.rejects(
      () => denunciar({
        denunciadoUid: uid, tipo: 'perfil', categoria: 'outro',
        reportIntentId: 'auto1',
      }),
      (e) => e.details?.recusa === 'autoDenuncia',
    );
  });

  test('categoria invalida para o tipo e recusada', async () => {
    await assert.rejects(
      () => denunciar({
        denunciadoUid: DENUNCIADO, tipo: 'partida', categoria: 'insulto',
        reportIntentId: 'cat1', matchId: 'm1',
      }),
      (e) => e.details?.recusa === 'categoriaInvalidaParaTipo',
    );
  });

  test('denuncia de partida sem matchId e recusada', async () => {
    await assert.rejects(
      () => denunciar({
        denunciadoUid: DENUNCIADO, tipo: 'partida', categoria: 'combinacao',
        reportIntentId: 'ref1',
      }),
      (e) => e.details?.recusa === 'referenciaAusente',
    );
  });

  test('o comprovante do denunciante nao carrega quem foi denunciado', async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDoc(
        doc(ctx.firestore(), `users/${uid}/reportReceipts/${uid}|valida1`));
      assert.equal(s.exists(), true);
      assert.equal(s.data().denunciadoUid, undefined);
      assert.equal(s.data().comentario, undefined);
      assert.equal(s.data().status, 'emAnalise');
    });
  });
});

describe('bloqueio pela Function', { skip: !process.env.FUNCTIONS_EMULATOR_HOST }, () => {
  const { initializeApp } = require('firebase/app');
  const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
  const {
    getFunctions, connectFunctionsEmulator, httpsCallable,
  } = require('firebase/functions');

  let bloquear, desbloquear, contato, uid;

  before(async () => {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, 'moderacao-bloqueio');
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`);
    uid = (await signInAnonymously(auth)).user.uid;

    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(fn, host, Number(porta));
    bloquear = httpsCallable(fn, 'bloquearJogador');
    desbloquear = httpsCallable(fn, 'desbloquearJogador');
    contato = httpsCallable(fn, 'consultarContato');
  });

  test('bloquear e UNILATERAL: nao cria o inverso', async () => {
    await bloquear({ bloqueadoUid: DENUNCIADO });
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const ida = await getDoc(doc(ctx.firestore(), `users/${uid}/blocks/${DENUNCIADO}`));
      const volta = await getDoc(doc(ctx.firestore(), `users/${DENUNCIADO}/blocks/${uid}`));
      assert.equal(ida.exists(), true);
      assert.equal(volta.exists(), false, 'bloqueio nao pode ser espelhado');
    });
  });

  test('bloquear duas vezes CONVERGE, nao falha', async () => {
    await bloquear({ bloqueadoUid: DENUNCIADO });
    await bloquear({ bloqueadoUid: DENUNCIADO });
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDocs(collection(ctx.firestore(), `users/${uid}/blocks`));
      assert.equal(s.docs.filter((d) => d.id === DENUNCIADO).length, 1);
    });
  });

  test('auto-bloqueio e recusado', async () => {
    await assert.rejects(
      () => bloquear({ bloqueadoUid: uid }),
      (e) => e.details?.recusa === 'autoBloqueio',
    );
  });

  test('o contato do bloqueado com o bloqueador e barrado', async () => {
    const r = await contato({ alvoUid: DENUNCIADO });
    assert.equal(r.data.permitido, false);
    assert.equal(r.data.motivo, 'bloqueouODestino');
  });

  test('desbloquear libera, e desbloquear duas vezes converge', async () => {
    await desbloquear({ bloqueadoUid: DENUNCIADO });
    await desbloquear({ bloqueadoUid: DENUNCIADO });
    const r = await contato({ alvoUid: DENUNCIADO });
    assert.equal(r.data.permitido, true);
  });

  test('consultar contato com UID desconhecido responde neutro', async () => {
    // Secao 18 da OS: a resposta nao pode servir de mapa de contas validas.
    const r = await contato({ alvoUid: 'uidQueNaoExisteEmLugarNenhum' });
    assert.equal(r.data.permitido, true);
  });
});

// ===========================================================================
describe('nao-regressao: os tres blocos anteriores continuam de pe', () => {
  test('o fecho padrao ainda nega caminho nao declarado', async () => {
    await assertFails(getDoc(doc(comoDenunciante(), 'colecaoInventada/doc1')));
    await assertFails(
      setDoc(doc(comoDenunciante(), 'colecaoInventada/doc1'), { x: 1 }),
    );
  });

  test('o segundo bloco users/{uid} nao afrouxou o inventario', async () => {
    // As regras avaliam TODOS os blocos que casam e concedem se qualquer um
    // conceder. Se o bloco novo tivesse um `match /{documento=**}` interno, ele
    // teria aberto inventario e comprovantes de campanha junto.
    await assertFails(
      getDoc(doc(comoTerceiro(), `users/${DENUNCIANTE}/inventory/pioneer_2026_crown`)),
    );
    await assertFails(
      setDoc(doc(comoDenunciante(), `users/${DENUNCIANTE}/inventory/forjado`), {
        itemId: 'forjado',
      }),
    );
  });
});
