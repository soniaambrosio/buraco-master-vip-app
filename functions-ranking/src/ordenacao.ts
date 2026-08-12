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
// A PENDENCIA DE PRODUTO QUE ESTAVA REGISTRADA AQUI FOI RESOLVIDA. Ate a OS
// anterior, a ordem era `pontos DESC, publicPlayerId ASC` — um criterio
// competitivo e um desempate tecnico neutro, porque nao havia decisao de produto
// sobre o resto. A secao 17 da OS da Politica Competitiva v1 decidiu, e a ordem
// oficial da temporada passou a ter CINCO criterios competitivos:
//
//   1. rating DESC ............ mais rating vem antes;
//   2. vitorias DESC .......... na temporada;
//   3. saldoPontos DESC ....... saldo acumulado das partidas ranqueadas;
//   4. abandonos ASC .......... MENOS abandonos vem antes (unico criterio
//                               ascendente, e por isso o mais facil de inverter
//                               por engano);
//   5. ratingAtingidoEm ASC ... quem chegou ao rating atual PRIMEIRO vem antes.
//
// O SEXTO CAMPO CONTINUA SENDO `publicPlayerId ASC`, E ELE NAO E REGRA
// COMPETITIVA. A secao 17 o permite nominalmente ("se ainda for necessario um
// desempate puramente tecnico posterior para estabilidade de banco/paginacao")
// e impoe duas condicoes que este arquivo cumpre: ele nao e apresentado como
// regra competitiva (esta escrito aqui que nao e) e nao substitui os cinco
// acima (vem depois de todos). Ele existe para uma razao mecanica: sem ordem
// TOTAL, o `startAfter` do cursor nao consegue apontar para um ponto unico da
// lista, e duas paginas consecutivas repetiriam ou pulariam linhas. Como o id
// publico e opaco e atribuido sem relacao com desempenho, ninguem consegue
// joga-lo a favor.
//
// O UID NAO E CRITERIO, e a secao 17 proibe explicitamente que seja. Ele nem
// chega a esta camada.
//
// COMO O CARIMBO DO CRITERIO 5 E CAPTURADO (a secao 17 pede que isto esteja
// documentado): `ratingAtingidoEm` e reescrito com o instante do servidor
// SEMPRE QUE O VALOR DO RATING MUDA, e preservado quando o rating fica igual.
// Entao ele responde literalmente "desde quando este jogador esta neste rating",
// que e o que o criterio pede. Um delta zero (que a v1 nao produz em partida
// valida, mas que uma correcao administrativa poderia) nao reinicia o relogio.
// A consequencia desejada: entre dois jogadores com 1400, vem antes o que chegou
// a 1400 ha mais tempo e se manteve.

// ---------------------------------------------------------------------------
// A ORDEM COMO DADO, E NAO COMO SEQUENCIA DE `if`
// ---------------------------------------------------------------------------
// Os criterios sao declarados UMA vez, nesta lista, e tudo o mais deriva dela: a
// comparacao em memoria, os campos que o cursor carrega, a conferencia de que uma
// pagina veio na ordem certa e a ordem dos `orderBy` da consulta. Quando os seis
// campos estavam espalhados por quatro arquivos, acrescentar um criterio exigia
// lembrar de quatro lugares — e esquecer um deles produz uma paginacao que pula
// linhas em silencio.

export type SentidoDeOrdem = "asc" | "desc";

export interface CriterioDeOrdem {
  /// O nome do campo no MODELO (`ChaveDeOrdem`).
  readonly campo: string;
  /// O nome do campo no DOCUMENTO, quando difere do modelo.
  ///
  /// Existe por causa de um caso so: `rankingPlayers` guarda a pontuacao de vida
  /// inteira em `pontosTotais`, e a leitura a projeta como `pontos`. Sem esta
  /// separacao, ou o `orderBy` apontaria para um campo que nao existe no
  /// documento, ou o cursor leria um campo que nao existe no modelo — e as duas
  /// falhas so aparecem na segunda pagina.
  readonly campoNoBanco?: string;
  readonly sentido: SentidoDeOrdem;
  /// E um criterio COMPETITIVO (secao 17) ou um desempate tecnico?
  readonly competitivo: boolean;
}

/// O nome com que um criterio e consultado no Firestore.
export function campoNoBanco(criterio: CriterioDeOrdem): string {
  return criterio.campoNoBanco ?? criterio.campo;
}

/// A ordem oficial da classificacao de temporada (secao 17).
export const ORDEM_TEMPORADA: ReadonlyArray<CriterioDeOrdem> = [
  { campo: "pontos", sentido: "desc", competitivo: true },
  { campo: "vitorias", sentido: "desc", competitivo: true },
  { campo: "saldoPontos", sentido: "desc", competitivo: true },
  { campo: "abandonos", sentido: "asc", competitivo: true },
  { campo: "ratingAtingidoEm", sentido: "asc", competitivo: true },
  { campo: "publicPlayerId", sentido: "asc", competitivo: false },
];

/// A ordem do agregado de vida inteira (o escopo `global` das abas do cliente).
///
/// DELIBERADAMENTE DIFERENTE, e nao um esquecimento: os cinco criterios da secao
/// 17 sao definidos para "a ordenacao oficial da TEMPORADA". `rankingPlayers`
/// nao e uma classificacao de temporada — e um acumulado de vida inteira, sem
/// vitorias por temporada, sem saldo por temporada e sem o carimbo de "atingiu
/// este rating primeiro" (que so faz sentido dentro de uma temporada). Aplicar
/// os cinco criterios aqui exigiria inventar o significado de cada um fora do
/// recorte em que a OS os definiu.
export const ORDEM_GLOBAL: ReadonlyArray<CriterioDeOrdem> = [
  { campo: "pontos", campoNoBanco: "pontosTotais", sentido: "desc", competitivo: true },
  { campo: "publicPlayerId", sentido: "asc", competitivo: false },
];

/// Uma linha de classificacao, no minimo que a ordenacao precisa conhecer.
///
/// Os campos do desempate tem default no leitor (`standingDeDoc`), entao uma
/// linha gravada antes desta OS ordena como se tivesse zero vitorias, zero saldo
/// e zero abandono — que e a leitura correta de "nao ha registro disso".
export interface ChaveDeOrdem {
  readonly pontos: number;
  readonly vitorias: number;
  readonly saldoPontos: number;
  readonly abandonos: number;
  readonly ratingAtingidoEm: string;
  readonly publicPlayerId: string;
}

/// Le de uma linha o valor de um campo de ordenacao.
///
/// Centralizado para que a comparacao em memoria e a montagem do cursor leiam o
/// MESMO campo — se as duas divergirem, o cursor aponta para um lugar que a
/// ordem nao reconhece.
export function valorDoCriterio(
  linha: ChaveDeOrdem,
  criterio: CriterioDeOrdem
): number | string {
  switch (criterio.campo) {
    case "pontos":
      return linha.pontos;
    case "vitorias":
      return linha.vitorias;
    case "saldoPontos":
      return linha.saldoPontos;
    case "abandonos":
      return linha.abandonos;
    case "ratingAtingidoEm":
      return linha.ratingAtingidoEm;
    case "publicPlayerId":
      return linha.publicPlayerId;
    default:
      throw new Error(`criterio de ordem desconhecido: ${criterio.campo}`);
  }
}

/// Compara duas linhas por uma ordem qualquer. Negativo = `a` vem antes.
///
/// Existe como funcao, e nao so como indice do Firestore, por duas razoes: a
/// apuracao confere a ordem de cada lote em memoria, e os testes de desempate
/// precisam exercitar a regra sem subir emulador.
///
/// O CARIMBO E COMPARADO COMO TEXTO, e isso e correto e nao preguica: ISO-8601
/// em UTC com casas fixas ordena lexicograficamente na mesma ordem em que ordena
/// cronologicamente. E tambem como o Firestore o ordena, entao a comparacao em
/// memoria e a do banco concordam — que e o requisito de verdade aqui.
export function compararPor(
  ordem: ReadonlyArray<CriterioDeOrdem>,
  a: ChaveDeOrdem,
  b: ChaveDeOrdem
): number {
  for (const criterio of ordem) {
    const va = valorDoCriterio(a, criterio);
    const vb = valorDoCriterio(b, criterio);
    if (va === vb) continue;
    const antes = va < vb ? -1 : 1;
    return criterio.sentido === "asc" ? antes : -antes;
  }
  return 0;
}

/// Compara duas linhas pela ordem oficial da temporada.
export function compararOficial(a: ChaveDeOrdem, b: ChaveDeOrdem): number {
  return compararPor(ORDEM_TEMPORADA, a, b);
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
  /// Os valores de `startAfter`, na MESMA ordem dos criterios do escopo.
  ///
  /// LISTA, E NAO CAMPOS NOMEADOS, porque os dois escopos ordenam por listas de
  /// tamanhos diferentes (seis criterios na temporada, dois no global). Com
  /// campos fixos, o cursor do global carregaria quatro valores sem sentido e a
  /// forma nao diria mais qual e a ordem que ela representa.
  readonly chaves: ReadonlyArray<number | string>;
}

/// VERSAO 2: a v1 carregava `{p, i}` (pontos e id publico), que eram os dois
/// unicos criterios da ordem antiga. Com os cinco criterios competitivos da
/// secao 17, um cursor v1 aplicado a ordem nova apontaria para o lugar errado —
/// entao ele e RECUSADO (`versao_desconhecida`), e nao reinterpretado. O cliente
/// trata a recusa recomecando a lista, que e barato e correto; adivinhar o
/// formato velho produziria uma pagina plausivel e errada.
export const VERSAO_CURSOR = 2;

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
    k: c.chaves,
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
  esperado: { escopo: string; seasonId: string; ordem: ReadonlyArray<CriterioDeOrdem> }
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
  // A ARIDADE E CONFERIDA CONTRA A ORDEM DO ESCOPO. Um cursor com menos valores
  // do que a consulta tem criterios faria o `startAfter` do Firestore posicionar
  // por um prefixo — o que devolve uma pagina que COMECA no lugar plausivel e
  // repete linhas. Com mais valores, o Firestore recusaria a consulta inteira.
  const chaves = objeto.k;
  if (!Array.isArray(chaves) || chaves.length !== esperado.ordem.length) {
    throw new CursorInvalido(
      "formato_invalido",
      `cursor com ${Array.isArray(chaves) ? chaves.length : "nenhum"} valor(es) numa ` +
        `ordem de ${esperado.ordem.length} criterio(s).`
    );
  }
  for (let i = 0; i < chaves.length; i++) {
    const valor = chaves[i];
    const campo = esperado.ordem[i].campo;
    if (typeof valor === "number") {
      if (!Number.isInteger(valor)) {
        throw new CursorInvalido("formato_invalido", `cursor: "${campo}" nao e inteiro.`);
      }
      continue;
    }
    if (typeof valor !== "string") {
      throw new CursorInvalido(
        "formato_invalido",
        `cursor: "${campo}" nao e numero nem texto.`
      );
    }
  }

  return {
    versao: VERSAO_CURSOR,
    escopo: objeto.e,
    seasonId: objeto.s,
    chaves: chaves as ReadonlyArray<number | string>,
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
  seasonId: string,
  ordem: ReadonlyArray<CriterioDeOrdem>
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
      // Os valores saem da MESMA funcao que a comparacao usa, na MESMA ordem dos
      // criterios — e o que garante que o `startAfter` caia exatamente onde a
      // pagina parou.
      chaves: ordem.map((c) => valorDoCriterio(ultimo, c)),
    }),
    fim: false,
  };
}
