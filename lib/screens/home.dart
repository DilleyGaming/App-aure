import 'dart:async';

import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../pantalla.dart';
import '../perfil.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/fondo.dart';
import '../widgets/house_view.dart';
import '../widgets/presence_cycle.dart';
import 'rooms.dart';
import 'scenes.dart';

String saludoPersonal(HaHome home) {
  final nombre = PerfilStore.i.nombre(home);
  return nombre.isEmpty ? saludo() : '${saludo()}, $nombre';
}

/// Resumen del día: se actualiza solo con la casa y la agenda.
class TuDia extends StatefulWidget {
  const TuDia({super.key, required this.home, this.compacto = false});

  final HaHome home;
  final bool compacto;

  @override
  State<TuDia> createState() => _TuDiaState();
}

class _TuDiaState extends State<TuDia> {
  List<Evento> _eventos = [];
  Timer? _refresco;

  @override
  void initState() {
    super.initState();
    _cargar();
    _refresco = Timer.periodic(const Duration(minutes: 10), (_) => _cargar());
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final eventos = await widget.home.eventosHoy();
    if (mounted) setState(() => _eventos = eventos);
  }

  @override
  Widget build(BuildContext context) {
    final texto = widget.home.status == HaStatus.connected
        ? resumenDia(widget.home, _eventos)
        : resumenCasa(widget.home);
    if (widget.compacto) {
      return Text(texto, style: sans(15, color: AureColors.gris), maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: aureCard(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsetsDirectional.only(top: 8, end: 14),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AureColors.dorado),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('inicio.tuDia'), style: sans(13, color: AureColors.dorado, spacing: 0.5)),
                const SizedBox(height: 6),
                Text(texto, style: serif(18, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pestaña de inicio en el móvil.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.home, required this.alVerHabitaciones});

  final HaHome home;
  final VoidCallback alVerHabitaciones;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([home, PerfilStore.i]),
      builder: (context, _) {
        final casa = estadoCasa(home);
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
          children: [
            Row(
              children: [
                Expanded(child: Text(saludoPersonal(home), style: serif(30))),
                aureLogo(size: 38),
              ],
            ),
            const SizedBox(height: 14),
            TuDia(home: home),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
              decoration: aureCard(radius: 26),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: HouseView(niveles: casa.niveles, colores: casa.colores),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _Dato(Icons.lightbulb_outline, '${home.lightsOn}', t('inicio.luces'))),
                const SizedBox(width: 10),
                Expanded(
                  child: _Dato(
                    Icons.thermostat,
                    home.insideTemp == null ? '—' : '${grados(home.insideTemp!)}°',
                    t('inicio.dentro'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _Dato(Icons.music_note_outlined, '${home.playing}', t('inicio.sonando'))),
              ],
            ),
            const SizedBox(height: 26),
            Text(t('nav.escenas'), style: serif(22)),
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: escenasAure.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SceneCard(escena: escenasAure[i], home: home, compacta: true),
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: Text(t('nav.habitaciones'), style: serif(22))),
                TextButton(
                  onPressed: alVerHabitaciones,
                  child: Text(t('inicio.verTodas'), style: sans(14, color: AureColors.dorado)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RoomsGrid(home: home, limite: 4),
          ],
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.valor, this.texto);

  final IconData icono;
  final String valor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: aureCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AureColors.dorado),
          const SizedBox(height: 10),
          Text(valor, style: serif(24)),
          Text(texto, style: sans(12, color: AureColors.gris), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Panel izquierdo en tablet: reloj, saludo, tu día, la casa y escenas rápidas.
class HousePanel extends StatelessWidget {
  const HousePanel({super.key, required this.home, required this.alAjustes});

  final HaHome home;
  final VoidCallback alAjustes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([home, PerfilStore.i]),
      builder: (context, _) {
        final casa = estadoCasa(home);
        return LayoutBuilder(
          builder: (context, c) {
            final bajo = c.maxHeight < 680;
            return Padding(
              padding: EdgeInsets.fromLTRB(32, bajo ? 16 : 24, 32, bajo ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      aureLogo(size: 30),
                      const SizedBox(width: 12),
                      Text('AURÉ', style: sans(17, spacing: 8, weight: FontWeight.w300)),
                      const Spacer(),
                      IconButton(
                        tooltip: t('nav.ajustes'),
                        onPressed: alAjustes,
                        icon: const Icon(Icons.tune, color: AureColors.gris),
                      ),
                    ],
                  ),
                  SizedBox(height: bajo ? 8 : 20),
                  Reloj(style: serif(bajo ? 54 : 72, height: 1)),
                  const SizedBox(height: 8),
                  Text('${saludoPersonal(home)}.', style: serif(bajo ? 22 : 26, color: AureColors.doradoClaro)),
                  const SizedBox(height: 6),
                  TuDia(home: home, compacto: true),
                  SizedBox(height: bajo ? 10 : 18),
                  // La casa se encoge si no hay sitio.
                  Expanded(
                    child: Center(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: HouseView(niveles: casa.niveles, colores: casa.colores),
                      ),
                    ),
                  ),
                  SizedBox(height: bajo ? 10 : 18),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: escenasAure.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ScenePill(escena: escenasAure[i], home: home),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Pantalla de reposo para las tablets de pared: la casa "a la espera".
class AmbientScreen extends StatelessWidget {
  const AmbientScreen({super.key, required this.home, required this.alDespertar});

  final HaHome home;
  final VoidCallback alDespertar;

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final tamanoReloj = (pantalla.shortestSide * 0.55).clamp(200.0, 420.0);
    final atenuar = PantallaStore.i.atenuarAhora();
    final contenido = Material(
      color: AureColors.negro,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: alDespertar,
        child: SafeArea(
          child: Stack(
            children: [
              Center(child: PresenceCycle(tamano: tamanoReloj)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: ListenableBuilder(
                  listenable: home,
                  builder: (context, _) => Column(
                    children: [
                      Text(resumenCasa(home), textAlign: TextAlign.center, style: sans(14, color: AureColors.gris)),
                      const SizedBox(height: 6),
                      Text(
                        t('reposo.pista'),
                        textAlign: TextAlign.center,
                        style: sans(13, color: AureColors.grisOscuro, spacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!atenuar) return contenido;
    // Modo noche activado en Ajustes: misma pantalla, solo más tenue.
    return ColoredBox(
      color: Colors.black,
      child: Opacity(opacity: PantallaStore.i.brilloNoche, child: contenido),
    );
  }
}
