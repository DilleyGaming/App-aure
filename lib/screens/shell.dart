import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../actualizar.dart';
import '../alertas.dart';
import '../ha/ha_home.dart';
import '../atajos.dart';
import '../casas.dart';
import '../dispositivo.dart';
import '../i18n.dart';
import '../permisos.dart';
import '../perfil.dart';
import '../invitados.dart';
import '../pin.dart';
import '../reposo.dart';
import '../resumen_manana.dart';
import '../sesion.dart';
import '../widget_casa.dart';
import '../theme.dart';
import '../widgets/breathing_orb.dart';
import '../widgets/aure_icon.dart';
import '../widgets/common.dart';
import '../widgets/device_tile.dart';
import '../widgets/voz_pared.dart';
import '../widgets/permiso_card.dart';
import '../widgets/fondo.dart';
import '../widgets/hoja.dart';
import '../widgets/avisos.dart';
import '../widgets/pulsar_hablar.dart';
import 'home.dart';
import 'modo.dart';
import 'preferences.dart';
import 'rooms.dart';
import 'scenes.dart';
import 'casa_extra.dart';
import 'casas_vista.dart';
import 'instalador.dart';
import 'talk.dart';

void abrirPreferencias(BuildContext context, HaHome home) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PreferencesScreen(home: home)));
}

/// Hoja de ajustes, común a todos los dispositivos (con el fondo desenfocado).
Future<void> abrirAjustes(BuildContext context, HaHome home, VoidCallback alDesconectar) async {
  final invitado = PerfilStore.i.invitado;
  final d = DispositivoStore.i;
  // En la pantalla de pared, los ajustes pueden ir protegidos con PIN.
  if (d.esPared && !await PinPared.comprobar(context)) return;
  if (!context.mounted) return;
  final tienePin = await PinPared.tienePin();
  if (!context.mounted) return;
  await abrirHoja<void>(context, builder: (hoja) {
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
      child: SingleChildScrollView(
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
          if (!invitado && !d.esPared)
            opcion(
              Icons.home_work_outlined,
              t('casas.titulo'),
              CasasStore.i.casas.length < 2
                  ? t('casas.una')
                  : t('casas.sub', {'n': '${CasasStore.i.casas.length}', 'c': CasasStore.i.actual?.nombre ?? ''}),
              () {
                Navigator.pop(hoja);
                abrirCasas(context);
              },
            ),
          if (!invitado && !d.esPared) ...[
            opcion(Icons.qr_code_2, t('qr.otroMovil'), t('qr.otroMovilSub'), () {
              Navigator.pop(hoja);
              mostrarQrConexion(context, home);
            }),
            opcion(
              Icons.public,
              t('dir.titulo'),
              home.direcciones.length < 2
                  ? t('dir.sinFuera')
                  : (home.usandoFuera ? t('dir.usandoFuera') : t('dir.usandoCasa')),
              () {
                Navigator.pop(hoja);
                editarDirecciones(context, home);
              },
            ),
          ],
          if (home.esAdmin && !d.esPared)
            opcion(Icons.verified_user_outlined, t('perm.titulo'), t('perm.sub'), () {
              Navigator.pop(hoja);
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistorialPermisos()));
            }),
          if (home.esAdmin && !invitado && !d.esPared)
            opcion(Icons.badge_outlined, t('inv.titulo'), t('inv.sub'), () {
              Navigator.pop(hoja);
              abrirInvitados(context, home);
            }),
          if (!invitado)
            opcion(Icons.history, t('historial.titulo'), t('historial.sub'), () {
              Navigator.pop(hoja);
              abrirHistorial(context, home);
            }),
          if (d.esPared)
            opcion(Icons.lock_outline, t('pin.titulo'), tienePin ? t('pin.activado') : t('pin.sinPoner'), () {
              Navigator.pop(hoja);
              PinPared.configurar(context);
            }),
          if (home.esAdmin && !invitado)
            opcion(Icons.construction_outlined, t('inst.titulo'), t('inst.sub'), () {
              Navigator.pop(hoja);
              abrirInstalador(context, home);
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
      ),
    );
  });
}

/// Código QR para conectar otro móvil a esta casa (solo lleva las direcciones).
void mostrarQrConexion(BuildContext context, HaHome home) {
  final fuera = home.direcciones.length > 1 ? home.direcciones[1] : null;
  abrirHoja<void>(context, builder: (hoja) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AsaHoja(),
          const SizedBox(height: 6),
          Text(t('qr.otroMovil'), style: serif(26), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AureColors.crema, borderRadius: BorderRadius.circular(22)),
            child: QrImageView(
              data: Sesion.codigoQr(home.direcciones.first, fuera),
              size: 220,
              backgroundColor: AureColors.crema,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AureColors.negro),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AureColors.negro,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('qr.explica'), textAlign: TextAlign.center, style: sans(14, color: AureColors.gris)),
          if (fuera == null) ...[
            const SizedBox(height: 10),
            Text(t('qr.sinFuera'), textAlign: TextAlign.center, style: sans(13, color: AureColors.dorado)),
          ],
        ],
      ),
    );
  });
}

/// Cambiar la dirección de casa y la de fuera.
Future<void> editarDirecciones(BuildContext context, HaHome home) async {
  final casa = TextEditingController(text: home.direcciones.first);
  final fuera = TextEditingController(text: home.direcciones.length > 1 ? home.direcciones[1] : '');
  InputDecoration campo(String texto, [String? ayuda]) => InputDecoration(
        labelText: texto,
        helperText: ayuda,
        helperMaxLines: 2,
        helperStyle: sans(12, color: AureColors.grisOscuro),
        labelStyle: sans(14, color: AureColors.gris),
        filled: true,
        fillColor: AureColors.panel,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );
  final guardar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AureColors.panelAlto,
      title: Text(t('dir.titulo'), style: serif(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: casa, style: sans(15), keyboardType: TextInputType.url, decoration: campo(t('conectar.direccion'))),
          const SizedBox(height: 14),
          TextField(
            controller: fuera,
            style: sans(15),
            keyboardType: TextInputType.url,
            decoration: campo(t('conectar.fuera'), t('conectar.fueraAyuda')),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('comun.cancelar'), style: sans(14, color: AureColors.gris))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t('comun.guardar'), style: sans(14, color: AureColors.dorado))),
      ],
    ),
  );
  if (guardar != true) return;
  final c1 = Sesion.limpiar(casa.text);
  final c2 = Sesion.limpiar(fuera.text);
  if (c1.isEmpty) return;
  await Sesion.guardarDirecciones(c1, c2);
  home.direcciones
    ..clear()
    ..add(c1);
  if (c2.isNotEmpty) home.direcciones.add(c2);
  if (context.mounted) Avisos.mostrar(context, t('dir.guardadas'), icono: Icons.public);
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

  // Móvil: Auré y, deslizando, Inicio, Habitaciones y Escenas.
  int _paginaMovil = 0;
  final _paginasMovil = PageController();

  late final VigilanteCasa _vigilante = VigilanteCasa(widget.home);

  @override
  void initState() {
    super.initState();
    Reposo.i.home = widget.home;
    Reposo.i.actividad();
    _vigilante;
    Atajos.escuchar(_atajo);
    WidgetCasa.escuchar(_atajo);
    PermisosStore.i.conectar(widget.home);
    // Cuando llaman al timbre: aviso con la cámara de la entrada en directo.
    VigilanteCasa.alLlamar = (timbre) {
      Reposo.i.despertar();
      final c = Reposo.i.navigatorKey.currentContext ?? context;
      if (c.mounted) abrirTimbre(c, widget.home, timbre);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ResumenManana.comprobar(context, widget.home);
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) Actualizar.comprobar(context);
      });
      // Los invitados caducados se borran solos de la casa.
      Future<void>.delayed(const Duration(seconds: 12), () {
        if (mounted) widget.home.limpiarInvitados();
      });
    });
  }

  @override
  void dispose() {
    _paginasTablet.dispose();
    _paginasMovil.dispose();
    _vigilante.parar();
    Atajos.dejarDeEscuchar();
    WidgetCasa.dejarDeEscuchar();
    VigilanteCasa.alLlamar = null;
    PermisosStore.i.desconectar();
    super.dispose();
  }

  /// Acceso directo desde el icono de la app o desde el widget de la pantalla de inicio.
  void _atajo(String tipo) {
    if (tipo == 'hablar') {
      // Vuelve a Auré, lista para hablar.
      if (_paginasMovil.hasClients) _irMovil(0);
      return;
    }
    for (final e in escenasAure) {
      if (e.claveTitulo == tipo) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) activarEscena(context, widget.home, e);
        });
      }
    }
  }

  void _irMovil(int i) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_paginasMovil.hasClients) return;
    final distancia = (_paginasMovil.page ?? _paginaMovil.toDouble()) - i;
    if (distancia.abs() > 1.5) {
      _paginasMovil.jumpToPage(i);
    } else {
      _paginasMovil.animateToPage(i, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
    setState(() => _paginaMovil = i);
  }

  Widget _conMargen(Widget hijo) => SafeArea(bottom: false, child: hijo);

  /// Móvil: se pasa de Auré a la casa deslizando el dedo; la luz del centro de la barra vuelve a Auré.
  Widget _movil() {
    return PopScope(
      canPop: _paginaMovil == 0,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _irMovil(0);
      },
      // Sin Scaffold con barra: así cada página respeta la barra de gestos o botones de Android.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _paginasMovil,
              onPageChanged: (i) {
                Tacto.toque();
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _paginaMovil = i);
              },
              children: [
                _MantenerViva(
                  child: TalkView(
                    home: widget.home,
                    alMenu: () => _irMovil(1),
                    alPerfil: () => abrirPreferencias(context, widget.home),
                  ),
                ),
                _conMargen(HomeTab(home: widget.home, alVerHabitaciones: () => _irMovil(2))),
                _conMargen(RoomsTab(home: widget.home)),
                _conMargen(ScenesTab(home: widget.home)),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _paginaMovil == 0
                ? const SizedBox(width: double.infinity)
                : _BarraInferior(
                    home: widget.home,
                    indice: _paginaMovil - 1,
                    alCambiar: (i) => _irMovil(i + 1),
                    alHablar: () => _irMovil(0),
                    alAjustes: () => abrirAjustes(context, widget.home, widget.alDesconectar),
                  ),
          ),
        ],
        ),
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
              child: esTablet ? _tablet() : _movil(),
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
                        PulsarParaHablar(
                          home: widget.home,
                          label: t('hablar.boton'),
                          alTocar: () => abrirConversacion(context, widget.home),
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

/// Mantiene la conversación aunque deslices a otra página.
class _MantenerViva extends StatefulWidget {
  const _MantenerViva({required this.child});

  final Widget child;

  @override
  State<_MantenerViva> createState() => _MantenerVivaState();
}

class _MantenerVivaState extends State<_MantenerViva> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
    required this.home,
    required this.indice,
    required this.alCambiar,
    required this.alHablar,
    required this.alAjustes,
  });

  final HaHome home;
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
                  // Toque: volver a Auré. Mantener pulsado: hablarle sin salir de aquí.
                  child: PulsarParaHablar(
                    home: home,
                    label: t('hablar.boton'),
                    alTocar: alHablar,
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
