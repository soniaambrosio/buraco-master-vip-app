// idempotency.ts — barreira de idempotencia da moderacao (OS secoes 7 e 17).
//
// Mesmo desenho de `functions/src/idempotency.ts`, com coleçao propria. A copia
// e deliberada e segue o que o repositorio ja faz: cada codebase de Functions
// carrega a sua barreira (torneios tem a dela, billing tem `idempotencia.js`).
// Compartilhar o modulo entre codebases exigiria um pacote comum publicado ou um
// symlink no deploy — e as tres codebases sao unidades de implantacao separadas
// justamente para que uma nao derrube a outra.
//
// A EXIGENCIA aqui e diferente da de torneios: nao e so retry de gatilho. E toque
// duplo no botao de denunciar, reconexao no meio do envio, e a conta automatizada
// que repete o mesmo pedido mil vezes. As tres convergem se a chave for
// determinista e a reserva for um `create` dentro de transacao.

import { getFirestore, Firestore, Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

export const COLECAO_TAREFAS = "moderationTasks";

export function db(): Firestore {
  return getFirestore();
}

export interface RegistroTarefa {
  chave: string;
  tarefa: string;
  ator: string;
  alvo: string | null;
  executadaEm: string;
  resultado: string;
}

/// Executa `corpo` no maximo UMA vez para a `chave`, sob transacao.
///
/// Devolve `{executou: false}` quando a chave ja estava reservada. Reprocessar
/// NAO e falha: quem chama deve responder sucesso com uma marca de repeticao
/// (`jaRegistrada: true`), no mesmo padrao que as Functions de torneio ja usam.
/// Devolver erro aqui faria o cliente tentar de novo, e a segunda tentativa
/// tambem "falharia" — um laco que so termina quando o jogador desiste.
export async function executarUmaVez<T>(
  chave: string,
  metadados: Omit<RegistroTarefa, "chave" | "executadaEm" | "resultado">,
  corpo: (tx: Transaction) => Promise<T>
): Promise<{ executou: boolean; valor?: T }> {
  const ref = db().collection(COLECAO_TAREFAS).doc(chave);

  return db().runTransaction(async (tx) => {
    const existente = await tx.get(ref);
    if (existente.exists) {
      logger.info("tarefa de moderacao ja executada, ignorando", { chave });
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
