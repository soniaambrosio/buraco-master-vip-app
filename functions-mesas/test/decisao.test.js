/**
 * decisao.test.js — QUEM SENTA, E POR QUE.
 *
 * A suite central da OS. Cobre os casos obrigatorios:
 *
 *   Publica ....... 1 (autenticado entra sem VIP), 3 (nunca gera Ranking)
 *   VIP ........... 10 (assinatura ativa permite), 11/12 (expirada e revogada
 *                   recusam), 13 (booleano do cliente e ignorado), 20 (nao da
 *                   para virar VIP depois de autorizado)
 *   Cortesia ...... 21 (passe valido permite UMA entrada), 25 (a admissao
 *                   confirmada consome), 29 (ja usado recusa), 30/31 (nao
 *                   libera Salao nem criacao de Privada), 34 (sem vantagem)
 *   Privada ....... 37 (convidado VIP entra), 38 (nao VIP com codigo valido
 *                   NAO ocupa cadeira), 39 (cada cadeira valida
 *                   separadamente), 40 (VIP expirado entre configuracao e
 *                   admissao recusa), 41 (codigo nunca substitui
 *                   entitlement), 42 (uma assinatura nao autoriza convidados),
 *                   43 (cortesia nao autoriza Privada), 50 (codigo de uma sala
 *                   nao autoriza outra)
 *   Treino ........ 52 (nao consome cortesia), 53 (resultado local nao e
 *                   aceito como online)
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const { TIPO_MESA } = require("../lib/tipos");
const { FONTE, RECUSA, decidirAdmissao } = require("../lib/decisao");
const { CONCESSAO, decidirConcessao } = require("../lib/passe");

const T0 = "2026-08-01T12:00:00.000Z";
const DIA = 24 * 60 * 60 * 1000;
const em = (ms) => new Date(Date.parse(T0) + ms).toISOString();

const passeValido = decidirConcessao({ atual: null, agora: T0, assinaturaAtiva: false }).proposta;
const passeUsado = { ...passeValido, usadoEm: em(DIA), usadoNaAdmissao: "adm_anterior" };

function salaPrivada(extra = {}) {
  return {
    salaId: "sala_1",
    codigoDaSala: "BURACO-1",
    proprietarioUid: "uid_dono",
    criadaEm: T0,
    encerradaEm: null,
    cadeiras: ["liberada", "liberada", "liberada", "liberada"],
    ...extra,
  };
}

function fatos(extra = {}) {
  return {
    tipo: TIPO_MESA.PUBLICA,
    uidAutenticado: "uid_1",
    codigoDaSala: "BURACO-1",
    assento: 0,
    agora: em(DIA),
    assinaturaAtiva: false,
    passe: null,
    sala: null,
    admissaoAnterior: null,
    ...extra,
  };
}

// ===========================================================================

describe("DEC-PUB — Mesa Publica", () => {
  test("DEC-PUB-01 jogador autenticado entra sem VIP e sem passe", () => {
    const v = decidirAdmissao(fatos());
    assert.equal(v.ok, true);
    assert.equal(v.fonteElegibilidade, FONTE.NAO_EXIGIDA);
    assert.equal(v.consumirPasse, false);
  });

  test("DEC-PUB-02 a Publica NAO consome cortesia, mesmo havendo passe utilizavel", () => {
    // Consumir aqui queimaria o beneficio numa mesa que e gratuita por
    // definicao. E o defeito mais facil de introduzir e o mais dificil de
    // notar, porque o jogador entra na mesa do mesmo jeito.
    const v = decidirAdmissao(fatos({ passe: passeValido }));
    assert.equal(v.ok, true);
    assert.equal(v.consumirPasse, false);
    assert.equal(v.fonteElegibilidade, FONTE.NAO_EXIGIDA);
  });

  test("DEC-PUB-03 assento fora da mesa recusa", () => {
    for (const assento of [-1, 4, 1.5, "0", null, NaN]) {
      const v = decidirAdmissao(fatos({ assento }));
      assert.equal(v.ok, false, `aceitou assento ${JSON.stringify(assento)}`);
      assert.equal(v.codigoRecusa, RECUSA.ASSENTO_INVALIDO);
    }
  });
});

describe("DEC-VIP — Mesa VIP/Ranqueada", () => {
  const vip = (extra) => fatos({ tipo: TIPO_MESA.VIP_RANQUEADA, ...extra });

  test("DEC-VIP-01 assinatura ativa permite a entrada", () => {
    const v = decidirAdmissao(vip({ assinaturaAtiva: true }));
    assert.equal(v.ok, true);
    assert.equal(v.fonteElegibilidade, FONTE.ASSINATURA);
    assert.equal(v.consumirPasse, false);
  });

  test("DEC-VIP-02 assinatura expirada ou revogada recusa", () => {
    // Expirada e revogada chegam aqui do mesmo jeito: `assinaturaAtiva:
    // false`. Quem distingue os dois estados e a autoridade do Billing, e
    // ELA e a unica que distingue — este modulo nao tem opiniao sobre
    // assinatura, so consome a resposta.
    const v = decidirAdmissao(vip({ assinaturaAtiva: false }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.SEM_ASSINATURA_NEM_CORTESIA);
  });

  test("DEC-VIP-03 booleano VIP enviado pelo cliente e IGNORADO", () => {
    // O caso 13. Um payload adulterado nao tem por onde entrar: os fatos vem
    // de leitura de banco, e o campo do cliente nao e lido por ninguem.
    const v = decidirAdmissao(vip({ isVip: true, ehVip: true, vip: true, assinaturaAtiva: false }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.SEM_ASSINATURA_NEM_CORTESIA);
  });

  test("DEC-VIP-04 tipo desconhecido recusa — nao vira casual", () => {
    // O caso 20, pelo lado da decisao: se a traducao falhar, a admissao NAO
    // rebaixa para Publica. Rebaixar transformaria erro de configuracao em
    // mesa aberta e gratuita.
    const v = decidirAdmissao(fatos({ tipo: null }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.TIPO_DESCONHECIDO);
  });

  test("DEC-VIP-05 assinante NAO tem regra diferente — so fonte diferente", () => {
    // "VIP compra acesso, nao vantagem." O veredito de um assinante e o de um
    // portador de cortesia diferem no campo `fonteElegibilidade` e em mais
    // nada: os dois sentam do mesmo jeito, na mesma mesa.
    const comAssinatura = decidirAdmissao(vip({ assinaturaAtiva: true }));
    const comCortesia = decidirAdmissao(vip({ passe: passeValido }));
    assert.equal(comAssinatura.ok, comCortesia.ok);
    assert.notEqual(comAssinatura.fonteElegibilidade, comCortesia.fonteElegibilidade);
  });
});

describe("DEC-COR — o passe de cortesia", () => {
  const vip = (extra) => fatos({ tipo: TIPO_MESA.VIP_RANQUEADA, ...extra });

  test("DEC-COR-01 passe valido permite a entrada e MANDA consumir", () => {
    const v = decidirAdmissao(vip({ passe: passeValido }));
    assert.equal(v.ok, true);
    assert.equal(v.fonteElegibilidade, FONTE.CORTESIA);
    assert.equal(v.consumirPasse, true);
  });

  test("DEC-COR-02 passe ja usado recusa", () => {
    const v = decidirAdmissao(vip({ passe: passeUsado }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.SEM_ASSINATURA_NEM_CORTESIA);
  });

  test("DEC-COR-03 passe expirado recusa", () => {
    const v = decidirAdmissao(vip({ passe: passeValido, agora: em(8 * DIA) }));
    assert.equal(v.ok, false);
  });

  test("DEC-COR-04 assinante com passe na mao NAO gasta o passe", () => {
    const v = decidirAdmissao(vip({ assinaturaAtiva: true, passe: passeValido }));
    assert.equal(v.ok, true);
    assert.equal(v.consumirPasse, false);
    assert.equal(v.fonteElegibilidade, FONTE.ASSINATURA);
  });

  test("DEC-COR-05 a cortesia NAO abre Mesa Privada", () => {
    // Os casos 31 e 43. E o motivo tem nome proprio: o operador precisa
    // distinguir "a regra funcionou" de "faltou beneficio".
    const v = decidirAdmissao(
      fatos({ tipo: TIPO_MESA.PRIVADA, passe: passeValido, sala: salaPrivada() }),
    );
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.CORTESIA_NAO_SERVE_PRIVADA);
  });

  test("DEC-COR-06 a cortesia NAO cria entitlement — ela nao aparece no veredito como assinatura", () => {
    // O caso 32/30: o passe nao vira VIP. A fonte registrada e `cortesia`, e
    // nenhum consumidor de `playerEntitlements` e tocado por esta decisao.
    const v = decidirAdmissao(vip({ passe: passeValido }));
    assert.notEqual(v.fonteElegibilidade, FONTE.ASSINATURA);
  });

  test("DEC-COR-07 o Treino nunca consome cortesia", () => {
    // O caso 52. O Treino nem chega a ser admitido, entao nao ha caminho em
    // que ele gaste passe.
    const v = decidirAdmissao(fatos({ tipo: TIPO_MESA.TREINO, passe: passeValido }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.TREINO_NAO_ADMITE);
  });

  test("DEC-COR-08 uma entrada, e so uma: a segunda tentativa com o mesmo passe recusa", () => {
    // O caso 21 na forma mais direta. A primeira decisao manda consumir; o
    // documento consumido produz recusa na segunda.
    const primeira = decidirAdmissao(vip({ passe: passeValido }));
    assert.equal(primeira.consumirPasse, true);
    const segunda = decidirAdmissao(vip({ passe: passeUsado }));
    assert.equal(segunda.ok, false);
  });
});

describe("DEC-PRI — Mesa Privada", () => {
  const priv = (extra) => fatos({ tipo: TIPO_MESA.PRIVADA, sala: salaPrivada(), ...extra });

  test("DEC-PRI-01 convidado com assinatura ATIVA entra", () => {
    const v = decidirAdmissao(priv({ uidAutenticado: "uid_convidado", assinaturaAtiva: true, assento: 2 }));
    assert.equal(v.ok, true);
    assert.equal(v.fonteElegibilidade, FONTE.ASSINATURA);
  });

  test("DEC-PRI-02 NAO VIP com codigo valido NAO ocupa cadeira", () => {
    // O caso 38, e o coracao da emenda: o codigo LOCALIZA a sala, nunca
    // concede direito. A sala esta correta, o codigo corresponde, a cadeira
    // esta liberada — e ainda assim ele nao senta.
    const v = decidirAdmissao(priv({ uidAutenticado: "uid_convidado", assinaturaAtiva: false }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.SEM_ASSINATURA_NEM_CORTESIA);
  });

  test("DEC-PRI-03 cada cadeira valida SEPARADAMENTE a elegibilidade do ocupante", () => {
    // O caso 39/42: uma assinatura nao libera familiares nem convidados. O
    // dono ser VIP nao aparece na decisao dos outros tres — o unico fato
    // consultado e a assinatura de QUEM esta sentando.
    const dono = decidirAdmissao(priv({ uidAutenticado: "uid_dono", assinaturaAtiva: true, assento: 0 }));
    assert.equal(dono.ok, true);
    for (const assento of [1, 2, 3]) {
      const carona = decidirAdmissao(
        priv({ uidAutenticado: `uid_carona_${assento}`, assinaturaAtiva: false, assento }),
      );
      assert.equal(carona.ok, false, `carona sentou no assento ${assento}`);
    }
  });

  test("DEC-PRI-04 VIP que expirou entre a configuracao e a admissao e recusado", () => {
    // O caso 40. A elegibilidade e conferida NO INSTANTE DA ADMISSAO, e nao no
    // momento em que a tela foi aberta.
    const v = decidirAdmissao(priv({ assinaturaAtiva: false, agora: em(30 * DIA) }));
    assert.equal(v.ok, false);
  });

  test("DEC-PRI-05 codigo que aponta para outra sala e recusa DURA", () => {
    // O caso 50, e a proibicao de trocar o identificador da sala depois de
    // validar outro codigo. Nem assinante passa.
    const v = decidirAdmissao(
      priv({ assinaturaAtiva: true, codigoDaSala: "BURACO-OUTRA" }),
    );
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.CODIGO_NAO_CORRESPONDE);
  });

  test("DEC-PRI-06 sala inexistente ou encerrada recusa", () => {
    const semSala = decidirAdmissao(priv({ assinaturaAtiva: true, sala: null }));
    assert.equal(semSala.codigoRecusa, RECUSA.SALA_INEXISTENTE);

    const encerrada = decidirAdmissao(
      priv({ assinaturaAtiva: true, sala: salaPrivada({ encerradaEm: em(DIA) }) }),
    );
    assert.equal(encerrada.codigoRecusa, RECUSA.SALA_ENCERRADA);
  });

  test("DEC-PRI-07 cadeira travada ou reservada nao aceita ocupante, nem VIP", () => {
    const sala = salaPrivada({ cadeiras: ["liberada", "travada", "reservada", "liberada"] });
    for (const assento of [1, 2]) {
      const v = decidirAdmissao(priv({ assinaturaAtiva: true, sala, assento }));
      assert.equal(v.ok, false, `sentou na cadeira ${assento}`);
      assert.equal(v.codigoRecusa, RECUSA.ASSENTO_INDISPONIVEL);
    }
    assert.equal(decidirAdmissao(priv({ assinaturaAtiva: true, sala, assento: 3 })).ok, true);
  });

  test("DEC-PRI-08 a sala e conferida ANTES da elegibilidade", () => {
    // Ordem das checagens. Um codigo que aponta para outra sala tem que
    // recusar por CODIGO, e nao por falta de assinatura: inverter a ordem
    // faria um nao-assinante e um invasor produzirem o mesmo registro, e os
    // dois casos pedem investigacoes diferentes.
    const v = decidirAdmissao(
      priv({ assinaturaAtiva: false, codigoDaSala: "BURACO-OUTRA" }),
    );
    assert.equal(v.codigoRecusa, RECUSA.CODIGO_NAO_CORRESPONDE);
  });
});

describe("DEC-REC — reconexao ao proprio assento", () => {
  const vip = (extra) => fatos({ tipo: TIPO_MESA.VIP_RANQUEADA, ...extra });
  const anterior = { admissaoId: "adm_ok", assento: 2, fonteElegibilidade: FONTE.CORTESIA };

  test("DEC-REC-01 quem ja esta sentado volta sem pagar de novo", () => {
    const v = decidirAdmissao(
      vip({ assento: 2, admissaoAnterior: anterior, passe: passeUsado, assinaturaAtiva: false }),
    );
    assert.equal(v.ok, true);
    assert.equal(v.fonteElegibilidade, FONTE.RECONEXAO);
    assert.equal(v.consumirPasse, false);
    assert.equal(v.admissaoReaproveitada, "adm_ok");
  });

  test("DEC-REC-02 a reconexao NAO reavalia assinatura", () => {
    // Reavaliar aqui expulsaria da partida em andamento quem tivesse a
    // assinatura vencida no meio dela. O direito ja foi exercido na admissao.
    const v = decidirAdmissao(
      vip({ assento: 2, admissaoAnterior: anterior, assinaturaAtiva: false, agora: em(90 * DIA) }),
    );
    assert.equal(v.ok, true);
  });

  test("DEC-REC-03 reconexao para OUTRA cadeira nao e reconexao", () => {
    const v = decidirAdmissao(vip({ assento: 3, admissaoAnterior: anterior }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.ASSENTO_INDISPONIVEL);
  });

  test("DEC-REC-04 a reconexao nao atravessa o portao do tipo desconhecido", () => {
    const v = decidirAdmissao(fatos({ tipo: null, admissaoAnterior: anterior, assento: 2 }));
    assert.equal(v.ok, false);
    assert.equal(v.codigoRecusa, RECUSA.TIPO_DESCONHECIDO);
  });
});

describe("DEC-TRE — Treino", () => {
  test("DEC-TRE-01 o Treino NUNCA e admitido por esta autoridade", () => {
    // O caso 53: resultado local nao e aceito como resultado online. A forma
    // mais forte de garantir isso e nao existir admissao de treino — sem
    // admissao nao ha assento autoritativo, e sem assento nao ha partida
    // online que possa reivindicar o resultado.
    for (const extra of [{}, { assinaturaAtiva: true }, { passe: passeValido }]) {
      const v = decidirAdmissao(fatos({ tipo: TIPO_MESA.TREINO, ...extra }));
      assert.equal(v.ok, false);
      assert.equal(v.codigoRecusa, RECUSA.TREINO_NAO_ADMITE);
    }
  });

  test("DEC-TRE-02 nem assinatura ativa admite treino", () => {
    const v = decidirAdmissao(fatos({ tipo: TIPO_MESA.TREINO, assinaturaAtiva: true }));
    assert.equal(v.ok, false);
  });
});

describe("DEC-NEG — nao basta alterar no cliente (secao 13 da OS)", () => {
  test("DEC-NEG-01 campos inventados no payload nao mudam veredito nenhum", () => {
    // A decisao le APENAS os fatos nomeados em `FatosDaAdmissao`. Qualquer
    // campo extra e inerte — e este teste percorre a lista da secao 13.
    const veneno = {
      isVip: true,
      ehVip: true,
      vip: true,
      ranqueada: true,
      tipoMesa: "vipRanqueada",
      proprietario: true,
      publicId: "outro",
      codigoPrivado: "BMV-AAAA-AAAA",
      valorDaEntrada: 0,
      resultadoDoTreino: "vitoria",
      admissaoId: "forjada",
      fonteElegibilidade: "assinaturaVipAtiva",
    };
    const limpo = decidirAdmissao(fatos({ tipo: TIPO_MESA.VIP_RANQUEADA }));
    const envenenado = decidirAdmissao(fatos({ tipo: TIPO_MESA.VIP_RANQUEADA, ...veneno }));
    assert.deepEqual(envenenado, limpo);
    assert.equal(envenenado.ok, false);
  });

  test("DEC-NEG-02 uma admissao anterior FORJADA nao passa pelo assento", () => {
    // Reaproveitar admissao alheia exigiria acertar o assento tambem — e o
    // assento vem do gate do servidor, que o deriva de quem ja esta sentado.
    const v = decidirAdmissao(
      fatos({
        tipo: TIPO_MESA.VIP_RANQUEADA,
        assento: 0,
        admissaoAnterior: { admissaoId: "roubada", assento: 3, fonteElegibilidade: FONTE.ASSINATURA },
      }),
    );
    assert.equal(v.ok, false);
  });

  test("DEC-NEG-03 nenhum veredito aprovado sai sem fonte de elegibilidade", () => {
    const aprovacoes = [
      decidirAdmissao(fatos()),
      decidirAdmissao(fatos({ tipo: TIPO_MESA.VIP_RANQUEADA, assinaturaAtiva: true })),
      decidirAdmissao(fatos({ tipo: TIPO_MESA.VIP_RANQUEADA, passe: passeValido })),
    ];
    for (const v of aprovacoes) {
      assert.equal(v.ok, true);
      assert.ok(Object.values(FONTE).includes(v.fonteElegibilidade), "fonte fora da enumeracao");
    }
  });

  test("DEC-NEG-04 nenhuma recusa vaza o motivo real na forma de mensagem", () => {
    // O `codigoRecusa` e um simbolo de uma lista fechada. Ele nao interpola
    // valor nenhum vindo do cliente, entao nao ha como ele virar oraculo.
    const v = decidirAdmissao(fatos({ tipo: TIPO_MESA.PRIVADA, sala: null, assinaturaAtiva: true }));
    assert.equal(v.ok, false);
    assert.ok(Object.values(RECUSA).includes(v.codigoRecusa));
    assert.equal(/uid_|BURACO|BMV/.test(v.codigoRecusa), false);
  });
});
