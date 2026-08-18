/**
 * Prova o CONTRATO CANONICO DAS ESTATISTICAS OFICIAIS DO PERFIL V1.
 *
 * A matriz de 30 casos da OS esta inteira aqui, e cada caso tem um nome que diz
 * o que ele afirma. Alem dela, esta suite prova tres coisas que a matriz nao
 * cobre e sem as quais o contrato nao valeria nada:
 *
 *   1. COERENCIA ENTRE O SCHEMA E O CODIGO. Os exemplos validos do arquivo
 *      docs/contratos/fato-partida-oficial-v1.schema.json tem de passar pelo
 *      analisador, e os invalidos tem de ser recusados por ele. Um schema que
 *      diverge do analisador e pior do que nenhum: ele promete ao vizinho
 *      (o servidor Railway) uma forma que a nossa porta nao aceita. As
 *      enumeracoes e a lista de campos obrigatorios tambem sao comparadas uma a
 *      uma com as constantes do TypeScript.
 *
 *   2. AUSENCIA DE ESCRITA. Uma varredura ESTRUTURAL do codigo-fonte dos tres
 *      modulos, com os comentarios removidos, atras de Firestore, rede, relogio,
 *      aleatoriedade e qualquer `require`. Nao ha como um teste de comportamento
 *      provar a ausencia de um efeito que ninguem chamou; a prova tem de ser
 *      sobre o texto.
 *
 *   3. SUPERFICIE DE IMPLANTACAO INTOCADA. `src/index.ts` nao importa nada
 *      deste dominio, entao nenhuma Cloud Function nova nasce. A mutacao
 *      "exportar nova Cloud Function" morre neste teste.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  analisarFatoPartidaOficial,
  chaveDeLancamento,
  chaveDoFato,
  VERSAO_CONTRATO_FATO_PARTIDA,
  MODALIDADES,
  MODALIDADES_ELEGIVEIS,
  ESTADOS_TERMINAIS,
  EQUIPES,
  CLASSES,
  AUTORIDADES,
} = require("../lib/estatisticas/contrato");
const {
  ESTATISTICAS_ZERADAS,
  aplicarDelta,
  derivar,
  validarAgregado,
} = require("../lib/estatisticas/agregado");
const {
  classificarElegibilidade,
  reduzirEnvelope,
  reduzirFatoPartidaOficial,
} = require("../lib/estatisticas/redutor");
// O varredor recursivo de campo proibido e o DA PROJECAO, e nao um segundo
// varredor escrito para esta suite. Duas opinioes sobre "o que e campo sensivel"
// e o defeito que esta OS existe para eliminar.
const { acharCampoProibido } = require("../lib/projecao");

const RAIZ = path.join(__dirname, "..", "..");
const SCHEMA = JSON.parse(
  fs.readFileSync(
    path.join(RAIZ, "docs", "contratos", "fato-partida-oficial-v1.schema.json"),
    "utf8"
  )
);

const clonar = (o) => JSON.parse(JSON.stringify(o));

/** Mesa publica RANQUEADA, concluida, vitoria de `nos`. Vem do schema. */
const baseRanqueada = () => clonar(SCHEMA.examples[0]);
/** Mesa publica CASUAL, concluida, EMPATE. Vem do schema. */
const baseEmpate = () => clonar(SCHEMA.examples[1]);

/** Mesa publica CASUAL, concluida, vitoria de `nos`. */
function baseCasual() {
  const f = baseRanqueada();
  f.modalidade = "publica_casual";
  f.ambienteCompetitivo = false;
  return f;
}

/** Le a reducao de um envelope que TEM de ser valido. */
function reduzir(envelope) {
  const r = reduzirEnvelope(envelope);
  assert.equal(r.ok, true, `envelope deveria ser valido: ${JSON.stringify(r.erros)}`);
  return r.reducao;
}

/** O delta de um assento. */
function deltaDoAssento(reducao, envelope, assento) {
  const p = envelope.participantes.find((x) => x.assento === assento);
  const d = reducao.deltas.find((x) => x.publicPlayerId === p.publicPlayerId);
  assert.ok(d, `sem delta para o assento ${assento}`);
  return d;
}

// ---------------------------------------------------------------------------
// 1 a 8 — ELEGIBILIDADE
// ---------------------------------------------------------------------------

describe("elegibilidade: o que conta e o que nao conta", () => {
  test("1. publica casual concluida CONTA", () => {
    const r = reduzir(baseCasual());
    assert.equal(r.elegivel, true);
    assert.equal(r.motivo, null);
    assert.equal(r.deltas.length, 4);
  });

  test("2. publica ranqueada concluida CONTA", () => {
    const r = reduzir(baseRanqueada());
    assert.equal(r.elegivel, true);
    assert.equal(r.deltas.length, 4);
  });

  test("3. privada NAO conta", () => {
    const f = baseCasual();
    f.modalidade = "privada";
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "modalidade_nao_elegivel");
    assert.deepEqual(r.deltas, []);
  });

  test("4. treino NAO conta", () => {
    const f = baseCasual();
    f.modalidade = "treino";
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "modalidade_nao_elegivel");
    assert.deepEqual(r.deltas, []);
  });

  test("5. simulada NAO conta", () => {
    const f = baseCasual();
    f.modalidade = "simulada";
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "modalidade_nao_elegivel");
    assert.deepEqual(r.deltas, []);
  });

  test("6. cancelada NAO conta", () => {
    const f = baseCasual();
    f.estadoTerminal = "cancelada";
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "estado_nao_concluido");
    assert.deepEqual(r.deltas, []);
  });

  test("6b. abandonada NAO conta nesta versao — nao ha responsavel identificavel", () => {
    const f = baseCasual();
    f.estadoTerminal = "abandonada";
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "estado_nao_concluido");
  });

  test("7. sem encerramento autoritativo NAO conta", () => {
    const f = baseCasual();
    f.encerramentoAutoritativo = false;
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "sem_encerramento_autoritativo");
    assert.deepEqual(r.deltas, []);
  });

  test("8. robo participante torna a partida INELEGIVEL", () => {
    const f = baseCasual();
    f.participantes[3].classe = "robo";
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "participacao_de_robo");
    assert.deepEqual(r.deltas, []);
  });

  test("8b. substituicao definitiva por robo torna a partida INELEGIVEL", () => {
    const f = baseCasual();
    f.participantes[1].substituidoPorBot = true;
    f.houveSubstituicaoPorBot = true;
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "participacao_de_robo");
  });

  test("5b. torneio NAO conta, e e RECUSA DE ELEGIBILIDADE, nao de envelope", () => {
    const f = baseCasual();
    f.modalidade = "torneio";
    // O envelope e ACEITO: torneio e modalidade conhecida.
    const analise = analisarFatoPartidaOficial(f);
    assert.equal(analise.ok, true, JSON.stringify(analise.erros));
    // E nao produz nada.
    const r = reduzir(f);
    assert.equal(r.elegivel, false);
    assert.equal(r.motivo, "modalidade_nao_elegivel");
    assert.deepEqual(r.deltas, []);
    // E a chave do fato existe mesmo assim — o escritor precisa dela para
    // reconhecer a entrega repetida de uma partida que nao conta.
    assert.equal(r.chaveDoFato, `${f.matchId}|${f.eventoId}`);
  });

  test("5c. torneio marcado como ambiente competitivo RECUSA o envelope", () => {
    const f = baseCasual();
    f.modalidade = "torneio";
    f.ambienteCompetitivo = true;
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false);
    assert.ok(r.erros.some((e) => e.startsWith("ambienteCompetitivo")));
  });

  test("modalidade CONHECIDA e inelegivel e simbolo DESCONHECIDO tem respostas diferentes", () => {
    // Conhecida e inelegivel: envelope valido, zero delta, motivo nomeado.
    for (const conhecida of ["torneio", "privada", "treino", "simulada"]) {
      const f = baseCasual();
      f.modalidade = conhecida;
      const r = reduzirEnvelope(f);
      assert.equal(r.ok, true, `${conhecida} deveria ser envelope valido`);
      assert.equal(r.reducao.elegivel, false);
      assert.equal(r.reducao.motivo, "modalidade_nao_elegivel");
      assert.deepEqual(r.reducao.deltas, []);
    }
    // Desconhecida: nao ha reducao nenhuma — o envelope inteiro e recusado, e
    // isso e defeito do produtor, nao dia a dia.
    for (const desconhecida of ["publica", "treinamento", "contra_robos"]) {
      const f = baseCasual();
      f.modalidade = desconhecida;
      const r = reduzirEnvelope(f);
      assert.equal(r.ok, false, `${desconhecida} deveria recusar o envelope`);
      assert.equal(r.reducao, undefined);
    }
  });

  test("as seis modalidades do contrato sao classificadas sem excecao", () => {
    for (const modalidade of MODALIDADES) {
      const f = baseCasual();
      f.modalidade = modalidade;
      f.ambienteCompetitivo = modalidade === "publica_ranqueada";
      const r = reduzir(f);
      const esperado = MODALIDADES_ELEGIVEIS.includes(modalidade);
      assert.equal(r.elegivel, esperado, `modalidade ${modalidade}`);
    }
  });
});

// ---------------------------------------------------------------------------
// 9 a 13 — RESULTADO
// ---------------------------------------------------------------------------

describe("resultado: vitoria, derrota e empate", () => {
  test("9. a dupla vencedora recebe DUAS vitorias", () => {
    const f = baseRanqueada();
    const r = reduzir(f);
    for (const assento of [0, 2]) {
      const d = deltaDoAssento(r, f, assento);
      assert.equal(d.vitorias, 1);
      assert.equal(d.derrotas, 0);
      assert.equal(d.empates, 0);
      assert.equal(d.partidas, 1);
    }
    const total = r.deltas.reduce((s, d) => s + d.vitorias, 0);
    assert.equal(total, 2);
  });

  test("10. a dupla perdedora recebe DUAS derrotas", () => {
    const f = baseRanqueada();
    const r = reduzir(f);
    for (const assento of [1, 3]) {
      const d = deltaDoAssento(r, f, assento);
      assert.equal(d.derrotas, 1);
      assert.equal(d.vitorias, 0);
      assert.equal(d.partidas, 1);
    }
    const total = r.deltas.reduce((s, d) => s + d.derrotas, 0);
    assert.equal(total, 2);
  });

  test("11. empate: QUATRO partidas e QUATRO empates", () => {
    const r = reduzir(baseEmpate());
    assert.equal(r.deltas.reduce((s, d) => s + d.partidas, 0), 4);
    assert.equal(r.deltas.reduce((s, d) => s + d.empates, 0), 4);
  });

  test("12. empate produz ZERO vitoria", () => {
    const r = reduzir(baseEmpate());
    assert.equal(r.deltas.reduce((s, d) => s + d.vitorias, 0), 0);
  });

  test("13. empate produz ZERO derrota", () => {
    const r = reduzir(baseEmpate());
    assert.equal(r.deltas.reduce((s, d) => s + d.derrotas, 0), 0);
  });

  test("cada jogador elegivel recebe EXATAMENTE uma partida", () => {
    for (const envelope of [baseRanqueada(), baseCasual(), baseEmpate()]) {
      const r = reduzir(envelope);
      for (const d of r.deltas) assert.equal(d.partidas, 1);
    }
  });
});

// ---------------------------------------------------------------------------
// 14 a 16 — CANASTRAS
// ---------------------------------------------------------------------------

describe("canastras: fato da dupla, creditado aos dois integrantes", () => {
  test("14. canastra LIMPA e creditada aos dois parceiros", () => {
    const f = baseRanqueada();
    f.equipes.nos.canastrasLimpas = 3;
    const r = reduzir(f);
    assert.equal(deltaDoAssento(r, f, 0).canastrasLimpas, 3);
    assert.equal(deltaDoAssento(r, f, 2).canastrasLimpas, 3);
  });

  test("15. canastra SUJA e creditada aos dois parceiros", () => {
    const f = baseRanqueada();
    f.equipes.nos.canastrasSujas = 5;
    const r = reduzir(f);
    assert.equal(deltaDoAssento(r, f, 0).canastrasSujas, 5);
    assert.equal(deltaDoAssento(r, f, 2).canastrasSujas, 5);
  });

  test("16. o adversario NAO recebe a canastra da outra dupla", () => {
    const f = baseRanqueada();
    f.equipes.nos.canastrasLimpas = 4;
    f.equipes.nos.canastrasSujas = 1;
    f.equipes.eles.canastrasLimpas = 0;
    f.equipes.eles.canastrasSujas = 2;
    const r = reduzir(f);
    for (const assento of [1, 3]) {
      const d = deltaDoAssento(r, f, assento);
      assert.equal(d.canastrasLimpas, 0);
      assert.equal(d.canastrasSujas, 2);
    }
    for (const assento of [0, 2]) {
      const d = deltaDoAssento(r, f, assento);
      assert.equal(d.canastrasLimpas, 4);
      assert.equal(d.canastrasSujas, 1);
    }
  });

  test("nenhum delta carrega canastra individual — o campo nao existe", () => {
    const r = reduzir(baseRanqueada());
    for (const d of r.deltas) {
      assert.deepEqual(
        Object.keys(d).sort(),
        [
          "canastrasLimpas",
          "canastrasSujas",
          "chaveDeLancamento",
          "derrotas",
          "empates",
          "partidas",
          "publicPlayerId",
          "vitorias",
          "xpTotal",
        ]
      );
    }
  });
});

// ---------------------------------------------------------------------------
// 17 e 18 — IDEMPOTENCIA
// ---------------------------------------------------------------------------

describe("idempotencia: reconexao e reenvio", () => {
  test("17. reconexao mantem o mesmo matchId, e a chave de lancamento nao muda", () => {
    const antes = baseRanqueada();
    const depois = baseRanqueada();
    // A reconexao produz uma nova AFIRMACAO sobre a MESMA partida.
    depois.eventoId = "evt-9f3ac21b-encerramento-2";

    const rAntes = reduzir(antes);
    const rDepois = reduzir(depois);

    assert.notEqual(rAntes.chaveDoFato, rDepois.chaveDoFato);
    for (const p of antes.participantes) {
      const a = rAntes.deltas.find((d) => d.publicPlayerId === p.publicPlayerId);
      const b = rDepois.deltas.find((d) => d.publicPlayerId === p.publicPlayerId);
      assert.equal(a.chaveDeLancamento, b.chaveDeLancamento);
      assert.equal(
        a.chaveDeLancamento,
        `${antes.matchId}|${p.publicPlayerId}|estatisticasOficiais|v1`
      );
    }
  });

  test("18. duplicacao de eventoId e IDENTIFICAVEL pela chave do fato", () => {
    const f = baseRanqueada();
    const primeira = reduzir(f);
    const segunda = reduzir(clonar(f));
    assert.equal(primeira.chaveDoFato, segunda.chaveDoFato);
    assert.equal(primeira.chaveDoFato, `${f.matchId}|${f.eventoId}`);
    assert.deepEqual(primeira.deltas, segunda.deltas);
  });

  test("reduzir o mesmo fato duas vezes produz resultado identico", () => {
    const f = baseEmpate();
    assert.deepEqual(reduzir(f), reduzir(clonar(f)));
  });

  test("a chave de lancamento nao depende do eventoId, por construcao", () => {
    const chave = chaveDeLancamento("mtc-abc-12345678", "PQ7R4M2N8K3VW");
    assert.equal(chave, "mtc-abc-12345678|PQ7R4M2N8K3VW|estatisticasOficiais|v1");
  });

  test("a chave do fato e matchId|eventoId", () => {
    const analise = analisarFatoPartidaOficial(baseRanqueada());
    assert.equal(analise.ok, true);
    assert.equal(
      chaveDoFato(analise.fato),
      `${analise.fato.matchId}|${analise.fato.eventoId}`
    );
  });
});

// ---------------------------------------------------------------------------
// 19 e 20 — IDENTIDADE E PRIVACIDADE
// ---------------------------------------------------------------------------

describe("identidade: publico e interno nao se misturam", () => {
  test("19. o UID NUNCA aparece no que sai do redutor", () => {
    for (const envelope of [baseRanqueada(), baseCasual(), baseEmpate()]) {
      const r = reduzir(envelope);
      // Varredura recursiva com o varredor da projecao, que bane uid, userId,
      // email, deviceId e mais seis nomes.
      assert.equal(acharCampoProibido(r), null);
      // E a prova direta: nenhum valor de uid do envelope aparece no texto.
      const texto = JSON.stringify(r);
      for (const p of envelope.participantes) {
        assert.equal(texto.includes(p.uid), false, `uid vazou: ${p.uid}`);
        assert.equal(texto.includes(p.publicPlayerId), true);
      }
    }
  });

  test("19b. o fato analisado guarda o uid — a fronteira e o delta, e nao o envelope", () => {
    const analise = analisarFatoPartidaOficial(baseRanqueada());
    assert.equal(analise.ok, true);
    assert.equal(analise.fato.participantes[0].uid, "uid-firebase-aaa");
  });

  test("20. identificador local do aparelho e RECUSADO", () => {
    const f = baseCasual();
    f.deviceId = "aparelho-9f21";
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false);
    assert.ok(r.erros.some((e) => e.includes("deviceId")));
  });

  test("20b. o id local do cofre de contas.js nao passa por publicPlayerId", () => {
    const f = baseCasual();
    // `contas.js` usa um id gerado no aparelho, estilo "continuar como
    // convidado". Ele nao tem a forma do id publico canonico.
    f.participantes[0].publicPlayerId = "conv-9f21a8c3";
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false);
    assert.ok(r.erros.some((e) => e.includes("publicPlayerId")));
  });

  test("20c. um uid do Firebase no lugar do id publico e recusado", () => {
    const f = baseCasual();
    f.participantes[2].publicPlayerId = "uid-firebase-ccc";
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false);
  });
});

// ---------------------------------------------------------------------------
// 21 a 24 — AGREGADO E DERIVADOS
// ---------------------------------------------------------------------------

describe("agregado: invariantes e derivados", () => {
  test("21. zero partidas produz 0%, e nao NaN nem infinito", () => {
    const d = derivar(ESTATISTICAS_ZERADAS);
    assert.equal(d.aproveitamento, 0);
    assert.equal(Number.isFinite(d.aproveitamento), true);
    assert.equal(d.canastras, 0);
  });

  test("22. o aproveitamento inclui o EMPATE no denominador", () => {
    const a = {
      ...ESTATISTICAS_ZERADAS,
      partidas: 4,
      vitorias: 2,
      empates: 1,
      derrotas: 1,
    };
    assert.deepEqual(validarAgregado(a), []);
    // 2 de 4 = 50%. Se o empate saisse do denominador seriam 2 de 3 = 66,7%.
    assert.equal(derivar(a).aproveitamento, 50);
  });

  test("22b. o aproveitamento fica entre 0 e 100", () => {
    const casos = [
      [0, 0, 0, 0],
      [1, 1, 0, 0],
      [10, 0, 0, 10],
      [7, 3, 2, 2],
    ];
    for (const [partidas, vitorias, empates, derrotas] of casos) {
      const a = { ...ESTATISTICAS_ZERADAS, partidas, vitorias, empates, derrotas };
      assert.deepEqual(validarAgregado(a), [], JSON.stringify(a));
      const ap = derivar(a).aproveitamento;
      assert.ok(ap >= 0 && ap <= 100, `aproveitamento fora da faixa: ${ap}`);
    }
  });

  test("23. agregado NEGATIVO e recusado, e nao normalizado", () => {
    const a = { ...ESTATISTICAS_ZERADAS, vitorias: -1 };
    const erros = validarAgregado(a);
    assert.ok(erros.length > 0);
    assert.ok(erros.some((e) => e.startsWith("vitorias")));
  });

  test("23b. contador fracionario ou ilegivel e recusado", () => {
    for (const valor of [1.5, "3", null, undefined, NaN]) {
      const a = { ...ESTATISTICAS_ZERADAS, partidas: valor };
      assert.ok(validarAgregado(a).length > 0, `aceitou ${String(valor)}`);
    }
  });

  test("24. quebra de `partidas = vitorias + empates + derrotas` e recusada", () => {
    const a = { ...ESTATISTICAS_ZERADAS, partidas: 5, vitorias: 2, empates: 1, derrotas: 1 };
    const erros = validarAgregado(a);
    assert.ok(erros.some((e) => e.includes("vitorias + empates + derrotas")));
  });

  test("aplicar os deltas de uma partida preserva os invariantes", () => {
    const f = baseRanqueada();
    const r = reduzir(f);
    for (const d of r.deltas) {
      const depois = aplicarDelta(ESTATISTICAS_ZERADAS, d, f.encerradaEm);
      assert.deepEqual(validarAgregado(depois), []);
      assert.equal(depois.partidas, 1);
      assert.equal(depois.atualizadoEm, f.encerradaEm);
    }
  });

  test("aplicarDelta nao muta a entrada", () => {
    const f = baseRanqueada();
    const antes = clonar(ESTATISTICAS_ZERADAS);
    aplicarDelta(ESTATISTICAS_ZERADAS, reduzir(f).deltas[0], f.encerradaEm);
    assert.deepEqual(ESTATISTICAS_ZERADAS, antes);
  });

  test("aplicar duas partidas soma os contadores e o total de canastras deriva", () => {
    const f = baseRanqueada();
    const d = reduzir(f).deltas.find((x) => x.vitorias === 1);
    const um = aplicarDelta(ESTATISTICAS_ZERADAS, d, f.encerradaEm);
    const dois = aplicarDelta(um, d, f.encerradaEm);
    assert.equal(dois.partidas, 2);
    assert.equal(dois.vitorias, 2);
    assert.equal(derivar(dois).aproveitamento, 100);
    assert.equal(
      derivar(dois).canastras,
      dois.canastrasLimpas + dois.canastrasSujas
    );
  });
});

// ---------------------------------------------------------------------------
// 25 e 26 — ENVELOPE
// ---------------------------------------------------------------------------

describe("envelope: recusa e nao normalizacao", () => {
  test("25. versao desconhecida e RECUSADA", () => {
    for (const versao of [0, 2, "1", null, undefined]) {
      const f = baseCasual();
      f.versaoContrato = versao;
      const r = reduzirEnvelope(f);
      assert.equal(r.ok, false, `aceitou versao ${String(versao)}`);
      assert.ok(r.erros.some((e) => e.startsWith("versaoContrato")));
    }
  });

  test("26. campo inesperado no envelope e RECUSADO", () => {
    const f = baseCasual();
    f.moedas = 250;
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false);
    assert.ok(r.erros.some((e) => e.includes('campo inesperado "moedas"')));
  });

  test("26b. campo inesperado dentro de participante, equipe ou origem tambem recusa", () => {
    const casos = [
      (f) => { f.participantes[0].canastras = 3; },
      (f) => { f.equipes.nos.xp = 100; },
      (f) => { f.origem.token = "segredo"; },
    ];
    for (const sujar of casos) {
      const f = baseCasual();
      sujar(f);
      assert.equal(reduzirEnvelope(f).ok, false);
    }
  });

  test("modalidade desconhecida e RECUSADA — nada de equivalente silencioso", () => {
    // Os simbolos dos outros vocabularios que NAO tem correspondente neste.
    // `torneio` saiu desta lista de proposito: ele agora e conhecido, e a
    // diferenca entre conhecido-inelegivel e desconhecido tem teste proprio.
    for (const alheia of ["publica", "treinamento", "contra_robos", "PUBLICA_CASUAL", "ranqueada"]) {
      const f = baseCasual();
      f.modalidade = alheia;
      const r = reduzirEnvelope(f);
      assert.equal(r.ok, false, `aceitou modalidade ${alheia}`);
      assert.ok(r.erros.some((e) => e.startsWith("modalidade")));
    }
  });

  test("envelope incompleto e recusado, campo a campo", () => {
    for (const campo of SCHEMA.required) {
      const f = baseCasual();
      delete f[campo];
      assert.equal(reduzirEnvelope(f).ok, false, `aceitou sem ${campo}`);
    }
  });

  test("a lei da mesa e conferida: assento par e `nos`, impar e `eles`", () => {
    const f = baseCasual();
    f.participantes[1].equipe = "nos";
    const r = reduzirEnvelope(f);
    assert.equal(r.ok, false);
    assert.ok(r.erros.some((e) => e.includes("lei da mesa")));
  });

  test("ambiente competitivo incoerente com a modalidade recusa o envelope", () => {
    const f = baseCasual();
    f.ambienteCompetitivo = true;
    assert.equal(reduzirEnvelope(f).ok, false);
    const g = baseRanqueada();
    g.ambienteCompetitivo = false;
    assert.equal(reduzirEnvelope(g).ok, false);
  });

  test("empate e ladoVencedor nao podem se contradizer", () => {
    const f = baseEmpate();
    f.ladoVencedor = "nos";
    assert.equal(reduzirEnvelope(f).ok, false);
    const g = baseCasual();
    g.empate = true;
    assert.equal(reduzirEnvelope(g).ok, false);
  });

  test("instante sem fuso, sem Z ou impossivel e recusado", () => {
    for (const instante of ["2026-08-17 21:04:11", "2026-08-17T21:04:11", "2026-13-45T99:99:99Z", ""]) {
      const f = baseCasual();
      f.encerradaEm = instante;
      assert.equal(reduzirEnvelope(f).ok, false, `aceitou ${instante}`);
    }
  });

  test("mesa que nao tem os quatro assentos e recusada", () => {
    const f = baseCasual();
    f.participantes[2].assento = 0;
    f.participantes[2].equipe = "nos";
    assert.equal(reduzirEnvelope(f).ok, false);
  });

  test("identidade repetida na mesma mesa e recusada", () => {
    const f = baseCasual();
    f.participantes[2].publicPlayerId = f.participantes[0].publicPlayerId;
    assert.equal(reduzirEnvelope(f).ok, false);
  });

  test("houveSubstituicaoPorBot tem de bater com o que os assentos declaram", () => {
    const f = baseCasual();
    f.houveSubstituicaoPorBot = true;
    assert.equal(reduzirEnvelope(f).ok, false);
  });
});

// ---------------------------------------------------------------------------
// 27 a 29 — XP, NIVEL E TITULO
// ---------------------------------------------------------------------------

describe("XP, nivel e titulo: contrato reservado, recompensa nao inventada", () => {
  test("27. o XP permanece ZERO sem concessao autorizada", () => {
    const f = baseRanqueada();
    const r = reduzir(f);
    for (const d of r.deltas) assert.equal(d.xpTotal, 0);
    let a = ESTATISTICAS_ZERADAS;
    for (const d of r.deltas) a = aplicarDelta(a, d, f.encerradaEm);
    assert.equal(a.xpTotal, 0);
    assert.equal(a.versaoXp, null);
  });

  test("27b. XP concedido sem politica declarada e RECUSADO pelo agregado", () => {
    const a = { ...ESTATISTICAS_ZERADAS, xpTotal: 140 };
    const erros = validarAgregado(a);
    assert.ok(erros.some((e) => e.startsWith("xpTotal")));
  });

  test("28. nenhuma formula local de nivel e promovida — nivel e null", () => {
    assert.equal(derivar(ESTATISTICAS_ZERADAS).nivel, null);
    const a = { ...ESTATISTICAS_ZERADAS, partidas: 30, vitorias: 20, derrotas: 10 };
    assert.equal(derivar(a).nivel, null);
    // Mesmo com uma politica na mao, ela so vale se o agregado disser que foi
    // ELA quem concedeu o XP. `versaoXp` e null, entao nao vale.
    const politica = { versao: "servidor-node", nivelDe: () => 24 };
    assert.equal(derivar(a, politica).nivel, null);
  });

  test("28b. o modulo do agregado NAO exporta implementacao de politica de XP", () => {
    const modulo = require("../lib/estatisticas/agregado");
    const funcoes = Object.keys(modulo).filter((k) => typeof modulo[k] === "function");
    assert.deepEqual(funcoes.sort(), ["aplicarDelta", "derivar", "validarAgregado"]);
    for (const k of Object.keys(modulo)) {
      const v = modulo[k];
      const ehPolitica =
        v !== null && typeof v === "object" && typeof v.nivelDe === "function";
      assert.equal(ehPolitica, false, `${k} parece uma politica de XP`);
    }
  });

  test("29. o titulo NAO e calculado pelo redutor", () => {
    const r = reduzir(baseRanqueada());
    const texto = JSON.stringify(r).toLowerCase();
    for (const palavra of ["titulo", "title", "liga", "rainha"]) {
      assert.equal(texto.includes(palavra), false, `o redutor mencionou "${palavra}"`);
    }
    const derivados = derivar(ESTATISTICAS_ZERADAS);
    assert.deepEqual(Object.keys(derivados).sort(), ["aproveitamento", "canastras", "nivel"]);
  });
});

// ---------------------------------------------------------------------------
// 30 — AUSENCIA DE ESCRITA, PROVADA NO TEXTO
// ---------------------------------------------------------------------------

const FONTES = ["contrato.ts", "agregado.ts", "redutor.ts"];

function codigoSemComentarios(arquivo) {
  const bruto = fs.readFileSync(
    path.join(__dirname, "..", "src", "estatisticas", arquivo),
    "utf8"
  );
  const semBloco = bruto.replace(/\/\*[\s\S]*?\*\//g, "");
  return semBloco
    .split("\n")
    .map((linha) => linha.split("//")[0])
    .join("\n");
}

describe("30. nenhuma escrita externa acontece", () => {
  test("o codigo dos tres modulos nao menciona persistencia, rede, relogio nem sorteio", () => {
    const proibidos = [
      "firebase",
      "firestore",
      "firebase-admin",
      "admin.",
      "FieldValue",
      "collection(",
      ".set(",
      ".update(",
      ".delete(",
      "increment",
      "onCall",
      "onDocument",
      "onSchedule",
      "fetch(",
      "XMLHttpRequest",
      "require(",
      "process.",
      "Date.now",
      "Math.random",
      "setTimeout",
      "setInterval",
      "console.",
    ];
    for (const arquivo of FONTES) {
      const codigo = codigoSemComentarios(arquivo);
      for (const token of proibidos) {
        assert.equal(
          codigo.includes(token),
          false,
          `${arquivo} contem "${token}" fora de comentario`
        );
      }
    }
  });

  test("os modulos so importam do proprio dominio e da projecao ja existente", () => {
    const permitidos = new Set(["../identidade", "../projecao", "./contrato", "./agregado"]);
    for (const arquivo of FONTES) {
      const codigo = codigoSemComentarios(arquivo);
      const encontrados = [...codigo.matchAll(/from\s+"([^"]+)"/g)].map((m) => m[1]);
      for (const alvo of encontrados) {
        assert.equal(permitidos.has(alvo), true, `${arquivo} importa ${alvo}`);
      }
    }
  });

  test("nenhuma Cloud Function nova nasce: src/index.ts nao conhece este dominio", () => {
    const index = fs.readFileSync(path.join(__dirname, "..", "src", "index.ts"), "utf8");
    assert.equal(index.includes("estatisticas/"), false);
    assert.equal(index.includes("./estatisticas"), false);
    // A contagem de funcoes exportadas do entrypoint e a mesma de antes desta OS.
    const exportados = [...index.matchAll(/^export const /gm)].length;
    assert.equal(exportados, 11);
  });

  test("o redutor devolve valor e nao produz efeito observavel", () => {
    const f = baseRanqueada();
    const congelado = Object.freeze(clonar(f));
    const r = reduzirEnvelope(congelado);
    assert.equal(r.ok, true);
    // O envelope de entrada sai intacto: nada foi anotado nele.
    assert.deepEqual(congelado, clonar(f));
  });
});

// ---------------------------------------------------------------------------
// COERENCIA ENTRE O SCHEMA COMPARTILHAVEL E O CODIGO
// ---------------------------------------------------------------------------

describe("schema: o artefato compartilhavel diz a mesma coisa que o codigo", () => {
  test("a versao do schema e a versao do contrato", () => {
    assert.equal(SCHEMA["x-versaoContrato"], VERSAO_CONTRATO_FATO_PARTIDA);
    assert.equal(SCHEMA.properties.versaoContrato.const, VERSAO_CONTRATO_FATO_PARTIDA);
  });

  test("as enumeracoes do schema sao as do TypeScript, sem sobra nem falta", () => {
    assert.deepEqual(SCHEMA.properties.modalidade.enum, [...MODALIDADES]);
    assert.deepEqual(SCHEMA.properties.estadoTerminal.enum, [...ESTADOS_TERMINAIS]);
    assert.deepEqual(SCHEMA.$defs.participante.properties.equipe.enum, [...EQUIPES]);
    assert.deepEqual(SCHEMA.$defs.participante.properties.classe.enum, [...CLASSES]);
    assert.deepEqual(SCHEMA.$defs.origem.properties.autoridade.enum, [...AUTORIDADES]);
  });

  test("a lista de campos obrigatorios do schema e a do analisador", () => {
    assert.deepEqual(
      [...SCHEMA.required].sort(),
      Object.keys(SCHEMA.properties).sort()
    );
    // E o analisador aceita exatamente esse conjunto: um campo a mais recusa.
    const f = baseCasual();
    assert.deepEqual(Object.keys(f).sort(), [...SCHEMA.required].sort());
  });

  test("o envelope autoritativo proibe propriedade inesperada em todos os niveis", () => {
    assert.equal(SCHEMA.additionalProperties, false);
    assert.equal(SCHEMA.properties.equipes.additionalProperties, false);
    assert.equal(SCHEMA.$defs.resultadoDaEquipe.additionalProperties, false);
    assert.equal(SCHEMA.$defs.participante.additionalProperties, false);
    assert.equal(SCHEMA.$defs.origem.additionalProperties, false);
  });

  test("todos os exemplos VALIDOS do schema passam pelo analisador", () => {
    assert.ok(SCHEMA.examples.length >= 2);
    for (const exemplo of SCHEMA.examples) {
      const r = analisarFatoPartidaOficial(exemplo);
      assert.equal(r.ok, true, `exemplo recusado: ${JSON.stringify(r.erros)}`);
    }
  });

  test("todos os exemplos INVALIDOS do schema sao recusados pelo analisador", () => {
    const invalidos = SCHEMA["x-exemplosInvalidos"];
    assert.ok(invalidos.length >= 8);
    for (const caso of invalidos) {
      const r = analisarFatoPartidaOficial(caso.envelope);
      assert.equal(r.ok, false, `exemplo invalido foi aceito: ${caso.motivo}`);
    }
  });

  test("os exemplos VALIDOS E INELEGIVEIS do schema sao aceitos e nao geram delta", () => {
    const inelegiveis = SCHEMA["x-exemplosValidosInelegiveis"];
    assert.ok(inelegiveis.length >= 2);
    const modalidades = new Set();
    for (const caso of inelegiveis) {
      const analise = analisarFatoPartidaOficial(caso.envelope);
      assert.equal(analise.ok, true, `recusado: ${caso.motivo}`);
      const r = reduzirFatoPartidaOficial(analise.fato);
      assert.equal(r.elegivel, false, `elegivel indevidamente: ${caso.motivo}`);
      assert.equal(r.motivo, "modalidade_nao_elegivel");
      assert.deepEqual(r.deltas, []);
      modalidades.add(caso.envelope.modalidade);
    }
    // O artefato tem de mostrar o caso do torneio, que e o menos obvio.
    assert.equal(modalidades.has("torneio"), true);
  });

  test("os exemplos validos do schema sao ELEGIVEIS — o artefato mostra o caso feliz", () => {
    for (const exemplo of SCHEMA.examples) {
      const r = reduzir(exemplo);
      assert.equal(r.elegivel, true, `exemplo inelegivel: ${exemplo.matchId}`);
      assert.equal(r.deltas.length, 4);
    }
  });

  test("classificarElegibilidade e a mesma decisao que reduzirFatoPartidaOficial usa", () => {
    for (const envelope of [baseRanqueada(), baseCasual(), baseEmpate()]) {
      const analise = analisarFatoPartidaOficial(envelope);
      assert.equal(analise.ok, true);
      const motivo = classificarElegibilidade(analise.fato);
      const reducao = reduzirFatoPartidaOficial(analise.fato);
      assert.equal(reducao.motivo, motivo);
      assert.equal(reducao.elegivel, motivo === null);
    }
  });
});
