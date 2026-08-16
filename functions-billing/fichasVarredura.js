/**
 * fichasVarredura.js — a entrega mensal de fichas para TODOS os assinantes.
 *
 * POR QUE ISTO SAIU DE DENTRO DE `index.js`
 *
 * A decisao que esta rotina toma vale dinheiro em duas direcoes: deixar de pagar
 * quem tem direito, e pagar duas vezes quem ja recebeu. Enquanto ela morava
 * inline no adaptador do Cloud Scheduler, nenhuma das duas era exercitavel —
 * importar `index.js` puxa `firebase-functions`, `firebase-admin` e `googleapis`,
 * e este projeto roda os testes sem `node_modules` de proposito. O resultado
 * pratico foi que o teto de 500 assinantes atravessou a homologacao inteira sem
 * nenhum teste falhar, porque nao havia teste que pudesse falhar.
 *
 * Mesma fronteira que `entitlement.js` / `entitlementStore.js` e
 * `fichas.js` / `fichasStore.js` ja tracam. `index.js` volta a ser o que deve
 * ser: fiacao.
 *
 * O QUE MUDOU NA SELECAO DOS ASSINANTES
 *
 *     ANTES  .where('vipAtivo','==',true).limit(500).get()
 *     AGORA  varrerPaginado(...) sobre a mesma consulta, com cursor por id
 *
 * O `.limit(500)` solto nao era pagina, era teto: a consulta e ordenada de forma
 * estavel, entao ela devolvia os MESMOS 500 documentos todo dia, e a rotina nao
 * escreve em `playerEntitlements` — nada tirava esses 500 da frente da fila. O
 * 501o assinante nunca era visitado, e o log dizia "candidatos: 500", que se le
 * como saude.
 *
 * O QUE NAO MUDOU, E NAO PODIA MUDAR
 *
 * Quanto vale cada parcela, quando ela vence, quem e elegivel: nada disso mora
 * aqui. Continua em `fichas.js` (calendario) e em `configuracao/billing`
 * (politica). Esta OS e sobre ALCANCE, e nao sobre valor.
 *
 * A barreira de idempotencia tambem nao mudou de lugar: e a linha deterministica
 * `fichasConcessoes/{hash}_{indice}`, criada na MESMA transacao que credita o
 * saldo, em `fichasStore.js`. E por isso que reexecutar a varredura no mesmo
 * periodo nao dobra nada, e por isso que uma interrupcao no meio nao precisa de
 * checkpoint: o que protege o dinheiro esta em quem PAGA, e nao em quem itera.
 */

'use strict';

const { planoDoCatalogo, fichasDoIndice, indicesDevidos } = require('./fichas');
const { varrerPaginado, TAMANHO_PAGINA } = require('./varredura');

/**
 * Liquida as parcelas vencidas de todos os assinantes ativos.
 *
 * @param {object} deps
 * @param {object} deps.db                Firestore (Admin SDK) ou equivalente.
 * @param {object} deps.FieldPath         Namespace com `documentId()`.
 * @param {string} deps.colecaoEntitlement
 * @param {object} deps.catalogo          Definicoes de produto ja lidas.
 * @param {string} deps.agora             Instante ISO da execucao.
 * @param {function(string): Promise<object|null>} deps.lerInterno
 *   Devolve o documento interno do jogador (de onde sai o `purchaseTokenHash`),
 *   ou `null`. Injetado porque quem sabe montar essa referencia e o store.
 * @param {function(object): Promise<{creditado: number, motivo: string}>}
 *   deps.liquidarParcela  `fichasStore.liquidarParcela`.
 * @param {function(string, string): boolean} deps.anteriorA
 *   `anteriorA(a, b)` — `a` acontece antes de `b`.
 * @param {function} [deps.registrarErro] Recebe (mensagem, {uid}).
 *
 * @returns {Promise<object>} O relatorio do tick. `esgotou: false` significa que
 *   a varredura parou no teto de paginas e que `cursor` e o ponto de retomada —
 *   nunca um corte silencioso.
 */
async function concederFichasDeTodosOsAssinantes({
  db,
  FieldPath,
  colecaoEntitlement,
  catalogo,
  agora,
  lerInterno,
  liquidarParcela,
  anteriorA,
  registrarErro = () => {},
  tamanhoPagina = TAMANHO_PAGINA,
  maxPaginas,
  cursorInicial = null,
}) {
  let jogadores = 0;
  let parcelas = 0;
  let fichas = 0;
  let truncados = 0;
  let semPlano = 0;
  let comFalha = 0;

  const resultado = await varrerPaginado({
    consulta: () =>
      db.collection(colecaoEntitlement).where('vipAtivo', '==', true),
    FieldPath,
    tamanhoPagina,
    maxPaginas,
    cursorInicial,
    aoVisitar: async (doc) => {
      const uid = doc.id;
      const dados = doc.data();
      try {
        // Prazo vencido nao gera parcela, mesmo com `vipAtivo: true` gravado. A
        // varredura de vencimento roda a cada 30 minutos e fecha esses
        // documentos, mas ela pode nao ter passado ainda — e pagar um mes que o
        // jogador nao pagou e exatamente o erro que nao da para desfazer.
        if (!dados.expiraEm || !anteriorA(agora, dados.expiraEm)) return;

        const plano = planoDoCatalogo(catalogo[dados.produtoId], dados.planoBase);
        if (!plano) {
          semPlano += 1;
          return;
        }

        const interno = await lerInterno(uid);
        const hash = interno ? interno.purchaseTokenHash : null;
        if (!hash) {
          // Sem token nao ha livro-razao estavel para este direito — e sem ele
          // nao existe idempotencia. Direito migrado do legado cai aqui, de
          // proposito: ele nunca teve compra registrada por este codebase.
          semPlano += 1;
          return;
        }

        const { indices, truncado } = indicesDevidos({
          inicioEm: dados.inicioEm,
          agora,
        });
        if (truncado) truncados += 1;

        let creditouAlgo = false;
        for (const indice of indices) {
          const r = await liquidarParcela({
            uid,
            purchaseTokenHash: hash,
            indice,
            fichas: fichasDoIndice(plano, indice),
            produtoId: dados.produtoId || null,
            planoBase: dados.planoBase || null,
            origem: 'agendador',
          });
          if (r.creditado > 0) {
            parcelas += 1;
            fichas += r.creditado;
            creditouAlgo = true;
          }
        }
        if (creditouAlgo) jogadores += 1;
      } catch (e) {
        // Um jogador problematico nao trava a varredura: o tick seguinte tenta
        // de novo, e cada parcela e idempotente. O cursor ja avancou antes
        // desta chamada, entao a pagina seguinte nao volta a este documento.
        comFalha += 1;
        registrarErro(e && e.message ? e.message : String(e), { uid });
      }
    },
  });

  return {
    candidatos: resultado.visitados,
    paginas: resultado.paginas,
    esgotou: resultado.esgotou,
    cursor: resultado.esgotou ? null : resultado.cursor,
    jogadores,
    parcelas,
    fichas,
    truncados,
    semPlano,
    comFalha,
  };
}

module.exports = { concederFichasDeTodosOsAssinantes };
