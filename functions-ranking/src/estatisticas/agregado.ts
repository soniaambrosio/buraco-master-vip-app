// agregado.ts — ESTATISTICAS OFICIAIS DO PERFIL V1, o estado acumulado.
//
// Modelo PURO. Nao ha Firestore aqui, nem nome de colecao, nem `FieldValue`,
// nem relogio: `aplicarDelta` recebe o instante de fora. Onde este agregado
// mora e decisao da OS do escritor, e adiantar essa escolha aqui a esconderia
// dentro de um tipo.
//
// ---------------------------------------------------------------------------
// VITALICIO, E NAO POR TEMPORADA
// ---------------------------------------------------------------------------
//
// A decisao de produto e explicita: as estatisticas do Perfil sao VITALICIAS.
// Temporada pertence ao Ranking. Isto e o que separa este agregado de
// `rankingStandings/{seasonId|uid}` (functions-ranking/src/firestore.ts:768-776),
// que zera a cada temporada por desenho — e e a razao de os dois nao poderem ser
// o mesmo documento, por mais parecidos que os contadores sejam.
//
// ---------------------------------------------------------------------------
// O QUE E GUARDADO E O QUE E DERIVADO
// ---------------------------------------------------------------------------
//
// Guardado: `partidas`, `vitorias`, `empates`, `derrotas`, `canastrasLimpas`,
// `canastrasSujas`, `xpTotal`, `versaoXp`, `atualizadoEm`, `versaoContrato`.
//
// Derivado, NUNCA guardado: `canastras` (limpas + sujas), `aproveitamento`
// (vitorias sobre partidas) e `nivel`. Guardar um derivado e criar uma segunda
// autoridade sobre o mesmo numero — que e, palavra por palavra, o defeito que
// esta linhagem de OS existe para eliminar. Se o derivado divergir da conta, o
// derivado esta errado, e nao ha como saber isso quando ele e persistido.

import { aproveitamentoDe } from "../projecao";

/// A versao deste agregado. Casa com a do fato que o alimenta.
export const VERSAO_ESTATISTICAS_OFICIAIS = 1;

/// O estado acumulado de um jogador.
export interface EstatisticasOficiaisPerfilV1 {
  readonly versaoContrato: number;
  readonly partidas: number;
  readonly vitorias: number;
  readonly empates: number;
  readonly derrotas: number;
  readonly canastrasLimpas: number;
  readonly canastrasSujas: number;
  /// Vitalicio, e SEMPRE zero nesta versao.
  ///
  /// O campo existe para que o schema nao mude quando a politica existir. Ele
  /// nao e zero por acaso: nao ha politica de XP aprovada em lugar nenhum do
  /// projeto. Ha uma formula VIVA no servidor Node — `50*(n-1)*n`, com quatro
  /// constantes de ganho (buraco-servidor@85d0eee server.js:3315-3338) — que
  /// nunca passou por OS de produto. Ela NAO se torna oficial por heranca, e
  /// `validarAgregado` recusa qualquer XP concedido sem politica declarada.
  readonly xpTotal: number;
  /// O identificador da politica de XP que concedeu o `xpTotal`.
  ///
  /// `null` significa "nenhuma politica" — e, enquanto for `null`, `xpTotal`
  /// tem de ser zero.
  readonly versaoXp: string | null;
  /// Instante do ultimo lancamento aplicado, ISO 8601 em UTC. `null` enquanto
  /// nada foi aplicado.
  readonly atualizadoEm: string | null;
}

/// O ponto de partida de qualquer jogador.
///
/// Zerado, e nao ausente: um jogador que nunca jogou tem zero partidas, o que e
/// verdade. O que o Perfil NAO pode fazer e DESENHAR esse zero como se fosse
/// avaliacao — e isso e decisao da tela, nao deste modulo, e ela ja esta certa
/// (app/lib/screens/perfil_screen.dart:101-105).
export const ESTATISTICAS_ZERADAS: EstatisticasOficiaisPerfilV1 = {
  versaoContrato: VERSAO_ESTATISTICAS_OFICIAIS,
  partidas: 0,
  vitorias: 0,
  empates: 0,
  derrotas: 0,
  canastrasLimpas: 0,
  canastrasSujas: 0,
  xpTotal: 0,
  versaoXp: null,
  atualizadoEm: null,
};

/// O que um fato acrescenta a um jogador.
///
/// NAO CARREGA `uid`. A fronteira de identidade e esta linha: o fato conhece o
/// uid porque o backend precisa dele para achar o documento, e o delta ja e
/// material de projecao. Repetir o uid aqui seria arrastar identidade interna
/// para dentro do que a proxima camada publica.
export interface DeltaDoJogador {
  readonly publicPlayerId: string;
  /// `matchId|publicPlayerId|estatisticasOficiais|v1`. Ver `chaveDeLancamento`.
  readonly chaveDeLancamento: string;
  readonly partidas: number;
  readonly vitorias: number;
  readonly empates: number;
  readonly derrotas: number;
  readonly canastrasLimpas: number;
  readonly canastrasSujas: number;
  /// Sempre zero nesta versao. Ver `xpTotal` acima.
  readonly xpTotal: number;
}

/// Os numeros que a leitura calcula e ninguem guarda.
export interface DerivadosDoPerfil {
  readonly canastras: number;
  /// Vitorias sobre partidas, em PORCENTAGEM com uma casa decimal.
  readonly aproveitamento: number;
  /// `null` enquanto nao houver politica de XP aprovada — que e sempre, hoje.
  readonly nivel: number | null;
}

/// A forma que uma futura politica de XP tera de ter.
///
/// A interface existe; a IMPLEMENTACAO nao, em lugar nenhum deste repositorio, e
/// isso e o ponto. `derivar` so calcula nivel se receber uma politica de fora, e
/// nao ha de onde tirar uma. Reservar o contrato sem inventar a recompensa e
/// exatamente o que a OS pediu.
export interface PoliticaDeXp {
  readonly versao: string;
  nivelDe(xpTotal: number): number;
}

/// Confere os invariantes do agregado e devolve a lista de erros.
///
/// Vazia significa integro. Nao ha "corrigir": valor ilegivel ou negativo e
/// RECUSADO, nunca normalizado em silencio — normalizar apagaria a prova de que
/// alguem escreveu errado.
export function validarAgregado(bruto: unknown): ReadonlyArray<string> {
  const erros: string[] = [];
  if (typeof bruto !== "object" || bruto === null || Array.isArray(bruto)) {
    return ["agregado: deve ser objeto"];
  }
  const a = bruto as Record<string, unknown>;

  const contadores = [
    "partidas",
    "vitorias",
    "empates",
    "derrotas",
    "canastrasLimpas",
    "canastrasSujas",
    "xpTotal",
  ];
  let numerosOk = true;
  for (const campo of contadores) {
    const v = a[campo];
    if (typeof v !== "number" || !Number.isInteger(v) || v < 0) {
      erros.push(`${campo}: inteiro nao negativo exigido (recebido ${JSON.stringify(v)})`);
      numerosOk = false;
    }
  }

  if (a.versaoContrato !== VERSAO_ESTATISTICAS_OFICIAIS) {
    erros.push(
      `versaoContrato: ${VERSAO_ESTATISTICAS_OFICIAIS} exigido (recebido ${JSON.stringify(a.versaoContrato)})`
    );
  }
  if (a.versaoXp !== null && (typeof a.versaoXp !== "string" || a.versaoXp.length === 0)) {
    erros.push("versaoXp: string nao vazia ou null exigido");
  }
  if (a.atualizadoEm !== null && typeof a.atualizadoEm !== "string") {
    erros.push("atualizadoEm: string ISO 8601 ou null exigido");
  }

  if (numerosOk) {
    const partidas = a.partidas as number;
    const soma = (a.vitorias as number) + (a.empates as number) + (a.derrotas as number);
    if (partidas !== soma) {
      erros.push(
        `partidas (${partidas}) deve ser vitorias + empates + derrotas (${soma})`
      );
    }
    // XP concedido sem politica declarada e XP inventado. A recusa e aqui, e nao
    // num comentario, porque comentario nao reprova ninguem.
    if (a.versaoXp === null && (a.xpTotal as number) !== 0) {
      erros.push("xpTotal: sem politica de XP declarada (versaoXp null), xpTotal tem de ser 0");
    }
  }

  return erros;
}

/// Aplica um delta e devolve um agregado NOVO.
///
/// Puro: nao muta a entrada, nao le relogio (o instante vem de fora) e lanca se
/// o resultado violar um invariante — o que so acontece se o delta estiver
/// malformado, e nesse caso deixar passar seria pior.
///
/// A IDEMPOTENCIA NAO MORA AQUI, e isto e deliberado. Quem decide se um
/// `chaveDeLancamento` ja foi aplicado e o escritor, pelo id do documento, no
/// mesmo padrao dos vizinhos (functions-ranking/src/resultado.ts:478). Uma
/// funcao pura nao tem como saber o que ja aconteceu, e fingir que sabe seria a
/// forma mais rapida de contar duas vezes.
export function aplicarDelta(
  atual: EstatisticasOficiaisPerfilV1,
  delta: DeltaDoJogador,
  instante: string
): EstatisticasOficiaisPerfilV1 {
  const proximo: EstatisticasOficiaisPerfilV1 = {
    versaoContrato: VERSAO_ESTATISTICAS_OFICIAIS,
    partidas: atual.partidas + delta.partidas,
    vitorias: atual.vitorias + delta.vitorias,
    empates: atual.empates + delta.empates,
    derrotas: atual.derrotas + delta.derrotas,
    canastrasLimpas: atual.canastrasLimpas + delta.canastrasLimpas,
    canastrasSujas: atual.canastrasSujas + delta.canastrasSujas,
    xpTotal: atual.xpTotal + delta.xpTotal,
    versaoXp: atual.versaoXp,
    atualizadoEm: instante,
  };
  const erros = validarAgregado(proximo);
  if (erros.length > 0) {
    throw new Error(`agregado invalido apos aplicar delta: ${erros.join("; ")}`);
  }
  return proximo;
}

/// Calcula o que ninguem guarda.
///
/// `politica` e `null` na chamada real, hoje e ate segunda ordem. Quando ela
/// existir, tera de declarar a MESMA `versao` que o agregado registrou — senao o
/// nivel exibido seria o de uma regra que nunca concedeu aquele XP.
export function derivar(
  a: EstatisticasOficiaisPerfilV1,
  politica: PoliticaDeXp | null = null
): DerivadosDoPerfil {
  // Reuso de proposito: `aproveitamentoDe` ja e a conta que o ranking publica
  // (functions-ranking/src/projecao.ts:154). Reescreve-la aqui criaria duas
  // versoes do mesmo numero, que e o defeito que esta OS elimina. Empate fica no
  // DENOMINADOR e fora do numerador — um empate nao e meia vitoria.
  const aproveitamento = aproveitamentoDe(a.vitorias, a.partidas);
  const nivel =
    politica !== null && a.versaoXp !== null && politica.versao === a.versaoXp
      ? politica.nivelDe(a.xpTotal)
      : null;
  return {
    canastras: a.canastrasLimpas + a.canastrasSujas,
    aproveitamento,
    nivel,
  };
}
