// domain.ts — a ponte com o dominio Dart social.
//
// O bundle e gerado por `npm run build:domain` (dart compile js sobre
// app/lib/social/js_bridge.dart) e AUTO-REGISTRA `globalThis.bmvSocial` ao ser
// carregado. Por isso o require e do modulo inteiro, sem destructuring: nao ha
// export, ha efeito colateral.
//
// A falha e no CARREGAMENTO, e nao no primeiro uso. Deliberado: um bundle
// ausente tem que derrubar o deploy, e nao virar um `undefined is not a
// function` no meio do primeiro pedido de amizade de um jogador real.

require("../lib/domain_bundle.js");

type PonteJs = (entrada: string) => string;

interface PonteSocial {
  idPublicoDeBytes: PonteJs;
  normalizarIdPublico: PonteJs;
  recusaDeConsultaPublica: PonteJs;
  avaliarAtualizacaoDeApresentacao: PonteJs;
  conferirDocumentoPublico: PonteJs;
  perfilPublicoInicial: PonteJs;
  avaliarContato: PonteJs;
  chaveDoPar: PonteJs;
  avaliarSolicitacao: PonteJs;
  avaliarAceite: PonteJs;
  avaliarRecusa: PonteJs;
  avaliarCancelamento: PonteJs;
  avaliarRemocao: PonteJs;
  vistaDaRelacao: PonteJs;
  avaliarConsultaDeBusca: PonteJs;
  chaveDeBusca: PonteJs;
  projetarResultadosDeBusca: PonteJs;
  paginarAmigos: PonteJs;
  constantes: PonteJs;
}

const ponte = (globalThis as unknown as { bmvSocial?: PonteSocial }).bmvSocial;

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
    throw new Error(`dominio social: ${saida.erro}`);
  }
  return saida;
}

// -------------------------------------------------------------------- tipos

export type EstadoAmizade = "nenhuma" | "pendente" | "amigos";

export type AcaoAmizade =
  | "criarSolicitacao"
  | "aceitarInversa"
  | "aceitar"
  | "apagar"
  | "nenhuma";

export interface VereditoAmizade {
  aceita: boolean;
  recusa: string | null;
  acao: AcaoAmizade;
  /// O desfecho pedido JA VALE e nada mudou. Quem chama responde SUCESSO com
  /// marca de repeticao — nunca erro. Ver o cabecalho de amizade.dart.
  repeticao: boolean;
}

export interface PerfilPublicoDoc {
  publicId: string;
  apelido: string;
  apelidoOrdenacao: string;
  avatarRef: string | null;
  estado: string;
  criadoEm: string;
  atualizadoEm: string;
  esquema: number;
}

export interface ConstantesSociais {
  limiteAmigos: number;
  limiteSolicitacoesEnviadas: number;
  limiteSolicitacoesRecebidas: number | null;
  comprimentoIdPublico: number;
  prefixoIdPublico: string;
  tamanhoTotalIdPublico: number;
  apelidoMinimo: number;
  apelidoMaximo: number;
  paginaPadrao: number;
  paginaMaxima: number;
  /// Limites da BUSCA por apelido. Vem do dominio pelo mesmo motivo que os
  /// outros: um teto que exista em dois lugares e um teto que vai divergir.
  consultaMinima: number;
  consultaMaxima: number;
  resultadosPadrao: number;
  resultadosMaximo: number;
  /// Sempre `false` na v1. Declarado — em vez de simplesmente ausente — para que
  /// a decisao antienumeracao de §9 apareca no contrato e num teste, e nao so na
  /// falta de um campo `cursor` na resposta.
  buscaComCursor: boolean;
  esquema: number;
  camposPublicos: string[];
  errosConhecidos: string[];
}

export type ModoBusca = "exato" | "prefixo";

/// Uma consulta ja validada pelo dominio, com a faixa pronta.
export interface ConsultaDeBusca {
  aceita: boolean;
  recusa: string | null;
  modo: ModoBusca;
  chaveInicio: string;
  chaveFim: string;
  limite: number;
}

/// Um candidato ANTES da projecao. Carrega uid; nao sai desta camada.
export interface CandidatoDeBusca {
  publicId: string;
  uidAlvo: string;
  estado: EstadoAmizade;
  solicitanteUid: string | null;
  euBloqueeiOAlvo: boolean;
  alvoMeBloqueou: boolean;
}

/// O resultado sanitizado: identidade publica, relacao e acoes. Sem uid.
export interface ResultadoDeBusca {
  publicId: string;
  relacao: string;
  acoes: string[];
}

export interface EntradaSocial {
  publicId: string;
  apelido: string;
  avatarRef: string | null;
  desde: string | null;
}

// ----------------------------------------------------------------- chamadas

export const dominio = {
  idPublicoDeBytes: (bytes: number[]): { publicId: string } =>
    chamar(ponte.idPublicoDeBytes, { bytes }),

  normalizarIdPublico: (publicId: unknown): { publicId: string | null } =>
    chamar(ponte.normalizarIdPublico, { publicId }),

  recusaDeConsultaPublica: (e: {
    publicId: unknown;
    existe: boolean;
    estado: string | null;
  }): { recusa: string | null } => chamar(ponte.recusaDeConsultaPublica, e),

  avaliarAtualizacaoDeApresentacao: (e: {
    apelido?: string | null;
    avatarRef?: unknown;
    removerAvatar?: boolean;
    agora: string;
    catalogoAvatares?: string[];
  }): {
    aceita: boolean;
    recusa: string | null;
    campos: Record<string, unknown> | null;
  } => chamar(ponte.avaliarAtualizacaoDeApresentacao, e),

  conferirDocumentoPublico: (
    documento: Record<string, unknown>
  ): { ok: boolean; ofensivas: string[]; privadas: string[] } =>
    chamar(ponte.conferirDocumentoPublico, { documento }),

  perfilPublicoInicial: (e: {
    publicId: string;
    apelido: string;
    agora: string;
  }): PerfilPublicoDoc => chamar(ponte.perfilPublicoInicial, e),

  /// O veredito de contato da MODERACAO, compilado dentro deste bundle.
  ///
  /// Nao e uma reimplementacao: `js_bridge.dart` importa
  /// `moderacao/relacao_social.dart` e chama a MESMA funcao que
  /// `functions-moderacao` chama. §18: consumir, nunca duplicar.
  avaliarContato: (e: {
    origemBloqueouDestino: boolean;
    destinoBloqueouOrigem: boolean;
    origemComChatSilenciado?: boolean;
    origemComRestricaoSocial?: boolean;
  }): { permitido: boolean; motivo: string | null } =>
    chamar(ponte.avaliarContato, e),

  chaveDoPar: (uidA: string, uidB: string): {
    pairKey: string;
    membros: string[];
  } => chamar(ponte.chaveDoPar, { uidA, uidB }),

  avaliarSolicitacao: (e: {
    solicitanteUid: string;
    destinatarioUid: string;
    estadoAtual: EstadoAmizade;
    solicitantePendenteUid: string | null;
    contatoPermitido: boolean;
    amigosDoSolicitante: number;
    amigosDoDestinatario: number;
    pendentesEnviadasDoSolicitante: number;
  }): VereditoAmizade => chamar(ponte.avaliarSolicitacao, e),

  avaliarAceite: (e: {
    uidQueAceita: string;
    estadoAtual: EstadoAmizade;
    destinatarioPendenteUid: string | null;
    contatoPermitido: boolean;
    amigosDeQuemAceita: number;
    amigosDoOutro: number;
  }): VereditoAmizade => chamar(ponte.avaliarAceite, e),

  avaliarRecusa: (e: {
    uidQueRecusa: string;
    estadoAtual: EstadoAmizade;
    destinatarioPendenteUid: string | null;
  }): VereditoAmizade => chamar(ponte.avaliarRecusa, e),

  avaliarCancelamento: (e: {
    uidQueCancela: string;
    estadoAtual: EstadoAmizade;
    solicitantePendenteUid: string | null;
  }): VereditoAmizade => chamar(ponte.avaliarCancelamento, e),

  avaliarRemocao: (e: {
    uidQueRemove: string;
    estadoAtual: EstadoAmizade;
    ehMembro: boolean;
  }): VereditoAmizade => chamar(ponte.avaliarRemocao, e),

  vistaDaRelacao: (e: {
    uidObservador: string;
    uidAlvo: string;
    estado: EstadoAmizade;
    solicitanteUid: string | null;
    euBloqueeiOAlvo: boolean;
    contatoPermitido: boolean;
  }): { relacao: string; acoes: string[] } => chamar(ponte.vistaDaRelacao, e),

  /// Valida o termo e monta a faixa de chaves (OS de Busca §5, §6, §9).
  avaliarConsultaDeBusca: (e: {
    termo: unknown;
    modo?: unknown;
    limite?: unknown;
  }): ConsultaDeBusca => chamar(ponte.avaliarConsultaDeBusca, e),

  /// A chave de comparacao de um texto. E a MESMA que produz `apelidoOrdenacao`.
  chaveDeBusca: (termo: unknown): { chave: string | null } =>
    chamar(ponte.chaveDeBusca, { termo }),

  /// Filtra por bloqueio e rotula relacao/acoes, numa travessia so (§8, §10).
  projetarResultadosDeBusca: (e: {
    uidObservador: string;
    candidatos: CandidatoDeBusca[];
    observadorComChatSilenciado?: boolean;
    observadorComRestricaoSocial?: boolean;
  }): { itens: ResultadoDeBusca[] } =>
    chamar(ponte.projetarResultadosDeBusca, e),

  paginarAmigos: (e: {
    itens: EntradaSocial[];
    cursor: string | null;
    limite: unknown;
  }): {
    itens: EntradaSocial[];
    proximoCursor: string | null;
    total: number | null;
  } => chamar(ponte.paginarAmigos, e),

  constantes: (): ConstantesSociais => chamar(ponte.constantes, {}),
};

/// Os limites vem do DOMINIO, nao de uma copia em TypeScript.
///
/// §25 pede limites "centralizados/configuraveis" e "nao espalhar numeros
/// magicos". Dois lugares com o numero 200 ja sao um lugar a mais: o dia em que
/// um subisse e o outro nao, o teto viraria uma sugestao.
export const LIMITES = dominio.constantes();

/// Instante atual em ISO-8601 com fuso.
///
/// Uma funcao unica para que TODA a operacao use o MESMO instante quando ele e
/// capturado uma vez e passado adiante — mesma disciplina de `agoraUtc` na
/// moderacao.
export function agoraUtc(): string {
  return new Date().toISOString();
}
