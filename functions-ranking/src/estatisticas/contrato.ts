// contrato.ts — FATO DE PARTIDA OFICIAL V1, o envelope que o futuro escritor
// das estatisticas do Perfil vai consumir.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO E, E O QUE ELE NAO E
// ---------------------------------------------------------------------------
//
// E um CONTRATO PURO: tipos, enumeracoes fechadas e um analisador que aceita ou
// recusa um envelope bruto. Nao ha Firestore, nao ha rede, nao ha relogio, nao
// ha aleatoriedade e nao ha Cloud Function aqui — de proposito. A OS que criou
// este arquivo proibe ATIVAR qualquer autoridade; ela existe para eliminar a
// ambiguidade ANTES que alguem comece a gravar.
//
// O problema que ele resolve esta em docs/ARBITRAGEM-ESTATISTICAS-PERFIL-V1.md:
// hoje o mesmo fato fisico — uma partida que acabou no servidor Railway —
// produziria DOIS registros divergentes dos mesmos oito campos do Perfil, com
// regras diferentes, identidade diferente e idempotencia diferente. O cofre
// local do servidor (`contas.js`) e a autoridade viva e ERRADA; o caminho
// `matches` -> `rankingStandings` e a autoridade certa e DESLIGADA. Este
// contrato descreve o que a autoridade certa vai receber, sem ligar nada.
//
// ---------------------------------------------------------------------------
// POR QUE O VOCABULARIO DE MODALIDADE E NOVO, E NAO HERDADO
// ---------------------------------------------------------------------------
//
// Existem HOJE tres vocabularios incompativeis para "que tipo de mesa foi esta":
//
//   dominio Dart  publica_casual | publica_ranqueada | privada | torneio |
//   (canonico)    treinamento | contra_robos
//                 (app/lib/rastreabilidade/identidade_partida.dart:67-99)
//
//   servidor Node publica | privada | simulada
//                 (buraco-servidor@85d0eee server.js:3801) — e o envelope
//                 emitido carrega `tipoPartida: "publica"`, que NAO DISTINGUE
//                 casual de ranqueada (server.js:4043)
//
//   ranking       AMBIENTE_COMPETITIVO = ["publica_ranqueada"], um unico
//                 elemento (functions-ranking/src/competicao.ts:106)
//
// A enumeracao deste contrato e FECHADA e nao aceita nenhum dos outros dois
// vocabularios como equivalente silencioso. `"publica"` nao vira
// `"publica_casual"` por adivinhacao: adivinhar aqui seria decidir, sem
// arbitragem, se a partida de alguem conta. Um simbolo desconhecido e RECUSADO,
// e recusar e o comportamento seguro — nenhuma estatistica e melhor do que a
// estatistica errada.
//
// A traducao e trabalho do PRODUTOR, na proxima OS, e por isso ela nao mora
// aqui: quem sabe se a mesa nasceu ranqueada e quem a abriu.

import { idPublicoValido } from "../identidade";

// ---------------------------------------------------------------------------
// VERSAO
// ---------------------------------------------------------------------------

/// A unica versao aceita deste contrato.
///
/// Um envelope com outra versao e RECUSADO, e nao lido "na melhor das
/// hipoteses". Ler um contrato futuro com as regras de hoje e a forma classica
/// de contar errado em silencio.
export const VERSAO_CONTRATO_FATO_PARTIDA = 1;

// ---------------------------------------------------------------------------
// ENUMERACOES FECHADAS
// ---------------------------------------------------------------------------

/// A natureza da mesa, no vocabulario DESTE contrato.
export type ModalidadeOficial =
  | "publica_casual"
  | "publica_ranqueada"
  | "privada"
  | "treino"
  | "simulada";

export const MODALIDADES: ReadonlyArray<ModalidadeOficial> = [
  "publica_casual",
  "publica_ranqueada",
  "privada",
  "treino",
  "simulada",
];

/// As modalidades que produzem estatistica oficial de Perfil na V1.
///
/// Decisao de produto, registrada em docs/CONTRATO-ESTATISTICAS-OFICIAIS-PERFIL-V1.md
/// secao "Modalidade": contam SOMENTE as partidas online publicas concluidas
/// autoritativamente — Mesa Publica casual e Mesa VIP/ranqueada. As outras tres
/// sao modalidades CONHECIDAS e INELEGIVEIS, o que e diferente de desconhecidas:
/// um envelope de mesa privada e valido, e simplesmente nao gera delta.
export const MODALIDADES_ELEGIVEIS: ReadonlyArray<ModalidadeOficial> = [
  "publica_casual",
  "publica_ranqueada",
];

/// O estado terminal da partida.
///
/// `concluida` e o unico que produz estatistica. `abandonada` fica de fora
/// nesta versao porque o registro oficial sabe que houve abandono e NAO sabe
/// QUEM abandonou (functions-ranking/src/projecao.ts:65-72) — e uma derrota
/// atribuida sem responsavel identificavel e uma invencao.
export type EstadoTerminalOficial = "concluida" | "cancelada" | "abandonada";

export const ESTADOS_TERMINAIS: ReadonlyArray<EstadoTerminalOficial> = [
  "concluida",
  "cancelada",
  "abandonada",
];

/// O lado da mesa. Nao ha um terceiro.
export type EquipeDaMesa = "nos" | "eles";

export const EQUIPES: ReadonlyArray<EquipeDaMesa> = ["nos", "eles"];

/// A classe do participante. Espectador nao entra no envelope: nao competiu.
export type ClasseDeParticipante = "humano" | "robo";

export const CLASSES: ReadonlyArray<ClasseDeParticipante> = ["humano", "robo"];

/// Quem tem autoridade para afirmar este fato.
///
/// Espelha o claim exigido por `registrarEncerramentoPartida`
/// (functions/src/rastreabilidade.ts:69-83): `motorDePartidas` ou `admin`.
/// Cliente autenticado comum nao esta na lista, aqui pelo mesmo motivo que la.
export type AutoridadeDeOrigem = "motorDePartidas" | "admin";

export const AUTORIDADES: ReadonlyArray<AutoridadeDeOrigem> = [
  "motorDePartidas",
  "admin",
];

// ---------------------------------------------------------------------------
// A FORMA DO ENVELOPE
// ---------------------------------------------------------------------------

/// O que uma equipe fez na partida.
///
/// Canastra e fato DA DUPLA. Nao ha, em lugar nenhum do sistema, autoria
/// individual de canastra — o motor conta por lado
/// (app/lib/motor/motor_partida.dart:80), o desfecho copia por lado
/// (app/lib/motor/desfecho_partida.dart:494-507) e o registro tambem
/// (app/lib/rastreabilidade/registro_partida.dart:263-291). Inventar o parceiro
/// que "fez" a canastra seria criar regra onde nao ha.
export interface ResultadoDaEquipe {
  readonly pontos: number;
  readonly canastrasLimpas: number;
  /// Limpa e suja sao guardadas SEPARADAS, e o total e derivado.
  ///
  /// A distincao ja existe no motor — `mesa.dart:380` e `:509` decidem
  /// `qtdCuringas > 0 ? "suja" : "limpa"`, e `mesa.dart:278` conta as duas —
  /// mas ela PARA no `Jogo`: `LadoDaMesa` so propaga `canastrasLimpas`. O campo
  /// existe neste contrato porque a decisao de produto o exige; quem tem de
  /// passar a emiti-lo e o produtor, na proxima OS.
  readonly canastrasSujas: number;
}

/// Um jogador da mesa.
export interface ParticipanteOficial {
  /// Identidade INTERNA. So atravessa a fronteira protegida do backend; nunca
  /// e publicada. Ver `deltasDoFato`, que nao a copia para o delta.
  readonly uid: string;
  /// Identidade PUBLICA, no formato canonico emitido por functions-social
  /// (`idPublicoValido`, functions-ranking/src/identidade.ts:93). E o unico
  /// identificador que a projecao publica pode carregar.
  readonly publicPlayerId: string;
  readonly equipe: EquipeDaMesa;
  /// 0 a 3. A lei da mesa liga assento e equipe e nao e parametrizavel: pares
  /// sao `nos`, impares sao `eles`
  /// (app/lib/rastreabilidade/registro_partida.dart:145-146; a mesma conta esta
  /// em buraco-servidor server.js:1729). O analisador CONFERE as duas coisas
  /// juntas — um envelope que diga assento 1 na equipe `nos` e recusado, porque
  /// so ha duas explicacoes para ele, e as duas sao defeito.
  readonly assento: number;
  readonly classe: ClasseDeParticipante;
  /// O humano saiu e um robo terminou a partida no lugar dele?
  readonly substituidoPorBot: boolean;
}

/// De onde veio a afirmacao.
export interface OrigemDoFato {
  readonly autoridade: AutoridadeDeOrigem;
  /// Qual processo afirmou. Rastreabilidade operacional, nao identidade de
  /// pessoa.
  readonly instancia: string;
}

/// O fato de uma partida oficial, como o escritor de estatisticas vai receber.
export interface FatoPartidaOficialV1 {
  readonly versaoContrato: number;
  /// Identidade ESTAVEL da partida. Reconexao nao a muda — e por isso que ela,
  /// e nao o `eventoId`, entra na chave de idempotencia por jogador.
  readonly matchId: string;
  /// Identidade da AFIRMACAO. Duas afirmacoes do mesmo desfecho tem `matchId`
  /// igual e `eventoId` diferente.
  readonly eventoId: string;
  /// Instante autoritativo do encerramento, ISO 8601 em UTC.
  readonly encerradaEm: string;
  readonly modalidade: ModalidadeOficial;
  readonly estadoTerminal: EstadoTerminalOficial;
  /// A partida foi encerrada pela autoridade da partida?
  ///
  /// `false` cobre o desfecho observado por terceiros, o resumo remontado pelo
  /// cliente e o encerramento inferido. Nenhum deles produz estatistica.
  readonly encerramentoAutoritativo: boolean;
  /// Esta mesa alimenta rating competitivo?
  ///
  /// Redundante COM PROPOSITO: o analisador exige que seja exatamente
  /// `modalidade === "publica_ranqueada"`. A redundancia e uma trava, nao um
  /// dado — ela impede que um produtor marque uma mesa casual como competitiva
  /// (ou o contrario) sem que o envelope inteiro seja recusado.
  readonly ambienteCompetitivo: boolean;
  readonly empate: boolean;
  /// `null` exatamente quando `empate` e `true`.
  readonly ladoVencedor: EquipeDaMesa | null;
  readonly equipes: Readonly<Record<EquipeDaMesa, ResultadoDaEquipe>>;
  /// Os quatro assentos da mesa, sempre. Buraco em dupla senta 0, 1, 2 e 3.
  readonly participantes: ReadonlyArray<ParticipanteOficial>;
  /// Houve substituicao definitiva por robo em algum assento?
  ///
  /// Como `ambienteCompetitivo`, e conferido contra os participantes: dizer
  /// `false` com um assento marcado `substituidoPorBot` recusa o envelope.
  readonly houveSubstituicaoPorBot: boolean;
  readonly origem: OrigemDoFato;
}

// ---------------------------------------------------------------------------
// ANALISE — ACEITAR OU RECUSAR, NUNCA NORMALIZAR
// ---------------------------------------------------------------------------

/// O resultado da analise de um envelope bruto.
///
/// Recusa e ERRO DE ENVELOPE, e nao "partida que nao conta". As duas coisas sao
/// distintas de proposito: um envelope recusado e defeito do produtor e merece
/// alarme; uma partida inelegivel e funcionamento normal e nao merece nenhum.
export type AnaliseDoFato =
  | { readonly ok: true; readonly fato: FatoPartidaOficialV1 }
  | { readonly ok: false; readonly erros: ReadonlyArray<string> };

/// As chaves que o envelope pode ter. Qualquer outra recusa o envelope.
const CHAVES_DO_FATO: ReadonlyArray<string> = [
  "versaoContrato",
  "matchId",
  "eventoId",
  "encerradaEm",
  "modalidade",
  "estadoTerminal",
  "encerramentoAutoritativo",
  "ambienteCompetitivo",
  "empate",
  "ladoVencedor",
  "equipes",
  "participantes",
  "houveSubstituicaoPorBot",
  "origem",
];

const CHAVES_DO_PARTICIPANTE: ReadonlyArray<string> = [
  "uid",
  "publicPlayerId",
  "equipe",
  "assento",
  "classe",
  "substituidoPorBot",
];

const CHAVES_DA_EQUIPE: ReadonlyArray<string> = [
  "pontos",
  "canastrasLimpas",
  "canastrasSujas",
];

const CHAVES_DA_ORIGEM: ReadonlyArray<string> = ["autoridade", "instancia"];

/// Prefixos que denunciam identificador de demonstracao, teste ou fixture.
///
/// A OS proibe que partida de demonstracao produza estatistica. Um envelope nao
/// tem como provar que NAO e demonstracao, entao a barreira e pelo nome: um
/// `matchId` que comeca por `demo` nao entra. E grosseiro de proposito — o
/// alvo sao os `demo-...` e `teste-...` que aparecem em fixture, e nao um
/// adversario que queira burlar (contra esse quem vale e o claim
/// `motorDePartidas`).
const PREFIXOS_DE_DEMONSTRACAO: ReadonlyArray<string> = [
  "demo",
  "teste",
  "test",
  "mock",
  "exemplo",
  "sample",
  "fixture",
  "fake",
];

const SIMBOLOS_DE_ID =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-";

/// Um identificador de partida ou de evento tem forma aceitavel?
///
/// Deliberadamente sem expressao regular: a regra cabe em tres perguntas, e
/// escrita assim ela e conferivel de relance por quem nao le regex.
function identificadorValido(valor: unknown): valor is string {
  if (typeof valor !== "string") return false;
  if (valor.length < 8 || valor.length > 64) return false;
  for (const c of valor) {
    if (!SIMBOLOS_DE_ID.includes(c)) return false;
  }
  const minusculo = valor.toLowerCase();
  for (const p of PREFIXOS_DE_DEMONSTRACAO) {
    if (minusculo.startsWith(p)) return false;
  }
  return true;
}

/// Instante ISO 8601 em UTC, com `Z` explicito.
///
/// `Z` obrigatorio porque um instante sem fuso e um instante sem significado, e
/// porque o campo e o carimbo AUTORITATIVO do encerramento — o momento em que
/// alguem decidiu que a partida acabou, e nao a hora local de quem contou.
function instanteValido(valor: unknown): valor is string {
  if (typeof valor !== "string") return false;
  if (valor.length < 20 || valor.length > 24) return false;
  if (!valor.endsWith("Z")) return false;
  if (valor[4] !== "-" || valor[7] !== "-" || valor[10] !== "T") return false;
  if (valor[13] !== ":" || valor[16] !== ":") return false;
  const t = Date.parse(valor);
  if (!Number.isFinite(t)) return false;
  return new Date(t).toISOString().slice(0, 19) === valor.slice(0, 19);
}

function inteiroNaoNegativo(valor: unknown): valor is number {
  return typeof valor === "number" && Number.isInteger(valor) && valor >= 0;
}

function inteiro(valor: unknown): valor is number {
  return typeof valor === "number" && Number.isInteger(valor);
}

function objeto(valor: unknown): valor is Record<string, unknown> {
  return typeof valor === "object" && valor !== null && !Array.isArray(valor);
}

/// Acusa chave inesperada. Lista fechada, e nao "ignore o que nao conhece":
/// campo a mais e sinal de que o produtor fala outro contrato.
function chavesInesperadas(
  o: Record<string, unknown>,
  permitidas: ReadonlyArray<string>,
  onde: string,
  erros: string[]
): void {
  for (const chave of Object.keys(o)) {
    if (!permitidas.includes(chave)) {
      erros.push(`${onde}: campo inesperado "${chave}"`);
    }
  }
}

function analisarEquipe(
  bruto: unknown,
  onde: string,
  erros: string[]
): ResultadoDaEquipe | null {
  if (!objeto(bruto)) {
    erros.push(`${onde}: deve ser objeto`);
    return null;
  }
  chavesInesperadas(bruto, CHAVES_DA_EQUIPE, onde, erros);
  let falhou = false;
  if (!inteiro(bruto.pontos)) {
    erros.push(`${onde}.pontos: inteiro exigido`);
    falhou = true;
  }
  if (!inteiroNaoNegativo(bruto.canastrasLimpas)) {
    erros.push(`${onde}.canastrasLimpas: inteiro nao negativo exigido`);
    falhou = true;
  }
  if (!inteiroNaoNegativo(bruto.canastrasSujas)) {
    erros.push(`${onde}.canastrasSujas: inteiro nao negativo exigido`);
    falhou = true;
  }
  if (falhou) return null;
  return {
    pontos: bruto.pontos as number,
    canastrasLimpas: bruto.canastrasLimpas as number,
    canastrasSujas: bruto.canastrasSujas as number,
  };
}

function analisarParticipante(
  bruto: unknown,
  onde: string,
  erros: string[]
): ParticipanteOficial | null {
  if (!objeto(bruto)) {
    erros.push(`${onde}: deve ser objeto`);
    return null;
  }
  chavesInesperadas(bruto, CHAVES_DO_PARTICIPANTE, onde, erros);
  let falhou = false;
  if (typeof bruto.uid !== "string" || bruto.uid.length === 0) {
    erros.push(`${onde}.uid: string nao vazia exigida`);
    falhou = true;
  }
  // O formato do id publico NAO e reimplementado aqui: `idPublicoValido` e a
  // funcao que o ranking ja usa, e ter duas opinioes sobre o mesmo formato e o
  // defeito que esta OS inteira existe para evitar.
  if (!idPublicoValido(bruto.publicPlayerId)) {
    erros.push(`${onde}.publicPlayerId: id publico canonico exigido`);
    falhou = true;
  }
  if (typeof bruto.equipe !== "string" || !EQUIPES.includes(bruto.equipe as EquipeDaMesa)) {
    erros.push(`${onde}.equipe: "nos" ou "eles" exigido`);
    falhou = true;
  }
  if (!inteiroNaoNegativo(bruto.assento) || (bruto.assento as number) > 3) {
    erros.push(`${onde}.assento: inteiro de 0 a 3 exigido`);
    falhou = true;
  }
  if (typeof bruto.classe !== "string" || !CLASSES.includes(bruto.classe as ClasseDeParticipante)) {
    erros.push(`${onde}.classe: "humano" ou "robo" exigido`);
    falhou = true;
  }
  if (typeof bruto.substituidoPorBot !== "boolean") {
    erros.push(`${onde}.substituidoPorBot: booleano exigido`);
    falhou = true;
  }
  if (falhou) return null;
  const assento = bruto.assento as number;
  const equipe = bruto.equipe as EquipeDaMesa;
  const peloAssento: EquipeDaMesa = assento % 2 === 0 ? "nos" : "eles";
  if (equipe !== peloAssento) {
    erros.push(
      `${onde}: assento ${assento} pertence a "${peloAssento}" pela lei da mesa, e o envelope diz "${equipe}"`
    );
    return null;
  }
  return {
    uid: bruto.uid as string,
    publicPlayerId: bruto.publicPlayerId as string,
    equipe,
    assento,
    classe: bruto.classe as ClasseDeParticipante,
    substituidoPorBot: bruto.substituidoPorBot as boolean,
  };
}

function analisarOrigem(
  bruto: unknown,
  erros: string[]
): OrigemDoFato | null {
  if (!objeto(bruto)) {
    erros.push("origem: deve ser objeto");
    return null;
  }
  chavesInesperadas(bruto, CHAVES_DA_ORIGEM, "origem", erros);
  let falhou = false;
  if (
    typeof bruto.autoridade !== "string" ||
    !AUTORIDADES.includes(bruto.autoridade as AutoridadeDeOrigem)
  ) {
    erros.push('origem.autoridade: "motorDePartidas" ou "admin" exigido');
    falhou = true;
  }
  if (typeof bruto.instancia !== "string" || bruto.instancia.length === 0) {
    erros.push("origem.instancia: string nao vazia exigida");
    falhou = true;
  }
  if (falhou) return null;
  return {
    autoridade: bruto.autoridade as AutoridadeDeOrigem,
    instancia: bruto.instancia as string,
  };
}

/// Le um envelope bruto e devolve o fato, ou a lista de erros.
///
/// NAO NORMALIZA NADA. Nao completa campo ausente com zero, nao converte texto
/// em numero, nao aparava espaco, nao adivinha modalidade. O envelope esta certo
/// ou esta recusado — porque cada normalizacao silenciosa aqui viraria uma regra
/// de negocio escondida num analisador.
export function analisarFatoPartidaOficial(bruto: unknown): AnaliseDoFato {
  const erros: string[] = [];

  if (!objeto(bruto)) {
    return { ok: false, erros: ["envelope: deve ser objeto"] };
  }
  chavesInesperadas(bruto, CHAVES_DO_FATO, "envelope", erros);

  if (bruto.versaoContrato !== VERSAO_CONTRATO_FATO_PARTIDA) {
    erros.push(
      `versaoContrato: ${VERSAO_CONTRATO_FATO_PARTIDA} exigido (recebido ${JSON.stringify(bruto.versaoContrato)})`
    );
  }
  if (!identificadorValido(bruto.matchId)) {
    erros.push("matchId: identificador estavel exigido (sem marca de demonstracao)");
  }
  if (!identificadorValido(bruto.eventoId)) {
    erros.push("eventoId: identificador estavel exigido (sem marca de demonstracao)");
  }
  if (!instanteValido(bruto.encerradaEm)) {
    erros.push("encerradaEm: instante ISO 8601 em UTC exigido");
  }
  if (
    typeof bruto.modalidade !== "string" ||
    !MODALIDADES.includes(bruto.modalidade as ModalidadeOficial)
  ) {
    erros.push(
      `modalidade: uma de ${MODALIDADES.join(", ")} exigida (recebido ${JSON.stringify(bruto.modalidade)})`
    );
  }
  if (
    typeof bruto.estadoTerminal !== "string" ||
    !ESTADOS_TERMINAIS.includes(bruto.estadoTerminal as EstadoTerminalOficial)
  ) {
    erros.push(`estadoTerminal: uma de ${ESTADOS_TERMINAIS.join(", ")} exigida`);
  }
  if (typeof bruto.encerramentoAutoritativo !== "boolean") {
    erros.push("encerramentoAutoritativo: booleano exigido");
  }
  if (typeof bruto.ambienteCompetitivo !== "boolean") {
    erros.push("ambienteCompetitivo: booleano exigido");
  }
  if (typeof bruto.empate !== "boolean") {
    erros.push("empate: booleano exigido");
  }
  if (
    bruto.ladoVencedor !== null &&
    (typeof bruto.ladoVencedor !== "string" ||
      !EQUIPES.includes(bruto.ladoVencedor as EquipeDaMesa))
  ) {
    erros.push('ladoVencedor: "nos", "eles" ou null exigido');
  }
  if (typeof bruto.houveSubstituicaoPorBot !== "boolean") {
    erros.push("houveSubstituicaoPorBot: booleano exigido");
  }

  let equipes: Record<EquipeDaMesa, ResultadoDaEquipe> | null = null;
  if (!objeto(bruto.equipes)) {
    erros.push("equipes: deve ser objeto com as chaves nos e eles");
  } else {
    chavesInesperadas(bruto.equipes, EQUIPES, "equipes", erros);
    const nos = analisarEquipe(bruto.equipes.nos, "equipes.nos", erros);
    const eles = analisarEquipe(bruto.equipes.eles, "equipes.eles", erros);
    if (nos !== null && eles !== null) equipes = { nos, eles };
  }

  let participantes: ParticipanteOficial[] | null = null;
  if (!Array.isArray(bruto.participantes)) {
    erros.push("participantes: lista exigida");
  } else if (bruto.participantes.length !== 4) {
    erros.push(
      `participantes: a mesa de Buraco em dupla tem 4 assentos (recebidos ${bruto.participantes.length})`
    );
  } else {
    const lidos: ParticipanteOficial[] = [];
    for (let i = 0; i < bruto.participantes.length; i++) {
      const p = analisarParticipante(bruto.participantes[i], `participantes[${i}]`, erros);
      if (p !== null) lidos.push(p);
    }
    if (lidos.length === 4) {
      const assentos = lidos.map((p) => p.assento).sort();
      if (assentos.join(",") !== "0,1,2,3") {
        erros.push("participantes: os quatro assentos 0, 1, 2 e 3 sao exigidos, sem repeticao");
      }
      const publicos = new Set(lidos.map((p) => p.publicPlayerId));
      const uids = new Set(lidos.map((p) => p.uid));
      if (publicos.size !== 4 || uids.size !== 4) {
        erros.push("participantes: identidade repetida na mesma mesa");
      }
      if (assentos.join(",") === "0,1,2,3" && publicos.size === 4 && uids.size === 4) {
        participantes = lidos;
      }
    }
  }

  const origem = analisarOrigem(bruto.origem, erros);

  // Coerencias cruzadas. So valem depois que cada campo isolado esta valido —
  // comparar campo ilegivel com campo ilegivel produz erro que nao ajuda.
  if (typeof bruto.empate === "boolean") {
    const semVencedor = bruto.ladoVencedor === null;
    if (bruto.empate !== semVencedor) {
      erros.push(
        "empate e ladoVencedor se contradizem: empate exige ladoVencedor null, e vice-versa"
      );
    }
  }
  if (
    typeof bruto.ambienteCompetitivo === "boolean" &&
    typeof bruto.modalidade === "string" &&
    MODALIDADES.includes(bruto.modalidade as ModalidadeOficial)
  ) {
    const esperado = bruto.modalidade === "publica_ranqueada";
    if (bruto.ambienteCompetitivo !== esperado) {
      erros.push(
        `ambienteCompetitivo: ${esperado} exigido para modalidade "${bruto.modalidade}"`
      );
    }
  }
  if (typeof bruto.houveSubstituicaoPorBot === "boolean" && participantes !== null) {
    const algum = participantes.some((p) => p.substituidoPorBot);
    if (bruto.houveSubstituicaoPorBot !== algum) {
      erros.push(
        `houveSubstituicaoPorBot: ${algum} exigido, pelo que os participantes declaram`
      );
    }
  }

  if (erros.length > 0 || equipes === null || participantes === null || origem === null) {
    if (erros.length === 0) erros.push("envelope incompleto");
    return { ok: false, erros };
  }

  return {
    ok: true,
    fato: {
      versaoContrato: VERSAO_CONTRATO_FATO_PARTIDA,
      matchId: bruto.matchId as string,
      eventoId: bruto.eventoId as string,
      encerradaEm: bruto.encerradaEm as string,
      modalidade: bruto.modalidade as ModalidadeOficial,
      estadoTerminal: bruto.estadoTerminal as EstadoTerminalOficial,
      encerramentoAutoritativo: bruto.encerramentoAutoritativo as boolean,
      ambienteCompetitivo: bruto.ambienteCompetitivo as boolean,
      empate: bruto.empate as boolean,
      ladoVencedor: bruto.ladoVencedor as EquipeDaMesa | null,
      equipes,
      participantes,
      houveSubstituicaoPorBot: bruto.houveSubstituicaoPorBot as boolean,
      origem,
    },
  };
}

// ---------------------------------------------------------------------------
// IDEMPOTENCIA — CHAVES DETERMINISTICAS, NO PADRAO DO CODEBASE
// ---------------------------------------------------------------------------
//
// O padrao ja usado no projeto e "id de documento deterministico, nunca
// `increment` sem chave": `matches/{matchId}`,
// `rankingContributions/{matchId|seasonId|politicaId|vN}`
// (functions-ranking/src/resultado.ts:478). As duas funcoes abaixo devolvem
// STRINGS e nada mais — quem as usar como id de documento ganha a idempotencia
// pela mesma porta que os vizinhos.

/// O escopo desta contabilidade. Entra na chave para que uma futura segunda
/// contabilidade sobre o mesmo `matchId` nao colida com esta.
export const ESCOPO_ESTATISTICAS_OFICIAIS = "estatisticasOficiais";

/// Identidade da AFIRMACAO: `matchId|eventoId`.
///
/// Duas entregas do mesmo evento produzem a mesma chave — e por ela que o
/// futuro escritor reconhece a duplicata.
export function chaveDoFato(fato: FatoPartidaOficialV1): string {
  return `${fato.matchId}|${fato.eventoId}`;
}

/// Identidade do LANCAMENTO por jogador:
/// `matchId|publicPlayerId|estatisticasOficiais|v1`.
///
/// O `eventoId` fica FORA de proposito. Reconexao e reenvio produzem eventos
/// diferentes para a MESMA partida; se ele entrasse na chave, cada reenvio
/// pareceria um lancamento novo e o jogador contaria duas vezes — que e
/// exatamente o defeito do cofre local do servidor
/// (docs/ARBITRAGEM-ESTATISTICAS-PERFIL-V1.md, secao 1, item 3).
export function chaveDeLancamento(
  matchId: string,
  publicPlayerId: string
): string {
  return `${matchId}|${publicPlayerId}|${ESCOPO_ESTATISTICAS_OFICIAIS}|v${VERSAO_CONTRATO_FATO_PARTIDA}`;
}
