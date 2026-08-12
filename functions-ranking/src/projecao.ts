// projecao.ts — o que sai para o cliente, e o que NAO sai de jeito nenhum.
//
// Este arquivo responde tres secoes de uma vez, e as tres sao a mesma disciplina:
//
//   SECAO 15 ("sou eu")     -> `souEu` e decidido AQUI, comparando o uid da linha
//                              com o uid autenticado. O cliente nunca compara
//                              apelido, e nao teria como: o uid nao chega la.
//   SECAO 16 (id publico)   -> a linha sai identificada por `publicPlayerId`, um
//                              identificador opaco que nao e o UID do Firebase.
//   SECAO 17 (privacidade)  -> a projecao e uma LISTA BRANCA. Campo novo no
//                              standing nao vaza sozinho: ele precisa ser escrito
//                              aqui para sair.
//
// POR QUE LISTA BRANCA E NAO LISTA NEGRA, que e a decisao de desenho do arquivo:
// com `delete linha.uid` (lista negra), qualquer campo acrescentado ao standing
// no futuro passa a ser publicado por omissao, e o vazamento acontece no dia em
// que alguem adiciona um campo sem lembrar deste arquivo. Com lista branca, o
// esquecimento produz um campo AUSENTE na tela — visivel, chato e inofensivo —
// em vez de um dado exposto.
//
// O `uid` E LIDO AQUI e nao e devolvido. E a unica funcao do sistema que ve os
// dois lados, e por isso ela e curta o suficiente para ser conferida de relance.

import { Direcao } from "./apuracao";
import { EstadoCompetitivo } from "./competicao";

/// A linha como ela vive no Firestore. Contem o uid — nao atravessa a fronteira.
export interface StandingArmazenado {
  readonly seasonId: string;
  readonly uid: string;
  readonly publicPlayerId: string;
  readonly apelido: string;
  readonly avatar: string;
  /// O RATING da temporada. O nome do campo e historico (`pontos`), e trocar
  /// para `rating` renomearia o campo do indice composto e invalidaria todo
  /// cursor em circulacao — custo alto para ganho de vocabulario.
  readonly pontos: number;
  readonly partidasComputadas: number;
  readonly posicao: number | null;
  readonly posicaoAnterior: number | null;
  readonly direcao: Direcao;
  readonly deltaPosicao: number;
  readonly ligaId: string | null;
  readonly ligaNome: string | null;
  readonly selo: string | null;
  readonly atualizadoEm: string;

  // --- Politica Competitiva v1 ---------------------------------------------

  /// `em_colocacao`, `em_revalidacao` ou `classificado` (secoes 8 e 21).
  readonly estadoCompetitivo: EstadoCompetitivo;
  /// Quantas partidas ranqueadas validas ja contaram para a qualificacao.
  readonly partidasDeQualificacao: number;
  /// Quantas o estado exige. `0` para quem ja consolidou.
  readonly qualificacaoExigida: number;

  readonly vitorias: number;
  readonly derrotas: number;
  readonly empates: number;

  /// Saldo acumulado de pontos das partidas ranqueadas (criterio 3 do desempate).
  /// Estatistica e desempate — NAO entra na formula do Elo (secao 11).
  readonly saldoPontos: number;

  /// Abandonos atribuidos ao jogador (criterio 4 do desempate).
  ///
  /// FICA EM ZERO HOJE, e a razao esta declarada no relatorio: o registro oficial
  /// de partida marca que houve abandono (`estado: abandonada`), mas nao diz QUEM
  /// abandonou. Atribuir aos dois integrantes do lado perdedor puniria o parceiro
  /// inocente, que seria uma regra inventada. O campo e o criterio existem e sao
  /// exercitados; a fonte que os alimenta e dependencia de outra OS.
  readonly abandonos: number;

  /// Desde quando o jogador esta neste rating (criterio 5 do desempate).
  /// ISO-8601 UTC, reescrito so quando o valor do rating muda.
  readonly ratingAtingidoEm: string;
}

/// A linha como o cliente a recebe.
///
/// Espelha `RankingJogador` de `app/lib/ranking/ranking_contract.dart` campo a
/// campo — `id`, `apelido`, `avatar`, `liga`, `pontos`, `posicao`, `direcao`,
/// `delta`, `selo`, `souEu` — para que o adaptador Dart seja uma leitura de
/// mapa, sem traducao de nomes onde um erro passaria despercebido.
export interface JogadorPublicado {
  /// `RankingJogador.id`. E o `publicPlayerId`, NUNCA o uid.
  readonly id: string;
  /// VAZIO HOJE. Nao ha fonte de perfil no backend, e a secao 23 proibe fabricar
  /// um: nada de derivar nome de e-mail, nada de expor uid como fallback.
  readonly apelido: string;
  readonly avatar: string;
  /// ROTULO PRONTO PARA A TELA, e nao so o nome da Liga.
  ///
  /// Enquanto o jogador esta em colocacao ou revalidacao, ele NAO TEM Liga
  /// (secao 15: "Durante colocacao: `Em colocacao`, nao Bronze/Prata"), e este
  /// campo carrega o rotulo do estado. Um cliente que ja saiba exibir
  /// `RankingJogador.liga` mostra a coisa certa sem mudar uma linha; quem quiser
  /// ramificar em codigo tem `estado` e `ligaId` logo abaixo.
  ///
  /// Vazio so quando a temporada nao aponta para escada nenhuma.
  readonly liga: string;
  /// O id estavel da Liga (`bronze`, `prata`, ...), ou `null` durante a
  /// qualificacao. E o campo com que se escolhe arte, e por isso ele e separado
  /// do rotulo: `liga` pode dizer "Em colocacao", que nao e uma Liga.
  readonly ligaId: string | null;
  /// O RATING do jogador na temporada.
  readonly pontos: number;
  readonly posicao: number;
  readonly direcao: Direcao;
  readonly delta: number;
  readonly selo: string | null;
  readonly souEu: boolean;

  // --- Politica Competitiva v1 (secao 24) ----------------------------------

  /// `em_colocacao` | `em_revalidacao` | `classificado`.
  readonly estado: EstadoCompetitivo;
  /// Quantas partidas ranqueadas ainda faltam para consolidar a Liga. `0` para
  /// quem ja consolidou. Permite "faltam 3 partidas" sem que o cliente subtraia
  /// nada — a conta e do servidor, como todo o resto.
  readonly qualificacaoRestante: number;
  readonly partidas: number;
  readonly vitorias: number;
  readonly derrotas: number;
  /// Vitorias sobre partidas, em PORCENTAGEM, com uma casa decimal.
  ///
  /// Empate nao conta como vitoria nem como derrota, entao um jogador com
  /// vitorias + derrotas < partidas tem aproveitamento menor que o complemento
  /// das derrotas — o que e a leitura correta e nao um erro de conta.
  /// `0` quando ainda nao ha partida, e nao `NaN`.
  readonly aproveitamento: number;
}

/// Posicao publicada para quem ainda nao foi apurado.
///
/// Zero, e nao 1: `0` nao e uma posicao valida em nenhuma classificacao, entao
/// ele nao pode ser confundido com "esta em primeiro". O cliente exibe o que
/// vier — o contrato dele diz "vem da fonte e e exibida como veio" — e um jogador
/// recem-chegado, ainda sem apuracao, aparece com 0 ate a proxima passagem.
export const POSICAO_NAO_APURADA = 0;

/// Projeta uma linha para o cliente.
///
/// `uidDoLeitor` e `null` quando quem le nao esta autenticado; nesse caso nenhuma
/// linha e "eu", que e a resposta correta e nao um erro.
/// Os rotulos dos estados de qualificacao, como a tela os exibe (secoes 15 e 21).
export const ROTULO_DO_ESTADO: Readonly<Record<EstadoCompetitivo, string>> = {
  em_colocacao: "Em colocacao",
  em_revalidacao: "Em revalidacao",
  classificado: "",
};

/// Vitorias sobre partidas, em porcentagem com uma casa.
export function aproveitamentoDe(vitorias: number, partidas: number): number {
  if (partidas <= 0) return 0;
  return Math.round((vitorias / partidas) * 1000) / 10;
}

export function projetarJogador(
  linha: StandingArmazenado,
  uidDoLeitor: string | null
): JogadorPublicado {
  const qualificando = linha.estadoCompetitivo !== "classificado";
  return {
    id: linha.publicPlayerId,
    apelido: linha.apelido,
    avatar: linha.avatar,
    // A ORDEM DESTE `if` E A REGRA DA SECAO 15. O estado vence a Liga: mesmo que
    // a linha ja tenha um `ligaNome` gravado, quem esta em colocacao nao exibe
    // Liga. Invertido, um jogador em colocacao apareceria como Bronze.
    liga: qualificando ? ROTULO_DO_ESTADO[linha.estadoCompetitivo] : linha.ligaNome ?? "",
    ligaId: qualificando ? null : linha.ligaId,
    pontos: linha.pontos,
    posicao: linha.posicao ?? POSICAO_NAO_APURADA,
    direcao: linha.direcao,
    delta: linha.deltaPosicao,
    selo: linha.selo,
    // A comparacao acontece nesta linha, e em nenhuma outra do sistema.
    souEu: uidDoLeitor !== null && linha.uid === uidDoLeitor,
    estado: linha.estadoCompetitivo,
    qualificacaoRestante: Math.max(
      0,
      linha.qualificacaoExigida - linha.partidasDeQualificacao
    ),
    partidas: linha.partidasComputadas,
    vitorias: linha.vitorias,
    derrotas: linha.derrotas,
    aproveitamento: aproveitamentoDe(linha.vitorias, linha.partidasComputadas),
  };
}

/// Prova, como valor conferivel, que a projecao nao publica campo sensivel.
///
/// Existe para o teste da secao 23 ("leitura publica apenas dos campos
/// autorizados") poder afirmar a lista inteira em vez de checar um campo por
/// vez — e para que acrescentar um campo a `JogadorPublicado` sem atualizar esta
/// constante quebre o teste.
export const CAMPOS_PUBLICADOS: ReadonlyArray<keyof JogadorPublicado> = [
  "id",
  "apelido",
  "avatar",
  "liga",
  "ligaId",
  "pontos",
  "posicao",
  "direcao",
  "delta",
  "selo",
  "souEu",
  "estado",
  "qualificacaoRestante",
  "partidas",
  "vitorias",
  "derrotas",
  "aproveitamento",
];

/// Campos que NAO podem aparecer em nada que atravesse a fronteira.
///
/// Lista literal da secao 17 mais o que este projeto guarda por perto. O teste
/// varre a resposta inteira — resumo, podio, paginas — atras destes nomes.
export const CAMPOS_PROIBIDOS: ReadonlyArray<string> = [
  "uid",
  "userId",
  "email",
  "token",
  "deviceId",
  "purchaseToken",
  "ip",
  "denuncianteUid",
  "sancao",
  "entitlement",
];

/// Confere recursivamente que nenhuma chave proibida aparece na resposta.
///
/// Rodar isto em TESTE, e nao em producao, e deliberado: em producao ele custaria
/// uma varredura por resposta para reconfirmar o que a lista branca ja garante.
/// O valor dele e travar a regressao — o dia em que alguem devolver o documento
/// cru "so para depurar".
export function acharCampoProibido(valor: unknown, caminho = "$"): string | null {
  if (Array.isArray(valor)) {
    for (let i = 0; i < valor.length; i++) {
      const achado = acharCampoProibido(valor[i], `${caminho}[${i}]`);
      if (achado !== null) return achado;
    }
    return null;
  }
  if (typeof valor === "object" && valor !== null) {
    for (const [chave, dentro] of Object.entries(valor)) {
      if (CAMPOS_PROIBIDOS.includes(chave)) return `${caminho}.${chave}`;
      const achado = acharCampoProibido(dentro, `${caminho}.${chave}`);
      if (achado !== null) return achado;
    }
  }
  return null;
}
