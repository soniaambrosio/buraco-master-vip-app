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
// A UNICA coisa que este arquivo decide e se o registro ENTRA no ranking, e o
// criterio para isso ja existe no registro: o campo `alteraRanking`, que o
// dominio Dart calcula como `identidade.alteraRanking && estado.valeu` e
// denormaliza na gravacao.

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
  | "sem_competidores"
  | "sem_temporada_vigente"
  | "temporada_encerrada"
  | "politica_nao_definida"
  | "ja_processado";

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
///   4. tem quem pontuar? .............. nao -> recusa benigna definitiva
///   5. ja foi processado? ............. sim -> RECUSA BENIGNA, sem efeito
///   6. ha temporada para receber? ..... nao -> backlog
///   7. a politica existe? ............. nao -> backlog
///
/// A IDEMPOTENCIA VEM ANTES DA POLITICA, e este e o detalhe que o Dart tambem
/// registra: um reprocessamento de partida antiga tem que ser reportado como "ja
/// lancado" em vez de estourar por causa de uma politica que mudou desde entao.
/// Invertido, um retry apos troca de regra viraria erro permanente.
export function decidirProcessamento(params: {
  resultado: ResultadoOficial | null;
  jaProcessado: boolean;
  temporadaVigente: string | null;
  temporadaEncerrada: boolean;
  temCalculadora: boolean;
}): DecisaoDeProcessamento {
  const { resultado, jaProcessado, temporadaVigente, temporadaEncerrada, temCalculadora } =
    params;

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
  if (resultado.competidores.length === 0) {
    return recusa(
      "sem_competidores",
      true,
      false,
      `a partida ${resultado.matchId} nao tem competidor pontuavel.`
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
