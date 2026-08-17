// functions/src/autoridade.ts — QUEM É A AUTORIDADE DA PARTIDA.
//
// Este arquivo existe separado de `rastreabilidade.ts` pelo mesmo motivo que
// `conquistas.ts`: `src/index.ts` faz `export * from "./rastreabilidade"`, e o
// Firebase trata CADA export do entrypoint como definição de função a implantar.
// Um predicado exportado de lá viraria uma Cloud Function vazia — e o `tsc` não
// acusaria nada. Aqui, não: `index.ts` não reexporta este módulo, então o que
// mora neste arquivo é biblioteca, e não superfície de implantação.
//
// A razão de existir é ter UM lugar só onde se decide se um token manda no
// encerramento. Antes desta extração a regra vivia embutida dentro de
// `exigirAutoridadeDePartida`, o que a tornava impossível de provar sem chamar
// a função inteira — e uma regra de permissão que nenhum teste alcança é uma
// regra que só se descobre errada em produção.
//
// NADA AQUI FOI AFROUXADO. A comparação continua sendo `=== true`, idêntica à
// que estava embutida; o que mudou é o endereço dela.

/// Papeis que podem escrever registro de partida.
///
/// Espelha `ChamadorAutorizado.papeisDeAutoridade` do dominio Dart. A
/// duplicacao e inevitavel enquanto a ponte nao carregar a rastreabilidade, e
/// esta anotada de proposito para quem for unifica-las achar os dois pontos.
export const PAPEIS_DE_AUTORIDADE = ["motorDePartidas", "admin"] as const;

/// O nome do claim que esta OS provisiona. Constante, e não literal solto, para
/// que o provisionador administrativo e a guarda não possam divergir por um
/// erro de digitação que nenhum compilador pegaria.
export const CLAIM_MOTOR_DE_PARTIDAS = "motorDePartidas";

/// Os claims do token, como este projeto os le.
///
/// Tipado em vez de `any` para que um claim escrito errado (`Admin`, `sup0rte`)
/// vire erro de compilacao e nao uma comparacao que sempre da `false` — o pior
/// defeito possivel numa checagem de permissao, porque falha ABERTA em nenhum
/// teste e FECHADA em producao.
export type ClaimsDoToken = Partial<
  Record<(typeof PAPEIS_DE_AUTORIDADE)[number] | "suporte", boolean>
>;

/// Este token manda no encerramento de partida?
///
/// `=== true` e ESTRITO de proposito, e é o contrato desta OS. Um claim que
/// chegue como a string `"true"`, como o número `1`, como `"1"` ou como
/// `false` NÃO autoriza — os três primeiros são exatamente o que um
/// provisionamento manual desleixado produz, e aceitá-los transformaria um erro
/// de digitação em concessão de autoridade.
///
/// Ausência também não autoriza: o objeto vazio é o caso do jogador comum, que
/// é a maioria das conexões.
export function autorizaComoMotorDePartidas(
  claims: ClaimsDoToken | undefined | null
): boolean {
  const token = claims ?? {};
  return PAPEIS_DE_AUTORIDADE.some((papel) => token[papel] === true);
}
