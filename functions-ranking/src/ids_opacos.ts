// ids_opacos.ts — O UNICO lugar deste codebase que sorteia alguma coisa.
//
// ESTE ARQUIVO EXISTE POR CAUSA DE UM GUARDA, E NAO APESAR DELE.
//
// `test/identidade.test.js` proibia aleatoriedade em TODA fonte do codebase de
// ranking, e a razao estava escrita ali: `randomBytes` era o insumo de
// `garantirIdPublico`, a funcao que sorteava `publicId` — e o ranking NAO E a
// autoridade de identidade publica. Quem emite `publicId` e `functions-social`;
// o ranking le e projeta. Um segundo emissor criaria duas identidades para a
// mesma pessoa, e as duas divergiriam.
//
// O guarda terminava com uma premissa: "um codebase que nao precisa de
// aleatoriedade para nada mais nao tem razao para importa-la de volta". Essa
// premissa MUDOU com o Passe de Cortesia, que exige por contrato um
// identificador de ciclo OPACO E NAO DERIVADO — nao o uid, nao a data, nao uma
// posicao, nao um contador. Nenhum deles serve: todos se deduzem de fora, e um
// identificador dedutivel deixa de identificar.
//
// A saida NAO foi afrouxar o guarda para o codebase inteiro. Foi concentrar a
// aleatoriedade AQUI, num arquivo que:
//
//   * tem uma funcao so, de tres linhas;
//   * nao conhece Firestore, nao conhece jogador e nao conhece identidade;
//   * nao menciona `publicId`, `publicPlayerId`, `playerIdentities` nem
//     `publicIdIndex` — e ha teste que varre este arquivo atras dessas
//     palavras, exatamente para que a excecao nao vire porta.
//
// Assim o guarda continua valendo onde ele importa: nenhuma outra fonte do
// ranking sorteia nada, e nenhuma — inclusive esta — produz identidade publica.

import { randomUUID } from "node:crypto";

/// Um identificador opaco, sorteado, sem estrutura legivel.
///
/// `randomUUID` e nao um contador: contador conta quantos existem, que e
/// informacao que ninguem pediu para publicar, e permite adivinhar o proximo.
/// E nao um derivado de uid ou de data: os dois se reconstroem de fora.
export function idOpaco(): string {
  return randomUUID();
}
