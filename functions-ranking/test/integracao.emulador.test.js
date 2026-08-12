/**
 * INTEGRACAO CONTRA O FIRESTORE REAL (emulador).
 *
 * ESTA SUITE EXISTE PARA FECHAR A LACUNA QUE A OS ANTERIOR DECLAROU. O
 * `RESULTADO-BACKEND-RANKING.md` registrou, sem arredondar, que "as Functions
 * chamaveis nao foram exercitadas contra o emulador, so as Rules e a logica
 * pura" — e a secao 30 desta OS pede para fechar isso se tecnicamente viavel.
 *
 * E viavel, e o que ela exercita e exatamente o que teste puro NAO alcanca:
 *
 *   transacao ....... contribuicao, ledger e classificacao entram juntos ou nao
 *                     entram;
 *   idempotencia .... a chave de contribuicao E o id do documento, entao a
 *                     segunda gravacao e recusada pelo BANCO, e nao por um `if`;
 *   concorrencia .... duas partidas do mesmo jogador ao mesmo tempo disputam o
 *                     mesmo documento de standing, e a transacao reexecuta a
 *                     perdedora — que le o saldo ja atualizado;
 *   paginacao ....... o cursor de seis criterios contra `startAfter` de verdade;
 *   backlog ......... o reprocessamento paginado, com retomada por cursor.
 *
 * NAO RODA NO `npm test`. Exige emulador, e o alvo e `npm run test:emulador`.
 *
 * O QUE ELA AINDA NAO PROVA, e continua declarado no relatorio: o emulador do
 * Firestore NAO exige indice composto — ele os cria sozinho. Entao um
 * `firestore.indexes.json` incompleto passaria aqui e falharia em producao. A
 * conferencia do indice e por leitura, no proprio arquivo, e continua sendo
 * portao de pre-deploy.
 */

const { test, describe, before, beforeEach, after } = require("node:test");
const assert = require("node:assert/strict");

const admin = require("firebase-admin");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error(
    "esta suite exige o emulador do Firestore. Use `npm run test:emulador`."
  );
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-bmv-ranking" });

const {
  processarResultadoOficial,
  apurarTemporada,
  consolidarTemporada,
  encerrarTemporada,
  reprocessarBacklog,
  paginaDaTemporada,
  abrirTemporada,
  db,
  C_STANDINGS,
  C_LEDGER,
  C_CONTRIBUTIONS,
  C_BACKLOG,
  C_MATCHES,
  C_SEASONS,
  C_PLAYERS,
} = require("../lib/firestore");
const {
  registrarPoliticaV1,
  POLITICA_COMPETITIVA_V1,
  LADDER_V1_ID,
} = require("../lib/competicao");
const { ORDEM_TEMPORADA, valorDoCriterio } = require("../lib/ordenacao");

registrarPoliticaV1();

const TEMPORADA = "2026-INT";

/// Apaga tudo entre um caso e outro. Sem isto, a idempotencia de um teste
/// esconderia o efeito do seguinte.
async function limpar() {
  const colecoes = [
    C_STANDINGS,
    C_LEDGER,
    C_CONTRIBUTIONS,
    C_BACKLOG,
    C_MATCHES,
    C_SEASONS,
    C_PLAYERS,
    "rankingTasks",
    "rankingAudit",
    // As canonicas do dominio SOCIAL. Este codebase nunca as escreve em
    // producao; aqui elas sao FIXTURE — o teste representa o estado que o
    // provisionamento oficial ja produziu. Ver `provisionarIdentidades`.
    "playerIdentities",
    "publicIdIndex",
    "publicProfiles",
  ];
  for (const c of colecoes) {
    const snap = await db().collection(c).get();
    const lote = db().batch();
    snap.docs.forEach((d) => lote.delete(d.ref));
    await lote.commit();
  }
}

/// O id publico de fixture de um jogador.
///
/// Ids DETERMINISTICOS por uid, e nao sorteados: o teste precisa poder afirmar
/// "a linha saiu com O id deste jogador", e um id aleatorio so permitiria
/// afirmar "saiu com algum id". O formato e o mesmo do canonico (prefixo "P",
/// 12 simbolos do alfabeto sem I/L/O/U) porque `idPublicoValido` o confere.
const idPublicoDe = (uid) => `P${uid.toUpperCase().replace(/[^0-9A-HJKMNP-TV-Z]/g, "0")}`
  .padEnd(13, "0")
  .slice(0, 13);

/// Escreve os tres documentos canonicos, como `garantirIdentidade` os escreve.
///
/// FIXTURE, E NAO IMPLEMENTACAO PARALELA. A diferenca importa: nenhum codigo de
/// producao deste codebase escreve aqui, e `test/identidade.test.js` prova isso
/// varrendo `src/`. Este arquivo esta em `test/`, e o que ele representa e "o
/// dominio social ja rodou" — sem obrigar esta suite a compilar o bundle Dart do
/// vizinho so para abrir uma temporada.
///
/// A prova de que o mecanismo OFICIAL produz este mesmo estado esta em
/// functions-social/test/integracao.identidade.emulador.test.js, que usa
/// `garantirIdentidade` de verdade.
async function provisionarIdentidades(uids) {
  const lote = db().batch();
  for (const uid of uids) {
    const publicId = idPublicoDe(uid);
    lote.set(db().collection("playerIdentities").doc(uid), {
      uid,
      publicId,
      criadoEm: "2026-08-01T00:00:00.000Z",
      esquema: 1,
    });
    lote.set(db().collection("publicIdIndex").doc(publicId), {
      publicId,
      uid,
      criadoEm: "2026-08-01T00:00:00.000Z",
      esquema: 1,
    });
    lote.set(db().collection("publicProfiles").doc(publicId), {
      publicId,
      apelido: `apelido-${uid}`,
      apelidoOrdenacao: `apelido-${uid}`,
      avatarRef: `assets/avatares/${uid}.webp`,
      desde: "2026-08-01T00:00:00.000Z",
      esquema: 1,
    });
  }
  await lote.commit();
}

const OS_QUATRO = ["u1", "u2", "u3", "u4"];

/// Uma partida ranqueada valida: dupla A (u1,u3) contra dupla B (u2,u4).
const partidaRanqueada = (matchId, vencedor, over = {}) => ({
  matchId,
  estado: "finalizada",
  tipo: "publica_ranqueada",
  alteraRanking: true,
  motivoEncerramento: "objetivo_atingido",
  ladoVencedor: vencedor,
  encerradaEm: "2026-08-11T20:00:00.000Z",
  participantes: [
    { classe: "humano", userId: "u1", assento: 0, lado: "A" },
    { classe: "humano", userId: "u2", assento: 1, lado: "B" },
    { classe: "humano", userId: "u3", assento: 2, lado: "A" },
    { classe: "humano", userId: "u4", assento: 3, lado: "B" },
  ],
  placar: [
    { lado: "A", pontos: 3000, canastrasLimpas: 2 },
    { lado: "B", pontos: 1500, canastrasLimpas: 0 },
  ],
  ...over,
});

const gravarPartida = (doc) => db().collection(C_MATCHES).doc(doc.matchId).set(doc);

const abrirTemporadaV1 = () =>
  abrirTemporada({
    seasonId: TEMPORADA,
    nome: "Integracao",
    inicioEm: "2026-08-01T00:00:00.000Z",
    fimEm: "2026-09-26T00:00:00.000Z",
    politica: POLITICA_COMPETITIVA_V1,
    ladderId: LADDER_V1_ID,
    autor: "teste",
  });

const standingDe = async (uid) =>
  (await db().collection(C_STANDINGS).doc(`${TEMPORADA}|${uid}`).get()).data();

before(limpar);
after(limpar);

describe("integracao: uma partida vira pontuacao", () => {
  beforeEach(async () => {
    await limpar();
    // O DOMINIO SOCIAL JA PROVISIONOU. Sem isto, `decidirIdentidadePublica`
    // manda toda partida para o backlog — que e o comportamento correto e tem
    // teste proprio, mais abaixo.
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();
  });

  test("os quatro jogadores saem de 1000, em colocacao", async () => {
    await gravarPartida(partidaRanqueada("m1", "A"));
    const r = await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    assert.equal(r.processada, true, r.detalhe ?? "");
    // Duplas iguais (1000 e 1000 dos dois lados), K=40 em colocacao: +-20.
    assert.deepEqual(r.deltas, { u1: 20, u2: -20, u3: 20, u4: -20 });

    const s1 = await standingDe("u1");
    assert.equal(s1.pontos, 1020);
    assert.equal(s1.ratingInicial, 1000, "a semente ficou registrada");
    assert.equal(s1.estadoCompetitivo, "em_colocacao");
    assert.equal(s1.partidasDeQualificacao, 1);
    assert.equal(s1.qualificacaoExigida, 10);
    assert.equal(s1.vitorias, 1);
    assert.equal(s1.derrotas, 0);
    assert.equal(s1.saldoPontos, 1500);
    assert.equal(s1.ligaId, null, "sem Liga durante a colocacao");
  });

  test("o ledger fecha: antes + delta == depois, partindo de 1000", async () => {
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    const l = (await db().collection(C_LEDGER).doc("m1|u1|resultado_de_partida").get()).data();
    assert.equal(l.rankingBefore, 1000, "o lancamento NAO parte de zero");
    assert.equal(l.rankingDelta, 20);
    assert.equal(l.rankingAfter, 1020);
    assert.equal(l.seasonId, TEMPORADA);
    assert.deepEqual(l.politica, { id: "competitiva", versao: 1 }, "secao 25");
  });

  test("a contribuicao registra politica e natureza (secoes 4 e 25)", async () => {
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    const chave = `m1|${TEMPORADA}|competitiva|v1`;
    const c = (await db().collection(C_CONTRIBUTIONS).doc(chave).get()).data();
    assert.equal(c.matchId, "m1");
    assert.deepEqual(c.politica, { id: "competitiva", versao: 1 });
    assert.equal(c.tipo, "publica_ranqueada");
    assert.deepEqual(c.jogadores, ["u1", "u2", "u3", "u4"]);
  });
});

describe("integracao: idempotencia no BANCO (secao 29)", () => {
  beforeEach(async () => {
    await limpar();
    // O DOMINIO SOCIAL JA PROVISIONOU. Sem isto, `decidirIdentidadePublica`
    // manda toda partida para o backlog — que e o comportamento correto e tem
    // teste proprio, mais abaixo.
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();
    await gravarPartida(partidaRanqueada("m1", "A"));
  });

  test("processar duas vezes nao dobra nada", async () => {
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    const depoisDaPrimeira = await standingDe("u1");

    const segunda = await processarResultadoOficial({
      matchId: "m1",
      origem: "administrativo",
      autor: "admin",
    });
    assert.equal(segunda.processada, false);
    assert.equal(segunda.recusa, "ja_processado");

    const depoisDaSegunda = await standingDe("u1");
    assert.equal(depoisDaSegunda.pontos, depoisDaPrimeira.pontos, "o rating dobrou");
    assert.equal(depoisDaSegunda.partidasComputadas, 1, "a contagem de partidas dobrou");
    assert.equal(depoisDaSegunda.vitorias, 1, "as vitorias dobraram");
    assert.equal(
      depoisDaSegunda.partidasDeQualificacao,
      1,
      "consumiu duas partidas de colocacao"
    );

    const ledger = await db().collection(C_LEDGER).where("matchId", "==", "m1").get();
    assert.equal(ledger.size, 4, "o ledger ganhou lancamento duplicado");
  });

  test("DEZ execucoes simultaneas da mesma partida aplicam UMA vez", async () => {
    // O caso que a entrega "ao menos uma vez" do Cloud Functions produz de
    // verdade, e que a leitura previa sozinha nao resolve: dez execucoes passam
    // pela primeira checagem juntas. Quem barra e o `tx.create` sobre um id que
    // ja existe.
    const todas = await Promise.all(
      Array.from({ length: 10 }, () =>
        processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null }).catch(
          (e) => ({ processada: false, recusa: `erro:${e.code ?? e.message}` })
        )
      )
    );
    const aplicadas = todas.filter((r) => r.processada).length;
    assert.equal(aplicadas, 1, `${aplicadas} execucoes aplicaram`);

    const s = await standingDe("u1");
    assert.equal(s.pontos, 1020);
    assert.equal(s.partidasComputadas, 1);
  });
});

describe("integracao: concorrencia (secao 30)", () => {
  beforeEach(async () => {
    await limpar();
    // O DOMINIO SOCIAL JA PROVISIONOU. Sem isto, `decidirIdentidadePublica`
    // manda toda partida para o backlog — que e o comportamento correto e tem
    // teste proprio, mais abaixo.
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();
  });

  test("partidas simultaneas do mesmo jogador nao perdem rating", async () => {
    // O LOST UPDATE CLASSICO: N transacoes leem o mesmo saldo e escrevem
    // saldo+delta, e N-1 somem. Aqui as N disputam o MESMO documento de
    // standing; o Firestore detecta o conflito e reexecuta a perdedora, que
    // entao le o saldo ja atualizado e aplica o proprio delta em cima dele.
    const quantas = 8;
    for (let i = 0; i < quantas; i++) {
      await gravarPartida(partidaRanqueada(`c${i}`, "A"));
    }

    await Promise.all(
      Array.from({ length: quantas }, (_, i) =>
        processarResultadoOficial({ matchId: `c${i}`, origem: "gatilho", autor: null })
      )
    );

    const s = await standingDe("u1");
    assert.equal(s.partidasComputadas, quantas, "alguma partida se perdeu");
    assert.equal(s.vitorias, quantas);
    // 8 vitorias: as duas primeiras com K=40 entre iguais... o valor exato
    // depende da sequencia, entao o que se afirma e a INVARIANTE: a cadeia do
    // ledger fecha, e o rating final e explicavel por ela.
    const ledger = await db()
      .collection(C_LEDGER)
      .where("matchId", "in", Array.from({ length: quantas }, (_, i) => `c${i}`))
      .get();
    const meus = ledger.docs.map((d) => d.data()).filter((l) => l.userId === "u1");
    assert.equal(meus.length, quantas);

    // Ordenados pela cadeia: cada lancamento parte de onde o anterior parou.
    meus.sort((a, b) => a.rankingBefore - b.rankingBefore);
    let esperado = 1000;
    for (const l of meus) {
      assert.equal(l.rankingBefore, esperado, "a cadeia do ledger nao fecha");
      assert.equal(l.rankingAfter, l.rankingBefore + l.rankingDelta);
      esperado = l.rankingAfter;
    }
    assert.equal(s.pontos, esperado, "o standing nao bate com a cadeia");
  });
});

describe("integracao: elegibilidade contra o banco (secoes 3, 6 e 26)", () => {
  beforeEach(async () => {
    await limpar();
    // O DOMINIO SOCIAL JA PROVISIONOU. Sem isto, `decidirIdentidadePublica`
    // manda toda partida para o backlog — que e o comportamento correto e tem
    // teste proprio, mais abaixo.
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();
  });

  test("Mesa Publica casual nao cria standing nenhum", async () => {
    await gravarPartida(
      partidaRanqueada("casual", "A", { tipo: "publica_casual", alteraRanking: false })
    );
    const r = await processarResultadoOficial({
      matchId: "casual",
      origem: "gatilho",
      autor: null,
    });
    assert.equal(r.processada, false);
    assert.equal(r.recusa, "nao_pontua");
    assert.equal(await standingDe("u1"), undefined, "a casual criou linha de ranking");
    assert.equal((await db().collection(C_LEDGER).get()).size, 0);
  });

  test("torneio nao cria standing nenhum", async () => {
    await gravarPartida(partidaRanqueada("t1", "A", { tipo: "torneio", alteraRanking: true }));
    const r = await processarResultadoOficial({ matchId: "t1", origem: "gatilho", autor: null });
    assert.equal(r.processada, false);
    assert.equal(r.recusa, "fora_do_ambiente_competitivo");
    assert.equal(await standingDe("u1"), undefined, "o torneio alimentou o Elo");
  });

  test("a natureza alterada e detectada no reprocessamento (secao 4)", async () => {
    // A partida entra no backlog como CASUAL... nao entra: casual e recusada em
    // definitivo. Entao o caminho real e outro: uma ranqueada fica pendente por
    // falta de temporada, e depois alguem troca o `tipo` dela.
    await db().collection(C_SEASONS).doc(TEMPORADA).delete();
    await gravarPartida(partidaRanqueada("m9", "A"));
    const primeira = await processarResultadoOficial({
      matchId: "m9",
      origem: "gatilho",
      autor: null,
    });
    assert.equal(primeira.recusa, "sem_temporada_vigente");
    const guardado = (await db().collection(C_BACKLOG).doc("m9").get()).data();
    assert.equal(guardado.situacao, "pendente");
    assert.equal(guardado.tipo, "publica_ranqueada", "a natureza observada foi registrada");

    // Agora alguem "promove" a partida trocando o tipo, e abre a temporada.
    await abrirTemporadaV1();
    await gravarPartida(partidaRanqueada("m9", "A", { tipo: "torneio" }));
    const segunda = await processarResultadoOficial({
      matchId: "m9",
      origem: "reprocessamento",
      autor: "admin",
    });
    // Duas guardas a recusam, e qualquer uma basta. A de ambiente vem primeiro.
    assert.equal(segunda.processada, false);
    assert.equal(await standingDe("u1"), undefined);
  });
});

describe("integracao: identidade publica (OS de integracao, secoes 8, 9 e 23)", () => {
  beforeEach(async () => {
    await limpar();
    await abrirTemporadaV1();
  });

  test("CASO A — identidade antes da primeira ranqueada: o ranking usa o MESMO id", async () => {
    await provisionarIdentidades(OS_QUATRO);
    await gravarPartida(partidaRanqueada("m1", "A"));
    const r = await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    assert.equal(r.processada, true, r.detalhe ?? "");

    for (const uid of OS_QUATRO) {
      const canonico = (
        await db().collection("playerIdentities").doc(uid).get()
      ).data().publicId;
      assert.equal(
        (await standingDe(uid)).publicPlayerId,
        canonico,
        `a linha de ${uid} nao usou o id canonico`
      );
      assert.equal(
        (await db().collection(C_PLAYERS).doc(uid).get()).data().publicPlayerId,
        canonico
      );
    }
  });

  test("CASO A — o ranking projeta apelido e avatar do PERFIL PUBLICO", async () => {
    // §10: o ranking pode MOSTRAR apelido e avatar, e a autoridade continua sendo
    // a identidade publica. Ate esta OS estes campos nasciam vazios porque nao
    // havia fonte; agora ha, e a linha copia dela.
    await provisionarIdentidades(OS_QUATRO);
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    const s1 = await standingDe("u1");
    assert.equal(s1.apelido, "apelido-u1");
    assert.equal(s1.avatar, "assets/avatares/u1.webp");
  });

  test("CASO B — sem identidade: NAO cunha, NAO pontua, vai para o backlog", async () => {
    // O CASO CENTRAL DA OS. Antes dela, esta partida teria criado quatro
    // identidades novas dentro do codebase competitivo.
    await gravarPartida(partidaRanqueada("m1", "A"));
    const r = await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    assert.equal(r.processada, false);
    assert.equal(r.recusa, "identidade_publica_ausente");

    // Nada de identidade foi criado em lugar nenhum.
    assert.equal((await db().collection("playerIdentities").get()).size, 0);
    assert.equal((await db().collection("publicIdIndex").get()).size, 0);
    assert.equal((await db().collection("publicProfiles").get()).size, 0);
    // E nenhuma colecao propria de ids ressuscitou.
    assert.equal((await db().collection("rankingPublicIds").get()).size, 0);

    // Nada de competitivo foi gravado: nem linha, nem ledger, nem contribuicao.
    assert.equal(await standingDe("u1"), undefined);
    assert.equal((await db().collection(C_LEDGER).get()).size, 0);
    assert.equal((await db().collection(C_CONTRIBUTIONS).get()).size, 0);

    // O que existe e um item de trabalho, pendente e retomavel.
    const guardado = (await db().collection(C_BACKLOG).doc("m1").get()).data();
    assert.equal(guardado.situacao, "pendente");
    assert.equal(guardado.motivo, "identidade_publica_ausente");
  });

  test("CASO B — provisionada a identidade, o backlog retoma e pontua UMA vez", async () => {
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    assert.equal((await db().collection(C_BACKLOG).doc("m1").get()).data().situacao, "pendente");

    // O dominio social provisiona. O ranking nao participou disso.
    await provisionarIdentidades(OS_QUATRO);

    const r = await reprocessarBacklog({ limite: 10, autor: "admin" });
    assert.equal(r.processados, 1, JSON.stringify(r));

    const canonico = (await db().collection("playerIdentities").doc("u1").get()).data().publicId;
    const s1 = await standingDe("u1");
    assert.equal(s1.publicPlayerId, canonico);
    assert.equal(s1.pontos, 1020, "a partida retomada pontuou uma vez");
    assert.equal((await db().collection(C_CONTRIBUTIONS).get()).size, 1);
  });

  test("CASO D — reprocessar depois da retomada nao duplica contribuicao", async () => {
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    await provisionarIdentidades(OS_QUATRO);
    await reprocessarBacklog({ limite: 10, autor: "admin" });

    const depoisDaPrimeira = await standingDe("u1");
    const segunda = await processarResultadoOficial({
      matchId: "m1",
      origem: "administrativo",
      autor: "admin",
    });
    assert.equal(segunda.processada, false);
    assert.equal(segunda.recusa, "ja_processado");
    assert.deepEqual(await standingDe("u1"), depoisDaPrimeira);
    assert.equal((await db().collection(C_CONTRIBUTIONS).get()).size, 1);
  });

  test("um SO competidor sem identidade ja segura a partida inteira", async () => {
    // Nao ha meio-termo: pontuar tres e deixar um de fora produziria um Elo que
    // nao fecha, porque a expectativa de cada lado depende dos dois ratings.
    await provisionarIdentidades(["u1", "u2", "u3"]);
    await gravarPartida(partidaRanqueada("m1", "A"));
    const r = await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    assert.equal(r.recusa, "identidade_publica_ausente");
    assert.match(r.detalhe, /u4/);
    assert.equal(await standingDe("u1"), undefined, "u1 pontuou sozinho");
  });

  test("o uid NUNCA aparece como identidade publica numa linha", async () => {
    // §8, item por item: nem uid, nem "unknown", nem string vazia, nem id
    // temporario. A afirmacao vale para a linha GRAVADA, e nao so para a
    // projetada — quem le o banco direto tambem nao ve o uid no lugar do id.
    await provisionarIdentidades(OS_QUATRO);
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });

    for (const uid of OS_QUATRO) {
      const s = await standingDe(uid);
      assert.notEqual(s.publicPlayerId, uid);
      assert.notEqual(s.publicPlayerId, "unknown");
      assert.notEqual(s.publicPlayerId, "");
      assert.match(s.publicPlayerId, /^P[0-9A-HJKMNP-TV-Z]{12}$/);
    }
  });

  test("mudar apelido e avatar NAO troca o publicId nem o rating", async () => {
    // §10 e §17 na mesma afirmacao: apresentacao muda, identidade e carreira
    // competitiva nao.
    await provisionarIdentidades(OS_QUATRO);
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    const antes = await standingDe("u1");

    const canonico = antes.publicPlayerId;
    await db().collection("publicProfiles").doc(canonico).update({
      apelido: "Dona Sonia",
      avatarRef: "assets/avatares/novo.webp",
    });

    await gravarPartida(partidaRanqueada("m2", "A"));
    await processarResultadoOficial({ matchId: "m2", origem: "gatilho", autor: null });
    const depois = await standingDe("u1");

    assert.equal(depois.publicPlayerId, canonico, "o publicId mudou com o apelido");
    assert.equal(
      (await db().collection("playerIdentities").doc("u1").get()).data().publicId,
      canonico
    );
    assert.equal(depois.apelido, "Dona Sonia", "a projecao nao acompanhou o perfil");
    assert.equal(depois.avatar, "assets/avatares/novo.webp");

    // O rating avancou pela SEGUNDA PARTIDA, e nao pelo apelido. Nao se afirma o
    // numero exato de proposito: depois da primeira partida os quatro ratings
    // deixaram de ser iguais, e o delta do Elo passou a depender deles. Afirmar
    // "+20" aqui seria reafirmar a formula — que tem suite propria — e amarrar
    // este teste de identidade a ela.
    assert.equal(depois.partidasComputadas, antes.partidasComputadas + 1);
    assert.equal(depois.pontos > antes.pontos, true, "a vitoria nao pontuou");
    assert.equal(depois.vitorias, antes.vitorias + 1);
  });

  test("subir de Liga NAO troca o publicId", async () => {
    await provisionarIdentidades(OS_QUATRO);
    await gravarPartida(partidaRanqueada("m1", "A"));
    await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    const canonico = (await standingDe("u1")).publicPlayerId;

    // Dez partidas: u1 consolida, ganha Liga e continua com o mesmo id.
    for (let i = 0; i < 10; i++) {
      await gravarPartida(partidaRanqueada(`liga${i}`, "A"));
      await processarResultadoOficial({ matchId: `liga${i}`, origem: "gatilho", autor: null });
    }
    const s = await standingDe("u1");
    assert.equal(s.estadoCompetitivo, "classificado");
    assert.notEqual(s.ligaId, null, "o cenario nao chegou a atribuir Liga");
    assert.equal(s.publicPlayerId, canonico, "a Liga trocou o id publico");
  });

  test("perfil publico AUSENTE nao vira uid no apelido", async () => {
    // §31-F do contrato social, provado do lado competitivo: sem perfil, o campo
    // fica vazio. Nunca cai para o uid, que seria o vazamento exato que o
    // publicId existe para impedir.
    const lote = db().batch();
    for (const uid of OS_QUATRO) {
      const publicId = idPublicoDe(uid);
      lote.set(db().collection("playerIdentities").doc(uid), { uid, publicId });
      lote.set(db().collection("publicIdIndex").doc(publicId), { publicId, uid });
      // publicProfiles de proposito AUSENTE.
    }
    await lote.commit();

    await gravarPartida(partidaRanqueada("m1", "A"));
    const r = await processarResultadoOficial({ matchId: "m1", origem: "gatilho", autor: null });
    assert.equal(r.processada, true, "identidade existe; a falta e so de perfil");

    const s = await standingDe("u1");
    assert.equal(s.apelido, "");
    assert.equal(s.avatar, "");
    assert.equal(s.publicPlayerId, idPublicoDe("u1"));
  });
});

describe("integracao: backlog (secao 26)", () => {
  beforeEach(async () => {
    await limpar();
    await provisionarIdentidades(OS_QUATRO);
  });

  test("o que ficou pendente e reprocessado, em ordem, e vira pontuacao", async () => {
    // Sem temporada, tres partidas encerram e vao para o backlog.
    for (let i = 0; i < 3; i++) {
      await gravarPartida(partidaRanqueada(`b${i}`, "A"));
      const r = await processarResultadoOficial({
        matchId: `b${i}`,
        origem: "gatilho",
        autor: null,
      });
      assert.equal(r.recusa, "sem_temporada_vigente");
    }
    const pendentes = await db()
      .collection(C_BACKLOG)
      .where("situacao", "==", "pendente")
      .get();
    assert.equal(pendentes.size, 3);

    // A politica chega e a temporada abre.
    await abrirTemporadaV1();
    const relatorio = await reprocessarBacklog({ autor: "admin", limite: 30 });

    assert.equal(relatorio.processados, 3, JSON.stringify(relatorio.porRecusa));
    assert.equal(relatorio.aindaPendentes, 0);
    assert.equal(relatorio.fim, true);

    const s = await standingDe("u1");
    assert.equal(s.partidasComputadas, 3);
    assert.equal(s.vitorias, 3);
  });

  test("reprocessar de novo e idempotente — nada muda na segunda passada", async () => {
    await abrirTemporadaV1();
    await db().collection(C_SEASONS).doc(TEMPORADA).delete();
    await gravarPartida(partidaRanqueada("b0", "A"));
    await processarResultadoOficial({ matchId: "b0", origem: "gatilho", autor: null });
    await abrirTemporadaV1();

    await reprocessarBacklog({ autor: "admin" });
    const depoisDaPrimeira = await standingDe("u1");

    const segunda = await reprocessarBacklog({ autor: "admin" });
    assert.equal(segunda.examinados, 0, "um item processado voltou a fila");
    const depoisDaSegunda = await standingDe("u1");
    assert.deepEqual(depoisDaSegunda, depoisDaPrimeira);
  });

  test("a fila e retomavel por cursor", async () => {
    for (let i = 0; i < 5; i++) {
      await gravarPartida(
        partidaRanqueada(`p${i}`, "A", { encerradaEm: `2026-08-1${i}T20:00:00.000Z` })
      );
      await processarResultadoOficial({ matchId: `p${i}`, origem: "gatilho", autor: null });
    }
    await abrirTemporadaV1();

    const primeiro = await reprocessarBacklog({ autor: "admin", limite: 2 });
    assert.equal(primeiro.examinados, 2);
    assert.equal(primeiro.fim, false);
    assert.notEqual(primeiro.cursor, null);

    const segundo = await reprocessarBacklog({
      autor: "admin",
      limite: 2,
      cursor: primeiro.cursor,
    });
    assert.equal(segundo.examinados, 2);

    const terceiro = await reprocessarBacklog({
      autor: "admin",
      limite: 2,
      cursor: segundo.cursor,
    });
    assert.equal(terceiro.examinados, 1);
    assert.equal(terceiro.fim, true);

    const s = await standingDe("u1");
    assert.equal(s.partidasComputadas, 5, "a retomada pulou ou repetiu alguma partida");
  });
});

describe("integracao: paginacao com os seis criterios (secoes 17 e 31)", () => {
  before(async () => {
    await limpar();
    // O DOMINIO SOCIAL JA PROVISIONOU. Sem isto, `decidirIdentidadePublica`
    // manda toda partida para o backlog — que e o comportamento correto e tem
    // teste proprio, mais abaixo.
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();
    // 12 jogadores, com empates deliberados em rating para forcar o desempate a
    // decidir de verdade.
    const lote = db().batch();
    for (let i = 0; i < 12; i++) {
      lote.set(db().collection(C_STANDINGS).doc(`${TEMPORADA}|x${i}`), {
        seasonId: TEMPORADA,
        uid: `x${i}`,
        publicPlayerId: `P${String(i).padStart(4, "0")}`,
        apelido: "",
        avatar: "",
        pontos: 1000 + (i % 3) * 10,
        vitorias: i % 2,
        saldoPontos: 100 * (i % 4),
        abandonos: 0,
        ratingAtingidoEm: `2026-08-${String(i + 1).padStart(2, "0")}T00:00:00.000Z`,
        partidasComputadas: 10,
        estadoCompetitivo: "classificado",
        partidasDeQualificacao: 10,
        qualificacaoExigida: 10,
        derrotas: 0,
        empates: 0,
        posicao: null,
        direcao: "estavel",
        deltaPosicao: 0,
        ligaId: "prata",
        ligaNome: "Prata",
        selo: null,
        atualizadoEm: "2026-08-11T00:00:00.000Z",
      });
    }
    await lote.commit();
  });

  test("paginar a temporada inteira nao repete nem pula ninguem", async () => {
    const vistos = [];
    let depoisDe = null;
    for (let volta = 0; volta < 20; volta++) {
      const pagina = await paginaDaTemporada({ seasonId: TEMPORADA, limite: 5, depoisDe });
      const itens = pagina.slice(0, 5);
      vistos.push(...itens.map((l) => l.publicPlayerId));
      if (pagina.length <= 5) break;
      const ultimo = itens[itens.length - 1];
      depoisDe = ORDEM_TEMPORADA.map((c) => valorDoCriterio(ultimo, c));
    }

    assert.equal(vistos.length, 12, "pulou ou repetiu alguem");
    assert.equal(new Set(vistos).size, 12, "houve repeticao");
  });

  test("a apuracao atribui posicao densa e unica na ordem oficial", async () => {
    const r = await apurarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    assert.equal(r.jogadores, 12);

    const todos = await paginaDaTemporada({ seasonId: TEMPORADA, limite: 100, depoisDe: null });
    assert.deepEqual(
      todos.map((l) => l.posicao),
      Array.from({ length: 12 }, (_, i) => i + 1)
    );
  });
});

describe("integracao: encerramento, consolidacao e a temporada seguinte", () => {
  test("o classificado carrega o rating final; a temporada anterior nao se move", async () => {
    await limpar();
    // O DOMINIO SOCIAL JA PROVISIONOU. Sem isto, `decidirIdentidadePublica`
    // manda toda partida para o backlog — que e o comportamento correto e tem
    // teste proprio, mais abaixo.
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();

    // u1 consolida: 10 partidas ranqueadas validas.
    for (let i = 0; i < 10; i++) {
      await gravarPartida(partidaRanqueada(`q${i}`, "A"));
      await processarResultadoOficial({ matchId: `q${i}`, origem: "gatilho", autor: null });
    }
    const antesDoFecho = await standingDe("u1");
    assert.equal(antesDoFecho.estadoCompetitivo, "classificado");
    assert.notEqual(antesDoFecho.ligaId, null, "consolidou sem receber Liga");

    await apurarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    await encerrarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    const consolidacao = await consolidarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    assert.equal(consolidacao.classificados, 4, "os quatro consolidaram");

    // O RETRATO DO CONGELAMENTO E TIRADO AQUI, e nao antes da apuracao final: a
    // apuracao que roda no fecho e justamente a que atribui a posicao
    // definitiva, entao a linha muda uma ultima vez, de proposito. O que a secao
    // 19 congela e o estado APOS o encerramento.
    const congeladaNoFecho = await standingDe("u1");
    assert.equal(congeladaNoFecho.pontos, antesDoFecho.pontos, "o fecho mexeu no rating");

    // A POSICAO EXATA DE u1 NAO E DETERMINADA, e afirmar que ela e 1 seria um
    // teste errado: u1 e u3 jogaram as mesmas 10 partidas do mesmo lado, entao
    // empatam nos CINCO criterios competitivos da secao 17 e sao separados pelo
    // `publicPlayerId`, que e aleatorio. O que esta determinado — e e o que
    // importa — e que a apuracao atribuiu posicao e que os vencedores ficaram
    // acima dos perdedores.
    assert.ok(
      congeladaNoFecho.posicao === 1 || congeladaNoFecho.posicao === 2,
      `vencedor ficou em ${congeladaNoFecho.posicao}`
    );
    const posicoes = {};
    for (const uid of ["u1", "u2", "u3", "u4"]) {
      posicoes[uid] = (await standingDe(uid)).posicao;
    }
    assert.deepEqual(
      Object.values(posicoes).sort(),
      [1, 2, 3, 4],
      "a posicao nao ficou densa e unica"
    );
    assert.ok(
      Math.max(posicoes.u1, posicoes.u3) < Math.min(posicoes.u2, posicoes.u4),
      "quem venceu as 10 nao ficou acima de quem perdeu as 10"
    );

    const jogador = (await db().collection(C_PLAYERS).doc("u1").get()).data();
    assert.equal(jogador.ultimaTemporadaConsolidada, TEMPORADA);
    assert.equal(jogador.ratingFinalConsolidado, antesDoFecho.pontos);

    // A temporada seguinte: u1 entra com soft reset, em revalidacao.
    const seguinte = "2026-INT-B";
    await abrirTemporada({
      seasonId: seguinte,
      nome: "Seguinte",
      inicioEm: "2026-09-27T00:00:00.000Z",
      fimEm: "2026-11-22T00:00:00.000Z",
      politica: POLITICA_COMPETITIVA_V1,
      ladderId: LADDER_V1_ID,
      autor: "admin",
    });
    await gravarPartida(partidaRanqueada("n1", "A"));
    await processarResultadoOficial({ matchId: "n1", origem: "gatilho", autor: null });

    const nova = (
      await db().collection(C_STANDINGS).doc(`${seguinte}|u1`).get()
    ).data();
    const esperado = 1000 + Math.round(0.6 * (antesDoFecho.pontos - 1000));
    assert.equal(nova.ratingInicial, esperado, "o soft reset nao foi aplicado");
    assert.equal(nova.estadoCompetitivo, "em_revalidacao");
    assert.equal(nova.qualificacaoExigida, 5);

    // SECAO 19: uma partida da temporada NOVA nao move um byte da anterior. A
    // garantia e a chave do documento — `{seasonId}|{uid}` —, e este e o teste
    // que a exercita contra o banco de verdade.
    assert.deepEqual(
      await standingDe("u1"),
      congeladaNoFecho,
      "a temporada encerrada foi alterada pela seguinte"
    );
  });

  test("a consolidacao e idempotente", async () => {
    const r = await consolidarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    assert.equal(r.jaConsolidada, true);
  });

  test("temporada nova e soft reset NAO trocam o publicId (§22.14 e §22.15)", async () => {
    // §17 na sua forma mais concreta: o que atravessa a virada de temporada e a
    // IDENTIDADE, e o que e recalculado e o RATING. Um jogador que mudasse de id
    // ao virar a temporada teria, na pratica, uma carreira nova por ano — e o
    // link de perfil dele quebraria todo mes de setembro.
    await limpar();
    await provisionarIdentidades(OS_QUATRO);
    await abrirTemporadaV1();

    await gravarPartida(partidaRanqueada("r1", "A"));
    await processarResultadoOficial({ matchId: "r1", origem: "gatilho", autor: null });
    const idNaPrimeira = (await standingDe("u1")).publicPlayerId;
    const canonico = (
      await db().collection("playerIdentities").doc("u1").get()
    ).data().publicId;
    assert.equal(idNaPrimeira, canonico);

    // Dez partidas para consolidar, e a temporada fecha.
    for (let i = 0; i < 10; i++) {
      await gravarPartida(partidaRanqueada(`s${i}`, "A"));
      await processarResultadoOficial({ matchId: `s${i}`, origem: "gatilho", autor: null });
    }
    await apurarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    await encerrarTemporada({ seasonId: TEMPORADA, autor: "admin" });
    await consolidarTemporada({ seasonId: TEMPORADA, autor: "admin" });

    const seguinte = `${TEMPORADA}-B`;
    await abrirTemporada({
      seasonId: seguinte,
      nome: "Seguinte",
      inicioEm: "2026-09-27T00:00:00.000Z",
      fimEm: "2026-11-22T00:00:00.000Z",
      politica: POLITICA_COMPETITIVA_V1,
      ladderId: LADDER_V1_ID,
      autor: "admin",
    });
    await gravarPartida(partidaRanqueada("n1", "A"));
    await processarResultadoOficial({ matchId: "n1", origem: "gatilho", autor: null });

    const nova = (await db().collection(C_STANDINGS).doc(`${seguinte}|u1`).get()).data();

    // O soft reset ACONTECEU — o cenario e valido, e nao um falso positivo em
    // que nada mudou.
    assert.equal(nova.estadoCompetitivo, "em_revalidacao");
    assert.equal(nova.qualificacaoExigida, 5);
    assert.notEqual(nova.ratingInicial, 1000, "o soft reset nao foi aplicado");

    // E o id atravessou os tres eventos sem se mover.
    assert.equal(nova.publicPlayerId, canonico, "a temporada nova trocou o id publico");
    assert.equal(
      (await db().collection("playerIdentities").doc("u1").get()).data().publicId,
      canonico,
      "a identidade canonica foi reescrita pela virada de temporada"
    );
    assert.equal(
      (await db().collection(C_PLAYERS).doc("u1").get()).data().publicPlayerId,
      canonico
    );
    // E nenhuma identidade nova nasceu no caminho.
    assert.equal((await db().collection("playerIdentities").get()).size, 4);
    assert.equal((await db().collection("publicIdIndex").get()).size, 4);
  });
});
