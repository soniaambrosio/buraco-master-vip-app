/**
 * backfillHashStore.js — a UNICA escrita do backfill, com o Firestore injetado.
 *
 * POR QUE ELA E SEPARADA DE `backfillHash.js`
 *
 * Mesma fronteira que `entitlement.js` / `entitlementStore.js` e
 * `fichas.js` / `fichasStore.js` ja tracam, e aqui ela tem um papel a mais: e o
 * que faz o dry-run ser incapaz de escrever POR CONSTRUCAO. `backfillHash.js`
 * nao importa este arquivo — quem o injeta e a fiacao, e so quando o operador
 * pede escrita explicitamente. Um dry-run que compartilhasse o caminho de escrita
 * com um booleano dependeria de o booleano estar certo em toda chamada.
 *
 * A PRECONDICAO E RELIDA DENTRO DA TRANSACAO, E NAO HERDADA DA VARREDURA
 *
 * Entre o instante em que a varredura classificou este uid como AUTO e o instante
 * do commit cabem: uma compra nova validada pelo app, uma RTDN, outra execucao do
 * proprio backfill. Confiar na classificacao de fora seria decidir com informacao
 * velha — o mesmo defeito que `aplicarProposta` existe para nao cometer. Entao a
 * transacao RELE tudo de que a decisao depende e reaplica a regra:
 *
 *   1. o entitlement ainda existe;
 *   2. o documento interno ainda existe;
 *   3. `purchaseTokenHash` AINDA esta ausente — e este e o teste de idempotencia
 *      e o de concorrencia ao mesmo tempo. Um campo ja preenchido nunca e
 *      sobrescrito, nem pelo mesmo valor (que seria escrita inutil) nem por outro
 *      (que seria corrupcao silenciosa);
 *   4. o token em claro, se houver, concorda com o hash;
 *   5. `compras/{hash}` ainda existe, ainda e deste uid, ainda e assinatura e
 *      ainda esta `concedida`.
 *
 * O QUE A TRANSACAO NAO RELE, E POR QUE ISSO E SEGURO
 *
 * Ela nao reconta os candidatos: contar exige uma CONSULTA, e a garantia que
 * importa nao depende disso. Se uma segunda compra deste uid nascer depois da
 * classificacao, ela nasce por `validarCompraPlay` — e a proposta dessa validacao
 * chega a `decidirAtualizacao` com `fonte: 'validacao'`, que atravessa
 * `token_superado` por desenho e sobrescreve o hash com o da compra nova. O hash
 * que este backfill gravou nao bloqueia a compra seguinte de ninguem.
 *
 * O QUE ELA ESCREVE, E SO ISSO
 *
 * Tres campos, com `merge: true`, no documento INTERNO. `set` sem merge apagaria
 * `purchaseToken`, `produtoId`, `ultimaVerificacaoEm` e o resto do documento — a
 * regra oposta a de `aplicarProposta`, onde o estado consolidado e completo e o
 * merge e que seria errado. O documento PUBLICO nao e tocado: `purchaseTokenHash`
 * nao mora la, e o jogador nao le nada diferente por causa desta operacao.
 *
 * A procedencia fica gravada (`purchaseTokenHashOrigem`) porque um valor que
 * apareceu por backfill precisa ser distinguivel de um que veio da Play, tanto
 * para auditoria quanto para um eventual rollback: sem a marca, desfazer o
 * backfill exigiria adivinhar quais campos ele criou.
 */

'use strict';

const { COL_ENTITLEMENT, COL_COMPRAS, chaveDaCompra } = require('./entitlementStore');
const { ESTADO: ESTADO_COMPRA } = require('./idempotencia');
const { ehHashValido, ORIGEM_BACKFILL } = require('./backfillHash');

/** Por que o commit recusou. Nenhum destes e erro: sao recusas previstas. */
const RECUSA = {
  ENTRADA_INVALIDA: 'entrada_invalida',
  ENTITLEMENT_AUSENTE: 'entitlement_ausente',
  INTERNO_AUSENTE: 'interno_ausente',
  JA_PREENCHIDO: 'ja_preenchido',
  CONFLITO_NO_COMMIT: 'conflito_no_commit',
  TOKEN_EM_CLARO_DISCORDA: 'token_em_claro_discorda',
  COMPRA_AUSENTE: 'compra_ausente',
  COMPRA_DE_OUTRO_TITULAR: 'compra_de_outro_titular',
  COMPRA_NAO_E_ASSINATURA: 'compra_nao_e_assinatura',
  COMPRA_NAO_CONCEDIDA: 'compra_nao_concedida',
};

const APLICADO = 'hash_preenchido';

/**
 * @param {object} deps
 * @param {object} deps.db        Firestore (Admin SDK) ou equivalente
 * @param {function} deps.carimbo produz o sentinel de timestamp do servidor
 */
function criarGravadorDeHash({ db, carimbo }) {
  /**
   * Grava o hash de UM jogador, se a precondicao ainda valer.
   *
   * @param {{uid: string, hash: string}} args
   * @returns {Promise<{aplicado: boolean, motivo: string}>}
   *   NUNCA lanca por recusa. Uma recusa e informacao — ela vira contagem no
   *   relatorio. Excecao aqui e falha de infraestrutura, e essa sobe.
   */
  async function gravarHash({ uid, hash }) {
    if (typeof uid !== 'string' || !uid || !ehHashValido(hash)) {
      return { aplicado: false, motivo: RECUSA.ENTRADA_INVALIDA };
    }

    const publico = db.collection(COL_ENTITLEMENT).doc(uid);
    const interno = publico.collection('interno').doc('billing');
    const compra = db.collection(COL_COMPRAS).doc(hash);

    return db.runTransaction(async (tx) => {
      const [pub, int, cmp] = await Promise.all([
        tx.get(publico),
        tx.get(interno),
        tx.get(compra),
      ]);

      if (!pub.exists) {
        return { aplicado: false, motivo: RECUSA.ENTITLEMENT_AUSENTE };
      }
      if (!int.exists) {
        return { aplicado: false, motivo: RECUSA.INTERNO_AUSENTE };
      }

      const dados = int.data() || {};

      // Idempotencia e concorrencia, no mesmo teste. Ja preenchido nunca e
      // sobrescrito — e a distincao entre "o mesmo valor" e "outro valor" e
      // reportada, porque a segunda e um incidente e a primeira e rotina.
      if (dados.purchaseTokenHash) {
        return {
          aplicado: false,
          motivo:
            dados.purchaseTokenHash === hash
              ? RECUSA.JA_PREENCHIDO
              : RECUSA.CONFLITO_NO_COMMIT,
        };
      }

      // O token em claro, quando existe, e prova direta. Ele nao autoriza nada
      // sozinho, mas desmente.
      if (dados.purchaseToken && chaveDaCompra(dados.purchaseToken) !== hash) {
        return { aplicado: false, motivo: RECUSA.TOKEN_EM_CLARO_DISCORDA };
      }

      if (!cmp.exists) {
        return { aplicado: false, motivo: RECUSA.COMPRA_AUSENTE };
      }
      const registro = cmp.data() || {};
      if (registro.uid !== uid) {
        return { aplicado: false, motivo: RECUSA.COMPRA_DE_OUTRO_TITULAR };
      }
      if (registro.assinatura !== true) {
        return { aplicado: false, motivo: RECUSA.COMPRA_NAO_E_ASSINATURA };
      }
      if (registro.estado !== ESTADO_COMPRA.CONCEDIDA) {
        return { aplicado: false, motivo: RECUSA.COMPRA_NAO_CONCEDIDA };
      }

      tx.set(
        interno,
        {
          purchaseTokenHash: hash,
          purchaseTokenHashOrigem: ORIGEM_BACKFILL,
          purchaseTokenHashBackfillEm: carimbo(),
        },
        { merge: true }
      );

      return { aplicado: true, motivo: APLICADO };
    });
  }

  return { gravarHash };
}

module.exports = { RECUSA, APLICADO, criarGravadorDeHash };
