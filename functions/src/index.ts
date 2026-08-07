// index.ts — Cloud Functions do Motor de Torneios (OS 02 secoes 19, 20 e 21).
//
// DIVISAO DE TRABALHO, E ELA E A COISA MAIS IMPORTANTE DESTE ARQUIVO:
//   - QUEM DECIDE  -> o dominio Dart, via domain.ts. Elegibilidade, lotacao,
//                     desempate, avanco, conclusao e premiacao saem de la.
//   - QUEM EXECUTA -> este arquivo. Autenticacao, transacao, leitura e escrita.
//
// Nenhuma regra de competicao esta escrita em TypeScript. Se um `if` de negocio
// aparecer aqui, ele esta no lugar errado e vai divergir do app (OS 02 secao 1).
//
// OS 02 secao 21: todas as operacoes sensiveis passam por aqui, e o firestore.rules
// nega escrita direta do cliente em classificacao, resultado, vencedor, premio,
// elegibilidade, status, fase, posicao, convite especial e concessao.

import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Transaction } from "firebase-admin/firestore";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

import { dominio, agoraUtc, TarefaPendente } from "./domain";
import { executarUmaVez, chavesExecutadas } from "./idempotency";

initializeApp();
const db = () => getFirestore();

// App Check exigido em tudo que o cliente chama (OS 02 secao 20). Nao substitui
// autenticacao: impede que um cliente NAO-oficial fale com a API, enquanto o
// `request.auth` diz QUEM esta falando.
const opcoesCliente = { enforceAppCheck: true, region: "southamerica-east1" };
const opcoesServidor = { region: "southamerica-east1" };

function exigirAutenticacao(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "E preciso estar autenticado.");
  }
  return uid;
}

function exigirAdmin(req: CallableRequest): string {
  const uid = exigirAutenticacao(req);
  if (req.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "Operacao restrita a administracao.");
  }
  return uid;
}

// ---------------------------------------------------------------------------
// Leituras auxiliares
// ---------------------------------------------------------------------------

async function lerTemplate(tournamentId: string) {
  const doc = await db().collection("tournaments").doc(tournamentId).get();
  if (!doc.exists) {
    throw new HttpsError("not-found", `torneio desconhecido: ${tournamentId}`);
  }
  return doc.data() as Record<string, unknown>;
}

async function lerEdicao(tournamentId: string, editionId: string) {
  const doc = await db()
    .collection("tournaments").doc(tournamentId)
    .collection("editions").doc(editionId)
    .get();
  if (!doc.exists) {
    throw new HttpsError("not-found", `edicao desconhecida: ${editionId}`);
  }
  return doc.data() as Record<string, unknown>;
}

/// Monta o retrato de elegibilidade do jogador.
///
/// Le de varias colecoes DE PROPOSITO em vez de confiar num campo denormalizado
/// no perfil: um `nivel` copiado para o documento do jogador seria escrito pelo
/// cliente em algum momento e viraria porta para autoconceder elegibilidade.
async function montarPerfil(userId: string): Promise<Record<string, unknown>> {
  const [perfil, convites, historico] = await Promise.all([
    db().collection("players").doc(userId).get(),
    db().collection("closingInvites")
      .where("userId", "==", userId)
      .where("status", "in", ["convite_aceito", "confirmado"])
      .get(),
    db().collection("tournamentHistory")
      .where("participantesUserIds", "array-contains", userId)
      .get(),
  ]);

  const dados = perfil.data() ?? {};
  const titulos = new Set<string>();
  const participacoes = new Set<string>();
  const temporadas = new Set<string>();
  for (const doc of historico.docs) {
    const h = doc.data();
    participacoes.add(h.tournamentId as string);
    temporadas.add(h.temporada as string);
    if ((h.campeoes as string[] | undefined)?.includes(userId)) {
      titulos.add(h.tournamentId as string);
    }
  }

  return {
    userId,
    nivel: dados.nivel ?? null,
    posicaoRanking: dados.posicaoRanking ?? null,
    assinaturaAtiva: dados.assinaturaAtiva === true,
    // O convite habilita o torneio de encerramento; a colecao guarda a temporada,
    // nao o torneio, entao a traducao acontece aqui.
    convitesAtivos: convites.empty ? [] : ["encerramento_anual"],
    conquistas: Array.isArray(dados.conquistas) ? dados.conquistas : [],
    participacoes: [...participacoes],
    titulos: [...titulos],
    temporadasAtivas: [...temporadas],
    suspenso: dados.suspenso === true,
  };
}

// ---------------------------------------------------------------------------
// INSCRICAO (OS 02 secao 5)
// ---------------------------------------------------------------------------

export const inscreverEmTorneio = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { tournamentId, editionId, parceiroId } = req.data ?? {};
  if (typeof tournamentId !== "string" || typeof editionId !== "string") {
    throw new HttpsError("invalid-argument", "tournamentId e editionId sao obrigatorios.");
  }

  const [template, edicao, perfil] = await Promise.all([
    lerTemplate(tournamentId),
    lerEdicao(tournamentId, editionId),
    montarPerfil(uid),
  ]);

  const registrations = db()
    .collection("tournaments").doc(tournamentId)
    .collection("editions").doc(editionId)
    .collection("registrations");

  // Transacao: entre avaliar a lotacao e gravar a vaga cabe outra inscricao.
  // Sem a transacao, duas chamadas simultaneas na ultima vaga passariam as duas.
  return db().runTransaction(async (tx: Transaction) => {
    const inscricoes = await tx.get(registrations);
    const carteira = await tx.get(db().collection("wallets").doc(uid));
    const saldoFichas = (carteira.data()?.fichas as number | undefined) ?? 0;

    // A DECISAO E DO DOMINIO. Esta Function nao sabe o que e lotacao nem
    // elegibilidade — ela so pergunta e obedece.
    const veredito = dominio.inscrever({
      edicao,
      template,
      perfil,
      vagas: {
        limite: template.limiteParticipantes,
        listaEspera: template.listaEspera === true,
        custoEntrada: (template.custoEntrada as number | undefined) ?? 0,
      },
      agora: agoraUtc(),
      saldoFichas,
      parceiroId: typeof parceiroId === "string" ? parceiroId : null,
      inscricoes: inscricoes.docs.map((d) => d.data()),
    });

    if (!veredito.aceita) {
      throw new HttpsError("failed-precondition", veredito.recusa ?? "inscricao recusada", {
        recusa: veredito.recusa,
        falhas: veredito.falhas,
      });
    }

    const inscricao = veredito.inscricao!;
    // O ID do documento e o userId: uma segunda inscricao do mesmo jogador seria
    // a MESMA escrita. A duplicidade fica impossivel por construcao, e nao por
    // checagem — mesma disciplina da chave de idempotencia do dominio.
    tx.create(registrations.doc(uid), inscricao);

    const debito = inscricao.fichasDebitadas as number;
    if (debito > 0) {
      tx.update(db().collection("wallets").doc(uid), {
        fichas: FieldValue.increment(-debito),
      });
    }

    return { status: inscricao.status, emEspera: inscricao.status === "lista_espera" };
  });
});

export const cancelarInscricaoTorneio = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { tournamentId, editionId } = req.data ?? {};
  if (typeof tournamentId !== "string" || typeof editionId !== "string") {
    throw new HttpsError("invalid-argument", "tournamentId e editionId sao obrigatorios.");
  }

  const ref = db()
    .collection("tournaments").doc(tournamentId)
    .collection("editions").doc(editionId)
    .collection("registrations").doc(uid);

  return db().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) {
      throw new HttpsError("not-found", "inscricao inexistente.");
    }
    const atual = doc.data()!;
    if (atual.status === "cancelado") {
      // Reprocessamento nao e falha: o efeito desejado ja aconteceu.
      return { cancelada: true, jaEstava: true, fichasDevolvidas: 0 };
    }

    const edicao = await lerEdicao(tournamentId, editionId);
    const template = await lerTemplate(tournamentId);
    const permitido = ["inscricoes_abertas", "inscricoes_encerradas", "checkin_aberto"];
    if (!permitido.includes(edicao.status as string)) {
      throw new HttpsError("failed-precondition", "fora_da_janela");
    }

    const devolve = template.devolveFichas === true;
    const fichas = devolve ? ((atual.fichasDebitadas as number) ?? 0) : 0;

    tx.update(ref, { status: "cancelado", atualizadoEm: agoraUtc() });
    if (fichas > 0) {
      tx.update(db().collection("wallets").doc(uid), {
        fichas: FieldValue.increment(fichas),
      });
    }
    return { cancelada: true, jaEstava: false, fichasDevolvidas: fichas };
  });
});

// ---------------------------------------------------------------------------
// RESULTADO (OS 02 secoes 9 e 23)
// ---------------------------------------------------------------------------

/// Recebe o resultado validado do Motor de Partidas.
///
/// NAO exige App Check: quem chama e o servidor de partidas, nao um aparelho.
/// Exige, em compensacao, o claim `motorDePartidas` — deixar esta porta aberta
/// permitiria a qualquer cliente autenticado escrever o proprio placar.
export const receberResultadoPartida = onCall(opcoesServidor, async (req) => {
  exigirAutenticacao(req);
  if (req.auth?.token?.motorDePartidas !== true && req.auth?.token?.admin !== true) {
    throw new HttpsError("permission-denied", "somente o Motor de Partidas envia resultado.");
  }

  const resultado = req.data?.resultado as Record<string, unknown> | undefined;
  if (!resultado) {
    throw new HttpsError("invalid-argument", "resultado e obrigatorio.");
  }
  const tournamentId = resultado.tournamentId as string;
  const editionId = resultado.editionId as string;
  const mesaId = resultado.mesaId as string;

  const edicaoRef = db()
    .collection("tournaments").doc(tournamentId)
    .collection("editions").doc(editionId);

  return db().runTransaction(async (tx) => {
    const [edicaoDoc, mesaDoc] = await Promise.all([
      tx.get(edicaoRef),
      tx.get(edicaoRef.collection("tables").doc(mesaId)),
    ]);
    if (!edicaoDoc.exists) {
      throw new HttpsError("not-found", "edicao desconhecida.");
    }

    const status = edicaoDoc.data()!.status as string;
    const mesa = mesaDoc.data();

    const veredito = dominio.processarResultado({
      resultado,
      // A solicitacao e reconstruida da mesa gravada: e ela que registra a que
      // fase e a que assentos a partida pertence.
      solicitacao: mesa
        ? {
            matchId: mesa.matchId,
            tournamentId,
            editionId,
            faseId: mesa.faseId,
            mesaId,
            assentos: mesa.assentos,
            modalidade: "ABERTO",
            metaPontos: 1,
            solicitadaEm: agoraUtc(),
          }
        : null,
      edicaoEmDisputa: ["preparando_mesas", "em_andamento", "aguardando_validacao"].includes(status),
      // Nao se envia a lista de resultados: a idempotencia real e o `create`
      // abaixo, que o Firestore garante. Enviar uma lista lida fora da transacao
      // daria uma segunda barreira mais fraca que a primeira.
      processados: [],
    });

    if (!veredito.processado) {
      if (veredito.idempotente) return { aceito: true, jaProcessado: true };
      throw new HttpsError("failed-precondition", veredito.recusa ?? "resultado recusado");
    }

    const ref = edicaoRef.collection("results").doc(veredito.chaveIdempotencia);
    const existente = await tx.get(ref);
    if (existente.exists) {
      // Reenvio por timeout do Motor de Partidas. Sucesso, nao erro.
      return { aceito: true, jaProcessado: true };
    }

    tx.create(ref, resultado);
    tx.update(mesaDoc.ref, { status: "encerrada" });
    return { aceito: true, jaProcessado: false };
  });
});

// ---------------------------------------------------------------------------
// AUTOMACAO (OS 02 secao 19)
// ---------------------------------------------------------------------------

/// Tick do agendador. Roda a cada 5 minutos e cuida das edicoes vivas.
///
/// A granularidade nao precisa ser fina: as janelas de torneio sao de minutos a
/// dias, e cada tarefa e idempotente — atrasar um tick nao perde nada, e adiantar
/// nao duplica.
export const tickTorneios = onSchedule(
  { schedule: "every 5 minutes", region: "southamerica-east1" },
  async () => {
    const vivas = await db()
      .collectionGroup("editions")
      .where("status", "in", [
        "agendado", "anunciado", "inscricoes_abertas", "inscricoes_encerradas",
        "checkin_aberto", "preparando_mesas", "em_andamento", "aguardando_validacao",
      ])
      .get();

    for (const doc of vivas.docs) {
      try {
        await processarEdicao(doc.data() as Record<string, unknown>);
      } catch (e) {
        // Uma edicao com problema nao pode travar as outras: o tick seguinte
        // tenta de novo, e a tarefa continua idempotente.
        logger.error("falha ao processar edicao", { edicao: doc.id, erro: String(e) });
      }
    }
  }
);

async function processarEdicao(edicao: Record<string, unknown>): Promise<void> {
  const tournamentId = edicao.tournamentId as string;
  const editionId = edicao.editionId as string;
  const template = await lerTemplate(tournamentId);

  const edicaoRef = db()
    .collection("tournaments").doc(tournamentId)
    .collection("editions").doc(editionId);

  const [inscricoes, fases, executadas] = await Promise.all([
    edicaoRef.collection("registrations").get(),
    edicaoRef.collection("phases").get(),
    chavesExecutadas(tournamentId, editionId),
  ]);

  const ocupando = inscricoes.docs.filter((d) =>
    !["lista_espera", "cancelado", "ausente", "desclassificado"].includes(d.data().status)
  ).length;

  // Fase apuravel = em andamento com todas as mesas encerradas. A checagem de
  // "todas encerradas" e do dominio (faseConcluida), mas para MONTAR a lista a
  // Function so precisa contar — nao ha regra de competicao nisso.
  const fasesApuraveis: string[] = [];
  for (const fase of fases.docs) {
    if (fase.data().status !== "em_andamento") continue;
    const mesas = await edicaoRef.collection("tables")
      .where("faseId", "==", fase.id).get();
    const abertas = mesas.docs.filter((m) =>
      !["encerrada", "cancelada"].includes(m.data().status));
    if (mesas.size > 0 && abertas.length === 0) fasesApuraveis.push(fase.id);
  }

  const { tarefas } = dominio.planejarTarefas({
    edicao,
    template,
    agora: agoraUtc(),
    contexto: {
      lotado: ocupando >= ((template.limiteParticipantes as number | null) ?? Infinity),
      quorumAtingido: ocupando >= ((template.minimoParticipantes as number | null) ?? 0),
      usaCheckin: template.usaCheckin === true,
      fasesApuraveis,
      todasFasesConcluidas:
        fases.size > 0 && fases.docs.every((f) => f.data().status === "concluida"),
    },
    executadas,
  });

  for (const tarefa of tarefas) {
    await executarTarefa(tarefa, edicao, template);
  }
}

async function executarTarefa(
  tarefa: TarefaPendente,
  edicao: Record<string, unknown>,
  template: Record<string, unknown>
): Promise<void> {
  const edicaoRef = db()
    .collection("tournaments").doc(tarefa.tournamentId)
    .collection("editions").doc(tarefa.editionId);

  await executarUmaVez(
    tarefa.chaveIdempotencia,
    {
      tarefa: tarefa.tarefa,
      tournamentId: tarefa.tournamentId,
      editionId: tarefa.editionId,
      alvo: tarefa.alvo,
    },
    async (tx) => {
      // Toda transicao de status passa pelo grafo do dominio, com ator
      // `sistema`. E o que impede a automacao de cancelar um torneio ou reabrir
      // inscricoes — o grafo nao autoriza (OS 02 secao 21).
      if (tarefa.transicaoPara) {
        const veredito = dominio.avaliarTransicao({
          de: edicao.status,
          para: tarefa.transicaoPara,
          ator: "sistema",
        });
        if (!veredito.permitida) {
          logger.warn("transicao automatica recusada pelo dominio", {
            chave: tarefa.chaveIdempotencia, recusa: veredito.recusa,
          });
          return;
        }
        tx.update(edicaoRef, {
          status: veredito.destino,
          atualizadoEm: agoraUtc(),
        });
        tx.create(db().collection("tournamentAudit").doc(), {
          tournamentId: tarefa.tournamentId,
          editionId: tarefa.editionId,
          de: edicao.status,
          para: veredito.destino,
          ator: "sistema",
          em: agoraUtc(),
          motivo: `tarefa ${tarefa.tarefa}`,
        });
      }

      // As tarefas que produzem dado (formar mesas, apurar fase, concluir) sao
      // enfileiradas em vez de executadas aqui: cada uma le colecoes inteiras, e
      // transacao do Firestore tem teto de operacoes. O gatilho correspondente
      // faz o trabalho pesado fora da transacao, e a barreira de idempotencia
      // desta chave ja impede o enfileiramento duplo.
      if (["formar_mesas", "avancar_fase", "conceder_premios"].includes(tarefa.tarefa)) {
        tx.create(db().collection("tournamentJobs").doc(tarefa.chaveIdempotencia), {
          ...tarefa,
          template: template.tournamentId,
          enfileiradaEm: agoraUtc(),
        });
      }
    }
  );
}

// ---------------------------------------------------------------------------
// CONCLUSAO -> PREMIACAO + HISTORICO + REGISTRO ANUAL
// (OS 02 secoes 12, 13, 15 e 16)
// ---------------------------------------------------------------------------

/// Reage a conclusao de uma edicao.
///
/// Gatilho de criacao, e nao de escrita: a conclusao e criada uma unica vez
/// (o dominio recusa a segunda), entao o gatilho dispara uma vez por edicao. Um
/// reenvio do proprio gatilho ainda e coberto pela chave de idempotencia de cada
/// concessao — duas barreiras, porque premiar duas vezes e o erro mais caro do
/// sistema (OS 02 secao 13: "Nunca premiar duas vezes").
export const aoConcluirEdicao = onDocumentCreated(
  {
    document: "tournaments/{tournamentId}/editions/{editionId}/conclusion/{docId}",
    region: "southamerica-east1",
  },
  async (event) => {
    const conclusao = event.data?.data();
    if (!conclusao) return;

    const { tournamentId, editionId } = event.params;
    const edicaoRef = db()
      .collection("tournaments").doc(tournamentId)
      .collection("editions").doc(editionId);

    const [template, edicaoDoc, assetsSeed, politicasSeed] = await Promise.all([
      lerTemplate(tournamentId),
      edicaoRef.get(),
      db().collection("seeds").doc("assets_registry").get(),
      db().collection("seeds").doc("reward_policies").get(),
    ]);

    // Concessoes ja existentes do mesmo torneio/edicao entram como historico: e
    // o que faz um reprocessamento devolver `concessao_duplicada` em vez de
    // premiar de novo.
    const anteriores = await db().collection("rewardGrants")
      .where("tournamentId", "==", tournamentId)
      .where("editionId", "==", editionId)
      .get();

    const { premiacoes } = dominio.planejarPremiacao({
      conclusao,
      template,
      assetsSeed: assetsSeed.data(),
      politicasSeed: politicasSeed.data(),
      agora: agoraUtc(),
      historico: anteriores.docs.map((d) => d.data()),
    });

    const lote = db().batch();

    for (const premio of premiacoes) {
      if (premio.concedida && premio.concessao) {
        const chave = premio.concessao.chaveIdempotencia as string;
        // O ID do documento E a chave de idempotencia: gravar duas vezes o mesmo
        // direito e a mesma escrita. `create` falharia; `set` e convergente.
        lote.set(db().collection("rewardGrants").doc(chave), premio.concessao);
      } else if (premio.recusa) {
        logger.info("premio nao concedido", {
          userId: premio.userId, colocacao: premio.colocacao, recusa: premio.recusa,
        });
      }
      if (premio.fichas && premio.fichas > 0) {
        lote.set(
          db().collection("wallets").doc(premio.userId),
          { fichas: FieldValue.increment(premio.fichas) },
          { merge: true }
        );
      }
    }

    // Historico (OS 02 secao 15): snapshot congelado, id = tournamentId|editionId.
    const classificacao = await edicaoRef.collection("standings")
      .orderBy("posicao").get();
    const fases = await edicaoRef.collection("phases").orderBy("ordem").get();
    const resultados = await edicaoRef.collection("results").get();

    const historico = dominio.montarHistorico({
      edicao: edicaoDoc.data(),
      template,
      conclusao,
      classificacaoFinal: classificacao.docs.map((d) => d.data()),
      fases: fases.docs.map((d) => d.id),
      totalPartidas: resultados.size,
      premiacoes,
    });
    lote.set(
      db().collection("tournamentHistory").doc(`${tournamentId}|${editionId}`),
      historico
    );

    // Registro anual (OS 02 secao 16): campeao e vice ganham vaga ao encerramento.
    //
    // PENDENCIA DECLARADA: quais colocacoes de quais torneios geram vaga ainda
    // NAO foi definido pelo projeto (ver tournaments.seed.json). Campeao e vice
    // sao o recorte minimo defensavel; quando a regra chegar, ela vira
    // configuracao do template e este bloco le dali.
    const temporada = edicaoDoc.data()?.temporada as string;
    const qualificados: Array<{ userId: string; origem: string; colocacao: number }> = [];
    for (const userId of (conclusao.campeoes as string[]) ?? []) {
      qualificados.push({ userId, origem: "campeao_edicao", colocacao: 1 });
    }

    for (const q of qualificados) {
      const chave = `${temporada}|${tournamentId}|${editionId}|${q.userId}`;
      lote.set(db().collection("annualQualifications").doc(chave), {
        userId: q.userId,
        temporada,
        tournamentId,
        editionId,
        origem: q.origem,
        colocacao: q.colocacao,
        motivo: null,
        registradoEm: agoraUtc(),
        chaveIdempotencia: chave,
      });
    }

    await lote.commit();
    logger.info("edicao concluida processada", {
      tournamentId, editionId,
      premios: premiacoes.filter((p) => p.concedida).length,
      qualificados: qualificados.length,
    });
  }
);

// ---------------------------------------------------------------------------
// CONVITES DO ENCERRAMENTO ANUAL (OS 02 secoes 17 e 18)
// ---------------------------------------------------------------------------

/// Reconsolida os convites da temporada.
///
/// Um convite por jogador, com o contador de classificacoes reprojetado. Convites
/// ja aceitos NAO sao rebaixados — a decisao e do dominio (consolidarConvites), e
/// esta Function so grava o que ele devolve.
export const consolidarConvitesDaTemporada = onCall(opcoesCliente, async (req) => {
  exigirAdmin(req);
  const temporada = req.data?.temporada;
  if (typeof temporada !== "string") {
    throw new HttpsError("invalid-argument", "temporada e obrigatoria.");
  }

  const [registros, existentes] = await Promise.all([
    db().collection("annualQualifications").where("temporada", "==", temporada).get(),
    db().collection("closingInvites").where("temporada", "==", temporada).get(),
  ]);

  const { convites, excedentes } = dominio.consolidarConvites({
    temporada,
    registros: registros.docs.map((d) => d.data()),
    agora: agoraUtc(),
    existentes: existentes.docs.map((d) => d.data()),
  });

  const lote = db().batch();
  for (const convite of convites) {
    // ID = chave de idempotencia (`temporada|userId`). E isto que garante UM
    // convite por jogador por temporada, mesmo com tres classificacoes
    // (OS 02 secao 17).
    lote.set(db().collection("closingInvites").doc(convite.chaveIdempotencia), convite);
  }
  await lote.commit();

  return {
    convites: convites.length,
    // A regra de redistribuicao da vaga repetida nao existe e nao foi inventada
    // (OS 02 secao 17). Os excedentes voltam listados para a administracao.
    excedentes: excedentes.length,
  };
});

/// O jogador aceita ou recusa o proprio convite (OS 02 secao 18).
///
/// Os demais estados (gerado, enviado, confirmado, participou, ausencia) sao do
/// backend: deixar o cliente saltar para `participou` daria presenca a quem nao
/// jogou.
export const responderConviteEncerramento = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  const { temporada, aceitar } = req.data ?? {};
  if (typeof temporada !== "string" || typeof aceitar !== "boolean") {
    throw new HttpsError("invalid-argument", "temporada e aceitar sao obrigatorios.");
  }

  const ref = db().collection("closingInvites").doc(`${temporada}|${uid}`);

  return db().runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) {
      throw new HttpsError("not-found", "convite inexistente.");
    }
    const atual = doc.data()!;
    if (atual.userId !== uid) {
      throw new HttpsError("permission-denied", "convite de outro jogador.");
    }
    const destino = aceitar ? "convite_aceito" : "convite_recusado";
    if (atual.status === destino) {
      return { status: destino, jaEstava: true };
    }
    if (atual.status !== "convite_enviado") {
      throw new HttpsError("failed-precondition", "transicao_inexistente");
    }
    tx.update(ref, { status: destino, atualizadoEm: agoraUtc() });
    return { status: destino, jaEstava: false };
  });
});
