// chaves.ts — colecoes, projecao publica e a TRAVA DE VAZAMENTO.
//
// MODULO PURO DE PROPOSITO: nada aqui importa firebase-admin, e nada aqui carrega
// o bundle do dominio Dart. E o que permite que `test/chaves.test.js` prove a
// trava com `node --test`, sem emulador e sem `dart compile js` — a mesma
// disciplina de `functions-moderacao/src/idempotency.ts`, cujo teste tambem roda
// sobre o modulo puro.
//
// A TRAVA E O MOTIVO DESTE ARQUIVO EXISTIR. §21 e §31-F dizem a mesma coisa por
// dois angulos: UID nao sai numa resposta publica, e-mail nao sai, Billing nao
// sai. Uma revisao de codigo nao garante isso — basta um `...relacao` num spread
// para o `membros` (que sao UIDs) sair junto. [exigirRespostaSegura] transforma
// esse acidente em erro, e o teste prova que ele erra.

// ---------------------------------------------------------------------------
// COLECOES
// ---------------------------------------------------------------------------
//
// Tres documentos para a identidade, e nao um, porque cada um tem um publico
// diferente e as regras do Firestore liberam ou negam o DOCUMENTO INTEIRO:
//
//   playerIdentities/{uid} ..... uid -> publicId. Privado; o dono le o proprio.
//   publicIdIndex/{publicId} ... publicId -> uid. CARREGA UID, portanto e negado
//                                a TODO cliente, inclusive ao dono. E tambem o
//                                documento de RESERVA: `create` falha se o id ja
//                                existir, e e assim que a colisao e detectada.
//   publicProfiles/{publicId} .. o documento PUBLICO. Apelido e avatar. Legivel
//                                por qualquer autenticado, e por isso nao pode
//                                conter mais nada.
//
// Juntar os tres seria escolher entre publicar o UID e nao ter perfil publico.

export const C_IDENTIDADES = "playerIdentities";
export const C_INDICE_PUBLICO = "publicIdIndex";
export const C_PERFIS_PUBLICOS = "publicProfiles";

/// A relacao canonica. Um documento por PAR (§20). Negada ao cliente em leitura
/// e escrita: `membros` sao UIDs.
export const C_AMIZADES = "friendships";

/// Contadores sociais, escritos na MESMA transacao que a relacao.
///
/// Por que contador transacional em vez de `count()` como a moderacao faz no teto
/// de bloqueios: `count()` nao roda dentro de transacao, entao o teto viraria uma
/// checagem "antes" que duas chamadas simultaneas atravessam. Com o contador na
/// transacao, o teto e exato — e §26 exige provar que uma chamada repetida NAO
/// incrementa duas vezes, que e um teste que so faz sentido se houver contador.
export const C_SOCIAL_JOGADOR = "playerSocial";

/// Colecoes de OUTRO dominio que este consome, e nunca escreve.
///
/// `users/{uid}/blocks` e a fonte canonica de bloqueio (OS de Moderacao §8), e
/// `playerModeration/{uid}` e o estado disciplinar consolidado. §18 e explicita:
/// consumir, nunca duplicar.
export const C_USUARIOS = "users";
export const SUB_BLOQUEIOS = "blocks";
export const C_MODERACAO_JOGADOR = "playerModeration";

// ---------------------------------------------------------------------------
// A TRAVA
// ---------------------------------------------------------------------------

/// Chaves que jamais podem aparecer numa resposta destinada a outro jogador.
///
/// Espelha `camposProibidosNoPublico` do dominio Dart, e a duplicacao e
/// deliberada: aquela lista guarda o DOCUMENTO gravado, esta guarda a RESPOSTA
/// montada. Sao dois momentos diferentes, e um documento limpo ainda pode virar
/// uma resposta suja se alguem espalhar a relacao canonica dentro dela.
export const CHAVES_PROIBIDAS = new Set([
  "uid",
  "userId",
  "ownerUid",
  "donoUid",
  "membros",
  "solicitanteUid",
  "destinatarioUid",
  "pairKey",
  "publicIds",
  "email",
  "telefone",
  "phoneNumber",
  "token",
  "idToken",
  "refreshToken",
  "providerId",
  "providerData",
  "claims",
  "vip",
  "billing",
  "entitlement",
  "entitlements",
  "assinatura",
  "fichas",
  "compras",
  "reports",
  "denuncias",
  "sanctions",
  "sancoes",
  "playerModeration",
  "chatSilenciadoAte",
  "socialRestritoAte",
  "suspensoAte",
  "suspensaoPermanente",
  "endereco",
  "cpf",
]);

/// Procura chave proibida em profundidade e devolve os CAMINHOS encontrados.
///
/// Recursiva porque o vazamento real quase nunca esta no topo: ele esta em
/// `{ perfil: {...}, relacao: { membros: [...] } }`, um nivel abaixo de onde
/// alguem olharia.
export function caminhosProibidos(valor: unknown, prefixo = ""): string[] {
  if (Array.isArray(valor)) {
    return valor.flatMap((v, i) => caminhosProibidos(v, `${prefixo}[${i}]`));
  }
  if (valor === null || typeof valor !== "object") return [];

  const achados: string[] = [];
  for (const [chave, v] of Object.entries(valor as Record<string, unknown>)) {
    const caminho = prefixo ? `${prefixo}.${chave}` : chave;
    if (CHAVES_PROIBIDAS.has(chave)) achados.push(caminho);
    achados.push(...caminhosProibidos(v, caminho));
  }
  return achados;
}

/// Erro lancado quando uma resposta publica carrega dado privado.
///
/// Classe propria, e nao `Error` cru, para que o `catch` de quem chama consiga
/// distinguir "vazamento" de "falha do Firestore" — o primeiro e incidente de
/// seguranca e merece log de nivel diferente.
export class VazamentoPublico extends Error {
  readonly caminhos: string[];
  constructor(caminhos: string[]) {
    super(`resposta publica carrega dado privado: ${caminhos.join(", ")}`);
    this.name = "VazamentoPublico";
    this.caminhos = caminhos;
  }
}

/// Devolve a resposta se ela for segura; lanca se nao for.
///
/// CHAMADA EM PRODUCAO, e nao so no teste. Falhar a chamada e melhor que
/// entregar o UID: o jogador ve um erro, o servidor loga um incidente, e ninguem
/// coleta identidade interna enquanto o defeito nao e corrigido.
export function exigirRespostaSegura<T>(resposta: T): T {
  const caminhos = caminhosProibidos(resposta);
  if (caminhos.length > 0) throw new VazamentoPublico(caminhos);
  return resposta;
}

// ---------------------------------------------------------------------------
// PROJECAO
// ---------------------------------------------------------------------------

export interface EntradaPublica {
  publicId: string;
  apelido: string;
  avatarRef: string | null;
  desde: string | null;
}

/// Monta uma entrada de lista a partir do perfil publico do OUTRO jogador.
///
/// Recebe o perfil ja lido, e nao o uid: e a assinatura que impede alguem de
/// "resolver depois" e acabar carregando o uid ate a borda.
export function entradaPublica(
  perfil: { publicId?: unknown; apelido?: unknown; avatarRef?: unknown } | undefined,
  publicIdConhecido: string,
  desde: string | null
): EntradaPublica {
  return {
    publicId:
      typeof perfil?.publicId === "string" ? perfil.publicId : publicIdConhecido,
    // Perfil sem apelido devolve VAZIO — nunca o uid. §31-F: "Nao usar UID como
    // fallback caso apelido ou avatar estejam ausentes."
    apelido: typeof perfil?.apelido === "string" ? perfil.apelido : "",
    avatarRef: typeof perfil?.avatarRef === "string" ? perfil.avatarRef : null,
    desde,
  };
}

/// Uma entrada de RESULTADO DE BUSCA: apresentacao publica + estado social.
///
/// E [EntradaPublica] mais `relacao` e `acoes`, e MENOS `desde`: "amigos desde"
/// nao e informacao de descoberta, e uma busca que devolvesse a data de amizade
/// de cada resultado estaria contando ao pesquisador coisas sobre relacoes que
/// ele nao abriu.
export interface EntradaDeBusca {
  publicId: string;
  apelido: string;
  avatarRef: string | null;
  relacao: string;
  acoes: string[];
}

/// As UNICAS chaves que um resultado de busca pode ter (OS de Busca §7).
///
/// A allowlist de novo, mesmo com a fonte ja sendo publica — "defesa em
/// profundidade", nas palavras da §7. `publicProfiles` e limpo por construcao
/// (a trava de escrita nao deixa outro campo entrar), mas o dia em que ele
/// ganhar um campo legitimo e novo, ele nao vaza para a busca de brinde: ele
/// simplesmente nao e copiado.
export const CAMPOS_DO_RESULTADO = [
  "publicId",
  "apelido",
  "avatarRef",
  "relacao",
  "acoes",
] as const;

/// Monta um resultado de busca a partir do perfil publico e do estado social.
///
/// CAMPO A CAMPO, e nunca por espalhamento do perfil lido. Um `{...perfil}` aqui
/// traria `apelidoOrdenacao`, `estado`, `criadoEm` e `esquema` — nenhum deles
/// privado, todos irrelevantes para quem procura, e o quarto e um detalhe
/// interno de versao de documento que o cliente passaria a enxergar sem que
/// ninguem tivesse decidido isso.
export function entradaDeBusca(
  perfil: { publicId?: unknown; apelido?: unknown; avatarRef?: unknown } | undefined,
  publicIdConhecido: string,
  relacao: string,
  acoes: string[]
): EntradaDeBusca {
  const base = entradaPublica(perfil, publicIdConhecido, null);
  return {
    publicId: base.publicId,
    apelido: base.apelido,
    avatarRef: base.avatarRef,
    relacao,
    acoes: [...acoes],
  };
}

/// O estado da relacao lido do documento canonico, sem expor os UIDs.
export interface RelacaoLida {
  estado: "nenhuma" | "pendente" | "amigos";
  solicitanteUid: string | null;
  destinatarioUid: string | null;
  solicitadaEm: string | null;
  amigosDesde: string | null;
  membros: string[];
  publicIds: Record<string, string>;
}

/// Le o documento canonico de amizade (ou a ausencia dele) numa forma unica.
///
/// Devolver um objeto para o documento AUSENTE, em vez de `null`, e o que faz
/// cada chamador tratar o caso "nao ha relacao" sem se lembrar de tratar.
export function lerRelacao(dados: Record<string, unknown> | undefined): RelacaoLida {
  const estadoBruto = dados?.estado;
  const estado =
    estadoBruto === "pendente" || estadoBruto === "amigos"
      ? estadoBruto
      : "nenhuma";
  const publicIds: Record<string, string> = {};
  const brutos = dados?.publicIds;
  if (brutos && typeof brutos === "object") {
    for (const [k, v] of Object.entries(brutos as Record<string, unknown>)) {
      if (typeof v === "string") publicIds[k] = v;
    }
  }
  return {
    estado,
    solicitanteUid:
      typeof dados?.solicitanteUid === "string" ? dados.solicitanteUid : null,
    destinatarioUid:
      typeof dados?.destinatarioUid === "string" ? dados.destinatarioUid : null,
    solicitadaEm:
      typeof dados?.solicitadaEm === "string" ? dados.solicitadaEm : null,
    amigosDesde: typeof dados?.amigosDesde === "string" ? dados.amigosDesde : null,
    membros: Array.isArray(dados?.membros)
      ? (dados.membros as unknown[]).filter(
          (m): m is string => typeof m === "string"
        )
      : [],
    publicIds,
  };
}

/// Contadores sociais de um jogador, com o zero como padrao.
export interface ContadoresSociais {
  amigos: number;
  solicitacoesEnviadas: number;
}

export function lerContadores(
  dados: Record<string, unknown> | undefined
): ContadoresSociais {
  const inteiro = (v: unknown): number =>
    typeof v === "number" && Number.isFinite(v) && v > 0 ? Math.floor(v) : 0;
  return {
    amigos: inteiro(dados?.amigos),
    solicitacoesEnviadas: inteiro(dados?.solicitacoesEnviadas),
  };
}
