import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Splash oficial animada do Buraco Master VIP.
///
/// A tela é exclusivamente visual. O destino final é recebido em [proximaTela].
/// O som pode ser desligado pela camada de preferências por [habilitarSom].
class SplashOficialScreen extends StatefulWidget {
  const SplashOficialScreen({
    super.key,
    required this.proximaTela,
    this.habilitarSom = true,
    this.duracao = const Duration(milliseconds: 3800),
  });

  final Widget proximaTela;
  final bool habilitarSom;
  final Duration duracao;

  @override
  State<SplashOficialScreen> createState() => _SplashOficialScreenState();
}

class _SplashOficialScreenState extends State<SplashOficialScreen>
    with SingleTickerProviderStateMixin {
  static const _ouro = Color(0xFFEFB94A);
  static const _ouroClaro = Color(0xFFF6E2A6);

  late final AnimationController _controller;
  late final Animation<double> _entrada;
  late final Animation<double> _escala;
  late final Animation<double> _conteudo;
  late final Animation<double> _progresso;
  late final Animation<double> _saida;

  final AudioPlayer _audio = AudioPlayer();
  bool _navegou = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duracao);
    _entrada = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.04, 0.34, curve: Curves.easeOutCubic),
    );
    _escala = Tween<double>(begin: 0.78, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.34, curve: Curves.easeOutBack),
      ),
    );
    _conteudo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.42, curve: Curves.easeOut),
    );
    _progresso = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.20, 0.91, curve: Curves.easeInOutCubic),
    );
    _saida = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.92, 1, curve: Curves.easeIn),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _abrirAplicativo();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.habilitarSom) {
        try {
          await _audio.play(
            AssetSource('splash/splash_intro.mp3'),
            volume: 0.52,
          );
        } catch (_) {
          // A splash nunca deve impedir a abertura do aplicativo por falha de áudio.
        }
      }
      if (mounted) {
        _controller.forward();
      }
    });
  }

  Future<void> _abrirAplicativo() async {
    if (_navegou || !mounted) return;
    _navegou = true;
    await _audio.stop();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, __, ___) => widget.proximaTela,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050201),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _controller.value >= 0.74 ? _abrirAplicativo : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: 1 - _saida.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _FundoSplash(),
                  CustomPaint(
                    painter: _ParticulasSplashPainter(
                      progresso: _controller.value,
                    ),
                  ),
                  SafeArea(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final largura = math.min(constraints.maxWidth, 430.0);
                        final logo = math.min(largura * 0.92, 390.0);

                        return Center(
                          child: SizedBox(
                            width: largura,
                            child: Column(
                              children: [
                                const Spacer(flex: 1),
                                FadeTransition(
                                  opacity: _entrada,
                                  child: ScaleTransition(
                                    scale: _escala,
                                    child: _LogoComBrilho(
                                      tamanho: logo,
                                      progresso: _controller.value,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FadeTransition(
                                  opacity: _conteudo,
                                  child: const Text(
                                    'PREPARANDO SUA MESA...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _ouroClaro,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.1,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FadeTransition(
                                  opacity: _conteudo,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 34),
                                    child: _BarraCarregamento(
                                      progresso: _progresso.value,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 34),
                                FadeTransition(
                                  opacity: _conteudo,
                                  child: const _AssinaturaSplash(),
                                ),
                                const Spacer(flex: 2),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FundoSplash extends StatelessWidget {
  const _FundoSplash();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.38),
          radius: 1.12,
          colors: [
            Color(0xFF321609),
            Color(0xFF160804),
            Color(0xFF050201),
            Color(0xFF000000),
          ],
          stops: [0, 0.38, 0.78, 1],
        ),
      ),
    );
  }
}

class _LogoComBrilho extends StatelessWidget {
  const _LogoComBrilho({
    required this.tamanho,
    required this.progresso,
  });

  final double tamanho;
  final double progresso;

  @override
  Widget build(BuildContext context) {
    final pulsoFinal =
        math.exp(-math.pow((progresso - 0.82) / 0.055, 2).toDouble());
    final brilhoX = -1.8 + progresso * 4.2;

    return SizedBox.square(
      dimension: tamanho,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.02 + pulsoFinal * 0.025,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEFB94A)
                        .withValues(alpha: 0.19 + pulsoFinal * 0.18),
                    blurRadius: 52 + pulsoFinal * 28,
                    spreadRadius: 2 + pulsoFinal * 4,
                  ),
                ],
              ),
            ),
          ),
          Image.asset(
            'assets/splash/logo_splash_oficial.webp',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          ClipRect(
            child: Transform.translate(
              offset: Offset(brilhoX * tamanho, 0),
              child: Transform.rotate(
                angle: -0.24,
                child: Container(
                  width: tamanho * 0.20,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.05),
                        const Color(0xFFFFEEC7).withValues(alpha: 0.34),
                        Colors.white.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraCarregamento extends StatelessWidget {
  const _BarraCarregamento({required this.progresso});

  final double progresso;

  @override
  Widget build(BuildContext context) {
    final valor = progresso.clamp(0.0, 1.0);

    return Container(
      height: 22,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF090401),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: SplashOficialScreenStateColors.ouro, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: SplashOficialScreenStateColors.ouro.withValues(alpha: 0.20),
            blurRadius: 13,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: valor,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFB76B09),
                    Color(0xFFFFD96A),
                    Color(0xFFFFF0AD),
                    Color(0xFFE8A516),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cores públicas somente para widgets auxiliares deste arquivo.
abstract final class SplashOficialScreenStateColors {
  static const ouro = Color(0xFFEFB94A);
}

class _AssinaturaSplash extends StatelessWidget {
  const _AssinaturaSplash();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 74, child: Divider(color: Color(0xFF81500E))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 20,
                color: Color(0xFFEFB94A),
              ),
            ),
            SizedBox(width: 74, child: Divider(color: Color(0xFF81500E))),
          ],
        ),
        SizedBox(height: 11),
        Text(
          'JOGUE. CONQUISTE. SEJA VIP.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFEFB94A),
            fontSize: 12,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ParticulasSplashPainter extends CustomPainter {
  const _ParticulasSplashPainter({required this.progresso});

  final double progresso;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(20260729);
    final paint = Paint();

    for (var i = 0; i < 46; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final velocidade = 18 + random.nextDouble() * 42;
      final fase = random.nextDouble() * math.pi * 2;
      final y = (baseY - progresso * velocidade) % size.height;
      final twinkle = 0.45 + 0.55 * math.sin(fase + progresso * 15).abs();
      final raio = 0.55 + random.nextDouble() * 1.45;

      paint.color = const Color(0xFFFFD86B)
          .withValues(alpha: 0.12 + twinkle * 0.48);
      canvas.drawCircle(Offset(baseX, y), raio * twinkle, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticulasSplashPainter oldDelegate) {
    return oldDelegate.progresso != progresso;
  }
}
