import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../utils.dart';

/// Vibraciones distintas según la acción.
class Tacto {
  Tacto._();

  /// Tocar algo normal.
  static void toque() => HapticFeedback.selectionClick();

  /// Encender o apagar.
  static void encender() => HapticFeedback.lightImpact();

  /// Confirmar algo importante (una escena, un pedido).
  static void confirmar() => HapticFeedback.mediumImpact();

  /// Un aviso que requiere atención: doble pulso.
  static Future<void> aviso() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
  }
}

/// Cualquier elemento que se "hunde" un poco al tocarlo.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.label});

  final Widget child;
  final VoidCallback? onTap;
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pulsado = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pulsado = true),
          onTapUp: (_) => setState(() => _pulsado = false),
          onTapCancel: () => setState(() => _pulsado = false),
          onTap: widget.onTap == null
              ? null
              : () {
                  Tacto.toque();
                  widget.onTap!();
                },
          child: AnimatedScale(
            scale: _pulsado ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Interruptor dorado de Auré.
class AureToggle extends StatelessWidget {
  const AureToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const duracion = Duration(milliseconds: 260);
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () {
          Tacto.encender();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedContainer(
            duration: duracion,
            curve: Curves.easeOutCubic,
            width: 54,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: value ? AureColors.dorado : AureColors.panelAlto,
              border: Border.all(color: value ? AureColors.dorado : AureColors.linea),
            ),
            child: AnimatedAlign(
              duration: duracion,
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? AureColors.negro : AureColors.gris,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reloj que se actualiza solo.
class Reloj extends StatefulWidget {
  const Reloj({super.key, required this.style, this.conFecha = false, this.estiloFecha});

  final TextStyle style;
  final bool conFecha;
  final TextStyle? estiloFecha;

  @override
  State<Reloj> createState() => _RelojState();
}

class _RelojState extends State<Reloj> {
  late Timer _timer;
  DateTime _ahora = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ahora = DateTime.now();
      if (ahora.minute != _ahora.minute) setState(() => _ahora = ahora);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(hora(_ahora), style: widget.style),
        if (widget.conFecha)
          Text(fechaLarga(_ahora), style: widget.estiloFecha ?? sans(16, color: AureColors.gris)),
      ],
    );
  }
}

/// Título de sección con su subtítulo.
class Encabezado extends StatelessWidget {
  const Encabezado(this.titulo, {super.key, this.subtitulo, this.accion});

  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: serif(30)),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(subtitulo!, style: sans(14, color: AureColors.gris)),
              ],
            ],
          ),
        ),
        if (accion != null) accion!,
      ],
    );
  }
}
