/**
 * entitlementStore.js — as ESCRITAS do entitlement, com o Firestore injetado.
 *
 * POR QUE ESTE ARQUIVO NASCEU
 *
 * Ate aqui, `aplicarProposta` e `titularDoToken` moravam dentro de `index.js`,
 * coladas em `getFirestore()`. Isso deixava a parte mais delicada do desenho —
 * a TRANSACAO que decide e marca "ja processei" no mesmo commit — como a unica
 * coisa do codebase que nenhum teste alcancava: importar `index.js` puxa
 * `firebase-functions`, `firebase-admin` e `googleapis`, e este projeto roda
 * `node --test` sem `node_modules` de proposito (ver `package.json`).
 *
 * A correcao nao e "mockar o firebase-admin". E parar de chamar o singleton:
 * `criarStore` recebe o `db` e o carimbo de servidor por parametro. Em producao
 * entram `getFirestore()` e `FieldValue.serverTimestamp()`; no teste entra o
 * Firestore falso de `test/apoio/firestore_falso.js`, que implementa contencao
 * de verdade e por isso consegue provar duas notificacoes concorrentes.
 *
 * NENHUMA REGRA ECONOMICA MUDOU AQUI. O corpo das funcoes e o mesmo que estava
 * em `index.js`; o que mudou foi de onde vem o `db`. As decisoes continuam todas
 * em `entitlement.js`, puras.
 */

'use strict';

const crypto = require('crypto');

const {
  decidirAtualizacao,
  documentosDeEntitlement,
  rotuloToken,
} = require('./entitlement');

/** Fonte canonica do direito VIP. Escrita SO por este codebase. */
const COL_ENTITLEMENT = 'playerEntitlements';

/** Trilha de notificacoes processadas — id do documento = messageId do Pub/Sub. */
const COL_EVENTOS = 'billingEvents';

/** Registro de titularidade que `validarCompraPlay` grava — id = hash do token. */
const COL_COMPRAS = 'compras';

/**
 * Chave do registro de compra. Hash do token porque o token e longo demais
 * para ID de documento do Firestore (limite de 1500 bytes) e nao ha motivo
 * para guardar o valor bruto como identificador.
 *
 * Mora AQUI, e nao em `entitlement.js`, porque isto e identidade de DOCUMENTO:
 * e a chave de `compras/{hash}` e o `purchaseTokenHash` do entitlement. `crypto`
 * e modulo embutido do Node, entao este arquivo continua carregavel por
 * `node --test` sem `node_modules`.
 */
function chaveDaCompra(tokenCompra) {
  return crypto.createHash('sha256').update(tokenCompra).digest('hex');
}

/**
 * @param {object} deps
 * @param {object} deps.db      Firestore (Admin SDK) ou equivalente
 * @param {function} deps.carimbo  produz o sentinel de timestamp do servidor
 */
function criarStore({ db, carimbo }) {
  /**
   * Os dois documentos do entitlement de um jogador.
   *
   *   playerEntitlements/{uid}                   o dono le: estado, prazo, produto
   *   playerEntitlements/{uid}/interno/billing   ninguem le: token e verificacao
   *
   * Dois porque regra do Firestore libera o documento INTEIRO. A separacao repete
   * a que a moderacao fez entre `reports` e `reportReceipts`, pelo mesmo motivo.
   */
  function refsEntitlement(uid) {
    const publico = db.collection(COL_ENTITLEMENT).doc(uid);
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
   * @param {{id: string, tipo?: number|null}} [evento]
   *        notificacao que originou a proposta. Registrada na MESMA transacao: o
   *        efeito e a marca de "ja processei" nascem juntos, ou nao nascem.
   */
  async function aplicarProposta(proposta, evento) {
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
          processadoEm: carimbo(),
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
   * Quem e o dono deste `purchaseToken`?
   *
   * A notificacao da Google traz o token e mais nada sobre identidade — ela nao
   * sabe o que e um UID do Firebase. O elo e o registro que `validarCompraPlay`
   * ja grava em `compras/{hash}`, com o uid tirado do contexto AUTENTICADO da
   * chamada. Sem esse registro nao ha titular comprovavel, e o evento e
   * descartado: atribuir um direito por palpite seria pior que perder o evento.
   *
   * Recebe o HASH ja calculado — quem tem o token cru e o chamador, e nao ha
   * motivo para o valor bruto atravessar mais uma fronteira do que precisa.
   */
  async function titularDoToken(hash) {
    const doc = await db.collection(COL_COMPRAS).doc(hash).get();
    if (!doc.exists) return { ok: false, motivo: 'compra_desconhecida', hash };
    const dados = doc.data();
    if (!dados.uid) return { ok: false, motivo: 'registro_sem_uid', hash };
    if (dados.assinatura !== true) {
      return { ok: false, motivo: 'nao_e_assinatura', hash };
    }
    return { ok: true, uid: dados.uid, produtoId: dados.produtoId || null, hash };
  }

  /**
   * A mensagem ja foi processada ate o fim?
   *
   * Atalho barato, cobrado ANTES de gastar uma chamada de rede. NAO e a barreira
   * de idempotencia — essa esta dentro da transacao de `aplicarProposta`, que e
   * onde a corrida existe de verdade.
   */
  async function eventoConcluido(messageId) {
    if (!messageId) return false;
    const doc = await db.collection(COL_EVENTOS).doc(messageId).get();
    return doc.exists && doc.data().estado === 'concluido';
  }

  /** Anota um evento que nao produziu efeito, para a trilha nao ter buraco. */
  async function registrarEventoSemEfeito(messageId, dados) {
    if (!messageId) return;
    await db.collection(COL_EVENTOS).doc(messageId).set(
      {
        messageId,
        estado: 'concluido',
        aplicado: false,
        processadoEm: carimbo(),
        ...dados,
      },
      { merge: true }
    );
  }

  return {
    refsEntitlement,
    aplicarProposta,
    titularDoToken,
    eventoConcluido,
    registrarEventoSemEfeito,
  };
}

module.exports = {
  COL_ENTITLEMENT,
  COL_EVENTOS,
  COL_COMPRAS,
  chaveDaCompra,
  criarStore,
};
