/**
 * elegibilidade.test.js — "HA ASSINATURA VIGENTE AGORA?", E O ESPELHO.
 *
 * Cobre os casos obrigatorios 10 (assinatura ativa permite), 11 (expirada
 * recusa), 12 (revogada recusa) e 40 (VIP expirado entre a configuracao e a
 * admissao e recusado).
 *
 * O bloco `ELE-ESP` e o antidoto contra o espelho envelhecer: ele LE
 * `functions-billing/entitlement.js` e falha se a lista de estados com acesso
 * divergir da copia em `src/elegibilidade.ts`. E o mesmo padrao que
 * `functions-conta/src/plano.ts` usa para `STATUS_INSCRICAO_ATIVA`, e ele
 * existe porque este codebase NAO pode importar o vizinho: cada codebase e
 * uma unidade de implantacao propria, e um `require` para fora do diretorio
 * compila na bancada e quebra no deploy.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const { ESTADOS_COM_ACESSO, assinaturaVigente } = require("../lib/elegibilidade");

const T0 = "2026-08-01T12:00:00.000Z";
const DIA = 24 * 60 * 60 * 1000;
const em = (ms) => new Date(Date.parse(T0) + ms).toISOString();

describe("ELE — a vigencia e temporal", () => {
  test("ELE-01 estado com acesso e prazo correndo => vigente", () => {
    for (const estado of ESTADOS_COM_ACESSO) {
      assert.equal(
        assinaturaVigente({ estado, expiraEm: em(30 * DIA) }, T0),
        true,
        `${estado} nao concedeu`,
      );
    }
  });

  test("ELE-02 assinatura EXPIRADA recusa, mesmo com `vipAtivo: true` gravado", () => {
    // O campo booleano do documento descreve o instante em que ele foi
    // escrito, e esse instante ja passou. Quem encerra o acesso e o relogio.
    const doc = { estado: "ativo", expiraEm: em(DIA), vipAtivo: true };
    assert.equal(assinaturaVigente(doc, T0), true);
    assert.equal(assinaturaVigente(doc, em(2 * DIA)), false);
  });

  test("ELE-03 a fronteira e ESTRITA: no instante do vencimento ja nao vale", () => {
    const doc = { estado: "ativo", expiraEm: em(DIA) };
    assert.equal(assinaturaVigente(doc, em(DIA - 1)), true);
    assert.equal(assinaturaVigente(doc, em(DIA)), false);
  });

  test("ELE-04 estados REVOGADO e REEMBOLSADO nao concedem, nem dentro do prazo", () => {
    for (const estado of ["revogado", "reembolsado", "expirado", "em_espera", "pausado", "pendente"]) {
      assert.equal(
        assinaturaVigente({ estado, expiraEm: em(30 * DIA) }, T0),
        false,
        `${estado} concedeu acesso`,
      );
    }
  });

  test("ELE-05 falha FECHADA em tudo que nao da para provar", () => {
    const invalidos = [
      null,
      undefined,
      {},
      { estado: "ativo" },
      { expiraEm: em(DIA) },
      { estado: "ativo", expiraEm: null },
      { estado: "ativo", expiraEm: 12345 },
      { estado: "ativo", expiraEm: "amanha" },
      { estado: "ATIVO", expiraEm: em(DIA) },
      { estado: "desconhecido", expiraEm: em(DIA) },
    ];
    for (const doc of invalidos) {
      assert.equal(assinaturaVigente(doc, T0), false, `concedeu para ${JSON.stringify(doc)}`);
    }
  });

  test("ELE-06 `vipAtivo: true` sozinho NAO concede", () => {
    // O campo existe no documento do Billing e NAO e a autoridade aqui: sem
    // estado com acesso e sem prazo, ele nao vale nada.
    assert.equal(assinaturaVigente({ vipAtivo: true }, T0), false);
  });
});

describe("ELE-ESP — o espelho de ESTADOS_COM_ACESSO", () => {
  const CAMINHO = path.join(__dirname, "..", "..", "functions-billing", "entitlement.js");
  const billing = fs.readFileSync(CAMINHO, "utf8");

  test("ELE-ESP-01 a autoridade do Billing continua onde o espelho diz", () => {
    assert.ok(billing.includes("ESTADOS_COM_ACESSO"), "ESTADOS_COM_ACESSO sumiu do Billing");
  });

  test("ELE-ESP-02 os estados com acesso batem, um a um", () => {
    // O bloco `const ESTADOS_COM_ACESSO = new Set([...])` do arquivo original.
    const inicio = billing.indexOf("const ESTADOS_COM_ACESSO");
    const bloco = billing.slice(inicio, billing.indexOf("]", inicio));

    // No Billing eles aparecem como `ESTADO.ATIVO`; aqui como as strings que
    // aquele mapa produz. A comparacao e pelo NOME DA CONSTANTE, que e o que
    // muda quando alguem acrescenta ou remove um estado.
    const noBilling = [...bloco.matchAll(/ESTADO\.([A-Z_]+)/g)].map((m) => m[1].toLowerCase());
    assert.deepEqual(
      [...noBilling].sort(),
      [...ESTADOS_COM_ACESSO].sort(),
      "o espelho de estados com acesso divergiu de functions-billing/entitlement.js",
    );
  });

  test("ELE-ESP-03 este codebase NAO escreve em playerEntitlements", () => {
    // A colecao e do Billing. Este codebase le, e so le — se alguem
    // acrescentar uma escrita, a colecao passa a ter duas autoridades e as
    // duas divergem no primeiro caminho que esquecer de atualizar a outra.
    const raiz = path.join(__dirname, "..", "src");
    for (const arquivo of fs.readdirSync(raiz)) {
      const fonte = fs.readFileSync(path.join(raiz, arquivo), "utf8");
      const codigo = fonte
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .split("\n")
        .filter((l) => !l.trim().startsWith("//"))
        .join("\n");
      // Toda escrita neste codebase passa por `tx.set(ref.X(...))`. A unica
      // referencia de entitlement e `ref.entitlement`, e ela so aparece em
      // `tx.get`.
      const escritas = [...codigo.matchAll(/tx\.(set|update|delete)\(\s*ref\.(\w+)/g)].map((m) => m[2]);
      assert.equal(
        escritas.includes("entitlement"),
        false,
        `${arquivo} escreve em playerEntitlements`,
      );
    }
  });
});
