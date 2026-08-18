// domain.ts — ponte tipada para o Motor de Torneios.
//
// AS REGRAS NAO MORAM AQUI. Este arquivo carrega `lib/domain_bundle.js`, que e o
// dominio Dart de app/lib/torneios/ compilado por `dart compile js` a partir de
// js_bridge.dart. Elegibilidade, lotacao, desempate, avanco de fase, conclusao,
// premiacao e idempotencia sao decididos LA, pelo mesmo codigo que o app executa
// e que a suite de app/test/torneios/ cobre.
//
// Escrever essas regras em TypeScript criaria uma segunda implementacao do mesmo
// motor — o que a OS 02 secao 1 proibe — e as duas divergiriam no primeiro dia em
// que alguem mudasse um criterio so de um lado. O jogador veria uma classificacao
// na tela e outra no servidor.
//
// O QUE E RESPONSABILIDADE DESTA CAMADA: autenticacao, transacao, leitura e
// escrita no Firestore. Nada que decida competicao.
//
// Regenerar o bundle:  npm run build:domain

/* eslint-disable @typescript-eslint/no-var-requires */
require("../lib/domain_bundle.js");

type PonteJs = (entrada: string) => string;

interface PonteTorneios {
  comporElegibilidade: PonteJs;
  avaliarElegibilidade: PonteJs;
  inscrever: PonteJs;
  avaliarTransicao: PonteJs;
  processarResultado: PonteJs;
  calcularClassificacao: PonteJs;
  apurarFase: PonteJs;
  formarMesas: PonteJs;
  concluirEdicao: PonteJs;
  planejarPremiacao: PonteJs;
  planejarTarefas: PonteJs;
  consolidarConvites: PonteJs;
  montarHistorico: PonteJs;
  avaliarPrimeiraBatidaReal: PonteJs;
}

const ponte = (globalThis as unknown as { bmvTorneios?: PonteTorneios }).bmvTorneios;

if (!ponte) {
  // Falha na carga, e nao no primeiro uso: um bundle ausente que so estourasse
  // na hora de inscrever alguem viraria erro intermitente em producao.
  throw new Error(
    "domain_bundle.js nao carregou. Rode `npm run build:domain` antes de `npm run build`."
  );
}

/// Chama a ponte e devolve o objeto ja parseado.
///
/// O dominio devolve `{erro: "..."}` quando a entrada e invalida — em vez de
/// lancar atraves da fronteira JS, onde a stack se perde. Aqui isso vira excecao
/// de novo, para a Function falhar alto.
function chamar<T>(fn: PonteJs, entrada: unknown): T {
  const bruto = fn(JSON.stringify(entrada));
  const saida = JSON.parse(bruto) as T & { erro?: string };
  if (saida.erro) throw new Error(`dominio de torneios: ${saida.erro}`);
  return saida;
}

// ---------------------------------------------------------------------------
// Tipos de retorno. Espelham o que js_bridge.dart serializa.
// ---------------------------------------------------------------------------

export interface FalhaElegibilidade {
  criterio: string;
  recusa: string;
}

export interface ResultadoInscricao {
  aceita: boolean;
  recusa: string | null;
  inscricao: Record<string, unknown> | null;
  falhas: FalhaElegibilidade[];
}

export interface ResultadoTransicao {
  permitida: boolean;
  destino: string | null;
  recusa: string | null;
}

export interface ResultadoProcessamento {
  processado: boolean;
  idempotente: boolean;
  recusa: string | null;
  chaveIdempotencia: string;
}

export interface LinhaClassificacao {
  posicao: number;
  participanteId: string;
  situacao: string;
  empateNaoResolvido: boolean;
  vitorias: number;
  derrotas: number;
  pontosFeitos: number;
  pontosSofridos: number;
  saldo: number;
  canastrasLimpas: number;
  partidasConcluidas: number;
}

export interface ResultadoApuracao {
  apurada: boolean;
  recusa: string | null;
  avancam: string[];
  classificacao: LinhaClassificacao[];
}

export interface ResultadoFormacao {
  formada: boolean;
  recusa: string | null;
  mesas: Array<Record<string, unknown>>;
  excedentes: string[];
}

export interface ResultadoConclusao {
  concluida: boolean;
  idempotente: boolean;
  recusa: string | null;
  conclusao: Record<string, unknown> | null;
}

export interface PremiacaoPlanejada {
  userId: string;
  colocacao: number;
  fichas: number | null;
  concedida: boolean;
  recusa: string | null;
  concessao: Record<string, unknown> | null;
}

export interface TarefaPendente {
  tarefa: string;
  tournamentId: string;
  editionId: string;
  alvo: string | null;
  venceuEm: string;
  transicaoPara: string | null;
  chaveIdempotencia: string;
}

export interface ResultadoConvites {
  convites: Array<Record<string, unknown> & { userId: string; chaveIdempotencia: string }>;
  excedentes: Array<Record<string, unknown>>;
}

// ---------------------------------------------------------------------------
// API
// ---------------------------------------------------------------------------

export interface PerfilElegibilidade {
  userId: string;
  nivel: number | null;
  posicaoRanking: number | null;
  assinaturaAtiva: boolean;
  convitesAtivos: string[];
  conquistas: string[];
  participacoes: string[];
  titulos: string[];
  temporadasAtivas: string[];
  suspenso: boolean;
}

/// O que o dominio responde sobre a conquista `primeira_batida_real`.
///
/// `elegivel: false` NAO e erro: e a resposta normal da imensa maioria dos
/// encerramentos. `motivo` traz o codigo estavel da recusa, para o log.
export interface VeredictoConquista {
  elegivel: boolean;
  userId: string | null;
  assento: number | null;
  motivo: string | null;
  conquistaId: string;
  versaoContrato: number;
  origem: string;
}

export const dominio = {
  /// Monta o retrato de elegibilidade a partir dos documentos das FONTES REAIS
  /// (`playerModeration/{uid}` e `playerEntitlements/{uid}`).
  ///
  /// Esta camada le os documentos; quem decide o que eles significam — se a
  /// suspensao ainda vale, se o VIP ainda esta no prazo — e o dominio Dart, pelo
  /// mesmo motivo de sempre: uma segunda implementacao aqui divergiria da
  /// primeira, e a divergencia seria justamente em quem entra e quem nao entra.
  comporElegibilidade: (e: unknown) =>
    chamar<PerfilElegibilidade>(ponte.comporElegibilidade, e),

  avaliarElegibilidade: (e: unknown) =>
    chamar<{ elegivel: boolean; falhas: FalhaElegibilidade[] }>(ponte.avaliarElegibilidade, e),

  inscrever: (e: unknown) => chamar<ResultadoInscricao>(ponte.inscrever, e),

  avaliarTransicao: (e: unknown) => chamar<ResultadoTransicao>(ponte.avaliarTransicao, e),

  processarResultado: (e: unknown) =>
    chamar<ResultadoProcessamento>(ponte.processarResultado, e),

  calcularClassificacao: (e: unknown) =>
    chamar<{ classificacao: LinhaClassificacao[] }>(ponte.calcularClassificacao, e),

  apurarFase: (e: unknown) => chamar<ResultadoApuracao>(ponte.apurarFase, e),

  formarMesas: (e: unknown) => chamar<ResultadoFormacao>(ponte.formarMesas, e),

  concluirEdicao: (e: unknown) => chamar<ResultadoConclusao>(ponte.concluirEdicao, e),

  planejarPremiacao: (e: unknown) =>
    chamar<{ premiacoes: PremiacaoPlanejada[] }>(ponte.planejarPremiacao, e),

  planejarTarefas: (e: unknown) =>
    chamar<{ tarefas: TarefaPendente[] }>(ponte.planejarTarefas, e),

  consolidarConvites: (e: unknown) => chamar<ResultadoConvites>(ponte.consolidarConvites, e),

  montarHistorico: (e: unknown) => chamar<Record<string, unknown>>(ponte.montarHistorico, e),

  /// Decide quem — se alguem — ganhou a conquista `primeira_batida_real` num
  /// encerramento de partida.
  ///
  /// Entrada: `{registro}`, o JSON INTEIRO de `RegistroDePartida.toJson()`. Nao
  /// se escolhem campos aqui de proposito: escolher seria decidir o que importa,
  /// e quem decide e o dominio.
  ///
  /// A regra vive em `app/lib/conquistas/primeira_batida_real.dart` e nao esta
  /// reescrita nesta camada. Se algum dia aparecer um `if` de elegibilidade de
  /// conquista neste arquivo, ele esta no lugar errado — pelo mesmo motivo que
  /// o cabecalho deste modulo ja da para o Motor de Torneios.
  avaliarPrimeiraBatidaReal: (e: unknown) =>
    chamar<VeredictoConquista>(ponte.avaliarPrimeiraBatidaReal, e),
};

/// Instante atual no formato que o dominio exige: ISO-8601 com sufixo Z.
///
/// O dominio RECUSA data sem fuso — a mesma decisao ja tomada em
/// reward_grants.dart. Esta funcao existe para que nenhuma Function invente o
/// proprio formato e descubra a recusa em producao.
export function agoraUtc(): string {
  return new Date().toISOString();
}
