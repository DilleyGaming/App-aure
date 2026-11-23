import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Cómo se usa este dispositivo.
enum ModoDispositivo {
  /// El móvil de una persona: Auré lista para hablar, sin reposo.
  movil,

  /// La tablet de una persona: panel de la casa, reposo opcional.
  tablet,

  /// Pantalla empotrada en la pared: reposo, siempre encendida y ligada a una estancia.
  pared,
}

class DispositivoStore extends ChangeNotifier {
  DispositivoStore._();

  static final DispositivoStore i = DispositivoStore._();
  static const _almacen = FlutterSecureStorage();

  ModoDispositivo modo = ModoDispositivo.movil;
  bool configurado = false;

  /// Estancia de Home Assistant donde está la pantalla de pared.
  String? area;

  /// En una tablet personal, ¿entrar en reposo al no tocarla?
  bool reposoEnTablet = false;

  bool get esPared => modo == ModoDispositivo.pared;

  /// ¿Debe entrar en reposo este dispositivo?
  bool get usaReposo => esPared || (modo == ModoDispositivo.tablet && reposoEnTablet);

  Future<void> cargar() async {
    final m = await _almacen.read(key: 'modo_dispositivo');
    configurado = m != null;
    for (final v in ModoDispositivo.values) {
      if (v.name == m) modo = v;
    }
    area = await _almacen.read(key: 'area_pared');
    reposoEnTablet = (await _almacen.read(key: 'reposo_tablet')) == '1';
    _pantallaEncendida();
  }

  Future<void> elegir(ModoDispositivo nuevo, {String? areaPared}) async {
    modo = nuevo;
    area = nuevo == ModoDispositivo.pared ? areaPared : null;
    configurado = true;
    notifyListeners();
    _pantallaEncendida();
    await _almacen.write(key: 'modo_dispositivo', value: nuevo.name);
    if (area == null) {
      await _almacen.delete(key: 'area_pared');
    } else {
      await _almacen.write(key: 'area_pared', value: area);
    }
  }

  Future<void> cambiarReposoEnTablet(bool valor) async {
    reposoEnTablet = valor;
    notifyListeners();
    await _almacen.write(key: 'reposo_tablet', value: valor ? '1' : '0');
  }

  /// Al desconectar la casa, el dispositivo vuelve a preguntar cómo se usa.
  Future<void> olvidar() async {
    configurado = false;
    area = null;
    await _almacen.delete(key: 'modo_dispositivo');
    await _almacen.delete(key: 'area_pared');
    _pantallaEncendida();
  }

  /// Las pantallas de pared no se apagan nunca.
  void _pantallaEncendida() {
    try {
      if (esPared && configurado) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    } catch (_) {
      // En algunas plataformas no está disponible; la app sigue igual.
    }
  }
}
