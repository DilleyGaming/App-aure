import 'package:flutter/material.dart';

import '../theme.dart';

/// Siluetas que brillan en dorado mientras la casa conecta.
class Brillo extends StatefulWidget {
  const Brillo({super.key, required this.child});

  final Widget child;

  @override
  State<Brillo> createState() => _BrilloState();
}

class _BrilloState extends State<Brillo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final x = -1.5 + 3 * _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: [
              AureColors.panel,
              AureColors.dorado.withValues(alpha: 0.18),
              AureColors.panel,
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Tarjetas vacías con forma de contenido.
class Siluetas extends StatelessWidget {
  const Siluetas({super.key, this.cantidad = 4, this.alto = 120});

  final int cantidad;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return Brillo(
      child: Column(
        children: [
          for (var i = 0; i < cantidad; i++)
            Container(
              height: alto,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AureColors.panel, borderRadius: BorderRadius.circular(22)),
            ),
        ],
      ),
    );
  }
}
