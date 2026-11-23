import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/avisos.dart';
import '../widgets/common.dart';
import 'scenes.dart';

/// Cómo quedará cada aparato dentro de la escena.
class _Ajuste {
  _Ajuste.desde(HaEntity e)
      : encendido = e.isOn || e.state == 'playing',
        brillo = e.isOn ? e.brightness : 0.6,
        abierta = e.state != 'closed',
        temperatura = (e.attributes['temperature'] as num?)?.toDouble() ?? 21,
        modoClima = e.state == 'off' ? _primerModo(e) : e.state;

  bool encendido;
  double brillo;
  bool abierta;
  double temperatura;
  String modoClima;

  static String _primerModo(HaEntity e) {
    final modos = e.attributes['hvac_modes'];
    if (modos is List) {
      for (final m in modos) {
        if (m != 'off') return m.toString();
      }
    }
    return 'heat';
  }

  Map<String, dynamic> paraHomeAssistant(HaEntity e) {
    switch (e.domain) {
      case 'light':
        return {
          'state': encendido ? 'on' : 'off',
          if (encendido) 'brightness': (brillo * 255).round(),
        };
      case 'cover':
        return {'state': abierta ? 'open' : 'closed'};
      case 'climate':
        return {
          'state': encendido ? modoClima : 'off',
          if (encendido && e.attributes['temperature'] is num) 'temperature': temperatura,
        };
      case 'media_player':
        return {'state': encendido ? 'playing' : 'paused'};
      default:
        return {'state': encendido ? 'on' : 'off'};
    }
  }
}

/// Pantalla para crear una escena propia.
class SceneEditor extends StatefulWidget {
  const SceneEditor({super.key, required this.home});

  final HaHome home;

  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  final _nombre = TextEditingController();
  final Map<String, _Ajuste> _seleccion = {};
  String _icono = iconosEscena.first.$1;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = t('editor.faltaNombre'));
      return;
    }
    if (_seleccion.isEmpty) {
      setState(() => _error = t('editor.faltaAparato'));
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    final entidades = <String, Map<String, dynamic>>{
      for (final entrada in _seleccion.entries)
        if (widget.home.entities[entrada.key] != null)
          entrada.key: entrada.value.paraHomeAssistant(widget.home.entities[entrada.key]!),
    };
    final error = await widget.home.guardarEscena(nombre, _icono, entidades);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _guardando = false;
        _error = error;
      });
      return;
    }
    Tacto.confirmar();
    Avisos.mostrar(context, t('editor.guardada'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final aparatos = widget.home.devices;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AureColors.negro,
        surfaceTintColor: Colors.transparent,
        title: Text(t('editor.titulo'), style: serif(24)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                    children: [
                      TextField(
                        controller: _nombre,
                        style: serif(22),
                        decoration: InputDecoration(
                          hintText: t('editor.nombre'),
                          hintStyle: serif(22, color: AureColors.grisOscuro),
                          filled: true,
                          fillColor: AureColors.panel,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AureColors.linea),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AureColors.dorado),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(t('editor.icono'), style: sans(14, color: AureColors.gris)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final par in iconosEscena)
                            Pressable(
                              onTap: () => setState(() => _icono = par.$1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _icono == par.$1 ? AureColors.dorado : AureColors.panel,
                                  border: Border.all(color: AureColors.linea),
                                ),
                                child: Icon(
                                  par.$2,
                                  color: _icono == par.$1 ? AureColors.negro : AureColors.dorado,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(t('editor.aparatos'), style: serif(22)),
                      const SizedBox(height: 4),
                      Text(t('editor.ayuda'), style: sans(13, color: AureColors.gris)),
                      const SizedBox(height: 14),
                      for (final e in aparatos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tarjeta(e),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                  child: Column(
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(_error!, style: sans(14, color: const Color(0xFFE8A87C))),
                        ),
                      Pressable(
                        label: t('comun.guardar'),
                        onTap: _guardando ? null : _guardar,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 54,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _guardando ? AureColors.panelAlto : AureColors.dorado,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            t('comun.guardar'),
                            style: sans(16, weight: FontWeight.w600, color: AureColors.negro),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(HaEntity e) {
    final ajuste = _seleccion[e.id];
    final incluido = ajuste != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: aureCard(active: incluido, radius: 18),
      child: Column(
        children: [
          Row(
            children: [
              Icon(_iconoDe(e), color: incluido ? AureColors.dorado : AureColors.grisOscuro, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(e.name, style: sans(15), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              AureToggle(
                value: incluido,
                onChanged: (v) => setState(() {
                  if (v) {
                    _seleccion[e.id] = _Ajuste.desde(e);
                  } else {
                    _seleccion.remove(e.id);
                  }
                }),
              ),
            ],
          ),
          if (ajuste != null) ...[
            const SizedBox(height: 8),
            _controles(e, ajuste),
          ],
        ],
      ),
    );
  }

  IconData _iconoDe(HaEntity e) => switch (e.domain) {
        'light' => Icons.lightbulb_outline,
        'cover' => Icons.view_day_outlined,
        'climate' => Icons.thermostat,
        'media_player' => Icons.music_note_outlined,
        'fan' => Icons.air,
        _ => Icons.power_settings_new,
      };

  Widget _controles(HaEntity e, _Ajuste a) {
    switch (e.domain) {
      case 'cover':
        return _opciones([
          (t('disp.abierta'), a.abierta, () => setState(() => a.abierta = true)),
          (t('disp.cerrada'), !a.abierta, () => setState(() => a.abierta = false)),
        ]);
      case 'media_player':
        return _opciones([
          (t('musica.reproducir'), a.encendido, () => setState(() => a.encendido = true)),
          (t('musica.pausa'), !a.encendido, () => setState(() => a.encendido = false)),
        ]);
      case 'climate':
        return Column(
          children: [
            _opciones([
              (t('disp.encendido'), a.encendido, () => setState(() => a.encendido = true)),
              (t('disp.apagado'), !a.encendido, () => setState(() => a.encendido = false)),
            ]),
            if (a.encendido && e.attributes['temperature'] is num)
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => a.temperatura -= 0.5),
                    icon: const Icon(Icons.remove, color: AureColors.dorado),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('${grados(a.temperatura)}°', style: serif(26, color: AureColors.doradoClaro)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => a.temperatura += 0.5),
                    icon: const Icon(Icons.add, color: AureColors.dorado),
                  ),
                ],
              ),
          ],
        );
      case 'light':
        return Column(
          children: [
            _opciones([
              (t('disp.encendida'), a.encendido, () => setState(() => a.encendido = true)),
              (t('disp.apagada'), !a.encendido, () => setState(() => a.encendido = false)),
            ]),
            if (a.encendido)
              Slider(
                value: a.brillo.clamp(0.01, 1.0),
                min: 0.01,
                max: 1,
                onChanged: (v) => setState(() => a.brillo = v),
              ),
          ],
        );
      default:
        return _opciones([
          (t('disp.encendido'), a.encendido, () => setState(() => a.encendido = true)),
          (t('disp.apagado'), !a.encendido, () => setState(() => a.encendido = false)),
        ]);
    }
  }

  Widget _opciones(List<(String, bool, VoidCallback)> opciones) {
    return Row(
      children: [
        for (var i = 0; i < opciones.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              label: opciones[i].$1,
              onTap: opciones[i].$3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: opciones[i].$2 ? AureColors.dorado : AureColors.panelAlto,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  opciones[i].$1,
                  style: sans(14, color: opciones[i].$2 ? AureColors.negro : AureColors.gris),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
