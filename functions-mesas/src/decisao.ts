// decisao.ts — QUEM PODE SENTAR, E POR QUE.
//
// Modulo puro. Recebe FATOS ja lidos e devolve um VEREDITO. Nao le banco, nao
// escreve, nao chama rede e nao le o relogio. E a mesma reparticao de papeis
// que os outros codebases deste projeto ja usam:
//
//   QUEM DECIDE  -> este arquivo (e tipos.ts, politica.ts, passe.ts, salas.ts)
//   QUEM EXECUTA -> firestore.ts (transacao, leitura, escrita)
//   QUEM ATENDE  -> index.ts (autenticacao, forma do payload, resposta)
//
// A razao de ser puro e a mesma de `idempotencia.js` no Billing: e aqui que
// mora o risco de liberar entrada indevida, e risco desse tipo so aparece em
// producao, sob concorrencia. Sendo puro, da para exaurir a matriz com
// `node --test`, sem emulador.
//
// ===========================================================================
// AS DUAS PERGUNTAS QUE NAO SAO A MESMA
// ===========================================================================
//
//   "esta mesa exige VIP?" .......... vipRanqueada E privada
//   "o passe de cortesia serve?" .... SO vipRanqueada
//
// A Mesa Privada e o caso em que as duas divergem, e ela e a razao de o
// veredito nao poder ser um booleano. A OS diz, com todas as letras, que a
// cortesia quinzenal NAO autoriza Mesa Privada — e que possuir o codigo nao
// concede direito nenhum. Quem senta numa Privada precisa de ASSINATURA ATIVA
// PROPRIA, conferida cadeira por cadeira, no instante da admissao.
//
// Uma assinatura nao libera familiares nem convidados. E por isso que a
// elegibilidade e conferida por OCUPANTE e nao por SALA: uma checagem por sala
// (feita uma vez, na criacao) responderia "o dono e VIP" e deixaria os outros
// tres entrarem de carona para sempre.
//
// ===========================================================================
// FALHA FECHADA EM TODA ARESTA
// ===========================================================================
//
// Tipo desconhecido, categoria desconhecida, sala ausente, sala encerrada,
// codigo que aponta para outra sala, assento fora da mesa: tudo recusa. Nao
// existe ramo que resolva duvida para "pode entrar", e nao existe modo de
// desenvolvimento que ligue sozinho.
//
// A recusa que sai no fio e SEMPRE a mesma, redigida. O `codigoRecusa` daqui
// e para REGISTRO — ele diz ao operador o que aconteceu sem dizer ao
// adversario o que ele acertou.

import { TIPO_MESA, TipoDeMesa, aceitaPasseDeCortesia, exigeElegibilidadeVip } from "./tipos";
import { DocumentoPasse, estadoDoPasse } from "./passe";

// ===========================================================================
// A FONTE DE ELEGIBILIDADE
// ===========================================================================

/// Por que este jogador pode entrar.
///
/// A OS exige que a resposta autoritativa carregue a FONTE, e nao so o
/// veredito. Sem a fonte nao da para responder depois "ele e assinante,
/// convidado ou portador de cortesia?" — que e uma das perguntas do estado
/// final esperado.
export const FONTE = {
  /// A mesa nao exige elegibilidade. Publica.
  NAO_EXIGIDA: "naoExigida",
  /// `playerEntitlements/{uid}` diz que ha assinatura vigente agora.
  ASSINATURA: "assinaturaVipAtiva",
  /// `passesVip/{uid}` tinha passe utilizavel, e ele foi consumido nesta
  /// admissao.
  CORTESIA: "passeCortesiaValido",
  /// O jogador ja ocupava este assento nesta sala. O direito foi exercido na
  /// admissao anterior e nao se cobra de novo.
  RECONEXAO: "reconexaoAoProprioAssento",
} as const;

export type Fonte = (typeof FONTE)[keyof typeof FONTE];

// ===========================================================================
// OS MOTIVOS DE RECUSA
// ===========================================================================

export const RECUSA = {
  TIPO_DESCONHECIDO: "TIPO_DESCONHECIDO",
  /// Treino nunca e admitido por esta autoridade — ele nem deveria perguntar.
  TREINO_NAO_ADMITE: "TREINO_NAO_ADMITE",
  SEM_ASSINATURA_NEM_CORTESIA: "SEM_ASSINATURA_NEM_CORTESIA",
  /// Privada: o jogador tem cortesia, e cortesia nao abre sala privada.
  CORTESIA_NAO_SERVE_PRIVADA: "CORTESIA_NAO_SERVE_PRIVADA",
  SALA_INEXISTENTE: "SALA_INEXISTENTE",
  SALA_ENCERRADA: "SALA_ENCERRADA",
  CODIGO_NAO_CORRESPONDE: "CODIGO_NAO_CORRESPONDE",
  ASSENTO_INVALIDO: "ASSENTO_INVALIDO",
  ASSENTO_INDISPONIVEL: "ASSENTO_INDISPONIVEL",
} as const;

export type Recusa = (typeof RECUSA)[keyof typeof RECUSA];

// ===========================================================================
// OS FATOS
// ===========================================================================

/// `salasPrivadas/{salaId}`.
export type SalaPrivada = {
  salaId: string;
  /// O codigo da sala no servidor de mesas. E o elo entre as duas autoridades.
  codigoDaSala: string;
  proprietarioUid: string;
  criadaEm: string;
  encerradaEm: string | null;
  /// Estado de cada cadeira, na ordem dos assentos. So o dono muda isto.
  cadeiras: readonly string[];
};

/// A admissao que este jogador ja tem nesta sala, se tiver.
export type AdmissaoAnterior = {
  admissaoId: string;
  assento: number;
  fonteElegibilidade: Fonte;
};

export type FatosDaAdmissao = {
  tipo: TipoDeMesa | null;
  uidAutenticado: string;
  codigoDaSala: string;
  assento: number;
  agora: string;
  /// A autoridade do Billing ja respondeu: ha assinatura vigente AGORA?
  assinaturaAtiva: boolean;
  /// O passe corrente, ja materializado pela janela. `null` se nao ha.
  passe: DocumentoPasse | null;
  /// So para Mesa Privada. `null` nos outros tipos.
  sala: SalaPrivada | null;
  /// Preenchido quando o gate do servidor classificou a tentativa como
  /// reconexao ao proprio assento.
  admissaoAnterior: AdmissaoAnterior | null;
};

export type Veredito =
  | {
      ok: true;
      fonteElegibilidade: Fonte;
      /// A transacao deve marcar o passe como usado?
      consumirPasse: boolean;
      /// Reaproveita a admissao anterior em vez de cunhar uma nova.
      admissaoReaproveitada: string | null;
    }
  | { ok: false; codigoRecusa: Recusa };

// ===========================================================================
// O VEREDITO
// ===========================================================================

/// Decide a admissao ao assento.
///
/// A ordem das checagens NAO e estetica, e vale nomear por que ela e esta:
///
///   1. TIPO primeiro. Sem tipo nao ha politica, e sem politica todas as
///      perguntas seguintes ficam sem criterio.
///   2. RECONEXAO segundo, e ANTES de olhar elegibilidade. Quem ja esta
///      sentado ja pagou a entrada; reavaliar assinatura aqui expulsaria da
///      partida em andamento quem tivesse a assinatura vencida no meio dela.
///      Ver a secao 6.3 da OS: consumo confirmado nao se desfaz, e o inverso
///      tambem vale — direito exercido nao se cobra de novo.
///   3. SALA depois, e antes de elegibilidade. Um codigo que nao corresponde a
///      sala e uma tentativa de trocar de sala DEPOIS de validar outro codigo,
///      e isso e recusa dura — nao adianta ser assinante.
///   4. ELEGIBILIDADE por ultimo, ja com o tipo e a sala confirmados.
export function decidirAdmissao(f: FatosDaAdmissao): Veredito {
  // ---- 1. tipo ----------------------------------------------------------
  if (f.tipo === null) return { ok: false, codigoRecusa: RECUSA.TIPO_DESCONHECIDO };
  if (f.tipo === TIPO_MESA.TREINO) {
    // Treino roda local, contra tres robos, e nao ocupa assento em servidor
    // nenhum. Uma admissao pedida para treino significa que alguem esta
    // tentando fazer uma partida local passar por partida online — e o
    // resultado dela nunca pode ser aceito como competitivo.
    return { ok: false, codigoRecusa: RECUSA.TREINO_NAO_ADMITE };
  }

  if (!Number.isInteger(f.assento) || f.assento < 0 || f.assento > 3) {
    return { ok: false, codigoRecusa: RECUSA.ASSENTO_INVALIDO };
  }

  // ---- 2. reconexao ao proprio assento ----------------------------------
  if (f.admissaoAnterior !== null) {
    if (f.admissaoAnterior.assento !== f.assento) {
      // A admissao anterior era de OUTRA cadeira. Isto nao e reconexao: e
      // mudanca de assento com credencial de reconexao, e ela nao passa.
      return { ok: false, codigoRecusa: RECUSA.ASSENTO_INDISPONIVEL };
    }
    return {
      ok: true,
      fonteElegibilidade: FONTE.RECONEXAO,
      consumirPasse: false,
      admissaoReaproveitada: f.admissaoAnterior.admissaoId,
    };
  }

  // ---- 3. a sala, quando ela existe -------------------------------------
  if (f.tipo === TIPO_MESA.PRIVADA) {
    if (f.sala === null) return { ok: false, codigoRecusa: RECUSA.SALA_INEXISTENTE };
    if (f.sala.encerradaEm !== null) return { ok: false, codigoRecusa: RECUSA.SALA_ENCERRADA };
    if (f.sala.codigoDaSala !== f.codigoDaSala) {
      // O vinculo codigo -> sala foi resolvido em outro momento, e agora a
      // admissao chega apontando para uma sala diferente. Recusa dura.
      return { ok: false, codigoRecusa: RECUSA.CODIGO_NAO_CORRESPONDE };
    }
    const cadeira = f.sala.cadeiras[f.assento];
    if (cadeira !== undefined && cadeira !== "liberada") {
      // Cadeira travada ou reservada. So o dono muda isso, e ele muda por
      // outro caminho — nunca por uma mensagem de entrada.
      return { ok: false, codigoRecusa: RECUSA.ASSENTO_INDISPONIVEL };
    }
  }

  // ---- 4. elegibilidade --------------------------------------------------
  if (!exigeElegibilidadeVip(f.tipo)) {
    // Mesa Publica. Autenticado basta, e nada e consumido. A gratuidade da
    // mesa publica e a razao de ela existir.
    return {
      ok: true,
      fonteElegibilidade: FONTE.NAO_EXIGIDA,
      consumirPasse: false,
      admissaoReaproveitada: null,
    };
  }

  if (f.assinaturaAtiva) {
    // Assinatura ativa NAO consome cortesia, mesmo que haja passe utilizavel.
    // Gastar o passe de quem ja tem assinatura seria queimar um beneficio sem
    // entregar nada em troca.
    return {
      ok: true,
      fonteElegibilidade: FONTE.ASSINATURA,
      consumirPasse: false,
      admissaoReaproveitada: null,
    };
  }

  const passeServe = aceitaPasseDeCortesia(f.tipo);
  const passeUtilizavel =
    f.passe !== null && estadoDoPasse(f.passe, f.agora).utilizavel;

  if (passeUtilizavel && passeServe) {
    return {
      ok: true,
      fonteElegibilidade: FONTE.CORTESIA,
      consumirPasse: true,
      admissaoReaproveitada: null,
    };
  }

  if (passeUtilizavel && !passeServe) {
    // O jogador TEM cortesia e ela nao vale aqui. Motivo proprio, porque o
    // caso e diferente de "nao tem nada": ele diz ao operador que a regra
    // funcionou, e nao que faltou beneficio.
    return { ok: false, codigoRecusa: RECUSA.CORTESIA_NAO_SERVE_PRIVADA };
  }

  return { ok: false, codigoRecusa: RECUSA.SEM_ASSINATURA_NEM_CORTESIA };
}
