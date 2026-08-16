// temporadas.ts — a temporada como ENTIDADE, e as decisoes sobre ela como
// funcoes puras.
//
// SECAO 12: "A temporada vigente nao deve ser inferida no cliente." Antes desta
// OS, ela nao era inferida em lugar nenhum — simplesmente nao existia. O que
// existia era a palavra `temporada` como CAMPO DE TEXTO em
// `annualQualifications` e `closingInvites`, do Motor de Torneios, que a usa
// como rotulo de agrupamento anual.
//
// AS DUAS NAO FORAM UNIFICADAS, e isso e deliberado: o `temporada` de torneios
// agrupa edicoes para o convite de encerramento, e a temporada de ranking
// delimita uma classificacao. Fundir as duas exigiria decidir que a virada do
// ranking acontece junto com o encerramento anual de torneios — que e decisao de
// produto e nao consta em lugar nenhum. Ficam separadas, e a pendencia esta
// registrada no relatorio.
//
// O QUE ESTE ARQUIVO NAO DECIDE, porque e produto (secao 13):
//   * quanto tempo dura uma temporada;
//   * se a pontuacao zera, e reduzida ou e mantida na virada;
//   * se a liga da temporada anterior influencia a proxima;
//   * o que acontece com quem nao jogou.
// A unica coisa que ele afirma sobre a virada e a que a secao 13 EXIGE: ela e
// idempotente e nao apaga o passado.

import { PoliticaDeRanking, POLITICA_PENDENTE, politicaDeJson } from "./politica";

export const STATUS_TEMPORADA = ["planejada", "vigente", "encerrada"] as const;
export type StatusTemporada = (typeof STATUS_TEMPORADA)[number];

export interface Temporada {
  readonly seasonId: string;
  readonly nome: string;
  /// ISO-8601 UTC.
  readonly inicioEm: string;
  /// ISO-8601 UTC. `null` quando a temporada e aberta sem data de termino
  /// decidida — que e o caso hoje, e e informacao, nao lacuna.
  readonly fimEm: string | null;
  readonly status: StatusTemporada;
  readonly politica: PoliticaDeRanking;
  /// Qual escada de ligas vale nesta temporada. Vazio = nenhuma.
  readonly ladderId: string;
  readonly abertaEm: string | null;
  readonly fechadaEm: string | null;
  /// Carimbo da ultima apuracao de posicoes.
  readonly ultimaApuracaoId: string | null;
  readonly ultimaApuracaoEm: string | null;
  readonly jogadoresClassificados: number;
}

export function temporadaDeJson(raw: unknown): Temporada | null {
  if (typeof raw !== "object" || raw === null) return null;
  const o = raw as Record<string, unknown>;
  if (typeof o.seasonId !== "string" || o.seasonId.length === 0) return null;
  const status = `${o.status}`;
  if (!(STATUS_TEMPORADA as ReadonlyArray<string>).includes(status)) return null;

  const texto = (campo: string): string | null =>
    typeof o[campo] === "string" ? (o[campo] as string) : null;

  return {
    seasonId: o.seasonId,
    nome: typeof o.nome === "string" ? o.nome : o.seasonId,
    inicioEm: texto("inicioEm") ?? "",
    fimEm: texto("fimEm"),
    status: status as StatusTemporada,
    politica: politicaDeJson(o.politica),
    ladderId: typeof o.ladderId === "string" ? o.ladderId : "",
    abertaEm: texto("abertaEm"),
    fechadaEm: texto("fechadaEm"),
    ultimaApuracaoId: texto("ultimaApuracaoId"),
    ultimaApuracaoEm: texto("ultimaApuracaoEm"),
    jogadoresClassificados:
      typeof o.jogadoresClassificados === "number" ? o.jogadoresClassificados : 0,
  };
}

// ---------------------------------------------------------------------------
// ABERTURA
// ---------------------------------------------------------------------------

export type RecusaDeAbertura =
  | "id_vazio"
  | "ja_existe"
  | "outra_vigente"
  | "intervalo_invertido";

export interface DecisaoDeAbertura {
  readonly aceita: boolean;
  readonly recusa: RecusaDeAbertura | null;
  readonly detalhe: string | null;
}

/// Decide se uma temporada pode ser aberta.
///
/// A regra que importa e "no maximo UMA vigente por vez", e ela nao e cosmetica:
/// com duas vigentes, `temporadaVigente()` teria que escolher, e escolheria pela
/// ordem em que o Firestore devolveu — ou seja, o jogador veria uma
/// classificacao diferente conforme a hora do dia.
///
/// Funcao PURA: recebe o estado, devolve o veredito. Quem grava e index.ts,
/// dentro de transacao, para que a leitura que fundamenta esta decisao e a
/// escrita que decorre dela nao tenham uma segunda abertura no meio.
export function decidirAbertura(params: {
  seasonId: string;
  inicioEm: string;
  fimEm: string | null;
  jaExiste: boolean;
  vigenteAtual: string | null;
}): DecisaoDeAbertura {
  const { seasonId, inicioEm, fimEm, jaExiste, vigenteAtual } = params;

  if (seasonId.length === 0) {
    return recusarAbertura("id_vazio", "temporada precisa de identificador.");
  }
  if (jaExiste) {
    // Reabrir uma temporada existente sobrescreveria a politica com que ela
    // pontuou, e o ledger dela ficaria explicado por uma regra que nao valia na
    // epoca — exatamente o que o campo `politica` do lancamento existe para
    // evitar.
    return recusarAbertura("ja_existe", `a temporada ${seasonId} ja existe.`);
  }
  if (vigenteAtual !== null && vigenteAtual !== seasonId) {
    return recusarAbertura(
      "outra_vigente",
      `a temporada ${vigenteAtual} ainda esta vigente; encerre-a antes de abrir ${seasonId}.`
    );
  }
  if (fimEm !== null && fimEm <= inicioEm) {
    return recusarAbertura(
      "intervalo_invertido",
      `a temporada ${seasonId} terminaria em ${fimEm}, antes de comecar em ${inicioEm}.`
    );
  }
  return { aceita: true, recusa: null, detalhe: null };
}

function recusarAbertura(recusa: RecusaDeAbertura, detalhe: string): DecisaoDeAbertura {
  return { aceita: false, recusa, detalhe };
}

/// O documento de uma temporada recem-aberta.
///
/// `politica` entra como PENDENTE quando o chamador nao informa uma, e nao como
/// um id inventado. Uma temporada vigente com politica pendente e um estado
/// legitimo e visivel: ela acumula partidas em `rankingBacklog` e nao pontua
/// ninguem, ate que a regra exista.
export function temporadaNova(params: {
  seasonId: string;
  nome: string;
  inicioEm: string;
  fimEm: string | null;
  politica?: PoliticaDeRanking;
  ladderId?: string;
  agora: string;
}): Temporada {
  return {
    seasonId: params.seasonId,
    nome: params.nome.length > 0 ? params.nome : params.seasonId,
    inicioEm: params.inicioEm,
    fimEm: params.fimEm,
    status: "vigente",
    politica: params.politica ?? POLITICA_PENDENTE,
    ladderId: params.ladderId ?? "",
    abertaEm: params.agora,
    fechadaEm: null,
    ultimaApuracaoId: null,
    ultimaApuracaoEm: null,
    jogadoresClassificados: 0,
  };
}

// ---------------------------------------------------------------------------
// ENCERRAMENTO (secao 13)
// ---------------------------------------------------------------------------

export type ResultadoDeEncerramento =
  | "encerrada"
  | "ja_encerrada"
  | "inexistente";

export interface DecisaoDeEncerramento {
  readonly resultado: ResultadoDeEncerramento;
  /// A segunda execucao e SUCESSO, nao falha. Quem chamou deve responder ok.
  readonly idempotente: boolean;
  readonly detalhe: string | null;
}

/// Decide o encerramento de uma temporada.
///
/// SECAO 13, ITEM POR ITEM, e onde cada garantia mora:
///
///   nao duplicar premiacao ..... esta OS nao premia; `rewardGrants` e do Motor
///                                de Torneios e nao foi tocado.
///   nao duplicar Hall .......... `hallEntries` nao recebe escrita automatica
///                                (secao 14: nao fabricar vencedor).
///   nao apagar resultado ....... o encerramento NAO escreve em
///                                `rankingStandings`. As linhas da temporada
///                                ficam onde estao, e a chave delas carrega o
///                                `seasonId` — a temporada seguinte grava em
///                                documentos com OUTRO id e nao tem como
///                                sobrescrever a anterior.
///   nao reinicializar duas vezes  esta funcao nao reinicializa NENHUMA vez:
///                                zerar, reduzir ou carregar pontuacao entre
///                                temporadas e decisao de produto que nao
///                                existe. A temporada nova comeca vazia porque
///                                nao ha linha com o id dela ainda, o que e
///                                consequencia da modelagem e nao uma politica
///                                escolhida aqui.
///
/// A idempotencia real e de banco (`rankingTasks/{seasonId|encerramento}`); esta
/// funcao e a decisao que a acompanha.
export function decidirEncerramento(params: {
  temporada: Temporada | null;
}): DecisaoDeEncerramento {
  const t = params.temporada;
  if (t === null) {
    return { resultado: "inexistente", idempotente: false, detalhe: "temporada desconhecida." };
  }
  if (t.status === "encerrada") {
    return {
      resultado: "ja_encerrada",
      idempotente: true,
      detalhe: `a temporada ${t.seasonId} ja foi encerrada em ${t.fechadaEm}.`,
    };
  }
  return { resultado: "encerrada", idempotente: false, detalhe: null };
}

/// A temporada depois do encerramento. Nao mexe em nada alem de status e carimbo.
export function temporadaEncerrada(t: Temporada, agora: string): Temporada {
  return { ...t, status: "encerrada", fechadaEm: agora };
}

// ---------------------------------------------------------------------------
// A FAIXA DE TEMPO QUE O CLIENTE EXIBE
// ---------------------------------------------------------------------------

/// Texto pronto da contagem regressiva ("Temporada acaba em 12d 6h").
///
/// POR QUE O SERVIDOR FORMATA ISTO, se formatar e trabalho de cliente: porque o
/// contrato do cliente pede assim, e por um motivo bom. `RankingResumo.faixaTempo`
/// diz "Texto pronto da temporada. O cliente nao calcula prazo de temporada" — e
/// o cliente nao pode mesmo: o relogio do aparelho e do jogador, e um aparelho
/// adiantado mostraria a temporada acabando antes. A conta e feita contra o
/// relogio do servidor.
///
/// Isto e FORMATACAO, e nao regra competitiva: nao decide quando a temporada
/// acaba, so escreve por extenso a data que a temporada ja carrega.
export function faixaDeTempo(t: Temporada, agora: Date): string {
  if (t.status === "encerrada") return "Temporada encerrada";
  if (t.fimEm === null) return "";

  const fim = Date.parse(t.fimEm);
  if (Number.isNaN(fim)) return "";

  const restante = fim - agora.getTime();
  if (restante <= 0) return "Temporada encerrada";

  const horasTotais = Math.floor(restante / 3_600_000);
  const dias = Math.floor(horasTotais / 24);
  const horas = horasTotais % 24;

  if (dias > 0) return `Temporada acaba em ${dias}d ${horas}h`;
  if (horas > 0) {
    const minutos = Math.floor((restante % 3_600_000) / 60_000);
    return `Temporada acaba em ${horas}h ${minutos}min`;
  }
  const minutos = Math.max(1, Math.floor(restante / 60_000));
  return `Temporada acaba em ${minutos}min`;
}
