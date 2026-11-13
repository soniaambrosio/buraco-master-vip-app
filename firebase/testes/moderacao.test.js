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
// DUAS SUITES NUM ARQUIVO SO, e a divisao esta marcada no meio:
//
//   REGRAS ..... rodam com `--only firestore`. Sem `dart compile js`, sem tsc.
//   FUNCTIONS .. rodam SOMENTE quando `FUNCTIONS_EMULATOR_HOST` existe. Sao as
//                que provam idempotencia, concorrencia e o UID do payload
//                ignorado — coisas que regra nenhuma alcanca.
//
// O `skip` dos dois describes de Function nao basta para que eles rodem: como
// `emulators:exec` NAO exporta `FUNCTIONS_EMULATOR_HOST`, quem sobe o emulador
// pela via normal os pula em silencio e ve a suite verde. Quem exporta a
// variavel — e FALHA se a porta 5001 nao atender — e `com-functions.js`, atras
// de `npm run emulador:moderacao`.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador                        # so as regras (Functions puladas)
//   npm run emulador:moderacao              # regras + Functions de moderacao
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

  let denunciar, uid;

  before(async () => {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, 'moderacao');
    const auth = getAuth(app);
    connectAuthEmulator(auth, `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`);
    uid = (await signInAnonymously(auth)).user.uid;

    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const fn = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(fn, host, Number(porta));
    denunciar = httpsCallable(fn, 'registrarDenuncia');
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
      const db = ctx.firestore();
      const reportId = `${uid}|corrida1`;
      assert.equal((await getDoc(doc(db, `reports/${reportId}`))).exists(), true);

      // CONTAR A TRILHA, e nao os documentos de `reports`.
      //
      // A versao anterior deste teste filtrava `reports` por id e conferia que
      // sobrava um — assercao que NAO PODE FALHAR, porque id de documento e
      // unico por construcao: cinco criacoes concorrentes da mesma chave
      // deixariam um documento mesmo se a barreira de idempotencia nao
      // existisse. O teste passava sem provar nada, e ninguem percebeu porque o
      // bloco inteiro estava permanentemente pulado.
      //
      // `moderationAudit` e o unico artefato que DENUNCIA a execucao dupla: os
      // documentos tem id automatico, entao um corpo de transacao executado
      // duas vezes deixa duas linhas de trilha para o mesmo `reportId`.
      const trilha = await getDocs(collection(db, 'moderationAudit'));
      const dessa = trilha.docs.filter((d) => d.data().reportId === reportId);
      assert.equal(dessa.length, 1, 'o corpo da transacao rodou mais de uma vez');

      const recibos = await getDocs(collection(db, `users/${uid}/reportReceipts`));
      assert.equal(
        recibos.docs.filter((d) => d.id === reportId).length, 1,
      );
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
      // A LISTA INTEIRA, e nao os documentos com aquele id: filtrar por id so
      // pode devolver zero ou um, entao a assercao antiga nao alcancava o
      // defeito que o teste descreve. Contar a lista pega a gravacao duplicada
      // sob outra chave — que e a forma que a duplicidade teria.
      assert.equal(s.docs.length, 1);
      assert.equal(s.docs[0].id, DENUNCIADO);
    });
  });

  test('auto-bloqueio e recusado', async () => {
    await assert.rejects(
      () => bloquear({ bloqueadoUid: uid }),
      (e) => e.details?.recusa === 'autoBloqueio',
    );
  });

  test('quem BLOQUEOU tambem nao alcanca quem ele bloqueou', async () => {
    // O nome antigo deste caso ("o contato do bloqueado com o bloqueador")
    // descrevia a direcao OPOSTA a que ele media: aqui quem chama e o
    // bloqueador, e `bloqueouODestino` e justamente o motivo da outra ponta.
    // A direcao que a §8 da OS EXIGE — o bloqueado nao alcanca o bloqueador —
    // nao era coberta por teste nenhum; ela vive no caso seguinte.
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

  test('o BLOQUEADO nao alcanca quem o bloqueou (§8 da OS)', async () => {
    // Roda DEPOIS do desbloqueio de proposito: sem bloqueio na ida, uma recusa
    // aqui so pode vir da volta. Se as duas pontas estivessem bloqueadas, o
    // teste passaria pelo motivo errado e a §8 seguiria sem prova.
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${DENUNCIADO}/blocks/${uid}`), {
        bloqueadorUid: DENUNCIADO, bloqueadoUid: uid, criadoEm: new Date(),
        esquema: 1,
      });
    });

    const r = await contato({ alvoUid: DENUNCIADO });
    assert.equal(r.data.permitido, false);
    assert.equal(r.data.motivo, 'bloqueadoPeloDestino');

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), `users/${DENUNCIADO}/blocks/${uid}`));
    });
  });

  test('consultar contato com UID desconhecido responde neutro', async () => {
    // Secao 18 da OS: a resposta nao pode servir de mapa de contas validas.
    const r = await contato({ alvoUid: 'uidQueNaoExisteEmLugarNenhum' });
    assert.equal(r.data.permitido, true);
  });
});

// ===========================================================================
// SOCIAL-02 C4 — bloqueio com corte duravel, desbloqueio e lista por publicId.
//
// Callables REAIS da Moderacao (`moderacaoemu` sobe so esta codebase). O que o
// teste semeia direto (identidades, bloqueios em massa com o mesmo instante,
// diarios) e MONTAGEM declarada: nenhuma flag, endpoint ou modo de produto.
// A faxina do Social (gatilho) NAO roda aqui — e a prova dividida B-1: este
// arquivo prova a callable e o FORMATO gravado; social.test.js usa esse
// formato e prova o gatilho.
// ===========================================================================
describe('bloqueio, corte e lista (SOCIAL-02 C4)', { skip: !process.env.FUNCTIONS_EMULATOR_HOST }, () => {
  const { initializeApp } = require('firebase/app');
  const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
  const {
    getFunctions, connectFunctionsEmulator, httpsCallable,
  } = require('firebase/functions');
  const { writeBatch, runTransaction } = require('firebase/firestore');

  const ALFABETO = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  const PRIVADAS = ['uid', 'bloqueadorUid', 'bloqueadoUid', 'token', 'membros', 'corteId'];
  let seq = 0;

  /// `P` + 12 simbolos do alfabeto do publicId: valido para `normalizarPublicId`.
  function novoPid() {
    let n = ++seq;
    let corpo = '';
    for (let i = 0; i < 10; i++) {
      corpo = ALFABETO[n % 32] + corpo;
      n = Math.floor(n / 32);
    }
    return `PC4${corpo}`;
  }

  async function jogador(nome) {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, `c4-${nome}-${++seq}`);
    const auth = getAuth(app);
    connectAuthEmulator(
      auth,
      `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`,
      { disableWarnings: true },
    );
    const uid = (await signInAnonymously(auth)).user.uid;
    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const f = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(f, host, Number(porta));
    const c = (n) => async (d) => (await httpsCallable(f, n)(d)).data;
    return {
      uid,
      bloquearPid: c('bloquearJogadorPorPublicId'),
      bloquearUid: c('bloquearJogador'),
      desbloquearPid: c('desbloquearJogadorPorPublicId'),
      desbloquearUid: c('desbloquearJogador'),
      listar: c('listarMeusBloqueios'),
      denunciar: c('registrarDenuncia'),
    };
  }

  /// Aplica um conjunto de escritas administrativas em lotes atomicos.
  async function semearLote(estado) {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const fs = ctx.firestore();
      let lote = writeBatch(fs);
      let n = 0;
      for (const [caminho, dados] of Object.entries(estado)) {
        if (dados === null) lote.delete(doc(fs, caminho));
        else lote.set(doc(fs, caminho), dados);
        if (++n === 450) { await lote.commit(); lote = writeBatch(fs); n = 0; }
      }
      if (n > 0) await lote.commit();
    });
  }

  async function ler(caminho) {
    let v;
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDoc(doc(ctx.firestore(), caminho));
      v = s.exists() ? s.data() : undefined;
    });
    return v;
  }

  async function contarBloqueios(dono) {
    let n;
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      n = (await getDocs(collection(ctx.firestore(), `users/${dono}/blocks`))).size;
    });
    return n;
  }

  /// A identidade publica de um uid, como functions-social a escreve.
  const identidade = (uid, pid) => ({
    [`playerIdentities/${uid}`]: { publicId: pid },
    [`publicIdIndex/${pid}`]: { publicId: pid, uid },
    [`publicProfiles/${pid}`]: { publicId: pid, apelido: `Alvo ${pid}`, avatarRef: null },
  });

  /// Um alvo semeado (nao precisa autenticar: so e bloqueado).
  async function alvo(rotulo, { comIdentidade = true } = {}) {
    const uid = rotulo ?? `c4alvo${String(++seq).padStart(6, '0')}`;
    const pid = novoPid();
    if (comIdentidade) await semearLote(identidade(uid, pid));
    return { uid, pid };
  }

  const caminhoCorte = (x, y) => `cortesDeRelacao/${[x, y].sort().join('|')}`;

  /// Nenhuma chave privada, em profundidade, e nenhum UID no texto da resposta.
  function semPrivado(resposta, uids) {
    const achar = (v, p) => {
      if (Array.isArray(v)) return v.flatMap((x, i) => achar(x, `${p}[${i}]`));
      if (v === null || typeof v !== 'object') return [];
      return Object.entries(v).flatMap(([k, x]) => [
        ...(PRIVADAS.includes(k) ? [`${p}.${k}`] : []), ...achar(x, `${p}.${k}`),
      ]);
    };
    assert.deepEqual(achar(resposta, ''), [], 'chave privada na resposta');
    const texto = JSON.stringify(resposta);
    for (const u of uids) assert.equal(texto.includes(u), false, 'UID no texto da resposta');
  }

  const recusa = (codigo, http) => (e) => {
    assert.equal(e.details?.recusa, codigo, `esperava ${codigo}, veio ${e.details?.recusa} (${e.code})`);
    if (http) assert.equal(e.code, `functions/${http}`);
    return true;
  };

  /// Decodifica um cursor como qualquer cliente poderia.
  const decodificar = (c) => JSON.parse(Buffer.from(c, 'base64url').toString('utf8'));
  const cursorForjado = (partes) => Buffer.from(JSON.stringify(partes), 'utf8').toString('base64url');

  // ------------------------------------------------- bloquear (O10)

  test('M01 — bloquear por publicId grava o bloqueio no formato de hoje e o corte do par', async () => {
    const a = await jogador('m01');
    const b = await alvo();
    const r = await a.bloquearPid({ publicId: b.pid });
    assert.deepEqual(r, { bloqueado: true });
    semPrivado(r, [a.uid, b.uid]);

    const bl = await ler(`users/${a.uid}/blocks/${b.uid}`);
    assert.deepEqual(Object.keys(bl).sort(), ['bloqueadoUid', 'bloqueadorUid', 'criadoEm', 'esquema']);
    assert.equal(bl.bloqueadorUid, a.uid);
    assert.equal(bl.bloqueadoUid, b.uid);
    assert.equal(bl.esquema, 1);
    assert.equal(typeof bl.criadoEm.toMillis, 'function', 'criadoEm e Timestamp do servidor');

    const ct = await ler(caminhoCorte(a.uid, b.uid));
    assert.deepEqual(Object.keys(ct).sort(), ['atualizadoEm', 'corteId', 'esquema', 'membros']);
    assert.match(ct.corteId, /^[A-Za-z0-9_-]{22}$/);
    assert.deepEqual(ct.membros, [a.uid, b.uid].sort());
    assert.equal(ct.esquema, 1);
    assert.ok(!Number.isNaN(Date.parse(ct.atualizadoEm)));
  });

  test('M02/S32d — bloquear pelo UID legado grava o MESMO par de documentos, no mesmo formato', async () => {
    const a = await jogador('m02');
    const b = await alvo();
    assert.deepEqual(await a.bloquearUid({ bloqueadoUid: b.uid }), { bloqueado: true });
    const bl = await ler(`users/${a.uid}/blocks/${b.uid}`);
    assert.deepEqual(Object.keys(bl).sort(), ['bloqueadoUid', 'bloqueadorUid', 'criadoEm', 'esquema']);
    assert.equal(bl.bloqueadoUid, b.uid);
    const ct = await ler(caminhoCorte(a.uid, b.uid));
    assert.deepEqual(Object.keys(ct).sort(), ['atualizadoEm', 'corteId', 'esquema', 'membros']);
    assert.match(ct.corteId, /^[A-Za-z0-9_-]{22}$/);
    assert.deepEqual(ct.membros, [a.uid, b.uid].sort());
  });

  test('M03/DT-01 — repetir o bloqueio vigente, pelos dois caminhos e em paralelo, nao escreve: mesmo corte e mesmo criadoEm', async () => {
    const a = await jogador('m03');
    const b = await alvo();
    // Primeira inclusao com cinco chamadas simultaneas: UM bloqueio, UM corte.
    const primeiras = await Promise.all([
      a.bloquearPid({ publicId: b.pid }), a.bloquearUid({ bloqueadoUid: b.uid }),
      a.bloquearPid({ publicId: b.pid }), a.bloquearUid({ bloqueadoUid: b.uid }),
      a.bloquearPid({ publicId: b.pid }),
    ]);
    for (const r of primeiras) assert.deepEqual(r, { bloqueado: true });
    assert.equal(await contarBloqueios(a.uid), 1);
    const bl = await ler(`users/${a.uid}/blocks/${b.uid}`);
    const ct = await ler(caminhoCorte(a.uid, b.uid));

    const repeticoes = await Promise.all([
      a.bloquearPid({ publicId: b.pid }), a.bloquearUid({ bloqueadoUid: b.uid }),
      a.bloquearPid({ publicId: b.pid }), a.bloquearUid({ bloqueadoUid: b.uid }),
      a.bloquearPid({ publicId: b.pid }),
    ]);
    for (const r of repeticoes) assert.deepEqual(r, { bloqueado: true });
    const bl2 = await ler(`users/${a.uid}/blocks/${b.uid}`);
    assert.equal(bl2.criadoEm.seconds, bl.criadoEm.seconds, 'criadoEm intocado');
    assert.equal(bl2.criadoEm.nanoseconds, bl.criadoEm.nanoseconds, 'criadoEm intocado');
    assert.deepEqual(await ler(caminhoCorte(a.uid, b.uid)), ct, 'o corte da repeticao e o mesmo');
    assert.equal(await contarBloqueios(a.uid), 1);
  });

  test('M04 — bloqueio cruzado grava bloqueio e corte novos e mantem o primeiro bloqueio', async () => {
    const a = await jogador('m04a');
    const pidA = novoPid();
    await semearLote(identidade(a.uid, pidA));
    const b = await jogador('m04b');
    const pidB = novoPid();
    await semearLote(identidade(b.uid, pidB));
    await a.bloquearPid({ publicId: pidB });
    const corte1 = await ler(caminhoCorte(a.uid, b.uid));
    assert.deepEqual(await b.bloquearPid({ publicId: pidA }), { bloqueado: true });
    const corte2 = await ler(caminhoCorte(a.uid, b.uid));
    assert.notEqual(corte2.corteId, corte1.corteId, 'o segundo bloqueio e documento novo: corte novo');
    assert.ok(await ler(`users/${a.uid}/blocks/${b.uid}`), 'A -> B intacto');
    assert.ok(await ler(`users/${b.uid}/blocks/${a.uid}`));
  });

  // ------------------------------------------------- desbloquear (O15)

  test('M05 — desbloquear por publicId duas vezes apaga o bloqueio e NUNCA toca o corte', async () => {
    const a = await jogador('m05');
    const b = await alvo();
    await a.bloquearPid({ publicId: b.pid });
    const corte = await ler(caminhoCorte(a.uid, b.uid));
    const r1 = await a.desbloquearPid({ publicId: b.pid });
    const r2 = await a.desbloquearPid({ publicId: b.pid });
    assert.deepEqual(r1, { desbloqueado: true });
    assert.deepEqual(r2, { desbloqueado: true });
    semPrivado(r1, [a.uid, b.uid]);
    assert.equal(await ler(`users/${a.uid}/blocks/${b.uid}`), undefined);
    assert.deepEqual(await ler(caminhoCorte(a.uid, b.uid)), corte, 'desbloquear nao apaga o corte');
  });

  test('M06/DT-05 — desbloquear publicId malformado ou inexistente responde neutro e nao escreve', async () => {
    const a = await jogador('m06');
    const b = await alvo();
    await a.bloquearPid({ publicId: b.pid });
    assert.deepEqual(await a.desbloquearPid({ publicId: 'nao e publicId' }), { desbloqueado: true });
    assert.deepEqual(await a.desbloquearPid({ publicId: novoPid() }), { desbloqueado: true });
    assert.deepEqual(await a.desbloquearPid({}), { desbloqueado: true });
    assert.equal(await contarBloqueios(a.uid), 1, 'o bloqueio existente continua');
  });

  // ------------------------------------------------- lista (O15) e cursor

  const cursoresVistos = [];
  const uidsVistos = [];

  test('M07 — lista propria: ordem criadoEm DESC, apelido fresco, item sem identidade omitido, so do dono', async () => {
    const a = await jogador('m07');
    const outro = await jogador('m07b');
    const b1 = await alvo();
    const b2 = await alvo();
    const semId = await alvo(undefined, { comIdentidade: false });
    const b3 = await alvo();
    await a.bloquearPid({ publicId: b1.pid });
    await a.bloquearPid({ publicId: b2.pid });
    await a.bloquearUid({ bloqueadoUid: semId.uid });
    await a.bloquearPid({ publicId: b3.pid });
    await semearLote({ [`publicProfiles/${b2.pid}`]: { publicId: b2.pid, apelido: 'Apelido Novo', avatarRef: 'av1' } });

    const r = await a.listar({});
    semPrivado(r, [a.uid, b1.uid, b2.uid, b3.uid, semId.uid]);
    assert.deepEqual(r.itens.map((i) => i.publicId), [b3.pid, b2.pid, b1.pid]);
    assert.deepEqual(Object.keys(r.itens[0]).sort(), ['apelido', 'avatarRef', 'bloqueadoEm', 'publicId']);
    assert.equal(r.itens[1].apelido, 'Apelido Novo');
    assert.equal(r.itens[1].avatarRef, 'av1');
    assert.ok(!Number.isNaN(Date.parse(r.itens[0].bloqueadoEm)));
    assert.equal(r.proximoCursor, null, 'a consulta esgotou');
    assert.deepEqual((await outro.listar({})).itens, [], 'a lista e so do dono');
  });

  /// Dono com bloqueios semeados no MESMO instante exato (montagem do teste).
  const T = { s: 1767225600, ns: 123456000 };
  async function empate(dono, rotulos, instante = T) {
    const { Timestamp } = require('firebase/firestore');
    const alvos = [];
    const estado = {};
    for (const rotulo of rotulos) {
      const x = { uid: rotulo, pid: novoPid() };
      alvos.push(x);
      Object.assign(estado, identidade(x.uid, x.pid));
      estado[`users/${dono}/blocks/${x.uid}`] = {
        bloqueadorUid: dono, bloqueadoUid: x.uid,
        criadoEm: new Timestamp(instante.s, instante.ns), esquema: 1,
      };
    }
    await semearLote(estado);
    uidsVistos.push(dono, ...alvos.map((x) => x.uid));
    return alvos;
  }
  /// Ordem esperada: mesmo instante -> id do documento DESC.
  const ordemDesc = (alvos) => [...alvos].sort((x, y) => (x.uid < y.uid ? 1 : -1));

  test('M08/R2 — empate exato + remocao ANTES da ancora: nenhum item pulado nem repetido', async () => {
    const a = await jogador('m08');
    const alvos = ordemDesc(await empate(a.uid, ['c4m08x1', 'c4m08x2', 'c4m08x3', 'c4m08x4']));
    const p1 = await a.listar({ limite: 2 });
    assert.deepEqual(p1.itens.map((i) => i.publicId), [alvos[0].pid, alvos[1].pid]);
    assert.ok(p1.proximoCursor);
    cursoresVistos.push(p1.proximoCursor);
    // Remove o PRIMEIRO entregue (antes da ancora). Com deslocamento, C sumiria.
    await a.desbloquearPid({ publicId: alvos[0].pid });
    const p2 = await a.listar({ limite: 2, cursor: p1.proximoCursor });
    assert.deepEqual(p2.itens.map((i) => i.publicId), [alvos[2].pid, alvos[3].pid]);
    if (p2.proximoCursor) cursoresVistos.push(p2.proximoCursor);
    const p3 = p2.proximoCursor ? await a.listar({ limite: 2, cursor: p2.proximoCursor }) : { itens: [], proximoCursor: null };
    assert.deepEqual(p3.itens, []);
    assert.equal(p3.proximoCursor, null);
  });

  test('M09/R2 — inclusao no empate depois da ancora aparece uma vez; antes da ancora nao repete nada', async () => {
    const a = await jogador('m09');
    const alvos = ordemDesc(await empate(a.uid, ['c4m09x1', 'c4m09x2', 'c4m09x3', 'c4m09x4']));
    const p1 = await a.listar({ limite: 2 });
    cursoresVistos.push(p1.proximoCursor);
    assert.deepEqual(p1.itens.map((i) => i.publicId), [alvos[0].pid, alvos[1].pid]);
    // 'c4m09x25' cai entre a ancora (x3) e x2; 'c4m09x5' cai antes de x4.
    const [depois, antes] = await empate(a.uid, ['c4m09x25', 'c4m09x5']);
    const p2 = await a.listar({ limite: 10, cursor: p1.proximoCursor });
    assert.deepEqual(p2.itens.map((i) => i.publicId), [depois.pid, alvos[2].pid, alvos[3].pid]);
    assert.equal(p2.itens.some((i) => i.publicId === antes.pid), false);
    assert.equal(p2.proximoCursor, null);
  });

  test('M10/R2 — ancora removida: a posicao continua valendo pelos valores', async () => {
    const a = await jogador('m10');
    const alvos = ordemDesc(await empate(a.uid, ['c4m10x1', 'c4m10x2', 'c4m10x3', 'c4m10x4']));
    const p1 = await a.listar({ limite: 2 });
    cursoresVistos.push(p1.proximoCursor);
    await a.desbloquearPid({ publicId: alvos[1].pid }); // a propria ancora
    const p2 = await a.listar({ limite: 2, cursor: p1.proximoCursor });
    assert.deepEqual(p2.itens.map((i) => i.publicId), [alvos[2].pid, alvos[3].pid]);
  });

  test('M11/R2 — ancora sem identidade resolvivel: retomada inclusiva, nenhuma omissao, repeticao so do empate', async () => {
    const a = await jogador('m11');
    const alvos = ordemDesc(await empate(a.uid, ['c4m11x1', 'c4m11x2', 'c4m11x3', 'c4m11x4']));
    const [anterior] = await empate(a.uid, ['c4m11y'], { s: T.s - 60, ns: 0 });
    const p1 = await a.listar({ limite: 2 });
    cursoresVistos.push(p1.proximoCursor);
    // A identidade da ancora deixa de resolver (indice reverso apagado).
    await semearLote({ [`publicIdIndex/${alvos[1].pid}`]: null });
    const p2 = await a.listar({ limite: 10, cursor: p1.proximoCursor });
    const vistos = p2.itens.map((i) => i.publicId);
    for (const x of [alvos[2], alvos[3], anterior]) {
      assert.ok(vistos.includes(x.pid), 'nenhum item depois da ancora e omitido');
    }
    const empatados = new Set(alvos.map((x) => x.pid));
    for (const pid of vistos.filter((p) => p === alvos[0].pid || p === alvos[1].pid)) {
      assert.ok(empatados.has(pid), 'so itens do mesmo instante podem repetir');
    }
    assert.equal(vistos[vistos.length - 1], anterior.pid, 'o item mais antigo vem por ultimo');
  });

  test('M12/R2 — cursor decodificado nao carrega UID; cursor invalido -> invalid-argument/cursorInvalido', async () => {
    assert.ok(cursoresVistos.length >= 4);
    for (const c of cursoresVistos) {
      const partes = decodificar(c);
      assert.equal(partes.length, 4);
      assert.equal(partes[0], 'b1');
      assert.equal(Number.isInteger(partes[1]) && Number.isInteger(partes[2]), true);
      assert.match(partes[3], /^P[0-9A-Z]{12}$/);
      const texto = Buffer.from(c, 'base64url').toString('utf8');
      for (const u of uidsVistos) {
        assert.equal(texto.includes(u), false, 'UID dentro do cursor');
      }
    }
    const a = await jogador('m12');
    const invalidos = [
      'nao-e-cursor',
      cursorForjado(['b1', T.s, T.ns, null]),
      cursorForjado(['b0', T.s, T.ns, 'PC40000000000']),
      cursorForjado(['b1', 1.5, 0, 'PC40000000000']),
      cursorForjado(['b1', T.s, 1e9, 'PC40000000000']),
      cursorForjado(['b1', T.s, T.ns, 'PC40000000000', 'extra']),
      cursorForjado(['b1', 1e15, 0, 'PC40000000000']),
      12345,
    ];
    for (const cursor of invalidos) {
      await assert.rejects(() => a.listar({ cursor }), recusa('cursorInvalido', 'invalid-argument'));
    }
  });

  // ------------------------------------------------- C-01: varredura incompleta

  test('C-01 (pagina pequena) — orcamento esgotado em itens sem identidade no mesmo instante: erro explicito, nenhum cursor; depois da limpeza, o valido aparece', async () => {
    const a = await jogador('c01a');
    // 12 sem identidade (z..) vem antes do valido (a..) na ordem DESC; com
    // limite 2 o orcamento e 4 x 3 = 12 documentos.
    const semId = Array.from({ length: 12 }, (_, i) => `c4c01z${String(i).padStart(2, '0')}`);
    const estado = {};
    const { Timestamp } = require('firebase/firestore');
    for (const u of semId) {
      estado[`users/${a.uid}/blocks/${u}`] = {
        bloqueadorUid: a.uid, bloqueadoUid: u, criadoEm: new Timestamp(T.s, T.ns), esquema: 1,
      };
    }
    await semearLote(estado);
    const [valido] = await empate(a.uid, ['c4c01a']);
    await assert.rejects(() => a.listar({ limite: 2 }), recusa('varreduraIncompleta', 'unavailable'));
    // Limpeza dos registros indisponiveis; o chamador tenta de novo.
    await semearLote(Object.fromEntries(semId.map((u) => [`users/${a.uid}/blocks/${u}`, null])));
    const r = await a.listar({ limite: 2 });
    assert.deepEqual(r.itens.map((i) => i.publicId), [valido.pid]);
    assert.equal(r.proximoCursor, null);
  });

  test('C-01 (com cursor, pagina pequena) — o cursor so avanca ate o ultimo entregue; sem ancora segura, erro; o cursor anterior alcanca o valido depois da limpeza', async () => {
    const a = await jogador('c01b');
    const [primeiro] = await empate(a.uid, ['c4c02zz']);
    const semId = Array.from({ length: 12 }, (_, i) => `c4c02y${String(i).padStart(2, '0')}`);
    const estado = {};
    const { Timestamp } = require('firebase/firestore');
    for (const u of semId) {
      estado[`users/${a.uid}/blocks/${u}`] = {
        bloqueadorUid: a.uid, bloqueadoUid: u, criadoEm: new Timestamp(T.s, T.ns), esquema: 1,
      };
    }
    await semearLote(estado);
    const [ultimo] = await empate(a.uid, ['c4c02a']);

    const p1 = await a.listar({ limite: 2 });
    assert.deepEqual(p1.itens.map((i) => i.publicId), [primeiro.pid]);
    assert.ok(p1.proximoCursor, 'nao esgotou: ha cursor, ancorado no ultimo entregue');
    assert.equal(decodificar(p1.proximoCursor)[3], primeiro.pid);
    await assert.rejects(() => a.listar({ limite: 2, cursor: p1.proximoCursor }),
      recusa('varreduraIncompleta', 'unavailable'));
    await semearLote(Object.fromEntries(semId.map((u) => [`users/${a.uid}/blocks/${u}`, null])));
    const p2 = await a.listar({ limite: 2, cursor: p1.proximoCursor });
    assert.deepEqual(p2.itens.map((i) => i.publicId), [ultimo.pid], 'sem omissao silenciosa');
    assert.equal(p2.proximoCursor, null);
  });

  test('C-01 (pagina padrao) — o mesmo com limite padrao: orcamento 4 x 26 sem identidade -> erro; limpeza -> valido', async () => {
    const a = await jogador('c01c');
    const semId = Array.from({ length: 104 }, (_, i) => `c4c03z${String(i).padStart(3, '0')}`);
    const estado = {};
    const { Timestamp } = require('firebase/firestore');
    for (const u of semId) {
      estado[`users/${a.uid}/blocks/${u}`] = {
        bloqueadorUid: a.uid, bloqueadoUid: u, criadoEm: new Timestamp(T.s, T.ns), esquema: 1,
      };
    }
    await semearLote(estado);
    const [valido] = await empate(a.uid, ['c4c03a']);
    await assert.rejects(() => a.listar({}), recusa('varreduraIncompleta', 'unavailable'));
    await semearLote(Object.fromEntries(semId.map((u) => [`users/${a.uid}/blocks/${u}`, null])));
    assert.deepEqual((await a.listar({})).itens.map((i) => i.publicId), [valido.pid]);
  });

  test('C-01 — a consulta realmente esgota sem item visivel: [] e proximoCursor null sao legitimos', async () => {
    const a = await jogador('c01d');
    const { Timestamp } = require('firebase/firestore');
    await semearLote({
      [`users/${a.uid}/blocks/c4c04z1`]: { bloqueadorUid: a.uid, bloqueadoUid: 'c4c04z1', criadoEm: new Timestamp(T.s, T.ns), esquema: 1 },
      [`users/${a.uid}/blocks/c4c04z2`]: { bloqueadorUid: a.uid, bloqueadoUid: 'c4c04z2', criadoEm: new Timestamp(T.s, T.ns), esquema: 1 },
    });
    const r = await a.listar({ limite: 2 });
    assert.deepEqual(r, { itens: [], proximoCursor: null });
  });

  // ------------------------------------------------- plano, diarios e teto

  test('M13/S20 — jogador GRATUITO bloqueia, lista, desbloqueia e denuncia por publicId', async () => {
    const a = await jogador('m13');
    const b = await alvo();
    assert.equal(await ler(`playerEntitlements/${a.uid}`), undefined, 'sem entitlement');
    assert.deepEqual(await a.bloquearPid({ publicId: b.pid }), { bloqueado: true });
    assert.deepEqual((await a.listar({})).itens.map((i) => i.publicId), [b.pid]);
    assert.deepEqual(await a.desbloquearPid({ publicId: b.pid }), { desbloqueado: true });
    const d = await a.denunciar({
      denunciadoPublicId: b.pid, tipo: 'perfil', categoria: 'nomeOfensivo', reportIntentId: 'c4m13',
    });
    assert.equal(d.registrada, true);
  });

  test('M14/S23c/S30c — diario no BLOQUEADO: publicId -> alvoNaoResolvido; UID -> neutro; nenhum bloqueio nem corte', async () => {
    const a = await jogador('m14');
    const b = await alvo();
    await semearLote({ [`accountDeletions/${b.uid}`]: { estado: 'iniciada', esquema: 1 } });
    await assert.rejects(() => a.bloquearPid({ publicId: b.pid }), recusa('alvoNaoResolvido', 'invalid-argument'));
    assert.deepEqual(await a.bloquearUid({ bloqueadoUid: b.uid }), { bloqueado: true });
    assert.equal(await ler(`users/${a.uid}/blocks/${b.uid}`), undefined);
    assert.equal(await ler(caminhoCorte(a.uid, b.uid)), undefined);
  });

  test('M15 — diario no BLOQUEADOR (dono): os dois caminhos e a lista recusam acaoIndisponivel, sem escrita', async () => {
    const a = await jogador('m15');
    const b = await alvo();
    await semearLote({ [`accountDeletions/${a.uid}`]: { estado: 'iniciada', esquema: 1 } });
    await assert.rejects(() => a.bloquearPid({ publicId: b.pid }), recusa('acaoIndisponivel', 'failed-precondition'));
    await assert.rejects(() => a.bloquearUid({ bloqueadoUid: b.uid }), recusa('acaoIndisponivel', 'failed-precondition'));
    await assert.rejects(() => a.listar({}), recusa('acaoIndisponivel', 'failed-precondition'));
    assert.equal(await contarBloqueios(a.uid), 0);
    assert.equal(await ler(caminhoCorte(a.uid, b.uid)), undefined);
  });

  // r3 (run 43342070243): com 24 alvos fixos o diario chegou depois de a
  // ultima chamada terminar (0 recusadas) — a prova de nao-escrita passou, a de
  // sobreposicao nao. Agora os trabalhadores SEGUEM chamando ate haver chamadas
  // iniciadas depois do commit do diario, e a foto le um SUBCONJUNTO DECLARADO
  // (os 3 primeiros alvos, ja gravados, e a cauda ainda nao alcancada), que nao
  // disputa as chamadas em andamento.
  test('M16/S23c — diario criado EM VOO: cada bloqueio e (bloqueio + corte) antes do diario ou nenhuma escrita', async (t) => {
    const a = await jogador('m16');
    const alvos = Array.from({ length: 120 }, (_, i) => ({
      uid: `c4m16${a.uid.slice(0, 6)}t${String(i).padStart(3, '0')}`, pid: novoPid(),
    }));
    const preparo = {};
    for (const x of alvos) Object.assign(preparo, identidade(x.uid, x.pid));
    await semearLote(preparo);
    const observados = alvos.filter((_, i) => i < 3 || i >= 60);
    const caminhosDe = (x) => [`users/${a.uid}/blocks/${x.uid}`, caminhoCorte(a.uid, x.uid)];

    const chamadas = [];
    let proximo = 0;
    let diarioEm = null;
    const posDiario = () => chamadas.filter((c) => diarioEm !== null && c.ini > diarioEm).length;
    const trabalhador = async () => {
      while (proximo < alvos.length && !(diarioEm !== null && posDiario() >= 6)) {
        const i = proximo++;
        const x = alvos[i];
        const ini = performance.now();
        let desfecho;
        try {
          await (i % 2 === 0 ? a.bloquearPid({ publicId: x.pid }) : a.bloquearUid({ bloqueadoUid: x.uid }));
          desfecho = 'ok';
        } catch (e) {
          assert.equal(e.details?.recusa, 'acaoIndisponivel');
          desfecho = 'recusado';
        }
        chamadas.push({ i, ini, fim: performance.now(), desfecho });
      }
    };
    // O diario nasce por uma TRANSACAO do teste que le o conjunto observado
    // (bloqueios e cortes, inclusive os ainda ausentes): o que ela le e o estado
    // exato no instante do diario.
    let foto;
    const criarDiario = async () => {
      while (chamadas.length < 3) await new Promise((r) => setTimeout(r, 5));
      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        await runTransaction(fs, async (tx) => {
          const lido = {};
          await Promise.all(observados.flatMap(caminhosDe).map(async (c) => {
            lido[c] = (await tx.get(doc(fs, c))).exists();
          }));
          tx.set(doc(fs, `accountDeletions/${a.uid}`), { estado: 'iniciada', esquema: 1 });
          foto = lido;
        }, { maxAttempts: 25 });
      });
      diarioEm = performance.now();
    };
    await Promise.all([criarDiario(), trabalhador(), trabalhador(), trabalhador(), trabalhador()]);

    for (const x of alvos) {
      const [bloqueio, corte] = await Promise.all(caminhosDe(x).map(async (c) => !!(await ler(c))));
      assert.equal(bloqueio, corte, 'nunca bloqueio sem corte nem corte sem bloqueio');
    }
    for (const x of observados) {
      for (const c of caminhosDe(x)) {
        assert.equal(!!(await ler(c)), foto[c], `nada foi escrito depois do diario: ${c}`);
      }
    }
    const depois = chamadas.filter((c) => c.ini > diarioEm);
    assert.ok(depois.length >= 1, 'houve chamadas iniciadas depois do diario');
    for (const c of depois) {
      assert.equal(c.desfecho, 'recusado', 'toda chamada iniciada depois do diario recusa');
      assert.equal(await ler(`users/${a.uid}/blocks/${alvos[c.i].uid}`), undefined);
      assert.equal(await ler(caminhoCorte(a.uid, alvos[c.i].uid)), undefined);
    }
    assert.ok(chamadas.some((c) => c.desfecho === 'ok' && c.fim < diarioEm), 'chamadas antes do diario gravaram');
    const sobrepostas = chamadas.filter((c) => c.ini < diarioEm && c.fim > diarioEm).length;
    t.diagnostic(`M16: ${chamadas.length} chamadas, ${sobrepostas} em voo no commit do diario, `
      + `${depois.length} iniciadas depois (todas recusadas), `
      + `${chamadas.filter((c) => c.desfecho === 'ok').length} gravadas antes`);
  });

  test('M17/S38 — ator no teto de ritmo de seguir: bloquear, desbloquear e denunciar passam (a Moderacao nao le ritmo)', async () => {
    const a = await jogador('m17');
    const b = await alvo();
    const agora = Date.now();
    await semearLote({
      [`playerSocialRitmo/${a.uid}`]: {
        criacoes: Array.from({ length: 30 }, (_, i) => new Date(agora - i * 1000).toISOString()),
        pedidosPendentesEnviados: 100, esquema: 1,
      },
    });
    assert.deepEqual(await a.bloquearPid({ publicId: b.pid }), { bloqueado: true });
    assert.deepEqual(await a.desbloquearPid({ publicId: b.pid }), { desbloqueado: true });
    const d = await a.denunciar({
      denunciadoPublicId: b.pid, tipo: 'perfil', categoria: 'nomeOfensivo', reportIntentId: 'c4m17',
    });
    assert.equal(d.registrada, true);
  });

  test('M18/DT-04 — identificador invalido: UID com | -> failed-precondition/identificadorInvalido (como antes); publicId malformado -> alvoNaoResolvido; sem escrita', async () => {
    const a = await jogador('m18');
    await assert.rejects(() => a.bloquearUid({ bloqueadoUid: 'abc|def' }),
      recusa('identificadorInvalido', 'failed-precondition'));
    await assert.rejects(() => a.bloquearUid({ bloqueadoUid: a.uid }),
      recusa('autoBloqueio', 'failed-precondition'));
    await assert.rejects(() => a.bloquearPid({ publicId: '!!' }),
      recusa('alvoNaoResolvido', 'invalid-argument'));
    await assert.rejects(() => a.bloquearPid({ publicId: novoPid() }),
      recusa('alvoNaoResolvido', 'invalid-argument'));
    assert.equal(await contarBloqueios(a.uid), 0);
  });

  test('M19/R5 — no teto de 500: repetir pelos dois caminhos converge sem escrita; inclusao NOVA recusa limiteAtingido', async () => {
    const a = await jogador('m19');
    const b = await alvo();
    const c = await alvo();
    const estado = {};
    const instante = new Date('2026-03-01T00:00:00.000Z');
    estado[`users/${a.uid}/blocks/${b.uid}`] = {
      bloqueadorUid: a.uid, bloqueadoUid: b.uid, criadoEm: instante, esquema: 1,
    };
    for (let i = 0; i < 499; i++) {
      const u = `c4m19t${String(i).padStart(3, '0')}`;
      estado[`users/${a.uid}/blocks/${u}`] = {
        bloqueadorUid: a.uid, bloqueadoUid: u, criadoEm: instante, esquema: 1,
      };
    }
    await semearLote(estado);
    assert.equal(await contarBloqueios(a.uid), 500);
    const antes = await ler(`users/${a.uid}/blocks/${b.uid}`);

    assert.deepEqual(await a.bloquearPid({ publicId: b.pid }), { bloqueado: true });
    assert.deepEqual(await a.bloquearUid({ bloqueadoUid: b.uid }), { bloqueado: true });
    const depois = await ler(`users/${a.uid}/blocks/${b.uid}`);
    assert.equal(depois.criadoEm.seconds, antes.criadoEm.seconds);
    assert.equal(depois.criadoEm.nanoseconds, antes.criadoEm.nanoseconds);
    assert.equal(await ler(caminhoCorte(a.uid, b.uid)), undefined,
      'a repeticao nao escreve: nem o corte que o bloqueio semeado nao tinha');

    await assert.rejects(() => a.bloquearPid({ publicId: c.pid }), recusa('limiteAtingido', 'failed-precondition'));
    await assert.rejects(() => a.bloquearUid({ bloqueadoUid: c.uid }), recusa('limiteAtingido', 'failed-precondition'));
    assert.equal(await ler(`users/${a.uid}/blocks/${c.uid}`), undefined);
    assert.equal(await ler(caminhoCorte(a.uid, c.uid)), undefined);
    assert.equal(await contarBloqueios(a.uid), 500);
  });

  test('sem autenticacao, as tres callables novas sao recusadas', async () => {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, 'c4-anonimo');
    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const f = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(f, host, Number(porta));
    for (const nome of ['bloquearJogadorPorPublicId', 'desbloquearJogadorPorPublicId', 'listarMeusBloqueios']) {
      await assert.rejects(() => httpsCallable(f, nome)({ publicId: 'PC40000000000' }),
        (e) => e.code === 'functions/unauthenticated', nome);
    }
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
