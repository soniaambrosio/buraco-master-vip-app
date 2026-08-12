// apuracao.ts — de onde vem a POSICAO OFICIAL.
//
// O PROBLEMA. O Firestore nao sabe dizer "este documento e o 4237o da consulta".
// Nao existe `rank()`, e contar quantos estao acima de alguem custa uma leitura
// por jogador acima dele — o que na pratica significa varrer a base a cada
// abertura de tela, que e o que a secao 19 proibe com todas as letras.
//
// A SOLUCAO, que e a padrao para esta classe de problema: a posicao nao e
// calculada na LEITURA, e sim ATRIBUIDA numa passagem de apuracao. A leitura so
// devolve o numero que ja esta gravado. O custo sai do caminho quente (uma
// abertura de tela por jogador) e vai para o caminho frio (uma passagem
// periodica), e o ganho e de ordens de grandeza.
//
// A CONSEQUENCIA HONESTA DISSO, e ela precisa estar escrita: a posicao e "a da
// ultima apuracao", nao "a deste milissegundo". Uma partida que acabou de
// pontuar mexe no SALDO na hora e na POSICAO na proxima apuracao. Isso nao e um
// defeito escondido — e o que torna `direcao` e `delta` do contrato do cliente
// possiveis de definir: "subiu 3 posicoes" so quer dizer alguma coisa se houver
// dois instantes para comparar, e os dois instantes sao duas apuracoes.
//
// O QUE ESTE ARQUIVO NAO DECIDE: quem entra na classificacao. Nao ha filtro de
// "minimo de partidas para ser classificado" porque esse minimo e decisao de
// produto e nao existe. Todo mundo com uma linha de standing e apurado.

import { ChaveDeOrdem, compararOficial } from "./ordenacao";
import { DegrauDeLiga, EscadaDeLigas, ligaDe } from "./ligas";
import { EstadoCompetitivo } from "./competicao";

/// Movimento da posicao desde a apuracao anterior. Espelha `RankingDirecao` de
/// `app/lib/ranking/ranking_contract.dart`, wire a wire.
export type Direcao = "subiu" | "desceu" | "estavel";

/// Le uma direcao persistida, caindo em `estavel` para qualquer coisa que nao
/// seja um dos tres valores. Um campo corrompido vira "sem movimento", que e o
/// unico default que nao afirma nada sobre o jogador.
export function direcaoDeJson(bruto: unknown): Direcao {
  return bruto === "subiu" || bruto === "desceu" ? bruto : "estavel";
}

/// O que a apuracao le de cada linha.
export interface LinhaParaApurar extends ChaveDeOrdem {
  readonly uid: string;
  readonly posicao: number | null;
  /// Decide se esta linha recebe Liga nesta passagem (secao 15).
  readonly estadoCompetitivo: EstadoCompetitivo;
}

/// O que a apuracao grava de volta.
export interface PosicaoApurada {
  readonly uid: string;
  readonly publicPlayerId: string;
  readonly posicao: number;
  readonly posicaoAnterior: number | null;
  readonly direcao: Direcao;
  /// Quantas posicoes andou. Sempre >= 0; sem significado quando `estavel`.
  readonly deltaPosicao: number;
  readonly ligaId: string | null;
  readonly ligaNome: string | null;
}

/// Compara a posicao nova com a anterior.
///
/// A CONVENCAO QUE IMPORTA: posicao MENOR e melhor. "Subiu" significa que o
/// numero DIMINUIU. Escrever isso errado inverteria as setas de toda a tela, e e
/// o tipo de defeito que passa em revisao porque as duas leituras da frase
/// "subiu de 10 para 5" parecem certas.
///
/// Quem nao tinha posicao anterior (entrou na classificacao agora) sai como
/// `estavel`, e nao como "subiu do infinito": o cliente exibiria uma seta verde
/// com um numero enorme na primeira aparicao de todo jogador novo.
export function compararPosicao(
  nova: number,
  anterior: number | null
): { direcao: Direcao; deltaPosicao: number } {
  if (anterior === null || anterior === nova) {
    return { direcao: "estavel", deltaPosicao: 0 };
  }
  if (nova < anterior) return { direcao: "subiu", deltaPosicao: anterior - nova };
  return { direcao: "desceu", deltaPosicao: nova - anterior };
}

/// Apura um LOTE de linhas ja ordenadas, comecando na posicao `primeiraPosicao`.
///
/// POR QUE EM LOTE, com a posicao inicial vinda de fora: a apuracao percorre a
/// temporada inteira em paginas (`limit` + `startAfter`), porque carregar todos
/// os jogadores em memoria e a mesma leitura integral que a secao 19 proibe —
/// so que dentro da Function em vez de dentro do cliente. Cada pagina chama esta
/// funcao com o contador que a anterior deixou.
///
/// A funcao CONFERE a ordem em vez de ordenar: se o lote chegou fora de ordem, o
/// problema esta na consulta (indice errado, campo faltando) e ordenar aqui
/// esconderia isso enquanto produzisse posicoes que nao batem com a paginacao
/// que o jogador ve. Falhar alto e o comportamento certo.
export function apurarLote(params: {
  linhas: ReadonlyArray<LinhaParaApurar>;
  primeiraPosicao: number;
  escada: EscadaDeLigas;
}): PosicaoApurada[] {
  const { linhas, primeiraPosicao, escada } = params;

  for (let i = 1; i < linhas.length; i++) {
    if (compararOficial(linhas[i - 1], linhas[i]) > 0) {
      throw new Error(
        "apuracao recebeu lote fora da ordem oficial: " +
          `${linhas[i - 1].publicPlayerId}(${linhas[i - 1].pontos}) antes de ` +
          `${linhas[i].publicPlayerId}(${linhas[i].pontos})`
      );
    }
  }

  const apuradas: PosicaoApurada[] = [];
  let posicao = primeiraPosicao;

  for (const linha of linhas) {
    const movimento = compararPosicao(posicao, linha.posicao);
    // SECAO 15: Liga so para quem consolidou. Quem esta em colocacao ou
    // revalidacao aparece na classificacao, com posicao e rating, mas sem Liga —
    // e a tela mostra "Em colocacao" no lugar dela. Derivar a Liga aqui e deixar
    // a projecao esconde-la seria gravar no banco uma afirmacao que nao vale.
    const degrau: DegrauDeLiga | null =
      linha.estadoCompetitivo === "classificado" ? ligaDe(escada, linha.pontos) : null;
    apuradas.push({
      uid: linha.uid,
      publicPlayerId: linha.publicPlayerId,
      posicao,
      posicaoAnterior: linha.posicao,
      direcao: movimento.direcao,
      deltaPosicao: movimento.deltaPosicao,
      ligaId: degrau?.ligaId ?? null,
      ligaNome: degrau?.nome ?? null,
    });
    posicao += 1;
  }

  return apuradas;
}

/// A posicao e DENSA e unica: 1, 2, 3, ... sem repetir e sem pular.
///
/// Duas pessoas com a mesma pontuacao recebem posicoes DIFERENTES, decididas
/// pelo desempate tecnico de `ordenacao.ts`. A alternativa — posicao
/// compartilhada, "dois em quarto lugar, ninguem em quinto" — e uma convencao
/// competitiva, e escolher uma seria decidir produto. A densa e a unica que a
/// paginacao por cursor sustenta sem ambiguidade, e por isso ela e a tecnica
/// neutra aqui.
///
/// Documentado como funcao, e nao so como comentario, porque o teste da secao 23
/// ("desempate") precisa de algo para afirmar.
export function posicoesSaoDensasEUnicas(apuradas: ReadonlyArray<PosicaoApurada>): boolean {
  for (let i = 0; i < apuradas.length; i++) {
    if (apuradas[i].posicao !== apuradas[0].posicao + i) return false;
  }
  return true;
}

/// Identificador de uma passagem de apuracao.
///
/// Vira chave de idempotencia em `rankingTasks`, e por isso ele NAO pode conter
/// relogio: duas execucoes do mesmo tick com timestamps diferentes de
/// milissegundo produziriam chaves diferentes e a apuracao rodaria duas vezes.
/// O carimbo que o chamador passa e o do MINUTO, e a granularidade e deliberada.
export function apuracaoId(seasonId: string, carimbo: string): string {
  return `${seasonId}|apuracao|${carimbo}`;
}

/// Carimbo de minuto em UTC (`2026-08-11T20:31Z`), para [apuracaoId].
export function carimboDeMinuto(agora: Date): string {
  return `${agora.toISOString().slice(0, 16)}Z`;
}
