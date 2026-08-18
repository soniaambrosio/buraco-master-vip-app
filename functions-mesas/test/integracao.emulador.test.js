/**
 * integracao.emulador.test.js — A TRANSACAO, CONTRA O FIRESTORE DE VERDADE.
 *
 * Os casos que NAO se provam com dobre de memoria, e por isso moram aqui:
 *
 *   24 .... falha antes da reserva nao consome o passe
 *   25 .... admissao confirmada consome
 *   26 .... retry idempotente nao consome de novo
 *   27 .... duas tentativas SIMULTANEAS produzem UM consumo
 *   33 .... abandono depois da admissao nao devolve o passe
 *   55-61 . regressao: contrato, formatos desconhecidos, sem debito duplo
 *
 * POR QUE UM FALSO DE MEMORIA NAO SERVE AQUI. Um Firestore de mentira
 * serializa transacoes do jeito que quem o escreveu imaginou. O que este
 * arquivo mede e justamente o que ninguem imagina certo: duas transacoes
 * disputando `passesVip/{uid}`, uma vencendo, a outra REEXECUTANDO e lendo o
 * documento ja alterado. Isso e comportamento do banco, nao do codigo — e so o
 * banco pode responder por ele.
 *
 * COMO RODAR (a partir da raiz, que e onde firebase.json mora):
 *
 *     npm --prefix functions-mesas run test:emulador
 *
 * `--only firestore`: nao ha Auth aqui. Este arquivo exercita o STORE
 * diretamente, sem passar pelo `onRequest` — a autenticacao tem prova propria,
 * e misturar as duas exigiria o emulador de Functions, cuja descoberta de
 * codebase e uma fonte de falha que nao tem nada a ver com o que se quer medir.
 */

const { test, describe, before, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const { criarStore, COL } = require("../lib/firestore");
const { FONTE, RECUSA } = require("../lib/decisao");
const { RECUSA_PASSE } = require("../lib/passe");

const T0 = "2026-08-01T12:00:00.000Z";
const DIA = 24 * 60 * 60 * 1000;
const em = (ms) => new Date(Date.parse(T0) + ms).toISOString();

let app;
let db;

/** Um relogio controlado. O store recebe `agora` por parametro, entao o teste
 *  manda no tempo sem tocar em `Date`. */
function relogio(instante = T0) {
  const estado = { agora: instante };
  return { estado, ler: () => estado.agora };
}

before(() => {
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "FIRESTORE_EMULATOR_HOST ausente: rode por `npm run test:emulador`, nunca contra producao",
  );
  app = initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-bmv" }, "mesas-teste");
  db = getFirestore(app);
});

/** Limpa so o que este arquivo escreve. */
async function limpar() {
  for (const colecao of Object.values(COL)) {
    const docs = await db.collection(colecao).listDocuments();
    await Promise.all(docs.map((d) => d.delete()));
  }
}

beforeEach(limpar);

async function darAssinatura(uid, ate = em(90 * DIA)) {
  await db.collection(COL.ENTITLEMENTS).doc(uid).set({ estado: "ativo", expiraEm: ate });
}

function pedido(extra = {}) {
  return {
    uidAutenticado: "uid_1",
    codigoDaSala: "BMV-AAAA-AAAA",
    identidadeDaPartida: null,
    assento: 0,
    categoriaCompetitiva: "vip_ranqueada",
    tentativaEntradaId: "te_1",
    reconexao: false,
    ...extra,
  };
}

// ===========================================================================

describe("INT — o consumo do passe", () => {
  test("INT-01 (caso 25) a admissao confirmada consome, na MESMA escrita", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });

    // A primeira consulta materializa a janela 0.
    const antes = await store.consultarPasse("uid_1");
    assert.equal(antes.temPasse, true);
    assert.equal(antes.estado.utilizavel, true);

    const veredito = await store.admitir(pedido());
    assert.equal(veredito.ok, true);
    assert.equal(veredito.fonteElegibilidade, FONTE.CORTESIA);

    const depois = await store.consultarPasse("uid_1");
    assert.equal(depois.estado.utilizavel, false);
    assert.equal(depois.estado.usadoEm, T0);

    // A admissao e o consumo existem juntos, ou nao existem.
    const adm = await db.collection(COL.ADMISSOES).doc("te_1").get();
    assert.equal(adm.exists, true);
    assert.equal(adm.data().ok, true);
    assert.equal(adm.data().fonteElegibilidade, FONTE.CORTESIA);
  });

  test("INT-02 (caso 24) recusa ANTES da reserva nao consome o passe", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await store.consultarPasse("uid_1");

    // Assento fora da mesa: recusa no primeiro portao, antes de qualquer
    // efeito. O passe tem que sobreviver intacto.
    const veredito = await store.admitir(pedido({ assento: 9, tentativaEntradaId: "te_ruim" }));
    assert.equal(veredito.ok, false);

    const depois = await store.consultarPasse("uid_1");
    assert.equal(depois.estado.utilizavel, true, "o passe sumiu numa admissao recusada");
  });

  test("INT-03 (caso 26) o retry com a MESMA tentativa nao consome de novo", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await store.consultarPasse("uid_1");

    const primeira = await store.admitir(pedido());
    assert.equal(primeira.ok, true);
    assert.equal(primeira.repetida, false);

    // O jogador nao recebeu a resposta e o servidor repetiu o voo. Mesma
    // tentativa, mesma resposta — e nenhum efeito novo.
    r.estado.agora = em(60 * 1000);
    const retry = await store.admitir(pedido());
    assert.equal(retry.ok, true);
    assert.equal(retry.repetida, true);
    assert.equal(retry.admissaoId, primeira.admissaoId);

    const passe = await db.collection(COL.PASSES).doc("uid_1").get();
    assert.equal(passe.data().usadoEm, T0, "o retry remarcou o consumo");
  });

  test("INT-04 (caso 27) duas tentativas SIMULTANEAS produzem UM consumo", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await store.consultarPasse("uid_1");

    // Dois aparelhos, duas tentativas DIFERENTES, disparadas juntas. As duas
    // transacoes tocam `passesVip/{uid}`: o Firestore serializa, uma vence e a
    // outra reexecuta e le `usadoEm` preenchido.
    const [a, b] = await Promise.all([
      store.admitir(pedido({ tentativaEntradaId: "te_a", assento: 0 })),
      store.admitir(pedido({ tentativaEntradaId: "te_b", assento: 1 })),
    ]);

    const aprovadas = [a, b].filter((x) => x.ok);
    assert.equal(aprovadas.length, 1, "as duas tentativas foram aprovadas com um passe so");
    assert.equal(aprovadas[0].fonteElegibilidade, FONTE.CORTESIA);

    const recusada = [a, b].find((x) => !x.ok);
    assert.ok(
      recusada.codigoRecusa === RECUSA.SEM_ASSINATURA_NEM_CORTESIA ||
        recusada.codigoRecusa === RECUSA_PASSE.JA_USADO,
      `recusa inesperada: ${recusada.codigoRecusa}`,
    );

    const passe = await db.collection(COL.PASSES).doc("uid_1").get();
    assert.equal(passe.data().usadoEm !== null, true);
  });

  test("INT-05 (caso 33) o abandono depois da admissao nao devolve o passe", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await store.consultarPasse("uid_1");
    await store.admitir(pedido());

    // Nao ha caminho de devolucao. O jogador que sair e voltar depende de
    // reconexao ao PROPRIO assento — e uma entrada nova, com tentativa nova,
    // encontra o passe gasto.
    r.estado.agora = em(2 * 60 * 1000);
    const nova = await store.admitir(pedido({ tentativaEntradaId: "te_2" }));
    assert.equal(nova.ok, false);
  });

  test("INT-06 assinante ativo NAO gasta o passe", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await darAssinatura("uid_1");
    // Com assinatura ativa nem se concede passe — e por isso ele nao existe
    // para ser gasto.
    const estado = await store.consultarPasse("uid_1");
    assert.equal(estado.assinaturaAtiva, true);
    assert.equal(estado.temPasse, false);

    const veredito = await store.admitir(pedido());
    assert.equal(veredito.ok, true);
    assert.equal(veredito.fonteElegibilidade, FONTE.ASSINATURA);
  });
});

describe("INT — reconexao", () => {
  test("INT-07 quem ja esta sentado volta sem gastar um segundo passe", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await store.consultarPasse("uid_1");

    const primeira = await store.admitir(pedido());
    assert.equal(primeira.ok, true);

    r.estado.agora = em(5 * 60 * 1000);
    const volta = await store.admitir(
      pedido({ tentativaEntradaId: "te_volta", reconexao: true }),
    );
    assert.equal(volta.ok, true);
    assert.equal(volta.fonteElegibilidade, FONTE.RECONEXAO);
    assert.equal(volta.admissaoId, primeira.admissaoId, "a admissao original foi trocada");
  });

  test("INT-08 declarar `reconexao: true` sem ancora nao vale nada", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    // Sem passe e sem assinatura, e alegando reconexao: recusa.
    await db.collection(COL.PASSES).doc("uid_1").set({
      esquema: 1,
      ancoraEm: T0,
      indiceJanela: 0,
      recebidoEm: T0,
      expiraEm: em(7 * DIA),
      usadoEm: T0,
      usadoNaAdmissao: "adm_velha",
    });
    const veredito = await store.admitir(pedido({ reconexao: true }));
    assert.equal(veredito.ok, false);
  });
});

describe("INT — Mesa Privada", () => {
  test("INT-09 (caso 36) nao assinante NAO registra Mesa Privada", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    const res = await store.registrarMesaPrivada({
      uid: "uid_pobre",
      codigoDaSala: "BMV-SALA-0001",
      codigoConvite: "BMV-ACDE-FGHJ",
      cadeiras: ["liberada", "liberada", "liberada", "liberada"],
      expiraEm: em(12 * 60 * 60 * 1000),
    });
    assert.equal(res.ok, false);
    assert.equal(res.motivo, "SEM_ASSINATURA_ATIVA");
    const sala = await db.collection(COL.SALAS).doc("BMV-SALA-0001").get();
    assert.equal(sala.exists, false, "a sala nasceu sem assinatura");
  });

  test("INT-10 (caso 38) nao VIP com convite valido NAO ocupa cadeira", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await darAssinatura("uid_dono");
    const reg = await store.registrarMesaPrivada({
      uid: "uid_dono",
      codigoDaSala: "BMV-SALA-0002",
      codigoConvite: "BMV-ACDE-FGHJ",
      cadeiras: ["liberada", "liberada", "liberada", "liberada"],
      expiraEm: em(12 * 60 * 60 * 1000),
    });
    assert.equal(reg.ok, true);

    // O convidado RESOLVE o convite — ele sabe onde e a sala.
    const convite = await store.resolverConvite({
      uid: "uid_convidado",
      codigoBruto: "bmv acde fghj",
    });
    assert.equal(convite.ok, true);
    assert.equal(convite.salaId, "BMV-SALA-0002");

    // E mesmo assim nao senta: o codigo localiza, nao concede.
    const veredito = await store.admitir(
      pedido({
        uidAutenticado: "uid_convidado",
        codigoDaSala: "BMV-SALA-0002",
        assento: 1,
        categoriaCompetitiva: "casual",
        tentativaEntradaId: "te_convidado",
      }),
    );
    assert.equal(veredito.ok, false);
    assert.equal(veredito.codigoRecusa, RECUSA.SEM_ASSINATURA_NEM_CORTESIA);
  });

  test("INT-11 (caso 43) a cortesia nao abre Mesa Privada", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await darAssinatura("uid_dono");
    await store.registrarMesaPrivada({
      uid: "uid_dono",
      codigoDaSala: "BMV-SALA-0003",
      codigoConvite: "BMV-KMNP-QRTU",
      cadeiras: ["liberada", "liberada", "liberada", "liberada"],
      expiraEm: em(12 * 60 * 60 * 1000),
    });
    await store.consultarPasse("uid_cortesia"); // materializa um passe valido

    const veredito = await store.admitir(
      pedido({
        uidAutenticado: "uid_cortesia",
        codigoDaSala: "BMV-SALA-0003",
        assento: 2,
        categoriaCompetitiva: "casual",
        tentativaEntradaId: "te_cortesia",
      }),
    );
    assert.equal(veredito.ok, false);
    assert.equal(veredito.codigoRecusa, RECUSA.CORTESIA_NAO_SERVE_PRIVADA);

    // E o passe continua intacto: recusar nao pode cobrar.
    const passe = await store.consultarPasse("uid_cortesia");
    assert.equal(passe.estado.utilizavel, true);
  });

  test("INT-12 (caso 41) o limitador barra a varredura de convites", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    const codigos = ["BMV-ACDE-FGHJ", "BMV-KMNP-QRTU", "BMV-VWXY-3467"];
    let barrado = false;
    for (let i = 0; i < 12; i++) {
      const res = await store.resolverConvite({
        uid: "uid_varredor",
        codigoBruto: codigos[i % codigos.length],
      });
      assert.equal(res.ok, false);
      if (res.motivoInterno === "EXCESSO_DE_TENTATIVAS") barrado = true;
    }
    assert.equal(barrado, true, "o limitador nao barrou doze palpites seguidos");
  });

  test("INT-13 (caso 50) convite de uma sala nao autoriza outra", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await darAssinatura("uid_dono");
    await store.registrarMesaPrivada({
      uid: "uid_dono",
      codigoDaSala: "BMV-SALA-000A",
      codigoConvite: "BMV-ACDE-FGHJ",
      cadeiras: ["liberada", "liberada", "liberada", "liberada"],
      expiraEm: em(12 * 60 * 60 * 1000),
    });
    const res = await store.resolverConvite({ uid: "u", codigoBruto: "BMV-ACDE-FGHJ" });
    assert.equal(res.salaId, "BMV-SALA-000A");
    assert.notEqual(res.salaId, "BMV-SALA-000B");
  });

  test("INT-14 o convite NAO fica em claro no banco", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await darAssinatura("uid_dono");
    await store.registrarMesaPrivada({
      uid: "uid_dono",
      codigoDaSala: "BMV-SALA-000C",
      codigoConvite: "BMV-ACDE-FGHJ",
      cadeiras: ["liberada", "liberada", "liberada", "liberada"],
      expiraEm: em(12 * 60 * 60 * 1000),
    });
    const docs = await db.collection(COL.CODIGOS).listDocuments();
    assert.equal(docs.length, 1);
    // O id e a impressao, e nao o codigo.
    assert.equal(docs[0].id.length, 64, "o id do documento nao e um sha256");
    assert.equal(docs[0].id.includes("ACDE"), false);
    const dados = (await docs[0].get()).data();
    assert.equal(JSON.stringify(dados).includes("ACDE"), false, "o codigo vazou para um campo");
  });
});

describe("INT — a janela do passe, no banco", () => {
  test("INT-15 (caso 5 do laudo) a janela seguinte SOBRESCREVE a anterior", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await store.consultarPasse("uid_1");
    await store.admitir(pedido());

    r.estado.agora = em(15 * DIA);
    const novo = await store.consultarPasse("uid_1");
    assert.equal(novo.estado.indiceJanela, 1);
    assert.equal(novo.estado.utilizavel, true);

    // UM documento, sempre. "Nao acumula" e invariante de ESCRITA.
    const docs = await db.collection(COL.PASSES).listDocuments();
    assert.equal(docs.length, 1);
  });

  test("INT-16 duas consultas simultaneas na mesma janela concedem UM passe", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    const [a, b] = await Promise.all([
      store.consultarPasse("uid_1"),
      store.consultarPasse("uid_1"),
    ]);
    assert.equal(a.estado.indiceJanela, 0);
    assert.equal(b.estado.indiceJanela, 0);
    assert.equal(a.estado.recebidoEm, b.estado.recebidoEm);
    const docs = await db.collection(COL.PASSES).listDocuments();
    assert.equal(docs.length, 1);
  });
});

describe("INT — regressao", () => {
  test("INT-17 (caso 61) categoria desconhecida falha FECHADA", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await darAssinatura("uid_1");
    for (const categoria of ["vip", "VIP_RANQUEADA", "", "desconhecida", "ranqueada"]) {
      const veredito = await store.admitir(
        pedido({ categoriaCompetitiva: categoria, tentativaEntradaId: `te_${categoria}` }),
      );
      assert.equal(veredito.ok, false, `aceitou categoria "${categoria}"`);
      assert.equal(veredito.codigoRecusa, RECUSA.TIPO_DESCONHECIDO);
    }
  });

  test("INT-18 (caso 1) mesa publica casual admite sem assinatura e sem passe", async () => {
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    const veredito = await store.admitir(
      pedido({ categoriaCompetitiva: "casual", tentativaEntradaId: "te_pub" }),
    );
    assert.equal(veredito.ok, true);
    assert.equal(veredito.fonteElegibilidade, FONTE.NAO_EXIGIDA);
    // E o passe materializado pela janela continua utilizavel: mesa gratuita
    // nao cobra cortesia.
    const passe = await store.consultarPasse("uid_1");
    assert.equal(passe.estado.utilizavel, true);
  });

  test("INT-19 a recusa registrada guarda o motivo REAL", async () => {
    // O motivo nao sai no fio, e sai no registro. As duas coisas ao mesmo
    // tempo sao o que permite operar sem virar oraculo.
    const r = relogio();
    const store = criarStore({ db, agora: r.ler });
    await db.collection(COL.PASSES).doc("uid_1").set({
      esquema: 1,
      ancoraEm: T0,
      indiceJanela: 0,
      recebidoEm: T0,
      expiraEm: em(7 * DIA),
      usadoEm: T0,
      usadoNaAdmissao: "adm_velha",
    });
    await store.admitir(pedido({ tentativaEntradaId: "te_reg" }));
    const doc = await db.collection(COL.ADMISSOES).doc("te_reg").get();
    assert.equal(doc.data().ok, false);
    assert.equal(doc.data().codigoRecusa, RECUSA.SEM_ASSINATURA_NEM_CORTESIA);
    assert.equal(doc.data().versaoContrato, "admissao-vip-v1");
  });
});

test("encerra a conexao com o emulador", async () => {
  await deleteApp(app);
});
