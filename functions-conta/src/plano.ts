// plano.ts — a ORDEM, e as duas recusas que acontecem antes de qualquer escrita.
//
// MODULO PURO DE PROPOSITO: recebe fatos ja lidos e devolve decisoes. Nao toca
// Firestore, nao toca Auth, nao le relogio. `test/plano.test.js` prova a ordem e
// as recusas com `node --test`.
//
// ===========================================================================
// POR QUE A ORDEM E PARTE DO PROJETO, E NAO DETALHE DE IMPLEMENTACAO
// ===========================================================================
//
// Uma exclusao pode falhar no meio — cota, contencao, rede, instancia
// reciclada. A pergunta que decide o desenho e: "se parar AQUI, o sistema fica
// num estado pior do que antes?". A ordem abaixo e escolhida para que a
// resposta seja sempre nao.
//
//   1. A CONTA E TRANCADA PRIMEIRO, E APAGADA POR ULTIMO.
//      Trancar (desabilitar + revogar os tokens de atualizacao) impede que o
//      jogador continue agindo enquanto os dados dele sao removidos — sem isso,
//      uma solicitacao de amizade aceita no meio do caminho recriaria a projecao
//      que a etapa anterior acabou de apagar.
//      Apagar a conta do Authentication e a ULTIMA escrita porque ela e a unica
//      irreversivel e a unica que destroi a chave de retomada: parada no meio,
//      com a conta ainda existindo, a exclusao e retomavel; parada no meio com a
//      conta ja apagada, sobra dado orfao e ninguem com sessao para pedir de
//      novo.
//
//   2. O `publicId` E LIDO ANTES DE `playerIdentities` SER APAGADO.
//      Ele e a chave de tres itens da matriz (`publicProfiles`, `publicIdIndex`
//      e as linhas de ranking). Apagar o mapa primeiro deixaria os tres
//      inalcancaveis — e um jogador sem identidade publica so seria detectado
//      depois, quando ja nao houvesse como voltar.
//
//   3. AS AMIZADES SAO LIDAS ANTES DE SEREM APAGADAS.
//      Os espelhos (`users/{outro}/friends/{uid}`) sao alcancados pelos UIDs que
//      vem de `friendships.membros`. Apagar o canonico primeiro apagaria o mapa
//      que leva aos espelhos, e eles ficariam para tras — em documentos de OUTRAS
//      pessoas, que e o pior lugar para esquecer um UID.
//
//   4. TUDO O QUE E DESVINCULAR/ANONIMIZAR VEM ANTES DO QUE E APAGAR na mesma
//      area, quando um depende do outro. E o caso de `playerEntitlements`
//      (apagado) e `compras` (desvinculado): a busca de compras e por campo
//      `uid`, e nao depende do entitlement, mas a ordem inversa nao teria como
//      ser retomada se o entitlement ja tivesse sumido com o rastro.
//
// ===========================================================================
// AS DUAS RECUSAS
// ===========================================================================
//
// Recusar e melhor do que fazer pela metade. Sao duas, e nenhuma e sobre
// privacidade — as duas sao sobre nao quebrar o jogo de outras pessoas.

import { INVENTARIO, ItemDoInventario, itemPorId } from "./inventario";

// ---------------------------------------------------------------------------
// RECUSA 1 — INSCRICAO ATIVA EM EDICAO QUE NAO ENCERROU
// ---------------------------------------------------------------------------
//
// Uma conta que some no meio de um torneio deixa uma cadeira ocupada por
// ninguem: a mesa nao fecha, a fase nao apura, e os outros tres ficam presos.
//
// A alternativa seria cancelar a inscricao aqui — e ela foi RECUSADA, por dois
// motivos. Primeiro, cancelar inscricao tem regra: devolucao de fichas,
// convocacao da lista de espera, recontagem de lotacao. Essa regra mora no
// dominio de torneios, e reproduzi-la neste codebase seria duplicar regra
// competitiva num lugar que nao a revisa. Segundo, a OS proibe alterar regra
// competitiva — e uma segunda implementacao de cancelamento e exatamente isso,
// mesmo que a primeira versao concorde com a original.
//
// Entao a porta recusa e diz o que fazer: cancele a inscricao pelo fluxo que ja
// existe, depois volte. E uma espera de minutos, nao um bloqueio permanente.

/// Estados em que a inscricao AINDA CONTA. Espelha `StatusInscricao.ativo` de
/// app/lib/torneios/registrations.dart — os tres que NAO estao aqui
/// (`cancelado`, `ausente`, `desclassificado`) sao os que ja liberaram a vaga.
///
/// A repeticao dos valores e a mesma que functions-ranking/src/identidade.ts faz
/// com as colecoes de functions-social, e pelo mesmo motivo: os codebases sao
/// unidades de implantacao separadas e nao compartilham pacote. O teste confere
/// esta lista contra o arquivo Dart, para que um estado novo la nao passe a ser
/// tratado como inativo aqui em silencio.
export const STATUS_INSCRICAO_ATIVA: readonly string[] = [
  "inscrito",
  "lista_espera",
  "aguardando_dupla",
  "dupla_confirmada",
  "checkin_pendente",
  "checkin_realizado",
  "convocado_para_mesa",
  "em_partida",
];

/// Estados de edicao em que a inscricao ainda prende alguem.
///
/// Uma inscricao "ativa" numa edicao ENCERRADA e so historico — nao ha cadeira
/// a liberar. Por isso a recusa olha os dois lados, e nao so o status da
/// inscricao.
export const STATUS_EDICAO_ENCERRADA: readonly string[] = [
  "encerrada",
  "concluida",
  "cancelada",
];

export const RECUSA = {
  /// Ha inscricao ativa em edicao que nao encerrou.
  TORNEIO_EM_ANDAMENTO: "torneioEmAndamento",
  /// A credencial nao foi apresentada ha pouco.
  REAUTENTICACAO: "reautenticacaoNecessaria",
  /// A palavra de confirmacao nao confere.
  CONFIRMACAO: "confirmacaoInvalida",
  /// Ja existe uma exclusao concluida para esta conta.
  JA_EXCLUIDA: "contaJaExcluida",
} as const;

export type Recusa = (typeof RECUSA)[keyof typeof RECUSA];

// ---------------------------------------------------------------------------
// RECUSA 2 — O PEDIDO NOMEIA UMA CONTA
// ---------------------------------------------------------------------------
//
// O UID vem de `req.auth.uid`, sempre. Um payload que TRAZ um alvo nao esta
// pedindo nada que possa ser atendido — no melhor caso e um cliente confuso, no
// pior e uma tentativa de excluir a conta de outra pessoa.
//
// A escolha aqui e entre IGNORAR e RECUSAR, e ela nao e obvia: ignorar produz o
// mesmo efeito (a conta certa e excluida) e e mais tolerante. Recusar ganha uma
// coisa que ignorar nao tem — a tentativa vira um registro. Numa operacao que
// apaga conta, saber que alguem tentou nomear outra e informacao operacional, e
// nao ruido.
//
// Mora aqui, e nao em index.ts, para ser puro e testavel: `test/plano.test.js`
// prova a lista inteira sem forjar um `CallableRequest`.

/// Os nomes pelos quais alguem diria "apague ESTA conta". Nenhum tem uso
/// legitimo nas rotas de exclusao.
export const CAMPOS_DE_ALVO_PROIBIDOS: readonly string[] = [
  "uid",
  "userId",
  "publicId",
  "alvo",
  "alvoUid",
];

/// Os campos de alvo presentes no payload. Vazio quando o pedido esta limpo.
///
/// `undefined` nao conta como presenca — um cliente que serializa o campo como
/// ausente esta, para todos os efeitos, nao mandando o campo. `null` CONTA:
/// mandar `uid: null` e mandar o campo.
export function camposDeAlvoNoPayload(dados: unknown): readonly string[] {
  if (dados === null || typeof dados !== "object") return [];
  const registro = dados as Record<string, unknown>;
  return CAMPOS_DE_ALVO_PROIBIDOS.filter((c) => registro[c] !== undefined);
}

export interface InscricaoPendente {
  readonly tournamentId: string;
  readonly editionId: string;
  readonly status: string;
  readonly statusEdicao: string;
}

export interface VereditoElegibilidade {
  readonly pode: boolean;
  readonly recusa: Recusa | null;
  /// As inscricoes que travaram, para a tela poder NOMEA-LAS. Um "cancele suas
  /// inscricoes" sem dizer quais manda a pessoa procurar.
  readonly bloqueios: readonly InscricaoPendente[];
}

/// A conta pode ser excluida agora?
///
/// Recebe as inscricoes JA LIDAS — a consulta e do executor, a decisao e daqui.
export function decidirElegibilidade(
  inscricoes: readonly InscricaoPendente[]
): VereditoElegibilidade {
  const bloqueios = inscricoes.filter(
    (i) =>
      STATUS_INSCRICAO_ATIVA.includes(i.status) &&
      !STATUS_EDICAO_ENCERRADA.includes(i.statusEdicao)
  );

  if (bloqueios.length > 0) {
    return { pode: false, recusa: RECUSA.TORNEIO_EM_ANDAMENTO, bloqueios };
  }
  return { pode: true, recusa: null, bloqueios: [] };
}

// ===========================================================================
// AS ETAPAS
// ===========================================================================
//
// Uma etapa e a menor unidade que vale a pena retomar. Granularidade fina
// demais (um documento por etapa) encheria o diario; grossa demais ("apague
// tudo") faria uma falha no fim repetir o comeco.

export interface Etapa {
  readonly id: string;
  /// Os itens da matriz que esta etapa realiza. Vazio nas etapas que operam no
  /// Authentication, que nao e Firestore.
  readonly itens: readonly string[];
  /// O que esta etapa faz, em uma linha, para o log e para o relatorio.
  readonly resumo: string;
}

export const ETAPAS: readonly Etapa[] = [
  {
    id: "trancar",
    itens: [],
    resumo:
      "Desabilita a conta e revoga os tokens de atualizacao. A partir daqui o jogador nao consegue mais escrever nada — nem recriar o que as etapas seguintes apagam.",
  },
  {
    id: "social",
    itens: [
      "social.friendships",
      "social.friendsDoDono",
      "social.friendsDoOutro",
      "social.friendRequestsDoDono",
      "social.friendRequestsDoOutro",
      "social.playerSocial",
    ],
    resumo:
      "Amizades e solicitacoes, canonico e os DOIS espelhos. Le `friendships` primeiro: e de `membros` que saem os UIDs dos amigos, e sem eles os espelhos ficariam inalcancaveis.",
  },
  {
    id: "moderacaoDoJogador",
    itens: [
      "moderacao.blocksDoDono",
      "moderacao.mutesDoDono",
      "moderacao.reportReceipts",
      "moderacao.blocksContraOExcluido",
      "moderacao.mutesContraOExcluido",
    ],
    resumo:
      "Bloqueios, silenciamentos e comprovantes de denuncia — as listas dele e as referencias a ele nas listas dos outros. Denuncias, sancoes e estado disciplinar NAO entram: sao retidos.",
  },
  {
    id: "rastreabilidadeDoJogador",
    itens: ["rastreabilidade.matchHistory"],
    resumo:
      "So a projecao pessoal do historico de partidas. `matches`, `events`, `rankingLedger` e `fraudSignals` ficam — integridade competitiva.",
  },
  {
    id: "colecoes",
    itens: ["colecoes.inventory", "colecoes.campaignClaims", "colecoes.campaignEligible"],
    resumo: "Inventario, comprovantes de resgate e elegibilidade de campanha (Kit Pioneiros).",
  },
  {
    id: "ranking",
    itens: ["ranking.rankingStandings", "ranking.rankingPlayers", "ranking.hallEntries"],
    resumo:
      "Neutraliza a APRESENTACAO nas linhas competitivas — apelido e avatar viram o rotulo anonimo. As linhas ficam: apaga-las reescreveria a colocacao de quem jogou contra.",
  },
  {
    id: "billing",
    itens: [
      "billing.playerEntitlementsInterno",
      "billing.playerEntitlements",
      "billing.compras",
      "billing.billingEvents",
      "billing.usuariosLegado",
    ],
    resumo:
      "Direito VIP e o documento interno com o token em claro sao apagados; compras e eventos da Play sao DESVINCULADOS (o fato fiscal fica, o titular sai). O interno antes do pai: `delete` no pai nao apaga subcolecao.",
  },
  {
    id: "mesas",
    itens: [
      "mesas.tentativasDeCodigo",
      "mesas.assentosAdmitidos",
      "mesas.passesVip",
      "mesas.codigosDeSala",
      "mesas.salasPrivadas",
      "mesas.admissoesDeMesa",
      "economia.economiaLedger",
    ],
    resumo:
      "Passe de cortesia, ancoras de assento e o contador de palpites sao apagados; sala privada, convite, admissoes e o livro-razao da economia sao DESVINCULADOS (o fato fica, o titular sai). A ORDEM importa: as ancoras e o contador saem primeiro porque nao respondem mais a ninguem, e a sala sai por ultimo entre as suas porque perder o `proprietarioUid` e o que impede alguem de herdar o controle das cadeiras.",
  },
  {
    id: "identidade",
    itens: [
      "identidade.publicProfiles",
      "identidade.publicIdIndex",
      "identidade.playerIdentities",
    ],
    resumo:
      "O corte do vinculo. Perfil publico anonimizado e marcado `indisponivel`, indice reverso vira lapide sem `uid`, e o mapa uid->publicId e apagado. DEPOIS de ranking: as linhas competitivas precisam do publicId para serem alcancadas.",
  },
  {
    id: "perfil",
    itens: ["torneios.wallets", "conta.usersRaiz"],
    resumo:
      "Carteira de fichas (com o saldo registrado no diario antes de sumir) e o documento raiz do jogador.",
  },
  {
    id: "encerrar",
    itens: ["auth.usuario"],
    resumo:
      "Apaga a conta do Authentication e fecha o diario. A ULTIMA escrita, e a unica irreversivel.",
  },
];

/// As etapas que ainda faltam, na ordem.
///
/// Idempotencia por SALTO, e nao por tentativa: uma etapa ja registrada como
/// concluida nao roda de novo. E o que faz uma chamada repetida — ou uma
/// retomada depois de falha parcial — custar quase nada em vez de repetir o
/// trabalho inteiro.
export function etapasPendentes(concluidas: readonly string[]): readonly Etapa[] {
  const feitas = new Set(concluidas);
  return ETAPAS.filter((e) => !feitas.has(e.id));
}

/// Os itens da matriz que uma etapa realiza, ja resolvidos.
///
/// Lanca se um id nao existir na matriz: uma etapa que aponta para item
/// inexistente e um erro de programacao que precisa aparecer no teste, e nao
/// virar uma etapa que silenciosamente nao faz nada.
export function itensDaEtapa(etapa: Etapa): readonly ItemDoInventario[] {
  return etapa.itens.map((id) => {
    const item = itemPorId(id);
    if (!item) {
      throw new Error(
        `etapa '${etapa.id}' aponta para o item '${id}', que nao existe no inventario`
      );
    }
    return item;
  });
}

/// Todo item acionavel da matriz esta em alguma etapa?
///
/// A pergunta que fecha o circulo: a matriz pode estar completa e o plano ainda
/// deixar um item de fora. `test/plano.test.js` chama isto e falha com a lista
/// dos esquecidos.
export function itensAcionaveisForaDoPlano(): readonly string[] {
  const noPlano = new Set(ETAPAS.flatMap((e) => e.itens));
  return INVENTARIO.filter((i) => i.alcance.modo !== "semAcao" && !noPlano.has(i.id)).map(
    (i) => i.id
  );
}
