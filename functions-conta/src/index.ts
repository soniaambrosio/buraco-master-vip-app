// index.ts — QUEM ATENDE. Autenticacao, forma do payload, traducao de recusa.
//
// A MESMA REPARTICAO DE PAPEIS DOS OUTROS CODEBASES:
//
//   QUEM DECIDE  -> inventario.ts (o destino de cada dado) e plano.ts (a ordem
//                   e as recusas).
//   QUEM EXECUTA -> executor.ts. Firestore, Authentication, paginacao.
//   QUEM ATENDE  -> este arquivo.
//
// ===========================================================================
// A FRASE QUE GOVERNA ESTE ARQUIVO
// ===========================================================================
//
//   O CLIENTE NAO ESCOLHE DE QUEM E A CONTA.
//
// Nao ha, em nenhuma das duas rotas abaixo, um caminho pelo qual um UID venha
// do payload. O UID vem de `req.auth.uid`, que o `onCall` extrai de um ID token
// cuja assinatura ja foi verificada antes de este codigo rodar — e a mesma
// disciplina que functions-social/src/index.ts aplica a todo o dominio social.
//
// E vamos ALEM de ignorar: se o payload TRAZ um `uid`, a chamada e RECUSADA em
// vez de atendida com o UID certo. Ignorar em silencio funcionaria igual e
// esconderia a tentativa; recusar deixa um `permission-denied` no log com o
// autor identificado. Numa operacao que apaga conta, a tentativa e informacao.
//
// ===========================================================================
// OS TRES PORTOES, E O QUE CADA UM RESOLVE
// ===========================================================================
//
//   1. AUTENTICACAO ...... "ha alguem logado?" O UID sai daqui.
//   2. REAUTENTICACAO .... "faz pouco tempo que essa pessoa provou que e ela?"
//      Conferida pelo claim `auth_time`, que e assinado e nao se falsifica. Ver
//      reautenticacao.ts.
//   3. CONFIRMACAO ....... "essa pessoa entendeu o que vai acontecer?" A palavra
//      digitada, conferida no servidor porque o que so a tela confere, um
//      aplicativo modificado nao confere.
//
// Um toque acidental passa pelo portao 1 e pelo 2 (a sessao E recente) e para no
// 3. Um aparelho desbloqueado e esquecido para no 2. Um aplicativo modificado
// para no 3. Os tres cobrem coisas diferentes, e por isso sao tres.

import { initializeApp } from "firebase-admin/app";
import { logger } from "firebase-functions";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";

import { CLASSE, INVENTARIO } from "./inventario";
import { ETAPAS, RECUSA, decidirElegibilidade } from "./plano";
import { descreverEtapa, executar, lerInscricoes, lerPublicId } from "./executor";
import {
  JANELA_REAUTENTICACAO_SEGUNDOS,
  PALAVRA_DE_CONFIRMACAO,
  confirmacaoConfere,
  conferirReautenticacao,
} from "./reautenticacao";

initializeApp();

/// App Check EXIGIDO em producao, dispensado sob o emulador.
///
/// `FUNCTIONS_EMULATOR` e posto pelo proprio emulador e nunca vale "true" numa
/// instancia implantada — nao ha caminho pelo qual um cliente real desligue esta
/// verificacao, porque ela nao le nada que venha do pedido. Mesma decisao, pelo
/// mesmo motivo, que functions-social e functions-moderacao.
const exigirAppCheck = process.env.FUNCTIONS_EMULATOR !== "true";

/// A REGIAO PRECISA CASAR com a que o cliente chama
/// (app/lib/conta/fonte_exclusao_firebase.dart). Chamar a regiao errada devolve
/// `not-found`, que num fluxo de exclusao e facil de confundir com "conta ja
/// removida" — e confundir os dois seria desastroso.
const opcoesCliente = {
  enforceAppCheck: exigirAppCheck,
  region: "southamerica-east1",
};

// ------------------------------------------------------------------ portoes

function exigirAutenticacao(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "E preciso estar autenticado.");
  }
  return uid;
}

/// Recusa qualquer tentativa de nomear a conta alvo.
///
/// Cobre `uid`, `userId` e `publicId`: os tres nomes pelos quais alguem tentaria
/// dizer "apague ESTA conta". Nenhum deles tem uso legitimo nestas rotas.
function recusarAlvoExterno(req: CallableRequest, uid: string): void {
  const dados = (req.data ?? {}) as Record<string, unknown>;
  const proibidos = ["uid", "userId", "publicId", "alvo", "alvoUid"];
  const presentes = proibidos.filter((c) => dados[c] !== undefined);

  if (presentes.length > 0) {
    logger.warn("tentativa de exclusao com alvo no payload", {
      autor: uid,
      campos: presentes,
    });
    throw new HttpsError(
      "permission-denied",
      "A exclusao age sobre a identidade autenticada e nao aceita alvo no pedido.",
      { recusa: "alvoNoPayloadRecusado", campos: presentes }
    );
  }
}

function exigirReautenticacaoRecente(req: CallableRequest): void {
  const veredito = conferirReautenticacao(
    req.auth?.token?.auth_time,
    Math.floor(Date.now() / 1000)
  );
  if (veredito.recente) return;

  throw new HttpsError("failed-precondition", RECUSA.REAUTENTICACAO, {
    recusa: RECUSA.REAUTENTICACAO,
    motivo: veredito.motivo,
    idadeSegundos: veredito.idadeSegundos,
    janelaSegundos: JANELA_REAUTENTICACAO_SEGUNDOS,
  });
}

// ============================================================ PREVIA (AVISO)

/// O que acontece se eu excluir minha conta?
///
/// SO LE. E a rota que alimenta a tela de aviso, e ela existe para que o texto
/// da tela NAO seja uma lista escrita a mao no Flutter. Uma lista escrita a mao
/// envelhece: acrescenta-se uma colecao ao backend, a matriz e atualizada, e o
/// aviso continua prometendo o que prometia antes. Aqui o aviso e DERIVADO da
/// mesma matriz que o executor obedece, entao os dois nao tem como divergir.
///
/// NAO exige reautenticacao: ler o que vai acontecer nao e um ato destrutivo, e
/// pedir a senha para EXIBIR o aviso empurraria a pessoa a decidir antes de
/// saber. A reautenticacao fica no ato.
export const resumirExclusaoDeConta = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  recusarAlvoExterno(req, uid);

  const [publicId, inscricoes] = await Promise.all([
    lerPublicId(uid),
    lerInscricoes(uid),
  ]);
  const elegibilidade = decidirElegibilidade(inscricoes);

  const porClasse = (classe: string) =>
    INVENTARIO.filter((i) => i.classe === classe).map((i) => ({
      caminho: i.caminho,
      dominio: i.dominio,
      porque: i.porque,
    }));

  return {
    temIdentidadePublica: publicId !== null,
    podeExcluir: elegibilidade.pode,
    recusa: elegibilidade.recusa,
    bloqueios: elegibilidade.bloqueios,
    palavraDeConfirmacao: PALAVRA_DE_CONFIRMACAO,
    janelaReautenticacaoSegundos: JANELA_REAUTENTICACAO_SEGUNDOS,
    // As tres listas que a tela precisa mostrar, com a justificativa junto. O
    // jogador tem direito de saber nao so o que fica, mas POR QUE fica.
    apagado: porClasse(CLASSE.APAGAR),
    anonimizado: porClasse(CLASSE.ANONIMIZAR),
    desvinculado: porClasse(CLASSE.DESVINCULAR),
    retido: porClasse(CLASSE.RETER),
    etapas: ETAPAS.map(descreverEtapa),
  };
});

// ================================================================== EXECUCAO

/// Exclui a conta de quem chama. Autoritativa, idempotente e retomavel.
///
/// A RESPOSTA CHEGA AO CLIENTE ANTES DE A SESSAO MORRER, e essa ordem e
/// deliberada: a conta do Authentication e apagada na ultima etapa, entao o
/// token que autorizou esta chamada continua valido durante ela. E o que permite
/// ao aplicativo receber `{concluida: true}` e so entao chamar `signOut()`. Se a
/// conta morresse no comeco, a chamada terminaria com erro de rede e o jogador
/// veria uma falha depois de a exclusao ter dado certo.
export const excluirMinhaConta = onCall(opcoesCliente, async (req) => {
  const uid = exigirAutenticacao(req);
  recusarAlvoExterno(req, uid);
  exigirReautenticacaoRecente(req);

  const { confirmacao } = (req.data ?? {}) as { confirmacao?: unknown };
  if (!confirmacaoConfere(confirmacao)) {
    throw new HttpsError("failed-precondition", RECUSA.CONFIRMACAO, {
      recusa: RECUSA.CONFIRMACAO,
      esperado: PALAVRA_DE_CONFIRMACAO,
    });
  }

  // A ELEGIBILIDADE E RECONFERIDA AQUI, e nao herdada da previa. Entre ver o
  // aviso e confirmar, a pessoa pode ter se inscrito num torneio noutra aba —
  // e uma previa aprovada nao e uma autorizacao guardada.
  const elegibilidade = decidirElegibilidade(await lerInscricoes(uid));
  if (!elegibilidade.pode) {
    throw new HttpsError("failed-precondition", elegibilidade.recusa as string, {
      recusa: elegibilidade.recusa,
      bloqueios: elegibilidade.bloqueios,
    });
  }

  logger.info("exclusao de conta autorizada", { uid });
  const resultado = await executar(uid);

  if (resultado.estado === "parcial") {
    // NAO E SUCESSO E NAO E ERRO SIMPLES. A conta ja esta trancada e parte dos
    // dados ja saiu — dizer "falhou" faria o jogador supor que nada aconteceu.
    // `details.estado` diz a verdade, e `retomavel` diz o que fazer: chamar de
    // novo, que a execucao continua de onde parou.
    throw new HttpsError("internal", "exclusaoParcial", {
      recusa: "exclusaoParcial",
      estado: resultado.estado,
      etapasConcluidas: resultado.etapasConcluidas,
      falhas: resultado.falhas,
      retomavel: true,
    });
  }

  return {
    concluida: resultado.estado === "concluida",
    repeticao: resultado.repeticao,
    etapasConcluidas: resultado.etapasConcluidas,
    // O resumo NAO volta inteiro para o cliente: saldo e VIP no encerramento sao
    // dado de suporte, gravados no diario. O que o aplicativo precisa saber e se
    // acabou, para entao encerrar a sessao.
  };
});
