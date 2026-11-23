import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/device_tile.dart';
import '../widgets/fondo.dart';
import '../widgets/room_art.dart';
import '../widgets/shimmer.dart';

/// Una habitación para mostrar: un área real o "Otros dispositivos".
class Habitacion {
  const Habitacion(this.areaId, this.nombre, this.aparatos);

  final String? areaId;
  final String nombre;
  final List<HaEntity> aparatos;

  int get encendidos => aparatos.where((e) => e.isOn || e.state == 'open' || e.state == 'playing').length;

  String get etiqueta => 'habitacion-${areaId ?? 'otros'}';
}

List<Habitacion> habitacionesDe(HaHome home) {
  final lista = <Habitacion>[
    for (final a in home.areas) Habitacion(a.id, a.name, home.inArea(a.id)),
  ].where((h) => h.aparatos.isNotEmpty).toList();
  final otros = home.inArea(null);
  if (otros.isNotEmpty) lista.add(Habitacion(null, t('hab.otros'), otros));
  return lista;
}

/// Abre la ficha de una habitación: la tarjeta "se abre" y se convierte en la página.
void abrirHabitacion(BuildContext context, HaHome home, Habitacion h) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => RoomPage(home: home, habitacion: h),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(0.2, 1, curve: Curves.easeOut)),
        child: child,
      ),
    ),
  );
}

/// Ficha completa de una habitación.
class RoomPage extends StatelessWidget {
  const RoomPage({super.key, required this.home, required this.habitacion});

  final HaHome home;
  final Habitacion habitacion;

  @override
  Widget build(BuildContext context) {
    final h = habitacion;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FondoVivo(
        home: home,
        child: SafeArea(
          child: ListenableBuilder(
            listenable: home,
            builder: (context, _) {
              final aparatos = home.inArea(h.areaId);
              final luces = aparatos.where((e) => e.domain == 'light' && e.isOn).map((e) => e.id).toList();
              final encendida = luces.isNotEmpty;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          tooltip: t('comun.cerrar'),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: AureColors.gris),
                        ),
                      ),
                      Hero(
                        tag: h.etiqueta,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: aureCard(active: encendida, radius: 28),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h.nombre, style: serif(34)),
                                      const SizedBox(height: 6),
                                      Text(
                                        t('hab.activos', {'a': '${aparatos.where((e) => e.isOn || e.state == 'open' || e.state == 'playing').length}', 'n': '${aparatos.length}'}),
                                        style: sans(14, color: AureColors.gris),
                                      ),
                                    ],
                                  ),
                                ),
                                IlustracionEstancia(tipoEstancia(h.nombre), encendida: encendida, alto: 72),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (luces.isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () {
                              Tacto.encender();
                              home.service('light', 'turn_off', {'entity_id': luces});
                            },
                            child: Text(t('hab.apagarLuces'), style: sans(14, color: AureColors.dorado)),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                      for (final e in aparatos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DeviceTile(key: ValueKey(e.id), entity: e, home: home),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cuadrícula de habitaciones.
class RoomsGrid extends StatelessWidget {
  const RoomsGrid({super.key, required this.home, this.limite});

  final HaHome home;
  final int? limite;

  @override
  Widget build(BuildContext context) {
    var lista = habitacionesDe(home);
    if (limite != null && lista.length > limite!) lista = lista.take(limite!).toList();
    if (lista.isEmpty) {
      if (home.status == HaStatus.connecting) {
        return const Siluetas(cantidad: 2, alto: 150);
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(t('hab.vacia'), style: sans(14, color: AureColors.gris)),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 640 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columnas,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            for (final h in lista)
              Pressable(
                label: h.nombre,
                onTap: () => abrirHabitacion(context, home, h),
                child: Hero(
                  tag: h.etiqueta,
                  child: Material(
                    color: Colors.transparent,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(16),
                      decoration: aureCard(active: h.encendidos > 0, radius: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: IlustracionEstancia(tipoEstancia(h.nombre), encendida: h.encendidos > 0, alto: 56),
                            ),
                          ),
                          Text(h.nombre, style: serif(19), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            h.encendidos == 0
                                ? t('hab.aparatos', {'n': '${h.aparatos.length}'})
                                : t('hab.activos', {'a': '${h.encendidos}', 'n': '${h.aparatos.length}'}),
                            style: sans(13, color: AureColors.gris),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pestaña "Habitaciones".
class RoomsTab extends StatelessWidget {
  const RoomsTab({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        final sinAreas = home.devices.isNotEmpty && home.devices.every((e) => home.areaOf(e.id) == null);
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 120),
          children: [
            Encabezado(t('nav.habitaciones'), subtitulo: t('hab.subtitulo')),
            const SizedBox(height: 20),
            RoomsGrid(home: home),
            if (sinAreas) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: aureCard(radius: 16),
                child: Text(t('hab.consejo'), style: sans(14, color: AureColors.gris)),
              ),
            ],
          ],
        );
      },
    );
  }
}
