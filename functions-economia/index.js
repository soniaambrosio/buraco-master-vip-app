/**
 * index.js — as Cloud Functions da ECONOMIA BASICA do jogador.
 *
 * TRES MOVIMENTOS, DOIS GATILHOS
 *
 *   garantirBonusDeBoasVindas   callable  — +100, uma vez por conta
 *   aoRegistrarPartida          gatilho   — +15 / -10 por resultado
 *   reprocessarResultadoDaPartida callable (admin) — a saida de emergencia
 *
 * DIVISAO DE TRABALHO, e ela e a coisa mais importante deste arquivo:
 *
 *   QUEM DECIDE  -> `economia.js`. Politica, elegibilidade, piso e as chaves de
 *                   idempotencia. Puro, sem Firestore, coberto por `node --test`.
 *   QUEM ESCREVE -> `economiaStore.js`. A transacao onde recibo e saldo sao a
 *                   mesma escrita.
 *   QUEM EXECUTA -> este arquivo. Autenticacao, gatilho, leitura do registro e
 *                   observabilidade. Nenhuma regra de negocio mora aqui.
 *
 * POR QUE O RESULTADO DA PARTIDA E UM GATILHO, E NAO UM CALLABLE
 *
 * Porque a secao 6 da OS exige que o servidor seja a autoridade, e um gatilho de
 * Firestore e a forma mais forte disso que existe: o cliente nao consegue
 * invoca-lo, nao consegue deixar de invoca-lo, e nao tem por onde passar
 * parametro. O que ele observa e `matches/{matchId}` — documento que
 * `firestore.rules` nega a toda escrita de cliente e que so
 * `registrarEncerramentoPartida` (em `functions/src/rastreabilidade.ts`, exigindo
 * o claim `motorDePartidas`) escreve.
 *
 * Consequencia pratica: nao existe caminho pelo qual um aplicativo modificado
 * declare que venceu para receber 15, nem pelo qual ele recuse o debito
 * declarando outro resultado. Ele nao participa da conversa.
 *
 * E POR QUE ESTE CODEBASE E SEPARADO
 *
 * Mesma razao que `firebase.json` da para os outros quatro: sao unidades de
 * implantacao independentes. Um deploy da economia basica nao pode derrubar a
 * validacao de compra, e uma correcao no RTDN nao pode mexer no que o jogador
 * ganha por vencer. A carteira e a mesma (`usuarios/{uid}.fichas`); o codigo que
 * a move por motivos diferentes nao precisa ser.
 */

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const { POLITICA, movimentosDoResultado } = require('./economia');
const { EFEITO, criarCarteira } = require('./economiaStore');

initializeApp();

/**
 * `southamerica-east1` acompanha `functions/` (torneios e rastreabilidade), e
 * nao `us-central1` de billing, por uma razao tecnica e nao estetica: o gatilho
 * abaixo observa a mesma instancia de Firestore que `aoConcluirEdicao` ja
 * observa daquela regiao, e gatilho de Firestore precisa acompanhar a regiao do
 * banco.
 */
const REGIAO = 'southamerica-east1';

/**
 * Dependencias montadas na primeira chamada, e nao na carga do modulo.
 *
 * `getFirestore()` na carga rodaria em todo cold start de toda funcao deste
 * codebase, inclusive nas que nao tocam o banco. Mesmo padrao de
 * `functions-billing/index.js`.
 */
let _carteira = null;
function carteira() {
  if (!_carteira) {
    _carteira = criarCarteira({
      db: getFirestore(),
      carimbo: () => FieldValue.serverTimestamp(),
    });
  }
  return _carteira;
}

// ===========================================================================
// BOAS-VINDAS — +100, uma vez por conta
// ===========================================================================

/**
 * Garante que a conta ja recebeu o bonus de boas-vindas.
 *
 * IDEMPOTENTE POR DESENHO, e por isso o nome e "garantir" e nao "conceder": o
 * aplicativo pode chamar isto a cada abertura, a cada login e depois de cada
 * reinstalacao. Chamar de novo custa uma leitura e devolve `concedido: false`.
 * Foi feito assim de proposito — um cliente que precisa LEMBRAR de chamar so uma
 * vez e um cliente em que a corretude depende do cliente.
 *
 * NAO ACEITA NENHUM PARAMETRO. O `request.data` inteiro e ignorado: nao ha por
 * onde informar valor, saldo, ou um booleano dizendo "ainda nao recebi". A
 * identidade sai do token do Firebase Auth, ja verificado pelo runtime do
 * callable.
 *
 * SEM `enforceAppCheck`, acompanhando `validarCompraPlay` — que e o outro
 * callable de dinheiro deste projeto — e nao os callables de torneio. O motivo:
 * `firebase_app_check` esta declarado no `pubspec.yaml` do aplicativo mas nunca
 * e inicializado, entao exigi-lo aqui recusaria todo jogador real. A troca e
 * aceitavel porque esta funcao nao tem entrada a proteger: o pior que um
 * chamador hostil consegue e pedir de novo o bonus de uma conta que ele ja
 * autenticou, e a resposta e `false`.
 */
exports.garantirBonusDeBoasVindas = onCall({ region: REGIAO }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Entre na sua conta para receber o bonus.');
  }

  const r = await carteira().concederBoasVindas({ uid });

  if (r.efeito === EFEITO.CARTEIRA_ILEGIVEL) {
    // Nao se move o que nao se entende. Alto no log porque significa que alguem
    // gravou lixo no campo `fichas` de um jogador.
    console.error('[economia] carteira ilegivel no bonus de boas-vindas', { uid });
    throw new HttpsError('failed-precondition', 'Nao foi possivel ler seu saldo.');
  }
  if (r.efeito === EFEITO.MAL_FORMADO) {
    throw new HttpsError('internal', 'Movimento mal formado.');
  }

  const concedido = r.efeito === EFEITO.LANCADO;
  if (concedido) {
    console.info('[economia] bonus de boas-vindas concedido', {
      uid,
      valor: r.delta,
      saldo: r.depois,
    });
  }

  return {
    concedido,
    // Sempre o valor da politica, tenha sido creditado agora ou nao: o cliente
    // usa isto para dizer "voce ja recebeu suas 100 fichas", e um zero na
    // segunda chamada leria como se o bonus nao existisse.
    valor: POLITICA.boasVindas,
  };
});

// ===========================================================================
// RESULTADO DA PARTIDA — +15 por vitoria, -10 por derrota
// ===========================================================================

/**
 * Percorre os movimentos que a partida deve e aplica cada um.
 *
 * Fora dos gatilhos porque os DOIS caminhos (o automatico e o de reparo
 * administrativo) usam este mesmo corpo. Um segundo caminho com regra propria
 * seria a maneira mais barata de as duas divergirem.
 */
async function liquidarResultado(matchId, registro, origem) {
  const { movimentos, recusa } = movimentosDoResultado(registro);

  if (recusa) {
    // Nao e erro: a maioria destas recusas descreve partidas que legitimamente
    // nao pagam. Fica no log porque "nao movimentou" e uma resposta, e uma
    // varredura silenciosa se leria como "movimentou tudo".
    console.info('[economia] partida nao movimenta carteira', { matchId, recusa, origem });
    return { aplicados: 0, repetidos: 0, recusa, movimentos: 0 };
  }

  let aplicados = 0;
  let repetidos = 0;

  for (const m of movimentos) {
    try {
      const r = await carteira().aplicarMovimentoDePartida({
        matchId,
        uid: m.uid,
        motivo: m.motivo,
        deltaNominal: m.deltaNominal,
      });
      if (r.efeito === EFEITO.LANCADO) aplicados += 1;
      else if (r.efeito === EFEITO.JA_LANCADO) repetidos += 1;
      else console.error('[economia] movimento recusado', { matchId, efeito: r.efeito });
    } catch (e) {
      // Um jogador problematico nao trava os outros da mesma mesa: cada
      // movimento tem recibo proprio, entao um reprocessamento posterior
      // completa o que faltou sem repetir o que ja saiu.
      console.error('[economia] falha ao aplicar movimento', e.message, { matchId });
    }
  }

  console.info('[economia] resultado economico da partida', {
    matchId,
    origem,
    movimentos: movimentos.length,
    aplicados,
    repetidos,
  });
  return { aplicados, repetidos, recusa: null, movimentos: movimentos.length };
}

/**
 * Aplica o resultado economico assim que a partida e registrada.
 *
 * `onDocumentWritten`, e nao `onDocumentCreated`: hoje `registrarEncerramentoPartida`
 * grava o documento ja em estado terminal, num `set` unico, e `onCreated`
 * bastaria. Mas o dia em que a partida passar a ser registrada viva e atualizada
 * no encerramento — que e o grafo de estados que `EstadoDaPartida.transicoes`
 * descreve — um gatilho de criacao pararia de pagar em silencio. `onWritten`
 * cobre os dois desenhos, e o custo de disparar em escritas nao-terminais e uma
 * leitura que devolve `partida_nao_valeu` e nao escreve nada.
 *
 * SEGURO CONTRA REPETICAO por construcao dupla: o Firestore pode entregar o
 * mesmo evento mais de uma vez (garantia at-least-once), e cada movimento tem
 * recibo determinado. O segundo disparo encontra os recibos e nao credita.
 */
exports.aoRegistrarPartida = onDocumentWritten(
  { document: 'matches/{matchId}', region: REGIAO },
  async (event) => {
    const depois = event.data && event.data.after;
    if (!depois || !depois.exists) return; // exclusao de documento nao paga nada
    await liquidarResultado(event.params.matchId, depois.data(), 'gatilho');
  }
);

/**
 * Reprocessa o resultado economico de UMA partida. So admin.
 *
 * A saida de emergencia do desenho, no mesmo espirito de
 * `reconciliarEntitlementDoJogador` no billing: gatilho que falhou por
 * indisponibilidade momentanea, partida registrada antes deste codebase existir,
 * divergencia relatada pelo suporte.
 *
 * NAO ACEITA RESULTADO, so o `matchId`. O registro e relido do Firestore e a
 * decisao sai dele — um admin tambem nao escolhe quem venceu. E, como tudo aqui
 * passa pelos mesmos recibos, mandar reprocessar uma partida ja liquidada e
 * inofensivo: devolve tudo como `repetidos`.
 */
exports.reprocessarResultadoDaPartida = onCall({ region: REGIAO }, async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Operacao restrita a administracao.');
  }
  const matchId = request.data && request.data.matchId;
  if (typeof matchId !== 'string' || matchId.length === 0) {
    throw new HttpsError('invalid-argument', 'matchId e obrigatorio.');
  }

  const doc = await getFirestore().collection('matches').doc(matchId).get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'partida nao encontrada.');
  }

  return liquidarResultado(matchId, doc.data(), 'reprocessamento');
});
