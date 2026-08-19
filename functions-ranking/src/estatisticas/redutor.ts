// redutor.ts — DE UM FATO DE PARTIDA PARA DELTAS POR JOGADOR.
//
// Logica de dominio pura. Sem I/O, sem Firestore, sem rede, sem relogio, sem
// aleatoriedade, sem Cloud Function. Entra um envelope, sai uma decisao de
// elegibilidade e uma lista de deltas — e nada acontece no mundo.
//
// Este arquivo NAO E O ESCRITOR. O escritor e outra OS. O que existe aqui e a
// regra que o escritor tera de obedecer, escrita de forma conferivel antes de
// qualquer gravacao existir — para que a arbitragem venha antes da atividade, e
// nao depois.

import {
  chaveDeLancamento,
  chaveDoFato,
  FatoPartidaOficialV1,
  MODALIDADES_ELEGIVEIS,
  analisarFatoPartidaOficial,
} from "./contrato";
import { DeltaDoJogador } from "./agregado";

/// Por que uma partida VALIDA nao produz estatistica.
///
/// Recusa de envelope e outra coisa e mora em `analisarFatoPartidaOficial`. A
/// separacao importa na operacao: envelope invalido e defeito do produtor e
/// merece alarme; partida inelegivel e o dia a dia — a maior parte das mesas do
/// aplicativo e privada ou de treino, e nenhuma delas e um problema.
export type MotivoDeInelegibilidade =
  | "sem_encerramento_autoritativo"
  | "estado_nao_concluido"
  | "modalidade_nao_elegivel"
  | "participacao_de_robo";

/// O resultado da reducao de um fato.
export interface ReducaoDoFato {
  /// `matchId|eventoId`. Presente inclusive quando inelegivel: e por ela que o
  /// futuro escritor reconhece a entrega repetida do mesmo evento e nao a
  /// processa de novo.
  readonly chaveDoFato: string;
  readonly elegivel: boolean;
  readonly motivo: MotivoDeInelegibilidade | null;
  /// Vazia quando inelegivel. Quatro deltas quando elegivel, um por assento.
  readonly deltas: ReadonlyArray<DeltaDoJogador>;
}

/// Classifica a elegibilidade, na ordem em que as perguntas ficam mais caras.
///
/// A ordem e deliberada e o primeiro motivo encontrado vence: sem encerramento
/// autoritativo nada mais importa (nem sabemos se a partida acabou), e so faz
/// sentido perguntar pela modalidade de uma partida que de fato terminou.
export function classificarElegibilidade(
  fato: FatoPartidaOficialV1
): MotivoDeInelegibilidade | null {
  if (!fato.encerramentoAutoritativo) return "sem_encerramento_autoritativo";

  // `concluida` e o unico estado que conta. `cancelada` nunca contou em lugar
  // nenhum. `abandonada` fica de fora NESTA VERSAO por uma razao concreta: o
  // registro oficial marca que houve abandono e nao diz QUEM abandonou
  // (functions-ranking/src/projecao.ts:65-72). Atribuir a derrota sem
  // responsavel identificavel seria inventar; atribuir a todos, punir inocente.
  if (fato.estadoTerminal !== "concluida") return "estado_nao_concluido";

  if (!MODALIDADES_ELEGIVEIS.includes(fato.modalidade)) {
    return "modalidade_nao_elegivel";
  }

  // Robo em mesa que produz estatistica publica e a mesma porta que o dominio ja
  // fechou para ranking: uma mesa contra bots que valesse pontuacao seria "a
  // forma mais barata de farmar pontuacao que existe"
  // (app/lib/rastreabilidade/identidade_partida.dart:85-88). Substituicao
  // definitiva por robo cai aqui pelo mesmo motivo — metade da partida deixou de
  // ser disputada por quem sera creditado.
  const temRobo = fato.participantes.some(
    (p) => p.classe === "robo" || p.substituidoPorBot
  );
  if (temRobo) return "participacao_de_robo";

  return null;
}

/// Produz os deltas de um fato ja analisado.
///
/// Cada jogador elegivel recebe EXATAMENTE UMA partida. Vitoria e derrota sao da
/// DUPLA — os dois integrantes do lado vencedor recebem vitoria, os dois do
/// outro lado recebem derrota. No empate ninguem recebe vitoria e ninguem recebe
/// derrota, e os quatro recebem uma partida e um empate: empate e um terceiro
/// numero, e nao meia vitoria de ninguem.
///
/// Canastra e creditada aos DOIS integrantes da dupla que a fez, inteira, e nao
/// rateada. A alternativa seria escolher qual parceiro "fez" a canastra, e essa
/// informacao nao existe em lugar nenhum do sistema. O efeito colateral esta
/// registrado e e aceito: a soma global de canastras por jogador e o DOBRO da
/// soma por dupla, porque o numero exibido responde "quantas canastras a minha
/// dupla fez com voce na mesa", e nao "quantas voce fez sozinho".
export function reduzirFatoPartidaOficial(fato: FatoPartidaOficialV1): ReducaoDoFato {
  const chave = chaveDoFato(fato);
  const motivo = classificarElegibilidade(fato);
  if (motivo !== null) {
    return { chaveDoFato: chave, elegivel: false, motivo, deltas: [] };
  }

  const deltas: DeltaDoJogador[] = fato.participantes.map((p) => {
    const venceu = !fato.empate && fato.ladoVencedor === p.equipe;
    const perdeu = !fato.empate && fato.ladoVencedor !== p.equipe;
    const daDupla = fato.equipes[p.equipe];
    return {
      publicPlayerId: p.publicPlayerId,
      chaveDeLancamento: chaveDeLancamento(fato.matchId, p.publicPlayerId),
      partidas: 1,
      vitorias: venceu ? 1 : 0,
      empates: fato.empate ? 1 : 0,
      derrotas: perdeu ? 1 : 0,
      canastrasLimpas: daDupla.canastrasLimpas,
      canastrasSujas: daDupla.canastrasSujas,
      // Zero, e o zero e a regra. Nao ha politica de XP aprovada; a formula viva
      // no servidor Node nao se torna oficial por heranca. Ver `xpTotal` em
      // agregado.ts.
      xpTotal: 0,
    };
  });

  return { chaveDoFato: chave, elegivel: true, motivo: null, deltas };
}

/// O caminho completo, do bruto ao delta.
///
/// Devolve os erros de envelope separados da reducao, porque as duas respostas
/// pedem tratamentos diferentes de quem chamar.
export type ReducaoDeEnvelope =
  | { readonly ok: false; readonly erros: ReadonlyArray<string> }
  | { readonly ok: true; readonly reducao: ReducaoDoFato };

export function reduzirEnvelope(bruto: unknown): ReducaoDeEnvelope {
  const analise = analisarFatoPartidaOficial(bruto);
  if (!analise.ok) return { ok: false, erros: analise.erros };
  return { ok: true, reducao: reduzirFatoPartidaOficial(analise.fato) };
}
