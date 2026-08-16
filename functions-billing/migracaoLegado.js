/**
 * migracaoLegado.js — transportar para `playerEntitlements/{uid}` os direitos
 * que so existem em `usuarios/{uid}`.
 *
 * POR QUE ISTO SAIU DE DENTRO DE `index.js`
 *
 * Pelo mesmo motivo que a varredura de fichas saiu: e uma decisao que mexe em
 * quem tem acesso pago, e enquanto morava inline no callable ela era
 * inalcancavel por `node --test` — importar `index.js` puxa `firebase-functions`,
 * `firebase-admin` e `googleapis`. A auditoria registrou a ausencia de cobertura
 * como pendencia; ela existia porque nao havia superficie para testar.
 *
 * O QUE ESTE ARQUIVO NAO DECIDE
 *
 * Nada de politica NOVA. Os casos ambiguos que a auditoria levantou — legado
 * `vip: true` SEM prazo, e legado com prazo ja VENCIDO — continuam se
 * comportando exatamente como antes, e agora estao descritos em teste:
 *
 *   sem prazo   nao migra, e e CONTADO em `semPrazo`. Nao da para afirmar que o
 *               direito ainda vale, e afirmar o que nao se sabe e o defeito que
 *               a consolidacao do entitlement veio consertar.
 *   vencido     MIGRA, como `expirado` e `vipAtivo: false`. O documento passa a
 *               contar a verdade em vez de nao existir, e ninguem ganha acesso.
 *
 * As duas leituras comerciais possiveis para o primeiro caso (dar um prazo de
 * cortesia, ou nao migrar) dependem de saber QUANTOS jogadores estao nele, e
 * esse diagnostico e um gate posterior. Registrar o comportamento de hoje em
 * teste e o que impede que ele mude por acidente antes da decisao.
 *
 * POR QUE O DIREITO MIGRADO NAO SABE O PRAZO REAL
 *
 * `compras/{hash}` guarda o HASH do token, nunca o token. Para as compras
 * anteriores a consolidacao nao existe, em lugar nenhum desta arvore, o valor com
 * que se pergunta a Play. A unica informacao disponivel e `vipExpiraEm`, que veio
 * da Google no dia da compra. O direito migrado vale ate esse prazo e nao vale um
 * minuto a mais; se a assinatura renovou, quem repoe o prazo e a proxima
 * notificacao ou a proxima validacao — as duas carregam o token.
 *
 * `origem: 'legado_usuarios'` e `purchaseTokenHash: null` ficam gravados
 * justamente para que esses documentos sejam distinguiveis num relatorio — e sao
 * a razao pela qual a varredura de fichas nao paga parcela a eles: sem token nao
 * ha livro-razao estavel, e sem ele nao ha idempotencia.
 */

'use strict';

const { instante, anteriorA } = require('./entitlement');

/** Tamanho maximo de pagina aceito, para o cliente nao pedir a colecao inteira. */
const LOTE_MAXIMO = 400;
const LOTE_PADRAO = 100;

/**
 * Migra UMA pagina de `usuarios` com `vip: true`.
 *
 * A continuacao e EXPLICITA — quem chama recebe o cursor e decide se pede a
 * proxima pagina. Diferente da varredura de fichas, que roda sozinha no
 * agendador, esta e uma operacao administrativa: quem a executa quer poder
 * parar, conferir o relatorio de uma pagina e so entao seguir.
 *
 * @param {object} deps
 * @param {object} deps.db
 * @param {object} deps.FieldPath          namespace com `documentId()`
 * @param {function(object): Promise<{aplicado: boolean}>} deps.aplicarProposta
 * @param {object} deps.ESTADO_VIP
 * @param {string} deps.agora              instante ISO
 * @param {string|null} [deps.cursor]
 * @param {number} [deps.lote]
 *
 * @returns {Promise<object>} `cursor: null` significa que acabou.
 */
async function migrarPaginaDeLegado({
  db,
  FieldPath,
  aplicarProposta,
  ESTADO_VIP,
  agora,
  cursor = null,
  lote = LOTE_PADRAO,
}) {
  const tamanho = Math.min(Number(lote) || LOTE_PADRAO, LOTE_MAXIMO);

  let consulta = db
    .collection('usuarios')
    .where('vip', '==', true)
    .orderBy(FieldPath.documentId())
    .limit(tamanho);
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
      // que nao se sabe e o defeito que a consolidacao veio consertar.
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

  return {
    examinados: pagina.size,
    migrados,
    jaTinham,
    semPrazo,
    // `null` quando a pagina veio incompleta: acabou.
    cursor: pagina.size === tamanho ? ultimo : null,
  };
}

module.exports = { migrarPaginaDeLegado, LOTE_MAXIMO, LOTE_PADRAO };
