import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import 'aure_icon.dart';
import 'climate_dial.dart';
import 'common.dart';

/// Tarjeta de un aparato, adaptada a su tipo.
/// Las luces se regulan deslizando el dedo sobre la tarjeta y lanzan un destello al encenderse.
class DeviceTile extends StatefulWidget {
  const DeviceTile({super.key, required this.entity, required this.home});

  final HaEntity entity;
  final HaHome home;

  @override
  State<DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<DeviceTile> with SingleTickerProviderStateMixin {
  late final AnimationController _destello = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  double? _brillo;
  double? _volumen;
  double _anchoTarjeta = 1;

  HaHome get _home => widget.home;

  @override
  void didUpdateWidget(covariant DeviceTile old) {
    super.didUpdateWidget(old);
    final antes = _activo(old.entity), ahora = _activo(widget.entity);
    if (!antes && ahora) _destello.forward(from: 0);
  }

  @override
  void dispose() {
    _destello.dispose();
    super.dispose();
  }

  bool _activo(HaEntity e) =>
      e.isOn || e.state == 'open' || e.state == 'playing' || (e.domain == 'climate' && e.state != 'off');

  @override
  Widget build(BuildContext context) {
    final e = widget.entity;
    final activo = _activo(e);
    return LayoutBuilder(
      builder: (context, c) {
        _anchoTarjeta = c.maxWidth;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          decoration: aureCard(active: activo),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Relleno del brillo (solo luces encendidas)
                if (e.domain == 'light' && e.isOn)
                  Positioned.fill(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AnimatedFractionallySizedBox(
                        duration: Duration(milliseconds: _brillo == null ? 400 : 0),
                        curve: Curves.easeOut,
                        widthFactor: (_brillo ?? e.brightness).clamp(0.02, 1.0),
                        heightFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AureColors.dorado.withValues(alpha: 0.05),
                              AureColors.dorado.withValues(alpha: 0.16),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Destello dorado al encender
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _destello,
                      builder: (context, _) {
                        final v = _destello.value;
                        if (v == 0 || v == 1) return const SizedBox.shrink();
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const AlignmentDirectional(0.85, 0).resolve(Directionality.of(context)),
                              radius: 0.2 + 2.2 * Curves.easeOut.transform(v),
                              colors: [
                                AureColors.doradoClaro.withValues(alpha: 0.35 * (1 - v)),
                                AureColors.dorado.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
                  child: switch (e.domain) {
                    'light' => _luz(e),
                    'cover' => _persiana(e),
                    'climate' => _clima(e),
                    'media_player' => _musica(e),
                    _ => _interruptor(e),
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cabecera(HaEntity e, AureIcono icono, String detalle, {Widget? derecha}) {
    final activo = _activo(e);
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo ? AureColors.dorado.withValues(alpha: 0.16) : AureColors.panelAlto,
          ),
          child: AureIcon(icono, size: 22, color: activo ? AureColors.dorado : AureColors.grisOscuro, relleno: activo),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.name, style: sans(16, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(detalle, style: sans(13, color: AureColors.gris), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (derecha != null) derecha,
      ],
    );
  }

  // ---------- Luces: tocar para encender, deslizar para regular ----------
  Widget _luz(HaEntity e) {
    final b = _brillo ?? e.brightness;
    final porcentaje = (b * 100).round();
    return Semantics(
      label: e.name,
      value: e.isOn ? '$porcentaje %' : t('disp.apagada'),
      onIncrease: () => _fijarBrillo(e, (b + 0.1).clamp(0.01, 1.0)),
      onDecrease: () => _fijarBrillo(e, (b - 0.1).clamp(0.01, 1.0)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: e.isOn ? (_) => setState(() => _brillo = b) : null,
        onHorizontalDragUpdate: e.isOn
            ? (d) {
                final rtl = Directionality.of(context) == TextDirection.rtl;
                final delta = (rtl ? -d.delta.dx : d.delta.dx) / _anchoTarjeta;
                final nuevo = ((_brillo ?? b) + delta).clamp(0.01, 1.0);
                if ((nuevo * 10).floor() != ((_brillo ?? b) * 10).floor()) Tacto.toque();
                setState(() => _brillo = nuevo);
              }
            : null,
        onHorizontalDragEnd: e.isOn ? (_) => _fijarBrillo(e, _brillo ?? b) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cabecera(
              e,
              AureIcono.luz,
              e.isOn ? '${t('disp.encendida')}  ·  $porcentaje%' : t('disp.apagada'),
              derecha: AureToggle(value: e.isOn, onChanged: (_) => _home.toggle(e)),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: e.isOn
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 58, top: 6),
                      child: Text(t('disp.deslizar'), style: sans(12, color: AureColors.grisOscuro)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fijarBrillo(HaEntity e, double v) async {
    setState(() => _brillo = v);
    await _home.service('light', 'turn_on', {'entity_id': e.id, 'brightness_pct': (v * 100).round()});
    if (mounted) setState(() => _brillo = null);
  }

  Widget _interruptor(HaEntity e) {
    return _cabecera(
      e,
      e.domain == 'fan' ? AureIcono.ventilador : AureIcono.enchufe,
      e.isOn ? t('disp.encendido') : t('disp.apagado'),
      derecha: AureToggle(value: e.isOn, onChanged: (_) => _home.toggle(e)),
    );
  }

  // ---------- Persianas ----------
  Widget _persiana(HaEntity e) {
    final pos = e.attributes['current_position'];
    final detalle = switch (e.state) {
      'open' => pos is num ? '${t('disp.abierta')}  ·  ${pos.round()}%' : t('disp.abierta'),
      'closed' => t('disp.cerrada'),
      'opening' => t('disp.abriendo'),
      'closing' => t('disp.cerrando'),
      _ => e.state,
    };
    return Column(
      children: [
        _cabecera(e, AureIcono.persiana, detalle),
        const SizedBox(height: 12),
        Row(
          children: [
            _boton(Icons.keyboard_arrow_up, t('disp.subir'), () => _home.service('cover', 'open_cover', {'entity_id': e.id})),
            const SizedBox(width: 8),
            _boton(Icons.pause, t('disp.parar'), () => _home.service('cover', 'stop_cover', {'entity_id': e.id})),
            const SizedBox(width: 8),
            _boton(Icons.keyboard_arrow_down, t('disp.bajar'), () => _home.service('cover', 'close_cover', {'entity_id': e.id})),
          ],
        ),
      ],
    );
  }

  // ---------- Clima: dial dorado ----------
  Widget _clima(HaEntity e) {
    final actual = e.attributes['current_temperature'];
    final objetivo = e.attributes['temperature'];
    final modo = switch (e.state) {
      'heat' => t('clima.heat'),
      'cool' => t('clima.cool'),
      'auto' || 'heat_cool' => t('clima.auto'),
      'dry' => t('clima.dry'),
      'fan_only' => t('clima.fan'),
      'off' => t('clima.off'),
      _ => e.state,
    };
    final minimo = (e.attributes['min_temp'] as num?)?.toDouble() ?? 16.0;
    final maximo = (e.attributes['max_temp'] as num?)?.toDouble() ?? 30.0;
    return Column(
      children: [
        _cabecera(
          e,
          AureIcono.clima,
          actual is num ? t('clima.dentro', {'m': modo, 't': grados(actual.toDouble())}) : modo,
        ),
        if (objetivo is num)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: DialClima(
                valor: objetivo.toDouble(),
                min: minimo,
                max: maximo > minimo ? maximo : minimo + 14,
                size: 200,
                alCambiar: (v) {
                  Tacto.confirmar();
                  _home.service('climate', 'set_temperature', {'entity_id': e.id, 'temperature': v});
                },
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Música ----------
  Widget _musica(HaEntity e) {
    final titulo = e.attributes['media_title']?.toString();
    final artista = e.attributes['media_artist']?.toString();
    final sonando = e.state == 'playing';
    final volumen = _volumen ?? ((e.attributes['volume_level'] as num?)?.toDouble() ?? 0.0);
    final detalle = titulo == null
        ? (sonando ? t('musica.reproduciendo') : t('musica.pausa'))
        : [titulo, if (artista != null) artista].join(' — ');
    return Column(
      children: [
        _cabecera(
          e,
          AureIcono.musica,
          detalle,
          derecha: Pressable(
            label: sonando ? t('musica.pausar') : t('musica.reproducir'),
            onTap: () {
              Tacto.encender();
              _home.service('media_player', 'media_play_pause', {'entity_id': e.id});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: sonando ? AureColors.dorado : AureColors.panelAlto),
              child: Icon(sonando ? Icons.pause : Icons.play_arrow, color: sonando ? AureColors.negro : AureColors.dorado),
            ),
          ),
        ),
        if (e.attributes.containsKey('volume_level'))
          Row(
            children: [
              const Icon(Icons.volume_down, size: 18, color: AureColors.grisOscuro),
              Expanded(
                child: Slider(
                  value: volumen.clamp(0.0, 1.0),
                  onChanged: (v) => setState(() => _volumen = v),
                  onChangeEnd: (v) async {
                    await _home.service('media_player', 'volume_set', {
                      'entity_id': e.id,
                      'volume_level': double.parse(v.toStringAsFixed(2)),
                    });
                    if (mounted) setState(() => _volumen = null);
                  },
                ),
              ),
              const Icon(Icons.volume_up, size: 18, color: AureColors.grisOscuro),
            ],
          ),
      ],
    );
  }

  Widget _boton(IconData icono, String texto, VoidCallback onTap) {
    return Expanded(
      child: Pressable(
        label: texto,
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AureColors.panelAlto,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AureColors.linea),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 18, color: AureColors.dorado),
              const SizedBox(width: 6),
              Text(texto, style: sans(14)),
            ],
          ),
        ),
      ),
    );
  }
}
