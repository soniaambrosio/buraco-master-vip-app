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
  CanalDeChat,
  ParDeContato,
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
  projetarMensagem,
} from "./chat";

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
  const docMensagem =
    tipo === "mensagem" && typeof messageId === "string"
      ? await db().collection(C_MENSAGENS).doc(messageId).get()
      : null;

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

  const evidencia = evidenciaDeMensagem(
    {
      messageId: typeof messageId === "string" ? messageId : null,
      roomId: typeof roomId === "string" ? roomId : null,
      denunciadoUid,
      atestadaPeloCliente: tipo === "mensagem" ? atestada : null,
    },
    docMensagem && docMensagem.exists
      ? (docMensagem.data() as DocumentoMensagem)
      : null
  );

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
  const { canalId, superficie, participantes, aberto } = req.data ?? {};

  const id = exigirIdSeguro(canalId, "canalId");

  if (typeof superficie !== "string") {
    throw new HttpsError("invalid-argument", "superficie e obrigatoria.");
  }

  // A superficie precisa ser uma que o DOMINIO conheca e libere. Aceitar string
  // qualquer aqui deixaria o motor abrir canal fora da classificacao da §11, e a
  // §11 seria letra morta.
  const politicas = dominio.politicaDeSuperficies();
  const politica = politicas.superficies.find((s) => s.superficie === superficie);
  if (!politica) {
    throw new HttpsError("invalid-argument", "superficie desconhecida.");
  }
  if (!politica.aceitaTextoLivre) {
    throw new HttpsError("failed-precondition", "superficieNaoAceitaChat", {
      recusa: "superficieNaoAceitaChat",
      superficie,
    });
  }

  if (!Array.isArray(participantes)) {
    throw new HttpsError("invalid-argument", "participantes e obrigatorio.");
  }

  const normalizados = participantes.map((p) => {
    const item = (p ?? {}) as Record<string, unknown>;
    return {
      uid: exigirIdSeguro(item.uid, "participantes[].uid"),
      papel: typeof item.papel === "string" ? item.papel : "fora_do_canal",
    };
  });

  await db()
    .collection(C_CANAIS)
    .doc(id)
    .set({
      canalId: id,
      superficie,
      participantes: normalizados,
      // Ausente vira FECHADO, igual ao dominio: um canal so aceita fala se alguem
      // disser explicitamente que ele esta aberto.
      aberto: aberto === true,
      atualizadoEm: agoraUtc(),
      atualizadoPor: responsavel,
      esquema: politicas.esquema,
    });

  logger.info("canal de chat declarado", {
    canalId: id,
    aberto: aberto === true,
  });
  return { definido: true, canalId: id };
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
  mensagem: ReturnType<typeof projetarMensagem>;
  destinatarios: string[];
}

async function executarEnvioDeMensagem(
  autorUid: string,
  dados: Record<string, unknown>,
  camposDoPayload: string[]
): Promise<ResultadoEnvio> {
  const intentId = exigirIdSeguro(dados.intentId, "intentId");
  const canalId = exigirIdSeguro(dados.canalId, "canalId");

  const usuarios = db().collection("users");

  // LEITURA 1: canal, identidade publica e estado disciplinar do autor. Em
  // paralelo porque nenhuma depende da outra.
  const [canalSnap, identidadeSnap, estadoSnap] = await Promise.all([
    db().collection(C_CANAIS).doc(canalId).get(),
    db().collection(C_IDENTIDADES).doc(autorUid).get(),
    db().collection(COL_ESTADO).doc(autorUid).get(),
  ]);

  const canalBruto = canalSnap.exists
    ? (canalSnap.data() as Record<string, unknown>)
    : null;

  const canal: CanalDeChat | null = canalBruto
    ? {
        canalId: String(canalBruto.canalId ?? canalId),
        superficie: String(canalBruto.superficie ?? ""),
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
  // operacao fariam a primeira checagem dizer "silenciado" e a segunda,
  // milissegundos depois, dizer "livre" — o cuidado que o cabecalho de sancao.dart
  // declara.
  const agora = agoraUtc();
  const est = estadoSnap.data() ?? {};
  const vigente = (campo: string): boolean =>
    typeof est[campo] === "string" && agora < (est[campo] as string);

  // LEITURA 2: bloqueio nas DUAS direcoes, por assento. Somente para quem esta
  // sentado e nao e o autor — espectador nao recebe, entao nao ha par a consultar.
  const assentos = (canal?.participantes ?? [])
    .filter((p) => p.papel === "jogador_sentado" && p.uid !== autorUid)
    .map((p) => p.uid);

  const contatos: ParDeContato[] = await Promise.all(
    assentos.map(async (uid) => {
      const [ida, volta] = await Promise.all([
        usuarios.doc(autorUid).collection("blocks").doc(uid).get(),
        usuarios.doc(uid).collection("blocks").doc(autorUid).get(),
      ]);
      return { uid, autorBloqueou: ida.exists, bloqueouOAutor: volta.exists };
    })
  );

  // A DECISAO. Nenhum `if` de politica antes desta linha decidiu se a mensagem
  // existe: o que veio antes foi leitura e forma.
  const veredito = dominio.avaliarEnvioChat({
    autorUid,
    intentId,
    conteudo: dados.conteudo,
    superficie: dados.superficie,
    canal,
    sancao: {
      chatSilenciado: vigente("chatSilenciadoAte"),
      restricaoSocial: vigente("socialRestritoAte"),
      // §8: suspensao TEMPORARIA tambem cala. `TipoSancao.suspensaoTemporaria`
      // esta documentada como "impede entrar na aplicacao por um prazo", e quem
      // nao entra nao fala. Ver `SancaoDoAutor.suspenso` no dominio para a lacuna
      // que isto NAO fecha nas rotas sociais.
      suspenso: vigente("suspensoAte") || est.suspensaoPermanente === true,
    },
    contatos,
    camposDoPayload,
    autorPublicId,
  });

  if (!veredito.aceita) {
    logger.info("mensagem de chat recusada", {
      canalId,
      recusa: veredito.recusa,
      motivoContato: veredito.motivoContato,
    });
    throw new HttpsError("failed-precondition", veredito.recusa ?? "recusada", {
      recusa: veredito.recusa,
      motivoContato: veredito.motivoContato,
      camposProibidos: veredito.camposProibidos,
    });
  }

  const messageId = veredito.messageId as string;
  const documento: DocumentoMensagem = {
    messageId,
    canalId: (canal as CanalDeChat).canalId,
    superficie: (canal as CanalDeChat).superficie,
    autorUid,
    autorPublicId: autorPublicId as string,
    conteudo: veredito.conteudo as string,
    destinatarios: veredito.destinatarios ?? [],
    enviadaEm: agora,
    esquema: veredito.esquema,
  };

  const resultado = await executarUmaVez(
    messageId,
    {
      tarefa: "enviarMensagemChat",
      ator: autorUid,
      alvo: documento.canalId,
      // O que a chave NAO carrega. Sem isto, o mesmo `intentId` reaproveitado com
      // OUTRO texto encontraria a chave reservada e a autoridade responderia
      // sucesso sem gravar a mensagem nova — a mensagem pedida desapareceria com
      // uma confirmacao na mao de quem pediu.
      impressao: veredito.impressao as string,
    },
    async (tx) => {
      tx.create(db().collection(C_MENSAGENS).doc(messageId), documento);
      return { messageId };
    }
  );

  // REPETICAO: a mensagem ja existia. Devolver `documento` (montado agora) seria
  // devolver um `enviadaEm` diferente do gravado, e o cliente veria a mesma
  // mensagem com dois horarios. Lemos o que esta gravado e projetamos AQUELE.
  //
  // O `destinatarios` tambem sai do GRAVADO, e nao do veredito recem-calculado:
  // um retry depois de alguem bloquear teria uma lista nova, e reentregar por ela
  // faria a MESMA mensagem alcancar um conjunto diferente de pessoas. A entrega
  // repetida segue a decisao da vez em que a mensagem nasceu (§15).
  if (!resultado.executou) {
    const gravado = await db().collection(C_MENSAGENS).doc(messageId).get();
    if (!gravado.exists) {
      // Reserva sem mensagem nao deveria existir: as duas escritas acontecem na
      // MESMA transacao. Se acontecer, e defeito — e defeito nao se responde com
      // uma mensagem inventada.
      logger.error("reserva de chat sem mensagem gravada", { messageId });
      throw new HttpsError("internal", "mensagem reservada e ausente.");
    }
    const doc = gravado.data() as DocumentoMensagem;
    return {
      enviada: true,
      jaEnviada: true,
      mensagem: projetarMensagem(doc),
      destinatarios: Array.isArray(doc.destinatarios) ? doc.destinatarios : [],
    };
  }

  logger.info("mensagem de chat gravada", {
    canalId: documento.canalId,
    destinatarios: documento.destinatarios.length,
  });

  return {
    enviada: true,
    jaEnviada: false,
    // `projetarMensagem` e lista de PERMISSAO e passa por `exigirEntregaSegura`:
    // `autorUid` e `destinatarios` nao saem daqui, e um campo novo no documento
    // nao vaza por esquecimento.
    mensagem: projetarMensagem(documento),
    destinatarios: documento.destinatarios,
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
  };
});
