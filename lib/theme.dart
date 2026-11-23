import 'dart:ui' show FontVariation;

import 'package:flutter/material.dart';

/// Colores de la marca Auré.
class AureColors {
  AureColors._();

  static const negro = Color(0xFF0E0E10);
  static const panel = Color(0xFF16151A);
  static const panelAlto = Color(0xFF1E1D23);
  static const linea = Color(0x2ED4B57A);
  static const dorado = Color(0xFFD4B57A);
  static const doradoClaro = Color(0xFFF1DDB2);
  static const crema = Color(0xFFF4EEE3);
  static const gris = Color(0xFFB8AE9C);
  static const grisOscuro = Color(0xFF7D7568);
  static const calido = Color(0xFFE9C989);
}

const _pesos = [
  FontWeight.w100, FontWeight.w200, FontWeight.w300, FontWeight.w400, FontWeight.w500,
  FontWeight.w600, FontWeight.w700, FontWeight.w800, FontWeight.w900,
];

/// Grosor numérico (100-900) para las fuentes variables.
double _peso(FontWeight w) {
  final i = _pesos.indexOf(w);
  return (i < 0 ? 4 : i + 1) * 100.0;
}

/// Bodoni Moda (incluida en la app). El tamaño óptico se ajusta para que los
/// trazos finos no desaparezcan en tamaños medianos y pequeños.
TextStyle serif(
  double size, {
  Color color = AureColors.crema,
  FontWeight weight = FontWeight.w500,
  double height = 1.18,
}) {
  final optico = (size * 0.55).clamp(10.0, 40.0);
  return TextStyle(
    fontFamily: 'BodoniModa',
    fontFamilyFallback: const ['Georgia', 'Times New Roman', 'Noto Serif'],
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    fontVariations: [FontVariation('wght', _peso(weight)), FontVariation('opsz', optico)],
  );
}

/// Manrope (incluida en la app) para textos.
TextStyle sans(
  double size, {
  Color color = AureColors.crema,
  FontWeight weight = FontWeight.w400,
  double spacing = 0,
}) {
  return TextStyle(
    fontFamily: 'Manrope',
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: spacing,
    fontVariations: [FontVariation('wght', _peso(weight))],
  );
}

/// La palabra AURÉ con su letra de marca (Jost fina).
TextStyle marca(double size, {Color color = AureColors.crema, double spacing = 8}) {
  return TextStyle(
    fontFamily: 'Jost',
    fontSize: size,
    color: color,
    letterSpacing: spacing,
    fontWeight: FontWeight.w300,
    fontVariations: const [FontVariation('wght', 300)],
  );
}

ThemeData aureTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, fontFamily: 'Manrope');
  return base.copyWith(
    scaffoldBackgroundColor: AureColors.negro,
    colorScheme: const ColorScheme.dark(
      primary: AureColors.dorado,
      onPrimary: AureColors.negro,
      secondary: AureColors.dorado,
      surface: AureColors.panel,
      onSurface: AureColors.crema,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AureColors.crema,
      displayColor: AureColors.crema,
      fontFamily: 'Manrope',
    ),
    splashFactory: InkRipple.splashFactory,
    sliderTheme: const SliderThemeData(
      activeTrackColor: AureColors.dorado,
      inactiveTrackColor: Color(0x33D4B57A),
      thumbColor: AureColors.doradoClaro,
      overlayColor: Color(0x22D4B57A),
      trackHeight: 3,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AureColors.dorado,
      selectionColor: Color(0x55D4B57A),
      selectionHandleColor: AureColors.dorado,
    ),
  );
}

/// Tarjeta oscura con borde fino; si está activa, brilla en dorado.
BoxDecoration aureCard({bool active = false, double radius = 20}) {
  return BoxDecoration(
    color: AureColors.panel,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: active ? AureColors.dorado.withValues(alpha: 0.65) : AureColors.linea,
    ),
    boxShadow: active
        ? [BoxShadow(color: AureColors.dorado.withValues(alpha: 0.12), blurRadius: 28)]
        : const [],
  );
}

/// El símbolo de Auré (casa mayordomo) desde los archivos del logo.
Widget aureLogo({double size = 40, bool dark = false}) {
  return Image.asset(
    dark ? 'assets/logo/aure_simbolo_negro_1024.png' : 'assets/logo/aure_simbolo_dorado_1024.png',
    width: size,
    height: size,
    errorBuilder: (context, error, stack) => SizedBox(width: size, height: size),
  );
}
