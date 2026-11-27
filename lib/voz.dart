import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'i18n.dart';

/// La voz de Auré en la app: escuchar por el micrófono y responder en voz alta.
class Voz extends ChangeNotifier {
  Voz._();

  static final Voz i = Voz._();
  static const _almacen = FlutterSecureStorage();

  final SpeechToText _oido = SpeechToText();
  final FlutterTts _habla = FlutterTts();
  bool _oidoListo = false;

  bool escuchando = false;
  bool hablando = false;

  /// Preferencia: responder en voz alta cuando le hablas.
  bool responderEnVoz = true;

  /// Voz elegida (nombre de la voz del sistema; null = la de por defecto), tono y velocidad.
  String? vozElegida;
  double tono = 1.0;
  double velocidad = 0.5;

  String get _idiomaVoz => switch (I18n.i.idioma) {
        Idioma.es => 'es-ES',
        Idioma.en => 'en-GB',
        Idioma.ar => 'ar-AE',
        Idioma.fr => 'fr-FR',
        Idioma.ru => 'ru-RU',
        Idioma.hi => 'hi-IN',
      };

  Future<void> cargar() async {
    responderEnVoz = (await _almacen.read(key: 'responder_en_voz')) != '0';
    vozElegida = await _almacen.read(key: 'voz_nombre');
    tono = double.tryParse(await _almacen.read(key: 'voz_tono') ?? '') ?? 1.0;
    velocidad = double.tryParse(await _almacen.read(key: 'voz_velocidad') ?? '') ?? 0.5;
    try {
      await _habla.setSpeechRate(velocidad);
      await _habla.setPitch(tono);
      _habla.setStartHandler(() {
        hablando = true;
        notifyListeners();
      });
      _habla.setCompletionHandler(() {
        hablando = false;
        notifyListeners();
      });
      _habla.setCancelHandler(() {
        hablando = false;
        notifyListeners();
      });
      _habla.setErrorHandler((_) {
        hablando = false;
        notifyListeners();
      });
    } catch (_) {
      // Sin voz en este dispositivo: la app sigue funcionando por escrito.
    }
  }

  Future<void> cambiarResponderEnVoz(bool valor) async {
    responderEnVoz = valor;
    notifyListeners();
    await _almacen.write(key: 'responder_en_voz', value: valor ? '1' : '0');
  }

  /// Voces del sistema para el idioma actual: lista de (nombre, idioma).
  Future<List<(String, String)>> voces() async {
    try {
      final todas = await _habla.getVoices;
      final prefijo = _idiomaVoz.split('-').first.toLowerCase();
      final lista = <(String, String)>[];
      if (todas is List) {
        for (final v in todas) {
          if (v is Map) {
            final nombre = v['name']?.toString();
            final locale = v['locale']?.toString() ?? '';
            if (nombre != null && locale.toLowerCase().startsWith(prefijo)) lista.add((nombre, locale));
          }
        }
      }
      lista.sort((a, b) => a.$1.compareTo(b.$1));
      return lista;
    } catch (_) {
      return [];
    }
  }

  Future<void> elegirVoz(String? nombre, String? locale) async {
    vozElegida = nombre;
    notifyListeners();
    if (nombre == null) {
      await _almacen.delete(key: 'voz_nombre');
      await _almacen.delete(key: 'voz_locale');
    } else {
      await _almacen.write(key: 'voz_nombre', value: nombre);
      await _almacen.write(key: 'voz_locale', value: locale ?? _idiomaVoz);
    }
  }

  Future<void> cambiarTono(double v) async {
    tono = v;
    notifyListeners();
    await _almacen.write(key: 'voz_tono', value: v.toStringAsFixed(2));
  }

  Future<void> cambiarVelocidad(double v) async {
    velocidad = v;
    notifyListeners();
    await _almacen.write(key: 'voz_velocidad', value: v.toStringAsFixed(2));
  }

  /// Aplica voz, tono y velocidad antes de hablar.
  Future<void> _prepararVoz() async {
    await _habla.setLanguage(_idiomaVoz);
    final nombre = vozElegida;
    if (nombre != null) {
      final locale = await _almacen.read(key: 'voz_locale') ?? _idiomaVoz;
      // Solo si la voz es del idioma actual (si cambias de idioma, vuelve a la de por defecto).
      if (locale.toLowerCase().startsWith(_idiomaVoz.split('-').first.toLowerCase())) {
        await _habla.setVoice({'name': nombre, 'locale': locale});
      }
    }
    await _habla.setPitch(tono);
    await _habla.setSpeechRate(velocidad);
  }

  Future<bool> _prepararOido() async {
    if (_oidoListo) return true;
    try {
      _oidoListo = await _oido.initialize(
        onStatus: (estado) {
          if (estado == 'done' || estado == 'notListening') {
            escuchando = false;
            notifyListeners();
          }
        },
        onError: (_) {
          escuchando = false;
          notifyListeners();
        },
      );
    } catch (_) {
      _oidoListo = false;
    }
    return _oidoListo;
  }

  /// Empieza a escuchar. Devuelve false si este dispositivo no tiene reconocimiento de voz.
  Future<bool> escuchar({
    required void Function(String texto) alOir,
    required void Function(String texto) alTerminar,
  }) async {
    if (!await _prepararOido()) return false;
    await callar();
    escuchando = true;
    notifyListeners();
    try {
      await _oido.listen(
        localeId: _idiomaVoz.replaceAll('-', '_'),
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        onResult: (r) {
          if (r.finalResult) {
            escuchando = false;
            notifyListeners();
            alTerminar(r.recognizedWords);
          } else {
            alOir(r.recognizedWords);
          }
        },
      );
    } catch (_) {
      escuchando = false;
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> dejarDeEscuchar() async {
    try {
      await _oido.stop();
    } catch (_) {}
    escuchando = false;
    notifyListeners();
  }

  /// Dice un texto en voz alta (si la preferencia está activada o se fuerza).
  Future<void> decir(String texto, {bool forzar = false}) async {
    if (texto.trim().isEmpty || (!responderEnVoz && !forzar)) return;
    try {
      await _prepararVoz();
      await _habla.speak(texto);
    } catch (_) {}
  }

  Future<void> callar() async {
    try {
      await _habla.stop();
    } catch (_) {}
    hablando = false;
  }
}
