// functions/src/autoridade.ts — QUEM É A AUTORIDADE DA PARTIDA.
//
// Este arquivo existe separado de `rastreabilidade.ts` pelo mesmo motivo que
// `conquistas.ts`: `src/index.ts` faz `export * from "./rastreabilidade"`, e o
// Firebase trata CADA export do entrypoint como definição de função a implantar.
// Um predicado exportado de lá viraria uma Cloud Function vazia — e o `tsc` não
// acusaria nada. Aqui, não: `index.ts` não reexporta este módulo, então o que
// mora neste arquivo é biblioteca, e não superfície de implantação.
//
// A razão de existir é ter UM lugar só onde se decide se um token manda no
// encerramento. Antes desta extração a regra vivia embutida dentro de
// `exigirAutoridadeDePartida`, o que a tornava impossível de provar sem chamar
// a função inteira — e uma regra de permissão que nenhum teste alcança é uma
// regra que só se descobre errada em produção.
//
// NADA AQUI FOI AFROUXADO. A comparação continua sendo `=== true`, idêntica à
// que estava embutida; o que mudou é o endereço dela.

/// Papeis que podem escrever registro de partida.
///
/// Espelha `ChamadorAutorizado.papeisDeAutoridade` do dominio Dart. A
/// duplicacao e inevitavel enquanto a ponte nao carregar a rastreabilidade, e
/// esta anotada de proposito para quem for unifica-las achar os dois pontos.
export const PAPEIS_DE_AUTORIDADE = ["motorDePartidas", "admin"] as const;

/// O nome do claim que esta OS provisiona. Constante, e não literal solto, para
/// que o provisionador administrativo e a guarda não possam divergir por um
/// erro de digitação que nenhum compilador pegaria.
export const CLAIM_MOTOR_DE_PARTIDAS = "motorDePartidas";

/// Os claims do token, como este projeto os le.
///
/// Tipado em vez de `any` para que um claim escrito errado (`Admin`, `sup0rte`)
/// vire erro de compilacao e nao uma comparacao que sempre da `false` — o pior
/// defeito possivel numa checagem de permissao, porque falha ABERTA em nenhum
/// teste e FECHADA em producao.
export type ClaimsDoToken = Partial<
  Record<(typeof PAPEIS_DE_AUTORIDADE)[number] | "suporte", boolean>
>;

/// Este token manda no encerramento de partida?
///
/// `=== true` e ESTRITO de proposito, e é o contrato desta OS. Um claim que
/// chegue como a string `"true"`, como o número `1`, como `"1"` ou como
/// `false` NÃO autoriza — os três primeiros são exatamente o que um
/// provisionamento manual desleixado produz, e aceitá-los transformaria um erro
/// de digitação em concessão de autoridade.
///
/// Ausência também não autoriza: o objeto vazio é o caso do jogador comum, que
/// é a maioria das conexões.
export function autorizaComoMotorDePartidas(
  claims: ClaimsDoToken | undefined | null
): boolean {
  const token = claims ?? {};
  return PAPEIS_DE_AUTORIDADE.some((papel) => token[papel] === true);
}

// ===========================================================================
// [CREDENCIAL] REVOGAÇÃO EFETIVA — o corte tem de valer em PRODUÇÃO
// ===========================================================================
//
// O PROBLEMA, medido e documentado na OS anterior (§4 e §11.5 de
// docs/PROVISIONAMENTO-CLAIM-MOTOR-PARTIDAS-V1.md):
//
//   Revogar o claim NÃO invalida nenhum token já emitido, e revogar as sessões
//   (`revokeRefreshTokens`) só é notado por quem VERIFICA com `checkRevoked`.
//   O protocolo callable não verifica: ele confere assinatura, expiração,
//   audience e emissor, e preenche `request.auth`. Um token de uma sessão
//   revogada continua chegando aqui com `req.auth.token.motorDePartidas === true`
//   até expirar — até uma hora depois do corte.
//
//   No EMULADOR isso não aparece: lá `verifyIdToken` recusa o token revogado
//   mesmo sem a flag. Foi por isso que o ponto ficou apenas *documentado* na OS
//   anterior, e é exatamente o tipo de divergência que faz uma equipe concluir,
//   errado, que o corte funciona.
//
// A CORREÇÃO: para a única função que a AUTORIDADE DA PARTIDA chama, o bearer
// bruto é verificado outra vez, agora com `checkRevoked: true`, e a decisão de
// autoridade passa a sair DESSE token — não de `req.auth.token`.
//
// POR QUE ISTO NÃO CRIA UMA SEGUNDA AUTORIDADE. Não há duas respostas possíveis:
// a verificação com revogação é ESTRITAMENTE mais forte que a do protocolo
// (mesmo conjunto de checagens, mais uma), e as duas identidades são comparadas
// — divergiu, recusa. O protocolo continua sendo quem admite a requisição; o que
// mudou é que a autoridade exige uma prova a mais que só o servidor de partidas
// precisa dar.
//
// POR QUE SÓ AQUI. `verifyIdToken(_, true)` consulta o registro de revogação do
// usuário, o que custa uma ida à rede. No encerramento de partida isso acontece
// UMA vez por partida — não por jogada, não por quadro, não por leitura de
// perfil. Aplicar o mesmo às funções do aplicativo trocaria latência de toda a
// base de jogadores por uma garantia que só a identidade técnica precisa.

/// Por que a autoridade foi recusada.
///
/// Existe para os TESTES e para o log. NÃO viaja para o chamador: o servidor de
/// partidas não precisa saber se falhou por bearer ausente ou por sessão
/// revogada, e detalhar isso ensina a diferença a quem estiver sondando.
export const RECUSA = {
  SEM_BEARER: "sem_bearer",
  BEARER_MALFORMADO: "bearer_malformado",
  TOKEN_RECUSADO: "token_recusado",
  IDENTIDADE_DIVERGENTE: "identidade_divergente",
  SEM_AUTORIDADE: "sem_autoridade",
} as const;

export type MotivoDeRecusa = (typeof RECUSA)[keyof typeof RECUSA];

/// O recorte de `admin.auth()` de que esta guarda depende.
///
/// Tipado como interface mínima, e não como `Auth` do SDK, por uma razão de
/// prova: assim o teste injeta um dublê que REGISTRA os argumentos recebidos, e
/// o `checkRevoked: true` deixa de ser algo que se confere lendo o código para
/// virar algo que uma asserção quebra se alguém mudar.
export interface AutenticadorQueVerifica {
  verifyIdToken(
    idToken: string,
    checkRevoked?: boolean
  ): Promise<{ uid: string } & Record<string, unknown>>;
}

export type TokenVerificado = { uid: string; claims: ClaimsDoToken };

export type VerificadorDeToken = (token: string) => Promise<TokenVerificado>;

/// O verificador de produção.
///
/// O `true` do segundo argumento é o objeto inteiro desta entrega. Sem ele, em
/// produção, um token de sessão revogada continua verificando até expirar.
export function verificadorComRevogacao(
  auth: AutenticadorQueVerifica
): VerificadorDeToken {
  return async (token: string) => {
    const decodificado = await auth.verifyIdToken(token, true);
    return {
      uid: decodificado.uid,
      // Os custom claims chegam no mesmo nível do payload decodificado, ao lado
      // de `sub`, `aud` e `iss` — é assim que o Admin SDK os entrega.
      claims: decodificado as unknown as ClaimsDoToken,
    };
  };
}

/// Extrai o token de um `Authorization: Bearer <token>`.
///
/// ESTRITO de propósito. Aceitar `bearer` minúsculo, dois espaços ou um token
/// vazio seria tolerância que só beneficia quem está tateando o formato — o
/// cliente legítimo é uma linha de código nossa, e ela acerta na primeira.
export function extrairBearer(cabecalho: unknown): string | null {
  if (typeof cabecalho !== "string") return null;
  const casou = /^Bearer ([^\s]+)$/.exec(cabecalho);
  return casou ? casou[1] : null;
}

export type ConferenciaDeAutoridade =
  | { ok: true; uid: string }
  | { ok: false; motivo: MotivoDeRecusa };

/// A guarda completa da autoridade de partida, com revogação conferida.
///
/// A ORDEM IMPORTA, e cada passo fecha um caminho:
///
///   1. bearer presente e bem formado — sem ele não há o que verificar;
///   2. `verifyIdToken(token, true)` — assinatura, expiração, audience, emissor
///      E REVOGAÇÃO. Qualquer falha recusa; nada é inferido de `req.auth`;
///   3. a identidade verificada bate com a que o protocolo colocou em
///      `req.auth.uid`. Divergir aqui não deveria acontecer — e é justamente por
///      isso que é recusa: significa que uma das duas leituras está errada, e
///      não há como saber qual;
///   4. só então o papel é avaliado, e sobre os claims DO TOKEN VERIFICADO.
///
/// O passo 4 usa `autorizaComoMotorDePartidas`, a mesma função de sempre —
/// `admin: true` continua autorizando, por papel próprio e anterior a esta
/// entrega. O que mudou não é QUEM autoriza; é de qual token a resposta sai.
export async function conferirAutoridadeDePartida(params: {
  cabecalhoAuthorization: unknown;
  uidDoProtocolo: string;
  verificar: VerificadorDeToken;
}): Promise<ConferenciaDeAutoridade> {
  const { cabecalhoAuthorization, uidDoProtocolo, verificar } = params;

  if (cabecalhoAuthorization === undefined || cabecalhoAuthorization === null) {
    return { ok: false, motivo: RECUSA.SEM_BEARER };
  }
  const token = extrairBearer(cabecalhoAuthorization);
  if (token === null) {
    return { ok: false, motivo: RECUSA.BEARER_MALFORMADO };
  }

  let verificado: TokenVerificado;
  try {
    verificado = await verificar(token);
  } catch (_) {
    // Token inválido, expirado ou de sessão REVOGADA caem todos aqui, e todos
    // dão no mesmo lugar: recusa. Distingui-los no retorno seria descrever a
    // própria defesa para quem a está testando.
    return { ok: false, motivo: RECUSA.TOKEN_RECUSADO };
  }

  if (!verificado.uid || verificado.uid !== uidDoProtocolo) {
    return { ok: false, motivo: RECUSA.IDENTIDADE_DIVERGENTE };
  }

  if (!autorizaComoMotorDePartidas(verificado.claims)) {
    return { ok: false, motivo: RECUSA.SEM_AUTORIDADE };
  }

  return { ok: true, uid: verificado.uid };
}
