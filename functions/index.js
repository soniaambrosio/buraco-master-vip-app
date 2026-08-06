/**
 * validarCompraPlay — validacao server-side de compras do Google Play.
 *
 * POR QUE ISTO EXISTE
 * O retorno de compra da Play Store chega dentro do aparelho do jogador, e
 * aparelho de jogador nao e ambiente confiavel: um dispositivo com root ou um
 * app de "compra gratis" consegue forjar um retorno de sucesso. O que NAO da
 * para forjar e a resposta da Google Play Developer API, porque ela exige a
 * credencial de uma conta de servico — que vive aqui e nunca sai daqui.
 *
 * Por isso o aplicativo nao concede nada. Ele manda o `purchaseToken`, esta
 * funcao pergunta a Google se a compra e real, e SO ENTAO grava a concessao no
 * Firestore. O app descobre o que ganhou lendo o Firestore depois.
 *
 * IDEMPOTENCIA
 * A Play Store reentrega compras (troca de aparelho, app fechado no meio da
 * validacao, reinstalacao). Cada token e registrado numa transacao antes de
 * qualquer credito, entao a segunda entrega devolve `jaProcessada: true` e nao
 * credita de novo.
 *
 * ESTADO ATUAL
 * O mapa de produtos vive no Firestore (`configuracao/billing`) e esta vazio
 * ate a Play Console liberar a area de produtos. Sem produto declarado, a
 * funcao recusa toda compra — que e o comportamento correto: melhor recusar do
 * que conceder algo que ninguem definiu.
 */

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { google } = require('googleapis');
const crypto = require('crypto');

initializeApp();

/**
 * JSON da conta de servico com acesso a Google Play Developer API.
 * Guardado no Secret Manager, nunca no repositorio. Ver README desta pasta.
 */
const CONTA_SERVICO_PLAY = defineSecret('PLAY_SERVICE_ACCOUNT_JSON');

/** applicationId oficial registrado na Play Console. */
const PACOTE = 'io.github.soniaambrosio.buracomastervip';

/** Estados de assinatura que valem como "jogador tem VIP agora". */
const ASSINATURA_VALIDA = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

let clientePlay = null;

async function androidPublisher() {
  if (clientePlay) return clientePlay;
  const credenciais = JSON.parse(CONTA_SERVICO_PLAY.value());
  const auth = new google.auth.GoogleAuth({
    credentials: credenciais,
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  clientePlay = google.androidpublisher({ version: 'v3', auth });
  return clientePlay;
}

/**
 * Chave do registro de compra. Hash do token porque o token e longo demais
 * para ID de documento do Firestore (limite de 1500 bytes) e nao ha motivo
 * para guardar o valor bruto como identificador.
 */
function chaveDaCompra(tokenCompra) {
  return crypto.createHash('sha256').update(tokenCompra).digest('hex');
}

/** Le o catalogo autoritativo. O app NAO decide o que cada produto concede. */
async function lerCatalogo() {
  const doc = await getFirestore().doc('configuracao/billing').get();
  const dados = doc.exists ? doc.data() : null;
  return (dados && dados.produtos) || {};
}

async function consultarAssinatura(tokenCompra) {
  const play = await androidPublisher();
  const { data } = await play.purchases.subscriptionsv2.get({
    packageName: PACOTE,
    token: tokenCompra,
  });
  return data;
}

async function consultarProduto(produtoId, tokenCompra) {
  const play = await androidPublisher();
  const { data } = await play.purchases.products.get({
    packageName: PACOTE,
    productId: produtoId,
    token: tokenCompra,
  });
  return data;
}

/**
 * Confirma a compra junto a Google. Sem isso, a Play Store estorna
 * automaticamente em 3 dias. O app tambem confirma pelo seu lado; confirmar
 * duas vezes nao causa problema, e a Google devolve erro que ignoramos.
 */
async function reconhecer(assinatura, produtoId, tokenCompra) {
  const play = await androidPublisher();
  try {
    if (assinatura) {
      await play.purchases.subscriptions.acknowledge({
        packageName: PACOTE,
        subscriptionId: produtoId,
        token: tokenCompra,
        requestBody: {},
      });
    } else {
      await play.purchases.products.acknowledge({
        packageName: PACOTE,
        productId: produtoId,
        token: tokenCompra,
        requestBody: {},
      });
    }
  } catch (e) {
    console.warn('[billing] reconhecimento falhou (provavelmente ja reconhecida):', e.message);
  }
}

exports.validarCompraPlay = onCall(
  { secrets: [CONTA_SERVICO_PLAY], region: 'us-central1' },
  async (request) => {
    // 1) Identidade. O callable ja traz o token do Firebase Auth verificado, e
    //    por isso o app nao manda uid — uid mandado pelo cliente e falsificavel.
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Entre na sua conta para concluir a compra.');
    }

    // 2) Entrada.
    const { produtoId, tokenCompra, assinatura, orderId } = request.data || {};
    if (typeof produtoId !== 'string' || !produtoId) {
      throw new HttpsError('invalid-argument', 'produtoId ausente.');
    }
    if (typeof tokenCompra !== 'string' || !tokenCompra) {
      throw new HttpsError('invalid-argument', 'tokenCompra ausente.');
    }
    const ehAssinatura = assinatura === true;

    // 3) O produto precisa existir no catalogo do servidor. Enquanto a Play
    //    Console nao liberar a area de produtos, isto recusa tudo — de proposito.
    const catalogo = await lerCatalogo();
    const definicao = catalogo[produtoId];
    if (!definicao) {
      throw new HttpsError(
        'failed-precondition',
        `Produto "${produtoId}" nao esta no catalogo do servidor.`
      );
    }
    if (!!definicao.assinatura !== ehAssinatura) {
      throw new HttpsError('invalid-argument', `Tipo divergente para "${produtoId}".`);
    }

    const db = getFirestore();
    const refCompra = db.doc(`compras/${chaveDaCompra(tokenCompra)}`);

    // 4) Idempotencia ANTES de creditar. A transacao e o que impede que duas
    //    entregas simultaneas do mesmo token creditem duas vezes.
    const jaExistia = await db.runTransaction(async (tx) => {
      const snap = await tx.get(refCompra);
      if (snap.exists) return true;
      tx.set(refCompra, {
        uid,
        produtoId,
        assinatura: ehAssinatura,
        orderId: orderId || null,
        estado: 'em_validacao',
        criadoEm: FieldValue.serverTimestamp(),
      });
      return false;
    });

    if (jaExistia) {
      const atual = (await refCompra.get()).data();
      // Uma reentrega de compra ja concedida e sucesso, nao erro.
      if (atual.estado === 'concedida') {
        return { aprovada: true, jaProcessada: true, detalhes: atual.concessao || {} };
      }
      if (atual.estado === 'recusada') {
        return { aprovada: false, jaProcessada: true, motivo: atual.motivo || 'compra recusada' };
      }
      // Ficou presa em `em_validacao`: uma execucao anterior morreu no meio.
      // Deixa seguir para revalidar — a Google e a fonte da verdade.
    }

    // 5) Pergunta a Google.
    let compra;
    try {
      compra = ehAssinatura
        ? await consultarAssinatura(tokenCompra)
        : await consultarProduto(produtoId, tokenCompra);
    } catch (e) {
      console.error('[billing] Play Developer API falhou:', e.message);
      // NAO marca como recusada: pode ser instabilidade da API. O app mantem a
      // compra pendente e volta a tentar.
      await refCompra.set({ estado: 'em_validacao', ultimoErro: e.message }, { merge: true });
      throw new HttpsError('unavailable', 'Nao consegui confirmar a compra agora. Tente em instantes.');
    }

    // 6) Veredito.
    let valida = false;
    let motivo = '';
    if (ehAssinatura) {
      valida = ASSINATURA_VALIDA.has(compra.subscriptionState);
      motivo = valida ? '' : `assinatura em estado ${compra.subscriptionState}`;
    } else {
      // purchaseState: 0 = comprado, 1 = cancelado, 2 = pendente.
      valida = compra.purchaseState === 0;
      motivo = valida ? '' : `produto em purchaseState ${compra.purchaseState}`;
    }

    if (!valida) {
      await refCompra.set({ estado: 'recusada', motivo }, { merge: true });
      return { aprovada: false, motivo };
    }

    // 7) Concede. A escrita do saldo/VIP e do servidor; as regras do Firestore
    //    proibem o cliente de escrever nestes campos.
    const concessao = await db.runTransaction(async (tx) => {
      const refJogador = db.doc(`usuarios/${uid}`);
      const resultado = {};

      if (ehAssinatura) {
        const expiraEm = compra.lineItems && compra.lineItems.length
          ? compra.lineItems[0].expiryTime
          : null;
        resultado.vip = true;
        resultado.vipExpiraEm = expiraEm;
        resultado.planoBase = compra.lineItems && compra.lineItems.length
          ? compra.lineItems[0].offerDetails && compra.lineItems[0].offerDetails.basePlanId
          : null;
        tx.set(refJogador, {
          vip: true,
          vipExpiraEm: expiraEm,
          vipProdutoId: produtoId,
          vipAtualizadoEm: FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        // `fichas` vem do catalogo no servidor, nunca do payload do app.
        const fichas = Number(definicao.fichas || 0);
        resultado.fichasCreditadas = fichas;
        tx.set(refJogador, {
          fichas: FieldValue.increment(fichas),
          fichasAtualizadoEm: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      tx.set(refCompra, {
        estado: 'concedida',
        concessao: resultado,
        concedidoEm: FieldValue.serverTimestamp(),
      }, { merge: true });

      return resultado;
    });

    // 8) Reconhece na Google (depois de conceder — se falhar aqui, o jogador ja
    //    recebeu, e a Google reentrega para reconhecermos de novo).
    await reconhecer(ehAssinatura, produtoId, tokenCompra);

    return { aprovada: true, jaProcessada: false, detalhes: concessao };
  }
);
