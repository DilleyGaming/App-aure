import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dispositivo.dart';
import 'ha/ha_home.dart';
import 'i18n.dart';
import 'perfil.dart';
import 'theme.dart';
import 'utils.dart';
import 'widgets/common.dart';
import 'widgets/hoja.dart';
import 'widgets/tiempo.dart';

/// La primera vez que abres la app por la mañana: el tiempo, lo que tienes hoy y cómo está la casa.
class ResumenManana {
  ResumenManana._();

  static const _almacen = FlutterSecureStorage();
  static bool _mirado = false;

  static Future<void> comprobar(BuildContext context, HaHome home) async {
    if (_mirado || DispositivoStore.i.esPared) return;
    _mirado = true;
    final ahora = DateTime.now();
    if (ahora.hour < 5 || ahora.hour >= 12) return;
    final hoy = '${ahora.year}-${ahora.month}-${ahora.day}';
    if (await _almacen.read(key: 'resumen_manana') == hoy) return;
    // Esperamos a tener la casa conectada (como mucho 15 segundos).
    for (var i = 0; i < 30 && home.status != HaStatus.connected; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (home.status != HaStatus.connected || !context.mounted) return;
    final eventos = await home.eventosHoy();
    if (!context.mounted) return;
    await _almacen.write(key: 'resumen_manana', value: hoy);
    await abrirHoja<void>(context, builder: (hoja) => _Resumen(home: home, eventos: eventos));
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.home, required this.eventos});

  final HaHome home;
  final List<Evento> eventos;

  @override
  Widget build(BuildContext context) {
    final fuera = tiempoFuera(home);
    final abiertas = home.entities.values
        .where((e) =>
            e.domain == 'binary_sensor' &&
            e.state == 'on' &&
            const {'door', 'window', 'garage_door', 'opening'}.contains(e.attributes['device_class']))
        .toList();
    HaEntity? alarma;
    for (final e in home.entities.values) {
      if (e.domain == 'alarm_control_panel') alarma = e;
    }
    final dentro = home.insideTemp;
    final nombre = PerfilStore.i.nombre(home);

    Widget fila(IconData icono, String texto, {bool aviso = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 20, color: aviso ? const Color(0xFFE8A87C) : AureColors.dorado),
              const SizedBox(width: 12),
              Expanded(child: Text(texto, style: sans(15, color: aviso ? const Color(0xFFE8A87C) : AureColors.crema))),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AsaHoja(),
            const SizedBox(height: 6),
            Text(nombre.isEmpty ? t('saludo.manana') : '${t('saludo.manana')}, $nombre', style: serif(30)),
            const SizedBox(height: 4),
            Text(fechaLarga(DateTime.now()), style: sans(14, color: AureColors.gris)),
            if (fuera != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(fuera.$1, size: 40, color: AureColors.dorado),
                  const SizedBox(width: 14),
                  Text(fuera.$2, style: serif(40, height: 1)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(fuera.$3, style: sans(15, color: AureColors.gris))),
                ],
              ),
            ],
            const SizedBox(height: 22),
            Text(t('manana.hoy'), style: sans(13, color: AureColors.dorado, spacing: 0.5)),
            const SizedBox(height: 10),
            if (eventos.isEmpty)
              fila(Icons.event_available_outlined, t('brief.sinEventos'))
            else
              for (final e in eventos.take(5))
                fila(Icons.event_outlined, '${e.todoElDia ? t('brief.todoDia') : hora(e.inicio)} · ${e.titulo}'),
            const SizedBox(height: 12),
            Text(t('manana.casa'), style: sans(13, color: AureColors.dorado, spacing: 0.5)),
            const SizedBox(height: 10),
            if (dentro != null) fila(Icons.thermostat, t('resumen.dentro', {'t': grados(dentro)})),
            if (alarma != null)
              fila(
                alarma.state.startsWith('armed') ? Icons.shield_outlined : Icons.shield_moon_outlined,
                alarma.state.startsWith('armed') ? t('manana.alarmaOn') : t('manana.alarmaOff'),
              ),
            if (abiertas.isEmpty)
              fila(Icons.door_front_door_outlined, t('manana.todoCerrado'))
            else
              fila(
                Icons.door_front_door_outlined,
                t('manana.abiertas', {'lista': abiertas.map((e) => e.name).take(3).join(', ')}),
                aviso: true,
              ),
            if (home.lightsOn > 0) fila(Icons.lightbulb_outline, resumenCasa(home)),
            const SizedBox(height: 18),
            Pressable(
              label: t('manana.empezar'),
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AureColors.dorado, borderRadius: BorderRadius.circular(30)),
                child: Text(t('manana.empezar'), style: sans(16, weight: FontWeight.w600, color: AureColors.negro)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
