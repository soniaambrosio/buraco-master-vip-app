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
 *
 * CICLO DE VIDA DO ENTITLEMENT (correcao P0-3)
 * Validar a compra e o COMECO do direito, nao o direito inteiro. A assinatura
 * renova, expira, e cancelada, entra em carencia, e pausada, e revogada e e
 * estornada — e cada um desses desfechos precisa chegar ao consumidor. Por isso
 * este codebase tem, alem de `validarCompraPlay`:
 *
 *   notificacoesPlay            consumidor de RTDN (Pub/Sub)
 *   reconciliarEntitlements     varredura agendada de vencimento
 *   reconciliarEntitlementDoJogador   reconsulta autoritativa, so admin
 *   migrarEntitlementsLegado    transicao de `usuarios/{uid}` (so admin)
 *
 * A fonte canonica do direito passou a ser `playerEntitlements/{uid}`, escrita
 * so por este codebase e lida pelos consumidores (torneios, hoje). As decisoes
 * de estado moram em `entitlement.js`, puras e testadas.
 */

'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onMessagePublished } = require('firebase-functions/v2/pubsub');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { google } = require('googleapis');
const crypto = require('crypto');

const {
  ESTADO,
  ACAO,
  conferirTitularidade,
  decidirSobreRegistroExistente,
  podeConceder,
} = require('./idempotencia');

const {
  ESTADO: ESTADO_VIP,
  consolidarAssinatura,
  consolidarTerminal,
  interpretarNotificacao,
  decidirAtualizacao,
  documentosDeEntitlement,
  instante,
  anteriorA,
  rotuloToken,
} = require('./entitlement');

initializeApp();

/**
 * JSON da conta de servico com acesso a Google Play Developer API.
 * Guardado no Secret Manager, nunca no repositorio.
 */
const CONTA_SERVICO_PLAY = defineSecret('PLAY_SERVICE_ACCOUNT_JSON');

/** applicationId oficial registrado na Play Console. */
const PACOTE = 'io.github.soniaambrosio.buracomastervip';

/**
 * Topico Pub/Sub que recebe as Real-time Developer Notifications.
 *
 * Configurado na Play Console (Monetizar > Configuracao de monetizacao). A
 * Google e a UNICA publicadora autorizada nele; o `packageName` de cada mensagem
 * ainda e conferido em `interpretarNotificacao`, porque um projeto com mais de
 * um applicationId apontando para o mesmo topico entregaria evento alheio aqui.
 */
const TOPICO_RTDN = 'play-billing-rtdn';

/** Estados de assinatura que valem como "jogador tem VIP agora". */
const ASSINATURA_VALIDA = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

/** Fonte canonica do direito VIP. Escrita SO por este codebase. */
const COL_ENTITLEMENT = 'playerEntitlements';

/** Trilha de notificacoes processadas — id do documento = messageId do Pub/Sub. */
const COL_EVENTOS = 'billingEvents';

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

// ===========================================================================
// ENTITLEMENT — a fonte canonica do direito VIP
// ===========================================================================

/**
 * Os dois documentos do entitlement de um jogador.
 *
 *   playerEntitlements/{uid}                  o dono le: estado, prazo, produto
 *   playerEntitlements/{uid}/interno/billing   ninguem le: token e verificacao
 *
 * Dois porque regra do Firestore libera o documento INTEIRO. A separacao repete
 * a que a moderacao fez entre `reports` e `reportReceipts`, pelo mesmo motivo.
 */
function refsEntitlement(uid) {
  const publico = getFirestore().collection(COL_ENTITLEMENT).doc(uid);
  return { publico, interno: publico.collection('interno').doc('billing') };
}

/**
 * Grava a proposta, se ela puder ser gravada.
 *
 * TODA escrita de entitlement passa por aqui, e por uma razao so: a decisao
 * precisa ser tomada com o documento RELIDO DENTRO DA TRANSACAO. Ler o estado,
 * decidir fora e escrever depois deixaria duas notificacoes simultaneas — ou uma
 * validacao manual concorrendo com um RTDN — gravarem estados que ignoram um ao
 * outro, e a ultima a commitar venceria mesmo tendo consultado a Google primeiro.
 *
 * `set` sem `merge` e deliberado: o estado consolidado e completo, e um merge
 * deixaria campo velho de um estado anterior sobrevivendo ao lado do novo.
 *
 * @param {object} proposta ver `decidirAtualizacao` em entitlement.js
 * @param {{id: string, tipo?: number|null, motivo?: string}} [evento]
 *        notificacao que originou a proposta. Registrada na MESMA transacao: o
 *        efeito e a marca de "ja processei" nascem juntos, ou nao nascem.
 */
async function aplicarProposta(proposta, evento) {
  const db = getFirestore();
  const { publico, interno } = refsEntitlement(proposta.uid);
  const refEvento = evento ? db.collection(COL_EVENTOS).doc(evento.id) : null;

  return db.runTransaction(async (tx) => {
    const [pub, int, ev] = await Promise.all([
      tx.get(publico),
      tx.get(interno),
      refEvento ? tx.get(refEvento) : Promise.resolve(null),
    ]);

    // Reentrega do Pub/Sub. A entrega e "pelo menos uma vez" por contrato, entao
    // ver a mesma mensagem duas vezes e rotina, nao anomalia.
    if (ev && ev.exists && ev.data().estado === 'concluido') {
      return { aplicado: false, motivo: 'evento_repetido' };
    }

    const atual =
      pub.exists || int.exists
        ? { ...(pub.data() || {}), ...(int.data() || {}) }
        : null;

    const decisao = decidirAtualizacao(atual, proposta);

    if (decisao.aplicar) {
      const docs = documentosDeEntitlement(atual, proposta);
      tx.set(publico, docs.publico);
      tx.set(interno, docs.interno);
    }

    if (refEvento) {
      tx.set(refEvento, {
        messageId: evento.id,
        estado: 'concluido',
        tipo: evento.tipo != null ? evento.tipo : null,
        decisao: decisao.motivo,
        aplicado: decisao.aplicar,
        uid: proposta.uid,
        // Rotulo curto do hash — nunca o token, nunca o hash inteiro.
        token: rotuloToken(proposta.purchaseTokenHash),
        processadoEm: FieldValue.serverTimestamp(),
      });
    }

    return {
      aplicado: decisao.aplicar,
      motivo: decisao.motivo,
      estado: decisao.aplicar ? proposta.estado : atual && atual.estado,
      vipAtivo: decisao.aplicar
        ? proposta.vipAtivo === true
        : Boolean(atual && atual.vipAtivo),
    };
  });
}

/**
 * Consulta autoritativa + consolidacao + gravacao, para um token de assinatura.
 *
 * `consultadoEm` e capturado ANTES da chamada de rede, de proposito: uma
 * resposta que demorou dez segundos descreve o mundo de dez segundos atras, e
 * carimba-la com o instante da volta a faria ganhar de uma consulta mais nova
 * que respondeu rapido.
 */
async function reconsultarEAplicar({
  uid,
  produtoId,
  tokenCompra,
  fonte,
  eventoEm = null,
  eventoTipo = null,
  evento = null,
}) {
  const consultadoEm = new Date().toISOString();
  const resposta = await consultarAssinatura(tokenCompra);
  const consolidado = consolidarAssinatura(resposta, consultadoEm);

  return aplicarProposta(
    {
      uid,
      ...consolidado,
      produtoId: consolidado.produtoId || produtoId || null,
      origem: 'play',
      purchaseTokenHash: chaveDaCompra(tokenCompra),
      purchaseToken: tokenCompra,
      verificadoEm: consultadoEm,
      eventoEm,
      eventoTipo,
      fonte,
    },
    evento
  );
}

/**
 * Quem e o dono deste `purchaseToken`?
 *
 * A notificacao da Google traz o token e mais nada sobre identidade — ela nao
 * sabe o que e um UID do Firebase. O elo e o registro que `validarCompraPlay`
 * ja grava em `compras/{hash}`, com o uid tirado do contexto AUTENTICADO da
 * chamada. Sem esse registro nao ha titular comprovavel, e o evento e
 * descartado: atribuir um direito por palpite seria pior que perder o evento.
 */
async function titularDoToken(tokenCompra) {
  const hash = chaveDaCompra(tokenCompra);
  const doc = await getFirestore().collection('compras').doc(hash).get();
  if (!doc.exists) return { ok: false, motivo: 'compra_desconhecida', hash };
  const dados = doc.data();
  if (!dados.uid) return { ok: false, motivo: 'registro_sem_uid', hash };
  if (dados.assinatura !== true) {
    return { ok: false, motivo: 'nao_e_assinatura', hash };
  }
  return { ok: true, uid: dados.uid, produtoId: dados.produtoId || null, hash };
}

/** Anota um evento que nao produziu efeito, para a trilha nao ter buraco. */
async function registrarEventoSemEfeito(messageId, dados) {
  if (!messageId) return;
  await getFirestore().collection(COL_EVENTOS).doc(messageId).set(
    {
      messageId,
      estado: 'concluido',
      aplicado: false,
      processadoEm: FieldValue.serverTimestamp(),
      ...dados,
    },
    { merge: true }
  );
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
      // ASSINATURA NAO PARA AQUI — e este atalho que produzia o P0-3.
      //
      // Numa renovacao o `purchaseToken` e o MESMO, o registro ja esta
      // `concedida`, e a funcao devolvia `JA_CONCEDIDA` sem nunca reconsultar a
      // Google. O prazo gravado ficava sendo o da primeira cobranca, para
      // sempre. Em consumivel o atalho continua certo (as fichas ja foram
      // creditadas e creditar de novo seria o erro); em assinatura, o direito
      // tem prazo, e prazo precisa ser reconferido.
      if (!ehAssinatura) {
        return { aprovada: true, jaProcessada: true, detalhes: decisao.concessao };
      }
      try {
        const refresco = await reconsultarEAplicar({
          uid,
          produtoId,
          tokenCompra,
          fonte: 'validacao',
        });
        return {
          aprovada: refresco.vipAtivo,
          jaProcessada: true,
          detalhes: decisao.concessao,
          entitlement: { estado: refresco.estado, vipAtivo: refresco.vipAtivo },
        };
      } catch (e) {
        console.error('[billing] refresco de assinatura falhou:', e.message, {
          uid,
          token: rotuloToken(chaveDaCompra(tokenCompra)),
        });
        throw new HttpsError(
          'unavailable',
          'Nao consegui confirmar sua assinatura agora. Tente em instantes.'
        );
      }
    }
    if (decisao.acao === ACAO.JA_RECUSADA) {
      return { aprovada: false, jaProcessada: true, motivo: decisao.motivo };
    }

    // 5) Pergunta a Google. O instante e capturado ANTES da chamada: a resposta
    //    descreve o mundo de quando a pergunta saiu, nao de quando ela voltou.
    const consultadoEm = new Date().toISOString();
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

    // 6.1) ENTITLEMENT — antes do veredito decidir o rumo, e valendo ou nao.
    //
    //      A resposta que acabou de chegar e a informacao mais autoritativa que
    //      este sistema tera sobre o direito deste jogador. Grava-la so no
    //      caminho feliz deixaria o caso mais importante de fora: a assinatura
    //      que a Google diz estar EXPIRED ou ON_HOLD precisa virar "sem VIP" no
    //      documento que o torneio le, e nao apenas um `aprovada: false` que
    //      ninguem persiste.
    let entitlement = null;
    if (ehAssinatura) {
      const consolidado = consolidarAssinatura(compra, consultadoEm);
      entitlement = await aplicarProposta({
        uid,
        ...consolidado,
        produtoId: consolidado.produtoId || produtoId,
        origem: 'play',
        purchaseTokenHash: chaveDaCompra(tokenCompra),
        purchaseToken: tokenCompra,
        verificadoEm: consultadoEm,
        fonte: 'validacao',
      });
      console.info('[billing] entitlement consolidado na validacao', {
        uid,
        estado: entitlement.estado,
        vipAtivo: entitlement.vipAtivo,
        decisao: entitlement.motivo,
        token: rotuloToken(chaveDaCompra(tokenCompra)),
      });
    }

    if (!valida) {
      if (ehAssinatura) {
        // Assinatura NAO vira `recusada` no registro do token. `ON_HOLD`,
        // `PAUSED` e carencia sao situacoes das quais se VOLTA, e um registro
        // marcado recusado devolveria `JA_RECUSADA` para sempre — a propria
        // recuperacao ficaria barrada. Quem guarda o estado do direito e o
        // entitlement, que acabou de ser atualizado logo acima.
        await refCompra.set(
          { ultimoEstadoAssinatura: compra.subscriptionState || null, motivo },
          { merge: true }
        );
        return {
          aprovada: false,
          motivo,
          entitlement: { estado: entitlement.estado, vipAtivo: entitlement.vipAtivo },
        };
      }
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
        // O REGISTRO DA COMPRA, e nao o estado do direito.
        //
        // Aqui se anota o que ESTA compra concedeu no instante em que foi paga —
        // dado historico, congelado. O estado vigente (renovou? expirou? foi
        // estornado?) mora em `playerEntitlements/{uid}` e ja foi escrito no
        // passo 6.1.
        //
        // O que sumiu daqui de proposito: o `tx.set` em `usuarios/{uid}` com
        // `vip: true`. Aquele campo era monotonico — nada no sistema o removia —
        // e manter a escrita criaria DUAS fontes concorrentes de entitlement,
        // que e exatamente o que a correcao veio desfazer. `usuarios/` continua
        // dono das fichas e do resto do legado; de VIP, nao mais.
        const item = compra.lineItems && compra.lineItems.length ? compra.lineItems[0] : null;
        concessao.vip = true;
        concessao.vipExpiraEm = item ? item.expiryTime : null;
        concessao.planoBase = item && item.offerDetails ? item.offerDetails.basePlanId : null;
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

    return {
      aprovada: true,
      jaProcessada: false,
      detalhes: resultadoConcessao.concessao,
      ...(entitlement
        ? { entitlement: { estado: entitlement.estado, vipAtivo: entitlement.vipAtivo } }
        : {}),
    };
  }
);

// ===========================================================================
// RTDN — Real-time Developer Notifications
// ===========================================================================

/**
 * Consumidor das notificacoes da Play.
 *
 * A NOTIFICACAO E UM SINAL, NAO UM VEREDITO. Fora os dois desfechos terminais
 * (revogacao e anulacao, que a consulta de estado nao expressa), nenhum estado e
 * derivado do payload: o que a mensagem faz e mandar PERGUNTAR a Google qual e o
 * estado agora. Confiar no payload seria confiar num evento que pode ter sido
 * emitido antes de outro que ja processamos.
 *
 * TRES ENTREGAS ANORMAIS SAO TRATADAS COMO NORMAIS:
 *
 *   repetida    o Pub/Sub entrega "pelo menos uma vez". `billingEvents/{messageId}`
 *               e escrito na MESMA transacao do efeito — ou os dois acontecem, ou
 *               nenhum dos dois.
 *   fora de ordem  o carimbo comparado nao e o do evento, e o da CONSULTA que
 *               produziu a proposta (`decidirAtualizacao`). Um evento antigo que
 *               chega depois faz uma consulta nova, e consulta nova nunca regride.
 *   sobre token velho  a proposta e descartada por `token_superado`: uma
 *               expiracao da assinatura anterior nao derruba a assinatura atual.
 *
 * `retry: true` e deliberado: falha na Play Developer API tem que voltar como
 * reentrega do Pub/Sub, que e a reconciliacao posterior deste desenho. Como o
 * registro de "ja processei" so e gravado junto com o efeito, a reentrega
 * encontra trabalho a fazer — e nao um evento marcado como concluido sem ter
 * concluido nada.
 */
exports.notificacoesPlay = onMessagePublished(
  {
    topic: TOPICO_RTDN,
    secrets: [CONTA_SERVICO_PLAY],
    region: 'us-central1',
    retry: true,
  },
  async (event) => {
    const mensagem = (event.data && event.data.message) || {};
    const messageId = mensagem.messageId || event.id || null;

    let corpo;
    try {
      corpo = JSON.parse(Buffer.from(mensagem.data || '', 'base64').toString('utf8'));
    } catch (e) {
      // Mensagem ilegivel nao melhora com retry: registrar e seguir.
      console.error('[billing] RTDN ilegivel:', e.message, { messageId });
      await registrarEventoSemEfeito(messageId, { decisao: 'corpo_ilegivel' });
      return;
    }

    const leitura = interpretarNotificacao(corpo, PACOTE);

    if (leitura.acao === 'ignorar') {
      console.info('[billing] RTDN ignorada', { messageId, motivo: leitura.motivo });
      await registrarEventoSemEfeito(messageId, { decisao: leitura.motivo });
      return;
    }

    if (!leitura.purchaseToken) {
      console.error('[billing] RTDN sem purchaseToken', { messageId });
      await registrarEventoSemEfeito(messageId, { decisao: 'sem_token' });
      return;
    }

    // Atalho barato antes de gastar uma chamada de rede. NAO e a barreira de
    // idempotencia — essa esta dentro da transacao, onde a corrida existe.
    if (messageId) {
      const jaVisto = await getFirestore().collection(COL_EVENTOS).doc(messageId).get();
      if (jaVisto.exists && jaVisto.data().estado === 'concluido') {
        console.info('[billing] RTDN repetida, ja concluida', { messageId });
        return;
      }
    }

    // TITULARIDADE. A Google conhece o token; quem conhece o dono e o registro
    // que a validacao gravou com o uid autenticado.
    const titular = await titularDoToken(leitura.purchaseToken);
    if (!titular.ok) {
      console.warn('[billing] RTDN sem titular comprovavel', {
        messageId,
        motivo: titular.motivo,
        token: rotuloToken(titular.hash),
      });
      await registrarEventoSemEfeito(messageId, {
        decisao: titular.motivo,
        token: rotuloToken(titular.hash),
      });
      return;
    }

    // Mensagem sem id nao tem como ser deduplicada. Ela ainda e processada — o
    // efeito importa mais que a trilha —, e a idempotencia real continua sendo a
    // de `decidirAtualizacao`: reprocessar a mesma consulta nao muda nada.
    const evento = messageId
      ? { id: messageId, tipo: leitura.tipo != null ? leitura.tipo : null }
      : null;

    // DESFECHO TERMINAL: o fato esta no payload, e nao ha consulta que o
    // expresse. Esperar para confirmar deixaria uma janela em que o estornado
    // continua VIP.
    if (leitura.acao === 'aplicar_terminal') {
      const agora = new Date().toISOString();
      const resultado = await aplicarProposta(
        {
          uid: titular.uid,
          ...consolidarTerminal(leitura.terminal, agora),
          produtoId: leitura.produtoId || titular.produtoId || null,
          origem: 'play',
          purchaseTokenHash: titular.hash,
          purchaseToken: leitura.purchaseToken,
          verificadoEm: agora,
          eventoEm: leitura.eventoEm,
          eventoTipo: leitura.tipo != null ? leitura.tipo : null,
          fonte: 'rtdn',
        },
        evento
      );
      console.info('[billing] entitlement encerrado por notificacao', {
        messageId,
        uid: titular.uid,
        estado: leitura.terminal,
        decisao: resultado.motivo,
        token: rotuloToken(titular.hash),
      });
      return;
    }

    // RECONCILIACAO: pergunta a Google e grava o que ela responder.
    const resultado = await reconsultarEAplicar({
      uid: titular.uid,
      produtoId: leitura.produtoId || titular.produtoId,
      tokenCompra: leitura.purchaseToken,
      fonte: 'rtdn',
      eventoEm: leitura.eventoEm,
      eventoTipo: leitura.tipo != null ? leitura.tipo : null,
      evento,
    });

    console.info('[billing] entitlement reconciliado por notificacao', {
      messageId,
      uid: titular.uid,
      tipo: leitura.tipo,
      estado: resultado.estado,
      vipAtivo: resultado.vipAtivo,
      decisao: resultado.motivo,
      token: rotuloToken(titular.hash),
    });
  }
);

// ===========================================================================
// RECONCILIACAO
// ===========================================================================

/**
 * Varredura de vencimento. A rede de seguranca do ciclo de vida.
 *
 * NAO consulta a Google, e isso e o ponto: ela fecha o direito de quem passou do
 * prazo mesmo que a notificacao de expiracao nunca chegue, o topico esteja mal
 * configurado ou a Play Developer API esteja fora do ar. E uma conclusao do
 * RELOGIO sobre um prazo que a Google ja tinha informado.
 *
 * O consumidor nao depende dela para estar correto — `EntitlementVip.vigenteEm`
 * ja recusa um direito vencido mesmo com `vipAtivo: true` gravado. Esta funcao
 * existe para que o DOCUMENTO tambem conte a verdade, e para que um relatorio
 * administrativo nao precise reimplementar a conta do prazo.
 */
exports.reconciliarEntitlements = onSchedule(
  { schedule: 'every 30 minutes', region: 'us-central1' },
  async () => {
    const db = getFirestore();
    const agora = new Date().toISOString();

    const vencidos = await db
      .collection(COL_ENTITLEMENT)
      .where('vipAtivo', '==', true)
      .where('expiraEm', '<=', agora)
      .limit(200)
      .get();

    let fechados = 0;
    for (const doc of vencidos.docs) {
      const uid = doc.id;
      try {
        const interno = await refsEntitlement(uid).interno.get();
        const resultado = await aplicarProposta({
          uid,
          estado: ESTADO_VIP.EXPIRADO,
          vipAtivo: false,
          produtoId: doc.data().produtoId || null,
          inicioEm: doc.data().inicioEm || null,
          // O prazo NAO e reescrito: ele e o fato que produziu a conclusao.
          expiraEm: doc.data().expiraEm || null,
          renovacaoAutomatica: false,
          origem: doc.data().origem || 'play',
          purchaseTokenHash: interno.exists ? interno.data().purchaseTokenHash : null,
          verificadoEm: agora,
          fonte: 'relogio',
        });
        if (resultado.aplicado) fechados += 1;
      } catch (e) {
        // Um documento problematico nao pode travar a varredura: o tick seguinte
        // tenta de novo, e a operacao e idempotente.
        console.error('[billing] falha ao fechar entitlement vencido:', e.message, { uid });
      }
    }

    console.info('[billing] varredura de vencimento', {
      candidatos: vencidos.size,
      fechados,
    });
  }
);

/**
 * Reconsulta autoritativa de UM jogador. So admin.
 *
 * A saida de emergencia do desenho: divergencia relatada, notificacao perdida,
 * topico reconfigurado. Usa o `purchaseToken` guardado no documento interno —
 * que e a unica razao pela qual ele e guardado.
 */
exports.reconciliarEntitlementDoJogador = onCall(
  { secrets: [CONTA_SERVICO_PLAY], region: 'us-central1' },
  async (request) => {
    if (!request.auth || request.auth.token.admin !== true) {
      throw new HttpsError('permission-denied', 'Operacao restrita a administracao.');
    }
    const uid = request.data && request.data.uid;
    if (typeof uid !== 'string' || !uid) {
      throw new HttpsError('invalid-argument', 'uid e obrigatorio.');
    }

    const interno = await refsEntitlement(uid).interno.get();
    const dados = interno.exists ? interno.data() : null;
    if (!dados || !dados.purchaseToken) {
      throw new HttpsError(
        'failed-precondition',
        'Sem token guardado para este jogador: nao ha o que reconsultar.'
      );
    }

    const resultado = await reconsultarEAplicar({
      uid,
      produtoId: dados.produtoId,
      tokenCompra: dados.purchaseToken,
      fonte: 'reconciliacao',
    });

    console.info('[billing] reconciliacao manual', {
      uid,
      estado: resultado.estado,
      vipAtivo: resultado.vipAtivo,
      decisao: resultado.motivo,
      token: rotuloToken(dados.purchaseTokenHash),
    });

    return {
      estado: resultado.estado,
      vipAtivo: resultado.vipAtivo,
      aplicado: resultado.aplicado,
      motivo: resultado.motivo,
    };
  }
);

// ===========================================================================
// MIGRACAO DO LEGADO
// ===========================================================================

/**
 * Transporta para `playerEntitlements/{uid}` os direitos que so existem em
 * `usuarios/{uid}`. So admin, idempotente, com cursor.
 *
 * POR QUE NAO DA PARA SIMPLESMENTE RECONSULTAR A GOOGLE: `compras/{hash}` guarda
 * o HASH do token, nunca o token. Para as compras anteriores a esta OS nao
 * existe, em lugar nenhum desta arvore, o valor com que se pergunta a Play. A
 * unica informacao disponivel sobre elas e `vipExpiraEm`, que veio da Google no
 * dia da compra.
 *
 * O QUE ISSO SIGNIFICA, DITO SEM MAQUIAGEM: o direito migrado vale ate o prazo
 * que ja estava gravado e nao vale um minuto a mais. Se a assinatura renovou,
 * quem repoe o prazo e a proxima notificacao ou a proxima validacao — as duas
 * carregam o token. Se foi estornada no meio, o sistema so descobre no
 * vencimento. A janela de erro e de no maximo um periodo de cobranca, ela existe
 * porque o token nao foi guardado la atras, e ela e menor do que a alternativa,
 * que seria tirar o VIP de todo assinante pagante no dia da virada.
 *
 * `origem: 'legado_usuarios'` fica gravado justamente para que esses documentos
 * sejam distinguiveis num relatorio, e para que a remocao do legado possa ser
 * conferida.
 */
exports.migrarEntitlementsLegado = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth || request.auth.token.admin !== true) {
      throw new HttpsError('permission-denied', 'Operacao restrita a administracao.');
    }

    const db = getFirestore();
    const cursor = (request.data && request.data.cursor) || null;
    const lote = Math.min(Number((request.data && request.data.lote) || 100), 400);
    const agora = new Date().toISOString();

    let consulta = db
      .collection('usuarios')
      .where('vip', '==', true)
      .orderBy(FieldPath.documentId())
      .limit(lote);
    if (cursor) consulta = consulta.startAfter(cursor);

    const pagina = await consulta.get();

    let migrados = 0;
    let jaTinham = 0;
    let semPrazo = 0;
    let ultimo = cursor;

    for (const doc of pagina.docs) {
      const uid = doc.id;
      ultimo = uid;
      const dados = doc.data();

      const expiraEm = instante(dados.vipExpiraEm);
      if (!expiraEm) {
        // Sem prazo nao da para afirmar que o direito ainda vale, e afirmar o
        // que nao se sabe e o defeito que esta OS veio consertar.
        semPrazo += 1;
        continue;
      }

      const vigente = anteriorA(agora, expiraEm);
      const resultado = await aplicarProposta({
        uid,
        estado: vigente ? ESTADO_VIP.ATIVO : ESTADO_VIP.EXPIRADO,
        vipAtivo: vigente,
        produtoId: dados.vipProdutoId || null,
        inicioEm: null,
        expiraEm,
        // O legado nao registra se a renovacao estava ligada. `false` e o valor
        // que nao promete nada.
        renovacaoAutomatica: false,
        origem: 'legado_usuarios',
        purchaseTokenHash: null,
        verificadoEm: agora,
        fonte: 'migracao',
      });

      if (resultado.aplicado) migrados += 1;
      else jaTinham += 1;
    }

    console.info('[billing] migracao de entitlement legado', {
      examinados: pagina.size,
      migrados,
      jaTinham,
      semPrazo,
    });

    return {
      examinados: pagina.size,
      migrados,
      jaTinham,
      semPrazo,
      // `null` quando a pagina veio incompleta: acabou.
      cursor: pagina.size === lote ? ultimo : null,
    };
  }
);
