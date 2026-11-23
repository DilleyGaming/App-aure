import 'dart:async';

import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../pantalla.dart';
import '../theme.dart';
import 'house_view.dart';

/// ¿Es de noche? (de 23:00 a 7:00)
bool esDeNoche([DateTime? ahora]) {
  final h = (ahora ?? DateTime.now()).hour;
  return h >= 23 || h < 7;
}

/// Fondo vivo: cambia con la hora del día y se calienta con las luces de la casa.
/// De noche, toda la app baja un poco su brillo.
class FondoVivo extends StatefulWidget {
  const FondoVivo({super.key, required this.home, required this.child});

  final HaHome home;
  final Widget child;

  @override
  State<FondoVivo> createState() => _FondoVivoState();
}

class _FondoVivoState extends State<FondoVivo> {
  late Timer _timer;
  DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() => _ahora = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Color del "cielo" según la hora.
  Color _cielo() {
    final h = _ahora.hour + _ahora.minute / 60;
    if (h >= 6 && h < 9) return const Color(0xFF2A1F22); // amanecer
    if (h >= 9 && h < 18) return const Color(0xFF1F1D24); // día
    if (h >= 18 && h < 21) return const Color(0xFF261C1E); // atardecer
    return const Color(0xFF15141B); // noche
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.home, PantallaStore.i]),
      builder: (context, _) {
        // Cuánta luz cálida hay encendida en casa.
        final casa = estadoCasa(widget.home);
        var suma = 0.0;
        var n = 0;
        Color? tono;
        casa.niveles.forEach((zona, nivel) {
          if (nivel > 0.05) {
            suma += nivel;
            n++;
            tono ??= casa.colores[zona];
          }
        });
        final calidez = n == 0 ? 0.0 : (suma / casa.niveles.length).clamp(0.0, 1.0);
        final brillo = Color.lerp(_cielo(), tono ?? AureColors.calido, 0.10 + 0.25 * calidez)!;
        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(seconds: 2),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.1),
                    radius: 1.3,
                    colors: [brillo, AureColors.negro],
                    stops: const [0, 0.7],
                  ),
                ),
              ),
            ),
            widget.child,
            if (PantallaStore.i.atenuarAhora(_ahora))
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: Colors.black.withValues(alpha: 1 - PantallaStore.i.brilloNoche)),
                ),
              ),
          ],
        );
      },
    );
  }
}
