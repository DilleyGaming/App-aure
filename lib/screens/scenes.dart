import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../perfil.dart';
import '../theme.dart';
import '../voz.dart';
import '../widgets/avisos.dart';
import '../widgets/common.dart';
import '../widgets/hoja.dart';
import '../widgets/house_view.dart';
import 'scene_editor.dart';

class EscenaAure {
  const EscenaAure(this.claveTitulo, this.claveDetalle, this.icono, this.accion, this.vista);

  final String claveTitulo;
  final String claveDetalle;
  final IconData icono;
  final Future<void> Function(HaHome home, Preferencias prefs) accion;

  /// Cómo quedarán las ventanas de la casa (para la vista previa).
  final Map<String, double> vista;
}

const _zonasCasa = ['salon', 'comedor', 'cocina', 'dorm', 'estudio', 'porche', 'garaje'];

/// Activa una escena con vibración y aviso dorado.
Future<void> activarEscena(BuildContext context, HaHome home, EscenaAure e) async {
  Tacto.confirmar();
  Avisos.mostrar(context, t('esc.activada', {'n': t(e.claveTitulo)}), icono: e.icono);
  await e.accion(home, PerfilStore.i.prefs);
  if (e.claveTitulo == 'esc.noches') {
    // Revisión de buenas noches: ¿se ha quedado algo abierto?
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    final abiertos = home.revisionNoche();
    final texto = abiertos.isEmpty ? t('noche.ok') : t('noche.abierto', {'lista': abiertos.join(', ')});
    if (context.mounted) {
      Avisos.mostrar(context, texto, icono: abiertos.isEmpty ? Icons.nightlight_round : Icons.warning_amber_rounded);
    }
    if (abiertos.isNotEmpty) Tacto.aviso();
    Voz.i.decir(texto);
  }
}

/// Vista previa: al mantener pulsada una escena, la casa muestra cómo quedará.
void verEscena(BuildContext context, HaHome home, EscenaAure e) {
  Tacto.toque();
  abrirHoja<void>(context, builder: (hoja) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AsaHoja(),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(e.icono, color: AureColors.dorado),
              const SizedBox(width: 12),
              Expanded(child: Text(t(e.claveTitulo), style: serif(28))),
            ],
          ),
          const SizedBox(height: 4),
          Text(t('esc.vista'), style: sans(14, color: AureColors.gris)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            decoration: aureCard(radius: 22),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: HouseView(
                niveles: {for (final z in _zonasCasa) z: e.vista[z] ?? 0.0},
                colores: const {},
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(t(e.claveDetalle), style: sans(15, color: AureColors.gris)),
          const SizedBox(height: 20),
          Pressable(
            label: t('esc.activar'),
            onTap: () {
              Navigator.of(hoja).pop();
              activarEscena(context, home, e);
            },
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AureColors.dorado, borderRadius: BorderRadius.circular(30)),
              child: Text(t('esc.activar'), style: sans(16, weight: FontWeight.w600, color: AureColors.negro)),
            ),
          ),
        ],
      ),
    );
  });
}

final escenasAure = <EscenaAure>[
  EscenaAure('esc.bienvenida', 'esc.bienvenidaSub', Icons.wb_twilight, (h, p) async {
    await h.lucesA(p.brillo, kelvin: p.kelvin);
    await h.climaA(p.temperatura);
  }, const {'salon': .8, 'comedor': .8, 'cocina': .8, 'dorm': .8, 'estudio': .8, 'porche': .8, 'garaje': .5}),
  EscenaAure('esc.cena', 'esc.cenaSub', Icons.restaurant, (h, p) => h.lucesA(0.3, kelvin: 2400),
      const {'salon': .3, 'comedor': .3, 'cocina': .3, 'dorm': .3, 'estudio': .3, 'porche': .3}),
  EscenaAure('esc.noches', 'esc.nochesSub', Icons.bedtime, (h, p) async {
    await h.apagarLuces();
    await h.bajarPersianas();
  }, const {}),
  EscenaAure('esc.salgo', 'esc.salgoSub', Icons.directions_walk, (h, p) async {
    await h.apagarLuces();
    await h.pausarMusica();
  }, const {}),
];

/// Iconos disponibles para las escenas: nombre en Home Assistant e icono en la app.
const iconosEscena = <(String, IconData)>[
  ('mdi:sofa', Icons.weekend_outlined),
  ('mdi:movie-open', Icons.movie_outlined),
  ('mdi:silverware-fork-knife', Icons.restaurant),
  ('mdi:weather-night', Icons.bedtime),
  ('mdi:party-popper', Icons.celebration_outlined),
  ('mdi:book-open-variant', Icons.menu_book_outlined),
  ('mdi:spa', Icons.spa_outlined),
  ('mdi:white-balance-sunny', Icons.wb_sunny_outlined),
];

IconData iconoDeEscena(HaEntity s) {
  final icono = s.attributes['icon'];
  for (final par in iconosEscena) {
    if (par.$1 == icono) return par.$2;
  }
  return Icons.auto_awesome_outlined;
}

/// Tarjeta de escena que brilla un momento al activarse.
class SceneCard extends StatefulWidget {
  const SceneCard({super.key, required this.escena, required this.home, this.compacta = false});

  final EscenaAure escena;
  final HaHome home;
  final bool compacta;

  @override
  State<SceneCard> createState() => _SceneCardState();
}

class _SceneCardState extends State<SceneCard> {
  bool _activa = false;

  Future<void> _activar() async {
    setState(() => _activa = true);
    await activarEscena(context, widget.home, widget.escena);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _activa = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.escena;
    return GestureDetector(
      onLongPress: () => verEscena(context, widget.home, e),
      child: Pressable(
      label: t(e.claveTitulo),
      onTap: _activar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        width: widget.compacta ? 160 : null,
        padding: const EdgeInsets.all(16),
        decoration: aureCard(active: _activa, radius: 22).copyWith(
          color: _activa ? const Color(0xFF221F19) : AureColors.panel,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(e.icono, color: AureColors.dorado, size: 22),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _activa ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const Icon(Icons.check, color: AureColors.dorado, size: 18),
                ),
              ],
            ),
            SizedBox(height: widget.compacta ? 14 : 22),
            Text(t(e.claveTitulo), style: serif(widget.compacta ? 18 : 22)),
            const SizedBox(height: 4),
            Text(
              t(e.claveDetalle),
              style: sans(12.5, color: AureColors.gris),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Escena en formato píldora (una sola línea), para espacios pequeños.
class ScenePill extends StatefulWidget {
  const ScenePill({super.key, required this.escena, required this.home});

  final EscenaAure escena;
  final HaHome home;

  @override
  State<ScenePill> createState() => _ScenePillState();
}

class _ScenePillState extends State<ScenePill> {
  bool _activa = false;

  Future<void> _activar() async {
    setState(() => _activa = true);
    await activarEscena(context, widget.home, widget.escena);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _activa = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.escena;
    return GestureDetector(
      onLongPress: () => verEscena(context, widget.home, e),
      child: Pressable(
      label: t(e.claveTitulo),
      onTap: _activar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _activa ? AureColors.dorado : AureColors.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AureColors.dorado.withValues(alpha: _activa ? 1 : 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(e.icono, size: 17, color: _activa ? AureColors.negro : AureColors.dorado),
            const SizedBox(width: 8),
            Text(
              t(e.claveTitulo),
              style: sans(14, color: _activa ? AureColors.negro : AureColors.crema),
              maxLines: 1,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Pestaña "Escenas".
class ScenesTab extends StatelessWidget {
  const ScenesTab({super.key, required this.home});

  final HaHome home;

  Future<void> _borrar(BuildContext context, HaEntity escena) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AureColors.panel,
        title: Text(t('esc.borrar', {'n': escena.name}), style: serif(22)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t('comun.cancelar'), style: sans(15, color: AureColors.gris)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('comun.borrar'), style: sans(15, color: AureColors.dorado)),
          ),
        ],
      ),
    );
    if (confirmar == true) await home.borrarEscena(escena);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([home, PerfilStore.i]),
      builder: (context, _) {
        final propias = home.scenes;
        final puedeCrear = !PerfilStore.i.invitado;
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 40),
          children: [
            Encabezado(t('nav.escenas'), subtitulo: t('esc.subtitulo')),
            const SizedBox(height: 6),
            Text(t('esc.mantener'), style: sans(13, color: AureColors.grisOscuro)),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final columnas = c.maxWidth >= 640 ? 3 : 2;
                final ancho = (c.maxWidth - 12 * (columnas - 1)) / columnas;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final e in escenasAure)
                      SizedBox(width: ancho, child: SceneCard(escena: e, home: home)),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(t('esc.tuyas'), style: serif(22)),
            if (propias.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(t('esc.mantenerBorrar'), style: sans(13, color: AureColors.grisOscuro)),
            ],
            const SizedBox(height: 12),
            if (puedeCrear)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Pressable(
                  label: t('esc.crear'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SceneEditor(home: home)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: aureCard(radius: 16).copyWith(
                      border: Border.all(color: AureColors.dorado.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: AureColors.dorado),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('esc.crear'), style: sans(15, weight: FontWeight.w500)),
                              Text(t('esc.crearSub'), style: sans(13, color: AureColors.gris)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            for (final s in propias)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onLongPress: puedeCrear ? () => _borrar(context, s) : null,
                  child: Pressable(
                    label: s.name,
                    onTap: () {
                      Tacto.confirmar();
                      Avisos.mostrar(context, t('esc.activada', {'n': s.name}), icono: iconoDeEscena(s));
                      home.service('scene', 'turn_on', {'entity_id': s.id});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: aureCard(radius: 16),
                      child: Row(
                        children: [
                          Icon(iconoDeEscena(s), color: AureColors.dorado, size: 20),
                          const SizedBox(width: 14),
                          Expanded(child: Text(s.name, style: sans(15))),
                          const Icon(Icons.play_arrow_rounded, color: AureColors.grisOscuro),
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
