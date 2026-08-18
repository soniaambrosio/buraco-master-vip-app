// domain.ts — a ponte com o dominio Dart de moderacao.
//
// O bundle e gerado por `npm run build:domain` (dart compile js sobre
// app/lib/moderacao/js_bridge.dart) e AUTO-REGISTRA `globalThis.bmvModeracao` ao
// ser carregado. Por isso o require e do modulo inteiro, sem destructuring: nao
// ha export, ha efeito colateral.
//
// A falha e no CARREGAMENTO, e nao no primeiro uso. Deliberado: um bundle
// ausente tem que derrubar o deploy, e nao virar um `undefined is not a
// function` no meio da primeira denuncia de um jogador real.

require("../lib/domain_bundle.js");

type PonteJs = (entrada: string) => string;

interface PonteModeracao {
  avaliarDenuncia: PonteJs;
  statusPublico: PonteJs;
  avaliarBloqueio: PonteJs;
  avaliarMute: PonteJs;
  avaliarContato: PonteJs;
  avaliarSancao: PonteJs;
  consolidarSancoes: PonteJs;
  avaliarEnvioChat: PonteJs;
  politicaDeSuperficies: PonteJs;
}

const ponte = (globalThis as unknown as { bmvModeracao?: PonteModeracao })
  .bmvModeracao;

if (!ponte) {
  throw new Error(
    "domain_bundle.js nao carregou. Rode `npm run build:domain` antes de `npm run build`."
  );
}

/// Toda travessia e string-in/string-out, com UMA forma de serializacao.
function chamar<T>(fn: PonteJs, entrada: unknown): T {
  const bruto = fn(JSON.stringify(entrada));
  const saida = JSON.parse(bruto) as T & { erro?: string };
  if (saida.erro) {
    throw new Error(`dominio de moderacao: ${saida.erro}`);
  }
  return saida;
}

// ------------------------------------------------------------------- tipos

export type TipoDenuncia = "perfil" | "mensagem" | "partida";

export interface Referencias {
  matchId?: string | null;
  roomId?: string | null;
  messageId?: string | null;
}

export interface VereditoDenuncia {
  aceita: boolean;
  recusa: string | null;
  falhas: string[];
  /// So vem quando aceita: o ID do documento em `reports`.
  chave?: string;
  esquema?: number;
}

export interface VereditoRelacao {
  aceita: boolean;
  recusa: string | null;
  falhas: string[];
}

export interface VereditoContato {
  permitido: boolean;
  motivo: string | null;
}

export interface VereditoSancao {
  aceita: boolean;
  recusa: string | null;
  falhas: string[];
}

export interface EstadoModeracao {
  userId: string;
  chatSilenciadoAte: string | null;
  socialRestritoAte: string | null;
  suspensoAte: string | null;
  suspensaoPermanente: boolean;
  esquema: number;
}

// ------------------------------------------------------------------ chat (§4)

/// Um participante do canal, como o documento autoritativo o descreve.
export interface ParticipanteDoCanal {
  uid: string;
  /// `jogador_sentado` | `espectador` | `fora_do_canal`.
  papel: string;
}

/// O CONTEXTO ESTAVEL da §10. Nada aqui e conexao, socket ou tentativa.
export interface CanalDeChat {
  canalId: string;
  superficie: string;
  aberto: boolean;
  participantes: ParticipanteDoCanal[];
}

/// Bloqueio entre o autor e UM candidato, nas duas direcoes (§7).
export interface ParDeContato {
  uid: string;
  autorBloqueou: boolean;
  bloqueouOAutor: boolean;
}

export interface VereditoEnvioChat {
  aceita: boolean;
  recusa: string | null;
  /// Vocabulario canonico de `MotivoContatoRecusado`, quando a recusa for de
  /// contato. Nao e um segundo enum: e o mesmo, carregado.
  motivoContato: string | null;
  camposProibidos: string[];
  /// So quando aceita.
  messageId?: string;
  impressao?: string;
  conteudo?: string;
  destinatarios?: string[];
  esquema: number;
}

// ------------------------------------------------------------------ chamadas

export const dominio = {
  avaliarDenuncia: (e: {
    denuncianteUid: string;
    denunciadoUid: string;
    tipo: string;
    categoria: string;
    reportIntentId: string;
    comentario?: string | null;
    referencias?: Referencias;
    jaNaJanela?: number;
  }): VereditoDenuncia => chamar(ponte.avaliarDenuncia, e),

  statusPublico: (status: string): { publico: string } =>
    chamar(ponte.statusPublico, { status }),

  avaliarBloqueio: (e: {
    bloqueadorUid: string;
    bloqueadoUid: string;
    jaBloqueados?: number;
  }): VereditoRelacao => chamar(ponte.avaliarBloqueio, e),

  avaliarMute: (e: { donoUid: string; alvoUid: string }): VereditoRelacao =>
    chamar(ponte.avaliarMute, e),

  avaliarContato: (e: {
    origemBloqueouDestino: boolean;
    destinoBloqueouOrigem: boolean;
    origemComChatSilenciado?: boolean;
    origemComRestricaoSocial?: boolean;
  }): VereditoContato => chamar(ponte.avaliarContato, e),

  avaliarSancao: (e: {
    userId: string;
    responsavel: string;
    tipo: string;
    motivo: string;
    inicio: string;
    fim?: string | null;
  }): VereditoSancao => chamar(ponte.avaliarSancao, e),

  consolidarSancoes: (e: {
    userId: string;
    agora: string;
    sancoes: unknown[];
  }): EstadoModeracao => chamar(ponte.consolidarSancoes, e),

  /// A PORTA UNICA do chat. Ver app/lib/chat/porta.dart.
  ///
  /// `camposDoPayload` sao as CHAVES que o cliente mandou — nao os valores. A
  /// presenca de um campo proibido recusa o pedido, e o valor nao muda a decisao,
  /// entao serializar dado arbitrario do cliente para dentro do dominio seria
  /// superficie sem proposito.
  avaliarEnvioChat: (e: {
    autorUid: string;
    intentId: string;
    conteudo: unknown;
    superficie: unknown;
    canal: CanalDeChat | null;
    sancao: {
      chatSilenciado?: boolean;
      restricaoSocial?: boolean;
      suspenso?: boolean;
    };
    contatos: ParDeContato[];
    camposDoPayload: string[];
    autorPublicId?: string | null;
  }): VereditoEnvioChat => chamar(ponte.avaliarEnvioChat, e),

  /// A classificacao da §11, lida do dominio em vez de recopiada aqui.
  politicaDeSuperficies: (): {
    superficies: {
      superficie: string;
      politica: string;
      aceitaTextoLivre: boolean;
    }[];
    limiteMensagem: number;
    esquema: number;
  } => chamar(ponte.politicaDeSuperficies, {}),
};

/// Instante atual em ISO-8601 com fuso.
///
/// O dominio RECUSA data sem fuso — ver `exigirUtc` em validacao.dart. Uma
/// funcao unica aqui garante que toda a operacao use O MESMO instante quando ele
/// e capturado uma vez e passado adiante (secao 17 da OS: sancao que expira no
/// meio da operacao).
export function agoraUtc(): string {
  return new Date().toISOString();
}
