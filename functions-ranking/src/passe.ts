// passe.ts — O PASSE VIP QUINZENAL DE CORTESIA, como REGRA e como DECISAO.
//
// MESMA DIVISAO DE TRABALHO DO RESTO DESTE CODEBASE (ver o cabecalho de
// firestore.ts): aqui moram as decisoes, e sao puras; `firestore.ts` aplica
// contra o banco. Uma leitura de documento que aparecer neste arquivo esta no
// lugar errado, e um `if` de regra de produto que aparecer la tambem.
//
// POR QUE ESTE CODEBASE, E NAO O DE BILLING. O passe de CORTESIA nao e uma
// compra: ele nao passa pela Play, nao tem recibo de pagamento, nao estorna e
// nao renova por assinatura. O que ele governa e a ENTRADA NA MESA
// VIP/RANQUEADA — que e a modalidade competitiva oficial, e a competicao mora
// aqui. Colocar isto no billing acoplaria um direito gratuito ao ciclo de vida
// de uma compra, que e exatamente a confusao que a OS manda evitar.
//
// E POR QUE NAO `playerEntitlements`. Aquela colecao e a autoridade da
// ASSINATURA VIP paga — quem comprou, ate quando vale, se foi estornada.
// Escrever a cortesia dentro dela criaria uma segunda razao para um jogador
// aparecer como "VIP", e as duas divergiriam no primeiro caminho que esquecesse
// de olhar as duas. Sao autoridades diferentes, com donos diferentes e ciclos
// de vida diferentes, e ficam em documentos diferentes.
//
// O QUE ESTE ARQUIVO NAO FAZ, e nao e esquecimento:
//   * nao consome o passe de verdade (a admissao e a OS seguinte);
//   * nao exporta Cloud Function nenhuma;
//   * nao agenda nada — nao existe scheduler, e o estado e MATERIALIZADO sob
//     demanda, quando uma operacao autorizada pergunta pelo beneficio.
//
// A AUSENCIA DE SCHEDULER E A DECISAO CENTRAL DO DESENHO. Um agendador que
// concedesse o passe de quinze em quinze dias precisaria varrer a base inteira,
// e erraria de dois jeitos: concederia a quem nunca mais vai jogar, e daria a
// quem jogou no dia 16 um passe que ele so veria no dia 30. Materializar sob
// demanda faz o ciclo de cada jogador ser DELE — ancorado no proprio
// `recebidoEm`, e nao num calendario global.

/// Versao do contrato do documento persistido. Um documento com versao
/// desconhecida NAO e normalizado: ele falha fechado. Normalizar em silencio e
/// como reescrever um direito de alguem sem saber o que ele dizia.
export const VERSAO_CONTRATO_PASSE = 1;

/// Os dois numeros do produto. Ficam aqui, um ao lado do outro, porque a relacao
/// entre eles E a regra: a validade cabe DENTRO do ciclo, e sobra uma janela de
/// oito dias sem passe. Trocar um sem olhar o outro e como o defeito nasce.
export const DIAS_DE_VALIDADE = 7;
export const DIAS_DE_CICLO = 15;

const MS_POR_DIA = 24 * 60 * 60 * 1000;

export const MS_DE_VALIDADE = DIAS_DE_VALIDADE * MS_POR_DIA;
export const MS_DE_CICLO = DIAS_DE_CICLO * MS_POR_DIA;

/// Por que um estado persistido foi recusado. Sao para LOG e TESTE; nenhum
/// deles chega ao cliente, e nenhum carrega identidade.
export const MOTIVOS_DE_FALHA = [
  "contrato_desconhecido",
  "datas_ilegiveis",
  "janela_impossivel",
  "ciclo_incoerente",
] as const;
export type MotivoDeFalha = (typeof MOTIVOS_DE_FALHA)[number];

/// Por que um recibo de admissao foi recusado.
export const MOTIVOS_DE_RECUSA = [
  "sem_passe_disponivel",
  "ja_consumido_por_outra_tentativa",
  "tentativa_de_outro_jogador",
  "tentativa_invalida",
  "contexto_divergente",
] as const;
export type MotivoDeRecusa = (typeof MOTIVOS_DE_RECUSA)[number];

// ---------------------------------------------------------------------------
// O QUE FICA GUARDADO
// ---------------------------------------------------------------------------

/// UM ciclo de cortesia. E o registro historico, e ele NAO e apagado quando o
/// passe some da projecao: e dele que sai a idempotencia do recibo, e apagar o
/// passado seria abrir a porta para consumir duas vezes.
export interface CicloDePasse {
  /// Opaco e NAO derivado. Nao e o uid, nao e um indice, nao e a data, nao e
  /// uma posicao — nada disso pode virar identificador, porque tudo isso se
  /// deduz de fora e um identificador dedutivel deixa de identificar.
  readonly cicloId: string;
  readonly recebidoEm: string;
  readonly validoAte: string;
  readonly proximaElegibilidadeEm: string;
  readonly consumidoEm: string | null;
  /// Quando este ciclo foi OBSERVADO encerrado. Ver `cicloEncerradoEm` no
  /// controle: encerramento e FATO, e nao comparacao de relogio.
  readonly encerradoEm: string | null;
  /// Preenchidos SO no consumo, pela OS de admissao. Nunca saem em projecao.
  readonly tentativaEntradaId: string | null;
  readonly admissaoId: string | null;
  readonly versaoContrato: number;
}

/// O controle por jogador: o retrato do ciclo vigente, para que a decisao
/// transacional precise ler UM documento em vez de varrer o historico.
export interface ControleDePasse {
  readonly versaoContrato: number;
  readonly cicloAtualId: string | null;
  readonly recebidoEm: string | null;
  readonly validoAte: string | null;
  readonly proximaElegibilidadeEm: string | null;
  readonly consumidoEm: string | null;
  /// O ciclo vigente ja foi OBSERVADO encerrado — consumido ou vencido.
  ///
  /// ESTE CAMPO E A PROTECAO REAL CONTRA REGRESSAO DE RELOGIO, e ele existe
  /// porque a primeira tentativa nao funcionou. Guardar so a "ultima
  /// materializacao" nao bastava: o caminho que observa o passe vencido NAO
  /// escreve nada, entao o marcador nunca avancava, e um relogio que voltasse
  /// atras encontrava o passe outra vez dentro da validade. O defeito passou
  /// pelo teste puro — o fixture afirmava um estado que o executor nunca
  /// produzia — e so apareceu contra o banco.
  ///
  /// A correcao troca COMPARACAO por FATO: quando a autoridade ve o ciclo
  /// encerrado, ela registra que viu, uma vez. Dali em diante o ciclo esta
  /// encerrado porque esta escrito, e nao porque a conta deu isso — e conta
  /// depende de relogio, enquanto fato nao.
  readonly cicloEncerradoEm: string | null;
  /// A ultima vez que este controle foi materializado. Segunda camada, barata:
  /// impede que um relogio adiantado e depois corrigido antecipe a proxima
  /// elegibilidade. Ver `instanteEfetivo`.
  readonly ultimaMaterializacaoEm: string | null;
}

export type LeituraDoControle =
  | { readonly estado: "inexistente" }
  | { readonly estado: "valido"; readonly controle: ControleDePasse }
  | { readonly estado: "malformado"; readonly motivo: MotivoDeFalha };

// ---------------------------------------------------------------------------
// TEMPO
// ---------------------------------------------------------------------------

/// ISO-8601 UTC -> milissegundos. `null` quando ilegivel.
///
/// Estrito de proposito: `new Date("qualquer coisa")` devolve `Invalid Date`
/// silenciosamente em algumas formas e um numero em outras, e um `NaN` que
/// atravessa vira comparacao sempre-falsa — que aqui significaria "o passe
/// nunca expira".
export function instanteDeIso(valor: unknown): number | null {
  if (typeof valor !== "string" || valor.length === 0) return null;
  const ms = Date.parse(valor);
  return Number.isFinite(ms) ? ms : null;
}

export function isoDeInstante(ms: number): string {
  return new Date(ms).toISOString();
}

/// O instante que a autoridade usa, que NUNCA anda para tras.
///
/// Se o relogio do servidor regredir — correcao de NTP, maquina nova, container
/// com hora errada — um passe ja expirado voltaria a estar dentro da validade e
/// o jogador ganharia uma entrada que ja tinha acabado. Pior: um ciclo ja
/// vencido voltaria a bloquear a proxima concessao.
///
/// A protecao e monotonica e conservadora: vale o MAIOR entre o relogio de
/// agora e a ultima materializacao registrada. Ela so pode empurrar o tempo
/// para a frente, e empurrar para a frente nunca concede nada — no maximo
/// expira algo que ja estava para expirar. O erro seguro e esse.
export function instanteEfetivo(agoraMs: number, ultimaMaterializacaoMs: number | null): number {
  if (ultimaMaterializacaoMs === null) return agoraMs;
  return agoraMs > ultimaMaterializacaoMs ? agoraMs : ultimaMaterializacaoMs;
}

// ---------------------------------------------------------------------------
// LEITURA DO ESTADO PERSISTIDO — FALHA FECHADA
// ---------------------------------------------------------------------------

/// Le o controle guardado. Documento ausente NAO e malformado: e um jogador que
/// nunca pediu o beneficio, e o caminho dele e criar o primeiro ciclo.
///
/// Tudo o mais que nao feche RECUSA. A alternativa — normalizar o que der e
/// seguir — significaria decidir sozinho o que um direito de alguem queria
/// dizer, e um erro nessa decisao aparece como passe concedido a mais ou a
/// menos, sem ninguem perceber.
export function lerControle(raw: unknown): LeituraDoControle {
  if (raw === null || raw === undefined) return { estado: "inexistente" };
  if (typeof raw !== "object") return { estado: "malformado", motivo: "contrato_desconhecido" };

  const o = raw as Record<string, unknown>;

  if (o.versaoContrato !== VERSAO_CONTRATO_PASSE) {
    return { estado: "malformado", motivo: "contrato_desconhecido" };
  }

  const cicloAtualId = typeof o.cicloAtualId === "string" && o.cicloAtualId.length > 0
    ? o.cicloAtualId
    : null;

  // Controle sem ciclo nenhum: legitimo apenas se NADA do ciclo estiver
  // preenchido. Meio preenchido e estado impossivel, e estado impossivel recusa.
  const temAlgumaData =
    o.recebidoEm !== undefined && o.recebidoEm !== null
      || o.validoAte !== undefined && o.validoAte !== null
      || o.proximaElegibilidadeEm !== undefined && o.proximaElegibilidadeEm !== null;

  if (cicloAtualId === null) {
    if (temAlgumaData) return { estado: "malformado", motivo: "ciclo_incoerente" };
    return {
      estado: "valido",
      controle: {
        versaoContrato: VERSAO_CONTRATO_PASSE,
        cicloAtualId: null,
        recebidoEm: null,
        validoAte: null,
        proximaElegibilidadeEm: null,
        consumidoEm: null,
        cicloEncerradoEm: null,
        ultimaMaterializacaoEm: typeof o.ultimaMaterializacaoEm === "string" ? o.ultimaMaterializacaoEm : null,
      },
    };
  }

  const recebidoMs = instanteDeIso(o.recebidoEm);
  const validoMs = instanteDeIso(o.validoAte);
  const proximaMs = instanteDeIso(o.proximaElegibilidadeEm);
  if (recebidoMs === null || validoMs === null || proximaMs === null) {
    return { estado: "malformado", motivo: "datas_ilegiveis" };
  }

  // A JANELA TEM DE SER A JANELA. Um documento que diga oito dias de validade,
  // ou quatorze de ciclo, foi escrito por codigo que nao e este — ou por
  // alguem. Recusar e a unica resposta honesta: aceitar seria deixar o dado
  // sobrescrever a regra.
  if (validoMs - recebidoMs !== MS_DE_VALIDADE) {
    return { estado: "malformado", motivo: "janela_impossivel" };
  }
  if (proximaMs - recebidoMs !== MS_DE_CICLO) {
    return { estado: "malformado", motivo: "janela_impossivel" };
  }

  const consumidoEm = o.consumidoEm === null || o.consumidoEm === undefined
    ? null
    : typeof o.consumidoEm === "string" && instanteDeIso(o.consumidoEm) !== null
      ? o.consumidoEm
      : undefined;
  if (consumidoEm === undefined) return { estado: "malformado", motivo: "datas_ilegiveis" };

  // Consumo fora do proprio ciclo e impossivel: ninguem usa um passe antes de
  // receber, nem depois de ele ter vencido.
  if (consumidoEm !== null) {
    const consumidoMs = instanteDeIso(consumidoEm) as number;
    if (consumidoMs < recebidoMs || consumidoMs > validoMs) {
      return { estado: "malformado", motivo: "ciclo_incoerente" };
    }
  }

  return {
    estado: "valido",
    controle: {
      versaoContrato: VERSAO_CONTRATO_PASSE,
      cicloAtualId,
      recebidoEm: o.recebidoEm as string,
      validoAte: o.validoAte as string,
      proximaElegibilidadeEm: o.proximaElegibilidadeEm as string,
      consumidoEm,
      cicloEncerradoEm: typeof o.cicloEncerradoEm === "string" && instanteDeIso(o.cicloEncerradoEm) !== null
        ? o.cicloEncerradoEm
        : null,
      ultimaMaterializacaoEm: typeof o.ultimaMaterializacaoEm === "string" ? o.ultimaMaterializacaoEm : null,
    },
  };
}

// ---------------------------------------------------------------------------
// A DECISAO DE MATERIALIZAR
// ---------------------------------------------------------------------------

/// As datas de um ciclo novo. O `cicloId` NAO nasce aqui: ele e sorteado por
/// quem executa, porque um identificador opaco nao pode ser funcao pura do
/// estado — se fosse, seria dedutivel.
export interface PlanoDeCiclo {
  readonly recebidoEmMs: number;
  readonly validoAteMs: number;
  readonly proximaElegibilidadeEmMs: number;
}

export type Decisao =
  | { readonly acao: "criar_primeiro"; readonly plano: PlanoDeCiclo }
  | { readonly acao: "reaproveitar" }
  | { readonly acao: "criar_novo"; readonly plano: PlanoDeCiclo }
  /// `precisaEncerrar` pede ao executor que REGISTRE, uma vez, que este ciclo
  /// acabou. E o unico caminho de leitura que escreve, e escreve no maximo uma
  /// vez por ciclo — nao a cada consulta.
  | {
      readonly acao: "aguardar";
      readonly proximaElegibilidadeEmMs: number;
      readonly precisaEncerrar: boolean;
    }
  | { readonly acao: "falha_fechada"; readonly motivo: MotivoDeFalha };

/// As datas de um ciclo ancorado em `agoraMs`.
///
/// ANCORADO NO INSTANTE REAL, e nao na elegibilidade que passou: quem sumiu por
/// dois meses recebe UM passe agora, e nao quatro passes atrasados. E isso, e
/// so isso, que impede acumulo — nao existe fila de ciclos perdidos porque
/// ciclo perdido nao e devido, e a proxima elegibilidade conta a partir de
/// AGORA, nao de um calendario que ninguem esta acompanhando.
export function planejarCiclo(agoraMs: number): PlanoDeCiclo {
  return {
    recebidoEmMs: agoraMs,
    validoAteMs: agoraMs + MS_DE_VALIDADE,
    proximaElegibilidadeEmMs: agoraMs + MS_DE_CICLO,
  };
}

/// O passe deste controle esta DISPONIVEL agora?
///
/// As duas fronteiras sao fechadas do lado de fora, e isso e o contrato:
///   * consumido    -> indisponivel, sempre, para sempre;
///   * `agora >= validoAte` -> expirado. EM `validoAte` JA ESTA EXPIRADO. Sete
///     dias e a duracao, nao o ultimo instante.
///   * encerrado    -> indisponivel, e este e o ramo que sobrevive a um relogio
///     que ande para tras: uma vez escrito, o encerramento nao depende de conta.
export function passeDisponivel(controle: ControleDePasse, agoraMs: number): boolean {
  if (controle.cicloAtualId === null) return false;
  if (controle.consumidoEm !== null) return false;
  if (controle.cicloEncerradoEm !== null) return false;
  const validoMs = instanteDeIso(controle.validoAte);
  if (validoMs === null) return false;
  return agoraMs < validoMs;
}

/// A PORTA UNICA DE DECISAO. Nao existe segundo lugar no projeto que resolva
/// "este jogador tem passe?" — e por isso que os limites de sete e quinze dias
/// aparecem uma vez so.
///
/// A ordem dos ramos e o contrato, e nao estetica:
///   1. malformado ...... recusa antes de qualquer conta;
///   2. inexistente ..... primeiro ciclo;
///   3. disponivel ...... reaproveita (materializar NAO consome);
///   4. elegivel ........ ciclo novo, ancorado agora;
///   5. resto ........... aguarda, sem passe.
///
/// O ramo 3 vem ANTES do 4 de proposito: um passe ainda valido nao pode ser
/// trocado por um novo, senao a validade viraria quinze dias na pratica.
export function decidirMaterializacao(leitura: LeituraDoControle, agoraMs: number): Decisao {
  if (leitura.estado === "malformado") {
    return { acao: "falha_fechada", motivo: leitura.motivo };
  }
  if (leitura.estado === "inexistente") {
    return { acao: "criar_primeiro", plano: planejarCiclo(agoraMs) };
  }

  const controle = leitura.controle;
  const efetivo = instanteEfetivo(agoraMs, instanteDeIso(controle.ultimaMaterializacaoEm));

  if (controle.cicloAtualId === null) {
    return { acao: "criar_primeiro", plano: planejarCiclo(efetivo) };
  }

  if (passeDisponivel(controle, efetivo)) {
    return { acao: "reaproveitar" };
  }

  const proximaMs = instanteDeIso(controle.proximaElegibilidadeEm);
  if (proximaMs === null) {
    return { acao: "falha_fechada", motivo: "datas_ilegiveis" };
  }

  // EM `proximaElegibilidadeEm` JA PODE. Quinze dias e a espera, e no instante
  // em que ela termina o ciclo novo e devido — a fronteira oposta a da
  // validade, e simetrica com ela de proposito.
  if (efetivo >= proximaMs) {
    return { acao: "criar_novo", plano: planejarCiclo(efetivo) };
  }

  // Consumido ou expirado, e ainda dentro da quinzena: nao ha passe, e nao ha
  // nada a criar. Consumir NAO antecipa a proxima elegibilidade, e expirar
  // tambem nao — as duas caem exatamente aqui, e e por isso que a ancora
  // quinzenal continua sendo `recebidoEm`.
  //
  // E e AQUI que o encerramento e registrado, se ainda nao estiver: este e o
  // primeiro momento em que a autoridade CONSTATA que o ciclo acabou.
  return {
    acao: "aguardar",
    proximaElegibilidadeEmMs: proximaMs,
    precisaEncerrar: controle.cicloEncerradoEm === null,
  };
}

// ---------------------------------------------------------------------------
// PROJECOES
// ---------------------------------------------------------------------------

/// O que o DONO do passe pode saber.
///
/// Nao carrega uid: quem pergunta ja sabe quem e, e repetir a identidade dentro
/// da resposta so cria mais um lugar de onde ela pode vazar.
export interface ProjecaoDoProprietario {
  readonly versaoContrato: number;
  readonly disponivel: boolean;
  /// So existe enquanto o passe existe.
  readonly validoAte: string | null;
  /// Quando o proximo ciclo pode ser materializado. `null` enquanto ha passe
  /// disponivel — informar as duas coisas ao mesmo tempo convidaria o cliente a
  /// achar que ganharia o proximo sem gastar este.
  readonly proximaElegibilidadeEm: string | null;
}

/// O que QUALQUER UM pode ver. Existe apenas enquanto o passe esta disponivel;
/// consumido ou expirado, ele desaparece — nao vira "false", nao vira "expirado",
/// nao deixa rastro. A ausencia e a projecao.
export interface ProjecaoPublica {
  readonly versaoContrato: number;
  readonly validoAte: string;
}

export function projecaoDoProprietario(
  leitura: LeituraDoControle,
  agoraMs: number
): ProjecaoDoProprietario {
  const vazia: ProjecaoDoProprietario = {
    versaoContrato: VERSAO_CONTRATO_PASSE,
    disponivel: false,
    validoAte: null,
    proximaElegibilidadeEm: null,
  };
  if (leitura.estado !== "valido") return vazia;

  const controle = leitura.controle;
  const efetivo = instanteEfetivo(agoraMs, instanteDeIso(controle.ultimaMaterializacaoEm));
  if (passeDisponivel(controle, efetivo)) {
    return {
      versaoContrato: VERSAO_CONTRATO_PASSE,
      disponivel: true,
      validoAte: controle.validoAte,
      proximaElegibilidadeEm: null,
    };
  }
  return {
    versaoContrato: VERSAO_CONTRATO_PASSE,
    disponivel: false,
    validoAte: null,
    proximaElegibilidadeEm: controle.cicloAtualId === null ? null : controle.proximaElegibilidadeEm,
  };
}

export function projecaoPublica(
  leitura: LeituraDoControle,
  agoraMs: number
): ProjecaoPublica | null {
  if (leitura.estado !== "valido") return null;
  const controle = leitura.controle;
  const efetivo = instanteEfetivo(agoraMs, instanteDeIso(controle.ultimaMaterializacaoEm));
  if (!passeDisponivel(controle, efetivo)) return null;
  const validoAte = controle.validoAte;
  // `passeDisponivel` ja garante que ha ciclo e que a data e legivel — esta
  // checagem e para o compilador, e para o dia em que alguem afrouxar aquela
  // funcao sem lembrar desta. Projecao sem validade nao e projecao: e ausencia.
  if (validoAte === null) return null;
  return { versaoContrato: VERSAO_CONTRATO_PASSE, validoAte };
}

// ---------------------------------------------------------------------------
// O RECIBO DE ADMISSAO — MODELADO AQUI, CONSUMIDO NA OS SEGUINTE
// ---------------------------------------------------------------------------

/// O contexto de UMA tentativa de entrada, como o gate do servidor a produz.
/// Ver `buraco-servidor@e4bad52`, contrato `admissao-vip-v1`.
export interface ContextoDaTentativa {
  readonly uid: string;
  readonly tentativaEntradaId: string;
  readonly codigoDaSala: string;
  readonly identidadeDaPartida: string | null;
}

export type PlanoDeRecibo =
  /// Primeira vez desta tentativa: consome, e o `admissaoId` e emitido por quem
  /// executa (opaco, como o `cicloId`).
  | { readonly acao: "consumir"; readonly cicloId: string }
  /// A MESMA tentativa ja consumiu. Devolve o MESMO `admissaoId` — nao consome
  /// de novo, e nao recusa.
  | { readonly acao: "recuperar"; readonly admissaoId: string; readonly cicloId: string }
  | { readonly acao: "recusar"; readonly motivo: MotivoDeRecusa };

/// O PLANO do recibo. Puro: nao escreve, nao sorteia e nao consome.
///
/// A REGRA QUE ESTE PLANEJAMENTO EXISTE PARA GARANTIR, e que e a razao de ele
/// estar sendo modelado uma OS antes de ser usado:
///
///   uma queda de conexao depois da aprovacao NAO pode queimar o passe.
///
/// O servidor aprova, a rede cai, o jogador volta e tenta de novo — com a MESMA
/// `tentativaEntradaId`, porque e o gate que a cunha e ele a conserva. Se a
/// segunda chegada consumisse de novo, o jogador perderia quinze dias por causa
/// de um cabo. Se ela fosse recusada, ele perderia a entrada que ja tinha
/// ganho. A resposta certa e a terceira: RECUPERAR o mesmo recibo.
///
/// E o contrario tambem tem de valer: uma tentativa DIFERENTE nao herda a
/// aprovacao da anterior. Duas partidas, dois passes — e como so ha um passe
/// por quinzena, a segunda e recusada.
export function planejarRecibo(
  ciclo: CicloDePasse | null,
  contexto: ContextoDaTentativa,
  uidDoDono: string,
  agoraMs: number
): PlanoDeRecibo {
  if (typeof contexto.tentativaEntradaId !== "string" || contexto.tentativaEntradaId.length === 0) {
    return { acao: "recusar", motivo: "tentativa_invalida" };
  }
  // O recibo e do DONO do passe. Uma tentativa carimbada com outro uid nao
  // consome o passe deste jogador — nem que o resto do contexto feche.
  if (contexto.uid !== uidDoDono) {
    return { acao: "recusar", motivo: "tentativa_de_outro_jogador" };
  }
  if (ciclo === null) {
    return { acao: "recusar", motivo: "sem_passe_disponivel" };
  }

  // Ciclo ja encerrado pela autoridade: acabou, e acabou por escrito. Nao se
  // reabre por relogio — que e a mesma razao de `cicloEncerradoEm` existir no
  // controle. A checagem vem ANTES da de consumo para que um ciclo encerrado e
  // nao consumido nao pareca consumivel.
  if (ciclo.encerradoEm !== null && ciclo.consumidoEm === null) {
    return { acao: "recusar", motivo: "sem_passe_disponivel" };
  }

  if (ciclo.consumidoEm !== null) {
    // Ja consumido. So ha um caminho de volta: ser a MESMA tentativa.
    if (ciclo.tentativaEntradaId !== null && ciclo.tentativaEntradaId === contexto.tentativaEntradaId) {
      if (typeof ciclo.admissaoId === "string" && ciclo.admissaoId.length > 0) {
        return { acao: "recuperar", admissaoId: ciclo.admissaoId, cicloId: ciclo.cicloId };
      }
      // Consumido pela mesma tentativa mas sem recibo gravado: estado
      // impossivel. Nao se inventa um `admissaoId` novo aqui — inventar seria
      // fabricar a prova de uma admissao que ninguem pode conferir.
      return { acao: "recusar", motivo: "ja_consumido_por_outra_tentativa" };
    }
    return { acao: "recusar", motivo: "ja_consumido_por_outra_tentativa" };
  }

  // Nao consumido: so vale se ainda estiver dentro da validade.
  const validoMs = instanteDeIso(ciclo.validoAte);
  if (validoMs === null || agoraMs >= validoMs) {
    return { acao: "recusar", motivo: "sem_passe_disponivel" };
  }
  return { acao: "consumir", cicloId: ciclo.cicloId };
}

/// O ciclo depois do consumo. Puro, e a unica forma de produzir um ciclo
/// consumido — para que nenhum caminho grave `consumidoEm` sem gravar junto a
/// tentativa e o recibo que o justificam.
///
/// `proximaElegibilidadeEm` NAO e recalculado: consumir nao antecipa nada. A
/// ancora e `recebidoEm`, e ela nao se move.
export function aplicarConsumo(
  ciclo: CicloDePasse,
  contexto: ContextoDaTentativa,
  admissaoId: string,
  agoraMs: number
): CicloDePasse {
  return {
    ...ciclo,
    consumidoEm: isoDeInstante(agoraMs),
    tentativaEntradaId: contexto.tentativaEntradaId,
    admissaoId,
  };
}
