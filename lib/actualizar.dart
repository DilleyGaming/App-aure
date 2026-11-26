import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'i18n.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/hoja.dart';

/// Avisa cuando hay una versión nueva de la app.
/// GitHub publica en esta dirección el número de la última versión y dónde descargarla.
/// (Cuando la web esté lista, se puede cambiar por https://aure.andrelia.es/app/version.json.)
class Actualizar {
  Actualizar._();

  static const _direccion = 'https://raw.githubusercontent.com/DilleyGaming/App-aure/apk/version.json';
  static bool _avisado = false;

  /// Comprueba si hay versión nueva y, si la hay, enseña el aviso (una vez por sesión).
  static Future<void> comprobar(BuildContext context) async {
    if (_avisado) return;
    try {
      if (!Platform.isAndroid) return;
      final info = await PackageInfo.fromPlatform();
      final actual = int.tryParse(info.buildNumber) ?? 0;
      final res = await http.get(Uri.parse(_direccion)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final datos = jsonDecode(res.body) as Map<String, dynamic>;
      final ultima = (datos['build'] as num?)?.toInt() ?? 0;
      final url = datos['url'] as String?;
      if (ultima <= actual || url == null) return;
      _avisado = true;
      if (!context.mounted) return;
      await _mostrar(context, (datos['nombre'] ?? '').toString(), url);
    } catch (_) {
      // Sin internet o sin datos: no pasa nada, se mira la próxima vez.
    }
  }

  static Future<void> _mostrar(BuildContext context, String nombre, String url) {
    return abrirHoja<void>(context, builder: (hoja) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AsaHoja(),
            const SizedBox(height: 6),
            Row(
              children: [
                aureLogo(size: 34),
                const SizedBox(width: 12),
                Expanded(child: Text(t('act.titulo'), style: serif(26))),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              t('act.texto', {'v': nombre}),
              style: sans(15, color: AureColors.gris),
            ),
            const SizedBox(height: 22),
            Pressable(
              label: t('act.descargar'),
              onTap: () {
                Navigator.pop(hoja);
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AureColors.dorado,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  t('act.descargar'),
                  style: sans(16, weight: FontWeight.w600, color: AureColors.negro),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(hoja),
                child: Text(t('act.luego'), style: sans(14, color: AureColors.gris)),
              ),
            ),
          ],
        ),
      );
    });
  }
}
