const { test, describe } = require('node:test');
const assert = require('node:assert/strict');

const {
  VALOR_POR_JOGADOR,
  avaliarVinculo,
  avaliarPartida,
  deveReterParaRevisao,
  chaveLedger,
  normalizarCodigoPublico,
} = require('../politica');

describe('vínculo da indicação', () => {
  test('recusa autoindicação, repetição e vínculo depois de jogar', () => {
    assert.equal(avaliarVinculo({ inviteeUid: 'a', referrerUid: 'a' }).recusa, 'auto_indicacao');
    assert.equal(avaliarVinculo({ inviteeUid: 'a', referrerUid: 'b', jaVinculada: true }).recusa, 'indicacao_ja_vinculada');
    assert.equal(avaliarVinculo({ inviteeUid: 'a', referrerUid: 'b', jaJogou: true }).recusa, 'primeira_partida_ja_ocorreu');
  });

  test('aceita vínculo novo antes da primeira partida', () => {
    assert.deepEqual(avaliarVinculo({ inviteeUid: 'a', referrerUid: 'b' }), { aceita: true, recusa: null });
  });
});

test('código público aceita a forma humana sem relaxar o alfabeto', () => {
  assert.equal(normalizarCodigoPublico(' p0abc-defg-hjkm '), 'P0ABCDEFGHJKM');
  assert.equal(normalizarCodigoPublico('Poabci2345678'), 'P0ABC12345678');
  assert.equal(normalizarCodigoPublico('curto'), null);
  assert.equal(normalizarCodigoPublico('PUABCDEFGHIJK'), null);
});

describe('partida que libera a recompensa', () => {
  const base = {
    estado: 'finalizada',
    tipo: 'publica_casual',
    temRobo: false,
    participantes: [
      { classe: 'humano', userId: 'b' },
      { classe: 'humano', userId: 'a' },
    ],
  };

  test('aceita pública humana finalizada e ordena os UIDs', () => {
    assert.deepEqual(avaliarPartida(base), { elegivel: true, recusa: null, uids: ['a', 'b'] });
  });

  test('treino, privada, robô, abandono e participante duplicado não pagam', () => {
    assert.equal(avaliarPartida({ ...base, tipo: 'treinamento' }).elegivel, false);
    assert.equal(avaliarPartida({ ...base, tipo: 'privada' }).elegivel, false);
    assert.equal(avaliarPartida({ ...base, temRobo: true }).elegivel, false);
    assert.equal(avaliarPartida({ ...base, estado: 'abandonada' }).elegivel, false);
    assert.equal(avaliarPartida({ ...base, participantes: [base.participantes[0], base.participantes[0]] }).elegivel, false);
  });
});

test('valor, idempotência e limiar de revisão são determinísticos', () => {
  assert.equal(VALOR_POR_JOGADOR, 500);
  assert.equal(chaveLedger('convidado', 'indicador'), 'primeira_partida|convidado|indicador');
  assert.equal(deveReterParaRevisao({ concedidasHoje: 9, concedidasTotal: 49 }), false);
  assert.equal(deveReterParaRevisao({ concedidasHoje: 10, concedidasTotal: 10 }), true);
  assert.equal(deveReterParaRevisao({ concedidasHoje: 1, concedidasTotal: 50 }), true);
});
