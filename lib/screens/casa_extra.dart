import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/hoja.dart';

// ---------------------------------------------------------------------------
// Quién está en casa
// ---------------------------------------------------------------------------

/// Fila con las personas de la casa: dentro (aro dorado) o fuera (atenuadas).
class QuienEnCasa extends StatelessWidget {
  const QuienEnCasa({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    final personas = home.personasEstado;
    if (personas.isEmpty) return const SizedBox.shrink();
    final dentro = personas.where((p) => p.state == 'home').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dentro == 0 ? t('casa.nadie') : t('casa.dentro', {'n': '$dentro'}),
          style: sans(13, color: AureColors.dorado, spacing: 0.5),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: personas.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final p = personas[i];
              final enCasa = p.state == 'home';
              final nombre = p.name.split(' ').first;
              final donde = enCasa
                  ? t('casa.enCasa')
                  : (p.state == 'not_home' || p.state == 'unknown' ? t('casa.fuera') : p.state);
              return Semantics(
                label: '$nombre, $donde',
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: enCasa ? AureColors.panelAlto : AureColors.panel,
                        border: Border.all(
                          color: enCasa ? AureColors.dorado : AureColors.linea,
                          width: enCasa ? 1.6 : 1,
                        ),
                        boxShadow: enCasa
                            ? [BoxShadow(color: AureColors.dorado.withValues(alpha: 0.25), blurRadius: 14)]
                            : null,
                      ),
                      child: Text(
                        nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
                        style: serif(20, color: enCasa ? AureColors.doradoClaro : AureColors.grisOscuro),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      nombre,
                      style: sans(12, color: enCasa ? AureColors.crema : AureColors.grisOscuro),
                    ),
                    Text(donde, style: sans(10, color: AureColors.grisOscuro)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Accesos rápidos de inicio: música, cámaras e historial
// ---------------------------------------------------------------------------

class AccesosCasa extends StatelessWidget {
  const AccesosCasa({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    final hayCamaras = home.camaras.isNotEmpty;
    final hayMusica = home.altavoces.isNotEmpty;
    Widget acceso(IconData icono, String texto, VoidCallback onTap) => Expanded(
          child: Pressable(
            label: texto,
            onTap: () {
              Tacto.toque();
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              decoration: aureCard(radius: 18),
              child: Column(
                children: [
                  Icon(icono, color: AureColors.dorado, size: 22),
                  const SizedBox(height: 8),
                  Text(texto, style: sans(13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        if (hayMusica) ...[
          acceso(Icons.queue_music_outlined, t('musica.titulo'), () => abrirMusica(context, home)),
          const SizedBox(width: 10),
        ],
        if (hayCamaras) ...[
          acceso(Icons.videocam_outlined, t('camaras.titulo'), () => abrirCamaras(context, home)),
          const SizedBox(width: 10),
        ],
        acceso(Icons.history, t('historial.titulo'), () => abrirHistorial(context, home)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Música por estancias
// ---------------------------------------------------------------------------

void abrirMusica(BuildContext context, HaHome home) {
  abrirHoja<void>(context, builder: (hoja) {
    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        final altavoces = home.altavoces;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AsaHoja(),
              const SizedBox(height: 6),
              Text(t('musica.titulo'), style: serif(26)),
              const SizedBox(height: 4),
              Text(t('musica.pista'), style: sans(13, color: AureColors.gris)),
              const SizedBox(height: 16),
              if (altavoces.isEmpty)
                Text(t('musica.ninguno'), style: sans(15, color: AureColors.gris))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: altavoces.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _Altavoz(home: home, e: altavoces[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  });
}

class _Altavoz extends StatelessWidget {
  const _Altavoz({required this.home, required this.e});

  final HaHome home;
  final HaEntity e;

  @override
  Widget build(BuildContext context) {
    final sonando = e.state == 'playing';
    final titulo = e.attributes['media_title']?.toString();
    final artista = e.attributes['media_artist']?.toString();
    final volumen = (e.attributes['volume_level'] as num?)?.toDouble();
    final area = home.areaName(home.areaOf(e.id));
    final que = titulo == null
        ? (sonando ? t('musica.sonando') : (e.state == 'off' ? t('musica.apagado') : t('musica.enPausa')))
        : (artista == null || artista.isEmpty ? titulo : '$titulo · $artista');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
      decoration: aureCard(active: sonando, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(area ?? e.name, style: sans(16, weight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(que, style: sans(13, color: sonando ? AureColors.doradoClaro : AureColors.gris), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                tooltip: sonando ? t('musica.pausar') : t('musica.reproducir'),
                onPressed: () {
                  Tacto.toque();
                  home.service('media_player', 'media_play_pause', {'entity_id': e.id});
                },
                icon: Icon(sonando ? Icons.pause_circle_outline : Icons.play_circle_outline, color: AureColors.dorado, size: 32),
              ),
              IconButton(
                tooltip: t('musica.siguiente'),
                onPressed: () {
                  Tacto.toque();
                  home.service('media_player', 'media_next_track', {'entity_id': e.id});
                },
                icon: const Icon(Icons.skip_next_outlined, color: AureColors.gris),
              ),
            ],
          ),
          if (volumen != null)
            Row(
              children: [
                const Icon(Icons.volume_down_outlined, size: 18, color: AureColors.grisOscuro),
                Expanded(child: _Volumen(home: home, entidad: e.id, valor: volumen)),
                const Icon(Icons.volume_up_outlined, size: 18, color: AureColors.grisOscuro),
              ],
            ),
        ],
      ),
    );
  }
}

/// Volumen que se mueve con el dedo y se envía al soltar.
class _Volumen extends StatefulWidget {
  const _Volumen({required this.home, required this.entidad, required this.valor});

  final HaHome home;
  final String entidad;
  final double valor;

  @override
  State<_Volumen> createState() => _VolumenState();
}

class _VolumenState extends State<_Volumen> {
  double? _arrastrando;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: (_arrastrando ?? widget.valor).clamp(0.0, 1.0),
      onChanged: (v) => setState(() => _arrastrando = v),
      onChangeEnd: (v) {
        widget.home.service('media_player', 'volume_set', {'entity_id': widget.entidad, 'volume_level': v});
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _arrastrando = null);
        });
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cámaras
// ---------------------------------------------------------------------------

/// Imagen de una cámara que se va refrescando sola.
class CamaraVista extends StatefulWidget {
  const CamaraVista({super.key, required this.home, required this.camara, this.cada = const Duration(seconds: 3)});

  final HaHome home;
  final String camara;
  final Duration cada;

  @override
  State<CamaraVista> createState() => _CamaraVistaState();
}

class _CamaraVistaState extends State<CamaraVista> {
  Uint8List? _foto;
  Timer? _timer;
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    _pedir();
    _timer = Timer.periodic(widget.cada, (_) => _pedir());
  }

  Future<void> _pedir() async {
    if (_pidiendo) return;
    _pidiendo = true;
    final foto = await widget.home.fotoCamara(widget.camara);
    _pidiendo = false;
    if (mounted && foto != null) setState(() => _foto = foto);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foto = _foto;
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: foto == null
          ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 1.5))
          : Image.memory(foto, fit: BoxFit.cover, gaplessPlayback: true, width: double.infinity, height: double.infinity),
    );
  }
}

void abrirCamaras(BuildContext context, HaHome home) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CamarasScreen(home: home)));
}

class CamarasScreen extends StatelessWidget {
  const CamarasScreen({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    final camaras = home.camaras;
    final ancho = MediaQuery.sizeOf(context).width;
    final columnas = ancho > 900 ? 3 : (ancho > 560 ? 2 : 1);
    return Scaffold(
      backgroundColor: AureColors.negro,
      appBar: AppBar(
        backgroundColor: AureColors.negro,
        surfaceTintColor: Colors.transparent,
        title: Text(t('camaras.titulo'), style: serif(24)),
      ),
      body: camaras.isEmpty
          ? Center(child: Text(t('camaras.ninguna'), style: sans(15, color: AureColors.gris)))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnas,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 16 / 10.5,
              ),
              itemCount: camaras.length,
              itemBuilder: (context, i) {
                final c = camaras[i];
                return Pressable(
                  label: c.name,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => _CamaraGrande(home: home, camara: c)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CamaraVista(home: home, camara: c.id),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 20, 14, 10),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Text(
                              home.areaName(home.areaOf(c.id)) ?? c.name,
                              style: sans(14, color: AureColors.crema, weight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CamaraGrande extends StatelessWidget {
  const _CamaraGrande({required this.home, required this.camara});

  final HaHome home;
  final HaEntity camara;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Text(home.areaName(home.areaOf(camara.id)) ?? camara.name, style: serif(22)),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: InteractiveViewer(
            maxScale: 4,
            child: CamaraVista(home: home, camara: camara.id, cada: const Duration(seconds: 1)),
          ),
        ),
      ),
    );
  }
}

/// Aviso de timbre: quién llama, con la cámara de la entrada en directo.
void abrirTimbre(BuildContext context, HaHome home, String? timbre) {
  final camara = home.camaraPara(timbre);
  abrirHoja<void>(context, builder: (hoja) {
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
              const Icon(Icons.doorbell_outlined, color: AureColors.dorado, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(t('timbre.llaman'), style: serif(26))),
            ],
          ),
          const SizedBox(height: 4),
          Text(hora(DateTime.now()), style: sans(13, color: AureColors.gris)),
          const SizedBox(height: 16),
          if (camara != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CamaraVista(home: home, camara: camara.id, cada: const Duration(seconds: 1)),
              ),
            )
          else
            Text(t('timbre.sinCamara'), style: sans(14, color: AureColors.gris)),
        ],
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Historial de la casa
// ---------------------------------------------------------------------------

void abrirHistorial(BuildContext context, HaHome home) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistorialScreen(home: home)));
}

class _Suceso {
  const _Suceso(this.cuando, this.icono, this.texto);

  final DateTime cuando;
  final IconData icono;
  final String texto;
}

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, required this.home});

  final HaHome home;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  List<_Suceso>? _sucesos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final datos = await widget.home.historial(DateTime.now().subtract(const Duration(hours: 48)));
    final lista = <_Suceso>[];
    for (final d in datos) {
      final s = _traducir(d);
      if (s != null) lista.add(s);
    }
    lista.sort((a, b) => b.cuando.compareTo(a.cuando));
    if (mounted) setState(() => _sucesos = lista);
  }

  /// Convierte una línea del registro en una frase de Auré (solo lo que importa).
  _Suceso? _traducir(Map<String, dynamic> d) {
    final id = d['entity_id']?.toString();
    final estado = d['state']?.toString();
    final cuando = DateTime.tryParse(d['when']?.toString() ?? '')?.toLocal();
    if (id == null || cuando == null) return null;
    final dominio = id.split('.').first;
    final entidad = widget.home.entities[id];
    final nombre = (d['name'] ?? entidad?.name ?? id).toString();
    final clase = entidad?.attributes['device_class']?.toString();
    switch (dominio) {
      case 'person':
        if (estado == 'home') return _Suceso(cuando, Icons.login, t('hist.llega', {'n': nombre.split(' ').first}));
        if (estado == 'not_home') return _Suceso(cuando, Icons.logout, t('hist.sale', {'n': nombre.split(' ').first}));
        return null;
      case 'lock':
        if (estado == 'unlocked') return _Suceso(cuando, Icons.lock_open, t('hist.abreCerradura', {'n': nombre}));
        if (estado == 'locked') return _Suceso(cuando, Icons.lock_outline, t('hist.cierraCerradura', {'n': nombre}));
        return null;
      case 'alarm_control_panel':
        if (estado == 'triggered') return _Suceso(cuando, Icons.notification_important, t('hist.alarmaSalta'));
        if (estado != null && estado.startsWith('armed')) return _Suceso(cuando, Icons.shield_outlined, t('hist.alarmaOn'));
        if (estado == 'disarmed') return _Suceso(cuando, Icons.shield_moon_outlined, t('hist.alarmaOff'));
        return null;
      case 'binary_sensor':
        if (estado != 'on') {
          if (estado == 'off' && const {'door', 'garage_door'}.contains(clase)) {
            return _Suceso(cuando, Icons.door_front_door_outlined, t('hist.cierra', {'n': nombre}));
          }
          return null;
        }
        return switch (clase) {
          'door' || 'garage_door' || 'opening' => _Suceso(cuando, Icons.door_front_door_outlined, t('hist.abre', {'n': nombre})),
          'window' => _Suceso(cuando, Icons.window_outlined, t('hist.abre', {'n': nombre})),
          'moisture' => _Suceso(cuando, Icons.water_drop_outlined, t('alerta.agua', {'n': nombre})),
          'smoke' => _Suceso(cuando, Icons.local_fire_department_outlined, t('alerta.humo', {'n': nombre})),
          'gas' || 'carbon_monoxide' => _Suceso(cuando, Icons.warning_amber_rounded, t('alerta.gas', {'n': nombre})),
          _ => null,
        };
      case 'event':
        if (clase == 'doorbell') return _Suceso(cuando, Icons.doorbell_outlined, t('timbre.llaman'));
        return null;
      case 'scene':
        return _Suceso(cuando, Icons.auto_awesome_outlined, t('hist.escena', {'n': nombre}));
      case 'cover':
        if (estado == 'open') return _Suceso(cuando, Icons.blinds, t('hist.subePersiana', {'n': nombre}));
        if (estado == 'closed') return _Suceso(cuando, Icons.blinds_closed, t('hist.bajaPersiana', {'n': nombre}));
        return null;
      default:
        return null;
    }
  }

  String _dia(DateTime d) {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    if (d.year == hoy.year && d.month == hoy.month && d.day == hoy.day) return t('hist.hoy');
    if (d.year == ayer.year && d.month == ayer.month && d.day == ayer.day) return t('hist.ayer');
    return fechaLarga(d);
  }

  @override
  Widget build(BuildContext context) {
    final sucesos = _sucesos;
    final filas = <Widget>[];
    String? diaAnterior;
    for (final s in sucesos ?? const <_Suceso>[]) {
      final dia = _dia(s.cuando);
      if (dia != diaAnterior) {
        filas.add(Padding(
          padding: EdgeInsets.only(top: diaAnterior == null ? 4 : 22, bottom: 10),
          child: Text(dia, style: serif(20, color: AureColors.doradoClaro)),
        ));
        diaAnterior = dia;
      }
      filas.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            SizedBox(width: 50, child: Text(hora(s.cuando), style: sans(13, color: AureColors.gris))),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AureColors.panel, border: Border.all(color: AureColors.linea)),
              child: Icon(s.icono, size: 17, color: AureColors.dorado),
            ),
            const SizedBox(width: 12),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(s.texto, style: sans(15)),
            )),
          ],
        ),
      ));
    }
    return Scaffold(
      backgroundColor: AureColors.negro,
      appBar: AppBar(
        backgroundColor: AureColors.negro,
        surfaceTintColor: Colors.transparent,
        title: Text(t('historial.titulo'), style: serif(24)),
      ),
      body: sucesos == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 1.5))
          : RefreshIndicator(
              onRefresh: _cargar,
              color: AureColors.dorado,
              child: sucesos.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(child: Text(t('hist.vacio'), style: sans(15, color: AureColors.gris))),
                      ],
                    )
                  : ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 40), children: filas),
            ),
    );
  }
}
