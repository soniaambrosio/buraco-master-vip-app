/**
 * inventario.test.js — A PROVA DE QUE NENHUMA COLECAO FICOU SEM CLASSIFICACAO.
 *
 * OS de Exclusao de Conta e Dados do Jogador v1.
 *
 * POR QUE ESTE ARQUIVO LE `firebase/firestore.rules`, e nao so chama funcoes.
 *
 * A matriz de retencao pode estar perfeita hoje e errada em duas semanas, e o
 * modo como ela erra e sempre o mesmo: alguem acrescenta uma colecao ao banco,
 * escreve a regra dela, e nao lembra que existe um fluxo de exclusao. A partir
 * dali a exclusao passa a deixar dado para tras — e passa em silencio, porque
 * nenhum teste de comportamento sabe perguntar por uma colecao que ele nao
 * conhece.
 *
 * A unica forma de detectar isso e cruzar a matriz com uma FONTE EXTERNA que o
 * autor da colecao nova e obrigado a tocar. `firestore.rules` e essa fonte: o
 * arquivo termina com `match /{documento=**} { allow read, write: if false; }`,
 * entao uma colecao sem bloco proprio nao e legivel por ninguem — na pratica,
 * toda colecao que o cliente alcanca esta declarada la.
 *
 * E o mesmo raciocinio de functions-ranking/test/identidade.test.js, que le o
 * arquivo do codebase vizinho para provar que um `rename` la nao deixa o
 * ranking lendo colecao que deixou de existir.
 *
 * O QUE ACONTECE QUANDO ESTE TESTE QUEBRA: alguem acrescentou uma colecao. A
 * correcao NAO e acrescentar o nome a lista de excecoes — e decidir o que
 * acontece com aquele dado quando o jogador pede para sair, e escrever a decisao
 * em src/inventario.ts com a justificativa.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  CLASSE,
  INVENTARIO,
  colecaoRaizDe,
  itemPorId,
  itensAcionaveis,
  itensDaClasse,
} = require("../lib/inventario");

const REGRAS = path.join(
  __dirname,
  "..",
  "..",
  "firebase",
  "firestore.rules"
);

/// As colecoes de PRIMEIRO NIVEL declaradas nas regras.
///
/// So o primeiro nivel: as subcolecoes aparecem na matriz com o caminho
/// completo (`users/{uid}/friends/{outroUid}`), e cruza-las uma a uma exigiria
/// um analisador de blocos aninhados — complexidade que compraria pouco, porque
/// uma subcolecao nova quase sempre chega junto com o codigo que a escreve.
function colecoesDasRegras() {
  const texto = fs.readFileSync(REGRAS, "utf8");
  const achadas = new Set();

  // `match /nome/{param}` no primeiro nivel de indentacao do bloco de
  // documentos. A indentacao e o que separa colecao de subcolecao neste arquivo,
  // que e formatado com quatro espacos por nivel.
  const regex = /^ {4}match \/([A-Za-z_][A-Za-z0-9_]*)\//gm;
  let m;
  while ((m = regex.exec(texto)) !== null) achadas.add(m[1]);

  // O fecho `match /{documento=**}` nao e colecao.
  achadas.delete("databases");
  return achadas;
}

/// Colecoes que a matriz declara, tiradas do primeiro segmento do caminho.
function colecoesDaMatriz() {
  return new Set(INVENTARIO.map(colecaoRaizDe));
}

describe("cobertura da matriz", () => {
  test("toda colecao declarada em firestore.rules esta na matriz", () => {
    const nasRegras = colecoesDasRegras();
    const naMatriz = colecoesDaMatriz();

    const faltando = [...nasRegras].filter((c) => !naMatriz.has(c)).sort();

    assert.deepEqual(
      faltando,
      [],
      "colecoes declaradas em firestore.rules e ausentes de src/inventario.ts. " +
        "Decida o destino de cada uma (APAGAR/ANONIMIZAR/DESVINCULAR/RETER/" +
        "NAO_APLICAVEL) com justificativa, em vez de acrescentar excecao aqui: " +
        faltando.join(", ")
    );
  });

  test("as colecoes que vivem FORA das regras tambem estao classificadas", () => {
    // Escritas so pelo Admin SDK, invisiveis ao cliente, e por isso ausentes de
    // firestore.rules — caem no fecho `if false`. Sao justamente as que o
    // cruzamento acima nao pegaria, e a mais importante delas guarda o saldo de
    // fichas do jogador.
    for (const colecao of ["wallets", "seeds", "tournamentJobs", "accountDeletions"]) {
      const item = INVENTARIO.find((i) => colecaoRaizDe(i) === colecao);
      assert.ok(item, `'${colecao}' nao esta na matriz`);
    }
  });

  test("o Authentication esta na matriz", () => {
    const auth = itemPorId("auth.usuario");
    assert.ok(auth, "a conta do Authentication precisa estar classificada");
    assert.equal(auth.classe, CLASSE.APAGAR);
    assert.equal(auth.alcance.modo, "authentication");
  });
});

describe("forma da matriz", () => {
  test("os ids sao unicos", () => {
    const vistos = new Set();
    for (const item of INVENTARIO) {
      assert.ok(!vistos.has(item.id), `id repetido: ${item.id}`);
      vistos.add(item.id);
    }
  });

  test("toda classe e uma das cinco da OS", () => {
    const validas = new Set(Object.values(CLASSE));
    for (const item of INVENTARIO) {
      assert.ok(validas.has(item.classe), `${item.id} tem classe invalida`);
    }
  });

  test("todo item tem justificativa, e ela nao e decorativa", () => {
    // A OS proibe "apagar historico sem justificativa". Um campo obrigatorio que
    // aceita string vazia nao proibe nada, entao o teste exige substancia: uma
    // frase curta demais e um `porque` que ninguem escreveu de verdade.
    for (const item of INVENTARIO) {
      assert.ok(
        typeof item.porque === "string" && item.porque.trim().length >= 40,
        `${item.id} nao tem justificativa suficiente`
      );
    }
  });

  test("ANONIMIZAR e DESVINCULAR dizem QUAIS campos", () => {
    // Sem `campos`, as duas classes seriam intencao sem instrucao: o executor
    // nao saberia o que cortar e a matriz descreveria um efeito que nao acontece.
    for (const item of INVENTARIO) {
      if (item.classe === CLASSE.ANONIMIZAR || item.classe === CLASSE.DESVINCULAR) {
        assert.ok(
          Array.isArray(item.campos) && item.campos.length > 0,
          `${item.id} e ${item.classe} e nao declara campos`
        );
      }
    }
  });

  test("RETER e NAO_APLICAVEL nao tem alcance de execucao", () => {
    // Um item retido com consulta declarada e um acidente esperando: alguem
    // acrescenta o item ao plano e a colecao passa a ser varrida — e, um dia,
    // escrita.
    for (const item of INVENTARIO) {
      if (item.classe === CLASSE.RETER || item.classe === CLASSE.NAO_APLICAVEL) {
        assert.equal(
          item.alcance.modo,
          "semAcao",
          `${item.id} e ${item.classe} e mesmo assim declara como ser alcancado`
        );
      }
    }
  });

  test("APAGAR, ANONIMIZAR e DESVINCULAR sao alcancaveis", () => {
    for (const item of INVENTARIO) {
      const acionavel =
        item.classe === CLASSE.APAGAR ||
        item.classe === CLASSE.ANONIMIZAR ||
        item.classe === CLASSE.DESVINCULAR;
      if (!acionavel) continue;
      assert.notEqual(
        item.alcance.modo,
        "semAcao",
        `${item.id} pede acao e nao diz como ser encontrado`
      );
    }
  });

  test("itensAcionaveis exclui exatamente RETER e NAO_APLICAVEL", () => {
    const acionaveis = new Set(itensAcionaveis().map((i) => i.id));
    for (const item of INVENTARIO) {
      const deveriaAgir =
        item.classe !== CLASSE.RETER && item.classe !== CLASSE.NAO_APLICAVEL;
      assert.equal(acionaveis.has(item.id), deveriaAgir, item.id);
    }
  });
});

describe("as decisoes que a OS destaca", () => {
  test("moderacao nao e apagada — nem denuncia, nem sancao, nem estado", () => {
    // A regra do Firestore chama `playerModeration` de "o ponto exato onde morre
    // a tentativa de apagar a propria punicao". Se a exclusao de conta o
    // apagasse, ela seria essa tentativa com outro nome.
    for (const id of [
      "moderacao.reports",
      "moderacao.sanctions",
      "moderacao.playerModeration",
    ]) {
      assert.equal(itemPorId(id).classe, CLASSE.RETER, id);
    }
  });

  test("o registro financeiro fica, e perde o titular", () => {
    const compras = itemPorId("billing.compras");
    assert.equal(compras.classe, CLASSE.DESVINCULAR);
    assert.deepEqual([...compras.campos], ["uid"]);
  });

  test("o historico competitivo compartilhado nao e apagado", () => {
    for (const id of [
      "rastreabilidade.matches",
      "rastreabilidade.rankingLedger",
      "ranking.rankingContributions",
      "torneios.tournamentHistory",
    ]) {
      assert.equal(itemPorId(id).classe, CLASSE.RETER, id);
    }
  });

  test("as linhas de ranking ficam, sem rosto", () => {
    for (const id of ["ranking.rankingStandings", "ranking.rankingPlayers"]) {
      const item = itemPorId(id);
      assert.equal(item.classe, CLASSE.ANONIMIZAR, id);
      assert.ok(item.campos.includes("apelido"), id);
    }
  });

  test("o publicIdIndex vira lapide, e nao e apagado", () => {
    // Apagar devolveria o publicId ao sorteio, e um jogador novo herdaria as
    // mencoes historicas de quem saiu.
    const item = itemPorId("identidade.publicIdIndex");
    assert.equal(item.classe, CLASSE.DESVINCULAR);
    assert.notEqual(item.classe, CLASSE.APAGAR);
  });

  test("o documento com o purchaseToken em claro e apagado explicitamente", () => {
    // `delete` no pai NAO apaga subcolecao no Firestore. Sem item proprio, o
    // token sobreviveria a conta.
    const item = itemPorId("billing.playerEntitlementsInterno");
    assert.equal(item.classe, CLASSE.APAGAR);
    assert.equal(item.alcance.modo, "subcolecaoDoDono");
  });

  test("os dois namespaces de perfil sao tratados", () => {
    // `users/` e `usuarios/` estao ambos vivos e sao diferentes. Uma exclusao
    // que varresse so o primeiro deixaria o perfil legado do Billing inteiro.
    assert.equal(itemPorId("conta.usersRaiz").classe, CLASSE.APAGAR);
    assert.equal(itemPorId("billing.usuariosLegado").classe, CLASSE.APAGAR);
  });

  test("os espelhos nas contas de terceiros sao apagados", () => {
    // O UID do excluido vaza pela CHAVE do documento na conta do outro jogador.
    for (const id of [
      "social.friendsDoOutro",
      "social.friendRequestsDoOutro",
      "moderacao.blocksContraOExcluido",
      "moderacao.mutesContraOExcluido",
    ]) {
      assert.equal(itemPorId(id).classe, CLASSE.APAGAR, id);
    }
  });

  test("ha pelo menos um item de cada classe da OS", () => {
    // Uma matriz que so soubesse apagar seria a matriz cega que a OS proibe.
    for (const classe of Object.values(CLASSE)) {
      assert.ok(itensDaClasse(classe).length > 0, `nenhum item ${classe}`);
    }
  });
});
