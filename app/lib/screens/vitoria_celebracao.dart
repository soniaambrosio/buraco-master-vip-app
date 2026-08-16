import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Contrato visual da comemoração de vitória.
///
/// A autoridade para dizer quem venceu é do servidor/motor. A UI nunca deve
/// inferir o vencedor apenas comparando textos/placares parciais.
class CelebracaoVitoriaVM {
  final String eventoId;
  final bool ativa;
  final bool jogadorLocalVenceu;
  final List<String> nomesVencedores;
  final bool somHabilitado;
  final String efeitoId;
  final Duration duracao;

  const CelebracaoVitoriaVM({
    required this.eventoId,
    required this.ativa,
    required this.jogadorLocalVenceu,
    required this.nomesVencedores,
    this.somHabilitado = true,
    this.efeitoId = 'confete_padrao',
    this.duracao = const Duration(milliseconds: 2600),
  });

  bool get tocarSomLocal => ativa && jogadorLocalVenceu && somHabilitado;

  bool get usarConfetePadrao => ativa && efeitoId == 'confete_padrao';

  String get vencedoresLabel {
    if (nomesVencedores.isEmpty) return 'Dupla vencedora';
    if (nomesVencedores.length == 1) return nomesVencedores.first;
    return '${nomesVencedores[0]} & ${nomesVencedores[1]}';
  }
}

/// Camada visual reutilizável para ResultadoPartida/Mesa.
///
/// - confete é visível para todos, celebrando quem venceu;
/// - o som de vitória toca somente no dispositivo de integrante da dupla
///   vencedora;
/// - o efeito não intercepta toques nem modifica estado da partida;
/// - efeitos premium podem substituir `efeitoId` depois, mantendo o contrato.
class CelebracaoVitoriaLayer extends StatefulWidget {
  final CelebracaoVitoriaVM vm;
  final Widget child;

  const CelebracaoVitoriaLayer({
    super.key,
    required this.vm,
    required this.child,
  });

  @override
  State<CelebracaoVitoriaLayer> createState() => _CelebracaoVitoriaLayerState();
}

class _CelebracaoVitoriaLayerState extends State<CelebracaoVitoriaLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final AudioPlayer _audio = AudioPlayer();
  String? _eventoExecutado;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _executarSeNecessario());
  }

  @override
  void didUpdateWidget(covariant CelebracaoVitoriaLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm.eventoId != widget.vm.eventoId ||
        oldWidget.vm.ativa != widget.vm.ativa) {
      _executarSeNecessario();
    }
  }

  Future<void> _executarSeNecessario() async {
    if (!mounted || !widget.vm.ativa) return;
    if (_eventoExecutado == widget.vm.eventoId) return;
    _eventoExecutado = widget.vm.eventoId;

    _controller.duration = widget.vm.duracao;
    _controller
      ..stop()
      ..value = 0;

    // Áudio nunca pode bloquear nem quebrar a tela de resultado: sem plugin de
    // som disponível esta chamada não completa, e esperar por ela engolia o
    // confete inteiro. O adendo §10.5 é explícito — som mudo mantém o visual.
    if (widget.vm.tocarSomLocal) {
      unawaited(_tocarSomDaVitoria());
    }

    if (mounted) {
      await _controller.forward();
    }
  }

  Future<void> _tocarSomDaVitoria() async {
    try {
      await _audio.play(AssetSource('sons/vitoria.mp3'), volume: .78);
    } catch (_) {
      // Som é comemoração, não requisito.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (widget.vm.ativa)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.vm.usarConfetePadrao)
                        CustomPaint(
                          painter: _ConfeteVitoriaPainter(progress),
                        ),
                      Align(
                        alignment: const Alignment(0, -.62),
                        child: Opacity(
                          opacity: _bannerOpacity(progress),
                          child: Transform.scale(
                            scale: .94 + .06 * Curves.easeOutBack.transform(
                              progress.clamp(0.0, .42) / .42,
                            ),
                            child: _VencedoresBanner(
                              nomes: widget.vm.vencedoresLabel,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  double _bannerOpacity(double progress) {
    if (progress < .10) return progress / .10;
    if (progress < .78) return 1;
    return ((1 - progress) / .22).clamp(0.0, 1.0);
  }
}

class _VencedoresBanner extends StatelessWidget {
  final String nomes;

  const _VencedoresBanner({required this.nomes});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 310),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xF02C1608), Color(0xF0452810)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD76C), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0x77EFB94A), blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆  VITÓRIA!  🏆',
              style: TextStyle(
                color: Color(0xFFFFE7A0),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: .8,
              )),
          const SizedBox(height: 3),
          Text(
            nomes,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfeteVitoriaPainter extends CustomPainter {
  final double progress;

  const _ConfeteVitoriaPainter(this.progress);

  static const _colors = <Color>[
    Color(0xFFFFD76C),
    Color(0xFFB66DFF),
    Color(0xFF7EE8B0),
    Color(0xFFFF7A7A),
    Color(0xFFF6E2A6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(10082026);
    final paint = Paint();
    const total = 92;

    for (var i = 0; i < total; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = -30 - random.nextDouble() * size.height * .45;
      final speed = .65 + random.nextDouble() * .75;
      final drift = math.sin(progress * math.pi * 4 + i) * (8 + random.nextDouble() * 18);
      final y = startY + progress * (size.height + 130) * speed;
      final x = startX + drift;
      if (y < -40 || y > size.height + 30) continue;

      final w = 4.0 + random.nextDouble() * 5;
      final h = 7.0 + random.nextDouble() * 8;
      paint.color = _colors[i % _colors.length].withOpacity(
        progress > .88 ? ((1 - progress) / .12).clamp(0.0, 1.0) : .95,
      );

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * 8 + i * .47);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfeteVitoriaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
