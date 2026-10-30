import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

enum PreparacaoEtapa {
  confirmando,
  embaralhando,
  separandoMortos,
  distribuindo,
  pronta,
}

enum PosicaoJogador { topo, direita, baixo, esquerda }

class JogadorPreparacaoVM {
  final String id;
  final String nome;
  final String avatar;
  final bool ehVip;
  final bool pronto;
  final PosicaoJogador posicao;

  const JogadorPreparacaoVM({
    required this.id,
    required this.nome,
    required this.avatar,
    required this.ehVip,
    required this.pronto,
    required this.posicao,
  });
}

class PreparandoPartidaVM {
  final String titulo;
  final String subtitulo;
  final bool ehVip;
  final List<JogadorPreparacaoVM> jogadores;

  const PreparandoPartidaVM({
    required this.titulo,
    required this.subtitulo,
    required this.ehVip,
    required this.jogadores,
  });

  factory PreparandoPartidaVM.mock({bool ehVip = false}) {
    return PreparandoPartidaVM(
      titulo: 'SUA PARTIDA VAI COMEÇAR',
      subtitulo: 'Tudo pronto! Boa sorte e bom jogo!',
      ehVip: ehVip,
      jogadores: const [
        JogadorPreparacaoVM(
          id: 'carlos',
          nome: 'Carlos',
          avatar: '🧔🏻',
          ehVip: true,
          pronto: true,
          posicao: PosicaoJogador.topo,
        ),
        JogadorPreparacaoVM(
          id: 'rafael',
          nome: 'Rafael',
          avatar: '🧔🏽',
          ehVip: true,
          pronto: true,
          posicao: PosicaoJogador.direita,
        ),
        JogadorPreparacaoVM(
          id: 'patricia',
          nome: 'Patrícia',
          avatar: '👩🏼',
          ehVip: true,
          pronto: true,
          posicao: PosicaoJogador.baixo,
        ),
        JogadorPreparacaoVM(
          id: 'juliana',
          nome: 'Juliana',
          avatar: '👩🏽',
          ehVip: true,
          pronto: true,
          posicao: PosicaoJogador.esquerda,
        ),
      ],
    );
  }
}

/// Transição entre a confirmação dos jogadores e a mesa de jogo.
///
/// A tela não conhece servidor, publicidade ou motor. Ela executa
/// [onPrepararPartida] em paralelo à animação mínima e só chama
/// [onConcluido] depois que ambos terminarem.
class PreparandoPartidaScreen extends StatefulWidget {
  const PreparandoPartidaScreen({
    super.key,
    required this.vm,
    required this.onConcluido,
    this.onPrepararPartida,
    this.onErro,
    this.onSaibaMaisVip,
    this.anuncio,
    this.habilitarSom = true,
    this.duracaoMinima = const Duration(milliseconds: 5100),
  });

  final PreparandoPartidaVM vm;
  final Future<void> Function()? onPrepararPartida;
  final VoidCallback onConcluido;
  final ValueChanged<Object>? onErro;
  final VoidCallback? onSaibaMaisVip;
  final Widget? anuncio;
  final bool habilitarSom;
  final Duration duracaoMinima;

  @override
  State<PreparandoPartidaScreen> createState() =>
      _PreparandoPartidaScreenState();
}

class _PreparandoPartidaScreenState extends State<PreparandoPartidaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final AudioPlayer _audio = AudioPlayer();

  int _etapaAnterior = -1;
  Object? _erro;
  bool _finalizada = false;
  bool _preparando = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0);
    _controller.addListener(_acompanharEtapas);
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  PreparacaoEtapa _etapaPara(double valor) {
    if (valor < .15) return PreparacaoEtapa.confirmando;
    if (valor < .45) return PreparacaoEtapa.embaralhando;
    if (valor < .63) return PreparacaoEtapa.separandoMortos;
    if (valor < .91) return PreparacaoEtapa.distribuindo;
    return PreparacaoEtapa.pronta;
  }

  void _acompanharEtapas() {
    final indice = _etapaPara(_controller.value).index;
    if (indice == _etapaAnterior) return;
    _etapaAnterior = indice;
    if (widget.habilitarSom && indice > 0 && indice < 4) {
      _tocarCarta(indice == 1 ? .30 : .20);
    }
  }

  Future<void> _tocarCarta(double volume) async {
    try {
      await _audio.play(AssetSource('sons/carta.mp3'), volume: volume);
    } catch (_) {
      // Falha de som nunca pode impedir a entrada na partida.
    }
  }

  Future<void> _iniciar() async {
    if (_preparando || !mounted) return;
    _preparando = true;
    _finalizada = false;
    _etapaAnterior = -1;
    _controller.value = 0;
    setState(() => _erro = null);

    try {
      final primeiraParteMs =
          (widget.duracaoMinima.inMilliseconds * .88).round();
      final animacaoInicial = _controller.animateTo(
        .88,
        duration: Duration(milliseconds: primeiraParteMs),
        curve: Curves.easeInOutCubic,
      );
      final preparoReal =
          widget.onPrepararPartida?.call() ?? Future<void>.value();

      await Future.wait<void>([animacaoInicial, preparoReal]);
      if (!mounted) return;

      await _controller.animateTo(
        1,
        duration: Duration(
          milliseconds: math.max(
            520,
            widget.duracaoMinima.inMilliseconds - primeiraParteMs,
          ),
        ),
        curve: Curves.easeOutCubic,
      );
      if (widget.habilitarSom) await _tocarCarta(.25);
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted || _finalizada) return;
      _finalizada = true;
      widget.onConcluido();
    } catch (erro) {
      if (!mounted) return;
      widget.onErro?.call(erro);
      setState(() {
        _erro = erro;
        _preparando = false;
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_acompanharEtapas)
      ..dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050201),
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 430,
              height: 850,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      const _FundoPreparacao(),
                      CustomPaint(
                        painter: _ParticulasPainter(_controller.value),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Column(
                          children: [
                            _Cabecalho(
                              titulo: widget.vm.titulo,
                              subtitulo: widget.vm.subtitulo,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              flex: 42,
                              child: _MesaAnimada(
                                jogadores: widget.vm.jogadores,
                                progresso: _controller.value,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 218,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 64,
                                    child: _EtapasPanel(
                                      progresso: _controller.value,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 36,
                                    child: _ProgressoPanel(
                                      progresso: _controller.value,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 104,
                              child: widget.vm.ehVip
                                  ? const _BeneficioVip()
                                  : _MonetizacaoLivre(
                                      anuncio: widget.anuncio,
                                      onSaibaMaisVip:
                                          widget.onSaibaMaisVip,
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.vm.ehVip
                                  ? '👑 Benefício VIP: sua partida começa sem anúncios.'
                                  : 'Apoie o jogo enquanto a mesa é preparada.',
                              style: const TextStyle(
                                color: Color(0xFF9C918B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_erro != null)
                        _ErroPreparacao(onTentarNovamente: _iniciar),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FundoPreparacao extends StatelessWidget {
  const _FundoPreparacao();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.48),
              radius: 1.2,
              colors: [
                Color(0xFF29150B),
                Color(0xFF120805),
                Color(0xFF030201),
              ],
              stops: [0, .52, 1],
            ),
          ),
        ),
        Positioned(
          top: -58,
          left: -72,
          child: _Cortina(cantoEsquerdo: true),
        ),
        Positioned(
          top: -58,
          right: -72,
          child: _Cortina(cantoEsquerdo: false),
        ),
      ],
    );
  }
}

class _Cortina extends StatelessWidget {
  const _Cortina({required this.cantoEsquerdo});
  final bool cantoEsquerdo;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: cantoEsquerdo ? -.35 : .35,
      child: Container(
        width: 180,
        height: 190,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: cantoEsquerdo
                ? Alignment.topLeft
                : Alignment.topRight,
            end: cantoEsquerdo
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            colors: const [
              Color(0xFF6D1AA1),
              Color(0xFF24052F),
              Colors.transparent,
            ],
          ),
          border: Border.all(color: const Color(0xFFEFB94A), width: 1.2),
          borderRadius: BorderRadius.circular(90),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.titulo, required this.subtitulo});
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: Image.asset(
            'assets/splash/logo_splash_oficial.webp',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF6E2A6),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFBEB3AC),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MesaAnimada extends StatelessWidget {
  const _MesaAnimada({required this.jogadores, required this.progresso});
  final List<JogadorPreparacaoVM> jogadores;
  final double progresso;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final deckCenter = Offset(size.width / 2, size.height / 2 + 4);
        final deal = ((progresso - .62) / .28).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 20,
              bottom: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101111),
                  borderRadius: BorderRadius.circular(150),
                  border: Border.all(
                    color: const Color(0xFF9D691D),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x559C6518),
                      blurRadius: 16,
                    ),
                    BoxShadow(
                      color: Color(0xFF020202),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: 33,
              bottom: 33,
              left: 13,
              right: 13,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(140),
                  border: Border.all(color: const Color(0xFF3D2D18)),
                  gradient: const RadialGradient(
                    colors: [Color(0xFF191A19), Color(0xFF090A09)],
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: size,
              painter: _BrilhoMesaPainter(progresso),
            ),
            ...jogadores.map(
              (jogador) => _posicionarJogador(jogador, size),
            ),
            ..._cartasDistribuidas(size, deckCenter, deal),
            Positioned(
              left: deckCenter.dx - 42,
              top: deckCenter.dy + 46,
              child: const Row(
                children: [
                  _CartaPequena(largura: 32, altura: 44),
                  SizedBox(width: 8),
                  _CartaPequena(largura: 32, altura: 44),
                ],
              ),
            ),
            Positioned(
              left: deckCenter.dx - 31,
              top: deckCenter.dy - 50,
              child: _BaralhoEmbaralhando(progresso: progresso),
            ),
          ],
        );
      },
    );
  }

  Widget _posicionarJogador(JogadorPreparacaoVM jogador, Size size) {
    switch (jogador.posicao) {
      case PosicaoJogador.topo:
        return Positioned(
          top: 0,
          left: size.width / 2 - 62,
          child: _JogadorChip(jogador: jogador, horizontal: false),
        );
      case PosicaoJogador.direita:
        return Positioned(
          right: 0,
          top: size.height / 2 - 36,
          child: _JogadorChip(jogador: jogador, horizontal: true),
        );
      case PosicaoJogador.baixo:
        return Positioned(
          bottom: 0,
          left: size.width / 2 - 62,
          child: _JogadorChip(jogador: jogador, horizontal: false),
        );
      case PosicaoJogador.esquerda:
        return Positioned(
          left: 0,
          top: size.height / 2 - 36,
          child: _JogadorChip(jogador: jogador, horizontal: true),
        );
    }
  }

  List<Widget> _cartasDistribuidas(
    Size size,
    Offset centro,
    double deal,
  ) {
    final destinos = <Offset>[
      Offset(size.width / 2 - 30, 55),
      Offset(size.width - 84, size.height / 2 - 16),
      Offset(size.width / 2 - 30, size.height - 92),
      Offset(54, size.height / 2 - 16),
    ];

    return List.generate(destinos.length, (index) {
      final inicio = index * .10;
      final local = ((deal - inicio) / (1 - inicio)).clamp(0.0, 1.0);
      final curva = Curves.easeOutCubic.transform(local);
      final destino = destinos[index];
      final x = centro.dx - 15 + (destino.dx - centro.dx + 15) * curva;
      final y = centro.dy - 22 + (destino.dy - centro.dy + 22) * curva;
      return Positioned(
        left: x,
        top: y,
        child: Opacity(
          opacity: local,
          child: Transform.rotate(
            angle: (index - 1.5) * .12,
            child: const _CartaPequena(largura: 28, altura: 40),
          ),
        ),
      );
    });
  }
}

class _JogadorChip extends StatelessWidget {
  const _JogadorChip({required this.jogador, required this.horizontal});
  final JogadorPreparacaoVM jogador;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF19110C),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFEFB94A), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66EFB94A), blurRadius: 8),
            ],
          ),
          child: Text(jogador.avatar, style: const TextStyle(fontSize: 29)),
        ),
        if (jogador.ehVip)
          const Positioned(right: -4, bottom: -3, child: _MiniVip()),
      ],
    );

    final textos = Column(
      crossAxisAlignment: horizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          jogador.nome,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFD79926),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            jogador.pronto ? 'PRONTO' : 'AGUARDANDO',
            style: const TextStyle(
              color: Color(0xFF211407),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [avatar, const SizedBox(width: 5), textos],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [avatar, const SizedBox(height: 2), textos],
    );
  }
}

class _MiniVip extends StatelessWidget {
  const _MiniVip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF4C1379),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFEFB94A)),
      ),
      child: const Text(
        '♛',
        style: TextStyle(color: Color(0xFFFFD467), fontSize: 12),
      ),
    );
  }
}

class _BaralhoEmbaralhando extends StatelessWidget {
  const _BaralhoEmbaralhando({required this.progresso});
  final double progresso;

  @override
  Widget build(BuildContext context) {
    final embaralhando = ((progresso - .13) / .34).clamp(0.0, 1.0);
    final oscilacao = math.sin(embaralhando * math.pi * 14);

    return SizedBox(
      width: 62,
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(5, (index) {
          final distancia = (index - 2) * 2.3;
          final movimento = oscilacao * (index - 2).abs() * 2.6;
          return Transform.translate(
            offset: Offset(distancia + movimento, -index * 1.2),
            child: Transform.rotate(
              angle: (index - 2) * .028 + oscilacao * .012,
              child: Image.asset(
                'assets/baralho/dorso.webp',
                width: 42,
                height: 60,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CartaPequena extends StatelessWidget {
  const _CartaPequena({required this.largura, required this.altura});
  final double largura;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: largura,
      height: altura,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset('assets/baralho/dorso.webp', fit: BoxFit.fill),
      ),
    );
  }
}

class _EtapaDef {
  final String texto;
  final IconData icone;
  const _EtapaDef(this.texto, this.icone);
}

class _EtapasPanel extends StatelessWidget {
  const _EtapasPanel({required this.progresso});
  final double progresso;

  static const _etapas = <_EtapaDef>[
    _EtapaDef('Confirmando jogadores', Icons.groups_rounded),
    _EtapaDef('Embaralhando as cartas', Icons.shuffle_rounded),
    _EtapaDef('Separando os mortos', Icons.inventory_2_rounded),
    _EtapaDef('Distribuindo 11 cartas', Icons.style_rounded),
    _EtapaDef('Mesa pronta!', Icons.workspace_premium_rounded),
  ];

  int get _atual {
    if (progresso < .15) return 0;
    if (progresso < .45) return 1;
    if (progresso < .63) return 2;
    if (progresso < .91) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xCC0C0A08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF78521F)),
      ),
      child: Column(
        children: List.generate(_etapas.length, (index) {
          final concluida = index < _atual;
          final ativa = index == _atual;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: ativa
                    ? const Color(0xFF311144)
                    : const Color(0xFF14100D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: ativa
                      ? const Color(0xFFB94CF0)
                      : const Color(0xFF2E251F),
                ),
                boxShadow: ativa
                    ? const [
                        BoxShadow(
                          color: Color(0x665F1B84),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    _etapas[index].icone,
                    size: 16,
                    color: ativa
                        ? const Color(0xFFF6E2A6)
                        : concluida
                            ? const Color(0xFFEFB94A)
                            : const Color(0xFF8E837C),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _etapas[index].texto,
                      style: TextStyle(
                        color: ativa
                            ? const Color(0xFFF6E2A6)
                            : concluida
                                ? Colors.white
                                : const Color(0xFF9C918B),
                        fontSize: 11,
                        fontWeight:
                            ativa ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (concluida)
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFFEFB94A),
                      size: 17,
                    )
                  else if (ativa)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFB94CF0),
                      ),
                    )
                  else
                    Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF635A54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ProgressoPanel extends StatelessWidget {
  const _ProgressoPanel({required this.progresso});
  final double progresso;

  @override
  Widget build(BuildContext context) {
    final percentual = (progresso * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 13, 11, 12),
      decoration: BoxDecoration(
        color: const Color(0xCC0C0A08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF78521F)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF15110D),
              border: Border.all(color: const Color(0xFFEFB94A), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x55EFB94A), blurRadius: 12),
              ],
            ),
            child: Transform.rotate(
              angle: progresso * math.pi * 2,
              child: const Icon(
                Icons.spa_rounded,
                color: Color(0xFFEFB94A),
                size: 37,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Preparando cada\ndetalhe para uma\npartida perfeita.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFC8BDB6),
              fontSize: 11,
              height: 1.25,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 9,
              backgroundColor: const Color(0xFF2A1332),
              valueColor: const AlwaysStoppedAnimation(
                Color(0xFFEFB94A),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$percentual%',
            style: const TextStyle(
              color: Color(0xFFEFB94A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonetizacaoLivre extends StatelessWidget {
  const _MonetizacaoLivre({this.anuncio, this.onSaibaMaisVip});
  final Widget? anuncio;
  final VoidCallback? onSaibaMaisVip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF351044), Color(0xFF130A16), Color(0xFF0B0908)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFB94A), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 58,
            child: Row(
              children: [
                const Icon(
                  Icons.diamond_rounded,
                  color: Color(0xFFEFB94A),
                  size: 32,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'JOGUE SEM LIMITES',
                        style: TextStyle(
                          color: Color(0xFFEFB94A),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'SEJA VIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Sem anúncios e com recompensas exclusivas.',
                        style: TextStyle(
                          color: Color(0xFFD9C793),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onSaibaMaisVip,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF211407),
                    backgroundColor: const Color(0xFFEFB94A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text(
                    'SAIBA MAIS',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 42,
            child: Semantics(
              label: 'Anúncio',
              container: true,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF716A66)),
                ),
                child: anuncio ?? const _AnuncioPlaceholder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnuncioPlaceholder extends StatelessWidget {
  const _AnuncioPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ANÚNCIO',
            style: TextStyle(
              color: Color(0xFF9B9693),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'carregando…',
            style: TextStyle(color: Color(0xFF716D6A), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _BeneficioVip extends StatelessWidget {
  const _BeneficioVip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF461361), Color(0xFF18091E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFB94A)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFFEFB94A),
            size: 44,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BENEFÍCIO VIP',
                  style: TextStyle(
                    color: Color(0xFFEFB94A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sua partida começa sem anúncios.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Mais conforto, a mesma disputa justa.',
                  style: TextStyle(
                    color: Color(0xFFCABDB6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErroPreparacao extends StatelessWidget {
  const _ErroPreparacao({required this.onTentarNovamente});
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xDD050201),
      child: Center(
        child: Container(
          width: 330,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1C130C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEFB94A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFEFB94A),
                size: 42,
              ),
              const SizedBox(height: 12),
              const Text(
                'Não foi possível preparar a mesa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confira a conexão e tente novamente. Nenhuma aposta foi duplicada.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBDB2AB),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 17),
              FilledButton(
                onPressed: onTentarNovamente,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEFB94A),
                  foregroundColor: const Color(0xFF211407),
                ),
                child: const Text(
                  'Tentar novamente',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrilhoMesaPainter extends CustomPainter {
  const _BrilhoMesaPainter(this.progresso);
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 3; i++) {
      final raio = 39 + i * 13 + math.sin(progresso * 16 + i) * 4;
      paint.color = const Color(0xFFEFB94A).withOpacity(.20 - i * .04);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: raio),
        progresso * math.pi * 2 + i,
        math.pi * 1.25,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BrilhoMesaPainter oldDelegate) =>
      oldDelegate.progresso != progresso;
}

class _ParticulasPainter extends CustomPainter {
  const _ParticulasPainter(this.progresso);
  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(29072026);
    final paint = Paint();
    for (var i = 0; i < 38; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y =
          (baseY - progresso * (20 + random.nextDouble() * 60)) % size.height;
      final twinkle = .35 + .65 * math.sin(progresso * 20 + i).abs();
      paint.color = const Color(0xFFFFD96A).withOpacity(.12 + twinkle * .34);
      canvas.drawCircle(
        Offset(x, y),
        .5 + random.nextDouble() * 1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticulasPainter oldDelegate) =>
      oldDelegate.progresso != progresso;
}
