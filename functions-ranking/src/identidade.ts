// identidade.ts — como o RANKING REFERENCIA a identidade publica. Nada aqui a
// cria.
//
// ESTA E A REGRA CENTRAL DA OS DE INTEGRACAO, e ela cabe numa linha:
//
//     O Ranking referencia a identidade. O Ranking nao cria identidade.
//
// A autoridade unica de emissao de `publicId` e o dominio de IDENTIDADE PUBLICA
// (`functions-social`), em `garantirIdentidade` de functions-social/src/
// repositorio.ts. Ele e quem sorteia, quem reserva, quem detecta colisao e quem
// grava os tres documentos canonicos. Ver docs/AUTORIDADE-DE-IDENTIDADE-PUBLICA.md.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO TINHA, E POR QUE FOI EMBORA
// ---------------------------------------------------------------------------
//
// Ate esta OS, este modulo exportava `idPublicoDeBytes` — um GERADOR — e
// `firestore.ts` o usava em `garantirIdPublico`, que sorteava um id, reservava
// em `rankingPublicIds/{id}` e gravava em `rankingPlayers/{uid}`. Era uma
// autoridade de emissao completa, paralela e ignorante da outra.
//
// As duas linhas nasceram em branches irmas e chegaram, por acidente feliz, ao
// MESMO FORMATO (base32 de Crockford sem I/L/O/U, 12 simbolos, prefixo "P" —
// ver o cabecalho de app/lib/social/identidade_publica.dart, que registra a
// coincidencia como deliberada). Formato igual nao e autoridade igual: dois
// geradores independentes sobre o mesmo formato produzem, para o mesmo jogador,
// DOIS ids validos e diferentes, e nada no sistema saberia qual e o dele.
//
// Por isso o gerador saiu inteiro, e nao foi "desligado por uma flag". Uma flag
// e uma autoridade adormecida; a ausencia da funcao e a unica prova durável.
// `test/identidade.test.js` varre a arvore deste codebase e falha se ela voltar.
//
// ---------------------------------------------------------------------------
// O QUE ESTE ARQUIVO CONTINUA FAZENDO
// ---------------------------------------------------------------------------
//
//   1. VALIDA formato. Recusar `"uid-do-firebase"` como id publico antes de
//      tocar o banco fecha a enumeracao por tentativa barata, e validar nao e
//      emitir: quem sabe reconhecer uma nota nao sabe imprimi-la.
//   2. Nomeia as COLECOES CANONICAS que o ranking le (e nunca escreve).
//   3. Monta a chave de `rankingStandings`, que e competitiva e nao de
//      identidade.

// ---------------------------------------------------------------------------
// AS COLECOES CANONICAS — LIDAS, NUNCA ESCRITAS
// ---------------------------------------------------------------------------
//
// Os NOMES sao propriedade de functions-social/src/chaves.ts. Estao repetidos
// aqui porque os dois codebases sao unidades de implantacao separadas e nao
// compartilham pacote npm — nao ha import possivel. A repeticao e conferida por
// teste (`test/identidade.test.js` le o arquivo do vizinho e compara), para que
// um `rename` la nao deixe o ranking lendo uma colecao que deixou de existir.
//
// ESCREVER EM QUALQUER UMA DELAS, DESTE CODEBASE, E DEFEITO. O Admin SDK
// permitiria; a disciplina e que nao. O mesmo teste varre o codebase atras de
// escrita nestes caminhos.

/// `playerIdentities/{uid}` — o mapa canonico `uid -> publicId`.
export const C_IDENTIDADES_CANONICAS = "playerIdentities";

/// `publicIdIndex/{publicId}` — o mapa canonico de volta, `publicId -> uid`.
export const C_INDICE_PUBLICO_CANONICO = "publicIdIndex";

/// `publicProfiles/{publicId}` — apelido e `avatarRef`. Fonte unica de
/// apresentacao. O ranking COPIA para a linha de classificacao, como projecao.
export const C_PERFIS_PUBLICOS_CANONICOS = "publicProfiles";

// ---------------------------------------------------------------------------
// FORMATO — SO PARA RECONHECER
// ---------------------------------------------------------------------------

/// Alfabeto do id publico: base32 de Crockford SEM I, L, O e U.
///
/// Espelha `kAlfabetoIdPublico` de app/lib/social/identidade_publica.dart, que e
/// a fonte. Aqui ele serve a UMA coisa: dizer se um simbolo pertence ao
/// conjunto. Nao ha caminho, neste codebase, que escolha um simbolo dele.
const ALFABETO = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/// Quantos simbolos formam o corpo do id (12 = 60 bits).
export const COMPRIMENTO_ID_PUBLICO = 12;

/// Prefixo legivel. Serve ao suporte ("isto e id de jogador, nao matchId").
export const PREFIXO_ID_PUBLICO = "P";

/// Um id publico tem a forma esperada?
///
/// Usado na LEITURA, antes de gastar uma consulta: um id malformado vindo do
/// cliente e recusado sem tocar o banco.
///
/// NAO CONFUNDIR COM EXISTENCIA. Formato valido nao diz que o jogador existe —
/// quem responde isso e `publicIdIndex`, que e do dominio social. Esta funcao
/// so evita a ida ao banco quando a resposta ja e "nao" pela forma.
export function idPublicoValido(valor: unknown): valor is string {
  if (typeof valor !== "string") return false;
  if (valor.length !== COMPRIMENTO_ID_PUBLICO + PREFIXO_ID_PUBLICO.length) return false;
  if (!valor.startsWith(PREFIXO_ID_PUBLICO)) return false;
  for (const c of valor.slice(PREFIXO_ID_PUBLICO.length)) {
    if (!ALFABETO.includes(c)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// CHAVE COMPETITIVA — nao e identidade
// ---------------------------------------------------------------------------

/// A chave composta de uma linha de classificacao: `seasonId|uid`.
///
/// O `seasonId` vem PRIMEIRO por uma razao pratica: o Firestore consulta por
/// intervalo de `documentId()`, e com a temporada na frente todas as linhas de
/// uma temporada ficam contiguas. Invertido, nao ficariam.
///
/// E o `uid` — e nao o id publico — porque esta e a chave de ESCRITA, e quem
/// escreve conhece o uid. Buscar o id publico so para montar a chave custaria
/// uma leitura a mais em cada processamento de partida.
///
/// ESTA CHAVE NAO SAI DAQUI. Ela e interna: a linha e PUBLICADA por
/// `projetarJogador`, que troca o uid pelo `publicPlayerId` (ver projecao.ts).
export function chaveDeStanding(seasonId: string, uid: string): string {
  return `${seasonId}|${uid}`;
}
