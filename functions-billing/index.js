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
 *   backfillPurchaseTokenHash   recupera o hash de `compras/` (so admin, dry-run
 *                               por padrao)
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
  // `instante` saiu junto com o corpo da migracao de legado: quem interpreta
  // `vipExpiraEm` agora e `migracaoLegado.js`.
  anteriorA,
  rotuloToken,
} = require('./entitlement');

const {
  COL_ENTITLEMENT,
  chaveDaCompra,
  criarStore,
} = require('./entitlementStore');
const { criarReconciliador } = require('./reconciliacao');
const { criarProcessadorRtdn } = require('./rtdn');

// `indicesDevidos` saiu daqui junto com o corpo da varredura mensal: quem conta
// parcelas vencidas agora e `fichasVarredura.js`. O que sobrou nesta fiacao usa
// so o indice 0, que e a ativacao creditada na hora da compra.
const { planoDoCatalogo, fichasDoIndice } = require('./fichas');
const { criarLivroDeFichas } = require('./fichasStore');
const {
  concederFichasDeTodosOsAssinantes,
} = require('./fichasVarredura');
const { migrarPaginaDeLegado } = require('./migracaoLegado');
const {
  criarDiagnosticoPopulacao,
  criarPortasFirestore,
} = require('./diagnosticoPopulacao');
const {
  criarBackfillHash,
  criarPortasDeLeitura,
} = require('./backfillHash');
// A porta de ESCRITA do backfill e importada aqui e injetada em UM lugar so, sob
// duas condicoes explicitas. Ver `backfillPurchaseTokenHash`, no fim do arquivo.
const { criarGravadorDeHash } = require('./backfillHashStore');

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
 * As dependencias de infraestrutura, montadas UMA vez e sob demanda.
 *
 * Preguicoso pela mesma razao que `androidPublisher()`: `getFirestore()` so pode
 * ser chamado depois de `initializeApp()`, e montar isto no topo do modulo
 * amarraria a carga do arquivo a ordem de inicializacao do Admin SDK.
 *
 * E AQUI QUE AS PORTAS SAO LIGADAS. Store, reconciliador e processador de RTDN
 * nao conhecem `firebase-admin` nem `googleapis`; conhecem as funcoes que este
 * bloco entrega. E por isso que `node --test` consegue exercita-los sem
 * `node_modules`, e por isso que trocar o cliente da Play amanha nao encosta na
 * politica economica.
 */
let infra = null;

function dependencias() {
  if (infra) return infra;

  const store = criarStore({
    db: getFirestore(),
    carimbo: () => FieldValue.serverTimestamp(),
  });

  const reconciliador = criarReconciliador({
    consultarAssinatura,
    aplicarProposta: store.aplicarProposta,
  });

  const rtdn = criarProcessadorRtdn({
    pacote: PACOTE,
    store,
    reconciliador,
    log: console,
  });

  const livroFichas = criarLivroDeFichas({
    db: getFirestore(),
    carimbo: () => FieldValue.serverTimestamp(),
    incremento: (n) => FieldValue.increment(n),
  });

  infra = { store, reconciliador, rtdn, livroFichas };
  return infra;
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
//
// As escritas moraram aqui ate esta OS. Hoje vivem em `entitlementStore.js`
// (a transacao) e `reconciliacao.js` (a consulta autoritativa), com o Firestore
// injetado — o que as tornou alcancaveis por `node --test`, que este codebase
// roda sem `node_modules`. O CORPO delas nao mudou; mudou de onde vem o `db`.
// Ver o cabecalho daqueles dois arquivos.

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
        const refresco = await dependencias().reconciliador.reconsultarEAplicar({
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
      entitlement = await dependencias().store.aplicarProposta({
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
        // As fichas de ATIVACAO nao sao creditadas nesta transacao — elas sao a
        // parcela de indice 0 do livro-razao, liquidada logo abaixo pelo mesmo
        // caminho que o agendador usa. Ver o comentario no passo 7.1.
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

    // 7.1) FICHAS DE ATIVACAO — a parcela de indice 0.
    //
    //      FORA da transacao de concessao, e de proposito. A idempotencia desta
    //      parcela nao vem de `compras/{hash}`: vem do livro-razao, que e a mesma
    //      barreira que `concederFichasMensais` atravessa. Com isso existe UM
    //      caminho de credito de fichas, nao dois que podem divergir — e o
    //      agendador vira, sem nenhum codigo de reparo, a rede de seguranca
    //      desta linha: se o processo morrer aqui, o jogador ja tem o VIP e a
    //      parcela 0 fica pendente ate o proximo tick, que a paga uma unica vez.
    //
    //      Roda tambem no caminho `jaConcedida` porque a corrida pode ter sido
    //      perdida para uma execucao que morreu antes de chegar ate aqui.
    if (ehAssinatura) {
      const planoBase =
        (resultadoConcessao.concessao && resultadoConcessao.concessao.planoBase) || null;
      const plano = planoDoCatalogo(definicao, planoBase);
      if (!plano) {
        // Nao derruba a compra: o VIP foi pago e ja foi concedido. Mas e
        // divergencia entre a Play e `configuracao/billing` — o plano-base que a
        // Google devolveu nao esta configurado — e divergencia economica em
        // silencio e exatamente o que nao pode acontecer.
        console.error('[billing] plano-base sem configuracao de fichas', {
          uid,
          produtoId,
          planoBase,
          token: rotuloToken(chaveDaCompra(tokenCompra)),
        });
      } else {
        try {
          const r = await dependencias().livroFichas.liquidarParcela({
            uid,
            purchaseTokenHash: chaveDaCompra(tokenCompra),
            indice: 0,
            fichas: fichasDoIndice(plano, 0),
            produtoId,
            planoBase,
            origem: 'validacao',
          });
          console.info('[billing] parcela de ativacao', {
            uid,
            planoBase,
            creditado: r.creditado,
            motivo: r.motivo,
          });
        } catch (e) {
          // O agendador liquida no proximo tick. Falhar a chamada inteira aqui
          // faria o app reapresentar uma compra que a Google ja considera
          // fechada — custo maior que o atraso de uma parcela.
          console.error('[billing] falha ao liquidar parcela de ativacao:', e.message, { uid });
        }
      }
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
 * Consumidor das notificacoes da Play — o ADAPTADOR.
 *
 * O que este bloco faz e so ligar o gatilho do Pub/Sub ao processador de
 * `rtdn.js`, que e onde o caminho inteiro esta descrito e testado. Nada de
 * politica economica mora aqui.
 *
 * `retry: true` e deliberado, e e METADE do tratamento de falha transitoria: a
 * outra metade e `processarNotificacao` DEIXAR A EXCECAO SUBIR quando a Play
 * Developer API falha. Uma coisa sem a outra nao funciona — sem `retry` a
 * excecao viraria mensagem perdida, e sem a excecao o `retry` nunca dispararia.
 * Ver o cabecalho de `rtdn.js` e o teste RTDN-11.
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
    await dependencias().rtdn.processarNotificacao({
      // `event.id` e a rede de seguranca: o envelope do CloudEvent carrega o
      // mesmo identificador quando `message.messageId` nao vem preenchido.
      messageId: mensagem.messageId || event.id || null,
      data: mensagem.data,
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
        const interno = await dependencias().store.refsEntitlement(uid).interno.get();
        const resultado = await dependencias().store.aplicarProposta({
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

// ===========================================================================
// FICHAS — a entrega MENSAL do beneficio da assinatura
// ===========================================================================

/**
 * Liquida as parcelas de fichas ja vencidas de cada assinante ativo.
 *
 * POR QUE ISTO E UM AGENDADOR, E NAO UM OUVINTE DE RTDN
 *
 * A Play notifica RENOVACAO, e renovacao acontece a cada ciclo de COBRANCA: uma
 * vez por mes no plano mensal, uma vez por TRIMESTRE no trimestral, uma vez por
 * ANO no anual. Nao existe notificacao para "mes 2 do plano anual" — e a politica
 * aprovada promete 1.500 fichas em cada um dos 11 meses seguintes a ativacao.
 * Nenhum evento da plataforma marca essas datas. Quem as marca e o relogio.
 *
 * A mesma natureza de `reconciliarEntitlements` logo acima: uma conclusao sobre
 * um prazo que a Google ja informou, tirada sem perguntar nada a ninguem.
 *
 * POR QUE RODAR DE NOVO NAO DOBRA NADA
 *
 * Cada parcela e uma linha deterministica em `fichasConcessoes`, e criar a linha
 * e creditar o saldo sao a MESMA transacao. Um segundo tick — ou dois ticks
 * concorrentes, ou um retry depois de falha parcial — encontra a linha e nao
 * credita. E a disciplina de `idempotencia.js`, aplicada a um evento que nao vem
 * de fora: vem do calendario.
 *
 * DIARIO, E NAO DE HORA EM HORA, porque a unidade da politica e o mes: um atraso
 * de ate 24h na parcela e invisivel para o jogador e corta o custo da varredura
 * por 24. Nenhuma parcela se perde por causa do intervalo — ela so e liquidada no
 * tick seguinte, com o valor certo, porque o que manda e o indice do mes e nao o
 * momento em que o job passou.
 *
 * POR QUE A SELECAO DOS ASSINANTES E PAGINADA
 *
 * Ate aqui esta funcao lia `.where('vipAtivo','==',true).limit(500)`. Um limite
 * sem cursor nao e uma pagina, e um TETO: a consulta e ordenada de forma estavel,
 * entao ela devolvia os MESMOS 500 documentos todo dia, e como esta rotina nao
 * escreve em `playerEntitlements`, nada tirava esses 500 da frente da fila. O
 * 501o assinante nunca era visitado — nao hoje, nao amanha, nunca — e o log
 * dizia "candidatos: 500", que se le como saude.
 *
 * A decisao inteira mora agora em `fichasVarredura.js`, testavel sem
 * `firebase-functions`. Aqui ficou so a fiacao.
 */
exports.concederFichasMensais = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'America/Sao_Paulo', region: 'us-central1' },
  async () => {
    const db = getFirestore();
    const agora = new Date().toISOString();

    // UMA leitura do catalogo por tick, e nao uma por jogador: a politica e a
    // mesma para todo mundo dentro do tick, e ler por jogador multiplicaria o
    // custo sem mudar nenhuma decisao.
    const catalogo = await lerCatalogo();

    const relatorio = await concederFichasDeTodosOsAssinantes({
      db,
      FieldPath,
      colecaoEntitlement: COL_ENTITLEMENT,
      catalogo,
      agora,
      anteriorA,
      lerInterno: async (uid) => {
        const snap = await dependencias().store.refsEntitlement(uid).interno.get();
        return snap.exists ? snap.data() : null;
      },
      liquidarParcela: (parcela) =>
        dependencias().livroFichas.liquidarParcela(parcela),
      registrarErro: (mensagem, contexto) =>
        console.error('[billing] falha ao conceder fichas', mensagem, contexto),
    });

    // Nada aqui e silencioso de proposito: `truncados`, `semPlano` e `comFalha`
    // sao os jeitos de a varredura entregar MENOS do que a politica promete, e
    // uma varredura que corta sem dizer se le como "estava tudo em dia".
    console.info('[billing] entrega mensal de fichas', relatorio);

    // O unico corte possivel e o teto de paginas, e ele grita. `cursor` e o
    // ponto exato de retomada.
    if (!relatorio.esgotou) {
      console.error(
        '[billing] a entrega mensal NAO esgotou a base neste tick',
        { paginas: relatorio.paginas, retomarApos: relatorio.cursor }
      );
    }
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

    const interno = await dependencias().store.refsEntitlement(uid).interno.get();
    const dados = interno.exists ? interno.data() : null;
    if (!dados || !dados.purchaseToken) {
      throw new HttpsError(
        'failed-precondition',
        'Sem token guardado para este jogador: nao ha o que reconsultar.'
      );
    }

    const resultado = await dependencias().reconciliador.reconsultarEAplicar({
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

    // A decisao por documento mora em `migracaoLegado.js`, testavel sem
    // `firebase-functions`. Aqui ficou o portao de admin e a fiacao.
    const relatorio = await migrarPaginaDeLegado({
      db: getFirestore(),
      FieldPath,
      aplicarProposta: (proposta) =>
        dependencias().store.aplicarProposta(proposta),
      ESTADO_VIP,
      agora: new Date().toISOString(),
      cursor: (request.data && request.data.cursor) || null,
      lote: (request.data && request.data.lote) || undefined,
    });

    console.info('[billing] migracao de entitlement legado', relatorio);
    return relatorio;
  }
);

// ===========================================================================
// DIAGNOSTICO DA POPULACAO — antes de migrar
// ===========================================================================

/**
 * Conta quem esta em `usuarios/` e em `playerEntitlements/`, projeta o que a
 * migracao faria com cada um, e mede quantos jogadores perdem a ficha mensal por
 * falta de `purchaseTokenHash`. So admin, e SOMENTE LEITURA.
 *
 * POR QUE ELE E UMA FUNCAO E NAO UMA CONSULTA NO CONSOLE: as respostas que
 * interessam sao cruzamentos entre tres colecoes (`usuarios`, `playerEntitlements`
 * com a subcolecao `interno`, e `compras`), e `interno/billing` esta fechado para
 * cliente E para admin nas regras — so o Admin SDK alcanca. Nao existe consulta
 * de console que responda "quantos vigentes estao sem hash".
 *
 * A GARANTIA DE NAO ESCREVER E ESTRUTURAL, e mora em `diagnosticoPopulacao.js`:
 * o modulo nao recebe `db`, so leitores, e `DIAG-31`/`DIAG-32` provam isso pelo
 * fonte e pelo estado do banco. Esta fiacao nao pode afrouxar a garantia porque
 * `criarPortasFirestore` e quem fala com o `db`, e o corpo dela e so `.get()`.
 *
 * O RETORNO NAO CARREGA IDENTIDADE: contagens, e amostras com `rotulo` (doze
 * caracteres de sha256 do uid). Nenhum uid, nenhum e-mail, nenhum token, nenhum
 * hash de token. O rotulo e deterministico, entao um operador que ja suspeita de
 * uma conta calcula o rotulo dela e confere — sem que a funcao enumere ninguem.
 *
 * `esgotou: false` no retorno significa que o teto de paginas mordeu e que
 * `cursor` e o ponto de retomada; somar os pedacos e responsabilidade de quem
 * chama, e `somarResumos` existe para isso.
 */
exports.diagnosticarPopulacaoVip = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth || request.auth.token.admin !== true) {
      throw new HttpsError('permission-denied', 'Operacao restrita a administracao.');
    }

    const pedido = request.data || {};
    const portas = criarPortasFirestore({ db: getFirestore(), FieldPath });

    const diagnostico = criarDiagnosticoPopulacao({
      ...portas,
      // A correlacao com `compras/` custa uma consulta por jogador. Ela e o que
      // responde se o hash e recuperavel, entao o padrao e LIGADA: desligar por
      // omissao faria o relatorio dizer "nao investigado" justamente na pergunta
      // que motivou a OS. Quem precisa de um censo barato desliga de propria mao.
      lerComprasDoJogador:
        pedido.correlacionarCompras === false ? null : portas.lerComprasDoJogador,
      agora: () => new Date().toISOString(),
    });

    const relatorio = await diagnostico.diagnosticar({
      cursorInicial: pedido.cursor || null,
      tamanhoPagina: pedido.tamanhoPagina || undefined,
      maxPaginas: pedido.maxPaginas || undefined,
      amostrasPorCategoria: pedido.amostrasPorCategoria || undefined,
    });

    // O log leva o resumo, nunca as amostras: rotulo anonimo continua sendo um
    // dado por jogador, e log de producao nao e lugar de lista de gente.
    console.info('[billing] diagnostico da populacao VIP', {
      examinados: relatorio.resumo.examinados,
      esgotou: relatorio.esgotou,
      porCategoria: relatorio.resumo.porCategoria,
      porAlerta: relatorio.resumo.porAlerta,
    });

    return relatorio;
  }
);

// ===========================================================================
// BACKFILL DE `purchaseTokenHash` — recuperar o hash historico de `compras/`
// ===========================================================================

/**
 * Preenche `playerEntitlements/{uid}/interno/billing.purchaseTokenHash` quando o
 * valor pode ser recuperado, sem ambiguidade, da chave historica de
 * `compras/{hash}`. So admin, e DRY-RUN POR PADRAO.
 *
 * POR QUE O HASH E RECUPERAVEL E O TOKEN NAO: `chaveDaCompra` e `sha256(token)`,
 * e o resultado dela E O ID DO DOCUMENTO de `compras/{hash}`. Desde `fe4cdb5` a
 * mesma transacao que gravava `usuarios/{uid}.vip = true` gravava esse registro
 * com o `uid` do comprador. O token em claro, esse sim, nunca foi guardado para
 * as compras antigas, e continua irrecuperavel — mas `concederFichasMensais` nao
 * precisa dele: precisa do hash, e so dele.
 *
 * ISTO NAO E UM PREENCHIMENTO INERTE, e a protecao reflete isso. O campo alimenta
 * `mesmoToken` em `decidirAtualizacao`, entao um `null` que vira valor muda o que
 * o sistema aceita dali em diante. A analise antes/depois esta em
 * `docs/BACKFILL-PURCHASETOKENHASH.md` e fixada em `test/backfillEfeitos.test.js`.
 *
 * AS TRES CAMADAS QUE SEPARAM LER DE ESCREVER
 *
 *   1. `modo` e `'dry_run'` por OMISSAO. Chamar sem argumento nenhum le e conta.
 *   2. escrever exige `modo: 'escrever'` E `confirmacao` com a frase exata. Um
 *      `modo` sozinho nao basta: um cliente administrativo com o campo errado
 *      preenchido por engano nao pode disparar escrita em base de pagante.
 *   3. a porta de escrita so e CONSTRUIDA quando as duas condicoes passam.
 *      `criarBackfillHash` recebe `gravarHash: null` no dry-run, e sem essa porta
 *      nao existe, dentro de `backfillHash.js`, nenhuma expressao capaz de
 *      escrever — a garantia e estrutural, e `BFH-43` a verifica pelo fonte.
 *
 * A AUTORIZACAO OPERACIONAL E SEPARADA DA EXISTENCIA DO CODIGO: o `claim` de
 * admin abre a funcao, e a frase de confirmacao abre a escrita. Quem tem o
 * primeiro nao ganha o segundo de graca.
 *
 * O RETORNO E O LOG NAO CARREGAM IDENTIDADE: contagens, e amostras com
 * `rotuloHash` (oito caracteres, a mesma regra de `rotuloToken`). Nenhum uid,
 * nenhum token, nenhum hash inteiro.
 */
const CONFIRMACAO_DE_ESCRITA = 'EXECUTAR_BACKFILL_PURCHASETOKENHASH';

exports.backfillPurchaseTokenHash = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth || request.auth.token.admin !== true) {
      throw new HttpsError('permission-denied', 'Operacao restrita a administracao.');
    }

    const pedido = request.data || {};
    const querEscrever = pedido.modo === 'escrever';

    if (querEscrever && pedido.confirmacao !== CONFIRMACAO_DE_ESCRITA) {
      throw new HttpsError(
        'failed-precondition',
        'Modo de escrita exige a confirmacao explicita. Rode o dry-run primeiro.'
      );
    }

    const db = getFirestore();
    const portas = criarPortasDeLeitura({ db, FieldPath });

    const backfill = criarBackfillHash({
      ...portas,
      // Sem a correlacao nao ha backfill possivel: e ela que traz o hash. Desligar
      // so serve para medir o custo da varredura, e o relatorio DIZ que nao
      // investigou em vez de concluir "sem fonte".
      lerComprasDoJogador:
        pedido.correlacionarCompras === false ? null : portas.lerComprasDoJogador,
      // A UNICA linha deste arquivo que pode produzir escrita de backfill.
      gravarHash: querEscrever
        ? criarGravadorDeHash({ db, carimbo: () => FieldValue.serverTimestamp() })
            .gravarHash
        : null,
      agora: () => new Date().toISOString(),
      registrarErro: (mensagem, contexto) =>
        console.error('[billing] falha ao examinar jogador no backfill', mensagem, contexto),
    });

    const relatorio = await backfill.executar({
      cursorInicial: pedido.cursor || null,
      tamanhoPagina: pedido.tamanhoPagina || undefined,
      maxPaginas: pedido.maxPaginas || undefined,
      // Teto do LOTE PILOTO. Sem ele a primeira execucao real seria a base
      // inteira, que e exatamente o tipo de decisao que nao da para desfazer.
      maxEscritas: pedido.maxEscritas || undefined,
      amostrasPorClasse: pedido.amostrasPorClasse || undefined,
    });

    // O log leva o resumo, nunca as amostras: rotulo de hash continua sendo um
    // dado por jogador, e log de producao nao e lugar de lista de gente.
    console.info('[billing] backfill de purchaseTokenHash', {
      modo: relatorio.modo,
      examinados: relatorio.examinados,
      porClasse: relatorio.resumo.porClasse,
      escritas: relatorio.resumo.escritas,
      esgotou: relatorio.esgotou,
      parada: relatorio.parada,
    });

    if (!relatorio.esgotou) {
      console.error('[billing] o backfill NAO esgotou a base nesta execucao', {
        parada: relatorio.parada,
        retomarApos: relatorio.cursor,
      });
    }

    return relatorio;
  }
);

// ===========================================================================
// DIAGNOSTICO DOS METADADOS LEGADOS — quem fica APTO a ficha mensal
// ===========================================================================

/**
 * Mede, para cada entitlement, o que falta (`purchaseTokenHash`, `planoBase`,
 * `inicioEm`), o que e recuperavel de fonte historica real, e — a metrica que
 * importa — **quantos ficam aptos ao ciclo mensal de fichas**. So admin, e
 * SOMENTE LEITURA.
 *
 * POR QUE ELE NAO TEM MODO DE ESCRITA, e a ausencia e uma decisao registrada:
 *
 *   `planoBase` e recuperavel (`compras/{hash}.concessao.planoBase`, persistido
 *   desde `767b74a`). `inicioEm` NAO E — nenhuma das cinco geracoes de
 *   `validarCompraPlay` jamais gravou o `startTime` da assinatura, e as duas
 *   datas que `compras/` tem sao carimbos da validacao deste sistema, nao do
 *   inicio na Google.
 *
 *   Sem `inicioEm`, `mesesDecorridos` devolve -1 e NENHUMA parcela vence. Logo,
 *   preencher hash e plano no direito migrado nao entrega uma ficha sequer
 *   (`EFE-13`). Uma rotina de escrita para esses dois campos seria codigo que
 *   altera documento de pagante em troca de zero efeito — e criaria justamente o
 *   mal-entendido que o relatorio existe para evitar ("os campos foram
 *   preenchidos, logo o jogador voltou a receber"). Quando e se `inicioEm` ganhar
 *   uma fonte, a escrita se faz com o padrao ja pronto de `backfillHashStore.js`.
 *
 * A GARANTIA DE NAO ESCREVER E ESTRUTURAL e mora em `recuperacaoMetadados.js`: o
 * modulo nao recebe `db`, so leitores, nao importa nenhum store, e `REC-40` prova
 * isso lendo o proprio fonte. As portas de leitura sao as mesmas de
 * `backfillPurchaseTokenHash`, reusadas em vez de reescritas.
 *
 * O RETORNO NAO CARREGA IDENTIDADE: contagens, e amostras com veredito por campo.
 * Nenhum uid, nenhum token, nenhum hash — nem o rotulo de oito caracteres, que
 * aqui nao serve para nada.
 */
exports.diagnosticarMetadadosLegados = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth || request.auth.token.admin !== true) {
      throw new HttpsError('permission-denied', 'Operacao restrita a administracao.');
    }

    const pedido = request.data || {};
    const portas = criarPortasDeLeitura({ db: getFirestore(), FieldPath });

    const diagnostico = criarDiagnosticoMetadados({
      ...portas,
      // A correlacao com `compras/` e o que responde se o campo e recuperavel.
      // Desligar so serve para medir o custo da varredura, e o relatorio diz
      // "nao investigado" em vez de concluir "sem fonte".
      lerComprasDoJogador:
        pedido.correlacionarCompras === false ? null : portas.lerComprasDoJogador,
      agora: () => new Date().toISOString(),
      registrarErro: (mensagem, contexto) =>
        console.error('[billing] falha ao examinar metadados do jogador', mensagem, contexto),
    });

    const relatorio = await diagnostico.diagnosticar({
      cursorInicial: pedido.cursor || null,
      tamanhoPagina: pedido.tamanhoPagina || undefined,
      maxPaginas: pedido.maxPaginas || undefined,
      amostrasPorClasse: pedido.amostrasPorClasse || undefined,
    });

    console.info('[billing] diagnostico de metadados legados', {
      examinados: relatorio.examinados,
      porClasse: relatorio.resumo.porClasse,
      porBloqueio: relatorio.resumo.porBloqueio,
      aptidao: relatorio.resumo.aptidao,
      esgotou: relatorio.esgotou,
    });

    return relatorio;
  }
);
