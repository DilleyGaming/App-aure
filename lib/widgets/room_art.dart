import 'package:flutter/material.dart';

import '../theme.dart';

/// Ilustración de línea fina dorada para cada tipo de habitación.
enum TipoEstancia { salon, cocina, dormitorio, bano, despacho, exterior, otros }

TipoEstancia tipoEstancia(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('sal') || n.contains('living') || n.contains('صال')) return TipoEstancia.salon;
  if (n.contains('coc') || n.contains('kitch') || n.contains('مطبخ')) return TipoEstancia.cocina;
  if (n.contains('dorm') || n.contains('bed') || n.contains('habit') || n.contains('نوم')) return TipoEstancia.dormitorio;
  if (n.contains('baño') || n.contains('bano') || n.contains('bath') || n.contains('حمام')) return TipoEstancia.bano;
  if (n.contains('desp') || n.contains('estud') || n.contains('ofic') || n.contains('office')) return TipoEstancia.despacho;
  if (n.contains('jard') || n.contains('porch') || n.contains('terra') || n.contains('piscina') || n.contains('garden')) {
    return TipoEstancia.exterior;
  }
  return TipoEstancia.otros;
}

class IlustracionEstancia extends StatelessWidget {
  const IlustracionEstancia(this.tipo, {super.key, this.encendida = false, this.alto = 64});

  final TipoEstancia tipo;
  final bool encendida;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      width: alto * 1.6,
      child: CustomPaint(painter: _EstanciaPainter(tipo, encendida)),
    );
  }
}

class _EstanciaPainter extends CustomPainter {
  _EstanciaPainter(this.tipo, this.encendida);

  final TipoEstancia tipo;
  final bool encendida;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 80, size.height / 50);
    final color = encendida ? AureColors.dorado : AureColors.grisOscuro;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Suelo
    canvas.drawLine(const Offset(2, 46), const Offset(78, 46), p);
    // Luz de techo que brilla si la estancia está encendida
    if (encendida) {
      canvas.drawCircle(
        const Offset(40, 8),
        12,
        Paint()
          ..color = AureColors.dorado.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawLine(const Offset(40, 0), const Offset(40, 5), p);
    canvas.drawPath(Path()..moveTo(35, 9)..quadraticBezierTo(40, 3, 45, 9)..close(), encendida ? (Paint()..color = AureColors.dorado) : p);

    switch (tipo) {
      case TipoEstancia.salon:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 30, 40, 10), const Radius.circular(3)), p);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 24, 40, 8), const Radius.circular(3)), p);
        canvas.drawLine(const Offset(17, 40), const Offset(17, 46), p);
        canvas.drawLine(const Offset(51, 40), const Offset(51, 46), p);
        canvas.drawCircle(const Offset(66, 26), 4, p);
        canvas.drawLine(const Offset(66, 30), const Offset(66, 46), p);
      case TipoEstancia.cocina:
        canvas.drawRect(const Rect.fromLTWH(10, 30, 60, 16), p);
        canvas.drawLine(const Offset(30, 30), const Offset(30, 46), p);
        canvas.drawLine(const Offset(50, 30), const Offset(50, 46), p);
        canvas.drawRect(const Rect.fromLTWH(14, 16, 18, 8), p);
        canvas.drawRect(const Rect.fromLTWH(48, 16, 18, 8), p);
      case TipoEstancia.dormitorio:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 32, 56, 8), const Radius.circular(2)), p);
        canvas.drawLine(const Offset(12, 24), const Offset(12, 46), p);
        canvas.drawLine(const Offset(68, 32), const Offset(68, 46), p);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(15, 27, 12, 5), const Radius.circular(2)), p);
      case TipoEstancia.bano:
        canvas.drawPath(Path()..moveTo(12, 32)..lineTo(68, 32)..lineTo(64, 42)..quadraticBezierTo(40, 46, 16, 42)..close(), p);
        canvas.drawLine(const Offset(58, 32), const Offset(58, 20), p);
        canvas.drawLine(const Offset(58, 20), const Offset(52, 20), p);
      case TipoEstancia.despacho:
        canvas.drawLine(const Offset(14, 30), const Offset(66, 30), p);
        canvas.drawLine(const Offset(18, 30), const Offset(18, 46), p);
        canvas.drawLine(const Offset(62, 30), const Offset(62, 46), p);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 16, 20, 13), const Radius.circular(2)), p);
      case TipoEstancia.exterior:
        canvas.drawCircle(const Offset(22, 26), 8, p);
        canvas.drawCircle(const Offset(30, 22), 9, p);
        canvas.drawLine(const Offset(26, 32), const Offset(26, 46), p);
        canvas.drawRect(const Rect.fromLTWH(42, 38, 32, 6), p);
      case TipoEstancia.otros:
        canvas.drawRect(const Rect.fromLTWH(20, 22, 40, 24), p);
        canvas.drawLine(const Offset(40, 22), const Offset(40, 46), p);
    }
  }

  @override
  bool shouldRepaint(covariant _EstanciaPainter old) => old.tipo != tipo || old.encendida != encendida;
}
