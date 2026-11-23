import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'acento.dart';
import 'alertas.dart';
import 'atajos.dart';
import 'dispositivo.dart';
import 'pantalla.dart';
import 'ha/ha_home.dart';
import 'i18n.dart';
import 'perfil.dart';
import 'reposo.dart';
import 'screens/home.dart';
import 'screens/connect.dart';
import 'screens/modo.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'theme.dart';
import 'voz.dart';
import 'widgets/breathing_orb.dart';
import 'widgets/splash.dart';

void main() => runApp(const AureApp());

class AureApp extends StatelessWidget {
  const AureApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Toda la app se redibuja al cambiar de idioma (incluido el árabe, de derecha a izquierda).
    return ListenableBuilder(
      listenable: Listenable.merge([I18n.i, AcentoStore.i]),
      builder: (context, _) => MaterialApp(
        title: 'Auré',
        debugShowCheckedModeBanner: false,
        theme: aureTheme(),
        // Permite deslizar también con el ratón (en ordenador).
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        navigatorKey: Reposo.i.navigatorKey,
        builder: (context, child) => Directionality(
          textDirection: I18n.i.direccion,
          child: FiltroAcento(
            child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => Reposo.i.actividad(),
            child: ListenableBuilder(
              listenable: Reposo.i,
              builder: (context, _) {
                final casa = Reposo.i.home;
                return Stack(
                  children: [
                    child ?? const SizedBox.shrink(),
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 700),
                        child: Reposo.i.activo && casa != null
                          ? AmbientScreen(
                              key: const ValueKey('reposo'),
                              home: casa,
                              alDespertar: Reposo.i.actividad,
                            )
                            : const SizedBox.shrink(key: ValueKey('activo')),
                      ),
                    ),
                  ],
                );
              },
            ),
            ),
          ),
        ),
        home: const Raiz(),
      ),
    );
  }
}

/// Decide qué pantalla mostrar: conectar, cargando o la casa.
class Raiz extends StatefulWidget {
  const Raiz({super.key});

  @override
  State<Raiz> createState() => _RaizState();
}

class _RaizState extends State<Raiz> {
  final _almacen = const FlutterSecureStorage();
  HaHome? _casa;
  bool _cargando = true;
  bool _logoTerminado = false;
  bool _verBienvenida = false;
  String _url = 'http://192.168.1.155';

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    await I18n.i.cargar();
    await PerfilStore.i.cargar();
    await AcentoStore.i.cargar();
    await PantallaStore.i.cargar();
    await Voz.i.cargar();
    await DispositivoStore.i.cargar();
    await Alertas.iniciar();
    await Atajos.iniciar();
    final url = await _almacen.read(key: 'url');
    final token = await _almacen.read(key: 'token');
    if (url != null) _url = url;
    if (url != null && token != null) {
      final casa = HaHome(url, token);
      await casa.start();
      _casa = casa;
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<String?> _conectar(String url, String token) async {
    if (url.isEmpty || token.isEmpty) return t('conectar.faltan');
    final limpia = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final casa = HaHome(limpia, token);
    await casa.start();
    if (casa.status == HaStatus.error) {
      final error = casa.error;
      casa.dispose();
      return error ?? t('conectar.fallo');
    }
    await _almacen.write(key: 'url', value: limpia);
    await _almacen.write(key: 'token', value: token);
    final vista = await _almacen.read(key: 'bienvenida_vista');
    setState(() {
      _url = limpia;
      _casa = casa;
      _verBienvenida = vista != '1';
    });
    return null;
  }

  Future<void> _desconectar() async {
    final casa = _casa;
    Reposo.i.detener();
    setState(() => _casa = null);
    // Esperamos a que termine la transición antes de cerrar la conexión.
    Future<void>.delayed(const Duration(milliseconds: 900), () => casa?.dispose());
    await _almacen.delete(key: 'token');
    await DispositivoStore.i.olvidar();
  }

  @override
  Widget build(BuildContext context) {
    final Widget pantalla;
    if (!_logoTerminado) {
      pantalla = ArranqueLogo(
        key: const ValueKey('logo'),
        alTerminar: () => setState(() => _logoTerminado = true),
      );
    } else if (_cargando) {
      pantalla = const Scaffold(
        key: ValueKey('cargando'),
        body: Center(child: BreathingOrb(size: 160, mode: OrbMode.thinking)),
      );
    } else if (_casa != null && _verBienvenida) {
      pantalla = Bienvenida(
        key: const ValueKey('bienvenida'),
        alTerminar: () {
          _almacen.write(key: 'bienvenida_vista', value: '1');
          setState(() => _verBienvenida = false);
        },
      );
    } else if (_casa != null && !DispositivoStore.i.configurado) {
      pantalla = ModoScreen(
        key: const ValueKey('modo'),
        home: _casa!,
        alTerminar: () => setState(() {}),
      );
    } else if (_casa == null) {
      pantalla = ConnectScreen(
        key: const ValueKey('conectar'),
        alConectar: _conectar,
        urlInicial: _url,
      );
    } else {
      pantalla = Shell(
        key: ObjectKey(_casa),
        home: _casa!,
        alDesconectar: _desconectar,
      );
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 700), child: pantalla);
  }
}
