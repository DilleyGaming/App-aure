import 'package:flutter/material.dart';

import '../theme.dart';

/// El logo de Auré dibujándose trazo a trazo, y la palabra AURÉ apareciendo.
class ArranqueLogo extends StatefulWidget {
  const ArranqueLogo({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<ArranqueLogo> createState() => _ArranqueLogoState();
}

class _ArranqueLogoState extends State<ArranqueLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  bool _empezado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_empezado) return;
    _empezado = true;
    final sinMovimiento = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (sinMovimiento) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.alTerminar();
      });
      return;
    }
    _c.forward().whenComplete(() {
      if (mounted) widget.alTerminar();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AureColors.negro,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final trazo = Curves.easeInOutCubic.transform((_c.value / 0.65).clamp(0.0, 1.0));
            final relleno = ((_c.value - 0.45) / 0.25).clamp(0.0, 1.0);
            final palabra = ((_c.value - 0.55) / 0.3).clamp(0.0, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 104,
                  child: CustomPaint(painter: _LogoPainter(trazo, relleno)),
                ),
                const SizedBox(height: 26),
                Opacity(
                  opacity: palabra,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - palabra)),
                    child: Text('AURÉ', style: marca(26, spacing: 11)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.trazo, this.relleno);

  final double trazo;
  final double relleno;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 64;
    canvas.scale(k);
    final casa = Path()
      ..moveTo(10, 30)
      ..lineTo(32, 10)
      ..lineTo(54, 30)
      ..lineTo(54, 58)
      ..lineTo(10, 58)
      ..close();
    final cuello = Path()
      ..moveTo(24, 30)
      ..lineTo(32, 37)
      ..lineTo(40, 30);
    final pincel = Paint()
      ..color = AureColors.dorado
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final p in [casa, cuello]) {
      for (final m in p.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * trazo), pincel);
      }
    }
    if (relleno > 0) {
      final oro = Paint()..color = AureColors.dorado.withValues(alpha: relleno);
      canvas.drawPath(
        Path()
          ..moveTo(29.5, 37)
          ..lineTo(34.5, 37)
          ..lineTo(33.5, 41)
          ..lineTo(30.5, 41)
          ..close(),
        oro,
      );
      canvas.drawPath(
        Path()
          ..moveTo(30.5, 41)
          ..lineTo(28.5, 51)
          ..lineTo(32, 56)
          ..lineTo(35.5, 51)
          ..lineTo(33.5, 41)
          ..close(),
        oro,
      );
      // Brillo cálido que se enciende dentro de la casa
      canvas.drawCircle(
        const Offset(32, 44),
        16,
        Paint()
          ..color = AureColors.dorado.withValues(alpha: 0.18 * relleno)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.trazo != trazo || old.relleno != relleno;
}
