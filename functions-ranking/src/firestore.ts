// firestore.ts — QUEM EXECUTA. Transacao, leitura, escrita e mais nada.
//
// MESMA DIVISAO DE TRABALHO DOS OUTROS CODEBASES (ver o cabecalho de
// functions/src/index.ts): as decisoes vivem nos modulos puros deste diretorio
// — politica, ligas, ordenacao, temporadas, apuracao, projecao, resultado — e
// este arquivo so as aplica contra o banco. Um `if` de regra competitiva que
// aparecer aqui esta no lugar errado.
//
// AS COLECOES QUE ESTE ARQUIVO GOVERNA, e o papel de cada uma:
//
//   rankingSeasons/{seasonId} ............ a temporada. Autoridade sobre "qual e
//                                          a vigente" (secao 12).
//   rankingLadders/{ladderId} ............ a escada de ligas. VAZIA de fabrica.
//   rankingStandings/{seasonId|uid} ...... a classificacao. Uma linha por jogador
//                                          POR TEMPORADA — e por isso a temporada
//                                          anterior nunca e sobrescrita (secao 6).
//   rankingPlayers/{uid} ................. identidade publica e agregado de vida
//                                          inteira. O escopo "global" do cliente.
//   rankingPublicIds/{publicPlayerId} .... o caminho de volta, id publico -> uid.
//   rankingContributions/{chave} ......... a prova de que uma partida contribuiu
//                                          (secao 6) e a chave de idempotencia
//                                          (secao 8).
//   rankingBacklog/{matchId} ............. resultado oficial que NAO pontuou por
//                                          falta de regra. A lista de trabalho do
//                                          dia em que a formula existir.
//   rankingAudit/{eventoId} .............. trilha das operacoes administrativas.
//   rankingTasks/{chaveTarefa} ........... idempotencia de apuracao e virada.
//   hallEntries/{seasonId|categoria} ..... o Hall. Tambem vazio, e por decisao.
//
//   rankingLedger/{matchId|userId|motivo}  JA EXISTIA, da OS de Rastreabilidade.
//                                          Este codebase ESCREVE nela e nao a
//                                          redefine — ver ledger.ts.

import { getFirestore, Firestore, Transaction, FieldValue } from "firebase-admin/firestore";
import { randomBytes } from "node:crypto";
import { logger } from "firebase-functions";

import {
  PoliticaDeRanking,
  politicaDeJson,
  calculadoraDe,
  EntradaDeCalculo,
  politicaComoTexto,
} from "./politica";
import { EscadaDeLigas, SEM_ESCADA, escadaDeJson, ligaDe } from "./ligas";
import {
  Temporada,
  temporadaDeJson,
  decidirAbertura,
  decidirEncerramento,
  temporadaNova,
  temporadaEncerrada,
} from "./temporadas";
import {
  ResultadoOficial,
  resultadoDeJson,
  decidirProcessamento,
  chaveDeContribuicao,
  DecisaoDeProcessamento,
} from "./resultado";
import { aplicarLancamento, MotivoLancamento } from "./ledger";
import {
  idPublicoDeBytes,
  COMPRIMENTO_ID_PUBLICO,
  chaveDeStanding,
} from "./identidade";
import {
  apurarLote,
  apuracaoId,
  carimboDeMinuto,
  direcaoDeJson,
  LinhaParaApurar,
} from "./apuracao";
import { StandingArmazenado } from "./projecao";
import { compararOficial } from "./ordenacao";

export const C_SEASONS = "rankingSeasons";
export const C_LADDERS = "rankingLadders";
export const C_STANDINGS = "rankingStandings";
export const C_PLAYERS = "rankingPlayers";
export const C_PUBLIC_IDS = "rankingPublicIds";
export const C_CONTRIBUTIONS = "rankingContributions";
export const C_BACKLOG = "rankingBacklog";
export const C_AUDIT = "rankingAudit";
export const C_TASKS = "rankingTasks";
export const C_HALL = "hallEntries";
export const C_LEDGER = "rankingLedger";
export const C_MATCHES = "matches";

export const db = (): Firestore => getFirestore();

export function agoraIso(): string {
  return new Date().toISOString();
}

// ---------------------------------------------------------------------------
// TEMPORADA
// ---------------------------------------------------------------------------

/// A temporada vigente, ou `null`.
///
/// Consulta por `status`, com `limit(2)` e nao `limit(1)`: pedir duas e o que
/// permite DETECTAR o estado invalido "duas vigentes" em vez de escolher uma em
/// silencio. `decidirAbertura` impede que isso aconteca, mas uma escrita
/// administrativa direta no console ainda poderia criar o caso, e a deteccao
/// custa zero.
export async function temporadaVigente(): Promise<Temporada | null> {
  const snap = await db().collection(C_SEASONS).where("status", "==", "vigente").limit(2).get();
  if (snap.empty) return null;
  if (snap.size > 1) {
    logger.error("ha mais de uma temporada vigente", {
      temporadas: snap.docs.map((d) => d.id),
    });
    throw new Error(
      "estado invalido: mais de uma temporada vigente (" +
        snap.docs.map((d) => d.id).join(", ") +
        "). A classificacao seria diferente a cada leitura."
    );
  }
  return temporadaDeJson(snap.docs[0].data());
}

export async function lerTemporada(seasonId: string): Promise<Temporada | null> {
  const doc = await db().collection(C_SEASONS).doc(seasonId).get();
  return doc.exists ? temporadaDeJson(doc.data()) : null;
}

export async function lerEscada(ladderId: string): Promise<EscadaDeLigas> {
  if (ladderId.length === 0) return SEM_ESCADA;
  const doc = await db().collection(C_LADDERS).doc(ladderId).get();
  if (!doc.exists) return SEM_ESCADA;
  return escadaDeJson({ ladderId, ...doc.data() });
}

/// Abre uma temporada. A decisao e pura; esta funcao a aplica sob transacao.
///
/// A LEITURA DA VIGENTE ACONTECE DENTRO DA TRANSACAO. Fora dela, duas aberturas
/// simultaneas leriam "nenhuma vigente" e criariam duas — e o sistema entraria
/// exatamente no estado que `temporadaVigente()` recusa a interpretar.
export async function abrirTemporada(params: {
  seasonId: string;
  nome: string;
  inicioEm: string;
  fimEm: string | null;
  politica?: PoliticaDeRanking;
  ladderId?: string;
  autor: string;
}): Promise<{ aberta: boolean; recusa: string | null; detalhe: string | null }> {
  const ref = db().collection(C_SEASONS).doc(params.seasonId);

  return db().runTransaction(async (tx) => {
    const [existente, vigentes] = await Promise.all([
      tx.get(ref),
      tx.get(db().collection(C_SEASONS).where("status", "==", "vigente").limit(1)),
    ]);

    const decisao = decidirAbertura({
      seasonId: params.seasonId,
      inicioEm: params.inicioEm,
      fimEm: params.fimEm,
      jaExiste: existente.exists,
      vigenteAtual: vigentes.empty ? null : vigentes.docs[0].id,
    });
    if (!decisao.aceita) {
      return { aberta: false, recusa: decisao.recusa, detalhe: decisao.detalhe };
    }

    const agora = agoraIso();
    const nova = temporadaNova({ ...params, agora });
    tx.set(ref, nova);
    registrarAuditoria(tx, {
      evento: "temporada_aberta",
      seasonId: params.seasonId,
      autor: params.autor,
      antes: null,
      depois: { status: "vigente", politica: politicaComoTexto(nova.politica) },
    });
    return { aberta: true, recusa: null, detalhe: null };
  });
}

/// Encerra uma temporada, de forma idempotente (secao 13).
export async function encerrarTemporada(params: {
  seasonId: string;
  autor: string;
}): Promise<{ encerrada: boolean; jaEncerrada: boolean; detalhe: string | null }> {
  const ref = db().collection(C_SEASONS).doc(params.seasonId);

  return db().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const temporada = doc.exists ? temporadaDeJson(doc.data()) : null;
    const decisao = decidirEncerramento({ temporada });

    if (decisao.resultado === "inexistente") {
      return { encerrada: false, jaEncerrada: false, detalhe: decisao.detalhe };
    }
    if (decisao.resultado === "ja_encerrada") {
      // Segunda execucao: sucesso sem efeito. E o caminho do retry, e reenvio nao
      // e falha — mesma disciplina de `registrarEncerramentoPartida`.
      return { encerrada: true, jaEncerrada: true, detalhe: decisao.detalhe };
    }

    const agora = agoraIso();
    // NAO se escreve em `rankingStandings` aqui. As linhas da temporada ficam
    // exatamente como estao, para sempre, e a temporada seguinte grava em
    // documentos cuja chave comeca com OUTRO seasonId.
    tx.set(ref, temporadaEncerrada(temporada as Temporada, agora));
    registrarAuditoria(tx, {
      evento: "temporada_encerrada",
      seasonId: params.seasonId,
      autor: params.autor,
      antes: { status: (temporada as Temporada).status },
      depois: { status: "encerrada", fechadaEm: agora },
    });
    return { encerrada: true, jaEncerrada: false, detalhe: null };
  });
}

// ---------------------------------------------------------------------------
// IDENTIDADE PUBLICA
// ---------------------------------------------------------------------------

/// Devolve o id publico do jogador, criando-o na primeira vez.
///
/// A COLISAO E TRATADA, e nao apenas considerada improvavel: `create` no
/// documento de `rankingPublicIds` falha se o id ja existir, e a funcao tenta
/// outro. Com 60 bits, a segunda tentativa praticamente nunca acontece — mas
/// "praticamente nunca" multiplicado por milhoes de jogadores e uma vez, e essa
/// uma vez seria dois jogadores compartilhando identidade publica.
export async function garantirIdPublico(uid: string): Promise<string> {
  const jogadorRef = db().collection(C_PLAYERS).doc(uid);
  const existente = await jogadorRef.get();
  const gravado = existente.data()?.publicPlayerId;
  if (typeof gravado === "string" && gravado.length > 0) return gravado;

  for (let tentativa = 0; tentativa < 5; tentativa++) {
    const candidato = idPublicoDeBytes(randomBytes(COMPRIMENTO_ID_PUBLICO));
    try {
      const atribuido = await db().runTransaction(async (tx) => {
        const [jogador, reserva] = await Promise.all([
          tx.get(jogadorRef),
          tx.get(db().collection(C_PUBLIC_IDS).doc(candidato)),
        ]);
        const jaTem = jogador.data()?.publicPlayerId;
        if (typeof jaTem === "string" && jaTem.length > 0) return jaTem;
        if (reserva.exists) return null;

        const agora = agoraIso();
        tx.set(db().collection(C_PUBLIC_IDS).doc(candidato), {
          publicPlayerId: candidato,
          uid,
          criadoEm: agora,
        });
        tx.set(
          jogadorRef,
          {
            uid,
            publicPlayerId: candidato,
            pontosTotais: 0,
            partidasTotais: 0,
            criadoEm: agora,
            atualizadoEm: agora,
          },
          { merge: true }
        );
        return candidato;
      });
      if (atribuido !== null) return atribuido;
    } catch (erro) {
      logger.warn("colisao ao reservar id publico, tentando outro", { tentativa });
    }
  }
  throw new Error(`nao foi possivel reservar um id publico para ${uid} em 5 tentativas.`);
}

// ---------------------------------------------------------------------------
// PROCESSAMENTO DO RESULTADO OFICIAL (secoes 8, 9, 21)
// ---------------------------------------------------------------------------

export interface ResultadoDoProcessamento {
  readonly processada: boolean;
  readonly recusa: string | null;
  readonly detalhe: string | null;
  readonly seasonId: string | null;
  readonly deltas: Record<string, number>;
}

/// Processa um resultado oficial, no maximo UMA vez.
///
/// TUDO NUMA TRANSACAO SO (secao 21): contribuicao, lancamentos e classificacao
/// entram juntos ou nao entram. Nao existe caminho que grave a pontuacao sem a
/// prova de que ela veio daquela partida, nem que marque a partida processada
/// sem mover a pontuacao.
///
/// CONCORRENCIA (secao 9): duas partidas do mesmo jogador que terminem no mesmo
/// instante disputam o MESMO documento de standing. A transacao do Firestore
/// detecta o conflito e reexecuta a perdedora — que entao le o saldo ja
/// atualizado pela vencedora e aplica o proprio delta em cima dele. Nao ha lost
/// update, e o `rankingBefore` de cada lancamento reflete o saldo que realmente
/// existia quando ele foi aplicado, que e o que faz a cadeia do ledger fechar.
///
/// POR QUE NAO `FieldValue.increment`, que seria mais barato: o incremento
/// atomico nao devolve o valor anterior, e sem ele nao ha `rankingBefore` — o
/// ledger perderia a propriedade que da nome ao arquivo (antes + delta ==
/// depois) e viraria um contador sem auditoria.
export async function processarResultadoOficial(params: {
  matchId: string;
  origem: "gatilho" | "administrativo" | "reprocessamento";
  autor: string | null;
  /// Reprocessamento dirigido a uma temporada especifica (secao 22). Quando
  /// ausente, vale a vigente.
  seasonIdAlvo?: string;
}): Promise<ResultadoDoProcessamento> {
  const { matchId, origem, autor } = params;

  const matchDoc = await db().collection(C_MATCHES).doc(matchId).get();
  const resultado = resultadoDeJson(matchDoc.data());

  const temporada =
    params.seasonIdAlvo !== undefined
      ? await lerTemporada(params.seasonIdAlvo)
      : await temporadaVigente();

  const politica: PoliticaDeRanking = temporada?.politica ?? politicaDeJson(null);
  const calculadora = calculadoraDe(politica);

  const chave =
    temporada === null
      ? null
      : chaveDeContribuicao(matchId, temporada.seasonId, politica.id, politica.versao);

  const jaProcessado =
    chave === null
      ? false
      : (await db().collection(C_CONTRIBUTIONS).doc(chave).get()).exists;

  const decisao = decidirProcessamento({
    resultado,
    jaProcessado,
    temporadaVigente: temporada?.seasonId ?? null,
    temporadaEncerrada: temporada?.status === "encerrada",
    temCalculadora: calculadora !== null,
  });

  if (!decisao.processa) {
    if (decisao.guardarNoBacklog && resultado !== null) {
      await guardarNoBacklog(resultado, decisao);
    }
    return {
      processada: false,
      recusa: decisao.recusa,
      detalhe: decisao.detalhe,
      seasonId: temporada?.seasonId ?? null,
      deltas: {},
    };
  }

  const oficial = resultado as ResultadoOficial;
  const season = temporada as Temporada;
  const calcular = calculadora as NonNullable<typeof calculadora>;
  const contribuicaoRef = db().collection(C_CONTRIBUTIONS).doc(chave as string);
  const escada = await lerEscada(season.ladderId);

  // O id publico e garantido FORA da transacao, de proposito: ele tem transacao
  // propria (com retry de colisao), e transacao aninhada nao existe. Como ele e
  // idempotente e estavel, fazer isso antes nao muda nada se a transacao abaixo
  // reexecutar.
  const idsPublicos = new Map<string, string>();
  for (const c of oficial.competidores) {
    idsPublicos.set(c.userId, await garantirIdPublico(c.userId));
  }

  return db().runTransaction(async (tx) => {
    const jaGravada = await tx.get(contribuicaoRef);
    if (jaGravada.exists) {
      // Segunda barreira, no nivel do banco. A primeira (a leitura la em cima)
      // resolve o caso comum; esta resolve o caso em que duas execucoes passaram
      // pela primeira ao mesmo tempo.
      return {
        processada: false,
        recusa: "ja_processado",
        detalhe: `a partida ${matchId} ja contribuiu para o ranking.`,
        seasonId: season.seasonId,
        deltas: {},
      };
    }

    const refs = oficial.competidores.map((c) =>
      db().collection(C_STANDINGS).doc(chaveDeStanding(season.seasonId, c.userId))
    );
    const atuais = await Promise.all(refs.map((r) => tx.get(r)));

    const saldos = new Map<string, number>();
    atuais.forEach((doc, i) => {
      const pontos = doc.data()?.pontos;
      saldos.set(oficial.competidores[i].userId, typeof pontos === "number" ? pontos : 0);
    });

    const agora = agoraIso();
    const deltas: Record<string, number> = {};

    oficial.competidores.forEach((competidor, i) => {
      const saldoAtual = saldos.get(competidor.userId) as number;
      const entrada: EntradaDeCalculo = {
        matchId: oficial.matchId,
        userId: competidor.userId,
        saldoAtual,
        estado: oficial.estado,
        motivoEncerramento: oficial.motivoEncerramento,
        ladoVencedor: oficial.ladoVencedor,
        ladoDoJogador: competidor.lado,
        placar: oficial.placar,
        tipo: oficial.tipo,
        saldosDosOponentes: oficial.competidores
          .filter((o) => o.userId !== competidor.userId && o.lado !== competidor.lado)
          .map((o) => saldos.get(o.userId) as number),
      };

      const delta = calcular(entrada);
      if (!Number.isInteger(delta)) {
        // A calculadora e codigo de terceiro do ponto de vista deste arquivo.
        // Um `NaN` ou um fracionario dela envenenaria o ledger de forma
        // permanente, entao ele e recusado antes de virar escrita.
        throw new Error(
          `a calculadora de ${politicaComoTexto(politica)} devolveu ` +
            `${delta} para ${competidor.userId} — o delta precisa ser inteiro.`
        );
      }
      deltas[competidor.userId] = delta;

      const motivo: MotivoLancamento = "resultado_de_partida";
      const lancamento = aplicarLancamento({
        matchId: oficial.matchId,
        userId: competidor.userId,
        motivo,
        seasonId: season.seasonId,
        saldoAtual,
        delta,
        registradoEm: agora,
        politica,
      });
      tx.set(db().collection(C_LEDGER).doc(lancamento.chaveIdempotencia), lancamento);

      const anterior = atuais[i].data();
      const degrau = ligaDe(escada, lancamento.rankingAfter);
      const linha: Partial<StandingArmazenado> & Record<string, unknown> = {
        seasonId: season.seasonId,
        uid: competidor.userId,
        publicPlayerId: idsPublicos.get(competidor.userId) as string,
        // Apelido e avatar NAO sao inventados aqui. Nao existe fonte de perfil no
        // backend (ver o relatorio, dependencia aberta): o campo e preservado se
        // ja existir e nasce vazio se nao existir.
        apelido: typeof anterior?.apelido === "string" ? anterior.apelido : "",
        avatar: typeof anterior?.avatar === "string" ? anterior.avatar : "",
        pontos: lancamento.rankingAfter,
        partidasComputadas:
          (typeof anterior?.partidasComputadas === "number"
            ? anterior.partidasComputadas
            : 0) + 1,
        // A POSICAO NAO E TOCADA AQUI. Ela pertence a apuracao, e recalcula-la
        // agora exigiria saber quantos jogadores estao acima deste — a leitura
        // integral que a secao 19 proibe.
        posicao: typeof anterior?.posicao === "number" ? anterior.posicao : null,
        posicaoAnterior:
          typeof anterior?.posicaoAnterior === "number" ? anterior.posicaoAnterior : null,
        direcao: direcaoDeJson(anterior?.direcao),
        deltaPosicao:
          typeof anterior?.deltaPosicao === "number" ? anterior.deltaPosicao : 0,
        ligaId: degrau?.ligaId ?? null,
        ligaNome: degrau?.nome ?? null,
        selo: typeof anterior?.selo === "string" ? anterior.selo : null,
        atualizadoEm: agora,
        criadoEm: typeof anterior?.criadoEm === "string" ? anterior.criadoEm : agora,
      };
      tx.set(refs[i], linha);

      tx.set(
        db().collection(C_PLAYERS).doc(competidor.userId),
        {
          uid: competidor.userId,
          publicPlayerId: idsPublicos.get(competidor.userId) as string,
          temporadaAtual: season.seasonId,
          pontosTotais: FieldValue.increment(delta),
          partidasTotais: FieldValue.increment(1),
          atualizadoEm: agora,
        },
        { merge: true }
      );
    });

    // A PROVA (secao 6): partida processada, temporada usada, jogadores afetados,
    // delta aplicado, regra e versao, instante e origem. Tudo num documento so,
    // cujo id e a chave de idempotencia.
    tx.create(contribuicaoRef, {
      contributionId: chave,
      matchId: oficial.matchId,
      seasonId: season.seasonId,
      politica,
      jogadores: oficial.competidores.map((c) => c.userId).sort(),
      deltas,
      estadoDaPartida: oficial.estado,
      encerradaEm: oficial.encerradaEm,
      processadoEm: agora,
      origem,
      autor,
      versaoFormato: 1,
    });

    // A partida saiu do backlog, se estava nele.
    tx.delete(db().collection(C_BACKLOG).doc(matchId));

    logger.info("partida contribuiu para o ranking", {
      matchId,
      seasonId: season.seasonId,
      politica: politicaComoTexto(politica),
      jogadores: oficial.competidores.length,
    });

    return {
      processada: true,
      recusa: null,
      detalhe: null,
      seasonId: season.seasonId,
      deltas,
    };
  });
}

/// Guarda um resultado oficial que nao pode ser pontuado agora.
///
/// SEM ISSO, A AUSENCIA DE FORMULA SERIA UM BURACO SILENCIOSO: as partidas
/// aconteceriam, o ranking nao se moveria e ninguem saberia quantas ficaram para
/// tras. Com isso, o dia em que a politica existir comeca com uma lista exata do
/// que reprocessar (secao 22).
///
/// O id do documento e o `matchId`, entao guardar duas vezes e a mesma escrita.
async function guardarNoBacklog(
  resultado: ResultadoOficial,
  decisao: DecisaoDeProcessamento
): Promise<void> {
  await db()
    .collection(C_BACKLOG)
    .doc(resultado.matchId)
    .set({
      matchId: resultado.matchId,
      motivo: decisao.recusa,
      detalhe: decisao.detalhe,
      estado: resultado.estado,
      tipo: resultado.tipo,
      encerradaEm: resultado.encerradaEm,
      jogadores: resultado.competidores.map((c) => c.userId).sort(),
      registradoEm: agoraIso(),
    });
}

// ---------------------------------------------------------------------------
// APURACAO (secao 10)
// ---------------------------------------------------------------------------

/// Tamanho do lote de apuracao.
///
/// 400 e escolhido pelo limite de escritas de um `WriteBatch` do Firestore (500):
/// deixa folga para o documento da temporada e para a trilha de auditoria no
/// ultimo lote, sem precisar de aritmetica no meio do laco.
const LOTE_APURACAO = 400;

export interface RelatorioDeApuracao {
  readonly seasonId: string;
  readonly apuracaoId: string;
  readonly jogadores: number;
  readonly jaApurada: boolean;
}

/// Atribui posicao, direcao, delta e liga a temporada inteira.
///
/// PAGINADA, e nao de uma vez: a temporada e percorrida em lotes de
/// [LOTE_APURACAO] com `startAfter`, exatamente como a leitura do cliente. Uma
/// implementacao que carregasse todos os standings em memoria seria a leitura
/// integral da secao 19 — so que escondida dentro da Function em vez de dentro do
/// cliente, o que e pior porque ninguem a ve.
///
/// IDEMPOTENTE por `rankingTasks/{seasonId|apuracao|carimboDeMinuto}`: dois ticks
/// do mesmo minuto nao apuram duas vezes. Apurar duas vezes nao corromperia a
/// pontuacao (a apuracao nao a toca), mas zeraria `direcao` e `delta` de todo
/// mundo — a segunda passagem compararia a posicao nova com ela mesma.
export async function apurarTemporada(params: {
  seasonId: string;
  autor: string;
}): Promise<RelatorioDeApuracao> {
  const agora = new Date();
  const id = apuracaoId(params.seasonId, carimboDeMinuto(agora));
  const tarefaRef = db().collection(C_TASKS).doc(id);

  const reservou = await db().runTransaction(async (tx) => {
    const doc = await tx.get(tarefaRef);
    if (doc.exists) return false;
    tx.create(tarefaRef, {
      chave: id,
      tarefa: "apuracao",
      seasonId: params.seasonId,
      iniciadaEm: agora.toISOString(),
      autor: params.autor,
    });
    return true;
  });

  if (!reservou) {
    return { seasonId: params.seasonId, apuracaoId: id, jogadores: 0, jaApurada: true };
  }

  const temporada = await lerTemporada(params.seasonId);
  if (temporada === null) {
    throw new Error(`temporada desconhecida: ${params.seasonId}`);
  }
  const escada = await lerEscada(temporada.ladderId);

  let posicao = 1;
  let ultimo: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let total = 0;

  for (;;) {
    let consulta = db()
      .collection(C_STANDINGS)
      .where("seasonId", "==", params.seasonId)
      .orderBy("pontos", "desc")
      .orderBy("publicPlayerId", "asc")
      .limit(LOTE_APURACAO);
    if (ultimo !== null) consulta = consulta.startAfter(ultimo);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    const linhas: LinhaParaApurar[] = pagina.docs.map((d) => {
      const v = d.data();
      return {
        uid: `${v.uid}`,
        publicPlayerId: `${v.publicPlayerId}`,
        pontos: typeof v.pontos === "number" ? v.pontos : 0,
        posicao: typeof v.posicao === "number" ? v.posicao : null,
      };
    });

    const apuradas = apurarLote({ linhas, primeiraPosicao: posicao, escada });

    const lote = db().batch();
    apuradas.forEach((a, i) => {
      lote.update(pagina.docs[i].ref, {
        posicao: a.posicao,
        posicaoAnterior: a.posicaoAnterior,
        direcao: a.direcao,
        deltaPosicao: a.deltaPosicao,
        ligaId: a.ligaId,
        ligaNome: a.ligaNome,
        apuracaoId: id,
      });
    });
    await lote.commit();

    posicao += apuradas.length;
    total += apuradas.length;
    ultimo = pagina.docs[pagina.docs.length - 1];
    if (pagina.size < LOTE_APURACAO) break;
  }

  const fim = agoraIso();
  await db().collection(C_SEASONS).doc(params.seasonId).update({
    ultimaApuracaoId: id,
    ultimaApuracaoEm: fim,
    jogadoresClassificados: total,
  });
  await db().collection(C_AUDIT).doc(id).set({
    eventoId: id,
    evento: "apuracao",
    seasonId: params.seasonId,
    autor: params.autor,
    antes: null,
    depois: { jogadores: total },
    registradoEm: fim,
  });

  return { seasonId: params.seasonId, apuracaoId: id, jogadores: total, jaApurada: false };
}

// ---------------------------------------------------------------------------
// AUDITORIA
// ---------------------------------------------------------------------------

/// Grava um evento de auditoria dentro da transacao que o causou.
///
/// SECAO 21: "A auditoria nao deve depender exclusivamente de logs efemeros."
/// Por isso ela e um DOCUMENTO, escrito na mesma transacao da mudanca — nao ha
/// caminho em que a alteracao comite e o registro dela nao.
function registrarAuditoria(
  tx: Transaction,
  evento: {
    evento: string;
    seasonId: string;
    autor: string;
    antes: Record<string, unknown> | null;
    depois: Record<string, unknown> | null;
  }
): void {
  const agora = agoraIso();
  const id = `${evento.seasonId}|${evento.evento}|${agora}`;
  tx.set(db().collection(C_AUDIT).doc(id), {
    eventoId: id,
    ...evento,
    registradoEm: agora,
  });
}

// ---------------------------------------------------------------------------
// LEITURA ORDENADA (secoes 18 e 19)
// ---------------------------------------------------------------------------

/// Le uma pagina da classificacao de uma temporada.
///
/// Pede `limite + 1` documentos para saber se ha proxima pagina sem uma segunda
/// consulta — ver `fecharPagina` em ordenacao.ts.
export async function paginaDaTemporada(params: {
  seasonId: string;
  limite: number;
  depoisDe: { pontos: number; publicPlayerId: string } | null;
}): Promise<StandingArmazenado[]> {
  let consulta = db()
    .collection(C_STANDINGS)
    .where("seasonId", "==", params.seasonId)
    .orderBy("pontos", "desc")
    .orderBy("publicPlayerId", "asc")
    .limit(params.limite + 1);

  if (params.depoisDe !== null) {
    consulta = consulta.startAfter(params.depoisDe.pontos, params.depoisDe.publicPlayerId);
  }

  const snap = await consulta.get();
  return snap.docs.map((d) => standingDeDoc(d.data()));
}

/// Le uma pagina do agregado de vida inteira (o escopo "global" do cliente).
export async function paginaGlobal(params: {
  limite: number;
  depoisDe: { pontos: number; publicPlayerId: string } | null;
}): Promise<StandingArmazenado[]> {
  let consulta = db()
    .collection(C_PLAYERS)
    .orderBy("pontosTotais", "desc")
    .orderBy("publicPlayerId", "asc")
    .limit(params.limite + 1);

  if (params.depoisDe !== null) {
    consulta = consulta.startAfter(params.depoisDe.pontos, params.depoisDe.publicPlayerId);
  }

  const snap = await consulta.get();
  return snap.docs.map((d) => {
    const v = d.data();
    return standingDeDoc({
      ...v,
      pontos: v.pontosTotais,
      partidasComputadas: v.partidasTotais,
      // O agregado global NAO tem posicao apurada: a apuracao percorre a
      // temporada, nao a vida inteira. Publicar posicao aqui exigiria uma
      // segunda passagem sobre `rankingPlayers`, e ela nao foi construida —
      // esta registrado como pendencia no relatorio.
      posicao: null,
    });
  });
}

function standingDeDoc(v: FirebaseFirestore.DocumentData | undefined): StandingArmazenado {
  const o = v ?? {};
  return {
    seasonId: typeof o.seasonId === "string" ? o.seasonId : "",
    uid: `${o.uid}`,
    publicPlayerId: `${o.publicPlayerId}`,
    apelido: typeof o.apelido === "string" ? o.apelido : "",
    avatar: typeof o.avatar === "string" ? o.avatar : "",
    pontos: typeof o.pontos === "number" ? o.pontos : 0,
    partidasComputadas:
      typeof o.partidasComputadas === "number" ? o.partidasComputadas : 0,
    posicao: typeof o.posicao === "number" ? o.posicao : null,
    posicaoAnterior: typeof o.posicaoAnterior === "number" ? o.posicaoAnterior : null,
    direcao: direcaoDeJson(o.direcao),
    deltaPosicao: typeof o.deltaPosicao === "number" ? o.deltaPosicao : 0,
    ligaId: typeof o.ligaId === "string" ? o.ligaId : null,
    ligaNome: typeof o.ligaNome === "string" ? o.ligaNome : null,
    selo: typeof o.selo === "string" ? o.selo : null,
    atualizadoEm: typeof o.atualizadoEm === "string" ? o.atualizadoEm : "",
  };
}

/// O podio: as tres primeiras linhas da mesma ordem.
///
/// Consulta propria com `limit(3)`, e nao um recorte da primeira pagina: as duas
/// coisas coincidem hoje, mas o cliente pode pedir a primeira pagina com cursor
/// (num refresh a partir do meio) e ai o podio deixaria de ser o podio.
export async function podioDaTemporada(seasonId: string): Promise<StandingArmazenado[]> {
  const snap = await db()
    .collection(C_STANDINGS)
    .where("seasonId", "==", seasonId)
    .orderBy("pontos", "desc")
    .orderBy("publicPlayerId", "asc")
    .limit(3)
    .get();
  return snap.docs.map((d) => standingDeDoc(d.data()));
}

/// A linha do proprio jogador na temporada, para o cabecalho da tela.
export async function meuStanding(
  seasonId: string,
  uid: string
): Promise<StandingArmazenado | null> {
  const doc = await db().collection(C_STANDINGS).doc(chaveDeStanding(seasonId, uid)).get();
  return doc.exists ? standingDeDoc(doc.data()) : null;
}

/// Resolve `id publico -> linha`, para a navegacao "posicao -> perfil".
///
/// Duas leituras, e nao uma consulta por campo: o indice reverso e um documento
/// cujo id E o id publico, entao a primeira leitura e um `get` direto. Uma
/// consulta `where('publicPlayerId','==',...)` custaria o mesmo e exigiria um
/// indice a mais.
export async function porIdPublico(
  publicPlayerId: string,
  seasonId: string | null
): Promise<{ standing: StandingArmazenado | null; uid: string } | null> {
  const reverso = await db().collection(C_PUBLIC_IDS).doc(publicPlayerId).get();
  const uid = reverso.data()?.uid;
  if (typeof uid !== "string" || uid.length === 0) return null;
  if (seasonId === null) return { standing: null, uid };
  return { standing: await meuStanding(seasonId, uid), uid };
}

/// Ordena em memoria pela ordem oficial. Usado so onde o conjunto ja e pequeno e
/// limitado (o podio, por exemplo), nunca sobre a base inteira.
export function ordenarOficial<T extends { pontos: number; publicPlayerId: string }>(
  linhas: T[]
): T[] {
  return [...linhas].sort(compararOficial);
}
