/**
 * politica.test.js — QUE CONFIGURACAO CADA TIPO ACEITA, E O QUE ELE RECUSA.
 *
 * Cobre os casos obrigatorios 4 (Publica rejeita aposta), 6 (aceita 1.500,
 * 2.000 e 3.000), 7 (rejeita valor fora da politica), 8 (nao reintroduz 1.000),
 * 9 (nao libera espectadores premium indevidamente), 36 (nao VIP nao cria
 * Privada, pelo lado da politica) e 47/49/50 (Treino sem premio e sem
 * economia).
 *
 * A secao 13 da OS pede provas negativas de que "nao basta alterar no cliente".
 * Elas estao no bloco `POL-NEG`: cada uma monta o payload que um aplicativo
 * modificado enviaria e exige recusa.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const { TIPO_MESA } = require("../lib/tipos");
const {
  PONTOS_CANONICOS,
  PONTOS_LEGADOS,
  RECUSA_CONFIG,
  CAMPO,
  camposPermitidos,
  campoPermitido,
  permiteApostaDeEntrada,
  permiteEspectadores,
  temCodigoDeSala,
  temProprietarioDeCadeiras,
  criacaoExigeAssinaturaAtiva,
  validarConfiguracao,
} = require("../lib/politica");

const BASE = { modalidade: "stbl", jogadores: 4, pontos: 1500, tempo: 45, chat: "completo" };

describe("POL — os valores canonicos", () => {
  test("POL-01 os pontos sao 1.500, 2.000 e 3.000", () => {
    assert.deepEqual([...PONTOS_CANONICOS], [1500, 2000, 3000]);
  });

  test("POL-02 os tres pontos sao aceitos na Publica e na VIP", () => {
    for (const tipo of [TIPO_MESA.PUBLICA, TIPO_MESA.VIP_RANQUEADA]) {
      for (const pontos of PONTOS_CANONICOS) {
        const r = validarConfiguracao(tipo, { ...BASE, pontos });
        assert.equal(r.ok, true, `${tipo} recusou ${pontos}`);
        assert.equal(r.configuracao.pontos, pontos);
      }
    }
  });

  test("POL-03 a regra e a MESMA para assinante e nao assinante", () => {
    // "VIP compra acesso a competicao, nao vantagem." A lista de pontos da
    // VIP/Ranqueada e identica a da Publica, e este teste cai se alguem
    // acrescentar uma meta exclusiva de assinante.
    const publica = validarConfiguracao(TIPO_MESA.PUBLICA, BASE);
    const vip = validarConfiguracao(TIPO_MESA.VIP_RANQUEADA, BASE);
    assert.equal(publica.ok, true);
    assert.equal(vip.ok, true);
    assert.equal(publica.configuracao.pontos, vip.configuracao.pontos);
    assert.equal(publica.configuracao.modalidade, vip.configuracao.modalidade);
    assert.equal(publica.configuracao.tempo, vip.configuracao.tempo);
  });

  test("POL-04 valor de pontos fora da lista recusa", () => {
    for (const pontos of [900, 1200, 2500, 4000, 0, -1500, 1500.5]) {
      const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, pontos });
      assert.equal(r.ok, false, `aceitou ${pontos}`);
      assert.equal(r.motivo, RECUSA_CONFIG.PONTOS_INVALIDO);
    }
  });

  test("POL-05 1.000 tem motivo PROPRIO — a proposta superada nao volta calada", () => {
    assert.deepEqual([...PONTOS_LEGADOS], [1000]);
    for (const tipo of [TIPO_MESA.PUBLICA, TIPO_MESA.VIP_RANQUEADA]) {
      const r = validarConfiguracao(tipo, { ...BASE, pontos: 1000 });
      assert.equal(r.ok, false);
      assert.equal(r.motivo, RECUSA_CONFIG.PONTOS_LEGADOS);
    }
  });

  test("POL-06 pontos que nao sao numero recusam", () => {
    for (const pontos of ["1500", null, {}, []]) {
      const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, pontos });
      assert.equal(r.ok, false, `aceitou ${JSON.stringify(pontos)}`);
    }
  });
});

describe("POL — campos permitidos por tipo", () => {
  test("POL-07 a Publica nao tem aposta, espectadores nem cadeiras", () => {
    assert.equal(permiteApostaDeEntrada(TIPO_MESA.PUBLICA), false);
    assert.equal(permiteEspectadores(TIPO_MESA.PUBLICA), false);
    assert.equal(temProprietarioDeCadeiras(TIPO_MESA.PUBLICA), false);
    assert.equal(temCodigoDeSala(TIPO_MESA.PUBLICA), false);
  });

  test("POL-08 a VIP tem aposta e espectadores, e nao tem cadeiras nem codigo", () => {
    assert.equal(permiteApostaDeEntrada(TIPO_MESA.VIP_RANQUEADA), true);
    assert.equal(permiteEspectadores(TIPO_MESA.VIP_RANQUEADA), true);
    assert.equal(temProprietarioDeCadeiras(TIPO_MESA.VIP_RANQUEADA), false);
    assert.equal(temCodigoDeSala(TIPO_MESA.VIP_RANQUEADA), false);
  });

  test("POL-09 a Privada tem tudo, e e a unica com codigo e cadeiras", () => {
    assert.equal(temCodigoDeSala(TIPO_MESA.PRIVADA), true);
    assert.equal(temProprietarioDeCadeiras(TIPO_MESA.PRIVADA), true);
    assert.equal(temProprietarioDeCadeiras(TIPO_MESA.TREINO), false);
  });

  test("POL-10 o Treino nao tem chat, aposta, espectadores nem cadeiras", () => {
    const campos = [...camposPermitidos(TIPO_MESA.TREINO)];
    assert.deepEqual(campos.sort(), ["modalidade", "pontos", "tempo"]);
    assert.equal(permiteApostaDeEntrada(TIPO_MESA.TREINO), false);
    assert.equal(permiteEspectadores(TIPO_MESA.TREINO), false);
  });

  test("POL-11 criar Mesa Privada exige assinatura ativa; criar VIP nao", () => {
    // A cortesia da direito a ENTRAR numa mesa VIP, nunca a ABRIR uma sala
    // privada. Sao dois momentos diferentes, e a politica os separa.
    assert.equal(criacaoExigeAssinaturaAtiva(TIPO_MESA.PRIVADA), true);
    assert.equal(criacaoExigeAssinaturaAtiva(TIPO_MESA.VIP_RANQUEADA), false);
    assert.equal(criacaoExigeAssinaturaAtiva(TIPO_MESA.PUBLICA), false);
  });
});

describe("POL — normalizacao", () => {
  test("POL-12 o alias `sbtl` do motor antigo normaliza para `stbl`", () => {
    const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, modalidade: "SBTL" });
    assert.equal(r.ok, true);
    assert.equal(r.configuracao.modalidade, "stbl");
  });

  test("POL-13 modalidade fora do motor recusa", () => {
    for (const m of ["buraco", "", "abertoo", 7, null]) {
      const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, modalidade: m });
      assert.equal(r.ok, false, `aceitou ${JSON.stringify(m)}`);
      assert.equal(r.motivo, RECUSA_CONFIG.MODALIDADE_INVALIDA);
    }
  });

  test("POL-14 a Publica normaliza aposta para ZERO, sempre", () => {
    const r = validarConfiguracao(TIPO_MESA.PUBLICA, BASE);
    assert.equal(r.ok, true);
    assert.equal(r.configuracao.aposta, 0);
    assert.equal(r.configuracao.espectadores, false);
  });
});

describe("POL-NEG — nao basta alterar no cliente (secao 13 da OS)", () => {
  test("POL-NEG-01 Publica com aposta e RECUSADA, nao normalizada", () => {
    // Recusar em vez de ignorar: ignorar atenderia igual e esconderia a
    // tentativa. Aqui a tentativa vira motivo categorico no registro.
    for (const aposta of [500, 1000, 5000, 0]) {
      const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, aposta });
      assert.equal(r.ok, false, `aceitou aposta ${aposta} na Publica`);
      assert.equal(r.motivo, RECUSA_CONFIG.CAMPO_NAO_PERMITIDO);
      assert.equal(r.campo, CAMPO.APOSTA);
    }
  });

  test("POL-NEG-02 Publica com `aposta: 0` tambem recusa — o problema e o campo", () => {
    // O primeiro degrau para `aposta: 500` e `aposta: 0` passar batido.
    const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, aposta: 0 });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_CONFIG.CAMPO_NAO_PERMITIDO);
  });

  test("POL-NEG-03 Publica com espectadores premium recusa", () => {
    const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, espectadores: true });
    assert.equal(r.ok, false);
    assert.equal(r.campo, CAMPO.ESPECTADORES);
  });

  test("POL-NEG-04 Publica marcada como ranqueada recusa", () => {
    // `ranqueada` nao e campo de configuracao em tipo nenhum: a natureza
    // competitiva e do servidor, e nao do payload.
    for (const tipo of [TIPO_MESA.PUBLICA, TIPO_MESA.VIP_RANQUEADA, TIPO_MESA.PRIVADA]) {
      const r = validarConfiguracao(tipo, { ...BASE, ranqueada: true });
      assert.equal(r.ok, false, `${tipo} aceitou marcador ranqueado`);
      assert.equal(r.motivo, RECUSA_CONFIG.CAMPO_NAO_PERMITIDO);
    }
  });

  test("POL-NEG-05 campo `tipoMesa` no payload recusa", () => {
    // Reescrever o tipo depois de autorizado e o caso 20 da OS. A politica
    // fecha a porta pelo lado da configuracao; a decisao fecha pelo lado da
    // admissao.
    const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, tipoMesa: "vipRanqueada" });
    assert.equal(r.ok, false);
    assert.equal(r.campo, "tipoMesa");
  });

  test("POL-NEG-06 `isVip` no payload recusa", () => {
    const r = validarConfiguracao(TIPO_MESA.VIP_RANQUEADA, { ...BASE, isVip: true });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_CONFIG.CAMPO_NAO_PERMITIDO);
  });

  test("POL-NEG-07 Treino com premio, aposta ou espectador recusa", () => {
    for (const campo of ["aposta", "premio", "espectadores", "cadeiras", "chat"]) {
      const r = validarConfiguracao(TIPO_MESA.TREINO, {
        modalidade: "stbl",
        pontos: 1500,
        tempo: 45,
        [campo]: campo === "espectadores" ? true : 500,
      });
      assert.equal(r.ok, false, `Treino aceitou ${campo}`);
      assert.equal(r.motivo, RECUSA_CONFIG.CAMPO_NAO_PERMITIDO);
    }
  });

  test("POL-NEG-08 aposta fora da economia canonica recusa na VIP", () => {
    for (const aposta of [1, 250, 999999, -500]) {
      const r = validarConfiguracao(TIPO_MESA.VIP_RANQUEADA, { ...BASE, aposta });
      assert.equal(r.ok, false, `aceitou aposta ${aposta}`);
      assert.equal(r.motivo, RECUSA_CONFIG.APOSTA_INVALIDA);
    }
  });

  test("POL-NEG-09 cadeira com estado inventado recusa", () => {
    const r = validarConfiguracao(TIPO_MESA.PRIVADA, {
      ...BASE,
      cadeiras: ["liberada", "liberada", "liberada", "dono"],
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_CONFIG.CADEIRAS_INVALIDO);
  });

  test("POL-NEG-10 o campo estranho e recusado ANTES de o valor ser olhado", () => {
    // Ordem das passagens. Uma Publica com aposta E pontos invalidos tem que
    // recusar pelo CAMPO, nao pelo valor: inverter a ordem deixaria passar
    // `aposta: 0` numa configuracao no mais impecavel.
    const r = validarConfiguracao(TIPO_MESA.PUBLICA, { ...BASE, pontos: 1000, aposta: 500 });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_CONFIG.CAMPO_NAO_PERMITIDO);
  });

  test("POL-NEG-11 o campo `codigo` nao e configuracao em tipo nenhum", () => {
    // O codigo e cunhado pelo servidor. Aceita-lo no payload seria aceitar
    // codigo escolhido pelo cliente, que a secao 5.3 proibe expressamente.
    for (const tipo of [TIPO_MESA.PUBLICA, TIPO_MESA.VIP_RANQUEADA, TIPO_MESA.PRIVADA]) {
      const r = validarConfiguracao(tipo, { ...BASE, codigo: "BMV-AAAA-AAAA" });
      assert.equal(r.ok, false, `${tipo} aceitou codigo do cliente`);
      assert.equal(campoPermitido(tipo, "codigo"), false);
    }
  });
});
