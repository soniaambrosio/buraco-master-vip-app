// politica.ts — O CONTRATO DA FORMULA DE PONTUACAO E O REGISTRO VERSIONADO DELA.
//
// ATUALIZADO PELA OS DA POLITICA COMPETITIVA V1. O texto abaixo descrevia um
// projeto em que a formula NAO EXISTIA, e ele foi mantido porque explica por que
// as pecas tem a forma que tem. O que mudou: a formula agora existe, mora em
// `elo.ts` + `competicao.ts` e e registrada aqui como `competitiva@v1`. O
// mecanismo de pendencia continua inteiro e continua valendo para qualquer
// temporada que ainda nao tenha escolhido politica.
//
// --- registro historico, da OS anterior ------------------------------------
//
// Este e o arquivo mais importante desta codebase para quem estiver auditando a
// OS, porque ele e a resposta a secao 7 ("nao inventar formula") e a secao 31
// ("arquitetura faltante e problema tecnico; regra competitiva faltante e
// decisao de produto").
//
// O QUE A INVESTIGACAO ACHOU: a formula NAO existe, e isso ja estava escrito e
// testado antes desta OS. O dominio Dart da rastreabilidade
// (app/lib/rastreabilidade/ledger_competitivo.dart) declara:
//
//     static const PoliticaDeRanking pendente =
//         PoliticaDeRanking(id: 'nao_definida', versao: 0);
//
// e recusa qualquer lancamento com `RecusaLancamento.politicaNaoDefinida`
// enquanto ela valer. Este arquivo e o MESMO contrato do lado do servidor: o
// registro sai VAZIO de fabrica, e um resultado oficial que chegue sem
// calculadora registrada nao vira pontuacao — vira pendencia visivel
// (`rankingBacklog`), que e reprocessavel quando a regra chegar.
//
// POR QUE A CALCULADORA E CODIGO, E NAO UM DOCUMENTO DE CONFIGURACAO: uma
// formula digitada num documento do Firestore seria editavel sem revisao, sem
// teste e sem historico — e mudaria a pontuacao de todo mundo entre duas
// leituras. Registrar em codigo obriga a passar por deploy versionado, que e
// exatamente a rastreabilidade que a secao 21 pede. O que fica em documento e
// QUAL politica uma temporada usa, nao o que ela calcula.

/// Identificacao versionada da regra que produziu um delta.
///
/// Espelha `PoliticaDeRanking` do dominio Dart, campo a campo, porque os dois
/// lados gravam no MESMO documento (`rankingLedger`) e uma divergencia de
/// formato aqui so apareceria como lancamento ilegivel meses depois.
export interface PoliticaDeRanking {
  /// Nome estavel da politica (`temporada-2026-v1`).
  readonly id: string;

  /// Versao dentro da politica.
  readonly versao: number;
}

/// A politica que valeria hoje — e que NAO EXISTE.
///
/// Constante de PENDENCIA, nao valor de trabalho. Identica a
/// `PoliticaDeRanking.pendente` do Dart, inclusive no texto do id: os dois lados
/// precisam concordar sobre como se escreve "ainda nao decidido", senao uma
/// temporada criada por um lado pareceria definida para o outro.
export const POLITICA_PENDENTE: PoliticaDeRanking = { id: "nao_definida", versao: 0 };

export function politicaDefinida(p: PoliticaDeRanking): boolean {
  return !(p.id === POLITICA_PENDENTE.id && p.versao === POLITICA_PENDENTE.versao);
}

export function politicaDeJson(raw: unknown): PoliticaDeRanking {
  if (typeof raw !== "object" || raw === null) return POLITICA_PENDENTE;
  const o = raw as Record<string, unknown>;
  const versao = o.versao;
  return {
    id: typeof o.id === "string" ? o.id : POLITICA_PENDENTE.id,
    versao: typeof versao === "number" && Number.isInteger(versao) ? versao : 0,
  };
}

export function politicaComoTexto(p: PoliticaDeRanking): string {
  return `${p.id}@v${p.versao}`;
}

/// O que uma calculadora recebe para decidir o delta de UM jogador.
///
/// Tudo que ela precisa saber vem daqui, como DADO. Ela nao le o Firestore, nao
/// olha o relogio e nao chama outra funcao — e por isso ela e testavel e o
/// reprocessamento de uma temporada inteira (secao 22) produz o mesmo numero que
/// a execucao original produziu.
export interface EntradaDeCalculo {
  /// Identificador oficial da partida.
  readonly matchId: string;

  /// O jogador para quem este delta esta sendo calculado.
  readonly userId: string;

  /// Saldo do jogador na temporada ANTES desta partida.
  ///
  /// Sob a Politica Competitiva v1 este numero E O RATING, ja resolvido: quando
  /// o jogador entra na temporada, ele vale 1000 (jogador novo) ou o soft reset
  /// do rating final anterior (veterano). A calculadora nunca ve um zero de
  /// "jogador sem linha" — a semente e aplicada antes, em `firestore.ts`.
  readonly saldoAtual: number;

  /// Em que ponto da temporada o jogador esta: `em_colocacao`, `em_revalidacao`
  /// ou `classificado`.
  ///
  /// E daqui que sai o fator K, e ele e INDIVIDUAL: dois parceiros em estados
  /// diferentes usam K diferentes na mesma partida.
  readonly estadoCompetitivo: string;

  /// `finalizada`, `abandonada` ou `cancelada` — o estado terminal do registro.
  readonly estado: string;

  /// Motivo do encerramento, como o registro oficial o gravou.
  readonly motivoEncerramento: string | null;

  /// Lado vencedor declarado pela autoridade da partida (`null` em empate ou
  /// quando o desfecho nao produz vencedor).
  readonly ladoVencedor: string | null;

  /// O lado deste jogador na mesa, quando conhecido.
  readonly ladoDoJogador: string | null;

  /// Placar por lado, como o registro oficial o gravou.
  readonly placar: ReadonlyArray<{
    readonly lado: string;
    readonly pontos: number;
    readonly canastrasLimpas: number;
  }>;

  /// Tipo da partida (`publica_ranqueada`, `torneio`).
  readonly tipo: string;

  /// Ratings de TODOS os integrantes do lado deste jogador, incluindo ele
  /// proprio. Uma politica do tipo Elo em dupla precisa da forca do PARCEIRO, e
  /// nao apenas da do adversario (secao 9 da OS da Politica Competitiva v1).
  readonly ratingsDaMinhaDupla: ReadonlyArray<number>;

  /// Ratings de todos os integrantes do lado adversario.
  ///
  /// Substituiu `saldosDosOponentes`, que dizia metade do necessario: sem o
  /// rating do parceiro nao ha como calcular a media da propria dupla, e a
  /// expectativa sairia comparando UM jogador contra DOIS.
  readonly ratingsDaDuplaAdversaria: ReadonlyArray<number>;
}

/// Entra o contexto da partida, sai um inteiro. Nada mais.
///
/// A assinatura e a traducao literal de `CalculoDeDelta` do dominio Dart, e ela
/// existe escrita desde antes desta OS justamente para que quem for implementar
/// a formula encontre o formato pronto e nao seja tentado a espalhar o calculo
/// por dentro do processamento.
export type CalculoDeDelta = (entrada: EntradaDeCalculo) => number;

/// Registro de calculadoras, indexado por `id@vN`.
///
/// NASCE VAZIO E PERMANECE VAZIO ATE QUE ALGUEM REGISTRE. O que mudou com a OS
/// da Politica Competitiva v1 nao foi esta estrutura, e sim o fato de existir
/// agora uma politica real para colocar dentro dela: `registrarPoliticaV1()`, em
/// `competicao.ts`, chamada uma vez por `index.ts`.
///
/// A DISCIPLINA CONTINUA VALENDO, e continua sendo o ponto do arquivo: uma
/// temporada que nao declare uma politica registrada NAO pontua — ela acumula
/// `politica_nao_definida` no backlog. Nenhuma entrada "provisoria" deve ser
/// acrescentada aqui: uma formula de mentira registrada viraria pontuacao de
/// verdade no ledger, e o ledger e permanente.
const REGISTRO = new Map<string, CalculoDeDelta>();

/// Registra a calculadora de uma politica.
///
/// Chamado por quem IMPLEMENTAR a formula (um modulo novo, importado por
/// index.ts) e pelos testes, que registram calculadoras proprias para exercitar
/// a mecanica sem que a ausencia de regra de produto vire numero inventado.
export function registrarCalculadora(
  politica: PoliticaDeRanking,
  calculo: CalculoDeDelta
): void {
  if (!politicaDefinida(politica)) {
    // Registrar algo sob a politica "nao definida" transformaria a pendencia em
    // regra silenciosa: toda temporada que ainda nao escolheu politica passaria
    // a pontuar por ela.
    throw new Error(
      "nao se registra calculadora para a politica pendente: " +
        "isso transformaria 'ainda nao decidido' em regra de producao."
    );
  }
  REGISTRO.set(politicaComoTexto(politica), calculo);
}

/// A calculadora de uma politica, ou `null` quando ela nao foi registrada.
///
/// `null` NAO e erro tecnico: e a resposta correta enquanto o produto nao
/// decidir. Quem chama trata isso como `politica_nao_definida` e guarda a
/// partida para reprocessar depois — ver `decidirProcessamento`.
export function calculadoraDe(politica: PoliticaDeRanking): CalculoDeDelta | null {
  if (!politicaDefinida(politica)) return null;
  return REGISTRO.get(politicaComoTexto(politica)) ?? null;
}

/// As politicas com calculadora registrada. Serve ao diagnostico administrativo
/// ("por que a temporada nao pontua?") e aos testes.
export function politicasRegistradas(): string[] {
  return [...REGISTRO.keys()].sort();
}

/// Remove uma calculadora. Existe para os testes nao vazarem registro de um caso
/// para o outro; producao nao chama.
export function esquecerCalculadora(politica: PoliticaDeRanking): void {
  REGISTRO.delete(politicaComoTexto(politica));
}
