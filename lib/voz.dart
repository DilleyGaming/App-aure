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

  String get _idiomaVoz => switch (I18n.i.idioma) {
        Idioma.es => 'es-ES',
        Idioma.en => 'en-GB',
        Idioma.ar => 'ar-AE',
      };

  Future<void> cargar() async {
    responderEnVoz = (await _almacen.read(key: 'responder_en_voz')) != '0';
    try {
      await _habla.setSpeechRate(0.5);
      await _habla.setPitch(1.0);
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
      await _habla.setLanguage(_idiomaVoz);
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
