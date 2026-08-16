/**
 * economiaStore.js — A ESCRITA da economia basica, com o Firestore injetado.
 *
 * POR QUE ESTE ARQUIVO E SEPARADO DE `economia.js`
 *
 * Mesma fronteira que `functions-billing/fichasStore.js` traca, e pela mesma
 * razao: a politica e o piso sao puros e cabem em teste direto, mas a garantia
 * que importa de verdade — **o mesmo movimento nao acontece duas vezes** — so
 * existe dentro de uma transacao. Deixar essa transacao inline em `index.js` a
 * colocaria justamente onde `node --test` nao alcanca, porque importar
 * `index.js` puxa `firebase-functions` e `firebase-admin`, e este projeto roda
 * os testes sem `node_modules` de proposito.
 *
 * Com o `db` injetado, o Firestore falso de `test/apoio/firestore_falso.js` —
 * que implementa contencao otimista de verdade — consegue provar duas
 * concessoes concorrentes do MESMO bonus, e duas finalizacoes concorrentes da
 * MESMA partida.
 *
 * UM CAMINHO SO PARA TODO MOVIMENTO
 *
 * Boas-vindas, vitoria e derrota passam pela mesma funcao, [_lancar]. Nao ha um
 * caminho "do bonus" e outro "do resultado" que possam divergir com o tempo — ha
 * um, e os tres chamam. O que muda entre eles e o motivo, a chave e o delta
 * nominal; a idempotencia, o piso e a atomicidade sao os mesmos codigo.
 *
 * POR QUE NAO E `FieldValue.increment`
 *
 * Porque `increment(-10)` nao sabe parar no zero. O saldo e LIDO dentro da
 * transacao e gravado como valor absoluto. Isso e seguro sob concorrencia pelo
 * mesmo motivo que a transacao existe: o documento lido entra no conjunto de
 * versoes conferidas no commit, entao um credito de billing que aconteca no meio
 * do caminho invalida esta transacao e ela roda de novo contra o saldo novo. A
 * escrita perdida que o `increment` evita esta evitada aqui pela releitura.
 */

'use strict';

const {
  COL_LEDGER,
  COL_CARTEIRA,
  CAMPO_SALDO,
  CAMPO_SALDO_EM,
  MOTIVO,
  POLITICA,
  chaveBoasVindas,
  chaveResultado,
  saldoLegivel,
  aplicarPiso,
} = require('./economia');

/** Resultados possiveis de um lancamento. */
const EFEITO = Object.freeze({
  /** O movimento aconteceu agora. */
  LANCADO: 'lancado',
  /** Ja havia recibo. Recusa BENIGNA: o efeito desejado ja existe. */
  JA_LANCADO: 'ja_lancado',
  /** O saldo gravado nao e um inteiro >= 0. Nao se move o que nao se entende. */
  CARTEIRA_ILEGIVEL: 'carteira_ilegivel',
  /** Chamada mal formada. Nunca deveria acontecer; falha alta em vez de chute. */
  MAL_FORMADO: 'movimento_mal_formado',
});

/**
 * @param {object} deps
 * @param {object} deps.db        Firestore (Admin SDK) ou equivalente
 * @param {function} deps.carimbo produz o sentinel de timestamp do servidor
 */
function criarCarteira({ db, carimbo }) {
  /**
   * Aplica UM movimento, se ele ainda nao foi aplicado.
   *
   * A linha do livro-razao e a alteracao do saldo sao a MESMA escrita: nao
   * existe instante em que o saldo mudou e o movimento nao esta anotado, nem o
   * contrario. Quem chegar depois le a linha e devolve `ja_lancado` — sem tocar
   * no saldo, e sem erro: repetir e rotina, nao anomalia.
   *
   * O RECIBO E GRAVADO MESMO QUANDO O DELTA EFETIVO E ZERO — o caso de quem
   * perde com a carteira vazia. Aqui isso diverge de `fichasStore.liquidarParcela`,
   * que pula a linha de valor zero, e a diferenca e real: la o zero significa
   * "o catalogo ainda nao disse quanto vale, tente no proximo tick"; aqui o zero
   * e o resultado FINAL e correto da politica de piso, e nao anota-lo deixaria a
   * derrota eternamente pendente de processamento.
   *
   * @returns {Promise<{efeito: string, delta: number, antes: number|null, depois: number|null}>}
   */
  async function _lancar({ chave, uid, motivo, deltaNominal, matchId = null }) {
    if (
      typeof chave !== 'string' || chave.length === 0 ||
      typeof uid !== 'string' || uid.length === 0 ||
      typeof motivo !== 'string' || motivo.length === 0 ||
      !Number.isInteger(deltaNominal)
    ) {
      return { efeito: EFEITO.MAL_FORMADO, delta: 0, antes: null, depois: null };
    }

    const refRecibo = db.doc(`${COL_LEDGER}/${chave}`);
    const refCarteira = db.doc(`${COL_CARTEIRA}/${uid}`);

    return db.runTransaction(async (tx) => {
      // As DUAS leituras antes de qualquer escrita: o Firestore exige isso, e o
      // Firestore falso recusa a ordem inversa para que o teste pegue.
      const recibo = await tx.get(refRecibo);
      const carteira = await tx.get(refCarteira);

      // A LINHA QUE IMPEDE O MOVIMENTO DUPLO. Retry, callback repetido,
      // reconexao, reprocessamento administrativo e duas Functions concorrentes
      // chegam todos aqui.
      if (recibo.exists) {
        return { efeito: EFEITO.JA_LANCADO, delta: 0, antes: null, depois: null };
      }

      const dados = carteira.exists ? carteira.data() : null;
      const antes = saldoLegivel(dados ? dados[CAMPO_SALDO] : undefined);
      if (antes === null) {
        return { efeito: EFEITO.CARTEIRA_ILEGIVEL, delta: 0, antes: null, depois: null };
      }

      const { delta, depois } = aplicarPiso(antes, deltaNominal);

      tx.set(refRecibo, {
        chaveIdempotencia: chave,
        uid,
        motivo,
        // O que a politica mandou cobrar e o que de fato aconteceu. Iguais em
        // todo movimento menos o debito que bateu no piso — e e exatamente esse
        // caso que a auditoria precisa conseguir distinguir de um debito normal.
        deltaNominal,
        delta,
        saldoAntes: antes,
        saldoDepois: depois,
        // `null` quando o movimento nao vem de partida (boas-vindas). Gravado
        // como campo presente, e nao omitido, para a consulta por partida nao
        // ter que distinguir "ausente" de "nao se aplica".
        matchId,
        registradoEm: carimbo(),
      });

      tx.set(
        refCarteira,
        { [CAMPO_SALDO]: depois, [CAMPO_SALDO_EM]: carimbo() },
        { merge: true }
      );

      return { efeito: EFEITO.LANCADO, delta, antes, depois };
    });
  }

  /**
   * O bonus universal de boas-vindas: +100, uma vez por conta, para sempre.
   *
   * Nao recebe valor, nao recebe saldo e nao recebe nenhum sinalizador de "ja
   * recebi" — a secao 3 da OS proibe confiar em booleano do cliente, e a forma
   * de nao confiar e nao ter por onde receber. A unica entrada e o `uid`, que
   * quem chama tira do token verificado.
   *
   * CONTAS PREEXISTENTES entram por esta mesma porta, sem migracao: uma conta
   * criada antes desta OS simplesmente ainda nao tem recibo, entao a primeira
   * chamada credita os 100 dela e a segunda ja nao credita. Nao ha varredura,
   * nao ha alteracao de dado historico, e nao ha janela em que duas execucoes
   * possam creditar duas vezes.
   */
  async function concederBoasVindas({ uid }) {
    return _lancar({
      chave: chaveBoasVindas(uid),
      uid,
      motivo: MOTIVO.BOAS_VINDAS,
      deltaNominal: POLITICA.boasVindas,
    });
  }

  /**
   * Aplica UM movimento de resultado de partida.
   *
   * O `deltaNominal` vem de [movimentosDoResultado], derivado do registro
   * server-owned. Quem chama nao o escolhe — ele repassa.
   */
  async function aplicarMovimentoDePartida({ matchId, uid, motivo, deltaNominal }) {
    if (typeof matchId !== 'string' || matchId.length === 0) {
      return { efeito: EFEITO.MAL_FORMADO, delta: 0, antes: null, depois: null };
    }
    return _lancar({
      chave: chaveResultado(matchId, uid, motivo),
      uid,
      motivo,
      deltaNominal,
      matchId,
    });
  }

  return { concederBoasVindas, aplicarMovimentoDePartida };
}

module.exports = { EFEITO, criarCarteira };
