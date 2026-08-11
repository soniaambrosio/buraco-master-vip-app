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

/// A linha como ela vive no Firestore. Contem o uid — nao atravessa a fronteira.
export interface StandingArmazenado {
  readonly seasonId: string;
  readonly uid: string;
  readonly publicPlayerId: string;
  readonly apelido: string;
  readonly avatar: string;
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
  readonly apelido: string;
  readonly avatar: string;
  /// Rotulo da liga. Vazio quando nao ha escada registrada — e o cliente exibe
  /// vazio, em vez de exibir a primeira liga por default.
  readonly liga: string;
  readonly pontos: number;
  readonly posicao: number;
  readonly direcao: Direcao;
  readonly delta: number;
  readonly selo: string | null;
  readonly souEu: boolean;
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
export function projetarJogador(
  linha: StandingArmazenado,
  uidDoLeitor: string | null
): JogadorPublicado {
  return {
    id: linha.publicPlayerId,
    apelido: linha.apelido,
    avatar: linha.avatar,
    liga: linha.ligaNome ?? "",
    pontos: linha.pontos,
    posicao: linha.posicao ?? POSICAO_NAO_APURADA,
    direcao: linha.direcao,
    delta: linha.deltaPosicao,
    selo: linha.selo,
    // A comparacao acontece nesta linha, e em nenhuma outra do sistema.
    souEu: uidDoLeitor !== null && linha.uid === uidDoLeitor,
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
  "pontos",
  "posicao",
  "direcao",
  "delta",
  "selo",
  "souEu",
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
