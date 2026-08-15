// diario.ts — a LAPIDE, e a barreira de idempotencia que nasce dela.
//
// MODULO PURO DE PROPOSITO: tipos e decisoes, sem firebase-admin. `executor.ts`
// e quem le e grava; aqui so se decide o que fazer diante do que foi lido, e e
// por isso que `test/diario.test.js` prova a chamada duplicada, a retomada e a
// falha parcial com `node --test`, sem emulador.
//
// ===========================================================================
// POR QUE UM DIARIO, E NAO A BARREIRA DOS VIZINHOS
// ===========================================================================
//
// `functions-moderacao/src/idempotency.ts` e `functions/src/idempotency.ts`
// resolvem um problema mais simples: uma operacao CURTA, que cabe numa
// transacao, e cuja repeticao deve simplesmente nao acontecer. Reservar a chave
// e rodar o corpo resolve.
//
// A exclusao de conta nao cabe numa transacao e nao deveria caber. Ela toca
// dezenas de documentos em colecoes diferentes, varre subcolecoes de tamanho
// desconhecido, e chama o Authentication, que nao participa de transacao do
// Firestore de jeito nenhum. Uma tentativa de fazer tudo atomicamente
// produziria uma transacao que estoura limite e falha SEMPRE nas contas
// grandes — justamente as que mais tem dado a remover.
//
// Entao a atomicidade e trocada por algo que serve melhor a esta operacao:
//
//   TODA ETAPA E IDEMPOTENTE, E O PROGRESSO E REGISTRADO.
//
// Apagar um documento que ja nao existe e sucesso. Gravar o mesmo apelido
// anonimo duas vezes e o mesmo estado. Cortar um `uid` ja cortado nao muda
// nada. Como nenhuma etapa se importa de rodar de novo, a repeticao nunca
// corrompe — e como o progresso fica gravado, ela quase nunca precisa rodar.
//
// A CONSEQUENCIA PRATICA, que e o comportamento que a OS pede em "falha
// parcial" e "idempotencia": uma exclusao interrompida no meio fica com estado
// `parcial` e a lista do que ja foi feito. A proxima chamada retoma de onde
// parou. Uma exclusao concluida responde "ja foi" sem tocar em nada.

/// Estados do diario. Nao ha "pendente": o documento so nasce quando a execucao
/// comeca, e nascer ja significa que ela comecou.
export const ESTADO_EXCLUSAO = {
  /// Comecou e ainda nao terminou. Tambem e o estado que uma instancia morta no
  /// meio deixa para tras — e por isso ele NAO tranca a retomada.
  EM_ANDAMENTO: "emAndamento",
  /// Parou com erro numa etapa. Retomavel.
  PARCIAL: "parcial",
  /// Todas as etapas concluidas, conta do Authentication apagada.
  CONCLUIDA: "concluida",
} as const;

export type EstadoExclusao = (typeof ESTADO_EXCLUSAO)[keyof typeof ESTADO_EXCLUSAO];

export interface FalhaDeEtapa {
  readonly etapa: string;
  readonly erro: string;
  readonly em: string;
}

/// O documento `accountDeletions/{uid}`.
///
/// NAO CARREGA APELIDO, E-MAIL NEM AVATAR. E a diferenca entre uma lapide e um
/// arquivo do jogador: guarda que a conta existiu e o que foi feito com ela, e
/// nao quem ela era. `publicId` fica porque e o codigo opaco que aparece nas
/// linhas historicas — e sem ele o suporte nao consegue ligar um pedido
/// ("o jogador P0123456789AB reclamou") ao registro da exclusao.
export interface Diario {
  readonly uid: string;
  readonly publicId: string | null;
  readonly estado: EstadoExclusao;
  readonly solicitadaEm: string;
  readonly atualizadaEm: string;
  readonly concluidaEm: string | null;
  readonly etapasConcluidas: readonly string[];
  readonly falhas: readonly FalhaDeEtapa[];
  /// Quantas vezes a execucao foi disparada. Uma conta com `tentativas: 4`
  /// merece investigacao mesmo que tenha terminado.
  readonly tentativas: number;
  /// O que existia no encerramento. E o que permite ao suporte responder a um
  /// pedido de estorno depois, sem manter a carteira e o entitlement vivos.
  readonly resumo: ResumoDoEncerramento;
  readonly esquema: number;
}

export interface ResumoDoEncerramento {
  readonly fichas: number | null;
  readonly vipAtivo: boolean | null;
  readonly vipExpiraEm: string | null;
  readonly amizades: number | null;
  readonly comprasDesvinculadas: number | null;
}

export const ESQUEMA_DIARIO = 1;

export const RESUMO_VAZIO: ResumoDoEncerramento = {
  fichas: null,
  vipAtivo: null,
  vipExpiraEm: null,
  amizades: null,
  comprasDesvinculadas: null,
};

// ---------------------------------------------------------------------------
// A DECISAO
// ---------------------------------------------------------------------------

export const ACAO = {
  /// Nao ha diario: comecar do zero.
  COMECAR: "comecar",
  /// Ha diario incompleto: retomar das etapas que faltam.
  RETOMAR: "retomar",
  /// Ja concluida: responder sucesso repetido, sem tocar em nada.
  CONVERGIR: "convergir",
} as const;

export type Acao = (typeof ACAO)[keyof typeof ACAO];

export interface DecisaoDeExecucao {
  readonly acao: Acao;
  readonly concluidas: readonly string[];
}

/// O que fazer diante do diario (ou da ausencia dele).
///
/// A CHAMADA DUPLICADA E O CASO CENTRAL, e ela tem duas formas que precisam de
/// respostas diferentes:
///
///   * duplo toque no botao, com a primeira execucao ainda em voo. O diario
///     esta `emAndamento`. A resposta e RETOMAR, e nao um erro: as etapas ja
///     concluidas sao saltadas e as demais sao idempotentes, entao as duas
///     execucoes convergem no mesmo estado final. Recusar aqui seria pior —
///     uma instancia que morreu deixa `emAndamento` para sempre, e um `erro:
///     ja em andamento` trancaria a conta num limbo sem saida.
///
///   * chamada depois de tudo pronto. O diario esta `concluida`. A resposta e
///     CONVERGIR: sucesso, com a marca de repeticao. E o mesmo desenho de
///     `jaRegistrada: true` que as Functions de torneio e moderacao ja usam.
export function decidirExecucao(
  existente: Partial<Diario> | null | undefined
): DecisaoDeExecucao {
  if (!existente) return { acao: ACAO.COMECAR, concluidas: [] };

  const concluidas = Array.isArray(existente.etapasConcluidas)
    ? existente.etapasConcluidas.filter((e): e is string => typeof e === "string")
    : [];

  if (existente.estado === ESTADO_EXCLUSAO.CONCLUIDA) {
    return { acao: ACAO.CONVERGIR, concluidas };
  }

  return { acao: ACAO.RETOMAR, concluidas };
}

/// Registra uma etapa concluida sem duplicar.
///
/// A lista e um conjunto ordenado: repetir a mesma etapa numa retomada nao pode
/// fazer o diario crescer sem limite.
export function comEtapaConcluida(
  concluidas: readonly string[],
  etapa: string
): readonly string[] {
  return concluidas.includes(etapa) ? concluidas : [...concluidas, etapa];
}

/// O estado final, a partir do que aconteceu.
///
/// `parcial` exige as duas coisas: falha registrada E etapa faltando. Uma falha
/// numa etapa que a retomada seguinte concluiu nao deixa a conta parcial para
/// sempre — o historico da falha fica em `falhas`, que e o lugar dela.
export function estadoFinal(
  etapasConcluidas: readonly string[],
  todasAsEtapas: readonly string[],
  houveFalha: boolean
): EstadoExclusao {
  const faltando = todasAsEtapas.filter((e) => !etapasConcluidas.includes(e));
  if (faltando.length === 0) return ESTADO_EXCLUSAO.CONCLUIDA;
  return houveFalha ? ESTADO_EXCLUSAO.PARCIAL : ESTADO_EXCLUSAO.EM_ANDAMENTO;
}

/// Funde o resumo novo sobre o velho SEM apagar o que ja se sabia.
///
/// Numa retomada, a etapa que mediu as fichas ja rodou e nao vai medir de novo
/// (a carteira ja nao existe). Sobrescrever com `null` perderia o saldo que so
/// aquela execucao viu — e o saldo e justamente o dado que o suporte vai
/// precisar meses depois.
export function fundirResumo(
  velho: Partial<ResumoDoEncerramento> | undefined,
  novo: Partial<ResumoDoEncerramento>
): ResumoDoEncerramento {
  const escolher = <K extends keyof ResumoDoEncerramento>(
    chave: K
  ): ResumoDoEncerramento[K] => {
    const v = novo[chave];
    if (v !== undefined && v !== null) return v as ResumoDoEncerramento[K];
    const w = velho?.[chave];
    return (w === undefined ? null : w) as ResumoDoEncerramento[K];
  };

  return {
    fichas: escolher("fichas"),
    vipAtivo: escolher("vipAtivo"),
    vipExpiraEm: escolher("vipExpiraEm"),
    amizades: escolher("amizades"),
    comprasDesvinculadas: escolher("comprasDesvinculadas"),
  };
}
