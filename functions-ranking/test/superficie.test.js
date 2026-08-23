/**
 * SF — A SUPERFÍCIE IMPLANTADA, E QUEM GUARDA QUEM A GUARDA.
 *
 * ---------------------------------------------------------------------------
 * POR QUE ESTE ARQUIVO EXISTE
 * ---------------------------------------------------------------------------
 *
 * `PF-01`, em `test/passe.test.js`, conferia a superfície de deploy CONTANDO
 * exports. A contagem mentiu: o piso de `functions-moderacao` foi congelado em
 * `c9efc20`, uma linhagem que ainda não continha `6986de9` (Comunicação
 * Controlada V1). A raiz P contém, e o caso passou a reprovar com `11 !== 9` —
 * sem dizer quais onze, e sem distinguir "entrou export novo" de "renomearam
 * um". A correção foi trocar a contagem por uma RELAÇÃO NOMINAL.
 *
 * Uma relação nominal, porém, tem um jeito novo de morrer que a contagem não
 * tinha: alguém pode esvaziá-la, ou trocar o corpo do caso por um `assert.ok`
 * de fachada, mantendo o nome, o arquivo e o registro no `npm test`. É o mesmo
 * buraco que a fonte única dos gates fechou com `sha256`/`provas`, e ele vale
 * aqui igual.
 *
 * ENTÃO A GUARDA MORA FORA DO ARQUIVO QUE ELA GUARDA. Uma guarda que vive
 * dentro de `passe.test.js` some junto com `passe.test.js`, e é trivializada
 * pela mesma edição que trivializa PF-01. `PF-01` devolve a gentileza exigindo
 * que `SF-01` e `SF-02` continuem aqui: a dupla só cai calada se as DUAS forem
 * desmontadas no mesmo commit, e aí não há mais o que esconder no diff.
 *
 * ---------------------------------------------------------------------------
 * O QUE CADA CASO AFIRMA
 * ---------------------------------------------------------------------------
 *
 *   SF-01  PF-01 existe, está no alvo explícito do `npm test`, e a relação
 *          nominal escrita nele é EXATAMENTE a do disco — nome por nome.
 *   SF-02  a mesma superfície, congelada por `ferramentas/composicao/
 *          loja_functions.test.js`, também é a do disco.
 *
 * As duas afirmações apontam para o DISCO, e não uma para a outra. É assim que
 * duas listas congeladas em arquivos diferentes ficam impedidas de divergir sem
 * que nenhuma das duas vire "a fonte" da outra — que seria criar uma terceira
 * autoridade sobre a mesma coisa.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const RAIZ = path.resolve(__dirname, "..", "..");
const leia = (p) => fs.readFileSync(path.join(RAIZ, p), "utf8");

const PASSE = "functions-ranking/test/passe.test.js";
const CONGELADA = "ferramentas/composicao/loja_functions.test.js";

/// As quatro codebases que PF-01 guarda, e o ponto de entrada implantado de cada
/// uma. São quatro, e não nove, porque foi sobre estas quatro que a OS do Passe
/// se comprometeu: as outras cinco têm o mesmo congelamento em `CONGELADA`, sob
/// o gate `composloja`.
const GUARDADAS = [
  ["functions", "functions/src/index.ts"],
  ["functions-moderacao", "functions-moderacao/src/index.ts"],
  ["functions-ranking", "functions-ranking/src/index.ts"],
  ["functions-social", "functions-social/src/index.ts"],
];

/// Código sem comentário. Mesma limpeza de `passe.test.js` e de `CONGELADA`:
/// uma varredura que não separe prosa de código casa com o comentário que
/// explica a remoção e passa a provar o texto em vez do programa.
function codigoDe(fonte) {
  const limpo = fonte
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^[ \t]*\/\/.*$/gm, "")
    .replace(/^[ \t]*\/\/\/.*$/gm, "");
  assert.ok(limpo.includes("export"), "a limpeza comeu o código");
  return limpo;
}

/// O que uma entrada de fato exporta, por nome e ordenado.
function exportsDe(arquivo) {
  const fonte = codigoDe(leia(arquivo));
  const achados = new Set();
  for (const m of fonte.matchAll(/^\s*export\s+const\s+([A-Za-z0-9_]+)/gm)) achados.add(m[1]);
  for (const m of fonte.matchAll(/exports\.([A-Za-z0-9_]+)\s*=/g)) achados.add(m[1]);
  return [...achados].sort();
}

const escapar = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

/// Os nomes de uma lista literal `<chave>: [ ... ]` dentro de uma FONTE, lidos
/// como texto.
///
/// LIDOS COMO TEXTO, e não importados: `passe.test.js` e `CONGELADA` são suítes,
/// e `require` numa delas executaria os testes de dentro deste arquivo. O que se
/// quer aqui é o que está ESCRITO lá, que é justamente o que um `assert.ok(true)`
/// de fachada não teria.
function listaLiteral(fonte, chave, aspas) {
  const achado = new RegExp(aspas + escapar(chave) + aspas + "\\s*:\\s*\\[([^\\]]*)\\]").exec(fonte);
  assert.ok(achado !== null, "a relação nominal de `" + chave + "` sumiu");
  const nomes = [...achado[1].matchAll(/["']([A-Za-z0-9_]+)["']/g)].map((m) => m[1]);
  assert.ok(nomes.length > 0, "a relação nominal de `" + chave + "` está vazia");
  return nomes.sort();
}

describe("SF — a superfície de deploy não pode voltar a valer por contagem", () => {
  test("SF-01: PF-01 existe, é executado, e sua relação nominal é a do disco", () => {
    // 1. É EXECUTADO. O alvo do `npm test` deste codebase é explícito, e não um
    //    glob, de propósito: um arquivo renomeado sairia da suíte em silêncio.
    //    Se PF-01 sair dali, ele para de rodar sem nada ficar vermelho — então
    //    é aqui que a presença no alvo vira afirmação.
    const pkg = JSON.parse(leia("functions-ranking/package.json"));
    assert.ok(pkg.scripts.test.includes("test/passe.test.js"), "PF-01 saiu do `npm test`");
    assert.ok(
      pkg.scripts.test.includes("test/superficie.test.js"),
      "esta guarda saiu do `npm test`"
    );

    // 2. EXISTE, com o nome que a OS do Passe registrou. (Apagar o arquivo já
    //    derruba a suíte inteira, porque o alvo o nomeia; apagar só o CASO,
    //    não — e é esse o furo que esta linha fecha.)
    const fonte = leia(PASSE);
    const abre = fonte.indexOf('test("PF-01:');
    assert.ok(abre > 0, "o caso PF-01 sumiu de " + PASSE);

    // 3. E VALIDA POR NOME. Um corpo que voltasse a comparar quantidade não tem
    //    `deepEqual` sobre a relação, e um corpo trivial não tem nem a relação.
    const corpo = fonte.slice(abre, fonte.indexOf('test("PF-02:', abre));
    assert.ok(corpo.length > 0, "PF-02 sumiu: o recorte de PF-01 ficou sem fim");
    assert.ok(
      /assert\.deepEqual\(/.test(corpo),
      "PF-01 deixou de comparar a relação de nomes"
    );
    assert.ok(
      /SUPERFICIE_IMPLANTADA/.test(corpo),
      "PF-01 não consulta mais a superfície nominal"
    );

    // 4. A PROVA FORTE: o que está ESCRITO em PF-01 é, nome por nome, o que o
    //    disco exporta. Esvaziar a relação, deixar um nome de fora ou inventar
    //    um décimo segundo reprova aqui — mesmo que PF-01 fique verde por não
    //    olhar mais para ela.
    for (const [, arquivo] of GUARDADAS) {
      assert.deepEqual(
        listaLiteral(fonte, arquivo, '"'),
        exportsDe(arquivo),
        arquivo + ": a relação nominal de PF-01 não é mais a superfície do disco"
      );
    }
  });

  test("SF-02: a superfície congelada da composição também é a do disco", () => {
    // A OUTRA LISTA CONGELADA. Ela é a autoridade sobre as NOVE codebases e é
    // cobrada pelo gate `composloja`; aqui se cobra apenas o recorte que PF-01
    // compartilha com ela. Enquanto as duas apontarem para o disco, atualizar
    // uma sem a outra fica vermelho — que é a divergência que se quer impedir.
    const fonte = leia(CONGELADA);
    for (const [codebase, arquivo] of GUARDADAS) {
      assert.deepEqual(
        listaLiteral(fonte, codebase, "'"),
        exportsDe(arquivo),
        codebase + ": a superfície congelada em " + CONGELADA + " não é mais a do disco"
      );
    }
  });
});
