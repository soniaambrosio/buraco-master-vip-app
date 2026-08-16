// economia.test.js — prova as regras da ECONOMIA BASICA do jogador.
//
// O QUE ESTE ARQUIVO PROVA, e que nenhum teste em `node --test` consegue provar:
// quem escreve o livro-razao da economia e quem consegue le-lo.
//
// A politica, o piso e a idempotencia estao cobertos em
// `functions-economia/test/`, contra um Firestore falso. Aquela suite responde
// "dado este documento, o que acontece". Ela nao responde a pergunta que decide
// se a economia vale alguma coisa:
//
//     o proprio jogador consegue escrever esses documentos?
//
// Duas respostas erradas custariam dinheiro em direcoes opostas:
//
//   1. se ele criar `economiaLedger/boas_vindas|{uid}` a mao, o bonus fica
//      bloqueado — mas se ele APAGAR o recibo depois de receber, ganha outros
//      100 na chamada seguinte;
//   2. se ele criar `partida|{matchId}|{uid}|derrota_partida` antes do gatilho
//      passar, CANCELA o proprio debito de derrota: o gatilho encontra o recibo
//      e nao debita. Fraude sem precisar mentir sobre o resultado.
//
// E ainda a pergunta que ja valia antes desta OS e continua valendo:
//
//     o proprio jogador consegue escrever o saldo dele?
//
// `usuarios/{uid}.fichas` e campo de servidor desde o bloco 2/3 e esta OS nao o
// tocou. ECON-10 e ECON-11 sao regressao: eles caem se alguem afrouxar aquele
// bloco achando que a economia nova precisava de espaco la.
//
// Uso:
//   cd firebase/testes && npm install
//   npm run emulador-economia
//
// Numa maquina sem Java no PATH mas com Android Studio instalado:
//   JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npm run emulador-economia

'use strict';

const fs = require('fs');
const path = require('path');
const { test, before, after, describe } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const { doc, collection, query, where, getDoc, getDocs, setDoc, updateDoc, deleteDoc } =
  require('firebase/firestore');

const PROJETO = process.env.GCLOUD_PROJECT || 'buraco-master-vip-testes';

const DONO = 'uidJogadora';
const OUTRO = 'uidCurioso';
const ADMIN = 'uidAdmin';

const MATCH = 'match-mesa-7';
const CHAVE_BOAS_VINDAS = `boas_vindas|${DONO}`;
const CHAVE_DERROTA = `partida|${MATCH}|${DONO}|derrota_partida`;
const CHAVE_VITORIA_ALHEIA = `partida|${MATCH}|${OUTRO}|vitoria_partida`;

let ambiente;

/** Um recibo como `economiaStore.js` o grava. */
function recibo(extra = {}) {
  return {
    chaveIdempotencia: CHAVE_BOAS_VINDAS,
    uid: DONO,
    motivo: 'boas_vindas',
    deltaNominal: 100,
    delta: 100,
    saldoAntes: 0,
    saldoDepois: 100,
    matchId: null,
    registradoEm: '2026-08-13T12:00:00.000Z',
    ...extra,
  };
}

before(async () => {
  ambiente = await initializeTestEnvironment({
    projectId: PROJETO,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });

  // Semeia como o backend semearia: com as regras desligadas, que e exatamente
  // o privilegio que o Admin SDK tem em producao.
  await ambiente.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await setDoc(doc(db, `economiaLedger/${CHAVE_BOAS_VINDAS}`), recibo());
    await setDoc(
      doc(db, `economiaLedger/${CHAVE_DERROTA}`),
      recibo({
        chaveIdempotencia: CHAVE_DERROTA,
        motivo: 'derrota_partida',
        deltaNominal: -10,
        delta: -10,
        saldoAntes: 100,
        saldoDepois: 90,
        matchId: MATCH,
      })
    );
    await setDoc(
      doc(db, `economiaLedger/${CHAVE_VITORIA_ALHEIA}`),
      recibo({
        chaveIdempotencia: CHAVE_VITORIA_ALHEIA,
        uid: OUTRO,
        motivo: 'vitoria_partida',
        deltaNominal: 15,
        delta: 15,
        saldoAntes: 0,
        saldoDepois: 15,
        matchId: MATCH,
      })
    );

    // A carteira canonica, como billing a deixa.
    await setDoc(doc(db, `usuarios/${DONO}`), {
      apelido: 'Sonia',
      fichas: 90,
      fichasAtualizadoEm: '2026-08-13T12:00:00.000Z',
    });
  });
});

after(async () => {
  if (ambiente) await ambiente.cleanup();
});

const comoDono = () => ambiente.authenticatedContext(DONO).firestore();
const comoOutro = () => ambiente.authenticatedContext(OUTRO).firestore();
const comoAdmin = () => ambiente.authenticatedContext(ADMIN, { admin: true }).firestore();
const comoAnonimo = () => ambiente.unauthenticatedContext().firestore();

describe('economiaLedger — o extrato do jogador', () => {
  test('ECON-01 o jogador le o proprio recibo', async () => {
    await assertSucceeds(getDoc(doc(comoDono(), `economiaLedger/${CHAVE_BOAS_VINDAS}`)));
    await assertSucceeds(getDoc(doc(comoDono(), `economiaLedger/${CHAVE_DERROTA}`)));
  });

  test('ECON-02 o jogador NAO le o recibo de terceiro', async () => {
    // A chave carrega o `matchId`, entao um adversario de mesa consegue montar o
    // caminho do recibo alheio sem adivinhar nada. E o `uid` no corpo que barra.
    await assertFails(getDoc(doc(comoOutro(), `economiaLedger/${CHAVE_DERROTA}`)));
    await assertFails(getDoc(doc(comoDono(), `economiaLedger/${CHAVE_VITORIA_ALHEIA}`)));
  });

  test('ECON-03 a colecao nao e varrivel: nao ha `list` para ninguem', async () => {
    // Sem `allow list: if false`, o `ehAdmin()` do predicado — que nao depende
    // de documento nenhum — autorizaria a varredura da colecao INTEIRA, e um
    // `getDocs` traria a economia do jogo toda. Foi o que este teste pegou.
    await assertFails(getDocs(collection(comoDono(), 'economiaLedger')));
    await assertFails(getDocs(collection(comoAdmin(), 'economiaLedger')));
    // Nem filtrando pelo proprio uid: o extrato paginado sai por Function.
    await assertFails(
      getDocs(query(collection(comoDono(), 'economiaLedger'), where('uid', '==', DONO)))
    );
  });

  test('ECON-04 o admin le qualquer recibo', async () => {
    await assertSucceeds(getDoc(doc(comoAdmin(), `economiaLedger/${CHAVE_VITORIA_ALHEIA}`)));
  });

  test('ECON-05 anonimo nao le nada', async () => {
    await assertFails(getDoc(doc(comoAnonimo(), `economiaLedger/${CHAVE_BOAS_VINDAS}`)));
  });

  test('ECON-06 o jogador NAO planta recibo de derrota para cancelar o proprio debito', async () => {
    // O ataque mais barato contra esta OS: o recibo e a barreira de
    // idempotencia, entao criar um antes do gatilho passar cancela o debito.
    await assertFails(
      setDoc(doc(comoDono(), `economiaLedger/partida|${MATCH}|${DONO}|derrota_partida-2`), {
        uid: DONO,
        motivo: 'derrota_partida',
        delta: 0,
      })
    );
  });

  test('ECON-07 o jogador NAO apaga o recibo de boas-vindas para receber de novo', async () => {
    await assertFails(deleteDoc(doc(comoDono(), `economiaLedger/${CHAVE_BOAS_VINDAS}`)));
  });

  test('ECON-08 o jogador NAO reescreve o proprio saldo pelo recibo', async () => {
    await assertFails(
      updateDoc(doc(comoDono(), `economiaLedger/${CHAVE_DERROTA}`), {
        delta: 999999,
        saldoDepois: 999999,
      })
    );
  });

  test('ECON-09 nem o admin escreve pelo cliente — a trilha nao se planta nem se limpa', async () => {
    await assertFails(
      setDoc(doc(comoAdmin(), `economiaLedger/partida|${MATCH}|${ADMIN}|vitoria_partida`), recibo())
    );
    await assertFails(deleteDoc(doc(comoAdmin(), `economiaLedger/${CHAVE_DERROTA}`)));
  });
});

describe('usuarios/{uid} — REGRESSAO: a carteira continua sendo do servidor', () => {
  test('ECON-10 o jogador nao escreve `fichas` no proprio perfil', async () => {
    // Esta OS nao tocou o bloco 2/3. O teste existe para cair se alguem o
    // afrouxar achando que a economia nova precisava de espaco la.
    await assertFails(updateDoc(doc(comoDono(), `usuarios/${DONO}`), { fichas: 999999 }));
    await assertFails(
      updateDoc(doc(comoDono(), `usuarios/${DONO}`), {
        fichas: 999999,
        fichasAtualizadoEm: '2026-08-13T12:00:00.000Z',
      })
    );
    // Nem escondido no meio de uma edicao legitima de campo cosmetico.
    await assertFails(
      updateDoc(doc(comoDono(), `usuarios/${DONO}`), { apelido: 'Nova', fichas: 999999 })
    );
  });

  test('ECON-11 o jogador continua editando os campos cosmeticos dele', async () => {
    await assertSucceeds(updateDoc(doc(comoDono(), `usuarios/${DONO}`), { apelido: 'Rainha' }));
  });

  test('ECON-12 o jogador nao le a carteira de terceiro', async () => {
    await assertFails(getDoc(doc(comoOutro(), `usuarios/${DONO}`)));
  });
});
