// nome_falavel_da_carta.dart — o nome de uma carta em palavras.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO EXISTE, E POR QUE É SÓ ISTO
// ---------------------------------------------------------------------------
//
// A arte de uma carta é uma imagem sem texto. Para quem usa leitor de tela, uma
// mão inteira desenhada assim é silêncio: o foco para em cada carta e nada é
// dito. O nome falável é o que transforma esse silêncio em partida.
//
// A convenção já existia — a Mesa Online a escrevia dentro de
// `casca/mesa_online/arte_das_cartas.dart`, num `_emPalavras` privado. Quando a
// Mesa de Treino precisou da mesma coisa, havia dois caminhos: copiar o mapa
// para `lib/mesa.dart`, ou tirá-lo de lá e deixar UMA autoridade. Copiar daria
// dois dicionários que divergem no dia em que alguém acertar um só — e é
// exatamente esse o defeito que se paga caro e se descobre tarde.
//
// Então este módulo tem UMA responsabilidade e nenhuma dependência: recebe
// valor e naipe como texto e devolve o nome. Ele não conhece `Carta`, não
// conhece `CartaOnline`, não conhece Flutter e não sabe desenhar nada — o que o
// deixa fora de qualquer ciclo entre a partida local e a partida online, que
// por decisão registrada não podem se importar.
//
// ---------------------------------------------------------------------------
// POR QUE O NÚMERO NÃO VIRA PALAVRA AQUI
// ---------------------------------------------------------------------------
//
// `7 de copas` é lido "sete de copas" por qualquer leitor de tela em português:
// quem soletra o algarismo é o sintetizador de voz, no idioma do aparelho.
// Escrever "sete" na string mudaria o que a Mesa Online já anuncia hoje, e a
// extração de um utilitário compartilhado não pode alterar o comportamento de
// quem já o usava. As figuras entram no mapa porque `A`, `J`, `Q` e `K` NÃO são
// palavras em português — sem o mapa, o leitor soletraria letras.

/// O mapa das figuras. Os números não entram: ver o cabeçalho.
const Map<String, String> _figuras = {
  'A': 'ás',
  'J': 'valete',
  'Q': 'dama',
  'K': 'rei',
};

const Map<String, String> _naipes = {
  'copas': 'de copas',
  'ouros': 'de ouros',
  'paus': 'de paus',
  'espadas': 'de espadas',
};

/// O nome falável de uma carta: `rei de espadas`, `ás de ouros`, `curinga`.
///
/// [naipe] é nulo no curingão, e pode ser qualquer texto: um naipe que este
/// mapa não conhece some do nome em vez de virar código na boca do leitor.
String nomeFalavelDaCarta({required String valor, String? naipe}) {
  if (valor == 'JOKER') return 'curinga';
  final nome = _figuras[valor] ?? valor;
  final naipeEmPalavras = _naipes[naipe] ?? '';
  return '$nome $naipeEmPalavras'.trim();
}
