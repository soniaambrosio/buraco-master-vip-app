// resultado.ts — le o RESULTADO OFICIAL da partida e decide se ele pontua.
//
// ONDE ESTA A FONTE OFICIAL, que foi a primeira pergunta da secao 5.1:
//
//   documento .... `matches/{matchId}`
//   quem escreve . `registrarEncerramentoPartida`, em
//                  functions/src/rastreabilidade.ts, exigindo o claim
//                  `motorDePartidas` ou `admin`
//   quem produz .. o servidor de partidas Node/Railway, que monta o plano de
//                  encerramento com o MESMO dominio Dart que o app executa
//                  (app/lib/rastreabilidade/)
//   formato ...... `RegistroDePartida.toJson()`, em
//                  app/lib/rastreabilidade/registro_partida.dart
//   o cliente ..... nao escreve. `firestore.rules` nega `write` em `matches` sem
//                  nenhuma excecao, e nega ate a LEITURA para quem nao e admin.
//
// ESTE ARQUIVO NAO REINTERPRETA O DESFECHO. Quem venceu, se a partida valeu, se
// houve abandono — tudo isso ja foi decidido pela autoridade da partida e esta
// gravado. Aqui so se LE. Redecidir qualquer um desses pontos criaria uma segunda
// opiniao sobre o resultado, e duas opinioes sobre quem venceu e o pior defeito
// que um ranking pode ter.
//
// A UNICA coisa que este arquivo decide e se o registro ENTRA no ranking. Ate a
// OS anterior, o criterio era um campo so: `alteraRanking`, que o dominio Dart
// calcula como `identidade.alteraRanking && estado.valeu` e denormaliza na
// gravacao.
//
// A OS DA POLITICA COMPETITIVA V1 ACRESCENTOU UM SEGUNDO CRITERIO, e a razao e
// que os dois nao perguntam a mesma coisa:
//
//   alteraRanking .......... "esta partida produz lancamento no ledger
//                            competitivo?" — e ela e `publicaRanqueada ||
//                            torneio`;
//   ambiente competitivo ... "esta partida alimenta o RATING DE TEMPORADA?" — e
//                            a secao 6 respondeu que torneio NAO.
//
// Continuar usando so o primeiro faria toda partida de torneio pontuar Elo. Os
// dois sao aplicados em serie, e nenhum substitui o outro. `alteraRanking`
// continua sendo a unica fonte de "isto vale ledger", como o Dart afirma; o
// ambiente competitivo e um recorte MAIS ESTREITO dentro dela.

import { AMBIENTE_COMPETITIVO, noAmbienteCompetitivo } from "./competicao";

/// Um competidor, como o registro oficial o descreve.
export interface CompetidorOficial {
  readonly userId: string;
  /// O lado da mesa. `null` quando o registro nao o declara.
  readonly lado: string | null;
}

/// O recorte de `matches/{matchId}` que o ranking consome.
export interface ResultadoOficial {
  readonly matchId: string;
  readonly estado: string;
  readonly tipo: string;
  readonly alteraRanking: boolean;
  readonly motivoEncerramento: string | null;
  readonly ladoVencedor: string | null;
  readonly encerradaEm: string | null;
  readonly competidores: ReadonlyArray<CompetidorOficial>;
  readonly placar: ReadonlyArray<{
    readonly lado: string;
    readonly pontos: number;
    readonly canastrasLimpas: number;
  }>;
}

/// Estados terminais. Espelha `EstadoDaPartida.terminal` do Dart e a funcao
/// `ehTerminal` de functions/src/rastreabilidade.ts — este e o QUARTO ponto da
/// duplicacao declarada no cabecalho de ledger.ts.
const TERMINAIS = ["finalizada", "abandonada", "cancelada"];

export function estadoTerminal(estado: string): boolean {
  return TERMINAIS.includes(estado);
}

/// Le o documento oficial.
///
/// Devolve `null` quando o documento nao tem a forma minima. Nao lanca: o
/// gatilho recebe QUALQUER escrita em `matches`, inclusive as de abertura de
/// partida, e transformar "ainda nao e um resultado" em erro encheria o log de
/// falha para o funcionamento normal.
export function resultadoDeJson(raw: unknown): ResultadoOficial | null {
  if (typeof raw !== "object" || raw === null) return null;
  const o = raw as Record<string, unknown>;

  const matchId = o.matchId;
  const estado = o.estado;
  if (typeof matchId !== "string" || matchId.length === 0) return null;
  if (typeof estado !== "string" || estado.length === 0) return null;

  // `participantes` traz humanos, robos e espectadores. So humanos com userId
  // competem e pontuam — a regra e `ClasseDeParticipante.pontuavel` do Dart, e
  // ela e `classe == humano`. Espectador nao pontua (nao competiu) e robo nao
  // pontua (nao tem conta).
  const competidores: CompetidorOficial[] = [];
  const brutos = o.participantes;
  if (Array.isArray(brutos)) {
    for (const b of brutos) {
      if (typeof b !== "object" || b === null) continue;
      const p = b as Record<string, unknown>;
      if (p.classe !== "humano") continue;
      const userId = p.userId;
      if (typeof userId !== "string" || userId.length === 0) continue;
      const lado = p.lado;
      competidores.push({
        userId,
        lado: typeof lado === "string" && lado.length > 0 ? lado : null,
      });
    }
  }

  const placar: Array<{ lado: string; pontos: number; canastrasLimpas: number }> = [];
  const placarBruto = o.placar;
  if (Array.isArray(placarBruto)) {
    for (const b of placarBruto) {
      if (typeof b !== "object" || b === null) continue;
      const l = b as Record<string, unknown>;
      if (typeof l.lado !== "string") continue;
      placar.push({
        lado: l.lado,
        pontos: typeof l.pontos === "number" ? l.pontos : 0,
        canastrasLimpas:
          typeof l.canastrasLimpas === "number" ? l.canastrasLimpas : 0,
      });
    }
  }

  return {
    matchId,
    estado,
    tipo: typeof o.tipo === "string" ? o.tipo : "",
    // Lido do documento, e NAO recalculado a partir de `tipo` e `estado`.
    // Recalcular criaria uma segunda definicao de "isto vale ranking", e o
    // cabecalho de `TipoDePartida.alteraRanking` no Dart diz que ele e "a UNICA
    // fonte disso no sistema". Continua sendo.
    alteraRanking: o.alteraRanking === true,
    motivoEncerramento:
      typeof o.motivoEncerramento === "string" ? o.motivoEncerramento : null,
    ladoVencedor: typeof o.ladoVencedor === "string" ? o.ladoVencedor : null,
    encerradaEm: typeof o.encerradaEm === "string" ? o.encerradaEm : null,
    competidores,
    placar,
  };
}

// ---------------------------------------------------------------------------
// A DECISAO
// ---------------------------------------------------------------------------

export type RecusaDeProcessamento =
  | "sem_resultado"
  | "nao_terminal"
  | "nao_pontua"
  | "fora_do_ambiente_competitivo"
  | "natureza_alterada"
  | "desfecho_indefinido"
  | "lados_inconsistentes"
  | "sem_competidores"
  | "sem_temporada_vigente"
  | "temporada_encerrada"
  | "politica_nao_definida"
  | "ja_processado"
  /// Algum competidor ainda nao tem identidade publica canonica. Ver
  /// `decidirIdentidadePublica`, logo abaixo de `decidirProcessamento`.
  | "identidade_publica_ausente";

// ---------------------------------------------------------------------------
// A FORMA DA MESA (secao 9 da OS da Politica Competitiva v1)
// ---------------------------------------------------------------------------

/// Os lados da mesa, com quem esta em cada um.
export interface LadosDaMesa {
  readonly lados: ReadonlyArray<string>;
  readonly porLado: ReadonlyMap<string, ReadonlyArray<string>>;
}

/// Agrupa os competidores por lado, ou devolve `null` quando a mesa nao tem a
/// forma que um confronto de duas duplas exige.
///
/// AS TRES RECUSAS, e nenhuma delas e preciosismo:
///
///   competidor sem lado ..... nao da para saber contra quem ele jogou, entao
///                             nao da para calcular expectativa nenhuma;
///   menos de dois lados ..... nao houve confronto;
///   mais de dois lados ...... o Elo desta politica compara DUAS forcas (secao
///                             9). Uma mesa de tres lados exigiria uma regra de
///                             pontuacao multipartidaria que a OS nao definiu, e
///                             inventar uma seria decidir produto.
///
/// Devolver `null` em vez de adivinhar e o que impede uma partida malformada de
/// virar pontuacao plausivel e errada.
export function ladosDaMesa(
  competidores: ReadonlyArray<CompetidorOficial>
): LadosDaMesa | null {
  const porLado = new Map<string, string[]>();
  for (const c of competidores) {
    if (c.lado === null || c.lado.length === 0) return null;
    const lista = porLado.get(c.lado);
    if (lista === undefined) porLado.set(c.lado, [c.userId]);
    else lista.push(c.userId);
  }
  if (porLado.size !== 2) return null;
  return { lados: [...porLado.keys()], porLado };
}

export interface DecisaoDeProcessamento {
  readonly processa: boolean;
  readonly recusa: RecusaDeProcessamento | null;
  /// A recusa e BENIGNA: o efeito desejado ja existe ou nunca deveria existir.
  /// Quem chamou responde sucesso, e o gatilho nao tenta de novo.
  readonly benigna: boolean;
  /// A partida deve ficar guardada para reprocessar quando a regra existir?
  readonly guardarNoBacklog: boolean;
  readonly detalhe: string | null;
}

/// Decide se um resultado oficial vira pontuacao.
///
/// A ORDEM DAS GUARDAS E A MESMA DO DOMINIO DART (`registrarResultado` em
/// ledger_competitivo.dart), e ela nao e arbitraria:
///
///   1. e um resultado? ................ nao -> ignora em silencio (gatilho comum)
///   2. terminou? ...................... nao -> ignora em silencio
///   3. pontua? ........................ nao -> recusa benigna definitiva
///   4. e do ambiente competitivo? ..... nao -> recusa benigna definitiva
///   5. a natureza mudou desde antes? .. sim -> recusa benigna definitiva
///   6. tem quem pontuar? .............. nao -> recusa benigna definitiva
///   7. a mesa tem dois lados? ......... nao -> recusa benigna definitiva
///   8. o desfecho e definido? ......... nao -> recusa benigna definitiva
///   9. ja foi processado? ............. sim -> RECUSA BENIGNA, sem efeito
///  10. ha temporada para receber? ..... nao -> backlog
///  11. a politica existe? ............. nao -> backlog
///
/// AS RECUSAS DEFINITIVAS PRODUZEM DELTA ZERO E NAO VAO PARA O BACKLOG, e a
/// distincao e o ponto das secoes 13 e 26: backlog e para o que ainda PODE vir a
/// pontuar quando faltar uma peca (temporada, politica). Uma Mesa Publica nunca
/// vai pontuar, um torneio nunca vai alimentar este rating e uma partida sem
/// desfecho nunca vai ganhar um — guardar esses casos criaria uma fila que so
/// cresce e cuja unica saida seria a recusa que ja se conhece hoje.
///
/// A IDEMPOTENCIA VEM ANTES DA POLITICA, e este e o detalhe que o Dart tambem
/// registra: um reprocessamento de partida antiga tem que ser reportado como "ja
/// lancado" em vez de estourar por causa de uma politica que mudou desde entao.
/// Invertido, um retry apos troca de regra viraria erro permanente.
///
/// MAS A ELEGIBILIDADE VEM ANTES DA IDEMPOTENCIA, e isso e novo nesta OS. A
/// secao 26 exige que uma Mesa Publica que porventura esteja no backlog antigo
/// "termine em delta zero/recusa coerente — nunca passar a pontuar
/// retroativamente". Como as guardas 3 a 8 sao reavaliadas a cada
/// reprocessamento, contra o documento oficial atual, nao existe caminho pelo
/// qual um item do backlog pontue por ter sido guardado numa epoca em que as
/// regras eram outras.
export function decidirProcessamento(params: {
  resultado: ResultadoOficial | null;
  jaProcessado: boolean;
  temporadaVigente: string | null;
  temporadaEncerrada: boolean;
  temCalculadora: boolean;
  /// A natureza (`tipo`) com que esta partida foi observada da PRIMEIRA vez, se
  /// ela ja foi observada. `null` quando e a primeira vez.
  naturezaObservada?: string | null;
}): DecisaoDeProcessamento {
  const { resultado, jaProcessado, temporadaVigente, temporadaEncerrada, temCalculadora } =
    params;
  const naturezaObservada = params.naturezaObservada ?? null;

  if (resultado === null) {
    return recusa("sem_resultado", true, false, "documento sem forma de resultado.");
  }
  if (!estadoTerminal(resultado.estado)) {
    return recusa(
      "nao_terminal",
      true,
      false,
      `a partida ${resultado.matchId} esta em "${resultado.estado}".`
    );
  }
  if (!resultado.alteraRanking) {
    return recusa(
      "nao_pontua",
      true,
      false,
      `a partida ${resultado.matchId} (${resultado.tipo}/${resultado.estado}) nao altera ranking.`
    );
  }
  // SECOES 3.1 e 6. `alteraRanking` sozinho deixaria o TORNEIO passar, porque no
  // dominio Dart ele e `publicaRanqueada || torneio`. Esta guarda e a que
  // implementa "torneios nao alteram este rating" e, por construcao, tambem a
  // que garante que Mesa Publica casual jamais entre.
  if (!noAmbienteCompetitivo(resultado.tipo)) {
    return recusa(
      "fora_do_ambiente_competitivo",
      true,
      false,
      `a partida ${resultado.matchId} e do tipo "${resultado.tipo}", que nao alimenta ` +
        `o rating de temporada (ambiente competitivo: ${AMBIENTE_COMPETITIVO.join(", ")}).`
    );
  }
  // SECAO 4: a natureza da partida e imutavel. Se esta partida ja tinha sido
  // observada com outro tipo, alguem a reclassificou depois do fato — e uma
  // reclassificacao tardia e exatamente o caminho por onde uma casual viraria
  // ranqueada, ou por onde um resultado ruim seria apagado do ranking.
  if (naturezaObservada !== null && naturezaObservada !== resultado.tipo) {
    return recusa(
      "natureza_alterada",
      true,
      false,
      `a partida ${resultado.matchId} foi observada como "${naturezaObservada}" e agora ` +
        `diz "${resultado.tipo}" — a natureza competitiva nao muda depois da criacao.`
    );
  }
  if (resultado.competidores.length === 0) {
    return recusa(
      "sem_competidores",
      true,
      false,
      `a partida ${resultado.matchId} nao tem competidor pontuavel.`
    );
  }
  const mesa = ladosDaMesa(resultado.competidores);
  if (mesa === null) {
    return recusa(
      "lados_inconsistentes",
      true,
      false,
      `a partida ${resultado.matchId} nao descreve duas duplas: ` +
        `${resultado.competidores.length} competidor(es) em lados ` +
        `${resultado.competidores.map((c) => c.lado ?? "?").join("/")}.`
    );
  }
  // SECOES 12, 13 e 14. `ladoVencedor == null` numa partida FINALIZADA e o
  // empate oficial, e ele e legitimo (0.5 para os dois lados). Numa partida
  // ABANDONADA, ele significa que ninguem decretou o WO — e a secao 14 e clara
  // de que o Elo so age quando "o servidor decretar oficialmente derrota/WO".
  // Sem decreto nao ha desfecho, e sem desfecho o delta e zero (secao 13).
  if (resultado.ladoVencedor === null && resultado.estado !== "finalizada") {
    return recusa(
      "desfecho_indefinido",
      true,
      false,
      `a partida ${resultado.matchId} esta "${resultado.estado}" e nenhum lado foi ` +
        "declarado vencedor — nao ha desfecho oficial a pontuar."
    );
  }
  if (resultado.ladoVencedor !== null && !mesa.lados.includes(resultado.ladoVencedor)) {
    return recusa(
      "desfecho_indefinido",
      true,
      false,
      `a partida ${resultado.matchId} declara vencedor o lado ` +
        `"${resultado.ladoVencedor}", que nao esta na mesa (${mesa.lados.join(", ")}).`
    );
  }
  if (jaProcessado) {
    return recusa(
      "ja_processado",
      true,
      false,
      `a partida ${resultado.matchId} ja contribuiu para o ranking.`
    );
  }
  if (temporadaVigente === null) {
    // Backlog, e nao descarte: a partida aconteceu de verdade e o resultado dela
    // e permanente. Quando houver temporada, ela pode ser reprocessada.
    return recusa(
      "sem_temporada_vigente",
      true,
      true,
      `a partida ${resultado.matchId} encerrou sem temporada vigente.`
    );
  }
  if (temporadaEncerrada) {
    return recusa(
      "temporada_encerrada",
      true,
      true,
      `a temporada ${temporadaVigente} ja encerrou; a partida ${resultado.matchId} ficou fora.`
    );
  }
  if (!temCalculadora) {
    // O CAMINHO DE HOJE. Nenhuma politica esta registrada (ver politica.ts), e
    // por isso todo resultado oficial cai aqui: nao pontua ninguem e fica
    // guardado. E o comportamento que a secao 31 pede — construir a autoridade e
    // devolver a pendencia, sem improvisar a regra.
    return recusa(
      "politica_nao_definida",
      true,
      true,
      `a temporada ${temporadaVigente} nao tem calculadora de pontuacao registrada.`
    );
  }

  return { processa: true, recusa: null, benigna: false, guardarNoBacklog: false, detalhe: null };
}

function recusa(
  r: RecusaDeProcessamento,
  benigna: boolean,
  guardarNoBacklog: boolean,
  detalhe: string
): DecisaoDeProcessamento {
  return { processa: false, recusa: r, benigna, guardarNoBacklog, detalhe };
}

// ---------------------------------------------------------------------------
// A DECIMA SEGUNDA GUARDA — IDENTIDADE PUBLICA (OS de integracao, secoes 4 e 8)
// ---------------------------------------------------------------------------

/// O competidor tem identidade publica canonica?
///
/// POR QUE E UMA GUARDA SEPARADA, e nao a linha 12 de `decidirProcessamento`:
/// responde-la custa uma LEITURA POR COMPETIDOR em `playerIdentities`, e as onze
/// guardas anteriores sao puras. Fundi-las obrigaria o chamador a pagar essas
/// leituras em toda escrita de `matches` — inclusive nas Mesas Publicas, que a
/// guarda 4 recusa sem tocar o banco. Separada, a leitura so acontece para a
/// partida que ja passou por tudo o mais e realmente pontuaria.
///
/// POR QUE BACKLOG, E NAO CUNHAR AQUI (secao 8 da OS): o processamento
/// competitivo nao pode inventar um `publicId`, usar o UID no lugar dele,
/// gravar `"unknown"`, gravar vazio nem gerar um identificador temporario. A
/// unica saida honesta e a que este codebase JA TINHA para "o resultado e real,
/// falta uma peca": guardar em `rankingBacklog` como `pendente`.
///
/// E ISSO E RETOMAVEL POR CONSTRUCAO. O item volta a fila com as mesmas onze
/// guardas sendo reavaliadas; quando a identidade tiver sido provisionada pelo
/// dominio social, a mesma partida passa por aqui e pontua UMA vez — a chave de
/// idempotencia de `rankingContributions` continua sendo a mesma, entao um
/// reprocessamento tardio nao duplica contribuicao.
///
/// PURA DE PROPOSITO: recebe o mapa ja resolvido, e nao o Firestore. E o que
/// permite provar a regra sem emulador.
export function decidirIdentidadePublica(params: {
  resultado: ResultadoOficial;
  /// `uid -> publicId canonico`. Ausencia da chave, string vazia e `null`
  /// significam a MESMA coisa: nao ha identidade. Tratados juntos porque um
  /// documento de identidade meio gravado e indistinguivel, para o ranking, de
  /// um que nao existe — e ambos precisam terminar em backlog, nunca em id
  /// inventado.
  identidades: ReadonlyMap<string, string | null | undefined>;
}): DecisaoDeProcessamento {
  const { resultado, identidades } = params;
  const sem = resultado.competidores
    .map((c) => c.userId)
    .filter((uid) => {
      const id = identidades.get(uid);
      return typeof id !== "string" || id.length === 0;
    });

  if (sem.length === 0) {
    return { processa: true, recusa: null, benigna: false, guardarNoBacklog: false, detalhe: null };
  }

  return recusa(
    "identidade_publica_ausente",
    true,
    true,
    `a partida ${resultado.matchId} tem ${sem.length} competidor(es) sem identidade ` +
      `publica canonica (${sem.join(", ")}). O ranking NAO cunha publicId: a partida ` +
      "fica no backlog ate o dominio de Identidade Publica provisionar."
  );
}

/// A chave de idempotencia da CONTRIBUICAO de uma partida ao ranking.
///
/// `matchId|seasonId|politicaId|vN`, e cada pedaco esta ali por um motivo:
///
///   matchId ..... uma partida contribui no maximo uma vez (secao 8);
///   seasonId .... a mesma partida reprocessada para OUTRA temporada e outra
///                 contribuicao — e o que permite reconstruir uma temporada
///                 (secao 22) sem que a chave da original atrapalhe;
///   politica+vN . trocar a regra e recalcular e uma contribuicao NOVA, com
///                 trilha propria, em vez de uma reescrita silenciosa da antiga.
///
/// O resultado e o ID DO DOCUMENTO em `rankingContributions`. Duas execucoes
/// concorrentes do mesmo processamento disputam a criacao do MESMO documento, e
/// o Firestore deixa so uma passar.
export function chaveDeContribuicao(
  matchId: string,
  seasonId: string,
  politicaId: string,
  politicaVersao: number
): string {
  return `${matchId}|${seasonId}|${politicaId}|v${politicaVersao}`;
}
