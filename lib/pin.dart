import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'i18n.dart';
import 'theme.dart';
import 'widgets/common.dart';

/// PIN de la pantalla de pared: protege los ajustes para que una visita no pueda tocarlos.
class PinPared {
  PinPared._();

  static const _almacen = FlutterSecureStorage();
  static const _clave = 'pin_pared';
  static String? _pin;
  static bool _cargado = false;

  static Future<bool> tienePin() async {
    if (!_cargado) {
      _pin = await _almacen.read(key: _clave);
      _cargado = true;
    }
    return _pin != null && _pin!.isNotEmpty;
  }

  /// true si no hay PIN o si lo escriben bien.
  static Future<bool> comprobar(BuildContext context) async {
    if (!await tienePin()) return true;
    if (!context.mounted) return false;
    final escrito = await _teclado(context, t('pin.pide'));
    return escrito != null && escrito == _pin;
  }

  /// Poner, cambiar o quitar el PIN (pide el actual primero si ya hay uno).
  static Future<void> configurar(BuildContext context) async {
    if (await tienePin()) {
      if (!context.mounted) return;
      final actual = await _teclado(context, t('pin.actual'));
      if (actual != _pin) {
        if (context.mounted && actual != null) _aviso(context, t('pin.mal'));
        return;
      }
    }
    if (!context.mounted) return;
    final nuevo = await _teclado(context, t('pin.nuevo'), permitirVacio: true);
    if (nuevo == null) return;
    if (nuevo.isEmpty) {
      await _almacen.delete(key: _clave);
      _pin = null;
      if (context.mounted) _aviso(context, t('pin.quitado'));
      return;
    }
    if (!context.mounted) return;
    final repetido = await _teclado(context, t('pin.repite'));
    if (repetido != nuevo) {
      if (context.mounted && repetido != null) _aviso(context, t('pin.noCoincide'));
      return;
    }
    await _almacen.write(key: _clave, value: nuevo);
    _pin = nuevo;
    if (context.mounted) _aviso(context, t('pin.puesto'));
  }

  static void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(texto, style: sans(14)), backgroundColor: AureColors.panelAlto),
    );
  }

  static Future<String?> _teclado(BuildContext context, String titulo, {bool permitirVacio = false}) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _Teclado(titulo: titulo, permitirVacio: permitirVacio),
    );
  }
}

class _Teclado extends StatefulWidget {
  const _Teclado({required this.titulo, required this.permitirVacio});

  final String titulo;
  final bool permitirVacio;

  @override
  State<_Teclado> createState() => _TecladoState();
}

class _TecladoState extends State<_Teclado> {
  String _pin = '';
  static const _largo = 4;

  void _pulsar(String d) {
    if (_pin.length >= _largo) return;
    Tacto.toque();
    setState(() => _pin += d);
    if (_pin.length == _largo) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) Navigator.pop(context, _pin);
      });
    }
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    Tacto.toque();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    Widget tecla(String d) => Padding(
          padding: const EdgeInsets.all(7),
          child: Pressable(
            label: d,
            onTap: () => _pulsar(d),
            child: Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AureColors.panel,
                border: Border.all(color: AureColors.linea),
              ),
              child: Text(d, style: serif(26)),
            ),
          ),
        );
    return Dialog(
      backgroundColor: AureColors.panelAlto,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: AureColors.dorado.withValues(alpha: 0.9)),
            const SizedBox(height: 10),
            Text(widget.titulo, style: serif(22), textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _largo; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? AureColors.dorado : Colors.transparent,
                      border: Border.all(color: AureColors.dorado),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            for (final fila in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ])
              Row(mainAxisSize: MainAxisSize.min, children: [for (final d in fila) tecla(d)]),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 82,
                  child: widget.permitirVacio
                      ? TextButton(
                          onPressed: () => Navigator.pop(context, ''),
                          child: Text(t('pin.sinPin'), style: sans(12, color: AureColors.gris), textAlign: TextAlign.center),
                        )
                      : null,
                ),
                tecla('0'),
                SizedBox(
                  width: 82,
                  child: IconButton(
                    tooltip: t('pin.borrar'),
                    onPressed: _borrar,
                    icon: const Icon(Icons.backspace_outlined, color: AureColors.gris),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('comun.cancelar'), style: sans(14, color: AureColors.gris)),
            ),
          ],
        ),
      ),
    );
  }
}
