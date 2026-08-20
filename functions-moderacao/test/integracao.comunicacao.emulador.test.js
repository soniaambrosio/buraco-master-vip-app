/**
 * integracao.comunicacao.emulador.test.js — a COMUNICACAO CONTROLADA contra o
 * Emulator Suite.
 *
 * POR QUE ESTE ARQUIVO EXISTE, e o que so ele prova.
 *
 * As outras tres suites desta frente cobrem o que cada uma consegue cobrir:
 *
 *   `app/test/comunicacao/comunicacao_test.dart` prova a DECISAO — a matriz da
 *   §2, o catalogo, o ritmo, o silencio, o evento de sistema — com o estado
 *   entrando por parametro.
 *
 *   `functions-moderacao/test/comunicacao.test.js` prova a PROJECAO, a
 *   EVIDENCIA e a RETENCAO, sobre modulos puros.
 *
 *   `firebase/testes/chat.test.js` prova a AUTORIZACAO das colecoes.
 *
 * ESTE prova o que so acontece quando a decisao encontra o BANCO:
 *
 *   * o AMBIENTE e resolvido contra `salasPrivadas` e `assentosAdmitidos`, que
 *     sao escritos por OUTRA autoridade (functions-mesas). Declarar `privada`
 *     nao basta — a sala tem de existir, e o assento tem de ter sido admitido;
 *   * o DIREITO premium e lido de `playerEntitlements`, que e escrito pelo
 *     Billing, e a vigencia e recalculada contra o relogio;
 *   * o RITMO acumula em `chatRitmo` de verdade, entre chamadas;
 *   * o EVENTO DE SISTEMA nasce so com o claim, e nasce sem dono;
 *   * a DENUNCIA resolve o alvo pelo `publicIdIndex` e pelo evento gravado.
 *
 * Uso:
 *   cd functions-moderacao && npm run build:domain && npm run build
 *   npm run test:emulador
 */

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test, before, beforeEach, describe } = require("node:test");

const CONTRATO = JSON.parse(
  fs.readFileSync(
    path.resolve(__dirname, "..", "..", "contrato", "chat-transporte-v1.json"),
    "utf8"
  )
);

const PROJETO = process.env.GCLOUD_PROJECT || "demo-bmv";
const REGIAO = "southamerica-east1";
const HOST_FUNCTIONS = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const HOST_FIRESTORE = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";

const DONO = "uidDonoPrivada";
const CONVIDADO = "uidConvidadoPrivada";
const PENETRA = "uidPenetraPrivada";
const VIZINHO = "uidVizinhoPublica";
const MOTOR = "uidMotorPartidas";

const CODIGO_PRIVADA = "PRIV4D4X";
const CANAL_PRIVADA = "canalPrivadaInt";
const CANAL_PUBLICA = "canalPublicaInt";
const CANAL_SALAO = "canalSalaoVipInt";

/// FORMATO CANONICO do `publicId`: prefixo `P` + 12 simbolos do alfabeto de
/// app/lib/social/identidade_publica.dart (sem I, L e O, na tradicao do
/// Crockford). Um id fora do formato e recusado ANTES da consulta — e foi o que
/// aconteceu na primeira versao deste arquivo, com um id "legivel" que continha
/// a letra O.
const PUBLIC_ID_DONO = "PD0000000000A";
const PUBLIC_ID_CONVIDADO = "PC0000000000A";
const PUBLIC_ID_PENETRA = "PP0000000000A";
const PUBLIC_ID_VIZINHO = "PV0000000000A";

const LIMITE_CHAMADA_MS = 30_000;
const caminhoUrl = (c) => c.split("/").map(encodeURIComponent).join("/");

async function chamar(nome, dados, uid, claims = {}) {
  const cabecalhos = { "Content-Type": "application/json" };
  if (uid) {
    const cab = Buffer.from(
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
    cabecalhos.Authorization = `Bearer ${cab}.${corpo}.`;
  }

  const freio = new AbortController();
  const relogio = setTimeout(() => freio.abort(), LIMITE_CHAMADA_MS);
  let resposta;
  try {
    resposta = await fetch(
      `http://${HOST_FUNCTIONS}/${PROJETO}/${REGIAO}/${nome}`,
      {
        method: "POST",
        headers: cabecalhos,
        body: JSON.stringify({ data: dados }),
        signal: freio.signal,
      }
    );
  } catch (e) {
    return { status: 0, json: null, texto: `sem resposta de ${nome}: ${e.name}` };
  } finally {
    clearTimeout(relogio);
  }

  const texto = await resposta.text();
  let json = null;
  try {
    json = JSON.parse(texto);
  } catch (_) {
    /* resposta nao-JSON e falha de infra; o texto cru e o diagnostico */
  }
  return { status: resposta.status, json, texto };
}

/// Fala com a autoridade como o MOTOR fala: com o claim, e dizendo em nome de
/// quem. O ingresso direto do jogador esta fechado desde a OS do Transporte.
const comoMotor = (dados, autorUid) =>
  chamar(
    CONTRATO.funcoes.enviarPeloMotor,
    Object.assign({}, dados, { autorUid }),
    MOTOR,
    { motorDePartidas: true }
  );

const COMO_DONO = {
  "Content-Type": "application/json",
  Authorization: "Bearer owner",
};

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
  if (r.status === 409) {
    await fetch(
      `http://${HOST_FIRESTORE}/v1/projects/${PROJETO}/databases/(default)/documents/${caminhoUrl(caminho)}`,
      { method: "PATCH", headers: COMO_DONO, body: JSON.stringify({ fields: campos }) }
    );
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

const txt = (v) => ({ stringValue: v });
const bool = (v) => ({ booleanValue: v });
const participante = (uid, papel) => ({
  mapValue: { fields: { uid: txt(uid), papel: txt(papel) } },
});

let semente = 0;
const intent = (nome) => `com-${nome}-${++semente}`;

/// O canal, declarado pela porta REAL (com o claim do motor). Usar a porta em
/// vez de semear o documento e o ponto de metade dos casos: e ela que resolve o
/// ambiente contra a autoridade dos tipos.
const declararCanal = (dados) =>
  chamar(CONTRATO.funcoes.definirCanal, dados, MOTOR, { motorDePartidas: true });

before(async () => {
  const ping = await fetch(`http://${HOST_FUNCTIONS}/`).catch(() => null);
  assert.ok(
    ping,
    `emulador de Functions nao esta atendendo em ${HOST_FUNCTIONS}. ` +
      "Rode via `npm run test:emulador`, e nao com `node --test` solto."
  );
  const pingFs = await fetch(`http://${HOST_FIRESTORE}/`).catch(() => null);
  assert.ok(pingFs, `emulador de Firestore nao esta atendendo em ${HOST_FIRESTORE}`);

  for (const [uid, pub] of [
    [DONO, PUBLIC_ID_DONO],
    [CONVIDADO, PUBLIC_ID_CONVIDADO],
    [PENETRA, PUBLIC_ID_PENETRA],
    [VIZINHO, PUBLIC_ID_VIZINHO],
  ]) {
    await gravar(`playerIdentities/${uid}`, { publicId: txt(pub) });
    // O mapa reverso, como functions-social o escreve. E por ele que a denuncia
    // resolve um alvo que a tela so conhece por `publicId`.
    await gravar(`publicIdIndex/${pub}`, { uid: txt(uid) });
  }

  // A MESA PRIVADA, como `functions-mesas` a registra. Este documento so nasce
  // para quem tem ASSINATURA ATIVA — e e por isso que a autoridade de
  // comunicacao o exige antes de abrir o teclado.
  await gravar(`salasPrivadas/${CODIGO_PRIVADA}`, {
    salaId: txt(CODIGO_PRIVADA),
    codigoDaSala: txt(CODIGO_PRIVADA),
    proprietarioUid: txt(DONO),
    criadaEm: txt(new Date().toISOString()),
    encerradaEm: { nullValue: null },
    modoDeChat: txt("completo"),
  });

  // Os assentos ADMITIDOS, ancora que o gate VIP grava. O PENETRA nao tem.
  for (const uid of [DONO, CONVIDADO]) {
    await gravar(`assentosAdmitidos/${CODIGO_PRIVADA}__${uid}`, {
      uid: txt(uid),
      codigoDaSala: txt(CODIGO_PRIVADA),
    });
  }
});

beforeEach(async () => {
  // Ver o comentario equivalente em integracao.chat.emulador.test.js: o ritmo
  // e estado, e um arnes limpa estado entre casos. Os casos de INT-R NAO
  // dependem desta limpeza — eles medem a acumulacao dentro de UM caso.
  await Promise.all(
    [DONO, CONVIDADO, PENETRA, VIZINHO].map((uid) => apagar(`chatRitmo/${uid}`))
  );
});

// ===========================================================================
// INT-AMB — o ambiente vem da AUTORIDADE DOS TIPOS, e nao do pedido
// ===========================================================================
describe("INT-AMB — a resolucao do ambiente", () => {
  test("INT-AMB-01 Mesa Privada exige a sala REGISTRADA", async () => {
    // Declarar `privada` nao basta. Sem `salasPrivadas/{codigo}` — que so
    // nasce para assinante — o canal nao existe, e sem canal nao ha teclado.
    const semSala = await declararCanal({
      canalId: "canalPrivadaFantasma",
      tipoPartida: "privada",
      categoriaCompetitiva: "casual",
      codigoDaSala: "N4OEXIST",
      participantes: [
        { uid: DONO, papel: "jogador_sentado" },
        { uid: CONVIDADO, papel: "jogador_sentado" },
      ],
      aberto: true,
    });
    assert.notEqual(semSala.status, 200);
    assert.match(semSala.texto, /salaPrivadaNaoRegistrada/);
    assert.equal(await ler("chatChannels/canalPrivadaFantasma"), null);
  });

  test("INT-AMB-02 com a sala registrada, o canal nasce — e o CODIGO nao fica", async () => {
    const r = await declararCanal({
      canalId: CANAL_PRIVADA,
      tipoPartida: "privada",
      categoriaCompetitiva: "casual",
      codigoDaSala: CODIGO_PRIVADA,
      participantes: [
        { uid: DONO, papel: "jogador_sentado" },
        { uid: CONVIDADO, papel: "jogador_sentado" },
        { uid: PENETRA, papel: "jogador_sentado" },
      ],
      aberto: true,
    });
    assert.equal(r.status, 200, r.texto);
    assert.equal(r.json.result.ambiente, "mesa_privada");
    // O modo veio da SALA, e nao do pedido: o pedido nem o mandou.
    assert.equal(r.json.result.modo, "completo");

    const doc = await ler(`chatChannels/${CANAL_PRIVADA}`);
    assert.ok(doc);
    assert.equal(doc.ambiente.stringValue, "mesa_privada");
    // O CODIGO DA SALA NAO FICA GRAVADO. Ele e a chave de entrada da Mesa
    // Privada; um canal que o carregasse o entregaria a quem lesse o documento.
    assert.equal(JSON.stringify(doc).includes(CODIGO_PRIVADA), false);
  });

  test("INT-AMB-03 assento sem admissao e REBAIXADO, e a mesa nao emudece", async () => {
    // O PENETRA foi declarado sentado pelo motor e NAO tem
    // `assentosAdmitidos`. Ele nao fala e nao recebe — e os outros dois seguem
    // conversando. Recusar o canal inteiro calaria a mesa por causa de um.
    const doc = await ler(`chatChannels/${CANAL_PRIVADA}`);
    const papeis = Object.fromEntries(
      doc.participantes.arrayValue.values.map((p) => [
        p.mapValue.fields.uid.stringValue,
        p.mapValue.fields.papel.stringValue,
      ])
    );
    assert.equal(papeis[DONO], "jogador_sentado");
    assert.equal(papeis[CONVIDADO], "jogador_sentado");
    assert.equal(papeis[PENETRA], "fora_do_canal");
  });

  test("INT-AMB-04 Mesa Publica e Salao VIP nascem sem exigir sala", async () => {
    const publica = await declararCanal({
      canalId: CANAL_PUBLICA,
      tipoPartida: "publica",
      categoriaCompetitiva: "casual",
      participantes: [
        { uid: DONO, papel: "jogador_sentado" },
        { uid: VIZINHO, papel: "jogador_sentado" },
      ],
      aberto: true,
    });
    assert.equal(publica.status, 200, publica.texto);
    assert.equal(publica.json.result.ambiente, "mesa_publica");
    // Sem `modo` no pedido, o padrao e balões — nunca teclado.
    assert.equal(publica.json.result.modo, "apenas_emotes");
  });
});

// ===========================================================================
// INT-TXT — texto livre so na Mesa Privada, medido contra o banco
// ===========================================================================
describe("INT-TXT — o teclado tem UM lugar", () => {
  test("INT-TXT-01 jogador admitido escreve na Mesa Privada", async () => {
    const r = await comoMotor(
      { intentId: intent("txt01"), canalId: CANAL_PRIVADA, conteudo: "boa jogada" },
      DONO
    );
    assert.equal(r.status, 200, r.texto);
    assert.equal(r.json.result.mensagem.conteudo, "boa jogada");
    assert.equal(r.json.result.mensagem.ambiente, "mesa_privada");
    // O convidado recebe; o penetra rebaixado, nao.
    assert.deepEqual(r.json.result.destinatarios, [CONVIDADO]);
  });

  test("INT-TXT-02 a MESMA mensagem na Mesa Publica e recusada", async () => {
    const r = await comoMotor(
      { intentId: intent("txt02"), canalId: CANAL_PUBLICA, conteudo: "boa jogada" },
      DONO
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /textoLivreNaoPermitidoNoAmbiente/);
    assert.match(r.texto, /"familia":"ambiente"/);
  });

  test("INT-TXT-03 quem nao foi admitido nao escreve, nem com o motor pedindo", async () => {
    const r = await comoMotor(
      { intentId: intent("txt03"), canalId: CANAL_PRIVADA, conteudo: "entrei pelo codigo" },
      PENETRA
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /papelSemDireitoDeFala/);
  });

  test("INT-TXT-04 a retencao e gravada junto com a mensagem", async () => {
    const r = await comoMotor(
      { intentId: intent("txt04"), canalId: CANAL_PRIVADA, conteudo: "com prazo" },
      DONO
    );
    assert.equal(r.status, 200, r.texto);
    const doc = await ler(`chatMessages/${r.json.result.mensagem.messageId}`);
    assert.ok(doc.expiraEm, "a mensagem nasceu sem prazo de retencao");
    const dias =
      (Date.parse(doc.expiraEm.stringValue) -
        Date.parse(doc.enviadaEm.stringValue)) /
      86400000;
    assert.equal(dias, 30);
    // E o que o jogador recebe NAO carrega o prazo nem os destinatarios.
    assert.equal("expiraEm" in r.json.result.mensagem, false);
    assert.equal("destinatarios" in r.json.result.mensagem, false);
  });
});

// ===========================================================================
// INT-CAT — o catalogo, e o direito que ele exige
// ===========================================================================
describe("INT-CAT — catalogo e entitlement", () => {
  before(async () => {
    await declararCanal({
      canalId: CANAL_SALAO,
      // O Salao VIP nao e mesa: ele e declarado como saguao, e quem esta la
      // esta `presente`, nao sentado.
      tipoPartida: "publica",
      categoriaCompetitiva: "vip_ranqueada",
      participantes: [
        { uid: DONO, papel: "jogador_sentado" },
        { uid: VIZINHO, papel: "jogador_sentado" },
      ],
      aberto: true,
    });
  });

  test("INT-CAT-01 fala catalogada passa, e a FRASE nao viaja", async () => {
    const r = await comoMotor(
      {
        intentId: intent("cat01"),
        canalId: CANAL_PUBLICA,
        tipo: "fala_catalogada",
        itemId: "elogiar_boa_jogada_01",
      },
      DONO
    );
    assert.equal(r.status, 200, r.texto);
    assert.equal(r.json.result.mensagem.itemId, "elogiar_boa_jogada_01");
    assert.equal("conteudo" in r.json.result.mensagem, false);
    assert.equal(
      r.json.result.mensagem.chaveDeLocalizacao,
      "comunicacao.fala.elogiar_boa_jogada_01"
    );
    assert.equal(r.json.result.mensagem.fallbackOficial, "Boa jogada!");
  });

  test("INT-CAT-02 item premium sem direito VIGENTE e recusado", async () => {
    // O documento existe e diz `vipAtivo: true` — e esta VENCIDO. E o caso que
    // um `if (doc.vipAtivo)` erraria: assinatura cancelada vigente carrega o
    // booleano ligado ate o dia em que `expiraEm` fica no passado.
    await gravar(`playerEntitlements/${DONO}`, {
      vipAtivo: bool(true),
      estado: txt("cancelado_vigente"),
      expiraEm: txt(new Date(Date.now() - 86400000).toISOString()),
    });

    const r = await comoMotor(
      {
        intentId: intent("cat02"),
        canalId: CANAL_SALAO,
        tipo: "emoji_catalogado",
        itemId: "emoji_coroa_01",
      },
      DONO
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /entitlementAusente/);
    assert.match(r.texto, /"familia":"direito"/);
  });

  test("INT-CAT-03 com direito vigente, o mesmo item passa", async () => {
    await gravar(`playerEntitlements/${DONO}`, {
      vipAtivo: bool(true),
      estado: txt("ativo"),
      expiraEm: txt(new Date(Date.now() + 30 * 86400000).toISOString()),
    });

    const r = await comoMotor(
      {
        intentId: intent("cat03"),
        canalId: CANAL_SALAO,
        tipo: "emoji_catalogado",
        itemId: "emoji_coroa_01",
      },
      DONO
    );
    assert.equal(r.status, 200, r.texto);
    assert.equal(r.json.result.mensagem.itemId, "emoji_coroa_01");
  });

  test("INT-CAT-04 texto no lugar do id e recusado", async () => {
    const r = await comoMotor(
      {
        intentId: intent("cat04"),
        canalId: CANAL_PUBLICA,
        tipo: "fala_catalogada",
        itemId: "elogiar_boa_jogada_01",
        conteudo: "Boa jogada!",
      },
      DONO
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /textoNoLugarDoItem/);
  });
});

// ===========================================================================
// INT-R — o RITMO acumula no banco
// ===========================================================================
describe("INT-R — o freio existe de verdade", () => {
  test("INT-R-01 duas falas coladas: a segunda leva cooldown", async () => {
    const um = await comoMotor(
      {
        intentId: intent("r01a"),
        canalId: CANAL_PUBLICA,
        tipo: "reacao_catalogada",
        itemId: "reacao_aplauso_01",
      },
      VIZINHO
    );
    assert.equal(um.status, 200, um.texto);

    const dois = await comoMotor(
      {
        intentId: intent("r01b"),
        canalId: CANAL_PUBLICA,
        tipo: "reacao_catalogada",
        itemId: "reacao_risada_01",
      },
      VIZINHO
    );
    assert.notEqual(dois.status, 200);
    assert.match(dois.texto, /ritmoExcedido|comunicacaoBloqueadaPorAbuso/);
    // `liberaEmMs` e informacao sobre o PROPRIO pedido, e volta para a tela
    // poder desenhar o contador.
    assert.match(dois.texto, /liberaEmMs/);
  });

  test("INT-R-02 o estado do ritmo fica gravado, e o conteudo NAO", async () => {
    // AUTO-CONTIDO de proposito: `beforeEach` limpa o ritmo, entao um caso que
    // dependesse do estado deixado pelo caso anterior mediria o vazio e passaria
    // por engano no dia em que a ordem mudasse.
    const r = await comoMotor(
      {
        intentId: intent("r02"),
        canalId: CANAL_PUBLICA,
        tipo: "reacao_catalogada",
        itemId: "reacao_aplauso_01",
      },
      VIZINHO
    );
    assert.equal(r.status, 200, r.texto);

    const doc = await ler(`chatRitmo/${VIZINHO}`);
    assert.ok(doc, "o ritmo do jogador nao foi gravado");
    const cru = JSON.stringify(doc);
    assert.equal(cru.includes("conteudo"), false);
    assert.equal(cru.includes("Boa jogada"), false);
  });

  test("INT-R-03 o RETRY nao e barrado pelo freio", async () => {
    // Quem repete nao esta inundando: esta reconectando. O retry converge no
    // documento gravado, mesmo dentro da janela de cooldown.
    const id = intent("r03");
    const um = await comoMotor(
      {
        intentId: id,
        canalId: CANAL_PUBLICA,
        tipo: "emoji_catalogado",
        itemId: "emoji_joia_01",
      },
      VIZINHO
    );
    assert.equal(um.status, 200, um.texto);

    const retry = await comoMotor(
      {
        intentId: id,
        canalId: CANAL_PUBLICA,
        tipo: "emoji_catalogado",
        itemId: "emoji_joia_01",
      },
      VIZINHO
    );
    assert.equal(retry.status, 200, retry.texto);
    assert.equal(retry.json.result.jaEnviada, true);
    assert.equal(
      retry.json.result.mensagem.messageId,
      um.json.result.mensagem.messageId
    );
  });
});

// ===========================================================================
// INT-SIS — evento de sistema
// ===========================================================================
describe("INT-SIS — evento de sistema (§8)", () => {
  test("INT-SIS-01 jogador comum NAO emite", async () => {
    const r = await chamar(
      CONTRATO.funcoes.eventoDeSistema,
      {
        canalId: CANAL_PUBLICA,
        intentId: intent("sis01"),
        eventoId: "sistema_presente_disponivel",
      },
      DONO
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /permission-denied|PERMISSION_DENIED/);
  });

  test("INT-SIS-02 a autoridade emite, e o evento nasce SEM DONO", async () => {
    const r = await chamar(
      CONTRATO.funcoes.eventoDeSistema,
      {
        canalId: CANAL_PUBLICA,
        intentId: intent("sis02"),
        eventoId: "sistema_presente_disponivel",
      },
      MOTOR,
      { motorDePartidas: true }
    );
    assert.equal(r.status, 200, r.texto);
    assert.equal(r.json.result.mensagem.fallbackOficial, "Pegue seu presente!");
    assert.equal("autorPublicId" in r.json.result.mensagem, false);

    const doc = await ler(`chatMessages/${r.json.result.mensagem.messageId}`);
    assert.ok(doc.autorUid.nullValue !== undefined, "o evento nasceu com dono");
  });

  test("INT-SIS-03 evento inventado e recusado", async () => {
    const r = await chamar(
      CONTRATO.funcoes.eventoDeSistema,
      {
        canalId: CANAL_PUBLICA,
        intentId: intent("sis03"),
        eventoId: "sistema_voce_ganhou_tudo",
      },
      MOTOR,
      { motorDePartidas: true }
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /eventoDeSistemaDesconhecido/);
  });

  test("INT-SIS-04 o jogador nao alcanca o tipo pela porta de envio", async () => {
    const r = await comoMotor(
      {
        intentId: intent("sis04"),
        canalId: CANAL_PUBLICA,
        tipo: "evento_de_sistema",
        itemId: "sistema_presente_disponivel",
      },
      DONO
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /eventoDeSistemaSemAutoridade/);
  });
});

// ===========================================================================
// INT-DEN — a denuncia resolve o alvo
// ===========================================================================
describe("INT-DEN — denuncia (§9.3, §9.5)", () => {
  test("INT-DEN-01 o alvo sai do EVENTO, e vence o que o pedido disser", async () => {
    const fala = await comoMotor(
      { intentId: intent("den01"), canalId: CANAL_PRIVADA, conteudo: "algo denunciavel" },
      DONO
    );
    assert.equal(fala.status, 200, fala.texto);
    const messageId = fala.json.result.mensagem.messageId;

    const denuncia = await chamar(
      "registrarDenuncia",
      {
        // O denunciante MENTE sobre o autor. A autoridade le o documento.
        denunciadoUid: VIZINHO,
        tipo: "mensagem",
        categoria: "insulto",
        reportIntentId: intent("den01r"),
        messageId,
        roomId: CANAL_PRIVADA,
      },
      CONVIDADO
    );
    assert.equal(denuncia.status, 200, denuncia.texto);

    const registro = await ler(`reports/${denuncia.json.result.protocolo}`);
    assert.equal(registro.denunciadoUid.stringValue, DONO);
    assert.equal(registro.evidencia.mapValue.fields.origem.stringValue, "servidor");
    assert.equal(
      registro.evidencia.mapValue.fields.conteudo.stringValue,
      "algo denunciavel"
    );
  });

  test("INT-DEN-02 o alvo pode vir por publicId, sem UID no aparelho", async () => {
    // A dependencia que travou a OS de UI de denuncia: as telas do jogador so
    // conhecem `publicId`. A resolucao acontece no backend, pelo indice reverso
    // que e negado a todo cliente.
    const r = await chamar(
      "registrarDenuncia",
      {
        denunciadoPublicId: PUBLIC_ID_DONO,
        tipo: "perfil",
        categoria: "nomeOfensivo",
        reportIntentId: intent("den02"),
      },
      CONVIDADO
    );
    assert.equal(r.status, 200, r.texto);
    const registro = await ler(`reports/${r.json.result.protocolo}`);
    assert.equal(registro.denunciadoUid.stringValue, DONO);
  });

  test("INT-DEN-03 sem alvo resolvivel, a resposta e NEUTRA", async () => {
    const r = await chamar(
      "registrarDenuncia",
      {
        denunciadoPublicId: "BMVN4OEXIST",
        tipo: "perfil",
        categoria: "nomeOfensivo",
        reportIntentId: intent("den03"),
      },
      CONVIDADO
    );
    assert.notEqual(r.status, 200);
    assert.match(r.texto, /alvoNaoResolvido/);
    // A resposta NAO diz se o publicId existe.
    assert.equal(/nao existe|inexistente|not found/i.test(r.texto), false);
  });

  test("INT-DEN-04 fala catalogada preserva id, versao e REPETICAO", async () => {
    // Uma fala do catalogo nunca e ofensiva por si — ela foi aprovada. O que
    // ofende e a repeticao, e e ela que a evidencia precisa mostrar.
    let ultimo = null;
    for (let i = 0; i < 3; i++) {
      ultimo = await comoMotor(
        {
          intentId: intent("den04-" + i),
          canalId: CANAL_PUBLICA,
          tipo: "fala_catalogada",
          itemId: "provocar_essa_doeu_01",
        },
        VIZINHO
      );
      // O cooldown desta categoria e de 15 s; o arnes limpa o ritmo entre as
      // repeticoes porque o assunto aqui e a EVIDENCIA, e nao o freio.
      await apagar(`chatRitmo/${VIZINHO}`);
    }
    assert.equal(ultimo.status, 200, ultimo.texto);

    const r = await chamar(
      "registrarDenuncia",
      {
        tipo: "mensagem",
        categoria: "assedio",
        reportIntentId: intent("den04r"),
        messageId: ultimo.json.result.mensagem.messageId,
        roomId: CANAL_PUBLICA,
      },
      DONO
    );
    assert.equal(r.status, 200, r.texto);

    const ev = (await ler(`reports/${r.json.result.protocolo}`)).evidencia
      .mapValue.fields;
    assert.equal(ev.itemId.stringValue, "provocar_essa_doeu_01");
    assert.equal(Number(ev.versaoDoCatalogo.integerValue), 1);
    assert.equal(Number(ev.repeticoes.integerValue), 3);
    assert.equal(ev.instantes.arrayValue.values.length, 3);
    // E a evidencia NAO carrega texto nenhum: o id e a versao dizem tudo.
    assert.equal(JSON.stringify(ev).includes("fallback"), false);
  });
});
