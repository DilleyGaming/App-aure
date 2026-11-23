import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../alertas.dart';
import '../atajos.dart';
import '../dispositivo.dart';
import '../i18n.dart';
import '../permisos.dart';
import '../perfil.dart';
import '../reposo.dart';
import '../theme.dart';
import '../widgets/breathing_orb.dart';
import '../widgets/aure_icon.dart';
import '../widgets/common.dart';
import '../widgets/device_tile.dart';
import '../widgets/voz_pared.dart';
import '../widgets/permiso_card.dart';
import '../widgets/fondo.dart';
import '../widgets/hoja.dart';
import 'home.dart';
import 'modo.dart';
import 'preferences.dart';
import 'rooms.dart';
import 'scenes.dart';
import 'talk.dart';

void abrirPreferencias(BuildContext context, HaHome home) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PreferencesScreen(home: home)));
}

/// Hoja de ajustes, común a todos los dispositivos (con el fondo desenfocado).
void abrirAjustes(BuildContext context, HaHome home, VoidCallback alDesconectar) {
  final invitado = PerfilStore.i.invitado;
  final d = DispositivoStore.i;
  abrirHoja<void>(context, builder: (hoja) {
    Widget opcion(IconData icono, String titulo, String? subtitulo, VoidCallback onTap) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icono, color: AureColors.dorado),
          title: Text(titulo, style: sans(16, weight: FontWeight.w500)),
          subtitle: subtitulo == null ? null : Text(subtitulo, style: sans(13, color: AureColors.gris)),
          onTap: onTap,
        );
    final nombreModo = switch (d.modo) {
      ModoDispositivo.movil => t('modo.movil'),
      ModoDispositivo.tablet => t('modo.tablet'),
      ModoDispositivo.pared => '${t('modo.pared')} · ${home.areaName(d.area) ?? ''}',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AsaHoja(),
          const SizedBox(height: 6),
          Text(t('nav.ajustes'), style: serif(28)),
          const SizedBox(height: 6),
          Text(t('ajustes.conectada', {'url': home.baseUrl}), style: sans(14, color: AureColors.gris)),
          const SizedBox(height: 14),
          if (!d.esPared)
            opcion(Icons.person_outline, t('ajustes.preferencias'), t('ajustes.preferenciasSub'), () {
              Navigator.pop(hoja);
              abrirPreferencias(context, home);
            }),
          opcion(Icons.devices_outlined, t('modo.ajuste'), nombreModo, () {
            Navigator.pop(hoja);
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (c) => ModoScreen(home: home, cerrable: true, alTerminar: () => Navigator.of(c).pop()),
            ));
          }),
          if (d.modo == ModoDispositivo.tablet)
            opcion(
              Icons.bedtime_outlined,
              t('modo.reposoTablet'),
              d.reposoEnTablet ? t('modo.activado') : t('modo.desactivado'),
              () {
                d.cambiarReposoEnTablet(!d.reposoEnTablet);
                Navigator.pop(hoja);
              },
            ),
          if (home.esAdmin && !d.esPared)
            opcion(Icons.verified_user_outlined, t('perm.titulo'), t('perm.sub'), () {
              Navigator.pop(hoja);
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistorialPermisos()));
            }),
          opcion(Icons.nights_stay_outlined, t('ajustes.reposo'), t('ajustes.reposoSub'), () {
            Navigator.pop(hoja);
            Reposo.i.mostrar();
          }),
          if (!invitado && !d.esPared)
            opcion(Icons.logout, t('ajustes.desconectar'), null, () {
              Navigator.pop(hoja);
              alDesconectar();
            }),
        ],
      ),
    );
  });
}

/// Los aparatos de la estancia donde está la pantalla de pared.
class EstanciaPanel extends StatelessWidget {
  const EstanciaPanel({super.key, required this.home, required this.area});

  final HaHome home;
  final String area;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        final aparatos = home.inArea(area);
        return ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
          children: [
            Encabezado(home.areaName(area) ?? '', subtitulo: t('modo.estaEstancia')),
            const SizedBox(height: 18),
            if (aparatos.isEmpty)
              Text(t('hab.vacia'), style: sans(14, color: AureColors.gris))
            else
              for (final e in aparatos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DeviceTile(key: ValueKey(e.id), entity: e, home: home),
                ),
          ],
        );
      },
    );
  }
}

/// Estructura principal: en móvil, Auré lista para hablar; en tablet, el panel de la casa.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.home, required this.alDesconectar});

  final HaHome home;
  final VoidCallback alDesconectar;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _pestanaTablet = 0;
  final _paginasTablet = PageController();

  late final VigilanteCasa _vigilante = VigilanteCasa(widget.home);

  @override
  void initState() {
    super.initState();
    Reposo.i.home = widget.home;
    Reposo.i.actividad();
    _vigilante;
    Atajos.escuchar(_atajo);
    PermisosStore.i.conectar(widget.home);
  }

  @override
  void dispose() {
    _paginasTablet.dispose();
    _vigilante.parar();
    Atajos.dejarDeEscuchar();
    PermisosStore.i.desconectar();
    super.dispose();
  }

  /// Acceso directo desde el icono de la app.
  void _atajo(String tipo) {
    if (tipo == 'hablar') return; // la app ya abre lista para hablar
    for (final e in escenasAure) {
      if (e.claveTitulo == tipo) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) activarEscena(context, widget.home, e);
        });
      }
    }
  }

  void _abrirFunciones() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => FuncionesScreen(home: widget.home, alDesconectar: widget.alDesconectar),
        transitionsBuilder: (_, animacion, __, child) {
          final curva = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curva,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curva),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DispositivoStore.i,
      builder: (context, _) => LayoutBuilder(
      builder: (context, c) {
        final d = DispositivoStore.i;
        final esTablet = switch (d.modo) {
          ModoDispositivo.movil => false,
          ModoDispositivo.tablet => c.maxWidth >= 900,
          ModoDispositivo.pared => c.maxWidth >= 700,
        };
        return Stack(
          children: [
            FondoVivo(
              home: widget.home,
              child: esTablet
                  ? _tablet()
                  : TalkView(
                      home: widget.home,
                      alMenu: _abrirFunciones,
                      alPerfil: () => abrirPreferencias(context, widget.home),
                    ),
            ),
            AvisoConexion(home: widget.home, alCambiar: widget.alDesconectar),
            if (d.esPared) Positioned.fill(child: VozPared(home: widget.home)),
            const PermisoOverlay(),
          ],
        );
      },
      ),
    );
  }

  Widget _tablet() {
    final d = DispositivoStore.i;
    final estancia = d.esPared && d.area != null ? d.area : null;
    final opciones = [
      if (estancia != null) widget.home.areaName(estancia) ?? t('modo.pared'),
      t('nav.habitaciones'),
      t('nav.escenas'),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: HousePanel(
                home: widget.home,
                alAjustes: () => abrirAjustes(context, widget.home, widget.alDesconectar),
              ),
            ),
            Container(width: 1, color: AureColors.linea),
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Segmentos(
                            opciones: opciones,
                            indice: _pestanaTablet.clamp(0, opciones.length - 1),
                            alCambiar: (i) {
                              setState(() => _pestanaTablet = i);
                              _paginasTablet.animateToPage(
                                i,
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Pressable(
                          label: t('hablar.boton'),
                          onTap: () => abrirConversacion(context, widget.home),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 20, 0),
                            decoration: BoxDecoration(
                              color: AureColors.panel,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AureColors.dorado.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              children: [
                                const BreathingOrb(size: 40),
                                const SizedBox(width: 8),
                                Text(t('hablar.boton'), style: sans(14, color: AureColors.doradoClaro)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _paginasTablet,
                      onPageChanged: (i) {
                        Tacto.toque();
                        setState(() => _pestanaTablet = i);
                      },
                      children: [
                        if (estancia != null) EstanciaPanel(home: widget.home, area: estancia),
                        RoomsTab(home: widget.home),
                        ScenesTab(home: widget.home),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Funciones de la casa en el móvil: inicio, habitaciones y escenas.
/// La luz del centro de la barra vuelve a Auré.
class FuncionesScreen extends StatefulWidget {
  const FuncionesScreen({super.key, required this.home, required this.alDesconectar});

  final HaHome home;
  final VoidCallback alDesconectar;

  @override
  State<FuncionesScreen> createState() => _FuncionesScreenState();
}

class _FuncionesScreenState extends State<FuncionesScreen> {
  int _pestana = 0;
  final _paginas = PageController();

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _irA(int i) {
    setState(() => _pestana = i);
    _paginas.animateToPage(i, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AureColors.negro,
      body: FondoVivo(
        home: widget.home,
        child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: PageView(
              controller: _paginas,
              onPageChanged: (i) {
                Tacto.toque();
                setState(() => _pestana = i);
              },
              children: [
                HomeTab(home: widget.home, alVerHabitaciones: () => _irA(1)),
                RoomsTab(home: widget.home),
                ScenesTab(home: widget.home),
              ],
            ),
          ),
          AvisoConexion(home: widget.home, alCambiar: widget.alDesconectar),
        ],
      ),
      ),
      bottomNavigationBar: _BarraInferior(
        indice: _pestana,
        alCambiar: _irA,
        alHablar: () => Navigator.of(context).pop(),
        alAjustes: () => abrirAjustes(context, widget.home, widget.alDesconectar),
      ),
    );
  }
}

/// Aviso superior cuando no hay conexión con la casa.
class AvisoConexion extends StatelessWidget {
  const AvisoConexion({super.key, required this.home, required this.alCambiar});

  final HaHome home;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        final visible = home.status != HaStatus.connected;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          left: 16,
          right: 16,
          top: visible ? MediaQuery.paddingOf(context).top + 12 : -120,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: AureColors.panelAlto,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AureColors.linea),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 22, height: 22, child: BreathingOrb(size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      home.status == HaStatus.error
                          ? (home.error ?? t('resumen.sinConexion'))
                          : t('resumen.conectando'),
                      style: sans(14),
                    ),
                  ),
                  if (home.status == HaStatus.error)
                    TextButton(
                      onPressed: alCambiar,
                      child: Text(t('aviso.cambiar'), style: sans(14, color: AureColors.dorado)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Barra inferior del móvil con la luz de Auré en el centro.
class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.indice,
    required this.alCambiar,
    required this.alHablar,
    required this.alAjustes,
  });

  final int indice;
  final ValueChanged<int> alCambiar;
  final VoidCallback alHablar;
  final VoidCallback alAjustes;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AureColors.negro,
        border: Border(top: BorderSide(color: AureColors.linea)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              _item(0, AureIcono.casa, t('nav.inicio')),
              _item(1, AureIcono.habitaciones, t('nav.habitaciones')),
              Expanded(
                child: Center(
                  child: Pressable(
                    label: t('hablar.boton'),
                    onTap: alHablar,
                    child: const BreathingOrb(size: 64),
                  ),
                ),
              ),
              _item(2, AureIcono.escenas, t('nav.escenas')),
              Expanded(
                child: InkResponse(
                  onTap: alAjustes,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AureIcon(AureIcono.ajustes, color: AureColors.grisOscuro),
                      const SizedBox(height: 4),
                      Text(t('nav.ajustes'), style: sans(11, color: AureColors.grisOscuro)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, AureIcono icono, String texto) {
    final activo = indice == i;
    final color = activo ? AureColors.dorado : AureColors.grisOscuro;
    return Expanded(
      child: InkResponse(
        onTap: () {
          Tacto.toque();
          alCambiar(i);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AureIcon(icono, color: color, relleno: activo),
            const SizedBox(height: 4),
            Text(texto, style: sans(11, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Selector de pestañas en forma de píldoras.
class Segmentos extends StatelessWidget {
  const Segmentos({super.key, required this.opciones, required this.indice, required this.alCambiar});

  final List<String> opciones;
  final int indice;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AureColors.panel,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AureColors.linea),
      ),
      child: Row(
        children: [
          for (var i = 0; i < opciones.length; i++)
            Expanded(
              child: Pressable(
                label: opciones[i],
                onTap: () => alCambiar(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: indice == i ? AureColors.dorado : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    opciones[i],
                    style: sans(
                      14,
                      color: indice == i ? AureColors.negro : AureColors.gris,
                      weight: indice == i ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
