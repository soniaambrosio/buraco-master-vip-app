// idempotency.ts — barreira de idempotencia das tarefas e gatilhos
// (OS 02 secoes 19 e 27).
//
// A EXIGENCIA: "reprocessar uma tarefa automatica nao pode provocar duplicidade".
// Cloud Functions tem entrega AO MENOS UMA VEZ: um gatilho pode disparar duas
// vezes para o mesmo evento, e o Cloud Scheduler pode reenviar um tick. Sem esta
// barreira, um retry premiaria o campeao duas vezes.
//
// COMO: cada tarefa tem uma chave determinista vinda do dominio
// (automation.dart / ChaveTarefa). Esta chave vira o ID DO DOCUMENTO em
// `tournamentTasks`. Reservar a chave e um `create` dentro de transacao — e o
// Firestore garante que apenas UM dos concorrentes cria o documento.
//
// Nao se usa `get` seguido de `set` fora de transacao: entre a leitura e a
// escrita cabe outra execucao, e as duas se achariam a primeira.

import { getFirestore, Firestore, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

export const COLECAO_TAREFAS = "tournamentTasks";

export function db(): Firestore {
  return getFirestore();
}

export interface RegistroTarefa {
  chave: string;
  tarefa: string;
  tournamentId: string;
  editionId: string;
  alvo: string | null;
  executadaEm: string;
  resultado: string;
}

/// Executa `corpo` no maximo UMA vez para a `chave`, sob transacao.
///
/// Devolve `{executou: false}` quando a chave ja estava reservada — reprocessamento
/// nao e falha, e quem chamou deve responder sucesso.
///
/// A reserva e feita ANTES do corpo, dentro da mesma transacao: se o corpo
/// escrever no Firestore pela transacao, ou tudo comita ou nada comita. Um corpo
/// que falhe desfaz a reserva junto e a tarefa pode ser tentada de novo — que e o
/// comportamento desejado para falha transitoria.
export async function executarUmaVez<T>(
  chave: string,
  metadados: Omit<RegistroTarefa, "chave" | "executadaEm" | "resultado">,
  corpo: (tx: Transaction) => Promise<T>
): Promise<{ executou: boolean; valor?: T }> {
  const ref = db().collection(COLECAO_TAREFAS).doc(chave);

  return db().runTransaction(async (tx) => {
    const existente = await tx.get(ref);
    if (existente.exists) {
      logger.info("tarefa ja executada, ignorando", { chave });
      return { executou: false };
    }

    const valor = await corpo(tx);

    tx.create(ref, {
      chave,
      ...metadados,
      executadaEm: new Date().toISOString(),
      resultado: "ok",
    });

    return { executou: true, valor };
  });
}

/// Chaves de tarefa ja executadas para uma edicao.
///
/// Alimenta `planejarTarefas` no dominio, que remove do plano o que ja rodou.
/// A consulta e por prefixo do ID usando o intervalo de documentId — barato e sem
/// indice extra, porque a chave sempre termina com `|editionId` ou
/// `|editionId|alvo`.
export async function chavesExecutadas(
  tournamentId: string,
  editionId: string
): Promise<string[]> {
  const snapshot = await db()
    .collection(COLECAO_TAREFAS)
    .where("tournamentId", "==", tournamentId)
    .where("editionId", "==", editionId)
    .get();
  return snapshot.docs.map((d) => d.id);
}
