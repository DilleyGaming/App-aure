import 'dart:async';

import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../reposo.dart';
import '../rutinas.dart';
import '../theme.dart';
import '../voz.dart';
import 'avisos.dart';
import 'breathing_orb.dart';
import 'common.dart';

/// Mantén pulsado para hablar con Auré (como un walkie), desde cualquier pantalla.
/// Un toque normal hace [alTocar].
class PulsarParaHablar extends StatefulWidget {
  const PulsarParaHablar({super.key, required this.home, required this.child, this.alTocar, this.label});

  final HaHome home;
  final Widget child;
  final VoidCallback? alTocar;
  final String? label;

  @override
  State<PulsarParaHablar> createState() => _PulsarParaHablarState();
}

class _EstadoPanel {
  const _EstadoPanel(this.modo, this.oido, this.respuesta);

  final OrbMode modo;
  final String oido;
  final String respuesta;
}

class _PulsarParaHablarState extends State<PulsarParaHablar> {
  final _estado = ValueNotifier(const _EstadoPanel(OrbMode.listening, '', ''));
  OverlayEntry? _panel;
  String _ultimo = '';
  String? _final;
  bool _escuchando = false;
  Timer? _cerrar;

  @override
  void dispose() {
    _cerrar?.cancel();
    _quitarPanel();
    _estado.dispose();
    super.dispose();
  }

  void _quitarPanel() {
    _panel?.remove();
    _panel = null;
  }

  Future<void> _empezar() async {
    _cerrar?.cancel();
    _quitarPanel();
    FocusManager.instance.primaryFocus?.unfocus();
    Tacto.encender();
    Reposo.i.ocupar();
    _ultimo = '';
    _final = null;
    _escuchando = true;
    _estado.value = const _EstadoPanel(OrbMode.listening, '', '');
    _panel = OverlayEntry(builder: (_) => _Panel(estado: _estado, alCerrar: _terminarYa));
    Overlay.of(context).insert(_panel!);
    final ok = await Voz.i.escuchar(
      alOir: (texto) {
        _ultimo = texto;
        _estado.value = _EstadoPanel(OrbMode.listening, texto, '');
      },
      alTerminar: (texto) => _final = texto,
    );
    if (!ok) {
      _escuchando = false;
      Reposo.i.liberar();
      _quitarPanel();
      if (mounted) Avisos.mostrar(context, t('voz.noDisponible'), icono: Icons.mic_off_outlined);
    }
  }

  Future<void> _soltar() async {
    if (!_escuchando) return;
    _escuchando = false;
    await Voz.i.dejarDeEscuchar();
    // Damos un momento para que llegue el texto final.
    for (var i = 0; i < 12 && _final == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final frase = ((_final?.trim().isNotEmpty ?? false) ? _final! : _ultimo).trim();
    if (frase.isEmpty) {
      Reposo.i.liberar();
      _quitarPanel();
      return;
    }
    Tacto.confirmar();
    _estado.value = _EstadoPanel(OrbMode.thinking, frase, '');
    final respuesta = await hablarConAure(widget.home, frase);
    if (_panel == null) {
      Reposo.i.liberar();
      return;
    }
    _estado.value = _EstadoPanel(OrbMode.speaking, frase, respuesta);
    Voz.i.decir(respuesta);
    Reposo.i.liberar();
    _cerrar = Timer(Duration(seconds: 4 + respuesta.length ~/ 25), _quitarPanel);
  }

  void _terminarYa() {
    _cerrar?.cancel();
    Voz.i.callar();
    _quitarPanel();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _empezar(),
      onLongPressEnd: (_) => _soltar(),
      onLongPressCancel: _soltar,
      child: Pressable(label: widget.label, onTap: widget.alTocar, child: widget.child),
    );
  }
}

/// Tarjeta flotante con lo que oye y lo que responde.
class _Panel extends StatelessWidget {
  const _Panel({required this.estado, required this.alCerrar});

  final ValueNotifier<_EstadoPanel> estado;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom + 110;
    return Positioned(
      left: 16,
      right: 16,
      bottom: abajo,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: alCerrar,
              child: ValueListenableBuilder<_EstadoPanel>(
                valueListenable: estado,
                builder: (context, e, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.fromLTRB(18, 16, 20, 16),
                  decoration: BoxDecoration(
                    color: AureColors.panelAlto,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AureColors.dorado.withValues(alpha: 0.45)),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BreathingOrb(size: 52, mode: e.modo),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              switch (e.modo) {
                                OrbMode.listening => t('pulsar.escucho'),
                                OrbMode.thinking => t('talk.piensa'),
                                _ => e.oido.isEmpty ? '' : '«${e.oido}»',
                              },
                              style: sans(13, color: AureColors.dorado),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.modo == OrbMode.speaking
                                  ? e.respuesta
                                  : (e.oido.isEmpty ? t('pulsar.suelta') : e.oido),
                              style: serif(e.modo == OrbMode.speaking ? 19 : 17, height: 1.35),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
