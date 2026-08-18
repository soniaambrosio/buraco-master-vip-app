/**
 * Prova a projecao, a trava de vazamento e a evidencia de denuncia do chat —
 * logica pura, sem Firestore e sem `dart compile js`.
 *
 * POR QUE ESTE ARQUIVO EXISTE, e o que ele NAO prova.
 *
 * A OS do Chat Livre Seguro pede tres coisas em §13 que uma revisao de codigo nao
 * garante: que a mensagem entregue nao carregue UID interno, que nao carregue
 * token/socket/IP, e que o teste da projecao seja ESTRUTURAL e nao "um fixture
 * bonitinho". Um teste que so conferisse um objeto montado a mao provaria que
 * aquele objeto esta limpo — nao que o proximo campo acrescentado tambem estara. O
 * que se prova aqui e a TRAVA: `exigirEntregaSegura` erra quando devia errar, em
 * profundidade e dentro de lista.
 *
 * A §12 (evidencia de denuncia) tambem mora aqui, e pelo mesmo motivo que
 * `decidirSobreReserva` mora em `idempotencia.test.js`: a regra foi escrita pura
 * (`evidenciaDeMensagem` recebe o documento como DADO, nao vai ao banco), entao os
 * tres desfechos — servidor, cliente atestada, referencia — sao provaveis sem
 * emulador.
 *
 * O QUE NAO ESTA AQUI, de proposito: autenticacao, transacao, retry real e
 * concorrencia. Essas dependem do servidor, e ficam em
 * `test/integracao.chat.emulador.test.js`. A decisao de ENVIO (conteudo, bloqueio,
 * sancao, superficie) tambem nao esta aqui: ela e do dominio Dart, e e provada por
 * `app/test/chat/chat_test.dart`. Reimplementar aquelas regras em JavaScript para
 * "testar melhor" criaria a segunda implementacao que o bridge existe para evitar.
 */

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  CHAVES_PROIBIDAS_NA_ENTREGA,
  ORIGEM_EVIDENCIA,
  VazamentoDeChat,
  caminhosProibidos,
  evidenciaDeMensagem,
  exigirEntregaSegura,
  projetarMensagem,
} = require("../lib/chat.js");

const { decidirSobreReserva, ACAO_RESERVA } = require("../lib/idempotency.js");

const AUTOR = "uidAutor";
const OUTRO = "uidOutro";
const MSG_ID = "d0d9544f7185ad8d945ce892865a471c";

/** O documento como a autoridade o grava. */
function documento(extra = {}) {
  return {
    messageId: MSG_ID,
    canalId: "sala7",
    superficie: "mesa_de_partida",
    autorUid: AUTOR,
    autorPublicId: "BMV-7K2M",
    conteudo: "boa jogada",
    destinatarios: [OUTRO],
    enviadaEm: "2026-08-18T00:00:00.000Z",
    esquema: 1,
    ...extra,
  };
}

// ===========================================================================
// PROJECAO (§13)
// ===========================================================================

test("PRJ-01 a projecao nao carrega autorUid nem destinatarios", () => {
  const p = projetarMensagem(documento());

  assert.equal(p.autorUid, undefined);
  assert.equal(p.destinatarios, undefined);
  // E nao basta o campo faltar: o valor tambem nao pode aparecer noutro campo.
  assert.ok(!JSON.stringify(p).includes(AUTOR));
  assert.ok(!JSON.stringify(p).includes(OUTRO));
});

test("PRJ-02 a projecao tem EXATAMENTE os campos previstos", () => {
  // Lista fechada. Um campo novo reprova aqui e obriga quem o acrescentou a
  // justifica-lo — e o que impede o vazamento por acrescimo.
  assert.deepEqual(Object.keys(projetarMensagem(documento())).sort(), [
    "autorPublicId",
    "canalId",
    "conteudo",
    "enviadaEm",
    "esquema",
    "messageId",
    "superficie",
  ]);
});

test("PRJ-03 campo novo no documento NAO vaza para a projecao", () => {
  // O caso que distingue lista de PERMISSAO de remocao de campos proibidos. Um
  // `delete resposta.autorUid` deixaria `ipDeOrigem` passar; a lista de permissao
  // nao deixa, e nem precisa saber que o campo existe.
  const p = projetarMensagem(
    documento({ ipDeOrigem: "203.0.113.7", socketId: "sk-1", debug: { autorUid: AUTOR } })
  );
  assert.equal(p.ipDeOrigem, undefined);
  assert.equal(p.socketId, undefined);
  assert.equal(p.debug, undefined);
  assert.ok(!JSON.stringify(p).includes("203.0.113.7"));
});

test("PRJ-04 o conteudo do jogador atravessa intacto", () => {
  // Texto opaco: nada de escapar, nada de sanitizar, nada de interpretar. O que
  // ele escreveu e o que a evidencia da denuncia vai mostrar.
  const rico = 'É isso! 🎉 <b>bold</b> [link](http://x) & "aspas"';
  assert.equal(projetarMensagem(documento({ conteudo: rico })).conteudo, rico);
});

test("PRJ-05 a projecao nao anuncia marcacao ativa", () => {
  // §6: HTML, Markdown e link nao sao executados. A ausencia de campo que sugira
  // marcacao e contrato — um `formato: "html"` convidaria o primeiro renderizador
  // a interpretar texto escrito por outro jogador.
  const chaves = Object.keys(projetarMensagem(documento())).map((k) => k.toLowerCase());
  for (const suspeito of ["html", "markdown", "rich", "formato", "render"]) {
    assert.ok(
      !chaves.some((k) => k.includes(suspeito)),
      `projecao anuncia ${suspeito}`
    );
  }
});

// ===========================================================================
// A TRAVA (§13)
// ===========================================================================

test("TRV-01 exigirEntregaSegura devolve o que esta limpo", () => {
  const limpo = { messageId: MSG_ID, conteudo: "oi" };
  assert.equal(exigirEntregaSegura(limpo), limpo);
});

test("TRV-02 exigirEntregaSegura LANCA em vazamento de topo", () => {
  assert.throws(() => exigirEntregaSegura({ autorUid: AUTOR }), VazamentoDeChat);
  // Falhar a chamada e melhor que entregar o UID: o jogador ve um erro e ninguem
  // coleta identidade interna enquanto o defeito nao e corrigido.
  assert.throws(() => exigirEntregaSegura({ uid: AUTOR }), VazamentoDeChat);
});

test("TRV-03 a trava acha vazamento EM PROFUNDIDADE", () => {
  // O vazamento real quase nunca esta no topo: ele esta um nivel abaixo de onde
  // alguem olharia numa revisao.
  const sujo = {
    mensagem: { messageId: MSG_ID },
    canal: { canalId: "sala7", participantes: [AUTOR, OUTRO] },
  };
  assert.deepEqual(caminhosProibidos(sujo), ["canal.participantes"]);
  assert.throws(() => exigirEntregaSegura(sujo), VazamentoDeChat);
});

test("TRV-04 a trava acha vazamento dentro de LISTA", () => {
  const sujo = { mensagens: [{ messageId: MSG_ID }, { autorUid: AUTOR }] };
  assert.deepEqual(caminhosProibidos(sujo), ["mensagens[1].autorUid"]);
});

test("TRV-05 a trava carrega os CAMINHOS, para o log dizer onde", () => {
  try {
    exigirEntregaSegura({ a: { token: "x" }, b: { ip: "y" } });
    assert.fail("devia ter lancado");
  } catch (e) {
    assert.ok(e instanceof VazamentoDeChat);
    assert.deepEqual(e.caminhos.sort(), ["a.token", "b.ip"]);
    assert.equal(e.name, "VazamentoDeChat");
  }
});

test("TRV-06 transporte e estado administrativo estao na trava", () => {
  // §13 nomeia o que nao pode sair: UID, IP, token, socket id, e-mail, estado
  // administrativo, lista de bloqueios, sancao de terceiro.
  for (const campo of [
    "uid",
    "autorUid",
    "email",
    "token",
    "idToken",
    "ip",
    "remoteAddress",
    "socketId",
    "sessionId",
    "playerModeration",
    "chatSilenciadoAte",
    "suspensoAte",
    "suspensaoPermanente",
    "blocks",
    "sanctions",
    "entitlements",
    "cpf",
  ]) {
    assert.ok(CHAVES_PROIBIDAS_NA_ENTREGA.has(campo), `${campo} fora da trava`);
    assert.deepEqual(caminhosProibidos({ [campo]: "x" }), [campo]);
  }
});

test("TRV-07 a trava nao recusa os campos legitimos da mensagem", () => {
  // O contrario dos casos acima: uma trava que recusasse a propria projecao
  // quebraria producao em vez de proteger.
  assert.deepEqual(caminhosProibidos(projetarMensagem(documento())), []);
});

// ===========================================================================
// EVIDENCIA DE DENUNCIA (§12)
// ===========================================================================

test("EVD-01 mensagem existente no servidor: origem SERVIDOR", () => {
  const e = evidenciaDeMensagem(
    { messageId: MSG_ID, roomId: "sala7", denunciadoUid: AUTOR },
    documento()
  );
  assert.equal(e.origem, ORIGEM_EVIDENCIA.SERVIDOR);
  assert.equal(e.origem, "servidor");
  assert.equal(e.conteudo, "boa jogada");
  assert.equal(e.messageId, MSG_ID);
  assert.equal(e.canalId, "sala7");
});

test("EVD-02 a copia do cliente e DESCARTADA quando o servidor tem a mensagem", () => {
  // Aceitar as duas criaria duas versoes do mesmo fato, e a divergencia entre elas
  // seria decidida por quem lesse o registro depois.
  const e = evidenciaDeMensagem(
    {
      messageId: MSG_ID,
      denunciadoUid: AUTOR,
      atestadaPeloCliente: {
        conteudo: "TEXTO INVENTADO PELO DENUNCIANTE",
        enviadaEm: "1999-01-01T00:00:00.000Z",
      },
    },
    documento()
  );
  assert.equal(e.origem, "servidor");
  assert.equal(e.conteudo, "boa jogada");
  assert.equal(e.enviadaEm, "2026-08-18T00:00:00.000Z");
});

test("EVD-03 o autor vem do DOCUMENTO, nao de denunciadoUid", () => {
  // Sem isto, denunciar a mensagem de A dizendo que ela e de B gravaria uma
  // evidencia que acusa B do que A escreveu.
  const e = evidenciaDeMensagem(
    { messageId: MSG_ID, denunciadoUid: "uidInocente" },
    documento({ autorUid: AUTOR })
  );
  assert.equal(e.autorUid, AUTOR);
  assert.notEqual(e.autorUid, "uidInocente");
});

test("EVD-04 sem mensagem no servidor, cliente_atestada SOBREVIVE", () => {
  // A compatibilidade que a §12 manda delimitar em vez de apagar em silencio:
  // vale para as superficies sem mensagem autoritativa e para o historico ja
  // gravado, que nao se migra.
  const e = evidenciaDeMensagem(
    {
      messageId: "msg-legado",
      roomId: "sala-legado",
      denunciadoUid: AUTOR,
      atestadaPeloCliente: { conteudo: "o que ele disse", enviadaEm: null },
    },
    null
  );
  assert.equal(e.origem, ORIGEM_EVIDENCIA.CLIENTE);
  assert.equal(e.origem, "cliente_atestada");
  assert.equal(e.conteudo, "o que ele disse");
  assert.equal(e.autorUid, AUTOR);
});

test("EVD-05 sem mensagem e sem atestado: apenas REFERENCIA", () => {
  const e = evidenciaDeMensagem(
    { messageId: null, roomId: "sala7", denunciadoUid: AUTOR },
    null
  );
  assert.equal(e.origem, ORIGEM_EVIDENCIA.REFERENCIA);
  assert.equal(e.conteudo, undefined);
  assert.equal(e.messageId, null);
});

test("EVD-06 a origem e sempre um dos tres valores declarados", () => {
  // A moderacao humana precisa saber o peso do que esta lendo. Uma origem nova
  // sem declaracao tornaria o campo indecifravel para quem julga.
  const valores = new Set(Object.values(ORIGEM_EVIDENCIA));
  const casos = [
    evidenciaDeMensagem({ messageId: MSG_ID, denunciadoUid: AUTOR }, documento()),
    evidenciaDeMensagem(
      { messageId: "x", denunciadoUid: AUTOR, atestadaPeloCliente: { conteudo: "a" } },
      null
    ),
    evidenciaDeMensagem({ messageId: null, denunciadoUid: AUTOR }, null),
  ];
  for (const c of casos) assert.ok(valores.has(c.origem), c.origem);
  assert.equal(new Set(casos.map((c) => c.origem)).size, 3);
});

// ===========================================================================
// IDEMPOTENCIA DO CHAT SOBRE A BARREIRA EXISTENTE (§9)
// ===========================================================================

/** O pedido que `enviarMensagemChat` reserva. */
function pedido(extra = {}) {
  return {
    tarefa: "enviarMensagemChat",
    ator: AUTOR,
    alvo: "sala7",
    impressao: "d436b004234fda9e51085961ade1bca9",
    ...extra,
  };
}

test("IDE-01 chave livre: executa", () => {
  assert.equal(decidirSobreReserva(null, pedido()).acao, ACAO_RESERVA.EXECUTAR);
});

test("IDE-02 mesma chave e MESMO pedido: repeticao (retry nao duplica)", () => {
  const r = decidirSobreReserva(pedido(), pedido());
  assert.equal(r.acao, ACAO_RESERVA.REPETICAO);
});

test("IDE-03 mesma intencao com OUTRO texto: CONFLITO, nao sucesso silencioso", () => {
  // O defeito que a `impressao` existe para impedir: sem ela, reaproveitar o
  // `intentId` com outro texto encontraria a chave reservada e a autoridade
  // responderia sucesso sem gravar a mensagem nova — a mensagem pedida
  // desapareceria com uma confirmacao na mao de quem pediu.
  const r = decidirSobreReserva(pedido(), pedido({ impressao: "outro-digest" }));
  assert.equal(r.acao, ACAO_RESERVA.CONFLITO);
});

test("IDE-04 mesma intencao em OUTRO canal: CONFLITO", () => {
  const r = decidirSobreReserva(pedido(), pedido({ alvo: "sala9" }));
  assert.equal(r.acao, ACAO_RESERVA.CONFLITO);
});

test("IDE-05 a chave de chat nao se confunde com denuncia nem sancao", () => {
  // As tres tarefas compartilham a colecao `moderationTasks`. Se `tarefa` nao
  // entrasse na conferencia, um `messageId` que por acaso colidisse com um
  // `reportId` responderia sucesso para a operacao errada.
  for (const tarefa of ["registrarDenuncia", "aplicarSancao"]) {
    const r = decidirSobreReserva(pedido({ tarefa }), pedido());
    assert.equal(r.acao, ACAO_RESERVA.CONFLITO, tarefa);
  }
});

test("IDE-06 intencao de OUTRO autor na mesma chave: CONFLITO", () => {
  const r = decidirSobreReserva(pedido({ ator: OUTRO }), pedido());
  assert.equal(r.acao, ACAO_RESERVA.CONFLITO);
});
