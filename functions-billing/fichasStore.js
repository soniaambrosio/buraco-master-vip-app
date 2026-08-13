/**
 * fichasStore.js — a ESCRITA das parcelas de fichas, com o Firestore injetado.
 *
 * POR QUE ESTE ARQUIVO E SEPARADO DE `fichas.js`
 *
 * Mesma fronteira que `entitlement.js` / `entitlementStore.js` traca, e pela
 * mesma razao: a conta do calendario e pura e cabe em teste direto, mas a
 * garantia que importa de verdade — **a mesma parcela nao e paga duas vezes** —
 * so existe dentro de uma transacao. Deixar essa transacao inline em `index.js`
 * a colocaria justamente onde `node --test` nao alcanca, porque importar
 * `index.js` puxa `firebase-functions`, `firebase-admin` e `googleapis`, e este
 * projeto roda os testes sem `node_modules` de proposito.
 *
 * Com o `db` injetado, o Firestore falso de `test/apoio/firestore_falso.js` —
 * que implementa contencao otimista de verdade — consegue provar dois ticks
 * concorrentes disputando a MESMA parcela.
 *
 * UM CAMINHO SO PARA TODA PARCELA
 *
 * A ativacao (indice 0) e as mensalidades (indices 1..N) passam por aqui, pela
 * mesma funcao. Nao ha um caminho "da compra" e outro "do agendador" que possam
 * divergir com o tempo — ha um, e os dois chamam. E o que faz o agendador ser
 * capaz de REPARAR uma ativacao que falhou durante a validacao, sem nenhum
 * codigo de reparo existir.
 */

'use strict';

const { COL_FICHAS, chaveConcessao } = require('./fichas');

/**
 * @param {object} deps
 * @param {object} deps.db          Firestore (Admin SDK) ou equivalente
 * @param {function} deps.carimbo   produz o sentinel de timestamp do servidor
 * @param {function(number): any} deps.incremento
 *        produz o sentinel de incremento atomico. Injetado porque
 *        `FieldValue.increment` vem do Admin SDK: soma feita em JavaScript
 *        (ler, somar, gravar) perderia credito sob concorrencia justamente no
 *        caso que esta transacao existe para proteger.
 */
function criarLivroDeFichas({ db, carimbo, incremento }) {
  /**
   * Paga UMA parcela, se ela ainda nao foi paga.
   *
   * A linha do livro-razao e o credito no saldo sao a mesma escrita: nao existe
   * instante em que o saldo subiu e a parcela nao esta anotada, nem o contrario.
   * Quem chegar depois le a linha e devolve `parcela_ja_paga` — sem tocar no
   * saldo, e sem erro: repetir e rotina, nao anomalia.
   *
   * @returns {Promise<{creditado: number, motivo: string}>}
   */
  async function liquidarParcela({
    uid,
    purchaseTokenHash,
    indice,
    fichas,
    produtoId = null,
    planoBase = null,
    origem = 'agendador',
  }) {
    if (!uid || !purchaseTokenHash || !Number.isInteger(indice) || indice < 0) {
      return { creditado: 0, motivo: 'parcela_mal_formada' };
    }
    // Parcela de valor zero nao vira linha: o livro-razao registra pagamento, e
    // uma linha de zero fichas afirmaria que uma parcela foi paga quando nao
    // houve nada a pagar. Se o catalogo passar a valer algo para este indice, o
    // tick seguinte encontra a ausencia e paga.
    if (!Number.isFinite(fichas) || fichas <= 0) {
      return { creditado: 0, motivo: 'parcela_sem_valor' };
    }

    const ref = db.doc(`${COL_FICHAS}/${chaveConcessao(purchaseTokenHash, indice)}`);

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (snap.exists) return { creditado: 0, motivo: 'parcela_ja_paga' };

      tx.set(ref, {
        uid,
        purchaseTokenHash,
        produtoId,
        planoBase,
        indice,
        fichas,
        origem,
        concedidoEm: carimbo(),
      });
      tx.set(
        db.doc(`usuarios/${uid}`),
        { fichas: incremento(fichas), fichasAtualizadoEm: carimbo() },
        { merge: true }
      );

      return { creditado: fichas, motivo: 'parcela_liquidada' };
    });
  }

  return { liquidarParcela };
}

module.exports = { criarLivroDeFichas };
