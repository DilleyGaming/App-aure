import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../i18n.dart';

/// Un aparato de la casa (luz, persiana, clima...).
class HaEntity {
  const HaEntity(this.id, this.state, this.attributes);

  final String id;
  final String state;
  final Map<String, dynamic> attributes;

  String get domain => id.split('.').first;
  String get name => (attributes['friendly_name'] as String?) ?? id;
  bool get isOn => state == 'on';

  /// Brillo de 0 a 1 (solo luces encendidas).
  double get brightness {
    if (!isOn) return 0;
    final b = attributes['brightness'];
    if (b is num) return (b / 255).clamp(0.0, 1.0).toDouble();
    return 1;
  }

  /// Color de la luz, si lo tiene.
  Color? get rgb {
    final c = attributes['rgb_color'];
    if (c is List && c.length >= 3) {
      return Color.fromARGB(255, (c[0] as num).toInt(), (c[1] as num).toInt(), (c[2] as num).toInt());
    }
    return null;
  }

  HaEntity withState(String newState) => HaEntity(id, newState, attributes);
}

class HaArea {
  const HaArea(this.id, this.name);

  final String id;
  final String name;
}

enum HaStatus { connecting, connected, error }

/// Un evento de la agenda de hoy.
class Evento {
  const Evento(this.titulo, this.inicio, this.todoElDia);

  final String titulo;
  final DateTime inicio;
  final bool todoElDia;
}

/// Una persona de la casa (según Home Assistant).
class Persona {
  const Persona(this.id, this.nombre);

  final String id;
  final String nombre;
}

/// Toda la casa: estado en tiempo real, habitaciones y acciones.
class HaHome extends ChangeNotifier {
  /// [direcciones]: primero la de casa y después la de fuera (si hay). Auré usa sola la que responda.
  /// [renovar]: si la sesión es con usuario y contraseña, pide un token nuevo cuando caduca.
  HaHome(this.direcciones, this.token, {this.renovar}) : baseUrl = direcciones.first;

  final List<String> direcciones;
  String baseUrl;
  String token;
  final Future<String?> Function(String base)? renovar;

  static const controlables = {'light', 'switch', 'cover', 'climate', 'media_player', 'fan'};

  final Map<String, HaEntity> entities = {};
  List<HaArea> areas = [];
  HaStatus status = HaStatus.connecting;
  String? error;

  /// Quien quiera enterarse de eventos personalizados de Home Assistant (permisos, etc.).
  final List<void Function(String tipo, Map<String, dynamic> datos)> _oyentesEvento = [];

  void escucharEventos(void Function(String tipo, Map<String, dynamic> datos) oyente) => _oyentesEvento.add(oyente);

  void dejarDeEscucharEventos(void Function(String tipo, Map<String, dynamic> datos) oyente) =>
      _oyentesEvento.remove(oyente);

  /// Última frase oída por cada estancia (según los puntos de voz del techo).
  final Map<String?, String> fraseOida = {};

  // Quién está conectado
  String? usuarioNombre;
  bool esAdmin = false;
  List<Persona> personas = [];

  final Map<String, String> _areaDirecta = {};
  final Map<String, String> _areaDispositivo = {};
  final Map<String, String> _dispositivoDe = {};

  WebSocket? _ws;
  int _siguienteId = 0;
  final Map<int, void Function(dynamic)> _pendientes = {};
  final Map<int, Completer<dynamic>> _esperas = {};
  Timer? _reintento;
  Timer? _renovacion;
  bool _fueraDeLinea = false;
  bool _cerrado = false;
  String? _conversacionId;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  // ---------- Conexión ----------

  Future<void> start() async {
    await _elegirDireccion();
    if (renovar != null) {
      await _renovarToken();
      // Los tokens de sesión duran 30 minutos: se renuevan antes de que caduquen.
      _renovacion = Timer.periodic(const Duration(minutes: 20), (_) => _renovarToken());
    }
    await _cargarEstados();
    _abrirSocket();
  }

  /// Prueba primero la dirección de casa y, si no responde, la de fuera.
  Future<void> _elegirDireccion() async {
    if (direcciones.length < 2) return;
    for (var i = 0; i < direcciones.length; i++) {
      final url = direcciones[i];
      try {
        await http
            .get(Uri.parse('$url/api/'))
            .timeout(Duration(milliseconds: i == 0 ? 2500 : 7000));
        // Cualquier respuesta (aunque sea "sin permiso") significa que la casa está ahí.
        if (baseUrl != url) {
          baseUrl = url;
          _avisar();
        }
        return;
      } catch (_) {
        // No responde: probamos la siguiente.
      }
    }
  }

  /// Dirección de casa o de fuera que se está usando ahora.
  bool get usandoFuera => direcciones.length > 1 && baseUrl != direcciones.first;

  Future<bool> _renovarToken() async {
    final r = renovar;
    if (r == null) return false;
    try {
      final nuevo = await r(baseUrl);
      if (nuevo != null) {
        token = nuevo;
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _cargarEstados({bool reintentado = false}) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/states'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 401) {
        if (!reintentado && await _renovarToken()) return _cargarEstados(reintentado: true);
        _fallo(t('error.token'));
        return;
      }
      if (res.statusCode != 200) {
        _fallo(t('error.respuesta', {'c': '${res.statusCode}'}));
        return;
      }
      final List<dynamic> data = jsonDecode(res.body);
      for (final s in data) {
        _guardar(Map<String, dynamic>.from(s as Map));
      }
      status = HaStatus.connected;
      error = null;
      _avisar();
    } catch (_) {
      _fallo(t('error.conexion'));
    }
  }

  Future<void> _abrirSocket() async {
    if (_cerrado) return;
    // Si se cortó (por ejemplo, al salir de casa), buscamos otra vez qué dirección responde.
    if (_fueraDeLinea) {
      await _elegirDireccion();
      if (renovar != null) await _renovarToken();
      _fueraDeLinea = false;
    }
    final url = '${baseUrl.replaceFirst(RegExp(r'^http'), 'ws')}/api/websocket';
    try {
      final ws = await WebSocket.connect(url);
      if (_cerrado) {
        ws.close();
        return;
      }
      _ws = ws;
      ws.listen(
        _alRecibir,
        onDone: _programarReintento,
        onError: (_) => _programarReintento(),
        cancelOnError: true,
      );
    } catch (_) {
      _programarReintento();
    }
  }

  void _programarReintento() {
    _ws = null;
    _fueraDeLinea = true;
    for (final c in _esperas.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _esperas.clear();
    if (_cerrado) return;
    _reintento?.cancel();
    _reintento = Timer(const Duration(seconds: 5), _abrirSocket);
  }

  /// Envía un mensaje y espera la respuesta (null si falla o tarda demasiado).
  Future<dynamic> _pedir(Map<String, dynamic> mensaje) {
    final ws = _ws;
    if (ws == null) return Future.value(null);
    final id = ++_siguienteId;
    final c = Completer<dynamic>();
    _esperas[id] = c;
    ws.add(jsonEncode({'id': id, ...mensaje}));
    return c.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _esperas.remove(id);
      return null;
    });
  }

  void _enviar(Map<String, dynamic> mensaje, [void Function(dynamic)? alResponder]) {
    final ws = _ws;
    if (ws == null) return;
    final id = ++_siguienteId;
    if (alResponder != null) _pendientes[id] = alResponder;
    ws.add(jsonEncode({'id': id, ...mensaje}));
  }

  void _alRecibir(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'auth_required':
        _ws?.add(jsonEncode({'type': 'auth', 'access_token': token}));
      case 'auth_invalid':
        if (renovar != null) {
          // Puede que el token haya caducado: lo renovamos y volvemos a entrar.
          _renovarToken().then((ok) {
            if (ok) {
              _ws?.close();
            } else {
              _fallo(t('error.token'));
            }
          });
        } else {
          _fallo(t('error.token'));
        }
      case 'auth_ok':
        _alAutenticar();
      case 'result':
        final espera = _esperas.remove(msg['id']);
        if (espera != null) {
          if (!espera.isCompleted) espera.complete(msg['success'] == true ? (msg['result'] ?? true) : null);
          return;
        }
        final cb = _pendientes.remove(msg['id']);
        if (cb != null && msg['success'] == true) cb(msg['result']);
      case 'event':
        final evento = msg['event'];
        if (evento is Map && (evento['event_type'] as String? ?? '').startsWith('aure_')) {
          final datos = Map<String, dynamic>.from((evento['data'] as Map?) ?? {});
          for (final oyente in List.of(_oyentesEvento)) {
            oyente(evento['event_type'] as String, datos);
          }
          return;
        }
        if (evento is Map && evento['event_type'] == 'esphome.stt_text') {
          final datos = evento['data'];
          if (datos is Map && datos['text'] != null) {
            final dispositivo = datos['device_id']?.toString();
            fraseOida[dispositivo == null ? null : _areaDispositivo[dispositivo]] = datos['text'].toString();
            _avisar();
          }
          return;
        }
        if (evento is Map && evento['event_type'] == 'state_changed') {
          final datos = evento['data'] as Map;
          final nuevo = datos['new_state'];
          if (nuevo == null) {
            entities.remove(datos['entity_id']);
          } else {
            _guardar(Map<String, dynamic>.from(nuevo as Map));
          }
          _avisar();
        }
    }
  }

  void _alAutenticar() {
    status = HaStatus.connected;
    error = null;
    _enviar({'type': 'subscribe_events', 'event_type': 'state_changed'});
    // Los puntos de voz (reSpeaker con ESPHome) envían el texto que han oído.
    _enviar({'type': 'subscribe_events', 'event_type': 'esphome.stt_text'});
    // Solicitudes de permiso (solo las recibe el propietario, que es administrador).
    _enviar({'type': 'subscribe_events', 'event_type': 'aure_permiso_solicitado'});
    _enviar({'type': 'subscribe_events', 'event_type': 'aure_permiso_respuesta'});
    _enviar({'type': 'auth/current_user'}, (r) {
      usuarioNombre = r['name'] as String?;
      esAdmin = r['is_admin'] == true;
      _avisar();
    });
    _enviar({'type': 'person/list'}, (r) {
      final lista = <Persona>[];
      for (final grupo in ['storage', 'config']) {
        final personasGrupo = r[grupo];
        if (personasGrupo is List) {
          for (final p in personasGrupo) {
            lista.add(Persona(p['id'] as String, p['name'] as String));
          }
        }
      }
      personas = lista;
      _avisar();
    });
    _enviar({'type': 'get_states'}, (r) {
      for (final s in r as List) {
        _guardar(Map<String, dynamic>.from(s as Map));
      }
      _avisar();
    });
    _enviar({'type': 'config/area_registry/list'}, (r) {
      areas = [
        for (final a in r as List) HaArea(a['area_id'] as String, a['name'] as String),
      ];
      _avisar();
    });
    _enviar({'type': 'config/device_registry/list'}, (r) {
      _areaDispositivo.clear();
      for (final d in r as List) {
        final area = d['area_id'];
        if (area != null) _areaDispositivo[d['id'] as String] = area as String;
      }
      _avisar();
    });
    _enviar({'type': 'config/entity_registry/list'}, (r) {
      _areaDirecta.clear();
      _dispositivoDe.clear();
      for (final e in r as List) {
        final id = e['entity_id'] as String;
        if (e['area_id'] != null) _areaDirecta[id] = e['area_id'] as String;
        if (e['device_id'] != null) _dispositivoDe[id] = e['device_id'] as String;
      }
      _avisar();
    });
    _avisar();
  }

  void _guardar(Map<String, dynamic> s) {
    final id = s['entity_id'] as String;
    entities[id] = HaEntity(
      id,
      (s['state'] as String?) ?? 'unknown',
      Map<String, dynamic>.from((s['attributes'] as Map?) ?? const {}),
    );
  }

  void _fallo(String mensaje) {
    status = HaStatus.error;
    error = mensaje;
    _avisar();
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _reintento?.cancel();
    _renovacion?.cancel();
    _ws?.close();
    super.dispose();
  }

  // ---------- Consultas ----------

  String? areaOf(String entityId) => _areaDirecta[entityId] ?? _areaDispositivo[_dispositivoDe[entityId]];

  String? areaName(String? areaId) {
    if (areaId == null) return null;
    for (final a in areas) {
      if (a.id == areaId) return a.name;
    }
    return null;
  }

  List<HaEntity> get devices {
    final lista = entities.values
        .where((e) => controlables.contains(e.domain) && e.state != 'unavailable')
        .toList();
    lista.sort((a, b) => a.name.compareTo(b.name));
    return lista;
  }

  List<HaEntity> inArea(String? areaId) => devices.where((e) => areaOf(e.id) == areaId).toList();

  /// Puntos de voz de una estancia (satélites de voz de Home Assistant).
  List<HaEntity> satelitesEn(String? areaId) => entities.values
      .where((e) => e.domain == 'assist_satellite' && (areaId == null || areaOf(e.id) == areaId))
      .toList();

  /// Palabras de activación de un punto de voz: (disponibles como (id, nombre), activas, máximo).
  Future<(List<(String, String)>, List<String>, int)?> palabrasActivacion(String satelite) async {
    final r = await _pedir({'type': 'assist_satellite/get_configuration', 'entity_id': satelite});
    if (r is! Map) return null;
    final disponibles = <(String, String)>[
      for (final w in (r['available_wake_words'] as List? ?? const []))
        if (w is Map && w['id'] != null) (w['id'].toString(), (w['wake_word'] ?? w['id']).toString()),
    ];
    final activas = [for (final w in (r['active_wake_words'] as List? ?? const [])) w.toString()];
    final maximo = (r['max_active_wake_words'] as num?)?.toInt() ?? 1;
    return (disponibles, activas, maximo);
  }

  /// Cambia la palabra de activación de un punto de voz.
  Future<bool> ponerPalabraActivacion(String satelite, String palabra) async {
    final r = await _pedir({
      'type': 'assist_satellite/set_wake_words',
      'entity_id': satelite,
      'wake_word_ids': [palabra],
    });
    return r != null;
  }

  /// Estado de voz de una estancia: idle, listening, processing o responding.
  String estadoVoz(String? areaId) {
    const prioridad = ['listening', 'processing', 'responding'];
    var mejor = 'idle';
    for (final e in satelitesEn(areaId)) {
      if (prioridad.indexOf(e.state) > prioridad.indexOf(mejor)) mejor = e.state;
    }
    return mejor;
  }

  List<HaEntity> get lights => devices.where((e) => e.domain == 'light').toList();

  List<HaEntity> get scenes => entities.values.where((e) => e.domain == 'scene').toList();

  int get lightsOn => lights.where((e) => e.isOn).length;

  int get playing => devices.where((e) => e.domain == 'media_player' && e.state == 'playing').length;

  double? get insideTemp {
    for (final e in devices) {
      final temp = e.attributes['current_temperature'];
      if (e.domain == 'climate' && temp is num) return temp.toDouble();
    }
    return null;
  }

  HaEntity? get tiempo {
    for (final e in entities.values) {
      if (e.domain == 'weather') return e;
    }
    return null;
  }

  int get persianasAbiertas => devices.where((e) => e.domain == 'cover' && e.state == 'open').length;

  /// Eventos de hoy de todos los calendarios de la casa.
  Future<List<Evento>> eventosHoy() async {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day);
    final fin = inicio.add(const Duration(days: 1));
    final eventos = <Evento>[];
    for (final id in entities.keys.where((k) => k.startsWith('calendar.'))) {
      try {
        final uri = Uri.parse('$baseUrl/api/calendars/$id').replace(queryParameters: {
          'start': inicio.toUtc().toIso8601String(),
          'end': fin.toUtc().toIso8601String(),
        });
        final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
        if (res.statusCode != 200) continue;
        for (final ev in jsonDecode(res.body) as List) {
          final empieza = ev['start'] as Map;
          final fecha = empieza['dateTime'] ?? empieza['date'];
          final cuando = DateTime.tryParse(fecha.toString());
          if (cuando == null) continue;
          eventos.add(Evento(
            (ev['summary'] ?? '').toString(),
            cuando.toLocal(),
            empieza['dateTime'] == null,
          ));
        }
      } catch (_) {
        // Si un calendario falla, seguimos con los demás.
      }
    }
    eventos.sort((a, b) => a.inicio.compareTo(b.inicio));
    return eventos;
  }

  List<String> idsOf(String domain, [bool Function(HaEntity)? filtro]) {
    return [
      for (final e in devices)
        if (e.domain == domain && (filtro == null || filtro(e))) e.id,
    ];
  }

  // ---------- Acciones ----------

  Future<void> service(String domain, String service, Map<String, dynamic> data) async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/services/$domain/$service'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Si falla, el estado real llegará al reconectar.
    }
    if (_ws == null) await _cargarEstados();
  }

  /// Enciende o apaga, actualizando la pantalla al instante.
  Future<void> toggle(HaEntity e) async {
    final estabaEncendido = e.isOn;
    entities[e.id] = e.withState(estabaEncendido ? 'off' : 'on');
    _avisar();
    final dominio = {'light', 'switch', 'fan'}.contains(e.domain) ? e.domain : 'homeassistant';
    await service(dominio, estabaEncendido ? 'turn_off' : 'turn_on', {'entity_id': e.id});
  }

  static const _modosColor = {'color_temp', 'hs', 'rgb', 'rgbw', 'rgbww', 'xy'};

  bool _admiteTono(HaEntity e) {
    final modos = e.attributes['supported_color_modes'];
    return modos is List && modos.any(_modosColor.contains);
  }

  /// Enciende todas las luces a un brillo y, si se indica, a un tono (en kelvin).
  Future<void> lucesA(double nivel, {int? kelvin}) async {
    final brillo = (nivel * 100).round();
    if (kelvin == null) {
      final ids = idsOf('light');
      if (ids.isEmpty) return;
      await service('light', 'turn_on', {'entity_id': ids, 'brightness_pct': brillo});
      return;
    }
    final conTono = idsOf('light', _admiteTono);
    final sinTono = idsOf('light', (e) => !_admiteTono(e));
    if (conTono.isNotEmpty) {
      await service('light', 'turn_on', {
        'entity_id': conTono,
        'brightness_pct': brillo,
        'color_temp_kelvin': kelvin,
      });
    }
    if (sinTono.isNotEmpty) {
      await service('light', 'turn_on', {'entity_id': sinTono, 'brightness_pct': brillo});
    }
  }

  /// Pone a una temperatura todos los climatizadores que lo permiten.
  Future<void> climaA(double temperatura) async {
    final ids = idsOf('climate', (e) => e.attributes['temperature'] is num);
    if (ids.isEmpty) return;
    await service('climate', 'set_temperature', {'entity_id': ids, 'temperature': temperatura});
  }

  /// Guarda una escena en Home Assistant. Devuelve un error o null si ha ido bien.
  Future<String?> guardarEscena(String nombre, String icono, Map<String, Map<String, dynamic>> entidades) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/config/scene/config/$id'),
            headers: _headers,
            body: jsonEncode({'id': id, 'name': nombre, 'icon': icono, 'entities': entidades}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 401 || res.statusCode == 403) return t('editor.sinPermiso');
      if (res.statusCode != 200) return t('editor.error');
      return null;
    } catch (_) {
      return t('editor.error');
    }
  }

  /// Borra una escena creada desde la app o desde el editor de Home Assistant.
  Future<bool> borrarEscena(HaEntity escena) async {
    final id = escena.attributes['id'];
    if (id == null) return false;
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/api/config/scene/config/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> apagarLuces() async {
    final ids = idsOf('light', (e) => e.isOn);
    if (ids.isEmpty) return;
    await service('light', 'turn_off', {'entity_id': ids});
  }

  Future<void> bajarPersianas() async {
    final ids = idsOf('cover', (e) => e.state != 'closed');
    if (ids.isEmpty) return;
    await service('cover', 'close_cover', {'entity_id': ids});
  }

  Future<void> pausarMusica() async {
    final ids = idsOf('media_player', (e) => e.state == 'playing');
    if (ids.isEmpty) return;
    await service('media_player', 'media_pause', {'entity_id': ids});
  }

  /// Lanza un evento en Home Assistant (requiere ser administrador).
  void lanzarEvento(String tipo, Map<String, dynamic> datos) {
    _enviar({'type': 'fire_event', 'event_type': tipo, 'event_data': datos});
  }

  Future<bool> existeScript(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/config/script/config/$id'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> guardarScript(String id, Map<String, dynamic> config) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/api/config/script/config/$id'), headers: _headers, body: jsonEncode(config))
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------- Automatizaciones creadas por Auré dentro de Home Assistant ----------

  Future<bool> existeAutomatizacion(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/config/automation/config/$id'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Guarda una automatización. Devuelve un error o null si ha ido bien.
  Future<String?> guardarAutomatizacion(String id, Map<String, dynamic> config) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/config/automation/config/$id'),
            headers: _headers,
            body: jsonEncode({'id': id, ...config}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 401 || res.statusCode == 403) return t('editor.sinPermiso');
      if (res.statusCode != 200) return t('auto.error');
      return null;
    } catch (_) {
      return t('auto.error');
    }
  }

  Future<bool> borrarAutomatizacion(String id) async {
    try {
      final res = await http
          .delete(Uri.parse('$baseUrl/api/config/automation/config/$id'), headers: _headers)
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  List<String> get personasEntidades => entities.keys.where((k) => k.startsWith('person.')).toList();

  /// Llegada automática: al llegar alguien y ser de noche, la casa enciende la bienvenida.
  Future<String?> activarLlegada({required double brillo, required double temperatura}) async {
    final quienes = personasEntidades;
    if (quienes.isEmpty) return t('auto.sinPersonas');
    final luces = idsOf('light');
    final climas = idsOf('climate', (e) => e.attributes['temperature'] is num);
    return guardarAutomatizacion('aure_llegada', {
      'alias': 'Auré · Bienvenida al llegar',
      'description': 'Enciende la casa cuando llega alguien y ya es de noche. Creada por la app Auré.',
      'triggers': [
        {'trigger': 'state', 'entity_id': quienes, 'to': 'home'},
      ],
      'conditions': [
        {
          'condition': 'or',
          'conditions': [
            {'condition': 'sun', 'after': 'sunset', 'after_offset': '-00:30:00'},
            {'condition': 'sun', 'before': 'sunrise'},
          ],
        },
      ],
      'actions': [
        if (luces.isNotEmpty)
          {
            'action': 'light.turn_on',
            'target': {'entity_id': luces},
            'data': {'brightness_pct': (brillo * 100).round()},
          },
        if (climas.isNotEmpty)
          {
            'action': 'climate.set_temperature',
            'target': {'entity_id': climas},
            'data': {'temperature': temperatura},
          },
      ],
      'mode': 'single',
    });
  }

  /// Modo vacaciones: enciende y apaga luces a horas naturales para que parezca que hay alguien.
  Future<String?> activarVacaciones() async {
    final luces = idsOf('light');
    if (luces.isEmpty) return t('auto.sinLuces');
    return guardarAutomatizacion('aure_vacaciones', {
      'alias': 'Auré · Modo vacaciones',
      'description': 'Simula que hay alguien en casa. Creada por la app Auré.',
      'triggers': [
        {'trigger': 'time_pattern', 'minutes': '/25', 'id': 'simular'},
        {'trigger': 'time', 'at': '23:40:00', 'id': 'apagar'},
      ],
      'conditions': [],
      'actions': [
        {
          'choose': [
            {
              'conditions': [
                {'condition': 'trigger', 'id': 'apagar'},
              ],
              'sequence': [
                {'action': 'light.turn_off', 'target': {'entity_id': luces}},
              ],
            },
            {
              'conditions': [
                {'condition': 'trigger', 'id': 'simular'},
                {'condition': 'sun', 'after': 'sunset', 'after_offset': '-00:20:00'},
                {'condition': 'time', 'before': '23:30:00'},
              ],
              'sequence': [
                {
                  'delay': {'minutes': '{{ range(0, 10) | random }}'},
                },
                {
                  'action': 'light.toggle',
                  'target': {'entity_id': '{{ ${jsonEncode(luces)} | random }}'},
                },
              ],
            },
          ],
        },
      ],
      'mode': 'single',
    });
  }

  /// Revisión de buenas noches: qué se ha quedado abierto.
  List<String> revisionNoche() {
    const aberturas = {'door', 'window', 'opening', 'garage_door'};
    final abiertos = <String>[];
    for (final e in entities.values) {
      if (e.domain == 'binary_sensor' && aberturas.contains(e.attributes['device_class']) && e.state == 'on') {
        abiertos.add(e.name);
      }
      if (e.domain == 'lock' && e.state == 'unlocked') abiertos.add(e.name);
      if (e.domain == 'cover' && e.attributes['device_class'] == 'garage' && e.state == 'open') abiertos.add(e.name);
    }
    return abiertos;
  }

  /// Habla con el asistente de la casa, manteniendo el hilo de la conversación.
  Future<String> talk(String texto) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/conversation/process'),
            headers: _headers,
            body: jsonEncode({
              'text': texto,
              'language': I18n.i.codigo,
              if (_conversacionId != null) 'conversation_id': _conversacionId,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      _conversacionId = data['conversation_id'] as String?;
      final respuesta = data['response']?['speech']?['plain']?['speech'];
      return (respuesta as String?) ?? t('talk.sinRespuesta');
    } catch (_) {
      return t('talk.error');
    }
  }
}
