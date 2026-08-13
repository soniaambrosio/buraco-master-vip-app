/**
 * Testes da CARTEIRA — a garantia que custa dinheiro.
 *
 * `node --test` contra o Firestore falso de `test/apoio/firestore_falso.js`, que
 * implementa CONCORRENCIA OTIMISTA de verdade: cada documento tem versao, a
 * transacao anota o que leu, e no commit uma versao que mudou descarta o
 * trabalho inteiro e roda de novo. Sem isso, "reler dentro da transacao" nao
 * significaria nada e os testes de corrida provariam apenas que o autor sabe o
 * resultado que quer.
 *
 * `pausarAntesDoCommit` e o que torna a corrida DETERMINISTICA: sem um ponto de
 * interleaving controlado, teste de concorrencia vira sorteio.
 *
 * O QUE ESTA CAMADA PROVA
 *   CAR-01..09  o bonus de boas-vindas acontece uma vez por conta, sob retry,
 *               sob login repetido e sob duas execucoes concorrentes;
 *   CAR-10..19  vitoria e derrota, o piso zero, e a mesma partida processada
 *               duas vezes ou por duas Functions ao mesmo tempo;
 *   CAR-20..24  a partida inteira, do registro server-owned ate a carteira.
 *
 * O QUE ELA NAO PROVA: as regras de `firestore.rules` (o Firestore falso nao as
 * conhece) e o adaptador de gatilho dentro de `index.js`. O que o gatilho
 * decide esta todo aqui e em `economia.test.js`.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  COL_LEDGER,
  COL_CARTEIRA,
  CAMPO_SALDO,
  MOTIVO,
  POLITICA,
  chaveBoasVindas,
  chaveResultado,
  movimentosDoResultado,
} = require('../economia');
const { EFEITO, criarCarteira } = require('../economiaStore');
const { FirestoreFalso, CARIMBO } = require('./apoio/firestore_falso');

const UID = 'uid-jogadora-1';
const MATCH = 'match-mesa-7';

function montar() {
  const db = new FirestoreFalso();
  const carteira = criarCarteira({ db, carimbo: () => CARIMBO });
  return { db, carteira };
}

/** Porta de interleaving: uma Promise que outro trecho abre. */
function porta() {
  let abrir;
  const aberta = new Promise((r) => {
    abrir = r;
  });
  return { aberta, abrir };
}

const saldoDe = (db, uid) => {
  const d = db.ver(`${COL_CARTEIRA}/${uid}`);
  return d == null ? null : d[CAMPO_SALDO];
};

const recibos = (db) => db.caminhos().filter((c) => c.startsWith(`${COL_LEDGER}/`));

/** Semeia uma carteira com saldo, como billing a deixaria. */
const comSaldo = (db, uid, fichas) => db.semear(`${COL_CARTEIRA}/${uid}`, { [CAMPO_SALDO]: fichas });

/**
 * O que o gatilho `aoRegistrarPartida` faz: deriva os movimentos do registro e
 * aplica cada um. Replicado aqui porque `index.js` importa `firebase-functions`,
 * e este codebase roda os testes sem `node_modules` de proposito.
 */
async function liquidar(carteira, matchId, registro) {
  const { movimentos, recusa } = movimentosDoResultado(registro);
  if (recusa) return { recusa, resultados: [] };
  const resultados = [];
  for (const m of movimentos) {
    resultados.push(
      await carteira.aplicarMovimentoDePartida({
        matchId,
        uid: m.uid,
        motivo: m.motivo,
        deltaNominal: m.deltaNominal,
      })
    );
  }
  return { recusa: null, resultados };
}

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

function partidaFinalizada(extra = {}) {
  return {
    matchId: MATCH,
    estado: 'finalizada',
    tipo: 'publica_ranqueada',
    motivoEncerramento: 'meta_atingida',
    ladoVencedor: 'nos',
    participantes: [humano('uidA', 0), humano('uidB', 1)],
    ...extra,
  };
}

// ===========================================================================
// BOAS-VINDAS
// ===========================================================================

test('CAR-01 conta elegivel recebe exatamente 100 fichas', async () => {
  const { db, carteira } = montar();

  const r = await carteira.concederBoasVindas({ uid: UID });

  assert.strictEqual(r.efeito, EFEITO.LANCADO);
  assert.strictEqual(r.delta, 100);
  assert.strictEqual(r.antes, 0);
  assert.strictEqual(r.depois, 100);
  assert.strictEqual(saldoDe(db, UID), 100);
});

test('CAR-02 segundo login NAO concede outros 100', async () => {
  const { db, carteira } = montar();

  await carteira.concederBoasVindas({ uid: UID });
  const segunda = await carteira.concederBoasVindas({ uid: UID });

  assert.strictEqual(segunda.efeito, EFEITO.JA_LANCADO);
  assert.strictEqual(segunda.delta, 0);
  assert.strictEqual(saldoDe(db, UID), 100);
  assert.deepStrictEqual(recibos(db), [`${COL_LEDGER}/${chaveBoasVindas(UID)}`]);
});

test('CAR-03 retry nao duplica o bonus, por mais que se repita', async () => {
  const { db, carteira } = montar();

  for (let i = 0; i < 8; i += 1) await carteira.concederBoasVindas({ uid: UID });

  assert.strictEqual(saldoDe(db, UID), 100);
  assert.strictEqual(recibos(db).length, 1);
});

test('CAR-04 duas concessoes CONCORRENTES creditam uma unica vez', async () => {
  const { db, carteira } = montar();

  const chegou = porta();
  const liberado = porta();
  let primeira = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeira) return;
    primeira = false;
    chegou.abrir();
    await liberado.aberta;
  };

  // A entra, le a carteira sem recibo, e para na porta do commit.
  const pA = carteira.concederBoasVindas({ uid: UID });
  await chegou.aberta;

  // B corre inteira por dentro e commita primeiro.
  const rB = await carteira.concederBoasVindas({ uid: UID });

  liberado.abrir();
  const rA = await pA;

  // A perdeu a corrida: o documento que ela leu mudou, a transacao rodou de novo
  // e da segunda vez o recibo ja existia. +100 uma vez, nao +200.
  assert.strictEqual(rB.efeito, EFEITO.LANCADO);
  assert.strictEqual(rA.efeito, EFEITO.JA_LANCADO);
  assert.ok(db.conflitos >= 1, 'a corrida precisa ter sido detectada de verdade');
  assert.strictEqual(saldoDe(db, UID), 100);
  assert.strictEqual(recibos(db).length, 1);
});

test('CAR-05 dez concessoes disparadas juntas creditam 100, e so 100', async () => {
  const { db, carteira } = montar();

  const r = await Promise.all(
    Array.from({ length: 10 }, () => carteira.concederBoasVindas({ uid: UID }))
  );

  assert.strictEqual(r.filter((x) => x.efeito === EFEITO.LANCADO).length, 1);
  assert.strictEqual(saldoDe(db, UID), 100);
  assert.strictEqual(recibos(db).length, 1);
});

test('CAR-06 CONTA PREEXISTENTE recebe o bonus sem migracao e sem perder saldo', async () => {
  // A compatibilidade da secao 3 sai de graca da propria chave: uma conta criada
  // antes desta OS simplesmente ainda nao tem recibo. Nao ha varredura, nao ha
  // alteracao de dado historico, e o que ela ja tinha e somado, nao substituido.
  const { db, carteira } = montar();
  comSaldo(db, UID, 1500); // fichas que a assinatura ja havia entregue

  const r = await carteira.concederBoasVindas({ uid: UID });

  assert.strictEqual(r.efeito, EFEITO.LANCADO);
  assert.strictEqual(saldoDe(db, UID), 1600);
  const segunda = await carteira.concederBoasVindas({ uid: UID });
  assert.strictEqual(segunda.efeito, EFEITO.JA_LANCADO);
  assert.strictEqual(saldoDe(db, UID), 1600);
});

test('CAR-07 contas diferentes nao dividem recibo', async () => {
  const { db, carteira } = montar();

  await carteira.concederBoasVindas({ uid: 'uidA' });
  await carteira.concederBoasVindas({ uid: 'uidB' });

  assert.strictEqual(saldoDe(db, 'uidA'), 100);
  assert.strictEqual(saldoDe(db, 'uidB'), 100);
  assert.strictEqual(recibos(db).length, 2);
});

test('CAR-08 o recibo grava jogador, valor, motivo, chave e instante', async () => {
  const { db, carteira } = montar();
  await carteira.concederBoasVindas({ uid: UID });

  const recibo = db.ver(`${COL_LEDGER}/${chaveBoasVindas(UID)}`);
  assert.deepStrictEqual(recibo, {
    chaveIdempotencia: `boas_vindas|${UID}`,
    uid: UID,
    motivo: MOTIVO.BOAS_VINDAS,
    deltaNominal: 100,
    delta: 100,
    saldoAntes: 0,
    saldoDepois: 100,
    matchId: null,
    registradoEm: CARIMBO, // carimbo do SERVIDOR, nao relogio de cliente
  });
});

test('CAR-09 carteira com saldo ilegivel nao e movimentada', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, -5); // so poderia existir por adulteracao

  const r = await carteira.concederBoasVindas({ uid: UID });

  assert.strictEqual(r.efeito, EFEITO.CARTEIRA_ILEGIVEL);
  assert.strictEqual(saldoDe(db, UID), -5); // nao se corrige o que nao se entende
  assert.deepStrictEqual(recibos(db), []);
});

// ===========================================================================
// RESULTADO DA PARTIDA
// ===========================================================================

const vitoria = { matchId: MATCH, uid: UID, motivo: MOTIVO.VITORIA, deltaNominal: POLITICA.vitoria };
const derrota = { matchId: MATCH, uid: UID, motivo: MOTIVO.DERROTA, deltaNominal: POLITICA.derrota };

test('CAR-10 vitoria concede exatamente +15', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  const r = await carteira.aplicarMovimentoDePartida(vitoria);

  assert.strictEqual(r.efeito, EFEITO.LANCADO);
  assert.strictEqual(r.delta, 15);
  assert.strictEqual(saldoDe(db, UID), 115);
});

test('CAR-11 derrota debita exatamente -10', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  const r = await carteira.aplicarMovimentoDePartida(derrota);

  assert.strictEqual(r.efeito, EFEITO.LANCADO);
  assert.strictEqual(r.delta, -10);
  assert.strictEqual(saldoDe(db, UID), 90);
});

test('CAR-12 saldo 6 + derrota termina em 0, e o recibo conta a verdade', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 6);

  const r = await carteira.aplicarMovimentoDePartida(derrota);

  assert.strictEqual(saldoDe(db, UID), 0);
  assert.strictEqual(r.delta, -6);
  const recibo = db.ver(`${COL_LEDGER}/${chaveResultado(MATCH, UID, MOTIVO.DERROTA)}`);
  // Os dois numeros lado a lado: a politica cobrou 10, a carteira so tinha 6.
  assert.strictEqual(recibo.deltaNominal, -10);
  assert.strictEqual(recibo.delta, -6);
  assert.strictEqual(recibo.saldoAntes + recibo.delta, recibo.saldoDepois);
});

test('CAR-13 saldo 0 + derrota continua em 0, e ainda assim fica anotada', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 0);

  const r = await carteira.aplicarMovimentoDePartida(derrota);

  assert.strictEqual(saldoDe(db, UID), 0);
  assert.strictEqual(r.delta, 0);
  // O recibo de delta zero e o que impede a derrota de ficar eternamente
  // pendente de processamento.
  assert.strictEqual(recibos(db).length, 1);
});

test('CAR-14 carteira inexistente + derrota nasce em 0, nunca negativa', async () => {
  const { db, carteira } = montar();

  await carteira.aplicarMovimentoDePartida(derrota);

  assert.strictEqual(saldoDe(db, UID), 0);
});

test('CAR-15 NENHUM saldo de 0 a 60 fica negativo depois de dez derrotas seguidas', async () => {
  for (let inicial = 0; inicial <= 60; inicial += 1) {
    const { db, carteira } = montar();
    comSaldo(db, UID, inicial);
    for (let i = 0; i < 10; i += 1) {
      await carteira.aplicarMovimentoDePartida({ ...derrota, matchId: `m-${i}` });
    }
    const saldo = saldoDe(db, UID);
    assert.ok(saldo >= 0, `saldo inicial ${inicial} terminou em ${saldo}`);
    assert.strictEqual(saldo, Math.max(0, inicial - 100));
  }
});

test('CAR-16 a MESMA vitoria processada duas vezes concede +15 uma unica vez', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  const a = await carteira.aplicarMovimentoDePartida(vitoria);
  const b = await carteira.aplicarMovimentoDePartida(vitoria);
  const c = await carteira.aplicarMovimentoDePartida(vitoria);

  assert.strictEqual(a.efeito, EFEITO.LANCADO);
  assert.strictEqual(b.efeito, EFEITO.JA_LANCADO);
  assert.strictEqual(c.efeito, EFEITO.JA_LANCADO);
  assert.strictEqual(saldoDe(db, UID), 115); // e nao 145
  assert.strictEqual(recibos(db).length, 1);
});

test('CAR-17 a MESMA derrota processada duas vezes debita -10 uma unica vez', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  await carteira.aplicarMovimentoDePartida(derrota);
  const segunda = await carteira.aplicarMovimentoDePartida(derrota);

  assert.strictEqual(segunda.efeito, EFEITO.JA_LANCADO);
  assert.strictEqual(saldoDe(db, UID), 90); // e nao 80
  assert.strictEqual(recibos(db).length, 1);
});

test('CAR-18 duas finalizacoes CONCORRENTES da mesma partida nao duplicam', async () => {
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  const chegou = porta();
  const liberado = porta();
  let primeira = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeira) return;
    primeira = false;
    chegou.abrir();
    await liberado.aberta;
  };

  const pA = carteira.aplicarMovimentoDePartida(vitoria);
  await chegou.aberta;
  const rB = await carteira.aplicarMovimentoDePartida(vitoria);
  liberado.abrir();
  const rA = await pA;

  assert.strictEqual(rB.efeito, EFEITO.LANCADO);
  assert.strictEqual(rA.efeito, EFEITO.JA_LANCADO);
  assert.ok(db.conflitos >= 1, 'a corrida precisa ter sido detectada de verdade');
  assert.strictEqual(saldoDe(db, UID), 115); // +15 uma vez, nao +30
});

test('CAR-19 vitoria e derrota da mesma partida sao movimentos distintos', async () => {
  // Nao acontece com o MESMO jogador na mesma partida, mas a chave precisa
  // separa-los para que um estorno futuro nao colida com o lancamento.
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  await carteira.aplicarMovimentoDePartida(vitoria);
  await carteira.aplicarMovimentoDePartida(derrota);

  assert.strictEqual(saldoDe(db, UID), 105);
  assert.strictEqual(recibos(db).length, 2);
});

// ===========================================================================
// A PARTIDA INTEIRA — do registro server-owned ate a carteira
// ===========================================================================

test('CAR-20 a mesa inteira: o vencedor sobe 15 e o perdedor desce 10', async () => {
  const { db, carteira } = montar();
  comSaldo(db, 'uidA', 50);
  comSaldo(db, 'uidB', 50);

  await liquidar(carteira, MATCH, partidaFinalizada());

  assert.strictEqual(saldoDe(db, 'uidA'), 65);
  assert.strictEqual(saldoDe(db, 'uidB'), 40);
});

test('CAR-21 a mesa inteira reprocessada nao move nada pela segunda vez', async () => {
  const { db, carteira } = montar();
  comSaldo(db, 'uidA', 50);
  comSaldo(db, 'uidB', 50);

  await liquidar(carteira, MATCH, partidaFinalizada());
  const repeticao = await liquidar(carteira, MATCH, partidaFinalizada());

  assert.ok(repeticao.resultados.every((r) => r.efeito === EFEITO.JA_LANCADO));
  assert.strictEqual(saldoDe(db, 'uidA'), 65);
  assert.strictEqual(saldoDe(db, 'uidB'), 40);
  assert.strictEqual(recibos(db).length, 2);
});

test('CAR-22 partida ANULADA nao movimenta carteira nenhuma', async () => {
  const { db, carteira } = montar();
  comSaldo(db, 'uidA', 50);
  comSaldo(db, 'uidB', 50);

  const r = await liquidar(
    carteira,
    MATCH,
    partidaFinalizada({ estado: 'cancelada', motivoEncerramento: 'anulada', ladoVencedor: null })
  );

  assert.strictEqual(r.recusa, 'partida_nao_valeu');
  assert.strictEqual(saldoDe(db, 'uidA'), 50);
  assert.strictEqual(saldoDe(db, 'uidB'), 50);
  assert.deepStrictEqual(recibos(db), []);
});

test('CAR-23 partida NAO CONCLUIDA nao movimenta carteira nenhuma', async () => {
  const { db, carteira } = montar();
  comSaldo(db, 'uidA', 50);
  comSaldo(db, 'uidB', 50);

  for (const estado of ['criada', 'aguardando', 'ativa', 'reconectando']) {
    await liquidar(carteira, MATCH, partidaFinalizada({ estado, ladoVencedor: null }));
  }

  assert.strictEqual(saldoDe(db, 'uidA'), 50);
  assert.strictEqual(saldoDe(db, 'uidB'), 50);
  assert.deepStrictEqual(recibos(db), []);
});

test('CAR-23b TREINAMENTO, CONTRA ROBOS e PRIVADA nao encostam na carteira', async () => {
  // A ponta a ponta da decisao comercial: nao basta `movimentosDoResultado`
  // devolver lista vazia — nenhuma escrita pode chegar ao banco.
  for (const tipo of ['treinamento', 'contra_robos', 'privada']) {
    const { db, carteira } = montar();
    comSaldo(db, 'uidA', 50);
    comSaldo(db, 'uidB', 50);

    const r = await liquidar(carteira, MATCH, partidaFinalizada({ tipo }));

    assert.strictEqual(r.recusa, 'tipo_nao_move_carteira', tipo);
    assert.strictEqual(saldoDe(db, 'uidA'), 50, `${tipo} mexeu no vencedor`);
    assert.strictEqual(saldoDe(db, 'uidB'), 50, `${tipo} mexeu no perdedor`);
    assert.deepStrictEqual(recibos(db), [], `${tipo} deixou recibo`);
    assert.strictEqual(db.commits, 0, `${tipo} abriu transacao`);
  }
});

test('CAR-23c farm por repeticao contra robos rende exatamente zero', async () => {
  // O ataque que a decisao fecha: cem mesas contra bots, todas vencidas.
  const { db, carteira } = montar();
  comSaldo(db, 'uidA', 0);

  for (let i = 0; i < 100; i += 1) {
    await liquidar(
      carteira,
      `match-farm-${i}`,
      partidaFinalizada({
        matchId: `match-farm-${i}`,
        tipo: 'contra_robos',
        participantes: [humano('uidA', 0), humano('uidB', 1)],
      })
    );
  }

  assert.strictEqual(saldoDe(db, 'uidA'), 0);
  assert.deepStrictEqual(recibos(db), []);
});

test('CAR-24 dois gatilhos CONCORRENTES sobre a mesma mesa pagam uma vez so', async () => {
  const { db, carteira } = montar();
  comSaldo(db, 'uidA', 50);
  comSaldo(db, 'uidB', 50);

  // Sem porta: as duas liquidacoes correm entrelacadas de verdade, e o que as
  // separa e o recibo — o mesmo que separa duas entregas at-least-once do
  // Firestore.
  await Promise.all([
    liquidar(carteira, MATCH, partidaFinalizada()),
    liquidar(carteira, MATCH, partidaFinalizada()),
  ]);

  assert.strictEqual(saldoDe(db, 'uidA'), 65);
  assert.strictEqual(saldoDe(db, 'uidB'), 40);
  assert.strictEqual(recibos(db).length, 2);
});

test('CAR-25 boas-vindas e resultado somam na MESMA carteira, com motivos distintos', async () => {
  // A secao 8 da OS: economias distintas podem desembocar na mesma carteira
  // canonica desde que o livro-razao registre origens diferentes.
  const { db, carteira } = montar();

  await carteira.concederBoasVindas({ uid: UID });
  await carteira.aplicarMovimentoDePartida(vitoria);
  await carteira.aplicarMovimentoDePartida({ ...derrota, matchId: 'match-outra' });

  assert.strictEqual(saldoDe(db, UID), 105); // 0 +100 +15 -10
  const motivos = recibos(db)
    .map((c) => db.ver(c).motivo)
    .sort();
  assert.deepStrictEqual(motivos, ['boas_vindas', 'derrota_partida', 'vitoria_partida']);
});

test('CAR-26 chamada mal formada nao escreve nada', async () => {
  const { db, carteira } = montar();

  const semUid = await carteira.concederBoasVindas({ uid: '' });
  const semMatch = await carteira.aplicarMovimentoDePartida({ ...vitoria, matchId: '' });
  const deltaTorto = await carteira.aplicarMovimentoDePartida({ ...vitoria, deltaNominal: 1.5 });

  assert.strictEqual(semUid.efeito, EFEITO.MAL_FORMADO);
  assert.strictEqual(semMatch.efeito, EFEITO.MAL_FORMADO);
  assert.strictEqual(deltaTorto.efeito, EFEITO.MAL_FORMADO);
  assert.deepStrictEqual(db.caminhos(), []);
});

test('CAR-27 ATOMICIDADE: recibo e saldo sao a mesma escrita', async () => {
  // Prova por contagem de commits: um movimento, uma transacao, dois documentos.
  // Nao existe instante em que o saldo subiu e o recibo nao esta anotado.
  const { db, carteira } = montar();

  await carteira.concederBoasVindas({ uid: UID });

  assert.strictEqual(db.commits, 1);
  // `caminhos()` vem ordenado, entao o recibo aparece antes da carteira.
  assert.deepStrictEqual(db.caminhos(), [
    `${COL_LEDGER}/${chaveBoasVindas(UID)}`,
    `${COL_CARTEIRA}/${UID}`,
  ]);
});

test('CAR-28 o credito de billing e o da economia nao se atropelam', async () => {
  // A carteira e a mesma. Se billing creditar entre a leitura e o commit desta
  // transacao, a versao do documento muda e a transacao roda de novo contra o
  // saldo novo — nenhum dos dois creditos se perde.
  const { db, carteira } = montar();
  comSaldo(db, UID, 100);

  const chegou = porta();
  const liberado = porta();
  let primeira = true;
  db.pausarAntesDoCommit = async () => {
    if (!primeira) return;
    primeira = false;
    chegou.abrir();
    await liberado.aberta;
  };

  const pVitoria = carteira.aplicarMovimentoDePartida(vitoria);
  await chegou.aberta;
  // Billing entrega 1.500 fichas de parcela no meio do caminho.
  db.semear(`${COL_CARTEIRA}/${UID}`, { [CAMPO_SALDO]: 1600 });
  liberado.abrir();
  await pVitoria;

  assert.strictEqual(saldoDe(db, UID), 1615); // 1600 + 15, e nao 115
  assert.ok(db.conflitos >= 1);
});
