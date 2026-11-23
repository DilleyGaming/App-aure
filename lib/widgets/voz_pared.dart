import 'dart:async';

import 'package:flutter/material.dart';

import '../dispositivo.dart';
import '../ha/ha_home.dart';
import '../i18n.dart';
import '../reposo.dart';
import '../theme.dart';
import 'breathing_orb.dart';

/// En las pantallas de pared: cuando alguien habla al punto de voz de esta estancia,
/// la pantalla se despierta y muestra la luz de Auré y lo que ha oído.
class VozPared extends StatefulWidget {
  const VozPared({super.key, required this.home});

  final HaHome home;

  @override
  State<VozPared> createState() => _VozParedState();
}

class _VozParedState extends State<VozPared> {
  String _estado = 'idle';
  bool _visible = false;
  bool _ocupando = false;
  Timer? _ocultar;

  @override
  void initState() {
    super.initState();
    widget.home.addListener(_revisar);
  }

  @override
  void dispose() {
    widget.home.removeListener(_revisar);
    _ocultar?.cancel();
    if (_ocupando) Reposo.i.liberar();
    super.dispose();
  }

  void _revisar() {
    final d = DispositivoStore.i;
    if (!d.esPared) return;
    final nuevo = widget.home.estadoVoz(d.area);
    if (nuevo == _estado) {
      if (_visible) setState(() {}); // por si ha llegado el texto oído
      return;
    }
    final antes = _estado;
    _estado = nuevo;
    if (nuevo != 'idle') {
      if (antes == 'idle') widget.home.fraseOida.remove(d.area);
      _ocultar?.cancel();
      Reposo.i.despertar();
      if (!_ocupando) {
        _ocupando = true;
        Reposo.i.ocupar();
      }
      setState(() => _visible = true);
    } else {
      if (_ocupando) {
        _ocupando = false;
        Reposo.i.liberar();
      }
      _ocultar = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _visible = false);
      });
      setState(() {});
    }
  }

  OrbMode get _modo => switch (_estado) {
        'listening' => OrbMode.listening,
        'processing' => OrbMode.thinking,
        'responding' => OrbMode.speaking,
        _ => OrbMode.idle,
      };

  String get _texto => switch (_estado) {
        'listening' => t('talk.escucha'),
        'processing' => t('talk.piensa'),
        'responding' => t('talk.habla'),
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final frase = widget.home.fraseOida[DispositivoStore.i.area];
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 450),
        child: GestureDetector(
          onTap: () => setState(() => _visible = false),
          child: Container(
            color: AureColors.negro.withValues(alpha: 0.96),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BreathingOrb(size: 220, mode: _modo),
                const SizedBox(height: 14),
                Text(_texto, style: sans(15, color: AureColors.gris)),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    key: ValueKey(frase),
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      frase == null ? '' : '«$frase»',
                      textAlign: TextAlign.center,
                      style: serif(30, height: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
