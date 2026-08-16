/**
 * Prova a barreira de idempotencia da moderacao — logica pura, sem Firestore.
 *
 * POR QUE ESTE ARQUIVO EXISTE (homologacao P0 integrada).
 *
 * As tres codebases de Functions protegem a mesma coisa — "reprocessar nao pode
 * duplicar" — e cada uma resolveu de um jeito:
 *
 *   TORNEIOS  (functions/src/idempotency.ts)
 *     A chave vem do dominio e CARREGA o payload
 *     (`tournamentId|editionId|alvo`). Duas operacoes diferentes nao conseguem
 *     colidir na mesma chave, entao a existencia do documento e prova suficiente
 *     de que o pedido e o mesmo.
 *
 *   BILLING   (functions-billing/idempotencia.js)
 *     A chave e o hash do purchaseToken, que NAO carrega o payload — e por isso
 *     `conferirTitularidade` confere uid, produto e tipo antes de aceitar a
 *     repeticao. Um token de outro jogador que por acaso esteja `concedida` nao
 *     devolve a concessao alheia.
 *
 *   MODERACAO (functions-moderacao/src/idempotency.ts)
 *     Copiou o desenho de TORNEIOS ("Mesmo desenho de
 *     functions/src/idempotency.ts", diz o cabecalho) mas as chaves sao
 *     `${responsavel}|${sancaoIntentId}` e `${denuncianteUid}|${reportIntentId}`
 *     — elas NAO carregam o alvo nem o tipo. A precondicao que tornava o desenho
 *     de torneios seguro nao vale aqui, e a conferencia do billing nao foi
 *     trazida junto.
 *
 * O RISCO CONCRETO que estes testes protegem: um `sancaoIntentId` reaproveitado
 * com outro `userId` (ou outro `tipo`) encontra a chave reservada, e a Function
 * responde `{aplicada: true, jaAplicada: true}` sem ter aplicado NADA. A sancao
 * pedida some em silencio e o chamador recebe confirmacao. O mesmo vale para uma
 * denuncia reaproveitada contra outra pessoa.
 *
 * A GARANTIA PROTEGIDA: uma chave de intencao descreve UMA operacao. Se o pedido
 * que chega difere do que foi reservado, a resposta e CONFLITO — nunca sucesso
 * silencioso.
 *
 * Sem Firestore, sem emulador, sem relogio real e sem CWD: `decidirSobreReserva`
 * e `conferirConformidade` recebem o documento e os metadados como dados.
 */

'use strict';

const assert = require('node:assert/strict');
const { test, describe } = require('node:test');

const {
  ACAO_RESERVA,
  conferirConformidade,
  decidirSobreReserva,
} = require('../lib/idempotency.js');

/** Metadados de uma aplicacao de sancao — o caso de maior impacto. */
const SANCAO = Object.freeze({
  tarefa: 'aplicarSancao',
  ator: 'uidAdmin',
  alvo: 'uidJogador',
  impressao: 'silencio_chat|24h',
});

/** O documento que `executarUmaVez` grava em `moderationTasks`. */
function registro(sobrescreve = {}) {
  return {
    chave: 'uidAdmin|intent1',
    ...SANCAO,
    executadaEm: '2026-08-11T12:00:00.000Z',
    resultado: 'ok',
    ...sobrescreve,
  };
}

describe('decidirSobreReserva — chave livre executa', () => {
  test('sem documento reservado, o corpo deve rodar', () => {
    const d = decidirSobreReserva(null, SANCAO);
    assert.equal(d.acao, ACAO_RESERVA.EXECUTAR);
  });

  test('undefined tambem e chave livre (documento inexistente)', () => {
    const d = decidirSobreReserva(undefined, SANCAO);
    assert.equal(d.acao, ACAO_RESERVA.EXECUTAR);
  });
});

describe('decidirSobreReserva — repeticao legitima converge', () => {
  test('o MESMO pedido repetido e repeticao, nao erro', () => {
    const d = decidirSobreReserva(registro(), SANCAO);
    assert.equal(d.acao, ACAO_RESERVA.REPETICAO);
  });

  test('registro legado sem `impressao` ainda converge quando o resto bate', () => {
    // Compatibilidade: documentos gravados antes desta conferencia nao tem o
    // campo. Tratar ausencia como divergencia transformaria todo retry legitimo
    // de um registro antigo em CONFLITO.
    const antigo = registro();
    delete antigo.impressao;
    const d = decidirSobreReserva(antigo, SANCAO);
    assert.equal(d.acao, ACAO_RESERVA.REPETICAO);
  });
});

describe('decidirSobreReserva — intencao reaproveitada e CONFLITO', () => {
  test('DEFEITO P0: outro alvo com o mesmo intent id nao pode passar por repeticao', () => {
    // Antes da correcao isto respondia REPETICAO, e a Function devolvia
    // `{aplicada: true, jaAplicada: true}` sem sancionar `uidOutroJogador`.
    const d = decidirSobreReserva(registro(), { ...SANCAO, alvo: 'uidOutroJogador' });
    assert.equal(d.acao, ACAO_RESERVA.CONFLITO);
    assert.match(d.motivo, /alvo/);
  });

  test('outro tipo de sancao para o mesmo alvo tambem e CONFLITO', () => {
    // O caso do admin que quis escalar de silencio para suspensao reusando o
    // mesmo intent id: a escalada nao pode sumir em silencio.
    const d = decidirSobreReserva(registro(), {
      ...SANCAO,
      impressao: 'suspensao_permanente|null',
    });
    assert.equal(d.acao, ACAO_RESERVA.CONFLITO);
    assert.match(d.motivo, /impress/i);
  });

  test('outra tarefa reusando a chave e CONFLITO', () => {
    const d = decidirSobreReserva(registro(), { ...SANCAO, tarefa: 'registrarDenuncia' });
    assert.equal(d.acao, ACAO_RESERVA.CONFLITO);
    assert.match(d.motivo, /tarefa/);
  });

  test('outro ator reusando a chave e CONFLITO', () => {
    const d = decidirSobreReserva(registro(), { ...SANCAO, ator: 'uidOutroAdmin' });
    assert.equal(d.acao, ACAO_RESERVA.CONFLITO);
    assert.match(d.motivo, /ator/);
  });
});

describe('conferirConformidade — ordem e forma da conferencia', () => {
  test('alvo nulo de um lado e preenchido do outro divergem', () => {
    const c = conferirConformidade(registro({ alvo: null }), SANCAO);
    assert.equal(c.ok, false);
  });

  test('alvo nulo nos dois lados confere', () => {
    const c = conferirConformidade(registro({ alvo: null }), { ...SANCAO, alvo: null });
    assert.equal(c.ok, true);
  });

  test('a conferencia nao inventa divergencia por campo extra do documento', () => {
    // `executadaEm` e `resultado` sao do registro, nao do pedido: compara-los
    // faria toda repeticao virar conflito.
    const c = conferirConformidade(registro({ resultado: 'ok', executadaEm: 'outra' }), SANCAO);
    assert.equal(c.ok, true);
  });
});

describe('decidirSobreReserva — denuncia reaproveitada', () => {
  const DENUNCIA = Object.freeze({
    tarefa: 'registrarDenuncia',
    ator: 'uidDenunciante',
    alvo: 'uidDenunciado',
    impressao: 'mensagem|assedio',
  });

  test('DEFEITO P0: mesma intencao apontada para outra pessoa e CONFLITO', () => {
    const doc = { chave: 'uidDenunciante|intent1', ...DENUNCIA, resultado: 'ok' };
    const d = decidirSobreReserva(doc, { ...DENUNCIA, alvo: 'uidTerceiro' });
    assert.equal(d.acao, ACAO_RESERVA.CONFLITO);
  });

  test('a mesma denuncia reenviada (toque duplo, retry) converge', () => {
    const doc = { chave: 'uidDenunciante|intent1', ...DENUNCIA, resultado: 'ok' };
    const d = decidirSobreReserva(doc, { ...DENUNCIA });
    assert.equal(d.acao, ACAO_RESERVA.REPETICAO);
  });
});
