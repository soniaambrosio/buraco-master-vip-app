/**
 * comunicacao.test.js — a PROJECAO, a EVIDENCIA e a RETENCAO.
 *
 * Roda sobre o modulo JA COMPILADO (`lib/comunicacao.js`), com `node --test`, sem
 * emulador e sem `dart compile js`. E a mesma disciplina de `chat.test.js`: o que
 * e puro se prova barato, e o que exige servidor fica na suite de emulador.
 *
 * O QUE ESTE ARQUIVO GUARDA, e nao e verificavel por revisao:
 *
 *   1. A PROJECAO NAO VAZA. `autorUid`, `destinatarios` e `silenciados` existem
 *      no documento e nao podem existir na entrega. O terceiro e o mais
 *      perigoso dos tres: ele diria a quem recebe QUEM silenciou o autor.
 *
 *   2. A FALA CATALOGADA NAO VIAJA COMO FRASE. Se `conteudo` aparecesse numa
 *      projecao de catalogo, o cliente renderizaria o texto que chegou em vez da
 *      chave — e a localizacao da §6.3 morreria sem ninguem perceber, porque em
 *      portugues o resultado na tela seria identico.
 *
 *   3. A EVIDENCIA DE ITEM CATALOGADO PRESERVA A REPETICAO. Uma fala aprovada
 *      nunca e ofensiva por si; o que ofende e mandar doze em vinte segundos. A
 *      evidencia que guardasse so o id nao mostraria o abuso.
 */

"use strict";

const test = require("node:test");
const { describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  RETENCAO_DIAS,
  evidenciaDeItemCatalogado,
  expiraEmDe,
  projetarComunicacao,
  registroSeguro,
  tipoDe,
} = require("../lib/comunicacao.js");

const ENVIADA_EM = "2026-08-20T12:00:00.000Z";

function documento(extra = {}) {
  return Object.assign(
    {
      messageId: "m1",
      canalId: "canal1",
      superficie: "mesa_de_partida",
      ambiente: "mesa_privada",
      tipo: "texto_privado",
      autorUid: "uidInterno",
      autorPublicId: "BMV7K2MP4RC",
      conteudo: "boa jogada",
      itemId: null,
      chaveDeLocalizacao: null,
      fallbackOficial: null,
      destinatarios: ["uidOutro", "uidTerceiro"],
      silenciados: ["uidQuarto"],
      enviadaEm: ENVIADA_EM,
      expiraEm: "2026-09-19T12:00:00.000Z",
      versaoDoCatalogo: 1,
      versaoDoContrato: 1,
      esquema: 1,
    },
    extra
  );
}

describe("COM-A — a projecao nao vaza", () => {
  test("COM-A-01 os tres campos internos nunca saem", () => {
    const p = projetarComunicacao(documento());
    for (const proibido of ["autorUid", "destinatarios", "silenciados", "expiraEm"]) {
      assert.equal(proibido in p, false, "vazou " + proibido);
    }
  });

  test("COM-A-02 o autor sai como identidade PUBLICA", () => {
    const p = projetarComunicacao(documento());
    assert.equal(p.autorPublicId, "BMV7K2MP4RC");
    assert.equal(JSON.stringify(p).includes("uidInterno"), false);
  });

  test("COM-A-03 a lista de campos e FECHADA, e nao uma remocao", () => {
    // Um campo novo no documento nao pode aparecer na entrega por construcao.
    // Este caso e o que transforma "esqueci de apagar" em erro de teste.
    const p = projetarComunicacao(
      documento({ ipDeOrigem: "203.0.113.7", segredoInterno: "x" })
    );
    assert.equal("ipDeOrigem" in p, false);
    assert.equal("segredoInterno" in p, false);
  });

  test("COM-A-04 a entrega passa pela TRAVA, e a trava sabe reprovar", () => {
    // DUAS METADES, e as duas importam.
    //
    // (a) o que sai daqui esta limpo pelo criterio da propria trava. Nao e
    //     tautologia: `caminhosProibidos` varre EM PROFUNDIDADE, e a projecao
    //     copia campos que um dia podem deixar de ser texto.
    const { caminhosProibidos, exigirEntregaSegura } = require("../lib/chat.js");
    for (const tipo of ["texto_privado", "fala_catalogada", "evento_de_sistema"]) {
      const p = projetarComunicacao(documento({ tipo }));
      assert.deepEqual(caminhosProibidos(p), [], tipo);
    }

    // (b) a trava que a projecao usa reprova de verdade. Se ela aceitasse
    //     qualquer coisa, a metade (a) passaria por vacuidade — que e o modo
    //     classico de um teste de seguranca mentir.
    assert.throws(
      () => exigirEntregaSegura({ mensagem: { canal: { destinatarios: ["uidX"] } } }),
      /entrega de chat carrega dado privado/
    );
  });

  test("COM-A-05 metadado que nao e texto NAO entra na entrega", () => {
    // Fail-closed na copia: um documento com `chaveDeLocalizacao` estruturada
    // (defeito de escrita, ou tentativa de embutir objeto na projecao) perde o
    // campo em vez de leva-lo adiante.
    const p = projetarComunicacao(
      documento({
        tipo: "fala_catalogada",
        itemId: "elogiar_boa_jogada_01",
        chaveDeLocalizacao: { destinatarios: ["uidX"] },
        fallbackOficial: 42,
      })
    );
    assert.equal("chaveDeLocalizacao" in p, false);
    assert.equal("fallbackOficial" in p, false);
    assert.equal(p.itemId, "elogiar_boa_jogada_01");
  });
});

describe("COM-B — cada tipo projeta o que lhe cabe", () => {
  test("COM-B-01 texto privado leva `conteudo` e nao leva item", () => {
    const p = projetarComunicacao(documento());
    assert.equal(p.conteudo, "boa jogada");
    assert.equal("itemId" in p, false);
  });

  test("COM-B-02 fala catalogada leva id + chave + fallback, e NAO leva frase", () => {
    const p = projetarComunicacao(
      documento({
        tipo: "fala_catalogada",
        conteudo: null,
        itemId: "elogiar_boa_jogada_01",
        chaveDeLocalizacao: "comunicacao.fala.elogiar_boa_jogada_01",
        fallbackOficial: "Boa jogada!",
      })
    );
    assert.equal(p.itemId, "elogiar_boa_jogada_01");
    assert.equal(p.chaveDeLocalizacao, "comunicacao.fala.elogiar_boa_jogada_01");
    assert.equal(p.fallbackOficial, "Boa jogada!");
    assert.equal("conteudo" in p, false);
  });

  test("COM-B-03 conteudo GRAVADO num catalogado ainda assim nao viaja", () => {
    // Defesa contra o documento incoerente: se algum caminho gravasse a frase
    // num item catalogado, a projecao continuaria mandando so a chave.
    const p = projetarComunicacao(
      documento({
        tipo: "fala_catalogada",
        conteudo: "Boa jogada!",
        itemId: "elogiar_boa_jogada_01",
      })
    );
    assert.equal("conteudo" in p, false);
  });

  test("COM-B-04 evento de sistema NAO tem autor", () => {
    const p = projetarComunicacao(
      documento({
        tipo: "evento_de_sistema",
        autorUid: null,
        autorPublicId: null,
        conteudo: null,
        itemId: "sistema_presente_disponivel",
        chaveDeLocalizacao: "comunicacao.sistema.presente_disponivel",
        fallbackOficial: "Pegue seu presente!",
      })
    );
    assert.equal("autorPublicId" in p, false);
    assert.equal(p.fallbackOficial, "Pegue seu presente!");
  });

  test("COM-B-05 documento anterior a esta OS e lido como texto privado", () => {
    // Nao ha migracao de historico. O documento antigo nao tem `tipo`, e todo
    // documento antigo era texto de mesa — era a unica coisa que existia.
    assert.equal(tipoDe({}), "texto_privado");
    assert.equal(tipoDe({ tipo: null }), "texto_privado");
    assert.equal(tipoDe({ tipo: "" }), "texto_privado");
    assert.equal(tipoDe({ tipo: "fala_catalogada" }), "fala_catalogada");
  });
});

describe("COM-C — retencao (§7.5)", () => {
  test("COM-C-01 a expiracao deriva do envio, e nao do relogio de quem chama", () => {
    const expira = expiraEmDe(ENVIADA_EM);
    const dias = (Date.parse(expira) - Date.parse(ENVIADA_EM)) / 86400000;
    assert.equal(dias, RETENCAO_DIAS);
    // Duas chamadas para a MESMA mensagem tem de dar o mesmo valor: o documento
    // relido num retry nao pode expirar noutro dia.
    assert.equal(expiraEmDe(ENVIADA_EM), expira);
  });

  test("COM-C-02 envio invalido nao produz retencao silenciosa", () => {
    // Um `expiraEm` calculado sobre lixo viraria `Invalid Date` e o documento
    // ficaria sem prazo — retencao indefinida por acidente, que e exatamente o
    // que a §7.5 proibe.
    assert.throws(() => expiraEmDe("ontem"), /retencao/);
  });
});

describe("COM-D — evidencia de item catalogado (§9.5)", () => {
  const doc = {
    messageId: "m9",
    canalId: "canal1",
    ambiente: "mesa_publica",
    tipo: "fala_catalogada",
    autorUid: "uidAbusivo",
    itemId: "provocar_essa_doeu_01",
    enviadaEm: "2026-08-20T12:00:30.000Z",
    versaoDoCatalogo: 1,
    esquema: 1,
    destinatarios: [],
  };

  test("COM-D-01 preserva id, versao, quantidade e PADRAO", () => {
    const e = evidenciaDeItemCatalogado(doc, [
      { enviadaEm: "2026-08-20T12:00:10.000Z" },
      { enviadaEm: "2026-08-20T12:00:20.000Z" },
      { enviadaEm: "2026-08-20T12:00:30.000Z" },
    ]);
    assert.equal(e.origem, "servidor");
    assert.equal(e.itemId, "provocar_essa_doeu_01");
    assert.equal(e.versaoDoCatalogo, 1);
    assert.equal(e.repeticoes, 3);
    // Ordenados: o padrao e o que distingue uso de inundacao.
    assert.deepEqual(e.instantes, [
      "2026-08-20T12:00:10.000Z",
      "2026-08-20T12:00:20.000Z",
      "2026-08-20T12:00:30.000Z",
    ]);
  });

  test("COM-D-02 o autor sai do DOCUMENTO", () => {
    // Sem isso, denunciar a fala de A afirmando que e de B gravaria evidencia
    // acusando B. O mesmo cuidado que a evidencia de texto ja tomava.
    const e = evidenciaDeItemCatalogado(doc);
    assert.equal(e.autorUid, "uidAbusivo");
  });

  test("COM-D-03 a evidencia NAO carrega texto nenhum", () => {
    const e = evidenciaDeItemCatalogado(doc, [{ enviadaEm: doc.enviadaEm }]);
    const json = JSON.stringify(e);
    assert.equal(json.includes("conteudo"), false);
    assert.equal(json.includes("fallback"), false);
  });

  test("COM-D-04 sem documento, sobra a referencia — e nada mais", () => {
    const e = evidenciaDeItemCatalogado(null);
    assert.equal(e.origem, "referencia");
    assert.equal(e.itemId, null);
    assert.equal(e.messageId, null);
  });
});

describe("COM-E — o log tecnico (§11)", () => {
  test("COM-E-01 nao ha campo por onde texto de jogador entre no log", () => {
    const r = registroSeguro({
      canalId: "canal1",
      ambiente: "mesa_privada",
      tipo: "texto_privado",
      recusa: "conteudoVazio",
      destinatarios: 3,
      silenciados: 1,
      // Campos que NAO existem na assinatura: sao descartados.
      conteudo: "segredo do jogador",
      autorUid: "uidInterno",
    });
    const json = JSON.stringify(r);
    assert.equal(json.includes("segredo"), false);
    assert.equal(json.includes("uidInterno"), false);
    assert.equal(r.destinatarios, 3);
  });

  test("COM-E-02 `itemId` PODE ir para o log", () => {
    // Ele e identificador de catalogo, publico e igual para todo mundo. Sem ele
    // nao ha como investigar abuso de fala pronta a partir do log.
    const r = registroSeguro({ itemId: "provocar_essa_doeu_01" });
    assert.equal(r.itemId, "provocar_essa_doeu_01");
  });
});
