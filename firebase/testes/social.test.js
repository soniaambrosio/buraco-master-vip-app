// social.test.js — prova as regras do BLOCO 6/6 e as Functions sociais.
//
// O QUE ESTE ARQUIVO PROVA, e que o teste em Dart nao consegue provar: quem LE e
// quem ESCREVE. O dominio Dart decide se um apelido e valido e quem pode aceitar
// uma solicitacao; a REGRA decide se um aplicativo modificado consegue escrever
// a amizade direto no banco, pulando a Function inteira. Sao perguntas
// diferentes, e so a segunda responde a §33.
//
// DUAS SUITES NUM ARQUIVO SO, e a divisao esta marcada no meio:
//
//   REGRAS ..... rodam com `--only firestore`. Sem Java para Functions, sem
//                `dart compile js`, sem tsc.
//   FUNCTIONS .. rodam SOMENTE quando `FUNCTIONS_EMULATOR_HOST` existe. Sao as
//                que provam idempotencia, concorrencia e ausencia de UID nas
//                RESPOSTAS — coisas que regra nenhuma alcanca.
//
// A separacao e a mesma de moderacao.test.js, e existe para que o portao de CI
// que so tem Firestore continue provando alguma coisa em vez de pular tudo.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador-regras                 # so as regras
//   npm run emulador:social                 # regras + Functions do codebase social
//
// Numa maquina sem Java no PATH mas com Android Studio instalado:
//   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run emulador-regras

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

const ANA = 'uidAna';
const BIA = 'uidBia';
const CAIO = 'uidCaio';
const ADMIN = 'uidAdminSocial';

const PID_ANA = 'P0123456789AB';
const PID_BIA = 'PCDEFGHJKMNPQ';
const PID_CAIO = 'PRSTVWXYZ0123';

// A chave do par e `uidMenor|uidMaior` — ver chaveDoPar em amizade.dart.
const PAR_ANA_BIA = [ANA, BIA].sort().join('|');
const PAR_ANA_CAIO = [ANA, CAIO].sort().join('|');

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
    const agora = new Date().toISOString();

    for (const [uid, pid] of [[ANA, PID_ANA], [BIA, PID_BIA], [CAIO, PID_CAIO]]) {
      await setDoc(doc(db, `playerIdentities/${uid}`), {
        uid, publicId: pid, criadoEm: agora, esquema: 1,
      });
      await setDoc(doc(db, `publicIdIndex/${pid}`), {
        publicId: pid, uid, criadoEm: agora, esquema: 1,
      });
      // A FORMA EXATA que `perfilPublicoInicial` produz. Nao ha `uid` aqui, e
      // essa ausencia e o contrato inteiro do documento.
      await setDoc(doc(db, `publicProfiles/${pid}`), {
        publicId: pid,
        apelido: uid === ANA ? 'Ana' : uid === BIA ? 'Bia' : 'Caio',
        apelidoOrdenacao: uid === ANA ? 'ana' : uid === BIA ? 'bia' : 'caio',
        avatarRef: null,
        estado: 'ativo',
        criadoEm: agora,
        atualizadoEm: agora,
        esquema: 1,
      });
      await setDoc(doc(db, `playerSocial/${uid}`), {
        uid, amigos: 1, solicitacoesEnviadas: 1, atualizadoEm: agora,
      });
    }

    // Ana e Bia sao amigas.
    await setDoc(doc(db, `friendships/${PAR_ANA_BIA}`), {
      pairKey: PAR_ANA_BIA,
      membros: [ANA, BIA].sort(),
      estado: 'amigos',
      solicitanteUid: ANA,
      destinatarioUid: BIA,
      solicitadaEm: agora,
      amigosDesde: agora,
      publicIds: { [ANA]: PID_ANA, [BIA]: PID_BIA },
      esquema: 1,
    });
    await setDoc(doc(db, `users/${ANA}/friends/${BIA}`), {
      publicId: PID_BIA, apelidoOrdenacao: 'bia', amigosDesde: agora, esquema: 1,
    });
    await setDoc(doc(db, `users/${BIA}/friends/${ANA}`), {
      publicId: PID_ANA, apelidoOrdenacao: 'ana', amigosDesde: agora, esquema: 1,
    });

    // Ana pediu amizade a Caio; ainda pendente.
    await setDoc(doc(db, `friendships/${PAR_ANA_CAIO}`), {
      pairKey: PAR_ANA_CAIO,
      membros: [ANA, CAIO].sort(),
      estado: 'pendente',
      solicitanteUid: ANA,
      destinatarioUid: CAIO,
      solicitadaEm: agora,
      amigosDesde: null,
      publicIds: { [ANA]: PID_ANA, [CAIO]: PID_CAIO },
      esquema: 1,
    });
    await setDoc(doc(db, `users/${ANA}/friendRequests/${CAIO}`), {
      direcao: 'enviada', publicId: PID_CAIO, solicitadaEm: agora, esquema: 1,
    });
    await setDoc(doc(db, `users/${CAIO}/friendRequests/${ANA}`), {
      direcao: 'recebida', publicId: PID_ANA, solicitadaEm: agora, esquema: 1,
    });
  });
});

after(async () => {
  await ambiente.cleanup();
});

const comoAna = () => ambiente.authenticatedContext(ANA).firestore();
const comoBia = () => ambiente.authenticatedContext(BIA).firestore();
const comoCaio = () => ambiente.authenticatedContext(CAIO).firestore();
const comoAdmin = () =>
  ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

// ===========================================================================
// PERFIL PUBLICO — o primeiro documento deliberadamente publico do banco
// ===========================================================================
describe('perfil publico: legivel por todos, escrito por ninguem', () => {
  test('qualquer autenticado le o perfil de qualquer um (§31-D)', async () => {
    // E o que sustenta `Ranking/Hall -> publicId -> Ver Perfil` sem UID.
    await assertSucceeds(getDoc(doc(comoCaio(), `publicProfiles/${PID_ANA}`)));
    await assertSucceeds(getDoc(doc(comoBia(), `publicProfiles/${PID_CAIO}`)));
  });

  test('sem login nao le perfil nenhum', async () => {
    await assertFails(getDoc(doc(semLogin(), `publicProfiles/${PID_ANA}`)));
  });

  test('o documento publico NAO carrega UID, e-mail nem Billing (§5, §31-F)', async () => {
    const s = await assertSucceeds(
      getDoc(doc(comoCaio(), `publicProfiles/${PID_ANA}`)),
    );
    const dados = s.data();
    for (const proibido of [
      'uid', 'userId', 'email', 'telefone', 'providerId', 'claims',
      'vip', 'billing', 'entitlement', 'assinatura', 'fichas',
      'reports', 'sanctions', 'playerModeration', 'suspensoAte', 'cpf',
    ]) {
      assert.equal(dados[proibido], undefined, `${proibido} vazou no perfil publico`);
    }
    // E a lista fechada de §5, conferida pelo outro lado: nada alem disto.
    assert.deepEqual(
      Object.keys(dados).sort(),
      ['apelido', 'apelidoOrdenacao', 'atualizadoEm', 'avatarRef', 'criadoEm',
        'esquema', 'estado', 'publicId'],
    );
  });

  test('o DONO nao escreve no proprio perfil publico (§11)', async () => {
    // Nao e desconfianca: a alteracao precisa normalizar o apelido e propagar a
    // chave de ordenacao para as projecoes dos amigos, e regra nao faz nem uma
    // coisa nem a outra.
    await assertFails(
      updateDoc(doc(comoAna(), `publicProfiles/${PID_ANA}`), { apelido: 'Outra' }),
    );
    await assertFails(deleteDoc(doc(comoAna(), `publicProfiles/${PID_ANA}`)));
  });

  test('ninguem escreve no perfil ALHEIO', async () => {
    await assertFails(
      updateDoc(doc(comoCaio(), `publicProfiles/${PID_ANA}`), { apelido: 'Hackeada' }),
    );
  });

  test('ninguem cria perfil publico a mao — nem com campo privado dentro', async () => {
    await assertFails(
      setDoc(doc(comoAna(), 'publicProfiles/PFORJADO00000'), {
        publicId: 'PFORJADO00000', apelido: 'Forjada', email: 'a@b.c', uid: ANA,
      }),
    );
  });

  test('nem o admin escreve pelo cliente', async () => {
    await assertFails(
      updateDoc(doc(comoAdmin(), `publicProfiles/${PID_ANA}`), { apelido: 'Admin' }),
    );
  });
});

// ===========================================================================
// IDENTIDADE — o publicId e imutavel e o mapa reverso e invisivel
// ===========================================================================
describe('identidade: o cliente nao escolhe nem muda o proprio publicId (§33)', () => {
  test('o dono le a propria identidade', async () => {
    const s = await assertSucceeds(getDoc(doc(comoAna(), `playerIdentities/${ANA}`)));
    assert.equal(s.data().publicId, PID_ANA);
  });

  test('ninguem le a identidade de terceiro (o mapa uid -> publicId)', async () => {
    await assertFails(getDoc(doc(comoCaio(), `playerIdentities/${ANA}`)));
    await assertFails(getDocs(collection(comoAna(), 'playerIdentities')));
  });

  test('o dono NAO muda o proprio publicId', async () => {
    // §36: "publicId e imutavel". Nem por update, nem por set, nem apagando.
    await assertFails(
      updateDoc(doc(comoAna(), `playerIdentities/${ANA}`), { publicId: PID_BIA }),
    );
    await assertFails(
      setDoc(doc(comoAna(), `playerIdentities/${ANA}`), {
        uid: ANA, publicId: 'PESCOLHIDO000',
      }),
    );
    await assertFails(deleteDoc(doc(comoAna(), `playerIdentities/${ANA}`)));
  });

  test('ninguem cria identidade para OUTRO UID', async () => {
    await assertFails(
      setDoc(doc(comoAna(), `playerIdentities/${CAIO}`), {
        uid: CAIO, publicId: 'PROUBADO00000',
      }),
    );
  });

  test('o mapa reverso publicId -> uid e negado a TODO cliente (§31-D)', async () => {
    // Este e o teste central da separacao entre identidade interna e publica: se
    // um jogador lesse aqui, converteria qualquer publicId visto no ranking no
    // UID correspondente, e o publicId deixaria de proteger coisa nenhuma.
    await assertFails(getDoc(doc(comoAna(), `publicIdIndex/${PID_ANA}`)));
    await assertFails(getDoc(doc(comoCaio(), `publicIdIndex/${PID_ANA}`)));
    await assertFails(getDocs(collection(comoAna(), 'publicIdIndex')));
    await assertFails(
      setDoc(doc(comoAna(), 'publicIdIndex/PFORJADO00000'), {
        publicId: 'PFORJADO00000', uid: ANA,
      }),
    );
  });

  test('o admin le o mapa reverso — suporte precisa dessa pergunta', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), `publicIdIndex/${PID_ANA}`)));
  });
});

// ===========================================================================
// GRAFO — o cliente nao adultera amizade
// ===========================================================================
describe('amizade: o cliente nao cria, nao aceita e nao remove pelo banco (§33)', () => {
  test('nem os MEMBROS leem a relacao canonica (§21)', async () => {
    // A relacao e deles, mas o documento carrega `membros`, `solicitanteUid` e
    // `destinatarioUid` — todos UIDs. Liberar a leitura entregaria o UID do
    // amigo a qualquer aplicativo modificado.
    await assertFails(getDoc(doc(comoAna(), `friendships/${PAR_ANA_BIA}`)));
    await assertFails(getDoc(doc(comoBia(), `friendships/${PAR_ANA_BIA}`)));
    await assertFails(getDocs(collection(comoCaio(), 'friendships')));
  });

  test('o admin le, para suporte', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), `friendships/${PAR_ANA_BIA}`)));
  });

  test('ninguem CRIA amizade direto no banco', async () => {
    // O ataque obvio: virar amigo de quem nunca aceitou.
    const par = [CAIO, BIA].sort().join('|');
    await assertFails(
      setDoc(doc(comoCaio(), `friendships/${par}`), {
        pairKey: par, membros: [CAIO, BIA].sort(), estado: 'amigos',
        solicitanteUid: CAIO, destinatarioUid: BIA,
      }),
    );
  });

  test('o SOLICITANTE nao aceita a propria solicitacao (§14)', async () => {
    // Ana pediu a Caio. Se ela pudesse promover a pendencia para `amigos`,
    // teria adicionado Caio sem que ele aceitasse.
    await assertFails(
      updateDoc(doc(comoAna(), `friendships/${PAR_ANA_CAIO}`), {
        estado: 'amigos', amigosDesde: new Date().toISOString(),
      }),
    );
  });

  test('terceiro nao aceita em nome de ninguem', async () => {
    await assertFails(
      updateDoc(doc(comoBia(), `friendships/${PAR_ANA_CAIO}`), { estado: 'amigos' }),
    );
  });

  test('ninguem forja o remetente de uma solicitacao', async () => {
    // Trocar `solicitanteUid` inverteria quem pode cancelar e quem pode aceitar.
    await assertFails(
      updateDoc(doc(comoCaio(), `friendships/${PAR_ANA_CAIO}`), {
        solicitanteUid: CAIO, destinatarioUid: ANA,
      }),
    );
  });

  test('ninguem remove amizade ALHEIA', async () => {
    await assertFails(deleteDoc(doc(comoCaio(), `friendships/${PAR_ANA_BIA}`)));
  });

  test('nem o proprio membro remove pelo banco', async () => {
    // Remover e legitimo — por `removerAmizade`, que apaga os dois lados e
    // acerta os contadores na mesma transacao. Pelo banco, apagaria so isto.
    await assertFails(deleteDoc(doc(comoAna(), `friendships/${PAR_ANA_BIA}`)));
  });
});

// ===========================================================================
// PROJECOES — o vazamento estaria na CHAVE, nao no valor
// ===========================================================================
describe('projecoes sociais: negadas ate ao dono (§21)', () => {
  test('o dono NAO lista os proprios amigos pelo banco', async () => {
    // O detalhe que se perde numa leitura rapida: o ID DO DOCUMENTO e o UID do
    // outro jogador. Um `list` aqui devolveria a lista de UIDs dos amigos sem
    // que nenhum CAMPO carregasse UID.
    await assertFails(getDocs(collection(comoAna(), `users/${ANA}/friends`)));
    await assertFails(getDoc(doc(comoAna(), `users/${ANA}/friends/${BIA}`)));
  });

  test('o dono NAO lista as proprias solicitacoes pelo banco', async () => {
    await assertFails(
      getDocs(collection(comoCaio(), `users/${CAIO}/friendRequests`)),
    );
  });

  test('terceiro tambem nao alcanca', async () => {
    await assertFails(getDocs(collection(comoCaio(), `users/${ANA}/friends`)));
    await assertFails(
      getDoc(doc(comoBia(), `users/${ANA}/friendRequests/${CAIO}`)),
    );
  });

  test('ninguem escreve projecao', async () => {
    await assertFails(
      setDoc(doc(comoCaio(), `users/${CAIO}/friends/${BIA}`), {
        publicId: PID_BIA, apelidoOrdenacao: 'bia',
      }),
    );
    await assertFails(deleteDoc(doc(comoAna(), `users/${ANA}/friends/${BIA}`)));
  });

  test('o admin alcanca, para suporte e reconciliacao', async () => {
    await assertSucceeds(getDocs(collection(comoAdmin(), `users/${ANA}/friends`)));
  });
});

// ===========================================================================
// CONTADORES — onde morreria a tentativa de furar o teto
// ===========================================================================
describe('contadores sociais (§25)', () => {
  test('o dono le os proprios', async () => {
    const s = await assertSucceeds(getDoc(doc(comoAna(), `playerSocial/${ANA}`)));
    assert.equal(s.data().amigos, 1);
  });

  test('ninguem le os de terceiro', async () => {
    await assertFails(getDoc(doc(comoCaio(), `playerSocial/${ANA}`)));
    await assertFails(getDocs(collection(comoAna(), 'playerSocial')));
  });

  test('o dono NAO zera o proprio contador para furar o teto', async () => {
    await assertFails(
      updateDoc(doc(comoAna(), `playerSocial/${ANA}`), { amigos: 0 }),
    );
    await assertFails(deleteDoc(doc(comoAna(), `playerSocial/${ANA}`)));
  });
});

// ===========================================================================
// MUTE E BLOQUEIO — o dominio de moderacao continua intacto (§18, §19)
// ===========================================================================
describe('nao-regressao: moderacao nao foi afrouxada nem duplicada', () => {
  test('nao existe segunda colecao de bloqueio', async () => {
    // §18 e §40: bloqueio paralelo ao existente esta proibido. Se alguem criar
    // uma, o fecho padrao a nega — e este teste e o alarme.
    for (const inventada of ['socialBlocks', 'blockedPlayers', 'bloqueiosSociais']) {
      await assertFails(getDoc(doc(comoAna(), `${inventada}/${BIA}`)));
      await assertFails(setDoc(doc(comoAna(), `${inventada}/${BIA}`), { x: 1 }));
    }
  });

  test('o bloqueio canonico continua onde estava, com as mesmas regras', async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${ANA}/blocks/${CAIO}`), {
        bloqueadorUid: ANA, bloqueadoUid: CAIO, criadoEm: new Date(), esquema: 1,
      });
    });
    await assertSucceeds(getDoc(doc(comoAna(), `users/${ANA}/blocks/${CAIO}`)));
    // O bloqueado continua sem descobrir que foi bloqueado.
    await assertFails(getDoc(doc(comoCaio(), `users/${ANA}/blocks/${CAIO}`)));
    await assertFails(
      setDoc(doc(comoAna(), `users/${ANA}/blocks/${BIA}`), {
        bloqueadorUid: ANA, bloqueadoUid: BIA,
      }),
    );
  });

  test('MUTE continua escrito pelo cliente e separado do grafo (§19)', async () => {
    // §19: mute nao remove amizade, nao vira bloqueio e nao altera o grafo. A
    // prova aqui e que o bloco social nao mexeu na regra de mute.
    const ref = doc(comoAna(), `users/${ANA}/mutes/${BIA}`);
    await assertSucceeds(setDoc(ref, { alvoUid: BIA, criadoEm: new Date() }));
    // E a amizade continua existindo depois do mute.
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDoc(doc(ctx.firestore(), `friendships/${PAR_ANA_BIA}`));
      assert.equal(s.data().estado, 'amigos', 'mute nao pode desfazer amizade');
    });
    await assertSucceeds(deleteDoc(ref));
  });

  test('o fecho padrao ainda nega caminho nao declarado', async () => {
    await assertFails(getDoc(doc(comoAna(), 'colecaoSocialInventada/doc1')));
    await assertFails(
      setDoc(doc(comoAna(), 'colecaoSocialInventada/doc1'), { x: 1 }),
    );
  });

  test('o terceiro bloco users/{uid} nao afrouxou inventario nem comprovante', async () => {
    // As regras avaliam TODOS os blocos que casam e concedem se qualquer um
    // conceder. Um `match /{documento=**}` dentro do bloco social teria aberto
    // inventario, comprovantes de denuncia e historico de partidas junto.
    await assertFails(
      getDoc(doc(comoCaio(), `users/${ANA}/inventory/pioneer_2026_crown`)),
    );
    await assertFails(
      getDocs(collection(comoCaio(), `users/${ANA}/reportReceipts`)),
    );
    await assertFails(
      getDocs(collection(comoCaio(), `users/${ANA}/matchHistory`)),
    );
  });
});

// ===========================================================================
// A PARTIR DAQUI e preciso o emulador de FUNCTIONS, alem do de Firestore.
// Cobre o que a REGRA nao alcanca: idempotencia, concorrencia, soberania do
// bloqueio e a AUSENCIA de UID nas respostas.
// ===========================================================================

const comFunctions = { skip: !process.env.FUNCTIONS_EMULATOR_HOST };

describe('Functions sociais', comFunctions, () => {
  const { initializeApp } = require('firebase/app');
  const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
  const {
    getFunctions, connectFunctionsEmulator, httpsCallable,
  } = require('firebase/functions');

  const fn = {};
  let uidUm;
  let uidDois;
  let pidUm;
  let pidDois;

  /// Cria um cliente autenticado proprio. Duas contas ANONIMAS de verdade, e nao
  /// UIDs semeados a mao: o alvo do teste e o caminho que o jogador percorre.
  async function cliente(nome) {
    const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, nome);
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
    const chamar = (n) => httpsCallable(f, n);
    return {
      uid,
      identidade: chamar('obterMinhaIdentidade'),
      atualizar: chamar('atualizarPerfilPublico'),
      verPerfil: chamar('verPerfilPublico'),
      localizar: chamar('localizarJogadorPorIdentidade'),
      enviar: chamar('enviarSolicitacaoAmizade'),
      aceitar: chamar('aceitarSolicitacaoAmizade'),
      recusar: chamar('recusarSolicitacaoAmizade'),
      cancelar: chamar('cancelarSolicitacaoAmizade'),
      remover: chamar('removerAmizade'),
      listarAmigos: chamar('listarAmigos'),
      listarRecebidas: chamar('listarSolicitacoesRecebidas'),
      listarEnviadas: chamar('listarSolicitacoesEnviadas'),
    };
  }

  before(async () => {
    fn.um = await cliente('social-um');
    fn.dois = await cliente('social-dois');
    uidUm = fn.um.uid;
    uidDois = fn.dois.uid;
    pidUm = (await fn.um.identidade({})).data.publicId;
    pidDois = (await fn.dois.identidade({})).data.publicId;
  });

  // ------------------------------------------------------------- identidade

  test('a identidade nasce uma vez e a segunda chamada REUTILIZA (§10)', async () => {
    const r = await fn.um.identidade({});
    assert.equal(r.data.publicId, pidUm);
    assert.equal(r.data.criada, false, 'a segunda chamada nao cunha id novo');
  });

  test('CONCORRENCIA: cinco chamadas simultaneas dao UM publicId (§26)', async () => {
    const c = await cliente('social-corrida');
    const respostas = await Promise.all([
      c.identidade({}), c.identidade({}), c.identidade({}),
      c.identidade({}), c.identidade({}),
    ]);
    const ids = new Set(respostas.map((r) => r.data.publicId));
    assert.equal(ids.size, 1, 'duas identidades para o mesmo jogador');

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const todos = await getDocs(collection(ctx.firestore(), 'publicIdIndex'));
      const desse = todos.docs.filter((d) => d.data().uid === c.uid);
      assert.equal(desse.length, 1, 'reserva duplicada no mapa reverso');
    });
  });

  test('o publicId nao deriva do UID e o cliente nao o escolhe (§36)', async () => {
    assert.notEqual(pidUm, pidDois);
    assert.ok(!uidUm.toUpperCase().includes(pidUm.slice(1)));
    assert.ok(!pidUm.slice(1).includes(uidUm.toUpperCase()));

    // Mandar publicId no payload nao muda nada: a Function nao le esse campo.
    const r = await fn.um.identidade({ publicId: 'PESCOLHIDO000', uid: uidDois });
    assert.equal(r.data.publicId, pidUm);
  });

  test('a resposta de identidade nao carrega UID nem e-mail', async () => {
    const bruto = JSON.stringify((await fn.um.identidade({})).data);
    assert.equal(bruto.includes(uidUm), false, 'UID vazou na resposta');
    assert.equal(bruto.includes('email'), false);
  });

  // ---------------------------------------------------------------- apelido

  test('trocar apelido NAO troca o publicId (§31-I)', async () => {
    await fn.um.atualizar({ apelido: '  Dona   Maria  ' });
    const depois = await fn.um.identidade({});
    assert.equal(depois.data.publicId, pidUm);
    assert.equal(depois.data.perfil.apelido, 'Dona Maria', 'trim + colapso');
  });

  test('apelido invalido e recusado com codigo estavel (§35)', async () => {
    for (const ruim of ['ab', 'x'.repeat(25), '   ']) {
      await assert.rejects(
        () => fn.um.atualizar({ apelido: ruim }),
        (e) => e.details?.recusa === 'apelidoInvalido',
      );
    }
  });

  test('avatar arbitrario e recusado; referencia valida passa (§8)', async () => {
    await assert.rejects(
      () => fn.um.atualizar({ avatarRef: 'https://exemplo.com/eu.png' }),
      (e) => e.details?.recusa === 'avatarInvalido',
    );
    await assertSucceeds(fn.um.atualizar({ avatarRef: 'coruja_dourada' }));
  });

  // ------------------------------------------------------------- ver perfil

  test('abrir perfil por publicId, sem conhecer UID (§31-A, §31-D)', async () => {
    const r = await fn.dois.verPerfil({ publicId: pidUm });
    assert.equal(r.data.perfil.publicId, pidUm);
    assert.equal(r.data.relacao, 'nenhuma');
    assert.deepEqual(r.data.acoes.sort(), ['adicionarAmigo', 'bloquear']);

    const bruto = JSON.stringify(r.data);
    assert.equal(bruto.includes(uidUm), false, 'UID vazou em Ver Perfil');
    assert.equal(bruto.includes(uidDois), false);
  });

  test('publicId em minuscula e com hifen tambem abre (§9)', async () => {
    const bagunçado = `${pidUm.slice(0, 5)}-${pidUm.slice(5)}`.toLowerCase();
    const r = await fn.dois.verPerfil({ publicId: bagunçado });
    assert.equal(r.data.perfil.publicId, pidUm);
  });

  test('perfil INEXISTENTE e perfil INDISPONIVEL respondem IGUAL (§31-G)', async () => {
    // O oraculo que importa e este: se a resposta distinguisse "nunca existiu"
    // de "existiu e foi desativado", qualquer pessoa varreria ids para descobrir
    // quais ja pertenceram a alguem. Um publicId MALFORMADO e outra historia — o
    // cliente sabe sozinho que a string nao tem o formato, e recusar com codigo
    // proprio ajuda a tela sem contar nada de ninguem.
    const desativado = 'PZZZZZZZZZ999';
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const d = ctx.firestore();
      await setDoc(doc(d, `publicIdIndex/${desativado}`), {
        publicId: desativado, uid: 'uidContaRemovida', criadoEm: new Date().toISOString(),
      });
      await setDoc(doc(d, `publicProfiles/${desativado}`), {
        publicId: desativado, apelido: 'Ex-jogador', apelidoOrdenacao: 'ex-jogador',
        avatarRef: null, estado: 'indisponivel',
        criadoEm: new Date().toISOString(), atualizadoEm: new Date().toISOString(),
        esquema: 1,
      });
    });

    const respostas = [];
    for (const alvo of ['PYYYYYYYYYYYY', desativado]) {
      await fn.dois.verPerfil({ publicId: alvo }).catch((e) => {
        respostas.push([e.code, e.details?.recusa]);
      });
    }
    assert.equal(respostas.length, 2, 'os dois tinham que falhar');
    assert.deepEqual(respostas[0], respostas[1],
      'distinguir os dois diria quais ids ja pertenceram a alguem');
    assert.deepEqual(respostas[0], ['functions/not-found', 'perfilPublicoNaoDisponivel']);
  });

  test('publicId malformado e recusado sem tocar o banco (§9)', async () => {
    await assert.rejects(
      () => fn.dois.verPerfil({ publicId: 'nao-e-id' }),
      (e) => e.details?.recusa === 'perfilPublicoInvalido',
    );
  });

  test('o proprio perfil aparece como euMesmo, sem acao social', async () => {
    const r = await fn.um.verPerfil({ publicId: pidUm });
    assert.equal(r.data.relacao, 'euMesmo');
    assert.deepEqual(r.data.acoes, ['editarPerfil']);
  });

  // --------------------------------------------------------------- amizade

  test('A -> B cria a solicitacao e ela aparece dos DOIS lados', async () => {
    const r = await fn.um.enviar({ publicId: pidDois });
    assert.equal(r.data.ok, true);
    assert.equal(r.data.estado, 'pendente');

    const enviadas = await fn.um.listarEnviadas({});
    assert.equal(enviadas.data.itens.length, 1);
    assert.equal(enviadas.data.itens[0].publicId, pidDois);

    const recebidas = await fn.dois.listarRecebidas({});
    assert.equal(recebidas.data.itens.length, 1);
    assert.equal(recebidas.data.itens[0].publicId, pidUm);
  });

  test('as listas nao carregam UID nem e-mail (§21, §23, §24)', async () => {
    const bruto = JSON.stringify((await fn.dois.listarRecebidas({})).data);
    assert.equal(bruto.includes(uidUm), false);
    assert.equal(bruto.includes(uidDois), false);
    const item = (await fn.dois.listarRecebidas({})).data.itens[0];
    assert.deepEqual(Object.keys(item).sort(),
      ['apelido', 'avatarRef', 'desde', 'publicId']);
  });

  test('a MESMA solicitacao duas vezes nao duplica (§26)', async () => {
    const r = await fn.um.enviar({ publicId: pidDois });
    assert.equal(r.data.ok, true, 'repeticao responde sucesso, nunca erro');
    assert.equal(r.data.repeticao, true);
    assert.equal(r.data.motivo, 'solicitacaoJaExiste');

    const enviadas = await fn.um.listarEnviadas({});
    assert.equal(enviadas.data.itens.length, 1);
  });

  test('auto-amizade e recusada (§13)', async () => {
    await assert.rejects(
      () => fn.um.enviar({ publicId: pidUm }),
      (e) => e.details?.recusa === 'autoAmizadeInvalida',
    );
  });

  test('o REMETENTE nao aceita a propria solicitacao (§14)', async () => {
    await assert.rejects(
      () => fn.um.aceitar({ publicId: pidDois }),
      (e) => e.details?.recusa === 'naoEDestinatario',
    );
  });

  test('o DESTINATARIO aceita, e a amizade e bilateral (§14, §17)', async () => {
    const r = await fn.dois.aceitar({ publicId: pidUm });
    assert.equal(r.data.estado, 'amigos');

    for (const [quem, esperado] of [[fn.um, pidDois], [fn.dois, pidUm]]) {
      const lista = await quem.listarAmigos({});
      assert.equal(lista.data.itens.length, 1);
      assert.equal(lista.data.itens[0].publicId, esperado);
    }
    // E a solicitacao some das duas caixas.
    assert.equal((await fn.um.listarEnviadas({})).data.itens.length, 0);
    assert.equal((await fn.dois.listarRecebidas({})).data.itens.length, 0);
  });

  test('aceitar duas vezes nao cria segunda amizade (§14, §26)', async () => {
    const r = await fn.dois.aceitar({ publicId: pidUm });
    assert.equal(r.data.ok, true);
    assert.equal(r.data.repeticao, true);
    assert.equal((await fn.um.listarAmigos({})).data.itens.length, 1);

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDocs(collection(ctx.firestore(), 'friendships'));
      const desse = s.docs.filter(
        (d) => (d.data().membros || []).includes(uidUm)
          && (d.data().membros || []).includes(uidDois),
      );
      assert.equal(desse.length, 1, 'nao pode existir A-B e B-A');
    });
  });

  test('a relacao aparece em Ver Perfil, com as acoes certas (§31-B)', async () => {
    const r = await fn.um.verPerfil({ publicId: pidDois });
    assert.equal(r.data.relacao, 'amigos');
    assert.deepEqual(r.data.acoes.sort(), ['bloquear', 'removerAmigo']);
    assert.ok(r.data.amigosDesde);
  });

  test('pedir amizade a quem ja e amigo e recusado (§13)', async () => {
    await assert.rejects(
      () => fn.um.enviar({ publicId: pidDois }),
      (e) => e.details?.recusa === 'jaSaoAmigos',
    );
  });

  test('o contador de amigos subiu uma vez so (§26)', async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDoc(doc(ctx.firestore(), `playerSocial/${uidUm}`));
      assert.equal(s.data().amigos, 1, 'aceite repetido nao pode contar duas vezes');
      assert.equal(s.data().solicitacoesEnviadas, 0, 'a pendente virou amizade');
    });
  });

  test('qualquer um remove, e some dos DOIS lados (§17)', async () => {
    await fn.dois.remover({ publicId: pidUm });
    assert.equal((await fn.um.listarAmigos({})).data.itens.length, 0);
    assert.equal((await fn.dois.listarAmigos({})).data.itens.length, 0);
  });

  test('remover duas vezes e seguro (§26)', async () => {
    const r = await fn.dois.remover({ publicId: pidUm });
    assert.equal(r.data.ok, true);
    assert.equal(r.data.repeticao, true);
  });

  test('§27 — pedido cruzado vira aceite, e nao duas pendencias', async () => {
    const a = await cliente('social-cruzado-a');
    const b = await cliente('social-cruzado-b');
    const pa = (await a.identidade({})).data.publicId;
    const pb = (await b.identidade({})).data.publicId;

    await a.enviar({ publicId: pb });
    const r = await b.enviar({ publicId: pa });
    assert.equal(r.data.estado, 'amigos',
      'os dois se convidaram: quem chega por ultimo aceita');
    assert.equal((await a.listarAmigos({})).data.itens.length, 1);
    assert.equal((await b.listarAmigos({})).data.itens.length, 1);
  });

  test('recusar encerra a pendencia sem criar amizade nem bloquear (§15)', async () => {
    const a = await cliente('social-recusa-a');
    const b = await cliente('social-recusa-b');
    const pa = (await a.identidade({})).data.publicId;
    const pb = (await b.identidade({})).data.publicId;

    await a.enviar({ publicId: pb });
    await b.recusar({ publicId: pa });
    assert.equal((await b.listarRecebidas({})).data.itens.length, 0);
    assert.equal((await a.listarAmigos({})).data.itens.length, 0);
    // Recusar duas vezes continua seguro, e nao bloqueou ninguem: A pode pedir
    // de novo.
    assert.equal((await b.recusar({ publicId: pa })).data.repeticao, true);
    assert.equal((await a.enviar({ publicId: pb })).data.estado, 'pendente');
  });

  test('so o REMETENTE cancela (§16)', async () => {
    const a = await cliente('social-cancela-a');
    const b = await cliente('social-cancela-b');
    const pa = (await a.identidade({})).data.publicId;
    const pb = (await b.identidade({})).data.publicId;

    await a.enviar({ publicId: pb });
    await assert.rejects(
      () => b.cancelar({ publicId: pa }),
      (e) => e.details?.recusa === 'naoERemetente',
    );
    await a.cancelar({ publicId: pb });
    assert.equal((await a.listarEnviadas({})).data.itens.length, 0);
    assert.equal((await a.cancelar({ publicId: pb })).data.repeticao, true);
  });

  // -------------------------------------------------------------- bloqueio

  test('§18 — bloquear desfaz a amizade e barra o pedido novo', async () => {
    const a = await cliente('social-bloqueio-a');
    const b = await cliente('social-bloqueio-b');
    const pa = (await a.identidade({})).data.publicId;
    const pb = (await b.identidade({})).data.publicId;

    await a.enviar({ publicId: pb });
    await b.aceitar({ publicId: pa });
    assert.equal((await a.listarAmigos({})).data.itens.length, 1);

    // O bloqueio e escrito pelo dominio CANONICO (moderacao). Aqui ele e
    // semeado direto porque a suite pode rodar sem o codebase de moderacao
    // implantado — o gatilho social reage ao DOCUMENTO, nao a Function.
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${a.uid}/blocks/${b.uid}`), {
        bloqueadorUid: a.uid, bloqueadoUid: b.uid,
        criadoEm: new Date(), esquema: 1,
      });
    });

    // O pedido novo morre na hora, sem depender de o gatilho ja ter rodado —
    // toda operacao le o bloqueio dentro da propria transacao.
    await assert.rejects(
      () => b.enviar({ publicId: pa }),
      (e) => e.details?.recusa === 'relacaoBloqueada',
    );

    // E a faxina do gatilho desfaz a amizade. Espera curta: gatilho e assincrono.
    for (let i = 0; i < 40; i++) {
      if ((await a.listarAmigos({})).data.itens.length === 0) break;
      await new Promise((r) => setTimeout(r, 250));
    }
    assert.equal((await a.listarAmigos({})).data.itens.length, 0,
      'bloquear tem que desfazer a amizade (§18)');
    assert.equal((await b.listarAmigos({})).data.itens.length, 0,
      'e nos dois lados');
  });

  test('§18 — desbloquear NAO restaura a amizade', async () => {
    const a = await cliente('social-desbloqueio-a');
    const b = await cliente('social-desbloqueio-b');
    const pa = (await a.identidade({})).data.publicId;
    const pb = (await b.identidade({})).data.publicId;

    await a.enviar({ publicId: pb });
    await b.aceitar({ publicId: pa });

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${a.uid}/blocks/${b.uid}`), {
        bloqueadorUid: a.uid, bloqueadoUid: b.uid, criadoEm: new Date(),
      });
    });
    for (let i = 0; i < 40; i++) {
      if ((await a.listarAmigos({})).data.itens.length === 0) break;
      await new Promise((r) => setTimeout(r, 250));
    }
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), `users/${a.uid}/blocks/${b.uid}`));
    });

    assert.equal((await a.listarAmigos({})).data.itens.length, 0,
      'amizade nao volta sozinha');
    assert.equal((await a.listarEnviadas({})).data.itens.length, 0,
      'solicitacao antiga nao renasce');
    // Nova amizade exige nova interacao — e agora ela e possivel.
    assert.equal((await a.enviar({ publicId: pb })).data.estado, 'pendente');
  });

  test('§31-H — bloqueio prevalece em Ver Perfil, sem dizer quem bloqueou', async () => {
    const a = await cliente('social-verbloqueio-a');
    const b = await cliente('social-verbloqueio-b');
    const pa = (await a.identidade({})).data.publicId;
    const pb = (await b.identidade({})).data.publicId;

    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `users/${a.uid}/blocks/${b.uid}`), {
        bloqueadorUid: a.uid, bloqueadoUid: b.uid, criadoEm: new Date(),
      });
    });

    // Quem bloqueou SABE que bloqueou: ele fez isso.
    const visaoDeA = await a.verPerfil({ publicId: pb });
    assert.equal(visaoDeA.data.relacao, 'bloqueadoPorMim');
    assert.deepEqual(visaoDeA.data.acoes, ['desbloquear']);

    // Quem foi bloqueado NAO descobre. Estado generico e nenhuma acao.
    const visaoDeB = await b.verPerfil({ publicId: pa });
    assert.equal(visaoDeB.data.relacao, 'indisponivel');
    assert.deepEqual(visaoDeB.data.acoes, [],
      'ate o botao de bloquear seria informacao');
    assert.equal(JSON.stringify(visaoDeB.data).includes(a.uid), false);
  });

  // --------------------------------------------------------------- listagem

  test('a lista de amigos vem ordenada por apelido e paginada (§22)', async () => {
    const dono = await cliente('social-lista-dono');
    await dono.identidade({});

    const nomes = ['Zeca', 'Ávila', 'Bia', 'Carlos'];
    for (let i = 0; i < nomes.length; i++) {
      const amigo = await cliente(`social-lista-${i}`);
      const pid = (await amigo.identidade({})).data.publicId;
      await amigo.atualizar({ apelido: nomes[i] });
      await dono.enviar({ publicId: pid });
      await amigo.aceitar({
        publicId: (await dono.identidade({})).data.publicId,
      });
    }

    const p1 = await dono.listarAmigos({ limite: 2 });
    assert.deepEqual(p1.data.itens.map((i) => i.apelido), ['Ávila', 'Bia']);
    assert.ok(p1.data.proximoCursor, 'ha proxima pagina');

    const p2 = await dono.listarAmigos({ limite: 2, cursor: p1.data.proximoCursor });
    assert.deepEqual(p2.data.itens.map((i) => i.apelido), ['Carlos', 'Zeca']);
    assert.equal(p2.data.proximoCursor, null, 'acabou');
  });

  test('o limite de pagina tem teto (§22)', async () => {
    const r = await fn.um.listarAmigos({ limite: 100000 });
    assert.ok(r.data.itens.length <= 50);
  });

  // ----------------------------------------------------------- autenticacao

  test('sem autenticacao, tudo e recusado', async () => {
    const { initializeApp: init } = require('firebase/app');
    const app = init({ projectId: PROJETO, apiKey: 'fake' }, 'social-anonimo');
    const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
    const f = getFunctions(app, 'southamerica-east1');
    connectFunctionsEmulator(f, host, Number(porta));

    for (const nome of ['obterMinhaIdentidade', 'verPerfilPublico', 'listarAmigos']) {
      await assert.rejects(
        () => httpsCallable(f, nome)({ publicId: pidUm }),
        (e) => e.code === 'functions/unauthenticated',
        `${nome} tinha que exigir autenticacao`,
      );
    }
  });
});
