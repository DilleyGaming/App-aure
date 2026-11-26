import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../i18n.dart';
import '../theme.dart';

/// Cámara para leer el código QR de otra pantalla de Auré. Devuelve el texto leído.
class EscanearScreen extends StatefulWidget {
  const EscanearScreen({super.key});

  @override
  State<EscanearScreen> createState() => _EscanearScreenState();
}

class _EscanearScreenState extends State<EscanearScreen> {
  final _camara = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _hecho = false;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  void _alLeer(BarcodeCapture captura) {
    if (_hecho) return;
    for (final codigo in captura.barcodes) {
      final texto = codigo.rawValue;
      if (texto != null && texto.isNotEmpty) {
        _hecho = true;
        Navigator.of(context).pop(texto);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lado = MediaQuery.sizeOf(context).shortestSide * 0.68;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Text(t('qr.escanear'), style: serif(22)),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: MobileScanner(controller: _camara, onDetect: _alLeer)),
          IgnorePointer(
            child: Container(
              width: lado,
              height: lado,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AureColors.dorado, width: 2),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 32,
            right: 32,
            child: Text(
              t('qr.apunta'),
              textAlign: TextAlign.center,
              style: sans(15, color: AureColors.crema),
            ),
          ),
        ],
      ),
    );
  }
}
