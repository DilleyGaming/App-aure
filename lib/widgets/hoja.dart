import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Hoja que sube desde abajo con el fondo desenfocado.
Future<T?> abrirHoja<T>(BuildContext context, {required WidgetBuilder builder, double maxAncho = 720}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: AnimatedBuilder(
                animation: curva,
                builder: (_, __) => BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14 * curva.value, sigmaY: 14 * curva.value),
                  child: Container(color: Colors.black.withValues(alpha: 0.45 * curva.value)),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curva),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxAncho,
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                ),
                child: Material(
                  color: AureColors.panel,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    side: BorderSide(color: AureColors.linea),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(top: false, child: builder(ctx)),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Asa superior de las hojas.
class AsaHoja extends StatelessWidget {
  const AsaHoja({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: AureColors.grisOscuro, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}
