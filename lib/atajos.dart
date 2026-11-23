import 'dart:io' show Platform;

import 'package:quick_actions/quick_actions.dart';

import 'i18n.dart';

/// Accesos directos al mantener pulsado el icono de la app (Android e iPhone).
class Atajos {
  Atajos._();

  static String? _pendiente;
  static void Function(String tipo)? _manejador;

  static bool get _disponible {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static Future<void> iniciar() async {
    if (!_disponible) return;
    try {
      const acciones = QuickActions();
      await acciones.initialize((tipo) {
        final m = _manejador;
        if (m != null) {
          m(tipo);
        } else {
          _pendiente = tipo;
        }
      });
      await actualizar();
      I18n.alCambiar = actualizar;
    } catch (_) {}
  }

  /// Vuelve a poner los textos (por ejemplo, al cambiar de idioma).
  static Future<void> actualizar() async {
    if (!_disponible) return;
    try {
      await const QuickActions().setShortcutItems([
        ShortcutItem(type: 'hablar', localizedTitle: t('hablar.boton')),
        ShortcutItem(type: 'esc.cena', localizedTitle: t('esc.cena')),
        ShortcutItem(type: 'esc.noches', localizedTitle: t('esc.noches')),
        ShortcutItem(type: 'esc.bienvenida', localizedTitle: t('esc.bienvenida')),
      ]);
    } catch (_) {}
  }

  /// La casa ya está lista: atiende los accesos directos (y el que llegó antes de tiempo).
  static void escuchar(void Function(String tipo) manejador) {
    _manejador = manejador;
    final p = _pendiente;
    if (p != null) {
      _pendiente = null;
      manejador(p);
    }
  }

  static void dejarDeEscuchar() => _manejador = null;
}
