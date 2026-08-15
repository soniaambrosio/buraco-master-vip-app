/**
 * plano.test.js — A ORDEM, AS DEPENDENCIAS E A RECUSA.
 *
 * OS de Exclusao de Conta e Dados do Jogador v1.
 *
 * As tres coisas que este arquivo prova, e por que cada uma merece teste:
 *
 *   1. NENHUM ITEM ACIONAVEL FICOU FORA DO PLANO. A matriz pode estar completa
 *      e o plano ainda esquecer um item — e o esquecimento seria invisivel, - a
 *      exclusao terminaria "concluida" tendo deixado dado para tras.
 *
 *   2. AS DEPENDENCIAS DE ORDEM VALEM. Elas nao sao preferencia de estilo: sao
 *      o que separa uma exclusao retomavel de uma que se autossabota (apagar o
 *      mapa de identidade antes de usar o publicId, apagar as amizades antes de
 *      alcancar os espelhos).
 *
 *   3. A RECUSA POR TORNEIO OLHA OS DOIS LADOS. Inscricao ativa em edicao
 *      encerrada e historico e nao trava nada; recusar por ela deixaria contas
 *      antigas impossiveis de excluir para sempre.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  CAMPOS_DE_ALVO_PROIBIDOS,
  ETAPAS,
  RECUSA,
  STATUS_INSCRICAO_ATIVA,
  camposDeAlvoNoPayload,
  decidirElegibilidade,
  etapasPendentes,
  itensAcionaveisForaDoPlano,
  itensDaEtapa,
} = require("../lib/plano");

const posicao = (id) => ETAPAS.findIndex((e) => e.id === id);
const antesDe = (a, b) => posicao(a) < posicao(b);

describe("cobertura do plano", () => {
  test("todo item acionavel da matriz esta em alguma etapa", () => {
    const esquecidos = itensAcionaveisForaDoPlano();
    assert.deepEqual(
      esquecidos,
      [],
      "itens classificados para acao e ausentes de ETAPAS: " + esquecidos.join(", ")
    );
  });

  test("nenhuma etapa aponta para item que nao existe", () => {
    // `itensDaEtapa` lanca nesse caso. Chamar todas e o que transforma um erro
    // de digitacao num id em falha de teste, e nao em etapa que nao faz nada.
    for (const etapa of ETAPAS) {
      assert.doesNotThrow(() => itensDaEtapa(etapa), etapa.id);
    }
  });

  test("nenhum item e realizado por duas etapas", () => {
    const vistos = new Map();
    for (const etapa of ETAPAS) {
      for (const id of etapa.itens) {
        assert.ok(
          !vistos.has(id),
          `${id} aparece em '${vistos.get(id)}' e em '${etapa.id}'`
        );
        vistos.set(id, etapa.id);
      }
    }
  });

  test("toda etapa tem id unico e resumo", () => {
    const ids = new Set();
    for (const etapa of ETAPAS) {
      assert.ok(!ids.has(etapa.id), `etapa repetida: ${etapa.id}`);
      ids.add(etapa.id);
      assert.ok(etapa.resumo.trim().length >= 40, `etapa ${etapa.id} sem resumo`);
    }
  });
});

describe("as dependencias de ordem", () => {
  test("trancar a conta e a PRIMEIRA etapa", () => {
    // Sem isso, o jogador continua agindo enquanto os dados dele saem: uma
    // solicitacao de amizade aceita no meio recria a projecao recem-apagada.
    assert.equal(ETAPAS[0].id, "trancar");
  });

  test("apagar o Authentication e a ULTIMA etapa", () => {
    // E a unica escrita irreversivel e a unica que destroi a chave de retomada.
    assert.equal(ETAPAS[ETAPAS.length - 1].id, "encerrar");
  });

  test("o ranking e neutralizado ANTES de a identidade ser cortada", () => {
    // As linhas de ranking sao alcancadas pelo publicId, e o publicId vem de
    // `playerIdentities`, que a etapa `identidade` apaga.
    assert.ok(antesDe("ranking", "identidade"), "ranking precisa vir antes de identidade");
  });

  test("o social roda antes de o documento raiz do jogador ser apagado", () => {
    // A etapa social le e apaga subcolecoes de `users/{uid}`.
    assert.ok(antesDe("social", "perfil"));
  });

  test("o billing roda antes de o Authentication ser apagado", () => {
    // Desvincular `compras` depois de a conta sumir ainda funcionaria, mas a
    // retomada nao: sem conta, nao ha quem chame de novo.
    assert.ok(antesDe("billing", "encerrar"));
  });

  test("todas as etapas de dado ficam entre trancar e encerrar", () => {
    const primeiro = 0;
    const ultimo = ETAPAS.length - 1;
    ETAPAS.forEach((etapa, i) => {
      if (i === primeiro || i === ultimo) return;
      assert.ok(etapa.itens.length > 0, `etapa '${etapa.id}' no meio e nao faz nada`);
    });
  });
});

describe("retomada", () => {
  test("sem nada concluido, todas as etapas estao pendentes", () => {
    assert.equal(etapasPendentes([]).length, ETAPAS.length);
  });

  test("etapa concluida nao volta a ser pendente", () => {
    const pendentes = etapasPendentes(["trancar", "social"]).map((e) => e.id);
    assert.ok(!pendentes.includes("trancar"));
    assert.ok(!pendentes.includes("social"));
    assert.equal(pendentes.length, ETAPAS.length - 2);
  });

  test("a ordem das pendentes e a ordem do plano", () => {
    // Retomar fora de ordem quebraria as mesmas dependencias provadas acima.
    const pendentes = etapasPendentes(["social"]).map((e) => e.id);
    const esperado = ETAPAS.map((e) => e.id).filter((id) => id !== "social");
    assert.deepEqual(pendentes, esperado);
  });

  test("tudo concluido nao deixa pendencia", () => {
    assert.deepEqual(etapasPendentes(ETAPAS.map((e) => e.id)), []);
  });

  test("etapa desconhecida na lista de concluidas nao atrapalha", () => {
    // Um diario gravado por uma versao anterior pode citar etapa que nao existe
    // mais. Ignorar e o comportamento certo; travar deixaria a conta em limbo.
    assert.equal(etapasPendentes(["etapaQueNaoExisteMais"]).length, ETAPAS.length);
  });
});

describe("recusa por torneio em andamento", () => {
  const emAndamento = {
    tournamentId: "t1",
    editionId: "e1",
    status: "inscrito",
    statusEdicao: "inscricoes_abertas",
  };

  test("sem inscricoes, pode excluir", () => {
    const v = decidirElegibilidade([]);
    assert.equal(v.pode, true);
    assert.equal(v.recusa, null);
  });

  test("inscricao ativa em edicao aberta recusa", () => {
    const v = decidirElegibilidade([emAndamento]);
    assert.equal(v.pode, false);
    assert.equal(v.recusa, RECUSA.TORNEIO_EM_ANDAMENTO);
    assert.equal(v.bloqueios.length, 1);
  });

  test("a recusa NOMEIA as inscricoes que travaram", () => {
    // "Cancele suas inscricoes" sem dizer quais manda a pessoa procurar.
    const v = decidirElegibilidade([emAndamento]);
    assert.equal(v.bloqueios[0].tournamentId, "t1");
    assert.equal(v.bloqueios[0].editionId, "e1");
  });

  test("inscricao ativa em edicao ENCERRADA nao trava", () => {
    // E historico: nao ha cadeira a liberar. Recusar por ela deixaria toda conta
    // com passado competitivo impossivel de excluir.
    for (const statusEdicao of ["encerrada", "concluida", "cancelada"]) {
      const v = decidirElegibilidade([{ ...emAndamento, statusEdicao }]);
      assert.equal(v.pode, true, statusEdicao);
    }
  });

  test("inscricao cancelada, ausente ou desclassificada nao trava", () => {
    // Sao exatamente os tres estados que `StatusInscricao.ativo` exclui — a vaga
    // ja voltou ao bolo.
    for (const status of ["cancelado", "ausente", "desclassificado"]) {
      const v = decidirElegibilidade([{ ...emAndamento, status }]);
      assert.equal(v.pode, true, status);
    }
  });

  test("todos os estados ativos travam", () => {
    for (const status of STATUS_INSCRICAO_ATIVA) {
      const v = decidirElegibilidade([{ ...emAndamento, status }]);
      assert.equal(v.pode, false, status);
    }
  });

  test("uma inscricao livre nao salva outra travada", () => {
    const v = decidirElegibilidade([
      { ...emAndamento, statusEdicao: "encerrada" },
      emAndamento,
    ]);
    assert.equal(v.pode, false);
    assert.equal(v.bloqueios.length, 1);
  });
});

describe("tentativa contra UID de terceiro", () => {
  test("payload limpo passa", () => {
    for (const limpo of [undefined, null, {}, { confirmacao: "EXCLUIR" }]) {
      assert.deepEqual(camposDeAlvoNoPayload(limpo), [], JSON.stringify(limpo));
    }
  });

  test("qualquer nome de alvo e detectado", () => {
    // Nao basta cobrir `uid`: quem tenta apagar a conta de outra pessoa tenta os
    // nomes que o resto do sistema usa.
    for (const campo of CAMPOS_DE_ALVO_PROIBIDOS) {
      const achados = camposDeAlvoNoPayload({ [campo]: "uid-da-vitima" });
      assert.deepEqual(achados, [campo]);
    }
  });

  test("alvo nulo tambem conta como tentativa", () => {
    // Mandar `uid: null` e mandar o campo. So a AUSENCIA e ausencia.
    assert.deepEqual(camposDeAlvoNoPayload({ uid: null }), ["uid"]);
  });

  test("varios alvos de uma vez sao todos reportados", () => {
    const achados = camposDeAlvoNoPayload({ uid: "a", publicId: "P0", confirmacao: "EXCLUIR" });
    assert.deepEqual([...achados].sort(), ["publicId", "uid"]);
  });

  test("payload que nao e objeto nao derruba a conferencia", () => {
    for (const lixo of ["texto", 7, true, []]) {
      assert.deepEqual(camposDeAlvoNoPayload(lixo), [], JSON.stringify(lixo));
    }
  });

  test("a lista cobre publicId — o alvo que NAO e um UID", () => {
    // O cliente so fala em publicId (§13/§21 do contrato social). Se alguem
    // fosse tentar nomear outra conta, tentaria com o identificador que ele
    // conhece — e nao com o UID, que ele nunca ve.
    assert.ok(CAMPOS_DE_ALVO_PROIBIDOS.includes("publicId"));
  });
});

describe("o codebase nao le identidade do payload", () => {
  test("nenhuma rota tira uid de req.data", () => {
    // Prova de AUSENCIA, entao le codigo-fonte — mesma tecnica de
    // functions-ranking/test/identidade.test.js. Um teste de comportamento nao
    // pegaria isto: a rota que passasse a aceitar `req.data.uid` teria nome novo
    // e nenhum teste existente a chamaria.
    const raiz = path.join(__dirname, "..", "src");
    const fontes = fs
      .readdirSync(raiz)
      .filter((f) => f.endsWith(".ts"))
      .map((f) => ({ arquivo: f, texto: fs.readFileSync(path.join(raiz, f), "utf8") }));

    // Sem comentarios: este codebase documenta densamente, e os comentarios
    // falam justamente sobre `req.data.uid` para explicar que ele e recusado.
    const semComentarios = (t) =>
      t
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .split("\n")
        .map((l) => l.replace(/\/\/.*$/, ""))
        .join("\n");

    const proibido = /req\.data\??\.\s*(uid|userId|publicId)/;
    for (const { arquivo, texto } of fontes) {
      assert.ok(
        !proibido.test(semComentarios(texto)),
        `${arquivo} le identidade do payload — o UID vem de req.auth.uid, sempre`
      );
    }
  });

  test("o executor recebe o uid por parametro, e nao o descobre", () => {
    const executor = fs.readFileSync(
      path.join(__dirname, "..", "src", "executor.ts"),
      "utf8"
    );
    assert.ok(
      /export async function executar\(uid: string\)/.test(executor),
      "a assinatura de `executar` mudou; confira que o uid continua vindo de fora"
    );
    assert.ok(
      !/req\.|CallableRequest/.test(executor),
      "o executor nao pode conhecer o pedido — quem atende e index.ts"
    );
  });
});

describe("espelho dos estados de inscricao", () => {
  test("STATUS_INSCRICAO_ATIVA bate com StatusInscricao.ativo do dominio Dart", () => {
    // Os codebases sao unidades de implantacao separadas e nao compartilham
    // pacote, entao a lista e repetida aqui. Repeticao sem conferencia envelhece:
    // um estado novo em registrations.dart passaria a ser tratado como INATIVO
    // neste codebase, e uma conta com torneio em andamento seria excluida.
    //
    // Mesma tecnica de functions-ranking/test/identidade.test.js, que le o
    // arquivo do vizinho para provar que os nomes ainda batem.
    const dart = fs.readFileSync(
      path.join(__dirname, "..", "..", "app", "lib", "torneios", "registrations.dart"),
      "utf8"
    );

    const bloco = dart.slice(
      dart.indexOf("enum StatusInscricao {"),
      dart.indexOf("final String wire;")
    );
    assert.ok(bloco.length > 0, "nao achei o enum StatusInscricao no arquivo Dart");

    // `nome('wire')` — o valor de fio de cada estado.
    const todos = [...bloco.matchAll(/^\s*[a-zA-Z]+\('([a-z_]+)'\)/gm)].map((m) => m[1]);
    assert.ok(todos.length >= 10, `achei so ${todos.length} estados no Dart`);

    // `ativo` no Dart e "nao e cancelado, ausente nem desclassificado".
    const inativos = new Set(["cancelado", "ausente", "desclassificado"]);
    const esperado = todos.filter((s) => !inativos.has(s)).sort();

    assert.deepEqual(
      [...STATUS_INSCRICAO_ATIVA].sort(),
      esperado,
      "STATUS_INSCRICAO_ATIVA divergiu de app/lib/torneios/registrations.dart"
    );
  });
});
