import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../theme.dart';
import 'analog_clock.dart';
import 'common.dart';

/// Alterna con suavidad entre el reloj dorado y la marca Auré.
class PresenceCycle extends StatefulWidget {
  const PresenceCycle({super.key, this.tamano = 320});

  /// Diámetro del reloj.
  final double tamano;

  @override
  State<PresenceCycle> createState() => _PresenceCycleState();
}

class _PresenceCycleState extends State<PresenceCycle> {
  Timer? _timer;
  bool _reloj = true;

  @override
  void initState() {
    super.initState();
    _programar();
  }

  // El reloj se queda más tiempo; la marca aparece unos segundos.
  void _programar() {
    _timer = Timer(Duration(seconds: _reloj ? 14 : 6), () {
      if (!mounted) return;
      setState(() => _reloj = !_reloj);
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
    final Widget contenido = _reloj
        ? Column(
            key: const ValueKey('reloj'),
            mainAxisSize: MainAxisSize.min,
            children: [
              AnalogClock(size: d),
              SizedBox(height: d * 0.08),
              Reloj(
                style: sans(d * 0.06, color: AureColors.doradoClaro, spacing: 2),
                conFecha: true,
                estiloFecha: sans(d * 0.045, color: AureColors.gris),
              ),
            ],
          )
        : Column(
            key: const ValueKey('marca'),
            mainAxisSize: MainAxisSize.min,
            children: [
              aureLogo(size: d * 0.3),
              SizedBox(height: d * 0.07),
              Text('AURÉ', style: sans(d * 0.13, spacing: d * 0.045, weight: FontWeight.w300)),
              SizedBox(height: d * 0.04),
              Text(t('app.lema'), style: serif(d * 0.06, color: AureColors.gris)),
            ],
          );

    return SizedBox(
      height: d * 1.3,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 1200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animacion) => FadeTransition(
            opacity: animacion,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animacion),
              child: child,
            ),
          ),
          child: contenido,
        ),
      ),
    );
  }
}
