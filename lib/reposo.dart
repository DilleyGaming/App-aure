import 'dart:async';

import 'package:flutter/material.dart';

import 'dispositivo.dart';
import 'ha/ha_home.dart';

/// Controla el modo reposo de toda la app.
/// Tras unos segundos sin tocar nada, la app vuelve a su pantalla de reposo.
class Reposo extends ChangeNotifier {
  Reposo._();

  static final Reposo i = Reposo._();
  static const espera = Duration(seconds: 20);

  final navigatorKey = GlobalKey<NavigatorState>();

  HaHome? home;
  bool activo = false;
  int _ocupado = 0;
  Timer? _temporizador;

  /// Cualquier toque en la pantalla.
  void actividad() {
    if (activo) {
      activo = false;
      notifyListeners();
    }
    _programar();
  }

  void _programar() {
    _temporizador?.cancel();
    // Solo las pantallas de pared (y las tablets que lo tengan activado) entran en reposo.
    if (!DispositivoStore.i.usaReposo) return;
    _temporizador = Timer(espera, _entrar);
  }

  /// Despertar desde fuera (por ejemplo, porque alguien habla en la estancia).
  void despertar() => actividad();

  void _entrar() {
    if (home == null || _ocupado > 0 || _escribiendo) {
      _programar();
      return;
    }
    // Cerramos lo que esté abierto para que, al despertar, Auré esté lista.
    navigatorKey.currentState?.popUntil((ruta) => ruta.isFirst);
    activo = true;
    notifyListeners();
  }

  /// Muestra el reposo ahora mismo (desde Ajustes).
  void mostrar() {
    _temporizador?.cancel();
    navigatorKey.currentState?.popUntil((ruta) => ruta.isFirst);
    activo = true;
    notifyListeners();
  }

  /// Mientras Auré piensa o responde, no entramos en reposo.
  void ocupar() => _ocupado++;

  void liberar() {
    if (_ocupado > 0) _ocupado--;
    _programar();
  }

  /// No entrar en reposo si alguien está escribiendo.
  bool get _escribiendo {
    final contexto = FocusManager.instance.primaryFocus?.context;
    return contexto != null && contexto.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void detener() {
    _temporizador?.cancel();
    home = null;
    activo = false;
    _ocupado = 0;
    notifyListeners();
  }
}
