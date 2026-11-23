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

  Future<void> cargar() async {
    _elegido = await _almacen.read(key: 'perfil_activo');
    invitado = (await _almacen.read(key: 'modo_invitado')) == '1';
    await _cargarPrefs();
    notifyListeners();
  }

  /// Nombre de la persona: la elegida en este dispositivo o la del usuario conectado.
  String nombre(HaHome home) => _elegido ?? home.usuarioNombre ?? '';

  String rol(HaHome home) {
    if (invitado) return t('rol.invitado');
    return home.esAdmin ? t('rol.propietario') : t('rol.familia');
  }

  String get _clavePrefs => 'prefs_${_elegido ?? 'principal'}';

  Future<void> _cargarPrefs() async {
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
