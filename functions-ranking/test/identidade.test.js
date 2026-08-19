/**
 * identidade.test.js — A PROVA DE QUE O RANKING NAO CUNHA `publicId`.
 *
 * OS de integracao Identidade Publica x Ranking v1, secoes 4, 5, 12 e 31.
 *
 * POR QUE ESTE ARQUIVO LE CODIGO-FONTE, e nao so chama funcoes. As outras suites
 * provam COMPORTAMENTO: dado um estado, a funcao responde assim. Esta prova uma
 * AUSENCIA — "nao existe, neste codebase, caminho que emita identidade" —, e
 * ausencia nao se prova chamando: a funcao que voltasse a existir teria nome novo
 * e nenhum teste de comportamento a chamaria.
 *
 * E o mesmo raciocinio das travas que o projeto ja usa em outros lugares:
 * `exigirRespostaSegura` no social varre a resposta em vez de confiar na revisao
 * de codigo, e `acharCampoProibido` na projecao faz o mesmo com a linha
 * publicada. Aqui a superficie varrida e a arvore de fontes.
 *
 * O QUE ACONTECE SE ALGUEM PRECISAR MESMO DISSO: nada aqui impede a decisao de
 * produto de mudar. Impede que ela mude EM SILENCIO — quem reintroduzir geracao
 * de identidade neste codebase vai ter que apagar um teste cujo nome diz o que
 * ele esta apagando.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  idPublicoValido,
  chaveDeStanding,
  COMPRIMENTO_ID_PUBLICO,
  PREFIXO_ID_PUBLICO,
  C_IDENTIDADES_CANONICAS,
  C_INDICE_PUBLICO_CANONICO,
  C_PERFIS_PUBLICOS_CANONICOS,
} = require("../lib/identidade");

const RAIZ_SRC = path.join(__dirname, "..", "src");

/// Todos os `.ts` do codebase, com caminho relativo e conteudo.
function fontes() {
  return fs
    .readdirSync(RAIZ_SRC)
    .filter((f) => f.endsWith(".ts"))
    .map((f) => ({
      arquivo: f,
      texto: fs.readFileSync(path.join(RAIZ_SRC, f), "utf8"),
    }));
}

/// O texto SEM comentarios.
///
/// Necessario porque este codebase documenta densamente, e os comentarios falam
/// justamente sobre o que foi removido — `garantirIdPublico` aparece em varios
/// deles, explicando que nao existe mais. Varrer o texto cru acusaria a propria
/// documentacao da remocao.
function semComentarios(texto) {
  return texto
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .split("\n")
    .filter((l) => !l.trim().startsWith("//") && !l.trim().startsWith("///"))
    .join("\n");
}

describe("integracao: o Ranking nao tem gerador de identidade", () => {
  /// A UNICA fonte deste codebase autorizada a sortear.
  ///
  /// A excecao nasceu com o Passe de Cortesia, que exige por contrato um
  /// identificador de ciclo OPACO E NAO DERIVADO — uid, data, posicao e contador
  /// nao servem, porque todos se deduzem de fora. Ver o cabecalho do proprio
  /// arquivo, e o teste logo abaixo, que impede a excecao de virar porta.
  const FONTE_DE_ALEATORIEDADE = "ids_opacos.ts";

  test("nenhuma fonte importa fonte de aleatoriedade", () => {
    // `randomBytes` era o insumo de `garantirIdPublico`. Sem ele nao se sorteia
    // id — e o ranking NAO e a autoridade de identidade publica: quem emite
    // `publicId` e functions-social, e um segundo emissor criaria duas
    // identidades para a mesma pessoa.
    //
    // ESTE TESTE FOI ESTREITADO, E NAO AFROUXADO. Ele nasceu banindo
    // aleatoriedade em TODA fonte, com a premissa escrita de que "um codebase
    // que nao precisa de aleatoriedade para nada mais nao tem razao para
    // importa-la de volta". A premissa mudou: o Passe de Cortesia precisa. O
    // que NAO mudou e o que o teste protege — nenhuma fonte que toque
    // identidade sorteia coisa alguma, e a excecao e um arquivo so, de tres
    // linhas, conferido pelo caso seguinte.
    for (const { arquivo, texto } of fontes()) {
      if (arquivo === FONTE_DE_ALEATORIEDADE) continue;
      const codigo = semComentarios(texto);
      assert.equal(
        /randomBytes|randomUUID|crypto/.test(codigo),
        false,
        `${arquivo} voltou a importar aleatoriedade — era assim que o id era sorteado.`
      );
      assert.equal(
        /Math\.random/.test(codigo),
        false,
        `${arquivo} usa Math.random.`
      );
    }
  });

  test("a excecao de aleatoriedade nao conhece identidade", () => {
    // O QUE IMPEDE A EXCECAO DE VIRAR PORTA. `ids_opacos.ts` pode sortear, e so
    // isso: se um dia ele aprender a palavra `publicId`, a autoridade de
    // identidade tera voltado ao ranking por uma janela lateral — que e
    // exatamente o defeito que o teste acima existe para impedir.
    const arquivo = path.join(RAIZ_SRC, FONTE_DE_ALEATORIEDADE);
    assert.equal(fs.existsSync(arquivo), true, "a excecao tem de existir para ser conferida");
    const codigo = semComentarios(fs.readFileSync(arquivo, "utf8"));

    for (const palavra of [
      "publicId",
      "publicPlayerId",
      "playerIdentities",
      "publicIdIndex",
      "identidade",
      "uid",
      "Firestore",
      "firestore",
    ]) {
      assert.equal(
        codigo.includes(palavra),
        false,
        `${FONTE_DE_ALEATORIEDADE} passou a conhecer "${palavra}" — a excecao virou porta.`
      );
    }
    // E continua sendo um arquivo minusculo. Uma excecao que cresce deixa de ser
    // excecao; se este numero precisar subir, e porque alguem colocou regra
    // dentro dela.
    const linhasDeCodigo = codigo.split("\n").filter((l) => l.trim().length > 0).length;
    assert.ok(linhasDeCodigo <= 8, `${FONTE_DE_ALEATORIEDADE} cresceu para ${linhasDeCodigo} linhas de codigo`);
  });

  test("nao existe funcao que produza um id publico", () => {
    for (const { arquivo, texto } of fontes()) {
      const codigo = semComentarios(texto);
      for (const proibido of [
        "idPublicoDeBytes",
        "garantirIdPublico",
        "reservarIdPublico",
        "cunharIdPublico",
        "gerarIdPublico",
      ]) {
        assert.equal(
          codigo.includes(proibido),
          false,
          `${arquivo} declara ou chama "${proibido}" — o ranking nao emite identidade.`
        );
      }
    }
  });

  test("o alfabeto do id nao e indexado em lugar nenhum", () => {
    // A forma mais curta de reconstruir um gerador sem usar nenhum dos nomes
    // acima e indexar o alfabeto direto (`ALFABETO[n % 32]`). O modulo de
    // identidade so o usa em `includes`, que reconhece e nao constroi.
    for (const { arquivo, texto } of fontes()) {
      const codigo = semComentarios(texto);
      assert.equal(
        /ALFABETO\s*\[/.test(codigo),
        false,
        `${arquivo} indexa o alfabeto do id publico — isso constroi um id.`
      );
    }
  });

  test("a colecao propria de ids publicos deixou de existir", () => {
    // `rankingPublicIds` era o registro de reserva do gerador antigo. Enquanto o
    // nome existir no codigo, existe um segundo mapa capaz de discordar do
    // canonico.
    for (const { arquivo, texto } of fontes()) {
      assert.equal(
        semComentarios(texto).includes("rankingPublicIds"),
        false,
        `${arquivo} ainda cita rankingPublicIds.`
      );
    }
  });

  test("nenhuma escrita toca as colecoes canonicas de identidade", () => {
    // §6: um jogador nao pode ter dois publicId, e dois jogadores nao podem ter
    // o mesmo. Isso so e garantivel enquanto UM codigo escreve nesses tres
    // documentos. Aqui o que se prova e que este codebase nao e ele.
    const canonicas = [
      C_IDENTIDADES_CANONICAS,
      C_INDICE_PUBLICO_CANONICO,
      C_PERFIS_PUBLICOS_CANONICOS,
    ];
    for (const { arquivo, texto } of fontes()) {
      const codigo = semComentarios(texto);
      for (const colecao of canonicas) {
        // Casa `collection(X).doc(...).set/update/create/delete` e a forma
        // transacional `tx.set(collection(X).doc(...), ...)`, nas duas ordens.
        const escritaDireta = new RegExp(
          `collection\\(\\s*${colecao}\\s*\\)[\\s\\S]{0,120}?\\.(set|update|create|delete)\\(`
        );
        const escritaTransacional = new RegExp(
          `(tx|transaction)\\.(set|update|create|delete)\\([\\s\\S]{0,120}?collection\\(\\s*${colecao}\\s*\\)`
        );
        assert.equal(
          escritaDireta.test(codigo) || escritaTransacional.test(codigo),
          false,
          `${arquivo} escreve em ${colecao}, que pertence a functions-social.`
        );
      }
    }
  });

  test("a callable de emissao nao existe mais", () => {
    const indice = semComentarios(
      fs.readFileSync(path.join(RAIZ_SRC, "index.ts"), "utf8")
    );
    assert.equal(
      indice.includes("garantirIdentidadePublica"),
      false,
      "o endpoint de emissao voltou ao codebase competitivo."
    );
  });
});

describe("integracao: os nomes canonicos batem com o dono deles", () => {
  // Os tres nomes de colecao estao repetidos em dois codebases porque sao
  // unidades de implantacao separadas, sem pacote npm em comum. Repeticao sem
  // conferencia e como um contrato que so uma das partes guarda: este teste le o
  // arquivo do vizinho e compara.
  const CHAVES_SOCIAL = path.join(
    __dirname,
    "..",
    "..",
    "functions-social",
    "src",
    "chaves.ts"
  );

  test("playerIdentities, publicIdIndex e publicProfiles sao os mesmos la e aqui", (t) => {
    if (!fs.existsSync(CHAVES_SOCIAL)) {
      // Nao e "pulado por conveniencia": este codebase precisa ser testavel
      // sozinho, e uma checagem entre pacotes que falhasse por ausencia do
      // vizinho transformaria um deploy independente num deploy acoplado.
      t.skip("functions-social nao esta nesta arvore");
      return;
    }
    const texto = fs.readFileSync(CHAVES_SOCIAL, "utf8");
    const valorDe = (constante) => {
      const m = texto.match(
        new RegExp(`export const ${constante}\\s*=\\s*"([^"]+)"`)
      );
      return m === null ? null : m[1];
    };

    assert.equal(valorDe("C_IDENTIDADES"), C_IDENTIDADES_CANONICAS);
    assert.equal(valorDe("C_INDICE_PUBLICO"), C_INDICE_PUBLICO_CANONICO);
    assert.equal(valorDe("C_PERFIS_PUBLICOS"), C_PERFIS_PUBLICOS_CANONICOS);
  });

  test("o formato do id e o mesmo dos dois lados", () => {
    // Formato igual nao e autoridade igual (por isso o gerador saiu), mas
    // formato DIFERENTE seria pior ainda: um id emitido pelo social deixaria de
    // ser reconhecido pelo ranking, e a navegacao "posicao -> perfil" quebraria
    // para todo mundo.
    const dart = path.join(
      __dirname,
      "..",
      "..",
      "app",
      "lib",
      "social",
      "identidade_publica.dart"
    );
    if (!fs.existsSync(dart)) return;
    const texto = fs.readFileSync(dart, "utf8");
    assert.match(texto, new RegExp(`kComprimentoIdPublico = ${COMPRIMENTO_ID_PUBLICO}`));
    assert.match(texto, new RegExp(`kPrefixoIdPublico = '${PREFIXO_ID_PUBLICO}'`));
    assert.match(texto, /kAlfabetoIdPublico = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'/);
  });

  test("um id emitido pelo dominio social e aceito pelo ranking", () => {
    // O caso concreto: `idPublicoDeBytes` do Dart, com bytes 0..11, produz
    // "P0123456789AB" (ver app/test/social/teste_social.dart). O ranking tem que
    // reconhece-lo sem saber quem o gerou.
    assert.equal(idPublicoValido("P0123456789AB"), true);
    assert.equal(idPublicoValido("P000000000000"), true);
    assert.equal(idPublicoValido("PZZZZZZZZZZZZ"), true);
  });
});

describe("integracao: uid e publicId nao se confundem", () => {
  test("um uid do Firebase nunca passa por id publico", () => {
    for (const uid of [
      "uid-secreto-do-firebase",
      "AbCdEf0123456789AbCdEf012345",
      "unknown",
      "",
    ]) {
      assert.equal(idPublicoValido(uid), false, `"${uid}" foi aceito como id publico.`);
    }
  });

  test("a chave de standing continua interna, com uid", () => {
    // §6 pede que documentos PUBLICOS prefiram publicId. `rankingStandings` nao e
    // publico: as Rules o negam a todo cliente e a linha so sai projetada. A
    // chave com uid e o que permite escrever sem uma leitura a mais por partida.
    assert.equal(chaveDeStanding("2026-A", "uid-1"), "2026-A|uid-1");
  });
});
