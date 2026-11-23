import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';
import 'common.dart';

/// Rueda dorada para la temperatura: se gira con el dedo, como un termostato de diseño.
class DialClima extends StatefulWidget {
  const DialClima({
    super.key,
    required this.valor,
    required this.alCambiar,
    this.min = 16,
    this.max = 30,
    this.actual,
    this.size = 220,
  });

  final double valor;
  final double min;
  final double max;
  final double? actual;
  final double size;
  final ValueChanged<double> alCambiar;

  @override
  State<DialClima> createState() => _DialClimaState();
}

class _DialClimaState extends State<DialClima> {
  static const _inicio = math.pi * 0.75; // abajo a la izquierda
  static const _barrido = math.pi * 1.5; // 270 grados

  double? _arrastre;

  double get _valor => _arrastre ?? widget.valor;

  void _desdePunto(Offset p) {
    final c = Offset(widget.size / 2, widget.size / 2);
    var a = math.atan2(p.dy - c.dy, p.dx - c.dx);
    var rel = a - _inicio;
    while (rel < 0) {
      rel += 2 * math.pi;
    }
    if (rel > _barrido) {
      // Fuera del arco: lo pegamos al extremo más cercano.
      rel = rel - _barrido < (2 * math.pi - rel) ? _barrido : 0.0;
    }
    final v = widget.min + (rel / _barrido) * (widget.max - widget.min);
    final redondeado = (v * 2).round() / 2;
    if (redondeado != _arrastre) {
      Tacto.toque();
      setState(() => _arrastre = redondeado.clamp(widget.min, widget.max).toDouble());
    }
  }

  void _soltar() {
    final v = _arrastre;
    if (v != null) widget.alCambiar(v);
    setState(() => _arrastre = null);
  }

  @override
  Widget build(BuildContext context) {
    final fraccion = ((_valor - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return Semantics(
      label: 'Temperatura',
      value: '${grados(_valor)} grados',
      increasedValue: '${grados(_valor + 0.5)} grados',
      decreasedValue: '${grados(_valor - 0.5)} grados',
      onIncrease: () => widget.alCambiar((_valor + 0.5).clamp(widget.min, widget.max).toDouble()),
      onDecrease: () => widget.alCambiar((_valor - 0.5).clamp(widget.min, widget.max).toDouble()),
      child: GestureDetector(
        onPanStart: (d) => _desdePunto(d.localPosition),
        onPanUpdate: (d) => _desdePunto(d.localPosition),
        onPanEnd: (_) => _soltar(),
        onTapUp: (d) {
          _desdePunto(d.localPosition);
          _soltar();
        },
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _DialPainter(fraccion),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${grados(_valor)}°', style: serif(widget.size * 0.22, color: AureColors.doradoClaro, height: 1)),
                  if (widget.actual != null) ...[
                    const SizedBox(height: 6),
                    Text('${grados(widget.actual!)}° ', style: sans(13, color: AureColors.gris)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.fraccion);

  final double fraccion;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;
    final rect = Rect.fromCircle(center: c, radius: r);
    const inicio = math.pi * 0.75;
    const barrido = math.pi * 1.5;

    // Marcas finas a lo largo del arco
    final marca = Paint()
      ..color = AureColors.dorado.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var i = 0; i <= 28; i++) {
      final a = inicio + barrido * i / 28;
      final largo = i % 4 == 0 ? 10.0 : 5.0;
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (r + 8),
        c + Offset(math.cos(a), math.sin(a)) * (r + 8 + largo),
        marca,
      );
    }
    // Pista
    canvas.drawArc(rect, inicio, barrido, false, Paint()
      ..color = AureColors.panelAlto
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
    // Valor (con un brillo suave)
    canvas.drawArc(rect, inicio, barrido * fraccion, false, Paint()
      ..color = AureColors.dorado.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawArc(rect, inicio, barrido * fraccion, false, Paint()
      ..shader = const SweepGradient(
        colors: [AureColors.dorado, AureColors.doradoClaro],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
    // Tirador
    final a = inicio + barrido * fraccion;
    final punto = c + Offset(math.cos(a), math.sin(a)) * r;
    canvas.drawCircle(punto, 11, Paint()..color = AureColors.doradoClaro);
    canvas.drawCircle(punto, 4, Paint()..color = AureColors.negro);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.fraccion != fraccion;
}
