// inventario.ts — A MATRIZ DE RETENCAO/EXCLUSAO, em forma executavel.
//
// Este arquivo e a resposta inteira a pergunta "que dados este jogador tem, e o
// que acontece com cada um quando ele pede para sair?". Ele NAO e documentacao
// que acompanha o codigo: ele E o codigo. `plano.ts` monta a ordem a partir
// desta lista, `executor.ts` executa item por item, e `test/inventario.test.js`
// LE `firebase/firestore.rules` e falha se alguma colecao declarada la nao
// aparecer aqui.
//
// Essa ultima trava e o motivo principal de a matriz ser dado e nao prosa. Uma
// tabela num `.md` envelhece em silencio: alguem acrescenta uma colecao, o
// documento nao muda, e a exclusao passa a deixar rastro sem ninguem perceber.
// Aqui, acrescentar colecao sem classificar QUEBRA A SUITE.
//
// MODULO PURO DE PROPOSITO: nada aqui importa firebase-admin. E o que permite
// que a matriz inteira seja conferida com `node --test`, sem emulador — mesma
// disciplina de functions-social/src/chaves.ts.
//
// ===========================================================================
// A DOUTRINA — POR QUE "APAGAR TUDO" SERIA A RESPOSTA ERRADA
// ===========================================================================
//
// A OS e explicita: "nao apague dados historicos cegamente se isso quebrar
// integridade competitiva, financeira ou de moderacao". As tres quebras sao
// concretas, e vale nomea-las porque cada uma justifica uma linha RETER abaixo:
//
//   COMPETITIVA. Uma partida tem quatro pessoas. O rating que os outros tres
//   ganharam saiu do resultado contra este jogador. Apagar `matches`,
//   `rankingLedger` ou `rankingContributions` porque um dos quatro saiu
//   reescreveria a pontuacao de quem ficou — e a cadeia antes+delta==depois,
//   que o ledger existe para provar, passaria a nao fechar.
//
//   FINANCEIRA. `compras/{hash}` e o UNICO elo entre um `purchaseToken` da
//   Google e um titular. Apagar o registro apagaria a prova de uma transacao
//   que existiu de verdade, com dinheiro de verdade, e que a Play pode
//   estornar depois.
//
//   MODERACAO. `playerModeration/{uid}` e o efeito consolidado de uma sancao, e
//   `firebase/firestore.rules` nega a escrita ate para o dono, com o comentario
//   "o ponto exato onde morre a tentativa de apagar a propria punicao". Se a
//   exclusao de conta apagasse esse documento, ela viraria justamente o botao
//   que a regra recusa — um caminho de limpeza de ficha disciplinar.
//
// ---------------------------------------------------------------------------
// O QUE TORNA A RETENCAO ACEITAVEL: O CORTE DO VINCULO
// ---------------------------------------------------------------------------
//
// Reter registro chaveado por UID so nao e reter dado pessoal por causa de UMA
// propriedade, e ela e produzida ativamente por este fluxo:
//
//   depois da exclusao, NAO EXISTE MAIS CAMINHO DE UID PARA PESSOA.
//
// A conta do Authentication (e-mail, telefone, provedor, nome do provedor) e
// apagada. O perfil privado e apagado. `playerIdentities/{uid}` e apagado.
// `publicProfiles/{publicId}` perde apelido e avatar. O que sobra em
// `rankingLedger`, `matches` e `sanctions` e uma string opaca de 28 caracteres
// que nao resolve para ninguem — pseudonimo sem chave de reversao.
//
// E por isso que a matriz tem tantos DESVINCULAR: em vez de apagar o registro
// (que quebraria a integridade) ou de mante-lo intacto (que manteria o
// vinculo), corta-se o campo que faz a ponte para a identidade e preserva-se o
// fato.
//
// A UNICA excecao deliberada e `publicIdIndex/{publicId}`, que continua
// existindo SEM `uid` — a lapide. Ver a justificativa no item, porque ela e
// contra-intuitiva.

// ===========================================================================
// CLASSES
// ===========================================================================

/// As cinco classes que a OS pede, e nada alem delas.
export const CLASSE = {
  /// O documento deixa de existir.
  APAGAR: "APAGAR",
  /// O documento fica, e os campos que identificam a PESSOA (apelido, avatar,
  /// e-mail) sao substituidos por um rotulo neutro. Preserva a linha; perde o
  /// rosto.
  ANONIMIZAR: "ANONIMIZAR",
  /// O documento fica com o fato intacto, e o campo que aponta para a IDENTIDADE
  /// e cortado. Preserva o registro; perde a ponte.
  DESVINCULAR: "DESVINCULAR",
  /// O documento fica como esta. Reservado a trilhas de auditoria e a registros
  /// cujo unico dado de pessoa ja e o UID orfao.
  RETER: "RETER",
  /// Nao guarda dado de pessoa nenhum. Configuracao, catalogo, semente.
  NAO_APLICAVEL: "NAO_APLICAVEL",
} as const;

export type Classe = (typeof CLASSE)[keyof typeof CLASSE];

/// Dominio dono do dado. Serve ao relatorio e ao log — e para que uma falha
/// diga "parou no billing", que e acionavel, em vez de "parou na etapa 14".
export type Dominio =
  | "auth"
  | "conta"
  | "identidade"
  | "social"
  | "moderacao"
  | "rastreabilidade"
  | "ranking"
  | "torneios"
  | "billing"
  | "colecoes"
  | "mesas";

// ===========================================================================
// COMO SE ALCANCA O DADO
// ===========================================================================
//
// A forma de ACHAR e tao parte da matriz quanto a decisao, porque e onde mora o
// erro caro: um item classificado APAGAR que ninguem sabe localizar e um item
// que nao vai ser apagado. Os oito modos abaixo cobrem tudo o que existe hoje.

export type Alcance =
  /// `colecao/{uid}`. O caso simples.
  | { readonly modo: "docPorUid"; readonly colecao: string }
  /// `users/{uid}/{sub}` — apaga a subcolecao inteira do proprio jogador.
  | { readonly modo: "subcolecaoDoDono"; readonly raiz: string; readonly sub: string }
  /// `colecao/{publicId}`. Exige o publicId, que so existe se o jogador tiver
  /// identidade publica.
  | { readonly modo: "docPorPublicId"; readonly colecao: string }
  /// `where(campo == uid)`. `grupo: true` quando e subcolecao e a busca precisa
  /// ser collection-group.
  | {
      readonly modo: "consultaPorCampo";
      readonly colecao: string;
      readonly campo: string;
      readonly grupo?: boolean;
    }
  /// `where(campo array-contains uid)`.
  | { readonly modo: "consultaPorArray"; readonly colecao: string; readonly campo: string }
  /// A chave do documento e derivavel a partir de outra coisa conhecida (a lista
  /// de temporadas, a lista de amizades). Ver o comentario do item.
  | { readonly modo: "chaveDerivada"; readonly colecao: string; readonly de: string }
  /// Alcancado pelo OUTRO lado de uma relacao ja carregada. Nao ha consulta: os
  /// UIDs vem de `friendships.membros`.
  | { readonly modo: "pelaRelacao"; readonly raiz: string; readonly sub: string }
  /// Nao e Firestore: e o Authentication. Modo proprio, e nao "semAcao", porque
  /// e o item mais consequente da matriz e classifica-lo como "nada a fazer"
  /// seria a etiqueta errada no lugar mais perigoso.
  | { readonly modo: "authentication" }
  /// Nada a fazer — RETER e NAO_APLICAVEL. O item existe na matriz porque
  /// declarar "conferido, e fica" e diferente de esquecer.
  | { readonly modo: "semAcao" };

export interface ItemDoInventario {
  /// Identificador estavel. E o que vai gravado em `etapasConcluidas` no diario,
  /// entao renomear um id faz uma exclusao retomada repetir a etapa — o que e
  /// seguro (toda etapa e idempotente), mas nao e de graca.
  readonly id: string;
  /// O caminho como se escreve no Firestore, com os parametros entre chaves.
  readonly caminho: string;
  readonly dominio: Dominio;
  readonly classe: Classe;
  readonly alcance: Alcance;
  /// Campos a cortar (DESVINCULAR) ou a substituir (ANONIMIZAR).
  readonly campos?: readonly string[];
  /// A JUSTIFICATIVA. Obrigatoria, e o teste falha se vier vazia: a OS proibe
  /// apagar historico "sem justificativa", e a forma de garantir isso e nao
  /// deixar existir item sem uma.
  readonly porque: string;
}

/// O rotulo que substitui apelido e avatar nas linhas que continuam existindo.
///
/// Texto, e nao string vazia: uma linha de ranking com apelido vazio parece
/// defeito de carregamento e gera chamado de suporte. "Jogador removido" e uma
/// afirmacao, e a tela nao precisa de codigo novo para exibi-la.
export const APELIDO_ANONIMO = "Jogador removido";

/// O estado que `publicProfiles` passa a carregar.
///
/// NAO E INVENCAO DESTA OS. `EstadoPerfilPublico.indisponivel` ja existe no
/// dominio Dart (app/lib/social/identidade_publica.dart) e ja e respeitado pela
/// leitura; `docs/CONTRATO-IDENTIDADE-PUBLICA-SOCIAL.md` registra a lacuna com
/// todas as letras: "Quando ela existir, basta gravar `estado: indisponivel` —
/// a leitura ja respeita". Esta linha e o cumprimento daquele contrato.
export const ESTADO_PERFIL_REMOVIDO = "indisponivel";

// ===========================================================================
// A MATRIZ
// ===========================================================================

export const INVENTARIO: readonly ItemDoInventario[] = [
  // -------------------------------------------------------------------------
  // AUTENTICACAO
  // -------------------------------------------------------------------------
  {
    id: "auth.usuario",
    caminho: "FirebaseAuth/{uid}",
    dominio: "auth",
    classe: CLASSE.APAGAR,
    alcance: { modo: "authentication" },
    porque:
      "E a conta em si: e-mail, telefone, provedor e nome vindo do provedor. E TAMBEM a chave que torna todo o resto reversivel — enquanto ela existe, um UID em `rankingLedger` volta a ser uma pessoa. Apagada por ULTIMO de proposito (ver plano.ts): se fosse primeiro, uma falha no meio deixaria dado orfao e o jogador sem sessao para pedir de novo.",
  },

  // -------------------------------------------------------------------------
  // O DIARIO DA PROPRIA EXCLUSAO
  // -------------------------------------------------------------------------
  {
    id: "conta.diario",
    caminho: "accountDeletions/{uid}",
    dominio: "conta",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "A lapide. Guarda o que foi feito, quando, e o resumo do que existia (saldo de fichas, VIP ativo) para o suporte responder 'sim, esta conta foi excluida a pedido, nesta data'. Nao carrega apelido, e-mail nem avatar. E tambem a barreira de idempotencia: e a leitura dele que faz a segunda chamada convergir em vez de refazer tudo.",
  },

  // -------------------------------------------------------------------------
  // IDENTIDADE PUBLICA
  // -------------------------------------------------------------------------
  {
    id: "identidade.playerIdentities",
    caminho: "playerIdentities/{uid}",
    dominio: "identidade",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "playerIdentities" },
    porque:
      "E o mapa uid -> publicId. E metade da ponte que o corte de vinculo precisa derrubar: sem ele, ninguem parte de um UID retido e chega ao perfil.",
  },
  {
    id: "identidade.publicIdIndex",
    caminho: "publicIdIndex/{publicId}",
    dominio: "identidade",
    classe: CLASSE.DESVINCULAR,
    campos: ["uid"],
    alcance: { modo: "docPorPublicId", colecao: "publicIdIndex" },
    porque:
      "CONTRA-INTUITIVO, E DELIBERADO: o documento FICA, sem `uid`, marcado como retirado. Apagar devolveria o publicId ao sorteio de `garantirIdentidade` (o `create` so falha se o id existir), e um jogador novo poderia receber o codigo de um que saiu — herdando, aos olhos de quem le, as linhas de `rankingStandings`, `hallEntries` e `rankingLedger` que ainda citam aquele publicId. A lapide custa um documento e impede uma troca de identidade silenciosa.",
  },
  {
    id: "identidade.publicProfiles",
    caminho: "publicProfiles/{publicId}",
    dominio: "identidade",
    classe: CLASSE.ANONIMIZAR,
    campos: ["apelido", "apelidoOrdenacao", "avatarRef", "estado"],
    alcance: { modo: "docPorPublicId", colecao: "publicProfiles" },
    porque:
      "Apelido e avatar sao a PESSOA e saem. O documento fica porque e a fonte de apresentacao que ranking e hall projetam, e porque `estado: indisponivel` e exatamente o gancho que o contrato de identidade publica deixou reservado para esta OS. Apagar faria `verPerfilPublico` responder `not-found` — que ja e a mesma resposta de conta inexistente, entao nao ha ganho de privacidade em apagar, e ha perda de rotulo nas linhas historicas.",
  },

  // -------------------------------------------------------------------------
  // GRAFO SOCIAL
  // -------------------------------------------------------------------------
  {
    id: "social.friendships",
    caminho: "friendships/{pairKey}",
    dominio: "social",
    classe: CLASSE.APAGAR,
    alcance: { modo: "consultaPorArray", colecao: "friendships", campo: "membros" },
    porque:
      "A relacao canonica. Uma amizade e um vinculo entre duas contas vivas; morta uma, o vinculo nao descreve mais nada. O documento carrega `membros`, `solicitanteUid` e `destinatarioUid` — tres UIDs — entao mante-lo seria manter o UID do excluido dentro do dado de OUTRA pessoa.",
  },
  {
    id: "social.friendsDoDono",
    caminho: "users/{uid}/friends/{outroUid}",
    dominio: "social",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "friends" },
    porque: "Projecao da lista de amigos do proprio jogador. Deriva de `friendships`, que sai junto.",
  },
  {
    id: "social.friendsDoOutro",
    caminho: "users/{outroUid}/friends/{uid}",
    dominio: "social",
    classe: CLASSE.APAGAR,
    alcance: { modo: "pelaRelacao", raiz: "users", sub: "friends" },
    porque:
      "O ESPELHO, e ele e o item que uma exclusao ingenua esquece. O UID do excluido e o ID DO DOCUMENTO na lista do amigo: apagar so o lado dele deixaria o amigo com uma linha que aponta para uma conta que nao existe — e com o UID dela na chave. Alcancado sem varredura: os UIDs do outro lado vem de `friendships.membros`, ja carregado na etapa anterior.",
  },
  {
    id: "social.friendRequestsDoDono",
    caminho: "users/{uid}/friendRequests/{outroUid}",
    dominio: "social",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "friendRequests" },
    porque: "Projecao das solicitacoes do proprio jogador. Mesma derivacao de `friends`.",
  },
  {
    id: "social.friendRequestsDoOutro",
    caminho: "users/{outroUid}/friendRequests/{uid}",
    dominio: "social",
    classe: CLASSE.APAGAR,
    alcance: { modo: "pelaRelacao", raiz: "users", sub: "friendRequests" },
    porque:
      "O espelho da solicitacao pendente. Sem isto, o outro jogador ficaria com um convite eterno de alguem que nao existe, sem botao que resolva: aceitar chamaria uma Function que nao acha a contraparte.",
  },
  {
    id: "social.playerSocial",
    caminho: "playerSocial/{uid}",
    dominio: "social",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "playerSocial" },
    porque: "Contadores derivados (amigos, solicitacoes enviadas). Sem relacoes, nao contam nada.",
  },

  // -------------------------------------------------------------------------
  // MODERACAO
  // -------------------------------------------------------------------------
  {
    id: "moderacao.blocksDoDono",
    caminho: "users/{uid}/blocks/{alvoUid}",
    dominio: "moderacao",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "blocks" },
    porque:
      "A lista de quem ESTE jogador bloqueou. E preferencia de protecao dele, e carrega os UIDs de terceiros; sem conta, nao protege ninguem.",
  },
  {
    id: "moderacao.blocksContraOExcluido",
    caminho: "users/{outroUid}/blocks/{uid}",
    dominio: "moderacao",
    classe: CLASSE.APAGAR,
    alcance: {
      modo: "consultaPorCampo",
      colecao: "blocks",
      campo: "bloqueadoUid",
      grupo: true,
    },
    porque:
      "Bloqueios que OUTROS fizeram contra o excluido. Ficam orfaos: a conta bloqueada nao pode mais convidar, chamar nem escrever, porque nao existe. Apagar tira o UID do excluido de dentro da conta de terceiros, e limpa o fantasma da tela 'Jogadores bloqueados' do outro. Consulta collection-group pelo campo `bloqueadoUid`, que a Function de bloqueio ja grava redundantemente — o `fieldOverrides` correspondente foi declarado em firebase/firestore.indexes.json por esta OS.",
  },
  {
    id: "moderacao.mutesDoDono",
    caminho: "users/{uid}/mutes/{alvoUid}",
    dominio: "moderacao",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "mutes" },
    porque: "Silenciamentos configurados por ele. Preferencia de exibicao, sem efeito sobre terceiros.",
  },
  {
    id: "moderacao.mutesContraOExcluido",
    caminho: "users/{outroUid}/mutes/{uid}",
    dominio: "moderacao",
    classe: CLASSE.APAGAR,
    alcance: { modo: "consultaPorCampo", colecao: "mutes", campo: "alvoUid", grupo: true },
    porque:
      "Mesmo raciocinio do bloqueio espelhado: e o UID do excluido dentro da conta de outra pessoa, silenciando alguem que nao fala mais.",
  },
  {
    id: "moderacao.reports",
    caminho: "reports/{denuncianteUid|reportIntentId}",
    dominio: "moderacao",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "INTEGRIDADE DE MODERACAO, nos dois sentidos. As denuncias que ELE fez sao processos abertos contra terceiros: apaga-las derrubaria casos que nao sao dele. As que ELE sofreu sao a base das sancoes aplicadas: apaga-las apagaria o fundamento do historico disciplinar. O UID esta na chave e nos campos, e permanece — orfao, depois do corte de vinculo.",
  },
  {
    id: "moderacao.reportReceipts",
    caminho: "users/{uid}/reportReceipts/{reportId}",
    dominio: "moderacao",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "reportReceipts" },
    porque:
      "O COMPROVANTE e a copia pessoal do denunciante — protocolo e status, para ele acompanhar. O registro administrativo fica em `reports`, que e retido. Apagar o comprovante nao perde informacao nenhuma: perde a comodidade de quem nao existe mais.",
  },
  {
    id: "moderacao.sanctions",
    caminho: "sanctions/{sancaoId}",
    dominio: "moderacao",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "O historico disciplinar. A propria colecao ja e desenhada para nunca ser apagada — revogar grava `revogada`, nao deleta. Deixar a exclusao de conta apaga-la abriria o caminho de limpeza de ficha que `firestore.rules` recusa explicitamente ao dono.",
  },
  {
    id: "moderacao.playerModeration",
    caminho: "playerModeration/{uid}",
    dominio: "moderacao",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "O efeito consolidado (silenciado ate, suspenso ate, permanente). E O PONTO EXATO que firebase/firestore.rules descreve como 'onde morre a tentativa de apagar a propria punicao'. Uma exclusao que o apagasse seria essa tentativa, com outro nome. Fica, e o UID que o chaveia ja nao resolve para pessoa nenhuma.",
  },
  {
    id: "moderacao.moderationAudit",
    caminho: "moderationAudit/{eventoId}",
    dominio: "moderacao",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque: "Trilha administrativa. Por desenho, nem o admin apaga — 'para que a trilha nao possa ser limpa por quem a gerou'.",
  },
  {
    id: "moderacao.moderationTasks",
    caminho: "moderationTasks/{chaveTarefa}",
    dominio: "moderacao",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Barreira de idempotencia. Apagar reabriria intencoes ja gastas — uma denuncia repetida com o mesmo intent id voltaria a ser aceita. O ganho de privacidade seria zero; o custo, uma porta de reprocessamento.",
  },

  // -------------------------------------------------------------------------
  // RASTREABILIDADE DE PARTIDAS
  // -------------------------------------------------------------------------
  {
    id: "rastreabilidade.matches",
    caminho: "matches/{matchId}",
    dominio: "rastreabilidade",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "INTEGRIDADE COMPETITIVA. A partida e de quatro pessoas, nao de uma. Apagar (ou tirar um competidor de `userIdsCompetidores`) mudaria o registro dos outros tres e quebraria a reconstrucao de historico que a rastreabilidade existe para permitir.",
  },
  {
    id: "rastreabilidade.matchEvents",
    caminho: "matches/{matchId}/events/{eventId}",
    dominio: "rastreabilidade",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque: "Trilha de eventos da mesa. Mesmo motivo da partida: e o registro compartilhado de quem jogou junto.",
  },
  {
    id: "rastreabilidade.matchHistory",
    caminho: "users/{uid}/matchHistory/{matchId}",
    dominio: "rastreabilidade",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "matchHistory" },
    porque:
      "E a VISAO DO JOGADOR — projecao pessoal de `matches`, com as contagens dele. O registro tecnico fica; a copia pessoal sai. Nada se perde: a projecao e reconstrutivel a partir do canonico.",
  },
  {
    id: "rastreabilidade.rankingLedger",
    caminho: "rankingLedger/{matchId|userId|motivo}",
    dominio: "rastreabilidade",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "O extrato antes/delta/depois. E a prova de POR QUE cada pontuacao e o que e — inclusive a dos adversarios. Apagar os lancamentos de um jogador deixaria a cadeia dos outros com um degrau sem origem.",
  },
  {
    id: "rastreabilidade.fraudSignals",
    caminho: "fraudSignals/{chaveIdempotencia}",
    dominio: "rastreabilidade",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Sinais antifraude citam VARIOS alvos por documento (conluio e coletivo). Apagar por causa de um citado destruiria a suspeita sobre os outros — e transformaria 'excluir a conta' na forma mais barata de sumir com o rastro de um esquema. Sinal nao e veredito e nao pune ninguem; reter e o comportamento conservador correto.",
  },

  // -------------------------------------------------------------------------
  // RANKING, LIGAS E TEMPORADAS
  // -------------------------------------------------------------------------
  {
    id: "ranking.rankingStandings",
    caminho: "rankingStandings/{seasonId|uid}",
    dominio: "ranking",
    classe: CLASSE.ANONIMIZAR,
    campos: ["apelido", "avatar"],
    alcance: { modo: "chaveDerivada", colecao: "rankingStandings", de: "rankingSeasons" },
    porque:
      "A LINHA FICA, O ROSTO SAI. Apagar reescreveria a classificacao de temporadas encerradas — quem ficou em terceiro passaria a segundo por um motivo que nao aconteceu na mesa. `apelido` e `avatar` sao projecao de `publicProfiles` e viram o rotulo neutro; `uid` e `publicPlayerId` permanecem porque sao a chave da linha (o id do documento e `seasonId|uid`, e nao ha como cortar o campo sem inutilizar o proprio documento). NAO HA CONSULTA POR UID nesta colecao — as chaves sao remontadas varrendo `rankingSeasons`, que e pequena e finita.",
  },
  {
    id: "ranking.rankingPlayers",
    caminho: "rankingPlayers/{uid}",
    dominio: "ranking",
    classe: CLASSE.ANONIMIZAR,
    campos: ["apelido", "avatar"],
    alcance: { modo: "docPorUid", colecao: "rankingPlayers" },
    porque:
      "O agregado de vida inteira, que sustenta a aba global. Mesmo raciocinio do standing: apagar mexeria na ordem de quem ficou. Chaveado por UID, entao a linha e retida com a apresentacao neutralizada.",
  },
  {
    id: "ranking.rankingContributions",
    caminho: "rankingContributions/{chaveIdempotencia}",
    dominio: "ranking",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "A prova de que uma partida ja foi processada, com os deltas de TODOS os jogadores dela. E o que impede a mesma partida de pontuar duas vezes num reprocessamento. Apagar reabriria a dupla contagem para os adversarios.",
  },
  {
    id: "ranking.rankingBacklog",
    caminho: "rankingBacklog/{matchId}",
    dominio: "ranking",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Fila de partidas a reprocessar quando a formula existir. O documento e da PARTIDA, nao do jogador, e a ordem cronologica dele e o que faz o Elo (nao comutativo) chegar ao mesmo resultado.",
  },
  {
    id: "ranking.rankingAudit",
    caminho: "rankingAudit/{eventoId}",
    dominio: "ranking",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque: "Trilha. O UID que ela carrega e o do ADMIN que operou, nao o do jogador excluido.",
  },
  {
    id: "ranking.rankingTasks",
    caminho: "rankingTasks/{chaveTarefa}",
    dominio: "ranking",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque: "Idempotencia administrativa. Mesmo motivo de `moderationTasks`.",
  },
  {
    id: "ranking.rankingSeasons",
    caminho: "rankingSeasons/{seasonId}",
    dominio: "ranking",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque:
      "Configuracao de temporada. Guarda contagem de classificados, nunca quem. E, ao mesmo tempo, a FONTE das chaves de `rankingStandings` — lida, nunca escrita, por esta OS.",
  },
  {
    id: "ranking.rankingLadders",
    caminho: "rankingLadders/{ladderId}",
    dominio: "ranking",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque:
      "Escada de Ligas — as faixas de rating que definem Bronze a Imortal. Configuracao competitiva pura: descreve o sistema, nunca um jogador. Conferido item a item; nao ha campo de pessoa aqui.",
  },
  {
    id: "ranking.hallEntries",
    caminho: "hallEntries/{chave}",
    dominio: "ranking",
    classe: CLASSE.ANONIMIZAR,
    campos: ["apelido", "avatar"],
    alcance: { modo: "consultaPorCampo", colecao: "hallEntries", campo: "uid" },
    porque:
      "O Hall e memoria: quem venceu uma temporada venceu. Apagar reescreveria o passado; o rotulo neutro preserva o fato sem o rosto. NOTA DE ESTADO: nenhuma Function deste repositorio escreve `hallEntries` hoje (a colecao existe nas regras e nao tem produtor), entao a consulta tende a nao achar nada — e esta linha e o que garante que ela seja tratada no dia em que o produtor aparecer.",
  },

  // -------------------------------------------------------------------------
  // TORNEIOS
  // -------------------------------------------------------------------------
  {
    id: "torneios.registrations",
    caminho: "tournaments/{t}/editions/{e}/registrations/{uid}",
    dominio: "torneios",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "A inscricao e o fato de ter participado de uma edicao, e ela sustenta a classificacao e a premiacao dos outros inscritos. RESSALVA QUE ESTA OS NAO RESOLVE, e registra: se a edicao ainda NAO encerrou, a inscricao de uma conta morta continua ocupando vaga. Cancelar exigiria reproduzir a regra de `cancelarInscricaoTorneio` (devolucao de fichas, convocacao da lista de espera) dentro deste codebase, que e duplicacao de regra competitiva — e a OS proibe alterar regra competitiva. O bloqueio esta na porta: `plano.ts` RECUSA a exclusao enquanto houver inscricao ativa em edicao nao encerrada, e manda o jogador cancelar pelo fluxo proprio.",
  },
  {
    id: "torneios.tournamentHistory",
    caminho: "tournamentHistory/{registroId}",
    dominio: "torneios",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Snapshot congelado de uma edicao concluida, com `participantesUserIds` e `campeoes`. Mexer aqui reescreveria o resultado de um torneio inteiro por causa de um participante.",
  },
  {
    id: "torneios.rewardGrants",
    caminho: "rewardGrants/{chaveIdempotencia}",
    dominio: "torneios",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Concessao de premio: e registro economico e e idempotencia ao mesmo tempo. Apagar reabriria a possibilidade de a mesma premiacao ser concedida de novo num reprocessamento da edicao.",
  },
  {
    id: "torneios.annualQualifications",
    caminho: "annualQualifications/{registroId}",
    dominio: "torneios",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque: "O fato da classificacao anual. Sustenta a lista de excedentes e a consolidacao de convites dos OUTROS.",
  },
  {
    id: "torneios.closingInvites",
    caminho: "closingInvites/{chaveIdempotencia}",
    dominio: "torneios",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "O convite de encerramento e um direito emitido, contado na lotacao da edicao final. Apagar mudaria a contagem administrativa de uma temporada ja consolidada.",
  },
  {
    id: "torneios.tournamentTasks",
    caminho: "tournamentTasks/{chaveTarefa}",
    dominio: "torneios",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Idempotencia do agendador. O `alvo` e a fase, nao o jogador — conferido, nao ha UID aqui.",
  },
  {
    id: "torneios.tournamentAudit",
    caminho: "tournamentAudit/{eventoId}",
    dominio: "torneios",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Trilha do motor. O ator e 'sistema' — conferido, nao ha UID aqui.",
  },
  {
    id: "torneios.wallets",
    caminho: "wallets/{uid}",
    dominio: "torneios",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "wallets" },
    porque:
      "A CARTEIRA DE FICHAS. Saldo e intransferivel e morre com a conta — nao ha para quem devolver depois que o titular pede para sair. O saldo do momento do encerramento vai gravado no diario (`accountDeletions`), que e o que permite ao suporte responder a um pedido de estorno posterior sem manter a carteira viva. NOTA: `wallets` nao e declarada em firestore.rules e cai no fecho `if false` — invisivel ao cliente, escrita so pelo Admin SDK.",
  },
  {
    id: "torneios.editionsEStandings",
    caminho: "tournaments/{t}/editions/{e}/{tables|results|standings|conclusion|phases}",
    dominio: "torneios",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Mesas, resultados, classificacao e desfecho de uma edicao. Carregam `participanteId` (que em dupla e `uidA+uidB`) e `campeoes`. Sao o registro compartilhado da competicao; nenhum deles descreve so o excluido. Nao ha produtor destes documentos nesta arvore — vem do Motor de Partidas.",
  },
  {
    id: "torneios.tournamentJobs",
    caminho: "tournamentJobs/{chaveIdempotencia}",
    dominio: "torneios",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Fila interna do agendador, chaveada por fase. Conferido: nao ha UID.",
  },
  {
    id: "torneios.seeds",
    caminho: "seeds/{documento}",
    dominio: "torneios",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Sementes de catalogo (registro de assets, politicas de premio). Sem dado de pessoa.",
  },
  {
    id: "torneios.tournaments",
    caminho: "tournaments/{tournamentId}",
    dominio: "torneios",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Configuracao do torneio e das edicoes. Sem dado de pessoa.",
  },

  // -------------------------------------------------------------------------
  // BILLING
  // -------------------------------------------------------------------------
  {
    id: "billing.playerEntitlements",
    caminho: "playerEntitlements/{uid}",
    dominio: "billing",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "playerEntitlements" },
    porque:
      "O DIREITO VIP e da conta e morre com ela. Guardar um entitlement ativo de uma conta inexistente so criaria um estado que a reconciliacao teria de tratar para sempre. O que a compra teve de fato fica em `compras`, que e retido.",
  },
  {
    id: "billing.playerEntitlementsInterno",
    caminho: "playerEntitlements/{uid}/interno/billing",
    dominio: "billing",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "playerEntitlements", sub: "interno" },
    porque:
      "O DOCUMENTO MAIS SENSIVEL DO BANCO: carrega o `purchaseToken` EM CLARO. Apagar e obrigatorio, e apagar EXPLICITAMENTE tambem: um `delete` no documento pai NAO apaga subcolecao no Firestore, e confiar nisso deixaria o token vivo depois de a conta ter sumido.",
  },
  {
    id: "billing.compras",
    caminho: "compras/{sha256(purchaseToken)}",
    dominio: "billing",
    classe: CLASSE.DESVINCULAR,
    campos: ["uid"],
    alcance: { modo: "consultaPorCampo", colecao: "compras", campo: "uid" },
    porque:
      "INTEGRIDADE FINANCEIRA. O registro fica: houve uma transacao real, com valor real, que a Play pode estornar meses depois. O `uid` sai, e o efeito e exatamente o desejado — `titularDoToken` passa a responder `registro_sem_uid` e o RTDN daquela assinatura e DESCARTADO em vez de conceder direito a um fantasma. O comportamento seguro ja existia no billing; esta OS so o aciona.",
  },
  {
    id: "billing.billingEvents",
    caminho: "billingEvents/{messageId}",
    dominio: "billing",
    classe: CLASSE.DESVINCULAR,
    campos: ["uid"],
    alcance: { modo: "consultaPorCampo", colecao: "billingEvents", campo: "uid" },
    porque:
      "Trilha de notificacoes da Play, e barreira contra reentrega do Pub/Sub. O evento fica (apagar faria uma reentrega ser reprocessada); o `uid` sai. O documento ja guarda so um rotulo curto do hash do token, nunca o token.",
  },
  {
    id: "billing.usuariosLegado",
    caminho: "usuarios/{uid}",
    dominio: "billing",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "usuarios" },
    porque:
      "O PERFIL PRIVADO no namespace legado do Billing — e um namespace DIFERENTE de `users/`, e os dois estao vivos. Guarda fichas e os campos VIP historicos. Uma exclusao que varresse so `users/` deixaria este documento inteiro para tras, com o perfil do jogador dentro.",
  },
  {
    id: "billing.configuracao",
    caminho: "configuracao/{documento}",
    dominio: "billing",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Configuracao do billing (pacote do app, chaves de produto). Sem dado de pessoa.",
  },

  // -------------------------------------------------------------------------
  // COLECOES / KIT PIONEIROS
  // -------------------------------------------------------------------------
  {
    id: "colecoes.inventory",
    caminho: "users/{uid}/inventory/{itemId}",
    dominio: "colecoes",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "inventory" },
    porque: "Vitrine e itens cosmeticos do jogador. Sem valor fora da conta, e sem efeito sobre terceiros.",
  },
  {
    id: "colecoes.campaignClaims",
    caminho: "users/{uid}/campaign_claims/{campaignId}",
    dominio: "colecoes",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "users", sub: "campaign_claims" },
    porque:
      "Comprovante de resgate do Kit Pioneiros. E a idempotencia do resgate DAQUELE UID — e o UID nao volta a existir, entao nao ha resgate a repetir. O fato administrativo (quem resgatou, quando) fica em `audit`, que e retido.",
  },
  {
    id: "colecoes.campaignEligible",
    caminho: "campaigns/{campaignId}/eligible/{uid}",
    dominio: "colecoes",
    classe: CLASSE.APAGAR,
    alcance: { modo: "chaveDerivada", colecao: "campaigns", de: "campaigns" },
    porque:
      "Elegibilidade concedida a este UID. Chaveada por UID dentro da campanha — e mais um lugar onde o UID do excluido sobreviveria fora de `users/`. Apagar nao permite nada a ninguem: uma conta nova tem UID novo e precisa de concessao nova. ALCANCADA POR CHAVE DERIVADA, e nao por consulta: o documento NAO tem campo `uid` (so `concessaoAdministrativa`, `concedidaPor` e `concedidaEm`), entao nao ha por onde filtrar — a chave e remontada varrendo `campaigns`, que e uma colecao de configuracao pequena.",
  },
  {
    id: "colecoes.audit",
    caminho: "audit/{registroId}",
    dominio: "colecoes",
    classe: CLASSE.RETER,
    alcance: { modo: "semAcao" },
    porque:
      "Trilha de acao administrativa (concessao manual, revogacao). Carrega o UID do admin como `autor` e o do jogador como `alvo`. Por desenho, nem o admin apaga.",
  },
  {
    id: "colecoes.campaigns",
    caminho: "campaigns/{campaignId}",
    dominio: "colecoes",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Definicao da campanha. Sem dado de pessoa.",
  },
  {
    id: "colecoes.collections",
    caminho: "collections/{collectionId}",
    dominio: "colecoes",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque: "Catalogo de colecoes e itens. Sem dado de pessoa.",
  },
  {
    id: "colecoes.config",
    caminho: "config/{documento}",
    dominio: "colecoes",
    classe: CLASSE.NAO_APLICAVEL,
    alcance: { modo: "semAcao" },
    porque:
      "Feature flags do aplicativo, legiveis por qualquer autenticado e escritas so por admin. Conferido campo a campo: descrevem o que esta ligado no produto, nunca quem e o jogador.",
  },

  // -------------------------------------------------------------------------
  // O DOCUMENTO RAIZ DO JOGADOR
  // -------------------------------------------------------------------------
  {
    id: "conta.usersRaiz",
    caminho: "users/{uid}",
    dominio: "conta",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "users" },
    porque:
      "O documento raiz. Nenhuma Function deste repositorio o escreve hoje — ele existe como PAI das oito subcolecoes — mas apaga-lo e barato e fecha a porta para um campo gravado por fora. ATENCAO: apagar o pai NAO apaga as subcolecoes no Firestore; e por isso que cada uma delas tem item proprio nesta matriz, e nao uma linha 'users e tudo abaixo'.",
  },

  // =========================================================================
  // DOMINIO `economia` — a carteira e o livro-razao
  // =========================================================================
  //
  // ACHADO PREEXISTENTE, FECHADO AQUI. `economiaLedger` esta declarada em
  // `firebase/firestore.rules` desde a OS de Economia Basica e nunca foi
  // classificada nesta matriz — o teste que cruza as duas fontes ja falhava na
  // base desta OS. E exatamente o defeito que este arquivo existe para
  // detectar: uma colecao nova, uma regra escrita, e ninguem lembrou do fluxo
  // de exclusao. A correcao e a que o cabecalho manda — decidir o destino do
  // dado, com justificativa — e nao acrescentar uma excecao ao teste.
  {
    id: "economia.economiaLedger",
    caminho: "economiaLedger/{chaveIdempotencia}",
    dominio: "conta",
    classe: CLASSE.DESVINCULAR,
    campos: ["uid"],
    alcance: { modo: "consultaPorCampo", colecao: "economiaLedger", campo: "uid" },
    porque:
      "INTEGRIDADE FINANCEIRA, pela mesma doutrina de `compras` e `rankingLedger`. O livro-razao existe para provar a cadeia antes+delta==depois da carteira; apagar linhas dele porque um jogador saiu faria a cadeia parar de fechar para todo mundo, e a chave de idempotencia deixaria de barrar um reprocessamento do mesmo resultado. O FATO fica — houve um lancamento, com este valor, por esta partida — e o `uid` sai, que e o que corta o caminho de volta para a pessoa.",
  },

  // =========================================================================
  // DOMINIO `mesas` — tipos de mesa, permissoes VIP e passe de cortesia
  // origem: OS 2 — Arbitragem e canonizacao autoritativa dos tipos de mesa
  // =========================================================================
  //
  // As seis colecoes do codebase `mesas`. Elas se dividem em duas naturezas, e
  // a divisao explica as classes:
  //
  //   DIREITO DA CONTA ...... o passe. Morre com ela, como o entitlement.
  //   FATO DA PARTIDA ....... a admissao, o assento, a sala e o convite.
  //                           Descrevem algo que aconteceu numa mesa com outras
  //                           tres pessoas, e por isso seguem a mesma doutrina
  //                           de `matches` e `rankingLedger`: o fato fica, o
  //                           vinculo com a identidade sai.
  {
    id: "mesas.passesVip",
    caminho: "passesVip/{uid}",
    dominio: "mesas",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "passesVip" },
    porque:
      "MESMA DOUTRINA DE `playerEntitlements`: o direito de entrada e da conta e morre com ela. Um passe utilizavel de uma conta inexistente so criaria estado que alguem teria de tratar para sempre. E, ao contrario da compra, aqui nao ha nada a preservar do outro lado — a cortesia nao passa pela Google e nao tem transacao a comprovar.",
  },
  {
    id: "mesas.admissoesDeMesa",
    caminho: "admissoesDeMesa/{tentativaEntradaId}",
    dominio: "mesas",
    classe: CLASSE.DESVINCULAR,
    campos: ["uid"],
    alcance: { modo: "consultaPorCampo", colecao: "admissoesDeMesa", campo: "uid" },
    porque:
      "INTEGRIDADE COMPETITIVA E BARREIRA DE IDEMPOTENCIA. O documento e a chave que impede a mesma `tentativaEntradaId` de ser decidida duas vezes; apaga-lo reabriria a janela de dupla admissao para uma tentativa que ainda pudesse ser repetida. O FATO fica — houve uma admissao, com este veredito, nesta mesa —, e o `uid` sai, que e o mesmo tratamento de `compras` e `matches`.",
  },
  {
    id: "mesas.assentosAdmitidos",
    caminho: "assentosAdmitidos/{codigoDaSala}__{uid}",
    dominio: "mesas",
    classe: CLASSE.APAGAR,
    alcance: { modo: "consultaPorCampo", colecao: "assentosAdmitidos", campo: "uid" },
    porque:
      "A ANCORA DE RECONEXAO, e ela nao e historico: ela existe para responder 'este uid ja ocupa assento nesta sala AGORA'. Uma ancora orfa de conta apagada nao responde a ninguem, e mante-la seria guardar o vinculo uid-sala sem nenhum fato competitivo a proteger. O que houve de fato esta em `admissoesDeMesa`, que e retido desvinculado.",
  },
  {
    id: "mesas.salasPrivadas",
    caminho: "salasPrivadas/{codigoDaSala}",
    dominio: "mesas",
    classe: CLASSE.DESVINCULAR,
    campos: ["proprietarioUid"],
    alcance: { modo: "consultaPorCampo", colecao: "salasPrivadas", campo: "proprietarioUid" },
    porque:
      "A SALA PODE ESTAR EM ANDAMENTO COM OUTRAS TRES PESSOAS. Apaga-la porque o dono saiu derrubaria a mesa dos outros — e a mesma quebra que a doutrina desta matriz descreve para `matches`. Sai o `proprietarioUid`, e o efeito e exatamente o desejado: `podeControlarCadeiras` deixa de reconhecer dono, entao ninguem herda o controle das cadeiras de uma conta que nao existe mais.",
  },
  {
    id: "mesas.codigosDeSala",
    caminho: "codigosDeSala/{sha256(codigoConvite)}",
    dominio: "mesas",
    classe: CLASSE.DESVINCULAR,
    campos: ["proprietarioUid"],
    alcance: { modo: "consultaPorCampo", colecao: "codigosDeSala", campo: "proprietarioUid" },
    porque:
      "O CONVITE DE UMA SALA QUE PODE ESTAR EM ANDAMENTO. Apaga-lo trancaria do lado de fora quem ainda nao entrou numa mesa que continua de pe. O documento NAO carrega dado pessoal alem do dono — nem o codigo em claro, que so existe como impressao —, entao cortar `proprietarioUid` basta. O convite morre sozinho por `expiraEm`, em no maximo 12 horas.",
  },
  {
    id: "mesas.tentativasDeCodigo",
    caminho: "tentativasDeCodigo/{uid}",
    dominio: "mesas",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "tentativasDeCodigo" },
    porque:
      "CONTADOR OPERACIONAL DE CURTISSIMO PRAZO — janela de dez minutos. Nao ha fato a preservar e nao ha integridade a proteger: um contador de uma conta inexistente nunca mais sera lido. Reter seria guardar 'quantas vezes esta pessoa errou um codigo' sem nenhuma finalidade.",
  },

  // =========================================================================
  // BILLING — a ponte opaca entre a conta e a compra
  // =========================================================================
  //
  // As duas entraram com a correcao P0 da propriedade da compra, e formam um
  // par: `playerBillingIdentity/{uid}` guarda a conta ofuscada, e
  // `billingAccountIndex/{contaOfuscada}` faz o caminho de volta. Juntas, sao
  // exatamente o caminho `uid -> compra` — e e por isso que as duas saem.
  //
  // A ORDEM IMPORTA e esta declarada: o indice e alcancado ATRAVES da
  // identidade, entao ele vem primeiro. Apagar a identidade antes deixaria o
  // indice orfao e inalcancavel — o pior resultado possivel, porque seria um
  // vinculo remanescente que nenhuma varredura futura acharia.
  //
  // ISTO NAO APAGA A PROVA FINANCEIRA. `compras/{hash}` continua RETIDA pela
  // sua propria linha: o que morre e a ponte para a PESSOA, nao o fato de a
  // transacao ter existido.
  {
    id: "billing.indiceDeVinculo",
    caminho: "billingAccountIndex/{contaOfuscada}",
    dominio: "billing",
    classe: CLASSE.APAGAR,
    alcance: { modo: "chaveDerivada", colecao: "billingAccountIndex", de: "playerBillingIdentity" },
    porque:
      "E METADE DO CAMINHO `uid -> compra`, e a metade que aponta de volta. O documento nao guarda nada alem do uid: sem ele, a conta ofuscada deixa de resolver para pessoa nenhuma. Reter seria manter viva justamente a ponte que a exclusao existe para cortar, e sem finalidade — a autoridade de propriedade so precisa dela enquanto a conta existe. Vem ANTES de `billing.identidadeDeCompra` na matriz porque e por ela que este documento e encontrado.",
  },
  {
    id: "billing.identidadeDeCompra",
    caminho: "playerBillingIdentity/{uid}",
    dominio: "billing",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "playerBillingIdentity" },
    porque:
      "A OUTRA METADE DO CAMINHO. Guarda a conta ofuscada emitida para ESTE jogador, e mais nada. Uma vez apagado o indice, este documento e um identificador opaco sem contraparte — e mante-lo seria reter um dado de pessoa cuja unica finalidade (resolver a propriedade de uma compra futura) nao existe mais para uma conta encerrada.",
  },

  // =========================================================================
  // MODERACAO / CHAT
  // =========================================================================
  {
    id: "moderacao.canaisDeChat",
    caminho: "chatChannels/{canalId}",
    dominio: "moderacao",
    classe: CLASSE.DESVINCULAR,
    campos: ["participantes"],
    alcance: { modo: "consultaPorArray", colecao: "chatChannels", campo: "participantes" },
    porque:
      "O CANAL E DE UMA MESA, E A MESA E DE MAIS GENTE. Apaga-lo porque um dos participantes saiu destruiria o canal dos outros tres — a mesma quebra que a doutrina descreve para `matches`. Sai o UID de `participantes`; o canal continua existindo enquanto tiver finalidade compartilhada, e some sozinho quando nao tiver mais. O documento nao carrega apelido nem avatar: tirado o UID, nao sobra dado do excluido.",
  },
  {
    id: "moderacao.mensagensDeChat",
    caminho: "chatMessages/{messageId}",
    dominio: "moderacao",
    classe: CLASSE.APAGAR,
    alcance: { modo: "consultaPorCampo", colecao: "chatMessages", campo: "autorUid" },
    porque:
      "MENSAGEM COMUM NAO E REGISTRO COMPARTILHADO: ela e fala DE UMA PESSOA, e o conteudo e dela. Apagar as mensagens do excluido nao derruba a conversa de ninguem — as dos outros participantes permanecem, porque a consulta e por `autorUid`. NAO se retem a colecao inteira por precaucao: evidencia ja vinculada a um caso de moderacao ou seguranca segue a politica daquele caso, com finalidade, prazo e fundamento proprios, e fica FORA do caminho normal do produto — nao e este item que a autoriza, e este item nao a alcanca.",
  },

  // =========================================================================
  // CONQUISTAS
  // =========================================================================
  {
    id: "rastreabilidade.conquistas",
    caminho: "playerAchievements/{uid}/items/{itemId}",
    dominio: "rastreabilidade",
    classe: CLASSE.APAGAR,
    alcance: { modo: "subcolecaoDoDono", raiz: "playerAchievements", sub: "items" },
    porque:
      "CONQUISTA E DO JOGADOR, E DE MAIS NINGUEM. Diferente de `matches` e do ledger, nenhum outro jogador tem pontuacao que dependa de uma conquista alheia: apagar nao reescreve o passado de terceiro. E o documento e chaveado pelo UID e descreve o que ESTA pessoa fez — reter seria guardar historico pessoal de uma conta encerrada, sem integridade a proteger.",
  },
  {
    id: "rastreabilidade.conquistasRaiz",
    caminho: "playerAchievements/{uid}",
    dominio: "rastreabilidade",
    classe: CLASSE.APAGAR,
    alcance: { modo: "docPorUid", colecao: "playerAchievements" },
    porque:
      "O DOCUMENTO-RAIZ do jogador, depois de esvaziada a subcolecao. Apagar a raiz sem apagar `items` antes deixaria a subcolecao orfa e viva no Firestore — que e o modo classico de a exclusao parecer completa e nao ser.",
  },
] as const;

// ===========================================================================
// LEITURAS DA MATRIZ
// ===========================================================================

export function itensDaClasse(classe: Classe): readonly ItemDoInventario[] {
  return INVENTARIO.filter((i) => i.classe === classe);
}

export function itemPorId(id: string): ItemDoInventario | undefined {
  return INVENTARIO.find((i) => i.id === id);
}

/// Os itens que EXIGEM trabalho. RETER e NAO_APLICAVEL estao na matriz para
/// serem conferiveis, e nao para serem executados.
export function itensAcionaveis(): readonly ItemDoInventario[] {
  return INVENTARIO.filter((i) => i.alcance.modo !== "semAcao");
}

/// A primeira parte do caminho — o nome da colecao raiz. Usada pelo teste que
/// cruza esta matriz com `firebase/firestore.rules`.
export function colecaoRaizDe(item: ItemDoInventario): string {
  return item.caminho.split("/")[0];
}
