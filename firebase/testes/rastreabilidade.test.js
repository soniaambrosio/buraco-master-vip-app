// rastreabilidade.test.js — prova o BLOCO 4/4 do firestore.rules contra o
// emulador (OS Rastreabilidade, secoes 24 e 34).
//
// A outra metade da secao 34 vive no dominio Dart e esta em
// app/test/rastreabilidade/seguranca_test.dart. A divisao e clara:
//
//   dominio  -> o que uma VALIDACAO decide (envelope, autoridade, divergencia)
//   rules    -> o que o BANCO permite (quem escreve, quem le, quem apaga)
//
// Cobre, um caso por afirmacao da secao 24:
//   - o cliente NAO cria partida finalizada falsa;
//   - o cliente NAO edita resultado, participantes nem tipo de partida;
//   - o cliente NAO apaga partida;
//   - o cliente NAO cria nem le evento auditavel;
//   - o cliente NAO aumenta a propria pontuacao nem diminui a de terceiros;
//   - o cliente NAO apaga a trilha competitiva;
//   - o cliente le o PROPRIO lancamento e nao o alheio;
//   - o cliente NAO edita nem apaga o proprio historico;
//   - o cliente le o PROPRIO historico e nao o alheio;
//   - o cliente NAO le nem cria sinal antifraude;
//   - o admin le o registro tecnico e os sinais, mas nao escreve por aqui.
//
// Uso:
//   cd firebase/testes && npm install
//   firebase emulators:exec --only firestore "npm run test:rastreabilidade"

'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('node:assert/strict');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs,
} = require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const DONO = 'uid_dono';
const ALHEIO = 'uid_alheio';
const ADMIN = 'uid_admin';
const MATCH = 'match-f1-mesa-1';
const CHAVE_LEDGER = `${MATCH}|${DONO}|resultado_de_partida`;
const CHAVE_LEDGER_ALHEIO = `${MATCH}|${ALHEIO}|resultado_de_partida`;
const CHAVE_SINAL = `${MATCH}|mesma_dupla_recorrente|${DONO}`;

let ambiente;

/// Registro tecnico minimo, no formato que `RegistroDePartida.toJson()` produz.
const REGISTRO = {
  matchId: MATCH,
  estado: 'finalizada',
  tipo: 'publica_ranqueada',
  ladoVencedor: 'nos',
  userIdsCompetidores: [DONO, ALHEIO],
  impressaoEstado: 'abc123',
  encerradaEm: '2026-08-11T16:00:00.000Z',
};

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Semeia o que so o backend escreveria. `withSecurityRulesDisabled` e o
  // equivalente do Admin SDK aqui: e assim que a producao popula estas colecoes.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'matches', MATCH), REGISTRO);
    await setDoc(doc(db, 'matches', MATCH, 'events', `${MATCH}:resultado:v9`), {
      eventId: `${MATCH}:resultado:v9`,
      matchId: MATCH,
      tipo: 'resultado',
      emServidor: '2026-08-11T16:00:00.000Z',
    });
    await setDoc(doc(db, 'rankingLedger', CHAVE_LEDGER), {
      chaveIdempotencia: CHAVE_LEDGER,
      matchId: MATCH,
      userId: DONO,
      rankingBefore: 100,
      rankingDelta: 25,
      rankingAfter: 125,
    });
    await setDoc(doc(db, 'rankingLedger', CHAVE_LEDGER_ALHEIO), {
      chaveIdempotencia: CHAVE_LEDGER_ALHEIO,
      matchId: MATCH,
      userId: ALHEIO,
      rankingBefore: 300,
      rankingDelta: -15,
      rankingAfter: 285,
    });
    await setDoc(doc(db, 'fraudSignals', CHAVE_SINAL), {
      chaveIdempotencia: CHAVE_SINAL,
      matchId: MATCH,
      suspectedPattern: 'mesma_dupla_recorrente',
      alvos: [DONO, ALHEIO],
      geraPunicao: false,
    });
    await setDoc(doc(db, 'users', DONO, 'matchHistory', MATCH), {
      matchId: MATCH,
      resultado: 'vitoria',
      rankingDelta: 25,
    });
    await setDoc(doc(db, 'users', ALHEIO, 'matchHistory', MATCH), {
      matchId: MATCH,
      resultado: 'derrota',
      rankingDelta: -15,
    });
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoAlheio = () => ambiente.authenticatedContext(ALHEIO).firestore();
const comoAdmin = () =>
  ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const semLogin = () => ambiente.unauthenticatedContext().firestore();

describe('matches — registro tecnico da partida (secoes 14 e 24)', () => {
  test('o jogador NAO cria uma partida finalizada falsa', async () => {
    const db = comoDono();
    await assertFails(
      setDoc(doc(db, 'matches', 'match-inventada-0001'), {
        ...REGISTRO,
        matchId: 'match-inventada-0001',
        userIdsCompetidores: [DONO],
      }),
    );
  });

  test('o jogador NAO edita o resultado de uma partida existente', async () => {
    const db = comoDono();
    await assertFails(
      updateDoc(doc(db, 'matches', MATCH), { ladoVencedor: 'eles' }),
    );
  });

  test('o jogador NAO se marca vencedor nem troca o tipo da partida', async () => {
    const db = comoDono();
    await assertFails(updateDoc(doc(db, 'matches', MATCH), { vencedor: DONO }));
    await assertFails(
      updateDoc(doc(db, 'matches', MATCH), { tipo: 'publica_ranqueada' }),
    );
  });

  test('o jogador NAO altera a lista de participantes', async () => {
    const db = comoDono();
    await assertFails(
      updateDoc(doc(db, 'matches', MATCH), {
        userIdsCompetidores: [DONO, 'uid_plantado'],
      }),
    );
  });

  test('o jogador NAO apaga a partida', async () => {
    await assertFails(deleteDoc(doc(comoDono(), 'matches', MATCH)));
  });

  test('o jogador NAO le o registro tecnico — nem o da propria partida', async () => {
    // Secao 14: conhecer o matchId nao da acesso administrativo. O que ele le e
    // a projecao em users/{uid}/matchHistory.
    await assertFails(getDoc(doc(comoDono(), 'matches', MATCH)));
    await assertFails(getDoc(doc(comoAlheio(), 'matches', MATCH)));
  });

  test('o anonimo NAO le nem escreve', async () => {
    await assertFails(getDoc(doc(semLogin(), 'matches', MATCH)));
    await assertFails(
      setDoc(doc(semLogin(), 'matches', 'match-anonima-0001'), REGISTRO),
    );
  });

  test('o admin le o registro tecnico', async () => {
    const snap = await assertSucceeds(getDoc(doc(comoAdmin(), 'matches', MATCH)));
    assert.equal(snap.data().ladoVencedor, 'nos');
  });

  test('nem o admin escreve pelo cliente — a trilha nao se planta nem se limpa',
    async () => {
      const db = comoAdmin();
      await assertFails(updateDoc(doc(db, 'matches', MATCH), { ladoVencedor: 'eles' }));
      await assertFails(deleteDoc(doc(db, 'matches', MATCH)));
    });
});

describe('matches/{id}/events — trilha auditavel (secao 8)', () => {
  test('o jogador NAO cria evento administrativo', async () => {
    const db = comoDono();
    await assertFails(
      setDoc(doc(db, 'matches', MATCH, 'events', 'evento-plantado'), {
        eventId: 'evento-plantado',
        matchId: MATCH,
        tipo: 'resultado',
      }),
    );
  });

  test('o jogador NAO le nem apaga a trilha', async () => {
    const db = comoDono();
    await assertFails(getDocs(collection(db, 'matches', MATCH, 'events')));
    await assertFails(
      deleteDoc(doc(db, 'matches', MATCH, 'events', `${MATCH}:resultado:v9`)),
    );
  });

  test('o admin le a trilha', async () => {
    const snap = await assertSucceeds(
      getDocs(collection(comoAdmin(), 'matches', MATCH, 'events')),
    );
    assert.equal(snap.size, 1);
  });
});

describe('rankingLedger — trilha competitiva (secoes 12, 13 e 24)', () => {
  test('o jogador le o PROPRIO lancamento', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(comoDono(), 'rankingLedger', CHAVE_LEDGER)),
    );
    assert.equal(snap.data().rankingAfter, 125);
    // E a soma que a auditoria exige fecha no que esta gravado.
    assert.equal(
      snap.data().rankingBefore + snap.data().rankingDelta,
      snap.data().rankingAfter,
    );
  });

  test('o jogador NAO le o lancamento de terceiros', async () => {
    await assertFails(
      getDoc(doc(comoDono(), 'rankingLedger', CHAVE_LEDGER_ALHEIO)),
    );
  });

  test('o jogador NAO aumenta a propria pontuacao', async () => {
    const db = comoDono();
    await assertFails(
      updateDoc(doc(db, 'rankingLedger', CHAVE_LEDGER), { rankingAfter: 9999 }),
    );
    await assertFails(
      setDoc(doc(db, 'rankingLedger', `${MATCH}|${DONO}|correcao_administrativa`), {
        chaveIdempotencia: `${MATCH}|${DONO}|correcao_administrativa`,
        matchId: MATCH,
        userId: DONO,
        rankingBefore: 125,
        rankingDelta: 5000,
        rankingAfter: 5125,
      }),
    );
  });

  test('o jogador NAO diminui a pontuacao de terceiros', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), 'rankingLedger', CHAVE_LEDGER_ALHEIO), {
        rankingAfter: 0,
      }),
    );
  });

  test('o jogador NAO apaga a propria trilha competitiva', async () => {
    await assertFails(deleteDoc(doc(comoDono(), 'rankingLedger', CHAVE_LEDGER)));
  });

  test('o admin le qualquer lancamento', async () => {
    await assertSucceeds(
      getDoc(doc(comoAdmin(), 'rankingLedger', CHAVE_LEDGER_ALHEIO)),
    );
  });
});

describe('users/{uid}/matchHistory — historico do jogador (secoes 11 e 34)', () => {
  test('o jogador le o PROPRIO historico', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(comoDono(), 'users', DONO, 'matchHistory', MATCH)),
    );
    assert.equal(snap.data().resultado, 'vitoria');
  });

  test('o jogador NAO le o historico alheio', async () => {
    await assertFails(
      getDoc(doc(comoDono(), 'users', ALHEIO, 'matchHistory', MATCH)),
    );
    await assertFails(
      getDocs(collection(comoDono(), 'users', ALHEIO, 'matchHistory')),
    );
  });

  test('o jogador NAO cria entrada de historico competitivo falsa', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'users', DONO, 'matchHistory', 'match-inventada-0001'), {
        matchId: 'match-inventada-0001',
        resultado: 'vitoria',
        rankingDelta: 500,
      }),
    );
  });

  test('o jogador NAO edita nem apaga o proprio historico', async () => {
    const db = comoDono();
    const ref = doc(db, 'users', DONO, 'matchHistory', MATCH);
    await assertFails(updateDoc(ref, { resultado: 'vitoria', rankingDelta: 999 }));
    await assertFails(deleteDoc(ref));
  });

  test('o admin le o historico de qualquer jogador', async () => {
    await assertSucceeds(
      getDoc(doc(comoAdmin(), 'users', ALHEIO, 'matchHistory', MATCH)),
    );
  });
});

describe('fraudSignals — sinais antifraude (secoes 16, 17 e 35)', () => {
  test('o jogador NAO cria flag administrativa contra terceiros', async () => {
    const chave = `${MATCH}|abandono_ao_perder|${ALHEIO}`;
    await assertFails(
      setDoc(doc(comoDono(), 'fraudSignals', chave), {
        chaveIdempotencia: chave,
        matchId: MATCH,
        suspectedPattern: 'abandono_ao_perder',
        alvos: [ALHEIO],
      }),
    );
  });

  test('o jogador NAO le sinais — nem os que citam ele proprio', async () => {
    // Restricao que protege o alvo: sinal e suspeita, e expo-la ao proprio
    // citado transformaria observacao estatistica em acusacao.
    await assertFails(getDoc(doc(comoDono(), 'fraudSignals', CHAVE_SINAL)));
    await assertFails(getDocs(collection(comoDono(), 'fraudSignals')));
  });

  test('o admin le o sinal, e o documento diz sozinho que nao pune', async () => {
    const snap = await assertSucceeds(
      getDoc(doc(comoAdmin(), 'fraudSignals', CHAVE_SINAL)),
    );
    assert.equal(snap.data().geraPunicao, false);
    assert.equal(snap.data().matchId, MATCH);
    assert.ok(snap.data().suspectedPattern);
  });

  test('nem o admin planta ou apaga sinal pelo cliente', async () => {
    const db = comoAdmin();
    await assertFails(
      updateDoc(doc(db, 'fraudSignals', CHAVE_SINAL), { intensidade: 'alta' }),
    );
    await assertFails(deleteDoc(doc(db, 'fraudSignals', CHAVE_SINAL)));
  });
});

describe('negacao padrao — colecao nao declarada continua fechada', () => {
  test('uma colecao vizinha inventada e negada', async () => {
    await assertFails(
      setDoc(doc(comoDono(), 'matchesFalsas', 'x'), { matchId: 'x' }),
    );
    await assertFails(getDoc(doc(comoAdmin(), 'rankingLedgerAntigo', 'x')));
  });
});
