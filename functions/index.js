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
 * Por isso o aplicativo nao concede nada e nao consome nada. Ele manda o
 * `purchaseToken`, esta funcao pergunta a Google se a compra e real, credita, e
 * so entao consome o token. O app descobre o que ganhou lendo o Firestore.
 *
 * CREDITO UNICO SOB CONCORRENCIA
 * A Play Store reentrega compras (troca de aparelho, app fechado no meio da
 * validacao, reinstalacao), e duas entregas podem chegar ao mesmo tempo. A
 * concessao e a marcacao de `concedida` acontecem na MESMA transacao, com o
 * documento relido dentro dela: quem perder a corrida ve `concedida` e devolve
 * o que ja foi concedido, sem creditar de novo. Ver `idempotencia.js`.
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

const {
  ESTADO,
  ACAO,
  conferirTitularidade,
  decidirSobreRegistroExistente,
  podeConceder,
} = require('./idempotencia');

initializeApp();

/**
 * JSON da conta de servico com acesso a Google Play Developer API.
 * Guardado no Secret Manager, nunca no repositorio.
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
 * Fecha a compra junto a Google, DEPOIS de creditar.
 *
 * - Consumivel: `products.consume`, que tambem reconhece. Consumir e o que
 *   libera o token para ser comprado de novo — por isso vem depois do credito.
 *   Se falhar aqui, o jogador ja recebeu e a Play reentrega o token; a
 *   reentrega cai na idempotencia e nao credita duas vezes.
 * - Assinatura: `subscriptions.acknowledge`. Sem reconhecer, a Play Store
 *   estorna automaticamente em 3 dias.
 *
 * Erros sao tolerados e registrados: a causa quase sempre e "ja consumida" ou
 * "ja reconhecida", e transformar isso em falha da funcao faria o app achar que
 * a compra nao valeu.
 */
async function fecharComAGoogle(ehAssinatura, produtoId, tokenCompra) {
  const play = await androidPublisher();
  try {
    if (ehAssinatura) {
      await play.purchases.subscriptions.acknowledge({
        packageName: PACOTE,
        subscriptionId: produtoId,
        token: tokenCompra,
        requestBody: {},
      });
    } else {
      await play.purchases.products.consume({
        packageName: PACOTE,
        productId: produtoId,
        token: tokenCompra,
      });
    }
    return { ok: true };
  } catch (e) {
    console.warn('[billing] fechamento junto a Google falhou:', e.message);
    return { ok: false, erro: e.message };
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
    const ctx = { uid, produtoId, assinatura: ehAssinatura };

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
    if (Boolean(definicao.assinatura) !== ehAssinatura) {
      throw new HttpsError('invalid-argument', `Tipo divergente para "${produtoId}".`);
    }

    const db = getFirestore();
    const refCompra = db.doc(`compras/${chaveDaCompra(tokenCompra)}`);

    // 4) Registro do token. Se ja existir, decide olhando titularidade ANTES do
    //    estado — um token de outro jogador nao pode devolver concessao alheia.
    const decisao = await db.runTransaction(async (tx) => {
      const snap = await tx.get(refCompra);
      if (snap.exists) {
        return decidirSobreRegistroExistente(snap.data(), ctx);
      }
      tx.set(refCompra, {
        uid,
        produtoId,
        assinatura: ehAssinatura,
        orderId: orderId || null,
        estado: ESTADO.EM_VALIDACAO,
        criadoEm: FieldValue.serverTimestamp(),
      });
      return { acao: ACAO.PROSSEGUIR };
    });

    if (decisao.acao === ACAO.CONFLITO) {
      console.error('[billing] conflito de titularidade de token:', decisao.motivo, { uid, produtoId });
      throw new HttpsError('permission-denied', 'Esta compra nao pertence a esta conta.');
    }
    if (decisao.acao === ACAO.JA_CONCEDIDA) {
      return { aprovada: true, jaProcessada: true, detalhes: decisao.concessao };
    }
    if (decisao.acao === ACAO.JA_RECUSADA) {
      return { aprovada: false, jaProcessada: true, motivo: decisao.motivo };
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
      await refCompra.set({ ultimoErro: e.message }, { merge: true });
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
      await refCompra.set({ estado: ESTADO.RECUSADA, motivo }, { merge: true });
      return { aprovada: false, motivo };
    }

    // 7) TRANSACAO DE CONCESSAO — atomicamente idempotente.
    //
    //    O documento e RELIDO aqui dentro. Se outra execucao ja concedeu, esta
    //    devolve a concessao existente sem tocar no saldo. Credito e marcacao de
    //    `concedida` sao a mesma escrita: nao existe janela entre "creditei" e
    //    "anotei que creditei".
    const resultadoConcessao = await db.runTransaction(async (tx) => {
      const snap = await tx.get(refCompra);
      const registro = snap.exists ? snap.data() : null;

      if (registro) {
        // Defesa em profundidade: reconfere titularidade dentro da transacao.
        const t = conferirTitularidade(registro, ctx);
        if (!t.ok) return { conflito: true, motivo: t.motivo };
      }

      if (!podeConceder(registro)) {
        return { jaConcedida: true, concessao: (registro && registro.concessao) || {} };
      }

      const refJogador = db.doc(`usuarios/${uid}`);
      const concessao = {};

      if (ehAssinatura) {
        const item = compra.lineItems && compra.lineItems.length ? compra.lineItems[0] : null;
        const expiraEm = item ? item.expiryTime : null;
        concessao.vip = true;
        concessao.vipExpiraEm = expiraEm;
        concessao.planoBase = item && item.offerDetails ? item.offerDetails.basePlanId : null;
        tx.set(refJogador, {
          vip: true,
          vipExpiraEm: expiraEm,
          vipProdutoId: produtoId,
          vipAtualizadoEm: FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        // `fichas` vem do catalogo no servidor, nunca do payload do app.
        const fichas = Number(definicao.fichas || 0);
        concessao.fichasCreditadas = fichas;
        tx.set(refJogador, {
          fichas: FieldValue.increment(fichas),
          fichasAtualizadoEm: FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      tx.set(refCompra, {
        estado: ESTADO.CONCEDIDA,
        concessao,
        concedidoEm: FieldValue.serverTimestamp(),
      }, { merge: true });

      return { concedidaAgora: true, concessao };
    });

    if (resultadoConcessao.conflito) {
      console.error('[billing] conflito de titularidade na concessao:', resultadoConcessao.motivo);
      throw new HttpsError('permission-denied', 'Esta compra nao pertence a esta conta.');
    }

    if (resultadoConcessao.jaConcedida) {
      // Corrida perdida: outra execucao creditou. Nada a fazer alem de garantir
      // o fechamento junto a Google, que e idempotente do lado deles.
      await fecharComAGoogle(ehAssinatura, produtoId, tokenCompra);
      return { aprovada: true, jaProcessada: true, detalhes: resultadoConcessao.concessao };
    }

    // 8) Fecha na Google DEPOIS de creditar. Consumir antes de creditar seria a
    //    receita para o jogador pagar e nao receber.
    const fechamento = await fecharComAGoogle(ehAssinatura, produtoId, tokenCompra);
    if (!fechamento.ok) {
      await refCompra.set({ avisoFechamento: fechamento.erro }, { merge: true });
    }

    return { aprovada: true, jaProcessada: false, detalhes: resultadoConcessao.concessao };
  }
);
