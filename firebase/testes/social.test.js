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

  test('BUSCA §9 — o cliente NAO VARRE a colecao de perfis publicos', async () => {
    // O documento e publico; a COLECAO nao. `getDocs` aqui devolveria o apelido
    // e o publicId de todos os jogadores numa consulta, paginavel ate o fim da
    // base — a "listagem irrestrita de usuarios" que a OS de Busca proibe.
    //
    // A OS de Identidade Publica concedeu `get, list` juntos e o `list` nunca
    // teve consumidor: as telas resolvem um publicId por vez, e as Functions
    // usam o Admin SDK, que ignora estas regras.
    await assertFails(getDocs(collection(comoAna(), 'publicProfiles')));
    await assertFails(getDocs(collection(comoCaio(), 'publicProfiles')));
    await assertFails(getDocs(collection(semLogin(), 'publicProfiles')));
  });

  test('BUSCA §9 — nem uma consulta FILTRADA passa: a busca e do servidor', async () => {
    // A tentativa esperta: em vez de listar tudo, listar por faixa de apelido —
    // que e exatamente a consulta que a Function faz. Negada tambem, e tem que
    // ser: uma regra nao impoe termo minimo, teto de resultados nem respeito ao
    // bloqueio, e sem os tres a consulta e um diretorio com filtro.
    const { query, where, orderBy, limit } = require('firebase/firestore');
    await assertFails(getDocs(query(
      collection(comoCaio(), 'publicProfiles'),
      where('apelidoOrdenacao', '>=', 'a'),
      orderBy('apelidoOrdenacao'),
      limit(50),
    )));
    await assertFails(getDocs(query(
      collection(comoCaio(), 'publicProfiles'),
      where('apelidoOrdenacao', '==', 'ana'),
    )));
  });

  test('BUSCA §12 — a leitura POR ID continua publica: nao houve regressao', async () => {
    // O que saiu foi a varredura. O documento publico deliberado — o primeiro do
    // banco — continua legivel por qualquer autenticado, que e o que sustenta
    // `Ranking/Hall -> publicId -> Ver Perfil`.
    await assertSucceeds(getDoc(doc(comoCaio(), `publicProfiles/${PID_ANA}`)));
    await assertSucceeds(getDoc(doc(comoAna(), `publicProfiles/${PID_BIA}`)));
  });

  test('BUSCA §12 — o admin ainda lista, para suporte e reconciliacao', async () => {
    await assertSucceeds(getDocs(collection(comoAdmin(), 'publicProfiles')));
  });

  test('BUSCA §4 — nao existe colecao auxiliar de indice de busca', async () => {
    // A OS permite uma estrutura derivada; esta implementacao nao criou nenhuma,
    // porque `apelidoOrdenacao` ja mora no proprio perfil publico. Se alguem
    // criar uma um dia, o fecho padrao a nega — e este teste e o alarme que
    // avisa que ela precisa das PROPRIAS regras antes de existir.
    for (const inventada of ['nicknameIndex', 'apelidoIndex', 'searchIndex', 'buscaApelidos']) {
      await assertFails(getDoc(doc(comoAna(), `${inventada}/ana`)));
      await assertFails(getDocs(collection(comoAna(), inventada)));
      await assertFails(setDoc(doc(comoAna(), `${inventada}/ana`), {
        apelidoOrdenacao: 'ana', publicId: PID_ANA,
      }));
    }
  });

  test('BUSCA §12 — o cliente nao escreve a chave de busca do proprio perfil', async () => {
    // `apelidoOrdenacao` E o indice de busca. Poder grava-lo seria poder aparecer
    // em qualquer consulta: bastaria escrever a chave do apelido alheio.
    await assertFails(
      updateDoc(doc(comoAna(), `publicProfiles/${PID_ANA}`), {
        apelidoOrdenacao: 'aaaaaaa',
      }),
    );
    await assertFails(
      updateDoc(doc(comoCaio(), `publicProfiles/${PID_ANA}`), {
        apelidoOrdenacao: 'zzz',
      }),
    );
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
// SEGUIR — modelo privado (SOCIAL-02, etapa C2). SO REGRAS.
// ===========================================================================
// Tres raizes novas e quatro projecoes. Nenhum cliente le ou escreve — nem o
// dono; o admin le, como em `friendships`. Os documentos sao semeados com as
// regras desligadas, no formato persistido real (contrato V2 §2.2), para que
// `get`, `update` e `delete` sejam negados sobre algo que EXISTE.
//
// Estes casos rodam nos dois alvos (so regras e com Functions) e nunca ficam
// pulados: nao dependem de FUNCTIONS_EMULATOR_HOST.
describe('seguir: modelo privado negado ao cliente (SOCIAL-02 C2)', () => {
  const QUANDO_SEGUIR = '2026-11-12T10:00:00.000Z';
  const FOLLOW_ANA_BIA = `${ANA}|${BIA}`;
  const CORTE_ANA_BIA = [ANA, BIA].sort().join('|');

  /// [descricao, caminho do documento, colecao para `list`, dono, terceiro]
  const ALVOS = [
    ['follows (canonico dirigido)', `follows/${FOLLOW_ANA_BIA}`, 'follows', ANA, CAIO],
    ['cortesDeRelacao (corte do par)', `cortesDeRelacao/${CORTE_ANA_BIA}`, 'cortesDeRelacao', ANA, CAIO],
    ['playerSocialRitmo (contador do teto)', `playerSocialRitmo/${ANA}`, 'playerSocialRitmo', ANA, CAIO],
    ['seguindo (P1)', `users/${ANA}/seguindo/${BIA}`, `users/${ANA}/seguindo`, ANA, CAIO],
    ['seguidores (P2)', `users/${BIA}/seguidores/${ANA}`, `users/${BIA}/seguidores`, BIA, CAIO],
    ['pedidosSeguirEnviados (P3)', `users/${ANA}/pedidosSeguirEnviados/${CAIO}`, `users/${ANA}/pedidosSeguirEnviados`, ANA, BIA],
    ['pedidosSeguirRecebidos (P4)', `users/${CAIO}/pedidosSeguirRecebidos/${ANA}`, `users/${CAIO}/pedidosSeguirRecebidos`, CAIO, BIA],
  ];

  before(async () => {
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `follows/${FOLLOW_ANA_BIA}`), {
        seguidorUid: ANA, seguidoUid: BIA, estado: 'confirmado', ref: 'rAnaBia',
        corteNaCriacao: null,
        ultimaIntencao: { chave: `${ANA}|i1`, impressao: 'seguir|saida|-' },
        solicitadoEm: QUANDO_SEGUIR, confirmadoEm: QUANDO_SEGUIR, encerradoEm: null,
        desde: QUANDO_SEGUIR, criacoesRecentes: [QUANDO_SEGUIR], esquema: 1,
      });
      await setDoc(doc(db, `cortesDeRelacao/${CORTE_ANA_BIA}`), {
        corteId: 'corte1', membros: [ANA, BIA].sort(), atualizadoEm: QUANDO_SEGUIR, esquema: 1,
      });
      await setDoc(doc(db, `playerSocialRitmo/${ANA}`), {
        criacoes: [QUANDO_SEGUIR], pedidosPendentesEnviados: 1, atualizadoEm: QUANDO_SEGUIR, esquema: 1,
      });
      await setDoc(doc(db, `users/${ANA}/seguindo/${BIA}`), {
        publicId: PID_BIA, desde: QUANDO_SEGUIR, referencia: 'rAnaBia.',
      });
      await setDoc(doc(db, `users/${BIA}/seguidores/${ANA}`), {
        publicId: PID_ANA, desde: QUANDO_SEGUIR, referencia: 'rAnaBia.',
      });
      await setDoc(doc(db, `users/${ANA}/pedidosSeguirEnviados/${CAIO}`), {
        publicId: PID_CAIO, solicitadoEm: QUANDO_SEGUIR, referencia: 'rAnaCaio.',
      });
      await setDoc(doc(db, `users/${CAIO}/pedidosSeguirRecebidos/${ANA}`), {
        publicId: PID_ANA, solicitadoEm: QUANDO_SEGUIR, referencia: 'rAnaCaio.',
      });
    });
  });

  /// As cinco operacoes de cliente, todas negadas.
  async function negarTudo(db, caminho, colecaoDeLista) {
    await assertFails(getDoc(doc(db, caminho)));
    await assertFails(getDocs(collection(db, colecaoDeLista)));
    await assertFails(setDoc(doc(db, `${colecaoDeLista}/documentoNovoDoCliente`), { x: 1 }));
    await assertFails(updateDoc(doc(db, caminho), { estado: 'confirmado', pedidosPendentesEnviados: 0 }));
    await assertFails(deleteDoc(doc(db, caminho)));
  }

  const contextoDe = (uid) => ambiente.authenticatedContext(uid).firestore();

  for (const [descricao, caminho, colecaoDeLista, dono, terceiro] of ALVOS) {
    test(`${descricao}: nao autenticado nao le, nao lista e nao escreve`, async () => {
      await negarTudo(semLogin(), caminho, colecaoDeLista);
    });

    test(`${descricao}: o PROPRIO DONO nao le, nao lista e nao escreve`, async () => {
      await negarTudo(contextoDe(dono), caminho, colecaoDeLista);
    });

    test(`${descricao}: terceiro nao le, nao lista e nao escreve`, async () => {
      await negarTudo(contextoDe(terceiro), caminho, colecaoDeLista);
    });

    test(`${descricao}: o admin le para suporte, e tambem nao escreve`, async () => {
      await assertSucceeds(getDoc(doc(comoAdmin(), caminho)));
      await assertSucceeds(getDocs(collection(comoAdmin(), colecaoDeLista)));
      await assertFails(setDoc(doc(comoAdmin(), caminho), { x: 1 }));
      await assertFails(deleteDoc(doc(comoAdmin(), caminho)));
    });
  }

  test('o documento semeado continua inteiro depois de todas as tentativas', async () => {
    // A negacao tem que ter sido REAL: nada do que o cliente tentou chegou ao banco.
    await ambiente.withSecurityRulesDisabled(async (ctx) => {
      const s = await getDoc(doc(ctx.firestore(), `playerSocialRitmo/${ANA}`));
      assert.equal(s.data().pedidosPendentesEnviados, 1);
      const f = await getDoc(doc(ctx.firestore(), `follows/${FOLLOW_ANA_BIA}`));
      assert.equal(f.data().estado, 'confirmado');
      const novo = await getDoc(doc(ctx.firestore(), 'follows/documentoNovoDoCliente'));
      assert.equal(novo.exists(), false);
    });
  });

  test('as regras de amizade continuam como estavam (nao-regressao)', async () => {
    await assertFails(getDocs(collection(comoAna(), `users/${ANA}/friends`)));
    await assertSucceeds(getDocs(collection(comoAdmin(), `users/${ANA}/friends`)));
    const s = await assertSucceeds(getDoc(doc(comoAna(), `playerSocial/${ANA}`)));
    assert.equal(s.data().amigos, 1);
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
      buscar: chamar('buscarJogadoresPorApelido'),
      enviar: chamar('enviarSolicitacaoAmizade'),
      aceitar: chamar('aceitarSolicitacaoAmizade'),
      recusar: chamar('recusarSolicitacaoAmizade'),
      cancelar: chamar('cancelarSolicitacaoAmizade'),
      remover: chamar('removerAmizade'),
      listarAmigos: chamar('listarAmigos'),
      listarRecebidas: chamar('listarSolicitacoesRecebidas'),
      listarEnviadas: chamar('listarSolicitacoesEnviadas'),
      // SOCIAL-02 C3 — seguir.
      seguir: chamar('seguirJogador'),
      cancelarSeguir: chamar('cancelarPedidoSeguir'),
      aprovarSeguir: chamar('aprovarPedidoSeguir'),
      recusarSeguir: chamar('recusarPedidoSeguir'),
      deixarSeguir: chamar('deixarDeSeguir'),
      removerSeguidor: chamar('removerSeguidor'),
      listarSeguidores: chamar('listarSeguidores'),
      listarSeguindo: chamar('listarSeguindo'),
      listarPedidosRecebidos: chamar('listarPedidosSeguirRecebidos'),
      listarPedidosEnviados: chamar('listarPedidosSeguirEnviados'),
      privacidade: chamar('definirPrivacidadeSocial'),
      contadores: chamar('consultarContadoresSociais'),
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

  // ============================================================== BUSCA
  //
  // O BANCO DESTE ARQUIVO E COMPARTILHADO entre todos os testes acima, e varios
  // deles criaram jogadores com apelido ('Dona Maria', 'Zeca', 'Ávila', 'Bia',
  // 'Carlos'). Por isso os apelidos daqui sao improvaveis de proposito: uma
  // asserção de "veio exatamente um resultado" so vale se ninguem mais puder
  // casar com o termo.
  // ==========================================================================

  describe('busca por apelido', () => {
    const busca = {};
    // Sufixo comum aos tres primeiros, para o teste de prefixo.
    const RARO = 'Quixote';

    before(async () => {
      busca.alfa = await cliente('busca-alfa');
      busca.beta = await cliente('busca-beta');
      busca.gama = await cliente('busca-gama');

      busca.pidAlfa = (await busca.alfa.identidade({})).data.publicId;
      busca.pidBeta = (await busca.beta.identidade({})).data.publicId;
      busca.pidGama = (await busca.gama.identidade({})).data.publicId;

      // Acento e caixa DIFERENTES entre os dois, de proposito: a busca por
      // "quixote" tem que alcançar os dois, e e a normalizacao que faz isso.
      await busca.alfa.atualizar({ apelido: `${RARO} Álfa` });
      await busca.beta.atualizar({ apelido: `${RARO.toUpperCase()} BETA` });
      await busca.gama.atualizar({ apelido: 'Zarabatana Solitaria' });
    });

    // ------------------------------------------------------------ encontrar

    test('apelido EXISTENTE e encontrado por correspondencia exata (§6)', async () => {
      const r = await busca.gama.buscar({
        termo: 'Zarabatana Solitaria',
        modo: 'exato',
      });
      assert.equal(r.data.itens.length, 1);
      assert.equal(r.data.itens[0].publicId, busca.pidGama);
      assert.equal(r.data.itens[0].apelido, 'Zarabatana Solitaria');
      assert.equal(r.data.modo, 'exato');
    });

    test('caixa, acento e espaco nao atrapalham (§5)', async () => {
      // A prova de ponta a ponta da equivalencia entre a normalizacao da
      // gravacao e a da busca: o apelido foi gravado "Zarabatana Solitaria" e e
      // encontrado por quatro formas diferentes de digita-lo.
      for (const termo of [
        'zarabatana solitaria',
        'ZARABATANA SOLITARIA',
        '  Zarabatana   Solitaria  ',
        'Zarabatána Solitária',
      ]) {
        const r = await busca.alfa.buscar({ termo, modo: 'exato' });
        assert.equal(r.data.itens.length, 1, `nao achou por "${termo}"`);
        assert.equal(r.data.itens[0].publicId, busca.pidGama);
      }
    });

    test('apelido INEXISTENTE devolve lista vazia, e nao erro (§14)', async () => {
      const r = await busca.alfa.buscar({ termo: 'ninguemsechamaassim' });
      assert.deepEqual(r.data.itens, []);
      assert.equal(r.data.truncado, false);
    });

    test('o PREFIXO alcança os dois apelidos, em ordem determinada (§6)', async () => {
      const r = await busca.gama.buscar({ termo: RARO });
      const ids = r.data.itens.map((i) => i.publicId);
      assert.deepEqual(ids, [busca.pidAlfa, busca.pidBeta],
        'ordenado por apelido normalizado: "quixote alfa" antes de "quixote beta"');
      assert.equal(r.data.modo, 'prefixo');
    });

    test('o resultado e DETERMINISTICO entre chamadas (§14)', async () => {
      const a = await busca.gama.buscar({ termo: RARO });
      const b = await busca.gama.buscar({ termo: RARO });
      assert.deepEqual(a.data, b.data);
    });

    test('prefixo NAO e infixo: buscar o meio do apelido nao acha', async () => {
      // "Solitaria" e a segunda palavra de "Zarabatana Solitaria". A v1 ancora no
      // comeco da chave — e isso e contrato, nao limitacao acidental.
      const r = await busca.alfa.buscar({ termo: 'Solitaria' });
      assert.equal(
        r.data.itens.some((i) => i.publicId === busca.pidGama), false,
      );
    });

    // ------------------------------------------------------- anti-enumeracao

    test('§9 — termo curto demais e recusado com codigo estavel', async () => {
      for (const curto of ['a', 'ab', '  ab  ']) {
        await assert.rejects(
          () => busca.alfa.buscar({ termo: curto }),
          (e) => e.code === 'functions/invalid-argument'
            && e.details?.recusa === 'consultaMuitoCurta',
          `"${curto}" tinha que ser recusado`,
        );
      }
    });

    test('§9 — termo longo demais e recusado', async () => {
      await assert.rejects(
        () => busca.alfa.buscar({ termo: 'x'.repeat(25) }),
        (e) => e.details?.recusa === 'consultaMuitoLonga',
      );
    });

    test('§9 — termo vazio, ausente ou com controle e recusado', async () => {
      // O override de bidirecionalidade vai como ESCAPE: colado literalmente ele
      // some do diff e do terminal, que e justamente por que ele e recusado.
      for (const ruim of [
        undefined, '', '   ', 42, ['ana'], 'ana\nbia', 'a\u202Eb', 'ana\u200Bbia',
      ]) {
        await assert.rejects(
          () => busca.alfa.buscar({ termo: ruim }),
          (e) => e.details?.recusa === 'consultaInvalida',
          `${JSON.stringify(ruim)} tinha que ser recusado`,
        );
      }
    });

    test('§9 — modo desconhecido e recusado, e nao vira o padrao', async () => {
      await assert.rejects(
        () => busca.alfa.buscar({ termo: RARO, modo: 'contem' }),
        (e) => e.details?.recusa === 'consultaInvalida',
      );
    });

    test('§9 — nao ha curinga: `*` e comparado como texto', async () => {
      const r = await busca.alfa.buscar({ termo: '***' });
      assert.deepEqual(r.data.itens, [],
        'se `*` fosse curinga, isto devolveria a base inteira');
    });

    test('§9 — o limite tem teto e a pagina nao passa dele', async () => {
      const r = await busca.alfa.buscar({ termo: RARO, limite: 100000 });
      assert.ok(r.data.itens.length <= 20, 'o teto duro e 20');
      const um = await busca.alfa.buscar({ termo: RARO, limite: 1 });
      assert.equal(um.data.itens.length, 1);
      assert.equal(um.data.truncado, true, 'havia mais do que coube');
    });

    test('§9 — NAO HA CURSOR: a busca nao percorre a base', async () => {
      // A decisao antienumeracao central. `truncado` diz "refine o termo"; ele
      // nao e um cursor e nao ha campo nenhum que sirva de cursor.
      const r = await busca.alfa.buscar({ termo: RARO, limite: 1 });
      assert.deepEqual(Object.keys(r.data).sort(), ['itens', 'modo', 'truncado']);
      // E mandar um cursor nao muda nada: a Function nao le esse campo.
      const comCursor = await busca.alfa.buscar({
        termo: RARO, limite: 1, cursor: 'qualquer', proximoCursor: 'qualquer',
      });
      assert.deepEqual(comCursor.data, r.data);
    });

    test('§9 — nao existe rota que devolva todos os jogadores', async () => {
      // As formas de pedir "tudo", uma por uma. Nenhuma passa.
      for (const tentativa of [{}, { termo: '' }, { termo: '*' }, { termo: ' ' }]) {
        await assert.rejects(
          () => busca.alfa.buscar(tentativa),
          (e) => e.code === 'functions/invalid-argument',
          JSON.stringify(tentativa),
        );
      }
    });

    // --------------------------------------------------------------- vazamento

    test('§3 — o resultado NAO carrega UID, e-mail nem campo interno', async () => {
      const r = await busca.gama.buscar({ termo: RARO });
      const bruto = JSON.stringify(r.data);
      for (const uidReal of [busca.alfa.uid, busca.beta.uid, busca.gama.uid]) {
        assert.equal(bruto.includes(uidReal), false, 'UID vazou na busca');
      }
      for (const proibido of [
        'email', 'uid', 'userId', 'membros', 'pairKey', 'solicitanteUid',
        'billing', 'vip', 'entitlement', 'playerModeration', 'sanctions',
      ]) {
        assert.equal(bruto.includes(proibido), false, `${proibido} vazou`);
      }
      // A allowlist pelo outro lado: exatamente estas chaves, e nada mais.
      for (const item of r.data.itens) {
        assert.deepEqual(Object.keys(item).sort(),
          ['acoes', 'apelido', 'avatarRef', 'publicId', 'relacao']);
      }
    });

    test('§7 — o perfil PRIVADO nao entra no resultado', async () => {
      // Semeia dado privado em `users/{uid}` do alvo e confere que a busca — que
      // le `publicProfiles` — continua devolvendo so a apresentacao publica.
      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `users/${busca.gama.uid}`), {
          email: 'gama@exemplo.com', vip: true, fichas: 9999,
        });
      });
      const r = await busca.alfa.buscar({
        termo: 'Zarabatana Solitaria', modo: 'exato',
      });
      const bruto = JSON.stringify(r.data);
      assert.equal(r.data.itens.length, 1);
      for (const privado of ['gama@exemplo.com', '9999', 'fichas']) {
        assert.equal(bruto.includes(privado), false, `${privado} vazou`);
      }
    });

    test('§7 — perfil INDISPONIVEL nao aparece na busca', async () => {
      const oculto = 'PWWWWWWWWWWWW';
      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        const d = ctx.firestore();
        await setDoc(doc(d, `publicIdIndex/${oculto}`), {
          publicId: oculto, uid: 'uidContaDesativadaBusca',
        });
        await setDoc(doc(d, `publicProfiles/${oculto}`), {
          publicId: oculto,
          apelido: 'Quixote Desativado',
          apelidoOrdenacao: 'quixote desativado',
          avatarRef: null,
          estado: 'indisponivel',
          criadoEm: new Date().toISOString(),
          atualizadoEm: new Date().toISOString(),
          esquema: 1,
        });
      });
      const r = await busca.alfa.buscar({ termo: RARO });
      assert.equal(r.data.itens.some((i) => i.publicId === oculto), false,
        'conta desativada nao entra na descoberta');
    });

    // ---------------------------------------------------------- grafo social

    test('§10 — o estado social acompanha o resultado, e segue o canonico', async () => {
      // Sem relacao.
      let r = await busca.alfa.buscar({ termo: 'Zarabatana Solitaria', modo: 'exato' });
      assert.equal(r.data.itens[0].relacao, 'nenhuma');
      assert.deepEqual(r.data.itens[0].acoes.sort(), ['adicionarAmigo', 'bloquear']);

      // Solicitacao pendente, dos dois lados.
      await busca.alfa.enviar({ publicId: busca.pidGama });
      r = await busca.alfa.buscar({ termo: 'Zarabatana Solitaria', modo: 'exato' });
      assert.equal(r.data.itens[0].relacao, 'solicitacaoEnviada');
      assert.deepEqual(r.data.itens[0].acoes.sort(),
        ['bloquear', 'cancelarSolicitacao']);

      const visaoDoGama = await busca.gama.buscar({
        termo: `${RARO} Alfa`, modo: 'exato',
      });
      assert.equal(visaoDoGama.data.itens[0].relacao, 'solicitacaoRecebida');

      // Amizade.
      await busca.gama.aceitar({ publicId: busca.pidAlfa });
      r = await busca.alfa.buscar({ termo: 'Zarabatana Solitaria', modo: 'exato' });
      assert.equal(r.data.itens[0].relacao, 'amigos');
      assert.deepEqual(r.data.itens[0].acoes.sort(), ['bloquear', 'removerAmigo']);

      // Desfeita: volta a ser "nenhuma". A busca nao guarda memoria.
      await busca.alfa.remover({ publicId: busca.pidGama });
      r = await busca.alfa.buscar({ termo: 'Zarabatana Solitaria', modo: 'exato' });
      assert.equal(r.data.itens[0].relacao, 'nenhuma');
    });

    test('§10 — a busca nao e fonte de amizade: quem cria e a Function canonica', async () => {
      // O resultado diz "adicionarAmigo", e isso e desenho de botao. A amizade so
      // existe depois de `enviarSolicitacaoAmizade` + aceite — e o proprio
      // resultado prova que ela ainda nao existe.
      const r = await busca.alfa.buscar({ termo: 'Zarabatana Solitaria', modo: 'exato' });
      assert.equal(r.data.itens[0].relacao, 'nenhuma');
      assert.equal((await busca.alfa.listarAmigos({})).data.itens
        .some((i) => i.publicId === busca.pidGama), false);
    });

    test('§10 — o proprio jogador aparece na propria busca, sem acao social', async () => {
      const r = await busca.gama.buscar({ termo: 'Zarabatana Solitaria', modo: 'exato' });
      assert.equal(r.data.itens[0].publicId, busca.pidGama);
      assert.equal(r.data.itens[0].relacao, 'euMesmo');
      assert.deepEqual(r.data.itens[0].acoes, ['editarPerfil']);
    });

    // -------------------------------------------------------------- bloqueio

    test('§8 — quem me BLOQUEOU some da minha busca', async () => {
      const a = await cliente('busca-bloqueio-a');
      const b = await cliente('busca-bloqueio-b');
      await a.identidade({});
      const pidB = (await b.identidade({})).data.publicId;
      await b.atualizar({ apelido: 'Berimbau Escondido' });

      // Antes do bloqueio: encontravel.
      let r = await a.buscar({ termo: 'Berimbau Escondido', modo: 'exato' });
      assert.equal(r.data.itens.length, 1);
      assert.equal(r.data.itens[0].publicId, pidB);

      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `users/${b.uid}/blocks/${a.uid}`), {
          bloqueadorUid: b.uid, bloqueadoUid: a.uid, criadoEm: new Date(), esquema: 1,
        });
      });

      // Depois: some. Sem isso, a busca devolveria ao bloqueado o acesso que o
      // bloqueio tirou — ele acharia a pessoa e tentaria a amizade.
      r = await a.buscar({ termo: 'Berimbau Escondido', modo: 'exato' });
      assert.deepEqual(r.data.itens, []);

      // E a descoberta nao vira rota para contornar: nao ha publicId a usar, e
      // usar o de outro caminho tambem nao passa.
      await assert.rejects(
        () => a.enviar({ publicId: pidB }),
        (e) => e.details?.recusa === 'relacaoBloqueada',
      );
    });

    test('§8 — quem EU bloqueei tambem some, e a ausencia e IGUAL nos dois casos', async () => {
      const a = await cliente('busca-bloqueio-c');
      const b = await cliente('busca-bloqueio-d');
      await a.identidade({});
      await b.identidade({});
      await b.atualizar({ apelido: 'Cavaquinho Perdido' });

      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `users/${a.uid}/blocks/${b.uid}`), {
          bloqueadorUid: a.uid, bloqueadoUid: b.uid, criadoEm: new Date(), esquema: 1,
        });
      });

      const r = await a.buscar({ termo: 'Cavaquinho Perdido', modo: 'exato' });
      assert.deepEqual(r.data.itens, [],
        'quem eu bloqueei nao volta pela descoberta');
      // A resposta e indistinguivel da do caso anterior e da de "nao existe":
      // uma lista vazia. Nada nela diz de que lado veio o bloqueio, nem se houve
      // bloqueio.
      const inexistente = await a.buscar({ termo: 'Naoexisteninguem', modo: 'exato' });
      assert.deepEqual(r.data, inexistente.data);
    });

    test('§8 — o bloqueio some da busca antes de a faxina do gatilho rodar', async () => {
      // A janela entre o bloqueio e a faxina assincrona. Durante ela o documento
      // canonico ainda diz "amigos", e a busca ja nao pode exibir a pessoa.
      const a = await cliente('busca-bloqueio-e');
      const b = await cliente('busca-bloqueio-f');
      const pidA = (await a.identidade({})).data.publicId;
      const pidB = (await b.identidade({})).data.publicId;
      await b.atualizar({ apelido: 'Pandeiro Fugidio' });

      await a.enviar({ publicId: pidB });
      await b.aceitar({ publicId: pidA });
      assert.equal(
        (await a.buscar({ termo: 'Pandeiro Fugidio', modo: 'exato' }))
          .data.itens[0].relacao,
        'amigos',
      );

      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `users/${b.uid}/blocks/${a.uid}`), {
          bloqueadorUid: b.uid, bloqueadoUid: a.uid, criadoEm: new Date(),
        });
      });

      // Sem espera: a busca le o bloqueio na hora, nao depende do gatilho.
      assert.deepEqual(
        (await a.buscar({ termo: 'Pandeiro Fugidio', modo: 'exato' })).data.itens,
        [],
      );
    });

    test('§8 — o bloqueio remove SO o bloqueado, e nao a busca inteira', async () => {
      const r = await busca.alfa.buscar({ termo: RARO });
      assert.ok(r.data.itens.length >= 2, 'os outros continuam la');
    });

    // ==========================================================================
    // O CANDIDATO OCULTO NAO EXISTE — nem no metadado (§8)
    //
    // A §8 nao para na lista de itens. Se um candidato escondido pelo bloqueio
    // puder mexer em QUALQUER campo observavel, a ausencia dele deixa de ser
    // ausencia e vira sinal. Sao dois defeitos, pelo mesmo buraco, e uma
    // consulta unica de `limite + 1` tem os dois:
    //
    //   `truncado` sobre o lote BRUTO ... um bloqueado na posicao limite+1
    //                                     diria "havia mais" num resultado que,
    //                                     para quem procura, esta completo.
    //   vaga roubada .................... um bloqueado entre os primeiros
    //                                     empurraria um jogador legitimo para
    //                                     fora da janela lida.
    //
    // Estes testes provam os dois contra o emulador, que e o unico lugar onde a
    // varredura de verdade acontece.
    // ==========================================================================

    describe('o candidato oculto nao existe, nem no `truncado`', () => {
      const oculto = {};

      /// Cria um jogador com apelido, e devolve `{cliente, publicId}`.
      async function jogador(nome, apelido) {
        const c = await cliente(nome);
        const publicId = (await c.identidade({})).data.publicId;
        await c.atualizar({ apelido });
        return { c, publicId };
      }

      /// Semeia o bloqueio canonico. Escrito direto porque a suite pode rodar
      /// sem o codebase de moderacao implantado — o social so LE este documento.
      async function bloquear(bloqueadorUid, bloqueadoUid) {
        await ambiente.withSecurityRulesDisabled(async (ctx) => {
          await setDoc(
            doc(ctx.firestore(), `users/${bloqueadorUid}/blocks/${bloqueadoUid}`),
            {
              bloqueadorUid, bloqueadoUid, criadoEm: new Date(), esquema: 1,
            },
          );
        });
      }

      before(async () => {
        oculto.quem = await cliente('oculto-buscador');
        await oculto.quem.identidade({});
        const eu = oculto.quem.uid;

        // TROMBONE — a ordem por apelido normalizado e Aa < Bb < Cc < Dd, e o
        // BLOQUEADO E O PRIMEIRO de proposito: e a posicao em que ele roubaria
        // a vaga de outra pessoa.
        oculto.aa = await jogador('oculto-trombone-aa', 'Trombone Aa');
        oculto.bb = await jogador('oculto-trombone-bb', 'Trombone Bb');
        oculto.cc = await jogador('oculto-trombone-cc', 'Trombone Cc');
        oculto.dd = await jogador('oculto-trombone-dd', 'Trombone Dd');
        await bloquear(oculto.aa.c.uid, eu);

        // SANFONA — um unico candidato, e ele esta bloqueado.
        oculto.sanfona = await jogador('oculto-sanfona', 'Sanfona Unica');
        await bloquear(oculto.sanfona.c.uid, eu);

        // RABECA — tres candidatos, todos bloqueados.
        oculto.rabecas = [];
        for (const sufixo of ['Um', 'Dois', 'Tres']) {
          const j = await jogador(`oculto-rabeca-${sufixo}`, `Rabeca ${sufixo}`);
          await bloquear(j.c.uid, eu);
          oculto.rabecas.push(j);
        }

        // ZABUMBA — um bloqueou o buscador, o outro foi bloqueado por ele.
        oculto.dele = await jogador('oculto-zabumba-dele', 'Zabumba Dele');
        await bloquear(oculto.dele.c.uid, eu);
        oculto.meu = await jogador('oculto-zabumba-meu', 'Zabumba Meu');
        await bloquear(eu, oculto.meu.c.uid);
      });

      test('UM candidato bloqueado responde IGUAL a apelido inexistente', async () => {
        const comBloqueado = await oculto.quem.buscar({ termo: 'Sanfona Unica', modo: 'exato' });
        const inexistente = await oculto.quem.buscar({ termo: 'Sanfona Nenhuma', modo: 'exato' });
        assert.deepEqual(comBloqueado.data, inexistente.data);
        assert.deepEqual(comBloqueado.data,
          { itens: [], truncado: false, modo: 'exato' });
      });

      test('VARIOS candidatos bloqueados respondem IGUAL a inexistente', async () => {
        // Tres bloqueados. Se `truncado` ou a contagem reagissem ao numero de
        // escondidos, "tres" e "nenhum" seriam distinguiveis.
        const trinta = await oculto.quem.buscar({ termo: 'Rabeca' });
        const inexistente = await oculto.quem.buscar({ termo: 'Rabequinha' });
        assert.deepEqual(trinta.data, inexistente.data);
        assert.deepEqual(trinta.data,
          { itens: [], truncado: false, modo: 'prefixo' });
      });

      test('os OUTROS jogadores continuam achando quem bloqueou o buscador', async () => {
        // A contraprova: os perfis existem e sao encontraveis. Sem ela, os dois
        // testes acima passariam com uma busca simplesmente quebrada.
        const terceiro = await cliente('oculto-terceiro');
        await terceiro.identidade({});
        const r = await terceiro.buscar({ termo: 'Sanfona Unica', modo: 'exato' });
        assert.equal(r.data.itens.length, 1);
        assert.equal(r.data.itens[0].publicId, oculto.sanfona.publicId);

        const rabecas = await terceiro.buscar({ termo: 'Rabeca' });
        assert.equal(rabecas.data.itens.length, 3);
      });

      test('o bloqueado NAO ROUBA A VAGA de um jogador legitimo', async () => {
        // Faixa: [Aa bloqueado, Bb, Cc, Dd]. Com limite 2, uma consulta unica de
        // tres documentos leria [Aa, Bb], filtraria Aa e devolveria UM item — o
        // Cc ficaria de fora por causa de um bloqueio que nao e dele.
        const r = await oculto.quem.buscar({ termo: 'Trombone', limite: 2 });
        assert.deepEqual(r.data.itens.map((i) => i.publicId),
          [oculto.bb.publicId, oculto.cc.publicId]);
        assert.equal(r.data.truncado, true, 'o Dd ainda esta la fora');
      });

      test('`truncado` conta os VISIVEIS, e nao o lote bruto', async () => {
        // Tres visiveis (Bb, Cc, Dd) e um escondido (Aa). Com limite 3, a
        // resposta esta COMPLETA e `truncado` tem que ser falso — calculado
        // sobre o lote bruto de quatro, ele diria "havia mais", e essa diferenca
        // e a existencia do Aa vazando por um metadado.
        const r = await oculto.quem.buscar({ termo: 'Trombone', limite: 3 });
        assert.deepEqual(r.data.itens.map((i) => i.publicId),
          [oculto.bb.publicId, oculto.cc.publicId, oculto.dd.publicId]);
        assert.equal(r.data.truncado, false,
          'nao ha mais nenhum Trombone visivel para este jogador');
      });

      test('e quem NAO foi bloqueado ve o quarto, e o `truncado` dele', async () => {
        // O mesmo termo, o mesmo limite, outro observador: quatro candidatos,
        // limite tres, `truncado` verdadeiro. Os dois `truncado` sao diferentes
        // porque os dois MUNDOS sao diferentes — e nao porque um deles esta
        // contando o lote bruto.
        const terceiro = await cliente('oculto-terceiro-b');
        await terceiro.identidade({});
        const r = await terceiro.buscar({ termo: 'Trombone', limite: 3 });
        assert.deepEqual(r.data.itens.map((i) => i.publicId),
          [oculto.aa.publicId, oculto.bb.publicId, oculto.cc.publicId]);
        assert.equal(r.data.truncado, true);
      });

      test('bloqueio nos DOIS sentidos produz a mesma resposta', async () => {
        const eleMeBloqueou = await oculto.quem.buscar({ termo: 'Zabumba Dele', modo: 'exato' });
        const euOBloqueei = await oculto.quem.buscar({ termo: 'Zabumba Meu', modo: 'exato' });
        const inexistente = await oculto.quem.buscar({ termo: 'Zabumba Nada', modo: 'exato' });

        assert.deepEqual(eleMeBloqueou.data, euOBloqueei.data);
        assert.deepEqual(eleMeBloqueou.data, inexistente.data);

        // E o prefixo que casa com os dois tambem some por inteiro.
        const prefixo = await oculto.quem.buscar({ termo: 'Zabumba' });
        assert.deepEqual(prefixo.data,
          { itens: [], truncado: false, modo: 'prefixo' });
      });

      test('a ausencia de cursor continua valendo, inclusive com truncado', async () => {
        // A varredura avanca por um cursor INTERNO, que nasce e morre dentro da
        // chamada. Nada dele aparece na resposta, e mandar um cursor no payload
        // continua sem efeito.
        const r = await oculto.quem.buscar({ termo: 'Trombone', limite: 2 });
        assert.equal(r.data.truncado, true);
        assert.deepEqual(Object.keys(r.data).sort(), ['itens', 'modo', 'truncado']);
        for (const item of r.data.itens) {
          assert.deepEqual(Object.keys(item).sort(),
            ['acoes', 'apelido', 'avatarRef', 'publicId', 'relacao']);
        }
        const comCursor = await oculto.quem.buscar({
          termo: 'Trombone', limite: 2, cursor: 'x', proximoCursor: 'x', depoisDe: 'x',
        });
        assert.deepEqual(comCursor.data, r.data);
      });

      test('a varredura nao vaza UID nem na resposta truncada', async () => {
        const r = await oculto.quem.buscar({ termo: 'Trombone', limite: 2 });
        const bruto = JSON.stringify(r.data);
        for (const uidReal of [
          oculto.quem.uid, oculto.aa.c.uid, oculto.bb.c.uid,
          oculto.cc.c.uid, oculto.dd.c.uid,
        ]) {
          assert.equal(bruto.includes(uidReal), false, 'UID vazou na varredura');
        }
      });
    });

    // ==========================================================================
    // ESTRESSE — a garantia nao pode ter teto
    //
    // Uma versao anterior parava a varredura em cinco rodadas. O teto
    // reintroduzia a mesma classe de vazamento que a varredura fecha: parar sem
    // ter esgotado a faixa fazia `truncado` depender de QUANTOS estavam ocultos,
    // e deixava os candidatos legitimos que vinham DEPOIS dos ocultos fora da
    // resposta — "roubo de vaga" em escala maior.
    //
    // Este bloco poe 300 ocultos na frente de tres legitimos. Com os limites
    // usados aqui, cinco rodadas alcançavam 93 documentos; com o limite padrao,
    // 265. Os 300 passam dos dois de folga, entao a suite falha se o teto voltar
    // em qualquer forma.
    //
    // OS PERFIS SAO SEMEADOS DIRETO, e nao criados por conta anonima: a busca le
    // `publicProfiles`, `publicIdIndex` e `users/{uid}/blocks`, e trezentas
    // contas de verdade custariam novecentas chamadas de Function para provar
    // uma propriedade que nao depende de nenhuma delas.
    // ==========================================================================

    describe('estresse: centenas de ocultos nao mudam a resposta', () => {
      const { writeBatch } = require('firebase/firestore');

      const TERMO = 'Enxame';
      const OCULTOS = 300;
      const estresse = {};

      /// publicId valido: 'P' + 12 simbolos do alfabeto de Crockford. O corpo e
      /// 'V' seguido de 11 digitos, todos dentro do alfabeto.
      const pidOculto = (i) => `PV${String(i).padStart(11, '0')}`;
      const uidOculto = (i) => `uidEnxameOculto${String(i).padStart(4, '0')}`;

      /// Semeia N perfis ocultos, todos bloqueando quem procura.
      ///
      /// Os apelidos comecam com "A" para caírem ANTES dos visiveis na ordem —
      /// que e a posicao em que eles atrapalham.
      async function semearOcultos(de, ate, euUid) {
        await ambiente.withSecurityRulesDisabled(async (ctx) => {
          const db = ctx.firestore();
          let lote = writeBatch(db);
          let n = 0;
          for (let i = de; i < ate; i++) {
            const pid = pidOculto(i);
            const uid = uidOculto(i);
            const rotulo = String(i).padStart(4, '0');
            lote.set(doc(db, `publicProfiles/${pid}`), {
              publicId: pid,
              apelido: `${TERMO} A${rotulo}`,
              apelidoOrdenacao: `${TERMO.toLowerCase()} a${rotulo}`,
              avatarRef: null,
              estado: 'ativo',
              criadoEm: '2026-01-01T00:00:00.000Z',
              atualizadoEm: '2026-01-01T00:00:00.000Z',
              esquema: 1,
            });
            lote.set(doc(db, `publicIdIndex/${pid}`), { publicId: pid, uid });
            lote.set(doc(db, `users/${uid}/blocks/${euUid}`), {
              bloqueadorUid: uid, bloqueadoUid: euUid, esquema: 1,
            });
            n += 3;
            if (n >= 400) { await lote.commit(); lote = writeBatch(db); n = 0; }
          }
          if (n > 0) await lote.commit();
        });
      }

      async function apagarOcultos(de, ate) {
        await ambiente.withSecurityRulesDisabled(async (ctx) => {
          const db = ctx.firestore();
          let lote = writeBatch(db);
          let n = 0;
          for (let i = de; i < ate; i++) {
            lote.delete(doc(db, `publicProfiles/${pidOculto(i)}`));
            lote.delete(doc(db, `publicIdIndex/${pidOculto(i)}`));
            n += 2;
            if (n >= 400) { await lote.commit(); lote = writeBatch(db); n = 0; }
          }
          if (n > 0) await lote.commit();
        });
      }

      before(async () => {
        estresse.quem = await cliente('estresse-buscador');
        await estresse.quem.identidade({});

        // Os tres legitimos, DEPOIS dos ocultos na ordem ("z" > "a").
        estresse.visiveis = [];
        for (const sufixo of ['Z1', 'Z2', 'Z3']) {
          const c = await cliente(`estresse-visivel-${sufixo}`);
          const publicId = (await c.identidade({})).data.publicId;
          await c.atualizar({ apelido: `${TERMO} ${sufixo}` });
          estresse.visiveis.push(publicId);
        }

        await semearOcultos(0, OCULTOS, estresse.quem.uid);
      });

      test('os legitimos preenchem as vagas, atras de 300 ocultos', async () => {
        // Cinco rodadas alcançavam 93 documentos com este limite. Se o teto
        // voltar, esta chamada devolve lista vazia ou incompleta.
        const r = await estresse.quem.buscar({ termo: TERMO, limite: 2 });
        assert.deepEqual(r.data.itens.map((i) => i.publicId),
          [estresse.visiveis[0], estresse.visiveis[1]]);
        assert.equal(r.data.truncado, true, 'o terceiro visivel ainda esta la');
      });

      test('`truncado` depende SO dos visiveis, com 300 ocultos na frente', async () => {
        // Tres visiveis, limite tres: a resposta esta completa. Qualquer termo
        // sobre "como a varredura terminou" — teto, rodadas, lote bruto —
        // colocaria `true` aqui, e esse `true` seria a existencia dos 300.
        const r = await estresse.quem.buscar({ termo: TERMO, limite: 3 });
        assert.deepEqual(r.data.itens.map((i) => i.publicId), estresse.visiveis);
        assert.equal(r.data.truncado, false);
      });

      test('APAGAR ocultos nao altera nenhum campo observavel', async () => {
        const antes = await estresse.quem.buscar({ termo: TERMO, limite: 3 });
        await apagarOcultos(0, 150);
        const depois = await estresse.quem.buscar({ termo: TERMO, limite: 3 });
        assert.deepEqual(depois.data, antes.data,
          'metade dos ocultos sumiu e a resposta tem que ser identica');
      });

      test('ACRESCENTAR ocultos nao altera nenhum campo observavel', async () => {
        const antes = await estresse.quem.buscar({ termo: TERMO, limite: 3 });
        await semearOcultos(OCULTOS, OCULTOS + 120, estresse.quem.uid);
        const depois = await estresse.quem.buscar({ termo: TERMO, limite: 3 });
        assert.deepEqual(depois.data, antes.data,
          'mais 120 ocultos e a resposta tem que ser identica');

        // E de volta ao inicio: a resposta e a mesma dos tres estados.
        await apagarOcultos(OCULTOS, OCULTOS + 120);
        const restaurado = await estresse.quem.buscar({ termo: TERMO, limite: 3 });
        assert.deepEqual(restaurado.data, antes.data);
      });

      test('a mesma faixa, para quem NAO foi bloqueado, mostra os ocultos', async () => {
        // A contraprova: os 150 perfis restantes existem e sao encontraveis.
        // Sem ela, os testes acima passariam com uma busca simplesmente vazia.
        const terceiro = await cliente('estresse-terceiro');
        await terceiro.identidade({});
        const r = await terceiro.buscar({ termo: TERMO, limite: 3 });
        assert.equal(r.data.itens.length, 3);
        assert.equal(r.data.truncado, true, 'para ele ha centenas de Enxame');
        // E os que ele ve sao os "A", que vem antes dos visiveis na ordem.
        assert.equal(
          r.data.itens.every((i) => i.apelido.startsWith(`${TERMO} A`)), true,
        );
      });

      test('e nada disso vaza UID ou expoe cursor', async () => {
        const r = await estresse.quem.buscar({ termo: TERMO, limite: 2 });
        assert.deepEqual(Object.keys(r.data).sort(), ['itens', 'modo', 'truncado']);
        const bruto = JSON.stringify(r.data);
        assert.equal(bruto.includes(estresse.quem.uid), false);
        assert.equal(bruto.includes('uidEnxameOculto'), false);
      });
    });

    // ---------------------------------------------------------- autenticacao

    test('sem autenticacao, a busca e recusada', async () => {
      const { initializeApp: init } = require('firebase/app');
      const app = init({ projectId: PROJETO, apiKey: 'fake' }, 'busca-anonima');
      const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
      const f = getFunctions(app, 'southamerica-east1');
      connectFunctionsEmulator(f, host, Number(porta));
      await assert.rejects(
        () => httpsCallable(f, 'buscarJogadoresPorApelido')({ termo: RARO }),
        (e) => e.code === 'functions/unauthenticated',
      );
    });
  });

  // =========================================================================
  // SEGUIR — SOCIAL-02, etapa C3 (O01–O09, O12, O13)
  // =========================================================================
  //
  // Callables REAIS via HTTP no emulador, contra dados no formato congelado da
  // C2 r2. Cada caso cria jogadores anonimos novos, entao nenhum depende de
  // outro. Plano, diario, corte e ritmo sao SEMEADOS com regras desligadas: e o
  // estado que Billing, Conta e Moderacao gravariam, sem subir esses codebases.
  // Nada aqui executa o executor real da Conta nem o bloqueio real (C4).

  describe('seguir (SOCIAL-02 C3)', () => {
    const FUTURO = '2099-01-01T00:00:00.000Z';
    const PASSADO = '2000-01-01T00:00:00.000Z';
    const MIN = 60 * 1000;
    const HORA = 60 * MIN;
    const SEGUIR_ACOES = new Set([
      'seguir', 'solicitarSeguir', 'cancelarPedidoSeguir', 'deixarDeSeguir',
      'aprovarPedidoSeguir', 'recusarPedidoSeguir', 'removerSeguidor',
    ]);
    const SAIDA = new Set(['seguir', 'cancelarSeguir', 'deixarSeguir']);
    let seq = 0;

    const semear = (caminho, dados) => ambiente.withSecurityRulesDisabled(
      (ctx) => setDoc(doc(ctx.firestore(), caminho), dados));
    const apagar = (caminho) => ambiente.withSecurityRulesDisabled(
      (ctx) => deleteDoc(doc(ctx.firestore(), caminho)));
    async function ler(caminho) {
      let v;
      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        const s = await getDoc(doc(ctx.firestore(), caminho));
        v = s.exists() ? s.data() : undefined;
      });
      return v;
    }

    /// Entitlement canonico (o que `vigenteEm` le). `extra` sobrescreve.
    const vip = (j, extra = {}) => semear(`playerEntitlements/${j.uid}`, {
      vipAtivo: true, estado: 'ativo', origem: 'play', expiraEm: FUTURO, ...extra,
    });
    const diario = (j) => semear(`accountDeletions/${j.uid}`, { estado: 'iniciada', esquema: 1 });
    const R = (j) => `playerSocialRitmo/${j.uid}`;
    const ritmo = (j) => ler(R(j));
    const canonico = (s, d) => ler(`follows/${s.uid}|${d.uid}`);
    const semearCorte = (x, y, corteId) => semear(
      `cortesDeRelacao/${[x.uid, y.uid].sort().join('|')}`,
      { corteId, membros: [x.uid, y.uid].sort(), atualizadoEm: new Date().toISOString(), esquema: 1 },
    );
    const instantes = (...atras) => atras.map((ms) => new Date(Date.now() - ms).toISOString());
    const intencao = () => `i${Date.now().toString(36)}x${(++seq).toString(36)}`;

    async function jogador({ comVip = true } = {}) {
      const c = await cliente(`seguir-${++seq}`);
      c.pid = (await c.identidade({})).data.publicId;
      if (comVip) await vip(c);
      return c;
    }
    const privado = (j) => j.privacidade({ privacidade: 'privado' });
    const bloco = async (obs, alvo) => (await obs.verPerfil({ publicId: alvo.pid })).data.seguir;

    /// Um comando como o cliente faria: a referencia vem da releitura por O12.
    async function cmd(ator, nome, alvo, opcoes = {}) {
      let referencia = opcoes.referencia;
      if (!('referencia' in opcoes)) {
        const b = await bloco(ator, alvo);
        referencia = b ? (SAIDA.has(nome) ? b.meu.referencia : b.dele.referencia) : null;
      }
      const r = await ator[nome]({
        publicId: alvo.pid, referencia, intencaoId: opcoes.intencaoId ?? intencao(),
      });
      return r.data;
    }

    const recusa = (codigo, http) => (e) => {
      assert.equal(e.details?.recusa, codigo, `esperava ${codigo}, veio ${e.details?.recusa} (${e.code})`);
      if (http) assert.equal(e.code, `functions/${http}`);
      return true;
    };

    /// Os espelhos fisicos da direcao s -> d (adendo A1).
    function caminhosEspelho(s, d) {
      return {
        P1: `users/${s.uid}/seguindo/${d.uid}`,
        P2: `users/${d.uid}/seguidores/${s.uid}`,
        P3: `users/${s.uid}/pedidosSeguirEnviados/${d.uid}`,
        P4: `users/${d.uid}/pedidosSeguirRecebidos/${s.uid}`,
      };
    }
    async function espelhos(s, d) {
      const presentes = [];
      for (const [k, c] of Object.entries(caminhosEspelho(s, d))) {
        if (await ler(c)) presentes.push(k);
      }
      return presentes.join('+') || 'nenhum';
    }

    // --------------------------------------------------- criacao e gestao

    test('S03/O01 — VIP segue VIP publico: confirma na hora, so P1/P2, sem amizade e sem seguir de volta', async () => {
      const a = await jogador();
      const b = await jogador();
      const r = await cmd(a, 'seguir', b, { referencia: null });
      assert.equal(r.ok, true);
      assert.equal(r.repeticao, false);
      assert.equal(r.estado, 'seguindo');
      assert.equal(typeof r.referencia, 'string');
      assert.equal(await espelhos(a, b), 'P1+P2');
      assert.equal(await espelhos(b, a), 'nenhum', 'nao segue de volta');
      const c = await canonico(a, b);
      assert.equal(c.estado, 'confirmado');
      assert.equal(c.esquema, 1);
      assert.equal(c.criacoesRecentes.length, 1);
      assert.equal(typeof c.desde, 'string');
      assert.equal((await ler(`users/${a.uid}/seguindo/${b.uid}`)).referencia, r.referencia);
      assert.equal((await ler(`users/${a.uid}/seguindo/${b.uid}`)).publicId, b.pid);
      assert.equal((await ler(`users/${b.uid}/seguidores/${a.uid}`)).publicId, a.pid);
      assert.equal(await ler(`friendships/${[a.uid, b.uid].sort().join('|')}`), undefined,
        'seguir nao cria amizade');
      const rit = await ritmo(a);
      assert.equal(rit.pedidosPendentesEnviados, 0);
      assert.equal(rit.criacoes.length, 1);
      assert.equal((await a.contadores({})).data.contadores.seguindo, 1);
      assert.equal((await b.contadores({})).data.contadores.seguidores, 1);
      assert.equal((await b.contadores({})).data.contadores.seguindo, 0);
    });

    test('S04/S12/O02 — perfil privado: vira pedido, so P3/P4, remetente +1, detalhes null e nao conta como seguidor', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      const r = await cmd(a, 'seguir', b, { referencia: null });
      assert.equal(r.estado, 'pendente');
      assert.equal(await espelhos(a, b), 'P3+P4');
      const c = await canonico(a, b);
      assert.equal(c.estado, 'pendente');
      assert.equal(c.desde, null, 'pedido ainda nao e vinculo');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
      const v = (await a.verPerfil({ publicId: b.pid })).data;
      assert.equal(v.detalhes, null);
      assert.equal(v.seguir.meu.estado, 'pendente');
      assert.ok(v.acoes.includes('cancelarPedidoSeguir'));
      const cb = (await b.contadores({})).data.contadores;
      assert.equal(cb.seguidores, 0, 'pendente nao conta como seguidor');
      assert.equal(cb.pedidosSeguirRecebidos, 1);
    });

    test('S05/O04 — so o seguido aprova; aprovacoes paralelas dao UMA escrita e UM debito no remetente', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      const criacoesAntes = (await ritmo(a)).criacoes.length;
      // O remetente nao aprova o proprio pedido: a direcao b -> a nao existe.
      await assert.rejects(() => cmd(a, 'aprovarSeguir', b), recusa('referenciaObsoleta'));
      const ref = (await bloco(b, a)).dele.referencia;
      const rs = await Promise.all([0, 1, 2].map(
        () => cmd(b, 'aprovarSeguir', a, { referencia: ref })));
      assert.ok(rs.every((x) => x.ok && x.estado === 'seguidor'));
      assert.equal(rs.filter((x) => !x.repeticao).length, 1, 'uma so escrita');
      assert.equal(await espelhos(a, b), 'P1+P2');
      const rit = await ritmo(a);
      assert.equal(rit.pedidosPendentesEnviados, 0, 'debito unico no remetente, que nao e o ator');
      assert.equal(rit.criacoes.length, criacoesAntes, 'aprovar nao consome ritmo');
      assert.equal(await ritmo(b), undefined, 'o ritmo de quem aprova nao e tocado');
    });

    test('S06/O05 — recusar encerra sem vinculo e sem punir; repetir nao debita; novo pedido guarda o historico por alvo', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      const r = await cmd(b, 'recusarSeguir', a);
      assert.equal(r.estado, 'nenhum');
      assert.equal(r.repeticao, false);
      assert.equal(await espelhos(a, b), 'nenhum');
      assert.equal((await canonico(a, b)).estado, 'encerrado');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
      assert.equal(await ler(`users/${b.uid}/blocks/${a.uid}`), undefined, 'recusar nao bloqueia');
      const deNovo = await cmd(b, 'recusarSeguir', a);
      assert.equal(deNovo.repeticao, true);
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0, 'sem segundo debito');
      const r2 = await cmd(a, 'seguir', b);
      assert.equal(r2.estado, 'pendente');
      assert.equal((await canonico(a, b)).criacoesRecentes.length, 2, 'a recriacao preserva o historico');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
      assert.equal((await ritmo(a)).criacoes.length, 2);
    });

    test('S06/S28d/O03 — so o remetente cancela; debito unico; o reenvio do pedido cancelado nao o recria', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      const X = intencao();
      await cmd(a, 'seguir', b, { referencia: null, intencaoId: X });
      // B "cancelar" age sobre b -> a, que nao existe: o desfecho ja vale.
      const rb = await cmd(b, 'cancelarSeguir', a);
      assert.equal(rb.repeticao, true);
      assert.equal(await espelhos(a, b), 'P3+P4', 'o pedido de A continua');
      const ref = (await bloco(a, b)).meu.referencia;
      const Y = intencao();
      const r = await cmd(a, 'cancelarSeguir', b, { referencia: ref, intencaoId: Y });
      assert.equal(r.estado, 'nenhum');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
      const r2 = await cmd(a, 'cancelarSeguir', b, { referencia: ref, intencaoId: Y });
      assert.equal(r2.repeticao, true, 'reenvio do cancelamento');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0, 'sem segundo debito');
      await assert.rejects(
        () => cmd(a, 'seguir', b, { referencia: null, intencaoId: X }),
        recusa('referenciaObsoleta'));
      assert.equal(await espelhos(a, b), 'nenhum', 'o pedido cancelado nao volta');
      assert.equal((await ritmo(a)).criacoes.length, 1);
    });

    test('S07/S16/O06/O07 — deixar de seguir e remover seguidor encerram SO a sua direcao; amizade intocada', async () => {
      const a = await jogador();
      const b = await jogador();
      await a.enviar({ publicId: b.pid });
      await b.aceitar({ publicId: a.pid });
      const par = `friendships/${[a.uid, b.uid].sort().join('|')}`;
      const amizade = await ler(par);
      assert.equal(amizade.estado, 'amigos');
      await cmd(a, 'seguir', b, { referencia: null });
      await cmd(b, 'seguir', a, { referencia: null });
      assert.equal(await espelhos(a, b), 'P1+P2');
      assert.equal(await espelhos(b, a), 'P1+P2', 'reciprocidade e outra direcao, independente');
      const r = await cmd(a, 'deixarSeguir', b);
      assert.equal(r.estado, 'nenhum');
      assert.equal(await espelhos(a, b), 'nenhum');
      assert.equal(await espelhos(b, a), 'P1+P2', 'a direcao inversa fica');
      const r2 = await cmd(a, 'removerSeguidor', b);
      assert.equal(r2.estado, 'nenhum');
      assert.equal(await espelhos(b, a), 'nenhum');
      assert.equal((await canonico(b, a)).estado, 'encerrado');
      assert.equal((await canonico(b, a)).desde, null);
      assert.deepEqual(await ler(par), amizade, 'friendships intocado');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
      assert.equal((await ritmo(b)).pedidosPendentesEnviados, 0);
    });

    test('S31 — pedidos reciprocos simultaneos: quatro projecoes; decidir um deixa o inverso intacto', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(a);
      await privado(b);
      const [ra, rb] = await Promise.all([
        cmd(a, 'seguir', b, { referencia: null }),
        cmd(b, 'seguir', a, { referencia: null }),
      ]);
      assert.equal(ra.estado, 'pendente');
      assert.equal(rb.estado, 'pendente');
      assert.equal(await espelhos(a, b), 'P3+P4');
      assert.equal(await espelhos(b, a), 'P3+P4');
      const ka = (await a.contadores({})).data.contadores;
      assert.equal(ka.pedidosSeguirEnviados, 1);
      assert.equal(ka.pedidosSeguirRecebidos, 1);
      await cmd(b, 'aprovarSeguir', a);
      assert.equal(await espelhos(a, b), 'P1+P2');
      assert.equal(await espelhos(b, a), 'P3+P4', 'o pedido inverso continua');
      assert.equal((await ritmo(b)).pedidosPendentesEnviados, 1);
      await cmd(a, 'recusarSeguir', b);
      assert.equal(await espelhos(b, a), 'nenhum');
      assert.equal(await espelhos(a, b), 'P1+P2', 'o vinculo inverso continua');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
      assert.equal((await ritmo(b)).pedidosPendentesEnviados, 0);
    });

    // ---------------------------------------------------------- elegibilidade

    test('S01/S02/S09/S27 — gratuito, vencido, ilegivel e so-passe nao entram; VIP manual entra; recusa nao grava', async () => {
      const a = await jogador();
      const gratis = await jogador({ comVip: false });
      const vencido = await jogador();
      await vip(vencido, { expiraEm: PASSADO });
      const ilegivel = await jogador({ comVip: false });
      await semear(`playerEntitlements/${ilegivel.uid}`, {
        vipAtivo: true, estado: 'ativo', origem: 'play', expiraEm: 'nao-e-data',
      });
      const soPasse = await jogador({ comVip: false });
      await semear(`passesVip/${soPasse.uid}`, { ativo: true, expiraEm: FUTURO });
      await semear(`playerCourtesyPass/${soPasse.uid}`, { ativo: true, expiraEm: FUTURO });
      for (const alvo of [gratis, vencido, ilegivel, soPasse]) {
        await assert.rejects(() => cmd(a, 'seguir', alvo, { referencia: null }),
          recusa('acaoIndisponivel', 'failed-precondition'));
        assert.equal(await canonico(a, alvo), undefined);
        assert.equal(await espelhos(a, alvo), 'nenhum');
      }
      for (const ator of [gratis, vencido, ilegivel, soPasse]) {
        await assert.rejects(() => cmd(ator, 'seguir', a, { referencia: null }),
          recusa('requerVip', 'failed-precondition'));
        assert.equal(await canonico(ator, a), undefined);
        assert.equal(await ritmo(ator), undefined);
      }
      assert.equal(await ritmo(a), undefined, 'recusa nao consome nem cria ritmo');
      const manual = await jogador({ comVip: false });
      await vip(manual, { origem: 'administrativa' });
      assert.equal((await cmd(a, 'seguir', manual, { referencia: null })).estado, 'seguindo');
    });

    test('S13/S29 — o plano vence e volta sem escrita: lista e contagem iguais; acoes somem e voltam; encerrar nao exige VIP do outro', async () => {
      const a = await jogador();
      const b = await jogador();
      await cmd(a, 'seguir', b, { referencia: null });
      const foto = async () => {
        const vb = (await b.verPerfil({ publicId: a.pid })).data;
        return {
          lista: (await a.listarSeguindo({})).data.itens.map((i) => i.publicId),
          conta: (await a.contadores({})).data.contadores.seguindo,
          acoesB: vb.acoes.filter((x) => SEGUIR_ACOES.has(x)).sort(),
          blocoB: vb.seguir,
        };
      };
      const canonAntes = await canonico(a, b);
      const antes = await foto();
      await vip(b, { expiraEm: PASSADO });
      const durante = await foto();
      await vip(b);
      const volta = await foto();
      assert.deepEqual(antes.lista, [b.pid]);
      assert.deepEqual(durante.lista, antes.lista);
      assert.deepEqual(volta.lista, antes.lista);
      assert.equal(antes.conta, 1);
      assert.equal(durante.conta, 1);
      assert.equal(volta.conta, 1);
      assert.deepEqual(antes.acoesB, ['removerSeguidor', 'seguir']);
      assert.deepEqual(durante.acoesB, []);
      assert.equal(durante.blocoB, null);
      assert.deepEqual(volta.acoesB, antes.acoesB);
      assert.deepEqual(await canonico(a, b), canonAntes, 'vencer e voltar nao escreve');
      await vip(a, { expiraEm: PASSADO });
      await assert.rejects(() => cmd(a, 'deixarSeguir', b), recusa('requerVip'));
      assert.equal((await canonico(a, b)).estado, 'confirmado');
      await vip(a);
      await vip(b, { expiraEm: PASSADO });
      assert.equal((await cmd(a, 'deixarSeguir', b)).estado, 'nenhum', 'encerrar nao exige VIP do outro');
    });

    test('S26 — aprovar revalida as duas pontas: remetente sem VIP fica pendente; recusar nao exige o VIP dele', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      await vip(a, { expiraEm: PASSADO });
      await assert.rejects(() => cmd(b, 'aprovarSeguir', a), recusa('acaoIndisponivel'));
      assert.equal((await canonico(a, b)).estado, 'pendente');
      assert.equal(await espelhos(a, b), 'P3+P4');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
      const r = await cmd(b, 'recusarSeguir', a);
      assert.equal(r.estado, 'nenhum');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
    });

    test('S14/O09 — privacidade: publico ate escolher; repeticao sem escrita; fechar mantem; abrir nao aprova; a escolha persiste apos vencer', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      assert.equal((await b.contadores({})).data.contadores.privacidade, 'publico');
      const r0 = (await b.privacidade({ privacidade: 'publico' })).data;
      assert.equal(r0.repeticao, true);
      assert.equal(await ler(`playerSocial/${b.uid}`), undefined, 'repeticao nao grava');
      await cmd(a, 'seguir', b, { referencia: null });
      const r1 = (await b.privacidade({ privacidade: 'privado' })).data;
      assert.deepEqual(r1, { ok: true, repeticao: false, privacidade: 'privado' });
      assert.deepEqual(await ler(`playerSocial/${b.uid}`), { privacidade: 'privado' },
        'so o campo de privacidade');
      assert.equal((await b.privacidade({ privacidade: 'privado' })).data.repeticao, true);
      assert.equal(await espelhos(a, b), 'P1+P2', 'fechar mantem quem ja seguia');
      assert.equal((await cmd(c, 'seguir', b, { referencia: null })).estado, 'pendente');
      await b.privacidade({ privacidade: 'publico' });
      assert.equal(await espelhos(c, b), 'P3+P4', 'abrir nao aprova pedidos');
      assert.equal((await canonico(c, b)).estado, 'pendente');
      await b.privacidade({ privacidade: 'privado' });
      await vip(b, { expiraEm: PASSADO });
      await assert.rejects(() => b.privacidade({ privacidade: 'publico' }), recusa('requerVip'));
      assert.equal((await ler(`playerSocial/${b.uid}`)).privacidade, 'privado',
        'a escolha privada persiste depois de vencer');
      await assert.rejects(() => a.privacidade({ privacidade: 'aberto' }),
        recusa('pedidoInvalido', 'invalid-argument'));
      await assert.rejects(() => a.privacidade({}), recusa('pedidoInvalido', 'invalid-argument'));
    });

    test('S20 — gratuito: Ver Perfil funciona sem bloco; listas, contadores e privacidade pedem VIP', async () => {
      const g = await jogador({ comVip: false });
      const b = await jogador();
      const v = (await g.verPerfil({ publicId: b.pid })).data;
      assert.equal(v.seguir, null);
      assert.equal(v.detalhes, null);
      assert.ok(!v.acoes.some((x) => SEGUIR_ACOES.has(x)));
      for (const nome of ['listarSeguidores', 'listarSeguindo', 'listarPedidosRecebidos',
        'listarPedidosEnviados', 'contadores']) {
        await assert.rejects(() => g[nome]({}), recusa('requerVip', 'failed-precondition'));
      }
      await assert.rejects(() => g.privacidade({ privacidade: 'privado' }), recusa('requerVip'));
      assert.equal(await ler(`playerSocial/${g.uid}`), undefined);
    });

    // Precisao do parecer C3 R1 §4: o dominio C1 distingue as pontas. Diario no
    // ALVO: criar recusa e encerrar e repeticao com estado `nenhum`. Diario no
    // ATOR: tudo recusa com `acaoIndisponivel` (caso seguinte). Em nenhum dos
    // dois ha escrita, e a limpeza e da exclusao (O14).
    test('S30b/S30c — diario no ALVO: nada nasce e encerrar e repeticao nenhum sem escrita; diario no dono: criar, listar, contar e privacidade recusam', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      await cmd(a, 'seguir', b, { referencia: null });
      const refAB = (await bloco(a, b)).meu.referencia;
      const antes = await canonico(a, b);
      await diario(b);
      await assert.rejects(() => cmd(c, 'seguir', b, { referencia: null }),
        recusa('perfilPublicoNaoDisponivel', 'not-found'));
      assert.equal(await canonico(c, b), undefined);
      const r = await cmd(a, 'deixarSeguir', b, { referencia: refAB });
      assert.equal(r.repeticao, true);
      assert.equal(r.estado, 'nenhum');
      assert.deepEqual(await canonico(a, b), antes, 'nenhuma escrita depois do diario');
      assert.equal(await espelhos(a, b), 'P1+P2', 'a limpeza e da exclusao (O14)');
      assert.equal(await bloco(a, b), null);
      await diario(c);
      await assert.rejects(() => cmd(c, 'seguir', a, { referencia: null }), recusa('acaoIndisponivel'));
      assert.equal(await canonico(c, a), undefined);
      for (const nome of ['listarSeguidores', 'contadores']) {
        await assert.rejects(() => c[nome]({}), recusa('acaoIndisponivel'));
      }
      await assert.rejects(() => c.privacidade({ privacidade: 'privado' }), recusa('acaoIndisponivel'));
      assert.equal(await ritmo(c), undefined);
      assert.equal(await ler(`playerSocial/${c.uid}`), undefined);
    });

    test('S30b/S30c — diario no ATOR: encerrar (deixar, remover, cancelar) recusa com acaoIndisponivel e nada e gravado', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      await privado(c);
      await cmd(a, 'seguir', b, { referencia: null });
      await cmd(b, 'seguir', a, { referencia: null });
      await cmd(a, 'seguir', c, { referencia: null });
      const refDeixar = (await bloco(a, b)).meu.referencia;
      const refRemover = (await bloco(a, b)).dele.referencia;
      const refCancelar = (await bloco(a, c)).meu.referencia;
      const antes = {
        ab: await canonico(a, b), ba: await canonico(b, a), ac: await canonico(a, c),
        ritmoA: await ritmo(a), ritmoB: await ritmo(b),
      };
      await diario(a);
      await assert.rejects(() => cmd(a, 'deixarSeguir', b, { referencia: refDeixar }),
        recusa('acaoIndisponivel', 'failed-precondition'));
      await assert.rejects(() => cmd(a, 'removerSeguidor', b, { referencia: refRemover }),
        recusa('acaoIndisponivel', 'failed-precondition'));
      await assert.rejects(() => cmd(a, 'cancelarSeguir', c, { referencia: refCancelar }),
        recusa('acaoIndisponivel', 'failed-precondition'));
      assert.deepEqual(await canonico(a, b), antes.ab);
      assert.deepEqual(await canonico(b, a), antes.ba);
      assert.deepEqual(await canonico(a, c), antes.ac);
      assert.deepEqual(await ritmo(a), antes.ritmoA, 'cancelar recusado nao debita');
      assert.deepEqual(await ritmo(b), antes.ritmoB);
      assert.equal(await espelhos(a, b), 'P1+P2', 'a limpeza e da exclusao (O14)');
      assert.equal(await espelhos(b, a), 'P1+P2');
      assert.equal(await espelhos(a, c), 'P3+P4');
    });

    // ------------------------------------------- referencia, intencao, corte

    test('S28a — aprovacao atrasada de pedido cancelado, com pedido novo: referenciaObsoleta e o novo fica', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      const refA = (await bloco(b, a)).dele.referencia;
      await cmd(a, 'cancelarSeguir', b);
      await cmd(a, 'seguir', b);
      await assert.rejects(() => cmd(b, 'aprovarSeguir', a, { referencia: refA }),
        recusa('referenciaObsoleta', 'failed-precondition'));
      assert.equal((await canonico(a, b)).estado, 'pendente');
      assert.equal(await espelhos(a, b), 'P3+P4');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
    });

    test('S28b — deixar de seguir atrasado depois de seguir de novo: referenciaObsoleta e o vinculo novo continua', async () => {
      const a = await jogador();
      const b = await jogador();
      await cmd(a, 'seguir', b, { referencia: null });
      const s1 = (await bloco(a, b)).meu.referencia;
      await cmd(a, 'deixarSeguir', b, { referencia: s1 });
      await cmd(a, 'seguir', b);
      await assert.rejects(() => cmd(a, 'deixarSeguir', b, { referencia: s1 }),
        recusa('referenciaObsoleta'));
      assert.equal(await espelhos(a, b), 'P1+P2');
    });

    test('S28c/S33 — reenvio da mesma intencao e repeticao sem consumo; a mesma intencao em outro comando e pedidoInvalido; depois de deixar, o reenvio nao recria', async () => {
      const a = await jogador();
      const b = await jogador();
      const X = intencao();
      await cmd(a, 'seguir', b, { referencia: null, intencaoId: X });
      const rep = await cmd(a, 'seguir', b, { referencia: null, intencaoId: X });
      assert.equal(rep.repeticao, true);
      assert.equal(rep.estado, 'seguindo');
      assert.equal((await ritmo(a)).criacoes.length, 1, 'repeticao nao consome');
      await assert.rejects(() => cmd(a, 'deixarSeguir', b, { intencaoId: X }),
        recusa('pedidoInvalido', 'invalid-argument'));
      assert.equal(await espelhos(a, b), 'P1+P2');
      await cmd(a, 'deixarSeguir', b);
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null, intencaoId: X }),
        recusa('referenciaObsoleta'));
      assert.equal(await espelhos(a, b), 'nenhum', 'nada e recriado');
      assert.equal((await ritmo(a)).criacoes.length, 1);
    });

    test('S33b — o reenvio de um seguir aceito nao atravessa plano nem exclusao do alvo', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      const X = intencao();
      await cmd(a, 'seguir', b, { referencia: null, intencaoId: X });
      await vip(b, { expiraEm: PASSADO });
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null, intencaoId: X }),
        recusa('acaoIndisponivel'));
      const Y = intencao();
      await cmd(a, 'seguir', c, { referencia: null, intencaoId: Y });
      await diario(c);
      await assert.rejects(() => cmd(a, 'seguir', c, { referencia: null, intencaoId: Y }),
        recusa('perfilPublicoNaoDisponivel'));
    });

    test('S32e(i) — corte semeado: confirmado antigo vale encerrado; B privado; o pedido com a referencia atual deixa SO P3+P4 e soma 1', async () => {
      const a = await jogador();
      const b = await jogador();
      await cmd(a, 'seguir', b, { referencia: null });
      await cmd(b, 'seguir', a, { referencia: null });
      const inversoAntes = await canonico(b, a);
      await semearCorte(a, b, 'corte1');
      const v = await bloco(a, b);
      assert.equal(v.meu.estado, 'nenhum', 'a geracao antiga vale encerrada');
      assert.match(v.meu.referencia, /\.corte1$/);
      await privado(b);
      const r = await cmd(a, 'seguir', b);
      assert.equal(r.estado, 'pendente');
      assert.equal(await espelhos(a, b), 'P3+P4');
      const c = await canonico(a, b);
      assert.equal(c.estado, 'pendente');
      assert.equal(c.corteNaCriacao, 'corte1');
      assert.equal(c.criacoesRecentes.length, 2);
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
      assert.deepEqual(await canonico(b, a), inversoAntes, 'a direcao inversa nao e tocada');
      assert.equal(await espelhos(b, a), 'P1+P2');
    });

    test('S32e(ii)/S33d — pedido cortado: o reenvio exato e obsoleto; B publico; seguir com a referencia nova deixa SO P1+P2 e debita 1', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      const X = intencao();
      await cmd(a, 'seguir', b, { referencia: null, intencaoId: X });
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
      await semearCorte(a, b, 'corte2');
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null, intencaoId: X }),
        recusa('referenciaObsoleta'));
      const v = await bloco(a, b);
      assert.equal(v.meu.estado, 'nenhum');
      const rc = await cmd(a, 'cancelarSeguir', b, { referencia: v.meu.referencia });
      assert.equal(rc.repeticao, true);
      assert.equal((await canonico(a, b)).estado, 'pendente', 'sem escrita: a faxina e da C4');
      await assert.rejects(() => cmd(b, 'aprovarSeguir', a), recusa('referenciaObsoleta'));
      await b.privacidade({ privacidade: 'publico' });
      const r = await cmd(a, 'seguir', b, { referencia: v.meu.referencia });
      assert.equal(r.estado, 'seguindo');
      assert.equal(await espelhos(a, b), 'P1+P2');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0,
        'o pedido fisico substituido sai do contador');
      assert.equal((await canonico(a, b)).corteNaCriacao, 'corte2');
    });

    test('P1–P4 — cada transicao deixa exatamente os espelhos do estado novo, com a referencia da resposta', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      const passos = [
        [() => cmd(a, 'seguir', b, { referencia: null }), 'P3+P4'],
        [() => cmd(a, 'cancelarSeguir', b), 'nenhum'],
        [() => cmd(a, 'seguir', b), 'P3+P4'],
        [() => cmd(b, 'aprovarSeguir', a), 'P1+P2'],
        [() => cmd(b, 'removerSeguidor', a), 'nenhum'],
        [async () => {
          await b.privacidade({ privacidade: 'publico' });
          return cmd(a, 'seguir', b);
        }, 'P1+P2'],
        [() => cmd(a, 'deixarSeguir', b), 'nenhum'],
      ];
      for (const [passo, esperado] of passos) {
        const r = await passo();
        assert.equal(await espelhos(a, b), esperado);
        for (const caminho of Object.values(caminhosEspelho(a, b))) {
          const d = await ler(caminho);
          if (d) assert.equal(d.referencia, r.referencia, caminho);
        }
        assert.equal(await espelhos(b, a), 'nenhum', 'a direcao inversa nunca e escrita');
      }
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
    });

    // ------------------------------------------------------------- limites

    test('S39 — a quarta criacao contra o mesmo alvo em 24h e recusada sem consumo; outro alvo passa; a janela por alvo e movel', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      for (let i = 0; i < 3; i++) {
        await cmd(a, 'seguir', b, i === 0 ? { referencia: null } : {});
        await cmd(a, 'deixarSeguir', b);
      }
      await assert.rejects(() => cmd(a, 'seguir', b), recusa('ritmoExcedido', 'resource-exhausted'));
      assert.equal((await canonico(a, b)).estado, 'encerrado');
      assert.equal((await canonico(a, b)).criacoesRecentes.length, 3);
      assert.equal((await ritmo(a)).criacoes.length, 3, 'recusa nao consome');
      assert.equal((await cmd(a, 'seguir', c, { referencia: null })).estado, 'seguindo',
        'outro alvo nao e afetado');
      const canon = await canonico(a, b);
      await semear(`follows/${a.uid}|${b.uid}`, {
        ...canon, criacoesRecentes: instantes(24 * HORA + 2 * MIN, 2 * HORA, HORA),
      });
      assert.equal((await cmd(a, 'seguir', b)).estado, 'seguindo', 'a mais antiga saiu da janela');
      assert.equal((await canonico(a, b)).criacoesRecentes.length, 3, 'e saiu do historico');
      await cmd(a, 'deixarSeguir', b);
      const canon2 = await canonico(a, b);
      await semear(`follows/${a.uid}|${b.uid}`, {
        ...canon2, criacoesRecentes: instantes(23 * HORA, 2 * HORA, HORA),
      });
      await assert.rejects(() => cmd(a, 'seguir', b), recusa('ritmoExcedido'));
    });

    test('S36 — 30 criacoes em 10 min: a 31a e ritmoExcedido; a janela movel libera; repeticao e referencia velha nao consomem', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      const recentes = (n) => Array.from({ length: n }, (_, i) => (i + 1) * 15 * 1000);
      await semear(R(a), {
        criacoes: instantes(...recentes(30)), pedidosPendentesEnviados: 0, esquema: 1,
      });
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null }),
        recusa('ritmoExcedido', 'resource-exhausted'));
      assert.equal((await ritmo(a)).criacoes.length, 30);
      assert.equal(await canonico(a, b), undefined);
      await semear(R(a), {
        criacoes: instantes(...recentes(29), 10 * MIN + 30 * 1000),
        pedidosPendentesEnviados: 0, esquema: 1,
      });
      assert.equal((await cmd(a, 'seguir', b, { referencia: null })).estado, 'seguindo');
      assert.equal((await ritmo(a)).criacoes.length, 31, 'a de 10 min ainda esta nas 24h');
      const rep = await cmd(a, 'seguir', b);
      assert.equal(rep.repeticao, true);
      await assert.rejects(() => cmd(a, 'deixarSeguir', b, { referencia: 'velha.' }),
        recusa('referenciaObsoleta'));
      assert.equal((await ritmo(a)).criacoes.length, 31, 'repeticao e referencia velha nao consomem');
      await assert.rejects(() => cmd(a, 'seguir', c, { referencia: null }), recusa('ritmoExcedido'));
    });

    test('S36 — 300 criacoes em 24h: a 301a e recusada; com a mais antiga fora da janela, passa e o historico e podado', async () => {
      const a = await jogador();
      const b = await jogador();
      const espalhadas = (n) => Array.from({ length: n }, (_, i) => 20 * MIN + i * 4 * MIN);
      await semear(R(a), {
        criacoes: instantes(...espalhadas(300)), pedidosPendentesEnviados: 0, esquema: 1,
      });
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null }), recusa('ritmoExcedido'));
      assert.equal((await ritmo(a)).criacoes.length, 300);
      await semear(R(a), {
        criacoes: instantes(...espalhadas(299), 24 * HORA + 5 * MIN),
        pedidosPendentesEnviados: 0, esquema: 1,
      });
      assert.equal((await cmd(a, 'seguir', b, { referencia: null })).estado, 'seguindo');
      assert.equal((await ritmo(a)).criacoes.length, 300);
    });

    test('historico desconhecido: criacoes ilegivel no ritmo ou canonico sem historico = limiteIndisponivel, sem escrita', async () => {
      const a = await jogador();
      const b = await jogador();
      await semear(R(a), { criacoes: 'nao-e-lista', pedidosPendentesEnviados: 0, esquema: 1 });
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null }),
        recusa('limiteIndisponivel', 'failed-precondition'));
      assert.equal(await canonico(a, b), undefined);
      assert.equal((await ritmo(a)).criacoes, 'nao-e-lista', 'nada virou lista vazia');
      await semear(R(a), { criacoes: [], pedidosPendentesEnviados: 0, esquema: 1 });
      const agora = new Date().toISOString();
      const canon = {
        seguidorUid: a.uid, seguidoUid: b.uid, estado: 'encerrado', ref: 'refAntiga',
        corteNaCriacao: null, ultimaIntencao: { chave: 'x', impressao: 'y' },
        solicitadoEm: agora, confirmadoEm: agora, encerradoEm: agora, desde: null, esquema: 1,
      };
      await semear(`follows/${a.uid}|${b.uid}`, canon);
      await assert.rejects(() => cmd(a, 'seguir', b, { referencia: 'refAntiga.' }),
        recusa('limiteIndisponivel'));
      assert.deepEqual(await canonico(a, b), canon);
      assert.deepEqual((await ritmo(a)).criacoes, []);
    });

    test('ator novo x estado perdido: sem ritmo e sem canonico inicializa; sem ritmo com canonico guardado recusa; campo ausente nao vira zero', async () => {
      const b = await jogador();
      const c = await jogador();
      await privado(b);
      const novo = await jogador();
      assert.equal(await ritmo(novo), undefined);
      assert.equal((await cmd(novo, 'seguir', b, { referencia: null })).estado, 'pendente');
      const rn = await ritmo(novo);
      assert.equal(rn.pedidosPendentesEnviados, 1);
      assert.equal(rn.criacoes.length, 1);
      assert.equal(rn.esquema, 1);
      const perdido = await jogador();
      await cmd(perdido, 'seguir', c, { referencia: null });
      await apagar(R(perdido));
      await assert.rejects(() => cmd(perdido, 'seguir', b, { referencia: null }),
        recusa('limiteIndisponivel'));
      assert.equal(await ritmo(perdido), undefined, 'o ritmo perdido nao e recriado vazio');
      assert.equal(await canonico(perdido, b), undefined);
      const semCampo = await jogador();
      await semear(R(semCampo), { criacoes: [], esquema: 1 });
      await assert.rejects(() => cmd(semCampo, 'seguir', b, { referencia: null }),
        recusa('limiteIndisponivel'));
      assert.equal((await cmd(semCampo, 'seguir', c, { referencia: null })).estado, 'seguindo');
      assert.equal('pedidosPendentesEnviados' in (await ritmo(semCampo)), false,
        'o campo ausente nao recebe 0');
    });

    // ---- Parecer C3 R1, item R1: a prova de primeira criacao olha tambem as
    // projecoes de SAIDA do proprio ator. Residuo de saida sem canonico e estado
    // anterior perdido; atividade so RECEBIDA nao conta.

    /// Tudo o que uma recusa por residuo nao pode tocar: o ator, o alvo e o terceiro.
    async function fotoDoResiduo(ator, alvo, terceiro) {
      const caminhos = [
        `playerSocialRitmo/${ator.uid}`, `playerSocialRitmo/${terceiro.uid}`,
        `follows/${ator.uid}|${alvo.uid}`, `follows/${ator.uid}|${terceiro.uid}`,
        ...Object.values(caminhosEspelho(ator, alvo)),
        ...Object.values(caminhosEspelho(ator, terceiro)),
      ];
      const foto = {};
      for (const c of caminhos) foto[c] = (await ler(c)) ?? null;
      return foto;
    }

    test('R1 — sem ritmo e com pedido ENVIADO orfao (com e sem espelho recebido): nao e primeira criacao; recusa sem tocar residuo nem terceiro', async () => {
      const x = await jogador();
      const publico = await jogador();
      const fechado = await jogador();
      await privado(fechado);
      const agora = new Date().toISOString();
      for (const comEspelho of [false, true]) {
        const a = await jogador();
        await semear(`users/${a.uid}/pedidosSeguirEnviados/${x.uid}`,
          { publicId: x.pid, solicitadoEm: agora, referencia: 'orfao.' });
        if (comEspelho) {
          await semear(`users/${x.uid}/pedidosSeguirRecebidos/${a.uid}`,
            { publicId: a.pid, solicitadoEm: agora, referencia: 'orfao.' });
        }
        assert.equal(await ritmo(a), undefined);
        assert.equal(await canonico(a, x), undefined, 'o residuo nao tem canonico');
        for (const alvo of [publico, fechado]) {
          const antes = await fotoDoResiduo(a, alvo, x);
          await assert.rejects(() => cmd(a, 'seguir', alvo, { referencia: null }),
            recusa('limiteIndisponivel', 'failed-precondition'));
          assert.deepEqual(await fotoDoResiduo(a, alvo, x), antes,
            `comEspelho=${comEspelho}: nenhum canonico, projecao, ritmo ou consumo novo`);
        }
      }
    });

    test('R1 — sem ritmo e com SEGUINDO orfao (com e sem espelho de seguidor) recusa; com ritmo, espelho orfao do MESMO par tambem e historico desconhecido', async () => {
      const x = await jogador();
      const b = await jogador();
      const agora = new Date().toISOString();
      for (const comEspelho of [false, true]) {
        const a = await jogador();
        await semear(`users/${a.uid}/seguindo/${x.uid}`,
          { publicId: x.pid, desde: agora, referencia: 'orfao.' });
        if (comEspelho) {
          await semear(`users/${x.uid}/seguidores/${a.uid}`,
            { publicId: a.pid, desde: agora, referencia: 'orfao.' });
        }
        const antes = await fotoDoResiduo(a, b, x);
        await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null }),
          recusa('limiteIndisponivel'));
        assert.deepEqual(await fotoDoResiduo(a, b, x), antes, `comEspelho=${comEspelho}`);
      }
      // Ritmo conhecido, mas o par a -> b tem espelho sem canonico: o historico
      // POR ALVO nao e "par novo".
      const p = await jogador();
      await semear(R(p), { criacoes: [], pedidosPendentesEnviados: 0, esquema: 1 });
      await semear(`users/${p.uid}/seguindo/${b.uid}`,
        { publicId: b.pid, desde: agora, referencia: 'orfao.' });
      const antesPar = await fotoDoResiduo(p, b, x);
      await assert.rejects(() => cmd(p, 'seguir', b, { referencia: null }),
        recusa('limiteIndisponivel'));
      assert.deepEqual(await fotoDoResiduo(p, b, x), antesPar);
      assert.equal((await cmd(p, 'seguir', x, { referencia: null })).estado, 'seguindo',
        'outro par, sem residuo, segue normal');
    });

    test('R1 — ator de saida novo com atividade so RECEBIDA (seguidores, pedidos e residuo recebidos) cria normalmente; ator inteiramente novo tambem', async () => {
      const n = await jogador();
      const c = await jogador();
      const d = await jogador();
      const z = await jogador();
      const b = await jogador();
      await cmd(c, 'seguir', n, { referencia: null });
      await privado(n);
      await cmd(d, 'seguir', n, { referencia: null });
      await semear(`users/${n.uid}/seguidores/${z.uid}`,
        { publicId: z.pid, desde: new Date().toISOString(), referencia: 'orfao.' });
      const terceiros = { cn: await canonico(c, n), dn: await canonico(d, n),
        rc: await ritmo(c), rd: await ritmo(d) };
      assert.equal(await ritmo(n), undefined);
      assert.equal((await cmd(n, 'seguir', b, { referencia: null })).estado, 'seguindo');
      const rn = await ritmo(n);
      assert.equal(rn.criacoes.length, 1);
      assert.equal(rn.pedidosPendentesEnviados, 0);
      assert.deepEqual({ cn: await canonico(c, n), dn: await canonico(d, n),
        rc: await ritmo(c), rd: await ritmo(d) }, terceiros, 'os dados de terceiros ficam');
      const m = await jogador();
      assert.equal((await cmd(m, 'seguir', b, { referencia: null })).estado, 'seguindo');
      assert.equal((await ritmo(m)).criacoes.length, 1);
    });

    test('teto: contador negativo, fracionario, texto ou nulo recusa; 0 e 99 passam; 100 e limitePedidosPendentes; cancelar libera', async () => {
      const a = await jogador();
      const alvos = [];
      for (let i = 0; i < 2; i++) {
        const t = await jogador();
        await privado(t);
        alvos.push(t);
      }
      for (const ruim of [-1, 1.5, '3', null]) {
        await semear(R(a), { criacoes: [], pedidosPendentesEnviados: ruim, esquema: 1 });
        await assert.rejects(() => cmd(a, 'seguir', alvos[0], { referencia: null }),
          recusa('limiteIndisponivel'));
        assert.equal(await canonico(a, alvos[0]), undefined);
        assert.deepEqual((await ritmo(a)).pedidosPendentesEnviados, ruim,
          'nada e arredondado, truncado ou zerado');
      }
      await semear(R(a), { criacoes: [], pedidosPendentesEnviados: 100, esquema: 1 });
      await assert.rejects(() => cmd(a, 'seguir', alvos[0], { referencia: null }),
        recusa('limitePedidosPendentes', 'resource-exhausted'));
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 100);
      await semear(R(a), { criacoes: [], pedidosPendentesEnviados: 99, esquema: 1 });
      assert.equal((await cmd(a, 'seguir', alvos[0], { referencia: null })).estado, 'pendente');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 100);
      await assert.rejects(() => cmd(a, 'seguir', alvos[1], { referencia: null }),
        recusa('limitePedidosPendentes'));
      await cmd(a, 'cancelarSeguir', alvos[0]);
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 99);
      assert.equal((await cmd(a, 'seguir', alvos[1], { referencia: null })).estado, 'pendente');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 100);
      const z = await jogador();
      await semear(R(z), { criacoes: [], pedidosPendentesEnviados: 0, esquema: 1 });
      assert.equal((await cmd(z, 'seguir', alvos[1], { referencia: null })).estado, 'pendente');
      assert.equal((await ritmo(z)).pedidosPendentesEnviados, 1);
    });

    test('contador do REMETENTE quando quem chama e o destinatario: ilegivel, inconsistente ou ausente falha fechado, sem max(0)', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      const bom = await ritmo(a);
      await semear(R(a), { ...bom, pedidosPendentesEnviados: 1.5 });
      await assert.rejects(() => cmd(b, 'aprovarSeguir', a), recusa('limiteIndisponivel'));
      assert.equal((await canonico(a, b)).estado, 'pendente');
      assert.equal(await espelhos(a, b), 'P3+P4');
      await semear(R(a), { ...bom, pedidosPendentesEnviados: 0 });
      await assert.rejects(() => cmd(b, 'recusarSeguir', a), recusa('limiteIndisponivel'));
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0, 'sem max(0): nada gravado');
      assert.equal((await canonico(a, b)).estado, 'pendente');
      await apagar(R(a));
      await assert.rejects(() => cmd(b, 'aprovarSeguir', a), recusa('limiteIndisponivel'));
      assert.equal(await ritmo(a), undefined, 'o destinatario nao inicializa o ritmo do remetente');
      await semear(R(a), bom);
      assert.equal((await cmd(b, 'aprovarSeguir', a)).estado, 'seguidor');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
    });

    // --------------------------------------------------------- concorrencia

    test('S37 — teto RIGIDO sob concorrencia: com 98, tres pedidos simultaneos, exatamente dois passam e o contador fecha em 100', async () => {
      const a = await jogador();
      const alvos = await Promise.all([0, 1, 2].map(async () => {
        const t = await jogador();
        await privado(t);
        return t;
      }));
      await semear(R(a), { criacoes: [], pedidosPendentesEnviados: 98, esquema: 1 });
      const rs = await Promise.allSettled(
        alvos.map((t) => cmd(a, 'seguir', t, { referencia: null })));
      const falhas = rs.filter((r) => r.status === 'rejected');
      assert.equal(rs.filter((r) => r.status === 'fulfilled').length, 2);
      assert.equal(falhas.length, 1);
      assert.equal(falhas[0].reason.details?.recusa, 'limitePedidosPendentes');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 100);
      assert.equal((await ritmo(a)).criacoes.length, 2);
      let pendentes = 0;
      for (const t of alvos) if ((await espelhos(a, t)) === 'P3+P4') pendentes++;
      assert.equal(pendentes, 2);
    });

    test('concorrencia: tres criacoes simultaneas do ator novo — o ritmo nasce uma vez e nenhum consumo se perde', async () => {
      const a = await jogador();
      const alvos = await Promise.all([0, 1, 2].map(() => jogador()));
      const rs = await Promise.all(alvos.map((t) => cmd(a, 'seguir', t, { referencia: null })));
      assert.ok(rs.every((r) => r.estado === 'seguindo'));
      const rit = await ritmo(a);
      assert.equal(rit.criacoes.length, 3);
      assert.equal(rit.pedidosPendentesEnviados, 0);
    });

    test('corrida aprovar x cancelar: um so desfecho, um so debito e espelhos coerentes', async () => {
      const a = await jogador();
      const b = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      const refMeu = (await bloco(a, b)).meu.referencia;
      const refDele = (await bloco(b, a)).dele.referencia;
      assert.equal(refMeu, refDele, 'a mesma direcao, a mesma referencia');
      const rs = await Promise.allSettled([
        cmd(b, 'aprovarSeguir', a, { referencia: refDele }),
        cmd(a, 'cancelarSeguir', b, { referencia: refMeu }),
      ]);
      assert.equal(rs.filter((r) => r.status === 'fulfilled').length, 1, 'um so vence');
      assert.equal(rs.find((r) => r.status === 'rejected').reason.details?.recusa,
        'referenciaObsoleta');
      const estado = (await canonico(a, b)).estado;
      assert.ok(estado === 'confirmado' || estado === 'encerrado');
      assert.equal(await espelhos(a, b), estado === 'confirmado' ? 'P1+P2' : 'nenhum');
      assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0, 'debito unico');
    });

    // ------------------------------------------------------------- leituras

    test('O12 — bloco seguir nas duas direcoes, com referencias e acoes; gratuito sem bloco; nenhuma chave proibida', async () => {
      const a = await jogador();
      const b = await jogador();
      const g = await jogador({ comVip: false });
      await cmd(b, 'seguir', a, { referencia: null });
      const v = (await a.verPerfil({ publicId: b.pid })).data;
      assert.deepEqual(Object.keys(v).sort(),
        ['acoes', 'amigosDesde', 'detalhes', 'perfil', 'relacao', 'seguir']);
      assert.deepEqual(v.seguir.meu, { estado: 'nenhum', referencia: null });
      assert.equal(v.seguir.dele.estado, 'seguidor');
      assert.equal(typeof v.seguir.dele.referencia, 'string');
      assert.deepEqual(v.acoes.filter((x) => SEGUIR_ACOES.has(x)), ['seguir', 'removerSeguidor']);
      assert.ok(v.acoes.includes('bloquear'), 'as acoes de amizade e seguranca continuam');
      assert.equal(v.detalhes, null);
      const vb = (await b.verPerfil({ publicId: a.pid })).data;
      assert.equal(vb.seguir.meu.estado, 'seguindo');
      assert.deepEqual(vb.acoes.filter((x) => SEGUIR_ACOES.has(x)), ['deixarDeSeguir']);
      await privado(b);
      const vp = (await a.verPerfil({ publicId: b.pid })).data;
      assert.ok(vp.acoes.includes('solicitarSeguir'));
      assert.ok(!vp.acoes.includes('seguir'));
      const vg = (await g.verPerfil({ publicId: b.pid })).data;
      assert.equal(vg.seguir, null);
      assert.deepEqual([...vg.acoes].sort(), ['adicionarAmigo', 'bloquear']);
      const vSelf = (await a.verPerfil({ publicId: a.pid })).data;
      assert.equal(vSelf.relacao, 'euMesmo');
      assert.deepEqual(vSelf.acoes, ['editarPerfil']);
      assert.equal(vSelf.seguir, null);
      assert.equal(vSelf.detalhes, null);
      const vAlvoGratis = (await a.verPerfil({ publicId: g.pid })).data;
      assert.ok(vAlvoGratis.seguir, 'o observador VIP ve o estado guardado');
      assert.ok(!vAlvoGratis.acoes.some((x) => SEGUIR_ACOES.has(x)), 'mas nada de criar');
      const texto = JSON.stringify([v, vb, vp, vg, vSelf, vAlvoGratis]);
      for (const proibido of [a.uid, b.uid, g.uid, 'ultimaIntencao', 'corteNaCriacao',
        'seguidorUid', 'seguidoUid', '"token"', 'criacoes', 'pedidosPendentesEnviados']) {
        assert.ok(!texto.includes(proibido), `vazou ${proibido}`);
      }
    });

    test('S35 (sequencial) — a leitura protegida acompanha privacidade, plano, contato e diario, mudanca a mudanca', async () => {
      const a = await jogador();
      const b = await jogador();
      const ver = async () => (await a.verPerfil({ publicId: b.pid })).data;
      assert.ok((await ver()).acoes.includes('seguir'));
      await privado(b);
      assert.ok((await ver()).acoes.includes('solicitarSeguir'));
      await vip(a, { expiraEm: PASSADO });
      assert.equal((await ver()).seguir, null);
      await vip(a);
      assert.ok((await ver()).seguir);
      await vip(b, { expiraEm: PASSADO });
      const semPlano = await ver();
      assert.ok(semPlano.seguir);
      assert.ok(!semPlano.acoes.includes('solicitarSeguir'));
      await vip(b);
      await semear(`playerModeration/${a.uid}`, { socialRestritoAte: FUTURO });
      assert.equal((await ver()).seguir, null);
      await apagar(`playerModeration/${a.uid}`);
      assert.ok((await ver()).seguir);
      await diario(b);
      const emExclusao = await ver();
      assert.equal(emExclusao.seguir, null);
      assert.equal(emExclusao.detalhes, null);
      assert.ok(!emExclusao.acoes.some((x) => SEGUIR_ACOES.has(x)));
    });

    // ---- Parecer C3 R1, item R2: S35 CONCORRENTE.
    //
    // Como a prova funciona:
    //   - Dois estados COMPLETOS, X e Y, com respostas legais distintas de O12.
    //     Cada um junta dois fatos que O12 le (por exemplo, privacidade do alvo
    //     e o canonico alvo -> observador), escolhidos para que TODA mistura dos
    //     fatos de X e de Y produza uma resposta diferente das duas legais.
    //   - O preparo do teste troca X <-> Y com UM `writeBatch` administrativo
    //     (atomico). E instrumentacao de teste, nao caminho de produto: nenhuma
    //     flag de payload, endpoint ou modo novo.
    //   - Quatro leitores chamam `verPerfilPublico` real sem parar enquanto as
    //     trocas acontecem. Cada leitura e cada troca registram inicio e fim no
    //     relogio do teste.
    // O que cada assert demonstra:
    //   (a) toda resposta e INTEIRAMENTE X ou Y: nenhuma permissao montada com
    //       fatos de instantes diferentes;
    //   (b) toda resposta e um estado vigente em algum ponto da janela da
    //       leitura: o confirmado antes de ela comecar, ou o de uma troca que se
    //       sobrepoe a ela. Uma leitura iniciada depois de uma troca confirmada
    //       nunca devolve o estado anterior; uma leitura autorizada antes da
    //       troca nao precisa ser negada retroativamente;
    //   (c) houve sobreposicao real entre leituras e trocas (contada e exigida);
    //   (d) a leitura feita depois de tudo reflete o ultimo estado.
    // O intervalo entre trocas so espalha as trocas no tempo; ele nao e prova.

    const { writeBatch } = require('firebase/firestore');

    /// Aplica um estado inteiro de uma vez. `null` apaga o documento.
    async function aplicarAtomico(estado) {
      await ambiente.withSecurityRulesDisabled(async (ctx) => {
        const fs = ctx.firestore();
        const lote = writeBatch(fs);
        for (const [caminho, dados] of Object.entries(estado)) {
          if (dados === null) lote.delete(doc(fs, caminho));
          else lote.set(doc(fs, caminho), dados);
        }
        await lote.commit();
      });
    }

    /// A direcao s -> d semeada no formato congelado, com os espelhos do estado
    /// (e os outros apagados). `estado` null = sem canonico e sem espelho.
    function direcaoSemeada(s, d, estado, ref) {
      const t = '2026-01-01T00:00:00.000Z';
      const p = caminhosEspelho(s, d);
      const saida = {
        [`follows/${s.uid}|${d.uid}`]: estado === null ? null : {
          seguidorUid: s.uid, seguidoUid: d.uid, estado, ref, corteNaCriacao: null,
          ultimaIntencao: { chave: 'semeado', impressao: 'semeado' },
          solicitadoEm: t, confirmadoEm: estado === 'confirmado' ? t : null,
          encerradoEm: null, desde: estado === 'confirmado' ? t : null,
          criacoesRecentes: [t], esquema: 1,
        },
        [p.P1]: null, [p.P2]: null, [p.P3]: null, [p.P4]: null,
      };
      if (estado === 'confirmado') {
        saida[p.P1] = { publicId: d.pid, desde: t, referencia: `${ref}.` };
        saida[p.P2] = { publicId: s.pid, desde: t, referencia: `${ref}.` };
      } else if (estado === 'pendente') {
        saida[p.P3] = { publicId: d.pid, solicitadoEm: t, referencia: `${ref}.` };
        saida[p.P4] = { publicId: s.pid, solicitadoEm: t, referencia: `${ref}.` };
      }
      return saida;
    }

    /// A parte de O12 que as permissoes decidem, numa forma comparavel.
    const assinatura = (dados) => (dados.seguir === null
      ? 'sem-bloco'
      : JSON.stringify({
        meu: dados.seguir.meu,
        dele: dados.seguir.dele,
        acoes: dados.acoes.filter((x) => SEGUIR_ACOES.has(x)),
      }));

    async function corridaO12(t, { obs, alvo, X, Y, trocas = 8, leitores = 4 }) {
      const ver = async () => assinatura((await obs.verPerfil({ publicId: alvo.pid })).data);
      await aplicarAtomico(Y);
      const assY = await ver();
      await aplicarAtomico(X);
      const assX = await ver();
      assert.notEqual(assX, assY, 'os dois estados precisam ter respostas distintas');
      const porEstado = { X: assX, Y: assY };

      const leituras = [];
      const registroTrocas = [];
      let parar = false;
      const leitor = async () => {
        while (!parar) {
          const ini = performance.now();
          const ass = await ver();
          leituras.push({ ini, fim: performance.now(), ass });
        }
      };
      const trocador = async () => {
        let atual = 'X';
        for (let i = 0; i < trocas; i++) {
          await new Promise((r) => setTimeout(r, 60));
          const proximo = atual === 'X' ? 'Y' : 'X';
          const ini = performance.now();
          await aplicarAtomico(proximo === 'X' ? X : Y);
          registroTrocas.push({ ini, fim: performance.now(), para: proximo });
          atual = proximo;
        }
        await new Promise((r) => setTimeout(r, 200));
        parar = true;
      };
      await Promise.all([trocador(), ...Array.from({ length: leitores }, leitor)]);

      let sobrepostas = 0;
      const vistos = { X: 0, Y: 0 };
      for (const l of leituras) {
        // (a) inteira: X ou Y.
        const nome = l.ass === assX ? 'X' : l.ass === assY ? 'Y' : null;
        assert.ok(nome, `resposta misturada: ${l.ass}`);
        vistos[nome]++;
        // (b) vigente na janela da leitura.
        const confirmadas = registroTrocas.filter((tr) => tr.fim <= l.ini);
        const noInicio = confirmadas.length ? confirmadas[confirmadas.length - 1].para : 'X';
        const emVoo = registroTrocas.filter((tr) => tr.ini < l.fim && tr.fim > l.ini);
        if (emVoo.length) sobrepostas++;
        const possiveis = new Set([noInicio, ...emVoo.map((tr) => tr.para)]);
        assert.ok(possiveis.has(nome),
          `leitura [${l.ini.toFixed(1)}, ${l.fim.toFixed(1)}] viu ${nome}; possiveis: ${[...possiveis]}`);
      }
      // (c) houve concorrencia de verdade.
      assert.ok(sobrepostas >= 1, 'nenhuma leitura se sobrepos a uma troca');
      // (d) o ultimo estado vale para quem le depois.
      const ultimo = registroTrocas[registroTrocas.length - 1].para;
      assert.equal(await ver(), porEstado[ultimo]);
      t.diagnostic(`O12 concorrente: ${leituras.length} leituras, ${registroTrocas.length} trocas, `
        + `${sobrepostas} leituras sobrepostas a troca, vistos X=${vistos.X} Y=${vistos.Y}`);
    }

    test('S35 (concorrente) — privacidade do alvo + direcao alvo->observador trocadas atomicamente durante O12: nunca mistura', async (t) => {
      const obs = await jogador();
      const alvo = await jogador();
      // X: alvo publico, sem direcao de entrada  -> acoes [seguir]
      // Y: alvo privado, alvo segue o observador -> [solicitarSeguir, removerSeguidor]
      // Misturas: privado sem entrada -> [solicitarSeguir]; publico com entrada ->
      // [seguir, removerSeguidor]. As quatro combinacoes sao distintas.
      await corridaO12(t, {
        obs, alvo,
        X: { [`playerSocial/${alvo.uid}`]: { privacidade: 'publico' },
          ...direcaoSemeada(alvo, obs, null) },
        Y: { [`playerSocial/${alvo.uid}`]: { privacidade: 'privado' },
          ...direcaoSemeada(alvo, obs, 'confirmado', 'refY') },
      });
    });

    test('S35 (concorrente) — plano do alvo + direcao alvo->observador trocados atomicamente durante O12: nunca mistura', async (t) => {
      const obs = await jogador();
      const alvo = await jogador();
      const plano = (expiraEm) => ({ vipAtivo: true, estado: 'ativo', origem: 'play', expiraEm });
      // X: alvo VIP, pedido de entrada pendente -> [seguir, aprovarPedidoSeguir, recusarPedidoSeguir]
      // Y: alvo vencido, entrada confirmada     -> [removerSeguidor]
      // Misturas: VIP + confirmada -> [seguir, removerSeguidor]; vencido + pendente ->
      // [recusarPedidoSeguir]. As quatro combinacoes sao distintas.
      await corridaO12(t, {
        obs, alvo,
        X: { [`playerEntitlements/${alvo.uid}`]: plano(FUTURO),
          ...direcaoSemeada(alvo, obs, 'pendente', 'refX') },
        Y: { [`playerEntitlements/${alvo.uid}`]: plano(PASSADO),
          ...direcaoSemeada(alvo, obs, 'confirmado', 'refY') },
      });
    });

    test('S35 (concorrente) — diario do alvo + privacidade trocados atomicamente durante O12: o bloco e o de antes ou nenhum', async (t) => {
      const obs = await jogador();
      const alvo = await jogador();
      // X: sem diario, alvo publico -> [seguir]
      // Y: diario no alvo, privado  -> sem bloco
      // Mistura detectavel: sem diario + privado -> [solicitarSeguir]. A outra
      // (diario + publico) tambem da "sem bloco": o diario domina a resposta.
      // Apagar o diario na volta Y -> X e so instrumentacao para repetir a troca;
      // no produto o diario nao some antes de a exclusao terminar.
      await corridaO12(t, {
        obs, alvo,
        X: { [`accountDeletions/${alvo.uid}`]: null,
          [`playerSocial/${alvo.uid}`]: { privacidade: 'publico' } },
        Y: { [`accountDeletions/${alvo.uid}`]: { estado: 'iniciada', esquema: 1 },
          [`playerSocial/${alvo.uid}`]: { privacidade: 'privado' } },
      });
    });

    test('S34a/S34b — lista propria: desde DESC; apelido FRESCO; travessia sem repetir com troca de apelido e item novo', async () => {
      const b = await jogador();
      const seguidores = [];
      for (let i = 0; i < 3; i++) {
        const f = await jogador();
        await cmd(f, 'seguir', b, { referencia: null });
        seguidores.push(f);
      }
      const p1 = (await b.listarSeguidores({ limite: 2 })).data;
      assert.deepEqual(p1.itens.map((i) => i.publicId), [seguidores[2].pid, seguidores[1].pid]);
      for (const i of p1.itens) {
        assert.deepEqual(Object.keys(i).sort(), ['apelido', 'avatarRef', 'desde', 'publicId', 'referencia']);
        assert.equal(typeof i.referencia, 'string');
      }
      assert.ok(p1.proximoCursor);
      await seguidores[0].atualizar({ apelido: 'Nome Novo' });
      const novo = await jogador();
      await cmd(novo, 'seguir', b, { referencia: null });
      const p2 = (await b.listarSeguidores({ limite: 2, cursor: p1.proximoCursor })).data;
      assert.deepEqual(p2.itens.map((i) => i.publicId), [seguidores[0].pid]);
      assert.equal(p2.itens[0].apelido, 'Nome Novo');
      assert.equal(p2.proximoCursor, null);
      const todos = (await b.listarSeguidores({ limite: 50 })).data.itens.map((i) => i.publicId);
      assert.deepEqual(todos, [novo.pid, seguidores[2].pid, seguidores[1].pid, seguidores[0].pid]);
      assert.equal((await b.contadores({})).data.contadores.seguidores, 4);
      const forjado = (await b.listarSeguidores({ limite: 2, cursor: 'lixo' })).data;
      assert.equal(forjado.itens.length, 2, 'cursor forjado = primeira pagina');
    });

    test('O08 — as quatro listas sao SO do dono; pedidos por solicitadoEm; o payload nao escolhe o dono', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      await privado(b);
      await cmd(a, 'seguir', b, { referencia: null });
      await cmd(a, 'seguir', c, { referencia: null });
      const env = (await a.listarPedidosEnviados({})).data.itens;
      assert.deepEqual(env.map((i) => i.publicId), [b.pid]);
      assert.deepEqual(Object.keys(env[0]).sort(),
        ['apelido', 'avatarRef', 'publicId', 'referencia', 'solicitadoEm']);
      assert.deepEqual((await b.listarPedidosRecebidos({})).data.itens.map((i) => i.publicId), [a.pid]);
      assert.deepEqual((await a.listarSeguindo({})).data.itens.map((i) => i.publicId), [c.pid]);
      assert.deepEqual((await c.listarSeguidores({})).data.itens.map((i) => i.publicId), [a.pid]);
      assert.deepEqual((await b.listarSeguidores({})).data.itens, [], 'pendente nao e seguidor');
      assert.deepEqual((await b.listarSeguindo({ publicId: a.pid, uid: a.uid })).data.itens, [],
        'o payload nao escolhe de quem e a lista');
      const texto = JSON.stringify(env);
      assert.ok(!texto.includes(a.uid) && !texto.includes(b.uid));
    });

    test('S19/S22/O13 — contadores proprios por fonte separada; indisponivel e null, nunca zero; sem contador tecnico', async () => {
      const a = await jogador();
      const b = await jogador();
      const c = await jogador();
      const d = await jogador();
      await privado(c);
      await cmd(a, 'seguir', b, { referencia: null });
      await cmd(a, 'seguir', c, { referencia: null });
      await cmd(d, 'seguir', a, { referencia: null });
      const k = (await a.contadores({})).data;
      assert.deepEqual(Object.keys(k), ['contadores']);
      assert.deepEqual(k.contadores, {
        amigos: null, pedidosAmizadeRecebidos: 0, pedidosSeguirRecebidos: 0,
        pedidosSeguirEnviados: 1, seguidores: 1, seguindo: 1, privacidade: 'publico',
      });
      const agora = new Date().toISOString();
      await semear(`playerSocial/${a.uid}`, { amigos: 2 });
      await semear(`users/${a.uid}/friendRequests/${d.uid}`,
        { direcao: 'recebida', publicId: d.pid, solicitadaEm: agora, esquema: 1 });
      await semear(`users/${a.uid}/friendRequests/${b.uid}`,
        { direcao: 'enviada', publicId: b.pid, solicitadaEm: agora, esquema: 1 });
      const k2 = (await a.contadores({})).data.contadores;
      assert.equal(k2.amigos, 2);
      assert.equal(k2.pedidosAmizadeRecebidos, 1, 'so a direcao recebida');
      await semear(`playerSocial/${a.uid}`, { amigos: 1.5, privacidade: 'privado' });
      const k3 = (await a.contadores({})).data.contadores;
      assert.equal(k3.amigos, null, 'ilegivel e null, nunca zero');
      assert.equal(k3.privacidade, 'privado');
    });

    // ------------------------------------------------- erros e autenticacao

    test('D07 — erros neutros: alvo gratuito, que eu bloqueei, que me bloqueou ou com contato restrito respondem IGUAL', async () => {
      const a = await jogador();
      const gratis = await jogador({ comVip: false });
      const euBloqueei = await jogador();
      const meBloqueou = await jogador();
      const restrito = await jogador();
      const agora = new Date().toISOString();
      await semear(`users/${a.uid}/blocks/${euBloqueei.uid}`,
        { bloqueadorUid: a.uid, bloqueadoUid: euBloqueei.uid, criadoEm: agora, esquema: 1 });
      await semear(`users/${meBloqueou.uid}/blocks/${a.uid}`,
        { bloqueadorUid: meBloqueou.uid, bloqueadoUid: a.uid, criadoEm: agora, esquema: 1 });
      const respostas = [];
      for (const alvo of [gratis, euBloqueei, meBloqueou]) {
        const e = await cmd(a, 'seguir', alvo, { referencia: null }).then(() => null, (x) => x);
        assert.ok(e, 'tinha que recusar');
        respostas.push([e.code, e.message, JSON.stringify(e.details)].join('|'));
      }
      await semear(`playerModeration/${restrito.uid}`, { socialRestritoAte: FUTURO });
      const e4 = await cmd(restrito, 'seguir', a, { referencia: null }).then(() => null, (x) => x);
      respostas.push([e4.code, e4.message, JSON.stringify(e4.details)].join('|'));
      assert.equal(new Set(respostas).size, 1, `respostas diferentes: ${respostas.join(' / ')}`);
      assert.ok(respostas[0].startsWith('functions/failed-precondition|'));
      const emExclusao = await jogador();
      await diario(emExclusao);
      const e5 = await a.seguir({ publicId: 'PZZZZZZZZZZZZ', referencia: null, intencaoId: intencao() })
        .then(() => null, (x) => x);
      const e6 = await cmd(a, 'seguir', emExclusao, { referencia: null }).then(() => null, (x) => x);
      assert.equal(e5.code, 'functions/not-found');
      assert.equal(e6.code, e5.code);
      assert.equal(e6.message, e5.message);
      assert.deepEqual(e6.details, e5.details, 'exclusao e inexistente respondem igual');
    });

    test('S08 — sobre si mesmo e entrada malformada: recusas estaveis; o payload nao escolhe UID nem estado', async () => {
      const a = await jogador();
      const b = await jogador();
      await assert.rejects(() => cmd(a, 'seguir', a, { referencia: null }),
        recusa('acaoSobreSiMesmo', 'failed-precondition'));
      await assert.rejects(() => a.seguir({ publicId: b.pid, referencia: null }),
        recusa('pedidoInvalido', 'invalid-argument'));
      await assert.rejects(
        () => a.seguir({ publicId: b.pid, referencia: null, intencaoId: 'tem espaco' }),
        recusa('pedidoInvalido'));
      for (const ruim of [123, 'a.b.c', 'sem-ponto', { ref: 'x' }]) {
        await assert.rejects(() => cmd(a, 'seguir', b, { referencia: ruim }), recusa('pedidoInvalido'));
      }
      await assert.rejects(() => a.seguir({ referencia: null, intencaoId: intencao() }),
        (e) => e.code === 'functions/invalid-argument');
      assert.equal(await canonico(a, b), undefined);
      assert.equal(await ritmo(a), undefined);
      await privado(b);
      const r = await a.seguir({
        publicId: b.pid, referencia: null, intencaoId: intencao(),
        uid: b.uid, atorUid: b.uid, estado: 'confirmado', agora: PASSADO, corte: 'x',
      });
      assert.equal(r.data.estado, 'pendente', 'quem decide e a privacidade lida no servidor');
      assert.equal((await canonico(a, b)).seguidorUid, a.uid, 'o ator vem da sessao');
      assert.equal(await canonico(b, a), undefined);
    });

    // =====================================================================
    // SOCIAL-02 C4 — bloqueio com corte, faxina de seguir e reconciliacao.
    //
    // PROVA DIVIDIDA (B-1): `socialemu` sobe so `functions:social`. O bloqueio
    // entra aqui como o LOTE ATOMICO que `bloquearJogador*` grava — bloqueio no
    // formato de hoje + corte novo do par —, no formato exato verificado pela
    // callable real em moderacao.test.js (M01/M02). O gatilho `aoBloquearJogador`
    // e REAL e reage a esse documento. A cadeia "callable da Moderacao ->
    // gatilho do Social" no mesmo runner NAO e executada aqui.
    //
    // MONTAGENS DO TESTE (nenhuma flag, endpoint ou modo de produto):
    //   * bloquear .... lote atomico {bloqueio + corte novo};
    //   * desbloquear . delete do documento de bloqueio, como a callable faz;
    //   * reentregar .. apagar e recriar o bloqueio SEM mudar o corte: o gatilho
    //                   recebe so o par, entao isto e a nova tentativa ou o
    //                   evento atrasado;
    //   * diario em voo transacao do teste que LE todo o conjunto observado
    //                   (inclusive o ainda ausente) e grava o diario: o que ela
    //                   le e o estado exato no instante do diario.
    // A faxina e assincrona: o que ela NAO escreve e observado numa janela
    // declarada, sem promessa de ausencia eterna.
    // =====================================================================
    describe('bloqueio, faxina e reconciliacao (SOCIAL-02 C4)', () => {
      const { randomBytes } = require('crypto');
      const { signInWithCustomToken } = require('firebase/auth');
      const { runTransaction } = require('firebase/firestore');

      const JANELA = 5000;
      const pausa = (ms) => new Promise((r) => setTimeout(r, ms));
      const caminhoCorte = (x, y) => `cortesDeRelacao/${[x.uid, y.uid].sort().join('|')}`;
      const caminhoPar = (x, y) => `friendships/${[x.uid, y.uid].sort().join('|')}`;
      const novoCorte = () => randomBytes(16).toString('base64url');

      /// O que `bloquearJogador*` grava (formato de M01/M02 em moderacao.test.js).
      function bloqueioDaModeracao(quem, alvo, corteId) {
        return {
          [`users/${quem.uid}/blocks/${alvo.uid}`]: {
            bloqueadorUid: quem.uid, bloqueadoUid: alvo.uid, criadoEm: new Date(), esquema: 1,
          },
          [caminhoCorte(quem, alvo)]: {
            corteId, membros: [quem.uid, alvo.uid].sort(),
            atualizadoEm: new Date().toISOString(), esquema: 1,
          },
        };
      }
      async function bloquear(quem, alvo) {
        const corteId = novoCorte();
        await aplicarAtomico(bloqueioDaModeracao(quem, alvo, corteId));
        return corteId;
      }
      const desbloquear = (quem, alvo) => aplicarAtomico({ [`users/${quem.uid}/blocks/${alvo.uid}`]: null });
      async function reentregar(quem, alvo) {
        await desbloquear(quem, alvo);
        await aplicarAtomico({
          [`users/${quem.uid}/blocks/${alvo.uid}`]: {
            bloqueadorUid: quem.uid, bloqueadoUid: alvo.uid, criadoEm: new Date(), esquema: 1,
          },
        });
      }

      /// Sondagem com prazo: a faxina e assincrona.
      async function ate(condicao, rotulo, prazo = 20000) {
        const fim = Date.now() + prazo;
        while (Date.now() < fim) {
          if (await condicao()) return;
          await pausa(200);
        }
        assert.fail(`nao convergiu no prazo: ${rotulo}`);
      }

      async function foto(caminhos) {
        const v = {};
        for (const c of caminhos) {
          const d = await ler(c);
          v[c] = d === undefined ? null : JSON.stringify(d);
        }
        return v;
      }

      /// Nada muda durante a janela declarada.
      async function estavel(caminhos, rotulo, janela = JANELA) {
        const antes = await foto(caminhos);
        const fim = Date.now() + janela;
        while (Date.now() < fim) {
          await pausa(500);
          assert.deepEqual(await foto(caminhos), antes, `mudou na janela: ${rotulo}`);
        }
        return antes;
      }

      /// Cria o diario por transacao do teste que le TODO o conjunto observado.
      async function diarioLendo(j, caminhos) {
        let lido;
        await ambiente.withSecurityRulesDisabled(async (ctx) => {
          const fs = ctx.firestore();
          await runTransaction(fs, async (tx) => {
            const v = {};
            await Promise.all(caminhos.map(async (c) => {
              const s = await tx.get(doc(fs, c));
              v[c] = s.exists() ? JSON.stringify(s.data()) : null;
            }));
            tx.set(doc(fs, `accountDeletions/${j.uid}`), { estado: 'iniciada', esquema: 1 });
            lido = v;
          }, { maxAttempts: 25 });
        });
        return lido;
      }

      /// O que uma direcao s -> d e a amizade do par tocam.
      function caminhosDaDirecao(s, d) {
        return [`follows/${s.uid}|${d.uid}`, ...Object.values(caminhosEspelho(s, d)), R(s)];
      }
      function caminhosDoPar(x, y) {
        return [
          ...caminhosDaDirecao(x, y), ...caminhosDaDirecao(y, x),
          caminhoPar(x, y), `users/${x.uid}/friends/${y.uid}`, `users/${y.uid}/friends/${x.uid}`,
          `users/${x.uid}/friendRequests/${y.uid}`, `users/${y.uid}/friendRequests/${x.uid}`,
          `playerSocial/${x.uid}`, `playerSocial/${y.uid}`,
        ];
      }

      async function amigos(x, y) {
        await x.enviar({ publicId: y.pid });
        await y.aceitar({ publicId: x.pid });
        assert.equal((await ler(caminhoPar(x, y))).estado, 'amigos');
      }

      /// Cliente ADMIN. O emulador de Auth aceita token personalizado SEM
      /// assinatura (comportamento documentado do emulador, para testes); o claim
      /// `admin` chega ao `req.auth.token` da callable real. So existe no teste.
      let admin;
      async function clienteAdmin() {
        if (admin) return admin;
        const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, 'c4-admin-social');
        const auth = getAuth(app);
        connectAuthEmulator(
          auth,
          `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`,
          { disableWarnings: true },
        );
        const agora = Math.floor(Date.now() / 1000);
        const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
        const token = [
          b64({ alg: 'none', typ: 'JWT' }),
          b64({
            iss: 'firebase-auth-emulator@example.com',
            sub: 'firebase-auth-emulator@example.com',
            aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
            iat: agora, exp: agora + 3600, uid: 'c4AdminSocial', claims: { admin: true },
          }),
          '',
        ].join('.');
        await signInWithCustomToken(auth, token);
        const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
        const f = getFunctions(app, 'southamerica-east1');
        connectFunctionsEmulator(f, host, Number(porta));
        const chamar = httpsCallable(f, 'reconciliarPerfilSocial');
        admin = { reconciliar: async (j) => (await chamar({ publicId: j.pid })).data };
        return admin;
      }

      const PRIVADAS = new Set(['uid', 'token', 'membros', 'corteId', 'seguidorUid', 'seguidoUid',
        'bloqueadorUid', 'bloqueadoUid', 'corteNaCriacao', 'ultimaIntencao']);
      function semPrivado(resposta, jogadores) {
        const achar = (v, p) => {
          if (Array.isArray(v)) return v.flatMap((x, i) => achar(x, `${p}[${i}]`));
          if (v === null || typeof v !== 'object') return [];
          return Object.entries(v).flatMap(([k, x]) => [
            ...(PRIVADAS.has(k) ? [`${p}.${k}`] : []), ...achar(x, `${p}.${k}`),
          ]);
        };
        assert.deepEqual(achar(resposta, ''), []);
        const texto = JSON.stringify(resposta);
        for (const j of jogadores) assert.equal(texto.includes(j.uid), false, 'UID na resposta');
      }

      // ------------------------------------------------- R3: provas separadas

      test('S02/S32a — bloqueio vigente + corte: O12 sem bloco e nenhuma criacao, antes E depois da faxina; desbloqueado, nada volta', async () => {
        const a = await jogador();
        const b = await jogador();
        await cmd(a, 'seguir', b, { referencia: null });
        const refAntiga = (await bloco(a, b)).meu.referencia;
        await bloquear(a, b);
        const conferir = async () => {
          assert.equal(await bloco(a, b), null, 'sem bloco sob bloqueio');
          assert.equal(await bloco(b, a), null);
          await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null }), recusa('acaoIndisponivel'));
          await assert.rejects(() => cmd(b, 'seguir', a, { referencia: null }), recusa('acaoIndisponivel'));
          assert.equal(await canonico(b, a), undefined, 'nada nasce sob bloqueio');
        };
        await conferir(); // o gatilho pode ou nao ter rodado: os dois valem
        await ate(async () => (await canonico(a, b))?.estado === 'encerrado', 'faxina a->b');
        await conferir();
        assert.equal(await espelhos(a, b), 'nenhum');

        await desbloquear(a, b);
        const v = await bloco(a, b);
        assert.equal(v.meu.estado, 'nenhum', 'desbloquear nao restaura o vinculo');
        await assert.rejects(() => cmd(a, 'deixarSeguir', b, { referencia: refAntiga }),
          recusa('referenciaObsoleta'));
        const r = await cmd(a, 'seguir', b, { referencia: v.meu.referencia });
        assert.equal(r.estado, 'seguindo', 'acao nova com a referencia atual segue as regras vigentes');
      });

      test('S03 — gatilho real: as duas direcoes encerradas, P1–P4 apagados, remetente debitado UMA vez; a reentrega nao muda nada', async () => {
        const a = await jogador();
        const b = await jogador();
        await privado(a);
        await cmd(b, 'seguir', a, { referencia: null }); // pedido B -> A
        await cmd(a, 'seguir', b, { referencia: null }); // A segue B
        const ritmoBAntes = await ritmo(b);
        const ritmoAAntes = await ritmo(a);
        assert.equal(ritmoBAntes.pedidosPendentesEnviados, 1);
        const pedidoAntes = await canonico(b, a);

        await bloquear(a, b);
        await ate(async () => (await canonico(a, b))?.estado === 'encerrado'
          && (await canonico(b, a))?.estado === 'encerrado', 'as duas direcoes');
        assert.equal(await espelhos(a, b), 'nenhum');
        assert.equal(await espelhos(b, a), 'nenhum');
        const rb = await ritmo(b);
        assert.equal(rb.pedidosPendentesEnviados, 0, 'o REMETENTE (B, o bloqueado) e debitado');
        assert.deepEqual(rb.criacoes, ritmoBAntes.criacoes, 'historico de criacao preservado');
        assert.deepEqual(await ritmo(a), ritmoAAntes, 'A nao tinha pedido pendente: ritmo intocado');
        const pedidoDepois = await canonico(b, a);
        assert.deepEqual(pedidoDepois.criacoesRecentes, pedidoAntes.criacoesRecentes);
        assert.equal(pedidoDepois.corteNaCriacao, pedidoAntes.corteNaCriacao);
        assert.deepEqual(pedidoDepois.ultimaIntencao, pedidoAntes.ultimaIntencao);

        await reentregar(a, b);
        await estavel([...caminhosDaDirecao(a, b), ...caminhosDaDirecao(b, a)], 'reentrega');
        assert.equal((await ritmo(b)).pedidosPendentesEnviados, 0, 'sem segundo debito');
      });

      test('S04/S32b — evento atrasado depois de relacao nova legitima nao toca a relacao nova', async () => {
        const a = await jogador();
        const b = await jogador();
        await cmd(a, 'seguir', b, { referencia: null });
        await bloquear(a, b);
        await ate(async () => (await canonico(a, b))?.estado === 'encerrado', 'faxina');
        await desbloquear(a, b);
        const v = await bloco(a, b);
        assert.equal((await cmd(a, 'seguir', b, { referencia: v.meu.referencia })).estado, 'seguindo');
        const nova = await canonico(a, b);
        const ritmoA = await ritmo(a);

        await reentregar(a, b); // evento antigo, reentregue: so o par
        await estavel(caminhosDaDirecao(a, b), 'evento atrasado');
        await desbloquear(a, b);
        assert.deepEqual(await canonico(a, b), nova, 'a relacao nova esta intacta');
        assert.equal(await espelhos(a, b), 'P1+P2');
        assert.deepEqual(await ritmo(a), ritmoA, 'nenhum debito');
      });

      test('S05/S32c — comando com referencia de ANTES do bloqueio, reenviado depois do desbloqueio: referenciaObsoleta', async () => {
        const a = await jogador();
        const b = await jogador();
        const antes = (await bloco(a, b)).meu.referencia;
        await bloquear(a, b);
        await desbloquear(a, b);
        await assert.rejects(() => cmd(a, 'seguir', b, { referencia: antes }), recusa('referenciaObsoleta'));
        assert.equal(await canonico(a, b), undefined, 'nada criado');
        assert.equal(await espelhos(a, b), 'nenhum');
      });

      test('S06/S24/S16 — seguir nos dois sentidos: as duas direcoes saem das listas e dos contadores, e nenhuma resposta diz quem bloqueou', async () => {
        const a = await jogador();
        const b = await jogador();
        await cmd(a, 'seguir', b, { referencia: null });
        await cmd(b, 'seguir', a, { referencia: null });
        await bloquear(b, a); // B bloqueia A
        await ate(async () => (await canonico(a, b))?.estado === 'encerrado'
          && (await canonico(b, a))?.estado === 'encerrado', 'as duas direcoes');
        for (const [x, y] of [[a, b], [b, a]]) {
          assert.equal(await espelhos(x, y), 'nenhum');
          assert.equal(await bloco(x, y), null, 'as duas pontas veem o mesmo: sem bloco');
          assert.deepEqual((await x.listarSeguindo({})).data.itens, []);
          assert.deepEqual((await x.listarSeguidores({})).data.itens, []);
          const c = (await x.contadores({})).data.contadores;
          assert.equal(c.seguidores, 0);
          assert.equal(c.seguindo, 0);
        }
      });

      test('S07 — contador do REMETENTE: faxina, reentregas e reconciliacao do remetente em paralelo debitam uma vez so', async (t) => {
        const a = await jogador();
        const b = await jogador();
        const adm = await clienteAdmin();
        await privado(a);
        await cmd(b, 'seguir', a, { referencia: null });
        assert.equal((await ritmo(b)).pedidosPendentesEnviados, 1);
        await bloquear(a, b);
        const ini = performance.now();
        const [r] = await Promise.all([
          adm.reconciliar(b),
          reentregar(a, b).then(() => reentregar(a, b)),
        ]);
        const fim = performance.now();
        assert.equal(r.reconciliado, true);
        await ate(async () => (await canonico(b, a))?.estado === 'encerrado', 'encerrado');
        await estavel([...caminhosDaDirecao(b, a)], 'depois das reentregas');
        assert.equal((await ritmo(b)).pedidosPendentesEnviados, 0, 'um debito, nunca dois');
        t.diagnostic(`S07: reconciliacao em ${(fim - ini).toFixed(0)} ms com duas reentregas em paralelo; `
          + `encerrada pela reconciliacao=${r.seguir.encerradasPorCorte}`);
      });

      test('S08/S33d — com documento de bloqueio: o reenvio exato da intencao antiga e obsoleto; O12 nenhum; token novo cria', async () => {
        const a = await jogador();
        const b = await jogador();
        await privado(b);
        const X = intencao();
        await cmd(a, 'seguir', b, { referencia: null, intencaoId: X });
        await bloquear(a, b);
        await ate(async () => (await canonico(a, b))?.estado === 'encerrado', 'faxina');
        assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0);
        await desbloquear(a, b);
        await assert.rejects(() => cmd(a, 'seguir', b, { referencia: null, intencaoId: X }),
          recusa('referenciaObsoleta'));
        const v = await bloco(a, b);
        assert.equal(v.meu.estado, 'nenhum');
        assert.equal((await cmd(a, 'seguir', b, { referencia: v.meu.referencia })).estado, 'pendente');
        assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
      });

      test('S09/S32e — relacao criada sob corte novo + faxina tardia: nada muda', async () => {
        const a = await jogador();
        const b = await jogador();
        await cmd(a, 'seguir', b, { referencia: null });
        await semearCorte(a, b, 'corteS09');
        const v = await bloco(a, b);
        assert.equal(v.meu.estado, 'nenhum');
        assert.equal((await cmd(a, 'seguir', b, { referencia: v.meu.referencia })).estado, 'seguindo');
        const nova = await canonico(a, b);
        assert.equal(nova.corteNaCriacao, 'corteS09');
        // Faxina tardia: o gatilho recebe o par e rele o corte ATUAL (o mesmo).
        await aplicarAtomico({ [`users/${a.uid}/blocks/${b.uid}`]: {
          bloqueadorUid: a.uid, bloqueadoUid: b.uid, criadoEm: new Date(), esquema: 1 } });
        await estavel(caminhosDaDirecao(a, b), 'faxina tardia');
        await desbloquear(a, b);
        assert.deepEqual(await canonico(a, b), nova);
        assert.equal(await espelhos(a, b), 'P1+P2');
      });

      test('S10/S35 com bloqueio — O12 em voo contra {bloqueio + corte} x {sem bloqueio, mesmo corte}: nunca o vinculo antigo como efetivo', async (t) => {
        const obs = await jogador();
        const alvo = await jogador();
        await cmd(obs, 'seguir', alvo, { referencia: null }); // vinculo sob corte nenhum
        const corte = { corteId: novoCorte(), membros: [obs.uid, alvo.uid].sort(),
          atualizadoEm: '2026-01-01T00:00:00.000Z', esquema: 1 };
        const bloqueio = { bloqueadorUid: obs.uid, bloqueadoUid: alvo.uid,
          criadoEm: new Date('2026-01-01T00:00:00.000Z'), esquema: 1 };
        const X = { [`users/${obs.uid}/blocks/${alvo.uid}`]: bloqueio, [caminhoCorte(obs, alvo)]: corte };
        const Y = { [`users/${obs.uid}/blocks/${alvo.uid}`]: null, [caminhoCorte(obs, alvo)]: corte };
        // A faxina do primeiro X converge ANTES da corrida: o estado fisico
        // estabiliza e as trocas seguintes so alternam bloqueio e contato.
        await aplicarAtomico(X);
        await ate(async () => (await canonico(obs, alvo))?.estado === 'encerrado', 'faxina inicial');
        await aplicarAtomico(Y);
        const emY = await bloco(obs, alvo);
        assert.equal(emY.meu.estado, 'nenhum', 'o vinculo de antes do corte nao vale');
        assert.match(emY.meu.referencia, new RegExp(`\\.${corte.corteId}$`));
        await corridaO12(t, { obs, alvo, X, Y });
      });

      test('S11/S38 — no teto de ritmo e de pendentes: deixar, cancelar, recusar e remover passam; criar nao', async () => {
        const a = await jogador();
        const b = await jogador();
        const c = await jogador();
        const e = await jogador();
        const g = await jogador();
        const h = await jogador();
        await cmd(g, 'seguir', a, { referencia: null }); // g segue a (confirmado)
        await cmd(a, 'seguir', b, { referencia: null }); // a segue b
        await privado(c);
        await cmd(a, 'seguir', c, { referencia: null }); // pedido a -> c
        await privado(a);
        await cmd(e, 'seguir', a, { referencia: null }); // pedido e -> a
        const agora = Date.now();
        await semear(R(a), {
          ...(await ritmo(a)),
          criacoes: Array.from({ length: 30 }, (_, i) => new Date(agora - i * 1000).toISOString()),
          pedidosPendentesEnviados: 100,
        });
        await assert.rejects(() => cmd(a, 'seguir', h, { referencia: null }),
          (x) => ['ritmoExcedido', 'limitePedidosPendentes'].includes(x.details?.recusa));
        assert.equal((await cmd(a, 'deixarSeguir', b)).ok, true);
        assert.equal((await cmd(a, 'cancelarSeguir', c)).ok, true);
        assert.equal((await cmd(a, 'recusarSeguir', e)).ok, true);
        assert.equal((await cmd(a, 'removerSeguidor', g)).ok, true);
        assert.equal((await ritmo(a)).pedidosPendentesEnviados, 99, 'cancelar debita o proprio pedido');
      });

      // ------------------------------------------------- R1: diarios

      test('S12 — diario em QUALQUER ponta: a faxina de seguir nao escreve', async () => {
        for (const emExclusao of ['seguidor', 'seguido']) {
          const a = await jogador();
          const b = await jogador();
          await cmd(a, 'seguir', b, { referencia: null });
          await diario(emExclusao === 'seguidor' ? a : b);
          const antes = await foto(caminhosDaDirecao(a, b));
          await bloquear(a, b);
          assert.deepEqual(await estavel(caminhosDaDirecao(a, b), `diario no ${emExclusao}`), antes);
        }
      });

      test('S13/R1 — faxina LEGADA de amizade com diario: amizade, projecoes e contadores de playerSocial intactos', async () => {
        const a = await jogador();
        const b = await jogador();
        await amigos(a, b);
        await diario(b);
        const caminhos = caminhosDoPar(a, b);
        const antes = await foto(caminhos);
        await bloquear(a, b);
        assert.deepEqual(await estavel(caminhos, 'faxina legada com diario'), antes);
        assert.equal((await ler(caminhoPar(a, b))).estado, 'amigos');
        assert.equal((await ler(`playerSocial/${a.uid}`)).amigos, 1, 'o contador nao e ajustado');
      });

      test('S14/R1 — diario criado EM VOO durante a faxina (amizade + seguir): o estado final e o do instante do diario', async (t) => {
        const a = await jogador();
        const parceiros = [];
        for (let i = 0; i < 8; i++) {
          const b = await jogador();
          await amigos(a, b);
          await cmd(a, 'seguir', b, { referencia: null });
          parceiros.push(b);
        }
        const caminhos = parceiros.flatMap((b) => caminhosDoPar(a, b));
        const estado = {};
        for (const b of parceiros) Object.assign(estado, bloqueioDaModeracao(a, b, novoCorte()));
        await aplicarAtomico(estado); // oito bloqueios: 24 unidades de faxina
        const unidadeFeita = async (b) => {
          const [par, seg] = await Promise.all([ler(caminhoPar(a, b)), canonico(a, b)]);
          return !par || seg?.estado === 'encerrado';
        };
        // Sondagem sem pausa: o diario precisa nascer no MEIO das 24 unidades.
        const prazo = Date.now() + 20000;
        while (!(await Promise.all(parceiros.map(unidadeFeita))).some(Boolean)) {
          if (Date.now() > prazo) assert.fail('nenhuma unidade de faxina concluiu no prazo');
        }
        const instante = await diarioLendo(a, caminhos);
        await pausa(JANELA);
        assert.deepEqual(await foto(caminhos), instante, 'nada escrito depois do diario');
        let feitas = 0;
        let pendentes = 0;
        for (const b of parceiros) {
          for (const c of [caminhoPar(a, b), `follows/${a.uid}|${b.uid}`]) {
            const v = instante[c];
            const concluida = v === null || JSON.parse(v).estado === 'encerrado';
            if (concluida) feitas++;
            else pendentes++;
          }
        }
        assert.ok(feitas >= 1, 'o diario veio depois de alguma unidade');
        assert.ok(pendentes >= 1, 'e antes de outras: sobreposicao real');
        t.diagnostic(`S14: no instante do diario, ${feitas} unidades concluidas e ${pendentes} ainda nao`);
      });

      test('S16 — reconciliacao com diario JA presente: contaEmExclusao e nenhuma escrita', async () => {
        const a = await jogador();
        const b = await jogador();
        const adm = await clienteAdmin();
        await amigos(a, b);
        await cmd(a, 'seguir', b, { referencia: null });
        await apagar(caminhosEspelho(a, b).P2); // algo que a reconciliacao reescreveria
        await diario(a);
        const caminhos = caminhosDoPar(a, b);
        const antes = await foto(caminhos);
        await assert.rejects(() => adm.reconciliar(a), (e) => {
          assert.equal(e.code, 'functions/failed-precondition');
          assert.equal(e.details?.recusa, 'contaEmExclusao');
          assert.equal(e.details?.parcial, false);
          return true;
        });
        assert.deepEqual(await foto(caminhos), antes);
      });

      test('S17/R1 — diario criado EM VOO durante a reconciliacao: nenhuma unidade escreve depois dele; o anterior fica', async (t) => {
        const a = await jogador({ comVip: false });
        const adm = await clienteAdmin();
        // Trinta outras pontas SEMEADAS (identidade + direcao no formato
        // congelado): a reconciliacao so precisa de canonico e identidade.
        const outros = Array.from({ length: 30 }, (_, i) => ({
          uid: `c4s17${a.uid.slice(0, 6)}o${String(i).padStart(2, '0')}`,
          pid: `PS17${String(i).padStart(9, '0')}`,
        }));
        const estado = {};
        for (let i = 0; i < outros.length; i++) {
          estado[`playerIdentities/${outros[i].uid}`] = { publicId: outros[i].pid };
          Object.assign(estado, direcaoSemeada(a, outros[i], 'confirmado', `refS17x${i}`));
          // Cada direcao sem P2: toda unidade tera o que reescrever.
          estado[caminhosEspelho(a, outros[i]).P2] = null;
        }
        await aplicarAtomico(estado);
        const caminhos = outros.flatMap((o) => caminhosDaDirecao(a, o));

        const restaurados = async () => (await Promise.all(
          outros.map((o) => ler(caminhosEspelho(a, o).P2)),
        )).filter(Boolean).length;
        const chamada = adm.reconciliar(a).then((r) => ({ r }), (e) => ({ e }));
        const prazo = Date.now() + 20000;
        while ((await restaurados()) < 1) {
          if (Date.now() > prazo) assert.fail('nenhuma unidade de reconciliacao concluiu no prazo');
        }
        const instante = await diarioLendo(a, caminhos);
        const desfecho = await chamada;
        await pausa(1000);
        assert.deepEqual(await foto(caminhos), instante, 'nada escrito depois do diario');

        const naFoto = outros.filter((o) => instante[caminhosEspelho(a, o).P2] !== null).length;
        assert.ok(naFoto >= 1, 'unidades confirmadas antes do diario ficam');
        assert.ok(naFoto < outros.length, 'e o diario chegou no meio');
        assert.ok(desfecho.e, 'a rotina parou no diario');
        assert.equal(desfecho.e.details?.recusa, 'contaEmExclusao');
        assert.equal(desfecho.e.details?.parcial, true);
        t.diagnostic(`S17: ${naFoto} de ${outros.length} direcoes confirmadas antes do diario; `
          + `unidadesConfirmadas=${desfecho.e.details?.unidadesConfirmadas}`);
      });

      test('S18 — outra ponta em exclusao: amizade e seguir com ela pulados e relatados, sem recriar projecao', async () => {
        const a = await jogador();
        const c = await jogador();
        const adm = await clienteAdmin();
        await amigos(a, c);
        await cmd(a, 'seguir', c, { referencia: null });
        await apagar(`users/${a.uid}/friends/${c.uid}`);
        await apagar(caminhosEspelho(a, c).P1);
        await diario(c);
        const r = await adm.reconciliar(a);
        semPrivado(r, [a, c]);
        assert.equal(r.amizade.puladasPorExclusao, 1);
        assert.equal(r.seguir.puladasPorExclusao, 1);
        assert.equal(await ler(`users/${a.uid}/friends/${c.uid}`), undefined);
        assert.equal(await ler(caminhosEspelho(a, c).P1), undefined);
      });

      test('S15 — reconciliacao: espelho reescrito, pedido sob corte antigo encerrado com debito unico, residuo relatado e NAO apagado; repetir nao muda nada', async () => {
        const a = await jogador();
        const b = await jogador();
        const c = await jogador();
        const adm = await clienteAdmin();
        await cmd(a, 'seguir', b, { referencia: null });
        await apagar(caminhosEspelho(a, b).P2);
        await privado(c);
        await cmd(a, 'seguir', c, { referencia: null });
        assert.equal((await ritmo(a)).pedidosPendentesEnviados, 1);
        await semearCorte(a, c, 'corteS15');
        const residuo = `users/${a.uid}/seguindo/c4ResiduoSemCanonico`;
        await semear(residuo, { publicId: 'PRESIDU000000', desde: '2026-01-01T00:00:00.000Z', referencia: 'x.' });
        const criacoes = (await ritmo(a)).criacoes;

        const r = await adm.reconciliar(a);
        semPrivado(r, [a, b, c]);
        assert.equal(r.reconciliado, true);
        assert.equal(r.seguir.ritmo, 'recontado');
        assert.equal(r.seguir.encerradasPorCorte, 1);
        assert.ok(r.seguir.espelhosReescritos >= 1);
        assert.equal(r.seguir.residuos, 1);
        assert.ok(await ler(caminhosEspelho(a, b).P2), 'P2 reescrito');
        assert.equal((await canonico(a, c)).estado, 'encerrado');
        assert.equal(await espelhos(a, c), 'nenhum');
        assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0, 'recontado 1, encerrado -1');
        assert.deepEqual((await ritmo(a)).criacoes, criacoes, 'criacoes intocado');
        assert.ok(await ler(residuo), 'residuo relatado e nao apagado');

        const r2 = await adm.reconciliar(a);
        assert.equal(r2.seguir.encerradasPorCorte, 0);
        assert.equal(r2.seguir.espelhosReescritos, 0);
        assert.equal((await ritmo(a)).pedidosPendentesEnviados, 0, 'sem desconto duplo');
      });

      // ------------------------------------------------- R4: contador

      test('S19/R4 — contador do remetente invalido (1,5 e -1): a faxina nao escreve a direcao, a outra direcao segue; a reconciliacao do remetente reconta e conclui, sem desconto duplo', async () => {
        for (const invalido of [1.5, -1]) {
          const a = await jogador();
          const b = await jogador();
          const adm = await clienteAdmin();
          await privado(a);
          await cmd(b, 'seguir', a, { referencia: null }); // pedido B -> A
          await cmd(a, 'seguir', b, { referencia: null }); // A segue B
          await semear(R(b), { ...(await ritmo(b)), pedidosPendentesEnviados: invalido });
          const criacoes = (await ritmo(b)).criacoes;
          await bloquear(a, b);
          await ate(async () => (await canonico(a, b))?.estado === 'encerrado', 'a outra direcao');
          await estavel(caminhosDaDirecao(b, a), `contador ${invalido}`);
          assert.equal((await canonico(b, a)).estado, 'pendente', 'a direcao com erro nao foi escrita');
          assert.equal((await ritmo(b)).pedidosPendentesEnviados, invalido, 'sem max(0), sem truncar');
          assert.equal(await bloco(b, a), null, 'o acesso continua negado');

          const r = await adm.reconciliar(b);
          assert.equal(r.seguir.ritmo, 'recontado');
          assert.equal(r.seguir.encerradasPorCorte, 1);
          assert.equal((await canonico(b, a)).estado, 'encerrado');
          assert.equal((await ritmo(b)).pedidosPendentesEnviados, 0);
          assert.deepEqual((await ritmo(b)).criacoes, criacoes, 'historico de criacao preservado');
          const r2 = await adm.reconciliar(b);
          assert.equal(r2.seguir.encerradasPorCorte, 0);
          await reentregar(a, b);
          await estavel([...caminhosDaDirecao(b, a), R(b)], 'reentrega depois do reparo');
          assert.equal((await ritmo(b)).pedidosPendentesEnviados, 0, 'sem desconto duplo');
        }
      });

      test('S20/R4 — reconciliar a OUTRA ponta relata o contador invalido do remetente e nao escreve aquela direcao', async () => {
        const a = await jogador();
        const b = await jogador();
        const adm = await clienteAdmin();
        await privado(a);
        await cmd(b, 'seguir', a, { referencia: null });
        await semear(R(b), { ...(await ritmo(b)), pedidosPendentesEnviados: 1.5 });
        await bloquear(a, b);
        await estavel(caminhosDaDirecao(b, a), 'faxina recusada');
        const r = await adm.reconciliar(a);
        semPrivado(r, [a, b]);
        assert.equal(r.seguir.contadorInvalidoDoRemetente, 1);
        assert.equal(r.seguir.encerradasPorCorte, 0);
        assert.equal((await canonico(b, a)).estado, 'pendente');
        assert.equal((await ritmo(b)).pedidosPendentesEnviados, 1.5);
      });

      test('S21/R4 — ritmo AUSENTE com pedido pendente: faxina nao escreve; a reconciliacao relata ausente e nao cria ritmo', async () => {
        const a = await jogador();
        const b = await jogador();
        const adm = await clienteAdmin();
        await privado(a);
        await cmd(b, 'seguir', a, { referencia: null });
        await apagar(R(b));
        await bloquear(a, b);
        await estavel(caminhosDaDirecao(b, a), 'faxina sem ritmo');
        assert.equal((await canonico(b, a)).estado, 'pendente');
        const r = await adm.reconciliar(b);
        assert.equal(r.seguir.ritmo, 'ausente');
        assert.equal(r.seguir.pendentesSemRitmo, 1);
        assert.equal(await ritmo(b), undefined, 'ritmo nao e criado');
        assert.equal((await canonico(b, a)).estado, 'pendente');
        assert.equal(await bloco(b, a), null, 'o acesso continua negado pelo bloqueio/corte');
      });

      test('S22 — reconciliarPerfilSocial: so admin; a resposta nao carrega UID nem campo interno', async () => {
        const a = await jogador();
        const b = await jogador();
        const adm = await clienteAdmin();
        await amigos(a, b);
        await cmd(a, 'seguir', b, { referencia: null });
        await assert.rejects(() => httpsCallableDoJogador(a)({ publicId: b.pid }),
          (e) => e.code === 'functions/permission-denied');
        const r = await adm.reconciliar(a);
        semPrivado(r, [a, b]);
        assert.deepEqual(Object.keys(r).sort(), ['amigos', 'amizade', 'reconciliado', 'seguir', 'solicitacoes']);
        assert.equal(r.amigos, 1);
        assert.equal(r.amizade.amigos, 1);
        assert.equal(r.amizade.recontagem, 'ok');
      });

      /// A callable administrativa chamada por um JOGADOR comum.
      function httpsCallableDoJogador(j) {
        return async (d) => {
          const app = initializeApp({ projectId: PROJETO, apiKey: 'fake' }, `c4-nao-admin-${j.uid}`);
          const auth = getAuth(app);
          connectAuthEmulator(
            auth,
            `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`,
            { disableWarnings: true },
          );
          await signInAnonymously(auth);
          const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
          const f = getFunctions(app, 'southamerica-east1');
          connectFunctionsEmulator(f, host, Number(porta));
          return httpsCallable(f, 'reconciliarPerfilSocial')(d);
        };
      }
    });

    test('sem autenticacao, toda callable de seguir e recusada', async () => {
      const { initializeApp: init } = require('firebase/app');
      const app = init({ projectId: PROJETO, apiKey: 'fake' }, 'seguir-anonimo');
      const [host, porta] = (process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001').split(':');
      const f = getFunctions(app, 'southamerica-east1');
      connectFunctionsEmulator(f, host, Number(porta));
      for (const nome of ['seguirJogador', 'cancelarPedidoSeguir', 'aprovarPedidoSeguir',
        'recusarPedidoSeguir', 'deixarDeSeguir', 'removerSeguidor', 'listarSeguidores',
        'listarSeguindo', 'listarPedidosSeguirRecebidos', 'listarPedidosSeguirEnviados',
        'definirPrivacidadeSocial', 'consultarContadoresSociais']) {
        await assert.rejects(
          () => httpsCallable(f, nome)({ publicId: pidUm, privacidade: 'privado' }),
          (e) => e.code === 'functions/unauthenticated',
          `${nome} tinha que exigir autenticacao`,
        );
      }
    });
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
