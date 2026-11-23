import 'package:flutter/material.dart';

import '../theme.dart';

/// Iconos propios de Auré: línea fina dorada, coherentes con el logo.
enum AureIcono { casa, habitaciones, escenas, ajustes, luz, persiana, clima, musica, enchufe, ventilador }

class AureIcon extends StatelessWidget {
  const AureIcon(this.icono, {super.key, this.size = 24, this.color = AureColors.dorado, this.relleno = false});

  final AureIcono icono;
  final double size;
  final Color color;

  /// Versión "encendida" (con detalle relleno).
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconoPainter(icono, color, relleno)),
    );
  }
}

class _IconoPainter extends CustomPainter {
  _IconoPainter(this.icono, this.color, this.relleno);

  final AureIcono icono;
  final Color color;
  final bool relleno;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final f = Paint()..color = color;
    switch (icono) {
      case AureIcono.casa:
        canvas.drawPath(Path()..moveTo(4, 11)..lineTo(12, 4)..lineTo(20, 11)..lineTo(20, 20)..lineTo(4, 20)..close(), p);
        canvas.drawPath(Path()..moveTo(9, 11)..lineTo(12, 13.5)..lineTo(15, 11), p);
        if (relleno) canvas.drawPath(Path()..moveTo(11.3, 13.8)..lineTo(10.7, 17.5)..lineTo(12, 19)..lineTo(13.3, 17.5)..lineTo(12.7, 13.8)..close(), f);
      case AureIcono.habitaciones:
        final r = RRect.fromRectAndRadius(const Rect.fromLTWH(4, 4, 7, 7), const Radius.circular(2));
        canvas.drawRRect(r, relleno ? f : p);
        canvas.drawRRect(r.shift(const Offset(9, 0)), p);
        canvas.drawRRect(r.shift(const Offset(0, 9)), p);
        canvas.drawRRect(r.shift(const Offset(9, 9)), p);
      case AureIcono.escenas:
        canvas.drawPath(Path()..moveTo(4, 19)..lineTo(20, 19), p);
        canvas.drawPath(Path()..moveTo(6, 19)..lineTo(6, 12)..lineTo(12, 8)..lineTo(18, 12)..lineTo(18, 19), p);
        final estrella = Path()
          ..moveTo(18, 2.5)..lineTo(19, 4.7)..lineTo(21.3, 5.6)..lineTo(19, 6.6)..lineTo(18, 8.8)
          ..lineTo(17, 6.6)..lineTo(14.7, 5.6)..lineTo(17, 4.7)..close();
        canvas.drawPath(estrella, relleno ? f : p);
      case AureIcono.ajustes:
        for (final y in [7.0, 12.0, 17.0]) {
          canvas.drawLine(Offset(4, y), Offset(20, y), p);
        }
        canvas.drawCircle(const Offset(9, 7), 2, relleno ? f : (Paint()..color = AureColors.negro));
        canvas.drawCircle(const Offset(9, 7), 2, p);
        canvas.drawCircle(const Offset(15, 12), 2, Paint()..color = AureColors.negro);
        canvas.drawCircle(const Offset(15, 12), 2, p);
        canvas.drawCircle(const Offset(7, 17), 2, Paint()..color = AureColors.negro);
        canvas.drawCircle(const Offset(7, 17), 2, p);
      case AureIcono.luz:
        canvas.drawPath(Path()..moveTo(9, 15)..cubicTo(6, 13, 6, 5, 12, 4.5)..cubicTo(18, 5, 18, 13, 15, 15)..close(), relleno ? f : p);
        canvas.drawLine(const Offset(9.5, 18), const Offset(14.5, 18), p);
        canvas.drawLine(const Offset(10.5, 20.5), const Offset(13.5, 20.5), p);
      case AureIcono.persiana:
        canvas.drawRect(const Rect.fromLTWH(4, 4, 16, 16), p);
        for (final y in [8.0, 12.0]) {
          canvas.drawLine(Offset(4, y), Offset(20, y), p);
        }
        if (relleno) canvas.drawRect(const Rect.fromLTWH(4, 4, 16, 4), f);
      case AureIcono.clima:
        canvas.drawPath(Path()..addArc(const Rect.fromLTWH(4, 4, 16, 16), 2.4, 4.6), p);
        canvas.drawCircle(const Offset(12, 12), relleno ? 3 : 2, f);
        canvas.drawLine(const Offset(12, 12), const Offset(16, 8), p);
      case AureIcono.musica:
        canvas.drawPath(Path()..moveTo(9, 17)..lineTo(9, 5)..lineTo(19, 3.5)..lineTo(19, 15), p);
        canvas.drawCircle(const Offset(7, 17), 2.3, relleno ? f : p);
        canvas.drawCircle(const Offset(17, 15), 2.3, relleno ? f : p);
      case AureIcono.enchufe:
        canvas.drawCircle(const Offset(12, 12), 8, p);
        canvas.drawCircle(const Offset(9.2, 12), 1.2, f);
        canvas.drawCircle(const Offset(14.8, 12), 1.2, f);
        if (relleno) canvas.drawCircle(const Offset(12, 12), 3, f);
      case AureIcono.ventilador:
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(12, 12);
          canvas.rotate(i * 2.094);
          canvas.drawPath(Path()..moveTo(0, 0)..cubicTo(1, -3, 5, -5, 6, -2)..cubicTo(6, 0, 3, 1, 0, 0), relleno ? f : p);
          canvas.restore();
        }
        canvas.drawCircle(const Offset(12, 12), 1.4, f);
    }
  }

  @override
  bool shouldRepaint(covariant _IconoPainter old) => old.icono != icono || old.color != color || old.relleno != relleno;
}
