import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Una casa guardada en este móvil: chalet, apartamento de la playa, villa en Dubái…
class CasaGuardada {
  CasaGuardada({
    required this.id,
    required this.nombre,
    required this.casa,
    this.fuera = '',
    this.token,
    this.renovacion,
  });

  /// La dirección de casa sirve de identificador.
  final String id;
  String nombre;
  final String casa;
  final String fuera;
  final String? token;
  final String? renovacion;

  List<String> get direcciones => [casa, if (fuera.isNotEmpty) fuera];

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'casa': casa,
        'fuera': fuera,
        if (token != null) 'token': token,
        if (renovacion != null) 'renovacion': renovacion,
      };

  factory CasaGuardada.fromJson(Map<String, dynamic> j) => CasaGuardada(
        id: j['id'] as String,
        nombre: (j['nombre'] as String?) ?? '',
        casa: j['casa'] as String,
        fuera: (j['fuera'] as String?) ?? '',
        token: j['token'] as String?,
        renovacion: j['renovacion'] as String?,
      );

  /// Nombre de respaldo a partir de la dirección (192.168.1.155 → "192.168.1.155").
  static String nombreDe(String url) => Uri.tryParse(url)?.host ?? url;
}

/// Las casas de este móvil y cuál está abierta ahora.
class CasasStore extends ChangeNotifier {
  CasasStore._();

  static final CasasStore i = CasasStore._();
  static const _almacen = FlutterSecureStorage();

  List<CasaGuardada> casas = [];
  String? activa;

  /// Los pone la app principal: abrir otra casa y empezar a añadir una nueva.
  Future<void> Function(String id)? alCambiar;
  VoidCallback? alAnadir;

  CasaGuardada? get actual {
    for (final c in casas) {
      if (c.id == activa) return c;
    }
    return null;
  }

  Future<void> cargar() async {
    try {
      final texto = await _almacen.read(key: 'casas_guardadas');
      if (texto != null) {
        casas = [
          for (final j in jsonDecode(texto) as List) CasaGuardada.fromJson(Map<String, dynamic>.from(j as Map)),
        ];
      }
    } catch (_) {
      casas = [];
    }
    activa = await _almacen.read(key: 'casa_activa');
  }

  Future<void> _guardar() async {
    notifyListeners();
    await _almacen.write(key: 'casas_guardadas', value: jsonEncode([for (final c in casas) c.toJson()]));
    if (activa == null) {
      await _almacen.delete(key: 'casa_activa');
    } else {
      await _almacen.write(key: 'casa_activa', value: activa);
    }
  }

  /// Guarda (o actualiza) una casa y la marca como la abierta.
  Future<void> recordar(CasaGuardada nueva) async {
    final antes = casas.indexWhere((c) => c.id == nueva.id);
    if (antes >= 0) {
      // Conservamos el nombre que le haya puesto el cliente.
      if (casas[antes].nombre.isNotEmpty) nueva.nombre = casas[antes].nombre;
      casas[antes] = nueva;
    } else {
      casas.add(nueva);
    }
    activa = nueva.id;
    await _guardar();
  }

  Future<void> renombrar(String id, String nombre) async {
    for (final c in casas) {
      if (c.id == id) c.nombre = nombre.trim().isEmpty ? CasaGuardada.nombreDe(c.casa) : nombre.trim();
    }
    await _guardar();
  }

  Future<void> olvidar(String id) async {
    casas.removeWhere((c) => c.id == id);
    if (activa == id) activa = null;
    await _guardar();
  }

  Future<void> marcarActiva(String id) async {
    activa = id;
    await _guardar();
  }
}
