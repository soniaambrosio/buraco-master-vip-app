// arte_das_cartas.dart — como uma carta online é desenhada.
//
// ---------------------------------------------------------------------------
// POR QUE ISTO NÃO SAIU DE DENTRO DE `mesa.dart`
// ---------------------------------------------------------------------------
//
// O treino já sabe desenhar carta: `lib/mesa.dart` tem `_cartaAsset`,
// `_cartaSimb` e companhia. Extrair essas funções para cá e fazer o treino
// importá-las daria UMA fonte da convenção de arte — que é a coisa certa a
// fazer, em tese.
//
// Não foi feito, e a razão é o tamanho do risco contra o do ganho. `mesa.dart`
// tem três mil e quatrocentas linhas, é a partida local inteira — motor,
// regras e tela no mesmo arquivo — e é a única superfície de jogo que hoje
// funciona de ponta a ponta. Mexer nele para ganhar uma constante compartilhada
// é gastar o risco no lugar errado, e esta OS proíbe expressamente regredir o
// treino.
//
// O preço dessa decisão é a divergência: alguém renomeia um arquivo de arte, o
// treino acompanha e o online não. É um preço que se paga com teste, não com
// esperança — `arte_das_cartas_test.dart` lê a fonte de `lib/mesa.dart`, extrai
// a convenção que ele usa e falha se as duas deixarem de bater. A dívida está
// registrada e vigiada; quando alguém for reformar `mesa.dart` por outro
// motivo, a extração fica barata e o teste vira desnecessário.

import 'package:flutter/material.dart';

import 'estado_mesa_online.dart';

/// O dorso, para monte e mortos — as pilhas que ninguém pode ver.
const String kDorsoDaCarta = 'assets/baralho/dorso.webp';

/// O caminho da arte de uma carta.
///
/// A convenção é a mesma de `lib/mesa.dart`: `naipe_valor.webp`, e os dois
/// desenhos de curinga alternando pela paridade da soma dos códigos do id —
/// que é só uma forma barata de a mesa não ficar com dois curingas idênticos
/// lado a lado.
String arteDaCarta(CartaOnline c) {
  if (c.valor == 'JOKER') {
    final h = c.id.codeUnits.fold<int>(0, (a, b) => a + b);
    return h.isEven ? 'assets/baralho/joker.webp' : 'assets/baralho/joker2.webp';
  }
  return 'assets/baralho/${c.naipe}_${c.valor}.webp';
}

const Map<String, String> _simbolos = {
  'copas': '♥',
  'ouros': '♦',
  'paus': '♣',
  'espadas': '♠',
};

String simboloDaCarta(CartaOnline c) =>
    c.valor == 'JOKER' ? '★' : (_simbolos[c.naipe] ?? '');

String rotuloDaCarta(CartaOnline c) => c.valor == 'JOKER' ? '★' : c.valor;

/// Uma carta desenhada.
///
/// [selecionada] e [destacada] são estados PURAMENTE VISUAIS e locais: a
/// seleção é do dedo da pessoa e não existe para o servidor, e o destaque é a
/// carta que o servidor disse ter de ser usada antes do descarte. Nenhum dos
/// dois muda o estado da partida.
class CartaOnlineWidget extends StatelessWidget {
  const CartaOnlineWidget({
    super.key,
    required this.carta,
    this.largura = 46,
    this.selecionada = false,
    this.destacada = false,
    this.onTap,
  });

  final CartaOnline carta;
  final double largura;
  final bool selecionada;
  final bool destacada;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final altura = largura * 1.45;
    final Color borda;
    if (selecionada) {
      borda = const Color(0xFFEFB94A);
    } else if (destacada) {
      borda = const Color(0xFF63C6F5);
    } else {
      borda = const Color(0x33000000);
    }

    return Semantics(
      // O leitor de tela precisa da carta em palavras: a arte é uma imagem sem
      // texto, e sem isto a mão inteira seria silêncio.
      label: _emPalavras(carta),
      selected: selecionada,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: largura,
          height: altura,
          // A carta selecionada sobe um pouco — é o gesto que a mesa física
          // faz, e diz "esta está na sua escolha" sem precisar de legenda.
          margin: EdgeInsets.only(
            top: selecionada ? 0 : 10,
            bottom: selecionada ? 10 : 0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borda, width: selecionada ? 2.4 : 1),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            arteDaCarta(carta),
            fit: BoxFit.cover,
            // A arte pode faltar num build mal empacotado. Cair para o desenho
            // de texto é melhor do que um quadrado cinza: a pessoa continua
            // conseguindo jogar.
            errorBuilder: (_, _, _) => _CartaEmTexto(carta: carta),
          ),
        ),
      ),
    );
  }
}

String _emPalavras(CartaOnline c) {
  if (c.valor == 'JOKER') return 'curinga';
  const nomes = {
    'A': 'ás',
    'J': 'valete',
    'Q': 'dama',
    'K': 'rei',
  };
  final valor = nomes[c.valor] ?? c.valor;
  final naipe = switch (c.naipe) {
    'copas' => 'de copas',
    'ouros' => 'de ouros',
    'paus' => 'de paus',
    'espadas' => 'de espadas',
    _ => '',
  };
  return '$valor $naipe'.trim();
}

/// A carta sem arte: naipe e valor desenhados.
class _CartaEmTexto extends StatelessWidget {
  const _CartaEmTexto({required this.carta});

  final CartaOnline carta;

  @override
  Widget build(BuildContext context) {
    final cor = carta.ehVermelha
        ? const Color(0xFFC0392B)
        : const Color(0xFF1C130C);
    return Container(
      color: const Color(0xFFF6F1E4),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rotuloDaCarta(carta),
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              Text(
                simboloDaCarta(carta),
                style: TextStyle(color: cor, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uma pilha fechada — monte ou mortos. Mostra o dorso e a contagem.
///
/// A contagem é tudo o que se sabe: `visaoDoAssento` manda `monteQtd` e
/// `mortosQtd`, e nunca as cartas. Desenhar o dorso é literal, não decorativo.
class PilhaFechada extends StatelessWidget {
  const PilhaFechada({
    super.key,
    required this.rotulo,
    required this.quantidade,
    this.largura = 46,
    this.onTap,
    this.habilitada = false,
  });

  final String rotulo;
  final int quantidade;
  final double largura;
  final VoidCallback? onTap;
  final bool habilitada;

  @override
  Widget build(BuildContext context) {
    final altura = largura * 1.45;
    return Semantics(
      label: '$rotulo, $quantidade cartas',
      button: habilitada,
      // O TOQUE PEGA A PILHA INTEIRA, rótulo incluído. Com o gesto só na
      // imagem, o alvo é uma carta de 46 pontos de largura — pequeno para o
      // dedo, e menor ainda para quem tem pouca firmeza na mão. O rótulo está
      // logo abaixo, faz parte da mesma coisa aos olhos de quem joga, e é
      // espaço de toque de graça.
      child: GestureDetector(
        onTap: habilitada ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: quantidade == 0 ? 0.35 : 1,
              child: Container(
                width: largura,
                height: altura,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: habilitada
                        ? const Color(0xFFEFB94A)
                        : const Color(0x33EFB94A),
                    width: habilitada ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  kDorsoDaCarta,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: const Color(0xFF2A1B0E)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$rotulo · $quantidade',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF9A8C6C), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
