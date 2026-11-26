import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final Set<String> _pilasAvisadas = {};
  static const _almacen = FlutterSecureStorage();

  /// Qué hacer cuando llaman al timbre (la app abre la cámara de la entrada).
  static void Function(String? timbre)? alLlamar;

  /// Timbres: entidades "event" de tipo doorbell, o sensores con timbre/doorbell en el nombre.
  Iterable<HaEntity> get _timbres => home.entities.values.where((e) {
        if (e.domain == 'event') return e.attributes['device_class'] == 'doorbell';
        if (e.domain == 'binary_sensor') {
          final texto = '${e.id} ${e.name}'.toLowerCase();
          return texto.contains('timbre') || texto.contains('doorbell') || texto.contains('ding');
        }
        return false;
      });

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
    for (final e in [..._sensores, ..._timbres]) {
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
    // Timbre: un evento nuevo (cambia la hora) o un sensor que pasa a "on".
    for (final e in _timbres) {
      final antes = _antes[e.id];
      final llaman = e.domain == 'event'
          ? (antes != null && antes != e.state && e.state != 'unavailable' && e.state != 'unknown')
          : (antes != null && antes != 'on' && e.state == 'on');
      if (llaman) {
        Alertas.notificar(t('timbre.llaman'), t('timbre.toca'));
        Tacto.aviso();
        alLlamar?.call(e.id);
      }
      _antes[e.id] = e.state;
    }
    _revisarPilas();
  }

  /// Pilas bajas (15 % o menos): un aviso por sensor cada tres días como mucho.
  Future<void> _revisarPilas() async {
    for (final (e, nivel) in home.pilas) {
      if (nivel == null || nivel > 15 || _pilasAvisadas.contains(e.id)) continue;
      _pilasAvisadas.add(e.id);
      final clave = 'pila_${e.id}';
      final ultima = DateTime.tryParse(await _almacen.read(key: clave) ?? '');
      if (ultima != null && DateTime.now().difference(ultima).inDays < 3) continue;
      await _almacen.write(key: clave, value: DateTime.now().toIso8601String());
      final nombre = e.name.replaceAll(RegExp(r'\s*(battery|batería|bateria|pila)\s*', caseSensitive: false), ' ').trim();
      await Alertas.notificar(t('pilas.titulo'), t('pilas.baja', {'n': nombre, 'p': nivel.round().toString()}));
    }
  }

  void parar() => home.removeListener(_revisar);
}
