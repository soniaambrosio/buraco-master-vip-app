// index.ts — Cloud Functions de moderacao (OS de Moderacao).
//
// A MESMA REPARTICAO DE PAPEIS DO MOTOR DE TORNEIOS:
//
//   QUEM DECIDE  -> o dominio Dart (app/lib/moderacao/), via domain.ts.
//                   O que e denuncia valida, o que e auto-bloqueio, quando uma
//                   sancao expira.
//   QUEM EXECUTA -> este arquivo. Autenticacao, transacao, leitura e escrita.
//
// Se um `if` de politica de moderacao aparecer aqui, ele esta no lugar errado.
//
// DUAS COISAS QUE O CLIENTE NUNCA ESCOLHE, e que por isso jamais sao lidas do
// payload: o UID de quem chama (vem de `req.auth`) e o instante (vem do
// servidor). Aceitar qualquer um dos dois seria deixar uma pessoa denunciar em
// nome de outra, ou datar um registro para tras.
//
// RESPOSTA NEUTRA (secao 18 da OS): nenhuma funcao aqui confirma ou nega a
// existencia de um UID, de uma denuncia ou de uma sancao alheia. Bloquear um UID
// inexistente responde o mesmo que bloquear um existente; consultar contato com
// um desconhecido responde "permitido". Diferenciar as respostas transformaria
// estes endpoints num mapa de contas validas.

import { initializeApp } from "firebase-admin/app";
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, CallableRequest, onCall } from "firebase-functions/v2/https";

import {
  CanalDeComunicacao,
  dominio,
  agoraUtc,
} from "./domain";
import { db, executarUmaVez } from "./idempotency";
import {
  C_CANAIS,
  C_IDENTIDADES,
  C_MENSAGENS,
  DocumentoMensagem,
  evidenciaDeMensagem,
} from "./chat";
import {
  C_ASSENTOS_ADMITIDOS,
  C_ENTITLEMENTS,
  C_RITMO,
  C_SALAS_PRIVADAS,
  DocumentoComunicacao,
  evidenciaDeItemCatalogado,
  expiraEmDe,
  projetarComunicacao,
  registroSeguro,
  tipoDe,
} from "./comunicacao";

initializeApp();

/// App Check EXIGIDO em producao, dispensado sob o emulador.
///
/// `FUNCTIONS_EMULATOR` e posto pelo proprio emulador de Functions e nunca vale
/// "true" numa instancia implantada — nao ha caminho pelo qual um cliente real
/// desligue esta verificacao, porque ela nao le nada que venha do pedido.
///
/// A dispensa existe porque o emulador nao tem provedor de App Check: com
/// `enforceAppCheck: true` toda chamada local morre em `unauthenticated` antes de
/// chegar ao `exigirAutenticacao`, e a suite nao conseguiria provar NADA do que
/// vem depois — idempotencia, recusa de auto-denuncia, UID do payload ignorado.
/// Trocar a prova dessas seis coisas pela prova do App Check seria mau negocio,
/// ainda mais porque quem garante o App Check e a plataforma, nao este codigo.
const exigirAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

const opcoesCliente = {
  enforceAppCheck: exigirAppCheck,
  region: "southamerica-east1",
};

// --------------------------------------------------------------- autenticacao

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

// ------------------------------------------------------------------ colecoes

const COL_DENUNCIAS = "reports";
const COL_SANCOES = "sanctions";
const COL_ESTADO = "playerModeration";
const COL_AUDITORIA = "moderationAudit";

/// O mapa reverso `publicId -> uid`, escrito por functions-social.
///
/// ESTE CODEBASE SO LE, e le por UM motivo: as telas do jogador nao conhecem
/// UID, entao uma denuncia vinda delas chega com `publicId`. Sem esta leitura,
/// ou nao existe botao "Denunciar" fora do chat, ou o UID de terceiro passa a
/// aparecer no aparelho — e a segunda opcao e a que a autoridade de identidade
/// publica existe para impedir.
const C_INDICE_PUBLICO = "publicIdIndex";

/// Trilha administrativa. Nunca guarda o conteudo denunciado nem o comentario:
/// so quem fez o que, sobre quem, e quando. O conteudo vive no registro da
/// denuncia, cuja leitura ja e restrita.
function registrarAuditoria(
  tx: FirebaseFirestore.Transaction,
  evento: {
    acao: string;
    ator: string;
    alvo: string | null;
    reportId?: string | null;
    sancaoId?: string | null;
    detalhe?: string | null;
  }
): void {
  tx.create(db().collection(COL_AUDITORIA).doc(), {
    ...evento,
    em: agoraUtc(),
  });
}

/// Traduz a recusa do dominio numa `HttpsError`.
///
/// O codigo do dominio vai em `details` porque o cliente precisa distinguir
/// "auto-denuncia" de "limite atingido" para escrever a mensagem certa na tela —
/// e nenhum dos dois revela nada sobre terceiros.
function recusar(recusa: string | null, falhas: string[]): never {
  throw new HttpsError("failed-precondition", recusa ?? "pedido recusado", {
    recusa,
    falhas,
  });
}

function textoOpcional(v: unknown, limite: number): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  if (!t) return null;
  if (t.length > limite) {
    throw new HttpsError("invalid-argument", "comentario acima do limite.");
  }
  return t;
}

// ============================================================== DENUNCIA

/// Registra uma denuncia.
///
/// IDEMPOTENTE POR CONSTRUCAO: o id do documento e `${uid}|${reportIntentId}`,
/// calculado pelo dominio. Toque duplo, retry apos timeout e reconexao no meio
/// do envio convergem no MESMO documento, e a segunda chamada responde sucesso
/// com `jaRegistrada: true` em vez de erro.
export const registrarDenuncia = onCall(opcoesCliente, async (req) => {
  const denuncianteUid = exigirAutenticacao(req);

  const {
    denunciadoUid: denunciadoUidPedido,
    denunciadoPublicId,
    tipo,
    categoria,
    reportIntentId,
    comentario,
    matchId,
    roomId,
    messageId,
    evidenciaMensagem,
  } = req.data ?? {};

  if (typeof tipo !== "string" || typeof categoria !== "string" ||
      typeof reportIntentId !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "tipo, categoria e reportIntentId sao obrigatorios."
    );
  }

  // ------------------------------------------------------------------------
  // QUEM E O DENUNCIADO — e por que o cliente nem sempre pode dizer
  // ------------------------------------------------------------------------
  //
  // TRES caminhos, nesta ordem de autoridade (§9.3: "Nao aceitar identidade
  // denunciada livremente quando ela puder ser resolvida pelo evento original"):
  //
  //   1. PELO EVENTO. Se ha `messageId` e o documento existe, o alvo e o AUTOR
  //      GRAVADO. Vence qualquer coisa que o pedido tenha dito — sem isso,
  //      denunciar a mensagem de A afirmando que ela e de B geraria um registro
  //      acusando B do que A escreveu.
  //
  //   2. PELO `publicId`. As telas do jogador (Ranking, Hall, Perfil, mesa)
  //      NAO conhecem UID — e isso e decisao da autoridade de identidade
  //      publica, nao limitacao. A resolucao publicId -> uid acontece AQUI,
  //      pelo indice reverso `publicIdIndex`, que e negado a todo cliente. E
  //      o que permite existir um botao "Denunciar" sem expor UID de terceiro.
  //
  //   3. PELO UID. Continua aceito, para os chamadores internos que ja o tem.
  //
  // ESTE BLOCO NAO CRIA UMA SEGUNDA AUTORIDADE DE IDENTIDADE: ele LE o indice
  // que functions-social escreve, e a normalizacao do id vem da mesma funcao
  // Dart que aquele codebase usa.
  let denunciadoUid =
    typeof denunciadoUidPedido === "string" ? denunciadoUidPedido : "";

  const docMensagem =
    typeof messageId === "string" && messageId
      ? await db().collection(C_MENSAGENS).doc(messageId).get()
      : null;

  const comunicacaoDenunciada =
    docMensagem && docMensagem.exists
      ? (docMensagem.data() as DocumentoComunicacao)
      : null;

  if (comunicacaoDenunciada && typeof comunicacaoDenunciada.autorUid === "string") {
    denunciadoUid = comunicacaoDenunciada.autorUid;
  } else if (!denunciadoUid && typeof denunciadoPublicId === "string") {
    const normalizado = dominio.normalizarPublicId(denunciadoPublicId).publicId;
    if (normalizado) {
      const indice = await db().collection(C_INDICE_PUBLICO).doc(normalizado).get();
      const uid = indice.data()?.uid;
      if (typeof uid === "string") denunciadoUid = uid;
    }
  }

  if (!denunciadoUid) {
    // RESPOSTA NEUTRA: nao diz se o publicId existe. Diferenciar "nao existe" de
    // "existe mas nao resolvi" transformaria esta porta num verificador de
    // identidades validas.
    throw new HttpsError("invalid-argument", "alvoNaoResolvido", {
      recusa: "alvoNaoResolvido",
    });
  }

  const texto = textoOpcional(comentario, 500);

  // Freio contra despejo automatizado (secao 7 da OS). A contagem e por janela
  // deslizante de uma hora, feita por consulta indexada — nao por contador
  // denormalizado, que precisaria de outra transacao para ficar correto.
  const desde = new Date(Date.now() - 60 * 60 * 1000).toISOString();
  const recentes = await db()
    .collection(COL_DENUNCIAS)
    .where("denuncianteUid", "==", denuncianteUid)
    .where("createdAt", ">=", desde)
    .count()
    .get();

  const veredito = dominio.avaliarDenuncia({
    denuncianteUid,
    denunciadoUid,
    tipo,
    categoria,
    reportIntentId,
    comentario: texto,
    referencias: {
      matchId: typeof matchId === "string" ? matchId : null,
      roomId: typeof roomId === "string" ? roomId : null,
      messageId: typeof messageId === "string" ? messageId : null,
    },
    jaNaJanela: recentes.data().count,
  });

  if (!veredito.aceita) {
    logger.info("denuncia recusada", {
      denuncianteUid,
      recusa: veredito.recusa,
    });
    recusar(veredito.recusa, veredito.falhas);
  }

  const reportId = veredito.chave!;
  const criadoEm = agoraUtc();

  // A EVIDENCIA (secao 5 da OS de Moderacao; secao 12 da OS do Chat).
  //
  // A LIMITACAO QUE ESTAVA AQUI MORREU EM PARTE, e o comentario antigo dizia o que
  // fazer quando morresse: "quando o chat passar a ser servidor-lado, a Function
  // preenche a mesma estrutura com `origem: servidor` e o campo atestado deixa de
  // ser aceito — sem migrar o que ja foi gravado". E exatamente o que acontece
  // agora, e nada mais que isso:
  //
  //   * a mensagem EXISTE em `chatMessages/{messageId}` -> evidencia do SERVIDOR,
  //     lida daqui, e a copia mandada pelo cliente e DESCARTADA (nao comparada,
  //     nao mesclada). O autor sai do DOCUMENTO, nao de `denunciadoUid`: sem isso,
  //     denunciar a mensagem de A dizendo que e de B gravaria evidencia acusando B
  //     do que A escreveu;
  //
  //   * a mensagem NAO existe -> segue `cliente_atestada`, como antes. A
  //     sobrevivencia e DELIMITADA e nao esquecida: vale para as superficies sem
  //     mensagem autoritativa (o saguao, e a mesa enquanto o transporte nao
  //     estiver ligado) e para o historico ja gravado, que nao se migra.
  //
  // A regra mora em `chat.ts` (pura, testada por `test/chat.test.js` sem
  // emulador); aqui fica somente a LEITURA que ela precisa.
  const atestada =
    evidenciaMensagem && typeof evidenciaMensagem === "object"
      ? {
          conteudo: textoOpcional(
            (evidenciaMensagem as Record<string, unknown>).conteudo,
            2000
          ),
          enviadaEm:
            typeof (evidenciaMensagem as Record<string, unknown>).enviadaEm ===
            "string"
              ? ((evidenciaMensagem as Record<string, unknown>)
                  .enviadaEm as string)
              : null,
        }
      : null;

  // A EVIDENCIA MINIMA (§9.5), e ela e DIFERENTE por especie de comunicacao.
  //
  //   TEXTO ............ a mensagem exata, o autor, o horario, a sala.
  //   ITEM CATALOGADO .. o `itemId`, a VERSAO do catalogo, e a QUANTIDADE e o
  //                      PADRAO de repeticao.
  //
  // A razao da diferenca e o abuso ser outro. Uma fala do catalogo nunca e
  // ofensiva por si — ela foi aprovada. O que ofende e a REPETICAO, e uma
  // evidencia que guardasse so "usou tal fala" nao mostraria o abuso.
  //
  // A JANELA DA REPETICAO E ESTREITA de proposito (uma hora antes do evento
  // denunciado). Varrer a conversa inteira seria a "retencao indiscriminada"
  // que a §9.5 proibe; uma hora e o que basta para distinguir uso de inundacao.
  const ehItemCatalogado =
    comunicacaoDenunciada !== null &&
    tipoDe(comunicacaoDenunciada) !== "texto_privado";

  let evidencia: Record<string, unknown>;

  if (ehItemCatalogado) {
    const doc = comunicacaoDenunciada as DocumentoComunicacao;
    const desdeRepeticao = new Date(
      Date.parse(doc.enviadaEm) - 60 * 60 * 1000
    ).toISOString();

    const repeticoes = await db()
      .collection(C_MENSAGENS)
      .where("canalId", "==", doc.canalId)
      .where("itemId", "==", doc.itemId)
      .where("enviadaEm", ">=", desdeRepeticao)
      .where("enviadaEm", "<=", doc.enviadaEm)
      .limit(50)
      .get();

    evidencia = evidenciaDeItemCatalogado(
      doc,
      repeticoes.docs
        .map((d) => d.data() as DocumentoComunicacao)
        // O autor sai do DOCUMENTO em cada linha: o canal e compartilhado, e
        // contar as falas dos outros como repeticao do denunciado seria acusar
        // um pelo volume de quatro.
        .filter((d) => d.autorUid === doc.autorUid)
        .map((d) => ({ enviadaEm: d.enviadaEm }))
    ) as unknown as Record<string, unknown>;
  } else {
    evidencia = evidenciaDeMensagem(
      {
        messageId: typeof messageId === "string" ? messageId : null,
        roomId: typeof roomId === "string" ? roomId : null,
        denunciadoUid,
        atestadaPeloCliente: tipo === "mensagem" ? atestada : null,
      },
      comunicacaoDenunciada as DocumentoMensagem | null
    ) as unknown as Record<string, unknown>;
  }

  const resultado = await executarUmaVez(
    reportId,
    {
      tarefa: "registrarDenuncia",
      ator: denuncianteUid,
      alvo: denunciadoUid,
      // O que a chave `${uid}|${reportIntentId}` NAO carrega. Sem isto, o mesmo
      // intent id reaproveitado com outro tipo/categoria passaria por repeticao.
      impressao: `${tipo}|${categoria}`,
    },
    async (tx) => {
      // O REGISTRO ADMINISTRATIVO. Leitura restrita a admin pelas regras: e aqui
      // que fica a identidade do denunciante, e e por isso que o denunciado nao
      // alcanca este documento por caminho nenhum.
      tx.create(db().collection(COL_DENUNCIAS).doc(reportId), {
        reportId,
        denuncianteUid,
        denunciadoUid,
        tipo,
        categoria,
        comentario: texto,
        matchId: matchId ?? null,
        roomId: roomId ?? null,
        messageId: messageId ?? null,
        evidencia,
        status: "recebida",
        origem: "aplicativo",
        createdAt: criadoEm,
        esquema: veredito.esquema ?? 1,
      });

      // O COMPROVANTE DO DENUNCIANTE. Documento separado, e nao uma regra de
      // projecao sobre o registro acima, porque as regras do Firestore liberam
      // ou negam o DOCUMENTO INTEIRO — nao ha como permitir ler quatro campos e
      // esconder o resto. Aqui nao entra denunciadoUid, comentario, evidencia
      // nem status interno.
      tx.create(
        db()
          .collection("users")
          .doc(denuncianteUid)
          .collection("reportReceipts")
          .doc(reportId),
        {
          protocolo: reportId,
          tipo,
          categoria,
          status: dominio.statusPublico("recebida").publico,
          criadoEm,
          esquema: veredito.esquema ?? 1,
        }
      );

      registrarAuditoria(tx, {
        acao: "denuncia_registrada",
        ator: denuncianteUid,
        alvo: denunciadoUid,
        reportId,
      });

      return { reportId };
    }
  );

  return {
    registrada: true,
    protocolo: reportId,
    jaRegistrada: !resultado.executou,
  };
});

// ============================================================== BLOQUEIO

/// Bloqueia outro jogador. Unilateral: nao cria o bloqueio inverso.
export const bloquearJogador = onCall(opcoesCliente, async (req) => {
  const bloqueadorUid = exigirAutenticacao(req);
  const { bloqueadoUid } = req.data ?? {};

  if (typeof bloqueadoUid !== "string") {
    throw new HttpsError("invalid-argument", "bloqueadoUid e obrigatorio.");
  }

  const lista = db().collection("users").doc(bloqueadorUid).collection("blocks");
  const quantos = await lista.count().get();

  const veredito = dominio.avaliarBloqueio({
    bloqueadorUid,
    bloqueadoUid,
    jaBloqueados: quantos.data().count,
  });
  if (!veredito.aceita) recusar(veredito.recusa, veredito.falhas);

  // `set` com merge, e nao `create`: bloquear duas vezes tem que convergir no
  // mesmo estado, e nao falhar. O id do documento e o UID bloqueado, entao a
  // duplicidade e impossivel por construcao.
  await lista.doc(bloqueadoUid).set(
    {
      bloqueadorUid,
      bloqueadoUid,
      criadoEm: FieldValue.serverTimestamp(),
      esquema: 1,
    },
    { merge: true }
  );

  logger.info("bloqueio registrado", { bloqueadorUid });
  return { bloqueado: true };
});

/// Desfaz o proprio bloqueio.
export const desbloquearJogador = onCall(opcoesCliente, async (req) => {
  const bloqueadorUid = exigirAutenticacao(req);
  const { bloqueadoUid } = req.data ?? {};

  if (typeof bloqueadoUid !== "string") {
    throw new HttpsError("invalid-argument", "bloqueadoUid e obrigatorio.");
  }

  // Apagar o que nao existe nao e erro: desbloquear duas vezes converge. Nao
  // consultamos antes de propósito — responder diferente para "existia" e "nao
  // existia" contaria ao chamador se aquele UID ja fora bloqueado.
  await db()
    .collection("users")
    .doc(bloqueadorUid)
    .collection("blocks")
    .doc(bloqueadoUid)
    .delete();

  return { desbloqueado: true };
});

/// Pode quem chama iniciar contato social com `alvoUid`?
///
/// PORTA UNICA das rotas sociais. Existe antes das rotas para que elas nascam
/// perguntando — a secao 8 da OS pede o contrato mesmo onde o recurso ainda nao
/// existe. Chat privado, convite direto e pedido de amizade devem chamar isto
/// ANTES de entregar qualquer coisa.
export const consultarContato = onCall(opcoesCliente, async (req) => {
  const origemUid = exigirAutenticacao(req);
  const { alvoUid } = req.data ?? {};

  if (typeof alvoUid !== "string") {
    throw new HttpsError("invalid-argument", "alvoUid e obrigatorio.");
  }

  const usuarios = db().collection("users");
  const [ida, volta, estado] = await Promise.all([
    usuarios.doc(origemUid).collection("blocks").doc(alvoUid).get(),
    usuarios.doc(alvoUid).collection("blocks").doc(origemUid).get(),
    db().collection(COL_ESTADO).doc(origemUid).get(),
  ]);

  const agora = agoraUtc();
  const e = estado.data() ?? {};
  const vigente = (campo: string): boolean =>
    typeof e[campo] === "string" && agora < (e[campo] as string);

  const veredito = dominio.avaliarContato({
    origemBloqueouDestino: ida.exists,
    destinoBloqueouOrigem: volta.exists,
    origemComChatSilenciado: vigente("chatSilenciadoAte"),
    origemComRestricaoSocial:
      vigente("socialRestritoAte") || e.suspensaoPermanente === true,
  });

  return veredito;
});

// ============================================================== SANCAO

/// Aplica uma sancao administrativa. SO ADMIN.
export const aplicarSancao = onCall(opcoesCliente, async (req) => {
  const responsavel = exigirAdmin(req);
  const { userId, tipo, motivo, fim, reportId, sancaoIntentId } = req.data ?? {};

  if (
    typeof userId !== "string" ||
    typeof tipo !== "string" ||
    typeof motivo !== "string" ||
    typeof sancaoIntentId !== "string"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "userId, tipo, motivo e sancaoIntentId sao obrigatorios."
    );
  }

  // UM instante para a operacao inteira (secao 17 da OS): se cada leitura
  // pegasse o relogio de novo, uma sancao poderia estar vigente na primeira
  // checagem e expirada na segunda, dentro da mesma transacao.
  const agora = agoraUtc();

  const veredito = dominio.avaliarSancao({
    userId,
    responsavel,
    tipo,
    motivo,
    inicio: agora,
    fim: typeof fim === "string" ? fim : null,
  });
  if (!veredito.aceita) recusar(veredito.recusa, veredito.falhas);

  const sancaoId = `${responsavel}|${sancaoIntentId}`;

  const resultado = await executarUmaVez(
    sancaoId,
    {
      tarefa: "aplicarSancao",
      ator: responsavel,
      alvo: userId,
      // O que a chave `${responsavel}|${sancaoIntentId}` NAO carrega. Sem isto,
      // escalar de silencio para suspensao reusando o intent id sumiria em
      // silencio com um `{aplicada: true}` na resposta.
      impressao: `${tipo}|${typeof fim === "string" ? fim : "null"}`,
    },
    async (tx) => {
      // As sancoes vigentes precisam ser lidas DENTRO da transacao: consolidar
      // sobre uma leitura de fora deixaria duas aplicacoes simultaneas gravarem
      // estados que ignoram uma a outra.
      const vigentes = await tx.get(
        db().collection(COL_SANCOES).where("userId", "==", userId)
      );

      const nova = {
        sancaoId,
        userId,
        tipo,
        motivo,
        inicio: agora,
        fim: typeof fim === "string" ? fim : null,
        responsavel,
        origem: "administrativa",
        status: "ativa",
        reportId: typeof reportId === "string" ? reportId : null,
        esquema: 1,
      };

      tx.create(db().collection(COL_SANCOES).doc(sancaoId), nova);

      const estado = dominio.consolidarSancoes({
        userId,
        agora,
        sancoes: [...vigentes.docs.map((d) => d.data()), nova],
      });

      tx.set(db().collection(COL_ESTADO).doc(userId), {
        ...estado,
        atualizadoEm: agora,
      });

      registrarAuditoria(tx, {
        acao: "sancao_aplicada",
        ator: responsavel,
        alvo: userId,
        sancaoId,
        reportId: typeof reportId === "string" ? reportId : null,
        detalhe: tipo,
      });

      return { sancaoId };
    }
  );

  return { aplicada: true, sancaoId, jaAplicada: !resultado.executou };
});

/// Revoga uma sancao e recalcula o estado. SO ADMIN.
export const revogarSancao = onCall(opcoesCliente, async (req) => {
  const responsavel = exigirAdmin(req);
  const { sancaoId, motivo } = req.data ?? {};

  if (typeof sancaoId !== "string") {
    throw new HttpsError("invalid-argument", "sancaoId e obrigatorio.");
  }

  const agora = agoraUtc();

  await db().runTransaction(async (tx) => {
    const ref = db().collection(COL_SANCOES).doc(sancaoId);
    const doc = await tx.get(ref);
    if (!doc.exists) {
      throw new HttpsError("not-found", "sancao inexistente.");
    }

    const userId = doc.data()!.userId as string;
    const vigentes = await tx.get(
      db().collection(COL_SANCOES).where("userId", "==", userId)
    );

    // A sancao nao e APAGADA: vira `revogada`. O historico disciplinar precisa
    // registrar que houve punicao e que ela foi desfeita — apagar deixaria a
    // trilha contando uma historia que nao aconteceu.
    tx.update(ref, {
      status: "revogada",
      revogadaEm: agora,
      revogadaPor: responsavel,
      motivoRevogacao: typeof motivo === "string" ? motivo : null,
    });

    const restantes = vigentes.docs
      .map((d) => d.data())
      .map((s) => (s.sancaoId === sancaoId ? { ...s, status: "revogada" } : s));

    const estado = dominio.consolidarSancoes({
      userId,
      agora,
      sancoes: restantes,
    });

    tx.set(db().collection(COL_ESTADO).doc(userId), {
      ...estado,
      atualizadoEm: agora,
    });

    registrarAuditoria(tx, {
      acao: "sancao_revogada",
      ator: responsavel,
      alvo: userId,
      sancaoId,
    });
  });

  return { revogada: true };
});

// ============================================================== CHAT LIVRE
//
// AUTORIDADE DA MENSAGEM (§14 da OS do Chat Livre Seguro).
//
// A mensagem nasce AQUI, e por eliminacao, nao por gosto. O servidor de partidas
// (Node/Railway) nao declara UMA unica dependencia em `package.json`, e portanto
// nao alcanca Firestore. Para ele decidir envio seria preciso dar-lhe
// firebase-admin e uma credencial, e ele passaria a ser um SEGUNDO leitor de
// bloqueio e de `playerModeration`. As tres coisas que a decisao precisa
// consultar — `users/{uid}/blocks`, `playerModeration/{uid}` e o veredito
// `avaliarContato` — ja moram nesta codebase. Uma gravacao, uma decisao.
//
// O QUE ESTA OS NAO LIGA, e nao finge ligar: o TRANSPORTE. A mensagem e gravada e
// projetada; quem a distribui aos outros aparelhos e o servidor de partidas, que
// ainda nao consome nada disto. `destinatarios` fica gravado justamente para que a
// entrega, quando existir, nao precise redecidir bloqueio.

/// Um identificador que pode virar id de documento.
///
/// NAO e paranoia redundante com o dominio: o dominio valida DEPOIS, e aqui o
/// valor e usado ANTES, para localizar o canal. Um `canalId` com barra viraria
/// caminho de subcolecao, e um com `..` sairia da colecao pretendida. Recusar
/// antes de tocar o Firestore e o que impede o payload de escolher ONDE a
/// autoridade vai ler.
function exigirIdSeguro(v: unknown, campo: string): string {
  if (typeof v !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(v)) {
    throw new HttpsError("invalid-argument", campo + " invalido.");
  }
  return v;
}

/// Quem tem autoridade para abrir e fechar canal de chat.
///
/// MESMOS PAPEIS que a ingestao de partidas ja exige (`motorDePartidas` ou
/// `admin`); a lista canonica esta em `app/lib/rastreabilidade/ingestao.dart`
/// (`ChamadorAutorizado.papeisDeAutoridade`). Um jogador NUNCA abre canal: se
/// abrisse, escolheria quem esta sentado, e o filtro de bloqueio da §7 passaria a
/// depender de uma lista escrita pelo proprio remetente.
function exigirMotorOuAdmin(req: CallableRequest): string {
  const uid = exigirAutenticacao(req);
  const t = req.auth?.token as Record<string, unknown> | undefined;
  if (t?.motorDePartidas !== true && t?.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Operacao restrita ao motor de partidas."
    );
  }
  return uid;
}

/// Declara o canal de chat de uma partida. SO MOTOR OU ADMIN.
///
/// IDEMPOTENTE POR NATUREZA: e um `set` sobre um id escolhido por quem chama, e
/// declarar o mesmo canal duas vezes converge no mesmo estado. NAO usa
/// `executarUmaVez` de proposito — a lista de participantes MUDA durante a partida
/// (alguem senta, alguem sai), e uma barreira de idempotencia recusaria a segunda
/// declaracao legitima como "intencao reaproveitada".
///
/// SEM CHAMADOR AINDA. O servidor de partidas nao chama isto, porque nao alcanca
/// Firebase. O endpoint existe para que a fronteira esteja escrita e provada, no
/// mesmo padrao que o repositorio ja usa noutras OSs (autoridade entregue, produtor
/// pendente). Enquanto ninguem chamar, nao ha canal — e sem canal
/// `enviarMensagemChat` recusa TODA mensagem. Falha fechada.
export const definirCanalDeChat = onCall(opcoesCliente, async (req) => {
  const responsavel = exigirMotorOuAdmin(req);
  const dados = (req.data ?? {}) as Record<string, unknown>;

  const id = exigirIdSeguro(dados.canalId, "canalId");

  // O AMBIENTE NAO VEM PRONTO. O que chega sao as DUAS DIMENSOES que o servidor
  // de mesas ja fala (topologia e natureza competitiva), ambas fixadas na
  // construcao do processo dele e nunca escolhidas por um jogador. A traducao
  // para um tipo canonico — e dele para o ambiente — e do dominio, que espelha
  // `functions-mesas/src/tipos.ts`.
  const resolucao = dominio.resolverAmbiente({
    tipoPartida: dados.tipoPartida,
    categoriaCompetitiva: dados.categoriaCompetitiva,
    modo: dados.modo,
  });

  if (!resolucao.ambiente) {
    // Combinacao que a taxonomia nao reconhece — inclusive `privada` x
    // `vip_ranqueada`, que seria sala fechada alimentando o Ranking.
    throw new HttpsError("invalid-argument", "ambienteDesconhecido", {
      recusa: "ambienteDesconhecido",
    });
  }
  // NADA DE JULGAR COMUNICACAO AINDA. O modo definitivo so e conhecido depois —
  // na Mesa Privada ele vem do documento da sala, e nos demais ambientes ele
  // tem padrao. Julgar aqui, com o modo do pedido (que pode nem ter vindo),
  // recusaria por `desligado` um canal que o padrao abriria.

  if (!Array.isArray(dados.participantes)) {
    throw new HttpsError("invalid-argument", "participantes e obrigatorio.");
  }

  let participantes = (dados.participantes as unknown[]).map((p) => {
    const item = (p ?? {}) as Record<string, unknown>;
    return {
      uid: exigirIdSeguro(item.uid, "participantes[].uid"),
      papel: typeof item.papel === "string" ? item.papel : "fora_do_canal",
    };
  });

  // ------------------------------------------------------------------------
  // A MESA PRIVADA PRECISA EXISTIR NA AUTORIDADE DOS TIPOS DE MESA
  // ------------------------------------------------------------------------
  //
  // Este bloco e a razao pela qual "declarar `privada`" nao concede texto
  // livre. A §3 manda CONSUMIR a classificacao autoritativa da mesa, e e o que
  // acontece aqui: a sala tem de estar registrada em `salasPrivadas/{codigo}`
  // por `functions-mesas`, que so a registra para quem tem ASSINATURA ATIVA.
  //
  // Uma instancia de servidor mal configurada — ou adulterada — consegue
  // declarar a topologia `privada`. Ela nao consegue inventar uma sala
  // registrada por um assinante, e e por isso que a prova mora aqui e nao no
  // campo que ela envia.
  //
  // O CODIGO DA SALA E USADO E DESCARTADO. Ele localiza a sala e o assento, e
  // NAO e gravado no canal: o codigo e a chave de entrada da Mesa Privada, e um
  // canal que o carregasse o entregaria a quem lesse o documento — inclusive
  // dentro de uma denuncia. Por isso tambem ele nunca vai para o log.
  let modo = typeof dados.modo === "string" ? dados.modo : "apenas_emotes";

  if (resolucao.exigeSalaRegistrada) {
    const codigo = exigirIdSeguro(dados.codigoDaSala, "codigoDaSala");

    const sala = await db().collection(C_SALAS_PRIVADAS).doc(codigo).get();
    if (!sala.exists) {
      throw new HttpsError("failed-precondition", "salaPrivadaNaoRegistrada", {
        recusa: "salaPrivadaNaoRegistrada",
      });
    }
    const salaDados = sala.data() as Record<string, unknown>;
    if (salaDados.encerradaEm) {
      throw new HttpsError("failed-precondition", "salaPrivadaEncerrada", {
        recusa: "salaPrivadaEncerrada",
      });
    }

    // O MODO VEM DA SALA, e nao do pedido (§7.3: "A escolha devera ser validada
    // pela autoridade. O estado nao podera ser alterado pelo convidado"). Quem
    // escolheu foi o anfitriao, no momento de registrar a mesa, e a escolha foi
    // validada la contra a politica dos tipos.
    //
    // AUSENTE NAO E `completo`: sala registrada antes desta OS nao tem o campo,
    // e o dominio le ausencia como `desligado`. Chat fechado numa sala antiga e
    // o desfecho correto — a alternativa seria conceder texto livre a partir de
    // um campo que ninguem escreveu.
    modo = typeof salaDados.modoDeChat === "string" ? salaDados.modoDeChat : "";

    // E OS ASSENTOS PRECISAM SER ADMITIDOS. `assentosAdmitidos/{codigo}__{uid}`
    // e a ancora que a autoridade dos tipos grava quando alguem passa pelo gate
    // VIP. Quem nao tem essa ancora nao esta sentado para efeito de comunicacao:
    // vira `fora_do_canal`, que nao fala e nao recebe.
    //
    // NAO se recusa o canal inteiro por causa de um assento: isso calaria a mesa
    // por causa de uma pessoa. Rebaixa-se a pessoa.
    const conferidos = await Promise.all(
      participantes.map(async (p) => {
        if (p.papel !== "jogador_sentado") return p;
        const admitido = await db()
          .collection(C_ASSENTOS_ADMITIDOS)
          .doc(codigo + "__" + p.uid)
          .get();
        return admitido.exists ? p : { uid: p.uid, papel: "fora_do_canal" };
      })
    );
    const rebaixados = conferidos.filter(
      (p, k) => p.papel !== participantes[k].papel
    ).length;
    participantes = conferidos;
    if (rebaixados > 0) {
      logger.warn("assento sem admissao na mesa privada", {
        canalId: id,
        rebaixados,
      });
    }
  }

  // O modo declarado tem de ser POSSIVEL neste ambiente. `completo` fora da Mesa
  // Privada e recusa nomeada, e nao degradacao silenciosa: a §7.3 pede que a
  // escolha seja validada, e validar e poder recusar.
  const conferencia = dominio.resolverAmbiente({
    tipoPartida: dados.tipoPartida,
    categoriaCompetitiva: dados.categoriaCompetitiva,
    modo,
  });
  if (!conferencia.modoPermitidoNoAmbiente) {
    throw new HttpsError("failed-precondition", "modoNaoPermitidoNoAmbiente", {
      recusa: "modoNaoPermitidoNoAmbiente",
      ambiente: resolucao.ambiente,
      modo,
    });
  }
  // E o canal so nasce se ele admitir ALGUMA comunicacao. Treino cai aqui, e
  // tambem a mesa cujo anfitriao escolheu `desligado`: um canal que nao aceita
  // nada e um documento que so serve para ser recusado depois, mensagem a
  // mensagem. Recusar a DECLARACAO e mais barato e mais honesto.
  if (!conferencia.aceitaComunicacao) {
    throw new HttpsError("failed-precondition", "ambienteSemComunicacao", {
      recusa: "ambienteSemComunicacao",
      ambiente: resolucao.ambiente,
      modo,
    });
  }

  const politicas = dominio.politicaDeAmbientes();

  await db()
    .collection(C_CANAIS)
    .doc(id)
    .set({
      canalId: id,
      // A superficie DERIVA do ambiente, e nao e mais aceita do pedido. Sem
      // isso, um canal poderia declarar `superficie: mesa_de_partida` com
      // `ambiente: saguao_publico` e as duas classificacoes passariam a
      // discordar sobre o mesmo canal.
      superficie: resolucao.superficie,
      ambiente: resolucao.ambiente,
      modo,
      participantes,
      // Ausente vira FECHADO, igual ao dominio: um canal so aceita fala se
      // alguem disser explicitamente que ele esta aberto.
      aberto: dados.aberto === true,
      atualizadoEm: agoraUtc(),
      atualizadoPor: responsavel,
      versaoDoCatalogo: politicas.versaoDoCatalogo,
      versaoDoContrato: politicas.versaoDoContrato,
      esquema: politicas.esquema,
    });

  logger.info(
    "canal de comunicacao declarado",
    registroSeguro({
      canalId: id,
      ambiente: resolucao.ambiente,
      tipo: modo,
    })
  );
  return {
    definido: true,
    canalId: id,
    ambiente: resolucao.ambiente,
    modo,
  };
});


// -------------------------------------------------------- NUCLEO DO ENVIO
//
// UMA AUTORIDADE, DOIS ADAPTADORES (§10 da OS do Transporte).
//
// Este e o unico lugar onde uma mensagem de chat passa a existir. Os dois
// ingressos — o do jogador e o do motor de partidas — chamam ESTA funcao e nada
// mais. A razao e concreta e ja custou caro noutras frentes do projeto: duas
// implementacoes da mesma regra divergem no primeiro dia em que alguem aperta um
// limite de um lado so, e a versao frouxa e sempre a porta de abuso.
//
// O QUE ESTE NUCLEO NAO SABE: quem chamou. Ele recebe o `autorUid` JA DECIDIDO
// pelo adaptador, e a diferenca entre os dois adaptadores e exatamente COMO cada
// um o decide — `req.auth.uid` no do jogador, campo do payload no do motor,
// porque la o chamador autenticado e o motor e nao o autor. Nenhuma politica
// mora nessa diferenca.
//
// `test/contrato.test.js` afirma estruturalmente que os dois adaptadores
// convergem aqui: nenhum deles pode ler `blocks`, `playerModeration`, chamar
// `avaliarEnvioChat` ou gravar em `chatMessages` por conta propria.

/// O que o nucleo devolve. `destinatarios` e INTERNO: sai para o motor (que
/// precisa dele para rotear) e NUNCA para um jogador.
interface ResultadoEnvio {
  enviada: true;
  jaEnviada: boolean;
  mensagem: ReturnType<typeof projetarComunicacao>;
  destinatarios: string[];
  /// Quem silenciou o autor. Vai para o transporte junto com `destinatarios`
  /// porque o transporte precisa saber a quem NAO entregar — e nao vai para o
  /// jogador por nenhum caminho.
  silenciados: string[];
}

/// Le o estado de ritmo do autor.
///
/// Documento ausente e estado VAZIO, que e o estado de quem nunca falou. Nao ha
/// caminho pelo qual a ausencia vire "ja falou demais" nem "esta bloqueado":
/// dado que nao existe nao restringe, e dado ilegivel tambem nao — o dominio
/// (`EstadoDeRitmo.fromJson`) devolve vazio para os dois casos.
async function lerRitmo(uid: string): Promise<unknown> {
  const doc = await db().collection(C_RITMO).doc(uid).get();
  return doc.exists ? doc.data() : null;
}

async function executarEnvioDeMensagem(
  autorUid: string,
  dados: Record<string, unknown>,
  camposDoPayload: string[]
): Promise<ResultadoEnvio> {
  const intentId = exigirIdSeguro(dados.intentId, "intentId");
  const canalId = exigirIdSeguro(dados.canalId, "canalId");

  const usuarios = db().collection("users");

  // A REPETICAO E RECONHECIDA ANTES DE TUDO.
  //
  // `messageId` deriva de autor + intencao (o dominio calcula; este arquivo nao
  // faz digest nenhum). Se o documento JA EXISTE e descreve O MESMO PEDIDO, isto
  // e um retry — e um retry converge no que foi gravado, sem passar pelo freio
  // de ritmo, sem reler bloqueio e sem gravar nada.
  //
  // A ORDEM E O PONTO. Com o anti-spam antes, uma reconexao 200 ms depois
  // levaria `ritmoExcedido` para uma mensagem que ja estava no banco: o cliente
  // acharia que falhou, tentaria de novo, e a cada tentativa o freio apertaria.
  // Quem repete nao esta inundando a mesa.
  //
  // "MESMO PEDIDO" e conferido campo a campo, e nao assumido: canal, tipo e o
  // que foi dito. Um `intentId` REAPROVEITADO com outro conteudo NAO cai aqui —
  // ele segue o caminho inteiro e encontra o conflito de idempotencia, que e a
  // resposta certa para "voce ja usou esta intencao para outra coisa".
  const { messageId: idPrevisto } = dominio.idDeMensagem({ autorUid, intentId });
  const jaGravado = await db().collection(C_MENSAGENS).doc(idPrevisto).get();
  if (jaGravado.exists) {
    const doc = jaGravado.data() as DocumentoComunicacao;
    const mesmoPedido =
      doc.canalId === canalId &&
      tipoDe(doc) === (typeof dados.tipo === "string" && dados.tipo
        ? dados.tipo
        : "texto_privado") &&
      (doc.itemId ?? null) ===
        (typeof dados.itemId === "string" ? dados.itemId : null) &&
      (doc.conteudo ?? null) ===
        (typeof dados.conteudo === "string" ? dados.conteudo.trim() : null);

    if (mesmoPedido) {
      logger.info(
        "comunicacao repetida",
        registroSeguro({
          canalId,
          ambiente: doc.ambiente,
          tipo: tipoDe(doc),
        })
      );
      return {
        enviada: true,
        jaEnviada: true,
        mensagem: projetarComunicacao(doc),
        destinatarios: Array.isArray(doc.destinatarios) ? doc.destinatarios : [],
        silenciados: Array.isArray(doc.silenciados) ? doc.silenciados : [],
      };
    }

    // MESMA INTENCAO, OUTRO PEDIDO. Nao e repeticao e nao e inundacao: e uma
    // intencao gasta descrevendo outra coisa. Responder sucesso faria a
    // mensagem pedida desaparecer com uma confirmacao na mao de quem pediu; e
    // responder "muito rapido" (o que o freio diria, se chegasse antes)
    // esconderia um defeito de cliente atras de um conselho de esperar.
    //
    // A barreira de `executarUmaVez` diz a MESMA coisa mais adiante, e continua
    // valendo para a corrida entre duas chamadas simultaneas. Esta aqui e a que
    // responde antes de qualquer leitura cara.
    logger.info(
      "intencao reaproveitada",
      registroSeguro({ canalId, ambiente: doc.ambiente, tipo: tipoDe(doc) })
    );
    throw new HttpsError("failed-precondition", "intencaoReutilizada", {
      recusa: "intencaoReutilizada",
      familia: "forma",
    });
  }

  // TIPO AUSENTE E `texto_privado`, e isso e compatibilidade deliberada com o
  // transporte que ja existe: o servidor de partidas manda `conteudo` sem
  // `tipo` desde a OS do Transporte. O que MUDA para ele nao e o formato do
  // pedido — e a resposta, porque texto agora so passa na Mesa Privada.
  const tipo =
    typeof dados.tipo === "string" && dados.tipo ? dados.tipo : "texto_privado";
  const ehCatalogado = tipo !== "texto_privado";

  // LEITURA 1: canal, identidade publica, estado disciplinar e ritmo. Em
  // paralelo porque nenhuma depende da outra.
  const [canalSnap, identidadeSnap, estadoSnap, ritmo] = await Promise.all([
    db().collection(C_CANAIS).doc(canalId).get(),
    db().collection(C_IDENTIDADES).doc(autorUid).get(),
    db().collection(COL_ESTADO).doc(autorUid).get(),
    lerRitmo(autorUid),
  ]);

  const canalBruto = canalSnap.exists
    ? (canalSnap.data() as Record<string, unknown>)
    : null;

  const canal: CanalDeComunicacao | null = canalBruto
    ? {
        canalId: String(canalBruto.canalId ?? canalId),
        superficie: String(canalBruto.superficie ?? ""),
        // AUSENTE FICA AUSENTE. Um canal declarado antes desta OS nao tem
        // ambiente, e o dominio recusa canal sem ambiente. Preencher aqui um
        // padrao seria escolher, no TypeScript, a politica que a §2 decide.
        ambiente: String(canalBruto.ambiente ?? ""),
        modo: String(canalBruto.modo ?? ""),
        aberto: canalBruto.aberto === true,
        participantes: Array.isArray(canalBruto.participantes)
          ? (canalBruto.participantes as Record<string, unknown>[]).map((p) => ({
              uid: String(p?.uid ?? ""),
              papel: String(p?.papel ?? "fora_do_canal"),
            }))
          : [],
      }
    : null;

  const publicIdBruto = identidadeSnap.data()?.publicId;
  const autorPublicId =
    typeof publicIdBruto === "string" ? publicIdBruto : null;

  // O RELOGIO E CONGELADO AQUI, uma vez. Duas leituras do relogio na mesma
  // operacao fariam a checagem de sancao dizer "silenciado" e a de ritmo, alguns
  // milissegundos depois, medir outra janela.
  const agora = agoraUtc();
  const est = estadoSnap.data() ?? {};
  const vigente = (campo: string): boolean =>
    typeof est[campo] === "string" && agora < (est[campo] as string);

  // LEITURA 2: bloqueio nas DUAS direcoes e SILENCIO, por candidato.
  //
  // Numa mesa os candidatos sao os assentos; num saguao, os presentes. A lista
  // sai do CANAL, nunca do pedido.
  const candidatos = (canal?.participantes ?? [])
    .filter(
      (p) =>
        (p.papel === "jogador_sentado" || p.papel === "presente") &&
        p.uid !== autorUid
    )
    .map((p) => p.uid);

  const [contatos, silenciaramOAutor] = await Promise.all([
    Promise.all(
      candidatos.map(async (uid) => {
        const [ida, volta] = await Promise.all([
          usuarios.doc(autorUid).collection("blocks").doc(uid).get(),
          usuarios.doc(uid).collection("blocks").doc(autorUid).get(),
        ]);
        return { uid, autorBloqueou: ida.exists, bloqueouOAutor: volta.exists };
      })
    ),
    // SILENCIO E DO OUVINTE. A pergunta e "este candidato silenciou o autor?",
    // e por isso a leitura e em `users/{candidato}/mutes/{autor}` — a direcao
    // inversa da que se leria por engano. O contrario ("o autor silenciou este
    // candidato") e uma preferencia do autor sobre o que ELE ve, e nao tem
    // efeito nenhum sobre o que ele manda.
    Promise.all(
      candidatos.map(async (uid) => {
        const mute = await usuarios
          .doc(uid)
          .collection("mutes")
          .doc(autorUid)
          .get();
        return mute.exists ? uid : null;
      })
    ).then((lista) => lista.filter((uid): uid is string => uid !== null)),
  ]);

  // LEITURA 3: o direito VIP, SO quando o pedido e de item catalogado. Texto
  // livre nao tem item premium, e ler o documento a toa acrescentaria uma
  // leitura por linha de conversa.
  //
  // O DOCUMENTO ATRAVESSA INTEIRO E SEM INTERPRETACAO. Quem responde "tem VIP
  // agora?" e `EntitlementVip.vigenteEm`, no dominio — a definicao unica do
  // projeto. Um `doc.vipAtivo === true` aqui seria um segundo leitor de
  // assinatura, e ele erraria no caso que mais importa: assinatura cancelada
  // vigente tem `vipAtivo: true` ate o dia em que `expiraEm` fica no passado,
  // sem que ninguem escreva nada.
  const entitlement = ehCatalogado
    ? ((await db().collection(C_ENTITLEMENTS).doc(autorUid).get()).data() ??
      null)
    : null;

  // A DECISAO. Nenhum `if` de politica antes desta linha decidiu se a
  // comunicacao existe: o que veio antes foi leitura e forma.
  const veredito = dominio.avaliarComunicacao({
    autorUid,
    intentId,
    tipo,
    itemId: dados.itemId,
    conteudo: dados.conteudo,
    canal,
    sancao: {
      chatSilenciado: vigente("chatSilenciadoAte"),
      restricaoSocial: vigente("socialRestritoAte"),
      // §10: suspensao TEMPORARIA tambem cala. Ver `SancaoDoAutor.suspenso` no
      // dominio para a lacuna que isto NAO fecha nas rotas sociais.
      suspenso: vigente("suspensoAte") || est.suspensaoPermanente === true,
    },
    agora,
    contatos,
    silenciaramOAutor,
    camposDoPayload,
    autorPublicId,
    entitlement: entitlement as Record<string, unknown> | null,
    ritmo,
  });

  // O ESTADO DE RITMO E GRAVADO NOS DOIS DESFECHOS.
  //
  // Se so o aceito gravasse, uma rajada de pedidos RECUSADOS nao contaria como
  // abuso — e o freio automatico da §6.5 nunca dispararia, porque nenhuma
  // tentativa recusada teria deixado rastro. Quem inunda a mesa com pedidos
  // invalidos inunda igual.
  if (veredito.proximoRitmo) {
    await db()
      .collection(C_RITMO)
      .doc(autorUid)
      .set({ ...veredito.proximoRitmo, atualizadoEm: agora });
  }

  if (!veredito.aceita) {
    logger.info(
      "comunicacao recusada",
      registroSeguro({
        canalId,
        ambiente: canal?.ambiente,
        tipo,
        recusa: veredito.recusa,
        motivoDeRitmo: veredito.motivoDeRitmo,
      })
    );
    throw new HttpsError("failed-precondition", veredito.recusa ?? "recusada", {
      recusa: veredito.recusa,
      // O motivo CATEGORICO, para quem traduz a recusa no fio sem conhecer cada
      // nome. Ver `FamiliaDeRecusa` no dominio.
      familia: veredito.familia,
      motivoContato: veredito.motivoContato,
      motivoDeRitmo: veredito.motivoDeRitmo,
      camposProibidos: veredito.camposProibidos,
      // Informacao sobre QUEM PEDIU, e so sobre ele: quando a propria tentativa
      // volta a ser aceita. Nao revela nada de terceiro.
      liberaEmMs: veredito.liberaEmMs,
    });
  }

  const messageId = veredito.messageId as string;
  const canalConfirmado = canal as CanalDeComunicacao;
  const documento: DocumentoComunicacao = {
    messageId,
    canalId: canalConfirmado.canalId,
    superficie: canalConfirmado.superficie,
    ambiente: canalConfirmado.ambiente,
    tipo: veredito.tipo as string,
    autorUid,
    autorPublicId: autorPublicId as string,
    conteudo: veredito.conteudo ?? null,
    itemId: veredito.itemId ?? null,
    chaveDeLocalizacao: veredito.chaveDeLocalizacao ?? null,
    fallbackOficial: veredito.fallbackOficial ?? null,
    destinatarios: veredito.destinatarios ?? [],
    silenciados: veredito.silenciados ?? [],
    enviadaEm: agora,
    // §7.5. O campo e a metade do mecanismo de retencao; a outra e a politica de
    // TTL do projeto, que e configuracao e nao deploy de codigo.
    expiraEm: expiraEmDe(agora),
    versaoDoCatalogo: veredito.versaoDoCatalogo,
    versaoDoContrato: veredito.versaoDoContrato,
    esquema: veredito.esquema,
  };

  const resultado = await executarUmaVez(
    messageId,
    {
      tarefa: "enviarMensagemChat",
      ator: autorUid,
      alvo: documento.canalId,
      // O que a chave NAO carrega. Sem isto, o mesmo `intentId` reaproveitado
      // com OUTRO item encontraria a chave reservada e a autoridade responderia
      // sucesso sem gravar nada — o pedido sumiria com uma confirmacao na mao de
      // quem pediu.
      impressao: veredito.impressao as string,
    },
    async (tx) => {
      tx.create(db().collection(C_MENSAGENS).doc(messageId), documento);
      return { messageId };
    }
  );

  // REPETICAO: a comunicacao ja existia. Devolver `documento` (montado agora)
  // seria devolver um `enviadaEm` diferente do gravado, e o cliente veria a
  // mesma mensagem com dois horarios. Lemos o que esta gravado e projetamos
  // AQUELE.
  //
  // `destinatarios` e `silenciados` tambem saem do GRAVADO: um retry depois de
  // alguem bloquear (ou silenciar) teria listas novas, e reentregar por elas
  // faria a MESMA mensagem alcancar um conjunto diferente de pessoas.
  if (!resultado.executou) {
    const gravado = await db().collection(C_MENSAGENS).doc(messageId).get();
    if (!gravado.exists) {
      // Reserva sem mensagem nao deveria existir: as duas escritas acontecem na
      // MESMA transacao. Se acontecer, e defeito — e defeito nao se responde com
      // uma mensagem inventada.
      logger.error("reserva de chat sem mensagem gravada", { messageId });
      throw new HttpsError("internal", "mensagem reservada e ausente.");
    }
    const doc = gravado.data() as DocumentoComunicacao;
    return {
      enviada: true,
      jaEnviada: true,
      mensagem: projetarComunicacao(doc),
      destinatarios: Array.isArray(doc.destinatarios) ? doc.destinatarios : [],
      silenciados: Array.isArray(doc.silenciados) ? doc.silenciados : [],
    };
  }

  logger.info(
    "comunicacao gravada",
    registroSeguro({
      canalId: documento.canalId,
      ambiente: documento.ambiente,
      tipo: tipoDe(documento),
      itemId: documento.itemId ?? undefined,
      destinatarios: documento.destinatarios.length,
      silenciados: (documento.silenciados ?? []).length,
    })
  );

  return {
    enviada: true,
    jaEnviada: false,
    // `projetarComunicacao` e lista de PERMISSAO e passa por
    // `exigirEntregaSegura`: `autorUid`, `destinatarios` e `silenciados` nao
    // saem daqui, e um campo novo no documento nao vaza por esquecimento.
    mensagem: projetarComunicacao(documento),
    destinatarios: documento.destinatarios,
    silenciados: documento.silenciados ?? [],
  };
}

// ------------------------------------------------- ADAPTADOR DO JOGADOR
//
// FECHADO NESTA OS, e nao apagado (§11 da OS do Transporte).
//
// A DECISAO E A RAZAO. O transporte do chat passou a ser o servidor de partidas:
// e ele que sabe em que sala o jogador esta, que assento ocupa e para quais
// sockets a projecao vai. Deixar TAMBEM um ingresso direto do aplicativo criaria
// dois caminhos produtivos com consequencias diferentes para a MESMA mensagem —
// o do servidor grava e ENTREGA, e o direto gravaria e NAO entregaria, porque
// ninguem estaria escutando por ele. O resultado seria mensagem autoritativa que
// nenhum jogador recebe, e um jogador convencido de que falou.
//
// NAO E BURACO DE SEGURANCA QUE SE FECHA AQUI: o ingresso direto nunca permitiu
// forjar autoria nem furar bloqueio — a autoridade valida participacao contra
// `chatChannels`. O que se fecha e uma INCOERENCIA de entrega.
//
// POR QUE CONTINUA EXPORTADA. Apagar o export mudaria a superficie de deploy sem
// deixar rastro para quem chamar amanha, e a §11 pede decisao documentada em vez
// de remocao silenciosa. Ela responde uma recusa ESTAVEL e nomeada, que um
// cliente antigo consegue distinguir de "falhou": `ingressoDiretoDesativado`.
//
// O NUCLEO CONTINUA PROVADO. `executarEnvioDeMensagem` e exercitado de ponta a
// ponta pela suite de emulador atraves do adaptador do motor, e as regras de
// conteudo, bloqueio, sancao e superficie continuam provadas pelo dominio.
export const enviarMensagemChat = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  logger.info("ingresso direto de chat recusado", { uid });
  throw new HttpsError("failed-precondition", "ingressoDiretoDesativado", {
    recusa: "ingressoDiretoDesativado",
    // Sem detalhe interno: o cliente so precisa saber que o caminho e outro.
    caminho: "transporte",
  });
});

// -------------------------------------------------- ADAPTADOR DO MOTOR
//
/// Envia uma mensagem em nome de um jogador. SO MOTOR OU ADMIN.
///
/// POR QUE ESTA PORTA EXISTE, e por que `autorUid` no payload aqui NAO e a falha
/// que ele seria na porta do jogador (§10):
///
/// O UID autenticado desta chamada e o do MOTOR, nao o do autor. Nao ha como
/// derivar o autor de `req.auth.uid` sem maquiar a diferenca — seria gravar toda
/// mensagem da mesa como se o motor a tivesse escrito. Entao o autor VEM no
/// payload, e o que o torna confiavel nao e o campo: e o claim
/// `motorDePartidas` do chamador, mais a conferencia da autoridade de que aquele
/// UID de fato OCUPA o canal (`papelSemDireitoDeFala` para quem nao ocupa).
///
/// O motor nao ganha poder de falar por quem quiser: ele ganha poder de falar por
/// quem esta sentado, e apenas no canal que ele mesmo declarou.
///
/// DEVOLVE `destinatarios`. E o unico ponto do sistema que devolve UIDs, e existe
/// porque o transporte precisa saber para quais sockets entregar. A §12 e §13 se
/// encontram aqui: a lista e do TRANSPORTE, e o pacote que chega ao jogador e
/// somente `mensagem`.
export const enviarMensagemChatPeloMotor = onCall(opcoesCliente, async (req) => {
  exigirMotorOuAdmin(req);
  const dados = (req.data ?? {}) as Record<string, unknown>;

  const autorUid = exigirIdSeguro(dados.autorUid, "autorUid");

  // `autorUid` e legitimo AQUI e proibido no dominio, entao ele nao pode entrar na
  // lista de campos que a trava inspeciona — senao a porta do motor recusaria a
  // si mesma. Todo o RESTO do payload continua sendo inspecionado: um motor que
  // mandasse `messageId`, `enviadaEm` ou `socketId` seria recusado igual.
  const camposDoPayload = Object.keys(dados).filter((k) => k !== "autorUid");

  const r = await executarEnvioDeMensagem(autorUid, dados, camposDoPayload);

  return {
    enviada: r.enviada,
    jaEnviada: r.jaEnviada,
    mensagem: r.mensagem,
    destinatarios: r.destinatarios,
    // Quem silenciou o autor. E lista de UID e existe pelo mesmo motivo de
    // `destinatarios`: o transporte precisa saber a quem nao entregar. As duas
    // param no servidor — o pacote que chega ao jogador e somente `mensagem`.
    silenciados: r.silenciados,
  };
});


// ================================================== EVENTO DE SISTEMA (§8)
//
// "Usuario comum nao podera fabricar 'Voce recebeu um presente', 'Sou
// moderador', 'Jogador foi banido', 'Pegue seu presente'."
//
// A garantia NAO e uma checagem de texto: e a inexistencia de caminho. O
// pedido do jogador (`enviarMensagemChatPeloMotor`) nao tem campo `eventoId`,
// e o dominio recusa `tipo: evento_de_sistema` vindo dele
// (`eventoDeSistemaSemAutoridade`). O evento so nasce por ESTA porta, que exige
// o claim, e so com um id que existe no catalogo de eventos.
//
// O EVENTO NAO TEM AUTOR. `autorUid` e `autorPublicId` sao `null` no documento
// e ausentes na projecao — e essa ausencia e o que o cliente le para saber que
// nao ha uma pessoa por tras. Um evento com autor seria indistinguivel de uma
// fala, e a §8 seria decorativa.
//
// ESTA OS NAO CRIA PRESENTE, nao move carteira e nao concede assinatura. Quem
// produz o FATO e a autoridade de Presentes, de Moderacao ou de Salas; o que
// nasce aqui e o AVISO daquele fato, localizado pelo cliente.
export const emitirEventoDeSistema = onCall(opcoesCliente, async (req) => {
  exigirMotorOuAdmin(req);
  const dados = (req.data ?? {}) as Record<string, unknown>;

  const intentId = exigirIdSeguro(dados.intentId, "intentId");
  const canalId = exigirIdSeguro(dados.canalId, "canalId");

  const canalSnap = await db().collection(C_CANAIS).doc(canalId).get();
  const canalBruto = canalSnap.exists
    ? (canalSnap.data() as Record<string, unknown>)
    : null;

  const canal: CanalDeComunicacao | null = canalBruto
    ? {
        canalId: String(canalBruto.canalId ?? canalId),
        superficie: String(canalBruto.superficie ?? ""),
        ambiente: String(canalBruto.ambiente ?? ""),
        modo: String(canalBruto.modo ?? ""),
        aberto: canalBruto.aberto === true,
        participantes: Array.isArray(canalBruto.participantes)
          ? (canalBruto.participantes as Record<string, unknown>[]).map((x) => ({
              uid: String(x?.uid ?? ""),
              papel: String(x?.papel ?? "fora_do_canal"),
            }))
          : [],
      }
    : null;

  const veredito = dominio.avaliarEventoDeSistema({
    eventoId: dados.eventoId,
    canal,
    intentId,
    // Decidido AQUI, contra o claim que `exigirMotorOuAdmin` ja conferiu. Nao
    // e lido do payload em caminho nenhum.
    autoridadeConfirmada: true,
  });

  if (!veredito.aceita) {
    logger.info(
      "evento de sistema recusado",
      registroSeguro({
        canalId,
        ambiente: canal?.ambiente,
        recusa: veredito.recusa,
      })
    );
    throw new HttpsError("failed-precondition", veredito.recusa ?? "recusado", {
      recusa: veredito.recusa,
    });
  }

  const agora = agoraUtc();
  const messageId = veredito.messageId as string;
  const canalConfirmado = canal as CanalDeComunicacao;

  const documento: DocumentoComunicacao = {
    messageId,
    canalId: canalConfirmado.canalId,
    superficie: canalConfirmado.superficie,
    ambiente: canalConfirmado.ambiente,
    tipo: veredito.tipo as string,
    // SEM DONO. Ver o cabecalho deste bloco.
    autorUid: null,
    autorPublicId: null,
    conteudo: null,
    itemId: veredito.itemId ?? null,
    chaveDeLocalizacao: veredito.chaveDeLocalizacao ?? null,
    fallbackOficial: veredito.fallbackOficial ?? null,
    destinatarios: veredito.destinatarios ?? [],
    silenciados: [],
    enviadaEm: agora,
    expiraEm: expiraEmDe(agora),
    versaoDoCatalogo: veredito.versaoDoCatalogo,
    versaoDoContrato: veredito.versaoDoContrato,
    esquema: veredito.esquema,
  };

  const resultado = await executarUmaVez(
    messageId,
    {
      tarefa: "emitirEventoDeSistema",
      ator: "sistema",
      alvo: documento.canalId,
      impressao: veredito.impressao as string,
    },
    async (tx) => {
      tx.create(db().collection(C_MENSAGENS).doc(messageId), documento);
      return { messageId };
    }
  );

  if (!resultado.executou) {
    const gravado = await db().collection(C_MENSAGENS).doc(messageId).get();
    if (!gravado.exists) {
      logger.error("reserva de evento sem documento gravado", { messageId });
      throw new HttpsError("internal", "evento reservado e ausente.");
    }
    const doc = gravado.data() as DocumentoComunicacao;
    return {
      emitido: true,
      jaEmitido: true,
      mensagem: projetarComunicacao(doc),
      destinatarios: Array.isArray(doc.destinatarios) ? doc.destinatarios : [],
    };
  }

  logger.info(
    "evento de sistema emitido",
    registroSeguro({
      canalId: documento.canalId,
      ambiente: documento.ambiente,
      tipo: documento.tipo,
      itemId: documento.itemId ?? undefined,
      destinatarios: documento.destinatarios.length,
    })
  );

  return {
    emitido: true,
    jaEmitido: false,
    mensagem: projetarComunicacao(documento),
    destinatarios: documento.destinatarios,
  };
});

// ====================================================== CATALOGO (§6.2)
//
/// O catalogo autoritativo e a matriz de ambientes, para o cliente.
///
/// SO LEITURA, e sem filtro vindo do pedido. Duas razoes para devolver o
/// catalogo INTEIRO em vez de "o que voce pode usar":
///
///   1. o que o jogador PODE usar depende do ambiente em que ele estiver
///      daqui a um minuto, e de um direito que pode expirar no meio da
///      partida. Uma lista personalizada seria uma foto que envelhece;
///   2. a decisao continua sendo tomada no ENVIO, contra o direito vigente
///      naquele instante. Se a tela mostrar um item premium a quem nao tem
///      VIP, o pior que acontece e uma recusa nomeada — e nao um envio.
///
/// O cliente e quem decide como apresentar. Esta OS nao desenha tela.
export const consultarCatalogoDeComunicacao = onCall(
  opcoesCliente,
  async (req) => {
    exigirAutenticacao(req);
    const catalogo = dominio.catalogo();
    const politica = dominio.politicaDeAmbientes();
    return {
      versao: catalogo.versao,
      itens: catalogo.itens,
      eventosDeSistema: catalogo.eventosDeSistema,
      ambientes: politica.ambientes,
      ritmo: politica.ritmo,
      versaoDoContrato: politica.versaoDoContrato,
    };
  }
);
