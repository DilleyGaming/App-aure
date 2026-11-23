import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../ha/ha_home.dart';
import '../theme.dart';

/// Palabras para saber qué luz corresponde a cada ventana del dibujo.
const _zonas = <String, List<String>>{
  'salon': ['salon', 'salón', 'living', 'lounge'],
  'comedor': ['comedor', 'dining', 'ceiling'],
  'cocina': ['cocina', 'kitchen'],
  'dorm': ['dormitorio', 'bed', 'habitacion', 'habitación', 'suite'],
  'estudio': ['estudio', 'office', 'despacho'],
  'porche': ['porche', 'entrance', 'entrada', 'jardin', 'jardín', 'garden', 'porch', 'exterior'],
  'garaje': ['garaje', 'garage'],
};

/// Calcula cuánto brilla cada ventana y de qué color, según las luces reales.
({Map<String, double> niveles, Map<String, Color> colores}) estadoCasa(HaHome home) {
  final niveles = <String, double>{for (final z in _zonas.keys) z: 0};
  final colores = <String, Color>{};
  for (final luz in home.lights) {
    final texto = '${luz.id} ${luz.name} ${home.areaName(home.areaOf(luz.id)) ?? ''}'.toLowerCase();
    for (final zona in _zonas.entries) {
      if (zona.value.any(texto.contains)) {
        final b = luz.brightness;
        if (b >= niveles[zona.key]!) {
          niveles[zona.key] = b;
          final c = luz.rgb;
          colores[zona.key] = c == null ? AureColors.calido : Color.lerp(AureColors.calido, c, 0.7)!;
        }
        break;
      }
    }
  }
  return (niveles: niveles, colores: colores);
}

/// El chalet de noche. Las ventanas se encienden suavemente con las luces.
class HouseView extends StatefulWidget {
  const HouseView({super.key, required this.niveles, required this.colores});

  final Map<String, double> niveles;
  final Map<String, Color> colores;

  @override
  State<HouseView> createState() => _HouseViewState();
}

class _HouseViewState extends State<HouseView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Map<String, double> _actual = {};
  final Map<String, Color> _color = {};
  double _t = 0;
  Duration _ultimo = Duration.zero;

  @override
  void initState() {
    super.initState();
    _actual.addAll(widget.niveles);
    _color.addAll(widget.colores);
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration ahora) {
    final dt = (ahora - _ultimo).inMicroseconds / 1e6;
    _ultimo = ahora;
    final k = math.min(1.0, dt * 3.5);
    setState(() {
      _t += dt;
      widget.niveles.forEach((zona, objetivo) {
        final actual = _actual[zona] ?? 0;
        _actual[zona] = actual + (objetivo - actual) * k;
      });
      widget.colores.forEach((zona, objetivo) {
        _color[zona] = Color.lerp(_color[zona] ?? objetivo, objetivo, k)!;
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Dibujo de la casa con las luces encendidas',
      child: AspectRatio(
        aspectRatio: 1100 / 430,
        child: CustomPaint(painter: _CasaPainter(Map.of(_actual), Map.of(_color), _t)),
      ),
    );
  }
}

class _CasaPainter extends CustomPainter {
  _CasaPainter(this.niveles, this.colores, this.t);

  final Map<String, double> niveles;
  final Map<String, Color> colores;
  final double t;

  Paint _trazo(double alfa, double grosor) => Paint()
    ..color = AureColors.dorado.withValues(alpha: alfa)
    ..style = PaintingStyle.stroke
    ..strokeWidth = grosor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1100);

    // Estrellas que titilan
    const estrellas = [
      Offset(140, 60), Offset(260, 34), Offset(610, 48),
      Offset(760, 26), Offset(900, 74), Offset(440, 70),
    ];
    for (var i = 0; i < estrellas.length; i++) {
      final a = 0.2 + 0.3 * (0.5 + 0.5 * math.sin(t * 1.3 + i * 1.7));
      canvas.drawCircle(estrellas[i], 1.4, Paint()..color = AureColors.crema.withValues(alpha: a));
    }

    // Luna y olivo
    canvas.drawCircle(const Offset(1010, 58), 17, _trazo(0.55, 1.2));
    final arbol = _trazo(0.4, 1.2);
    canvas.drawLine(const Offset(88, 360), const Offset(88, 298), arbol);
    canvas.drawCircle(const Offset(72, 282), 24, arbol);
    canvas.drawCircle(const Offset(102, 268), 28, arbol);
    canvas.drawCircle(const Offset(92, 300), 18, arbol);

    // Luz del porche
    final p = niveles['porche'] ?? 0;
    final colorPorche = colores['porche'] ?? AureColors.calido;
    final cono = Path()
      ..moveTo(820, 236)
      ..lineTo(840, 236)
      ..lineTo(884, 358)
      ..lineTo(776, 358)
      ..close();
    canvas.drawPath(cono, Paint()..color = colorPorche.withValues(alpha: 0.16 * p));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(830, 361), width: 140, height: 12),
      Paint()..color = colorPorche.withValues(alpha: 0.4 * p),
    );

    // Volúmenes de la casa
    final cuerpo = Paint()..color = const Color(0xFF121115);
    final borde = _trazo(0.7, 1.4);
    for (final r in const [
      Rect.fromLTWH(150, 220, 610, 140),
      Rect.fromLTWH(330, 110, 570, 110),
      Rect.fromLTWH(910, 250, 110, 110),
    ]) {
      canvas.drawRect(r, cuerpo);
      canvas.drawRect(r, borde);
    }
    final losa = Paint()
      ..color = AureColors.dorado
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(138, 220), const Offset(772, 220), losa);
    canvas.drawLine(const Offset(318, 110), const Offset(912, 110), losa);
    canvas.drawLine(const Offset(902, 250), const Offset(1028, 250), losa);
    canvas.drawLine(const Offset(895, 220), const Offset(895, 360), borde);

    // Ventanas
    _ventana(canvas, 'salon', const Rect.fromLTWH(180, 244, 250, 106), const [242, 305, 367]);
    _ventana(canvas, 'comedor', const Rect.fromLTWH(460, 244, 130, 106), const [525]);
    _ventana(canvas, 'cocina', const Rect.fromLTWH(620, 262, 110, 64), const [675]);
    _ventana(canvas, 'dorm', const Rect.fromLTWH(360, 136, 210, 60), const [465]);
    _ventana(canvas, 'estudio', const Rect.fromLTWH(600, 136, 150, 60), const [675]);
    _ventana(canvas, 'garaje', const Rect.fromLTWH(928, 282, 74, 78), const [], lamas: true);

    // Puerta y farol
    const puerta = Rect.fromLTWH(782, 268, 34, 92);
    canvas.drawRect(puerta, Paint()..color = const Color(0xFF17161B));
    canvas.drawRect(puerta, _trazo(0.55, 1));
    canvas.drawCircle(
      const Offset(830, 232),
      4.5,
      Paint()..color = AureColors.doradoClaro.withValues(alpha: p > 0.05 ? 1 : 0.15),
    );

    // Suelo, piscina y su reflejo
    canvas.drawLine(const Offset(20, 360), const Offset(1080, 360), _trazo(0.5, 1.2));
    const piscina = Rect.fromLTWH(150, 376, 460, 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(piscina, const Radius.circular(2)),
      Paint()..color = const Color(0xFF101014),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(piscina, const Radius.circular(2)), _trazo(0.35, 1));
    _reflejo(canvas, 'salon', const Rect.fromLTWH(180, 380, 250, 22));
    _reflejo(canvas, 'comedor', const Rect.fromLTWH(460, 380, 130, 22));

    // Agua en movimiento
    final agua = Paint()
      ..color = AureColors.negro
      ..strokeWidth = 2;
    final desplazamiento = (t * 10) % 28;
    for (double x = 142 + desplazamiento; x < 590; x += 28) {
      final a = math.max(170.0, x);
      final b = math.min(590.0, x + 18);
      if (b > a) canvas.drawLine(Offset(a, 391), Offset(b, 391), agua);
    }

    canvas.restore();
  }

  void _ventana(Canvas canvas, String zona, Rect r, List<double> montantes, {bool lamas = false}) {
    final n = (niveles[zona] ?? 0) * (lamas ? 0.6 : 1);
    final color = colores[zona] ?? AureColors.calido;
    if (n > 0.01) {
      canvas.drawRect(
        r.inflate(10),
        Paint()
          ..color = color.withValues(alpha: 0.28 * n)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    canvas.drawRect(r, Paint()..color = const Color(0xFF17161B));
    if (n > 0.01) canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.9 * n));
    canvas.drawRect(r, _trazo(0.55, 1));
    final marco = Paint()
      ..color = const Color(0xFF121115)
      ..strokeWidth = 2;
    for (final x in montantes) {
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), marco);
    }
    if (lamas) {
      for (var y = r.top + 19; y < r.bottom; y += 19) {
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), marco);
      }
    }
  }

  void _reflejo(Canvas canvas, String zona, Rect r) {
    final n = niveles[zona] ?? 0;
    if (n <= 0.01) return;
    final color = colores[zona] ?? AureColors.calido;
    canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.3 * n));
  }

  @override
  bool shouldRepaint(covariant _CasaPainter old) => true;
}
