import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ajustes de pantalla: modo noche opcional y su brillo.
/// El modo noche solo atenúa la pantalla; nunca cambia los colores.
class PantallaStore extends ChangeNotifier {
  PantallaStore._();

  static final PantallaStore i = PantallaStore._();
  static const _almacen = FlutterSecureStorage();

  /// Si está activo, de 23:00 a 7:00 la app baja su brillo.
  bool modoNoche = false;

  /// Brillo durante la noche (0,4 = muy tenue · 1 = normal).
  double brilloNoche = 0.8;

  Future<void> cargar() async {
    modoNoche = (await _almacen.read(key: 'modo_noche')) == '1';
    brilloNoche = double.tryParse(await _almacen.read(key: 'brillo_noche') ?? '') ?? 0.8;
  }

  Future<void> cambiarModoNoche(bool valor) async {
    modoNoche = valor;
    notifyListeners();
    await _almacen.write(key: 'modo_noche', value: valor ? '1' : '0');
  }

  Future<void> cambiarBrillo(double valor) async {
    brilloNoche = valor.clamp(0.4, 1.0);
    notifyListeners();
    await _almacen.write(key: 'brillo_noche', value: brilloNoche.toStringAsFixed(2));
  }

  /// ¿Hay que atenuar ahora?
  bool atenuarAhora([DateTime? ahora]) {
    if (!modoNoche) return false;
    final h = (ahora ?? DateTime.now()).hour;
    return h >= 23 || h < 7;
  }
}
