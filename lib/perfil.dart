import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'ha/ha_home.dart';
import 'i18n.dart';

/// Lo que le gusta a cada persona de la casa.
class Preferencias {
  Preferencias({this.temperatura = 21.5, this.tono = 'calida', this.brillo = 0.8});

  double temperatura;
  String tono; // calida, neutra, fria
  double brillo;

  int get kelvin => switch (tono) {
        'neutra' => 4000,
        'fria' => 5500,
        _ => 2700,
      };

  Map<String, dynamic> toJson() => {'temperatura': temperatura, 'tono': tono, 'brillo': brillo};

  factory Preferencias.fromJson(Map<String, dynamic> j) => Preferencias(
        temperatura: (j['temperatura'] as num?)?.toDouble() ?? 21.5,
        tono: (j['tono'] as String?) ?? 'calida',
        brillo: (j['brillo'] as num?)?.toDouble() ?? 0.8,
      );
}

/// Persona que está usando la app en este dispositivo y sus preferencias.
class PerfilStore extends ChangeNotifier {
  PerfilStore._();

  static final PerfilStore i = PerfilStore._();
  static const _almacen = FlutterSecureStorage();

  String? _elegido;
  Preferencias prefs = Preferencias();
  bool invitado = false;

  /// Cómo quiere la persona que Auré la llame (si no, su nombre de Home Assistant).
  String? apodo;

  Future<void> cargar() async {
    _elegido = await _almacen.read(key: 'perfil_activo');
    invitado = (await _almacen.read(key: 'modo_invitado')) == '1';
    I18n.nombreAsistente = await _almacen.read(key: 'nombre_asistente');
    await _cargarPrefs();
    notifyListeners();
  }

  /// Nombre de la persona: su apodo, la elegida en este dispositivo o la del usuario conectado.
  String nombre(HaHome home) => apodo ?? _elegido ?? home.usuarioNombre ?? '';

  /// Cambia cómo te llama Auré. Vacío = volver al nombre de Home Assistant.
  Future<void> cambiarApodo(String valor) async {
    final limpio = valor.trim();
    apodo = limpio.isEmpty ? null : limpio;
    notifyListeners();
    if (apodo == null) {
      await _almacen.delete(key: _claveApodo);
    } else {
      await _almacen.write(key: _claveApodo, value: apodo);
    }
  }

  /// Cambia el nombre de la asistente en toda la app. Vacío = Auré.
  Future<void> cambiarNombreAsistente(String valor) async {
    final limpio = valor.trim();
    I18n.nombreAsistente = limpio.isEmpty || limpio == 'Auré' ? null : limpio;
    notifyListeners();
    I18n.i.refrescar();
    if (I18n.nombreAsistente == null) {
      await _almacen.delete(key: 'nombre_asistente');
    } else {
      await _almacen.write(key: 'nombre_asistente', value: I18n.nombreAsistente);
    }
  }

  String get _claveApodo => 'apodo_${_elegido ?? 'principal'}';

  String rol(HaHome home) {
    if (invitado) return t('rol.invitado');
    return home.esAdmin ? t('rol.propietario') : t('rol.familia');
  }

  String get _clavePrefs => 'prefs_${_elegido ?? 'principal'}';

  Future<void> _cargarPrefs() async {
    apodo = await _almacen.read(key: _claveApodo);
    final texto = await _almacen.read(key: _clavePrefs);
    prefs = texto == null ? Preferencias() : Preferencias.fromJson(jsonDecode(texto) as Map<String, dynamic>);
  }

  Future<void> elegirPersona(String nombre) async {
    _elegido = nombre;
    await _almacen.write(key: 'perfil_activo', value: nombre);
    await _cargarPrefs();
    notifyListeners();
  }

  Future<void> guardarPrefs() async {
    notifyListeners();
    await _almacen.write(key: _clavePrefs, value: jsonEncode(prefs.toJson()));
  }

  Future<void> cambiarInvitado(bool valor) async {
    invitado = valor;
    notifyListeners();
    await _almacen.write(key: 'modo_invitado', value: valor ? '1' : '0');
  }

  /// Aplica la luz y la temperatura favoritas de la persona.
  Future<void> aplicarAmbiente(HaHome home) async {
    await home.lucesA(prefs.brillo, kelvin: prefs.kelvin);
    await home.climaA(prefs.temperatura);
  }
}
