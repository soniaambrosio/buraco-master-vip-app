// ordenacao.ts — a ordem oficial do ranking e o cursor que a percorre.
//
// DUAS COISAS MORAM AQUI, E ELAS SAO A MESMA COISA VISTA DE DOIS LADOS:
// a ordenacao determinstica (secao 10) e a paginacao por cursor (secao 18). Um
// cursor so funciona se a ordem for total e estavel — com empate sem desempate,
// duas paginas consecutivas repetem ou pulam linhas, e o `dedupe` do cliente
// esconderia o pulo sem corrigi-lo.
//
// ---------------------------------------------------------------------------
// O DESEMPATE, E POR QUE ELE E ESTE
// ---------------------------------------------------------------------------
// A ordem e: `pontos DESC, publicPlayerId ASC`.
//
// O primeiro criterio e o unico competitivo, e ele nao foi inventado aqui —
// "mais pontos vem antes" e o que a propria existencia de uma pontuacao
// significa.
//
// O SEGUNDO E DELIBERADAMENTE NEUTRO. A secao 10 permite exatamente isto quando
// a politica nao existe: "usar somente regra tecnica neutra e claramente
// documentada ou registrar como dependencia de produto". Este arquivo faz as
// duas coisas.
//
// O que `publicPlayerId ASC` garante: ordem TOTAL (dois jogadores nunca empatam,
// porque o id publico e unico), ESTAVEL (o id nao muda entre duas apuracoes) e
// INDEXAVEL (vira o segundo campo do indice composto, e o cursor do Firestore o
// usa como `startAfter`).
//
// O que ele NAO e: uma regra competitiva. Ele nao premia quem jogou menos, quem
// chegou antes, quem tem mais vitorias ou quem tem melhor saldo — qualquer um
// desses seria uma decisao de produto tomada por conta propria, e a secao 10
// proibe. Como o id publico e opaco e atribuido sem relacao com desempenho,
// a ordem entre empatados e arbitraria de proposito: ninguem consegue joga-la
// a favor.
//
// PENDENCIA DE PRODUTO REGISTRADA: qual e o desempate COMPETITIVO oficial
// (confronto direto? mais vitorias? menos partidas? quem atingiu a pontuacao
// primeiro?). Enquanto nao houver decisao, vale o desempate tecnico acima.

/// Uma linha de classificacao, no minimo que a ordenacao precisa conhecer.
export interface ChaveDeOrdem {
  readonly pontos: number;
  readonly publicPlayerId: string;
}

/// Compara duas linhas pela ordem oficial. Negativo = `a` vem antes.
///
/// Existe como funcao, e nao so como indice do Firestore, por duas razoes: a
/// apuracao ordena em memoria dentro de cada lote, e o teste da secao 23
/// ("ordenacao", "desempate") precisa exercitar a regra sem subir emulador.
export function compararOficial(a: ChaveDeOrdem, b: ChaveDeOrdem): number {
  if (a.pontos !== b.pontos) return b.pontos - a.pontos;
  if (a.publicPlayerId < b.publicPlayerId) return -1;
  if (a.publicPlayerId > b.publicPlayerId) return 1;
  return 0;
}

/// Tamanho de pagina. O cliente pede, o servidor limita.
///
/// O teto existe porque `limite` vem do cliente: sem ele, um pedido de 100000
/// viraria a "leitura integral da base" que a secao 19 proibe.
export const PAGINA_PADRAO = 25;
export const PAGINA_MAXIMA = 100;

export function normalizarLimite(bruto: unknown): number {
  const n = typeof bruto === "number" ? Math.floor(bruto) : Number.NaN;
  if (!Number.isFinite(n) || n <= 0) return PAGINA_PADRAO;
  return Math.min(n, PAGINA_MAXIMA);
}

/// O conteudo de um cursor, antes de virar texto opaco.
export interface Cursor {
  readonly versao: number;
  /// O escopo que produziu o cursor (`temporada`, `global`, `amigos`).
  readonly escopo: string;
  /// A temporada que produziu o cursor. Vazio no escopo global, que nao tem uma.
  readonly seasonId: string;
  /// Os valores de `startAfter`, na MESMA ordem dos campos do indice.
  readonly pontos: number;
  readonly publicPlayerId: string;
}

export const VERSAO_CURSOR = 1;

/// Por que um cursor foi recusado.
export type RecusaDeCursor =
  | "formato_invalido"
  | "versao_desconhecida"
  | "escopo_trocado"
  | "temporada_trocada";

export class CursorInvalido extends Error {
  constructor(readonly recusa: RecusaDeCursor, mensagem: string) {
    super(mensagem);
  }
}

/// Serializa o cursor como texto opaco.
///
/// Base64url de JSON. OPACO PARA O CLIENTE, e nao criptografado — a distincao
/// importa: nao ha segredo aqui, so posicao numa lista publica, e fingir sigilo
/// com base64 seria pior que nao ter. O que a opacidade compra e que o cliente
/// nao possa CONSTRUIR um cursor a mao e, com isso, passar a decidir de onde a
/// pagina comeca (o que seria o cliente paginando por conta propria).
///
/// Nao carrega uid, apelido, e-mail nem nada de secao 17: so pontos e id
/// publico, que sao exatamente os dois campos que a proxima consulta precisa.
export function codificarCursor(c: Cursor): string {
  const json = JSON.stringify({
    v: c.versao,
    e: c.escopo,
    s: c.seasonId,
    p: c.pontos,
    i: c.publicPlayerId,
  });
  return Buffer.from(json, "utf8").toString("base64url");
}

/// Le um cursor e CONFERE que ele pertence a esta consulta.
///
/// A conferencia de escopo e de temporada e o ponto do arquivo, e nao uma
/// formalidade. O cliente mantem tres abas independentes, cada uma com o proprio
/// paginador; um cursor da aba "temporada" aplicado a consulta "global" nao
/// falharia sozinho — ele devolveria uma pagina PLAUSIVEL do lugar errado, e o
/// jogador veria uma lista que pula gente sem nenhum sinal de erro.
export function decodificarCursor(
  bruto: unknown,
  esperado: { escopo: string; seasonId: string }
): Cursor {
  if (typeof bruto !== "string" || bruto.length === 0) {
    throw new CursorInvalido("formato_invalido", "cursor deve ser texto nao vazio.");
  }

  let objeto: Record<string, unknown>;
  try {
    const json = Buffer.from(bruto, "base64url").toString("utf8");
    const lido: unknown = JSON.parse(json);
    if (typeof lido !== "object" || lido === null) throw new Error("nao e objeto");
    objeto = lido as Record<string, unknown>;
  } catch {
    throw new CursorInvalido("formato_invalido", "cursor ilegivel.");
  }

  if (objeto.v !== VERSAO_CURSOR) {
    // Um cursor de versao antiga sobrevive a um deploy no bolso do cliente. Ele
    // e recusado em vez de reinterpretado: adivinhar o formato velho e como a
    // pagina erraria em silencio.
    throw new CursorInvalido(
      "versao_desconhecida",
      `cursor de versao ${objeto.v}; esta fonte publica a versao ${VERSAO_CURSOR}.`
    );
  }
  if (objeto.e !== esperado.escopo) {
    throw new CursorInvalido(
      "escopo_trocado",
      `cursor do escopo "${objeto.e}" usado numa consulta de "${esperado.escopo}".`
    );
  }
  if (objeto.s !== esperado.seasonId) {
    throw new CursorInvalido(
      "temporada_trocada",
      `cursor da temporada "${objeto.s}" usado numa consulta de "${esperado.seasonId}".`
    );
  }
  if (typeof objeto.p !== "number" || !Number.isInteger(objeto.p)) {
    throw new CursorInvalido("formato_invalido", "cursor sem pontuacao inteira.");
  }
  if (typeof objeto.i !== "string" || objeto.i.length === 0) {
    throw new CursorInvalido("formato_invalido", "cursor sem identificador publico.");
  }

  return {
    versao: VERSAO_CURSOR,
    escopo: objeto.e,
    seasonId: objeto.s,
    pontos: objeto.p,
    publicPlayerId: objeto.i,
  };
}

/// Decide o cursor da PROXIMA pagina a partir da pagina lida.
///
/// A regra de fim e a que o contrato do cliente descreve: `fim` e afirmacao da
/// fonte, e nao deducao de pagina vazia. Aqui ela sai de um fato do banco — a
/// consulta pediu `limite + 1` documentos e recebeu `limite` ou menos, o que
/// prova que nao ha proxima. Devolver cursor sempre e deixar o cliente descobrir
/// o fim com uma pagina vazia custaria uma ida a rede a cada lista.
export function fecharPagina<T extends ChaveDeOrdem>(
  lidos: ReadonlyArray<T>,
  limite: number,
  escopo: string,
  seasonId: string
): { itens: T[]; cursorProxima: string | null; fim: boolean } {
  const temMais = lidos.length > limite;
  const itens = temMais ? lidos.slice(0, limite) : [...lidos];

  if (!temMais || itens.length === 0) {
    return { itens, cursorProxima: null, fim: true };
  }

  const ultimo = itens[itens.length - 1];
  return {
    itens,
    cursorProxima: codificarCursor({
      versao: VERSAO_CURSOR,
      escopo,
      seasonId,
      pontos: ultimo.pontos,
      publicPlayerId: ultimo.publicPlayerId,
    }),
    fim: false,
  };
}
