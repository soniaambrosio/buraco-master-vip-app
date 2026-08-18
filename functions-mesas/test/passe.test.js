/**
 * passe.test.js — O PASSE QUINZENAL DE CORTESIA, NO RELOGIO.
 *
 * Cobre os casos obrigatorios 21 (passe valido permite uma entrada), 22/23
 * (abrir e voltar da configuracao nao consomem), 25 (admissao confirmada
 * consome), 28 (passe expirado recusa), 29 (passe ja usado recusa), 32 (o
 * passe nao cria entitlement VIP) e 33 (abandono depois da admissao nao
 * devolve).
 *
 * Os casos 24, 26, 27 e 30/31 dependem de transacao ou de outro dominio e
 * estao onde eles moram: 24/26/27 em test/integracao.emulador.test.js
 * (Firestore de verdade), 30/31 em test/decisao.test.js (a cortesia nao abre
 * Mesa Privada nem Salao).
 *
 * TODO instante entra por parametro. Nao ha `Date.now()` em lugar nenhum do
 * modulo, e este arquivo prova isso lendo o codigo.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  JANELA_MS,
  VALIDADE_MS,
  ESQUEMA_PASSE,
  CONCESSAO,
  RECUSA_PASSE,
  indiceDaJanela,
  janelaDe,
  estadoDoPasse,
  decidirConcessao,
  decidirConsumo,
} = require("../lib/passe");

const DIA = 24 * 60 * 60 * 1000;
const T0 = "2026-08-01T12:00:00.000Z";
const emT0 = (deslocamentoMs) => new Date(Date.parse(T0) + deslocamentoMs).toISOString();

function passeNovo(agora = T0) {
  const d = decidirConcessao({ atual: null, agora, assinaturaAtiva: false });
  assert.equal(d.acao, CONCESSAO.CONCEDER);
  return d.proposta;
}

describe("PAS — o calendario", () => {
  test("PAS-01 a janela e de 15 dias e a validade de 7", () => {
    assert.equal(JANELA_MS, 15 * DIA);
    assert.equal(VALIDADE_MS, 7 * DIA);
  });

  test("PAS-02 o indice da janela e derivado do calendario, nao do uso", () => {
    assert.equal(indiceDaJanela(T0, T0), 0);
    assert.equal(indiceDaJanela(T0, emT0(14 * DIA)), 0);
    assert.equal(indiceDaJanela(T0, emT0(15 * DIA)), 1);
    assert.equal(indiceDaJanela(T0, emT0(29 * DIA)), 1);
    assert.equal(indiceDaJanela(T0, emT0(30 * DIA)), 2);
    assert.equal(indiceDaJanela(T0, emT0(300 * DIA)), 20);
  });

  test("PAS-03 o indice NAO depende de quando a rotina roda dentro da janela", () => {
    // Esta e a propriedade que uma chave por timestamp nao teria, e ela e a
    // razao de a idempotencia da concessao funcionar sob concorrencia.
    const dentroDaJanela3 = [45, 46, 50, 59.9].map((d) => emT0(d * DIA));
    for (const instante of dentroDaJanela3) {
      assert.equal(indiceDaJanela(T0, instante), 3, instante);
    }
  });

  test("PAS-04 os instantes da janela N", () => {
    const j = janelaDe(T0, 2);
    assert.equal(j.recebidoEm, emT0(30 * DIA));
    assert.equal(j.expiraEm, emT0(37 * DIA));
    assert.equal(j.proximaElegibilidadeEm, emT0(45 * DIA));
  });
});

describe("PAS — concessao", () => {
  test("PAS-05 a primeira visita ancora o ciclo e concede a janela 0", () => {
    const p = passeNovo();
    assert.equal(p.esquema, ESQUEMA_PASSE);
    assert.equal(p.ancoraEm, T0);
    assert.equal(p.indiceJanela, 0);
    assert.equal(p.usadoEm, null);
    assert.equal(p.expiraEm, emT0(7 * DIA));
  });

  test("PAS-06 dentro da mesma janela nao se concede de novo", () => {
    const p = passeNovo();
    for (const d of [0, 1, 7, 14.9]) {
      const r = decidirConcessao({ atual: p, agora: emT0(d * DIA), assinaturaAtiva: false });
      assert.equal(r.acao, CONCESSAO.NADA, `concedeu de novo no dia ${d}`);
    }
  });

  test("PAS-07 nem depois de o passe da janela ser usado", () => {
    // "Nao acumula" e "um por janela" sao a mesma regra vista de dois angulos.
    const usado = { ...passeNovo(), usadoEm: emT0(DIA), usadoNaAdmissao: "adm_1" };
    const r = decidirConcessao({ atual: usado, agora: emT0(5 * DIA), assinaturaAtiva: false });
    assert.equal(r.acao, CONCESSAO.NADA);
  });

  test("PAS-08 no dia 15 nasce a janela 1, e o passe anterior deixa de existir", () => {
    const usado = { ...passeNovo(), usadoEm: emT0(DIA), usadoNaAdmissao: "adm_1" };
    const r = decidirConcessao({ atual: usado, agora: emT0(15 * DIA), assinaturaAtiva: false });
    assert.equal(r.acao, CONCESSAO.CONCEDER);
    assert.equal(r.proposta.indiceJanela, 1);
    assert.equal(r.proposta.usadoEm, null);
    assert.equal(r.proposta.usadoNaAdmissao, null);
    // A ancora NAO se move: a cadencia e fixa.
    assert.equal(r.proposta.ancoraEm, T0);
  });

  test("PAS-09 quem volta no dia 100 recebe a janela do dia 100, e nao seis passes", () => {
    // O caso do jogador que sumiu. A materializacao sob demanda concede UMA
    // janela — a corrente —, nunca o acumulado do periodo ausente.
    const p = passeNovo();
    const r = decidirConcessao({ atual: p, agora: emT0(100 * DIA), assinaturaAtiva: false });
    assert.equal(r.acao, CONCESSAO.CONCEDER);
    assert.equal(r.proposta.indiceJanela, 6);
    assert.equal(r.proposta.recebidoEm, emT0(90 * DIA));
    assert.equal(r.proposta.expiraEm, emT0(97 * DIA));
    // E ele ja nasce vencido, porque a janela dele passou. Correto: o passe
    // vale 7 dias a partir do RECEBIMENTO, e o recebimento e do calendario.
    assert.equal(estadoDoPasse(r.proposta, emT0(100 * DIA)).utilizavel, false);
  });

  test("PAS-10 assinante ativo nao recebe, e a ancora nao se move", () => {
    const p = passeNovo();
    const r = decidirConcessao({ atual: p, agora: emT0(15 * DIA), assinaturaAtiva: true });
    assert.equal(r.acao, CONCESSAO.ASSINANTE);
    // Nada foi proposto: o documento no banco continua sendo `p`, com a mesma
    // ancora. Quem cancelar a assinatura volta a receber na janela seguinte,
    // sem carencia artificial.
    assert.equal(p.ancoraEm, T0);
  });

  test("PAS-11 assinante que cancela volta a receber na janela seguinte", () => {
    const p = passeNovo();
    // 45 dias como assinante: nenhuma concessao.
    assert.equal(
      decidirConcessao({ atual: p, agora: emT0(45 * DIA), assinaturaAtiva: true }).acao,
      CONCESSAO.ASSINANTE,
    );
    // Cancelou. A janela corrente e a 3, e ele a recebe imediatamente.
    const r = decidirConcessao({ atual: p, agora: emT0(46 * DIA), assinaturaAtiva: false });
    assert.equal(r.acao, CONCESSAO.CONCEDER);
    assert.equal(r.proposta.indiceJanela, 3);
  });

  test("PAS-12 relogio que anda para tras nao concede", () => {
    const p = decidirConcessao({ atual: null, agora: emT0(30 * DIA), assinaturaAtiva: false }).proposta;
    const r = decidirConcessao({ atual: p, agora: T0, assinaturaAtiva: false });
    assert.equal(r.acao, CONCESSAO.NADA);
  });
});

describe("PAS — o estado, contra o relogio", () => {
  test("PAS-13 utilizavel do dia 0 ao dia 7, exclusivo", () => {
    const p = passeNovo();
    assert.equal(estadoDoPasse(p, T0).utilizavel, true);
    assert.equal(estadoDoPasse(p, emT0(6.99 * DIA)).utilizavel, true);
    // No instante EXATO do vencimento ja nao vale.
    assert.equal(estadoDoPasse(p, emT0(7 * DIA)).utilizavel, false);
    assert.equal(estadoDoPasse(p, emT0(7.01 * DIA)).utilizavel, false);
  });

  test("PAS-14 usado deixa de ser utilizavel, mesmo dentro do prazo", () => {
    const usado = { ...passeNovo(), usadoEm: emT0(DIA), usadoNaAdmissao: "adm_1" };
    assert.equal(estadoDoPasse(usado, emT0(2 * DIA)).utilizavel, false);
  });

  test("PAS-15 a expiracao NAO gera escrita — ela e conclusao da leitura", () => {
    // O mesmo documento, sem nenhuma alteracao, responde `true` e depois
    // `false` so porque o relogio andou. Nao ha rotina que apague passe
    // vencido, e este teste e a prova de que nao precisa haver.
    const p = passeNovo();
    const antes = JSON.stringify(p);
    assert.equal(estadoDoPasse(p, emT0(3 * DIA)).utilizavel, true);
    assert.equal(estadoDoPasse(p, emT0(8 * DIA)).utilizavel, false);
    assert.equal(JSON.stringify(p), antes, "o documento foi modificado pela leitura");
  });

  test("PAS-16 o estado diz quando vem o proximo", () => {
    const p = passeNovo();
    assert.equal(estadoDoPasse(p, emT0(8 * DIA)).proximaElegibilidadeEm, emT0(15 * DIA));
  });

  test("PAS-17 o estado NUNCA e um veredito guardado", () => {
    // A disciplina do `PortaoVip`: guardar FATOS, recomputar a vigencia contra
    // o relogio a cada leitura, e nunca guardar `liberado: true`. Se alguem
    // acrescentar um campo booleano de vigencia ao documento, este teste cai.
    const p = passeNovo();
    for (const campo of Object.keys(p)) {
      assert.equal(
        typeof p[campo] === "boolean",
        false,
        `o documento passou a guardar um veredito booleano: ${campo}`,
      );
    }
  });
});

describe("PAS — consumo", () => {
  test("PAS-18 passe valido e consumido uma vez, e o consumo grava a admissao", () => {
    const p = passeNovo();
    const r = decidirConsumo({ atual: p, agora: emT0(DIA), admissaoId: "adm_42" });
    assert.equal(r.ok, true);
    assert.equal(r.documento.usadoEm, emT0(DIA));
    assert.equal(r.documento.usadoNaAdmissao, "adm_42");
  });

  test("PAS-19 o consumo NAO grava — ele propoe", () => {
    // Funcao pura. O documento original nao e tocado, e quem grava e a
    // transacao que ocupa o assento. Consumir aqui e sentar depois abriria a
    // janela em que o passe some sem o jogador entrar.
    const p = passeNovo();
    const antes = JSON.stringify(p);
    decidirConsumo({ atual: p, agora: emT0(DIA), admissaoId: "adm_42" });
    assert.equal(JSON.stringify(p), antes);
  });

  test("PAS-20 passe ja usado recusa", () => {
    const usado = { ...passeNovo(), usadoEm: emT0(DIA), usadoNaAdmissao: "adm_1" };
    const r = decidirConsumo({ atual: usado, agora: emT0(2 * DIA), admissaoId: "adm_2" });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_PASSE.JA_USADO);
  });

  test("PAS-21 abandono depois da admissao NAO devolve o passe", () => {
    // Nao ha funcao de devolucao neste modulo, e a ausencia e o entregavel.
    // Se alguem acrescentar `devolverPasse`, este teste cai — e a discussao
    // volta para a mesa, que e onde ela deve estar.
    const modulo = require("../lib/passe");
    for (const nome of Object.keys(modulo)) {
      assert.equal(
        /devolv|estorn|reembols|restaur|desfaz/i.test(nome),
        false,
        `apareceu um caminho de devolucao: ${nome}`,
      );
    }
  });

  test("PAS-22 passe expirado recusa", () => {
    const p = passeNovo();
    const r = decidirConsumo({ atual: p, agora: emT0(8 * DIA), admissaoId: "adm_1" });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_PASSE.EXPIRADO);
  });

  test("PAS-23 ausencia de passe recusa", () => {
    const r = decidirConsumo({ atual: null, agora: T0, admissaoId: "adm_1" });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_PASSE.INEXISTENTE);
  });

  test("PAS-24 passe de janela futura ainda nao vale", () => {
    const p = passeNovo();
    const futuro = { ...p, recebidoEm: emT0(15 * DIA), expiraEm: emT0(22 * DIA), indiceJanela: 1 };
    const r = decidirConsumo({ atual: futuro, agora: emT0(2 * DIA), admissaoId: "adm_1" });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_PASSE.AINDA_NAO_VIGENTE);
  });
});

describe("PAS-EST — provas estruturais", () => {
  const fonte = fs.readFileSync(
    path.join(__dirname, "..", "src", "passe.ts"),
    "utf8",
  );

  /** O CODIGO do modulo, sem os comentarios. */
  const codigo = fonte
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .split("\n")
    .filter((l) => !l.trim().startsWith("//"))
    .join("\n");

  test("PAS-EST-01 o modulo nao le o relogio", () => {
    // Uma funcao de elegibilidade que chama `Date.now()` por dentro nao tem
    // fronteira testavel — e a fronteira e onde o defeito mora.
    assert.equal(/Date\.now\(\)/.test(codigo), false);
    assert.equal(/new Date\(\)/.test(codigo), false);
  });

  test("PAS-EST-02 o modulo nao conhece Firestore nem firebase-admin", () => {
    assert.equal(/firebase-admin|getFirestore|firebase-functions/.test(codigo), false);
  });

  test("PAS-EST-03 o passe nao toca `playerEntitlements`", () => {
    // O caso 32 da OS: o passe nao cria entitlement VIP. A forma mais forte de
    // garantir isso e o dominio do passe nao saber que a colecao existe.
    assert.equal(/playerEntitlements|entitlement/i.test(codigo), false);
  });
});
