// conquistas.ts — a concessao de conquistas permanentes do jogador.
//
// MODULO SEPARADO, e a separacao tem uma razao mecanica alem da organizacao:
// `src/index.ts` faz `export * from "./rastreabilidade"`, e o Firebase trata
// CADA export do entrypoint como definicao de funcao a implantar. As duas
// funcoes abaixo precisam ser exportadas para o teste de idempotencia
// (`functions/test/`) as executar contra o emulador; se morassem em
// rastreabilidade.ts, entrariam na superficie de deploy como se fossem
// gatilhos — e um deploy tentaria publicar `planejarPrimeiraBatidaReal` como
// se fosse uma Cloud Function. Aqui nao entram: nada reexporta este arquivo.
//
// QUEM DECIDE quem merece a conquista e o dominio Dart
// (`app/lib/conquistas/primeira_batida_real.dart`), chamado atraves da ponte.
// Este arquivo executa: le, decide ONDE gravar, e grava.

import { getFirestore, FieldValue, Transaction } from "firebase-admin/firestore";

import { dominio } from "./domain";

const db = () => getFirestore();

/// O que fazer com a conquista neste encerramento. Decidido na fase de LEITURA.
interface PlanoDeConquista {
  resultado: "concedida" | "ja_existente" | "inelegivel";
  motivo: string | null;
  uid: string | null;
  /// Preenchido so quando `resultado === "concedida"`. Aplicado depois, na fase
  /// de escrita — o Firestore exige TODA leitura antes de QUALQUER escrita
  /// dentro de uma transacao, e misturar as duas fases faz a transacao falhar
  /// em tempo de execucao, nao de compilacao.
  gravar: { ref: FirebaseFirestore.DocumentReference; dados: Record<string, unknown> } | null;
}

/// Decide se este encerramento concede a `primeira_batida_real`, e onde gravar.
///
/// QUEM DECIDE quem merece e o dominio Dart
/// (`app/lib/conquistas/primeira_batida_real.dart`), chamado por
/// `dominio.avaliarPrimeiraBatidaReal`. Esta funcao nao tem regra de
/// elegibilidade nenhuma: ela le o veredito e executa.
///
/// IDEMPOTENCIA, e ela e o ponto inteiro desta funcao:
///
///   playerAchievements/{uid}/items/primeira_batida_real
///
/// O id do documento e CONSTANTE por jogador. Nao ha chave derivada de partida,
/// de tentativa ou de relogio — e deliberado: a conquista e "a PRIMEIRA vez", e
/// um id que variasse por partida permitiria uma segunda concessao na segunda
/// vitoria, que e exatamente o que nao pode acontecer. Com id fixo, a segunda
/// vitoria colide com o documento da primeira e nao cria nada.
///
/// Roda DENTRO da transacao do encerramento (§21 da rastreabilidade): nao existe
/// caminho que feche a partida sem avaliar a conquista, nem que conceda a
/// conquista sem a partida ter fechado. Por isso ela so LE e devolve um plano —
/// o Firestore exige toda leitura antes de qualquer escrita, e a escrita fica
/// com [aplicarPlanoDeConquista].
///
/// EXPORTADA para o teste de idempotencia (`functions/test/`), que a executa
/// contra o emulador do Firestore dentro de transacoes de verdade. Sem isso, a
/// unica forma de provar concorrencia seria reimplementar a transacao no teste —
/// e o teste passaria a provar a copia, nao este codigo.
export async function planejarPrimeiraBatidaReal(
  tx: Transaction,
  registro: Record<string, unknown>,
  matchId: string
): Promise<PlanoDeConquista> {
  let veredito;
  try {
    veredito = dominio.avaliarPrimeiraBatidaReal({ registro });
  } catch (e) {
    // Envelope que o dominio recusa ler. NAO derruba o encerramento: a partida
    // fechou de verdade, e perder o registro dela por causa de uma conquista
    // seria trocar o dado importante pelo acessorio. Fica no log como recusa.
    return { resultado: "inelegivel", motivo: "envelope_ilegivel", uid: null, gravar: null };
  }

  if (!veredito.elegivel || !veredito.userId) {
    return { resultado: "inelegivel", motivo: veredito.motivo, uid: null, gravar: null };
  }

  const ref = db()
    .collection("playerAchievements")
    .doc(veredito.userId)
    .collection("items")
    .doc(veredito.conquistaId);

  const atual = await tx.get(ref);
  if (atual.exists) {
    // Ja tinha. Sucesso idempotente, e nao erro: e o caminho do jogador que
    // vence a segunda partida, e o do redelivery. Note que NAO ha reescrita —
    // `obtidaEm` continua sendo o da primeira vez.
    return { resultado: "ja_existente", motivo: null, uid: veredito.userId, gravar: null };
  }

  return {
    resultado: "concedida",
    motivo: null,
    uid: veredito.userId,
    gravar: {
      ref,
      dados: {
        id: veredito.conquistaId,
        // Carimbo do SERVIDOR. Nem o cliente nem a autoridade que chama
        // escolhem a data.
        obtidaEm: FieldValue.serverTimestamp(),
        partidaId: matchId,
        origem: veredito.origem,
        versaoContrato: veredito.versaoContrato,
        // O assento e prova, nao decoracao: com ele, uma auditoria futura
        // reabre a partida e confere a concessao sem depender deste log.
        assento: veredito.assento,
      },
    },
  };
}

/// Aplica o plano — a unica escrita desta camada.
///
/// `create`, e nao `set`: se duas transacoes concorrentes passarem pela leitura
/// ao mesmo tempo, a segunda falha no commit em vez de sobrescrever a primeira —
/// e o Firestore reexecuta a transacao, que na segunda passada ve o documento e
/// cai em `ja_existente`. Com `set`, a segunda venceria e reescreveria
/// `obtidaEm`, trocando a data do marco pela data do reprocessamento.
export function aplicarPlanoDeConquista(tx: Transaction, plano: PlanoDeConquista): void {
  if (plano.gravar) tx.create(plano.gravar.ref, plano.gravar.dados);
}
