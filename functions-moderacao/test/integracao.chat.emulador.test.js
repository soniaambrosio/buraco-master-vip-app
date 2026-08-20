/**
 * integracao.chat.emulador.test.js — o CHAT LIVRE contra o Emulator Suite.
 *
 * POR QUE ESTE ARQUIVO EXISTE, e o que so ele prova.
 *
 * A OS do Chat Livre Seguro pede, em §15, coisas que NENHUMA das outras duas
 * suites alcanca:
 *
 *   `app/test/chat/chat_test.dart` prova a DECISAO (conteudo, superficie, assento,
 *   filtro de bloqueio por par, projecao) — mas com bloqueio e sancao de FIXTURE.
 *
 *   `firebase/testes/chat.test.js` prova a AUTORIZACAO (ninguem grava mensagem,
 *   ninguem le o documento) — mas nao chama Function nenhuma.
 *
 *   ESTE prova que a decisao CHEGA AO BANCO: autenticado envia, anonimo nao,
 *   retry nao duplica sob transacao, duas chamadas simultaneas nao duplicam,
 *   bloqueio lido do Firestore recusa nas DUAS direcoes, sancao lida de
 *   `playerModeration` cala, e a denuncia recupera a evidencia server-side.
 *
 * Uso:
 *   cd functions-moderacao && npm run build:domain && npm run build
 *   npm run test:emulador
 *
 * Numa maquina sem Java no PATH mas com Android Studio instalado:
 *   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run test:emulador
 *
 * O RUNNER CONFERE QUE O EMULADOR DE FUNCTIONS ESTA ATENDENDO e FALHA se nao
 * estiver — a mesma disciplina de `firebase/testes/com-functions.js`.
 * `emulators:exec` nao exporta `FUNCTIONS_EMULATOR_HOST`, entao sem esta
 * conferencia a suite ficaria permanentemente pulada com o portao VERDE.
 */

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const { test, before, describe } = require("node:test");

const path = require("node:path");

/// O contrato compartilhado com o servidor. Os nomes das Functions saem DAQUI, e
/// não de literal solto: `test/contrato.test.js` afirma o digest deste arquivo,
/// então um nome que divirja do servidor reprova antes de chegar aqui.
const CONTRATO = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, "..", "..", "contrato", "chat-transporte-v1.json"),
    "utf8"
  )
);

const PROJETO = process.env.GCLOUD_PROJECT || "demo-bmv";
const REGIAO = "southamerica-east1";

const HOST_FUNCTIONS =
  process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const HOST_FIRESTORE =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

const AUTOR = "uidAutorChat";
const COLEGA = "uidColegaChat";
const TERCEIRO = "uidTerceiroChat";
const PLATEIA = "uidPlateiaChat";
const MOTOR = "uidMotorPartidas";

const CANAL = "salaIntegracao";

// ---------------------------------------------------------------------------
// Ferramentas: chamada de callable e escrita direta no Firestore do emulador.
// ---------------------------------------------------------------------------

/// Quanto tempo se espera por uma callable antes de chamar de travamento.
///
/// EXISTE porque o padrao do `fetch` e 5 MINUTOS: uma chamada que nunca responde
/// reprovava o caso com "fetch failed" cinco minutos depois, sem dizer qual
/// chamada travou. Trinta segundos distinguem "lento" de "travado" e deixam o
/// diagnostico legivel.
const LIMITE_CHAMADA_MS = 30_000;

/// Codifica cada segmento do caminho do documento.
///
/// NAO e zelo decorativo: os ids de denuncia sao `${uid}|${reportIntentId}`, e a
/// barra vertical NAO e caractere valido em URL. Sem codificar, o pedido sai
/// malformado e o emulador simplesmente NAO RESPONDE — o que aparece como
/// "fetch failed" depois do limite do fetch, e se confunde com Function travada.
const caminhoUrl = (caminho) =>
  caminho.split("/").map(encodeURIComponent).join("/");

/**
 * Chama uma callable no emulador.
 *
 * O token e um JWT NAO ASSINADO, que o emulador de Auth aceita de proposito: e
 * assim que se testa autenticacao sem subir provedor de identidade. Em producao
 * a assinatura e exigida, e por isso este atalho nao e uma porta — ele so existe
 * dentro do emulador.
 */
async function chamar(nome, dados, uid, claims = {}, direto = false) {
  // Desvio do harness: ver `comoMotor`. Três coisas o desligam:
  //  * `direto: true`, para quem QUER bater na porta antiga (INT-H-01);
  //  * ausência de `uid`, que é o caso do anônimo (INT-A-02);
  //  * qualquer outro nome de Function.
  if (nome === "enviarMensagemChat" && uid && !direto) {
    return comoMotor(nome, dados, uid);
  }

  const cabecalhos = { "Content-Type": "application/json" };

  if (uid) {
    const cabecalho = Buffer.from(
      JSON.stringify({ alg: "none", typ: "JWT" })
    ).toString("base64url");
    const corpo = Buffer.from(
      JSON.stringify({
        sub: uid,
        user_id: uid,
        iss: `https://securetoken.google.com/${PROJETO}`,
        aud: PROJETO,
        iat: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 3600,
        auth_time: Math.floor(Date.now() / 1000),
        firebase: { sign_in_provider: "custom", identities: {} },
        ...claims,
      })
    ).toString("base64url");
    cabecalhos.Authorization = `Bearer ${cabecalho}.${corpo}.`;
  }

  const url = `http://${HOST_FUNCTIONS}/${PROJETO}/${REGIAO}/${nome}`;

  const freio = new AbortController();
  const relogio = setTimeout(() => freio.abort(), LIMITE_CHAMADA_MS);
  let resposta;
  try {
    resposta = await fetch(url, {
      method: "POST",
      headers: cabecalhos,
      body: JSON.stringify({ data: dados }),
      signal: freio.signal,
    });
  } catch (e) {
    // Travamento e erro de rede viram RESULTADO, e nao excecao solta: o caso que
    // chamou precisa poder dizer QUAL chamada nao respondeu.
    return { status: 0, json: null, texto: `sem resposta de ${nome}: ${e.name}` };
  } finally {
    clearTimeout(relogio);
  }

  const texto = await resposta.text();
  let json = null;
  try {
    json = JSON.parse(texto);
  } catch (_) {
    // Resposta nao-JSON e falha de infraestrutura, e o texto cru e o diagnostico.
  }

  return { status: resposta.status, json, texto };
}

/**
 * Cabecalhos de SEMEADURA: escrita com autoridade de dono, ignorando as regras.
 *
 * `Bearer owner` e o token que o emulador do Firestore reconhece como acesso
 * administrativo — o equivalente REST do que `firebase-admin` faz em producao, e
 * do `withSecurityRulesDisabled` que o harness de regras usa.
 *
 * E PRECISO, e nao um atalho: as regras NEGAM escrita de cliente em
 * `playerIdentities`, `chatChannels`, `users/{uid}/blocks` e `playerModeration` —
 * e negar isso e justamente o que `firebase/testes/chat.test.js` prova. Semear
 * como cliente falharia por acerto das regras, e nao por defeito do chat. Quem
 * semeia aqui e a AUTORIDADE, que e quem semeia em producao.
 */
const COMO_DONO = {
  "Content-Type": "application/json",
  Authorization: "Bearer owner",
};

/**
 * O CAMINHO DE PRODUÇÃO DO ENVIO, desde a OS do Transporte Real.
 *
 * Os casos abaixo pedem `enviarMensagemChat` porque é assim que se lê "o jogador
 * X mandou este texto". Só que o ingresso DIRETO do jogador está fechado (a
 * decisão e o motivo estão no cabeçalho daquele export, e INT-H-01 prova que ele
 * recusa): quem fala com a autoridade é o motor de partidas, apresentando o claim
 * `motorDePartidas` e dizendo em nome de quem fala.
 *
 * A tradução acontece AQUI, no harness, e não nos casos — o que eles provam (a
 * decisão da autoridade sobre conteúdo, bloqueio, sanção e idempotência) não
 * mudou com o transporte. Mudou a porta.
 *
 * O que o motor NÃO ganha por esta porta está provado em INT-H: falar por quem
 * não ocupa o canal, e chamar sem o claim.
 */
function comoMotor(nome, dados, uid) {
  if (nome !== "enviarMensagemChat") return null;
  return chamar(
    CONTRATO.funcoes.enviarPeloMotor,
    Object.assign({}, dados, { autorUid: uid }),
    MOTOR,
    { motorDePartidas: true }
  );
}

/** Grava direto no Firestore do emulador, pela API REST (sem firebase-admin). */
async function gravar(caminho, campos) {
  const url =
    `http://${HOST_FIRESTORE}/v1/projects/${PROJETO}/databases/(default)/documents/` +
    caminho.split("/").slice(0, -1).join("/") +
    `?documentId=${encodeURIComponent(caminho.split("/").pop())}`;

  const r = await fetch(url, {
    method: "POST",
    headers: COMO_DONO,
    body: JSON.stringify({ fields: campos }),
  });
  if (!r.ok && r.status !== 409) {
    throw new Error(`falha ao semear ${caminho}: ${r.status} ${await r.text()}`);
  }
  // 409 = ja existe. Semear duas vezes converge, e nao e erro.
  if (r.status === 409) {
    const patch = `http://${HOST_FIRESTORE}/v1/projects/${PROJETO}/databases/(default)/documents/${caminhoUrl(caminho)}`;
    await fetch(patch, {
      method: "PATCH",
      headers: COMO_DONO,
      body: JSON.stringify({ fields: campos }),
    });
  }
}

async function apagar(caminho) {
  await fetch(
    `http://${HOST_FIRESTORE}/v1/projects/${PROJETO}/databases/(default)/documents/${caminhoUrl(caminho)}`,
    { method: "DELETE", headers: COMO_DONO }
  );
}

async function ler(caminho) {
  const r = await fetch(
    `http://${HOST_FIRESTORE}/v1/projects/${PROJETO}/databases/(default)/documents/${caminhoUrl(caminho)}`,
    { headers: COMO_DONO }
  );
  if (!r.ok) return null;
  return (await r.json()).fields ?? null;
}

/** Conta documentos de uma colecao. */
async function contar(colecao) {
  const r = await fetch(
    `http://${HOST_FIRESTORE}/v1/projects/${PROJETO}/databases/(default)/documents/${colecao}?pageSize=300`,
    { headers: COMO_DONO }
  );
  if (!r.ok) return 0;
  return ((await r.json()).documents ?? []).length;
}

const txt = (v) => ({ stringValue: v });
const bool = (v) => ({ booleanValue: v });

function participante(uid, papel) {
  return {
    mapValue: { fields: { uid: txt(uid), papel: txt(papel) } },
  };
}

let semente = 0;
/** Um `intentId` novo por caso, para que um caso nao herde a reserva do outro. */
const intent = (nome) => `int-${nome}-${++semente}`;

// ---------------------------------------------------------------------------

before(async () => {
  // O PORTAO DESTE ARQUIVO. `emulators:exec` nao exporta
  // `FUNCTIONS_EMULATOR_HOST`, entao sem esta conferencia a suite passaria
  // "verde" tendo pulado tudo — o defeito que `com-functions.js` ja documenta.
  const ping = await fetch(`http://${HOST_FUNCTIONS}/`).catch(() => null);
  assert.ok(
    ping,
    `emulador de Functions nao esta atendendo em ${HOST_FUNCTIONS}. ` +
      "Rode via `npm run test:emulador`, e nao com `node --test` solto."
  );

  const pingFs = await fetch(`http://${HOST_FIRESTORE}/`).catch(() => null);
  assert.ok(pingFs, `emulador de Firestore nao esta atendendo em ${HOST_FIRESTORE}`);

  // Identidade publica dos participantes. Sem `publicId` a autoridade recusa —
  // e recusar e o certo, porque a alternativa seria nomear o autor pelo UID.
  for (const [uid, pub] of [
    [AUTOR, "BMV-AUT1"],
    [COLEGA, "BMV-COL1"],
    [TERCEIRO, "BMV-TER1"],
    [PLATEIA, "BMV-PLA1"],
  ]) {
    await gravar(`playerIdentities/${uid}`, { publicId: txt(pub) });
  }

  // O canal, escrito como o motor de partidas o escreveria.
  await gravar(`chatChannels/${CANAL}`, {
    canalId: txt(CANAL),
    superficie: txt("mesa_privada"),
    aberto: bool(true),
    participantes: {
      arrayValue: {
        values: [
          participante(AUTOR, "jogador_sentado"),
          participante(COLEGA, "jogador_sentado"),
          participante(TERCEIRO, "jogador_sentado"),
          participante(PLATEIA, "espectador"),
        ],
      },
    },
  });
});

// ===========================================================================
// INT-A — autenticacao
// ===========================================================================
describe("INT-A — autenticacao", () => {
  test("INT-A-01 autenticado envia mensagem", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      {
        intentId: intent("a01"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "boa jogada",
      },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);
    assert.equal(r.json.result.enviada, true);
    assert.equal(r.json.result.jaEnviada, false);
    assert.equal(r.json.result.mensagem.conteudo, "boa jogada");
    assert.equal(r.json.result.mensagem.autorPublicId, "BMV-AUT1");
  });

  test("INT-A-02 ANONIMO nao envia", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      {
        intentId: intent("a02"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "sem login",
      },
      null
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /unauthenticated|UNAUTHENTICATED/);
  });

  test("INT-A-03 a resposta nao carrega UID nem destinatarios", async () => {
    // §13 no limite real: nao basta a projecao estar limpa no Dart, a RESPOSTA
    // que sai pela rede tem que estar limpa.
    const r = await chamar(
      "enviarMensagemChat",
      {
        intentId: intent("a03"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "olha a resposta",
      },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);

    // A PROJEÇÃO é o que chega ao jogador, e ela não carrega UID nenhum.
    const projecao = JSON.stringify(r.json.result.mensagem);
    for (const proibido of [AUTOR, COLEGA, TERCEIRO, "destinatarios", "autorUid"]) {
      assert.ok(!projecao.includes(proibido), `a projeção carrega ${proibido}: ${projecao}`);
    }

    // `destinatarios` vem AO LADO da projeção, e é proposital: é a lista que o
    // TRANSPORTE usa para achar os sockets (§12). Ela nunca atravessa o fio até o
    // jogador — quem prova isso é a suíte do servidor (CHT-C-04 e CHT-C-05), que
    // afirma que o pacote entregue é somente `{tipo, dados}` com a projeção.
    assert.ok(Array.isArray(r.json.result.destinatarios));
  });

  test("INT-A-04 o motor NAO fala por quem nao ocupa o canal", async () => {
    // A PROVA NEGATIVA DESTA CAMADA. Antes do transporte, o caso aqui era "UID de
    // terceiro no payload e recusado" — e ele continua valendo, mas mudou de
    // lugar: no ingresso do jogador o campo nem existe (test/contrato.test.js,
    // CTA-B-04) e no fio o servidor recusa identidade divergente
    // (buraco-servidor, CHT-A-03).
    //
    // Na porta do MOTOR o `autorUid` e legitimo — o UID autenticado da chamada e
    // o do motor, nao o do autor. Entao o que protege aqui NAO e a trava de
    // campos: e a conferencia de PARTICIPACAO. O motor pode falar por quem esta
    // sentado no canal que ele declarou, e por mais ninguem.
    const r = await chamar(
      CONTRATO.funcoes.enviarPeloMotor,
      {
        autorUid: "uidQueNuncaSentou",
        intentId: intent("a04"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "falando por estranho",
      },
      MOTOR,
      { motorDePartidas: true }
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /papelSemDireitoDeFala/);
  });

  test("INT-A-05 messageId e enviadaEm escolhidos pelo cliente sao recusados", async () => {
    for (const campo of ["messageId", "enviadaEm"]) {
      const r = await chamar(
        "enviarMensagemChat",
        {
          intentId: intent(`a05-${campo}`),
          canalId: CANAL,
          superficie: "mesa_privada",
          conteudo: "escolhi eu",
          [campo]: campo === "enviadaEm" ? "1999-01-01T00:00:00.000Z" : "id-meu",
        },
        AUTOR
      );
      assert.notEqual(r.status, 200, campo);
      assert.match(r.texto, /payloadComCampoProibido/);
    }
  });

  test("INT-A-06 o instante gravado e do SERVIDOR", async () => {
    const antes = Date.now();
    const r = await chamar(
      "enviarMensagemChat",
      {
        intentId: intent("a06"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "que hora e",
      },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);
    const t = Date.parse(r.json.result.mensagem.enviadaEm);
    assert.ok(t >= antes - 60_000 && t <= Date.now() + 60_000, r.json.result.mensagem.enviadaEm);
  });
});

// ===========================================================================
// INT-B — conteudo
// ===========================================================================
describe("INT-B — conteudo", () => {
  const base = () => ({
    canalId: CANAL,
    superficie: "mesa_privada",
  });

  test("INT-B-01 mensagem vazia e recusada", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { ...base(), intentId: intent("b01"), conteudo: "   " },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /conteudoVazio/);
  });

  test("INT-B-02 acima do limite e recusada", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { ...base(), intentId: intent("b02"), conteudo: "a".repeat(301) },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /conteudoAcimaDoLimite/);
  });

  test("INT-B-03 exatamente no limite e aceita", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { ...base(), intentId: intent("b03"), conteudo: "a".repeat(300) },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);
  });

  test("INT-B-04 payload estrutural no lugar do texto e recusado", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { ...base(), intentId: intent("b04"), conteudo: { texto: "oi" } },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /conteudoNaoTexto/);
  });

  test("INT-B-05 canalId com barra nao vira caminho de subcolecao", async () => {
    // Recusado ANTES de tocar o Firestore: um id com barra viraria caminho, e um
    // com `..` sairia da colecao pretendida.
    for (const mau of ["a/b", "../outra", "sala 7"]) {
      const r = await chamar(
        "enviarMensagemChat",
        { ...base(), canalId: mau, intentId: intent("b05"), conteudo: "oi" },
        AUTOR
      );
      assert.notEqual(r.status, 200, mau);
      assert.match(r.texto, /invalid-argument|canalId/);
    }
  });
});

// ===========================================================================
// INT-C — idempotencia REAL (§9, §15 itens 6, 7, 14)
// ===========================================================================
describe("INT-C — idempotencia", () => {
  test("INT-C-01 RETRY nao duplica: mesma mensagem, jaEnviada", async () => {
    const id = intent("c01");
    const pedido = {
      intentId: id,
      canalId: CANAL,
      superficie: "mesa_privada",
      conteudo: "mandei duas vezes",
    };

    const antes = await contar("chatMessages");
    const um = await chamar("enviarMensagemChat", pedido, AUTOR);
    const dois = await chamar("enviarMensagemChat", pedido, AUTOR);
    const depois = await contar("chatMessages");

    assert.equal(um.status, 200, um.texto);
    assert.equal(dois.status, 200, dois.texto);
    assert.equal(um.json.result.jaEnviada, false);
    assert.equal(dois.json.result.jaEnviada, true);
    assert.equal(depois - antes, 1, "retry gravou duas mensagens");

    // A MESMA mensagem, com o MESMO instante: devolver o horario de agora faria
    // o cliente ver a mesma mensagem com dois horarios.
    assert.deepEqual(dois.json.result.mensagem, um.json.result.mensagem);
  });

  test("INT-C-02 CONCORRENCIA nao duplica", async () => {
    const id = intent("c02");
    const pedido = {
      intentId: id,
      canalId: CANAL,
      superficie: "mesa_privada",
      conteudo: "cinco ao mesmo tempo",
    };

    const antes = await contar("chatMessages");
    const respostas = await Promise.all(
      Array.from({ length: 5 }, () => chamar("enviarMensagemChat", pedido, AUTOR))
    );
    const depois = await contar("chatMessages");

    // A transacao sobre `moderationTasks/{messageId}` e o que serializa: uma
    // ganha, as outras encontram a reserva e convergem.
    const ok = respostas.filter((r) => r.status === 200);
    assert.ok(ok.length >= 1, respostas.map((r) => r.texto).join(" | "));
    assert.equal(depois - antes, 1, "concorrencia gravou mais de uma mensagem");

    const ids = new Set(ok.map((r) => r.json.result.mensagem.messageId));
    assert.equal(ids.size, 1, "convergiram em messageIds diferentes");
  });

  test("INT-C-03 mensagens DIFERENTES viram duas mensagens", async () => {
    // O contrario dos dois acima: se a idempotencia colapsasse mensagens
    // distintas, o chat perderia falas — e um teste que so provasse "nao duplica"
    // ficaria verde com um chat que grava uma linha e ignora o resto.
    const antes = await contar("chatMessages");
    await chamar(
      "enviarMensagemChat",
      { intentId: intent("c03a"), canalId: CANAL, superficie: "mesa_privada", conteudo: "primeira" },
      AUTOR
    );
    await chamar(
      "enviarMensagemChat",
      { intentId: intent("c03b"), canalId: CANAL, superficie: "mesa_privada", conteudo: "segunda" },
      AUTOR
    );
    assert.equal((await contar("chatMessages")) - antes, 2);
  });

  test("INT-C-04 intencao REAPROVEITADA com outro texto e CONFLITO", async () => {
    // Nao e sucesso silencioso: o chamador reaproveitou uma intencao gasta para
    // descrever outra mensagem, e responder sucesso faria a mensagem pedida
    // desaparecer com uma confirmacao na mao dele.
    const id = intent("c04");
    const um = await chamar(
      "enviarMensagemChat",
      { intentId: id, canalId: CANAL, superficie: "mesa_privada", conteudo: "texto A" },
      AUTOR
    );
    assert.equal(um.status, 200, um.texto);

    const dois = await chamar(
      "enviarMensagemChat",
      { intentId: id, canalId: CANAL, superficie: "mesa_privada", conteudo: "texto B" },
      AUTOR
    );
    assert.notEqual(dois.status, 200);
    assert.match(dois.texto, /intencaoReutilizada/);
  });

  test("INT-C-05 o messageId gravado e OPACO", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("c05"), canalId: CANAL, superficie: "mesa_privada", conteudo: "opaco" },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);
    const id = r.json.result.mensagem.messageId;
    assert.match(id, /^[0-9a-f]{32}$/);
    assert.ok(!id.includes(AUTOR));
  });
});

// ===========================================================================
// INT-D — bloqueio lido do Firestore (§7, §15 itens 8, 9, 10)
// ===========================================================================
describe("INT-D — bloqueio", () => {
  test("INT-D-01 sem bloqueio: permitido", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("d01"), canalId: CANAL, superficie: "mesa_privada", conteudo: "sem bloqueio" },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);
  });

  test("INT-D-02 A bloqueou B: B sai da entrega", async () => {
    await gravar(`users/${AUTOR}/blocks/${COLEGA}`, {
      bloqueadorUid: txt(AUTOR),
      bloqueadoUid: txt(COLEGA),
      esquema: { integerValue: "1" },
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("d02"), canalId: CANAL, superficie: "mesa_privada", conteudo: "so o terceiro le" },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);

    // A projecao nao carrega `destinatarios`, entao a prova e no DOCUMENTO — que
    // e exatamente onde a entrega futura vai buscar.
    const doc = await ler(`chatMessages/${r.json.result.mensagem.messageId}`);
    const dest = (doc.destinatarios.arrayValue.values ?? []).map((v) => v.stringValue);
    assert.deepEqual(dest, [TERCEIRO]);

    await apagar(`users/${AUTOR}/blocks/${COLEGA}`);
  });

  test("INT-D-03 B bloqueou A: B sai da entrega (direcao inversa)", async () => {
    await gravar(`users/${COLEGA}/blocks/${AUTOR}`, {
      bloqueadorUid: txt(COLEGA),
      bloqueadoUid: txt(AUTOR),
      esquema: { integerValue: "1" },
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("d03"), canalId: CANAL, superficie: "mesa_privada", conteudo: "ele me bloqueou" },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);

    const doc = await ler(`chatMessages/${r.json.result.mensagem.messageId}`);
    const dest = (doc.destinatarios.arrayValue.values ?? []).map((v) => v.stringValue);
    assert.deepEqual(dest, [TERCEIRO], "bloqueio na direcao inversa foi ignorado");

    await apagar(`users/${COLEGA}/blocks/${AUTOR}`);
  });

  test("INT-D-04 mesa de dois com bloqueio: RECUSADO", async () => {
    // Canal proprio, com so duas pessoas: aqui o bloqueio zera a lista e a
    // mensagem nao existe. Aceitar deixaria o jogador falando com uma parede.
    const canal2 = "salaDeDois";
    await gravar(`chatChannels/${canal2}`, {
      canalId: txt(canal2),
      superficie: txt("mesa_privada"),
      aberto: bool(true),
      participantes: {
        arrayValue: {
          values: [
            participante(AUTOR, "jogador_sentado"),
            participante(COLEGA, "jogador_sentado"),
          ],
        },
      },
    });

    await gravar(`users/${COLEGA}/blocks/${AUTOR}`, {
      bloqueadorUid: txt(COLEGA),
      bloqueadoUid: txt(AUTOR),
      esquema: { integerValue: "1" },
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("d04"), canalId: canal2, superficie: "mesa_privada", conteudo: "ninguem le" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /contatoRecusado/);

    // DESBLOQUEIO volta a permitir.
    await apagar(`users/${COLEGA}/blocks/${AUTOR}`);
    const depois = await chamar(
      "enviarMensagemChat",
      { intentId: intent("d04b"), canalId: canal2, superficie: "mesa_privada", conteudo: "agora le" },
      AUTOR
    );
    assert.equal(depois.status, 200, depois.texto);
  });
});

// ===========================================================================
// INT-E — sancao lida de playerModeration (§8, §15 item 11)
// ===========================================================================
describe("INT-E — sancao", () => {
  const amanha = () => new Date(Date.now() + 864e5).toISOString();
  const ontem = () => new Date(Date.now() - 864e5).toISOString();

  test("INT-E-01 chat silenciado: envio RECUSADO", async () => {
    await gravar(`playerModeration/${AUTOR}`, {
      userId: txt(AUTOR),
      chatSilenciadoAte: txt(amanha()),
      suspensaoPermanente: bool(false),
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("e01"), canalId: CANAL, superficie: "mesa_privada", conteudo: "estou calado" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /contatoRecusado/);
    assert.match(r.texto, /chatSilenciadoPorSancao/);
  });

  test("INT-E-02 sancao EXPIRADA nao cala", async () => {
    // O relogio e do servidor. Uma sancao vencida que continuasse calando seria
    // punicao perpetua por acidente.
    await gravar(`playerModeration/${AUTOR}`, {
      userId: txt(AUTOR),
      chatSilenciadoAte: txt(ontem()),
      suspensaoPermanente: bool(false),
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("e02"), canalId: CANAL, superficie: "mesa_privada", conteudo: "ja posso falar" },
      AUTOR
    );
    assert.equal(r.status, 200, r.texto);
  });

  test("INT-E-03 SUSPENSAO TEMPORARIA tambem cala", async () => {
    // §8: `suspensaoTemporaria` esta documentada como "impede entrar na aplicacao
    // por um prazo", e quem nao entra nao fala. `consultarContato` NAO consulta
    // `suspensoAte` — o chat consulta, e este caso e o que fixa isso.
    await gravar(`playerModeration/${AUTOR}`, {
      userId: txt(AUTOR),
      suspensoAte: txt(amanha()),
      suspensaoPermanente: bool(false),
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("e03"), canalId: CANAL, superficie: "mesa_privada", conteudo: "suspenso falando" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /suspensaoImpedeChat/);
  });

  test("INT-E-04 suspensao PERMANENTE cala", async () => {
    await gravar(`playerModeration/${AUTOR}`, {
      userId: txt(AUTOR),
      suspensaoPermanente: bool(true),
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("e04"), canalId: CANAL, superficie: "mesa_privada", conteudo: "banido falando" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /suspensaoImpedeChat/);

    // Limpa para nao contaminar os casos seguintes.
    await apagar(`playerModeration/${AUTOR}`);
  });
});

// ===========================================================================
// INT-F — canal e papel (§11)
// ===========================================================================
describe("INT-F — canal e papel", () => {
  test("INT-F-01 ESPECTADOR nao envia", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("f01"), canalId: CANAL, superficie: "mesa_privada", conteudo: "sou plateia" },
      PLATEIA
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /papelSemDireitoDeFala/);
  });

  test("INT-F-02 quem nao esta no canal nao envia", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("f02"), canalId: CANAL, superficie: "mesa_privada", conteudo: "entrei de fora" },
      "uidForasteiro"
    );
    assert.notEqual(r.status, 200);
  });

  test("INT-F-03 canal inexistente: recusa, e NAO criacao", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("f03"), canalId: "salaQueNaoExiste", superficie: "mesa_privada", conteudo: "oi" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /canalDesconhecido/);
    assert.equal(await ler("chatChannels/salaQueNaoExiste"), null);
  });

  test("INT-F-04 SAGUAO nao aceita texto livre", async () => {
    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("f04"), canalId: CANAL, superficie: "saguao_publico", conteudo: "oi saguao" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /superficieNaoAceitaChat|canalInvalido/);
  });

  test("INT-F-05 canal FECHADO nao aceita fala", async () => {
    const fechado = "salaFechada";
    await gravar(`chatChannels/${fechado}`, {
      canalId: txt(fechado),
      superficie: txt("mesa_privada"),
      aberto: bool(false),
      participantes: {
        arrayValue: {
          values: [
            participante(AUTOR, "jogador_sentado"),
            participante(COLEGA, "jogador_sentado"),
          ],
        },
      },
    });

    const r = await chamar(
      "enviarMensagemChat",
      { intentId: intent("f05"), canalId: fechado, superficie: "mesa_privada", conteudo: "partida acabou" },
      AUTOR
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /canalFechado/);
  });

  test("INT-F-06 jogador NAO abre canal: definirCanalDeChat exige o claim", async () => {
    const semClaim = await chamar(
      "definirCanalDeChat",
      {
        canalId: "salaDoJogador",
        superficie: "mesa_privada",
        participantes: [{ uid: AUTOR, papel: "jogador_sentado" }],
        aberto: true,
      },
      AUTOR
    );
    assert.notEqual(semClaim.status, 200);
    assert.match(semClaim.texto, /permission-denied|PERMISSION_DENIED/);
    assert.equal(await ler("chatChannels/salaDoJogador"), null);

    // Com o claim do motor, passa.
    const comClaim = await chamar(
      "definirCanalDeChat",
      {
        canalId: "salaDoMotor",
        superficie: "mesa_privada",
        participantes: [
          { uid: AUTOR, papel: "jogador_sentado" },
          { uid: COLEGA, papel: "jogador_sentado" },
        ],
        aberto: true,
      },
      MOTOR,
      { motorDePartidas: true }
    );
    assert.equal(comClaim.status, 200, comClaim.texto);

    // E o canal que ele abriu funciona.
    const envio = await chamar(
      "enviarMensagemChat",
      { intentId: intent("f06"), canalId: "salaDoMotor", superficie: "mesa_privada", conteudo: "canal do motor" },
      AUTOR
    );
    assert.equal(envio.status, 200, envio.texto);
  });

  test("INT-F-07 o motor nao abre canal em superficie sem chat", async () => {
    const r = await chamar(
      "definirCanalDeChat",
      {
        canalId: "salaSaguao",
        superficie: "saguao_publico",
        participantes: [{ uid: AUTOR, papel: "jogador_sentado" }],
        aberto: true,
      },
      MOTOR,
      { motorDePartidas: true }
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /superficieNaoAceitaChat/);
  });
});

// ===========================================================================
// INT-G — denuncia com evidencia SERVER-SIDE (§12, §15 itens 15 e 16)
// ===========================================================================
describe("INT-G — denuncia sobre mensagem autoritativa", () => {
  test("INT-G-01 a denuncia recupera a evidencia do SERVIDOR", async () => {
    const envio = await chamar(
      "enviarMensagemChat",
      { intentId: intent("g01"), canalId: CANAL, superficie: "mesa_privada", conteudo: "frase que sera denunciada" },
      AUTOR
    );
    assert.equal(envio.status, 200, envio.texto);
    const messageId = envio.json.result.mensagem.messageId;

    const denuncia = await chamar(
      "registrarDenuncia",
      {
        denunciadoUid: AUTOR,
        tipo: "mensagem",
        categoria: "insulto",
        reportIntentId: intent("g01r"),
        messageId,
        roomId: CANAL,
        // A copia do cliente e mandada de proposito: ela tem que ser DESCARTADA.
        evidenciaMensagem: {
          conteudo: "TEXTO INVENTADO PELO DENUNCIANTE",
          enviadaEm: "1999-01-01T00:00:00.000Z",
        },
      },
      COLEGA
    );
    assert.equal(denuncia.status, 200, denuncia.texto);

    const doc = await ler(`reports/${denuncia.json.result.protocolo}`);
    const ev = doc.evidencia.mapValue.fields;

    assert.equal(ev.origem.stringValue, "servidor");
    assert.equal(ev.conteudo.stringValue, "frase que sera denunciada");
    assert.notEqual(ev.conteudo.stringValue, "TEXTO INVENTADO PELO DENUNCIANTE");
    assert.equal(ev.messageId.stringValue, messageId);
    assert.equal(ev.autorUid.stringValue, AUTOR);
  });

  test("INT-G-02 mensagem inexistente ainda aceita cliente_atestada", async () => {
    // A compatibilidade delimitada da §12: as superficies sem mensagem
    // autoritativa e o historico ja gravado continuam funcionando, e `origem`
    // continua dizendo qual dos dois casos aconteceu.
    const denuncia = await chamar(
      "registrarDenuncia",
      {
        denunciadoUid: AUTOR,
        tipo: "mensagem",
        categoria: "insulto",
        reportIntentId: intent("g02r"),
        messageId: "mensagemQueNaoExisteNoServidor",
        roomId: "salaLegado",
        evidenciaMensagem: { conteudo: "o que ele disse na mesa" },
      },
      COLEGA
    );
    assert.equal(denuncia.status, 200, denuncia.texto);

    const doc = await ler(`reports/${denuncia.json.result.protocolo}`);
    const ev = doc.evidencia.mapValue.fields;
    assert.equal(ev.origem.stringValue, "cliente_atestada");
    assert.equal(ev.conteudo.stringValue, "o que ele disse na mesa");
  });

  test("INT-G-03 o autor da evidencia vem do DOCUMENTO, nao do pedido", async () => {
    // Sem isto, denunciar a mensagem de A dizendo que ela e de B gravaria uma
    // evidencia que acusa B do que A escreveu.
    const envio = await chamar(
      "enviarMensagemChat",
      { intentId: intent("g03"), canalId: CANAL, superficie: "mesa_privada", conteudo: "escrita pelo autor" },
      AUTOR
    );
    assert.equal(envio.status, 200, envio.texto);

    const denuncia = await chamar(
      "registrarDenuncia",
      {
        denunciadoUid: TERCEIRO, // acusando o inocente
        tipo: "mensagem",
        categoria: "insulto",
        reportIntentId: intent("g03r"),
        messageId: envio.json.result.mensagem.messageId,
        // `roomId` e OBRIGATORIO em denuncia de mensagem: o dominio de moderacao
        // recusa com `referenciaAusente` sem ele. Nao e detalhe deste teste — e o
        // contrato de `avaliarDenuncia`, anterior a esta OS.
        roomId: CANAL,
      },
      COLEGA
    );
    assert.equal(denuncia.status, 200, denuncia.texto);

    const doc = await ler(`reports/${denuncia.json.result.protocolo}`);
    const ev = doc.evidencia.mapValue.fields;
    assert.equal(ev.autorUid.stringValue, AUTOR);
    assert.notEqual(ev.autorUid.stringValue, TERCEIRO);
  });
});

// ===========================================================================
// INT-H — as duas portas: quem pode falar em nome de quem (§23)
// ===========================================================================
describe("INT-H — adaptadores da autoridade", () => {
  const pedidoValido = (extra) =>
    Object.assign(
      {
        autorUid: AUTOR,
        intentId: intent("h"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "pela porta do motor",
      },
      extra || {}
    );

  test("INT-H-01 o ingresso DIRETO do jogador esta fechado", async () => {
    // A decisao da §11, provada: a porta continua exportada (nao desapareceu em
    // silencio) e responde uma recusa NOMEADA, que um cliente antigo consegue
    // distinguir de "falhou".
    const r = await chamar(
      CONTRATO.funcoes.ingressoDiretoDoJogador,
      {
        intentId: intent("h01"),
        canalId: CANAL,
        superficie: "mesa_privada",
        conteudo: "pela porta antiga",
      },
      AUTOR,
      {},
      true // sem o desvio do harness: é ESTA porta que se quer testar
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /ingressoDiretoDesativado/);
  });

  test("INT-H-02 SO o claim motorDePartidas abre a porta do motor", async () => {
    // Jogador comum autenticado: recusado.
    const jogador = await chamar(CONTRATO.funcoes.enviarPeloMotor, pedidoValido(), AUTOR);
    assert.notEqual(jogador.status, 200);
    assert.match(jogador.texto, /permission-denied|PERMISSION_DENIED/);

    // Anonimo: recusado antes disso.
    const anonimo = await chamar(CONTRATO.funcoes.enviarPeloMotor, pedidoValido(), null);
    assert.notEqual(anonimo.status, 200);
    assert.match(anonimo.texto, /unauthenticated|UNAUTHENTICATED/);

    // Com o claim: passa.
    const motor = await chamar(CONTRATO.funcoes.enviarPeloMotor, pedidoValido(), MOTOR, {
      motorDePartidas: true,
    });
    assert.equal(motor.status, 200, motor.texto);
  });

  test("INT-H-03 o motor pode falar por quem OCUPA o canal", async () => {
    // O outro lado de INT-A-04: a porta existe para isto, e funciona para os dois
    // ocupantes — nao apenas para um "autor privilegiado".
    for (const uid of [AUTOR, COLEGA]) {
      const r = await chamar(
        CONTRATO.funcoes.enviarPeloMotor,
        pedidoValido({ autorUid: uid, intentId: intent("h03-" + uid) }),
        MOTOR,
        { motorDePartidas: true }
      );
      assert.equal(r.status, 200, r.texto);
      // A projecao identifica o autor pelo publicId DELE, nao do motor.
      assert.equal(r.json.result.mensagem.autorPublicId, uid === AUTOR ? "BMV-AUT1" : "BMV-COL1");
    }
  });

  test("INT-H-04 o motor NAO pode falar por ESPECTADOR", async () => {
    const r = await chamar(
      CONTRATO.funcoes.enviarPeloMotor,
      pedidoValido({ autorUid: PLATEIA, intentId: intent("h04") }),
      MOTOR,
      { motorDePartidas: true }
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /papelSemDireitoDeFala/);
  });

  test("INT-H-05 a porta do motor devolve destinatarios para o TRANSPORTE", async () => {
    // O unico ponto do sistema que devolve UIDs, e ele existe porque o transporte
    // precisa saber para quais sockets entregar (§12). A projecao, ao lado, segue
    // sem UID nenhum (§13).
    const r = await chamar(
      CONTRATO.funcoes.enviarPeloMotor,
      pedidoValido({ intentId: intent("h05") }),
      MOTOR,
      { motorDePartidas: true }
    );
    assert.equal(r.status, 200, r.texto);
    assert.deepEqual(
      Object.keys(r.json.result).sort(),
      CONTRATO.respostaEnviarPeloMotor.campos.slice().sort()
    );
    assert.ok(Array.isArray(r.json.result.destinatarios));
    assert.equal(JSON.stringify(r.json.result.mensagem).includes(AUTOR), false);
  });

  test("INT-H-06 o motor tambem NAO escolhe messageId nem instante", async () => {
    // `autorUid` sai da trava porque e legitimo aqui. SO ele: um motor que
    // mandasse `messageId` ou `enviadaEm` poderia datar mensagem para tras.
    for (const campo of ["messageId", "enviadaEm", "socketId"]) {
      const r = await chamar(
        CONTRATO.funcoes.enviarPeloMotor,
        pedidoValido({ intentId: intent("h06-" + campo), [campo]: "escolhido" }),
        MOTOR,
        { motorDePartidas: true }
      );
      assert.notEqual(r.status, 200, campo);
      assert.match(r.texto, /payloadComCampoProibido/);
    }
  });

  test("INT-H-07 retry pelo motor converge e mantem destinatarios da 1a vez", async () => {
    // Transporte at-least-once com `messageId` estavel (§15). A lista devolvida no
    // retry e a GRAVADA, e nao um recalculo: reentregar por uma lista nova faria a
    // MESMA mensagem alcancar um conjunto diferente de pessoas.
    const pedido = pedidoValido({ intentId: intent("h07"), conteudo: "duas vezes pelo motor" });

    const um = await chamar(CONTRATO.funcoes.enviarPeloMotor, pedido, MOTOR, { motorDePartidas: true });
    const dois = await chamar(CONTRATO.funcoes.enviarPeloMotor, pedido, MOTOR, { motorDePartidas: true });

    assert.equal(um.status, 200, um.texto);
    assert.equal(dois.status, 200, dois.texto);
    assert.equal(um.json.result.jaEnviada, false);
    assert.equal(dois.json.result.jaEnviada, true);
    assert.deepEqual(dois.json.result.mensagem, um.json.result.mensagem);
    assert.deepEqual(dois.json.result.destinatarios, um.json.result.destinatarios);
  });

  test("INT-H-08 canal FECHADO recusa tambem pela porta do motor", async () => {
    const fechado = "salaFechadaMotor";
    await gravar(`chatChannels/${fechado}`, {
      canalId: txt(fechado),
      superficie: txt("mesa_privada"),
      aberto: bool(false),
      participantes: {
        arrayValue: {
          values: [participante(AUTOR, "jogador_sentado"), participante(COLEGA, "jogador_sentado")],
        },
      },
    });

    const r = await chamar(
      CONTRATO.funcoes.enviarPeloMotor,
      pedidoValido({ canalId: fechado, intentId: intent("h08") }),
      MOTOR,
      { motorDePartidas: true }
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /canalFechado/);
  });
});
