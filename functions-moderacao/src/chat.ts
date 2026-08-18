// chat.ts — colecoes do chat, projecao e a TRAVA DE VAZAMENTO.
//
// MODULO PURO DE PROPOSITO: nada aqui importa firebase-admin, e nada aqui carrega
// o bundle do dominio Dart. E o que permite a `test/chat.test.js` provar a trava
// com `node --test`, sem emulador e sem `dart compile js` — a mesma disciplina de
// `idempotency.ts` (cujo teste tambem roda sobre o modulo puro) e de
// `functions-social/src/chaves.ts`.
//
// A TRAVA E O MOTIVO DESTE ARQUIVO EXISTIR. §13 da OS do Chat: quem recebe chat
// nao ganha, por tabela, UID interno, IP, token, socket id, e-mail, estado
// administrativo, lista de bloqueios nem sancao de terceiro. Uma revisao de
// codigo nao garante isso — basta um `...doc.data()` num spread para o `autorUid`
// e a lista de `destinatarios` sairem junto. [exigirEntregaSegura] transforma esse
// acidente em erro, e o teste prova que ele erra.

// ---------------------------------------------------------------------------
// COLECOES
// ---------------------------------------------------------------------------
//
// DUAS colecoes, e nao uma, porque cada uma tem um dono de escrita diferente e as
// regras do Firestore liberam ou negam o DOCUMENTO INTEIRO:
//
//   chatChannels/{canalId} ... QUEM ESTA NO CANAL. Escrito pelo motor de
//                             partidas; carrega UIDs de participantes, portanto e
//                             negado a todo cliente. E o CONTEXTO ESTAVEL da §10:
//                             sem ele, a lista de participantes viria do payload
//                             e qualquer jogador se declararia sentado numa mesa
//                             que nunca viu.
//
//   chatMessages/{messageId}  A MENSAGEM. Escrita SO por esta autoridade.
//                             Carrega `autorUid` e `destinatarios` (UIDs), e por
//                             isso tambem e negada ao cliente: a entrega ao
//                             jogador e a PROJECAO, nunca o documento.
//
// Juntar as duas seria escolher entre publicar UID e nao ter canal.

export const C_MENSAGENS = "chatMessages";
export const C_CANAIS = "chatChannels";

/// A autoridade de IDENTIDADE PUBLICA, que este dominio consome e nunca escreve.
///
/// `playerIdentities/{uid}.publicId` e mantida por functions-social (OS de
/// Identidade Publica). O chat LE e falha fechado quando falta: cunhar um
/// `publicId` aqui criaria uma segunda identidade para a mesma pessoa.
///
/// `users/{uid}/blocks` e `playerModeration/{uid}` NAO ganham constante aqui de
/// proposito: `index.ts` ja as nomeia (`COL_ESTADO`, e a subcolecao inline em
/// `consultarContato`), e uma segunda constante para o mesmo caminho e o comeco de
/// duas verdades sobre onde mora o bloqueio.
export const C_IDENTIDADES = "playerIdentities";

// ---------------------------------------------------------------------------
// A TRAVA
// ---------------------------------------------------------------------------

/// Chaves que jamais podem aparecer numa mensagem entregue a outro jogador.
///
/// Espelha `kChavesProibidasNaEntrega` de app/lib/chat/mensagem.dart. A
/// duplicacao e deliberada, e e a mesma razao que `chaves.ts` ja declara: aquela
/// lista guarda o que o DOMINIO projeta, esta guarda o que ESTE PROCESSO devolve.
/// Sao dois momentos, e um dominio limpo ainda vira entrega suja se o TypeScript
/// espalhar o documento do Firestore dentro da resposta.
export const CHAVES_PROIBIDAS_NA_ENTREGA = new Set([
  // identidade interna
  "uid",
  "userId",
  "autorUid",
  "authorUid",
  "senderUid",
  "remetenteUid",
  "destinatarioUid",
  "destinatarios",
  "participantes",
  "espectadores",
  "membros",
  // contato e credencial
  "email",
  "telefone",
  "phoneNumber",
  "token",
  "idToken",
  "refreshToken",
  "claims",
  "providerId",
  "providerData",
  // transporte (§10 e §13: socket e IP nunca viajam com a mensagem)
  "ip",
  "remoteAddress",
  "socketId",
  "socket",
  "connectionId",
  "sessionId",
  // estado administrativo de terceiro
  "reports",
  "denuncias",
  "sanctions",
  "sancoes",
  "playerModeration",
  "chatSilenciadoAte",
  "socialRestritoAte",
  "suspensoAte",
  "suspensaoPermanente",
  "blocks",
  "bloqueios",
  "mutes",
  // Billing e dado pessoal
  "vip",
  "billing",
  "entitlement",
  "entitlements",
  "assinatura",
  "compras",
  "cpf",
  "endereco",
]);

/// Procura chave proibida em profundidade e devolve os CAMINHOS encontrados.
///
/// Recursiva porque o vazamento real quase nunca esta no topo: ele esta em
/// `{ mensagem: {...}, canal: { participantes: [...] } }`, um nivel abaixo de onde
/// alguem olharia numa revisao.
export function caminhosProibidos(valor: unknown, prefixo = ""): string[] {
  if (Array.isArray(valor)) {
    return valor.flatMap((v, i) => caminhosProibidos(v, `${prefixo}[${i}]`));
  }
  if (valor === null || typeof valor !== "object") return [];

  const achados: string[] = [];
  for (const [chave, v] of Object.entries(valor as Record<string, unknown>)) {
    const caminho = prefixo ? `${prefixo}.${chave}` : chave;
    if (CHAVES_PROIBIDAS_NA_ENTREGA.has(chave)) achados.push(caminho);
    achados.push(...caminhosProibidos(v, caminho));
  }
  return achados;
}

/// Erro lancado quando uma entrega de chat carrega dado privado.
///
/// Classe propria, e nao `Error` cru, para que o `catch` de quem chama consiga
/// distinguir "vazamento" de "falha do Firestore" — o primeiro e incidente de
/// seguranca e merece log de nivel diferente.
export class VazamentoDeChat extends Error {
  readonly caminhos: string[];
  constructor(caminhos: string[]) {
    super(`entrega de chat carrega dado privado: ${caminhos.join(", ")}`);
    this.name = "VazamentoDeChat";
    this.caminhos = caminhos;
  }
}

/// Devolve a entrega se ela for segura; lanca se nao for.
///
/// CHAMADA EM PRODUCAO, e nao so no teste. Falhar a chamada e melhor que entregar
/// o UID: o jogador ve um erro, o servidor loga um incidente, e ninguem coleta
/// identidade interna enquanto o defeito nao e corrigido.
export function exigirEntregaSegura<T>(entrega: T): T {
  const caminhos = caminhosProibidos(entrega);
  if (caminhos.length > 0) throw new VazamentoDeChat(caminhos);
  return entrega;
}

// ---------------------------------------------------------------------------
// PROJECAO
// ---------------------------------------------------------------------------

/// A mensagem como o cliente a recebe. Espelha `MensagemPublica` do dominio.
export interface MensagemPublica {
  messageId: string;
  autorPublicId: string;
  superficie: string;
  canalId: string;
  conteudo: string;
  enviadaEm: string;
  esquema: number;
}

/// O documento gravado em `chatMessages/{messageId}`.
///
/// `autorUid` e `destinatarios` existem aqui e NAO existem na projecao. E o motivo
/// de haver projecao: a moderacao precisa saber de quem foi a mensagem (a
/// denuncia depende disso, §12), e o jogador nao precisa e nao pode saber.
export interface DocumentoMensagem {
  messageId: string;
  canalId: string;
  superficie: string;
  autorUid: string;
  autorPublicId: string;
  conteudo: string;
  destinatarios: string[];
  enviadaEm: string;
  esquema: number;
}

/// Projeta o documento gravado na mensagem publica.
///
/// LISTA DE PERMISSAO, e nao remocao de campos proibidos. A diferenca importa: um
/// campo novo no documento (digamos `ipDeOrigem`) NAO aparece na projecao por
/// construcao, enquanto um `delete resposta.autorUid` deixaria passar tudo que
/// ninguem se lembrou de apagar. E a mesma escolha que o servidor de partidas ja
/// fez para a visao de espectador: "construida do zero por lista de permissao".
export function projetarMensagem(doc: DocumentoMensagem): MensagemPublica {
  return exigirEntregaSegura({
    messageId: doc.messageId,
    autorPublicId: doc.autorPublicId,
    superficie: doc.superficie,
    canalId: doc.canalId,
    conteudo: doc.conteudo,
    enviadaEm: doc.enviadaEm,
    esquema: doc.esquema,
  });
}

// ---------------------------------------------------------------------------
// EVIDENCIA DE DENUNCIA (§12)
// ---------------------------------------------------------------------------

/// De onde veio o conteudo que instrui uma denuncia de mensagem.
///
/// `servidor` passa a existir a partir desta OS. `cliente_atestada` NAO e apagada,
/// e a sobrevivencia dela e delimitada, nao esquecida: ver
/// [evidenciaDeMensagem].
export const ORIGEM_EVIDENCIA = {
  /// O conteudo foi lido de `chatMessages/{messageId}` pela propria autoridade.
  SERVIDOR: "servidor",
  /// O conteudo foi afirmado pelo aparelho de quem denuncia.
  CLIENTE: "cliente_atestada",
  /// Nao ha conteudo: so a referencia.
  REFERENCIA: "referencia",
} as const;

export interface EvidenciaMensagem {
  origem: string;
  autorUid?: string | null;
  conteudo?: string | null;
  enviadaEm?: string | null;
  messageId: string | null;
  roomId?: string | null;
  canalId?: string | null;
}

/// Monta a evidencia de uma denuncia de mensagem.
///
/// A REGRA, e por que ela e assim (§12):
///
///   1. Se a mensagem EXISTE no servidor, a evidencia e do SERVIDOR, e o conteudo
///      atestado pelo cliente e DESCARTADO — nao comparado, nao mesclado, nao
///      guardado "para conferencia". Aceitar a copia do cliente ao lado da
///      autoritativa criaria duas versoes do mesmo fato, e a divergencia entre
///      elas seria decidida por quem lesse o registro depois.
///
///   2. Se a mensagem NAO existe no servidor, cai no comportamento antigo. E aqui
///      esta a DELIMITACAO que a §12 exige em vez de uma remocao silenciosa:
///      `cliente_atestada` sobrevive para as superficies que ainda nao tem
///      mensagem autoritativa — o saguao e a mesa enquanto o transporte nao
///      estiver ligado — e para o historico ja gravado, que nao se migra. O campo
///      `origem` continua dizendo qual dos dois casos aconteceu, que e o que
///      permite a moderacao humana saber o peso do que esta lendo.
///
/// PURA DE PROPOSITO: recebe o documento (ou `null`) como DADO, sem Firestore,
/// para que `test/chat.test.js` prove os tres desfechos sem emulador.
export function evidenciaDeMensagem(
  entrada: {
    messageId: string | null;
    roomId?: string | null;
    denunciadoUid: string;
    atestadaPeloCliente?: { conteudo?: string | null; enviadaEm?: string | null } | null;
  },
  doc: DocumentoMensagem | null
): EvidenciaMensagem {
  if (doc) {
    return {
      origem: ORIGEM_EVIDENCIA.SERVIDOR,
      // O autor vem do DOCUMENTO, e nao de `denunciadoUid`. Sem isso, denunciar a
      // mensagem de A dizendo que ela e de B gravaria uma evidencia que acusa B do
      // que A escreveu.
      autorUid: doc.autorUid,
      conteudo: doc.conteudo,
      enviadaEm: doc.enviadaEm,
      messageId: doc.messageId,
      canalId: doc.canalId,
      roomId: entrada.roomId ?? null,
    };
  }

  if (entrada.atestadaPeloCliente) {
    return {
      origem: ORIGEM_EVIDENCIA.CLIENTE,
      autorUid: entrada.denunciadoUid,
      conteudo: entrada.atestadaPeloCliente.conteudo ?? null,
      enviadaEm: entrada.atestadaPeloCliente.enviadaEm ?? null,
      messageId: entrada.messageId ?? null,
      roomId: entrada.roomId ?? null,
    };
  }

  return {
    origem: ORIGEM_EVIDENCIA.REFERENCIA,
    messageId: entrada.messageId ?? null,
    roomId: entrada.roomId ?? null,
  };
}
