import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'ha/ha_home.dart';
import 'i18n.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets/avisos.dart';
import 'widgets/common.dart';
import 'widgets/hoja.dart';

/// Acceso de invitado que caduca: para el servicio, una niñera o un huésped.
/// El propietario crea un usuario temporal en Home Assistant y se lo pasa con un QR.
class Invitados {
  Invitados._();

  static const _almacen = FlutterSecureStorage();

  /// Código QR de invitado (lleva su usuario temporal; deja de valer cuando caduca).
  static String codigoQr({
    required String casa,
    String? fuera,
    required String usuario,
    required String clave,
    required String nombre,
    required DateTime hasta,
    List<String>? areas,
  }) =>
      Uri(
        scheme: 'aure',
        host: 'invitado',
        queryParameters: {
          'casa': casa,
          if (fuera != null && fuera.isNotEmpty) 'fuera': fuera,
          'u': usuario,
          'p': clave,
          'n': nombre,
          'hasta': hasta.toIso8601String(),
          if (areas != null && areas.isNotEmpty) 'areas': areas.join(','),
        },
      ).toString();

  // ---------- En el móvil del invitado ----------

  static Future<void> guardarAcceso({required DateTime hasta, List<String>? areas}) async {
    await _almacen.write(key: 'invitado_hasta', value: hasta.toIso8601String());
    if (areas == null || areas.isEmpty) {
      await _almacen.delete(key: 'invitado_areas');
    } else {
      await _almacen.write(key: 'invitado_areas', value: areas.join(','));
    }
  }

  /// (hasta cuándo, estancias permitidas) o null si este móvil no es de invitado.
  static Future<(DateTime, Set<String>?)?> acceso() async {
    final hasta = DateTime.tryParse(await _almacen.read(key: 'invitado_hasta') ?? '');
    if (hasta == null) return null;
    final areas = await _almacen.read(key: 'invitado_areas');
    return (hasta, areas == null || areas.isEmpty ? null : areas.split(',').toSet());
  }

  static Future<void> olvidarAcceso() async {
    await _almacen.delete(key: 'invitado_hasta');
    await _almacen.delete(key: 'invitado_areas');
  }
}

String _fechaCorta(DateTime d) => '${fechaLarga(d)} · ${hora(d)}';

/// Lista de invitados del propietario, con el botón para crear uno nuevo.
Future<void> abrirInvitados(BuildContext context, HaHome home) async {
  await abrirHoja<void>(context, builder: (hoja) {
    return StatefulBuilder(builder: (context, refrescar) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AsaHoja(),
            const SizedBox(height: 6),
            Text(t('inv.titulo'), style: serif(26)),
            const SizedBox(height: 4),
            Text(t('inv.explica'), style: sans(13, color: AureColors.gris)),
            const SizedBox(height: 16),
            FutureBuilder<List<(String, String, DateTime?)>>(
              future: home.invitados(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                  );
                }
                final lista = snap.data!;
                if (lista.isEmpty) return Text(t('inv.ninguno'), style: sans(14, color: AureColors.grisOscuro));
                return Column(
                  children: [
                    for (final inv in lista)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                        decoration: aureCard(radius: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.person_outline, color: AureColors.dorado),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(inv.$2, style: sans(15, weight: FontWeight.w500)),
                                  Text(
                                    inv.$3 == null
                                        ? ''
                                        : (inv.$3!.isBefore(DateTime.now())
                                            ? t('inv.caducado')
                                            : t('inv.hasta', {'f': _fechaCorta(inv.$3!)})),
                                    style: sans(12, color: AureColors.gris),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: t('inv.quitar'),
                              onPressed: () async {
                                await home.borrarUsuario(inv.$1);
                                refrescar(() {});
                              },
                              icon: const Icon(Icons.delete_outline, color: AureColors.gris),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Pressable(
              label: t('inv.nuevo'),
              onTap: () async {
                await _nuevoInvitado(context, home);
                refrescar(() {});
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AureColors.dorado, borderRadius: BorderRadius.circular(30)),
                child: Text(t('inv.nuevo'), style: sans(16, weight: FontWeight.w600, color: AureColors.negro)),
              ),
            ),
          ],
        ),
      );
    });
  });
}

Future<void> _nuevoInvitado(BuildContext context, HaHome home) async {
  final nombre = TextEditingController();
  const duraciones = [
    (Duration(hours: 24), 'inv.1dia'),
    (Duration(days: 3), 'inv.3dias'),
    (Duration(days: 7), 'inv.semana'),
    (Duration(days: 30), 'inv.mes'),
  ];
  var duracion = duraciones.first.$1;
  final elegidas = {for (final a in home.areas) a.id};
  var soloEnCasa = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        backgroundColor: AureColors.panelAlto,
        title: Text(t('inv.nuevo'), style: serif(24)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nombre,
                textCapitalization: TextCapitalization.words,
                style: sans(16),
                decoration: InputDecoration(
                  labelText: t('inv.nombre'),
                  labelStyle: sans(14, color: AureColors.gris),
                  filled: true,
                  fillColor: AureColors.panel,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              Text(t('inv.cuanto'), style: sans(13, color: AureColors.dorado)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in duraciones)
                    ChoiceChip(
                      label: Text(t(d.$2), style: sans(13)),
                      selected: duracion == d.$1,
                      onSelected: (_) => setD(() => duracion = d.$1),
                    ),
                ],
              ),
              if (home.areas.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t('inv.estancias'), style: sans(13, color: AureColors.dorado)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in home.areas)
                      FilterChip(
                        label: Text(a.name, style: sans(13)),
                        selected: elegidas.contains(a.id),
                        onSelected: (v) => setD(() => v ? elegidas.add(a.id) : elegidas.remove(a.id)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: soloEnCasa,
                onChanged: (v) => setD(() => soloEnCasa = v),
                title: Text(t('inv.soloCasa'), style: sans(14)),
                subtitle: Text(t('inv.soloCasaSub'), style: sans(12, color: AureColors.gris)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t('comun.cancelar'), style: sans(14, color: AureColors.gris)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('inv.crear'), style: sans(14, color: AureColors.dorado)),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final quien = nombre.text.trim().isEmpty ? t('inv.sinNombre') : nombre.text.trim();
  final hasta = DateTime.now().add(duracion);
  final creado = await home.crearInvitado(quien, hasta, soloEnCasa: soloEnCasa);
  if (!context.mounted) return;
  if (creado == null) {
    Avisos.mostrar(context, t('inv.error'), icono: Icons.error_outline);
    return;
  }
  final todas = elegidas.length == home.areas.length;
  final qr = Invitados.codigoQr(
    casa: home.direcciones.first,
    fuera: home.direcciones.length > 1 ? home.direcciones[1] : null,
    usuario: creado.$1,
    clave: creado.$2,
    nombre: quien,
    hasta: hasta,
    areas: todas ? null : elegidas.toList(),
  );
  await abrirHoja<void>(context, builder: (hoja) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AsaHoja(),
          const SizedBox(height: 6),
          Text(t('inv.listo', {'n': quien}), style: serif(24), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AureColors.crema, borderRadius: BorderRadius.circular(22)),
            child: QrImageView(
              data: qr,
              size: 230,
              backgroundColor: AureColors.crema,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AureColors.negro),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AureColors.negro),
            ),
          ),
          const SizedBox(height: 14),
          Text(t('inv.hasta', {'f': _fechaCorta(hasta)}), style: sans(14, color: AureColors.doradoClaro)),
          const SizedBox(height: 8),
          Text(t('inv.qrExplica'), textAlign: TextAlign.center, style: sans(13, color: AureColors.gris)),
        ],
      ),
    );
  });
}
