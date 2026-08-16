// ledger.ts — a mecanica de lancamento competitivo do lado do servidor.
//
// ESTE ARQUIVO E UM ESPELHO, E ISSO E UMA DECISAO, NAO UM DESCUIDO.
//
// A regra de lancamento ja existe, escrita e testada, em
// `app/lib/rastreabilidade/ledger_competitivo.dart`. O caminho ideal seria
// chamar aquele codigo aqui, como o codebase de torneios faz com o proprio
// dominio. Nao da: a ponte `dart compile js` de torneios exporta o dominio de
// TORNEIOS, e o cabecalho de `functions/src/rastreabilidade.ts` ja registra a
// mesma limitacao com as mesmas palavras — "a duplicacao e inevitavel enquanto a
// ponte nao carregar a rastreabilidade, e esta anotada de proposito para quem
// for unifica-las achar os dois pontos".
//
// Este e o TERCEIRO ponto. Os outros dois estao em rastreabilidade.ts
// (PAPEIS_DE_AUTORIDADE e ehTerminal). A pendencia de unificar as pontes esta em
// docs/OS-RASTREABILIDADE-PARTIDAS.md e continua aberta.
//
// O QUE FOI ESPELHADO, campo a campo e nome a nome, porque os dois lados gravam
// no MESMO documento (`rankingLedger/{matchId|userId|motivo}`):
//   * a chave de idempotencia e a sua composicao;
//   * a invariante `antes + delta == depois`, conferida na construcao;
//   * a lista de motivos e quais exigem autoridade declarada;
//   * o formato de serializacao (`rankingBefore/rankingDelta/rankingAfter`).

import { PoliticaDeRanking, politicaDeJson } from "./politica";

/// Por que a pontuacao mudou. Espelha `MotivoLancamento` do Dart, wire a wire.
export const MOTIVOS = [
  "resultado_de_partida",
  "abandono_declarado",
  "correcao_administrativa",
  "estorno",
] as const;

export type MotivoLancamento = (typeof MOTIVOS)[number];

/// Este motivo exige uma autoridade declarada?
///
/// Mesma resposta do Dart: correcao e estorno sim, os automaticos nao. Uma
/// correcao sem responsavel nao e auditavel, e uma autoridade carimbada num
/// lancamento automatico e mentira sobre quem decidiu.
export function exigeAutoridade(motivo: MotivoLancamento): boolean {
  return motivo === "correcao_administrativa" || motivo === "estorno";
}

export function motivoValido(valor: string): valor is MotivoLancamento {
  return (MOTIVOS as ReadonlyArray<string>).includes(valor);
}

/// A chave de idempotencia de um lancamento: `matchId|userId|motivo`.
///
/// O `motivo` entra na chave — sem ele, o estorno de uma partida seria recusado
/// como duplicata do lancamento que ele estorna. Mesma composicao do Dart, e ela
/// e literalmente o ID DO DOCUMENTO no Firestore, o que faz da duplicidade uma
/// impossibilidade de construcao e nao o resultado de uma checagem.
export function chaveDeLancamento(
  matchId: string,
  userId: string,
  motivo: MotivoLancamento
): string {
  return `${matchId}|${userId}|${motivo}`;
}

export interface LancamentoCompetitivo {
  readonly chaveIdempotencia: string;
  readonly matchId: string;
  readonly userId: string;
  readonly motivo: MotivoLancamento;
  /// Temporada em que o lancamento vale. NAO existe no Dart: la o ledger e por
  /// jogador, aqui ele precisa dizer a QUE classificacao pertence, senao a
  /// virada de temporada misturaria saldos (secao 12).
  readonly seasonId: string;
  readonly rankingBefore: number;
  readonly rankingDelta: number;
  readonly rankingAfter: number;
  readonly registradoEm: string;
  readonly politica: PoliticaDeRanking;
  readonly autoridade: string | null;
  readonly versaoFormato: number;
}

export const VERSAO_FORMATO_LANCAMENTO = 1;

/// Erro de coerencia de lancamento. Tipado para que quem chama saiba distinguir
/// "o produtor mandou lixo" de "o Firestore falhou".
export class LancamentoIncoerente extends Error {}

/// Constroi o lancamento a partir do saldo atual e do delta calculado.
///
/// `depois` e CONSEQUENCIA, nunca parametro: nao existe caminho pelo qual o
/// chamador informe um `depois` que nao feche. E a mesma escolha do factory
/// `LancamentoCompetitivo.aplicando` do Dart, e ela e o que impede o defeito
/// mais caro possivel aqui — um saldo que nao se explica pela sequencia.
export function aplicarLancamento(params: {
  matchId: string;
  userId: string;
  motivo: MotivoLancamento;
  seasonId: string;
  saldoAtual: number;
  delta: number;
  registradoEm: string;
  politica: PoliticaDeRanking;
  autoridade?: string | null;
}): LancamentoCompetitivo {
  const {
    matchId,
    userId,
    motivo,
    seasonId,
    saldoAtual,
    delta,
    registradoEm,
    politica,
  } = params;
  const autoridade = params.autoridade ?? null;

  if (matchId.length === 0) {
    throw new LancamentoIncoerente("lancamento sem partida nao e auditavel");
  }
  if (userId.length === 0) {
    throw new LancamentoIncoerente("lancamento sem jogador");
  }
  if (seasonId.length === 0) {
    throw new LancamentoIncoerente("lancamento sem temporada nao classifica");
  }
  if (!Number.isInteger(saldoAtual) || !Number.isInteger(delta)) {
    // Ponto flutuante no ledger e como centavo em ponto flutuante: a soma para
    // de fechar sozinha depois de algumas centenas de lancamentos.
    throw new LancamentoIncoerente(
      `pontuacao e delta devem ser inteiros (recebidos: ${saldoAtual}, ${delta})`
    );
  }
  if (exigeAutoridade(motivo) && (autoridade === null || autoridade.length === 0)) {
    throw new LancamentoIncoerente(
      `${motivo} exige autoridade declarada — correcao sem responsavel nao e auditavel`
    );
  }
  if (!exigeAutoridade(motivo) && autoridade !== null) {
    throw new LancamentoIncoerente(
      `${motivo} e automatico e nao tem autoridade a declarar`
    );
  }

  return {
    chaveIdempotencia: chaveDeLancamento(matchId, userId, motivo),
    matchId,
    userId,
    motivo,
    seasonId,
    rankingBefore: saldoAtual,
    rankingDelta: delta,
    rankingAfter: saldoAtual + delta,
    registradoEm,
    politica,
    autoridade,
    versaoFormato: VERSAO_FORMATO_LANCAMENTO,
  };
}

/// Rele um lancamento persistido, revalidando a coerencia.
///
/// Revalidar em vez de confiar no banco e a disciplina do Dart: um lancamento
/// adulterado (alguem subiu `rankingAfter` sem mexer no delta) e recusado na
/// LEITURA, em vez de virar saldo.
export function lancamentoDeJson(raw: unknown): LancamentoCompetitivo {
  if (typeof raw !== "object" || raw === null) {
    throw new LancamentoIncoerente("lancamento: objeto esperado");
  }
  const o = raw as Record<string, unknown>;

  const motivo = `${o.motivo}`;
  if (!motivoValido(motivo)) {
    throw new LancamentoIncoerente(`lancamento: motivo desconhecido "${motivo}"`);
  }

  const inteiro = (campo: string): number => {
    const v = o[campo];
    if (typeof v !== "number" || !Number.isInteger(v)) {
      throw new LancamentoIncoerente(
        `lancamento: ${campo} deve ser inteiro (recebido: ${v})`
      );
    }
    return v;
  };

  const antes = inteiro("rankingBefore");
  const delta = inteiro("rankingDelta");
  const depois = inteiro("rankingAfter");
  if (antes + delta !== depois) {
    throw new LancamentoIncoerente(
      `lancamento incoerente: ${antes} + ${delta} = ${antes + delta}, ` +
        `mas o documento diz ${depois}`
    );
  }

  const matchId = `${o.matchId}`;
  const userId = `${o.userId}`;
  const esperada = chaveDeLancamento(matchId, userId, motivo);
  const gravada = o.chaveIdempotencia;
  if (typeof gravada === "string" && gravada !== esperada) {
    throw new LancamentoIncoerente(
      `lancamento: chaveIdempotencia gravada ("${gravada}") nao corresponde aos ` +
        `campos (esperada: "${esperada}")`
    );
  }

  const autoridade = typeof o.autoridade === "string" ? o.autoridade : null;
  if (exigeAutoridade(motivo) && autoridade === null) {
    throw new LancamentoIncoerente(`${motivo} exige autoridade declarada`);
  }

  return {
    chaveIdempotencia: esperada,
    matchId,
    userId,
    motivo,
    seasonId: typeof o.seasonId === "string" ? o.seasonId : "",
    rankingBefore: antes,
    rankingDelta: delta,
    rankingAfter: depois,
    registradoEm: `${o.registradoEm}`,
    politica: politicaDeJson(o.politica),
    autoridade,
    versaoFormato:
      typeof o.versaoFormato === "number" ? o.versaoFormato : VERSAO_FORMATO_LANCAMENTO,
  };
}

/// A sequencia esta integra?
///
/// Mesma conferencia de `LedgerCompetitivo.conferir()`: cada lancamento tem que
/// partir de onde o anterior parou. Devolve o primeiro ponto de ruptura, ou
/// `null`. E o que permite ao suporte afirmar "este saldo e explicavel" sem ler
/// linha por linha.
export function conferirCadeia(
  lancamentos: ReadonlyArray<LancamentoCompetitivo>,
  saldoInicial = 0
): string | null {
  let esperado = saldoInicial;
  for (const l of lancamentos) {
    if (l.rankingBefore !== esperado) {
      return (
        `lancamento ${l.chaveIdempotencia} parte de ${l.rankingBefore} e a ` +
        `sequencia estava em ${esperado}`
      );
    }
    if (l.rankingBefore + l.rankingDelta !== l.rankingAfter) {
      return (
        `lancamento ${l.chaveIdempotencia}: ${l.rankingBefore} + ` +
        `${l.rankingDelta} != ${l.rankingAfter}`
      );
    }
    esperado = l.rankingAfter;
  }
  return null;
}
