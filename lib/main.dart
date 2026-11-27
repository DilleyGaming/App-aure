import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'acento.dart';
import 'alertas.dart';
import 'atajos.dart';
import 'casas.dart';
import 'dispositivo.dart';
import 'pantalla.dart';
import 'ha/ha_home.dart';
import 'i18n.dart';
import 'perfil.dart';
import 'reposo.dart';
import 'invitados.dart';
import 'sesion.dart';
import 'widget_casa.dart';
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
  String _urlFuera = '';
  String? _errorInicial;

  /// Añadiendo otra casa: se enseña la pantalla de conectar sin cerrar la actual.
  bool _anadiendo = false;

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
    await WidgetCasa.iniciar();
    // Al cambiar de idioma (o el nombre de la asistente), se traducen los accesos directos y el widget.
    I18n.alCambiar = () {
      Atajos.actualizar();
      WidgetCasa.actualizar();
    };
    await CasasStore.i.cargar();
    CasasStore.i.alCambiar = _cambiarCasa;
    CasasStore.i.alAnadir = () => setState(() {
          _anadiendo = true;
          _errorInicial = null;
          _url = 'http://';
          _urlFuera = '';
        });
    final url = await Sesion.direccionCasa();
    final fuera = await Sesion.direccionFuera();
    final token = await _almacen.read(key: 'token');
    final renovacion = await _almacen.read(key: 'refresh_token');
    if (url != null) _url = url;
    if (fuera != null) _urlFuera = fuera;
    // Acceso de invitado: si ya ha caducado, este móvil deja de entrar en la casa.
    final invitado = await Invitados.acceso();
    if (invitado != null && invitado.$1.isBefore(DateTime.now())) {
      await _olvidarSesion();
      _errorInicial = t('inv.caducadoTuyo');
    } else if (url != null && (token != null || renovacion != null)) {
      final casa = HaHome(
        [url, if (fuera != null) fuera],
        token ?? '',
        renovar: renovacion == null ? null : (base) => Sesion.renovar(base, renovacion),
      );
      casa.soloAreas = invitado?.$2;
      await casa.start();
      _casa = casa;
      // Casas guardadas de versiones anteriores: la actual pasa a la lista.
      if (CasasStore.i.actual == null) {
        await CasasStore.i.recordar(CasaGuardada(
          id: url,
          nombre: casa.nombreCasa ?? CasaGuardada.nombreDe(url),
          casa: url,
          fuera: fuera ?? '',
          token: token,
          renovacion: renovacion,
        ));
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<String?> _conectar(DatosConexion d) async {
    final casaUrl = Sesion.limpiar(d.casa);
    final fueraUrl = Sesion.limpiar(d.fuera);
    final direcciones = [if (casaUrl.isNotEmpty) casaUrl, if (fueraUrl.isNotEmpty) fueraUrl];
    if (direcciones.isEmpty) return t('conectar.faltan');
    final conToken = d.token.trim().isNotEmpty;
    if (!conToken && (d.usuario.trim().isEmpty || d.clave.isEmpty)) return t('conectar.faltanUsuario');

    HaHome casa;
    String? renovacion;
    final esInvitado = d.invitadoHasta != null;
    if (conToken) {
      casa = HaHome(direcciones, d.token.trim());
    } else {
      // Entramos por la primera dirección que responda (la de casa o la de fuera).
      Entrada? entrada;
      for (final base in direcciones) {
        entrada = await Sesion.entrar(base, d.usuario.trim(), d.clave);
        if (!entrada.sinConexion) break;
      }
      if (entrada == null || entrada.sinConexion) return t('error.conexion');
      if (entrada.error != null || entrada.acceso == null) return entrada.error ?? t('conectar.fallo');
      renovacion = entrada.renovacion;
      final r = renovacion;
      casa = HaHome(
        direcciones,
        entrada.acceso!,
        renovar: r == null ? null : (base) => Sesion.renovar(base, r),
      );
    }
    if (esInvitado) casa.soloAreas = d.invitadoAreas?.toSet();
    await casa.start();
    if (casa.status == HaStatus.error) {
      final error = casa.error;
      casa.dispose();
      return error ?? t('conectar.fallo');
    }
    await Sesion.guardarDirecciones(direcciones.first, direcciones.length > 1 ? direcciones[1] : '');
    if (conToken) {
      await _almacen.write(key: 'token', value: d.token.trim());
      await _almacen.delete(key: 'refresh_token');
    } else {
      await _almacen.delete(key: 'token');
      if (renovacion != null) await _almacen.write(key: 'refresh_token', value: renovacion);
    }
    if (esInvitado) {
      await Invitados.guardarAcceso(hasta: d.invitadoHasta!, areas: d.invitadoAreas);
      await PerfilStore.i.cambiarInvitado(true);
      final n = d.invitadoNombre;
      if (n != null && n.isNotEmpty) await PerfilStore.i.cambiarApodo(n);
    }
    await CasasStore.i.recordar(CasaGuardada(
      id: direcciones.first,
      nombre: casa.nombreCasa ?? CasaGuardada.nombreDe(direcciones.first),
      casa: direcciones.first,
      fuera: direcciones.length > 1 ? direcciones[1] : '',
      token: conToken ? d.token.trim() : null,
      renovacion: conToken ? null : renovacion,
    ));
    final vista = await _almacen.read(key: 'bienvenida_vista');
    final anterior = _casa;
    if (anterior != null) {
      Reposo.i.detener();
      Future<void>.delayed(const Duration(milliseconds: 900), anterior.dispose);
    }
    setState(() {
      _errorInicial = null;
      _anadiendo = false;
      _url = direcciones.first;
      _urlFuera = direcciones.length > 1 ? direcciones[1] : '';
      _casa = casa;
      _verBienvenida = vista != '1';
    });
    return null;
  }

  /// Abre otra de las casas guardadas en este móvil.
  Future<void> _cambiarCasa(String id) async {
    CasaGuardada? destino;
    for (final c in CasasStore.i.casas) {
      if (c.id == id) destino = c;
    }
    if (destino == null) return;
    final anterior = _casa;
    Reposo.i.detener();
    setState(() {
      _casa = null;
      _cargando = true;
      _anadiendo = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () => anterior?.dispose());
    // La casa elegida pasa a ser la de siempre al abrir la app.
    await Sesion.guardarDirecciones(destino.casa, destino.fuera);
    if (destino.token != null) {
      await _almacen.write(key: 'token', value: destino.token);
    } else {
      await _almacen.delete(key: 'token');
    }
    if (destino.renovacion != null) {
      await _almacen.write(key: 'refresh_token', value: destino.renovacion);
    } else {
      await _almacen.delete(key: 'refresh_token');
    }
    await CasasStore.i.marcarActiva(destino.id);
    final r = destino.renovacion;
    final casa = HaHome(
      destino.direcciones,
      destino.token ?? '',
      renovar: r == null ? null : (base) => Sesion.renovar(base, r),
    );
    await casa.start();
    if (!mounted) return;
    setState(() {
      _url = destino!.casa;
      _urlFuera = destino.fuera;
      _casa = casa;
      _cargando = false;
    });
  }

  Future<void> _desconectar() async {
    // Si hay más casas en este móvil, quitamos esta y abrimos la siguiente.
    final actual = CasasStore.i.activa;
    if (actual != null) await CasasStore.i.olvidar(actual);
    if (CasasStore.i.casas.isNotEmpty) {
      await _cambiarCasa(CasasStore.i.casas.first.id);
      return;
    }
    final casa = _casa;
    Reposo.i.detener();
    setState(() => _casa = null);
    // Esperamos a que termine la transición antes de cerrar la conexión.
    Future<void>.delayed(const Duration(milliseconds: 900), () => casa?.dispose());
    await _olvidarSesion();
    await DispositivoStore.i.olvidar();
  }

  Future<void> _olvidarSesion() async {
    await _almacen.delete(key: 'token');
    await _almacen.delete(key: 'refresh_token');
    if (await Invitados.acceso() != null) {
      await Invitados.olvidarAcceso();
      await PerfilStore.i.cambiarInvitado(false);
      await PerfilStore.i.cambiarApodo('');
    }
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
    } else if (_casa == null || _anadiendo) {
      final volverA = _anadiendo ? CasasStore.i.actual?.nombre : null;
      pantalla = ConnectScreen(
        key: ValueKey(_anadiendo ? 'anadir' : 'conectar'),
        alConectar: _conectar,
        urlInicial: _url,
        urlFueraInicial: _urlFuera,
        errorInicial: _errorInicial,
        volverA: volverA,
        alVolver: _anadiendo
            ? () => setState(() {
                  _anadiendo = false;
                  _url = CasasStore.i.actual?.casa ?? _url;
                })
            : null,
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
