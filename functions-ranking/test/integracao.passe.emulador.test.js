/**
 * O PASSE DE CORTESIA CONTRA O FIRESTORE REAL (emulador).
 *
 * `passe.test.js` prova a REGRA — as duas fronteiras, o que acumula e o que
 * não, o recibo. Esta suíte prova o que só o banco prova, e que teste puro não
 * alcança de jeito nenhum:
 *
 *   transação ....... o ciclo e o controle entram juntos, ou não entram;
 *   concorrência .... N chamadas simultâneas do MESMO jogador produzem UM
 *                     ciclo, porque a transação reexecuta as perdedoras e elas
 *                     releem um controle que já tem ciclo;
 *   persistência .... o que fica gravado é o que a regra decidiu, campo a campo;
 *   idempotência .... repetir não escreve, e não é uma promessa do código: é
 *                     medido por `updateTime` do documento;
 *   falha fechada ... um documento corrompido no banco recusa em vez de ser
 *                     normalizado por cima.
 *
 * NÃO RODA NO `npm test`. Exige emulador, e o alvo é `npm run test:emulador:passe`.
 *
 * O RELÓGIO É INJETADO aqui também. Sete e quinze dias não podem depender de
 * esperar sete e quinze dias, e o `agoraMs` da porta existe exatamente para isso.
 */

const { test, describe, before, beforeEach } = require("node:test");
const assert = require("node:assert/strict");

const admin = require("firebase-admin");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error("esta suite exige o emulador do Firestore. Use `npm run test:emulador:passe`.");
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-bmv-passe" });

const {
  materializarPasseDeCortesia,
  projetarPasseParaODono,
  cicloVigente,
  C_PASSE,
  SUB_CICLOS,
} = require("../lib/firestore");
const { VERSAO_CONTRATO_PASSE, MS_DE_VALIDADE, MS_DE_CICLO, isoDeInstante } = require("../lib/passe");

const db = admin.firestore();
const T0 = Date.UTC(2026, 7, 17, 12, 0, 0);
const DIA = 24 * 60 * 60 * 1000;

let contador = 0;
/// Um uid por caso. Nunca reaproveitar: um resíduo do caso anterior faria o
/// seguinte passar (ou falhar) pelo motivo errado.
function novoUid(rotulo) {
  contador += 1;
  return `uid-passe-${rotulo}-${contador}`;
}

async function apagarJogador(uid) {
  const ciclos = await db.collection(C_PASSE).doc(uid).collection(SUB_CICLOS).get();
  for (const d of ciclos.docs) await d.ref.delete();
  await db.collection(C_PASSE).doc(uid).delete();
}

async function controleDe(uid) {
  const s = await db.collection(C_PASSE).doc(uid).get();
  return s.exists ? s.data() : null;
}

async function ciclosDe(uid) {
  const s = await db.collection(C_PASSE).doc(uid).collection(SUB_CICLOS).get();
  return s.docs.map((d) => d.data());
}

/// AQUECIMENTO DA CONEXÃO, e por que ele merece um hook próprio.
///
/// A primeira chamada ao Firestore paga o estabelecimento do canal gRPC, e esse
/// custo não é do teste que por acaso vem primeiro. Sem este hook, `PEC-01`
/// media 185 s numa máquina carregada enquanto todos os outros casos ficavam
/// abaixo de 700 ms — e um relatório assim faz procurar defeito de lógica onde
/// só há handshake. Pior: a leitura errada convida a "otimizar" o caminho de
/// criação do passe, que não tem nada de lento.
///
/// A leitura é de um documento que não existe, de propósito: ela abre o canal
/// sem escrever nada e sem depender de fixture nenhum.
before(async () => {
  await db.collection(C_PASSE).doc("aquecimento-do-canal").get();
});

// ===========================================================================
describe("PASSE-EMU/CICLO — o que o banco guarda", () => {
  test("PEC-01: o primeiro acesso grava controle e ciclo, juntos e coerentes", async () => {
    const uid = novoUid("primeiro");
    const estado = await materializarPasseDeCortesia(uid, T0);

    assert.equal(estado.acao, "criar_primeiro");
    assert.equal(estado.disponivel, true);
    assert.equal(estado.validoAte, isoDeInstante(T0 + MS_DE_VALIDADE));

    const controle = await controleDe(uid);
    assert.equal(controle.versaoContrato, VERSAO_CONTRATO_PASSE);
    assert.equal(controle.cicloAtualId, estado.cicloId);
    assert.equal(controle.recebidoEm, isoDeInstante(T0));
    assert.equal(controle.validoAte, isoDeInstante(T0 + MS_DE_VALIDADE));
    assert.equal(controle.proximaElegibilidadeEm, isoDeInstante(T0 + MS_DE_CICLO));
    assert.equal(controle.consumidoEm, null);

    const ciclos = await ciclosDe(uid);
    assert.equal(ciclos.length, 1, "um ciclo, e só um");
    assert.equal(ciclos[0].cicloId, estado.cicloId);
    assert.equal(ciclos[0].consumidoEm, null);
    assert.equal(ciclos[0].tentativaEntradaId, null);
    assert.equal(ciclos[0].admissaoId, null);
  });

  test("PEC-02: o `cicloId` é opaco — não é o uid, nem data, nem contador", async () => {
    // §5: identificador opaco e não derivado. Dois jogadores criando no MESMO
    // instante têm ids diferentes, e nenhum dos dois contém o próprio uid.
    const a = novoUid("opaco-a");
    const b = novoUid("opaco-b");
    const ea = await materializarPasseDeCortesia(a, T0);
    const eb = await materializarPasseDeCortesia(b, T0);

    assert.notEqual(ea.cicloId, eb.cicloId, "mesmo instante, ids diferentes");
    for (const [uid, e] of [[a, ea], [b, eb]]) {
      assert.ok(!e.cicloId.includes(uid), "o id não carrega o uid");
      assert.ok(!e.cicloId.includes("2026"), "nem a data");
      assert.ok(!/^\d+$/.test(e.cicloId), "e não é um contador");
      assert.ok(e.cicloId.length >= 32, "é longo o bastante para não ser adivinhado");
    }
  });

  test("PEC-03: repetir NÃO escreve — idempotência medida no banco", async () => {
    // §11.11. A promessa não é "devolve igual": é "não toca no documento".
    // `updateTime` é o juiz, e ele não mente.
    const uid = novoUid("idem");
    await materializarPasseDeCortesia(uid, T0);
    const antes = (await db.collection(C_PASSE).doc(uid).get()).updateTime;

    for (let i = 0; i < 4; i++) {
      const e = await materializarPasseDeCortesia(uid, T0 + i * 1000);
      assert.equal(e.acao, "reaproveitar");
      assert.equal(e.disponivel, true);
    }

    const depois = (await db.collection(C_PASSE).doc(uid).get()).updateTime;
    assert.equal(antes.isEqual(depois), true, "o documento não foi reescrito");
    assert.equal((await ciclosDe(uid)).length, 1, "e nenhum ciclo novo nasceu");
  });

  test("PEC-04: entre sete e quinze dias não nasce ciclo novo", async () => {
    // §11.5, contra o banco: o histórico continua com UM documento.
    const uid = novoUid("janela");
    await materializarPasseDeCortesia(uid, T0);

    for (const dias of [7, 9, 12, 14]) {
      const e = await materializarPasseDeCortesia(uid, T0 + dias * DIA);
      assert.equal(e.acao, "aguardar", "dia " + dias);
      assert.equal(e.disponivel, false);
      assert.equal(e.proximaElegibilidadeEm, isoDeInstante(T0 + MS_DE_CICLO));
    }
    assert.equal((await ciclosDe(uid)).length, 1, "nenhum ciclo foi criado na janela seca");
  });

  test("PEC-05: em quinze dias nasce o segundo, e o primeiro NÃO é apagado", async () => {
    // §5: "não apagar o histórico necessário à idempotência". O passado é o que
    // impede consumir duas vezes; apagá-lo abriria a porta.
    const uid = novoUid("segundo");
    const primeiro = await materializarPasseDeCortesia(uid, T0);
    const segundo = await materializarPasseDeCortesia(uid, T0 + 15 * DIA);

    assert.equal(segundo.acao, "criar_novo");
    assert.notEqual(segundo.cicloId, primeiro.cicloId);

    const ciclos = await ciclosDe(uid);
    assert.equal(ciclos.length, 2, "o histórico guarda os dois");
    const ids = ciclos.map((c) => c.cicloId).sort();
    assert.deepEqual(ids, [primeiro.cicloId, segundo.cicloId].sort());

    const controle = await controleDe(uid);
    assert.equal(controle.cicloAtualId, segundo.cicloId, "o controle aponta para o vigente");
    assert.equal(controle.recebidoEm, isoDeInstante(T0 + 15 * DIA));
  });

  test("PEC-06: ciclos perdidos não acumulam — dois meses depois nasce UM", async () => {
    // §11.7 contra o banco. Quatro elegibilidades passaram; um documento novo.
    const uid = novoUid("perdidos");
    await materializarPasseDeCortesia(uid, T0);
    const tarde = T0 + 60 * DIA;
    const e = await materializarPasseDeCortesia(uid, tarde);

    assert.equal(e.acao, "criar_novo");
    assert.equal((await ciclosDe(uid)).length, 2, "dois ao todo: o original e UM novo");
    const controle = await controleDe(uid);
    assert.equal(controle.recebidoEm, isoDeInstante(tarde), "ancorado agora");
    assert.equal(controle.proximaElegibilidadeEm, isoDeInstante(tarde + MS_DE_CICLO));
  });
});

// ===========================================================================
describe("PASSE-EMU/CONCORRENCIA — a prova que só a transação dá", () => {
  test("PEK-01: oito chamadas simultâneas produzem UM ciclo", async () => {
    // §11.12 e §6.10. Sem transação as oito leriam "não há passe" e as oito
    // criariam — e o jogador teria oito passes na primeira vez que abrisse o
    // app em duas abas. A transação faz as perdedoras REEXECUTAREM e relerem um
    // controle que já tem ciclo.
    const uid = novoUid("corrida");
    const resultados = await Promise.all(
      Array.from({ length: 8 }, () => materializarPasseDeCortesia(uid, T0))
    );

    const ciclos = await ciclosDe(uid);
    assert.equal(ciclos.length, 1, "UM ciclo, e não oito");

    const ids = new Set(resultados.map((r) => r.cicloId));
    assert.equal(ids.size, 1, "e as oito chamadas concordam sobre qual é ele");
    assert.equal(ids.has(ciclos[0].cicloId), true);

    // Exatamente uma criou; as outras reaproveitaram.
    const criacoes = resultados.filter((r) => r.acao === "criar_primeiro").length;
    assert.equal(criacoes, 1, "uma única criação");
    assert.equal(resultados.every((r) => r.disponivel), true, "e todas veem o passe");
  });

  test("PEK-02: corrida na VIRADA de quinze dias também produz um só", async () => {
    // A corrida mais perigosa: todas veem o ciclo velho vencido e a
    // elegibilidade alcançada ao mesmo tempo.
    const uid = novoUid("virada");
    await materializarPasseDeCortesia(uid, T0);
    const quinze = T0 + 15 * DIA;

    const resultados = await Promise.all(
      Array.from({ length: 6 }, () => materializarPasseDeCortesia(uid, quinze))
    );

    assert.equal((await ciclosDe(uid)).length, 2, "o original + UM novo");
    assert.equal(resultados.filter((r) => r.acao === "criar_novo").length, 1, "uma criação só");
    assert.equal(new Set(resultados.map((r) => r.cicloId)).size, 1, "todas apontam o mesmo");
  });

  test("PEK-03: jogadores diferentes não disputam nada", async () => {
    const uids = Array.from({ length: 5 }, (_, i) => novoUid("paralelo" + i));
    const rs = await Promise.all(uids.map((u) => materializarPasseDeCortesia(u, T0)));
    assert.equal(rs.every((r) => r.acao === "criar_primeiro"), true);
    assert.equal(new Set(rs.map((r) => r.cicloId)).size, 5, "cinco ciclos distintos");
    for (const u of uids) assert.equal((await ciclosDe(u)).length, 1);
  });
});

// ===========================================================================
describe("PASSE-EMU/ESTADO — o banco pode estar errado, e a autoridade recusa", () => {
  test("PEE-01: documento com janela impossível falha FECHADO", async () => {
    // §11.13 e §12.14. Alguém (console, migração, código antigo) gravou oito
    // dias de validade. A autoridade NÃO normaliza: recusa, e deixa o documento
    // como está para quem for investigar.
    const uid = novoUid("malformado");
    await db.collection(C_PASSE).doc(uid).set({
      versaoContrato: VERSAO_CONTRATO_PASSE,
      cicloAtualId: "forjado",
      recebidoEm: isoDeInstante(T0),
      validoAte: isoDeInstante(T0 + 8 * DIA),
      proximaElegibilidadeEm: isoDeInstante(T0 + MS_DE_CICLO),
      consumidoEm: null,
      ultimaMaterializacaoEm: null,
    });

    const e = await materializarPasseDeCortesia(uid, T0 + DIA);
    assert.equal(e.acao, "falha_fechada");
    assert.equal(e.disponivel, false);
    assert.equal(e.motivo, "janela_impossivel");

    const depois = await controleDe(uid);
    assert.equal(depois.validoAte, isoDeInstante(T0 + 8 * DIA), "o documento NÃO foi reescrito");
    assert.equal((await ciclosDe(uid)).length, 0, "e nenhum ciclo foi criado por cima");
  });

  test("PEE-02: versão de contrato desconhecida falha FECHADA", async () => {
    const uid = novoUid("versao");
    await db.collection(C_PASSE).doc(uid).set({ versaoContrato: 99, cicloAtualId: null });
    const e = await materializarPasseDeCortesia(uid, T0);
    assert.equal(e.acao, "falha_fechada");
    assert.equal(e.motivo, "contrato_desconhecido");
    assert.equal((await controleDe(uid)).versaoContrato, 99, "intocado");
  });

  test("PEE-03: regressão de relógio não ressuscita passe", async () => {
    // §11.14 contra o banco: materializa no dia 8 (que grava
    // `ultimaMaterializacaoEm`), depois volta o relógio para o dia 3.
    const uid = novoUid("regressao");
    await materializarPasseDeCortesia(uid, T0);
    const noDia8 = await materializarPasseDeCortesia(uid, T0 + 8 * DIA);
    assert.equal(noDia8.disponivel, false, "no dia 8 já expirou");

    const voltando = await materializarPasseDeCortesia(uid, T0 + 3 * DIA);
    assert.equal(voltando.disponivel, false, "o relógio voltou e o passe NÃO voltou");
    assert.equal(voltando.acao, "aguardar");
    assert.equal((await ciclosDe(uid)).length, 1, "e nada foi criado");
  });
});

// ===========================================================================
describe("PASSE-EMU/PROJECAO — o que o dono recebe", () => {
  test("PEP-01: projetar materializa, e a projeção não carrega uid nem recibo", async () => {
    // §7, §11.18, §11.19. Materializar sob demanda é o desenho: não há
    // scheduler, e perguntar é o gatilho.
    const uid = novoUid("proj");
    const p = await projetarPasseParaODono(uid, T0);

    assert.equal(p.disponivel, true);
    assert.equal(p.validoAte, isoDeInstante(T0 + MS_DE_VALIDADE));
    assert.equal(p.proximaElegibilidadeEm, null);

    const texto = JSON.stringify(p);
    assert.ok(!texto.includes(uid), "o uid não sai na projeção");
    for (const campo of ["cicloId", "tentativaEntradaId", "admissaoId", "ultimaMaterializacaoEm", "consumidoEm"]) {
      assert.ok(!Object.prototype.hasOwnProperty.call(p, campo), "campo interno vazou: " + campo);
    }
    // e o passe existe de verdade no banco
    assert.equal((await ciclosDe(uid)).length, 1);
  });

  test("PEP-02: expirado, a projeção informa a próxima data e some com a validade", async () => {
    const uid = novoUid("projexp");
    await projetarPasseParaODono(uid, T0);
    const p = await projetarPasseParaODono(uid, T0 + 8 * DIA);
    assert.equal(p.disponivel, false);
    assert.equal(p.validoAte, null);
    assert.equal(p.proximaElegibilidadeEm, isoDeInstante(T0 + MS_DE_CICLO));
  });

  test("PEP-04: o ciclo nasce SEM recibo e SEM contexto — e o campo existe", async () => {
    // A idempotência do consumo é "mesma tentativa NO MESMO contexto", e o
    // contexto mora no documento. Aqui se prova que o campo nasce presente e
    // nulo: nascer AUSENTE faria uma comparação frouxa achar que "não há
    // divergência" e recuperar um recibo que ninguém pode conferir.
    const uid = novoUid("contexto");
    await materializarPasseDeCortesia(uid, T0);
    const [ciclo] = await ciclosDe(uid);

    assert.ok("contextoDoRecibo" in ciclo, "o campo existe no documento gravado");
    assert.equal(ciclo.contextoDoRecibo, null, "e nasce nulo — ainda não houve consumo");
    assert.equal(ciclo.tentativaEntradaId, null);
    assert.equal(ciclo.admissaoId, null);

    // E o par (recibo, contexto) é indivisível: não existe estado gravado com
    // `admissaoId` preenchido e contexto nulo.
    assert.equal(
      ciclo.admissaoId === null && ciclo.contextoDoRecibo === null,
      true,
      "recibo e contexto nascem juntos, e juntos vazios"
    );
  });

  test("PEP-03: `cicloVigente` lê sem materializar", async () => {
    // A porta que a OS de admissão vai usar para achar o ciclo. Ela LÊ: um
    // jogador sem passe não ganha um só por alguém ter perguntado por ele.
    const uid = novoUid("vigente");
    assert.equal(await cicloVigente(uid), null, "sem passe, não há ciclo");
    assert.equal(await controleDe(uid), null, "e perguntar não criou documento nenhum");

    await materializarPasseDeCortesia(uid, T0);
    const c = await cicloVigente(uid);
    assert.equal(c.versaoContrato, VERSAO_CONTRATO_PASSE);
    assert.equal(c.consumidoEm, null);
    assert.equal(c.admissaoId, null);
  });
});

// ===========================================================================
describe("PASSE-EMU/FRONTEIRA — o que NÃO foi tocado", () => {
  test("PEF-01: `playerEntitlements` continua intocada", async () => {
    // §11.15. Materializar passe não cria, não lê e não escreve a autoridade da
    // assinatura paga.
    const uid = novoUid("entitle");
    await db.collection("playerEntitlements").doc(uid).set({ vip: true, origem: "assinatura-paga" });
    const antes = (await db.collection("playerEntitlements").doc(uid).get()).updateTime;

    await materializarPasseDeCortesia(uid, T0);
    await projetarPasseParaODono(uid, T0 + DIA);
    await materializarPasseDeCortesia(uid, T0 + 20 * DIA);

    const doc = await db.collection("playerEntitlements").doc(uid).get();
    assert.equal(antes.isEqual(doc.updateTime), true, "não foi tocada nem uma vez");
    assert.deepEqual(doc.data(), { vip: true, origem: "assinatura-paga" });

    // e o passe vive em OUTRA coleção
    assert.notEqual(await controleDe(uid), null);
    await apagarJogador(uid);
    await db.collection("playerEntitlements").doc(uid).delete();
  });

  test("PEF-02: a materialização escreve SÓ nas duas coleções do passe", async () => {
    // Nenhum efeito colateral em ranking, torneio, moderação ou economia.
    const uid = novoUid("escopo");
    const vizinhas = ["rankingPlayers", "rankingStandings", "rankingLedger", "matches", "playerModeration", "usuarios"];
    for (const c of vizinhas) {
      const s = await db.collection(c).doc(uid).get();
      assert.equal(s.exists, false, "fixture suja em " + c);
    }

    await materializarPasseDeCortesia(uid, T0);
    await materializarPasseDeCortesia(uid, T0 + 15 * DIA);

    for (const c of vizinhas) {
      const s = await db.collection(c).doc(uid).get();
      assert.equal(s.exists, false, "o passe escreveu em " + c);
    }
  });
});
