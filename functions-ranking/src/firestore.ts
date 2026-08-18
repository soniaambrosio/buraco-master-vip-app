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
//   rankingPlayers/{uid} ................. o agregado de vida inteira. O escopo
//                                          "global" do cliente. Carrega
//                                          `publicPlayerId` como PROJECAO da
//                                          identidade canonica — nunca como
//                                          fonte dela (ver identidade.ts).
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
//
// AS COLECOES QUE ESTE ARQUIVO LE E NUNCA ESCREVE (OS de integracao de
// identidade):
//
//   playerIdentities/{uid} ............... `uid -> publicId`. A FONTE CANONICA.
//   publicIdIndex/{publicId} ............. `publicId -> uid`. O caminho de volta.
//
// Ambas pertencem a functions-social. Nao ha, neste arquivo, um unico `tx.set`,
// `set`, `update`, `create` ou `delete` sobre elas — e `test/identidade.test.js`
// varre o codebase para que continue assim.

import { getFirestore, Firestore, Transaction, FieldValue } from "firebase-admin/firestore";
import { idOpaco } from "./ids_opacos";

import {
  VERSAO_CONTRATO_PASSE,
  CicloDePasse,
  ControleDePasse,
  MotivoDeFalha,
  ProjecaoDoProprietario,
  lerControle,
  decidirMaterializacao,
  projecaoDoProprietario,
  isoDeInstante,
} from "./passe";
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
  decidirIdentidadePublica,
  chaveDeContribuicao,
  DecisaoDeProcessamento,
  ladosDaMesa,
} from "./resultado";
import {
  HistoricoConsolidado,
  SituacaoCompetitiva,
  escadaEmCodigo,
  estadoCompetitivoDeJson,
  partidasExigidas,
  resultadoElo,
  situacaoApos,
  situacaoInicial,
} from "./competicao";
import { aplicarLancamento, MotivoLancamento } from "./ledger";
import {
  C_IDENTIDADES_CANONICAS,
  C_INDICE_PUBLICO_CANONICO,
  C_PERFIS_PUBLICOS_CANONICOS,
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
import {
  ChaveDeOrdem,
  CriterioDeOrdem,
  ORDEM_GLOBAL,
  ORDEM_TEMPORADA,
  campoNoBanco,
  compararOficial,
} from "./ordenacao";

export const C_SEASONS = "rankingSeasons";
export const C_LADDERS = "rankingLadders";
export const C_STANDINGS = "rankingStandings";
export const C_PLAYERS = "rankingPlayers";
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

/// A escada de uma temporada.
///
/// O CODIGO E CONSULTADO PRIMEIRO, e essa ordem e a regra (secao 16). A escada
/// oficial da v1 mora em `competicao.ts`, versionada junto com a formula, e um
/// documento em `rankingLadders` com o mesmo id NAO a sobrescreve. Se a
/// precedencia fosse a inversa, um `update` no console mudaria a Liga de todo
/// mundo entre duas leituras, sem revisao, sem teste e sem historico — que e
/// exatamente o que a decisao "a regra competitiva e codigo" existe para
/// impedir.
///
/// `rankingLadders` continua servindo escadas que NAO sejam a oficial.
export async function lerEscada(ladderId: string): Promise<EscadaDeLigas> {
  if (ladderId.length === 0) return SEM_ESCADA;
  const emCodigo = escadaEmCodigo(ladderId);
  if (emCodigo !== null) return emCodigo;
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

/// O id publico CANONICO de um jogador, ou `null` se ele ainda nao tem.
///
/// LEITURA PURA. Nao cria, nao repara, nao completa, nao devolve default. Essa
/// e a diferenca inteira entre este arquivo e o que ele era antes da OS de
/// integracao: `garantirIdPublico` sorteava e gravava; `identidadeCanonicaDe`
/// so pergunta.
///
/// A FONTE E `playerIdentities/{uid}`, do dominio de Identidade Publica. Ler
/// colecao de outro dominio pelo Admin SDK e normal e nao move autoridade
/// nenhuma: autoridade e quem ESCREVE. Quem escreve ali e `garantirIdentidade`,
/// em functions-social/src/repositorio.ts, e so ele.
///
/// `null` NAO E ERRO, e nao deve virar excecao aqui. Um jogador legitimamente
/// ainda nao provisionado e um estado esperado do sistema — quem decide o que
/// fazer com ele e `decidirIdentidadePublica`, em resultado.ts, que manda a
/// partida para o backlog.
export async function identidadeCanonicaDe(uid: string): Promise<string | null> {
  const doc = await db().collection(C_IDENTIDADES_CANONICAS).doc(uid).get();
  const id = doc.data()?.publicId;
  return typeof id === "string" && id.length > 0 ? id : null;
}

/// Apelido e avatar de um jogador, lidos do perfil publico canonico.
///
/// PROJECAO, E O NOME DIZ ISSO. O ranking NAO e dono de apelido nem de avatar:
/// quem e dono e `publicProfiles/{publicId}`, escrito por
/// `atualizarPerfilPublico` no dominio social. Este tipo existe para que o
/// caminho da copia seja nomeado, em vez de acontecer por um `??` perdido no
/// meio da montagem da linha.
export interface ApresentacaoProjetada {
  readonly apelido: string;
  readonly avatar: string;
}

/// Le a apresentacao canonica de varios jogadores, numa ida so.
///
/// Recebe `uid -> publicId` porque o perfil publico e enderecado pelo ID
/// PUBLICO, nao pelo uid — e nao ha, e nao deve haver, um `publicProfiles/{uid}`.
///
/// Perfil ausente simplesmente NAO ENTRA no mapa. Quem chama preserva o que ja
/// tinha; ninguem cai para o uid, e ninguem grava `"unknown"`.
export async function apresentacoesCanonicasDe(
  identidades: ReadonlyMap<string, string | null>
): Promise<Map<string, ApresentacaoProjetada>> {
  const pares = [...identidades.entries()].filter(
    (p): p is [string, string] => typeof p[1] === "string" && p[1].length > 0
  );
  const mapa = new Map<string, ApresentacaoProjetada>();
  if (pares.length === 0) return mapa;

  const docs = await db().getAll(
    ...pares.map(([, publicId]) =>
      db().collection(C_PERFIS_PUBLICOS_CANONICOS).doc(publicId)
    )
  );
  docs.forEach((doc, i) => {
    const dado = doc.data();
    if (dado === undefined) return;
    mapa.set(pares[i][0], {
      apelido: typeof dado.apelido === "string" ? dado.apelido : "",
      // `avatarRef` no perfil publico, `avatar` na linha do ranking: os dois
      // nomes ja existiam nos dois contratos, e renomear um deles seria mexer
      // em contrato de cliente por estetica. A traducao acontece aqui, uma vez.
      avatar: typeof dado.avatarRef === "string" ? dado.avatarRef : "",
    });
  });
  return mapa;
}

/// As identidades canonicas de varios jogadores, numa ida so.
///
/// `getAll` em vez de N leituras porque a mesa tem quatro jogadores e quatro
/// viagens ao banco por partida processada e desperdicio mensuravel.
///
/// Devolve o mapa COMPLETO, com `null` para quem nao tem — e nao um mapa
/// parcial. E o formato que `decidirIdentidadePublica` espera, e a diferenca
/// importa: um mapa parcial faria "faltou ler" e "nao existe" parecerem a mesma
/// coisa no chamador.
export async function identidadesCanonicasDe(
  uids: ReadonlyArray<string>
): Promise<Map<string, string | null>> {
  const unicos = [...new Set(uids)];
  const mapa = new Map<string, string | null>(unicos.map((u) => [u, null]));
  if (unicos.length === 0) return mapa;

  const docs = await db().getAll(
    ...unicos.map((u) => db().collection(C_IDENTIDADES_CANONICAS).doc(u))
  );
  for (const doc of docs) {
    const id = doc.data()?.publicId;
    if (typeof id === "string" && id.length > 0) mapa.set(doc.id, id);
  }
  return mapa;
}

// ---------------------------------------------------------------------------
// PROCESSAMENTO DO RESULTADO OFICIAL (secoes 8, 9, 21)
// ---------------------------------------------------------------------------

/// Onde um jogador esta numa temporada no instante em que uma partida vai ser
/// aplicada. Ou o que a linha dele diz, ou a semente, se ele ainda nao tem linha.
///
/// E a `SituacaoCompetitiva` de `competicao.ts` mais o rating de ENTRADA, que so
/// interessa a persistencia: a regra nao o usa, e a auditoria do ledger sim.
interface SituacaoNaTemporada extends SituacaoCompetitiva {
  readonly ratingInicial: number;
}

/// O historico consolidado gravado em `rankingPlayers/{uid}`, ou `null`.
///
/// SO CONTA QUEM TERMINOU UMA TEMPORADA CLASSIFICADO. A consolidacao (ver
/// `consolidarTemporada`) escreve estes campos apenas para quem cumpriu a
/// colocacao ou a revalidacao — quem viu a temporada acabar no meio das 10
/// partidas nao deixa historico, e volta as 10 na temporada seguinte.
function historicoConsolidadoDe(
  jogador: FirebaseFirestore.DocumentData | undefined
): HistoricoConsolidado | null {
  const seasonId = jogador?.ultimaTemporadaConsolidada;
  const ratingFinal = jogador?.ratingFinalConsolidado;
  if (typeof seasonId !== "string" || seasonId.length === 0) return null;
  if (typeof ratingFinal !== "number" || !Number.isInteger(ratingFinal)) return null;
  return { seasonId, ratingFinal };
}

/// A situacao do jogador: a linha que ele ja tem, ou a semente da temporada.
///
/// AS DUAS PORTAS ESTAO AQUI, E SO AQUI. Nenhum outro ponto do sistema decide
/// "com quanto este jogador comeca" — o que importa porque um segundo lugar que
/// dissesse 0 em vez de 1000 produziria um ledger que fecha e um rating errado.
function situacaoNaTemporada(
  linha: FirebaseFirestore.DocumentData | undefined,
  jogador: FirebaseFirestore.DocumentData | undefined
): SituacaoNaTemporada {
  if (linha !== undefined && typeof linha.pontos === "number") {
    const estado = estadoCompetitivoDeJson(linha.estadoCompetitivo);
    const inteiro = (campo: string): number =>
      typeof linha[campo] === "number" ? (linha[campo] as number) : 0;
    return {
      rating: linha.pontos,
      ratingInicial: inteiro("ratingInicial"),
      estado,
      partidas: inteiro("partidasComputadas"),
      partidasDeQualificacao: inteiro("partidasDeQualificacao"),
      // Uma linha gravada antes desta OS nao tem a exigencia; ela e derivada do
      // estado, que por sua vez cai em `em_colocacao` por default.
      qualificacaoExigida:
        typeof linha.qualificacaoExigida === "number"
          ? linha.qualificacaoExigida
          : partidasExigidas(estado),
      vitorias: inteiro("vitorias"),
      derrotas: inteiro("derrotas"),
      empates: inteiro("empates"),
      saldoPontos: inteiro("saldoPontos"),
      abandonos: inteiro("abandonos"),
      ratingAtingidoEm:
        typeof linha.ratingAtingidoEm === "string" ? linha.ratingAtingidoEm : "",
    };
  }

  const inicial = situacaoInicial(historicoConsolidadoDe(jogador));
  return { ...inicial, ratingInicial: inicial.rating };
}

/// Os pontos de um lado da mesa, como o placar oficial os gravou. `0` quando o
/// lado nao aparece no placar.
function pontosDoLado(
  placar: ReadonlyArray<{ lado: string; pontos: number }>,
  lado: string
): number {
  for (const l of placar) if (l.lado === lado) return l.pontos;
  return 0;
}

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

  // A OBSERVACAO ANTERIOR DESTA PARTIDA, se houver (secao 4). O backlog guarda o
  // `tipo` com que a partida foi vista da primeira vez; compara-lo com o `tipo`
  // de agora e o que detecta uma reclassificacao tardia de casual para ranqueada
  // (ou o contrario) depois que o resultado ja existia.
  const observacaoAnterior = await db().collection(C_BACKLOG).doc(matchId).get();
  const naturezaObservada =
    typeof observacaoAnterior.data()?.tipo === "string"
      ? (observacaoAnterior.data()?.tipo as string)
      : null;

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
    naturezaObservada,
  });

  if (!decisao.processa) {
    if (decisao.guardarNoBacklog && resultado !== null) {
      await guardarNoBacklog(resultado, decisao, "pendente");
    } else if (observacaoAnterior.exists && resultado !== null) {
      // SECAO 26: um item que ESTAVA no backlog e agora e recusado em definitivo
      // termina como `recusado`, e nao some nem continua parecendo pendente. E o
      // caminho de uma Mesa Publica antiga guardada numa epoca de regras
      // diferentes: ela nao volta a pontuar e passa a dizer por que.
      await guardarNoBacklog(resultado, decisao, "recusado");
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

  // A DECIMA SEGUNDA GUARDA. Ate a OS de integracao, esta era a linha que
  // CUNHAVA identidade (`garantirIdPublico`, uma por competidor). Agora ela so
  // LE a identidade canonica e, se faltar alguma, recusa a partida para o
  // backlog em vez de inventar um id.
  //
  // Fora da transacao, como antes, mas por outra razao: agora e uma leitura, e
  // uma leitura fora da transacao que reexecuta e relida. Se a identidade for
  // provisionada entre esta leitura e a transacao, a partida cai no backlog e o
  // reprocessamento a pega — o pior caso e um ciclo de atraso, nunca um id
  // errado.
  const idsPublicos = await identidadesCanonicasDe(
    oficial.competidores.map((c) => c.userId)
  );
  const decisaoIdentidade = decidirIdentidadePublica({
    resultado: oficial,
    identidades: idsPublicos,
  });
  if (!decisaoIdentidade.processa) {
    await guardarNoBacklog(oficial, decisaoIdentidade, "pendente");
    logger.warn("partida sem identidade publica canonica foi para o backlog", {
      matchId,
      detalhe: decisaoIdentidade.detalhe,
    });
    return {
      processada: false,
      recusa: decisaoIdentidade.recusa,
      detalhe: decisaoIdentidade.detalhe,
      seasonId: season.seasonId,
      deltas: {},
    };
  }

  // A APRESENTACAO, tambem fora da transacao e tambem so leitura. Depois da
  // guarda, de proposito: perfil so e lido para partida que vai mesmo pontuar.
  const apresentacoes = await apresentacoesCanonicasDe(idsPublicos);

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
    const jogadorRefs = oficial.competidores.map((c) =>
      db().collection(C_PLAYERS).doc(c.userId)
    );
    // TODAS as leituras da transacao acontecem aqui, antes de qualquer escrita —
    // exigencia do Firestore, e tambem a ordem que faz a semente ser decidida
    // com o estado que realmente existia quando a transacao comecou.
    const [atuais, jogadores] = await Promise.all([
      Promise.all(refs.map((r) => tx.get(r))),
      Promise.all(jogadorRefs.map((r) => tx.get(r))),
    ]);

    // ---------------------------------------------------------------------
    // A SEMENTE (secoes 7, 20 e 21)
    // ---------------------------------------------------------------------
    // Quem ja tem linha nesta temporada continua de onde parou. Quem NAO tem
    // entra agora, e e aqui que se decide com que rating e em que estado — 1000
    // e 10 partidas para quem nunca consolidou, soft reset e 5 partidas para o
    // veterano.
    //
    // ISTO E O QUE IMPEDE O DEFEITO MAIS SILENCIOSO POSSIVEL: antes desta OS, um
    // jogador sem linha valia ZERO, e o primeiro lancamento dele teria
    // `rankingBefore: 0`. Com rating inicial 1000, zero nao e "sem historico" —
    // e uma pontuacao de Bronze profundo que ninguem teve.
    const situacoes = new Map<string, SituacaoNaTemporada>();
    oficial.competidores.forEach((competidor, i) => {
      situacoes.set(
        competidor.userId,
        situacaoNaTemporada(atuais[i].data(), jogadores[i].data())
      );
    });

    // ---------------------------------------------------------------------
    // A FORCA DE CADA LADO (secao 9)
    // ---------------------------------------------------------------------
    // Montada com os ratings JA SEMEADOS, e nao com o que estava no banco: um
    // estreante entra no calculo valendo 1000, como todo mundo.
    const mesa = ladosDaMesa(oficial.competidores);
    if (mesa === null) {
      // `decidirProcessamento` ja recusou este caso. Se chegou aqui, a mesa mudou
      // entre a decisao e a transacao — falhar alto e melhor que pontuar torto.
      throw new Error(`a partida ${matchId} deixou de descrever duas duplas.`);
    }
    const ratingsPorLado = new Map<string, number[]>();
    for (const [lado, uids] of mesa.porLado) {
      ratingsPorLado.set(
        lado,
        uids.map((u) => (situacoes.get(u) as SituacaoNaTemporada).rating)
      );
    }

    const agora = agoraIso();
    const deltas: Record<string, number> = {};

    oficial.competidores.forEach((competidor, i) => {
      const situacao = situacoes.get(competidor.userId) as SituacaoNaTemporada;
      const meuLado = competidor.lado as string;
      const outroLado = mesa.lados.find((l) => l !== meuLado) as string;

      const entrada: EntradaDeCalculo = {
        matchId: oficial.matchId,
        userId: competidor.userId,
        saldoAtual: situacao.rating,
        estadoCompetitivo: situacao.estado,
        estado: oficial.estado,
        motivoEncerramento: oficial.motivoEncerramento,
        ladoVencedor: oficial.ladoVencedor,
        ladoDoJogador: competidor.lado,
        placar: oficial.placar,
        tipo: oficial.tipo,
        ratingsDaMinhaDupla: ratingsPorLado.get(meuLado) as number[],
        ratingsDaDuplaAdversaria: ratingsPorLado.get(outroLado) as number[],
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
        saldoAtual: situacao.rating,
        delta,
        registradoEm: agora,
        politica,
      });
      tx.set(db().collection(C_LEDGER).doc(lancamento.chaveIdempotencia), lancamento);

      const anterior = atuais[i].data();

      // A EVOLUCAO DO JOGADOR ACONTECE EM `situacaoApos`, que e PURA e mora em
      // `competicao.ts`. Este arquivo nao repete a aritmetica de contadores,
      // consumo de colocacao nem carimbo de desempate — se repetisse, haveria
      // duas versoes da mesma regra e a que os testes exercitam seria a que nao
      // roda em producao.
      const depois = situacaoApos(situacao, {
        resultado: resultadoElo(oficial.ladoVencedor, meuLado),
        delta,
        saldoDaPartida:
          pontosDoLado(oficial.placar, meuLado) - pontosDoLado(oficial.placar, outroLado),
        agora,
      });

      if (depois.rating !== lancamento.rankingAfter) {
        // As duas contas do mesmo numero tem que fechar: a do ledger
        // (`antes + delta`) e a da situacao. Divergirem significa defeito de
        // programacao, e deixar passar gravaria um saldo que a cadeia do ledger
        // nao explica.
        throw new Error(
          `incoerencia ao aplicar ${matchId} para ${competidor.userId}: ` +
            `ledger diz ${lancamento.rankingAfter}, situacao diz ${depois.rating}.`
        );
      }

      // SECAO 15: a Liga so e gravada quando o jogador esta consolidado. Quem
      // consolida NESTA partida ja recebe a Liga do rating com que terminou —
      // e o que a secao 8 pede ao dizer "ao completar a 10a partida valida ...
      // recebe a Liga correspondente ao rating atual".
      const degrau =
        depois.estado === "classificado" ? ligaDe(escada, depois.rating) : null;

      const linha: Partial<StandingArmazenado> & Record<string, unknown> = {
        seasonId: season.seasonId,
        uid: competidor.userId,
        // PROJECAO, nao fonte. O valor canonico e `playerIdentities/{uid}` — e a
        // guarda acima ja provou que ele existe, por isso o `as string` nao e um
        // desejo: sem identidade a execucao nao chega ate aqui.
        publicPlayerId: idsPublicos.get(competidor.userId) as string,
        // Apelido e avatar TAMBEM sao projecao, e a fonte deles e
        // `publicProfiles/{publicId}` (ver `apresentacaoCanonicaDe`). Ate a OS de
        // integracao nao havia fonte nenhuma e estes campos nasciam vazios; agora
        // ha, e o valor e copiado a cada processamento.
        //
        // PROJECAO SIGNIFICA: quem quiser saber o apelido de verdade le o perfil
        // publico. Isto aqui e uma copia para a lista nao precisar de N leituras,
        // e uma copia velha nunca torna o perfil errado — so a lista atrasada.
        // Perfil ausente preserva o que ja havia, e nunca cai para o uid (§31-F
        // do contrato social: "Nao usar UID como fallback").
        apelido: apresentacoes.get(competidor.userId)?.apelido
          ?? (typeof anterior?.apelido === "string" ? anterior.apelido : ""),
        avatar: apresentacoes.get(competidor.userId)?.avatar
          ?? (typeof anterior?.avatar === "string" ? anterior.avatar : ""),
        pontos: depois.rating,
        /// O rating com que o jogador ENTROU na temporada. Guardado para que a
        /// cadeia do ledger (`antes + delta == depois`, lancamento a lancamento)
        /// possa ser conferida a partir de um ponto de partida conhecido, em vez
        /// de assumir zero.
        ratingInicial: situacao.ratingInicial,
        partidasComputadas: depois.partidas,
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

        estadoCompetitivo: depois.estado,
        partidasDeQualificacao: depois.partidasDeQualificacao,
        qualificacaoExigida: depois.qualificacaoExigida,
        vitorias: depois.vitorias,
        derrotas: depois.derrotas,
        empates: depois.empates,
        saldoPontos: depois.saldoPontos,
        abandonos: depois.abandonos,
        ratingAtingidoEm: depois.ratingAtingidoEm,
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
      // SECAO 25: a versao da politica que produziu ESTES deltas. Sem ela, um
      // delta de 13 pontos gravado hoje seria inexplicavel depois da primeira
      // correcao de formula.
      politica,
      // SECAO 4: a natureza com que a partida foi processada fica registrada.
      // Uma reclassificacao posterior passa a ser detectavel comparando com o
      // documento oficial, em vez de invisivel.
      tipo: oficial.tipo,
      jogadores: oficial.competidores.map((c) => c.userId).sort(),
      deltas,
      estadoDaPartida: oficial.estado,
      encerradaEm: oficial.encerradaEm,
      processadoEm: agora,
      origem,
      autor,
      versaoFormato: 1,
    });

    // A PARTIDA SAI DA FILA, MAS NAO SOME (secao 26: "distinguir processado,
    // recusado e ainda pendente"). Apagar o documento perderia justamente a
    // informacao de que ela ESTEVE pendente e de com que `tipo` foi observada —
    // que e o que sustenta a guarda de imutabilidade da secao 4.
    tx.set(
      db().collection(C_BACKLOG).doc(matchId),
      {
        matchId,
        situacao: "processado",
        motivo: null,
        detalhe: null,
        tipo: oficial.tipo,
        estado: oficial.estado,
        seasonId: season.seasonId,
        politica,
        processadoEm: agora,
      },
      { merge: true }
    );

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
///
/// AS TRES SITUACOES (secao 26), e a diferenca entre elas e operacional:
///   pendente ..... falta uma peca (temporada, politica). Vai ser reprocessada.
///   recusado ..... nunca vai pontuar, e ja se sabe por que.
///   processado ... virou pontuacao. Escrito na transacao, nao aqui.
///
/// `registradoEm` NAO e sobrescrito num item que ja existia: ele marca quando a
/// partida entrou na fila, e reescreve-lo a cada tentativa apagaria a idade do
/// backlog, que e o numero que diz se o reprocessamento esta dando conta.
async function guardarNoBacklog(
  resultado: ResultadoOficial,
  decisao: DecisaoDeProcessamento,
  situacao: "pendente" | "recusado"
): Promise<void> {
  const agora = agoraIso();
  const ref = db().collection(C_BACKLOG).doc(resultado.matchId);
  await db().runTransaction(async (tx) => {
    const existente = await tx.get(ref);
    tx.set(
      ref,
      {
        matchId: resultado.matchId,
        situacao,
        motivo: decisao.recusa,
        detalhe: decisao.detalhe,
        estado: resultado.estado,
        // A NATUREZA OBSERVADA (secao 4). Escrita na primeira observacao e
        // preservada depois: sobrescreve-la a cada tentativa faria a guarda de
        // imutabilidade comparar o tipo consigo mesmo e nunca detectar nada.
        tipo:
          typeof existente.data()?.tipo === "string"
            ? existente.data()?.tipo
            : resultado.tipo,
        encerradaEm: resultado.encerradaEm,
        jogadores: resultado.competidores.map((c) => c.userId).sort(),
        registradoEm:
          typeof existente.data()?.registradoEm === "string"
            ? existente.data()?.registradoEm
            : agora,
        avaliadoEm: agora,
      },
      { merge: true }
    );
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
    let consulta = aplicarOrdem(
      db().collection(C_STANDINGS).where("seasonId", "==", params.seasonId),
      ORDEM_TEMPORADA
    ).limit(LOTE_APURACAO);
    if (ultimo !== null) consulta = consulta.startAfter(ultimo);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    const linhas: LinhaParaApurar[] = pagina.docs.map((d) => {
      const linha = standingDeDoc(d.data());
      return {
        uid: linha.uid,
        publicPlayerId: linha.publicPlayerId,
        pontos: linha.pontos,
        vitorias: linha.vitorias,
        saldoPontos: linha.saldoPontos,
        abandonos: linha.abandonos,
        ratingAtingidoEm: linha.ratingAtingidoEm,
        posicao: linha.posicao,
        estadoCompetitivo: linha.estadoCompetitivo,
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
// CONSOLIDACAO DO ENCERRAMENTO (secoes 19, 20 e 21)
// ---------------------------------------------------------------------------

export interface RelatorioDeConsolidacao {
  readonly seasonId: string;
  readonly classificados: number;
  readonly percorridos: number;
  readonly jaConsolidada: boolean;
}

/// Carimba, em `rankingPlayers/{uid}`, o rating final de quem terminou a
/// temporada CLASSIFICADO.
///
/// POR QUE ISTO EXISTE: e a unica ponte entre uma temporada e a seguinte. O soft
/// reset (secao 20) precisa saber o rating final anterior, e a revalidacao
/// (secao 21) precisa saber que houve "classificacao competitiva anterior". Sem
/// este carimbo, todo mundo entraria na temporada nova como jogador novo — 1000
/// e 10 partidas — e a secao 20 estaria implementada no papel e desligada na
/// pratica.
///
/// SO OS CLASSIFICADOS SAO CARIMBADOS. Quem viu a temporada acabar no meio da
/// colocacao nunca teve classificacao competitiva, e a secao 21 condiciona a
/// revalidacao a ter tido uma. Ele volta as 10 partidas, do 1000.
///
/// O CARIMBO ANTERIOR NAO E APAGADO por uma temporada em que o jogador nao
/// consolidou. Quem foi Diamante em 2026-A, jogou 3 das 5 partidas de
/// revalidacao em 2026-B e sumiu, entra em 2026-C com o soft reset do rating de
/// 2026-A — o ultimo rating que o sistema efetivamente mediu. E o que o `merge`
/// abaixo garante, por nao escrever nada para quem nao consolidou.
///
/// NAO TOCA EM `rankingStandings` (secao 19: a classificacao final fica
/// congelada). Le a temporada que fechou e escreve so no agregado do jogador.
///
/// IDEMPOTENTE por `rankingTasks/{seasonId|consolidacao}`, e PAGINADA pelos
/// mesmos motivos da apuracao.
export async function consolidarTemporada(params: {
  seasonId: string;
  autor: string;
}): Promise<RelatorioDeConsolidacao> {
  const id = `${params.seasonId}|consolidacao`;
  const tarefaRef = db().collection(C_TASKS).doc(id);
  const agora = agoraIso();

  const reservou = await db().runTransaction(async (tx) => {
    const doc = await tx.get(tarefaRef);
    if (doc.exists) return false;
    tx.create(tarefaRef, {
      chave: id,
      tarefa: "consolidacao",
      seasonId: params.seasonId,
      iniciadaEm: agora,
      autor: params.autor,
    });
    return true;
  });

  if (!reservou) {
    return {
      seasonId: params.seasonId,
      classificados: 0,
      percorridos: 0,
      jaConsolidada: true,
    };
  }

  let ultimo: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let classificados = 0;
  let percorridos = 0;

  for (;;) {
    let consulta = aplicarOrdem(
      db().collection(C_STANDINGS).where("seasonId", "==", params.seasonId),
      ORDEM_TEMPORADA
    ).limit(LOTE_APURACAO);
    if (ultimo !== null) consulta = consulta.startAfter(ultimo);

    const pagina = await consulta.get();
    if (pagina.empty) break;

    const lote = db().batch();
    for (const doc of pagina.docs) {
      const linha = standingDeDoc(doc.data());
      percorridos += 1;
      if (linha.estadoCompetitivo !== "classificado") continue;
      classificados += 1;
      lote.set(
        db().collection(C_PLAYERS).doc(linha.uid),
        {
          ultimaTemporadaConsolidada: params.seasonId,
          ratingFinalConsolidado: linha.pontos,
          ligaFinalConsolidada: linha.ligaId,
          consolidadoEm: agora,
        },
        { merge: true }
      );
    }
    await lote.commit();

    ultimo = pagina.docs[pagina.docs.length - 1];
    if (pagina.size < LOTE_APURACAO) break;
  }

  await db().collection(C_AUDIT).doc(id).set({
    eventoId: id,
    evento: "consolidacao",
    seasonId: params.seasonId,
    autor: params.autor,
    antes: null,
    depois: { classificados, percorridos },
    registradoEm: agoraIso(),
  });

  return { seasonId: params.seasonId, classificados, percorridos, jaConsolidada: false };
}

// ---------------------------------------------------------------------------
// REPROCESSAMENTO DO BACKLOG (secao 26)
// ---------------------------------------------------------------------------

export interface RelatorioDeReprocessamento {
  readonly examinados: number;
  readonly processados: number;
  readonly recusados: number;
  readonly aindaPendentes: number;
  /// Onde parar e retomar. `null` quando a fila acabou.
  readonly cursor: string | null;
  readonly fim: boolean;
  readonly porRecusa: Record<string, number>;
}

/// Tamanho do lote de reprocessamento.
///
/// MUITO MENOR QUE O DA APURACAO (400), e de proposito: cada item aqui custa uma
/// TRANSACAO com varias leituras e escritas, e nao uma linha de `batch`. Trinta
/// itens por chamada mantem a execucao dentro do tempo de uma Function sem
/// depender de sorte, e a retomada por cursor faz o resto.
const LOTE_BACKLOG = 30;

/// Esvazia o `rankingBacklog`, um lote por chamada.
///
/// A SECAO 26 PEDE SETE PROPRIEDADES, e cada uma tem um dono concreto:
///
///   idempotente ............. `rankingContributions/{chave}` e o id do
///                             documento; a segunda passagem recusa
///                             `ja_processado` sem efeito.
///   transacional ............ cada item passa por `processarResultadoOficial`,
///                             que aplica contribuicao, ledger e classificacao
///                             numa transacao so.
///   nao duplicar ............ consequencia das duas acima.
///   registrar a versao ...... `politica` entra no ledger e na contribuicao.
///   preservar a ordem ....... a fila e percorrida por `registradoEm` crescente,
///                             que e a ordem em que as partidas encerraram.
///   paginado ................ `LOTE_BACKLOG` itens por chamada.
///   permitir retomada ....... o `cursor` devolvido volta como parametro.
///
/// A ORDEM CRONOLOGICA NAO E COSMETICA: o Elo nao e comutativo. Aplicar a partida
/// de marco depois da de abril daria ao jogador um rating diferente, porque a
/// expectativa de cada uma depende do rating vigente na hora. Reprocessar na
/// ordem em que as partidas encerraram e o que faz o resultado do backlog ser o
/// mesmo que teria saido se a politica existisse desde o inicio.
///
/// SO ITENS `pendente` SAO EXAMINADOS. `processado` ja virou pontuacao e
/// `recusado` ja foi decidido — reexamina-los a cada passada faria a fila nunca
/// encurtar. Um `recusado` pode ser reexaminado sob demanda, chamando
/// `processarResultadoOficial` diretamente para aquele `matchId`.
export async function reprocessarBacklog(params: {
  autor: string;
  seasonIdAlvo?: string;
  cursor?: string | null;
  limite?: number;
}): Promise<RelatorioDeReprocessamento> {
  const limite = Math.min(Math.max(params.limite ?? LOTE_BACKLOG, 1), LOTE_BACKLOG);

  let consulta = db()
    .collection(C_BACKLOG)
    .where("situacao", "==", "pendente")
    .orderBy("registradoEm", "asc")
    .orderBy("matchId", "asc")
    .limit(limite + 1);

  if (typeof params.cursor === "string" && params.cursor.length > 0) {
    const partes = params.cursor.split("|");
    if (partes.length !== 2) {
      throw new Error(`cursor de reprocessamento ilegivel: "${params.cursor}"`);
    }
    consulta = consulta.startAfter(partes[0], partes[1]);
  }

  const pagina = await consulta.get();
  const temMais = pagina.size > limite;
  const docs = temMais ? pagina.docs.slice(0, limite) : pagina.docs;

  let processados = 0;
  let recusados = 0;
  let aindaPendentes = 0;
  const porRecusa: Record<string, number> = {};

  // SEQUENCIAL, E NAO `Promise.all`. Duas partidas do mesmo jogador processadas
  // em paralelo disputariam a mesma linha de standing; a transacao resolveria o
  // conflito reexecutando uma delas, mas ao custo de retentativas e — o que
  // importa mais — sem garantia de qual chegaria primeiro, o que quebraria a
  // ordem cronologica que o paragrafo acima explica ser necessaria.
  for (const doc of docs) {
    const matchId = `${doc.data().matchId ?? doc.id}`;
    const r = await processarResultadoOficial({
      matchId,
      origem: "reprocessamento",
      autor: params.autor,
      seasonIdAlvo: params.seasonIdAlvo,
    });
    if (r.processada) {
      processados += 1;
      continue;
    }
    const motivo = r.recusa ?? "desconhecida";
    porRecusa[motivo] = (porRecusa[motivo] ?? 0) + 1;
    // Continua `pendente` quando a recusa e "falta uma peca"; vira `recusado`
    // quando e definitiva. Quem faz essa gravacao e `processarResultadoOficial`,
    // que ja sabe a diferenca — aqui so se conta.
    if (motivo === "sem_temporada_vigente" || motivo === "temporada_encerrada" ||
        motivo === "politica_nao_definida") {
      aindaPendentes += 1;
    } else {
      recusados += 1;
    }
  }

  const ultimo = docs.length > 0 ? docs[docs.length - 1] : null;
  const cursor =
    temMais && ultimo !== null
      ? `${ultimo.data().registradoEm}|${ultimo.data().matchId ?? ultimo.id}`
      : null;

  logger.info("lote de reprocessamento do backlog", {
    examinados: docs.length,
    processados,
    recusados,
    aindaPendentes,
    fim: !temMais,
  });

  return {
    examinados: docs.length,
    processados,
    recusados,
    aindaPendentes,
    cursor,
    fim: !temMais,
    porRecusa,
  };
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
/// Aplica uma ordem declarada a uma consulta.
///
/// A ORDEM VEM DE `ordenacao.ts`, e nao esta escrita aqui. E o que garante que a
/// consulta, o cursor e a comparacao em memoria concordem: os tres derivam da
/// mesma lista. Quando os `orderBy` eram digitados a mao em quatro lugares,
/// acrescentar um criterio exigia lembrar dos quatro.
function aplicarOrdem(
  consulta: FirebaseFirestore.Query,
  ordem: ReadonlyArray<CriterioDeOrdem>
): FirebaseFirestore.Query {
  let q = consulta;
  for (const criterio of ordem) q = q.orderBy(campoNoBanco(criterio), criterio.sentido);
  return q;
}

export async function paginaDaTemporada(params: {
  seasonId: string;
  limite: number;
  depoisDe: ReadonlyArray<number | string> | null;
}): Promise<StandingArmazenado[]> {
  let consulta = aplicarOrdem(
    db().collection(C_STANDINGS).where("seasonId", "==", params.seasonId),
    ORDEM_TEMPORADA
  ).limit(params.limite + 1);

  if (params.depoisDe !== null) {
    consulta = consulta.startAfter(...params.depoisDe);
  }

  const snap = await consulta.get();
  return snap.docs.map((d) => standingDeDoc(d.data()));
}

/// Le uma pagina do agregado de vida inteira (o escopo "global" do cliente).
export async function paginaGlobal(params: {
  limite: number;
  depoisDe: ReadonlyArray<number | string> | null;
}): Promise<StandingArmazenado[]> {
  let consulta = aplicarOrdem(db().collection(C_PLAYERS), ORDEM_GLOBAL).limit(
    params.limite + 1
  );

  if (params.depoisDe !== null) {
    consulta = consulta.startAfter(...params.depoisDe);
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
  const inteiro = (campo: string): number =>
    typeof o[campo] === "number" ? (o[campo] as number) : 0;
  return {
    seasonId: typeof o.seasonId === "string" ? o.seasonId : "",
    uid: `${o.uid}`,
    publicPlayerId: `${o.publicPlayerId}`,
    apelido: typeof o.apelido === "string" ? o.apelido : "",
    avatar: typeof o.avatar === "string" ? o.avatar : "",
    pontos: inteiro("pontos"),
    partidasComputadas: inteiro("partidasComputadas"),
    posicao: typeof o.posicao === "number" ? o.posicao : null,
    posicaoAnterior: typeof o.posicaoAnterior === "number" ? o.posicaoAnterior : null,
    direcao: direcaoDeJson(o.direcao),
    deltaPosicao: inteiro("deltaPosicao"),
    ligaId: typeof o.ligaId === "string" ? o.ligaId : null,
    ligaNome: typeof o.ligaNome === "string" ? o.ligaNome : null,
    selo: typeof o.selo === "string" ? o.selo : null,
    atualizadoEm: typeof o.atualizadoEm === "string" ? o.atualizadoEm : "",
    estadoCompetitivo: estadoCompetitivoDeJson(o.estadoCompetitivo),
    partidasDeQualificacao: inteiro("partidasDeQualificacao"),
    qualificacaoExigida: inteiro("qualificacaoExigida"),
    vitorias: inteiro("vitorias"),
    derrotas: inteiro("derrotas"),
    empates: inteiro("empates"),
    saldoPontos: inteiro("saldoPontos"),
    abandonos: inteiro("abandonos"),
    ratingAtingidoEm:
      typeof o.ratingAtingidoEm === "string" ? o.ratingAtingidoEm : "",
  };
}

/// O podio: as tres primeiras linhas da mesma ordem.
///
/// Consulta propria com `limit(3)`, e nao um recorte da primeira pagina: as duas
/// coisas coincidem hoje, mas o cliente pode pedir a primeira pagina com cursor
/// (num refresh a partir do meio) e ai o podio deixaria de ser o podio.
export async function podioDaTemporada(seasonId: string): Promise<StandingArmazenado[]> {
  const snap = await aplicarOrdem(
    db().collection(C_STANDINGS).where("seasonId", "==", seasonId),
    ORDEM_TEMPORADA
  )
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
///
/// O INDICE REVERSO E O CANONICO, `publicIdIndex`, e nao mais um proprio. Antes
/// da OS de integracao este caminho lia `rankingPublicIds` — o mapa que o
/// proprio ranking mantinha. Duas consequencias de ter trocado: um id emitido
/// pelo dominio social passa a resolver aqui (antes nao resolvia, porque nunca
/// tinha sido gravado no mapa do ranking), e nao existe mais um segundo mapa que
/// possa discordar do primeiro.
export async function porIdPublico(
  publicPlayerId: string,
  seasonId: string | null
): Promise<{ standing: StandingArmazenado | null; uid: string } | null> {
  const reverso = await db()
    .collection(C_INDICE_PUBLICO_CANONICO)
    .doc(publicPlayerId)
    .get();
  const uid = reverso.data()?.uid;
  if (typeof uid !== "string" || uid.length === 0) return null;
  if (seasonId === null) return { standing: null, uid };
  return { standing: await meuStanding(seasonId, uid), uid };
}

/// Ordena em memoria pela ordem oficial. Usado so onde o conjunto ja e pequeno e
/// limitado (o podio, por exemplo), nunca sobre a base inteira.
export function ordenarOficial<T extends ChaveDeOrdem>(linhas: T[]): T[] {
  return [...linhas].sort(compararOficial);
}

// ---------------------------------------------------------------------------
// PASSE VIP QUINZENAL DE CORTESIA
//
// A PORTA UNICA de materializacao. Nao existe segundo lugar que crie ciclo,
// calcule data ou decida disponibilidade — a regra toda mora em `passe.ts`, e
// este bloco so a aplica dentro de UMA transacao.
//
// AS DUAS COLECOES, e por que sao duas:
//
//   playerCourtesyPass/{uid} ............... o CONTROLE. Retrato do ciclo
//                                            vigente, para que a decisao leia um
//                                            documento so em vez de varrer o
//                                            historico a cada entrada de mesa.
//   playerCourtesyPass/{uid}/cycles/{id} ... o HISTORICO. Um documento por ciclo,
//                                            e nenhum e apagado: e dele que sai a
//                                            idempotencia do recibo, e apagar o
//                                            passado abriria a porta para
//                                            consumir duas vezes.
//
// As duas sao INTERNAS. O cliente nao le e nao escreve nenhuma das duas — as
// Rules negam tudo, e `firebase/testes/passe.test.js` prova. O que o aplicativo
// pode ver e a PROJECAO, e projecao nao e documento.
//
// NENHUMA DELAS E `playerEntitlements`, e isso e a decisao inteira: aquela e a
// autoridade da ASSINATURA paga, esta e a da CORTESIA. Duas razoes diferentes
// para alguem ser VIP, em dois documentos diferentes, com donos diferentes.
// ---------------------------------------------------------------------------

export const C_PASSE = "playerCourtesyPass";
export const SUB_CICLOS = "cycles";

/// O resultado de materializar. `disponivel` e o que a chamada precisa saber;
/// o resto e para log, teste e para a OS de admissao.
export interface EstadoDoPasse {
  readonly acao: "criar_primeiro" | "reaproveitar" | "criar_novo" | "aguardar" | "falha_fechada";
  readonly disponivel: boolean;
  readonly cicloId: string | null;
  readonly validoAte: string | null;
  readonly proximaElegibilidadeEm: string | null;
  readonly motivo: MotivoDeFalha | null;
}

/// Identificador OPACO de ciclo e de admissao.
///
/// `randomUUID` e nao algo derivado do uid, da data ou de um contador: os tres
/// se deduzem de fora, e um identificador dedutivel deixa de identificar. E
/// tambem nao e sequencial — sequencia conta quantos existem, que e informacao
/// que ninguem pediu para publicar.
function idOpacoDePasse(): string {
  return idOpaco();
}

/// MATERIALIZA o passe deste jogador e devolve o estado atual.
///
/// Tudo numa transacao, e a transacao e o ponto: duas chamadas simultaneas do
/// mesmo jogador — duas abas, dois cliques, duas conexoes — leem o mesmo
/// controle, e o Firestore aborta e repete a segunda. O resultado e UM ciclo,
/// nunca dois. Sem transacao, as duas leriam "nao ha passe" e as duas criariam.
///
/// IDEMPOTENTE: chamar de novo sem o tempo passar devolve o mesmo ciclo e nao
/// escreve nada. Materializar NAO consome — quem consome e a admissao, na OS
/// seguinte, e ela tem porta propria.
///
/// `agoraMs` e injetavel para que sete e quinze dias sejam provaveis sem
/// esperar sete e quinze dias. Em producao ele nao vem do cliente: vem de
/// `Date.now()` do servidor, e o cliente nao participa da conta.
export async function materializarPasseDeCortesia(
  uid: string,
  agoraMs: number = Date.now()
): Promise<EstadoDoPasse> {
  const controleRef = db().collection(C_PASSE).doc(uid);

  return db().runTransaction(async (tx) => {
    const snap = await tx.get(controleRef);
    const leitura = lerControle(snap.exists ? snap.data() : null);
    const decisao = decidirMaterializacao(leitura, agoraMs);

    if (decisao.acao === "falha_fechada") {
      // NAO normaliza e NAO reescreve. Um documento que a autoridade nao
      // reconhece e um direito de alguem escrito por outro codigo; consertar
      // por conta propria seria decidir sozinho o que ele queria dizer.
      logger.error("passe de cortesia: estado persistido recusado", {
        motivo: decisao.motivo,
      });
      return {
        acao: "falha_fechada" as const,
        disponivel: false,
        cicloId: null,
        validoAte: null,
        proximaElegibilidadeEm: null,
        motivo: decisao.motivo,
      };
    }

    if (decisao.acao === "reaproveitar") {
      const c = (leitura as { estado: "valido"; controle: ControleDePasse }).controle;
      // Nao escreve: reaproveitar e uma LEITURA. Gravar aqui faria toda consulta
      // sujar o documento e transformaria idempotencia em ilusao.
      return {
        acao: "reaproveitar" as const,
        disponivel: true,
        cicloId: c.cicloAtualId,
        validoAte: c.validoAte,
        proximaElegibilidadeEm: null,
        motivo: null,
      };
    }

    if (decisao.acao === "aguardar") {
      // O UNICO caminho de leitura que escreve, e ele escreve NO MAXIMO UMA VEZ
      // por ciclo: quando a autoridade constata, pela primeira vez, que o ciclo
      // acabou. `precisaEncerrar` ja e falso da segunda consulta em diante.
      //
      // Registrar isso e o que torna a regressao de relogio inofensiva. Sem
      // esta escrita o encerramento seria RECALCULADO a cada consulta, e um
      // relogio que voltasse atras encontraria o passe outra vez dentro da
      // validade — que foi exatamente o defeito que a prova contra o banco
      // pegou depois de a prova pura ter passado.
      if (decisao.precisaEncerrar) {
        const c = (leitura as { estado: "valido"; controle: ControleDePasse }).controle;
        const encerradoEm = isoDeInstante(agoraMs);
        tx.update(controleRef, { cicloEncerradoEm: encerradoEm });
        if (c.cicloAtualId !== null) {
          tx.update(controleRef.collection(SUB_CICLOS).doc(c.cicloAtualId), { encerradoEm });
        }
      }
      return {
        acao: "aguardar" as const,
        disponivel: false,
        cicloId: null,
        validoAte: null,
        proximaElegibilidadeEm: isoDeInstante(decisao.proximaElegibilidadeEmMs),
        motivo: null,
      };
    }

    // criar_primeiro | criar_novo — o unico caminho que escreve ciclo.
    const plano = decisao.plano;
    const cicloId = idOpacoDePasse();
    const recebidoEm = isoDeInstante(plano.recebidoEmMs);
    const validoAte = isoDeInstante(plano.validoAteMs);
    const proximaElegibilidadeEm = isoDeInstante(plano.proximaElegibilidadeEmMs);

    const ciclo: CicloDePasse = {
      cicloId,
      recebidoEm,
      validoAte,
      proximaElegibilidadeEm,
      consumidoEm: null,
      encerradoEm: null,
      tentativaEntradaId: null,
      admissaoId: null,
      versaoContrato: VERSAO_CONTRATO_PASSE,
    };

    // O historico primeiro, o controle depois. A ordem nao muda nada dentro da
    // transacao (ela e atomica), mas deixa a intencao legivel: o ciclo e o fato,
    // e o controle e o retrato dele.
    tx.create(controleRef.collection(SUB_CICLOS).doc(cicloId), ciclo);
    tx.set(controleRef, {
      versaoContrato: VERSAO_CONTRATO_PASSE,
      cicloAtualId: cicloId,
      recebidoEm,
      validoAte,
      proximaElegibilidadeEm,
      consumidoEm: null,
      // Ciclo NOVO nasce aberto. O campo vai explicito mesmo com `tx.set`
      // sobrescrevendo o documento inteiro: um encerramento herdado do ciclo
      // anterior faria o passe novo nascer morto.
      cicloEncerradoEm: null,
      ultimaMaterializacaoEm: isoDeInstante(agoraMs),
    });

    return {
      acao: decisao.acao,
      disponivel: true,
      cicloId,
      validoAte,
      proximaElegibilidadeEm: null,
      motivo: null,
    };
  });
}

/// A projecao do DONO, materializando antes de projetar.
///
/// Materializar aqui e o desenho: o estado do passe so existe quando alguem
/// pergunta, e perguntar e o gatilho. Nao ha scheduler porque nao precisa haver.
export async function projetarPasseParaODono(
  uid: string,
  agoraMs: number = Date.now()
): Promise<ProjecaoDoProprietario> {
  await materializarPasseDeCortesia(uid, agoraMs);
  const snap = await db().collection(C_PASSE).doc(uid).get();
  return projecaoDoProprietario(lerControle(snap.exists ? snap.data() : null), agoraMs);
}

/// O ciclo vigente deste jogador, ou `null`. Leitura pura, sem materializar.
/// Existe para a OS de admissao e para as provas de recibo.
export async function cicloVigente(uid: string): Promise<CicloDePasse | null> {
  const controle = await db().collection(C_PASSE).doc(uid).get();
  const leitura = lerControle(controle.exists ? controle.data() : null);
  if (leitura.estado !== "valido" || leitura.controle.cicloAtualId === null) return null;
  const doc = await db()
    .collection(C_PASSE)
    .doc(uid)
    .collection(SUB_CICLOS)
    .doc(leitura.controle.cicloAtualId)
    .get();
  return doc.exists ? (doc.data() as CicloDePasse) : null;
}
