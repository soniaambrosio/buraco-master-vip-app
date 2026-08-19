/**
 * A REGRA DO PASSE VIP QUINZENAL DE CORTESIA — decisão pura, sem banco.
 *
 * Quatro eixos, na ordem em que o benefício acontece:
 *   TEMPO      as duas fronteiras — sete dias de validade, quinze de ciclo;
 *   CICLO      criar, reaproveitar, aguardar, e o que NUNCA acumula;
 *   ESTADO     o que o documento persistido pode dizer, e o que faz falhar fechado;
 *   PROJECAO   o que o dono vê, o que qualquer um vê, e o que ninguém vê.
 *   RECIBO     a idempotência que a OS de admissão vai consumir.
 *
 * SEM EMULADOR AQUI, DE PROPÓSITO. Transação, concorrência e Rules têm suíte
 * própria (`integracao.passe.emulador.test.js` e `firebase/testes/passe.test.js`),
 * e são provas que só o banco dá. Esta suíte prova a REGRA, e ela tem de rodar
 * na máquina de quem está escrevendo, sem subir nada.
 *
 * O RELÓGIO É INJETADO em todo caso. Nenhum teste aqui espera sete dias, e
 * nenhum depende do relógio da máquina — o que se prova é a ARITMÉTICA da
 * concessão, e ela não pode variar com o fuso de quem roda.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  VERSAO_CONTRATO_PASSE,
  DIAS_DE_VALIDADE,
  DIAS_DE_CICLO,
  MS_DE_VALIDADE,
  MS_DE_CICLO,
  instanteDeIso,
  isoDeInstante,
  instanteEfetivo,
  lerControle,
  decidirMaterializacao,
  planejarCiclo,
  passeDisponivel,
  projecaoDoProprietario,
  projecaoPublica,
  planejarRecibo,
  aplicarConsumo,
  contextoEstavelDe,
  contextosCoincidem,
} = require("../lib/passe");

// ---------------------------------------------------------------------------
// arnês
// ---------------------------------------------------------------------------

const T0 = Date.UTC(2026, 7, 17, 12, 0, 0);
const DIA = 24 * 60 * 60 * 1000;
const UID = "uid-jogador";

/// Um controle com um ciclo recebido em `recebidoEmMs`, coerente por construção.
/// Coerente POR CONSTRUÇÃO importa: um fixture que já nasça com a janela errada
/// provaria `lerControle` contra si mesmo em vez de provar a regra.
function controleCom({ recebidoEmMs = T0, consumidoEmMs = null, cicloId = "ciclo-1", ultimaMaterializacaoMs = null, cicloEncerradoEmMs = null } = {}) {
  return {
    versaoContrato: VERSAO_CONTRATO_PASSE,
    cicloAtualId: cicloId,
    recebidoEm: isoDeInstante(recebidoEmMs),
    validoAte: isoDeInstante(recebidoEmMs + MS_DE_VALIDADE),
    proximaElegibilidadeEm: isoDeInstante(recebidoEmMs + MS_DE_CICLO),
    consumidoEm: consumidoEmMs === null ? null : isoDeInstante(consumidoEmMs),
    cicloEncerradoEm: cicloEncerradoEmMs === null ? null : isoDeInstante(cicloEncerradoEmMs),
    ultimaMaterializacaoEm: ultimaMaterializacaoMs === null ? null : isoDeInstante(ultimaMaterializacaoMs),
  };
}

function cicloCom({ recebidoEmMs = T0, consumidoEmMs = null, encerradoEmMs = null, tentativaEntradaId = null, admissaoId = null, cicloId = "ciclo-1", contextoDoRecibo = undefined } = {}) {
  return {
    cicloId,
    recebidoEm: isoDeInstante(recebidoEmMs),
    validoAte: isoDeInstante(recebidoEmMs + MS_DE_VALIDADE),
    proximaElegibilidadeEm: isoDeInstante(recebidoEmMs + MS_DE_CICLO),
    consumidoEm: consumidoEmMs === null ? null : isoDeInstante(consumidoEmMs),
    encerradoEm: encerradoEmMs === null ? null : isoDeInstante(encerradoEmMs),
    tentativaEntradaId,
    admissaoId,
    // Por padrão, um ciclo consumido carrega o contexto do próprio `contexto()`
    // — que é o caso normal. Passar `null` explicitamente simula o documento
    // antigo/incompleto, que NÃO pode recuperar.
    contextoDoRecibo:
      contextoDoRecibo === undefined
        ? (consumidoEmMs === null ? null : contextoEstavelDe(contexto()))
        : contextoDoRecibo,
    versaoContrato: VERSAO_CONTRATO_PASSE,
  };
}

/// O contexto como o gate do servidor o entrega — os cinco campos estáveis mais
/// a identidade da tentativa. Ver `admissao-vip-v1` em `buraco-servidor@e4bad52`.
const contexto = (extra = {}) => Object.assign({
  uid: UID,
  tentativaEntradaId: "te_1111",
  codigoDaSala: "BURACO-4821",
  identidadeDaPartida: null,
  assento: 2,
  categoriaCompetitiva: "vip_ranqueada",
}, extra);

// ===========================================================================
describe("PASSE/TEMPO — as duas fronteiras", () => {
  test("PT-01: sete e quinze dias, e a relação entre eles", () => {
    assert.equal(DIAS_DE_VALIDADE, 7);
    assert.equal(DIAS_DE_CICLO, 15);
    assert.equal(MS_DE_VALIDADE, 7 * DIA);
    assert.equal(MS_DE_CICLO, 15 * DIA);
    // A validade cabe DENTRO do ciclo, e sobram oito dias sem passe. Se esta
    // desigualdade se inverter, o jogador teria dois passes vivos ao mesmo
    // tempo — que é a definição de acumular.
    assert.ok(MS_DE_VALIDADE < MS_DE_CICLO, "a validade tem de caber no ciclo");
  });

  test("PT-02: as datas saem do `recebidoEm`, e só dele", () => {
    const p = planejarCiclo(T0);
    assert.equal(p.recebidoEmMs, T0);
    assert.equal(p.validoAteMs, T0 + 7 * DIA);
    assert.equal(p.proximaElegibilidadeEmMs, T0 + 15 * DIA);
  });

  test("PT-03: disponível um instante ANTES de sete dias", () => {
    // §11.3. Um milissegundo antes ainda é passe.
    const c = controleCom({});
    assert.equal(passeDisponivel(c, T0 + 7 * DIA - 1), true);
  });

  test("PT-04: EXPIRADO exatamente em sete dias", () => {
    // §11.4 e §4: "em `agora == validoAte`, o passe já está expirado". Sete dias
    // é a DURAÇÃO, não o último instante — a fronteira é fechada do lado de fora.
    const c = controleCom({});
    assert.equal(passeDisponivel(c, T0 + 7 * DIA), false);
    assert.equal(passeDisponivel(c, T0 + 7 * DIA + 1), false);
  });

  test("PT-05: relógio ilegível ou ausente não vira passe eterno", () => {
    // `NaN` numa comparação é sempre falso, e "sempre falso" no lugar errado
    // significaria "nunca expira".
    assert.equal(instanteDeIso("nao-e-data"), null);
    assert.equal(instanteDeIso(""), null);
    assert.equal(instanteDeIso(null), null);
    assert.equal(instanteDeIso(42), null);
    const quebrado = Object.assign(controleCom({}), { validoAte: "ontem" });
    assert.equal(passeDisponivel(quebrado, T0), false, "data ilegível não concede");
  });

  test("PT-06: o instante efetivo nunca anda para trás", () => {
    // §11.14. A proteção contra regressão de relógio, na primitiva.
    assert.equal(instanteEfetivo(T0, null), T0);
    assert.equal(instanteEfetivo(T0 + DIA, T0), T0 + DIA, "para a frente, segue");
    assert.equal(instanteEfetivo(T0 - DIA, T0), T0, "para trás, não anda");
  });
});

// ===========================================================================
describe("PASSE/CICLO — criar, reaproveitar, aguardar", () => {
  test("PC-01: primeiro acesso cria um passe", () => {
    // §11.1
    const d = decidirMaterializacao({ estado: "inexistente" }, T0);
    assert.equal(d.acao, "criar_primeiro");
    assert.equal(d.plano.recebidoEmMs, T0);
    assert.equal(d.plano.validoAteMs, T0 + 7 * DIA);
    assert.equal(d.plano.proximaElegibilidadeEmMs, T0 + 15 * DIA);
  });

  test("PC-02: disponível imediatamente após a criação", () => {
    // §11.2
    const c = controleCom({ recebidoEmMs: T0 });
    assert.equal(passeDisponivel(c, T0), true);
    const d = decidirMaterializacao({ estado: "valido", controle: c }, T0);
    assert.equal(d.acao, "reaproveitar", "materializar de novo não cria outro");
  });

  test("PC-03: nenhum passe novo entre sete e quinze dias", () => {
    // §11.5. Expirado, e ainda dentro da quinzena: não há passe e não há nada a
    // criar. É a janela de oito dias, e ela é o produto.
    const c = controleCom({ recebidoEmMs: T0 });
    for (const dias of [7, 8, 10, 14]) {
      const d = decidirMaterializacao({ estado: "valido", controle: c }, T0 + dias * DIA);
      assert.equal(d.acao, "aguardar", "dia " + dias);
      assert.equal(d.proximaElegibilidadeEmMs, T0 + 15 * DIA);
    }
    // e um milissegundo antes dos quinze ainda aguarda
    const quase = decidirMaterializacao({ estado: "valido", controle: c }, T0 + 15 * DIA - 1);
    assert.equal(quase.acao, "aguardar");
  });

  test("PC-04: novo passe EXATAMENTE em quinze dias", () => {
    // §11.6 e §4: "em `agora == proximaElegibilidadeEm`, um novo ciclo pode ser
    // materializado". A fronteira oposta à da validade, e simétrica com ela.
    const c = controleCom({ recebidoEmMs: T0 });
    const d = decidirMaterializacao({ estado: "valido", controle: c }, T0 + 15 * DIA);
    assert.equal(d.acao, "criar_novo");
    assert.equal(d.plano.recebidoEmMs, T0 + 15 * DIA);
  });

  test("PC-05: ciclos perdidos NÃO acumulam", () => {
    // §11.7. Quem sumiu por dois meses recebe UM passe agora — não quatro
    // atrasados —, e a próxima elegibilidade conta a partir de AGORA.
    const c = controleCom({ recebidoEmMs: T0 });
    const doisMeses = T0 + 60 * DIA;
    const d = decidirMaterializacao({ estado: "valido", controle: c }, doisMeses);
    assert.equal(d.acao, "criar_novo");
    assert.equal(d.plano.recebidoEmMs, doisMeses, "ancorado AGORA, não na elegibilidade perdida");
    assert.equal(d.plano.proximaElegibilidadeEmMs, doisMeses + 15 * DIA);
    // e a decisão é UMA, não uma fila de quatro
    assert.equal(typeof d.plano, "object");
    assert.ok(!Array.isArray(d.plano), "não existe lista de ciclos devidos");
  });

  test("PC-06: consumir NÃO antecipa a próxima elegibilidade", () => {
    // §11.8 e §4. A âncora é `recebidoEm`, e consumir não a move.
    const consumidoNoDia1 = controleCom({ recebidoEmMs: T0, consumidoEmMs: T0 + DIA });
    // no dia seguinte ao consumo: sem passe, e sem ciclo novo
    const d = decidirMaterializacao({ estado: "valido", controle: consumidoNoDia1 }, T0 + 2 * DIA);
    assert.equal(d.acao, "aguardar");
    assert.equal(d.proximaElegibilidadeEmMs, T0 + 15 * DIA, "a quinzena conta do RECEBIMENTO");
    // e no dia 15 — não no dia 16 — o próximo nasce
    const d15 = decidirMaterializacao({ estado: "valido", controle: consumidoNoDia1 }, T0 + 15 * DIA);
    assert.equal(d15.acao, "criar_novo");
  });

  test("PC-07: expirar também não antecipa nada", () => {
    const c = controleCom({ recebidoEmMs: T0 });
    const d = decidirMaterializacao({ estado: "valido", controle: c }, T0 + 7 * DIA);
    assert.equal(d.acao, "aguardar");
    assert.equal(d.proximaElegibilidadeEmMs, T0 + 15 * DIA);
  });

  test("PC-08: passe consumido nunca mais fica disponível", () => {
    const c = controleCom({ recebidoEmMs: T0, consumidoEmMs: T0 + DIA });
    // mesmo dentro da validade
    assert.equal(passeDisponivel(c, T0 + 2 * DIA), false);
    assert.equal(passeDisponivel(c, T0 + 6 * DIA), false);
  });

  test("PC-09: repetir a materialização é idempotente", () => {
    // §11.11. Três chamadas no mesmo instante, e nas três a mesma resposta —
    // sem criar nada.
    const c = controleCom({ recebidoEmMs: T0 });
    const leitura = { estado: "valido", controle: c };
    for (let i = 0; i < 3; i++) {
      assert.deepEqual(decidirMaterializacao(leitura, T0 + DIA), { acao: "reaproveitar" });
    }
  });

  test("PC-10: regressão de relógio não reativa passe expirado", () => {
    // §11.14. O caso que a monotonia existe para matar: o passe expirou (o
    // servidor já materializou no dia 8), e o relógio volta para o dia 3.
    // Sem a proteção, o passe voltaria a estar dentro da validade.
    const c = controleCom({ recebidoEmMs: T0, ultimaMaterializacaoMs: T0 + 8 * DIA });
    const d = decidirMaterializacao({ estado: "valido", controle: c }, T0 + 3 * DIA);
    assert.equal(d.acao, "aguardar", "o relógio andou para trás e o passe NÃO ressuscitou");
    // e a projeção concorda
    assert.equal(projecaoDoProprietario({ estado: "valido", controle: c }, T0 + 3 * DIA).disponivel, false);
  });

  test("PC-10b: o ENCERRAMENTO é fato escrito, e sobrevive a qualquer relógio", () => {
    // A proteção que o teste puro anterior NÃO cobria, e que só apareceu contra
    // o banco: `ultimaMaterializacaoEm` só era gravado na CRIAÇÃO, então o
    // caminho que observa o passe vencido nunca o avançava. Aqui o encerramento
    // é um campo, e campo não se recalcula.
    const encerrado = controleCom({ recebidoEmMs: T0, cicloEncerradoEmMs: T0 + 8 * DIA });
    // Mesmo com o relógio DENTRO da validade original — e sem nenhuma
    // `ultimaMaterializacaoEm` para socorrer:
    assert.equal(passeDisponivel(encerrado, T0 + DIA), false, "encerrado é encerrado");
    assert.equal(passeDisponivel(encerrado, T0), false);
    const d = decidirMaterializacao({ estado: "valido", controle: encerrado }, T0 + DIA);
    assert.equal(d.acao, "aguardar");
    assert.equal(d.precisaEncerrar, false, "já encerrado: não escreve de novo");
  });

  test("PC-10c: o encerramento é pedido UMA vez, e só na primeira constatação", () => {
    // O custo do desenho: o único caminho de leitura que escreve, escreve no
    // máximo uma vez por ciclo. Se `precisaEncerrar` viesse true sempre, toda
    // consulta na janela seca sujaria o documento.
    const aberto = controleCom({ recebidoEmMs: T0 });
    const primeira = decidirMaterializacao({ estado: "valido", controle: aberto }, T0 + 8 * DIA);
    assert.equal(primeira.acao, "aguardar");
    assert.equal(primeira.precisaEncerrar, true, "a primeira constatação registra");

    const jaRegistrado = controleCom({ recebidoEmMs: T0, cicloEncerradoEmMs: T0 + 8 * DIA });
    for (const dias of [8, 9, 14]) {
      const d = decidirMaterializacao({ estado: "valido", controle: jaRegistrado }, T0 + dias * DIA);
      assert.equal(d.precisaEncerrar, false, "dia " + dias + ": não escreve de novo");
    }
  });

  test("PC-10d: ciclo NOVO nasce aberto, mesmo depois de um encerrado", () => {
    const encerrado = controleCom({ recebidoEmMs: T0, cicloEncerradoEmMs: T0 + 8 * DIA });
    const d = decidirMaterializacao({ estado: "valido", controle: encerrado }, T0 + 15 * DIA);
    assert.equal(d.acao, "criar_novo", "o encerramento do anterior não bloqueia o próximo");
    assert.equal(d.plano.recebidoEmMs, T0 + 15 * DIA);
  });

  test("PC-11: regressão de relógio não recria ciclo antes da quinzena", () => {
    const c = controleCom({ recebidoEmMs: T0, ultimaMaterializacaoMs: T0 + 10 * DIA });
    const d = decidirMaterializacao({ estado: "valido", controle: c }, T0 - 100 * DIA);
    assert.equal(d.acao, "aguardar", "voltar cem dias não antecipa a elegibilidade");
  });
});

// ===========================================================================
describe("PASSE/ESTADO — o que o documento pode dizer", () => {
  test("PE-01: documento ausente é jogador novo, não estado malformado", () => {
    assert.deepEqual(lerControle(null), { estado: "inexistente" });
    assert.deepEqual(lerControle(undefined), { estado: "inexistente" });
  });

  test("PE-02: versão de contrato desconhecida falha FECHADA", () => {
    // §11.13 e §5. Não se normaliza um direito escrito por outro código.
    for (const v of [0, 2, "1", null, undefined]) {
      const r = lerControle(Object.assign(controleCom({}), { versaoContrato: v }));
      assert.equal(r.estado, "malformado", "versao " + JSON.stringify(v));
      assert.equal(r.motivo, "contrato_desconhecido");
    }
  });

  test("PE-03: janela impossível falha FECHADA", () => {
    // O documento não pode sobrescrever a regra. Oito dias de validade ou
    // quatorze de ciclo NÃO são aceitos — são recusados.
    const oitoDias = Object.assign(controleCom({}), { validoAte: isoDeInstante(T0 + 8 * DIA) });
    assert.equal(lerControle(oitoDias).motivo, "janela_impossivel");

    const quatorzeDias = Object.assign(controleCom({}), { proximaElegibilidadeEm: isoDeInstante(T0 + 14 * DIA) });
    assert.equal(lerControle(quatorzeDias).motivo, "janela_impossivel");
  });

  test("PE-04: datas ilegíveis falham FECHADAS", () => {
    for (const campo of ["recebidoEm", "validoAte", "proximaElegibilidadeEm"]) {
      const r = lerControle(Object.assign(controleCom({}), { [campo]: "ontem de manhã" }));
      assert.equal(r.estado, "malformado", campo);
      assert.equal(r.motivo, "datas_ilegiveis");
    }
  });

  test("PE-05: ciclo meio preenchido é estado impossível", () => {
    const semId = Object.assign(controleCom({}), { cicloAtualId: null });
    assert.equal(lerControle(semId).motivo, "ciclo_incoerente");
  });

  test("PE-06: consumo fora do próprio ciclo é impossível", () => {
    // Ninguém usa um passe antes de recebê-lo, nem depois de ele vencer.
    const antes = controleCom({ recebidoEmMs: T0 });
    antes.consumidoEm = isoDeInstante(T0 - DIA);
    assert.equal(lerControle(antes).motivo, "ciclo_incoerente");

    const depois = controleCom({ recebidoEmMs: T0 });
    depois.consumidoEm = isoDeInstante(T0 + 8 * DIA);
    assert.equal(lerControle(depois).motivo, "ciclo_incoerente");
  });

  test("PE-07: malformado NÃO é normalizado — a decisão recusa", () => {
    // §12.14: o defeito que se quer impossível é o silêncio. O estado ruim não
    // vira "sem passe" nem "com passe": vira recusa explícita e auditável.
    const d = decidirMaterializacao({ estado: "malformado", motivo: "janela_impossivel" }, T0);
    assert.equal(d.acao, "falha_fechada");
    assert.equal(d.motivo, "janela_impossivel");
  });

  test("PE-08: controle virgem (sem ciclo e sem datas) é legítimo", () => {
    const r = lerControle({ versaoContrato: VERSAO_CONTRATO_PASSE, cicloAtualId: null, consumidoEm: null });
    assert.equal(r.estado, "valido");
    assert.equal(r.controle.cicloAtualId, null);
    assert.equal(decidirMaterializacao(r, T0).acao, "criar_primeiro");
  });
});

// ===========================================================================
describe("PASSE/PROJECAO — o que sai, e o que nunca sai", () => {
  const proibidos = ["uid", "userId", "token", "tentativaEntradaId", "admissaoId", "cicloId", "credencial", "ultimaMaterializacaoEm"];

  test("PP-01: a projeção pública existe só enquanto o passe existe", () => {
    // §7 e §11.10
    const c = controleCom({ recebidoEmMs: T0 });
    const leitura = { estado: "valido", controle: c };
    assert.notEqual(projecaoPublica(leitura, T0 + DIA), null, "com passe, aparece");
    assert.equal(projecaoPublica(leitura, T0 + 7 * DIA), null, "expirado, DESAPARECE");
  });

  test("PP-02: passe consumido desaparece da projeção", () => {
    // §11.9. Não vira `false`, não vira "expirado": some.
    const c = controleCom({ recebidoEmMs: T0, consumidoEmMs: T0 + DIA });
    assert.equal(projecaoPublica({ estado: "valido", controle: c }, T0 + 2 * DIA), null);
  });

  test("PP-03: nenhuma projeção carrega uid, recibo ou campo interno", () => {
    // §11.18 e §11.19, nos dois lados e nos quatro estados.
    const casos = [
      ["com passe", controleCom({ recebidoEmMs: T0 }), T0 + DIA],
      ["expirado", controleCom({ recebidoEmMs: T0 }), T0 + 8 * DIA],
      ["consumido", controleCom({ recebidoEmMs: T0, consumidoEmMs: T0 + DIA }), T0 + 2 * DIA],
    ];
    for (const [nome, controle, agora] of casos) {
      const leitura = { estado: "valido", controle };
      for (const proj of [projecaoDoProprietario(leitura, agora), projecaoPublica(leitura, agora)]) {
        if (proj === null) continue;
        const texto = JSON.stringify(proj);
        for (const p of proibidos) {
          assert.ok(!Object.prototype.hasOwnProperty.call(proj, p), nome + ": campo " + p);
          assert.ok(!texto.includes(UID), nome + ": o uid vazou");
        }
      }
    }
  });

  test("PP-04: a projeção do dono informa disponibilidade, validade e elegibilidade", () => {
    const comPasse = projecaoDoProprietario({ estado: "valido", controle: controleCom({ recebidoEmMs: T0 }) }, T0 + DIA);
    assert.equal(comPasse.disponivel, true);
    assert.equal(comPasse.validoAte, isoDeInstante(T0 + 7 * DIA));
    assert.equal(comPasse.proximaElegibilidadeEm, null, "com passe na mão, a próxima data não interessa");

    const semPasse = projecaoDoProprietario({ estado: "valido", controle: controleCom({ recebidoEmMs: T0 }) }, T0 + 8 * DIA);
    assert.equal(semPasse.disponivel, false);
    assert.equal(semPasse.validoAte, null, "sem passe, não há validade a informar");
    assert.equal(semPasse.proximaElegibilidadeEm, isoDeInstante(T0 + 15 * DIA));
  });

  test("PP-05: estado malformado projeta ausência, e não erro vazado", () => {
    const leitura = { estado: "malformado", motivo: "janela_impossivel" };
    const p = projecaoDoProprietario(leitura, T0);
    assert.equal(p.disponivel, false);
    assert.ok(!JSON.stringify(p).includes("janela_impossivel"), "o motivo interno não sai");
    assert.equal(projecaoPublica(leitura, T0), null);
  });
});

// ===========================================================================
describe("PASSE/RECIBO — a idempotência que a admissão vai consumir", () => {
  test("PR-01: primeira tentativa consome", () => {
    const plano = planejarRecibo(cicloCom({}), contexto(), UID, T0 + DIA);
    assert.equal(plano.acao, "consumir");
    assert.equal(plano.cicloId, "ciclo-1");
  });

  test("PR-02: a MESMA tentativa recupera o mesmo recibo — não consome duas vezes", () => {
    // §11.22 e §8. É o caso da queda de conexão: o servidor aprovou, a rede
    // caiu, o jogador volta com a MESMA tentativa. Consumir de novo custaria
    // quinze dias por causa de um cabo.
    const consumido = cicloCom({
      consumidoEmMs: T0 + DIA,
      tentativaEntradaId: "te_1111",
      admissaoId: "adm-999",
    });
    const plano = planejarRecibo(consumido, contexto({ tentativaEntradaId: "te_1111" }), UID, T0 + 2 * DIA);
    assert.equal(plano.acao, "recuperar");
    assert.equal(plano.admissaoId, "adm-999", "o MESMO admissaoId, não um novo");
  });

  test("PR-02b: a MESMA tentativa em CONTEXTO DIFERENTE é recusada", () => {
    // A LACUNA QUE ESTA CORREÇÃO FECHA. `tentativaEntradaId` sozinha era uma
    // chave SOLTA: quem reapresentasse aquela string de outra sala, de outra
    // partida ou para outro assento receberia de volta o mesmo `admissaoId` e
    // entraria numa mesa que ninguém autorizou. Idempotência é "mesma tentativa
    // NO MESMO contexto"; "mesma string" é portão aberto.
    const consumido = cicloCom({
      consumidoEmMs: T0 + DIA,
      tentativaEntradaId: "te_1111",
      admissaoId: "adm-999",
    });
    const divergentes = [
      ["sala", { codigoDaSala: "BURACO-9999" }],
      ["partida", { identidadeDaPartida: "partida-outra" }],
      ["assento", { assento: 0 }],
      ["categoria", { categoriaCompetitiva: "casual" }],
    ];
    for (const [oQue, mudanca] of divergentes) {
      const plano = planejarRecibo(consumido, contexto(mudanca), UID, T0 + 2 * DIA);
      assert.equal(plano.acao, "recusar", oQue + " divergente");
      assert.equal(plano.motivo, "contexto_divergente", oQue);
      assert.ok(!JSON.stringify(plano).includes("adm-999"),
        oQue + ": a recusa não pode devolver o recibo alheio");
    }
  });

  test("PR-02c: JOGADOR divergente é recusado antes de qualquer contexto", () => {
    // O dono do passe é conferido primeiro, e com motivo próprio: a resposta
    // "contexto divergente" para outra pessoa contaria que existe um recibo ali.
    const consumido = cicloCom({
      consumidoEmMs: T0 + DIA,
      tentativaEntradaId: "te_1111",
      admissaoId: "adm-999",
    });
    const plano = planejarRecibo(consumido, contexto({ uid: "uid-invasor" }), UID, T0 + 2 * DIA);
    assert.equal(plano.acao, "recusar");
    assert.equal(plano.motivo, "tentativa_de_outro_jogador");
  });

  test("PR-02d: mudança só de RECONEXÃO ou de transporte continua recuperando", () => {
    // O caso que a conferência NÃO pode quebrar, e que é a razão de existir do
    // recibo: a conexão caiu e o jogador voltou. A segunda chegada quase sempre
    // vem classificada como reconexão e por outro caminho de transporte — e
    // nada disso é contexto estável.
    const consumido = cicloCom({
      consumidoEmMs: T0 + DIA,
      tentativaEntradaId: "te_1111",
      admissaoId: "adm-999",
    });
    const reapresentacoes = [
      ["classificada como reconexão", { reconexao: true, classificacao: "reconexao_ao_proprio_assento" }],
      ["por outra conexão", { conexaoId: "c-42", socketId: "s-99" }],
      ["com apelido novo", { apelido: "Sônia (2)" }],
      ["com carimbo de tempo novo", { enviadoEm: "2026-09-01T00:00:00.000Z" }],
    ];
    for (const [oQue, ruido] of reapresentacoes) {
      const plano = planejarRecibo(consumido, contexto(ruido), UID, T0 + 3 * DIA);
      assert.equal(plano.acao, "recuperar", oQue);
      assert.equal(plano.admissaoId, "adm-999", oQue + ": o MESMO recibo");
    }
  });

  test("PR-02e: recibo SEM contexto guardado não recupera", () => {
    // Documento antigo, escrita incompleta, migração pela metade: quem não pode
    // ser conferido não é recuperado. O contrário — recuperar na dúvida — é o
    // mesmo buraco por outro caminho.
    const semContexto = cicloCom({
      consumidoEmMs: T0 + DIA,
      tentativaEntradaId: "te_1111",
      admissaoId: "adm-999",
      contextoDoRecibo: null,
    });
    const plano = planejarRecibo(semContexto, contexto(), UID, T0 + 2 * DIA);
    assert.equal(plano.acao, "recusar");
    assert.equal(plano.motivo, "contexto_divergente");
  });

  test("PR-02f: a comparação de contexto é estrita, campo a campo", () => {
    // Na primitiva, para que a regra não dependa de como o caso acima monta o
    // fixture. `null` e ausência coincidem entre si; valor diferente, nunca.
    const base = contextoEstavelDe(contexto());
    assert.equal(contextosCoincidem(base, base), true);
    assert.equal(contextosCoincidem(null, base), false, "ausente não coincide com nada");
    assert.equal(contextosCoincidem(undefined, base), false);
    for (const campo of ["uid", "codigoDaSala", "identidadeDaPartida", "assento", "categoriaCompetitiva"]) {
      const mexido = Object.assign({}, base, { [campo]: campo === "assento" ? 3 : "outro-valor" });
      assert.equal(contextosCoincidem(mexido, base), false, campo + " diferente tem de divergir");
    }
    // `null` guardado x `null` atual coincidem — é o caso da sala em lobby.
    const semPartida = Object.assign({}, base, { identidadeDaPartida: null });
    assert.equal(contextosCoincidem(semPartida, semPartida), true);
  });

  test("PR-02g: o contexto estável carrega os CINCO campos, e só eles", () => {
    // Se um campo instável entrar aqui, a recuperação passa a falhar no caso
    // legítimo; se um estável sair, a chave volta a ficar solta. A lista é
    // fixada de propósito.
    const estavel = contextoEstavelDe(contexto({
      reconexao: true, classificacao: "reconexao_ao_proprio_assento",
      apelido: "Sônia", tentativaEntradaId: "te_1111", conexaoId: "c-1",
    }));
    assert.deepEqual(Object.keys(estavel).sort(), [
      "assento", "categoriaCompetitiva", "codigoDaSala", "identidadeDaPartida", "uid",
    ]);
    assert.ok(!("tentativaEntradaId" in estavel), "a tentativa é a chave, não o contexto");
    assert.ok(!("reconexao" in estavel), "reconexão é o que muda entre reapresentações");
  });

  test("PR-03: tentativas diferentes NÃO compartilham recibo", () => {
    // §11.23. Duas partidas, dois passes — e como só há um por quinzena, a
    // segunda é recusada.
    const consumido = cicloCom({
      consumidoEmMs: T0 + DIA,
      tentativaEntradaId: "te_1111",
      admissaoId: "adm-999",
    });
    const plano = planejarRecibo(consumido, contexto({ tentativaEntradaId: "te_2222" }), UID, T0 + 2 * DIA);
    assert.equal(plano.acao, "recusar");
    assert.equal(plano.motivo, "ja_consumido_por_outra_tentativa");
    assert.ok(!JSON.stringify(plano).includes("adm-999"), "e a recusa não vaza o recibo alheio");
  });

  test("PR-04: tentativa de OUTRO jogador é recusada", () => {
    // §11.24. O recibo é do dono do passe. Nem que todo o resto do contexto feche.
    const plano = planejarRecibo(cicloCom({}), contexto({ uid: "uid-outro" }), UID, T0 + DIA);
    assert.equal(plano.acao, "recusar");
    assert.equal(plano.motivo, "tentativa_de_outro_jogador");
  });

  test("PR-05: tentativa sem identidade é recusada antes de qualquer coisa", () => {
    for (const t of [undefined, null, "", 0, {}]) {
      const plano = planejarRecibo(cicloCom({}), contexto({ tentativaEntradaId: t }), UID, T0 + DIA);
      assert.equal(plano.acao, "recusar", JSON.stringify(t));
      assert.equal(plano.motivo, "tentativa_invalida");
    }
  });

  test("PR-06: sem passe, e com passe expirado, não há o que consumir", () => {
    assert.equal(planejarRecibo(null, contexto(), UID, T0).motivo, "sem_passe_disponivel");
    const expirado = cicloCom({ recebidoEmMs: T0 });
    assert.equal(planejarRecibo(expirado, contexto(), UID, T0 + 7 * DIA).motivo, "sem_passe_disponivel");
  });

  test("PR-06b: ciclo ENCERRADO não é consumível, nem com o relógio dentro da validade", () => {
    // A mesma proteção do controle, do lado do recibo: encerrado por escrito
    // não se reabre por conta.
    const encerrado = cicloCom({ recebidoEmMs: T0, encerradoEmMs: T0 + 8 * DIA });
    const plano = planejarRecibo(encerrado, contexto(), UID, T0 + DIA);
    assert.equal(plano.acao, "recusar");
    assert.equal(plano.motivo, "sem_passe_disponivel");
  });

  test("PR-07: consumido sem recibo gravado é recusado — não se inventa admissaoId", () => {
    // Estado impossível. Fabricar um recibo aqui seria produzir a prova de uma
    // admissão que ninguém pode conferir.
    const semRecibo = cicloCom({ consumidoEmMs: T0 + DIA, tentativaEntradaId: "te_1111", admissaoId: null });
    const plano = planejarRecibo(semRecibo, contexto({ tentativaEntradaId: "te_1111" }), UID, T0 + 2 * DIA);
    assert.equal(plano.acao, "recusar");
  });

  test("PR-08: o consumo não move a âncora quinzenal", () => {
    // §11.8 na transição pura: `proximaElegibilidadeEm` sai igual.
    const antes = cicloCom({ recebidoEmMs: T0 });
    const depois = aplicarConsumo(antes, contexto(), "adm-777", T0 + DIA);
    assert.equal(depois.proximaElegibilidadeEm, antes.proximaElegibilidadeEm);
    assert.equal(depois.recebidoEm, antes.recebidoEm);
    assert.equal(depois.validoAte, antes.validoAte);
    assert.equal(depois.consumidoEm, isoDeInstante(T0 + DIA));
    assert.equal(depois.tentativaEntradaId, "te_1111");
    assert.equal(depois.admissaoId, "adm-777");
    // E o contexto estável é gravado JUNTO com o recibo, na mesma transição —
    // não existe instante em que haja `admissaoId` sem contexto para conferi-lo.
    assert.deepEqual(depois.contextoDoRecibo, contextoEstavelDe(contexto()));
  });

  test("PR-09: consumir e reapresentar converge — a transição é idempotente", () => {
    // A cadeia inteira, como a OS de admissão vai percorrê-la.
    const ciclo = cicloCom({ recebidoEmMs: T0 });
    const ctx = contexto({ tentativaEntradaId: "te_abc" });

    const primeiro = planejarRecibo(ciclo, ctx, UID, T0 + DIA);
    assert.equal(primeiro.acao, "consumir");
    const consumido = aplicarConsumo(ciclo, ctx, "adm-abc", T0 + DIA);

    const segundo = planejarRecibo(consumido, ctx, UID, T0 + DIA);
    assert.equal(segundo.acao, "recuperar");
    assert.equal(segundo.admissaoId, "adm-abc");

    // e a terceira também
    const terceiro = planejarRecibo(consumido, ctx, UID, T0 + 3 * DIA);
    assert.deepEqual(terceiro, segundo);
  });
});

// ===========================================================================
describe("PASSE/FRONTEIRA — o que esta OS promete NÃO ter feito", () => {
  const raiz = path.resolve(__dirname, "..", "..");
  const leia = (p) => fs.readFileSync(path.join(raiz, p), "utf8");

  /// Código sem comentários. O bundle e os módulos deste repositório documentam
  /// as decisões em prosa longa, e uma varredura por ausência que não separe as
  /// duas coisas reprova justamente o texto que explica a decisão certa.
  function codigoDe(fonte) {
    const limpo = fonte.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^[ \t]*\/\/.*$/gm, "").replace(/^[ \t]*\/\/\/.*$/gm, "");
    assert.ok(limpo.includes("export"), "a limpeza comeu o código");
    return limpo;
  }

  test("PF-01: NENHUMA Cloud Function produtiva nova é exportada", () => {
    // §11.20 e §12.12. Neste repositório `index.ts` reexporta tudo: um `export`
    // a mais vira Cloud Function implantada. A contagem é fixa POR CODEBASE, e
    // mexer nela passa a exigir mexer neste teste — de propósito.
    // [COMPOSICAO canonica] DUAS CONTAGENS SUBIRAM, e as duas sao DECISAO — nao
    // acomodacao de merge. A intencao de PF-01 nao mudou: a OS do Passe continua
    // sem exportar Function nenhuma. O que mudou foi o mundo em volta dela.
    //
    //   moderacao 6 -> 9   O Chat Livre Seguro trouxe `definirCanalDeChat`,
    //                      `enviarMensagemChat` e `enviarMensagemChatPeloMotor`.
    //                      Sao a superficie do chat, e sem elas o codebase de
    //                      moderacao entra na composicao sem o produto que a
    //                      linhagem existe para entregar.
    //
    //   social 14 -> 15    `reconciliarPerfilSocial`, que ja vinha na linhagem
    //                      irma (`auditoria/passe-vip-quinzenal-cortesia-v1`) e
    //                      na de Mesas. O retrato de 14 e anterior as duas.
    //
    // As outras duas contagens NAO se mexeram, e e isso que mantem o teste util:
    // se `functions/` ou `functions-ranking` crescerem, ele continua reprovando.
    const esperado = {
      "functions/src/index.ts": 7,
      "functions-moderacao/src/index.ts": 9,
      "functions-ranking/src/index.ts": 11,
      "functions-social/src/index.ts": 15,
    };
    for (const [arquivo, quantos] of Object.entries(esperado)) {
      const achados = (leia(arquivo).match(/^export const /gm) || []).length;
      assert.equal(achados, quantos, arquivo + " mudou de superfície de deploy");
    }
    // E o módulo do passe não é alcançável a partir do index do ranking.
    assert.ok(!/from "\.\/passe"|require\("\.\/passe"\)/.test(leia("functions-ranking/src/index.ts")),
      "o index não importa o passe: ele não tem endpoint");
  });

  test("PF-02: NENHUM scheduler novo foi criado", () => {
    // §11.21 e §10. O único do projeto é `tickTorneios`, e ele é anterior.
    const codebases = [
      "functions/src/index.ts",
      "functions-moderacao/src/index.ts",
      "functions-ranking/src/index.ts",
      "functions-social/src/index.ts",
    ];
    let total = 0;
    for (const arquivo of codebases) {
      total += (codigoDe(leia(arquivo)).match(/onSchedule\s*\(/g) || []).length;
    }
    assert.equal(total, 1, "há exatamente UM scheduler no projeto, e ele é o de torneios");
    assert.ok(/onSchedule\s*\(/.test(leia("functions/src/index.ts")), "e ele está em torneios");
    assert.ok(!/onSchedule|pubsub|scheduler/.test(codigoDe(leia("functions-ranking/src/passe.ts"))),
      "o passe não agenda nada: ele materializa sob demanda");
  });

  test("PF-03: `playerEntitlements` fica INTOCADO", () => {
    // §11.15, §10 e §12.7. A cortesia não escreve, não lê e nem menciona a
    // autoridade da assinatura paga.
    const modulo = codigoDe(leia("functions-ranking/src/passe.ts"));
    const execucao = codigoDe(leia("functions-ranking/src/firestore.ts"));
    for (const fonte of [modulo, execucao]) {
      assert.ok(!/playerEntitlements/.test(fonte), "a cortesia não toca a assinatura");
      assert.ok(!/usuarios\/|compras|configuracao\/billing/.test(fonte), "nem o billing legado");
    }
    // e a coleção da cortesia é OUTRA, com nome próprio
    assert.ok(/playerCourtesyPass/.test(execucao));
  });

  test("PF-04: nenhum segredo entrou", () => {
    const fontes = [leia("functions-ranking/src/passe.ts"), leia("functions-ranking/src/firestore.ts")];
    for (const f of fontes) {
      for (const p of [/AIza[0-9A-Za-z_-]{10,}/, /eyJ[A-Za-z0-9_-]{20,}\./, /BEGIN [A-Z ]*PRIVATE KEY/, /client_secret/]) {
        assert.equal(p.test(f), false, "a fonte casa com " + p);
      }
    }
  });

  test("PF-05: o relógio do cliente não participa da conta", () => {
    // §4 e §10. Nenhuma data chega de fora: o módulo puro recebe milissegundos
    // de quem executa, e quem executa usa `Date.now()` do servidor.
    const execucao = codigoDe(leia("functions-ranking/src/firestore.ts"));
    const trecho = execucao.slice(execucao.indexOf("materializarPasseDeCortesia"));
    assert.ok(/agoraMs: number = Date\.now\(\)/.test(trecho), "o padrão é o relógio do servidor");
    assert.ok(!/req\.data|request\.data|body\./.test(trecho), "nada vem de requisição");
  });
});
