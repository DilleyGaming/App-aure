import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils.dart';
import 'analog_clock.dart';

/// Reposo: alterna con suavidad entre el reloj analógico dorado y un reloj digital
/// con la misma esfera, para que el cambio parezca la misma pieza transformándose.
class PresenceCycle extends StatefulWidget {
  const PresenceCycle({super.key, this.tamano = 320});

  /// Diámetro de la esfera.
  final double tamano;

  /// Alto total que ocupa (esfera y fecha), para que quien lo coloca sepa cuánto sitio dejar.
  static double altoPara(double tamano) => tamano * 1.16;

  @override
  State<PresenceCycle> createState() => _PresenceCycleState();
}

class _PresenceCycleState extends State<PresenceCycle> {
  Timer? _timer;
  bool _analogico = true;

  @override
  void initState() {
    super.initState();
    _programar();
  }

  void _programar() {
    _timer = Timer(Duration(seconds: _analogico ? 16 : 12), () {
      if (!mounted) return;
      setState(() => _analogico = !_analogico);
      _programar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.tamano;
    return SizedBox(
      width: d,
      height: PresenceCycle.altoPara(d),
      child: Column(
        children: [
          SizedBox.square(
            dimension: d,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animacion) => FadeTransition(
                opacity: animacion,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(animacion),
                  child: child,
                ),
              ),
              child: _analogico
                  ? AnalogClock(key: const ValueKey('analogico'), size: d)
                  : RelojDigital(key: const ValueKey('digital'), size: d),
            ),
          ),
          SizedBox(height: d * 0.06),
          // La fecha se queda fija debajo: solo cambia la esfera.
          _Fecha(estilo: sans(d * 0.05, color: AureColors.gris, spacing: d * 0.004)),
        ],
      ),
    );
  }
}

class _Fecha extends StatefulWidget {
  const _Fecha({required this.estilo});

  final TextStyle estilo;

  @override
  State<_Fecha> createState() => _FechaState();
}

class _FechaState extends State<_Fecha> {
  late Timer _timer;
  DateTime _hoy = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final ahora = DateTime.now();
      if (ahora.day != _hoy.day) setState(() => _hoy = ahora);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(fechaLarga(_hoy), style: widget.estilo, maxLines: 1, overflow: TextOverflow.fade, softWrap: false);
}

/// Reloj digital de Auré: la misma esfera y bisel dorados del analógico,
/// la hora en grande y los segundos recorriendo el borde como un arco de luz.
class RelojDigital extends StatefulWidget {
  const RelojDigital({super.key, this.size = 320});

  final double size;

  @override
  State<RelojDigital> createState() => _RelojDigitalState();
}

class _RelojDigitalState extends State<RelojDigital> with SingleTickerProviderStateMixin {
  late final AnimationController _ritmo =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ritmo.addListener(() {
      final ahora = DateTime.now();
      if (ahora.second != _ahora.second) setState(() => _ahora = ahora);
    });
  }

  @override
  void dispose() {
    _ritmo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    final sinMovimiento = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final hh = _ahora.hour.toString().padLeft(2, '0');
    final mm = _ahora.minute.toString().padLeft(2, '0');
    final cifras = serif(d * 0.25, weight: FontWeight.w400, height: 1, color: AureColors.doradoClaro)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Semantics(
      label: '$hh:$mm',
      child: SizedBox.square(
        dimension: d,
        child: AnimatedBuilder(
          animation: _ritmo,
          builder: (context, _) {
            final segundos = _ahora.second + (sinMovimiento ? 0.0 : _ritmo.value);
            final respira = sinMovimiento ? 0.5 : 0.5 + 0.5 * math.sin(segundos * math.pi);
            return CustomPaint(
              painter: _EsferaDigital(segundos: segundos, respira: respira),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  aureLogo(size: d * 0.11),
                  SizedBox(height: d * 0.05),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AureColors.doradoClaro, AureColors.dorado, Color(0xFFB8975E)],
                    ).createShader(r),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(hh, style: cifras),
                        // Los dos puntos laten despacio, como una respiración.
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: d * 0.015),
                          child: Opacity(
                            opacity: 0.35 + 0.65 * respira,
                            child: Text(':', style: cifras.copyWith(fontSize: d * 0.2)),
                          ),
                        ),
                        Text(mm, style: cifras),
                      ],
                    ),
                  ),
                  SizedBox(height: d * 0.045),
                  Container(
                    width: d * 0.3,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AureColors.dorado.withValues(alpha: 0),
                          AureColors.dorado.withValues(alpha: 0.8),
                          AureColors.dorado.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: d * 0.045),
                  Text(
                    'AURÉ',
                    style: marca(d * 0.045, color: AureColors.dorado, spacing: d * 0.022),
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

class _EsferaDigital extends CustomPainter {
  _EsferaDigital({required this.segundos, required this.respira});

  final double segundos;
  final double respira;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Mismo brillo, esfera y bisel que el reloj analógico.
    canvas.drawCircle(
      c,
      r * 0.98,
      Paint()
        ..color = AureColors.dorado.withValues(alpha: 0.04 + 0.05 * respira)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
    );
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF17161B), Color(0xFF0B0B0D)])
            .createShader(Rect.fromCircle(center: c, radius: r * 0.94)),
    );
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
        ..color = AureColors.dorado.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.005,
    );

    // Marcas de los 60 segundos: se iluminan las que ya han pasado.
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final pasada = i <= segundos.floor();
      final grande = i % 5 == 0;
      final p = Paint()
        ..color = AureColors.dorado.withValues(alpha: pasada ? (grande ? 0.95 : 0.6) : 0.16)
        ..strokeWidth = r * (grande ? 0.012 : 0.006)
        ..strokeCap = StrokeCap.round;
      final dentro = r * (grande ? 0.80 : 0.82);
      canvas.drawLine(_punto(c, r * 0.85, a), _punto(c, dentro, a), p);
    }

    // Arco de luz de los segundos, con una perla en la punta.
    final angulo = segundos / 60 * 2 * math.pi;
    final rect = Rect.fromCircle(center: c, radius: r * 0.885);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      angulo,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: const GradientRotation(-math.pi / 2),
          colors: [AureColors.dorado.withValues(alpha: 0.0), AureColors.doradoClaro],
          stops: [0, math.max(0.001, segundos / 60)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.012
        ..strokeCap = StrokeCap.round,
    );
    final punta = _punto(c, r * 0.885, angulo);
    canvas.drawCircle(
      punta,
      r * 0.04,
      Paint()
        ..color = AureColors.doradoClaro.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
    canvas.drawCircle(punta, r * 0.018, Paint()..color = AureColors.doradoClaro);
  }

  Offset _punto(Offset c, double radio, double angulo) =>
      Offset(c.dx + radio * math.sin(angulo), c.dy - radio * math.cos(angulo));

  @override
  bool shouldRepaint(covariant _EsferaDigital old) => old.segundos != segundos || old.respira != respira;
}
