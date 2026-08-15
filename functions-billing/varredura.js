/**
 * varredura.js — percorrer uma colecao INTEIRA, e nao a primeira pagina dela.
 *
 * O DEFEITO QUE ESTE ARQUIVO EXISTE PARA FECHAR
 *
 * `concederFichasMensais` selecionava os assinantes assim:
 *
 *     .where('vipAtivo', '==', true).limit(500).get()
 *
 * Um `.limit()` sem cursor nao e uma pagina: e um TETO. A consulta e ordenada de
 * forma estavel pelo Firestore, entao ela devolve os MESMOS 500 documentos todo
 * dia. O 501o assinante nunca aparece — e como a rotina nao escreve em
 * `playerEntitlements`, nada o tira da frente da fila. Ele nao recebe hoje, nao
 * recebe amanha, e nao recebe nunca. Nao ha erro, nao ha alerta: o log diz
 * "candidatos: 500" e parece saude.
 *
 * Trocar 500 por 5.000 nao conserta isso. Move o teto.
 *
 * A CORRECAO E UM CURSOR, E ELE PRECISA DE ORDEM ESTAVEL
 *
 * Paginar exige ordenar por algo que nao muda e nao repete. `orderBy(expiraEm)`
 * serviria para ordenar, mas dois assinantes com o mesmo instante de vencimento
 * — o que e comum, porque promocoes criam lotes — poderiam trocar de lugar entre
 * uma pagina e outra, e ai um deles seria pulado e o outro visitado duas vezes.
 * O ID do documento nao empata e nao muda: e o unico criterio que garante que a
 * pagina 2 comeca exatamente onde a 1 parou.
 *
 * `where(igualdade) + orderBy(__name__ asc)` e coberto pelo indice de campo
 * unico que o Firestore mantem sozinho — nao exige indice composto declarado. E
 * a mesma forma que `migrarEntitlementsLegado` ja usava; aqui ela deixa de ser
 * privilegio de uma funcao so.
 *
 * ESGOTAMENTO, E NAO CONTAGEM
 *
 * A condicao de parada e "a pagina veio menor que o lote", e nao "ja visitei N".
 * Contar exigiria saber o total antes de comecar — que e justamente a informacao
 * que nao cabe numa query. Uma pagina incompleta e a unica evidencia local de
 * que a colecao acabou.
 *
 * O TETO QUE SOBRA E DECLARADO, NAO SILENCIOSO
 *
 * [maxPaginas] existe para o caso patologico (colecao crescendo mais rapido do
 * que a varredura anda, cursor que nao avanca por defeito de dados). Quando ele
 * morde, a varredura devolve `esgotou: false` e o `cursor` de onde parar — quem
 * chama REGISTRA e pode continuar. Um corte que nao se anuncia se leria como
 * "estava tudo em dia", que e exatamente o defeito que este arquivo corrige.
 *
 * REEXECUCAO E SEGURA POR CONSTRUCAO, e nao por memoria: esta varredura nao
 * guarda checkpoint em lugar nenhum. Rodar de novo visita todo mundo de novo, e
 * quem impede pagamento em dobro e o livro-razao de `fichasStore.js`, cuja chave
 * e deterministica por parcela. Idempotencia mora onde o dinheiro e movido, e
 * nao em quem itera — assim uma interrupcao no meio nao deixa estado pendurado.
 */

'use strict';

/**
 * Documentos por pagina.
 *
 * Cada assinante visitado custa, alem da leitura da pagina, uma leitura do
 * documento interno e ate 24 transacoes. Paginas muito grandes seguram memoria e
 * atrasam o primeiro trabalho util; muito pequenas multiplicam ida e volta. 200
 * e a mesma ordem de grandeza que `reconciliarEntitlements` ja usa por tick.
 */
const TAMANHO_PAGINA = 200;

/**
 * Quantas paginas uma execucao percorre antes de devolver o cursor.
 *
 * 500 paginas x 200 = 100.000 assinantes por execucao — folga larga sobre
 * qualquer base plausivel desta operacao, e ainda assim um numero FINITO, para
 * que um cursor que nao avance por dados corrompidos nao vire laco infinito
 * dentro de uma Cloud Function.
 */
const MAX_PAGINAS = 500;

/**
 * Percorre todos os documentos de uma consulta, pagina a pagina, ate esgotar.
 *
 * @param {object} opcoes
 * @param {function(): object} opcoes.consulta
 *   Produz a consulta BASE (com os `where` ja aplicados) a cada pagina. E uma
 *   funcao, e nao um objeto pronto, porque objetos de consulta do Firestore sao
 *   imutaveis e encadeaveis: reaproveitar um so ja com `startAfter` acumularia
 *   cursores a cada volta.
 * @param {function(object): Promise<void>} opcoes.aoVisitar
 *   Chamado uma vez por documento, com o `QueryDocumentSnapshot`.
 *
 *   UMA EXCECAO AQUI SOBE. Este arquivo nao decide o que e um erro tolerave —
 *   isso depende do que se esta varrendo, e engolir tudo aqui esconderia falha
 *   de infraestrutura atras de um relatorio de sucesso. Quem varre para pagar
 *   (`fichasVarredura.js`) envolve o proprio trabalho num `try`, porque la um
 *   jogador problematico realmente nao pode impedir que os seguintes recebam.
 *
 *   O cursor avanca ANTES da chamada, de modo que mesmo uma excecao que suba
 *   deixa o ponto de retomada depois do documento que a causou.
 * @param {object} [opcoes.FieldPath] Namespace com `documentId()`. Injetado
 *   porque vem do Admin SDK e este arquivo precisa rodar sem ele nos testes.
 * @param {number} [opcoes.tamanhoPagina]
 * @param {number} [opcoes.maxPaginas]
 * @param {*} [opcoes.cursorInicial] Continua de onde uma execucao anterior parou.
 *
 * @returns {Promise<{visitados: number, paginas: number, esgotou: boolean,
 *   cursor: *}>} `esgotou: false` significa que [maxPaginas] mordeu e que
 *   `cursor` aponta o ponto de retomada. NUNCA e um corte silencioso.
 */
async function varrerPaginado({
  consulta,
  aoVisitar,
  FieldPath,
  tamanhoPagina = TAMANHO_PAGINA,
  maxPaginas = MAX_PAGINAS,
  cursorInicial = null,
}) {
  let cursor = cursorInicial;
  let visitados = 0;
  let paginas = 0;

  for (;;) {
    if (paginas >= maxPaginas) {
      return { visitados, paginas, esgotou: false, cursor };
    }

    // A ordenacao entra AQUI, e nao no `where` de quem chama, para que nao
    // exista consulta paginada neste codebase sem criterio estavel.
    let q = consulta().orderBy(FieldPath.documentId()).limit(tamanhoPagina);
    if (cursor) q = q.startAfter(cursor);

    const pagina = await q.get();
    paginas += 1;

    for (const doc of pagina.docs) {
      // O cursor avanca ANTES do trabalho. Se `aoVisitar` estourar, a proxima
      // pagina ainda comeca depois deste documento — e o que impede um
      // documento problematico de prender a varredura num laco.
      cursor = doc.id;
      visitados += 1;
      await aoVisitar(doc);
    }

    // Pagina incompleta e a unica evidencia local de que a colecao acabou.
    if (pagina.size < tamanhoPagina) {
      return { visitados, paginas, esgotou: true, cursor };
    }
  }
}

module.exports = { TAMANHO_PAGINA, MAX_PAGINAS, varrerPaginado };
