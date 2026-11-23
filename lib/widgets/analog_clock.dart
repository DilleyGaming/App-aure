import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Reloj analógico dorado de Auré, con el logo bajo las 12 y un brillo que respira.
class AnalogClock extends StatefulWidget {
  const AnalogClock({super.key, this.size = 320});

  final double size;

  @override
  State<AnalogClock> createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => setState(() => _t = d.inMicroseconds / 1e6))..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      label: 'Reloj',
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RelojPainter(DateTime.now(), sinMovimiento ? 0.5 : 0.5 + 0.5 * math.sin(_t * 1.4)),
        ),
      ),
    );
  }
}

class _RelojPainter extends CustomPainter {
  _RelojPainter(this.ahora, this.respira);

  final DateTime ahora;
  final double respira;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Brillo exterior que respira
    canvas.drawCircle(
      c,
      r * 0.98,
      Paint()
        ..color = AureColors.dorado.withValues(alpha: 0.04 + 0.06 * respira)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );

    // Esfera
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF17161B), Color(0xFF0B0B0D)],
          stops: [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.94)),
    );

    // Bisel: dos aros dorados finos
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..color = AureColors.dorado.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.012,
    );
    canvas.drawCircle(
      c,
      r * 0.885,
      Paint()
        ..color = AureColors.dorado.withValues(alpha: 0.25 + 0.15 * respira)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.005,
    );

    // Marcas de minutos
    final fino = Paint()
      ..color = AureColors.dorado.withValues(alpha: 0.35)
      ..strokeWidth = r * 0.006
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      if (i % 5 == 0) continue;
      final a = i * math.pi / 30;
      canvas.drawLine(_punto(c, r * 0.84, a), _punto(c, r * 0.81, a), fino);
    }

    // Índices horarios (barras doradas); doble índice a las 12
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      final ancho = r * 0.034;
      final largo = i % 3 == 0 ? r * 0.15 : r * 0.11;
      void barra(double dx) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(dx - ancho / 2, -r * 0.84, ancho, largo),
          Radius.circular(ancho * 0.3),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              colors: [AureColors.doradoClaro, AureColors.dorado, Color(0xFF9C7E4A)],
            ).createShader(rect.outerRect),
        );
      }

      if (i == 0) {
        barra(-ancho * 0.8);
        barra(ancho * 0.8);
      } else {
        barra(0);
      }
      canvas.restore();
    }

    // Logo de Auré y su nombre bajo las 12
    _logo(canvas, Offset(c.dx, c.dy - r * 0.46), r * 0.0034);
    final nombre = TextPainter(
      text: TextSpan(
        text: 'AURÉ',
        style: TextStyle(
          color: AureColors.dorado,
          fontSize: r * 0.068,
          letterSpacing: r * 0.03,
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    nombre.paint(canvas, Offset(c.dx - nombre.width / 2 + r * 0.015, c.dy - r * 0.3));

    // Agujas
    final s = ahora.second + ahora.millisecond / 1000;
    final m = ahora.minute + s / 60;
    final h = (ahora.hour % 12) + m / 60;
    _aguja(canvas, c, h * math.pi / 6, r * 0.5, r * 0.055);
    _aguja(canvas, c, m * math.pi / 30, r * 0.74, r * 0.042);

    // Segundero fino con contrapeso
    final as = s * math.pi / 30;
    final segundero = Paint()
      ..color = AureColors.doradoClaro
      ..strokeWidth = r * 0.008
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(_punto(c, -r * 0.16, as), _punto(c, r * 0.8, as), segundero);
    canvas.drawCircle(_punto(c, -r * 0.13, as), r * 0.025, Paint()..color = AureColors.doradoClaro);

    // Centro luminoso que respira (la luz de Auré)
    canvas.drawCircle(
      c,
      r * 0.09,
      Paint()
        ..color = AureColors.dorado.withValues(alpha: 0.15 + 0.25 * respira)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );
    canvas.drawCircle(c, r * 0.032, Paint()..color = AureColors.doradoClaro);
    canvas.drawCircle(c, r * 0.014, Paint()..color = const Color(0xFF0B0B0D));
  }

  Offset _punto(Offset c, double radio, double angulo) =>
      Offset(c.dx + radio * math.sin(angulo), c.dy - radio * math.cos(angulo));

  /// Aguja facetada tipo "dauphine": una mitad clara y otra oscura.
  void _aguja(Canvas canvas, Offset c, double angulo, double largo, double ancho) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angulo);
    final cola = largo * 0.14;
    final izquierda = Path()
      ..moveTo(0, cola)
      ..lineTo(-ancho, 0)
      ..lineTo(0, -largo)
      ..close();
    final derecha = Path()
      ..moveTo(0, cola)
      ..lineTo(ancho, 0)
      ..lineTo(0, -largo)
      ..close();
    final sombra = Path()
      ..addPath(izquierda, Offset.zero)
      ..addPath(derecha, Offset.zero);
    canvas.drawShadow(sombra, Colors.black, 3, false);
    canvas.drawPath(izquierda, Paint()..color = AureColors.doradoClaro);
    canvas.drawPath(derecha, Paint()..color = const Color(0xFFB8975E));
    canvas.restore();
  }

  /// El símbolo de Auré (casa mayordomo) dibujado en dorado.
  void _logo(Canvas canvas, Offset centro, double escala) {
    final k = escala;
    canvas.save();
    canvas.translate(centro.dx - 32 * k, centro.dy - 34 * k);
    canvas.scale(k);
    final trazo = Paint()
      ..color = AureColors.dorado
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final relleno = Paint()..color = AureColors.dorado;
    canvas.drawPath(
      Path()
        ..moveTo(10, 30)
        ..lineTo(32, 10)
        ..lineTo(54, 30)
        ..lineTo(54, 58)
        ..lineTo(10, 58)
        ..close(),
      trazo,
    );
    canvas.drawPath(
      Path()
        ..moveTo(24, 30)
        ..lineTo(32, 37)
        ..lineTo(40, 30),
      trazo,
    );
    final nudo = Path()
      ..moveTo(29.5, 37)
      ..lineTo(34.5, 37)
      ..lineTo(33.5, 41)
      ..lineTo(30.5, 41)
      ..close();
    final corbata = Path()
      ..moveTo(30.5, 41)
      ..lineTo(28.5, 51)
      ..lineTo(32, 56)
      ..lineTo(35.5, 51)
      ..lineTo(33.5, 41)
      ..close();
    canvas.drawPath(nudo, relleno);
    canvas.drawPath(corbata, relleno);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RelojPainter old) => true;
}
