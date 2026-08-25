/**
 * mutacoes_chat_ritmo.js — AS SABOTAGENS DO DESTINO DE `chatRitmo/{uid}`.
 *
 * OS 48 — Destino canonico de `chatRitmo/{uid}` na exclusao de conta v1.
 *
 * DADO, E NAO CODIGO. Este arquivo so descreve as mutacoes; quem aplica, roda o
 * portao e julga e `campanha_chat_ritmo.js`. A separacao e a mesma de
 * `ferramentas/composicao/mutacoes_loja.js`, e existe porque uma lista de
 * sabotagens que sabe se executar acaba julgando a si mesma.
 *
 * ===========================================================================
 * O QUE UMA MUTACAO PRECISA DECLARAR
 * ===========================================================================
 *
 *   id        rotulo curto e estavel, citado no laudo.
 *   arquivo   caminho relativo a raiz do repositorio.
 *   de        trecho literal a substituir. TEM DE OCORRER EXATAMENTE UMA VEZ —
 *             o arnes reprova a campanha inteira se a ancora for ambigua ou
 *             ausente, em vez de contar a mutacao como sobrevivente. Foi assim
 *             que uma ancora que casava com o COMENTARIO da remocao, e nao com
 *             o codigo, ja transformou um escape em falso verde noutra OS.
 *   para      o que entra no lugar.
 *   portao    `contafn` (suites puras) ou `contaemu` (emulador).
 *   mata      o que se espera que reprove, em uma linha. Vai para o laudo: uma
 *             mutacao que morre por OUTRO motivo que nao este e um resultado
 *             diferente de "pega", e o laudo tem de permitir enxergar isso.
 *
 * ===========================================================================
 * O QUE ESTA LISTA NAO COBRE, DE PROPOSITO
 * ===========================================================================
 *
 * Mutacao no `firestore.rules` (tirar o bloco `chatRitmo`). Ela DERRUBARIA o
 * cruzamento — mas pelo lado errado: sem a declaracao, a colecao deixa de ser
 * cobrada e a matriz passa a ter um item a mais, o que nenhuma suite reprova.
 * O buraco e real e nao e desta OS: ele vale para as 60 linhas da matriz
 * igualmente, e fecha-lo e mudar o criterio de cobertura, nao o destino de uma
 * colecao. Registrado em docs/EXCLUSAO-DE-CONTA-E-DADOS.md §7.
 */

const SRC_INV = "functions-conta/src/inventario.ts";
const SRC_PLANO = "functions-conta/src/plano.ts";
const SRC_EXEC = "functions-conta/src/executor.ts";

/// O item inteiro, como esta na matriz. Serve de ancora para a remocao (M01) e
/// de referencia para as trocas de campo.
const ITEM_ID = '    id: "moderacao.ritmoDeChat",';

const MUTACOES = [
  // =========================================================================
  // A DECISAO — a matriz
  // =========================================================================
  {
    id: "M01",
    arquivo: SRC_INV,
    de: ITEM_ID,
    para: '    id: "moderacao.ritmoDeChatDesativado",',
    portao: "contafn",
    mata:
      "renomear o item tira `chatRitmo` da cobertura: o cruzamento com firestore.rules volta a acusar a colecao sem destino",
  },
  {
    id: "M02",
    arquivo: SRC_INV,
    de: '    classe: CLASSE.APAGAR,\r\n    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    para: '    classe: CLASSE.RETER,\r\n    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    portao: "contafn",
    mata:
      "a leitura errada mais provavel: `bloqueadoAteMs` parece punicao, e o item e alinhado com a ficha disciplinar",
  },
  {
    id: "M03",
    arquivo: SRC_INV,
    de: '    classe: CLASSE.APAGAR,\r\n    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    para: '    classe: CLASSE.NAO_APLICAVEL,\r\n    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    portao: "contafn",
    mata:
      "a segunda leitura errada: `nao guarda dado de pessoa` — e guarda, pelo menos a chave e o padrao de envio",
  },
  {
    id: "M04",
    arquivo: SRC_INV,
    de: '    classe: CLASSE.APAGAR,\r\n    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    para: '    classe: CLASSE.DESVINCULAR,\r\n    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    portao: "contafn",
    mata:
      "desvincular um documento cuja unica ponte e a CHAVE nao corta nada, e a classe exige `campos` que este item nao tem",
  },
  {
    id: "M05",
    arquivo: SRC_INV,
    de: '    caminho: "chatRitmo/{uid}",',
    para: '    caminho: "chatRitmo/{publicId}",',
    portao: "contafn",
    mata:
      "O DESVIO DO UID, na matriz: uma conta sem identidade publica (caminho normal) nunca teria o freio apagado",
  },
  {
    id: "M06",
    arquivo: SRC_INV,
    de: '    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    para: '    alcance: { modo: "docPorUid", colecao: "chatRitmos" },',
    portao: "contafn",
    mata:
      "um plural a mais no alcance: o item fica declarado, coberto, e apontando para colecao que nao existe",
  },
  {
    id: "M07",
    arquivo: SRC_INV,
    de: '    alcance: { modo: "docPorUid", colecao: "chatRitmo" },',
    para: '    alcance: { modo: "semAcao" },',
    portao: "contafn",
    mata:
      "APAGAR sem dizer como ser encontrado e uma decisao que nao acontece",
  },
  {
    id: "M08",
    arquivo: SRC_INV,
    // A JUSTIFICATIVA INTEIRA, e nao o comeco dela. Trocar so a primeira frase
    // seria MUTANTE EQUIVALENTE: o resto do texto continua citando `sanctions`,
    // `playerModeration` e `limites.dart`, entao o argumento segue escrito e o
    // portao tem razao em nao reprovar. Medido: essa variante escapava, e o
    // escape era do arnes, nao da suite.
    deRegex: '"CONTADOR DE RAJADA[\\s\\S]*?por construcao\\.",',
    para:
      '"Documento operacional do jogador, sem finalidade compartilhada e sem integridade de terceiro a proteger. Apagado na exclusao de conta por decisao desta matriz.",',
    portao: "contafn",
    mata:
      "justificativa longa o bastante para o piso de 40 caracteres e vazia do que decide: sem citar que a ficha disciplinar fica em outro lugar, a decisao nao e defensavel",
  },

  // =========================================================================
  // A ORDEM — o plano
  // =========================================================================
  {
    id: "M09",
    arquivo: SRC_PLANO,
    de: '      "moderacao.ritmoDeChat",\r\n',
    para: "",
    portao: "contafn",
    mata:
      "item classificado e esquecido do plano: a exclusao termina `concluida` sem nunca ter chegado nele",
  },
  {
    id: "M10",
    arquivo: SRC_PLANO,
    de: '    id: "encerrar",\r\n    itens: ["auth.usuario"],',
    para: '    id: "encerrar",\r\n    itens: ["auth.usuario", "moderacao.ritmoDeChat"],',
    portao: "contafn",
    mata:
      "o freio pendurado TAMBEM em `encerrar`: um item realizado por duas etapas, que e como um apagamento vira duas ordens de execucao concorrentes",
  },
  {
    id: "M11",
    arquivo: SRC_PLANO,
    // REORDENA, e nao duplica. A primeira versao desta mutacao inseria a linha
    // antes das mensagens e DEIXAVA a original no fim: o efeito era um item em
    // duas posicoes, pego pelo caso "nenhum item e realizado por duas etapas" —
    // que e outra invariante. Uma mutacao que morre pela invariante errada nao
    // prova que a ORDEM esta guardada.
    deRegex: '"moderacao\\.mensagensDeChat",[\\s\\S]*?"moderacao\\.ritmoDeChat",',
    para:
      '"moderacao.ritmoDeChat",\r\n      "moderacao.mensagensDeChat",\r\n      "moderacao.canaisDeChat",',
    portao: "contafn",
    mata:
      "o freio apagado ANTES da varredura de mensagens alarga a janela em que uma chamada em voo o reescreve",
  },
  {
    id: "M12",
    arquivo: SRC_PLANO,
    de: "as mensagens dele e o contador de rajada.",
    para: "as mensagens dele.",
    portao: "contafn",
    mata:
      "a etapa passa a apagar um dado a mais do que anuncia no log e no relatorio de suporte",
  },

  // =========================================================================
  // O EFEITO — o executor
  // =========================================================================
  {
    id: "M13",
    arquivo: SRC_EXEC,
    de: '  await db().collection("chatRitmo").doc(ctx.uid).delete();\r\n',
    para: "",
    portao: "contaemu",
    mata:
      "A SABOTAGEM QUE REMOVE O TRATAMENTO: matriz, plano e justificativa intactos, e o documento fica",
  },
  {
    id: "M14",
    arquivo: SRC_EXEC,
    de: '  await db().collection("chatRitmo").doc(ctx.uid).delete();',
    para: '  await db().collection("chatRitmo").doc(ctx.publicId ?? ctx.uid).delete();',
    portao: "contaemu",
    mata:
      "A SABOTAGEM QUE DESVIA O UID: apaga o documento de uma chave que o produtor nunca usou",
  },
  {
    id: "M15",
    arquivo: SRC_EXEC,
    de: '  await db().collection("chatRitmo").doc(ctx.uid).delete();',
    para: '  await db().collection("chatRitmo").doc(`${ctx.uid}-ritmo`).delete();',
    portao: "contaemu",
    mata:
      "o desvio do UID por sufixo — a variante que um `id` composto inventado produziria",
  },
  {
    id: "M16",
    arquivo: SRC_EXEC,
    de: '  await db().collection("chatRitmo").doc(ctx.uid).delete();',
    para: '  await db().collection("chatRitmos").doc(ctx.uid).delete();',
    portao: "contaemu",
    mata:
      "a colecao errada no executor: o `delete` de documento inexistente e sucesso, entao a exclusao fica verde e nao apaga nada",
  },
  {
    id: "M17",
    arquivo: SRC_EXEC,
    de: '  await db().collection("chatRitmo").doc(ctx.uid).delete();',
    para: '  await apagarPorConsulta(db().collection("chatRitmo"));',
    portao: "contaemu",
    mata:
      "o excesso: uma varredura sem filtro leva o freio de rajada de TODOS os jogadores junto",
  },
  {
    id: "M18",
    arquivo: SRC_EXEC,
    de: '  await db().collection("chatRitmo").doc(ctx.uid).delete();',
    para:
      '  await db().collection("chatRitmo").doc(ctx.uid).delete();\r\n  await db().collection("playerModeration").doc(ctx.uid).delete();',
    portao: "contaemu",
    mata:
      "a exclusao vira o botao de limpar ficha: junto com o freio sai o estado disciplinar que a doutrina RETEM",
  },
];

module.exports = { MUTACOES, SRC_INV, SRC_PLANO, SRC_EXEC };
