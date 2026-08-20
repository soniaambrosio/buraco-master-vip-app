// comunicacao.ts — o documento da comunicacao, a projecao e a RETENCAO.
//
// MODULO PURO, pelo mesmo criterio de `chat.ts` e `idempotency.ts`: nada aqui
// importa firebase-admin e nada carrega o bundle Dart. E o que permite a
// `test/comunicacao.test.js` provar projecao, evidencia e retencao com
// `node --test`, sem emulador e sem `dart compile js`.
//
// ===========================================================================
// UMA COLECAO, E NAO DUAS
// ===========================================================================
//
// Fala catalogada, emoji, reacao, texto privado e evento de sistema moram todos
// em `chatMessages/{messageId}`. A tentacao de criar `chatFalas` era grande e
// esta errada, por tres razoes concretas:
//
//   1. A DENUNCIA precisa alcancar qualquer um deles pelo mesmo caminho. Com
//      duas colecoes, `registrarDenuncia` teria de adivinhar onde procurar — e
//      um `messageId` que existisse nas duas seria ambiguo.
//   2. A IDEMPOTENCIA e por `messageId`, derivado de autor+intencao. Duas
//      colecoes com a mesma chave permitiriam a MESMA intencao gravar dois
//      documentos.
//   3. A RETENCAO e uma politica so. Duas colecoes seriam duas politicas, e a
//      segunda seria esquecida.
//
// O que separa os tipos e o campo `tipo`, que e obrigatorio e fechado.

import { exigirEntregaSegura } from "./chat";

export const C_MENSAGENS = "chatMessages";

/// O estado de ritmo por jogador (§6.5).
///
/// COLECAO PROPRIA, e nao um campo em `playerModeration/{uid}`. A distincao e a
/// mesma que o dominio faz entre freio e sancao: `playerModeration` e o estado
/// DISCIPLINAR, com responsavel e motivo, lido por admin e por rotas sociais.
/// Contagem de rajada nao e disciplina — e um contador de segundos que muda a
/// cada mensagem. Guardar os dois no mesmo documento faria toda fala reescrever
/// o registro disciplinar do jogador.
export const C_RITMO = "chatRitmo";

/// Onde a Mesa Privada e registrada pela AUTORIDADE DOS TIPOS DE MESA.
///
/// ESTE CODEBASE SO LE. Quem escreve e `functions-mesas` (`registrarMesaPrivada`),
/// e o que se le daqui e exatamente o que a §3 manda consumir em vez de recriar:
/// que a sala existe, quem e o dono, se ja foi encerrada, e qual configuracao de
/// chat o anfitriao escolheu.
export const C_SALAS_PRIVADAS = "salasPrivadas";

/// A ancora de admissao da mesma autoridade: quem OCUPA assento nesta sala.
///
/// Id do documento: `${codigoDaSala}__${uid}`. Tambem so leitura.
export const C_ASSENTOS_ADMITIDOS = "assentosAdmitidos";

/// O direito VIP, escrito pelo Billing. SO LEITURA, e sem interpretacao: o
/// documento atravessa inteiro para o dominio, que decide vigencia.
export const C_ENTITLEMENTS = "playerEntitlements";

// ---------------------------------------------------------------------------
// RETENCAO (§7.5)
// ---------------------------------------------------------------------------
//
// "Nao manter historico privado indefinidamente por conveniencia."
//
// A JANELA E OPERACIONAL, e o numero tem uma razao: 30 dias e o prazo em que
// uma denuncia ainda pode ser aberta sobre uma conversa e triada por gente. Fora
// dessa janela, o documento nao serve a ninguem — nem ao jogador (o chat e ao
// vivo, nao ha historico na tela), nem a moderacao (a evidencia de uma denuncia
// e COPIADA para o registro dela, justamente para sobreviver a expiracao).
//
// O CAMPO E `expiraEm`, e ele e a metade do mecanismo. A outra metade e a
// politica de TTL do Firestore apontada para este campo, que e configuracao de
// projeto e NAO se aplica por deploy de codigo. Esta OS proibe deploy; o que ela
// entrega e o campo, a documentacao e a prova de que ele e gravado. A ativacao
// esta no runbook, em docs/COMUNICACAO-CONTROLADA-V1.md.
export const RETENCAO_DIAS = 30;

/// O instante em que este documento deixa de ter finalidade.
///
/// Deriva de `enviadaEm`, e nao do relogio de quem chama: dois documentos da
/// mesma mensagem (o gravado e o relido num retry) tem de expirar juntos.
export function expiraEmDe(enviadaEm: string): string {
  const base = Date.parse(enviadaEm);
  if (!Number.isFinite(base)) {
    throw new Error("enviadaEm invalido: retencao nao pode ser calculada.");
  }
  return new Date(base + RETENCAO_DIAS * 24 * 60 * 60 * 1000).toISOString();
}

// ---------------------------------------------------------------------------
// O DOCUMENTO
// ---------------------------------------------------------------------------

/// O documento gravado em `chatMessages/{messageId}` a partir desta OS.
///
/// SUPERCONJUNTO do `DocumentoMensagem` do chat livre: os campos antigos
/// continuam com o mesmo nome e o mesmo sentido, e os novos sao acrescimo. Um
/// documento gravado ANTES desta OS nao tem `tipo` nem `ambiente`, e
/// `projetarComunicacao` sabe ler os dois casos — ver `tipoDe`.
export interface DocumentoComunicacao {
  messageId: string;
  canalId: string;
  /// `mesa_de_partida` | `saguao_publico`. Mantido para nao reescrever o
  /// historico: e o vocabulario do chat livre.
  superficie: string;
  /// O ambiente da §2. Ausente nos documentos anteriores a esta OS.
  ambiente?: string;
  tipo?: string;

  /// `null` em evento de sistema — e essa ausencia e o que prova que ele nao
  /// tem dono.
  autorUid: string | null;
  autorPublicId: string | null;

  /// So em texto privado.
  conteudo?: string | null;
  /// So em item catalogado e em evento de sistema.
  itemId?: string | null;
  chaveDeLocalizacao?: string | null;
  fallbackOficial?: string | null;

  destinatarios: string[];
  /// Quem silenciou o autor e por isso nao recebeu a ENTREGA. Fica gravado
  /// porque a entrega repetida (retry) tem de seguir a decisao da vez em que a
  /// mensagem nasceu — a mesma razao de `destinatarios` ser gravado.
  silenciados?: string[];

  enviadaEm: string;
  expiraEm?: string;

  versaoDoCatalogo?: number;
  versaoDoContrato?: number;
  esquema: number;
}

/// O tipo do documento, com leitura do historico.
///
/// Documento sem `tipo` e anterior a esta OS, e todo documento anterior a esta
/// OS e texto livre de mesa — era a unica coisa que existia. Assumir isso e
/// seguro e e a unica leitura possivel; assumir o contrario (tratar como
/// catalogado) produziria uma projecao sem conteudo para uma mensagem que tem
/// conteudo.
export function tipoDe(doc: { tipo?: string | null }): string {
  return typeof doc.tipo === "string" && doc.tipo ? doc.tipo : "texto_privado";
}

// ---------------------------------------------------------------------------
// A PROJECAO
// ---------------------------------------------------------------------------

/// A comunicacao como o cliente a recebe.
export interface ComunicacaoPublica {
  messageId: string;
  autorPublicId?: string;
  ambiente: string;
  canalId: string;
  tipo: string;
  itemId?: string;
  chaveDeLocalizacao?: string;
  fallbackOficial?: string;
  conteudo?: string;
  enviadaEm: string;
  versaoDoCatalogo: number;
  versaoDoContrato: number;
  esquema: number;
}

/// Projeta o documento gravado.
///
/// LISTA DE PERMISSAO, e nao remocao de campos proibidos — a mesma escolha de
/// `projetarMensagem` em chat.ts, e pelo mesmo motivo: um campo novo no
/// documento NAO aparece aqui por construcao, enquanto um `delete` deixaria
/// passar tudo que ninguem se lembrou de apagar.
///
/// `autorUid`, `destinatarios` e `silenciados` nao saem daqui. `silenciados` e
/// o mais sensivel dos tres: ele diria a quem recebe QUEM silenciou o autor,
/// que e exatamente o que a §9.1 proibe ("nao notificar o alvo").
export function projetarComunicacao(doc: DocumentoComunicacao): ComunicacaoPublica {
  const tipo = tipoDe(doc);
  const projecao: ComunicacaoPublica = {
    messageId: doc.messageId,
    ambiente: typeof doc.ambiente === "string" ? doc.ambiente : "",
    canalId: doc.canalId,
    tipo,
    enviadaEm: doc.enviadaEm,
    versaoDoCatalogo:
      typeof doc.versaoDoCatalogo === "number" ? doc.versaoDoCatalogo : 0,
    versaoDoContrato:
      typeof doc.versaoDoContrato === "number" ? doc.versaoDoContrato : 0,
    esquema: doc.esquema,
  };

  // Evento de sistema nao tem autor, e a ausencia e o contrato: um cliente que
  // receba `autorPublicId` sabe que ha uma pessoa por tras. Ver §8.
  if (typeof doc.autorPublicId === "string" && doc.autorPublicId) {
    projecao.autorPublicId = doc.autorPublicId;
  }
  if (typeof doc.itemId === "string" && doc.itemId) {
    projecao.itemId = doc.itemId;
    if (typeof doc.chaveDeLocalizacao === "string") {
      projecao.chaveDeLocalizacao = doc.chaveDeLocalizacao;
    }
    if (typeof doc.fallbackOficial === "string") {
      projecao.fallbackOficial = doc.fallbackOficial;
    }
  }
  // CONTEUDO SO EM TEXTO. Uma fala catalogada que carregasse `conteudo` na
  // projecao entregaria a frase pronta em portugues e mataria a localizacao da
  // §6.3 — o cliente renderizaria o texto que chegou em vez da chave.
  if (tipo === "texto_privado" && typeof doc.conteudo === "string") {
    projecao.conteudo = doc.conteudo;
  }

  return exigirEntregaSegura(projecao);
}

// ---------------------------------------------------------------------------
// EVIDENCIA DE ITEM CATALOGADO (§9.5)
// ---------------------------------------------------------------------------

/// A evidencia de uma denuncia sobre item catalogado.
///
/// A §9.5 pede coisas DIFERENTES das que uma mensagem de texto pede:
///
///   texto ............ a mensagem exata, o autor, o horario, a sala;
///   fala catalogada .. o `falaId`, a VERSAO do catalogo, e a QUANTIDADE e o
///                      PADRAO de repeticao.
///
/// A razao da diferenca e o abuso ser outro. Uma fala do catalogo nunca e
/// ofensiva por si — ela foi aprovada. O que ofende e a REPETICAO: a mesma
/// provocacao doze vezes em dois minutos. Uma evidencia que guardasse so
/// "usou `provocar_essa_doeu_01`" nao mostraria o abuso; e uma que guardasse a
/// frase nao mostraria nada que o id ja nao diga.
export interface EvidenciaCatalogada {
  origem: string;
  autorUid?: string | null;
  itemId: string | null;
  versaoDoCatalogo: number | null;
  ambiente?: string | null;
  canalId?: string | null;
  enviadaEm?: string | null;
  messageId: string | null;
  /// Quantas vezes o MESMO item apareceu na janela examinada.
  repeticoes?: number;
  /// Instantes das repeticoes, do mais antigo ao mais novo. E o "padrao" da
  /// §9.5: dozes usos espacados em uma hora e uso normal; doze em vinte
  /// segundos e inundacao.
  instantes?: string[];
}

/// Monta a evidencia de um item catalogado a partir do documento e das
/// repeticoes que a autoridade encontrou.
///
/// PURA DE PROPOSITO: recebe os documentos como DADO. Quem consulta o Firestore
/// e o executor; a regra do que se preserva mora aqui, e o teste a prova sem
/// emulador.
export function evidenciaDeItemCatalogado(
  doc: DocumentoComunicacao | null,
  repeticoes: { enviadaEm: string }[] = []
): EvidenciaCatalogada {
  if (!doc) {
    return {
      origem: "referencia",
      itemId: null,
      versaoDoCatalogo: null,
      messageId: null,
    };
  }

  const instantes = repeticoes
    .map((r) => r.enviadaEm)
    .filter((e): e is string => typeof e === "string")
    .sort();

  return {
    origem: "servidor",
    // O autor vem do DOCUMENTO. Denunciar a fala de A dizendo que e de B
    // gravaria evidencia acusando B — o mesmo cuidado que `evidenciaDeMensagem`
    // ja tomava para texto.
    autorUid: doc.autorUid ?? null,
    itemId: typeof doc.itemId === "string" ? doc.itemId : null,
    versaoDoCatalogo:
      typeof doc.versaoDoCatalogo === "number" ? doc.versaoDoCatalogo : null,
    ambiente: typeof doc.ambiente === "string" ? doc.ambiente : null,
    canalId: doc.canalId,
    enviadaEm: doc.enviadaEm,
    messageId: doc.messageId,
    repeticoes: instantes.length,
    instantes,
  };
}

// ---------------------------------------------------------------------------
// O QUE NUNCA VAI PARA O LOG (§11)
// ---------------------------------------------------------------------------

/// Campos que um registro tecnico de comunicacao pode carregar.
///
/// LISTA DE PERMISSAO outra vez, e aqui ela vale mais que em qualquer outro
/// ponto: um `logger.info("mensagem", dados)` com o objeto inteiro publicaria o
/// chat privado no Cloud Logging — que e exatamente o que a §11 proibe, e um
/// lugar de onde nao se apaga com facilidade.
export function registroSeguro(e: {
  canalId?: string;
  ambiente?: string;
  tipo?: string;
  itemId?: string;
  recusa?: string | null;
  motivoDeRitmo?: string | null;
  destinatarios?: number;
  silenciados?: number;
}): Record<string, unknown> {
  const r: Record<string, unknown> = {};
  if (e.canalId) r.canalId = e.canalId;
  if (e.ambiente) r.ambiente = e.ambiente;
  if (e.tipo) r.tipo = e.tipo;
  // `itemId` PODE ir para o log: ele e um identificador de catalogo, publico e
  // igual para todo mundo. `conteudo` NAO tem campo aqui, e a ausencia e o
  // ponto — nao ha como registrar texto de jogador por esta funcao.
  if (e.itemId) r.itemId = e.itemId;
  if (e.recusa) r.recusa = e.recusa;
  if (e.motivoDeRitmo) r.motivoDeRitmo = e.motivoDeRitmo;
  if (typeof e.destinatarios === "number") r.destinatarios = e.destinatarios;
  if (typeof e.silenciados === "number") r.silenciados = e.silenciados;
  return r;
}
