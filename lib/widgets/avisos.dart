import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Píldora dorada que baja desde arriba: "Modo cena activado".
class Avisos {
  Avisos._();

  static OverlayEntry? _actual;
  static Timer? _timer;

  static void mostrar(BuildContext context, String texto, {IconData icono = Icons.check}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _timer?.cancel();
    _actual?.remove();
    final clave = GlobalKey<_PildoraState>();
    final entrada = OverlayEntry(builder: (_) => _Pildora(key: clave, texto: texto, icono: icono));
    _actual = entrada;
    overlay.insert(entrada);
    _timer = Timer(const Duration(milliseconds: 2600), () async {
      await clave.currentState?.salir();
      if (_actual == entrada) {
        entrada.remove();
        _actual = null;
      }
    });
  }
}

class _Pildora extends StatefulWidget {
  const _Pildora({super.key, required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  State<_Pildora> createState() => _PildoraState();
}

class _PildoraState extends State<_Pildora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  Future<void> salir() async {
    if (mounted) await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 14,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _c,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(curva),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                  decoration: BoxDecoration(
                    color: AureColors.panelAlto,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: AureColors.dorado.withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AureColors.dorado),
                        child: Icon(widget.icono, size: 18, color: AureColors.negro),
                      ),
                      const SizedBox(width: 12),
                      Text(widget.texto, style: sans(14.5, weight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
