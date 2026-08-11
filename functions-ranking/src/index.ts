// index.ts — Cloud Functions da autoridade de Ranking, Ligas e Temporadas.
//
// DIVISAO DE TRABALHO, a mesma dos outros tres codebases:
//   QUEM DECIDE  -> os modulos puros deste diretorio (politica, ligas, ordenacao,
//                   temporadas, apuracao, projecao, resultado, ledger).
//   QUEM EXECUTA -> firestore.ts.
//   ESTE ARQUIVO -> autenticacao, forma do payload e o contrato de saida.
//
// A DIFERENCA EM RELACAO A TORNEIOS E MODERACAO, e ela e a razao de ser desta
// OS: naqueles dois, "quem decide" e o dominio Dart, porque a regra competitiva
// deles existe. A regra competitiva do ranking NAO EXISTE — nao ha formula de
// pontuacao, nao ha faixa de liga e nao ha politica de temporada decididas em
// lugar nenhum do projeto. O que esta construido aqui e a AUTORIDADE: quem pode
// escrever, como o resultado vira pontuacao sem duplicar, onde a temporada mora,
// como a posicao e atribuida, como a leitura pagina e o que ela pode publicar.
// A regra entra por `politica.ts`, num arquivo novo, sem tocar em nada disto.
//
// O QUE O CLIENTE NAO CONSEGUE FAZER, item por item da secao 20 (as Rules negam
// a escrita direta; estas funcoes negam o resto):
//   escrever pontuacao ......... nenhuma funcao chamavel aceita `pontos`
//   escrever posicao ........... `apurarRanking` exige claim `admin`
//   escrever Liga .............. derivada da escada, nunca recebida
//   escolher temporada ......... `abrirTemporada`/`encerrarTemporada` sao admin
//   se colocar no Hall ......... nenhuma funcao escreve `hallEntries`
//   marcar partida processada .. `rankingContributions` so pela transacao
//   alterar resultado oficial .. este codebase nunca escreve em `matches`

import { initializeApp } from "firebase-admin/app";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

import {
  temporadaVigente,
  lerEscada,
  abrirTemporada,
  encerrarTemporada,
  apurarTemporada,
  processarResultadoOficial,
  paginaDaTemporada,
  paginaGlobal,
  podioDaTemporada,
  meuStanding,
  porIdPublico,
  garantirIdPublico,
  db,
  C_HALL,
  C_BACKLOG,
} from "./firestore";
import { politicaDeJson, politicasRegistradas } from "./politica";
import { escadaParaExibicao, escadaDefinida } from "./ligas";
import { faixaDeTempo, Temporada } from "./temporadas";
import { decodificarCursor, CursorInvalido, fecharPagina, normalizarLimite } from "./ordenacao";
import { projetarJogador, JogadorPublicado, StandingArmazenado } from "./projecao";
import { idPublicoValido } from "./identidade";

initializeApp();

const opcoesCliente = { enforceAppCheck: true, region: "southamerica-east1" };
const opcoesServidor = { region: "southamerica-east1" };

/// Os claims do token, como este arquivo os le.
///
/// Tipado em vez de `any` pela mesma razao de functions/src/rastreabilidade.ts:
/// um claim escrito errado (`Admin`, `motorDePartida`) vira erro de compilacao em
/// vez de uma comparacao que sempre da `false` — que numa checagem de permissao
/// falha ABERTA em nenhum teste e FECHADA em producao.
type ClaimsDoToken = Partial<Record<"admin" | "suporte" | "motorDePartidas", boolean>>;

function claimsDe(req: CallableRequest): ClaimsDoToken {
  return (req.auth?.token ?? {}) as ClaimsDoToken;
}

function exigirAutenticacao(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "E preciso estar autenticado.");
  return uid;
}

function exigirAdmin(req: CallableRequest): string {
  const uid = exigirAutenticacao(req);
  if (claimsDe(req).admin !== true) {
    throw new HttpsError("permission-denied", "Operacao restrita a administracao.");
  }
  return uid;
}

/// Papeis que podem pedir o processamento de um resultado.
///
/// Espelha `PAPEIS_DE_AUTORIDADE` de functions/src/rastreabilidade.ts. E o QUINTO
/// ponto da duplicacao declarada em ledger.ts, e pelo mesmo motivo: a ponte do
/// dominio Dart nao carrega a rastreabilidade.
function exigirAutoridadeDePartida(req: CallableRequest): string {
  const uid = exigirAutenticacao(req);
  const token = claimsDe(req);
  if (token.motorDePartidas !== true && token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "somente a autoridade da partida pede o processamento de um resultado."
    );
  }
  return uid;
}

// ---------------------------------------------------------------------------
// INGESTAO — do resultado oficial ao ranking
// ---------------------------------------------------------------------------

/// Reage a gravacao do resultado oficial de uma partida.
///
/// GATILHO DE ESCRITA, e nao de criacao: `registrarEncerramentoPartida` usa
/// `tx.set` sobre `matches/{matchId}`, e o documento pode ja existir de uma
/// abertura anterior. `onDocumentCreated` perderia justamente os encerramentos de
/// partidas que foram registradas ao abrir — e perder um resultado e pior que
/// processar um documento que nao interessa, porque o segundo caso e barato e se
/// resolve numa linha de guarda.
///
/// A GUARDA e `decidirProcessamento`, que ignora em silencio tudo que nao for
/// resultado terminal e pontuavel. Um gatilho que gritasse a cada escrita
/// intermediaria encheria o log de falha para o funcionamento normal.
///
/// ENTREGA AO MENOS UMA VEZ: o Cloud Functions pode disparar duas vezes para o
/// mesmo evento. A protecao nao esta aqui — esta na chave de idempotencia de
/// `rankingContributions`, que faz a segunda execucao nao ter efeito.
export const aoRegistrarResultadoOficial = onDocumentWritten(
  { document: "matches/{matchId}", region: "southamerica-east1" },
  async (event) => {
    const matchId = event.params.matchId;
    const depois = event.data?.after;
    if (depois === undefined || !depois.exists) return;

    const resultado = await processarResultadoOficial({
      matchId,
      origem: "gatilho",
      autor: null,
    });

    if (!resultado.processada && resultado.recusa !== null) {
      // `debug`, e nao `warn`: hoje TODA partida cai em `politica_nao_definida`,
      // e classificar o funcionamento esperado como aviso treinaria quem opera a
      // ignorar avisos.
      logger.debug("resultado nao contribuiu para o ranking", {
        matchId,
        recusa: resultado.recusa,
      });
    }
  }
);

/// Processa um resultado oficial sob demanda.
///
/// Existe para tres casos que o gatilho nao cobre: o retry manual depois de uma
/// falha transitoria, o reprocessamento dirigido a uma temporada (secao 22) e o
/// esvaziamento do backlog no dia em que a politica existir.
export const processarResultado = onCall(opcoesServidor, async (req) => {
  const autor = exigirAutoridadeDePartida(req);
  const matchId = req.data?.matchId;
  if (typeof matchId !== "string" || matchId.length === 0) {
    throw new HttpsError("invalid-argument", "matchId e obrigatorio.");
  }
  const seasonIdAlvo =
    typeof req.data?.seasonId === "string" && req.data.seasonId.length > 0
      ? req.data.seasonId
      : undefined;

  return processarResultadoOficial({
    matchId,
    origem: seasonIdAlvo === undefined ? "administrativo" : "reprocessamento",
    autor,
    seasonIdAlvo,
  });
});

// ---------------------------------------------------------------------------
// ADMINISTRACAO DE TEMPORADA E APURACAO
// ---------------------------------------------------------------------------

export const abrirTemporadaDeRanking = onCall(opcoesCliente, async (req) => {
  const autor = exigirAdmin(req);
  const { seasonId, nome, inicioEm, fimEm, politica, ladderId } = req.data ?? {};
  if (typeof seasonId !== "string" || seasonId.length === 0) {
    throw new HttpsError("invalid-argument", "seasonId e obrigatorio.");
  }
  if (typeof inicioEm !== "string" || Number.isNaN(Date.parse(inicioEm))) {
    throw new HttpsError("invalid-argument", "inicioEm deve ser ISO-8601.");
  }
  if (fimEm !== null && fimEm !== undefined && Number.isNaN(Date.parse(`${fimEm}`))) {
    throw new HttpsError("invalid-argument", "fimEm deve ser ISO-8601 ou nulo.");
  }

  const resposta = await abrirTemporada({
    seasonId,
    nome: typeof nome === "string" ? nome : seasonId,
    inicioEm,
    fimEm: typeof fimEm === "string" ? fimEm : null,
    politica: politica === undefined ? undefined : politicaDeJson(politica),
    ladderId: typeof ladderId === "string" ? ladderId : "",
    autor,
  });

  if (!resposta.aberta) {
    throw new HttpsError("failed-precondition", resposta.detalhe ?? "abertura recusada.");
  }
  return resposta;
});

export const encerrarTemporadaDeRanking = onCall(opcoesCliente, async (req) => {
  const autor = exigirAdmin(req);
  const seasonId = req.data?.seasonId;
  if (typeof seasonId !== "string" || seasonId.length === 0) {
    throw new HttpsError("invalid-argument", "seasonId e obrigatorio.");
  }

  // Uma apuracao final ANTES de fechar, para que a classificacao congelada da
  // temporada seja a definitiva e nao a da ultima passagem periodica.
  await apurarTemporada({ seasonId, autor });

  const resposta = await encerrarTemporada({ seasonId, autor });
  if (!resposta.encerrada) {
    throw new HttpsError("not-found", resposta.detalhe ?? "temporada desconhecida.");
  }
  return resposta;
});

export const apurarRanking = onCall(opcoesCliente, async (req) => {
  const autor = exigirAdmin(req);
  const seasonId =
    typeof req.data?.seasonId === "string" && req.data.seasonId.length > 0
      ? req.data.seasonId
      : (await temporadaVigente())?.seasonId;
  if (seasonId === undefined) {
    throw new HttpsError("failed-precondition", "nao ha temporada vigente para apurar.");
  }
  return apurarTemporada({ seasonId, autor });
});

/// Diagnostico administrativo: por que o ranking nao esta se movendo?
///
/// Existe porque a resposta honesta de hoje ("nenhuma politica registrada") e
/// invisivel de fora: as partidas acontecem, ninguem pontua e nada falha. Esta
/// funcao torna a pendencia consultavel em vez de folclorica.
export const diagnosticarRanking = onCall(opcoesCliente, async (req) => {
  exigirAdmin(req);
  const temporada = await temporadaVigente();
  const escada = temporada === null ? null : await lerEscada(temporada.ladderId);
  const backlog = await db().collection(C_BACKLOG).count().get();

  return {
    temporadaVigente: temporada?.seasonId ?? null,
    politicaDaTemporada: temporada === null ? null : temporada.politica,
    politicasComCalculadora: politicasRegistradas(),
    escadaDefinida: escada !== null && escadaDefinida(escada),
    ladderId: temporada?.ladderId ?? null,
    partidasNoBacklog: backlog.data().count,
    ultimaApuracaoEm: temporada?.ultimaApuracaoEm ?? null,
    jogadoresClassificados: temporada?.jogadoresClassificados ?? 0,
  };
});

// ---------------------------------------------------------------------------
// LEITURA — o que a tela consome (secoes 15 a 19)
// ---------------------------------------------------------------------------

const ESCOPOS = ["temporada", "global", "amigos"] as const;
type Escopo = (typeof ESCOPOS)[number];

function exigirEscopo(bruto: unknown): Escopo {
  if (typeof bruto !== "string" || !(ESCOPOS as ReadonlyArray<string>).includes(bruto)) {
    throw new HttpsError(
      "invalid-argument",
      `escopo deve ser um de: ${ESCOPOS.join(", ")}.`
    );
  }
  return bruto as Escopo;
}

/// A temporada exigida por uma leitura, ou a recusa que o cliente sabe exibir.
///
/// `failed-precondition` e escolhido de proposito: o adaptador do cliente o
/// traduz para `RankingIndisponivel`, que a tela mostra como "o ranking ainda nao
/// esta sendo publicado" com botao de tentar de novo. Devolver lista vazia seria
/// a tela dizendo "nao tem ninguem no ranking", que e diferente e falso.
async function exigirTemporada(): Promise<Temporada> {
  const t = await temporadaVigente();
  if (t === null) {
    throw new HttpsError(
      "failed-precondition",
      "Nao ha temporada de ranking em andamento."
    );
  }
  return t;
}

async function lerPagina(params: {
  escopo: Escopo;
  seasonId: string;
  limite: number;
  depoisDe: { pontos: number; publicPlayerId: string } | null;
}): Promise<StandingArmazenado[]> {
  if (params.escopo === "global") {
    return paginaGlobal({ limite: params.limite, depoisDe: params.depoisDe });
  }
  return paginaDaTemporada({
    seasonId: params.seasonId,
    limite: params.limite,
    depoisDe: params.depoisDe,
  });
}

/// O escopo "amigos" nao tem fonte.
///
/// Nao ha grafo social no projeto: `users/{uid}/blocks` e `users/{uid}/mutes` sao
/// da moderacao e listam quem o jogador NAO quer ver — o oposto de uma lista de
/// amigos. Construir uma aqui seria inventar uma funcionalidade inteira dentro de
/// uma OS de ranking.
///
/// A recusa e explicita para que a aba exiba indisponibilidade honesta em vez de
/// uma lista vazia que pareceria "voce nao tem amigos".
function recusarAmigos(): never {
  throw new HttpsError(
    "failed-precondition",
    "O ranking de amigos ainda nao esta disponivel."
  );
}

/// Abre um escopo: cabecalho + primeira pagina, numa ida so.
///
/// Espelha `RankingAbertura` do contrato do cliente. A ida unica e exigencia do
/// contrato ("para a tela nao ter dois estados de erro concorrentes"), e nao
/// otimizacao.
export const abrirRanking = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const escopo = exigirEscopo(req.data?.escopo);
  if (escopo === "amigos") recusarAmigos();

  const temporada = await exigirTemporada();
  const limite = normalizarLimite(req.data?.limite);
  const seasonIdDoCursor = escopo === "global" ? "" : temporada.seasonId;

  const [lidos, podio, meu, escada] = await Promise.all([
    lerPagina({ escopo, seasonId: temporada.seasonId, limite, depoisDe: null }),
    escopo === "temporada" ? podioDaTemporada(temporada.seasonId) : Promise.resolve([]),
    meuStanding(temporada.seasonId, uid),
    lerEscada(temporada.ladderId),
  ]);

  const pagina = fecharPagina(lidos, limite, escopo, seasonIdDoCursor);

  return {
    resumo: {
      escopo,
      temporadaId: temporada.seasonId,
      temporadaNome: temporada.nome,
      // O cliente NAO calcula prazo de temporada — ver `faixaDeTempo`.
      faixaTempo: faixaDeTempo(temporada, new Date()),
      fimEm: temporada.fimEm,
      // `divisao` fica nulo: divisao DENTRO de uma liga (e "faltam X pontos para
      // a proxima") depende de faixas que nao existem. Ver a dependencia aberta
      // no relatorio. Nulo e o valor que o contrato do cliente ja aceita.
      divisao: null,
      podio: podio.map((l) => projetarJogador(l, uid)),
      escadaLigas: escadaParaExibicao(escada, meu?.ligaId ?? null),
      // O proprio jogador, para o cabecalho. Nulo quando ele ainda nao pontuou.
      eu: meu === null ? null : projetarJogador(meu, uid),
    },
    primeiraPagina: paginaPublicada(pagina, uid),
  };
});

/// Pagina seguinte do mesmo escopo.
export const paginarRanking = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const escopo = exigirEscopo(req.data?.escopo);
  if (escopo === "amigos") recusarAmigos();

  const temporada = await exigirTemporada();
  const limite = normalizarLimite(req.data?.limite);
  const seasonIdDoCursor = escopo === "global" ? "" : temporada.seasonId;

  let cursor;
  try {
    cursor = decodificarCursor(req.data?.cursor, {
      escopo,
      seasonId: seasonIdDoCursor,
    });
  } catch (erro) {
    if (erro instanceof CursorInvalido) {
      throw new HttpsError("invalid-argument", erro.message);
    }
    throw erro;
  }

  const lidos = await lerPagina({
    escopo,
    seasonId: temporada.seasonId,
    limite,
    depoisDe: { pontos: cursor.pontos, publicPlayerId: cursor.publicPlayerId },
  });

  return paginaPublicada(fecharPagina(lidos, limite, escopo, seasonIdDoCursor), uid);
});

function paginaPublicada(
  pagina: { itens: StandingArmazenado[]; cursorProxima: string | null; fim: boolean },
  uid: string
): { itens: JogadorPublicado[]; cursorProxima: string | null; fim: boolean } {
  return {
    itens: pagina.itens.map((l) => projetarJogador(l, uid)),
    cursorProxima: pagina.cursorProxima,
    fim: pagina.fim,
  };
}

/// Perfil competitivo de um jogador pelo id PUBLICO.
///
/// E o outro lado da navegacao "posicao -> id publico -> perfil" que a OS
/// anterior preparou no cliente. Recebe id publico e devolve dado competitivo; o
/// uid nao entra e nao sai.
export const consultarJogadorPorIdPublico = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const publicPlayerId = req.data?.publicPlayerId;
  if (!idPublicoValido(publicPlayerId)) {
    // Recusa por FORMATO, antes de tocar o banco: fecha a enumeracao por
    // tentativa barata e nao revela se um id bem-formado existe ou nao.
    throw new HttpsError("invalid-argument", "identificador publico invalido.");
  }

  const temporada = await temporadaVigente();
  const achado = await porIdPublico(publicPlayerId, temporada?.seasonId ?? null);
  if (achado === null) throw new HttpsError("not-found", "jogador nao encontrado.");
  if (achado.standing === null) {
    return {
      id: publicPlayerId,
      temporadaId: temporada?.seasonId ?? null,
      classificado: false,
      jogador: null,
    };
  }

  return {
    id: publicPlayerId,
    temporadaId: temporada?.seasonId ?? null,
    classificado: true,
    jogador: projetarJogador(achado.standing, uid),
  };
});

/// Garante que o jogador autenticado tenha identidade publica.
///
/// Chamada pelo app no primeiro acesso a tela de Ranking. Sem ela, um jogador que
/// ainda nao terminou nenhuma partida ranqueada nao teria id publico e nao
/// poderia ser alvo de "abrir perfil" a partir de nenhuma lista.
export const garantirIdentidadePublica = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  return { publicPlayerId: await garantirIdPublico(uid) };
});

// ---------------------------------------------------------------------------
// HALL DOS IMORTAIS (secao 14)
// ---------------------------------------------------------------------------

/// As cinco categorias, exatamente como `HallCategoria` do contrato do cliente.
const CATEGORIAS_HALL = [
  "campeaoHoje",
  "melhorDupla",
  "maiorSequencia",
  "reiRainhaSemana",
  "lendaMes",
] as const;

/// Quadro atual do Hall.
///
/// SECAO 14, LITERALMENTE: "implementar somente o que puder ser derivado de
/// autoridade real" e "nao gerar entradas ficticias para preencher Hall vazio".
///
/// NENHUMA DAS CINCO CATEGORIAS PODE SER DERIVADA HOJE, e vale escrever por que
/// cada uma nao pode, porque "falta a formula de pontos" nao explica todas:
///
///   campeaoHoje ...... precisa de "campeao" definido para um DIA. Nao ha recorte
///                      diario em lugar nenhum, e nao ha pontuacao para ordenar.
///   melhorDupla ...... precisa de identidade de DUPLA persistente. O registro de
///                      partida tem lados de mesa (`ladoVencedor`, `placar[].lado`),
///                      que sao posicoes de uma partida, nao uma dupla que existe
///                      entre partidas.
///   maiorSequencia ... precisa da definicao de sequencia: quantas vitorias, em
///                      que janela, se abandono interrompe, se so vale ranqueada.
///   reiRainhaSemana .. precisa do recorte semanal e do criterio de "rei".
///   lendaMes ......... idem, mensal.
///
/// Entao esta funcao devolve, para cada categoria, um ESTADO explicito. Os quatro
/// estados que a secao 14 pede sao distinguiveis: `disponivel` (ha homenageado),
/// `sem_vencedor` (o criterio rodou e nao elegeu ninguem — ausencia legitima),
/// `criterio_nao_definido` (o produto ainda nao decidiu — o caso de hoje) e o erro
/// tecnico, que sai como excecao e nao como estado.
export const consultarHall = onCall(opcoesCliente, async (req) => {
  exigirAutenticacao(req);
  const temporada = await temporadaVigente();
  const seasonId = temporada?.seasonId ?? "";

  const docs = await Promise.all(
    CATEGORIAS_HALL.map((c) => db().collection(C_HALL).doc(`${seasonId}|${c}`).get())
  );

  const categorias = CATEGORIAS_HALL.map((categoria, i) => {
    const dado = docs[i].data();
    if (dado === undefined) {
      return { categoria, estado: "criterio_nao_definido" as const, honrado: null };
    }
    if (dado.honrado === null || dado.honrado === undefined) {
      return { categoria, estado: "sem_vencedor" as const, honrado: null };
    }
    return {
      categoria,
      estado: "disponivel" as const,
      // Publicado como esta gravado. Quem escrever aqui e responsavel por gravar
      // `id` como id PUBLICO — e nao ha caminho automatico que escreva errado,
      // porque nao ha caminho automatico nenhum.
      honrado: dado.honrado,
    };
  });

  return {
    temporadaId: temporada?.seasonId ?? null,
    categorias,
    // Afirmacao explicita, para o adaptador nao ter que deduzir de lista vazia.
    algumHonrado: categorias.some((c) => c.estado === "disponivel"),
  };
});
