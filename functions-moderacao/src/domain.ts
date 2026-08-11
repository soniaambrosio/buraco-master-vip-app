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
