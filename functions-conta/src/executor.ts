// executor.ts — QUEM EXECUTA. A repartição de papeis dos outros codebases:
//
//   QUEM DECIDE  -> inventario.ts (o que acontece com cada dado e por que) e
//                   plano.ts (em que ordem, e quando recusar).
//   QUEM EXECUTA -> este arquivo. Firestore, Authentication, paginacao, lote.
//   QUEM ATENDE  -> index.ts. Autenticacao, forma do payload, traducao de erro.
//
// Se um `if` de POLITICA aparecer aqui — "denuncia a gente guarda, amizade a
// gente apaga" — ele esta no lugar errado: isso e `inventario.ts`.
//
// ===========================================================================
// TRES DISCIPLINAS QUE VALEM PARA TODA FUNCAO DESTE ARQUIVO
// ===========================================================================
//
// 1. IDEMPOTENCIA POR CONSTRUCAO, e nao por checagem. Apagar documento que nao
//    existe e sucesso no Firestore. `set` com merge do mesmo conteudo converge.
//    `FieldValue.delete()` num campo ja ausente nao e erro. Nenhuma funcao aqui
//    pergunta "ja fiz isso?" antes de fazer — perguntar custaria uma leitura e
//    ainda assim teria corrida.
//
// 2. PAGINACAO SEMPRE. Uma conta antiga pode ter milhares de documentos de
//    historico. `.get()` sem limite numa subcolecao dessas traz tudo para a
//    memoria da instancia e estoura. Toda varredura aqui e por pagina, com o
//    lote commitado a cada pagina — o que tambem e o que faz uma execucao
//    interrompida ter deixado progresso real para tras.
//
// 3. NADA DE `recursiveDelete`. Ele existe no Admin SDK e resolveria
//    `users/{uid}` inteiro numa linha — e e exatamente por isso que nao serve:
//    apagaria as oito subcolecoes SEM PASSAR PELA MATRIZ, o que faria uma
//    subcolecao futura ser apagada por omissao em vez de por decisao. O custo de
//    apagar item a item e a garantia de que cada apagamento foi classificado.

import { getAuth } from "firebase-admin/auth";
import {
  FieldValue,
  Firestore,
  Query,
  getFirestore,
} from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import {
  APELIDO_ANONIMO,
  ESTADO_PERFIL_REMOVIDO,
  ItemDoInventario,
} from "./inventario";
import {
  ESQUEMA_DIARIO,
  ESTADO_EXCLUSAO,
  Diario,
  FalhaDeEtapa,
  RESUMO_VAZIO,
  ResumoDoEncerramento,
  comEtapaConcluida,
  decidirExecucao,
  estadoFinal,
  fundirResumo,
} from "./diario";
import {
  ETAPAS,
  Etapa,
  InscricaoPendente,
  itensDaEtapa,
} from "./plano";

export const C_DIARIO = "accountDeletions";

/// Tamanho da pagina de varredura. Abaixo do teto de 500 escritas por lote do
/// Firestore com folga: uma pagina pode gerar mais de uma escrita por documento
/// (apagar o canonico e o espelho, por exemplo).
const PAGINA = 200;

export const db = (): Firestore => getFirestore();
export const agoraIso = (): string => new Date().toISOString();

// ===========================================================================
// LEITURAS QUE ANTECEDEM A DECISAO
// ===========================================================================

/// O `publicId` do jogador, ou `null` se ele nunca teve identidade publica.
///
/// `null` E CAMINHO NORMAL, e nao falha: uma conta criada e abandonada antes de
/// a sessao chamar `obterMinhaIdentidade` nao tem identidade nenhuma. Tratar
/// isso como erro deixaria justamente as contas mais faceis de apagar sem poder
/// ser apagadas.
export async function lerPublicId(uid: string): Promise<string | null> {
  const doc = await db().collection("playerIdentities").doc(uid).get();
  const valor = doc.data()?.publicId;
  return typeof valor === "string" && valor.length > 0 ? valor : null;
}

/// Inscricoes em torneio deste jogador, com o status da EDICAO junto.
///
/// Os dois lados sao necessarios porque `plano.decidirElegibilidade` recusa por
/// inscricao ativa em edicao NAO ENCERRADA — inscricao ativa em edicao antiga e
/// so historico e nao trava nada.
///
/// A consulta e collection-group porque `registrations` vive sob cada edicao. O
/// indice composto (`userId`, `status`, `inscritoEm`) ja existe em
/// firestore.indexes.json com escopo COLLECTION_GROUP, e serve esta consulta
/// pelo prefixo `userId`.
export async function lerInscricoes(uid: string): Promise<InscricaoPendente[]> {
  const snap = await db()
    .collectionGroup("registrations")
    .where("userId", "==", uid)
    .get();

  const edicoes = new Map<string, string>();
  const pendentes: InscricaoPendente[] = [];

  for (const doc of snap.docs) {
    // O caminho e tournaments/{t}/editions/{e}/registrations/{uid}: a referencia
    // da edicao e o avo do documento.
    const refEdicao = doc.ref.parent.parent;
    if (!refEdicao) continue;

    const chave = refEdicao.path;
    if (!edicoes.has(chave)) {
      const edicao = await refEdicao.get();
      const status = edicao.data()?.status;
      edicoes.set(chave, typeof status === "string" ? status : "desconhecido");
    }

    pendentes.push({
      tournamentId: refEdicao.parent.parent?.id ?? "",
      editionId: refEdicao.id,
      status: typeof doc.data()?.status === "string" ? doc.data()!.status : "desconhecido",
      statusEdicao: edicoes.get(chave) as string,
    });
  }

  return pendentes;
}

// ===========================================================================
// PRIMITIVAS DE ESCRITA
// ===========================================================================

/// Apaga tudo o que a consulta devolver, pagina a pagina.
///
/// Devolve quantos documentos sairam — numero que vai para o log e, em dois
/// casos, para o resumo do diario.
async function apagarPorConsulta(consulta: Query): Promise<number> {
  let total = 0;
  for (;;) {
    const pagina = await consulta.limit(PAGINA).get();
    if (pagina.empty) return total;

    const lote = db().batch();
    for (const doc of pagina.docs) lote.delete(doc.ref);
    await lote.commit();
    total += pagina.size;

    // Pagina incompleta significa que era a ultima. Pedir mais uma so para ver
    // vazio custaria uma leitura por varredura, em todas as varreduras.
    if (pagina.size < PAGINA) return total;
  }
}

/// Corta campos de todos os documentos que a consulta devolver.
///
/// `FieldValue.delete()` e nao `null`: o campo some do documento, em vez de
/// ficar presente valendo nulo. A diferenca importa em `compras`, onde
/// `titularDoToken` testa `if (!dados.uid)` — as duas formas passariam no teste,
/// mas so a ausencia deixa o documento sem a coluna, que e o que "desvincular"
/// quer dizer.
async function desvincularPorConsulta(
  consulta: Query,
  campos: readonly string[],
  marca: Record<string, unknown>
): Promise<number> {
  const corte: Record<string, unknown> = { ...marca };
  for (const campo of campos) corte[campo] = FieldValue.delete();

  let total = 0;
  let ultimo: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    // `startAfter` e obrigatorio aqui, e a razao e sutil: diferente do
    // apagamento, o documento CONTINUA existindo depois de tratado e continua
    // casando com a consulta se ela filtrar pelo campo que acabou de sair —
    // ou nao, se ja saiu. Sem cursor, a paginacao ou repetiria ou pularia.
    let pagina = consulta.limit(PAGINA);
    if (ultimo) pagina = pagina.startAfter(ultimo);
    const snap = await pagina.get();
    if (snap.empty) return total;

    const lote = db().batch();
    for (const doc of snap.docs) lote.update(doc.ref, corte);
    await lote.commit();

    total += snap.size;
    ultimo = snap.docs[snap.docs.length - 1];
    if (snap.size < PAGINA) return total;
  }
}

/// Remove UM valor de um campo-array, sem tocar no resto da lista.
///
/// Existe porque `desvincularPorConsulta` apaga o CAMPO, e aqui o campo e
/// compartilhado: `chatChannels.participantes` guarda os quatro da mesa. Apagar
/// a lista removeria os outros tres junto com o excluido.
async function removerDeArray(
  consulta: Query,
  campo: string,
  valor: string
): Promise<number> {
  let total = 0;
  for (;;) {
    // Sem cursor, e de proposito: o documento tratado deixa de casar com o
    // `array-contains`, entao a proxima pagina comeca ja sem ele.
    const pagina = await consulta.limit(PAGINA).get();
    if (pagina.empty) return total;

    const lote = db().batch();
    for (const doc of pagina.docs) {
      lote.update(doc.ref, { [campo]: FieldValue.arrayRemove(valor) });
    }
    await lote.commit();

    total += pagina.size;
    if (pagina.size < PAGINA) return total;
  }
}

/// Apaga uma subcolecao inteira de um documento conhecido.
async function apagarSubcolecao(
  caminhoDoDono: string,
  sub: string
): Promise<number> {
  return apagarPorConsulta(db().doc(caminhoDoDono).collection(sub));
}

// ===========================================================================
// AS ETAPAS
// ===========================================================================

/// O que uma etapa precisa saber, e o que ela pode contar de volta.
export interface Contexto {
  readonly uid: string;
  readonly publicId: string | null;
  /// Preenchido pela etapa `social` e consumido pelas seguintes. E o unico
  /// estado que atravessa etapas, e ele NAO e persistido: numa retomada, a
  /// etapa `social` ja terá sido concluida e os espelhos ja apagados.
  amigos: string[];
  resumo: Partial<ResumoDoEncerramento>;
}

type Execucao = (ctx: Contexto) => Promise<void>;

/// Trancar a conta antes de mexer nos dados.
///
/// As DUAS chamadas importam, e uma nao substitui a outra. `disabled: true`
/// impede uma autenticacao NOVA; `revokeRefreshTokens` invalida as que ja
/// existem. So a primeira deixaria um token de acesso valido continuar
/// funcionando por ate uma hora — tempo de sobra para recriar, por acidente ou
/// por teimosia do aplicativo em segundo plano, a projecao que a etapa seguinte
/// apaga.
async function trancar(ctx: Contexto): Promise<void> {
  const auth = getAuth();
  await auth.updateUser(ctx.uid, { disabled: true });
  await auth.revokeRefreshTokens(ctx.uid);
}

/// Amizades: o canonico, os dois espelhos e os contadores.
async function apagarSocial(ctx: Contexto): Promise<void> {
  // A LEITURA VEM PRIMEIRO, e e ela que torna os espelhos alcancaveis. Ver o
  // item 3 do cabecalho de plano.ts.
  const relacoes = await db()
    .collection("friendships")
    .where("membros", "array-contains", ctx.uid)
    .get();

  const outros = new Set<string>();
  for (const doc of relacoes.docs) {
    const membros = doc.data()?.membros;
    if (!Array.isArray(membros)) continue;
    for (const m of membros) {
      if (typeof m === "string" && m !== ctx.uid) outros.add(m);
    }
  }
  ctx.amigos = [...outros];
  ctx.resumo = { ...ctx.resumo, amizades: relacoes.size };

  // Os espelhos, na conta de cada amigo. Em lotes, porque uma conta no teto de
  // 200 amigos produz 400 escritas.
  const usuarios = db().collection("users");
  for (let i = 0; i < ctx.amigos.length; i += PAGINA) {
    const fatia = ctx.amigos.slice(i, i + PAGINA);
    const lote = db().batch();
    for (const outro of fatia) {
      lote.delete(usuarios.doc(outro).collection("friends").doc(ctx.uid));
      lote.delete(usuarios.doc(outro).collection("friendRequests").doc(ctx.uid));
    }
    await lote.commit();
  }

  // As projecoes do proprio, e so entao o canonico. A ordem inversa deixaria,
  // numa falha no meio, projecoes sem canonico — que e o estado que
  // `reconciliarPerfilSocial` interpreta como "reconstruir para zero", e nao
  // como "sobrou lixo".
  await apagarSubcolecao(`users/${ctx.uid}`, "friends");
  await apagarSubcolecao(`users/${ctx.uid}`, "friendRequests");

  for (let i = 0; i < relacoes.docs.length; i += PAGINA) {
    const lote = db().batch();
    for (const doc of relacoes.docs.slice(i, i + PAGINA)) lote.delete(doc.ref);
    await lote.commit();
  }

  await db().collection("playerSocial").doc(ctx.uid).delete();
}

/// Bloqueios, silenciamentos e comprovantes — dos dois lados.
async function apagarModeracao(ctx: Contexto): Promise<void> {
  await apagarSubcolecao(`users/${ctx.uid}`, "blocks");
  await apagarSubcolecao(`users/${ctx.uid}`, "mutes");
  await apagarSubcolecao(`users/${ctx.uid}`, "reportReceipts");

  // As referencias a ele nas listas dos OUTROS. Collection-group, pelos campos
  // redundantes que as duas colecoes ja gravam — `bloqueadoUid` pela Function de
  // bloqueio, `alvoUid` pelo proprio cliente (a regra exige que ele bata com o
  // id do documento).
  await apagarPorConsulta(
    db().collectionGroup("blocks").where("bloqueadoUid", "==", ctx.uid)
  );
  await apagarPorConsulta(
    db().collectionGroup("mutes").where("alvoUid", "==", ctx.uid)
  );

  // CHAT — e as duas colecoes recebem tratamento DIFERENTE de proposito.
  //
  // MENSAGEM e fala de UMA pessoa: o conteudo e dela, e apagar as dela nao
  // derruba a conversa de ninguem — as dos outros participantes continuam,
  // porque a consulta e por `autorUid`.
  await apagarPorConsulta(
    db().collection("chatMessages").where("autorUid", "==", ctx.uid)
  );

  // CANAL e da MESA, e a mesa e de mais gente. Apaga-lo porque um participante
  // saiu destruiria o canal dos outros tres. Sai so o UID de `participantes`; o
  // canal continua enquanto tiver finalidade compartilhada.
  //
  // `arrayRemove` e nao `FieldValue.delete()`: o campo e uma lista compartilhada,
  // e apagar a lista inteira removeria os OUTROS participantes junto — que e
  // exatamente o "registro compartilhado apagado por consequencia" que a decisao
  // de retencao proibe.
  await removerDeArray(
    db().collection("chatChannels").where("participantes", "array-contains", ctx.uid),
    "participantes",
    ctx.uid
  );

  // FREIO DE RAJADA. `chatRitmo/{uid}` e o contador de anti-spam da Comunicacao
  // Controlada — `recentes`, `bloqueadoAteMs`, `recusasSeguidas` —, e a chave E o
  // uid: nao ha consulta, e um `delete` de documento que pode nao existir e
  // idempotente por construcao no Firestore.
  //
  // POR ULTIMO NA ETAPA, e nao por gosto: as varreduras acima podem demorar, e o
  // unico produtor do documento (`executarEnvioDeMensagem`, em
  // functions-moderacao) grava nos DOIS desfechos de uma chamada em voo.
  // Apagar antes da varredura deixaria a janela aberta por mais tempo.
  //
  // ISTO NAO E APAGAR PUNICAO: quem decide isso e `inventario.ts`, e a razao
  // esta la. `playerModeration`, `sanctions` e `reports` seguem RETIDOS, e este
  // documento nao e nenhum dos tres.
  await db().collection("chatRitmo").doc(ctx.uid).delete();
}

async function apagarRastreabilidade(ctx: Contexto): Promise<void> {
  await apagarSubcolecao(`users/${ctx.uid}`, "matchHistory");

  // CONQUISTAS. Diferente de `matches` e do ledger, nenhuma pontuacao de
  // terceiro depende de conquista alheia — apagar nao reescreve o passado de
  // ninguem.
  //
  // A SUBCOLECAO ANTES DA RAIZ, pelo mesmo motivo do `interno` do billing:
  // `delete` num documento NAO apaga as subcolecoes dele, e a raiz apagada
  // primeiro deixaria `items` viva e orfa.
  await apagarSubcolecao(`playerAchievements/${ctx.uid}`, "items");
  await db().collection("playerAchievements").doc(ctx.uid).delete();
}

async function apagarColecoes(ctx: Contexto): Promise<void> {
  await apagarSubcolecao(`users/${ctx.uid}`, "inventory");
  await apagarSubcolecao(`users/${ctx.uid}`, "campaign_claims");

  // Elegibilidade: chave derivada, porque o documento nao tem campo por onde
  // filtrar. `campaigns` e configuracao e tem poucas linhas.
  const campanhas = await db().collection("campaigns").get();
  if (!campanhas.empty) {
    const lote = db().batch();
    for (const c of campanhas.docs) {
      lote.delete(c.ref.collection("eligible").doc(ctx.uid));
    }
    await lote.commit();
  }
}

/// Ranking: a linha fica, o rosto sai.
async function anonimizarRanking(ctx: Contexto): Promise<void> {
  const anonimo = {
    apelido: APELIDO_ANONIMO,
    avatar: "",
    anonimizadoEm: agoraIso(),
  };

  // `rankingStandings` nao tem consulta por uid — a chave e `seasonId|uid`, e a
  // lista de temporadas e a fonte. `rankingSeasons` e pequena e finita, entao
  // remontar as chaves e mais barato (e mais exato) do que varrer a colecao de
  // classificacao inteira.
  const temporadas = await db().collection("rankingSeasons").get();
  for (let i = 0; i < temporadas.docs.length; i += PAGINA) {
    const fatia = temporadas.docs.slice(i, i + PAGINA);
    const refs = fatia.map((t) =>
      db().collection("rankingStandings").doc(`${t.id}|${ctx.uid}`)
    );
    // `getAll` e nao um `update` cego: atualizar documento inexistente falha o
    // lote inteiro, e a maioria das temporadas nao tem linha deste jogador.
    const docs = await db().getAll(...refs);
    const existentes = docs.filter((d) => d.exists);
    if (existentes.length === 0) continue;

    const lote = db().batch();
    for (const d of existentes) lote.update(d.ref, anonimo);
    await lote.commit();
  }

  const jogador = db().collection("rankingPlayers").doc(ctx.uid);
  if ((await jogador.get()).exists) await jogador.update(anonimo);

  // Hall: hoje sem produtor neste repositorio (a colecao existe nas regras e
  // nenhuma Function escreve). A varredura fica porque a matriz classificou o
  // item, e no dia em que o produtor aparecer ela ja o alcanca.
  const hall = await db().collection("hallEntries").where("uid", "==", ctx.uid).get();
  if (!hall.empty) {
    const lote = db().batch();
    for (const d of hall.docs) lote.update(d.ref, anonimo);
    await lote.commit();
  }

  // PASSE DE CORTESIA — apagado, subcolecao antes da raiz.
  //
  // Estado operacional de UM jogador: o controle do ciclo e o historico de
  // quinzenas, com as chaves de idempotencia do consumo. Nada disso e de mais
  // ninguem, e a regra nega leitura ate ao dono.
  await apagarSubcolecao(`playerCourtesyPass/${ctx.uid}`, "cycles");
  await db().collection("playerCourtesyPass").doc(ctx.uid).delete();
}

/// Billing: o direito morre, o fato fiscal fica sem titular.
async function tratarBilling(ctx: Contexto): Promise<void> {
  const entitlement = db().collection("playerEntitlements").doc(ctx.uid);
  const atual = await entitlement.get();
  if (atual.exists) {
    const dados = atual.data() ?? {};
    ctx.resumo = {
      ...ctx.resumo,
      vipAtivo: dados.vipAtivo === true,
      vipExpiraEm: typeof dados.expiraEm === "string" ? dados.expiraEm : null,
    };
  }

  // O INTERNO ANTES DO PAI, e nao por elegancia: `delete` num documento do
  // Firestore NAO apaga as subcolecoes dele. Apagar o pai primeiro deixaria
  // `playerEntitlements/{uid}/interno/billing` — o documento que guarda o
  // `purchaseToken` EM CLARO — vivo e agora orfao, sem pai que o denuncie.
  await apagarSubcolecao(`playerEntitlements/${ctx.uid}`, "interno");
  await entitlement.delete();

  const marca = { uidRemovidoEm: agoraIso(), motivoRemocao: "contaExcluida" };
  const compras = await desvincularPorConsulta(
    db().collection("compras").where("uid", "==", ctx.uid),
    ["uid"],
    marca
  );
  ctx.resumo = { ...ctx.resumo, comprasDesvinculadas: compras };

  await desvincularPorConsulta(
    db().collection("billingEvents").where("uid", "==", ctx.uid),
    ["uid"],
    marca
  );

  await db().collection("usuarios").doc(ctx.uid).delete();

  // A PONTE OPACA ENTRE A CONTA E A COMPRA, cortada nos dois sentidos.
  //
  // `playerBillingIdentity/{uid}` guarda a conta ofuscada deste jogador, e
  // `billingAccountIndex/{contaOfuscada}` faz o caminho de volta. Enquanto os
  // dois existirem, existe caminho `uid -> compra`.
  //
  // O INDICE PRIMEIRO, e a ordem NAO e estilo: e pela identidade que se
  // descobre qual e a conta ofuscada. Apagada a identidade antes, o indice
  // ficaria vivo e INALCANCAVEL — um vinculo remanescente que varredura nenhuma
  // acharia depois, porque a chave dele nao se deriva de mais nada.
  const identidadeDeCompra = db().collection("playerBillingIdentity").doc(ctx.uid);
  const vinculo = await identidadeDeCompra.get();
  if (vinculo.exists) {
    const conta = vinculo.data()?.contaOfuscada;
    if (typeof conta === "string" && conta !== "") {
      await db().collection("billingAccountIndex").doc(conta).delete();
    }
  }
  await identidadeDeCompra.delete();
}

/// O corte do vinculo.
/// A etapa `mesas` — sete itens, e a ordem e a do plano.
///
/// ELA EXISTIA NO PLANO E NAO NO EXECUTOR, e o efeito nao era "a etapa nao
/// roda": `executarEtapa` lanca ao ver etapa sem execucao, entao a exclusao
/// INTEIRA parava antes de apagar qualquer coisa. Os testes unitarios nao
/// pegavam porque conferem matriz x plano; quem instancia `EXECUCOES` e a suite
/// de emulador.
///
/// NADA AQUI DECIDE RETENCAO. Cada operacao cumpre a classe que
/// `inventario.ts` ja fixou, e os campos sao os que o produtor real grava
/// (`functions-mesas/src/firestore.ts` e `functions-economia/economiaStore.js`).
///
/// A ORDEM, como o resumo do plano descreve:
///
///   1. o que NAO responde mais a ninguem sai primeiro — contador de palpites,
///      ancoras de assento e passe de cortesia;
///   2. depois o que e COMPARTILHADO perde o titular — convite, sala, admissoes
///      e o livro-razao. A sala vem por ultimo entre as suas porque perder o
///      `proprietarioUid` e o que impede alguem de herdar o controle das
///      cadeiras de uma conta que nao existe mais.
async function tratarMesas(ctx: Contexto): Promise<void> {
  // --- APAGAR ---------------------------------------------------------------

  // `tentativasDeCodigo/{uid}` — contador de janela de dez minutos. A chave E o
  // uid, entao nao ha consulta: um `delete` de documento que pode nao existir e
  // idempotente por construcao no Firestore.
  await db().collection("tentativasDeCodigo").doc(ctx.uid).delete();

  // `passesVip/{uid}` — passe de cortesia, tambem chaveado pelo uid.
  await db().collection("passesVip").doc(ctx.uid).delete();

  // `assentosAdmitidos/{codigoDaSala}__{uid}` — a chave e COMPOSTA, e por isso a
  // busca e pelo campo `uid`, que o produtor grava no documento junto com a
  // ancora. Derivar a chave exigiria conhecer todas as salas em que ele sentou,
  // que e informacao que esta etapa nao tem — e nao deve passar a ter.
  await apagarPorConsulta(
    db().collection("assentosAdmitidos").where("uid", "==", ctx.uid)
  );

  // --- DESVINCULAR ----------------------------------------------------------
  //
  // Os quatro abaixo sao COMPARTILHADOS: uma sala tem quatro cadeiras, um
  // convite serve a quem ainda vai entrar, uma admissao e o registro de uma
  // tentativa e o livro-razao fecha a conta de moedas do jogo. Apagar qualquer
  // um porque um participante saiu derrubaria o registro dos outros.
  const marca = { uidRemovidoEm: agoraIso(), motivoRemocao: "contaExcluida" };

  // O convite antes da sala: ele expira sozinho em horas, e tirar o dono dele
  // primeiro fecha a porta de entrada nova enquanto a sala ainda se resolve.
  await desvincularPorConsulta(
    db().collection("codigosDeSala").where("proprietarioUid", "==", ctx.uid),
    ["proprietarioUid"],
    marca
  );

  await desvincularPorConsulta(
    db().collection("admissoesDeMesa").where("uid", "==", ctx.uid),
    ["uid"],
    marca
  );

  await desvincularPorConsulta(
    db().collection("economiaLedger").where("uid", "==", ctx.uid),
    ["uid"],
    marca
  );

  // A SALA POR ULTIMO. Sem `proprietarioUid`, `podeControlarCadeiras` deixa de
  // reconhecer dono — e ninguem herda o controle das cadeiras de uma conta
  // encerrada. A mesa dos outros tres continua de pe.
  await desvincularPorConsulta(
    db().collection("salasPrivadas").where("proprietarioUid", "==", ctx.uid),
    ["proprietarioUid"],
    marca
  );
}

async function cortarIdentidade(ctx: Contexto): Promise<void> {
  if (ctx.publicId) {
    // O perfil publico PERDE O ROSTO e ganha o estado que o contrato de
    // identidade publica ja reservou. `apelidoOrdenacao` sai junto: e a chave de
    // ordenacao derivada do apelido, e deixa-la seria deixar o apelido
    // normalizado sobreviver a remocao do apelido.
    await db()
      .collection("publicProfiles")
      .doc(ctx.publicId)
      .set(
        {
          apelido: APELIDO_ANONIMO,
          apelidoOrdenacao: "",
          avatarRef: null,
          estado: ESTADO_PERFIL_REMOVIDO,
          removidoEm: agoraIso(),
        },
        { merge: true }
      );

    // A LAPIDE. O documento fica para que o publicId nunca volte ao sorteio de
    // `garantirIdentidade` — ver a justificativa completa no item
    // `identidade.publicIdIndex` de inventario.ts.
    await db()
      .collection("publicIdIndex")
      .doc(ctx.publicId)
      .set(
        {
          uid: FieldValue.delete(),
          estado: "retirado",
          retiradoEm: agoraIso(),
        },
        { merge: true }
      );
  }

  await db().collection("playerIdentities").doc(ctx.uid).delete();
}

async function apagarPerfil(ctx: Contexto): Promise<void> {
  const carteira = db().collection("wallets").doc(ctx.uid);
  const doc = await carteira.get();
  if (doc.exists) {
    const fichas = doc.data()?.fichas;
    ctx.resumo = {
      ...ctx.resumo,
      fichas: typeof fichas === "number" ? fichas : 0,
    };
  }
  await carteira.delete();
  await db().collection("users").doc(ctx.uid).delete();
}

/// A ultima escrita.
///
/// `user-not-found` e ENGOLIDO de proposito: numa retomada, a conta pode ja ter
/// sido apagada pela execucao anterior que morreu logo depois. Tratar isso como
/// falha deixaria a exclusao eternamente `parcial` por causa da unica etapa que
/// de fato ja terminou.
async function apagarAutenticacao(ctx: Contexto): Promise<void> {
  try {
    await getAuth().deleteUser(ctx.uid);
  } catch (e) {
    const codigo = (e as { code?: string })?.code;
    if (codigo === "auth/user-not-found") {
      logger.info("conta do Authentication ja nao existia", { uid: ctx.uid });
      return;
    }
    throw e;
  }
}

const EXECUCOES: Record<string, Execucao> = {
  trancar,
  social: apagarSocial,
  moderacaoDoJogador: apagarModeracao,
  rastreabilidadeDoJogador: apagarRastreabilidade,
  colecoes: apagarColecoes,
  ranking: anonimizarRanking,
  billing: tratarBilling,
  mesas: tratarMesas,
  identidade: cortarIdentidade,
  perfil: apagarPerfil,
  encerrar: apagarAutenticacao,
};

/// Toda etapa declarada em `plano.ts` tem execucao aqui?
///
/// Conferido no CARREGAMENTO do modulo, e nao no teste: uma etapa sem execucao
/// seria saltada em silencio e a exclusao terminaria "concluida" tendo deixado
/// dado para tras. Falhar na carga transforma isso num deploy que nao sobe.
for (const etapa of ETAPAS) {
  if (!EXECUCOES[etapa.id]) {
    throw new Error(`etapa '${etapa.id}' declarada em plano.ts nao tem execucao em executor.ts`);
  }
}

// ===========================================================================
// O LACO
// ===========================================================================

export interface ResultadoDaExecucao {
  readonly estado: string;
  readonly etapasConcluidas: readonly string[];
  readonly falhas: readonly FalhaDeEtapa[];
  readonly repeticao: boolean;
  readonly resumo: ResumoDoEncerramento;
}

/// Executa (ou retoma) a exclusao da conta [uid].
///
/// NAO CONFERE ELEGIBILIDADE NEM REAUTENTICACAO: quem chama e `index.ts`, e e la
/// que os portoes ficam. Separar assim e o que permite ao teste de integracao
/// exercitar a execucao sem forjar token.
export async function executar(uid: string): Promise<ResultadoDaExecucao> {
  const refDiario = db().collection(C_DIARIO).doc(uid);
  const anterior = await refDiario.get();
  const decisao = decidirExecucao(
    anterior.exists ? (anterior.data() as Partial<Diario>) : null
  );

  if (decisao.acao === "convergir") {
    const d = anterior.data() as Diario;
    logger.info("exclusao ja concluida, convergindo", { uid });
    return {
      estado: d.estado,
      etapasConcluidas: d.etapasConcluidas ?? [],
      falhas: d.falhas ?? [],
      repeticao: true,
      resumo: fundirResumo(d.resumo, {}),
    };
  }

  const publicId = await lerPublicId(uid);
  const ctx: Contexto = { uid, publicId, amigos: [], resumo: {} };

  let concluidas = decisao.concluidas;
  const falhas: FalhaDeEtapa[] = [
    ...((anterior.data()?.falhas as FalhaDeEtapa[] | undefined) ?? []),
  ];

  // O diario nasce ANTES da primeira etapa. Se a instancia morrer na etapa 1, o
  // documento ja existe e a proxima chamada retoma em vez de recomecar do zero
  // sem saber que houve uma primeira.
  await refDiario.set(
    {
      uid,
      publicId,
      estado: ESTADO_EXCLUSAO.EM_ANDAMENTO,
      solicitadaEm: anterior.data()?.solicitadaEm ?? agoraIso(),
      atualizadaEm: agoraIso(),
      concluidaEm: null,
      etapasConcluidas: concluidas,
      falhas,
      tentativas: FieldValue.increment(1),
      resumo: fundirResumo(anterior.data()?.resumo, {}),
      esquema: ESQUEMA_DIARIO,
    },
    { merge: true }
  );

  let houveFalha = false;

  for (const etapa of ETAPAS) {
    if (concluidas.includes(etapa.id)) continue;

    try {
      await EXECUCOES[etapa.id](ctx);
      concluidas = comEtapaConcluida(concluidas, etapa.id);

      // GRAVA O PROGRESSO A CADA ETAPA, e nao no fim. Um `await` a mais por
      // etapa e o preco de uma retomada que nao repete o que ja foi feito —
      // e, no caso da etapa `social`, de nao varrer de novo as amizades de uma
      // conta que ja nao tem nenhuma.
      await refDiario.update({
        etapasConcluidas: concluidas,
        atualizadaEm: agoraIso(),
        resumo: fundirResumo(anterior.data()?.resumo, ctx.resumo),
      });
    } catch (e) {
      houveFalha = true;
      const falha: FalhaDeEtapa = {
        etapa: etapa.id,
        erro: e instanceof Error ? e.message : String(e),
        em: agoraIso(),
      };
      falhas.push(falha);
      logger.error("etapa da exclusao falhou", { uid, etapa: etapa.id, erro: falha.erro });

      // PARA NA PRIMEIRA FALHA, e nao segue para as proximas. As etapas tem
      // dependencia de ordem (a identidade e cortada depois de o ranking usar o
      // publicId), e continuar produziria um estado que nenhuma retomada sabe
      // interpretar. Melhor `parcial` coerente do que "quase pronto" confuso.
      break;
    }
  }

  const estado = estadoFinal(
    concluidas,
    ETAPAS.map((e) => e.id),
    houveFalha
  );
  const resumo = fundirResumo(anterior.data()?.resumo, ctx.resumo);

  await refDiario.set(
    {
      estado,
      atualizadaEm: agoraIso(),
      concluidaEm: estado === ESTADO_EXCLUSAO.CONCLUIDA ? agoraIso() : null,
      etapasConcluidas: concluidas,
      falhas,
      resumo,
      esquema: ESQUEMA_DIARIO,
    },
    { merge: true }
  );

  logger.info("exclusao de conta encerrada", { uid, estado, etapas: concluidas.length });

  return {
    estado,
    etapasConcluidas: concluidas,
    falhas,
    repeticao: false,
    resumo: resumo ?? RESUMO_VAZIO,
  };
}

/// O que a etapa faz, para o relatorio de previa. Nao executa nada.
export function descreverEtapa(etapa: Etapa): {
  etapa: string;
  resumo: string;
  itens: { caminho: string; classe: string; porque: string }[];
} {
  return {
    etapa: etapa.id,
    resumo: etapa.resumo,
    itens: itensDaEtapa(etapa).map((i: ItemDoInventario) => ({
      caminho: i.caminho,
      classe: i.classe,
      porque: i.porque,
    })),
  };
}
