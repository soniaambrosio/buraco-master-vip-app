// identidade.ts — o identificador PUBLICO do jogador (secao 16).
//
// A EXIGENCIA: "Ranking publico nao deve exigir exposicao de UID Firebase.
// Separar: UID interno; identificador publico do jogador."
//
// POR QUE ISSO IMPORTA DE VERDADE, e nao e higiene abstrata: o UID do Firebase e
// a chave de identidade do jogador em TODO o resto do sistema — e o caminho de
// `users/{uid}`, e o `request.auth.uid` das Rules, e o alvo de sancao em
// `playerModeration/{uid}`. Publica-lo numa lista que qualquer pessoa pagina
// entrega, de graca, o identificador com que se enderecam todas as outras
// colecoes. Nao ha exploracao imediata (as Rules continuam negando), mas e a
// primeira peca de toda cadeia, e ela sai sozinha de uma tela publica.
//
// COMO O ID PUBLICO E GERADO, e por que assim:
//
// Aleatorio, atribuido uma vez e PERSISTIDO nos dois sentidos. As alternativas
// foram descartadas com motivo:
//
//   hash(uid) ................. reversivel por forca bruta se o conjunto de uids
//                               for enumeravel, e uids do Firebase tem formato
//                               conhecido.
//   HMAC(uid, segredo) ........ resolve o ataque acima, mas cria uma chave a
//                               gerenciar: perde-la ou rotaciona-la muda o id
//                               publico de TODO MUNDO, e ids publicos ja estao
//                               em links de perfil.
//   sequencial (1, 2, 3...) ... vaza ordem de cadastro e o tamanho da base, e
//                               convida a enumeracao ("existe o 41, entao existe
//                               o 40").
//
// Aleatorio persistido nao tem nenhum dos tres problemas. O custo e que o mapa
// e a fonte da verdade e precisa sobreviver — mas ele vive no Firestore, junto
// com todo o resto que precisa sobreviver.

/// Alfabeto do id publico.
///
/// Base32 de Crockford SEM as letras I, L, O e U: as tres primeiras se confundem
/// com 1 e 0 quando alguem le um id em voz alta ou digita de um print (o que
/// acontece em suporte), e o U sai para reduzir a chance de palavra ofensiva
/// acidental num id que aparece na tela.
const ALFABETO = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/// Comprimento do id publico.
///
/// 12 caracteres de base32 sao 60 bits. Pelo paradoxo do aniversario, a chance de
/// colisao passa de 1 em 1 milhao so depois de ~1,5 milhao de jogadores — e a
/// colisao, se acontecer, e DETECTADA e nao ignorada (ver `reservarIdPublico` em
/// firestore.ts). O comprimento e generoso de proposito: alargar depois obrigaria
/// a conviver com duas geracoes de id.
export const COMPRIMENTO_ID_PUBLICO = 12;

/// Prefixo legivel. Serve ao suporte ("isso e um id de jogador, nao um matchId")
/// e nao entra na conta de entropia.
export const PREFIXO_ID_PUBLICO = "P";

/// Gera um id publico a partir de bytes aleatorios.
///
/// Os BYTES vem de fora, e nao de `crypto` chamado aqui dentro. E o que torna
/// esta funcao pura e testavel: o teste passa bytes conhecidos e afirma o id, em
/// vez de afirmar apenas o formato.
export function idPublicoDeBytes(bytes: Uint8Array): string {
  if (bytes.length < COMPRIMENTO_ID_PUBLICO) {
    throw new Error(
      `id publico precisa de ${COMPRIMENTO_ID_PUBLICO} bytes, recebeu ${bytes.length}.`
    );
  }
  let saida = "";
  for (let i = 0; i < COMPRIMENTO_ID_PUBLICO; i++) {
    // `% 32` sobre um byte NAO enviesa: 256 = 8 x 32, entao cada simbolo do
    // alfabeto recebe exatamente 8 dos 256 valores possiveis. O mesmo truque com
    // um alfabeto de tamanho nao-potencia-de-dois (26, por exemplo) precisaria de
    // rejeicao para nao favorecer as primeiras letras.
    saida += ALFABETO[bytes[i] % ALFABETO.length];
  }
  return PREFIXO_ID_PUBLICO + saida;
}

/// Um id publico tem a forma esperada?
///
/// Usado na LEITURA, antes de gastar uma consulta: um id malformado vindo do
/// cliente e recusado sem tocar o banco, o que fecha a porta de enumeracao por
/// tentativa barata.
export function idPublicoValido(valor: unknown): valor is string {
  if (typeof valor !== "string") return false;
  if (valor.length !== COMPRIMENTO_ID_PUBLICO + PREFIXO_ID_PUBLICO.length) return false;
  if (!valor.startsWith(PREFIXO_ID_PUBLICO)) return false;
  for (const c of valor.slice(PREFIXO_ID_PUBLICO.length)) {
    if (!ALFABETO.includes(c)) return false;
  }
  return true;
}

/// A chave composta de uma linha de classificacao: `seasonId|uid`.
///
/// O `seasonId` vem PRIMEIRO por uma razao pratica: o Firestore consulta por
/// intervalo de `documentId()`, e com a temporada na frente todas as linhas de
/// uma temporada ficam contiguas. Invertido, nao ficariam.
///
/// E o `uid` — e nao o id publico — porque esta e a chave de ESCRITA, e quem
/// escreve conhece o uid. Buscar o id publico so para montar a chave custaria
/// uma leitura a mais em cada processamento de partida.
export function chaveDeStanding(seasonId: string, uid: string): string {
  return `${seasonId}|${uid}`;
}
