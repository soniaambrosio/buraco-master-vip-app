/**
 * A PARTE DE CONTRATO DA SUITE DE COMPOSICAO.
 *
 * ---------------------------------------------------------------------------
 * POR QUE ESTES TRES CASOS NAO MORAM DO LADO DO FLUTTER
 * ---------------------------------------------------------------------------
 *
 * A OS pede uma suite de composicao com vinte casos, e tres deles sao sobre o
 * contrato das estatisticas oficiais: `torneio` na enumeracao, `torneio`
 * conhecido e inelegivel, e torneio competitivo incoerente recusado.
 *
 * Eles nao cabem numa suite Dart, e nao por preferencia: o overlay que o CI
 * monta para rodar o Flutter copia SO `app/`. Nenhum teste Dart alcanca
 * `functions-ranking/`, entao um caso escrito la teria de ler um arquivo que
 * nao existe no lugar onde ele roda — passaria por vacuidade, que e pior do que
 * nao existir.
 *
 * ---------------------------------------------------------------------------
 * E POR QUE ELES EXISTEM, SE `estatisticas.test.js` JA OS TEM
 * ---------------------------------------------------------------------------
 *
 * Porque a pergunta e outra. Aquela suite pergunta "o contrato esta correto?".
 * Esta pergunta "o contrato ATUALIZADO sobreviveu a composicao?" — e a diferenca
 * importa porque a base desta linhagem foi cortada em `fda063bf`, DOIS commits
 * antes de `torneio` existir. Uma composicao malfeita restauraria o contrato de
 * cinco modalidades sem nenhum conflito de merge, porque quem escreveu a base
 * simplesmente nao viu esses dois commits.
 *
 * Entao o que se afirma aqui e a PRESENCA da atualizacao, do lado de quem a
 * produz, com o vocabulario da OS. Se um merge futuro reverter `581bd91`, esta
 * suite cai antes de alguem descobrir pelo comportamento.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  MODALIDADES,
  MODALIDADES_ELEGIVEIS,
} = require("../lib/estatisticas/contrato");
const { reduzirEnvelope } = require("../lib/estatisticas/redutor");

const RAIZ = path.join(__dirname, "..", "..");
const SCHEMA = JSON.parse(
  fs.readFileSync(
    path.join(RAIZ, "docs", "contratos", "fato-partida-oficial-v1.schema.json"),
    "utf8"
  )
);

const clonar = (o) => JSON.parse(JSON.stringify(o));

/** Mesa publica CASUAL, concluida, vitoria de `nos`. */
function baseCasual() {
  const f = clonar(SCHEMA.examples[0]);
  f.modalidade = "publica_casual";
  f.ambienteCompetitivo = false;
  return f;
}

describe("composicao — o contrato atualizado sobreviveu", () => {
  test("C2. o contrato contem `torneio`, e sao SEIS modalidades", () => {
    // Seis, e nao "pelo menos seis": a composicao anterior parou num contrato
    // de cinco, e o numero e o que denuncia uma reversao silenciosa.
    assert.equal(MODALIDADES.length, 6);
    assert.ok(MODALIDADES.includes("torneio"), "`torneio` sumiu da enumeracao");
    assert.deepEqual([...MODALIDADES].sort(), [
      "privada",
      "publica_casual",
      "publica_ranqueada",
      "simulada",
      "torneio",
      "treino",
    ]);

    // E o schema publicado diz a mesma coisa que o TypeScript. Um schema que
    // diverge do analisador promete ao servidor Railway uma forma que a nossa
    // porta nao aceita.
    const doSchema = SCHEMA.properties.modalidade.enum;
    assert.deepEqual([...doSchema].sort(), [...MODALIDADES].sort());
  });

  test("C3. `torneio` e CONHECIDO e INELEGIVEL — que nao e o mesmo que desconhecido", () => {
    // Conhecido: o envelope e ACEITO.
    const f = baseCasual();
    f.modalidade = "torneio";
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, true, `envelope de torneio recusado: ${JSON.stringify(r.erros)}`);

    // Inelegivel: aceito, e nao produz nada — com o motivo NOMEADO.
    assert.equal(r.reducao.elegivel, false);
    assert.equal(r.reducao.motivo, "modalidade_nao_elegivel");
    assert.deepEqual(r.reducao.deltas, []);
    assert.ok(!MODALIDADES_ELEGIVEIS.includes("torneio"));

    // A DIFERENCA, encenada: uma modalidade desconhecida nao chega a ter
    // reducao — o envelope inteiro cai. Sem este contraste, "inelegivel" e
    // "desconhecida" ficariam indistinguiveis, que era o estado anterior.
    const g = baseCasual();
    g.modalidade = "campeonato";
    const rg = reduzirEnvelope(g);
    assert.equal(rg.ok, false, "modalidade desconhecida deveria cair o envelope");
  });

  test("C4. torneio marcado como ambiente competitivo e RECUSADO", () => {
    // A incoerencia: `torneio` nao esta em MODALIDADES_ELEGIVEIS e nao produz
    // estatistica, entao dizer que ele e ambiente competitivo e o produtor
    // afirmando duas coisas que nao se sustentam juntas. Recusar o envelope e a
    // resposta certa — deixar passar seria aceitar um fato malformado e so
    // descobri-lo na apuracao.
    const f = baseCasual();
    f.modalidade = "torneio";
    f.ambienteCompetitivo = true;

    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false, "torneio competitivo deveria ser recusado");
    assert.ok(
      r.erros.some((e) => e.startsWith("ambienteCompetitivo")),
      `a recusa deveria nomear ambienteCompetitivo: ${JSON.stringify(r.erros)}`
    );
  });

  test("C2b. e o contrato de CINCO modalidades nao pode voltar", () => {
    // A prova negativa da reversao, escrita como afirmacao: nenhuma das quatro
    // inelegiveis pode desaparecer, e as duas elegiveis continuam sendo duas.
    for (const conhecida of ["torneio", "privada", "treino", "simulada"]) {
      assert.ok(
        MODALIDADES.includes(conhecida),
        `${conhecida} saiu da enumeracao`
      );
      assert.ok(
        !MODALIDADES_ELEGIVEIS.includes(conhecida),
        `${conhecida} virou elegivel — a decisao de produto mudou sem OS`
      );
    }
    assert.deepEqual([...MODALIDADES_ELEGIVEIS].sort(), [
      "publica_casual",
      "publica_ranqueada",
    ]);
  });
});
