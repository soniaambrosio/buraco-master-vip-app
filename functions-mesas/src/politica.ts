// politica.ts — QUE CONFIGURACAO E VALIDA PARA CADA TIPO DE MESA.
//
// Modulo puro. Nao le banco, nao importa firebase-admin, nao decide admissao.
// Ele responde duas perguntas, e so duas:
//
//   1. quais CAMPOS de configuracao existem para este tipo;
//   2. quais VALORES cada campo aceita.
//
// ===========================================================================
// A FRASE QUE GOVERNA ESTE ARQUIVO
// ===========================================================================
//
//   A INTERFACE ESCONDER UM CAMPO NAO E PROTECAO.
//
// A tela de configuracao ja esconde a aposta na Mesa Publica e ja esconde o
// codigo fora da Privada. Isso resolve o jogador distraido e nao resolve mais
// nada: quem edita o JSON antes de enviar nunca viu a tela. Por isso a lista
// abaixo e a autoridade, e a tela e a conveniencia — nesta ordem, e nao na
// inversa.
//
// A consequencia pratica e a regra de rejeicao da secao 9.3 da OS: campo NAO
// PERMITIDO para o tipo e RECUSA, e nao "ignora e segue". Ignorar em silencio
// atende igual e esconde a tentativa; recusar deixa um motivo categorico no
// registro, com o autor identificado.
//
// ===========================================================================
// POR QUE 1.500 / 2.000 / 3.000, E POR QUE 1.000 E ERRO EXPLICITO
// ===========================================================================
//
// Houve uma proposta anterior de reduzir a lista a 1.000 e 2.000. Ela foi
// SUPERADA — a decisao vigente preserva o que ja esta implementado. O risco de
// uma decisao superada e ela voltar por engano, meses depois, quando alguem
// achar um documento antigo. Por isso `1000` nao e so "um valor fora da
// lista": ele tem motivo de recusa PROPRIO (`PONTOS_LEGADOS`), e ha teste que
// exige esse motivo. Se a lista mudar um dia, o teste obriga quem mudou a
// olhar para este paragrafo.

import { TIPO_MESA, TipoDeMesa } from "./tipos";

// ===========================================================================
// OS VALORES CANONICOS
// ===========================================================================

/// Pontos para vencer. Lista fechada e igual para Publica e VIP/Ranqueada —
/// a assinatura compra ACESSO a competicao, nunca uma regra diferente.
export const PONTOS_CANONICOS: readonly number[] = Object.freeze([1500, 2000, 3000]);

/// O valor da proposta superada. Nao e configuracao: e sentinela de regressao.
export const PONTOS_LEGADOS: readonly number[] = Object.freeze([1000]);

/// Segundos por jogada.
export const TEMPOS_CANONICOS: readonly number[] = Object.freeze([15, 30, 45]);

/// Modalidades que o motor implementa. `sbtl` e o alias historico de `stbl`, e
/// ele e aceito na ENTRADA e normalizado na saida — o motor do servidor ainda
/// escreve `sbtl` em alguns caminhos, e recusar o alias quebraria mesa que
/// funciona hoje sem tornar nada mais seguro.
export const MODALIDADES_CANONICAS: readonly string[] = Object.freeze([
  "aberto",
  "fechado",
  "stbl",
]);

/// Quantidade de jogadores sentados.
export const JOGADORES_CANONICOS: readonly number[] = Object.freeze([2, 4]);

/// Configuracao de chat.
export const CHATS_CANONICOS: readonly string[] = Object.freeze([
  "completo",
  "apenas_emotes",
  "desligado",
]);

// ===========================================================================
// OS CAMPOS
// ===========================================================================

/// Todo campo de configuracao que existe, nomeado uma vez so.
export const CAMPO = {
  MODALIDADE: "modalidade",
  JOGADORES: "jogadores",
  PONTOS: "pontos",
  TEMPO: "tempo",
  CHAT: "chat",
  APOSTA: "aposta",
  ESPECTADORES: "espectadores",
  CADEIRAS: "cadeiras",
} as const;

export type Campo = (typeof CAMPO)[keyof typeof CAMPO];

/// Os cinco campos que TODA mesa online tem.
const COMUNS: readonly Campo[] = Object.freeze([
  CAMPO.MODALIDADE,
  CAMPO.JOGADORES,
  CAMPO.PONTOS,
  CAMPO.TEMPO,
  CAMPO.CHAT,
]);

/// Os campos validos por tipo.
///
/// TREINO nao aparece com campos comuns por acidente: ele tem modalidade,
/// pontos e tempo como qualquer mesa, e NAO tem chat (nao ha com quem
/// conversar), nao tem aposta, nao tem espectador e nao tem cadeira para
/// controlar. Os tres robos nao sao configuraveis por esta politica.
const CAMPOS_POR_TIPO: Readonly<Record<TipoDeMesa, readonly Campo[]>> = Object.freeze({
  [TIPO_MESA.PUBLICA]: COMUNS,

  // Aposta e espectadores sao os recursos premium ja previstos. Eles nao
  // mudam regra de jogo — mudam o que a mesa oferece em volta dela.
  [TIPO_MESA.VIP_RANQUEADA]: Object.freeze([
    ...COMUNS,
    CAMPO.APOSTA,
    CAMPO.ESPECTADORES,
  ]),

  // A Privada acrescenta o controle de cadeiras, que so o proprietario
  // exerce. O CODIGO nao esta na lista de proposito: ele nao e configuracao,
  // e sim identidade cunhada pelo servidor. Ver salas.ts.
  [TIPO_MESA.PRIVADA]: Object.freeze([
    ...COMUNS,
    CAMPO.APOSTA,
    CAMPO.ESPECTADORES,
    CAMPO.CADEIRAS,
  ]),

  [TIPO_MESA.TREINO]: Object.freeze([
    CAMPO.MODALIDADE,
    CAMPO.PONTOS,
    CAMPO.TEMPO,
  ]),
});

/// Os campos validos para este tipo.
export function camposPermitidos(tipo: TipoDeMesa): readonly Campo[] {
  return CAMPOS_POR_TIPO[tipo];
}

/// Este campo e valido para este tipo?
export function campoPermitido(tipo: TipoDeMesa, campo: string): boolean {
  return CAMPOS_POR_TIPO[tipo].some((c) => c === campo);
}

// ===========================================================================
// AS PERGUNTAS DE PERMISSAO QUE A POLITICA RESPONDE
// ===========================================================================

/// Esta mesa pode cobrar entrada em fichas?
///
/// Publica NUNCA cobra — e a mesa gratuita, e essa e a razao de ela existir.
/// Treino NUNCA cobra nem paga. As duas restantes cobram conforme a economia
/// canonica, que esta OS nao redesenha.
export function permiteApostaDeEntrada(tipo: TipoDeMesa): boolean {
  return campoPermitido(tipo, CAMPO.APOSTA);
}

/// Esta mesa pode ter controle premium de espectadores?
export function permiteEspectadores(tipo: TipoDeMesa): boolean {
  return campoPermitido(tipo, CAMPO.ESPECTADORES);
}

/// Esta mesa tem codigo de acesso cunhado pelo servidor?
export function temCodigoDeSala(tipo: TipoDeMesa): boolean {
  return tipo === TIPO_MESA.PRIVADA;
}

/// Esta mesa tem proprietario com autoridade sobre as cadeiras?
export function temProprietarioDeCadeiras(tipo: TipoDeMesa): boolean {
  return campoPermitido(tipo, CAMPO.CADEIRAS);
}

/// Criar esta mesa exige assinatura VIP ativa?
///
/// So a Privada. A VIP/Ranqueada admite quem tem assinatura OU passe de
/// cortesia, e o passe da direito a ENTRAR — nao a abrir sala. A distincao e a
/// mesma que separa `exigeElegibilidadeVip` de `aceitaPasseDeCortesia` em
/// tipos.ts, e ela precisa existir nos dois lugares porque responde a dois
/// momentos diferentes: criar e sentar.
export function criacaoExigeAssinaturaAtiva(tipo: TipoDeMesa): boolean {
  return tipo === TIPO_MESA.PRIVADA;
}

// ===========================================================================
// A VALIDACAO
// ===========================================================================

/// Motivos categoricos de recusa. Sao para REGISTRO e TESTE.
///
/// Nenhum deles carrega valor enviado pelo cliente: o motivo diz O QUE estava
/// errado, nunca COM QUE valor. Ecoar o valor de volta no log e como um oraculo
/// se comporta, e a mesma disciplina que o servidor ja aplica a recusa de
/// admissao.
export const RECUSA_CONFIG = {
  TIPO_DESCONHECIDO: "TIPO_DESCONHECIDO",
  CAMPO_NAO_PERMITIDO: "CAMPO_NAO_PERMITIDO",
  CAMPO_AUSENTE: "CAMPO_AUSENTE",
  MODALIDADE_INVALIDA: "MODALIDADE_INVALIDA",
  JOGADORES_INVALIDO: "JOGADORES_INVALIDO",
  PONTOS_INVALIDO: "PONTOS_INVALIDO",
  PONTOS_LEGADOS: "PONTOS_LEGADOS",
  TEMPO_INVALIDO: "TEMPO_INVALIDO",
  CHAT_INVALIDO: "CHAT_INVALIDO",
  APOSTA_INVALIDA: "APOSTA_INVALIDA",
  ESPECTADORES_INVALIDO: "ESPECTADORES_INVALIDO",
  CADEIRAS_INVALIDO: "CADEIRAS_INVALIDO",
} as const;

export type RecusaConfig = (typeof RECUSA_CONFIG)[keyof typeof RECUSA_CONFIG];

export type ConfiguracaoNormalizada = {
  modalidade: string;
  jogadores: number;
  pontos: number;
  tempo: number;
  chat: string;
  aposta: number;
  espectadores: boolean;
  cadeiras: readonly string[];
};

export type ResultadoConfig =
  | { ok: true; configuracao: ConfiguracaoNormalizada }
  | { ok: false; campo: string | null; motivo: RecusaConfig };

/// Estados que uma cadeira da Mesa Privada pode ter.
export const ESTADO_CADEIRA: readonly string[] = Object.freeze([
  "liberada",
  "reservada",
  "travada",
]);

const APOSTAS_CANONICAS: readonly number[] = Object.freeze([0, 500, 1000, 5000]);

function alias(modalidade: string): string {
  // O motor antigo escreve `sbtl`; o dominio Dart canonizou `stbl`. Aceitar o
  // alias na entrada e normalizar na saida evita que a diferenca vire duas
  // modalidades diferentes no banco.
  return modalidade === "sbtl" ? "stbl" : modalidade;
}

/// Valida e NORMALIZA a configuracao pedida para um tipo de mesa.
///
/// Duas passagens, nesta ordem, e a ordem nao e estetica:
///
///   1. TODO campo presente tem que ser permitido para o tipo. Uma Publica com
///      `aposta` e recusada ANTES de alguem olhar o valor da aposta — porque o
///      problema nao e o valor, e o campo existir ali.
///   2. So entao cada campo permitido tem o valor conferido.
///
/// Inverter a ordem deixaria passar uma Publica com `aposta: 0`, que parece
/// inofensiva e e o primeiro degrau para `aposta: 500`.
export function validarConfiguracao(
  tipo: TipoDeMesa,
  bruta: Record<string, unknown>,
): ResultadoConfig {
  const permitidos = CAMPOS_POR_TIPO[tipo];
  if (!permitidos) return { ok: false, campo: null, motivo: RECUSA_CONFIG.TIPO_DESCONHECIDO };

  // Passagem 1 — campos estranhos ao tipo.
  for (const chave of Object.keys(bruta)) {
    if (!permitidos.some((c) => c === chave)) {
      return { ok: false, campo: chave, motivo: RECUSA_CONFIG.CAMPO_NAO_PERMITIDO };
    }
  }

  const tem = (campo: Campo) => permitidos.some((c) => c === campo);

  // Passagem 2 — valores.
  let modalidade = "stbl";
  if (tem(CAMPO.MODALIDADE)) {
    const v = bruta[CAMPO.MODALIDADE];
    if (typeof v !== "string") {
      return { ok: false, campo: CAMPO.MODALIDADE, motivo: RECUSA_CONFIG.MODALIDADE_INVALIDA };
    }
    modalidade = alias(v.trim().toLowerCase());
    if (!MODALIDADES_CANONICAS.includes(modalidade)) {
      return { ok: false, campo: CAMPO.MODALIDADE, motivo: RECUSA_CONFIG.MODALIDADE_INVALIDA };
    }
  }

  // Treino nao configura quantidade: e sempre um humano e tres robos.
  let jogadores = tipo === TIPO_MESA.TREINO ? 4 : 4;
  if (tem(CAMPO.JOGADORES)) {
    const v = bruta[CAMPO.JOGADORES];
    if (typeof v !== "number" || !JOGADORES_CANONICOS.includes(v)) {
      return { ok: false, campo: CAMPO.JOGADORES, motivo: RECUSA_CONFIG.JOGADORES_INVALIDO };
    }
    jogadores = v;
  }

  let pontos = 1500;
  if (tem(CAMPO.PONTOS)) {
    const v = bruta[CAMPO.PONTOS];
    if (typeof v !== "number") {
      return { ok: false, campo: CAMPO.PONTOS, motivo: RECUSA_CONFIG.PONTOS_INVALIDO };
    }
    if (PONTOS_LEGADOS.includes(v)) {
      // Motivo PROPRIO. Ver o cabecalho: a proposta de 1.000/2.000 foi
      // superada, e uma volta silenciosa dela seria retrabalho invisivel.
      return { ok: false, campo: CAMPO.PONTOS, motivo: RECUSA_CONFIG.PONTOS_LEGADOS };
    }
    if (!PONTOS_CANONICOS.includes(v)) {
      return { ok: false, campo: CAMPO.PONTOS, motivo: RECUSA_CONFIG.PONTOS_INVALIDO };
    }
    pontos = v;
  }

  let tempo = 45;
  if (tem(CAMPO.TEMPO)) {
    const v = bruta[CAMPO.TEMPO];
    if (typeof v !== "number" || !TEMPOS_CANONICOS.includes(v)) {
      return { ok: false, campo: CAMPO.TEMPO, motivo: RECUSA_CONFIG.TEMPO_INVALIDO };
    }
    tempo = v;
  }

  let chat = tem(CAMPO.CHAT) ? "completo" : "desligado";
  if (tem(CAMPO.CHAT) && bruta[CAMPO.CHAT] !== undefined) {
    const v = bruta[CAMPO.CHAT];
    if (typeof v !== "string" || !CHATS_CANONICOS.includes(v)) {
      return { ok: false, campo: CAMPO.CHAT, motivo: RECUSA_CONFIG.CHAT_INVALIDO };
    }
    chat = v;
  }

  // A aposta so existe onde o campo existe. Onde ele nao existe o valor
  // normalizado e ZERO, e nao "o que o cliente mandou" — e o que garante que
  // uma Publica nunca chegue a economia com valor de entrada.
  let aposta = 0;
  if (tem(CAMPO.APOSTA) && bruta[CAMPO.APOSTA] !== undefined) {
    const v = bruta[CAMPO.APOSTA];
    if (typeof v !== "number" || !APOSTAS_CANONICAS.includes(v)) {
      return { ok: false, campo: CAMPO.APOSTA, motivo: RECUSA_CONFIG.APOSTA_INVALIDA };
    }
    aposta = v;
  }

  let espectadores = false;
  if (tem(CAMPO.ESPECTADORES) && bruta[CAMPO.ESPECTADORES] !== undefined) {
    const v = bruta[CAMPO.ESPECTADORES];
    if (typeof v !== "boolean") {
      return { ok: false, campo: CAMPO.ESPECTADORES, motivo: RECUSA_CONFIG.ESPECTADORES_INVALIDO };
    }
    espectadores = v;
  }

  let cadeiras: readonly string[] = Object.freeze([]);
  if (tem(CAMPO.CADEIRAS) && bruta[CAMPO.CADEIRAS] !== undefined) {
    const v = bruta[CAMPO.CADEIRAS];
    if (!Array.isArray(v) || v.length !== jogadores) {
      return { ok: false, campo: CAMPO.CADEIRAS, motivo: RECUSA_CONFIG.CADEIRAS_INVALIDO };
    }
    for (const e of v) {
      if (typeof e !== "string" || !ESTADO_CADEIRA.includes(e)) {
        return { ok: false, campo: CAMPO.CADEIRAS, motivo: RECUSA_CONFIG.CADEIRAS_INVALIDO };
      }
    }
    cadeiras = Object.freeze([...(v as string[])]);
  }

  return {
    ok: true,
    configuracao: { modalidade, jogadores, pontos, tempo, chat, aposta, espectadores, cadeiras },
  };
}
