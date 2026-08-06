/**
 * Decisões de idempotência da validação de compra — lógica pura, sem Firestore.
 *
 * Fica separada de `index.js` porque é aqui que mora o risco de crédito
 * duplicado, e crédito duplicado é o tipo de bug que só aparece em produção,
 * sob concorrência, com dinheiro real envolvido. Sendo puro, dá para testar
 * exaustivamente com `node --test`, sem emulador.
 *
 * Duas garantias:
 *
 * 1. TITULARIDADE — o mesmo `purchaseToken` sempre descreve a mesma compra. Se
 *    chegar amarrado a outro jogador, outro produto ou outro tipo, alguém está
 *    replicando token de terceiro.
 *
 * 2. CRÉDITO ÚNICO — a concessão e a marcação de `concedida` acontecem na MESMA
 *    transação. Quem chegar depois lê `concedida` e devolve o que já foi
 *    concedido, em vez de creditar de novo.
 */

'use strict';

const ESTADO = {
  EM_VALIDACAO: 'em_validacao',
  CONCEDIDA: 'concedida',
  RECUSADA: 'recusada',
};

const ACAO = {
  /** Seguir o fluxo: perguntar à Google e, se valer, conceder. */
  PROSSEGUIR: 'prosseguir',
  /** Reentrega de compra já creditada. Devolve a concessão existente. */
  JA_CONCEDIDA: 'ja_concedida',
  /** Token já analisado e recusado. Não readmite. */
  JA_RECUSADA: 'ja_recusada',
  /** Token existe, mas descreve outra compra. Recusa dura. */
  CONFLITO: 'conflito',
};

/**
 * O registro existente tem que descrever exatamente a compra que chegou.
 *
 * @param {object} registro documento `compras/{hash}` já gravado
 * @param {{uid: string, produtoId: string, assinatura: boolean}} ctx
 */
function conferirTitularidade(registro, ctx) {
  if (registro.uid !== ctx.uid) {
    return { ok: false, motivo: 'token registrado para outro jogador' };
  }
  if (registro.produtoId !== ctx.produtoId) {
    return { ok: false, motivo: 'token registrado para outro produto' };
  }
  if (Boolean(registro.assinatura) !== Boolean(ctx.assinatura)) {
    return { ok: false, motivo: 'token registrado com outro tipo de compra' };
  }
  return { ok: true };
}

/**
 * O que fazer quando o token JÁ tem registro.
 *
 * A ordem importa: titularidade é conferida ANTES do estado. Um token de outro
 * jogador que por acaso esteja `concedida` não pode devolver a concessão alheia.
 */
function decidirSobreRegistroExistente(registro, ctx) {
  const t = conferirTitularidade(registro, ctx);
  if (!t.ok) return { acao: ACAO.CONFLITO, motivo: t.motivo };

  if (registro.estado === ESTADO.CONCEDIDA) {
    return { acao: ACAO.JA_CONCEDIDA, concessao: registro.concessao || {} };
  }
  if (registro.estado === ESTADO.RECUSADA) {
    return { acao: ACAO.JA_RECUSADA, motivo: registro.motivo || 'compra recusada' };
  }
  // `em_validacao`: uma execução anterior morreu no meio, ou há outra em voo.
  // Revalidar é seguro — a Google é a fonte da verdade e a transação final
  // impede o crédito duplo.
  return { acao: ACAO.PROSSEGUIR };
}

/**
 * Guarda da transação FINAL, avaliada com o documento relido dentro dela.
 *
 * É este predicado que impede o crédito duplo sob concorrência: duas execuções
 * simultâneas do mesmo token disputam a transação; o Firestore serializa e faz
 * a perdedora repetir a leitura, e aí ela vê `concedida` e desiste de creditar.
 */
function podeConceder(registro) {
  if (!registro) return true;
  return registro.estado !== ESTADO.CONCEDIDA;
}

module.exports = {
  ESTADO,
  ACAO,
  conferirTitularidade,
  decidirSobreRegistroExistente,
  podeConceder,
};
