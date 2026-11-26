import 'dart:async';
import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';

import 'i18n.dart';

/// Widget de Auré en la pantalla de inicio del móvil (Android):
/// cuatro botones que abren la app y hacen la escena al momento.
class WidgetCasa {
  WidgetCasa._();

  /// Lo que hace cada botón (mismas claves que los accesos directos del icono).
  static const acciones = ['hablar', 'esc.bienvenida', 'esc.cena', 'esc.noches'];

  static String? _pendiente;
  static void Function(String accion)? _manejador;
  static StreamSubscription<Uri?>? _toques;

  static bool get _disponible {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  static Future<void> iniciar() async {
    if (!_disponible) return;
    try {
      await actualizar();
      final inicial = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _recibir(inicial);
      _toques = HomeWidget.widgetClicked.listen(_recibir);
    } catch (_) {
      // Sin widget en este dispositivo: no pasa nada.
    }
  }

  /// Pone los textos del widget en el idioma actual.
  static Future<void> actualizar() async {
    if (!_disponible) return;
    try {
      await HomeWidget.saveWidgetData<String>('w_hablar', t('widget.hablar'));
      await HomeWidget.saveWidgetData<String>('w_bienvenida', t('widget.llego'));
      await HomeWidget.saveWidgetData<String>('w_cena', t('esc.cena'));
      await HomeWidget.saveWidgetData<String>('w_noches', t('widget.noches'));
      await HomeWidget.updateWidget(androidName: 'AureWidget');
    } catch (_) {}
  }

  static void _recibir(Uri? uri) {
    if (uri == null || uri.scheme != 'aure') return;
    final accion = uri.queryParameters['c'];
    if (accion == null || !acciones.contains(accion)) return;
    final m = _manejador;
    if (m != null) {
      m(accion);
    } else {
      _pendiente = accion;
    }
  }

  static void escuchar(void Function(String accion) manejador) {
    _manejador = manejador;
    final p = _pendiente;
    if (p != null) {
      _pendiente = null;
      manejador(p);
    }
  }

  static void dejarDeEscuchar() => _manejador = null;

  static void parar() => _toques?.cancel();
}
