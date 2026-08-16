// ligas.ts — a Liga como propriedade DERIVADA, e a faixa como parametro.
//
// SECAO 11 DA OS, LITERALMENTE: "Se esses parametros nao existirem oficialmente:
// criar a infraestrutura configuravel, mas nao criar politica de produto por
// conta propria."
//
// O QUE A INVESTIGACAO ACHOU. As ligas existem como ARTE, e so como arte. Na
// branch do cliente (`integracao/ranking-ligas-hall`) ha sete arquivos:
//
//   assets/ranking/liga_bronze.webp    liga_prata.webp     liga_ouro.webp
//   assets/ranking/liga_platina.webp   liga_diamante.webp  liga_imperial.webp
//   assets/ranking/liga_lenda.webp
//
// Nao ha, em nenhuma branch, nenhum documento e nenhum teste do repositorio:
//   * a lista OFICIAL de ligas (a arte tem sete; a OS anterior citou quatro
//     nomes; nenhuma das duas listas e uma decisao registrada);
//   * os limites de pontuacao de cada faixa;
//   * regra de promocao ou rebaixamento;
//   * o que a liga faz na virada de temporada.
//
// Entao ESTE ARQUIVO NAO DECIDE NADA DISSO. Ele sabe aplicar uma escada que
// alguem tenha registrado, e sabe dizer "nao ha escada" — que e a resposta
// honesta hoje. `rankingLadders` sai VAZIA de fabrica, e um standing apurado sem
// escada recebe `ligaId: null`, que o cliente exibe como ausencia em vez de
// exibir "Bronze" por default. Um default aqui seria uma faixa competitiva
// inventada em silencio, que e o que a secao 28 proibe.

/// Um degrau da escada. `pontosMinimos` inclusivo; `pontosMaximos` inclusivo.
///
/// AS DUAS PONTAS SAO ABERTAS, e por simetria: `pontosMaximos: null` no ultimo
/// degrau (nada acima de Lenda) e `pontosMinimos: null` no primeiro (nada abaixo
/// de Bronze). O piso aberto entrou com a Politica Competitiva v1, cuja secao 15
/// define Bronze como "abaixo de 950" sem indicar um fundo. Sem ele, seria
/// preciso inventar um numero — e qualquer numero escolhido deixaria a faixa
/// abaixo dele sem Liga nenhuma, que e o defeito `buraco_entre_faixas` que
/// `conferirEscada` recusa.
export interface DegrauDeLiga {
  readonly ligaId: string;
  readonly nome: string;
  /// Caminho do asset, quando o produto o registrar. Nao e derivado do nome:
  /// deduzir `assets/ranking/liga_${nome.toLowerCase()}.webp` amarraria a
  /// autoridade a um nome de arquivo do cliente.
  readonly icone: string;
  /// `null` = sem piso. So o PRIMEIRO degrau pode te-lo.
  readonly pontosMinimos: number | null;
  /// `null` = sem teto. So o ULTIMO degrau pode te-lo.
  readonly pontosMaximos: number | null;
}

/// A escada completa de uma temporada.
export interface EscadaDeLigas {
  readonly ladderId: string;
  readonly nome: string;
  readonly degraus: ReadonlyArray<DegrauDeLiga>;
}

/// A ausencia de escada, como VALOR e nao como `null` solto.
///
/// Ter um objeto para "ninguem definiu as faixas" permite que a apuracao e a
/// leitura tratem o caso sem espalhar `if (ladder == null)` por toda parte, e
/// deixa a ausencia visivel no diagnostico administrativo.
export const SEM_ESCADA: EscadaDeLigas = {
  ladderId: "nao_definida",
  nome: "escada de ligas nao definida",
  degraus: [],
};

export function escadaDefinida(e: EscadaDeLigas): boolean {
  return e.degraus.length > 0;
}

/// Por que uma escada foi recusada.
export type RecusaDeEscada =
  | "degraus_vazios"
  | "liga_duplicada"
  | "faixa_invertida"
  | "faixa_sobreposta"
  | "buraco_entre_faixas"
  | "teto_no_meio"
  | "piso_no_meio";

export interface ConferenciaDeEscada {
  readonly valida: boolean;
  readonly recusa: RecusaDeEscada | null;
  readonly detalhe: string | null;
}

const OK: ConferenciaDeEscada = { valida: true, recusa: null, detalhe: null };

function recusar(recusa: RecusaDeEscada, detalhe: string): ConferenciaDeEscada {
  return { valida: false, recusa, detalhe };
}

/// Confere que uma escada e aplicavel ANTES de ela virar liga de alguem.
///
/// A secao 23 pede teste de "ausencia de configuracao invalida", e a razao e
/// concreta: uma escada com buraco entre faixas deixa jogadores sem liga
/// nenhuma, e uma com sobreposicao da ligas diferentes para a mesma pontuacao
/// dependendo da ordem em que os degraus foram lidos. Os dois defeitos so
/// apareceriam na tela de alguem.
///
/// A escada e conferida na ORDEM em que foi registrada, e essa ordem tem que ser
/// crescente. Ordenar aqui por conta propria esconderia um registro
/// desorganizado em vez de recusa-lo.
export function conferirEscada(degraus: ReadonlyArray<DegrauDeLiga>): ConferenciaDeEscada {
  if (degraus.length === 0) {
    return recusar("degraus_vazios", "uma escada sem degraus nao classifica ninguem");
  }

  const vistos = new Set<string>();
  for (const d of degraus) {
    if (vistos.has(d.ligaId)) {
      return recusar("liga_duplicada", `a liga "${d.ligaId}" aparece duas vezes`);
    }
    vistos.add(d.ligaId);
  }

  // DUAS PASSAGENS, E A ORDEM ENTRE ELAS IMPORTA. A primeira confere a FORMA de
  // cada degrau isoladamente; a segunda confere a relacao entre vizinhos. Feitas
  // juntas, um piso aberto no meio da escada seria denunciado como
  // "faixa_sobreposta" pelo vizinho anterior (em JavaScript, `null <= 100` e
  // verdadeiro), e a mensagem apontaria para o degrau errado.
  for (let i = 0; i < degraus.length; i++) {
    const d = degraus[i];
    const ultimo = i === degraus.length - 1;
    const primeiro = i === 0;

    if (d.pontosMaximos === null && !ultimo) {
      return recusar(
        "teto_no_meio",
        `a liga "${d.ligaId}" nao tem teto mas nao e a ultima da escada — ` +
          "tudo acima dela ficaria inalcancavel"
      );
    }
    // Simetrico ao anterior: um piso aberto no meio da escada engoliria todas as
    // faixas abaixo dele, porque `ligaDe` percorre na ordem e o primeiro degrau
    // que aceita a pontuacao vence.
    if (d.pontosMinimos === null && !primeiro) {
      return recusar(
        "piso_no_meio",
        `a liga "${d.ligaId}" nao tem piso mas nao e a primeira da escada — ` +
          "tudo abaixo dela ficaria inalcancavel"
      );
    }
    if (
      d.pontosMaximos !== null &&
      d.pontosMinimos !== null &&
      d.pontosMaximos < d.pontosMinimos
    ) {
      return recusar(
        "faixa_invertida",
        `a liga "${d.ligaId}" vai de ${d.pontosMinimos} a ${d.pontosMaximos}`
      );
    }
  }

  for (let i = 0; i < degraus.length - 1; i++) {
    const d = degraus[i];
    const proximo = degraus[i + 1];
    const teto = d.pontosMaximos as number;
    // Nao e o primeiro degrau (i + 1 >= 1), entao o piso dele nao pode ser
    // aberto — a guarda `piso_no_meio` acima ja recusou esse caso.
    const pisoSeguinte = proximo.pontosMinimos as number;
    if (pisoSeguinte <= teto) {
      return recusar(
        "faixa_sobreposta",
        `"${d.ligaId}" termina em ${teto} e "${proximo.ligaId}" comeca em ` +
          `${pisoSeguinte}`
      );
    }
    if (pisoSeguinte !== teto + 1) {
      return recusar(
        "buraco_entre_faixas",
        `entre ${teto} ("${d.ligaId}") e ${pisoSeguinte} ` +
          `("${proximo.ligaId}") ha pontuacao sem liga`
      );
    }
  }

  return OK;
}

/// A liga de uma pontuacao, ou `null` quando a escada nao define.
///
/// `null` e devolvido em dois casos, e nenhum dos dois e erro:
///   * nao ha escada registrada — nenhuma temporada aponta para uma escada;
///   * a pontuacao esta abaixo do primeiro degrau, numa escada cujo primeiro
///     degrau tem piso fechado. Inventar "cai no Bronze" seria decidir
///     rebaixamento, que e politica de produto.
///
/// Na escada oficial da v1 o segundo caso nao acontece: o Bronze tem piso aberto,
/// entao toda pontuacao tem Liga. Quem ainda nao tem Liga na v1 nao e por falta
/// de faixa — e por estar em colocacao/revalidacao, que e outra coisa e e
/// decidida em `competicao.ts`, nao aqui.
export function ligaDe(escada: EscadaDeLigas, pontos: number): DegrauDeLiga | null {
  for (const d of escada.degraus) {
    const dentroDoPiso = d.pontosMinimos === null || pontos >= d.pontosMinimos;
    const dentroDoTeto = d.pontosMaximos === null || pontos <= d.pontosMaximos;
    if (dentroDoPiso && dentroDoTeto) return d;
  }
  return null;
}

/// A escada como o cliente a exibe: os degraus, com o atual marcado.
///
/// Espelha `RankingLigaDegrau` de `app/lib/ranking/ranking_contract.dart`
/// (`nome`, `icone`, `atual`). Quem decide qual e o atual e esta funcao — o
/// contrato do cliente diz "`atual` tambem vem da fonte".
export function escadaParaExibicao(
  escada: EscadaDeLigas,
  ligaAtual: string | null
): Array<{ ligaId: string; nome: string; icone: string; atual: boolean }> {
  return escada.degraus.map((d) => ({
    ligaId: d.ligaId,
    nome: d.nome,
    icone: d.icone,
    atual: d.ligaId === ligaAtual,
  }));
}

/// Le uma escada persistida, recusando o que nao for aplicavel.
///
/// Recusa devolvendo [SEM_ESCADA] em vez de lancar: uma escada mal registrada
/// nao pode derrubar a leitura do ranking inteiro. Ela derruba a LIGA, que passa
/// a ser `null`, e o problema fica visivel no diagnostico administrativo.
export function escadaDeJson(raw: unknown): EscadaDeLigas {
  if (typeof raw !== "object" || raw === null) return SEM_ESCADA;
  const o = raw as Record<string, unknown>;
  const brutos = o.degraus;
  if (!Array.isArray(brutos)) return SEM_ESCADA;

  const degraus: DegrauDeLiga[] = [];
  for (const b of brutos) {
    if (typeof b !== "object" || b === null) return SEM_ESCADA;
    const d = b as Record<string, unknown>;
    if (typeof d.ligaId !== "string" || d.ligaId.length === 0) return SEM_ESCADA;
    const piso = d.pontosMinimos;
    if (piso !== null && piso !== undefined && !Number.isInteger(piso as number)) {
      return SEM_ESCADA;
    }
    const teto = d.pontosMaximos;
    if (teto !== null && teto !== undefined && !Number.isInteger(teto as number)) {
      return SEM_ESCADA;
    }
    degraus.push({
      ligaId: d.ligaId,
      nome: typeof d.nome === "string" ? d.nome : d.ligaId,
      icone: typeof d.icone === "string" ? d.icone : "",
      pontosMinimos: piso === null || piso === undefined ? null : (piso as number),
      pontosMaximos: teto === null || teto === undefined ? null : (teto as number),
    });
  }

  if (!conferirEscada(degraus).valida) return SEM_ESCADA;

  return {
    ladderId: typeof o.ladderId === "string" ? o.ladderId : SEM_ESCADA.ladderId,
    nome: typeof o.nome === "string" ? o.nome : "",
    degraus,
  };
}
