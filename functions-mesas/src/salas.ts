// salas.ts — O CODIGO DA MESA PRIVADA, como DOMINIO PURO.
//
// Modulo puro: nao le banco, nao importa firebase-admin, nao sorteia nada por
// conta propria. A aleatoriedade entra por parametro (`bytes`), porque uma
// funcao que sorteia por dentro nao tem como ser conferida — e o que se quer
// conferir aqui e justamente a qualidade do sorteio.
//
// ===========================================================================
// O QUE ESTE ARQUIVO CORRIGE
// ===========================================================================
//
// O servidor de mesas cunha codigo assim, hoje:
//
//     "BURACO-" + Math.floor(1000 + Math.random() * 9000)
//
// Sao NOVE MIL codigos possiveis, sorteados por um gerador nao criptografico.
// Um script percorre o espaco inteiro em segundos, e a cada acerto entra numa
// sala privada de outra pessoa. Numa mesa que exige VIP de cada ocupante isso
// nem chega a ser a pior parte: a pior parte e que o codigo, sendo adivinhavel,
// vira um canal de descoberta de quem esta jogando com quem.
//
// A correcao tem tres partes, e as tres estao aqui:
//
//   ENTROPIA ......... 8 simbolos de um alfabeto de 25 = ~37 bits, contra os
//                      ~13 de hoje. Nao e chave de criptografia, e nao precisa
//                      ser: o codigo tambem e protegido por LIMITE DE
//                      TENTATIVAS, e 37 bits atras de um limitador de dez
//                      palpites por dez minutos e inatingivel por forca bruta.
//   NAO ARMAZENAR .... o banco guarda o SHA-256 do codigo, nunca o codigo. Um
//                      vazamento de leitura do banco nao vira uma lista de
//                      convites validos.
//   NAO ENUMERAR ..... o documento de resolucao tem a IMPRESSAO como id. Nao
//                      existe consulta por campo, entao nao existe varredura —
//                      e a mesma armadilha que `publicProfiles` ja custou uma
//                      correcao neste projeto, quando um `list` deixou a
//                      colecao varrivel.
//
// ===========================================================================
// O CODIGO NAO E BENEFICIO
// ===========================================================================
//
// Vale repetir aqui, onde o codigo e cunhado, porque e aqui que a tentacao
// aparece: o codigo LOCALIZA a sala. Ele nao concede assinatura, nao concede
// entitlement e nao concede o direito de ocupar uma cadeira. Quem senta numa
// Mesa Privada precisa de elegibilidade VIP PROPRIA, conferida individualmente
// no instante da admissao. Uma assinatura nao libera familiares nem
// convidados, e nenhum campo deste arquivo abre excecao a isso.

import { createHash } from "node:crypto";

// ===========================================================================
// O ALFABETO
// ===========================================================================

/// 32 simbolos, escolhidos para serem DITADOS EM VOZ ALTA sem ambiguidade.
///
/// Fora da lista, de proposito: `0` e `O`, `1` e `I` e `L`, `2` e `Z`, `5` e
/// `S`, `8` e `B`. Um codigo que se le errado ao telefone vira uma tentativa
/// falhada, e tentativa falhada consome o limitador de quem nao fez nada de
/// errado.
export const ALFABETO = "ACDEFGHJKMNPQRTUVWXY34679";

/// Quantos simbolos tem um codigo.
///
/// 25 simbolos elevado a 8 da ~1.5e11 (~37 bits). Com o limitador de
/// tentativas abaixo, sao mais de mil anos de forca bruta por identidade.
export const TAMANHO_CODIGO = 8;

/// Quantos bytes de aleatoriedade `cunharCodigo` exige.
///
/// Um byte por simbolo, e o byte e reduzido por REJEICAO (nao por modulo). Vem
/// dai a exigencia de mais bytes do que simbolos: alguns sao descartados.
export const BYTES_NECESSARIOS = 32;

const PREFIXO = "BMV";

// ===========================================================================
// A CUNHAGEM
// ===========================================================================

/// Cunha um codigo a partir de bytes CRIPTOGRAFICAMENTE aleatorios.
///
/// A reducao de byte para simbolo e por REJEICAO, e nao por `% 25`. O modulo
/// enviesaria: 256 nao e multiplo de 25, entao os primeiros seis simbolos do
/// alfabeto sairiam com probabilidade maior que os demais. O vies nao quebra o
/// codigo sozinho, mas ele corta entropia de graca — e entropia e a unica
/// coisa que este codigo tem.
///
/// Lanca se os bytes acabarem. Lancar e melhor do que completar com o que
/// sobrou: um codigo curto silencioso seria um codigo fraco silencioso.
export function cunharCodigo(bytes: Uint8Array | number[]): string {
  const limite = 256 - (256 % ALFABETO.length); // maior multiplo de 25 <= 256
  let saida = "";
  for (let i = 0; i < bytes.length && saida.length < TAMANHO_CODIGO; i++) {
    const b = bytes[i] & 0xff;
    if (b >= limite) continue; // rejeitado: usar seria enviesar
    saida += ALFABETO[b % ALFABETO.length];
  }
  if (saida.length < TAMANHO_CODIGO) {
    throw new RangeError("bytes aleatorios insuficientes para cunhar o codigo");
  }
  return `${PREFIXO}-${saida.slice(0, 4)}-${saida.slice(4, 8)}`;
}

/// Devolve o codigo na forma canonica, ou `null` se ele nao for um codigo.
///
/// Aceita o que uma pessoa realmente digita: minusculas, espacos, hifens a
/// mais ou a menos, o prefixo esquecido. Recusa qualquer simbolo fora do
/// alfabeto — e recusa ANTES de qualquer consulta, para que um palpite mal
/// formado nem chegue a tocar o banco.
export function normalizarCodigo(bruto: unknown): string | null {
  if (typeof bruto !== "string") return null;
  const limpo = bruto.toUpperCase().replace(/[^A-Z0-9]/g, "");
  const semPrefixo = limpo.startsWith(PREFIXO) ? limpo.slice(PREFIXO.length) : limpo;
  if (semPrefixo.length !== TAMANHO_CODIGO) return null;
  for (const s of semPrefixo) {
    if (!ALFABETO.includes(s)) return null;
  }
  return `${PREFIXO}-${semPrefixo.slice(0, 4)}-${semPrefixo.slice(4, 8)}`;
}

/// O codigo, como ele pode aparecer em log.
///
/// Tres simbolos e reticencias. O suficiente para casar duas linhas do mesmo
/// incidente, insuficiente para reconstruir o codigo — e a mesma disciplina
/// que o adaptador do servidor aplica ao token e a URL.
export function redigirCodigo(codigo: string): string {
  const canonico = normalizarCodigo(codigo);
  if (canonico === null) return "***";
  return `${canonico.slice(0, 7)}...`;
}

/// A impressao do codigo: SHA-256 em hexadecimal.
///
/// E ela, e nunca o codigo, que vira id de documento. Duas propriedades
/// importam, e as duas sao necessarias:
///
///   NAO ARMAZENAR ... um dump de leitura do banco nao vira uma lista de
///                     convites validos, porque o hash nao volta.
///   NAO ENUMERAR .... como o hash e o ID, quem nao tem o codigo nao tem o id.
///                     Nao ha consulta por campo, entao nao ha varredura.
///
/// Sem sal, e de proposito: o sal teria que ser guardado em algum lugar para
/// que a resolucao funcionasse, e um sal global guardado ao lado do hash nao
/// acrescenta nada contra quem ja leu o banco. O que protege o codigo e a
/// entropia dele mais o limitador — nao o segredo do hash.
export function impressaoDoCodigo(codigo: string): string {
  const canonico = normalizarCodigo(codigo);
  if (canonico === null) throw new TypeError("codigo invalido: nao ha impressao a calcular");
  return createHash("sha256").update(canonico, "utf8").digest("hex");
}

// ===========================================================================
// O VINCULO CODIGO -> SALA
// ===========================================================================

/// A forma do documento `codigosDeSala/{impressao}`.
///
/// O ID DO DOCUMENTO E A IMPRESSAO DO CODIGO. Nao existe campo `codigo`, e nao
/// existe consulta por campo: quem nao tem o codigo nao tem o id, e sem o id
/// nao ha leitura. Isso e o que torna a enumeracao impossivel em vez de
/// meramente dificil.
export type VinculoDeCodigo = {
  /// A sala que este codigo localiza. UM codigo aponta para UMA sala, sempre.
  salaId: string;
  /// Quem abriu a sala. Guardado aqui para que a resolucao nao precise ler o
  /// documento da sala antes de decidir se responde.
  proprietarioUid: string;
  criadoEm: string;
  /// Depois disto o codigo nao resolve mais, mesmo que a sala continue de pe.
  expiraEm: string;
  /// Revogado quando a sala e encerrada. Revogar em vez de apagar preserva a
  /// trilha: um codigo que some do banco e indistinguivel de um que nunca
  /// existiu, e os dois casos pedem investigacoes diferentes.
  revogadoEm: string | null;
};

/// Validade padrao de um codigo: 12 horas.
///
/// Nao e a duracao da sala — e a duracao do CONVITE. Uma sala pode durar
/// minutos; o codigo dela nao precisa continuar valendo no dia seguinte, e um
/// convite eterno e um convite que vaza.
export const VALIDADE_CODIGO_MS = 12 * 60 * 60 * 1000;

export const RECUSA_CODIGO = {
  /// A UNICA recusa que sai no fio. Ver abaixo.
  INDISPONIVEL: "CODIGO_INDISPONIVEL",
} as const;

/// Motivos INTERNOS. Vao para o registro de auditoria, nunca para o cliente.
export const MOTIVO_CODIGO = {
  MAL_FORMADO: "MAL_FORMADO",
  INEXISTENTE: "INEXISTENTE",
  EXPIRADO: "EXPIRADO",
  REVOGADO: "REVOGADO",
  EXCESSO_DE_TENTATIVAS: "EXCESSO_DE_TENTATIVAS",
} as const;

export type MotivoCodigo = (typeof MOTIVO_CODIGO)[keyof typeof MOTIVO_CODIGO];

export type ResolucaoDeCodigo =
  | { ok: true; salaId: string; proprietarioUid: string }
  | { ok: false; motivo: MotivoCodigo };

/// Resolve um codigo para uma sala.
///
/// TODA recusa tem a MESMA resposta no fio (`CODIGO_INDISPONIVEL`), e por isso
/// esta funcao devolve o motivo interno separado: quem chama registra o motivo
/// e responde a recusa unica.
///
/// Mensagens diferentes por motivo virariam ORACULO. "codigo expirado" conta
/// que a sala existiu; "codigo inexistente" conta que nao. Com as duas
/// respostas na mao, varrer o espaco de codigos deixa de ser adivinhacao e vira
/// medicao — e o limitador de tentativas perde metade da graca.
export function resolverCodigo(entrada: {
  vinculo: VinculoDeCodigo | null;
  agora: string;
}): ResolucaoDeCodigo {
  const { vinculo, agora } = entrada;
  if (vinculo === null) return { ok: false, motivo: MOTIVO_CODIGO.INEXISTENTE };
  if (vinculo.revogadoEm !== null) return { ok: false, motivo: MOTIVO_CODIGO.REVOGADO };
  if (Date.parse(agora) >= Date.parse(vinculo.expiraEm)) {
    return { ok: false, motivo: MOTIVO_CODIGO.EXPIRADO };
  }
  return { ok: true, salaId: vinculo.salaId, proprietarioUid: vinculo.proprietarioUid };
}

// ===========================================================================
// O LIMITE DE TENTATIVAS
// ===========================================================================

/// Quantos palpites por identidade dentro da janela.
export const TENTATIVAS_POR_JANELA = 10;

/// A janela do limitador: 10 minutos.
export const JANELA_TENTATIVAS_MS = 10 * 60 * 1000;

/// `tentativasDeCodigo/{uid}` — o contador do limitador.
export type RegistroDeTentativas = {
  /// Inicio da janela corrente.
  janelaEm: string;
  /// Quantos palpites ja houve nesta janela.
  tentativas: number;
};

export type DecisaoDeTentativa = {
  /// Pode consultar o codigo?
  permitido: boolean;
  /// O registro a gravar. Gravado SEMPRE — inclusive na recusa, porque nao
  /// contar a tentativa recusada tornaria o limitador contornavel por quem
  /// simplesmente insistisse.
  proximo: RegistroDeTentativas;
};

/// Decide se este palpite pode acontecer, e devolve o contador atualizado.
///
/// Janela FIXA, e nao deslizante. A deslizante e mais justa e exige guardar a
/// lista de instantes; a fixa exige dois campos e erra so na fronteira, onde o
/// pior caso e o dobro dos palpites num intervalo. Contra 37 bits de codigo,
/// 20 palpites e 10 palpites sao igualmente inuteis — entao a simplicidade
/// ganha, e o motivo de ela ganhar fica escrito aqui.
export function avaliarTentativa(entrada: {
  registro: RegistroDeTentativas | null;
  agora: string;
}): DecisaoDeTentativa {
  const { registro, agora } = entrada;
  const t = Date.parse(agora);

  if (registro === null || t - Date.parse(registro.janelaEm) >= JANELA_TENTATIVAS_MS) {
    return { permitido: true, proximo: { janelaEm: agora, tentativas: 1 } };
  }

  const proximo = { janelaEm: registro.janelaEm, tentativas: registro.tentativas + 1 };
  return { permitido: proximo.tentativas <= TENTATIVAS_POR_JANELA, proximo };
}

// ===========================================================================
// A AUTORIDADE SOBRE AS CADEIRAS
// ===========================================================================

export const RECUSA_CADEIRA = {
  NAO_E_PROPRIETARIO: "CADEIRA_NAO_E_PROPRIETARIO",
  SALA_ENCERRADA: "CADEIRA_SALA_ENCERRADA",
  INDICE_INVALIDO: "CADEIRA_INDICE_INVALIDO",
  ESTADO_INVALIDO: "CADEIRA_ESTADO_INVALIDO",
} as const;

export type RecusaCadeira = (typeof RECUSA_CADEIRA)[keyof typeof RECUSA_CADEIRA];

/// So o proprietario trava, libera ou reserva cadeira.
///
/// A comparacao e com o UID AUTENTICADO, nunca com um `proprietario: true` que
/// tenha chegado na mensagem. Um cliente pode escrever qualquer coisa no
/// payload; ele nao pode escrever no `sub` de um token assinado.
export function podeControlarCadeiras(entrada: {
  uidAutenticado: string;
  proprietarioUid: string;
  encerradaEm: string | null;
}): { ok: true } | { ok: false; motivo: RecusaCadeira } {
  if (entrada.encerradaEm !== null) {
    return { ok: false, motivo: RECUSA_CADEIRA.SALA_ENCERRADA };
  }
  if (entrada.uidAutenticado !== entrada.proprietarioUid) {
    return { ok: false, motivo: RECUSA_CADEIRA.NAO_E_PROPRIETARIO };
  }
  return { ok: true };
}
