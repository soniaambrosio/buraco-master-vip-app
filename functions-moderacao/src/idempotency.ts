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
import { HttpsError } from "firebase-functions/v2/https";

export const COLECAO_TAREFAS = "moderationTasks";

export function db(): Firestore {
  return getFirestore();
}

export interface RegistroTarefa {
  chave: string;
  tarefa: string;
  ator: string;
  alvo: string | null;
  /// Digest dos campos do pedido que NAO entram na chave (tipo de sancao,
  /// categoria da denuncia). Ver `conferirConformidade`.
  impressao: string;
  executadaEm: string;
  resultado: string;
}

/// Metadados que descrevem o PEDIDO — o que se compara numa repeticao.
export type PedidoTarefa = Omit<
  RegistroTarefa,
  "chave" | "executadaEm" | "resultado"
>;

export const ACAO_RESERVA = {
  /// Chave livre: reservar e rodar o corpo.
  EXECUTAR: "executar",
  /// Mesma chave, MESMO pedido: convergir e responder sucesso repetido.
  REPETICAO: "repeticao",
  /// Mesma chave, pedido DIFERENTE: a intencao foi reaproveitada.
  CONFLITO: "conflito",
} as const;

export type AcaoReserva = (typeof ACAO_RESERVA)[keyof typeof ACAO_RESERVA];

/// O registro reservado descreve exatamente o pedido que chegou?
///
/// PORQUE ISTO EXISTE, e porque nao existia antes: o cabecalho deste arquivo
/// dizia "mesmo desenho de functions/src/idempotency.ts", e la a chave CARREGA o
/// payload (`tournamentId|editionId|alvo`), o que torna a simples existencia do
/// documento prova de que o pedido e o mesmo. Aqui as chaves sao
/// `${responsavel}|${sancaoIntentId}` e `${denuncianteUid}|${reportIntentId}`:
/// elas nao carregam o alvo nem o tipo. Sem esta conferencia, um intent id
/// reaproveitado contra OUTRA pessoa encontrava a chave reservada e a Function
/// respondia sucesso sem ter feito nada — a sancao ou a denuncia pedida sumia em
/// silencio.
///
/// E a mesma disciplina que `functions-billing/idempotencia.js` ja aplica em
/// `conferirTitularidade`, onde a chave (hash do purchaseToken) tambem nao
/// carrega o payload.
///
/// So compara campos do PEDIDO. `executadaEm` e `resultado` pertencem ao
/// registro, e compara-los faria toda repeticao legitima virar conflito.
export function conferirConformidade(
  registro: Partial<RegistroTarefa>,
  pedido: PedidoTarefa
): { ok: boolean; motivo?: string } {
  if (registro.tarefa !== pedido.tarefa) {
    return { ok: false, motivo: "chave reservada por outra tarefa" };
  }
  if (registro.ator !== pedido.ator) {
    return { ok: false, motivo: "chave reservada por outro ator" };
  }
  if ((registro.alvo ?? null) !== (pedido.alvo ?? null)) {
    return { ok: false, motivo: "chave reservada para outro alvo" };
  }
  // COMPATIBILIDADE: documentos gravados antes desta conferencia nao tem
  // `impressao`. Tratar a ausencia como divergencia transformaria todo retry
  // legitimo de um registro antigo em conflito.
  if (registro.impressao !== undefined && registro.impressao !== pedido.impressao) {
    return { ok: false, motivo: "chave reservada com outra impressao do pedido" };
  }
  return { ok: true };
}

/// Decide o que fazer diante do documento de reserva (ou da ausencia dele).
///
/// Pura de proposito: recebe o documento como DADO, sem Firestore, sem relogio e
/// sem rede, para que `test/idempotencia.test.js` prove os tres desfechos.
export function decidirSobreReserva(
  existente: Partial<RegistroTarefa> | null | undefined,
  pedido: PedidoTarefa
): { acao: AcaoReserva; motivo?: string } {
  if (!existente) return { acao: ACAO_RESERVA.EXECUTAR };

  const c = conferirConformidade(existente, pedido);
  if (!c.ok) return { acao: ACAO_RESERVA.CONFLITO, motivo: c.motivo };

  return { acao: ACAO_RESERVA.REPETICAO };
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
  metadados: PedidoTarefa,
  corpo: (tx: Transaction) => Promise<T>
): Promise<{ executou: boolean; valor?: T }> {
  const ref = db().collection(COLECAO_TAREFAS).doc(chave);

  return db().runTransaction(async (tx) => {
    const existente = await tx.get(ref);
    const decisao = decidirSobreReserva(
      existente.exists ? (existente.data() as Partial<RegistroTarefa>) : null,
      metadados
    );

    if (decisao.acao === ACAO_RESERVA.CONFLITO) {
      // NAO e sucesso silencioso e NAO e repeticao: o chamador reaproveitou uma
      // intencao ja gasta para descrever outra operacao. Responder sucesso aqui
      // faria a operacao pedida desaparecer com uma confirmacao na mao do
      // chamador — que era exatamente o defeito.
      logger.warn("intencao de moderacao reaproveitada", {
        chave,
        motivo: decisao.motivo,
        tarefa: metadados.tarefa,
      });
      throw new HttpsError("failed-precondition", "intencaoReutilizada", {
        recusa: "intencaoReutilizada",
        motivo: decisao.motivo,
      });
    }

    if (decisao.acao === ACAO_RESERVA.REPETICAO) {
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
