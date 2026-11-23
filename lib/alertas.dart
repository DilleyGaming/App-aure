import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ha/ha_home.dart';
import 'i18n.dart';
import 'reposo.dart';
import 'voz.dart';
import 'widgets/avisos.dart';
import 'widgets/common.dart';

/// Avisos de la casa: agua, humo o gas. Voz, vibración, píldora dorada y notificación del sistema.
class Alertas {
  Alertas._();

  static final _notificaciones = FlutterLocalNotificationsPlugin();
  static bool _notificacionesListas = false;
  static int _siguienteId = 1;

  static Future<void> iniciar() async {
    try {
      const darwin = DarwinInitializationSettings();
      final ajustes = InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
        linux: const LinuxInitializationSettings(defaultActionName: 'Abrir'),
        windows: WindowsInitializationSettings(
          appName: 'Auré',
          appUserModelId: 'Andrelia.Aure',
          guid: 'b6f1c2a4-3d5e-4f7a-9b8c-1d2e3f4a5b6c',
        ),
      );
      await _notificaciones.initialize(settings: ajustes);
      await _notificaciones
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _notificacionesListas = true;
    } catch (_) {
      _notificacionesListas = false;
    }
  }

  /// Notificación discreta (sin voz), por ejemplo para pedir un permiso.
  static Future<void> notificar(String titulo, String texto) async {
    Tacto.confirmar();
    if (!_notificacionesListas) return;
    try {
      await _notificaciones.show(
        id: _siguienteId++,
        title: titulo,
        body: texto,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'aure_permisos',
            'Permisos de Auré',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  static Future<void> avisar(String texto, {IconData icono = Icons.warning_amber_rounded}) async {
    Tacto.aviso();
    final contexto = Reposo.i.navigatorKey.currentContext;
    if (contexto != null) Avisos.mostrar(contexto, texto, icono: icono);
    Voz.i.decir(texto, forzar: true);
    if (_notificacionesListas) {
      try {
        await _notificaciones.show(
          id: _siguienteId++,
          title: 'Auré',
          body: texto,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'aure_avisos',
              'Avisos de la casa',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (_) {}
    }
  }
}

/// Vigila la casa y avisa cuando un sensor de agua, humo o gas se activa.
class VigilanteCasa {
  VigilanteCasa(this.home) {
    _fotografiar();
    home.addListener(_revisar);
  }

  final HaHome home;
  final Map<String, String> _antes = {};

  static const _tipos = {
    'moisture': 'alerta.agua',
    'smoke': 'alerta.humo',
    'gas': 'alerta.gas',
    'carbon_monoxide': 'alerta.gas',
  };

  Iterable<HaEntity> get _sensores => home.entities.values.where(
        (e) => e.domain == 'binary_sensor' && _tipos.containsKey(e.attributes['device_class']),
      );

  void _fotografiar() {
    for (final e in _sensores) {
      _antes[e.id] = e.state;
    }
  }

  void _revisar() {
    for (final e in _sensores) {
      final antes = _antes[e.id];
      if (antes != null && antes != 'on' && e.state == 'on') {
        final clave = _tipos[e.attributes['device_class']]!;
        Alertas.avisar(t(clave, {'n': e.name}));
      }
      _antes[e.id] = e.state;
    }
  }

  void parar() => home.removeListener(_revisar);
}
