import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'i18n.dart';

/// Datos para conectar con la casa.
class DatosConexion {
  const DatosConexion({
    required this.casa,
    this.fuera = '',
    this.usuario = '',
    this.clave = '',
    this.token = '',
  });

  /// Dirección dentro de casa (por ejemplo http://192.168.1.155).
  final String casa;

  /// Dirección desde fuera (Tailscale, Nabu Casa o dominio propio). Opcional.
  final String fuera;
  final String usuario;
  final String clave;

  /// Token de larga duración (opción avanzada).
  final String token;
}

/// Resultado de entrar con usuario y contraseña.
class Entrada {
  const Entrada({this.acceso, this.renovacion, this.error, this.sinConexion = false});

  final String? acceso;
  final String? renovacion;
  final String? error;
  final bool sinConexion;
}

/// Sesión con Home Assistant: direcciones guardadas y entrada con usuario y contraseña,
/// igual que hace la app oficial (los tokens se renuevan solos).
class Sesion {
  Sesion._();

  static const clienteId = 'https://aure.andrelia.es/';
  static const _redireccion = 'https://aure.andrelia.es/app';
  static const almacen = FlutterSecureStorage();

  /// Limpia una dirección: quita espacios y la barra final, y añade http:// si falta.
  static String limpiar(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Entra con usuario y contraseña en una dirección concreta.
  static Future<Entrada> entrar(String base, String usuario, String clave) async {
    try {
      final inicio = await http
          .post(
            Uri.parse('$base/auth/login_flow'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'client_id': clienteId,
              'handler': ['homeassistant', null],
              'redirect_uri': _redireccion,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (inicio.statusCode != 200) {
        return Entrada(error: t('error.respuesta', {'c': '${inicio.statusCode}'}));
      }
      final flujo = (jsonDecode(inicio.body) as Map<String, dynamic>)['flow_id'] as String?;
      if (flujo == null) return Entrada(error: t('conectar.fallo'));

      final paso = await http
          .post(
            Uri.parse('$base/auth/login_flow/$flujo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'client_id': clienteId, 'username': usuario, 'password': clave}),
          )
          .timeout(const Duration(seconds: 10));
      final datos = jsonDecode(paso.body) as Map<String, dynamic>;
      if (datos['type'] != 'create_entry') {
        if (datos['step_id'] == 'mfa') return Entrada(error: t('conectar.mfa'));
        return Entrada(error: t('conectar.malUsuario'));
      }
      final codigo = datos['result'] as String;

      final res = await http.post(
        Uri.parse('$base/auth/token'),
        body: {'grant_type': 'authorization_code', 'code': codigo, 'client_id': clienteId},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return Entrada(error: t('conectar.fallo'));
      final tokens = jsonDecode(res.body) as Map<String, dynamic>;
      return Entrada(
        acceso: tokens['access_token'] as String?,
        renovacion: tokens['refresh_token'] as String?,
      );
    } on FormatException {
      return Entrada(error: t('conectar.fallo'));
    } catch (_) {
      return const Entrada(sinConexion: true);
    }
  }

  /// Pide un token de acceso nuevo con el de renovación.
  static Future<String?> renovar(String base, String renovacion) async {
    try {
      final res = await http.post(
        Uri.parse('$base/auth/token'),
        body: {'grant_type': 'refresh_token', 'refresh_token': renovacion, 'client_id': clienteId},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['access_token'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ---------- Lo guardado en este dispositivo ----------

  static Future<String?> direccionCasa() => almacen.read(key: 'url');

  static Future<String?> direccionFuera() async {
    final f = await almacen.read(key: 'url_fuera');
    return (f == null || f.isEmpty) ? null : f;
  }

  static Future<void> guardarDirecciones(String casa, String fuera) async {
    await almacen.write(key: 'url', value: casa);
    if (fuera.isEmpty) {
      await almacen.delete(key: 'url_fuera');
    } else {
      await almacen.write(key: 'url_fuera', value: fuera);
    }
  }

  /// Contenido del código QR para conectar otro móvil (solo direcciones, nunca contraseñas).
  static String codigoQr(String casa, String? fuera) => Uri(
        scheme: 'aure',
        host: 'conectar',
        queryParameters: {'casa': casa, if (fuera != null && fuera.isNotEmpty) 'fuera': fuera},
      ).toString();

  /// Lee un código QR de Auré: (casa, fuera) o null si no es nuestro.
  static (String, String)? leerQr(String texto) {
    final uri = Uri.tryParse(texto.trim());
    if (uri == null || uri.scheme != 'aure' || uri.host != 'conectar') return null;
    final casa = uri.queryParameters['casa'];
    if (casa == null || casa.isEmpty) return null;
    return (casa, uri.queryParameters['fuera'] ?? '');
  }
}
