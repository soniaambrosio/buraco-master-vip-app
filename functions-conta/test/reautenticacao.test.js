/**
 * reautenticacao.test.js — OS DOIS PORTOES QUE NAO SAO A AUTENTICACAO.
 *
 * OS de Exclusao de Conta e Dados do Jogador v1.
 *
 * O tempo entra como PARAMETRO, e nao como `Date.now()` dentro da funcao. E o
 * que permite encenar "quarenta minutos depois" sem esperar quarenta minutos —
 * e, mais importante, e o que faz o teste do relogio adiantado ser escrevivel.
 */

const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

const {
  FOLGA_RELOGIO_SEGUNDOS,
  JANELA_REAUTENTICACAO_SEGUNDOS,
  MOTIVO_REAUTENTICACAO,
  PALAVRA_DE_CONFIRMACAO,
  confirmacaoConfere,
  conferirReautenticacao,
} = require("../lib/reautenticacao");

const AGORA = 1_770_000_000; // instante fixo; o valor exato nao importa

describe("janela de reautenticacao", () => {
  test("credencial apresentada agora vale", () => {
    assert.equal(conferirReautenticacao(AGORA, AGORA).recente, true);
  });

  test("credencial dentro da janela vale", () => {
    const authTime = AGORA - (JANELA_REAUTENTICACAO_SEGUNDOS - 30);
    assert.equal(conferirReautenticacao(authTime, AGORA).recente, true);
  });

  test("credencial velha e recusada", () => {
    const v = conferirReautenticacao(AGORA - 40 * 60, AGORA);
    assert.equal(v.recente, false);
    assert.equal(v.motivo, MOTIVO_REAUTENTICACAO.VENCIDA);
  });

  test("a recusa diz a idade, para a tela poder explicar", () => {
    // "Sua sessao e de 40 minutos atras" e acionavel; "tente de novo" nao.
    const v = conferirReautenticacao(AGORA - 2400, AGORA);
    assert.equal(v.idadeSegundos, 2400);
  });

  test("token sem auth_time e recusado, e a ausencia nao vira aprovacao", () => {
    for (const vazio of [undefined, null]) {
      const v = conferirReautenticacao(vazio, AGORA);
      assert.equal(v.recente, false);
      assert.equal(v.motivo, MOTIVO_REAUTENTICACAO.AUSENTE);
    }
  });

  test("auth_time que nao e numero e recusado", () => {
    // Uma string convertivel seria aceita por um `Number()` distraido, e a porta
    // ficaria aberta para um claim customizado de tipo inesperado.
    for (const lixo of ["1770000000", {}, [], true, NaN, 0, -5]) {
      const v = conferirReautenticacao(lixo, AGORA);
      assert.equal(v.recente, false, String(lixo));
      assert.equal(v.motivo, MOTIVO_REAUTENTICACAO.INVALIDA, String(lixo));
    }
  });
});

describe("desencontro de relogio", () => {
  test("adiantamento pequeno e tolerado", () => {
    // O `auth_time` e carimbado noutra maquina. Sem folga, um segundo de
    // adiantamento recusaria credencial legitima de forma intermitente.
    const v = conferirReautenticacao(AGORA + 30, AGORA);
    assert.equal(v.recente, true);
  });

  test("credencial do futuro alem da folga e recusada", () => {
    // Aceitar faria de um auth_time inflado um passe permanente.
    const v = conferirReautenticacao(AGORA + FOLGA_RELOGIO_SEGUNDOS + 120, AGORA);
    assert.equal(v.recente, false);
    assert.equal(v.motivo, MOTIVO_REAUTENTICACAO.INVALIDA);
  });

  test("a idade nunca volta negativa", () => {
    assert.equal(conferirReautenticacao(AGORA + 30, AGORA).idadeSegundos, 0);
  });

  test("a folga vale para o fim da janela tambem", () => {
    const naFolga = AGORA - (JANELA_REAUTENTICACAO_SEGUNDOS + 30);
    assert.equal(conferirReautenticacao(naFolga, AGORA).recente, true);

    const fora = AGORA - (JANELA_REAUTENTICACAO_SEGUNDOS + FOLGA_RELOGIO_SEGUNDOS + 30);
    assert.equal(conferirReautenticacao(fora, AGORA).recente, false);
  });

  test("a janela pode ser encurtada por parametro", () => {
    assert.equal(conferirReautenticacao(AGORA - 300, AGORA, 60).recente, false);
  });
});

describe("palavra de confirmacao", () => {
  test("a palavra exata confere", () => {
    assert.equal(confirmacaoConfere(PALAVRA_DE_CONFIRMACAO), true);
  });

  test("minuscula e espaco em volta conferem", () => {
    // Teclado de celular com maiuscula automatica e dedo que encosta no espaco
    // nao sao mudanca de intencao.
    for (const digitado of ["excluir", "  EXCLUIR  ", "Excluir", "eXcLuIr\n"]) {
      assert.equal(confirmacaoConfere(digitado), true, JSON.stringify(digitado));
    }
  });

  test("qualquer outra coisa nao confere", () => {
    for (const errado of ["", "EXCLUI", "EXCLUIR CONTA", "sim", "DELETE", null, 1, {}]) {
      assert.equal(confirmacaoConfere(errado), false, JSON.stringify(errado));
    }
  });
});
