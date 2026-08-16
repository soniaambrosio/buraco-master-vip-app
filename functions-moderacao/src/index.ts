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

import { dominio, agoraUtc } from "./domain";
import { db, executarUmaVez } from "./idempotency";

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
    denunciadoUid,
    tipo,
    categoria,
    reportIntentId,
    comentario,
    matchId,
    roomId,
    messageId,
    evidenciaMensagem,
  } = req.data ?? {};

  if (
    typeof denunciadoUid !== "string" ||
    typeof tipo !== "string" ||
    typeof categoria !== "string" ||
    typeof reportIntentId !== "string"
  ) {
    throw new HttpsError(
      "invalid-argument",
      "denunciadoUid, tipo, categoria e reportIntentId sao obrigatorios."
    );
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

  // A EVIDENCIA (secao 5 da OS).
  //
  // LIMITACAO REGISTRADA, e nao escondida: nao existe chat no servidor hoje (ver
  // docs/MODERACAO.md e o relatorio da OS). Enquanto o conteudo da mensagem so
  // existir no aparelho, a evidencia de mensagem e ATESTADA PELO CLIENTE, e o
  // registro diz isso em `origem`. Quando o chat passar a ser servidor-lado, a
  // Function preenche a mesma estrutura com `origem: "servidor"` e o campo
  // atestado deixa de ser aceito — sem migrar o que ja foi gravado.
  const evidencia =
    tipo === "mensagem" && evidenciaMensagem && typeof evidenciaMensagem === "object"
      ? {
          origem: "cliente_atestada",
          autorUid: denunciadoUid,
          conteudo: textoOpcional((evidenciaMensagem as Record<string, unknown>).conteudo, 2000),
          enviadaEm:
            typeof (evidenciaMensagem as Record<string, unknown>).enviadaEm === "string"
              ? (evidenciaMensagem as Record<string, unknown>).enviadaEm
              : null,
          messageId: messageId ?? null,
          roomId: roomId ?? null,
        }
      : { origem: "referencia", messageId: messageId ?? null, roomId: roomId ?? null };

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
