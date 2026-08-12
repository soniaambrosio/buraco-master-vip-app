// repositorio.ts — QUEM EXECUTA. Transacao, leitura, escrita e mais nada.
//
// MESMA DIVISAO DE TRABALHO DOS OUTROS CODEBASES: as decisoes vivem no dominio
// Dart (app/lib/social/), acessado por domain.ts, e este arquivo so as aplica
// contra o banco. Um `if` de regra social que apareca aqui esta no lugar errado —
// a excecao sao as decisoes de PERSISTENCIA (o que escrever, em que ordem, sob
// qual transacao), que sao exatamente o assunto deste arquivo.
//
// ---------------------------------------------------------------------------
// FONTE DE VERDADE E PROJECOES (§20)
// ---------------------------------------------------------------------------
//
//   FONTE DE VERDADE ...... `friendships/{pairKey}`. UM documento por par. Se
//                           houver divergencia com qualquer outra colecao, ele
//                           esta certo e a outra esta errada.
//
//   PROJECOES DERIVADAS ... `users/{uid}/friends/{outroUid}` e
//                           `users/{uid}/friendRequests/{outroUid}`.
//
// As projecoes existem por UM motivo concreto: ordenar a lista de amigos por
// apelido (§22) exige que a chave de ordenacao esteja num campo indexavel do
// lado de QUEM CONSULTA — e o apelido do amigo e diferente para cada um dos dois
// membros do par, entao o documento canonico nao tem onde guardar os dois.
//
// ELAS SAO ESCRITAS NA MESMA TRANSACAO DA FONTE. Criar, aceitar, recusar,
// cancelar e remover tocam canonico e projecoes juntos ou nenhum dos dois: nao ha
// janela em que A liste B e B nao liste A.
//
// O UNICO PONTO EM QUE UMA PROJECAO PODE ENVELHECER e a troca de apelido, que
// atualiza `apelidoOrdenacao` em ate 200 documentos fora de transacao. E o
// estrago maximo disso e COSMETICO: `apelidoOrdenacao` so ordena. O apelido
// EXIBIDO e lido de `publicProfiles` na hora, entao §31-I ("alteracao de apelido
// refletida sem trocar publicId") vale por construcao, e uma projecao velha
// coloca um amigo na posicao errada da lista — nunca com o nome errado.
// `reconciliarProjecoesSociais` reconstroi tudo a partir do canonico.

import { getFirestore, Firestore, Transaction } from "firebase-admin/firestore";
import { randomBytes } from "node:crypto";
import { logger } from "firebase-functions";

import {
  C_AMIZADES,
  C_IDENTIDADES,
  C_INDICE_PUBLICO,
  C_MODERACAO_JOGADOR,
  C_PERFIS_PUBLICOS,
  C_SOCIAL_JOGADOR,
  C_USUARIOS,
  ContadoresSociais,
  RelacaoLida,
  SUB_BLOQUEIOS,
  lerContadores,
  lerRelacao,
} from "./chaves";
import { LIMITES, VereditoAmizade, agoraUtc, dominio } from "./domain";

export const SUB_AMIGOS = "friends";
export const SUB_SOLICITACOES = "friendRequests";

export function db(): Firestore {
  return getFirestore();
}

const dados = (
  d: FirebaseFirestore.DocumentSnapshot
): Record<string, unknown> | undefined =>
  d.exists ? (d.data() as Record<string, unknown>) : undefined;

// ===========================================================================
// IDENTIDADE PUBLICA (§10)
// ===========================================================================

export interface IdentidadeGarantida {
  publicId: string;
  /// `true` somente na chamada que de fato cunhou o id. As seguintes devolvem
  /// `false` com o MESMO publicId — §10: "Se ja existir: devolver a existente."
  criada: boolean;
}

/// Devolve o id publico do jogador, criando-o na primeira vez (§10).
///
/// IDEMPOTENTE E A PROVA DE CORRIDA. Duas chamadas simultaneas nao podem cunhar
/// dois ids para o mesmo jogador porque a decisao inteira acontece dentro de uma
/// transacao que LE `playerIdentities/{uid}` antes de escrever: a segunda
/// transacao ve o que a primeira gravou e devolve aquele id.
///
/// A COLISAO E TRATADA, e nao apenas considerada improvavel: a reserva em
/// `publicIdIndex/{candidato}` e conferida dentro da mesma transacao, e um
/// candidato ja tomado faz a funcao sortear outro. Com 60 bits a segunda
/// tentativa praticamente nunca acontece — mas "praticamente nunca" multiplicado
/// por milhoes de jogadores e uma vez, e essa uma vez seriam dois jogadores
/// compartilhando identidade publica.
export async function garantirIdentidade(
  uid: string,
  apelidoSugerido: string
): Promise<IdentidadeGarantida> {
  const refIdentidade = db().collection(C_IDENTIDADES).doc(uid);

  // Leitura barata fora da transacao: o caminho comum e "ja existe", e ele nao
  // precisa pagar por uma transacao.
  const jaGravado = dados(await refIdentidade.get())?.publicId;
  if (typeof jaGravado === "string" && jaGravado.length > 0) {
    return { publicId: jaGravado, criada: false };
  }

  for (let tentativa = 0; tentativa < 5; tentativa++) {
    const candidato = dominio.idPublicoDeBytes(
      Array.from(randomBytes(LIMITES.comprimentoIdPublico))
    ).publicId;

    const atribuido = await db().runTransaction(async (tx) => {
      const [identidade, reserva] = await Promise.all([
        tx.get(refIdentidade),
        tx.get(db().collection(C_INDICE_PUBLICO).doc(candidato)),
      ]);

      const existente = dados(identidade)?.publicId;
      if (typeof existente === "string" && existente.length > 0) {
        return existente;
      }
      if (reserva.exists) return null; // colisao: sorteia outro

      const agora = agoraUtc();

      // 1. O MAPA REVERSO. Carrega o uid, portanto e negado a todo cliente.
      tx.set(db().collection(C_INDICE_PUBLICO).doc(candidato), {
        publicId: candidato,
        uid,
        criadoEm: agora,
        esquema: LIMITES.esquema,
      });

      // 2. A IDENTIDADE DO JOGADOR. Escrita UMA vez na vida — nao ha caminho
      //    neste codebase que a atualize depois. §36: "publicId e imutavel."
      tx.set(refIdentidade, {
        uid,
        publicId: candidato,
        criadoEm: agora,
        esquema: LIMITES.esquema,
      });

      // 3. O DOCUMENTO PUBLICO. Montado pelo dominio, e conferido antes de sair
      //    daqui pela trava de §5.
      const perfil = dominio.perfilPublicoInicial({
        publicId: candidato,
        apelido: apelidoSugerido,
        agora,
      });
      exigirDocumentoPublicoLimpo(perfil as unknown as Record<string, unknown>);
      tx.set(db().collection(C_PERFIS_PUBLICOS).doc(candidato), perfil);

      return candidato;
    });

    if (atribuido !== null) {
      return { publicId: atribuido, criada: atribuido === candidato };
    }
    logger.warn("colisao ao reservar id publico, tentando outro", { tentativa });
  }

  throw new Error(
    `nao foi possivel reservar um id publico para ${uid} em 5 tentativas.`
  );
}

/// A trava de §5, do lado do servidor.
///
/// Chamada antes de CADA escrita em `publicProfiles`. Nao e um teste: e o que
/// impede que um campo novo, acrescentado com boa intencao num refactor, vire
/// dado privado publicado.
export function exigirDocumentoPublicoLimpo(doc: Record<string, unknown>): void {
  const veredito = dominio.conferirDocumentoPublico(doc);
  if (!veredito.ok) {
    logger.error("documento publico com campo nao autorizado", {
      ofensivas: veredito.ofensivas,
      privadas: veredito.privadas,
    });
    throw new Error(
      `documento publico com campo nao autorizado: ${veredito.ofensivas.join(", ")}`
    );
  }
}

/// `publicId -> uid`. Leitura por ID, e nao consulta.
///
/// A colecao `publicIdIndex` existe exatamente para isto: um
/// `where('publicId','==',...)` sobre `playerIdentities` custaria o mesmo e
/// exigiria um indice, e ainda deixaria o caminho de volta implicito.
export async function resolverUid(publicId: string): Promise<string | null> {
  const normalizado = dominio.normalizarIdPublico(publicId).publicId;
  if (!normalizado) return null;
  const doc = dados(
    await db().collection(C_INDICE_PUBLICO).doc(normalizado).get()
  );
  return typeof doc?.uid === "string" ? doc.uid : null;
}

/// `uid -> publicId`, sem criar.
export async function publicIdDe(uid: string): Promise<string | null> {
  const doc = dados(await db().collection(C_IDENTIDADES).doc(uid).get());
  return typeof doc?.publicId === "string" ? doc.publicId : null;
}

export async function lerPerfilPublico(
  publicId: string
): Promise<Record<string, unknown> | undefined> {
  return dados(await db().collection(C_PERFIS_PUBLICOS).doc(publicId).get());
}

/// Le varios perfis publicos de uma vez.
///
/// `getAll` em vez de N leituras: a lista de amigos precisa do apelido fresco de
/// cada um, e N idas separadas ao banco transformariam uma pagina em N viagens.
export async function lerPerfisPublicos(
  publicIds: string[]
): Promise<Map<string, Record<string, unknown>>> {
  const unicos = [...new Set(publicIds.filter((p) => p.length > 0))];
  if (unicos.length === 0) return new Map();
  const refs = unicos.map((p) => db().collection(C_PERFIS_PUBLICOS).doc(p));
  const docs = await db().getAll(...refs);
  const mapa = new Map<string, Record<string, unknown>>();
  for (const d of docs) {
    const v = dados(d);
    if (v) mapa.set(d.id, v);
  }
  return mapa;
}

// ===========================================================================
// BLOQUEIO — CONSUMIDO, NUNCA DUPLICADO (§18)
// ===========================================================================

export interface EstadoDeContato {
  permitido: boolean;
  motivo: string | null;
  /// Quem consulta bloqueou o alvo? Separado de [permitido] porque a TELA pode
  /// dizer "voce bloqueou esta pessoa" (o jogador fez isso, ele sabe), mas nunca
  /// o contrario — §31-B.
  euBloqueeiOAlvo: boolean;
}

/// Le o bloqueio nos dois sentidos e o estado disciplinar, e pergunta ao dominio.
///
/// Recebe a transacao quando ha uma: §27 exige que "A aceita enquanto B bloqueia
/// A" termine com o bloqueio prevalecendo, e isso so vale se a leitura do
/// bloqueio estiver DENTRO da mesma transacao que fecha a amizade. Fora dela, as
/// duas operacoes se cruzariam sem se ver.
export async function estadoDeContato(
  origemUid: string,
  alvoUid: string,
  tx?: Transaction
): Promise<EstadoDeContato> {
  const usuarios = db().collection(C_USUARIOS);
  const refIda = usuarios.doc(origemUid).collection(SUB_BLOQUEIOS).doc(alvoUid);
  const refVolta = usuarios.doc(alvoUid).collection(SUB_BLOQUEIOS).doc(origemUid);
  const refEstado = db().collection(C_MODERACAO_JOGADOR).doc(origemUid);

  const [ida, volta, estado] = tx
    ? await tx.getAll(refIda, refVolta, refEstado)
    : await db().getAll(refIda, refVolta, refEstado);

  const agora = agoraUtc();
  const e = dados(estado) ?? {};
  const vigente = (campo: string): boolean =>
    typeof e[campo] === "string" && agora < (e[campo] as string);

  const veredito = dominio.avaliarContato({
    origemBloqueouDestino: ida.exists,
    destinoBloqueouOrigem: volta.exists,
    origemComChatSilenciado: vigente("chatSilenciadoAte"),
    origemComRestricaoSocial:
      vigente("socialRestritoAte") || e.suspensaoPermanente === true,
  });

  return {
    permitido: veredito.permitido,
    motivo: veredito.motivo,
    euBloqueeiOAlvo: ida.exists,
  };
}

// ===========================================================================
// BUSCA POR APELIDO (OS de Busca §4, §6, §8, §9)
// ===========================================================================

/// Um candidato cru: o que a consulta ao indice devolveu, antes de qualquer
/// decisao sobre bloqueio ou relacao.
export interface CandidatoCru {
  publicId: string;
  perfil: Record<string, unknown>;
}

/// Um lote cru da faixa, e por onde continuar.
interface LoteDaFaixa {
  candidatos: CandidatoCru[];
  /// O ULTIMO documento lido, para a rodada seguinte comecar depois dele.
  ///
  /// E um cursor, e ele e INTERNO: nasce e morre dentro de UMA chamada de
  /// `buscarJogadoresPorApelido`, nunca e serializado e nunca chega ao cliente.
  /// O contrato de §9 — "a busca nao pagina" — e sobre o cliente nao poder
  /// avancar; ele nao proibe o servidor de ler o que precisa para responder uma
  /// pergunta so.
  ultimo: FirebaseFirestore.QueryDocumentSnapshot | null;
  /// O lote veio cheio, entao pode haver mais adiante na faixa.
  podeHaverMais: boolean;
}

/// Le um lote da faixa de chaves que o dominio montou.
///
/// A CONSULTA E SOBRE O DOCUMENTO PUBLICO, e nao sobre uma colecao de indice
/// paralela (§4). `apelidoOrdenacao` ja existe la, ja e derivado do apelido a
/// cada escrita e ja e recalculado pelo servidor — criar `nicknameIndex` seria
/// manter uma segunda copia do mesmo campo, e uma copia e uma divergencia
/// esperando o dia em que alguem escrever so num dos dois.
///
/// `estado == 'ativo'` VAI NA CONSULTA, e nao num filtro depois: uma pagina de
/// vinte que virasse tres depois de descartar contas indisponiveis faria o teto
/// de resultados depender de quem esta desativado. E o par igualdade+faixa e
/// exatamente o que o indice composto declarado em firestore.indexes.json serve.
///
/// A ORDEM E TOTAL: `apelidoOrdenacao` desempatado por `publicId`, que e unico.
/// Sem o desempate, duas pessoas com o mesmo apelido teriam ordem indefinida
/// entre chamadas — e §14 exige resultado deterministico. E e a ordem total que
/// torna o `startAfter` da rodada seguinte exato: nao ha empate que faca um
/// documento ser pulado nem lido duas vezes.
async function loteDaFaixa(
  chaveInicio: string,
  chaveFim: string,
  exato: boolean,
  tamanho: number,
  depoisDe: FirebaseFirestore.QueryDocumentSnapshot | null
): Promise<LoteDaFaixa> {
  const colecao = db().collection(C_PERFIS_PUBLICOS);

  let consulta = exato
    ? colecao
        .where("estado", "==", "ativo")
        .where("apelidoOrdenacao", "==", chaveInicio)
    : colecao
        .where("estado", "==", "ativo")
        .where("apelidoOrdenacao", ">=", chaveInicio)
        .where("apelidoOrdenacao", "<=", chaveFim);

  consulta = consulta
    .orderBy("apelidoOrdenacao", "asc")
    .orderBy("publicId", "asc")
    .limit(tamanho);

  if (depoisDe) consulta = consulta.startAfter(depoisDe);

  const snap = await consulta.get();
  return {
    candidatos: snap.docs.map((d) => ({
      publicId: d.id,
      perfil: d.data() as Record<string, unknown>,
    })),
    ultimo: snap.docs.length > 0 ? snap.docs[snap.docs.length - 1] : null,
    podeHaverMais: snap.docs.length === tamanho,
  };
}

export interface PaginaDeBusca {
  /// Ja filtrados pelo bloqueio, ja cortados no limite, na ordem do banco.
  candidatos: CandidatoCru[];
  /// Os UIDs dos candidatos acima. Ficam nesta camada; a resposta nao os tem.
  uidPorPublicId: Map<string, string>;
  /// Havia mais candidatos VISIVEIS do que o teto. NAO acompanha cursor: ver
  /// `kSemCursor` em app/lib/social/busca_apelido.dart. O cliente refina o
  /// termo; ele nao avanca.
  truncado: boolean;
  sancao: SancaoDoObservador;
  bloqueios: Map<string, BloqueioDeBusca>;
}

/// Varre a faixa ate juntar os candidatos VISIVEIS que a pagina precisa.
///
/// POR QUE UMA VARREDURA, E NAO UMA CONSULTA SO — e o defeito que isto conserta:
///
/// Uma consulta de `limite + 1` documentos, filtrada depois, tem dois vazamentos
/// pelo mesmo buraco. `truncado` sairia calculado sobre o lote BRUTO, entao um
/// bloqueado na posicao `limite + 1` diria "havia mais" num resultado que, para
/// quem procura, esta completo — e o mundo sem aquela pessoa responderia
/// `truncado: false`. Pior: um bloqueado entre os primeiros ROUBARIA A VAGA de
/// um jogador legitimo, que sumiria da resposta por causa de um bloqueio alheio.
///
/// Nos dois casos, alguem que deveria ser invisivel mexe no que se ve. A regra
/// da §8 e mais forte que "nao aparece na lista": para quem procura, o
/// bloqueado NAO EXISTE — e um inexistente nao altera contagem, ordem nem
/// metadado.
///
/// A varredura reproduz isso: continua avançando enquanto o bloqueio for
/// descartando candidatos, ate ter `limite + 1` visiveis (ha mais) ou a faixa
/// acabar (nao ha). O teto de rodadas vem do dominio; ver
/// `kRodadasMaximasDaBusca`.
///
/// A RELACAO DE AMIZADE NAO E LIDA AQUI. Ela so interessa a quem vai aparecer, e
/// ler `friendships` de um candidato que sera escondido seria trabalho jogado
/// fora — alem de fazer a visibilidade parecer depender dela.
export async function varrerVisiveis(
  observadorUid: string,
  chaveInicio: string,
  chaveFim: string,
  exato: boolean,
  limite: number
): Promise<PaginaDeBusca> {
  const porPublicId = new Map<string, CandidatoCru>();
  const uidPorPublicId = new Map<string, string>();
  const bloqueios = new Map<string, BloqueioDeBusca>();
  const visiveis: string[] = [];

  let sancao: SancaoDoObservador = {
    chatSilenciado: false,
    restricaoSocial: false,
  };
  let depoisDe: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  let faixaEsgotada = false;

  for (
    let rodada = 0;
    rodada < LIMITES.rodadasMaximasDaBusca && visiveis.length <= limite;
    rodada++
  ) {
    // O LOTE DOBRA A CADA RODADA, ate um teto por rodada. A primeira le o
    // minimo necessario (`limite + 1`) porque e a rodada que quase sempre
    // resolve; as seguintes so acontecem quando ha bloqueado no caminho, e ai
    // vale ler mais de uma vez do que voltar ao banco varias vezes. Cinco
    // rodadas cobrem centenas de correspondencias em vez de dezenas, o que
    // empurra o teto para longe do alcance de quem tentasse usa-lo como sinal.
    const tamanho = Math.min((limite + 1) * 2 ** rodada, 100);
    const lote = await loteDaFaixa(
      chaveInicio,
      chaveFim,
      exato,
      tamanho,
      depoisDe
    );
    if (lote.candidatos.length === 0) {
      faixaEsgotada = true;
      break;
    }

    const uids = await resolverUids(lote.candidatos.map((c) => c.publicId));
    const ctx = await bloqueiosParaBusca(observadorUid, [...uids.values()]);
    sancao = ctx.sancao;

    const paraFiltrar: {
      publicId: string;
      euBloqueeiOAlvo: boolean;
      alvoMeBloqueou: boolean;
    }[] = [];

    for (const c of lote.candidatos) {
      const alvoUid = uids.get(c.publicId);
      // Perfil publico sem entrada no mapa reverso e dado inconsistente, nao
      // resultado: sem uid nao ha como conferir bloqueio, e exibir alguem cujo
      // bloqueio nao foi conferido e exatamente o que §8 proibe. Descartado
      // ANTES do filtro, e por isso ele tambem nao ocupa vaga.
      if (!alvoUid) {
        logger.warn("perfil publico sem mapa reverso, omitido da busca", {
          publicId: c.publicId,
        });
        continue;
      }
      const b = ctx.porUid.get(alvoUid) ?? {
        euBloqueeiOAlvo: false,
        alvoMeBloqueou: false,
      };
      porPublicId.set(c.publicId, c);
      uidPorPublicId.set(c.publicId, alvoUid);
      bloqueios.set(c.publicId, b);
      paraFiltrar.push({ publicId: c.publicId, ...b });
    }

    // QUEM DECIDE E O DOMINIO, tambem aqui. A varredura sabe ler e paginar; ela
    // nao sabe o que torna alguem invisivel.
    visiveis.push(...dominio.filtrarVisiveisDaBusca(paraFiltrar).publicIds);

    depoisDe = lote.ultimo;
    if (!lote.podeHaverMais) {
      faixaEsgotada = true;
      break;
    }
  }

  // `truncado` sobre os VISIVEIS, nunca sobre o lote bruto. Se a faixa acabou,
  // o que sobrou e tudo o que existe — e ai `truncado` e falso mesmo que muitos
  // candidatos tenham sido escondidos, que e exatamente a propriedade que se
  // quer: o escondido nao mexe no metadado.
  //
  // O LIMITE HONESTO DESTA GARANTIA. Ela e exata sempre que a varredura termina
  // por esgotar a faixa ou por juntar visiveis suficientes — que e todo caso
  // realista. O unico desfecho em que um bloqueado ainda influencia `truncado` e
  // esgotar as CINCO rodadas, e para isso a faixa precisa esconder deste
  // pesquisador algo como 265 a 347 correspondencias (os lotes dobram). Nesse
  // regime o termo casa com centenas de apelidos e "refine" e a resposta util de
  // qualquer forma. Esta residual esta registrada no contrato, e nao escondida
  // atras de um numero.
  const truncado = visiveis.length > limite || !faixaEsgotada;
  const pagina = visiveis.slice(0, limite);

  return {
    candidatos: pagina.map((p) => porPublicId.get(p) as CandidatoCru),
    uidPorPublicId: new Map(pagina.map((p) => [p, uidPorPublicId.get(p) as string])),
    truncado,
    sancao,
    bloqueios: new Map(pagina.map((p) => [p, bloqueios.get(p) as BloqueioDeBusca])),
  };
}

/// `publicId -> uid` para varios ids, numa ida so.
///
/// N leituras por ID (`getAll`), e nao uma consulta: o mapa reverso e uma
/// colecao chaveada pelo proprio publicId, entao nao ha indice a construir nem
/// varredura a fazer. Um `where('publicId','in',[...])` custaria o mesmo e
/// esbarraria no teto de 30 valores da clausula.
export async function resolverUids(
  publicIds: string[]
): Promise<Map<string, string>> {
  const unicos = [...new Set(publicIds.filter((p) => p.length > 0))];
  if (unicos.length === 0) return new Map();
  const docs = await db().getAll(
    ...unicos.map((p) => db().collection(C_INDICE_PUBLICO).doc(p))
  );
  const mapa = new Map<string, string>();
  for (const d of docs) {
    const uid = dados(d)?.uid;
    if (typeof uid === "string") mapa.set(d.id, uid);
  }
  return mapa;
}

/// O bloqueio nos DOIS sentidos entre um observador e varios alvos.
export interface BloqueioDeBusca {
  euBloqueeiOAlvo: boolean;
  alvoMeBloqueou: boolean;
}

/// Estado de moderacao do OBSERVADOR, lido uma vez para a busca inteira.
export interface SancaoDoObservador {
  chatSilenciado: boolean;
  restricaoSocial: boolean;
}

export interface ContextoDeBloqueio {
  sancao: SancaoDoObservador;
  porUid: Map<string, BloqueioDeBusca>;
}

/// Le, de uma vez, o bloqueio nos dois sentidos contra cada alvo e a sancao de
/// quem pesquisa.
///
/// POR QUE NAO CHAMAR `estadoDeContato` N VEZES: cada chamada faria tres
/// leituras, e uma delas — `playerModeration/{observador}` — seria a MESMA em
/// todas. Vinte resultados custariam sessenta leituras, um terco delas
/// repetidas. Aqui sao `2N + 1` refs num unico `getAll`.
///
/// NAO DECIDE NADA. Devolve fatos (existe o documento de bloqueio? a sancao esta
/// vigente?) e quem decide e o dominio, em `projetarResultadosDeBusca` — que
/// chama a MESMA `avaliarContato` da moderacao que o resto do codebase usa.
export async function bloqueiosParaBusca(
  observadorUid: string,
  alvosUids: string[]
): Promise<ContextoDeBloqueio> {
  const usuarios = db().collection(C_USUARIOS);
  const alvos = [...new Set(alvosUids.filter((u) => u.length > 0))];

  const refEstado = db().collection(C_MODERACAO_JOGADOR).doc(observadorUid);
  const refsIda = alvos.map((a) =>
    usuarios.doc(observadorUid).collection(SUB_BLOQUEIOS).doc(a)
  );
  const refsVolta = alvos.map((a) =>
    usuarios.doc(a).collection(SUB_BLOQUEIOS).doc(observadorUid)
  );

  const docs = await db().getAll(refEstado, ...refsIda, ...refsVolta);

  const agora = agoraUtc();
  const e = dados(docs[0]) ?? {};
  const vigente = (campo: string): boolean =>
    typeof e[campo] === "string" && agora < (e[campo] as string);

  const porUid = new Map<string, BloqueioDeBusca>();
  alvos.forEach((alvo, i) => {
    porUid.set(alvo, {
      euBloqueeiOAlvo: docs[1 + i].exists,
      alvoMeBloqueou: docs[1 + alvos.length + i].exists,
    });
  });

  return {
    sancao: {
      chatSilenciado: vigente("chatSilenciadoAte"),
      restricaoSocial:
        vigente("socialRestritoAte") || e.suspensaoPermanente === true,
    },
    porUid,
  };
}

/// O estado canonico da relacao entre um jogador e varios outros.
///
/// Le `friendships/{pairKey}` por ID — a chave do par e funcao dos dois uids, e
/// por isso nao ha consulta a fazer.
export async function relacoesParaBusca(
  observadorUid: string,
  alvosUids: string[]
): Promise<Map<string, RelacaoLida>> {
  const alvos = [...new Set(alvosUids.filter((u) => u.length > 0))];
  const pares = alvos.map((a) =>
    a === observadorUid ? null : dominio.chaveDoPar(observadorUid, a).pairKey
  );
  const comDocumento = pares.filter((p): p is string => p !== null);
  if (comDocumento.length === 0) return new Map();

  const docs = await db().getAll(
    ...comDocumento.map((p) => db().collection(C_AMIZADES).doc(p))
  );
  const porPar = new Map<string, RelacaoLida>();
  for (const d of docs) porPar.set(d.id, lerRelacao(dados(d)));

  const porUid = new Map<string, RelacaoLida>();
  alvos.forEach((alvo, i) => {
    const par = pares[i];
    const rel = par ? porPar.get(par) : undefined;
    if (rel) porUid.set(alvo, rel);
  });
  return porUid;
}

// ===========================================================================
// A TRANSACAO DA RELACAO
// ===========================================================================

export interface ContextoRelacao {
  pairKey: string;
  membros: string[];
  relacao: RelacaoLida;
  contato: EstadoDeContato;
  contadoresChamador: ContadoresSociais;
  contadoresOutro: ContadoresSociais;
  publicIdChamador: string | null;
  publicIdOutro: string | null;
}

export interface ResultadoOperacao {
  veredito: VereditoAmizade;
  estadoFinal: RelacaoLida["estado"];
}

/// Aplica uma acao sobre a relacao entre dois jogadores, sob transacao unica.
///
/// TUDO NUMA TRANSACAO SO: canonico, projecoes dos dois lados e contadores dos
/// dois lados. A alternativa — escrever o canonico e depois "sincronizar" —
/// deixaria uma janela em que A e amigo de B e B nao e amigo de A, que e a
/// relacao fantasma que §17 proibe.
///
/// [decidir] recebe tudo ja lido e devolve o veredito do dominio. Ele NAO escreve:
/// quem escreve e este arquivo, a partir de `veredito.acao`. A separacao garante
/// que toda acao mantenha os mesmos invariantes de contador e projecao, em vez de
/// cada chamador lembrar de atualizar os cinco documentos.
export async function operarRelacao(
  uidChamador: string,
  uidOutro: string,
  decidir: (ctx: ContextoRelacao) => VereditoAmizade
): Promise<ResultadoOperacao> {
  const { pairKey, membros } = dominio.chaveDoPar(uidChamador, uidOutro);
  const refRelacao = db().collection(C_AMIZADES).doc(pairKey);
  const refSocialChamador = db().collection(C_SOCIAL_JOGADOR).doc(uidChamador);
  const refSocialOutro = db().collection(C_SOCIAL_JOGADOR).doc(uidOutro);
  const refIdChamador = db().collection(C_IDENTIDADES).doc(uidChamador);
  const refIdOutro = db().collection(C_IDENTIDADES).doc(uidOutro);

  return db().runTransaction(async (tx) => {
    // TODAS as leituras antes de qualquer escrita — exigencia do Firestore, e
    // tambem a razao de `estadoDeContato` receber a transacao.
    const [relDoc, socChamador, socOutro, idChamador, idOutro] = await tx.getAll(
      refRelacao,
      refSocialChamador,
      refSocialOutro,
      refIdChamador,
      refIdOutro
    );
    const contato = await estadoDeContato(uidChamador, uidOutro, tx);

    // `membros` vem do PAR, e nao do documento, quando o documento nao existe.
    //
    // Nao e detalhe de leitura: quem sao os dois membros de uma relacao e funcao
    // dos dois UIDs, nao do documento — que pode nem ter nascido, ou ja ter sido
    // apagado por uma remocao anterior. Confiar so no documento fazia
    // `avaliarRemocao` receber `ehMembro: false` na SEGUNDA remocao e responder
    // `naoEDestinatario` ("voce esta desfazendo amizade alheia") em vez da
    // repeticao idempotente que §17 e §26 exigem.
    const lida = lerRelacao(dados(relDoc));
    const relacao =
      lida.membros.length === 2 ? lida : { ...lida, membros };
    const publicIdChamador = dados(idChamador)?.publicId;
    const publicIdOutro = dados(idOutro)?.publicId;

    const ctx: ContextoRelacao = {
      pairKey,
      membros,
      relacao,
      contato,
      contadoresChamador: lerContadores(dados(socChamador)),
      contadoresOutro: lerContadores(dados(socOutro)),
      publicIdChamador:
        typeof publicIdChamador === "string" ? publicIdChamador : null,
      publicIdOutro: typeof publicIdOutro === "string" ? publicIdOutro : null,
    };

    const veredito = decidir(ctx);
    if (!veredito.aceita) {
      return { veredito, estadoFinal: relacao.estado };
    }

    const agora = agoraUtc();
    const perfis =
      veredito.acao === "aceitar" || veredito.acao === "aceitarInversa"
        ? await lerPerfisPublicos([
            ctx.publicIdChamador ?? "",
            ctx.publicIdOutro ?? "",
          ])
        : new Map<string, Record<string, unknown>>();

    switch (veredito.acao) {
      case "criarSolicitacao":
        escreverSolicitacao(tx, {
          pairKey,
          membros,
          solicitanteUid: uidChamador,
          destinatarioUid: uidOutro,
          publicIdSolicitante: ctx.publicIdChamador ?? "",
          publicIdDestinatario: ctx.publicIdOutro ?? "",
          agora,
        });
        tx.set(
          refSocialChamador,
          {
            uid: uidChamador,
            solicitacoesEnviadas: ctx.contadoresChamador.solicitacoesEnviadas + 1,
            atualizadoEm: agora,
          },
          { merge: true }
        );
        return { veredito, estadoFinal: "pendente" as const };

      case "aceitar":
      case "aceitarInversa": {
        // Quem enviou a pendencia continua sendo o solicitante gravado — mesmo
        // no aceite cruzado, em que quem "aceita" e quem chamou pedindo amizade.
        const solicitante = relacao.solicitanteUid ?? uidOutro;
        const outro = solicitante === uidChamador ? uidOutro : uidChamador;

        tx.set(
          refRelacao,
          {
            pairKey,
            membros,
            estado: "amigos",
            solicitanteUid: solicitante,
            destinatarioUid: outro,
            solicitadaEm: relacao.solicitadaEm ?? agora,
            amigosDesde: agora,
            publicIds: {
              [uidChamador]: ctx.publicIdChamador ?? "",
              [uidOutro]: ctx.publicIdOutro ?? "",
            },
            esquema: LIMITES.esquema,
          },
          { merge: true }
        );

        // As solicitacoes deixam de existir nos dois lados.
        tx.delete(refSolicitacao(uidChamador, uidOutro));
        tx.delete(refSolicitacao(uidOutro, uidChamador));

        escreverProjecaoAmigo(tx, {
          donoUid: uidChamador,
          outroUid: uidOutro,
          publicIdOutro: ctx.publicIdOutro ?? "",
          apelidoOrdenacao: ordenacaoDe(perfis, ctx.publicIdOutro),
          amigosDesde: agora,
        });
        escreverProjecaoAmigo(tx, {
          donoUid: uidOutro,
          outroUid: uidChamador,
          publicIdOutro: ctx.publicIdChamador ?? "",
          apelidoOrdenacao: ordenacaoDe(perfis, ctx.publicIdChamador),
          amigosDesde: agora,
        });

        // Contadores: +1 amigo para os dois, -1 pendente enviada para quem
        // enviou. `Math.max(0, ...)` em vez de `increment(-1)` porque o valor foi
        // lido nesta transacao: assim um contador que ja estivesse errado se
        // corrige em vez de afundar para negativo.
        const socDoSolicitante =
          solicitante === uidChamador ? ctx.contadoresChamador : ctx.contadoresOutro;
        tx.set(
          db().collection(C_SOCIAL_JOGADOR).doc(solicitante),
          {
            uid: solicitante,
            amigos: socDoSolicitante.amigos + 1,
            solicitacoesEnviadas: Math.max(
              0,
              socDoSolicitante.solicitacoesEnviadas - 1
            ),
            atualizadoEm: agora,
          },
          { merge: true }
        );
        const socDoOutro =
          solicitante === uidChamador ? ctx.contadoresOutro : ctx.contadoresChamador;
        tx.set(
          db().collection(C_SOCIAL_JOGADOR).doc(outro),
          { uid: outro, amigos: socDoOutro.amigos + 1, atualizadoEm: agora },
          { merge: true }
        );

        return { veredito, estadoFinal: "amigos" as const };
      }

      case "apagar": {
        const eraAmizade = relacao.estado === "amigos";
        tx.delete(refRelacao);
        tx.delete(refSolicitacao(uidChamador, uidOutro));
        tx.delete(refSolicitacao(uidOutro, uidChamador));
        tx.delete(refAmigo(uidChamador, uidOutro));
        tx.delete(refAmigo(uidOutro, uidChamador));

        if (eraAmizade) {
          tx.set(
            refSocialChamador,
            {
              uid: uidChamador,
              amigos: Math.max(0, ctx.contadoresChamador.amigos - 1),
              atualizadoEm: agora,
            },
            { merge: true }
          );
          tx.set(
            refSocialOutro,
            {
              uid: uidOutro,
              amigos: Math.max(0, ctx.contadoresOutro.amigos - 1),
              atualizadoEm: agora,
            },
            { merge: true }
          );
        } else if (relacao.solicitanteUid) {
          const solicitante = relacao.solicitanteUid;
          const soc =
            solicitante === uidChamador
              ? ctx.contadoresChamador
              : ctx.contadoresOutro;
          tx.set(
            db().collection(C_SOCIAL_JOGADOR).doc(solicitante),
            {
              uid: solicitante,
              solicitacoesEnviadas: Math.max(0, soc.solicitacoesEnviadas - 1),
              atualizadoEm: agora,
            },
            { merge: true }
          );
        }
        return { veredito, estadoFinal: "nenhuma" as const };
      }

      case "nenhuma":
        return { veredito, estadoFinal: relacao.estado };
    }
  });
}

function ordenacaoDe(
  perfis: Map<string, Record<string, unknown>>,
  publicId: string | null
): string {
  const p = publicId ? perfis.get(publicId) : undefined;
  return typeof p?.apelidoOrdenacao === "string" ? p.apelidoOrdenacao : "";
}

function refSolicitacao(donoUid: string, outroUid: string) {
  return db()
    .collection(C_USUARIOS)
    .doc(donoUid)
    .collection(SUB_SOLICITACOES)
    .doc(outroUid);
}

function refAmigo(donoUid: string, outroUid: string) {
  return db()
    .collection(C_USUARIOS)
    .doc(donoUid)
    .collection(SUB_AMIGOS)
    .doc(outroUid);
}

function escreverSolicitacao(
  tx: Transaction,
  e: {
    pairKey: string;
    membros: string[];
    solicitanteUid: string;
    destinatarioUid: string;
    publicIdSolicitante: string;
    publicIdDestinatario: string;
    agora: string;
  }
): void {
  tx.set(db().collection(C_AMIZADES).doc(e.pairKey), {
    pairKey: e.pairKey,
    membros: e.membros,
    estado: "pendente",
    solicitanteUid: e.solicitanteUid,
    destinatarioUid: e.destinatarioUid,
    solicitadaEm: e.agora,
    amigosDesde: null,
    publicIds: {
      [e.solicitanteUid]: e.publicIdSolicitante,
      [e.destinatarioUid]: e.publicIdDestinatario,
    },
    esquema: LIMITES.esquema,
  });

  tx.set(refSolicitacao(e.solicitanteUid, e.destinatarioUid), {
    direcao: "enviada",
    publicId: e.publicIdDestinatario,
    solicitadaEm: e.agora,
    esquema: LIMITES.esquema,
  });
  tx.set(refSolicitacao(e.destinatarioUid, e.solicitanteUid), {
    direcao: "recebida",
    publicId: e.publicIdSolicitante,
    solicitadaEm: e.agora,
    esquema: LIMITES.esquema,
  });
}

function escreverProjecaoAmigo(
  tx: Transaction,
  e: {
    donoUid: string;
    outroUid: string;
    publicIdOutro: string;
    apelidoOrdenacao: string;
    amigosDesde: string;
  }
): void {
  tx.set(refAmigo(e.donoUid, e.outroUid), {
    publicId: e.publicIdOutro,
    // Chave de ORDENACAO apenas. O apelido exibido nunca vem daqui: ele e lido
    // de `publicProfiles` na hora da consulta.
    apelidoOrdenacao: e.apelidoOrdenacao,
    amigosDesde: e.amigosDesde,
    esquema: LIMITES.esquema,
  });
}

// ===========================================================================
// LEITURAS DE LISTA
// ===========================================================================

export interface PaginaBruta {
  itens: { publicId: string; desde: string | null }[];
  proximoCursor: string | null;
}

/// Uma pagina da lista de amigos, ordenada por apelido normalizado e publicId
/// (§22).
///
/// A ordenacao acontece no BANCO, sobre a projecao, e nao em memoria: sem
/// indice, ordenar por apelido exigiria carregar as 200 amizades a cada pagina.
export async function paginaDeAmigos(
  uid: string,
  cursor: string | null,
  limite: number
): Promise<PaginaBruta> {
  let consulta = db()
    .collection(C_USUARIOS)
    .doc(uid)
    .collection(SUB_AMIGOS)
    .orderBy("apelidoOrdenacao", "asc")
    .orderBy("publicId", "asc")
    .limit(limite + 1); // +1 so para saber se ha proxima pagina

  const partes = cursor ? decodificarCursor(cursor) : null;
  if (partes) consulta = consulta.startAfter(partes[0], partes[1]);

  const snap = await consulta.get();
  const docs = snap.docs.slice(0, limite);
  const temMais = snap.docs.length > limite;
  const ultimo = docs[docs.length - 1];

  return {
    itens: docs.map((d) => ({
      publicId: `${d.data().publicId ?? ""}`,
      desde: typeof d.data().amigosDesde === "string" ? d.data().amigosDesde : null,
    })),
    proximoCursor:
      temMais && ultimo
        ? codificarCursor(
            `${ultimo.data().apelidoOrdenacao ?? ""}`,
            `${ultimo.data().publicId ?? ""}`
          )
        : null,
  };
}

/// Uma pagina de solicitacoes, por direcao (§23 e §24).
///
/// Ordenada por `solicitadaEm` DECRESCENTE, e nao por apelido: §25 proibe teto de
/// solicitacoes RECEBIDAS, entao esta lista e ilimitada e nao caberia num
/// carregamento unico. Recencia tambem e a ordem que o jogador espera numa caixa
/// de entrada.
export async function paginaDeSolicitacoes(
  uid: string,
  direcao: "enviada" | "recebida",
  cursor: string | null,
  limite: number
): Promise<PaginaBruta> {
  let consulta = db()
    .collection(C_USUARIOS)
    .doc(uid)
    .collection(SUB_SOLICITACOES)
    .where("direcao", "==", direcao)
    .orderBy("solicitadaEm", "desc")
    .orderBy("publicId", "asc")
    .limit(limite + 1);

  const partes = cursor ? decodificarCursor(cursor) : null;
  if (partes) consulta = consulta.startAfter(partes[0], partes[1]);

  const snap = await consulta.get();
  const docs = snap.docs.slice(0, limite);
  const temMais = snap.docs.length > limite;
  const ultimo = docs[docs.length - 1];

  return {
    itens: docs.map((d) => ({
      publicId: `${d.data().publicId ?? ""}`,
      desde:
        typeof d.data().solicitadaEm === "string" ? d.data().solicitadaEm : null,
    })),
    proximoCursor:
      temMais && ultimo
        ? codificarCursor(
            `${ultimo.data().solicitadaEm ?? ""}`,
            `${ultimo.data().publicId ?? ""}`
          )
        : null,
  };
}

/// O cursor e OPACO para o cliente: base64 de duas partes.
///
/// Opaco de proposito. Se ele fosse `{apelido, publicId}` legivel, um cliente
/// passaria a montar cursores a mao e qualquer mudanca de ordenacao quebraria
/// aplicativos ja instalados.
function codificarCursor(a: string, b: string): string {
  return Buffer.from(JSON.stringify([a, b]), "utf8").toString("base64url");
}

function decodificarCursor(cursor: string): [string, string] | null {
  try {
    const bruto = JSON.parse(
      Buffer.from(cursor, "base64url").toString("utf8")
    ) as unknown;
    if (
      Array.isArray(bruto) &&
      bruto.length === 2 &&
      typeof bruto[0] === "string" &&
      typeof bruto[1] === "string"
    ) {
      return [bruto[0], bruto[1]];
    }
  } catch {
    // Cursor corrompido ou forjado. Tratado como "primeira pagina" em vez de
    // erro: o pior desfecho de um cursor invalido e o jogador recomecar a lista,
    // e devolver 500 aqui daria a quem tenta forjar um sinal de que acertou o
    // formato.
  }
  return null;
}

// ===========================================================================
// FAXINA POR BLOQUEIO (§18)
// ===========================================================================

/// Desfaz amizade e solicitacoes entre dois jogadores por causa de um bloqueio.
///
/// §18: "ao bloquear alguem que ja e amigo: desfazer a amizade; cancelar
/// solicitacoes pendentes nos dois sentidos."
///
/// NAO E A UNICA DEFESA, e nao deveria ser. Toda operacao social ja consulta o
/// bloqueio dentro da propria transacao, entao a janela entre o bloqueio e esta
/// faxina nao e explorável: durante ela, a amizade existe no banco mas nenhuma
/// acao social passa. A faxina serve para que o estado do banco reflita a
/// realidade, e nao para produzi-la.
export async function desfazerPorBloqueio(
  bloqueadorUid: string,
  bloqueadoUid: string
): Promise<{ desfez: boolean }> {
  const resultado = await operarRelacao(bloqueadorUid, bloqueadoUid, (ctx) => {
    if (ctx.relacao.estado === "nenhuma") {
      return {
        aceita: false,
        recusa: null,
        acao: "nenhuma",
        repeticao: true,
      } as VereditoAmizade;
    }
    // Veredito montado aqui, e nao pedido ao dominio, porque esta nao e uma acao
    // de JOGADOR: e consequencia de uma decisao ja tomada por outro dominio. O
    // dominio social recusaria (o bloqueio ja esta em vigor, `contatoPermitido`
    // e falso) — e recusar seria justamente o errado.
    return {
      aceita: true,
      recusa: null,
      acao: "apagar",
      repeticao: false,
    } as VereditoAmizade;
  });
  return { desfez: resultado.veredito.aceita };
}

// ===========================================================================
// RECONCILIACAO (§20)
// ===========================================================================

/// Reconstroi as projecoes de UM jogador a partir da fonte de verdade.
///
/// Existe porque §20 pede o "mecanismo de reparo/reconciliacao" quando ha
/// projecoes. O unico caminho que pode deixa-las velhas e o leque de troca de
/// apelido (ver o cabecalho deste arquivo); esta funcao e a resposta a ele, e
/// tambem a rede para qualquer defeito futuro.
///
/// Le SO o canonico e reescreve as projecoes. Se as duas discordarem, o canonico
/// vence — e por isso ele e o canonico.
export async function reconciliarProjecoes(
  uid: string
): Promise<{ amigos: number; solicitacoes: number }> {
  const snap = await db()
    .collection(C_AMIZADES)
    .where("membros", "array-contains", uid)
    .get();

  const perfisNecessarios: string[] = [];
  for (const d of snap.docs) {
    const r = lerRelacao(d.data() as Record<string, unknown>);
    const outro = r.membros.find((m) => m !== uid);
    if (outro && r.publicIds[outro]) perfisNecessarios.push(r.publicIds[outro]);
  }
  const perfis = await lerPerfisPublicos(perfisNecessarios);

  const lote = db().batch();
  let amigos = 0;
  let solicitacoes = 0;

  for (const d of snap.docs) {
    const r = lerRelacao(d.data() as Record<string, unknown>);
    const outro = r.membros.find((m) => m !== uid);
    if (!outro) continue;
    const publicIdOutro = r.publicIds[outro] ?? "";

    if (r.estado === "amigos") {
      amigos++;
      lote.set(refAmigo(uid, outro), {
        publicId: publicIdOutro,
        apelidoOrdenacao: ordenacaoDe(perfis, publicIdOutro),
        amigosDesde: r.amigosDesde,
        esquema: LIMITES.esquema,
      });
      lote.delete(refSolicitacao(uid, outro));
    } else if (r.estado === "pendente") {
      solicitacoes++;
      lote.set(refSolicitacao(uid, outro), {
        direcao: r.solicitanteUid === uid ? "enviada" : "recebida",
        publicId: publicIdOutro,
        solicitadaEm: r.solicitadaEm,
        esquema: LIMITES.esquema,
      });
      lote.delete(refAmigo(uid, outro));
    }
  }

  // Os contadores tambem sao derivados: reconstrui-los aqui e o que impede que
  // um teto fique travado por um contador que ficou alto sem relacao real.
  lote.set(
    db().collection(C_SOCIAL_JOGADOR).doc(uid),
    {
      uid,
      amigos,
      solicitacoesEnviadas: snap.docs.filter((d) => {
        const r = lerRelacao(d.data() as Record<string, unknown>);
        return r.estado === "pendente" && r.solicitanteUid === uid;
      }).length,
      atualizadoEm: agoraUtc(),
    },
    { merge: true }
  );

  await lote.commit();
  return { amigos, solicitacoes };
}

/// Propaga a nova chave de ordenacao do apelido para as projecoes dos amigos.
///
/// O UNICO leque de escrita deste codebase, e ele e limitado pelo teto de §25:
/// no maximo 200 documentos, um lote so. Fora de transacao de proposito — travar
/// 200 documentos para reordenar uma lista seria caro e nada aqui e critico:
/// falhar deixa a ordenacao velha, nunca o nome errado.
export async function propagarApelidoParaAmigos(
  uid: string,
  apelidoOrdenacao: string
): Promise<number> {
  const snap = await db()
    .collection(C_AMIZADES)
    .where("membros", "array-contains", uid)
    .where("estado", "==", "amigos")
    .limit(LIMITES.limiteAmigos)
    .get();

  if (snap.empty) return 0;

  const lote = db().batch();
  let tocados = 0;
  for (const d of snap.docs) {
    const r = lerRelacao(d.data() as Record<string, unknown>);
    const outro = r.membros.find((m) => m !== uid);
    if (!outro) continue;
    lote.update(refAmigo(outro, uid), { apelidoOrdenacao });
    tocados++;
  }
  if (tocados > 0) await lote.commit();
  return tocados;
}
