import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../utils.dart';

/// Icono fino para el estado del tiempo de Home Assistant.
IconData iconoTiempo(String estado) => switch (estado) {
      'sunny' => Icons.wb_sunny_outlined,
      'clear-night' => Icons.nightlight_outlined,
      'partlycloudy' => Icons.wb_cloudy_outlined,
      'cloudy' => Icons.cloud_outlined,
      'rainy' || 'pouring' => Icons.water_drop_outlined,
      'lightning' || 'lightning-rainy' => Icons.flash_on_outlined,
      'snowy' || 'snowy-rainy' || 'hail' => Icons.ac_unit,
      'fog' => Icons.blur_on,
      'windy' || 'windy-variant' => Icons.air,
      _ => Icons.wb_cloudy_outlined,
    };

/// Tiempo de fuera en pocas palabras: (icono, "14°", "Soleado") o null si la casa no tiene tiempo.
(IconData, String, String)? tiempoFuera(HaHome home) {
  final tiempo = home.tiempo;
  final temp = tiempo?.attributes['temperature'];
  if (tiempo == null || temp is! num) return null;
  final clave = 'tiempo.${tiempo.state}';
  final condicion = t(clave) == clave ? tiempo.state : t(clave);
  return (iconoTiempo(tiempo.state), '${grados(temp.toDouble()).replaceAll(RegExp(r'[,.]0$'), '')}°', condicion);
}
