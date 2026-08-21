// competicao.ts — A POLITICA COMPETITIVA V1: quem compete, em que estado, e por
// qual escada.
//
// Este arquivo e a resposta as secoes 3 a 8, 15, 16, 21 e 25 da OS. Ele e o par
// de `elo.ts`: la mora QUANTO vale um resultado, aqui mora QUEM tem direito a
// que ele valha alguma coisa.
//
// ELE E TAMBEM O ARQUIVO QUE ENCERRA A PENDENCIA DECLARADA EM `politica.ts`. Ate
// esta OS, o registro de calculadoras saia vazio de fabrica e todo resultado
// oficial virava `politica_nao_definida` no backlog. `registrarPoliticaV1()`
// abaixo e a linha que troca esse estado por uma regra real, versionada e
// testada — sem apagar o mecanismo de pendencia, que continua valendo para
// qualquer temporada que ainda nao tenha escolhido politica.
//
// ---------------------------------------------------------------------------
// O PRINCIPIO DE PRODUTO, QUE E O QUE ESTE ARQUIVO IMPLEMENTA (secao 37)
// ---------------------------------------------------------------------------
//   Mesa Publica e o jogo casual.
//   Mesa VIP/Ranqueada e o campeonato.
//   O jogador paga para PARTICIPAR da competicao, nunca para ter vantagem
//   dentro dela.
//
// A segunda metade da ultima frase e verificavel por ausencia: procure por
// "vip", "assinante" ou "entitlement" neste arquivo e em `elo.ts`. Nao ha
// ocorrencia nenhuma. O acesso VIP decide se a partida NASCE ranqueada — decisao
// que acontece na abertura da mesa, fora deste codebase — e a partir dai o
// calculo trata todo mundo igual.

import {
  CalculoDeDelta,
  EntradaDeCalculo,
  PoliticaDeRanking,
  registrarCalculadora,
} from "./politica";
import {
  K_CLASSIFICADO,
  K_COLOCACAO,
  PARTIDAS_DE_COLOCACAO,
  PARTIDAS_DE_REVALIDACAO,
  RATING_INICIAL,
  ResultadoElo,
  deltaElo,
  expectativa,
  ratingDaDupla,
  softReset,
} from "./elo";
import { DegrauDeLiga, EscadaDeLigas } from "./ligas";

// ---------------------------------------------------------------------------
// A POLITICA, VERSIONADA (secao 25)
// ---------------------------------------------------------------------------

/// A regra competitiva desta OS, identificada e versionada.
///
/// POR QUE A VERSAO E OBRIGATORIA, e nao um capricho: todo lancamento em
/// `rankingLedger` e toda contribuicao em `rankingContributions` gravam este
/// objeto. Sem ele, reconstruir por que um jogador ganhou 13 pontos numa partida
/// de marco exigiria adivinhar qual era o codigo em marco. Com ele, a pergunta
/// tem resposta no proprio documento.
///
/// QUANDO ISTO MUDA: qualquer alteracao que faca a MESMA partida produzir um
/// delta DIFERENTE e uma versao nova — corrigir um K, mudar o divisor, mudar o
/// arredondamento. Corrigir um comentario nao e. A versao nova nao reescreve os
/// lancamentos antigos: ela passa a valer para os proximos, e a chave de
/// idempotencia de `rankingContributions` (que inclui `politica|vN`) permite
/// reprocessar uma temporada sob a regra nova sem colidir com a antiga.
export const POLITICA_COMPETITIVA_V1: PoliticaDeRanking = {
  id: "competitiva",
  versao: 1,
};

// ---------------------------------------------------------------------------
// AMBIENTE COMPETITIVO (secoes 3, 5 e 6)
// ---------------------------------------------------------------------------

/// Os tipos de partida que alimentam ESTE rating. Lista fechada.
///
/// UM UNICO ELEMENTO, e cada ausencia e uma decisao da OS:
///
///   publica_casual .. secao 3.1. Mesa Publica e o modo casual. Ela registra
///                     partida, estatistica e historico pessoal, e exibe anuncio
///                     — mas nao altera rating, nao altera Liga, nao conta como
///                     partida de colocacao e nao entra na classificacao.
///   torneio ......... secao 6. Torneio tera classificacao propria, titulo,
///                     premiacao, Hall e trofeu. Nada disso passa por aqui na
///                     v1: nenhuma partida de torneio alimenta o rating regular.
///   privada ......... o dono da sala escolhe os adversarios, o que torna a
///                     pontuacao combinavel por construcao (decisao anterior,
///                     registrada em `TipoDePartida.privada`).
///   treinamento ..... nunca pontuou.
///   contra_robos .... nunca pontuou; seria a forma mais barata de farmar
///                     pontuacao que existe.
///
/// POR QUE ESTA LISTA EXISTE, SE O REGISTRO JA TEM `alteraRanking`: porque os
/// dois nao querem dizer a mesma coisa, e a diferenca e exatamente o torneio.
/// `TipoDePartida.alteraRanking`, do dominio Dart, e
/// `publicaRanqueada || torneio` — ele responde "esta partida produz lancamento
/// no ledger competitivo?". A secao 6 desta OS respondeu uma pergunta MAIS
/// ESTREITA: "esta partida alimenta o rating de temporada?", e ali o torneio esta
/// fora. Reaproveitar `alteraRanking` sozinho faria toda partida de torneio
/// pontuar Elo, que e o defeito que a secao 6 manda testar.
///
/// As duas guardas sao aplicadas em serie, e nenhuma substitui a outra: o
/// registro precisa dizer `alteraRanking == true` E o tipo precisa estar nesta
/// lista.
export const AMBIENTE_COMPETITIVO: ReadonlyArray<string> = ["publica_ranqueada"];

export function noAmbienteCompetitivo(tipo: string): boolean {
  return AMBIENTE_COMPETITIVO.includes(tipo);
}

// ---------------------------------------------------------------------------
// ESTADO COMPETITIVO DO JOGADOR (secoes 8 e 21)
// ---------------------------------------------------------------------------

/// Onde o jogador esta na temporada.
///
///   em_colocacao ..... nunca consolidou uma Liga. 10 partidas (secao 8).
///   em_revalidacao ... ja consolidou numa temporada anterior e entrou nesta com
///                      soft reset. 5 partidas (secao 21).
///   classificado ..... cumpriu a exigencia e tem Liga.
///
/// OS DOIS PRIMEIROS NAO SAO LIGAS. Enquanto o jogador esta neles, `ligaId` fica
/// nulo e a tela mostra "Em colocacao" / "Em revalidacao" — nunca Bronze. A
/// secao 15 e explicita: "Durante colocacao: `Em colocacao`, nao Bronze/Prata".
/// Mostrar Bronze para quem ainda nao foi medido seria afirmar um rebaixamento
/// que nao aconteceu.
export const ESTADOS_COMPETITIVOS = [
  "em_colocacao",
  "em_revalidacao",
  "classificado",
] as const;

export type EstadoCompetitivo = (typeof ESTADOS_COMPETITIVOS)[number];

/// Le um estado persistido, caindo em `em_colocacao` para o que nao reconhecer.
///
/// O DEFAULT E O CERTO PARA O CASO QUE ELE ATENDE: uma linha de standing gravada
/// antes desta OS nao tem o campo, e um jogador cujo estado o sistema nao
/// registrou e, por definicao, um jogador que ainda nao foi colocado. O default
/// oposto (`classificado`) daria Liga a quem nunca cumpriu colocacao nenhuma.
export function estadoCompetitivoDeJson(bruto: unknown): EstadoCompetitivo {
  return (ESTADOS_COMPETITIVOS as ReadonlyArray<string>).includes(`${bruto}`)
    ? (bruto as EstadoCompetitivo)
    : "em_colocacao";
}

/// Le um estado que TEM que ser valido, e falha alto quando nao e.
///
/// Usado no caminho do CALCULO, onde `estadoCompetitivoDeJson` seria perigoso:
/// um estado irreconhecivel chegando na calculadora significa defeito de quem
/// montou a entrada, e cair em `em_colocacao` transformaria esse defeito num
/// K=40 aplicado a um jogador classificado — um delta errado, gravado no ledger,
/// que e permanente. Melhor nao pontuar do que pontuar errado.
export function exigirEstadoCompetitivo(bruto: string): EstadoCompetitivo {
  if (!(ESTADOS_COMPETITIVOS as ReadonlyArray<string>).includes(bruto)) {
    throw new Error(
      `estado competitivo desconhecido: "${bruto}" (esperado: ${ESTADOS_COMPETITIVOS.join(", ")})`
    );
  }
  return bruto as EstadoCompetitivo;
}

/// O jogador ainda esta sendo localizado pelo sistema?
export function emQualificacao(estado: EstadoCompetitivo): boolean {
  return estado === "em_colocacao" || estado === "em_revalidacao";
}

/// Quantas partidas o estado exige antes de consolidar a Liga.
export function partidasExigidas(estado: EstadoCompetitivo): number {
  if (estado === "em_colocacao") return PARTIDAS_DE_COLOCACAO;
  if (estado === "em_revalidacao") return PARTIDAS_DE_REVALIDACAO;
  return 0;
}

/// O fator K do jogador (secoes 10 e 21).
///
/// A LINHA DE CORTE E "JA FOI CLASSIFICADO ALGUMA VEZ?", e nao "esta em
/// qualificacao?". Só a COLOCACAO INICIAL usa 40; revalidacao e classificado
/// usam 24.
///
/// A distincao importa porque `emQualificacao` continua valendo para OUTRA
/// coisa: contar partidas para a exigencia (10 ou 5). Os dois estados
/// provisorios contam partidas; so um deles tem K alto. Reaproveitar
/// `emQualificacao` aqui — que era o que esta funcao fazia antes da decisao de
/// produto — juntava as duas perguntas numa condicao so, e a resposta certa
/// para uma virava a resposta errada para a outra.
///
/// Cada jogador usa o PROPRIO K, mesmo que o parceiro esteja em outro estado —
/// a secao 10 pede isso com todas as letras, e e o que faz sentido: o K mede a
/// confianca do sistema NAQUELE jogador, e a confianca nao e compartilhada por
/// estar sentado do mesmo lado da mesa.
export function kDoEstado(estado: EstadoCompetitivo): number {
  return estado === "em_colocacao" ? K_COLOCACAO : K_CLASSIFICADO;
}

/// O estado do jogador DEPOIS de mais uma partida ranqueada valida.
///
/// A conta e simples de proposito: se o jogador estava em qualificacao e esta
/// partida completou a exigencia, ele passa a `classificado`. Nao ha caminho de
/// volta — a secao 32 proibe explicitamente rebaixamento por inatividade (decay)
/// e protecao de Liga, e voltar alguem para colocacao seria uma terceira
/// mecanica que a OS nao pediu. A revalidacao seguinte acontece na virada de
/// temporada, e nao dentro dela.
export function estadoApos(
  estado: EstadoCompetitivo,
  partidasDeQualificacaoJaCumpridas: number
): EstadoCompetitivo {
  if (!emQualificacao(estado)) return "classificado";
  return partidasDeQualificacaoJaCumpridas >= partidasExigidas(estado)
    ? "classificado"
    : estado;
}

// ---------------------------------------------------------------------------
// SEMENTE: COMO UM JOGADOR ENTRA NUMA TEMPORADA (secoes 7, 20 e 21)
// ---------------------------------------------------------------------------

/// O que se sabe do passado competitivo de um jogador ao ve-lo pela primeira vez
/// numa temporada.
///
/// Vem de `rankingPlayers/{uid}`, escrito pela consolidacao do encerramento de
/// temporada. `null` quando o jogador nunca terminou uma temporada classificado.
export interface HistoricoConsolidado {
  /// A ultima temporada ENCERRADA em que ele terminou classificado.
  readonly seasonId: string;
  /// O rating com que terminou aquela temporada.
  readonly ratingFinal: number;
}

export interface SementeDaTemporada {
  readonly rating: number;
  readonly estado: EstadoCompetitivo;
  readonly qualificacaoExigida: number;
}

/// Com que rating e em que estado um jogador entra numa temporada.
///
/// AS DUAS PORTAS, e a diferenca entre elas e a unica coisa que este trecho
/// decide:
///
///   sem historico consolidado -> 1000, `em_colocacao`, 10 partidas (secoes 7 e 8)
///   com historico consolidado -> soft reset, `em_revalidacao`, 5 partidas (secoes 20 e 21)
///
/// "COM HISTORICO CONSOLIDADO" EXIGE TER TERMINADO CLASSIFICADO, e nao apenas
/// ter aparecido numa temporada anterior. Quem entrou em novembro, jogou 4
/// partidas de colocacao e viu a temporada acabar nunca teve classificacao
/// competitiva — a secao 21 fala em "jogador que ja possuia classificacao
/// competitiva anterior". Ele volta para as 10 partidas, do 1000, que e o
/// tratamento correto para alguem que o sistema ainda nao mediu.
export function sementeDaTemporada(historico: HistoricoConsolidado | null): SementeDaTemporada {
  if (historico === null) {
    return {
      rating: RATING_INICIAL,
      estado: "em_colocacao",
      qualificacaoExigida: PARTIDAS_DE_COLOCACAO,
    };
  }
  return {
    rating: softReset(historico.ratingFinal),
    estado: "em_revalidacao",
    qualificacaoExigida: PARTIDAS_DE_REVALIDACAO,
  };
}

// ---------------------------------------------------------------------------
// A EVOLUCAO DE UM JOGADOR DENTRO DA TEMPORADA (secoes 8, 17 e 21)
// ---------------------------------------------------------------------------

/// Tudo que a temporada sabe sobre um jogador num instante.
export interface SituacaoCompetitiva {
  readonly rating: number;
  readonly estado: EstadoCompetitivo;
  readonly partidas: number;
  readonly partidasDeQualificacao: number;
  readonly qualificacaoExigida: number;
  readonly vitorias: number;
  readonly derrotas: number;
  readonly empates: number;
  readonly saldoPontos: number;
  readonly abandonos: number;
  readonly ratingAtingidoEm: string;
}

/// A situacao inicial de quem entra numa temporada agora.
export function situacaoInicial(historico: HistoricoConsolidado | null): SituacaoCompetitiva {
  const semente = sementeDaTemporada(historico);
  return {
    rating: semente.rating,
    estado: semente.estado,
    partidas: 0,
    partidasDeQualificacao: 0,
    qualificacaoExigida: semente.qualificacaoExigida,
    vitorias: 0,
    derrotas: 0,
    empates: 0,
    saldoPontos: 0,
    abandonos: 0,
    ratingAtingidoEm: "",
  };
}

/// O que uma partida ja calculada faz com a situacao do jogador.
export interface EfeitoDaPartida {
  /// O desfecho deste jogador (1 / 0.5 / 0).
  readonly resultado: ResultadoElo;
  /// O delta ja calculado pela calculadora da politica.
  readonly delta: number;
  /// Pontos do meu lado menos pontos do lado adversario, no placar oficial.
  readonly saldoDaPartida: number;
  /// O instante do servidor. Recebido, e nao lido: esta camada nao le relogio.
  readonly agora: string;
}

/// A situacao do jogador DEPOIS de uma partida ranqueada valida.
///
/// FUNCAO PURA, E ESSE E O PONTO. Toda a evolucao de um jogador dentro da
/// temporada — rating, contadores, consumo de colocacao, consolidacao da Liga e
/// o carimbo do quinto criterio de desempate — acontece aqui e em nenhum outro
/// lugar. `firestore.ts` so a chama e grava o que ela devolve.
///
/// A alternativa (a mesma aritmetica escrita dentro da transacao) foi descartada
/// por um motivo concreto: sem funcao pura, provar "10 partidas consolidam e a
/// 11a nao consome nada" exigiria subir o emulador, e o teste que mais importa
/// nesta OS seria o mais caro de rodar.
///
/// SO E CHAMADA PARA PARTIDA RANQUEADA VALIDA. Casual, torneio, anulada e
/// incompleta sao recusadas antes, em `resultado.ts`, e por isso nunca consomem
/// uma das 10 (ou 5) partidas de qualificacao — que e a exigencia literal da
/// secao 8.
export function situacaoApos(
  atual: SituacaoCompetitiva,
  efeito: EfeitoDaPartida
): SituacaoCompetitiva {
  const partidasDeQualificacao = emQualificacao(atual.estado)
    ? atual.partidasDeQualificacao + 1
    : atual.partidasDeQualificacao;

  return {
    rating: atual.rating + efeito.delta,
    estado: estadoApos(atual.estado, partidasDeQualificacao),
    partidas: atual.partidas + 1,
    partidasDeQualificacao,
    qualificacaoExigida: atual.qualificacaoExigida,
    vitorias: atual.vitorias + (efeito.resultado === 1 ? 1 : 0),
    derrotas: atual.derrotas + (efeito.resultado === 0 ? 1 : 0),
    empates: atual.empates + (efeito.resultado === 0.5 ? 1 : 0),
    saldoPontos: atual.saldoPontos + efeito.saldoDaPartida,
    // NAO E INCREMENTADO POR PARTIDA. O registro oficial marca que houve
    // abandono, mas nao diz QUEM abandonou (ver o relatorio). Atribuir aos dois
    // integrantes do lado perdedor puniria o parceiro inocente, que seria uma
    // regra inventada. O contador existe, e ordenado pelo criterio 4 do
    // desempate, e fica correto no dia em que a autoridade disser quem saiu.
    abandonos: atual.abandonos,
    // CRITERIO 5 DO DESEMPATE (secao 17): o carimbo so anda quando o rating
    // MUDA. Delta zero preserva "desde quando este jogador esta neste rating",
    // que e literalmente o que o criterio pergunta.
    ratingAtingidoEm: efeito.delta === 0 ? atual.ratingAtingidoEm : efeito.agora,
  };
}

// ---------------------------------------------------------------------------
// AS SETE LIGAS (secoes 15 e 16)
// ---------------------------------------------------------------------------

/// O id da escada desta politica. Uma temporada aponta para ela por este texto.
export const LADDER_V1_ID = "competitiva-v1";

/// AS SETE LIGAS OFICIAIS DA V1, EXATAMENTE COMO A SECAO 15 AS DEFINE.
///
/// ESTE E O UNICO LUGAR DO SISTEMA COM ESTES NUMEROS (secao 16: "Evitar espalhar
/// numeros magicos em multiplos arquivos"). Nem a apuracao, nem a projecao, nem
/// os testes de limite repetem 950 ou 1699 — todos derivam daqui.
///
/// O PISO DO BRONZE E ABERTO (`null`), e nao um numero grande e negativo. A secao
/// 15 diz "Bronze: abaixo de 950", sem piso, e um piso inventado (0? -1000?)
/// criaria uma faixa de rating sem Liga nenhuma embaixo dele — que e exatamente
/// o defeito "buraco entre faixas" que `conferirEscada` recusa. Simetrico ao teto
/// aberto de Lenda.
///
/// `icone` E UMA TABELA LITERAL, e nao uma derivacao do nome. Sete linhas,
/// escritas uma a uma. A alternativa obvia — `assets/ranking/liga_` mais o nome
/// em minusculas — foi recusada em `DegrauDeLiga.icone` desde o primeiro dia, e
/// a razao acabou de se provar concreta: por seis meses a sexta arte se chamou
/// `liga_imperial.webp` enquanto a secao 15 nomeia a sexta liga MESTRE. Uma
/// regra de derivacao teria apontado para um arquivo inexistente — ou, pior,
/// teria convidado alguem a renomear a LIGA para caber no nome do ARQUIVO.
///
/// A ARTE DA MESTRE ENTROU NA OS DE CANONIZACAO:
/// `app/assets/ranking/liga_mestre.webp`, 256x256 WebP sRGBA com canal alfa
/// real. `liga_imperial.webp` SAIU do catalogo oficial — o arquivo continua no
/// repositorio como legado nao referenciado, e `test/competicao.test.js` reprova
/// se o nome voltar a aparecer aqui.
///
/// CADA CAMINHO E CONFERIDO CONTRA O DISCO por `test/competicao.test.js`: os
/// sete arquivos tem de existir sob `app/`. Apagar uma arte, renomear uma, ou
/// tirar uma linha desta tabela derruba o gate — que e o que a secao 7.2 da OS
/// de canonizacao pede com todas as letras.
///
/// NAO HA, e a secao 15 proibe cada um: Bronze I/II/III, subdivisao, estrela,
/// ponto de promocao, partida de promocao, protecao contra queda ou demotion
/// shield. A Liga e uma funcao pura do rating, e nada mais.
export const DEGRAUS_V1: ReadonlyArray<DegrauDeLiga> = [
  { ligaId: "bronze", nome: "Bronze", icone: "assets/ranking/liga_bronze.webp", pontosMinimos: null, pontosMaximos: 949 },
  { ligaId: "prata", nome: "Prata", icone: "assets/ranking/liga_prata.webp", pontosMinimos: 950, pontosMaximos: 1099 },
  { ligaId: "ouro", nome: "Ouro", icone: "assets/ranking/liga_ouro.webp", pontosMinimos: 1100, pontosMaximos: 1249 },
  { ligaId: "platina", nome: "Platina", icone: "assets/ranking/liga_platina.webp", pontosMinimos: 1250, pontosMaximos: 1399 },
  { ligaId: "diamante", nome: "Diamante", icone: "assets/ranking/liga_diamante.webp", pontosMinimos: 1400, pontosMaximos: 1549 },
  { ligaId: "mestre", nome: "Mestre", icone: "assets/ranking/liga_mestre.webp", pontosMinimos: 1550, pontosMaximos: 1699 },
  { ligaId: "lenda", nome: "Lenda", icone: "assets/ranking/liga_lenda.webp", pontosMinimos: 1700, pontosMaximos: null },
];

export const ESCADA_V1: EscadaDeLigas = {
  ladderId: LADDER_V1_ID,
  nome: "Escada competitiva v1",
  degraus: DEGRAUS_V1,
};

/// As escadas que vivem em CODIGO, indexadas por id.
///
/// POR QUE A ESCADA E CODIGO E NAO DOCUMENTO, que e a mesma decisao ja registrada
/// para a formula em `politica.ts`: uma faixa de Liga digitada num documento do
/// Firestore seria editavel sem revisao, sem teste e sem historico, e mudaria a
/// Liga de todo mundo entre duas leituras. `rankingLadders` continua existindo e
/// continua legivel, para escadas futuras que nao sejam a oficial; a resolucao
/// consulta o codigo PRIMEIRO justamente para que um documento adulterado nao
/// consiga rebaixar ninguem.
const ESCADAS_EM_CODIGO = new Map<string, EscadaDeLigas>([[LADDER_V1_ID, ESCADA_V1]]);

export function escadaEmCodigo(ladderId: string): EscadaDeLigas | null {
  return ESCADAS_EM_CODIGO.get(ladderId) ?? null;
}

// ---------------------------------------------------------------------------
// A CALCULADORA (secoes 9 a 14)
// ---------------------------------------------------------------------------

/// Traduz o desfecho oficial no resultado que o Elo entende (secoes 10 e 12).
///
/// EMPATE: `ladoVencedor == null` numa partida que a autoridade deu por
/// encerrada e um desfecho SEM VENCEDOR, e a secao 12 manda trata-lo como 0.5
/// para os dois lados. A calculadora sabe fazer isso; se o dominio do jogo
/// produz ou nao esse desfecho e assunto do dominio, e nao foi inventado aqui
/// nenhum mecanismo para criar empates.
///
/// A consistencia do desfecho (lado do jogador conhecido, lado vencedor existente
/// na mesa) e conferida ANTES, em `resultado.ts`. Aqui ela e pressuposta.
export function resultadoElo(
  ladoVencedor: string | null,
  ladoDoJogador: string
): ResultadoElo {
  if (ladoVencedor === null) return 0.5;
  return ladoVencedor === ladoDoJogador ? 1 : 0;
}

/// O delta de um jogador sob a Politica Competitiva v1.
///
/// A SEQUENCIA INTEIRA, em cinco linhas e sem ramificacao escondida:
///   1. a forca da minha dupla e a media do rating dos meus (secao 9);
///   2. a forca da dupla adversaria, idem;
///   3. a expectativa sai da diferenca entre as duas (secao 10);
///   4. o K sai do MEU estado, nao do da dupla (secao 10);
///   5. delta = K x (real - esperado), arredondado (secoes 10 e 11).
///
/// O placar da partida esta em `entrada`, e NAO E LIDO. Ele existe ali para as
/// estatisticas e o desempate, e a secao 11 proibe que ele multiplique o delta.
export const calcularDeltaV1: CalculoDeDelta = (entrada: EntradaDeCalculo): number => {
  const minha = ratingDaDupla(entrada.ratingsDaMinhaDupla);
  const adversaria = ratingDaDupla(entrada.ratingsDaDuplaAdversaria);
  return deltaElo({
    k: kDoEstado(exigirEstadoCompetitivo(entrada.estadoCompetitivo)),
    resultado: resultadoElo(entrada.ladoVencedor, entrada.ladoDoJogador as string),
    esperado: expectativa(minha, adversaria),
  });
};

/// Liga a Politica Competitiva v1 ao registro de calculadoras.
///
/// CHAMADA UMA VEZ, na carga do modulo de Functions (`index.ts`). E a linha que
/// faz `PoliticaDeRanking.pendente` deixar de ser a politica ativa do projeto: a
/// partir daqui, uma temporada que declare `competitiva@v1` pontua de verdade, e
/// o backlog acumulado sob `politica_nao_definida` passa a ser reprocessavel.
///
/// Idempotente: registrar duas vezes sobrescreve com a mesma funcao. Isso importa
/// porque testes e producao carregam o modulo em ordens diferentes.
export function registrarPoliticaV1(): void {
  registrarCalculadora(POLITICA_COMPETITIVA_V1, calcularDeltaV1);
}
