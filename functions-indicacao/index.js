/** Cloud Functions da indicação: vínculo e recompensa autoritativa. */

'use strict';

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');

const { avaliarPartida, normalizarCodigoPublico, RECUSA } = require('./politica');
const { criarStore } = require('./store');

initializeApp();

const REGIAO = 'southamerica-east1';
const opcoesCliente = {
  region: REGIAO,
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
};

let _store;
function store() {
  if (!_store) {
    _store = criarStore({
      db: getFirestore(),
      carimbo: () => FieldValue.serverTimestamp(),
      agora: () => new Date(),
    });
  }
  return _store;
}

function uidAutenticado(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Entre na sua conta.');
  return uid;
}

/** Vincula o convidado ao indicador antes da primeira partida válida. */
exports.registrarIndicacao = onCall(opcoesCliente, async (request) => {
  const inviteeUid = uidAutenticado(request);
  const codigo = normalizarCodigoPublico(request.data && request.data.codigo);
  if (!codigo) {
    throw new HttpsError('invalid-argument', 'codigo é obrigatório.');
  }

  // A normalização estrutural continua pertencendo ao social. Aqui só se usa
  // o índice canônico e uma resposta uniforme para código ausente/inexistente.
  const indice = await getFirestore().collection('publicIdIndex').doc(codigo).get();
  const referrerUid = indice.exists && indice.data() && indice.data().uid;
  if (typeof referrerUid !== 'string' || referrerUid.length === 0) {
    throw new HttpsError('not-found', 'Código não encontrado.');
  }

  const r = await store().vincular({
    inviteeUid,
    referrerUid,
    referrerPublicId: codigo,
  });
  if (!r.vinculada) {
    const codigoErro = r.recusa === RECUSA.AUTO_INDICACAO
      ? 'invalid-argument' : 'failed-precondition';
    throw new HttpsError(codigoErro, r.recusa, { recusa: r.recusa });
  }
  return { vinculada: true };
});

/**
 * Marca a primeira partida pública humana e concede 500 + 500, uma vez.
 * O cliente não chama esta função e não escolhe vencedor, valor ou matchId.
 */
exports.aoRegistrarPrimeiraPartidaIndicada = onDocumentWritten(
  { document: 'matches/{matchId}', region: REGIAO },
  async (event) => {
    const depois = event.data && event.data.after;
    if (!depois || !depois.exists) return;
    const avaliacao = avaliarPartida(depois.data());
    if (!avaliacao.elegivel) return;
    for (const inviteeUid of avaliacao.uids) {
      await store().registrarPrimeiraPartida({
        matchId: event.params.matchId,
        inviteeUid,
        encerradaEm: depois.data().encerradaEm,
      });
    }
  }
);
