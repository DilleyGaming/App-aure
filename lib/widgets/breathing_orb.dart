import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Estado de la "presencia" de Auré.
enum OrbMode { idle, listening, thinking, speaking }

/// La luz que respira: el alma visual de Auré.
class BreathingOrb extends StatefulWidget {
  const BreathingOrb({super.key, this.size = 120, this.mode = OrbMode.idle});

  final double size;
  final OrbMode mode;

  @override
  State<BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<BreathingOrb> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _fase = 0;
  double _giro = 0;
  Duration _ultimo = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration ahora) {
    final dt = (ahora - _ultimo).inMicroseconds / 1e6;
    _ultimo = ahora;
    final velocidad = switch (widget.mode) {
      OrbMode.idle => 0.22,
      OrbMode.listening => 0.9,
      OrbMode.thinking => 0.5,
      OrbMode.speaking => 1.6,
    };
    setState(() {
      _fase += dt * velocidad * 2 * math.pi;
      _giro += dt * 3.2;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _OrbPainter(sinMovimiento ? math.pi / 2 : _fase, _giro, widget.mode),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.fase, this.giro, this.mode);

  final double fase;
  final double giro;
  final OrbMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final respira = 0.5 + 0.5 * math.sin(fase);
    final voz = mode == OrbMode.speaking ? 0.5 + 0.5 * math.sin(fase * 2.3) : 0.0;

    // Halo suave
    canvas.drawCircle(
      c,
      r * 0.85,
      Paint()
        ..color = AureColors.dorado.withValues(alpha: 0.05 + 0.07 * respira)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.22),
    );

    // Anillos
    for (var i = 0; i < 3; i++) {
      final radio = r * (0.42 + i * 0.19) * (0.94 + 0.08 * respira + 0.05 * voz);
      final alfa = (0.55 - i * 0.15) * (0.45 + 0.55 * respira);
      canvas.drawCircle(
        c,
        radio,
        Paint()
          ..color = AureColors.dorado.withValues(alpha: alfa.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // Onda al escuchar
    if (mode == OrbMode.listening) {
      final p = (fase / (2 * math.pi)) % 1;
      canvas.drawCircle(
        c,
        r * (0.45 + 0.5 * p),
        Paint()
          ..color = AureColors.dorado.withValues(alpha: 0.5 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Arco al pensar
    if (mode == OrbMode.thinking) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.74),
        giro,
        1.3,
        false,
        Paint()
          ..color = AureColors.doradoClaro
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Núcleo luminoso
    final nucleo = r * 0.3 * (0.92 + 0.1 * respira + 0.1 * voz);
    canvas.drawCircle(
      c,
      nucleo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AureColors.doradoClaro,
            AureColors.dorado,
            AureColors.dorado.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: c, radius: nucleo)),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}
