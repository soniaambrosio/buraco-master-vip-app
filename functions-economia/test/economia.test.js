/**
 * Testes da POLITICA e da ELEGIBILIDADE da economia basica — logica pura.
 *
 * `node --test`, sem emulador, sem rede e sem relogio. O que esta camada prova:
 *
 *   POLITICA   os tres numeros aprovados (ECO-01 a ECO-03). Se alguem trocar
 *              100, 15 ou -10 sem decidir, estes testes caem — e essa e a
 *              funcao deles.
 *   PISO       a tabela da secao 4 da OS, caso a caso (ECO-10 a ECO-15).
 *   AUTORIDADE quem paga e quem nao paga sai do REGISTRO server-owned e de mais
 *              nada (ECO-20 em diante). Aqui esta a prova de que o cliente nao
 *              tem por onde escolher o proprio resultado.
 *
 * A transacao — a garantia de que nada acontece duas vezes — e o outro arquivo,
 * `carteira.test.js`, contra o Firestore falso.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  MOTIVO,
  POLITICA,
  PISO,
  TIPOS_QUE_PAGAM,
  RECUSA,
  tipoMoveCarteira,
  chaveBoasVindas,
  chaveResultado,
  saldoLegivel,
  aplicarPiso,
  ladoDoAssento,
  movimentosDoResultado,
} = require('../economia');

// ---------------------------------------------------------------------------
// Apoio: monta um documento `matches/{matchId}` como
// `RegistroDePartida.toJson()` o grava.
// ---------------------------------------------------------------------------

/** Assento par -> `nos`; impar -> `eles`. Igual a `ParticipantePartida.lado`. */
function humano(uid, assento) {
  return {
    classe: 'humano',
    userId: uid,
    botId: null,
    assento,
    lado: assento % 2 === 0 ? 'nos' : 'eles',
    participanteId: null,
  };
}

function robo(botId, assento) {
  return {
    classe: 'robo',
    userId: null,
    botId,
    assento,
    lado: assento % 2 === 0 ? 'nos' : 'eles',
    participanteId: null,
  };
}

function espectador(uid) {
  return {
    classe: 'espectador',
    userId: uid,
    botId: null,
    assento: null,
    lado: null,
    participanteId: null,
  };
}

function convidado(participanteId, assento) {
  return {
    classe: 'convidado',
    userId: null,
    botId: null,
    assento,
    lado: assento % 2 === 0 ? 'nos' : 'eles',
    participanteId,
  };
}

/** Mesa cheia de humanos: A e C sao `nos`, B e D sao `eles`. */
function partida(extra = {}) {
  return {
    matchId: 'match-mesa-1',
    estado: 'finalizada',
    tipo: 'publica_ranqueada',
    motivoEncerramento: 'meta_atingida',
    ladoVencedor: 'nos',
    participantes: [humano('uidA', 0), humano('uidB', 1), humano('uidC', 2), humano('uidD', 3)],
    ...extra,
  };
}

const chaves = (r) => r.movimentos.map((m) => `${m.uid}:${m.motivo}:${m.deltaNominal}`);

// ===========================================================================
// POLITICA — os numeros aprovados
// ===========================================================================

test('ECO-01 boas-vindas valem exatamente 100 fichas — valor normativo da OS', () => {
  // O NUMERO APROVADO, amarrado em teste. Ele aparece tambem, por extenso, no
  // documento de fechamento (docs/OS-ECONOMIA-BOAS-VINDAS-E-RESULTADO.md): 100
  // fichas na primeira concessao, uma vez por conta, para sempre.
  assert.strictEqual(POLITICA.boasVindas, 100);
});

test('ECO-02 vitoria vale exatamente +15', () => {
  assert.strictEqual(POLITICA.vitoria, 15);
});

test('ECO-03 derrota vale exatamente -10', () => {
  assert.strictEqual(POLITICA.derrota, -10);
});

test('ECO-04 o piso da carteira e zero', () => {
  assert.strictEqual(PISO, 0);
});

test('ECO-05 os tres motivos contabeis tem os nomes da secao 9 da OS', () => {
  assert.deepStrictEqual(
    { ...MOTIVO },
    {
      BOAS_VINDAS: 'boas_vindas',
      VITORIA: 'vitoria_partida',
      DERROTA: 'derrota_partida',
    }
  );
});

// ===========================================================================
// CHAVES DE IDEMPOTENCIA
// ===========================================================================

test('ECO-06 a chave de boas-vindas e a conta + o evento, e nada mais', () => {
  assert.strictEqual(chaveBoasVindas('uidA'), 'boas_vindas|uidA');
  // Sessao, aparelho e instalacao nao entram: e por isso que reinstalar nao
  // rende outro bonus.
  assert.strictEqual(chaveBoasVindas('uidA'), chaveBoasVindas('uidA'));
  assert.notStrictEqual(chaveBoasVindas('uidA'), chaveBoasVindas('uidB'));
});

test('ECO-07 a chave do resultado e partida + jogador + tipo do resultado', () => {
  assert.strictEqual(
    chaveResultado('match-1', 'uidA', MOTIVO.VITORIA),
    'partida|match-1|uidA|vitoria_partida'
  );
  // Vitoria e derrota da MESMA partida nao colidem — sem o motivo na chave, um
  // estorno futuro seria recusado como duplicata do lancamento que estorna.
  assert.notStrictEqual(
    chaveResultado('match-1', 'uidA', MOTIVO.VITORIA),
    chaveResultado('match-1', 'uidA', MOTIVO.DERROTA)
  );
  // Jogadores diferentes da mesma partida tambem nao.
  assert.notStrictEqual(
    chaveResultado('match-1', 'uidA', MOTIVO.DERROTA),
    chaveResultado('match-1', 'uidB', MOTIVO.DERROTA)
  );
});

// ===========================================================================
// LEITURA DO SALDO
// ===========================================================================

test('ECO-08 carteira ausente vale zero — e o estado de todo jogador novo', () => {
  assert.strictEqual(saldoLegivel(undefined), 0);
  assert.strictEqual(saldoLegivel(null), 0);
  assert.strictEqual(saldoLegivel(0), 0);
  assert.strictEqual(saldoLegivel(1500), 1500);
});

test('ECO-09 saldo que nao e inteiro >= 0 e DUVIDA, e duvida nao vira zero', () => {
  // Tratar lixo como zero apagaria as fichas de um jogador. Devolver `null`
  // faz quem chama recusar o movimento e registrar o defeito.
  for (const ruim of [-1, -0.5, 10.5, NaN, Infinity, '100', {}, [], true]) {
    assert.strictEqual(saldoLegivel(ruim), null, `${String(ruim)} deveria ser ilegivel`);
  }
});

// ===========================================================================
// PISO — a tabela da secao 4, caso a caso
// ===========================================================================

test('ECO-10 saldo 100 + derrota termina em 90', () => {
  assert.deepStrictEqual(aplicarPiso(100, POLITICA.derrota), { delta: -10, depois: 90 });
});

test('ECO-11 saldo 10 + derrota termina em 0', () => {
  assert.deepStrictEqual(aplicarPiso(10, POLITICA.derrota), { delta: -10, depois: 0 });
});

test('ECO-12 saldo 6 + derrota termina em 0, e o delta efetivo e -6', () => {
  // O delta gravado e o que ACONTECEU, para `antes + delta == depois` valer em
  // toda linha do livro-razao. O -10 nominal viaja ao lado, no recibo.
  assert.deepStrictEqual(aplicarPiso(6, POLITICA.derrota), { delta: -6, depois: 0 });
});

test('ECO-13 saldo 0 + derrota continua em 0, sem movimento nenhum', () => {
  assert.deepStrictEqual(aplicarPiso(0, POLITICA.derrota), { delta: 0, depois: 0 });
});

test('ECO-14 nenhum saldo inicial de 0 a 200 produz resultado negativo', () => {
  for (let saldo = 0; saldo <= 200; saldo += 1) {
    const { delta, depois } = aplicarPiso(saldo, POLITICA.derrota);
    assert.ok(depois >= 0, `saldo ${saldo} produziu ${depois}`);
    assert.strictEqual(saldo + delta, depois, `incoerente em ${saldo}`);
  }
});

test('ECO-15 a vitoria soma sem teto e o piso nao a atrapalha', () => {
  assert.deepStrictEqual(aplicarPiso(0, POLITICA.vitoria), { delta: 15, depois: 15 });
  assert.deepStrictEqual(aplicarPiso(90, POLITICA.vitoria), { delta: 15, depois: 105 });
});

test('ECO-16 os assentos pares sao `nos` e os impares sao `eles`', () => {
  assert.deepStrictEqual([0, 1, 2, 3].map(ladoDoAssento), ['nos', 'eles', 'nos', 'eles']);
  for (const fora of [-1, 4, 1.5, null, undefined, '0']) {
    assert.strictEqual(ladoDoAssento(fora), null);
  }
});

// ===========================================================================
// AUTORIDADE — quem paga sai do registro, e de mais nada
// ===========================================================================

test('ECO-20 partida finalizada paga +15 ao lado vencedor e -10 ao perdedor', () => {
  const r = movimentosDoResultado(partida());
  assert.strictEqual(r.recusa, null);
  assert.deepStrictEqual(chaves(r), [
    'uidA:vitoria_partida:15', // assento 0 -> nos -> venceu
    'uidB:derrota_partida:-10', // assento 1 -> eles
    'uidC:vitoria_partida:15', // assento 2 -> nos
    'uidD:derrota_partida:-10', // assento 3 -> eles
  ]);
});

test('ECO-21 abandono e resultado oficial: a mesa abandonada movimenta', () => {
  // `EstadoDaPartida.valeu` inclui `abandonada`, e o dominio exige lado
  // vencedor em todo motivo que nao seja anulacao.
  const r = movimentosDoResultado(
    partida({ estado: 'abandonada', motivoEncerramento: 'abandono', ladoVencedor: 'eles' })
  );
  assert.strictEqual(r.recusa, null);
  assert.deepStrictEqual(chaves(r), [
    'uidA:derrota_partida:-10',
    'uidB:vitoria_partida:15',
    'uidC:derrota_partida:-10',
    'uidD:vitoria_partida:15',
  ]);
});

test('ECO-22 partida ANULADA nao movimenta carteira nenhuma', () => {
  // `MotivoEncerramento.anulada` desemboca em `EstadoDaPartida.cancelada`, e
  // partida anulada nunca tem `ladoVencedor` — as duas guardas pegam.
  const r = movimentosDoResultado(
    partida({ estado: 'cancelada', motivoEncerramento: 'anulada', ladoVencedor: null })
  );
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.NAO_VALEU);
});

test('ECO-23 partida NAO CONCLUIDA nao movimenta carteira nenhuma', () => {
  for (const estado of ['criada', 'aguardando', 'ativa', 'reconectando']) {
    const r = movimentosDoResultado(partida({ estado, ladoVencedor: null }));
    assert.deepStrictEqual(r.movimentos, [], `${estado} movimentou`);
    assert.strictEqual(r.recusa, RECUSA.NAO_VALEU);
  }
});

test('ECO-24 registro ausente ou vazio nao movimenta nada', () => {
  for (const nada of [null, undefined, 'texto', 42]) {
    const r = movimentosDoResultado(nada);
    assert.deepStrictEqual(r.movimentos, []);
    assert.strictEqual(r.recusa, RECUSA.SEM_REGISTRO);
  }
});

test('ECO-25 EMPATE: sem lado vencedor declarado, ninguem ganha e ninguem perde', () => {
  // BASELINE PRESERVADO, e ele e ausencia de regra: o Motor de Partidas NAO
  // produz empate. `Jogo` so encerra quando alguem cruza a meta sem empate
  // exato, e `capturarDesfecho` estoura se o placar empatado for marcado como
  // encerrado. Nao existe hoje caminho que grave `finalizada` sem vencedor.
  //
  // Esta OS nao criou regra de empate. O que ela faz e nao pagar nada quando o
  // vencedor nao for afirmavel — que e o comportamento conservador e o mesmo
  // zero que valeria hoje.
  const r = movimentosDoResultado(partida({ ladoVencedor: null }));
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.SEM_VENCEDOR);
});

test('ECO-26 robo, convidado e espectador nao entram na carteira de ninguem', () => {
  const r = movimentosDoResultado(
    partida({
      participantes: [
        humano('uidA', 0),
        robo('bot-facil-3', 1),
        convidado('conv-9', 2),
        humano('uidD', 3),
        espectador('uidPlateia'),
      ],
    })
  );
  assert.strictEqual(r.recusa, null);
  // O espectador tem `userId` e mesmo assim fica de fora: `classe` e o criterio,
  // e so `humano` compete por uma carteira.
  assert.deepStrictEqual(chaves(r), ['uidA:vitoria_partida:15', 'uidD:derrota_partida:-10']);
});

test('ECO-27 mesa CONTRA ROBOS nao paga nada: farm fechado', () => {
  // A decisao comercial: bot nao reclama de perder e a mesa reinicia sozinha, o
  // que faria disto o caminho mais barato de fabricar fichas no produto.
  const r = movimentosDoResultado(
    partida({
      tipo: 'contra_robos',
      participantes: [humano('uidA', 0), robo('b1', 1), robo('b2', 2), robo('b3', 3)],
    })
  );
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.TIPO_NAO_PAGA);
});

test('ECO-27b TREINAMENTO nao gera economia', () => {
  const r = movimentosDoResultado(partida({ tipo: 'treinamento' }));
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.TIPO_NAO_PAGA);
});

test('ECO-27c MESA PRIVADA nao movimenta: resultado combinavel entre dois', () => {
  // O dono da sala escolhe os adversarios. Dois jogadores combinariam quem perde
  // e quem ganha e fabricariam saldo em par, sem nenhum deles precisar mentir
  // sobre o resultado — bastaria jogar de verdade e alternar.
  const r = movimentosDoResultado(partida({ tipo: 'privada' }));
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.TIPO_NAO_PAGA);
});

test('ECO-27d A TABELA INTEIRA, tipo a tipo — protecao contra regressao', () => {
  // Os seis tipos que `TipoDePartida` declara, todos escritos aqui. Este teste
  // cai se alguem acrescentar uma modalidade a `TIPOS_QUE_PAGAM` sem decidir, e
  // cai se alguem tirar uma que paga.
  const politica = {
    publica_casual: true,
    publica_ranqueada: true,
    torneio: true,
    treinamento: false,
    contra_robos: false,
    privada: false,
  };

  for (const [tipo, paga] of Object.entries(politica)) {
    const r = movimentosDoResultado(partida({ tipo }));
    assert.strictEqual(tipoMoveCarteira(tipo), paga, `tipoMoveCarteira(${tipo})`);
    if (paga) {
      assert.strictEqual(r.recusa, null, `${tipo} deveria pagar`);
      assert.deepStrictEqual(chaves(r), [
        'uidA:vitoria_partida:15',
        'uidB:derrota_partida:-10',
        'uidC:vitoria_partida:15',
        'uidD:derrota_partida:-10',
      ]);
    } else {
      assert.deepStrictEqual(r.movimentos, [], `${tipo} nao deveria pagar`);
      assert.strictEqual(r.recusa, RECUSA.TIPO_NAO_PAGA, `${tipo}`);
    }
  }

  // E a constante nao pode ter ganhado membro que a tabela acima nao conhece.
  assert.deepStrictEqual(
    [...TIPOS_QUE_PAGAM].sort(),
    Object.keys(politica).filter((t) => politica[t]).sort()
  );
});

test('ECO-27e tipo ausente, nulo ou desconhecido NAO paga — a duvida recusa', () => {
  // Lista de permissao, e nao de exclusao: uma modalidade nova nao passa a pagar
  // sozinha, e um documento sem `tipo` nao vira dinheiro por omissao.
  for (const tipo of [undefined, null, '', 'publica', 'PUBLICA_CASUAL', 42, {}]) {
    assert.strictEqual(tipoMoveCarteira(tipo), false, `${String(tipo)}`);
    const r = movimentosDoResultado(partida({ tipo }));
    assert.deepStrictEqual(r.movimentos, [], `${String(tipo)} movimentou`);
    assert.strictEqual(r.recusa, RECUSA.TIPO_NAO_PAGA);
  }
});

test('ECO-28 `lado` denormalizado adulterado invalida o registro inteiro', () => {
  // A unica forma de um humano trocar de time depois do fato seria editar o
  // campo denormalizado. Recalcular do assento e conferir custa nada.
  const p = partida();
  p.participantes[1] = { ...humano('uidB', 1), lado: 'nos' };
  const r = movimentosDoResultado(p);
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.INCOERENTE);
});

test('ECO-29 a mesma conta em dois assentos invalida o registro inteiro', () => {
  const r = movimentosDoResultado(
    partida({ participantes: [humano('uidA', 0), humano('uidA', 1), humano('uidC', 2)] })
  );
  assert.deepStrictEqual(r.movimentos, []);
  assert.strictEqual(r.recusa, RECUSA.INCOERENTE);
});

test('ECO-30 humano sem userId, sem assento ou participante torto invalida tudo', () => {
  const semUid = partida({ participantes: [{ ...humano('uidA', 0), userId: null }] });
  assert.strictEqual(movimentosDoResultado(semUid).recusa, RECUSA.INCOERENTE);

  const semAssento = partida({ participantes: [{ ...humano('uidA', 0), assento: null }] });
  assert.strictEqual(movimentosDoResultado(semAssento).recusa, RECUSA.INCOERENTE);

  assert.strictEqual(
    movimentosDoResultado(partida({ participantes: [null] })).recusa,
    RECUSA.INCOERENTE
  );
  assert.strictEqual(
    movimentosDoResultado(partida({ participantes: 'nao-e-lista' })).recusa,
    RECUSA.INCOERENTE
  );
});

test('ECO-31 O CLIENTE NAO ESCOLHE O RESULTADO: campos extras sao ignorados', () => {
  // A assinatura de `movimentosDoResultado` recebe UM registro server-owned e
  // nada mais — nao ha parametro por onde declarar vitoria, valor ou saldo. Um
  // registro cheio de campos inventados produz exatamente o mesmo resultado que
  // o registro limpo: a decisao sai de `estado`, `ladoVencedor` e `assento`.
  const limpo = movimentosDoResultado(partida());
  const forjado = movimentosDoResultado(
    partida({
      venci: true,
      vencedor: 'uidB',
      recompensa: 999999,
      moedas: 999999,
      saldoFinal: 999999,
      delta: 999999,
      participantes: [
        { ...humano('uidA', 0), venceu: false, premio: 0 },
        { ...humano('uidB', 1), venceu: true, premio: 999999 },
        humano('uidC', 2),
        humano('uidD', 3),
      ],
    })
  );
  assert.deepStrictEqual(chaves(forjado), chaves(limpo));
  assert.deepStrictEqual(chaves(forjado), [
    'uidA:vitoria_partida:15',
    'uidB:derrota_partida:-10',
    'uidC:vitoria_partida:15',
    'uidD:derrota_partida:-10',
  ]);
});

test('ECO-32 nenhum movimento sai fora dos dois valores da politica', () => {
  // Rede de seguranca contra um caminho futuro que calcule delta em vez de
  // copiar a politica.
  for (const vencedor of ['nos', 'eles']) {
    const r = movimentosDoResultado(partida({ ladoVencedor: vencedor }));
    for (const m of r.movimentos) {
      assert.ok(
        m.deltaNominal === POLITICA.vitoria || m.deltaNominal === POLITICA.derrota,
        `delta inesperado: ${m.deltaNominal}`
      );
      assert.strictEqual(
        m.motivo,
        m.deltaNominal > 0 ? MOTIVO.VITORIA : MOTIVO.DERROTA
      );
    }
  }
});
