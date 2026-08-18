// index.ts — QUEM ATENDE. Autenticacao, forma do payload, traducao de recusa.
//
// A mesma reparticao de papeis dos outros codebases deste projeto:
//
//   QUEM DECIDE  -> tipos.ts, politica.ts, passe.ts, salas.ts, elegibilidade.ts
//                   e decisao.ts. Puros, conferidos com `node --test`.
//   QUEM EXECUTA -> firestore.ts. Transacao, leitura, escrita.
//   QUEM ATENDE  -> este arquivo.
//
// ===========================================================================
// TODO `export` DAQUI VIRA UMA CLOUD FUNCTION
// ===========================================================================
//
// Este projeto ja pagou por isso uma vez: um `export` a mais em `index.ts`
// aparece como funcao implantada. Por isso a lista abaixo e curta e cada nome
// esta declarado de proposito. Nada de utilitario exportado por conveniencia —
// o que for compartilhado mora nos modulos, e este arquivo so importa.
//
//   admitirEmMesaVip ................. onRequest. O SERVIDOR chama.
//   consultarPasseDeCortesia ......... onCall. O aplicativo chama.
//   registrarMesaPrivada ............. onCall. O aplicativo chama.
//   resolverConviteDeMesaPrivada ..... onCall. O aplicativo chama.
//
// ===========================================================================
// POR QUE `onRequest`, E NAO `onCall`
// ===========================================================================
//
// `admitirEmMesaVip` e o UNICO `onRequest` deste projeto, e a excecao tem
// motivo: quem chama nao e um aparelho com o SDK do Firebase — e o servidor de
// mesas, em Node puro, que ja fala o contrato `admissao-vip-v1` e ja esta
// implantado. Uma callable exigiria que ele embrulhasse o corpo em `{data:
// ...}` e desembrulhasse `{result: ...}`, ou seja, exigiria mudar o adaptador
// que ja foi homologado do outro lado.
//
// O preco de `onRequest` e que a autenticacao nao vem pronta: nao ha
// `req.auth`. Ela e feita aqui, a mao, e por isso esta escrita em UM lugar so,
// logo abaixo.
//
// ===========================================================================
// O QUE NUNCA E REGISTRADO
// ===========================================================================
//
// ID token, cabecalho `authorization`, corpo da requisicao, corpo da resposta,
// codigo de convite em claro, e-mail, conteudo de chat. O que se registra sao
// codigos secos de uma lista fechada, e o `tentativaEntradaId`, que e opaco e
// cunhado pelo servidor.

import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { logger } from "firebase-functions";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { onRequest } from "firebase-functions/v2/https";
import { randomBytes } from "node:crypto";

import { TIPO_MESA } from "./tipos";
import { ESTADO_CADEIRA, temProprietarioDeCadeiras } from "./politica";
import { BYTES_NECESSARIOS, VALIDADE_CODIGO_MS, cunharCodigo, redigirCodigo } from "./salas";
import { storePadrao } from "./firestore";

initializeApp();

const REGIAO = "southamerica-east1";

/// App Check EXIGIDO em producao, dispensado sob o emulador.
///
/// `FUNCTIONS_EMULATOR` e posto pelo proprio emulador e nunca vale "true" num
/// processo implantado. Mesma disciplina de functions-conta.
const SOB_EMULADOR = process.env.FUNCTIONS_EMULATOR === "true";

/// Opcoes das callables que o APLICATIVO chama.
const opcoesCliente = { enforceAppCheck: !SOB_EMULADOR, region: REGIAO };

/// Opcoes do endpoint que o SERVIDOR chama.
///
/// Sem App Check, pelo mesmo motivo de `registrarEncerramentoPartida` e
/// `receberResultadoPartida`: quem chama nao e um aparelho. A prova de
/// autoridade dele e outra, e e mais forte — o claim `motorDePartidas` num
/// token assinado.
const opcoesServidor = { region: REGIAO };

/// Versao do contrato de transporte com o servidor de mesas.
const CONTRATO = "admissao-vip-v1";

/// Papeis que podem pedir admissao ao assento.
///
/// Espelha `PAPEIS_DE_AUTORIDADE` de `functions/src/rastreabilidade.ts`. A
/// duplicacao e inevitavel entre codebases e esta anotada de proposito para
/// quem for unifica-las achar os dois pontos.
const PAPEIS_DE_AUTORIDADE = ["motorDePartidas", "admin"] as const;

// ===========================================================================
// A UNICA RECUSA QUE SAI NO FIO
// ===========================================================================

/// Toda recusa de admissao responde ISTO, e nada mais.
///
/// Uma mensagem so para todos os motivos, porque mensagens diferentes viram
/// oraculo: quem tentasse varias vezes leria nas diferencas o estado interno
/// que o codigo nao conta — se o jogador tem passe, se a assinatura venceu
/// ontem, se a sala existe. O motivo real vai para `admissoesDeMesa` e para o
/// log, com o autor identificado.
///
/// A forma tambem importa: HTTP 200 com `ok: false`. O adaptador do servidor
/// trata 5xx como falha TEMPORARIA (e o jogador tenta de novo) e `ok:false`
/// como negativa comercial (e ele nao tenta). Responder 403 numa recusa
/// comercial faria o servidor tratar "voce nao e assinante" como "o backend
/// caiu".
const RESPOSTA_RECUSA = { versaoContrato: CONTRATO, ok: false as const };

// ===========================================================================
// admitirEmMesaVip — o endpoint que o servidor de mesas chama
// ===========================================================================

/// Os oito campos do contrato, e so eles.
///
/// A lista e FECHADA: um campo a mais no corpo e recusa, e nao "ignora e
/// segue". Ignorar atenderia igual e esconderia a tentativa — e o campo a mais
/// e exatamente a forma de um cliente modificado tentar declarar o que nao lhe
/// cabe (`isVip`, `ranqueada`, `tipoMesa`).
const CAMPOS_DO_CONTRATO = [
  "versaoContrato",
  "uidAutenticado",
  "codigoDaSala",
  "identidadeDaPartida",
  "assento",
  "categoriaCompetitiva",
  "tentativaEntradaId",
  "reconexao",
] as const;

/// O `tentativaEntradaId` e cunhado pelo servidor com o prefixo `te_`. Exigir
/// o prefixo aqui NAO e seguranca (quem forja um id forja o prefixo junto): e
/// deteccao. `eventoId` nunca usa esse prefixo, e um `eventoId` apresentado
/// como tentativa passa a ser recusado em vez de virar uma chave de
/// idempotencia que colide com outra coisa.
const PREFIXO_TENTATIVA = "te_";

type CorpoValido = {
  uidAutenticado: string;
  codigoDaSala: string;
  identidadeDaPartida: string | null;
  assento: number;
  categoriaCompetitiva: string;
  tentativaEntradaId: string;
  reconexao: boolean;
};

function lerCorpo(bruto: unknown): CorpoValido | null {
  if (!bruto || typeof bruto !== "object" || Array.isArray(bruto)) return null;
  const c = bruto as Record<string, unknown>;

  for (const chave of Object.keys(c)) {
    if (!CAMPOS_DO_CONTRATO.some((k) => k === chave)) return null;
  }
  if (c.versaoContrato !== CONTRATO) return null;
  if (typeof c.uidAutenticado !== "string" || c.uidAutenticado === "") return null;
  if (typeof c.codigoDaSala !== "string" || c.codigoDaSala === "") return null;
  if (c.identidadeDaPartida !== null && typeof c.identidadeDaPartida !== "string") return null;
  if (typeof c.assento !== "number" || !Number.isInteger(c.assento)) return null;
  if (typeof c.categoriaCompetitiva !== "string") return null;
  if (typeof c.tentativaEntradaId !== "string" || !c.tentativaEntradaId.startsWith(PREFIXO_TENTATIVA)) {
    return null;
  }
  if (typeof c.reconexao !== "boolean") return null;

  return {
    uidAutenticado: c.uidAutenticado,
    codigoDaSala: c.codigoDaSala,
    identidadeDaPartida: c.identidadeDaPartida as string | null,
    assento: c.assento,
    categoriaCompetitiva: c.categoriaCompetitiva,
    tentativaEntradaId: c.tentativaEntradaId,
    reconexao: c.reconexao,
  };
}

/// Verifica a credencial do motor.
///
/// TRES portoes, e cada um fecha uma coisa diferente:
///   1. ha `Bearer` no cabecalho?
///   2. o token e valido AGORA? (`verifyIdToken` confere assinatura, emissor,
///      audiencia e expiracao — e `true` no segundo argumento confere tambem
///      se a sessao foi REVOGADA, que e o que faz uma credencial cassada parar
///      de funcionar antes de expirar sozinha)
///   3. o token carrega o papel de autoridade?
async function autoridadeDoMotor(cabecalho: unknown): Promise<{ uid: string } | null> {
  if (typeof cabecalho !== "string" || !cabecalho.startsWith("Bearer ")) return null;
  const token = cabecalho.slice("Bearer ".length).trim();
  if (token === "") return null;

  try {
    const decodificado = await getAuth().verifyIdToken(token, true);
    const temPapel = PAPEIS_DE_AUTORIDADE.some(
      (papel) => (decodificado as Record<string, unknown>)[papel] === true,
    );
    if (!temPapel) return null;
    return { uid: decodificado.uid };
  } catch (_) {
    // A excecao NAO e interpolada em lugar nenhum: `e.message` do
    // firebase-admin carrega pedacos do token.
    return null;
  }
}

export const admitirEmMesaVip = onRequest(opcoesServidor, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json(RESPOSTA_RECUSA);
    return;
  }

  const autoridade = await autoridadeDoMotor(req.get("authorization"));
  if (autoridade === null) {
    // 401, e nao 200 com `ok:false`: credencial invalida NAO e negativa
    // comercial. O adaptador trata as duas diferente, e trata certo.
    logger.warn("admissao recusada", { etapa: "credencial" });
    res.status(401).json(RESPOSTA_RECUSA);
    return;
  }

  const corpo = lerCorpo(req.body);
  if (corpo === null) {
    logger.warn("admissao recusada", { etapa: "contrato" });
    res.status(400).json(RESPOSTA_RECUSA);
    return;
  }

  try {
    const r = await storePadrao().admitir(corpo);
    if (!r.ok) {
      logger.info("admissao recusada", {
        etapa: "decisao",
        motivo: r.codigoRecusa,
        tentativa: corpo.tentativaEntradaId,
      });
      res.status(200).json(RESPOSTA_RECUSA);
      return;
    }
    logger.info("admissao aprovada", {
      tipo: r.tipo,
      fonte: r.fonteElegibilidade,
      repetida: r.repetida,
      tentativa: corpo.tentativaEntradaId,
    });
    res.status(200).json({ versaoContrato: CONTRATO, ok: true, admissaoId: r.admissaoId });
  } catch (erro) {
    // 500 de proposito: uma falha de infraestrutura E temporaria, e o
    // adaptador precisa poder distingui-la de uma negativa comercial.
    logger.error("admissao falhou", { etapa: "transacao" });
    res.status(500).json(RESPOSTA_RECUSA);
  }
});

// ===========================================================================
// AS CALLABLES DO APLICATIVO
// ===========================================================================

function uidDe(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "e preciso estar autenticado.");
  return uid;
}

/// O payload NAO escolhe de quem e a conta.
///
/// E se ele TRAZ um `uid`, a chamada e RECUSADA em vez de atendida com o uid
/// certo. Ignorar em silencio funcionaria igual e esconderia a tentativa.
function recusarUidNoPayload(dados: unknown): void {
  if (dados && typeof dados === "object" && "uid" in (dados as Record<string, unknown>)) {
    throw new HttpsError("permission-denied", "o uid nao vem do payload.");
  }
}

/// O estado do passe, para a tela. NAO decide admissao.
///
/// Ela devolve FATOS — se ha passe utilizavel, quando ele vence e quando vem o
/// proximo — e nenhum veredito de entrada. A tela usa isso para nao empurrar o
/// jogador a uma porta que vai fechar; quem decide a porta e
/// `admitirEmMesaVip`, do outro lado.
export const consultarPasseDeCortesia = onCall(opcoesCliente, async (req) => {
  recusarUidNoPayload(req.data);
  const uid = uidDe(req);
  return storePadrao().consultarPasse(uid);
});

/// Registra uma Mesa Privada e devolve o convite.
///
/// O CODIGO E CUNHADO AQUI, com `randomBytes`. Ele nunca vem do payload — a
/// secao 5.3 da OS proibe codigo escolhido pelo cliente, e a proibicao e
/// estrutural: nao ha campo por onde ele entraria.
///
/// Devolvido UMA VEZ, na resposta desta chamada. O banco guarda so a
/// impressao, entao nao ha caminho para recupera-lo depois — quem perdeu o
/// convite abre outra sala.
export const registrarMesaPrivada = onCall(opcoesCliente, async (req) => {
  recusarUidNoPayload(req.data);
  const uid = uidDe(req);

  const dados = (req.data ?? {}) as Record<string, unknown>;
  const codigoDaSala = dados.codigoDaSala;
  if (typeof codigoDaSala !== "string" || codigoDaSala === "") {
    throw new HttpsError("invalid-argument", "codigo da sala ausente.");
  }
  if ("codigoConvite" in dados || "codigo" in dados) {
    // A tentativa de escolher o proprio convite e recusa explicita.
    throw new HttpsError("permission-denied", "o convite nao vem do payload.");
  }

  const cadeiras = Array.isArray(dados.cadeiras) ? dados.cadeiras : ["liberada", "liberada", "liberada", "liberada"];
  if (!temProprietarioDeCadeiras(TIPO_MESA.PRIVADA)) {
    throw new HttpsError("failed-precondition", "politica de cadeiras indisponivel.");
  }
  for (const c of cadeiras) {
    if (typeof c !== "string" || !ESTADO_CADEIRA.includes(c)) {
      throw new HttpsError("invalid-argument", "estado de cadeira invalido.");
    }
  }

  const codigoConvite = cunharCodigo(randomBytes(BYTES_NECESSARIOS));
  const expiraEm = new Date(Date.now() + VALIDADE_CODIGO_MS).toISOString();

  const r = await storePadrao().registrarMesaPrivada({
    uid,
    codigoDaSala,
    codigoConvite,
    cadeiras: cadeiras as string[],
    expiraEm,
  });

  if (!r.ok) {
    logger.info("mesa privada recusada", { motivo: r.motivo });
    if (r.motivo === "SEM_ASSINATURA_ATIVA") {
      throw new HttpsError("permission-denied", "a Mesa Privada e exclusiva de assinantes.");
    }
    throw new HttpsError("failed-precondition", "nao foi possivel registrar a mesa.");
  }

  logger.info("mesa privada registrada", { convite: redigirCodigo(codigoConvite) });
  return { codigoConvite, expiraEm };
});

/// Resolve um convite para uma sala.
///
/// Devolve SEMPRE a mesma recusa. Codigo invalido, expirado, revogado ou
/// excesso de tentativas produzem a mesma resposta — ver o cabecalho de
/// salas.ts sobre o oraculo.
///
/// E ela NAO admite ninguem: resolver o convite diz onde e a sala, e nada
/// mais. Sentar continua exigindo elegibilidade VIP propria, conferida em
/// `admitirEmMesaVip`.
export const resolverConviteDeMesaPrivada = onCall(opcoesCliente, async (req) => {
  recusarUidNoPayload(req.data);
  const uid = uidDe(req);
  const dados = (req.data ?? {}) as Record<string, unknown>;

  const r = await storePadrao().resolverConvite({ uid, codigoBruto: dados.codigoConvite });
  if (!r.ok) {
    logger.info("convite recusado", { motivo: r.motivoInterno });
    throw new HttpsError("not-found", "convite indisponivel.");
  }
  return { salaId: r.salaId };
});
