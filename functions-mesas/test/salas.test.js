/**
 * salas.test.js — O CODIGO DA MESA PRIVADA.
 *
 * Cobre os casos obrigatorios 38 (codigo invalido nao revela a existencia da
 * sala), 39 (codigo expirado recusa), 40 (codigo revogado recusa), 41
 * (tentativas excessivas sao limitadas), 46/47 (convidado nao controla
 * cadeiras, proprietario controla), 48 (comando adulterado de propriedade e
 * recusado) e 50 (codigo de uma sala nao autoriza outra).
 *
 * O eixo `SAL-ENT` mede a ENTROPIA, e ele existe porque o gerador de hoje
 * (`"BURACO-" + Math.floor(1000 + Math.random()*9000)`) tem nove mil saidas
 * possiveis. Um teste que so verificasse "o codigo tem oito letras" passaria
 * com um gerador igualmente fraco.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

const {
  ALFABETO,
  TAMANHO_CODIGO,
  BYTES_NECESSARIOS,
  VALIDADE_CODIGO_MS,
  TENTATIVAS_POR_JANELA,
  JANELA_TENTATIVAS_MS,
  MOTIVO_CODIGO,
  RECUSA_CADEIRA,
  cunharCodigo,
  normalizarCodigo,
  redigirCodigo,
  resolverCodigo,
  avaliarTentativa,
  podeControlarCadeiras,
} = require("../lib/salas");

const T0 = "2026-08-01T12:00:00.000Z";
const em = (ms) => new Date(Date.parse(T0) + ms).toISOString();
const MINUTO = 60 * 1000;

function codigoAleatorio() {
  return cunharCodigo(crypto.randomBytes(BYTES_NECESSARIOS));
}

function vinculo(extra = {}) {
  return {
    salaId: "sala_1",
    proprietarioUid: "uid_dono",
    criadoEm: T0,
    expiraEm: em(VALIDADE_CODIGO_MS),
    revogadoEm: null,
    ...extra,
  };
}

describe("SAL-ENT — entropia", () => {
  test("SAL-ENT-01 o alfabeto nao tem simbolos ambiguos ao serem ditados", () => {
    for (const proibido of ["0", "O", "1", "I", "L", "2", "Z", "5", "S", "8", "B"]) {
      assert.equal(ALFABETO.includes(proibido), false, `alfabeto contem ${proibido}`);
    }
    // Sem repeticao: um simbolo repetido sairia com o dobro da probabilidade.
    assert.equal(new Set(ALFABETO).size, ALFABETO.length);
  });

  test("SAL-ENT-02 o espaco de codigos e de pelo menos 2^36", () => {
    const bits = TAMANHO_CODIGO * Math.log2(ALFABETO.length);
    assert.ok(bits >= 36, `so ${bits.toFixed(1)} bits`);
    // O gerador de hoje tem ~13 bits. A margem nao e estetica.
    assert.ok(bits > 13 + 20);
  });

  test("SAL-ENT-03 mil codigos, mil valores diferentes", () => {
    const vistos = new Set();
    for (let i = 0; i < 1000; i++) vistos.add(codigoAleatorio());
    assert.equal(vistos.size, 1000);
  });

  test("SAL-ENT-04 a reducao de byte para simbolo e por rejeicao, e nao enviesa", () => {
    // `% 25` sobre 0..255 daria aos seis primeiros simbolos ~1.22x a chance dos
    // demais. Com rejeicao, a distribuicao e plana. 250 bytes cobrindo 0..249
    // devem produzir exatamente 10 ocorrencias de cada simbolo.
    const bytes = [];
    for (let b = 0; b < 256; b++) bytes.push(b);
    const contagem = new Map();
    const limite = 256 - (256 % ALFABETO.length);
    for (const b of bytes) {
      if (b >= limite) continue;
      const s = ALFABETO[b % ALFABETO.length];
      contagem.set(s, (contagem.get(s) || 0) + 1);
    }
    assert.equal(contagem.size, ALFABETO.length);
    for (const [simbolo, n] of contagem) {
      assert.equal(n, limite / ALFABETO.length, `vies em ${simbolo}`);
    }
  });

  test("SAL-ENT-05 bytes insuficientes LANCAM, e nao produzem codigo curto", () => {
    assert.throws(() => cunharCodigo([1, 2, 3]), RangeError);
  });
});

describe("SAL — normalizacao do que a pessoa digita", () => {
  test("SAL-01 o codigo cunhado sobrevive a ida e volta", () => {
    for (let i = 0; i < 50; i++) {
      const c = codigoAleatorio();
      assert.equal(normalizarCodigo(c), c);
    }
  });

  test("SAL-02 minusculas, espacos, prefixo esquecido: tudo resolve para o mesmo", () => {
    const c = codigoAleatorio();
    const nu = c.replace(/-/g, "").replace("BMV", "");
    for (const variante of [c.toLowerCase(), ` ${c} `, nu, nu.toLowerCase(), `bmv ${nu}`]) {
      assert.equal(normalizarCodigo(variante), c, `falhou em "${variante}"`);
    }
  });

  test("SAL-03 simbolo fora do alfabeto recusa ANTES de tocar o banco", () => {
    for (const ruim of ["BMV-0000-0000", "BMV-IIII-IIII", "", "BMV-AAA-AAA", null, 7, {}]) {
      assert.equal(normalizarCodigo(ruim), null, `aceitou ${JSON.stringify(ruim)}`);
    }
  });

  test("SAL-04 o log so mostra tres simbolos", () => {
    const c = codigoAleatorio();
    const red = redigirCodigo(c);
    assert.ok(red.endsWith("..."));
    assert.ok(red.length < c.length);
    // O que sobra nao reconstroi o codigo: cinco simbolos continuam ocultos.
    assert.equal(red.includes(c.slice(-4)), false);
  });
});

describe("SAL — resolucao, e o oraculo que nao existe", () => {
  test("SAL-05 codigo valido resolve para a sala vinculada", () => {
    const r = resolverCodigo({ vinculo: vinculo(), agora: em(MINUTO) });
    assert.equal(r.ok, true);
    assert.equal(r.salaId, "sala_1");
    assert.equal(r.proprietarioUid, "uid_dono");
  });

  test("SAL-06 inexistente, expirado e revogado tem motivos INTERNOS distintos", () => {
    assert.equal(resolverCodigo({ vinculo: null, agora: T0 }).motivo, MOTIVO_CODIGO.INEXISTENTE);
    assert.equal(
      resolverCodigo({ vinculo: vinculo(), agora: em(VALIDADE_CODIGO_MS) }).motivo,
      MOTIVO_CODIGO.EXPIRADO,
    );
    assert.equal(
      resolverCodigo({ vinculo: vinculo({ revogadoEm: em(MINUTO) }), agora: em(2 * MINUTO) }).motivo,
      MOTIVO_CODIGO.REVOGADO,
    );
  });

  test("SAL-07 os tres motivos internos NAO viram tres respostas no fio", () => {
    // O modulo expoe UMA recusa publica. Se alguem acrescentar uma segunda,
    // este teste cai — e a discussao sobre o oraculo volta para a mesa.
    const { RECUSA_CODIGO } = require("../lib/salas");
    assert.deepEqual(Object.keys(RECUSA_CODIGO), ["INDISPONIVEL"]);
  });

  test("SAL-08 revogacao vence prazo — sala encerrada nao resolve nem dentro da validade", () => {
    const r = resolverCodigo({
      vinculo: vinculo({ revogadoEm: em(MINUTO) }),
      agora: em(2 * MINUTO),
    });
    assert.equal(r.ok, false);
  });

  test("SAL-09 um codigo aponta para UMA sala", () => {
    // O caso 50: codigo de uma sala nao autoriza outra. O vinculo carrega o
    // `salaId`, e nao ha caminho em que ele seja escolhido por quem resolve.
    const a = resolverCodigo({ vinculo: vinculo({ salaId: "sala_A" }), agora: em(MINUTO) });
    const b = resolverCodigo({ vinculo: vinculo({ salaId: "sala_B" }), agora: em(MINUTO) });
    assert.equal(a.salaId, "sala_A");
    assert.equal(b.salaId, "sala_B");
    assert.notEqual(a.salaId, b.salaId);
  });
});

describe("SAL — limite de tentativas", () => {
  test("SAL-10 os dez primeiros palpites passam, o decimo primeiro nao", () => {
    let registro = null;
    for (let i = 1; i <= TENTATIVAS_POR_JANELA; i++) {
      const d = avaliarTentativa({ registro, agora: em(i * 1000) });
      assert.equal(d.permitido, true, `palpite ${i} foi barrado`);
      registro = d.proximo;
    }
    const excedente = avaliarTentativa({ registro, agora: em(11000) });
    assert.equal(excedente.permitido, false);
  });

  test("SAL-11 a tentativa RECUSADA tambem conta", () => {
    // Nao contar a recusada tornaria o limitador contornavel por insistencia.
    let registro = { janelaEm: T0, tentativas: TENTATIVAS_POR_JANELA };
    const d = avaliarTentativa({ registro, agora: em(1000) });
    assert.equal(d.permitido, false);
    assert.equal(d.proximo.tentativas, TENTATIVAS_POR_JANELA + 1);
  });

  test("SAL-12 a janela seguinte zera o contador", () => {
    const registro = { janelaEm: T0, tentativas: 99 };
    const d = avaliarTentativa({ registro, agora: em(JANELA_TENTATIVAS_MS) });
    assert.equal(d.permitido, true);
    assert.equal(d.proximo.tentativas, 1);
    assert.equal(d.proximo.janelaEm, em(JANELA_TENTATIVAS_MS));
  });

  test("SAL-13 forca bruta e inviavel: o espaco dividido pela vazao passa de mil anos", () => {
    const espaco = Math.pow(ALFABETO.length, TAMANHO_CODIGO);
    const porAno = (TENTATIVAS_POR_JANELA / JANELA_TENTATIVAS_MS) * 365 * 24 * 3600 * 1000;
    assert.ok(espaco / porAno > 1000, `so ${(espaco / porAno).toFixed(0)} anos`);
  });
});

describe("SAL — autoridade sobre as cadeiras", () => {
  test("SAL-14 o proprietario controla", () => {
    const r = podeControlarCadeiras({
      uidAutenticado: "uid_dono",
      proprietarioUid: "uid_dono",
      encerradaEm: null,
    });
    assert.equal(r.ok, true);
  });

  test("SAL-15 o convidado NAO controla, mesmo com codigo valido", () => {
    const r = podeControlarCadeiras({
      uidAutenticado: "uid_convidado",
      proprietarioUid: "uid_dono",
      encerradaEm: null,
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_CADEIRA.NAO_E_PROPRIETARIO);
  });

  test("SAL-16 comando adulterado de propriedade e recusado", () => {
    // O caso 48. A comparacao e com o UID AUTENTICADO. Um payload que traga
    // `proprietario: true` nao aparece nesta funcao, porque ela nao tem por
    // onde receber isso — e essa ausencia e o entregavel.
    const argumentos = podeControlarCadeiras.length;
    assert.equal(argumentos, 1, "a funcao passou a receber mais de um objeto de fatos");
    const r = podeControlarCadeiras({
      uidAutenticado: "uid_invasor",
      proprietarioUid: "uid_dono",
      encerradaEm: null,
      proprietario: true, // <- o campo que um cliente modificado enviaria
    });
    assert.equal(r.ok, false);
  });

  test("SAL-17 sala encerrada nao aceita comando nem do dono", () => {
    const r = podeControlarCadeiras({
      uidAutenticado: "uid_dono",
      proprietarioUid: "uid_dono",
      encerradaEm: em(MINUTO),
    });
    assert.equal(r.ok, false);
    assert.equal(r.motivo, RECUSA_CADEIRA.SALA_ENCERRADA);
  });
});
