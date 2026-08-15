/**
 * INTEGRACAO CONTRA O FIRESTORE E O AUTH REAIS (emulador).
 *
 * OS de Exclusao de Conta e Dados do Jogador v1 — os dez casos de teste.
 *
 * ESTA SUITE E A UNICA QUE PROVA O QUE IMPORTA DE VERDADE, e vale dizer por que:
 * as suites puras provam a MATRIZ (o que deve acontecer com cada dado) e o PLANO
 * (em que ordem). Nenhuma delas prova que o dado SAIU. Um item classificado
 * APAGAR, com etapa declarada e execucao escrita, ainda pode consultar a colecao
 * errada — e as tres suites puras passariam.
 *
 * Aqui a afirmacao e outra: grava-se o jogador inteiro, roda-se a exclusao, e
 * confere-se documento por documento o que sumiu, o que ficou sem rosto, o que
 * perdeu o titular e o que continua intacto.
 *
 * OS DEZ CASOS DA OS, e onde cada um esta:
 *   comum ................. "jogador comum"
 *   VIP ................... "jogador VIP"
 *   ranqueado ............. "jogador ranqueado"
 *   com amizades .......... "jogador com amizades"
 *   bloqueado ............. "jogador bloqueado por outros"
 *   com denuncias ......... "jogador com denuncias"
 *   chamada duplicada ..... "chamada duplicada e idempotencia"
 *   alvo de terceiro ...... "a exclusao nao encosta em quem nao foi excluido"
 *                           (a recusa do payload e pura, em plano.test.js)
 *   falha parcial ......... "falha parcial e retomada"
 *   idempotencia .......... "chamada duplicada e idempotencia"
 *
 * NAO RODA NO `npm test`. O alvo e `npm run test:emulador`.
 *
 * O QUE ELA NAO PROVA, e fica declarado: o emulador do Firestore NAO EXIGE
 * indice — ele os cria sozinho. As duas consultas collection-group desta OS
 * (`blocks.bloqueadoUid`, `mutes.alvoUid`) passam aqui mesmo que o
 * `fieldOverrides` nao existisse, e falhariam em producao. A conferencia do
 * indice e por leitura de firebase/firestore.indexes.json, e continua sendo
 * portao de pre-deploy — a mesma ressalva que
 * functions-ranking/test/integracao.emulador.test.js ja registra.
 */

const { test, describe, before, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

const admin = require("firebase-admin");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error("esta suite exige o emulador do Firestore. Use `npm run test:emulador`.");
}
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  // Sem esta trava, `deleteUser` tentaria falar com o Google de verdade e a
  // suite falharia com um erro de credencial que nao explica nada.
  throw new Error(
    "esta suite exige o emulador de Auth. O alvo `test:emulador` sobe `--only firestore,auth`."
  );
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-bmv" });

const { executar, lerPublicId, C_DIARIO } = require("../lib/executor");
const { ETAPAS } = require("../lib/plano");
const { APELIDO_ANONIMO, ESTADO_PERFIL_REMOVIDO } = require("../lib/inventario");

const db = admin.firestore();
const auth = admin.auth();

const ALVO = "uid-do-jogador-que-sai";
const AMIGO = "uid-do-amigo";
const TERCEIRO = "uid-de-quem-fica";
const PUBLIC_ID = "P0ALVO0000AA";
const PUBLIC_AMIGO = "P0AMIGO000BB";

// ---------------------------------------------------------------------------
// PREPARO
// ---------------------------------------------------------------------------

/// Apaga as colecoes que os casos usam.
///
/// Lista explicita, e nao varredura do banco: uma varredura apagaria colecao
/// criada por outra suite rodando no mesmo emulador, e o defeito apareceria
/// como falha intermitente noutro arquivo.
const COLECOES = [
  "users",
  "usuarios",
  "playerIdentities",
  "publicIdIndex",
  "publicProfiles",
  "friendships",
  "playerSocial",
  "playerEntitlements",
  "compras",
  "billingEvents",
  "wallets",
  "rankingSeasons",
  "rankingStandings",
  "rankingPlayers",
  "rankingLedger",
  "hallEntries",
  "reports",
  "sanctions",
  "playerModeration",
  "matches",
  "campaigns",
  "tournaments",
  C_DIARIO,
];

async function limpar() {
  for (const colecao of COLECOES) {
    // `recursiveDelete` E PERMITIDO AQUI, e proibido no executor: no teste ele
    // limpa; la ele apagaria subcolecao sem passar pela matriz.
    await db.recursiveDelete(db.collection(colecao));
  }
  for (const uid of [ALVO, AMIGO, TERCEIRO]) {
    try {
      await auth.deleteUser(uid);
    } catch (e) {
      if (e.code !== "auth/user-not-found") throw e;
    }
  }
}

async function criarContaAuth(uid) {
  await auth.createUser({ uid, email: `${uid}@exemplo.invalido` });
}

/// O jogador minimo: conta, identidade publica, perfil e carteira.
async function semearComum(uid = ALVO, publicId = PUBLIC_ID) {
  await criarContaAuth(uid);
  await db.collection("playerIdentities").doc(uid).set({ uid, publicId });
  await db.collection("publicIdIndex").doc(publicId).set({ publicId, uid });
  await db.collection("publicProfiles").doc(publicId).set({
    publicId,
    apelido: "Dona Rosa",
    apelidoOrdenacao: "dona rosa",
    avatarRef: "avatar/rosa.webp",
    estado: "ativo",
  });
  await db.collection("users").doc(uid).set({ criadoEm: "2026-01-01" });
  await db.collection("usuarios").doc(uid).set({ fichas: 40, apelido: "Dona Rosa" });
  await db.collection("wallets").doc(uid).set({ fichas: 120 });
  await db
    .collection("users")
    .doc(uid)
    .collection("matchHistory")
    .doc("m1")
    .set({ data: "2026-02-01", vitorias: 1 });
  await db
    .collection("users")
    .doc(uid)
    .collection("inventory")
    .doc("coroa")
    .set({ userId: uid, equipped: true });
}

async function semearVip(uid = ALVO) {
  await db.collection("playerEntitlements").doc(uid).set({
    uid,
    vipAtivo: true,
    expiraEm: "2026-12-31T00:00:00.000Z",
    produtoId: "vip_mensal",
  });
  await db
    .collection("playerEntitlements")
    .doc(uid)
    .collection("interno")
    .doc("billing")
    .set({ uid, purchaseToken: "TOKEN-EM-CLARO", purchaseTokenHash: "abc123" });
  await db
    .collection("compras")
    .doc("abc123")
    .set({ uid, produtoId: "vip_mensal", assinatura: true, valorCentavos: 1990 });
  await db
    .collection("billingEvents")
    .doc("msg-1")
    .set({ uid, messageId: "msg-1", estado: "concluido", token: "abc1" });
}

async function semearRanqueado(uid = ALVO, publicId = PUBLIC_ID) {
  await db.collection("rankingSeasons").doc("2026-A").set({ seasonId: "2026-A", status: "encerrada" });
  await db.collection("rankingSeasons").doc("2026-B").set({ seasonId: "2026-B", status: "vigente" });
  for (const season of ["2026-A", "2026-B"]) {
    await db.collection("rankingStandings").doc(`${season}|${uid}`).set({
      seasonId: season,
      uid,
      publicPlayerId: publicId,
      apelido: "Dona Rosa",
      avatar: "avatar/rosa.webp",
      pontos: 1440,
    });
  }
  await db.collection("rankingPlayers").doc(uid).set({
    uid,
    publicPlayerId: publicId,
    apelido: "Dona Rosa",
    avatar: "avatar/rosa.webp",
    pontosTotais: 3120,
  });
  await db
    .collection("rankingLedger")
    .doc(`m1|${uid}|partida`)
    .set({ userId: uid, matchId: "m1", antes: 1400, delta: 40, depois: 1440 });
  await db
    .collection("matches")
    .doc("m1")
    .set({ userIdsCompetidores: [uid, AMIGO, TERCEIRO], encerradaEm: "2026-02-01" });
}

async function semearAmizade(uid = ALVO, outro = AMIGO) {
  const par = [uid, outro].sort().join("|");
  await db.collection("friendships").doc(par).set({
    membros: [uid, outro].sort(),
    estado: "amigos",
    solicitanteUid: uid,
    destinatarioUid: outro,
    amigosDesde: "2026-03-01",
    publicIds: { [uid]: PUBLIC_ID, [outro]: PUBLIC_AMIGO },
  });
  await db
    .collection("users")
    .doc(uid)
    .collection("friends")
    .doc(outro)
    .set({ publicId: PUBLIC_AMIGO, apelidoOrdenacao: "amigo" });
  await db
    .collection("users")
    .doc(outro)
    .collection("friends")
    .doc(uid)
    .set({ publicId: PUBLIC_ID, apelidoOrdenacao: "dona rosa" });
  await db
    .collection("users")
    .doc(outro)
    .collection("friendRequests")
    .doc(uid)
    .set({ direcao: "recebida", publicId: PUBLIC_ID, solicitadaEm: "2026-03-01" });
  await db.collection("playerSocial").doc(uid).set({ uid, amigos: 1, solicitacoesEnviadas: 0 });
}

async function semearBloqueios(uid = ALVO) {
  // O que ELE bloqueou.
  await db
    .collection("users")
    .doc(uid)
    .collection("blocks")
    .doc(TERCEIRO)
    .set({ bloqueadorUid: uid, bloqueadoUid: TERCEIRO });
  await db
    .collection("users")
    .doc(uid)
    .collection("mutes")
    .doc(TERCEIRO)
    .set({ alvoUid: TERCEIRO });
  // O que OUTROS fizeram contra ele — o espelho que uma exclusao ingenua esquece.
  await db
    .collection("users")
    .doc(TERCEIRO)
    .collection("blocks")
    .doc(uid)
    .set({ bloqueadorUid: TERCEIRO, bloqueadoUid: uid });
  await db.collection("users").doc(TERCEIRO).collection("mutes").doc(uid).set({ alvoUid: uid });
}

async function semearDenuncias(uid = ALVO) {
  // Uma que ele fez, e uma que ele sofreu.
  await db
    .collection("reports")
    .doc(`${uid}|intent-1`)
    .set({ denuncianteUid: uid, denunciadoUid: TERCEIRO, tipo: "mensagem", status: "recebida" });
  await db
    .collection("reports")
    .doc(`${TERCEIRO}|intent-2`)
    .set({ denuncianteUid: TERCEIRO, denunciadoUid: uid, tipo: "conduta", status: "recebida" });
  await db
    .collection("users")
    .doc(uid)
    .collection("reportReceipts")
    .doc(`${uid}|intent-1`)
    .set({ protocolo: `${uid}|intent-1`, status: "recebida" });
  await db
    .collection("sanctions")
    .doc("s1")
    .set({ userId: uid, tipo: "silenciamento", inicio: "2026-04-01", revogada: false });
  await db
    .collection("playerModeration")
    .doc(uid)
    .set({ chatSilenciadoAte: "2026-05-01", suspensaoPermanente: false });
}

const existe = async (caminho) => (await db.doc(caminho).get()).exists;
const dados = async (caminho) => (await db.doc(caminho).get()).data();

before(limpar);
beforeEach(limpar);

// ---------------------------------------------------------------------------
// OS CASOS
// ---------------------------------------------------------------------------

describe("jogador comum", () => {
  test("a conta some do Authentication e o perfil sai do Firestore", async () => {
    await semearComum();

    const r = await executar(ALVO);
    assert.equal(r.estado, "concluida");
    assert.equal(r.etapasConcluidas.length, ETAPAS.length);

    await assert.rejects(() => auth.getUser(ALVO), /user-not-found|no user record/i);

    assert.equal(await existe(`users/${ALVO}`), false);
    assert.equal(await existe(`usuarios/${ALVO}`), false, "o namespace legado do Billing tambem sai");
    assert.equal(await existe(`wallets/${ALVO}`), false);
    assert.equal(await existe(`playerIdentities/${ALVO}`), false);
    assert.equal(
      await existe(`users/${ALVO}/matchHistory/m1`),
      false,
      "a projecao pessoal do historico sai"
    );
    assert.equal(await existe(`users/${ALVO}/inventory/coroa`), false);
  });

  test("o perfil publico fica anonimo e indisponivel, em vez de sumir", async () => {
    await semearComum();
    await executar(ALVO);

    const perfil = await dados(`publicProfiles/${PUBLIC_ID}`);
    assert.ok(perfil, "o perfil publico continua existindo");
    assert.equal(perfil.apelido, APELIDO_ANONIMO);
    assert.equal(perfil.avatarRef, null);
    assert.equal(perfil.apelidoOrdenacao, "");
    assert.equal(perfil.estado, ESTADO_PERFIL_REMOVIDO);
  });

  test("o publicId vira lapide e nao volta ao sorteio", async () => {
    await semearComum();
    await executar(ALVO);

    const indice = await dados(`publicIdIndex/${PUBLIC_ID}`);
    assert.ok(indice, "o documento fica — apagar devolveria o codigo ao sorteio");
    assert.equal(indice.uid, undefined, "e sem o uid: o caminho de volta morreu");
    assert.equal(indice.estado, "retirado");
  });

  test("o diario registra o encerramento, sem guardar quem a pessoa era", async () => {
    await semearComum();
    await executar(ALVO);

    const diario = await dados(`${C_DIARIO}/${ALVO}`);
    assert.equal(diario.estado, "concluida");
    assert.equal(diario.publicId, PUBLIC_ID);
    assert.equal(diario.resumo.fichas, 120, "o saldo do encerramento fica para o suporte");
    assert.ok(diario.concluidaEm);

    const texto = JSON.stringify(diario);
    assert.ok(!texto.includes("Dona Rosa"), "o diario nao guarda apelido");
    assert.ok(!texto.includes("@exemplo.invalido"), "o diario nao guarda e-mail");
  });

  test("conta sem identidade publica tambem e excluida", async () => {
    // Conta criada e abandonada antes de a sessao chamar `obterMinhaIdentidade`.
    // Tratar a ausencia como erro deixaria justamente as contas mais faceis de
    // apagar impossiveis de apagar.
    await criarContaAuth(ALVO);
    await db.collection("users").doc(ALVO).set({ criadoEm: "2026-01-01" });

    assert.equal(await lerPublicId(ALVO), null);
    const r = await executar(ALVO);
    assert.equal(r.estado, "concluida");
  });
});

describe("jogador VIP", () => {
  test("o direito VIP e o token em claro somem", async () => {
    await semearComum();
    await semearVip();

    await executar(ALVO);

    assert.equal(await existe(`playerEntitlements/${ALVO}`), false);
    assert.equal(
      await existe(`playerEntitlements/${ALVO}/interno/billing`),
      false,
      "o documento com o purchaseToken em claro tem que sair EXPLICITAMENTE: apagar o pai nao apaga subcolecao"
    );
  });

  test("a compra fica, e perde o titular", async () => {
    await semearComum();
    await semearVip();
    await executar(ALVO);

    const compra = await dados("compras/abc123");
    assert.ok(compra, "integridade financeira: o registro da transacao fica");
    assert.equal(compra.uid, undefined, "e sem titular");
    assert.equal(compra.valorCentavos, 1990, "o fato fiscal permanece intacto");
    assert.equal(compra.motivoRemocao, "contaExcluida");
  });

  test("o evento da Play fica sem uid — a reentrega continua barrada", async () => {
    await semearComum();
    await semearVip();
    await executar(ALVO);

    const evento = await dados("billingEvents/msg-1");
    assert.ok(evento, "apagar faria uma reentrega do Pub/Sub ser reprocessada");
    assert.equal(evento.uid, undefined);
    assert.equal(evento.estado, "concluido");
  });

  test("o diario guarda o estado do VIP no encerramento", async () => {
    await semearComum();
    await semearVip();
    await executar(ALVO);

    const diario = await dados(`${C_DIARIO}/${ALVO}`);
    assert.equal(diario.resumo.vipAtivo, true);
    assert.equal(diario.resumo.vipExpiraEm, "2026-12-31T00:00:00.000Z");
    assert.equal(diario.resumo.comprasDesvinculadas, 1);
  });
});

describe("jogador ranqueado", () => {
  test("as linhas de classificacao ficam, sem rosto", async () => {
    await semearComum();
    await semearRanqueado();
    await executar(ALVO);

    for (const season of ["2026-A", "2026-B"]) {
      const linha = await dados(`rankingStandings/${season}|${ALVO}`);
      assert.ok(linha, `a linha de ${season} continua existindo`);
      assert.equal(linha.pontos, 1440, "o resultado competitivo nao e reescrito");
      assert.equal(linha.apelido, APELIDO_ANONIMO);
      assert.equal(linha.avatar, "");
    }
  });

  test("o agregado de vida inteira fica, sem rosto", async () => {
    await semearComum();
    await semearRanqueado();
    await executar(ALVO);

    const jogador = await dados(`rankingPlayers/${ALVO}`);
    assert.ok(jogador);
    assert.equal(jogador.pontosTotais, 3120);
    assert.equal(jogador.apelido, APELIDO_ANONIMO);
  });

  test("o ledger e a partida NAO sao tocados", async () => {
    // Uma partida e de quatro pessoas: apagar mudaria o rating de quem ficou.
    await semearComum();
    await semearRanqueado();
    await executar(ALVO);

    const lancamento = await dados(`rankingLedger/m1|${ALVO}|partida`);
    assert.ok(lancamento, "o extrato competitivo permanece");
    assert.equal(lancamento.userId, ALVO, "inclusive o userId: e o que fecha a cadeia");

    const partida = await dados("matches/m1");
    assert.ok(partida);
    assert.deepEqual(partida.userIdsCompetidores, [ALVO, AMIGO, TERCEIRO]);
  });
});

describe("jogador com amizades", () => {
  test("a relacao canonica e os DOIS espelhos somem", async () => {
    await semearComum();
    await semearAmizade();
    await executar(ALVO);

    const par = [ALVO, AMIGO].sort().join("|");
    assert.equal(await existe(`friendships/${par}`), false);
    assert.equal(await existe(`users/${ALVO}/friends/${AMIGO}`), false);
    assert.equal(
      await existe(`users/${AMIGO}/friends/${ALVO}`),
      false,
      "o espelho na conta do AMIGO e o que uma exclusao ingenua esquece"
    );
    assert.equal(
      await existe(`users/${AMIGO}/friendRequests/${ALVO}`),
      false,
      "e a solicitacao pendente do outro lado tambem"
    );
    assert.equal(await existe(`playerSocial/${ALVO}`), false);
  });

  test("o diario conta quantas amizades existiam", async () => {
    await semearComum();
    await semearAmizade();
    await executar(ALVO);
    assert.equal((await dados(`${C_DIARIO}/${ALVO}`)).resumo.amizades, 1);
  });
});

describe("jogador bloqueado por outros", () => {
  test("as listas dele e as referencias a ele somem", async () => {
    await semearComum();
    await semearBloqueios();
    await executar(ALVO);

    assert.equal(await existe(`users/${ALVO}/blocks/${TERCEIRO}`), false);
    assert.equal(await existe(`users/${ALVO}/mutes/${TERCEIRO}`), false);
    assert.equal(
      await existe(`users/${TERCEIRO}/blocks/${ALVO}`),
      false,
      "o bloqueio que OUTRO fez contra ele: o UID esta na chave, dentro da conta de terceiro"
    );
    assert.equal(await existe(`users/${TERCEIRO}/mutes/${ALVO}`), false);
  });
});

describe("jogador com denuncias", () => {
  test("as denuncias e a ficha disciplinar FICAM", async () => {
    await semearComum();
    await semearDenuncias();
    await executar(ALVO);

    assert.ok(
      await existe(`reports/${ALVO}|intent-1`),
      "a denuncia que ELE fez e um processo aberto contra terceiro"
    );
    assert.ok(
      await existe(`reports/${TERCEIRO}|intent-2`),
      "a denuncia que ele SOFREU e o fundamento da sancao"
    );
    assert.ok(await existe("sanctions/s1"), "o historico disciplinar nao se apaga");
    assert.ok(
      await existe(`playerModeration/${ALVO}`),
      "e o ponto exato onde morre a tentativa de apagar a propria punicao"
    );
  });

  test("o comprovante pessoal do denunciante sai", async () => {
    // O registro administrativo fica em `reports`; o comprovante e so a copia de
    // acompanhamento de quem nao existe mais.
    await semearComum();
    await semearDenuncias();
    await executar(ALVO);

    assert.equal(await existe(`users/${ALVO}/reportReceipts/${ALVO}|intent-1`), false);
  });

  test("um jogador suspenso consegue excluir a conta, e a sancao sobrevive", async () => {
    // A exclusao NAO e negada a quem esta punido — negar transformaria a punicao
    // em prisao de dados. O que ela nao faz e limpar a ficha.
    await semearComum();
    await db.collection("playerModeration").doc(ALVO).set({ suspensaoPermanente: true });

    const r = await executar(ALVO);
    assert.equal(r.estado, "concluida");
    assert.equal((await dados(`playerModeration/${ALVO}`)).suspensaoPermanente, true);
  });
});

describe("chamada duplicada e idempotencia", () => {
  test("a segunda chamada converge, sem refazer nada", async () => {
    await semearComum();
    await semearVip();

    const primeira = await executar(ALVO);
    assert.equal(primeira.repeticao, false);
    assert.equal(primeira.estado, "concluida");

    const segunda = await executar(ALVO);
    assert.equal(segunda.repeticao, true, "a repeticao e sinalizada, e nao tratada como erro");
    assert.equal(segunda.estado, "concluida");
  });

  test("a convergencia nao incrementa a contagem de tentativas", async () => {
    // Se incrementasse, um cliente com retry automatico inflaria o contador ate
    // um numero que nao descreve mais nada.
    await semearComum();
    await executar(ALVO);
    const antes = (await dados(`${C_DIARIO}/${ALVO}`)).tentativas;
    await executar(ALVO);
    assert.equal((await dados(`${C_DIARIO}/${ALVO}`)).tentativas, antes);
  });

  test("a segunda chamada nao apaga o resumo que a primeira mediu", async () => {
    await semearComum();
    await semearVip();
    await executar(ALVO);
    const segunda = await executar(ALVO);
    assert.equal(segunda.resumo.fichas, 120);
    assert.equal(segunda.resumo.vipAtivo, true);
  });

  test("duas chamadas simultaneas convergem no mesmo estado final", async () => {
    // O duplo toque real: nenhuma das duas espera a outra. Toda etapa e
    // idempotente, entao a sobreposicao nao corrompe.
    await semearComum();
    await semearAmizade();
    await semearVip();

    const [a, b] = await Promise.all([executar(ALVO), executar(ALVO)]);
    for (const r of [a, b]) {
      assert.ok(["concluida"].includes(r.estado), `estado inesperado: ${r.estado}`);
    }
    assert.equal(await existe(`users/${ALVO}`), false);
    assert.equal((await dados(`${C_DIARIO}/${ALVO}`)).estado, "concluida");
  });
});

describe("a exclusao nao encosta em quem nao foi excluido", () => {
  test("os dados do terceiro permanecem intactos", async () => {
    // O caso "tentativa contra UID de terceiro" tem duas metades. A recusa do
    // payload e pura e esta em plano.test.js; esta e a outra: mesmo executando
    // legitimamente, a exclusao de A nao pode arrastar B junto.
    await semearComum(ALVO, PUBLIC_ID);
    await semearComum(TERCEIRO, "P0TERCEIRO01");
    await semearAmizade(ALVO, AMIGO);
    await criarContaAuth(AMIGO);

    await executar(ALVO);

    assert.ok(await auth.getUser(TERCEIRO), "a conta do terceiro continua no Auth");
    assert.ok(await existe(`users/${TERCEIRO}`));
    assert.ok(await existe(`wallets/${TERCEIRO}`));
    assert.ok(await existe(`playerIdentities/${TERCEIRO}`));

    const perfil = await dados("publicProfiles/P0TERCEIRO01");
    assert.equal(perfil.apelido, "Dona Rosa", "o perfil do terceiro nao foi anonimizado");
    assert.equal(perfil.estado, "ativo");

    assert.ok(await auth.getUser(AMIGO), "o amigo continua existindo — so a relacao acabou");
  });
});

describe("falha parcial e retomada", () => {
  test("sem conta no Auth, a exclusao para na primeira etapa e fica parcial", async () => {
    // A falha e realista: `trancar` chama `updateUser`, e a conta pode ter sido
    // removida por fora. O que importa e o que acontece DEPOIS da falha.
    await db.collection("playerIdentities").doc(ALVO).set({ uid: ALVO, publicId: PUBLIC_ID });
    await db.collection("users").doc(ALVO).set({ criadoEm: "2026-01-01" });
    await db.collection("wallets").doc(ALVO).set({ fichas: 77 });

    const r = await executar(ALVO);

    assert.equal(r.estado, "parcial");
    assert.deepEqual(r.etapasConcluidas, [], "parou na primeira etapa");
    assert.equal(r.falhas.length, 1);
    assert.equal(r.falhas[0].etapa, "trancar");

    // E PARA NA PRIMEIRA FALHA: as etapas seguintes nao rodaram, entao o dado
    // continua la, coerente, esperando a retomada.
    assert.ok(await existe(`users/${ALVO}`), "nada foi apagado depois da falha");
    assert.ok(await existe(`wallets/${ALVO}`));
  });

  test("a retomada continua de onde parou e conclui", async () => {
    await db.collection("playerIdentities").doc(ALVO).set({ uid: ALVO, publicId: PUBLIC_ID });
    await db.collection("users").doc(ALVO).set({ criadoEm: "2026-01-01" });
    await db.collection("wallets").doc(ALVO).set({ fichas: 77 });

    const parcial = await executar(ALVO);
    assert.equal(parcial.estado, "parcial");

    // A causa da falha e removida.
    await criarContaAuth(ALVO);

    const retomada = await executar(ALVO);
    assert.equal(retomada.estado, "concluida");
    assert.equal(await existe(`users/${ALVO}`), false);
    assert.equal(await existe(`wallets/${ALVO}`), false);

    const diario = await dados(`${C_DIARIO}/${ALVO}`);
    assert.equal(diario.estado, "concluida");
    assert.equal(diario.tentativas, 2, "as duas tentativas ficam contadas");
    assert.equal(diario.falhas.length, 1, "a falha antiga permanece no historico");
    assert.equal(diario.resumo.fichas, 77, "o saldo foi medido na retomada");
  });

  test("uma etapa ja concluida nao roda de novo na retomada", async () => {
    await semearComum();
    await semearAmizade();

    // Diario forjado: a etapa `social` consta como feita, mas as amizades ainda
    // existem. Se a retomada rodasse `social` de novo, elas sumiriam.
    await db.collection(C_DIARIO).doc(ALVO).set({
      uid: ALVO,
      publicId: PUBLIC_ID,
      estado: "parcial",
      etapasConcluidas: ["trancar", "social"],
      falhas: [],
      tentativas: 1,
      esquema: 1,
    });

    await executar(ALVO);

    const par = [ALVO, AMIGO].sort().join("|");
    assert.ok(
      await existe(`friendships/${par}`),
      "a etapa marcada como concluida foi SALTADA — e o que faz a retomada ser barata"
    );
  });

  test("um diario concluido nao volta a executar mesmo com dado no banco", async () => {
    await semearComum();
    await db.collection(C_DIARIO).doc(ALVO).set({
      uid: ALVO,
      estado: "concluida",
      etapasConcluidas: ETAPAS.map((e) => e.id),
      falhas: [],
      tentativas: 1,
      esquema: 1,
    });

    const r = await executar(ALVO);
    assert.equal(r.repeticao, true);
    assert.ok(
      await existe(`users/${ALVO}`),
      "convergir e NAO TOCAR EM NADA: o diario e a autoridade sobre o que ja foi feito"
    );
  });
});
