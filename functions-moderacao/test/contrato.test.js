/**
 * contrato.test.js — UMA AUTORIDADE, DOIS ADAPTADORES, e o contrato com o servidor.
 *
 * TRES TRABALHOS, e nenhum deles e verificavel por revisao de codigo:
 *
 * 1. O CONTRATO NAO DIVERGIU (§24). `contrato/chat-transporte-v1.json` existe
 *    IDENTICO neste repositorio e em `buraco-servidor`. Este arquivo afirma o
 *    digest dele, e a suite do servidor afirma o MESMO numero. Editar uma copia e
 *    nao a outra reprova as duas — que e o unico jeito de impedir nome de
 *    Function, regiao, campo de pedido, campo de resposta e codigo de recusa de
 *    passarem a discordar entre dois repositorios que ninguem compila junto.
 *
 * 2. OS DOIS ADAPTADORES CONVERGEM (§10). A OS proibe explicitamente
 *    `...Cliente` com uma implementacao e `...Motor` com outra. Isso e uma
 *    afirmacao sobre a ESTRUTURA do arquivo, e e varrivel: nenhum dos dois pode
 *    ler bloqueio, ler `playerModeration`, chamar `avaliarEnvioChat` ou gravar em
 *    `chatMessages` por conta propria. So o nucleo faz isso, e os dois o chamam.
 *
 * 3. O INGRESSO DIRETO ESTA FECHADO (§11). A decisao foi documentada, nao
 *    silenciosa: a porta continua exportada e responde uma recusa NOMEADA. Se
 *    alguem a reabrir sem decidir, este arquivo reprova.
 *
 * A VARREDURA E SOBRE CODIGO, NAO SOBRE PROSA. Os comentarios de `index.ts` falam
 * de bloqueio, de sancao e de `playerModeration` — explicar o que se faz e metade
 * da documentacao dali. Procurar no arquivo cru daria falso positivo em cima da
 * propria explicacao, entao a varredura acontece DEPOIS de tirar comentario.
 */

"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const RAIZ = path.resolve(__dirname, "..", "..");
const CAMINHO_CONTRATO = path.join(RAIZ, "contrato", "chat-transporte-v1.json");
const FONTE = fs.readFileSync(path.join(__dirname, "..", "src", "index.ts"), "utf8");

/**
 * O digest esperado do contrato compartilhado.
 *
 * MUDAR O CONTRATO E MUDAR ESTE NUMERO, nos DOIS repositorios, junto com o
 * arquivo. E trabalho de proposito: uma mudanca de contrato que nao exija tocar
 * as duas pontas e uma mudanca que vai divergir.
 *
 * Normalizado em LF: sem isso a mesma arvore reprovaria no Windows (CRLF do
 * autocrlf) e passaria no CI.
 */
const DIGEST_CONTRATO = "a3ccdbab0730d807c8e954eee3e47d3e2c7b48933fcc1abcac01b5d09c2a2c23";

const contrato = JSON.parse(fs.readFileSync(CAMINHO_CONTRATO, "utf8"));

/** Tira comentario de linha e de bloco. Mantem string, que aqui interessa. */
function soCodigo(fonte) {
  return fonte
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .replace(/^[ \t]*\/\/.*$/gm, " ")
    .replace(/^[ \t]*\/\/\/.*$/gm, " ");
}

const CODIGO = soCodigo(FONTE);

/** O corpo de uma funcao exportada, do `export const X` ate o proximo `export`. */
function corpoDoExport(nome) {
  const i = CODIGO.indexOf("export const " + nome + " =");
  assert.ok(i > 0, "export ausente: " + nome);
  const resto = CODIGO.slice(i + 10);
  const f = resto.indexOf("\nexport const ");
  return f === -1 ? CODIGO.slice(i) : CODIGO.slice(i, i + 10 + f);
}

// ===========================================================================
// CTA-A — o contrato compartilhado
// ===========================================================================
test("CTA-A-01 o contrato tem o digest esperado", () => {
  const normalizado = fs.readFileSync(CAMINHO_CONTRATO, "utf8").replace(/\r\n/g, "\n");
  const digest = crypto.createHash("sha256").update(normalizado, "utf8").digest("hex");
  assert.equal(
    digest,
    DIGEST_CONTRATO,
    "o contrato mudou; atualize o digest AQUI e em buraco-servidor/test/chat_contrato.test.js"
  );
});

test("CTA-A-02 as Functions do contrato existem com esses nomes", () => {
  for (const nome of [
    contrato.funcoes.definirCanal,
    contrato.funcoes.enviarPeloMotor,
    contrato.funcoes.ingressoDiretoDoJogador,
  ]) {
    assert.ok(
      CODIGO.includes("export const " + nome + " ="),
      "o contrato nomeia " + nome + ", que nao e exportada"
    );
  }
});

test("CTA-A-03 a regiao das Functions e a do contrato", () => {
  // O servidor monta a URL com a regiao do contrato. Se aqui for outra, a chamada
  // vai para um endereco que nao existe — e o sintoma seria "chat nao funciona".
  assert.match(FONTE, new RegExp('region:\\s*"' + contrato.funcoes.regiao + '"'));
});

test("CTA-A-04 a projecao publica tem EXATAMENTE os campos do contrato", () => {
  // A lista fechada mora em `comunicacao.ts` (`projetarComunicacao`), que e a
  // projecao PRODUTIVA desde a OS de Comunicacao Controlada. O contrato a repete
  // para o servidor poder afirmar o formato do fio; as duas nao podem divergir.
  //
  // O documento de teste e o CASO MAXIMO de proposito — texto E item, autor E
  // catalogo — porque a lista do contrato e a uniao dos campos possiveis. Um
  // documento minimo omitiria campos opcionais e a comparacao passaria por
  // ausencia, que e o modo classico de uma assercao de igualdade mentir.
  const { projetarComunicacao } = require("../lib/comunicacao.js");
  const projecao = projetarComunicacao({
    messageId: "m",
    canalId: "c",
    superficie: "mesa_de_partida",
    ambiente: "mesa_privada",
    tipo: "texto_privado",
    autorUid: "uidInterno",
    autorPublicId: "PUB",
    conteudo: "t",
    itemId: "elogiar_boa_jogada_01",
    chaveDeLocalizacao: "comunicacao.fala.elogiar_boa_jogada_01",
    fallbackOficial: "Boa jogada!",
    destinatarios: ["uidOutro"],
    silenciados: ["uidTerceiro"],
    enviadaEm: "2026-01-01T00:00:00.000Z",
    expiraEm: "2026-01-31T00:00:00.000Z",
    versaoDoCatalogo: 1,
    versaoDoContrato: 1,
    esquema: 1,
  });
  assert.deepEqual(
    Object.keys(projecao).sort(),
    contrato.projecaoPublica.campos.slice().sort()
  );
});

test("CTA-A-05 a projecao NAO carrega o que e interno", () => {
  // O espelho do caso acima, e o que importa de verdade: a lista do contrato e
  // fechada, mas uma lista pode estar certa e a funcao ainda vazar por um campo
  // que ninguem pensou em listar. Aqui a pergunta e a inversa — nenhum dos tres
  // campos internos aparece, em nenhum tipo de comunicacao.
  const { projetarComunicacao } = require("../lib/comunicacao.js");
  for (const tipo of ["texto_privado", "fala_catalogada", "evento_de_sistema"]) {
    const p = projetarComunicacao({
      messageId: "m",
      canalId: "c",
      superficie: "mesa_de_partida",
      ambiente: "mesa_publica",
      tipo,
      autorUid: tipo === "evento_de_sistema" ? null : "uidInterno",
      autorPublicId: tipo === "evento_de_sistema" ? null : "PUB",
      conteudo: "t",
      itemId: "emoji_joia_01",
      destinatarios: ["uidOutro"],
      silenciados: ["uidTerceiro"],
      enviadaEm: "2026-01-01T00:00:00.000Z",
      versaoDoCatalogo: 1,
      versaoDoContrato: 1,
      esquema: 1,
    });
    for (const proibido of ["autorUid", "destinatarios", "silenciados", "expiraEm"]) {
      assert.equal(proibido in p, false, tipo + " vazou " + proibido);
    }
    // Evento de sistema nao tem dono, e a AUSENCIA e o contrato.
    assert.equal(
      "autorPublicId" in p,
      tipo !== "evento_de_sistema",
      tipo + ": autorPublicId no lugar errado"
    );
    // Conteudo so em texto: numa fala catalogada a frase pronta mataria a
    // localizacao, porque o cliente renderizaria o texto que chegou.
    assert.equal("conteudo" in p, tipo === "texto_privado");
  }
});

// ===========================================================================
// CTA-B — uma autoridade, dois adaptadores
// ===========================================================================
test("CTA-B-01 existe UM nucleo, e os dois adaptadores o chamam", () => {
  const nucleos = [...CODIGO.matchAll(/async function executarEnvioDeMensagem\(/g)].length;
  assert.equal(nucleos, 1, "o nucleo do envio existe uma vez so");

  const motor = corpoDoExport(contrato.funcoes.enviarPeloMotor);
  assert.ok(
    motor.includes("executarEnvioDeMensagem("),
    "o adaptador do motor tem de chamar o nucleo"
  );
});

test("CTA-B-02 nenhum adaptador reimplementa a decisao", () => {
  // O defeito que a §10 nomeia: dois ingressos com implementacoes diferentes. A
  // versao frouxa seria a porta de abuso, e as duas divergiriam no primeiro
  // ajuste feito de um lado so.
  const proibidos = [
    'collection("blocks")',
    'collection("mutes")',
    "avaliarEnvioChat",
    "avaliarComunicacao",
    "C_MENSAGENS",
    "executarUmaVez",
    "projetarMensagem",
    "projetarComunicacao",
    "COL_ESTADO",
    "C_CANAIS",
    "C_RITMO",
  ];
  for (const nome of [
    contrato.funcoes.enviarPeloMotor,
    contrato.funcoes.ingressoDiretoDoJogador,
  ]) {
    const corpo = corpoDoExport(nome);
    for (const p of proibidos) {
      assert.equal(
        corpo.includes(p),
        false,
        nome + " toca `" + p + "` direto: a decisao saiu do nucleo"
      );
    }
  }
});

test("CTA-B-03 o nucleo e quem le bloqueio, sancao, canal e identidade", () => {
  // O espelho do caso acima: se o nucleo NAO fizer estas leituras, elas foram
  // para outro lugar — e o outro lugar e sempre um adaptador.
  const i = CODIGO.indexOf("async function executarEnvioDeMensagem(");
  const nucleo = CODIGO.slice(i, CODIGO.indexOf("export const ", i));
  for (const esperado of [
    'collection("blocks")',
    // `avaliarComunicacao` e a porta que ENVOLVE `avaliarEnvioChat` desde a OS
    // de Comunicacao Controlada. Exigir a antiga aqui seria exigir que o nucleo
    // chamasse o dominio do chat DIRETO — pulando a matriz da §2, que e a unica
    // coisa que impede texto livre fora da Mesa Privada.
    "avaliarComunicacao",
    'collection("mutes")',
    "C_CANAIS",
    "C_IDENTIDADES",
    "COL_ESTADO",
    "C_RITMO",
    "executarUmaVez",
    "projetarComunicacao",
  ]) {
    assert.ok(nucleo.includes(esperado), "o nucleo deveria conter " + esperado);
  }
});

test("CTA-B-04 so o adaptador do motor aceita autorUid do payload", () => {
  const motor = corpoDoExport(contrato.funcoes.enviarPeloMotor);
  const cliente = corpoDoExport(contrato.funcoes.ingressoDiretoDoJogador);

  // No motor isso e legitimo: o UID autenticado da chamada e o do MOTOR, e a
  // confianca vem do claim mais a conferencia de participacao feita pelo nucleo.
  assert.ok(motor.includes("dados.autorUid"), "o motor le autorUid do payload");
  assert.ok(motor.includes("exigirMotorOuAdmin("), "e exige o claim antes");

  // No ingresso do jogador isso seria falsificacao de remetente.
  assert.equal(cliente.includes("autorUid"), false);
});

test("CTA-B-05 autorUid sai da trava de campos SO na porta do motor", () => {
  // A trava do dominio recusa `autorUid` no payload. Na porta do motor o campo e
  // legitimo, entao ele e retirado da lista inspecionada — e SO ele. Se alguem
  // retirar `messageId` ou `enviadaEm` junto, o motor passaria a poder datar
  // mensagem para tras.
  const motor = corpoDoExport(contrato.funcoes.enviarPeloMotor);
  const filtros = [...motor.matchAll(/filter\(\(k\) => k !== "([^"]+)"\)/g)].map((m) => m[1]);
  assert.deepEqual(filtros, ["autorUid"]);
});

// ===========================================================================
// CTA-C — o ingresso direto do jogador esta fechado
// ===========================================================================
test("CTA-C-01 o ingresso direto recusa com codigo nomeado", () => {
  const cliente = corpoDoExport(contrato.funcoes.ingressoDiretoDoJogador);
  assert.ok(cliente.includes("ingressoDiretoDesativado"), "a recusa e nomeada");
  assert.ok(cliente.includes("exigirAutenticacao("), "e continua exigindo login");
  // NAO chama o nucleo: a mensagem nao nasce por este caminho.
  assert.equal(cliente.includes("executarEnvioDeMensagem("), false);
});

test("CTA-C-02 a porta nao foi apagada em silencio", () => {
  // A §11 pede decisao documentada em vez de remocao: apagar o export mudaria a
  // superficie de deploy sem deixar rastro para quem chamasse amanha.
  assert.ok(CODIGO.includes("export const " + contrato.funcoes.ingressoDiretoDoJogador + " ="));
});

test("CTA-C-03 o transporte tem UM ingresso produtivo", () => {
  // Dois ingressos produtivos gravariam a MESMA mensagem com consequencias
  // diferentes: o do servidor grava e ENTREGA; o direto gravaria e nao entregaria,
  // porque ninguem estaria escutando por ele.
  const produtivos = [
    contrato.funcoes.enviarPeloMotor,
    contrato.funcoes.ingressoDiretoDoJogador,
  ].filter((nome) => corpoDoExport(nome).includes("executarEnvioDeMensagem("));
  assert.deepEqual(produtivos, [contrato.funcoes.enviarPeloMotor]);
});

// ===========================================================================
// CTA-D — o canal continua sendo do motor
// ===========================================================================
test("CTA-D-01 definirCanalDeChat exige o claim do motor", () => {
  const canal = corpoDoExport(contrato.funcoes.definirCanal);
  assert.ok(canal.includes("exigirMotorOuAdmin("));
  // O pedido tem os campos que o contrato declara.
  for (const campo of contrato.pedidoDefinirCanal.campos) {
    assert.ok(canal.includes(campo), "o canal deveria receber " + campo);
  }
});

test("CTA-D-02 o claim aceito e `motorDePartidas` ou `admin`", () => {
  // Mesma lista canonica de `app/lib/rastreabilidade/ingestao.dart`
  // (`ChamadorAutorizado.papeisDeAutoridade`). Um terceiro papel aqui seria uma
  // autoridade nova que ninguem declarou.
  const i = CODIGO.indexOf("function exigirMotorOuAdmin(");
  const corpo = CODIGO.slice(i, CODIGO.indexOf("\n}", i));
  assert.ok(corpo.includes("motorDePartidas"));
  assert.ok(corpo.includes("admin"));
  assert.ok(corpo.includes("permission-denied"));
});
