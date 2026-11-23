import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'alertas.dart';
import 'ha/ha_home.dart';
import 'i18n.dart';

/// Una petición de Auré (o de Haspeer) que necesita la aprobación del propietario.
class Permiso {
  Permiso({
    required this.id,
    required this.titulo,
    this.detalle = '',
    this.importe = '',
    this.seguro = false,
    this.clave = '',
    DateTime? expira,
  }) : expira = expira ?? DateTime.now().add(const Duration(minutes: 5));

  final String id;
  final String titulo;
  final String detalle;
  final String importe;

  /// Pagos, puertas, accesos: piden huella, Face ID o el PIN del dispositivo.
  final bool seguro;

  /// Tipo de acción (por ejemplo "uber"), para poder "permitir siempre".
  final String clave;
  final DateTime expira;

  factory Permiso.desde(Map<String, dynamic> d) {
    bool siNo(dynamic v) => v == true || v.toString().toLowerCase() == 'true';
    return Permiso(
      id: d['id'].toString(),
      titulo: (d['titulo'] ?? '').toString(),
      detalle: (d['detalle'] ?? '').toString(),
      importe: (d['importe'] ?? '').toString(),
      seguro: siNo(d['seguro']),
      clave: (d['clave'] ?? '').toString(),
      expira: DateTime.tryParse((d['expira'] ?? '').toString())?.toLocal(),
    );
  }
}

/// Lo que se decidió (para el registro).
class Decision {
  Decision(this.titulo, this.aprobado, this.cuando, {this.automatico = false});

  final String titulo;
  final bool aprobado;
  final DateTime cuando;
  final bool automatico;

  Map<String, dynamic> toJson() =>
      {'t': titulo, 'a': aprobado, 'c': cuando.toIso8601String(), 'auto': automatico};

  factory Decision.fromJson(Map<String, dynamic> j) => Decision(
        (j['t'] ?? '').toString(),
        j['a'] == true,
        DateTime.tryParse((j['c'] ?? '').toString()) ?? DateTime.now(),
        automatico: j['auto'] == true,
      );
}

/// Gestiona las peticiones de permiso: las recibe, las muestra y envía la respuesta.
class PermisosStore extends ChangeNotifier {
  PermisosStore._();

  static final PermisosStore i = PermisosStore._();
  static const _almacen = FlutterSecureStorage();

  HaHome? _home;
  final List<Permiso> pendientes = [];
  List<Decision> historial = [];
  Set<String> siempre = {};
  Timer? _limpieza;

  Future<void> conectar(HaHome home) async {
    _home = home;
    home.escucharEventos(_alEvento);
    await _cargar();
    _limpieza = Timer.periodic(const Duration(seconds: 15), (_) => _quitarCaducados());
    // El propietario instala en Home Assistant los scripts que piden el permiso.
    unawaited(_instalarCuandoSeaAdmin(home));
  }

  void desconectar() {
    _home?.dejarDeEscucharEventos(_alEvento);
    _home = null;
    _limpieza?.cancel();
    pendientes.clear();
  }

  Future<void> _instalarCuandoSeaAdmin(HaHome home) async {
    // Esperamos a saber quién está conectado.
    for (var i = 0; i < 20 && home.usuarioNombre == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!home.esAdmin) return;
    if (await home.existeScript('aure_pedir_permiso')) return;
    await home.guardarScript('aure_pedir_permiso', _scriptPedirPermiso);
  }

  void _alEvento(String tipo, Map<String, dynamic> datos) {
    final home = _home;
    if (home == null || !home.esAdmin) return;
    if (tipo == 'aure_permiso_solicitado') {
      final p = Permiso.desde(datos);
      if (p.expira.isBefore(DateTime.now()) || pendientes.any((x) => x.id == p.id)) return;
      // "Permitir siempre" (nunca para acciones seguras).
      if (!p.seguro && p.clave.isNotEmpty && siempre.contains(p.clave)) {
        _enviar(p, true, automatico: true);
        return;
      }
      pendientes.add(p);
      notifyListeners();
      Alertas.notificar(t('perm.notif'), p.titulo);
    } else if (tipo == 'aure_permiso_respuesta') {
      // Respondida en otro dispositivo: quitamos la tarjeta aquí también.
      final antes = pendientes.length;
      pendientes.removeWhere((x) => x.id == datos['id'].toString());
      if (pendientes.length != antes) notifyListeners();
    }
  }

  void _quitarCaducados() {
    final antes = pendientes.length;
    pendientes.removeWhere((p) => p.expira.isBefore(DateTime.now()));
    if (pendientes.length != antes) notifyListeners();
  }

  /// Responde a una petición. Si es segura y se aprueba, pide huella / Face ID / PIN.
  Future<bool> responder(Permiso p, bool aprobado, {bool recordar = false}) async {
    if (aprobado && p.seguro && !await _verificarIdentidad(p.titulo)) return false;
    if (aprobado && recordar && !p.seguro && p.clave.isNotEmpty) {
      siempre.add(p.clave);
      await _almacen.write(key: 'permisos_siempre', value: jsonEncode(siempre.toList()));
    }
    _enviar(p, aprobado);
    return true;
  }

  void _enviar(Permiso p, bool aprobado, {bool automatico = false}) {
    _home?.lanzarEvento('aure_permiso_respuesta', {
      'id': p.id,
      'aprobado': aprobado,
      'quien': _home?.usuarioNombre ?? '',
    });
    pendientes.removeWhere((x) => x.id == p.id);
    historial.insert(0, Decision(p.titulo, aprobado, DateTime.now(), automatico: automatico));
    if (historial.length > 50) historial = historial.sublist(0, 50);
    notifyListeners();
    unawaited(_almacen.write(key: 'permisos_historial', value: jsonEncode(historial.map((d) => d.toJson()).toList())));
  }

  Future<void> olvidarPermitidos() async {
    siempre.clear();
    notifyListeners();
    await _almacen.delete(key: 'permisos_siempre');
  }

  Future<bool> _verificarIdentidad(String motivo) async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return true; // sin huella ni PIN configurados
      return await auth.authenticate(localizedReason: motivo);
    } catch (_) {
      return false;
    }
  }

  Future<void> _cargar() async {
    try {
      final h = await _almacen.read(key: 'permisos_historial');
      if (h != null) {
        historial = (jsonDecode(h) as List).map((e) => Decision.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
      final s = await _almacen.read(key: 'permisos_siempre');
      if (s != null) siempre = (jsonDecode(s) as List).map((e) => e.toString()).toSet();
    } catch (_) {}
  }
}

/// Script de Home Assistant que pide permiso en la app y espera la respuesta.
/// Haspeer (o cualquier automatización) lo llama así y recibe {"aprobado": true/false}:
///   action: script.aure_pedir_permiso
///   data: { titulo: "Pedir un coche al aeropuerto", detalle: "Mañana 7:00", importe: "≈ 35 €", seguro: true, clave: "coche" }
const Map<String, dynamic> _scriptPedirPermiso = {
  'alias': 'Auré · Pedir permiso',
  'description': 'Pide permiso al propietario en la app de Auré antes de una acción importante y '
      'devuelve si lo ha aprobado. Creado por la app Auré.',
  'mode': 'parallel',
  'fields': {
    'titulo': {'description': 'Qué se quiere hacer', 'required': true, 'example': 'Pedir un coche al aeropuerto'},
    'detalle': {'description': 'Más información', 'example': 'Mañana a las 7:00'},
    'importe': {'description': 'Coste aproximado, si lo hay', 'example': '≈ 35 €'},
    'seguro': {'description': 'Pagos, puertas o accesos: pide huella o Face ID', 'example': true},
    'clave': {'description': 'Tipo de acción, para poder permitirla siempre', 'example': 'coche'},
  },
  'sequence': [
    {
      'variables': {
        'solicitud': "{{ now().timestamp() | int }}-{{ range(1000, 9999) | random }}",
      },
    },
    {
      'event': 'aure_permiso_solicitado',
      'event_data': {
        'id': '{{ solicitud }}',
        'titulo': '{{ titulo }}',
        'detalle': "{{ detalle | default('') }}",
        'importe': "{{ importe | default('') }}",
        'seguro': '{{ seguro | default(false) }}',
        'clave': "{{ clave | default('') }}",
        'expira': '{{ (now() + timedelta(minutes=5)).isoformat() }}',
      },
    },
    {
      'repeat': {
        'sequence': [
          {
            'wait_for_trigger': [
              {'trigger': 'event', 'event_type': 'aure_permiso_respuesta'},
            ],
            'timeout': '00:05:00',
            'continue_on_timeout': true,
          },
        ],
        'until': [
          {
            'condition': 'template',
            'value_template': '{{ wait.trigger is none or wait.trigger.event.data.id == solicitud }}',
          },
        ],
      },
    },
    {
      'variables': {
        'resultado': {
          'aprobado': '{{ wait.trigger is not none and wait.trigger.event.data.aprobado | bool }}',
          'quien': "{{ wait.trigger.event.data.quien if wait.trigger is not none else '' }}",
        },
      },
    },
    {
      'action': 'logbook.log',
      'data': {
        'name': 'Auré',
        'message': "{{ 'Permiso concedido' if resultado.aprobado else 'Permiso no concedido' }}: {{ titulo }}"
            "{{ ' (' ~ resultado.quien ~ ')' if resultado.quien else '' }}",
      },
    },
    {'stop': 'Respuesta', 'response_variable': 'resultado'},
  ],
};
