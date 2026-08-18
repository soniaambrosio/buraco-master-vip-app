/**
 * rtdn.js — o CAMINHO de uma Real-time Developer Notification da Google Play.
 *
 * A NOTIFICACAO E UM SINAL, NAO UM VEREDITO
 *
 * Fora os dois desfechos terminais (revogacao e anulacao, que a consulta de
 * estado nao expressa), nenhum estado economico e derivado do payload: o que a
 * mensagem faz e mandar PERGUNTAR a Google qual e o estado agora. Confiar no
 * payload seria confiar num evento que pode ter sido emitido antes de outro que
 * ja processamos — e o Pub/Sub nao promete ordem nenhuma.
 *
 * POR QUE ESTE ARQUIVO E SEPARADO DE `index.js`
 *
 * O corpo desta funcao vivia dentro do `onMessagePublished`, onde nenhum teste o
 * alcancava: importar `index.js` puxa `firebase-functions`, `firebase-admin` e
 * `googleapis`, e este projeto roda `node --test` sem `node_modules` de
 * proposito. O caminho mais delicado do Billing era, por isso, o unico sem
 * cobertura — provado so no nivel das funcoes puras que ele chama.
 *
 * Aqui ele recebe as portas por parametro e `index.js` vira o adaptador que liga
 * as portas reais. `test/rtdn.test.js` liga as falsas e exercita os dezoito
 * cenarios da OS, incluindo os tres que so existem NESTA camada: reentrega
 * deduplicada, falha transitoria da Play API e token fora dos logs.
 *
 * TRES ENTREGAS ANORMAIS SAO TRATADAS COMO NORMAIS
 *
 *   repetida       o Pub/Sub entrega "pelo menos uma vez".
 *                  `billingEvents/{messageId}` e escrito na MESMA transacao do
 *                  efeito — ou os dois acontecem, ou nenhum dos dois.
 *   fora de ordem  o carimbo comparado nao e o do evento, e o da CONSULTA que
 *                  produziu a proposta (`decidirAtualizacao`). Um evento antigo
 *                  que chega depois faz uma consulta nova, e consulta nova nunca
 *                  regride.
 *   token velho    a proposta e descartada por `token_superado`: uma expiracao da
 *                  assinatura anterior nao derruba a assinatura atual.
 *
 * PROPAGAR A FALHA E O CONTRATO, NAO UM DESCUIDO
 *
 * Quando a Play Developer API falha, esta funcao DEIXA A EXCECAO SUBIR. O
 * `onMessagePublished` esta declarado com `retry: true`, entao subir e o que
 * transforma a falha em reentrega do Pub/Sub — que e a reconciliacao posterior
 * deste desenho. Engolir o erro aqui produziria o pior resultado possivel: um
 * evento marcado como concluido sem ter concluido nada, e um jogador cujo estado
 * so voltaria a ser conferido no proximo evento que a Google resolvesse mandar.
 * Como o registro de "ja processei" so e gravado JUNTO com o efeito, a reentrega
 * encontra trabalho a fazer. Ver `RTDN-11`.
 */

'use strict';

const {
  consolidarTerminal,
  interpretarNotificacao,
  rotuloToken,
} = require('./entitlement');

const { chaveDaCompra } = require('./entitlementStore');
const { MOTIVO } = require('./propriedade');

/**
 * Motivos que significam "nada foi gravado, e nada sera": propriedade nao
 * resolvida ou resposta malformada. Sao registrados na trilha e encerram o
 * processamento sem efeito — ao contrario de uma falha de rede, que SOBE para o
 * Pub/Sub reentregar.
 */
const MOTIVOS_SEM_EFEITO = new Set([
  MOTIVO.VINCULO_AUSENTE,
  MOTIVO.VINCULO_DESCONHECIDO,
  MOTIVO.VINCULO_DIVERGENTE,
  MOTIVO.RESPOSTA_PLAY_INVALIDA,
]);

/** Log neutro, para quem nao injetar nada. */
const SILENCIO = { info() {}, warn() {}, error() {} };

/**
 * @param {object} portas
 * @param {string} portas.pacote          applicationId esperado
 * @param {object} portas.store           `criarStore(...)`
 * @param {object} portas.reconciliador   `criarReconciliador(...)`
 * @param {object} [portas.log]           `{info, warn, error}`
 */
function criarProcessadorRtdn({ pacote, store, reconciliador, log }) {
  const registro = log || SILENCIO;
  // O relogio saiu daqui: o unico instante que este modulo precisava carimbar
  // era o do desfecho terminal, e ele agora vem junto da consulta autoritativa
  // (`verificarToken`), carimbado ANTES da rede. Dois relogios para o mesmo
  // caminho seriam duas oportunidades de discordar sobre a ordem dos eventos.

  // O applicationId oficial vem da configuracao do backend, e a sua ausencia
  // impede a INICIALIZACAO. Deixar o processador nascer sem pacote faria a
  // conferencia de origem cair para "nao sei comparar", e conferencia que nao
  // sabe comparar e conferencia desligada. Ver o achado M-3.
  if (typeof pacote !== 'string' || pacote === '') {
    throw new Error('criarProcessadorRtdn exige o applicationId oficial');
  }

  /** Encerra sem efeito, deixando a trilha contar por que. */
  async function recusarSemEfeito(messageId, motivo, hash) {
    registro.warn('[billing] RTDN sem propriedade comprovavel', {
      messageId,
      motivo,
      token: rotuloToken(hash),
    });
    await store.registrarEventoSemEfeito(messageId, {
      decisao: motivo,
      token: rotuloToken(hash),
    });
    return { decisao: motivo, aplicado: false };
  }

  /**
   * Processa UMA mensagem do topico RTDN.
   *
   * @param {{messageId: string|null, data: string}} mensagem
   *        `data` e o payload base64 como o Pub/Sub entrega.
   * @returns {Promise<{decisao: string, aplicado?: boolean, uid?: string,
   *                    estado?: string, vipAtivo?: boolean}>}
   *          o retorno existe para o teste; o runtime do Pub/Sub o ignora.
   * @throws  se a consulta autoritativa a Google falhar — ver o cabecalho.
   */
  async function processarNotificacao(mensagem) {
    const msg = mensagem || {};
    const messageId = msg.messageId || null;

    let corpo;
    try {
      corpo = JSON.parse(Buffer.from(msg.data || '', 'base64').toString('utf8'));
    } catch (e) {
      // Mensagem ilegivel nao melhora com retry: registrar e seguir. Repetir uma
      // entrega que nunca vai ser entendida so gastaria a cota do topico.
      //
      // `e.message` NAO ENTRA NO LOG, e isso nao e excesso de zelo. O
      // `SyntaxError` do V8 cita um trecho da entrada — "Unexpected token 'i',
      // \"isto nao e...\" is not valid JSON" —, entao um payload truncado no meio
      // de um `purchaseToken` imprimiria o token no log pela porta dos fundos. O
      // que se precisa saber para diagnosticar e que a mensagem nao era JSON e
      // qual era o tamanho dela; o conteudo nao acrescenta nada e custa um
      // segredo. Ver RTDN-12.
      registro.error('[billing] RTDN ilegivel', {
        messageId,
        erro: e.name,
        bytes: typeof msg.data === 'string' ? msg.data.length : 0,
      });
      await store.registrarEventoSemEfeito(messageId, { decisao: 'corpo_ilegivel' });
      return { decisao: 'corpo_ilegivel', aplicado: false };
    }

    const leitura = interpretarNotificacao(corpo, pacote);

    if (leitura.acao === 'ignorar') {
      registro.info('[billing] RTDN ignorada', { messageId, motivo: leitura.motivo });
      await store.registrarEventoSemEfeito(messageId, { decisao: leitura.motivo });
      return { decisao: leitura.motivo, aplicado: false };
    }

    if (!leitura.purchaseToken) {
      registro.error('[billing] RTDN sem purchaseToken', { messageId });
      await store.registrarEventoSemEfeito(messageId, { decisao: 'sem_token' });
      return { decisao: 'sem_token', aplicado: false };
    }

    // Atalho barato antes de gastar uma chamada de rede. NAO e a barreira de
    // idempotencia — essa esta dentro da transacao, onde a corrida existe.
    if (await store.eventoConcluido(messageId)) {
      registro.info('[billing] RTDN repetida, ja concluida', { messageId });
      return { decisao: 'evento_repetido', aplicado: false };
    }

    // PROPRIEDADE. A Google conhece o token e, desde a preparacao da compra,
    // tambem devolve QUAL CONTA o comprou. E de la que o dono sai agora — nao
    // mais de `compras/{hash}`, que registrava quem tivesse gravado primeiro.
    const hash = chaveDaCompra(leitura.purchaseToken);

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
      // O DONO NAO ESTA NO PAYLOAD, e nunca esteve. Antes ele saia de
      // `compras/{hash}`, ou seja, de quem tivesse apresentado o token primeiro —
      // o achado A-1. Agora sai da consulta autoritativa, como no caminho
      // economico: pergunta-se a Google DE QUEM e a compra, e aplica-se o
      // desfecho que o evento trouxe.
      //
      // O custo e uma consulta que antes nao existia. O beneficio e que um
      // estorno deixa de poder cair no entitlement de quem nao e o dono. A falha
      // de consulta SOBE, como em todo caminho: `retry: true` reentrega, e
      // estorno atrasado e melhor que estorno perdido.
      const dono = await reconciliador.verificarToken(leitura.purchaseToken, null);
      if (!dono.ok) return recusarSemEfeito(messageId, dono.motivo, hash);

      const consultadoEm = dono.consultadoEm;
      const resultado = await store.aplicarProposta(
        {
          uid: dono.uid,
          ...consolidarTerminal(leitura.terminal, consultadoEm),
          produtoId: leitura.produtoId || null,
          origem: 'play',
          purchaseTokenHash: hash,
          purchaseToken: leitura.purchaseToken,
          verificadoEm: consultadoEm,
          eventoEm: leitura.eventoEm,
          eventoTipo: leitura.tipo != null ? leitura.tipo : null,
          fonte: 'rtdn',
        },
        evento
      );
      registro.info('[billing] entitlement encerrado por notificacao', {
        messageId,
        uid: dono.uid,
        estado: leitura.terminal,
        decisao: resultado.motivo,
        token: rotuloToken(hash),
      });
      return {
        decisao: resultado.motivo,
        aplicado: resultado.aplicado,
        uid: dono.uid,
        estado: resultado.estado,
        vipAtivo: resultado.vipAtivo,
      };
    }

    // RECONCILIACAO: pergunta a Google, descobre DE QUEM e, e grava o que ela
    // responder. `uidEsperado` fica nulo de proposito — o RTDN nao tem sessao e
    // nao tem palpite, entao ele ACEITA o dono que a autoridade resolver. E o
    // oposto exato do comportamento antigo, em que ele aceitava o dono que
    // tivesse chegado primeiro.
    const resultado = await reconciliador.reconsultarEAplicar({
      uidEsperado: null,
      produtoId: leitura.produtoId,
      tokenCompra: leitura.purchaseToken,
      fonte: 'rtdn',
      eventoEm: leitura.eventoEm,
      eventoTipo: leitura.tipo != null ? leitura.tipo : null,
      evento,
    });

    // Propriedade nao resolvida ou resposta malformada: nada foi gravado, e nada
    // sera. Vai para a trilha e encerra — ao contrario de falha de rede, que sobe.
    if (MOTIVOS_SEM_EFEITO.has(resultado.motivo)) {
      return recusarSemEfeito(messageId, resultado.motivo, hash);
    }

    registro.info('[billing] entitlement reconciliado por notificacao', {
      messageId,
      uid: resultado.uid || null,
      tipo: leitura.tipo,
      estado: resultado.estado,
      vipAtivo: resultado.vipAtivo,
      decisao: resultado.motivo,
      token: rotuloToken(hash),
    });

    return {
      decisao: resultado.motivo,
      aplicado: resultado.aplicado,
      uid: resultado.uid || null,
      estado: resultado.estado,
      vipAtivo: resultado.vipAtivo,
    };
  }

  return { processarNotificacao };
}

module.exports = { criarProcessadorRtdn };
