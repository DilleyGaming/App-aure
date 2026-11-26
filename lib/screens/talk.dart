import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../perfil.dart';
import '../reposo.dart';
import '../rutinas.dart';
import '../theme.dart';
import '../utils.dart';
import '../voz.dart';
import '../widgets/avisos.dart';
import '../widgets/breathing_orb.dart';
import '../widgets/common.dart';
import '../widgets/device_tile.dart';
import '../widgets/hoja.dart';
import 'scenes.dart';

/// Abre la conversación a pantalla completa (tablet).
Future<void> abrirConversacion(BuildContext context, HaHome home) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => TalkView(home: home, cerrable: true),
      transitionsBuilder: (_, animacion, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animacion, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
}

/// Auré, lista para que le hables. En el móvil es la pantalla principal.
class TalkView extends StatefulWidget {
  const TalkView({
    super.key,
    required this.home,
    this.cerrable = false,
    this.alMenu,
    this.alPerfil,
  });

  final HaHome home;

  /// Si se abre encima de otra pantalla, muestra el botón de cerrar.
  final bool cerrable;
  final VoidCallback? alMenu;
  final VoidCallback? alPerfil;

  @override
  State<TalkView> createState() => _TalkViewState();
}

class _TalkViewState extends State<TalkView> {
  final _texto = TextEditingController();
  final _foco = FocusNode();
  OrbMode _modo = OrbMode.idle;
  String? _frase;
  String _respuesta = '';
  Timer? _maquina;
  Timer? _volver;
  bool _ocupada = false;
  final List<(String, bool)> _historial = [];
  bool _porVoz = false;
  List<HaEntity> _cambios = [];
  Map<String, String> _antes = {};

  String _huella(HaEntity e) => '${e.state}|${e.attributes['brightness']}|${e.attributes['current_position']}|'
      '${e.attributes['temperature']}|${e.attributes['media_title']}';

  void _fotografiar() {
    _antes = {for (final e in widget.home.devices) e.id: _huella(e)};
  }

  /// Tras responder, busca qué aparatos han cambiado para mostrarlos como tarjetas.
  void _buscarCambios() {
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final cambiados = widget.home.devices.where((e) => _antes[e.id] != null && _antes[e.id] != _huella(e)).take(3).toList();
      setState(() => _cambios = cambiados);
    });
  }

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (_modo == OrbMode.idle || _modo == OrbMode.listening) {
        setState(() => _modo = _foco.hasFocus ? OrbMode.listening : OrbMode.idle);
      }
    });
  }

  @override
  void dispose() {
    _maquina?.cancel();
    _volver?.cancel();
    if (_ocupada) Reposo.i.liberar();
    Voz.i.dejarDeEscuchar();
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  void _ocupar(bool valor) {
    if (valor == _ocupada) return;
    _ocupada = valor;
    valor ? Reposo.i.ocupar() : Reposo.i.liberar();
  }

  void _mostrarRespuesta(String respuesta) {
    _historial.add((respuesta, true));
    if (_porVoz) Voz.i.decir(respuesta);
    _porVoz = false;
    _buscarCambios();
    setState(() => _modo = OrbMode.speaking);
    var i = 0;
    _maquina?.cancel();
    _maquina = Timer.periodic(const Duration(milliseconds: 22), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      i = math.min(respuesta.length, i + 2);
      setState(() => _respuesta = respuesta.substring(0, i));
      if (i >= respuesta.length) {
        timer.cancel();
        setState(() => _modo = _foco.hasFocus ? OrbMode.listening : OrbMode.idle);
        _ocupar(false);
        _volver = Timer(const Duration(seconds: 25), () {
          if (mounted && _modo != OrbMode.thinking && _modo != OrbMode.speaking) {
            setState(() {
              _frase = null;
              _cambios = [];
            });
          }
        });
      }
    });
  }

  Future<void> _enviar([String? sugerencia]) async {
    final frase = (sugerencia ?? _texto.text).trim();
    if (frase.isEmpty || _modo == OrbMode.thinking || _modo == OrbMode.speaking) return;
    _texto.clear();
    _volver?.cancel();
    Tacto.encender();
    _ocupar(true);
    _fotografiar();
    _historial.add((frase, false));
    setState(() {
      _cambios = [];
      _frase = frase;
      _respuesta = '';
      _modo = OrbMode.thinking;
    });
    final respuesta = await hablarConAure(widget.home, frase);
    if (!mounted) return;
    _mostrarRespuesta(respuesta);
  }

  /// Tocar la luz (o el micrófono) para hablar.
  Future<void> _escuchar() async {
    if (_modo == OrbMode.thinking || _modo == OrbMode.speaking) return;
    if (Voz.i.escuchando) {
      await Voz.i.dejarDeEscuchar();
      setState(() => _modo = OrbMode.idle);
      return;
    }
    Tacto.encender();
    _volver?.cancel();
    setState(() {
      _modo = OrbMode.listening;
      _frase = '…';
      _respuesta = '';
      _cambios = [];
    });
    final ok = await Voz.i.escuchar(
      alOir: (texto) {
        if (mounted && texto.isNotEmpty) setState(() => _frase = texto);
      },
      alTerminar: (texto) {
        if (!mounted) return;
        if (texto.trim().isEmpty) {
          setState(() {
            _modo = OrbMode.idle;
            _frase = null;
          });
          return;
        }
        _porVoz = true;
        setState(() => _modo = OrbMode.idle);
        _enviar(texto);
      },
    );
    if (!ok && mounted) {
      setState(() {
        _modo = OrbMode.idle;
        _frase = null;
      });
      Avisos.mostrar(context, t('voz.noDisponible'), icono: Icons.mic_off_outlined);
    }
  }

  Future<void> _escena(EscenaAure escena) async {
    if (_modo == OrbMode.thinking || _modo == OrbMode.speaking) return;
    _volver?.cancel();
    Tacto.confirmar();
    _ocupar(true);
    _fotografiar();
    _historial.add((t(escena.claveTitulo), false));
    setState(() {
      _cambios = [];
      _frase = t(escena.claveTitulo);
      _respuesta = '';
      _modo = OrbMode.thinking;
    });
    await escena.accion(widget.home, PerfilStore.i.prefs);
    if (!mounted) return;
    _mostrarRespuesta(t('talk.hecho'));
  }

  String get _estado => switch (_modo) {
        OrbMode.idle => resumenCasa(widget.home),
        OrbMode.listening => Voz.i.escuchando ? t('voz.escuchando') : t('talk.escucha'),
        OrbMode.thinking => t('talk.piensa'),
        OrbMode.speaking => t('talk.habla'),
      };

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    final bajo = alto < 720;
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: widget.cerrable ? AureColors.negro : Colors.transparent,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.home, PerfilStore.i]),
          builder: (context, _) => Column(
            children: [
              _barraSuperior(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            button: true,
                            label: t('voz.tocar'),
                            child: GestureDetector(
                              onTap: _escuchar,
                              child: BreathingOrb(
                                size: tecladoAbierto ? 110 : (bajo ? 170 : 220),
                                mode: _modo,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _estado,
                              key: ValueKey(_estado),
                              textAlign: TextAlign.center,
                              style: sans(14, color: AureColors.gris),
                            ),
                          ),
                          SizedBox(height: bajo ? 16 : 26),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: _frase == null ? _bienvenida(bajo) : _intercambio(bajo),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_frase == null && !tecladoAbierto) _atajos(),
              _entrada(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraSuperior() {
    final nombre = PerfilStore.i.nombre(widget.home);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          if (widget.alMenu != null)
            IconButton(
              tooltip: t('nav.funciones'),
              onPressed: widget.alMenu,
              icon: const Icon(Icons.grid_view_rounded, color: AureColors.crema),
            )
          else
            const SizedBox(width: 48),
          if (_historial.isNotEmpty)
            IconButton(
              tooltip: t('talk.historial'),
              onPressed: _abrirHistorial,
              icon: const Icon(Icons.history, color: AureColors.gris),
            ),
          const Spacer(),
          aureLogo(size: 22),
          const SizedBox(width: 8),
          Text('AURÉ', style: marca(15, spacing: 6)),
          const Spacer(),
          if (_historial.isNotEmpty) const SizedBox(width: 48),
          if (widget.cerrable)
            IconButton(
              tooltip: t('comun.cerrar'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AureColors.gris),
            )
          else if (widget.alPerfil != null)
            Padding(
              padding: const EdgeInsets.all(4),
              child: Pressable(
                label: t('ajustes.preferencias'),
                onTap: widget.alPerfil,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AureColors.dorado.withValues(alpha: 0.18),
                  child: Text(
                    nombre.isEmpty ? '·' : nombre.characters.first.toUpperCase(),
                    style: serif(16, color: AureColors.dorado),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _bienvenida(bool bajo) {
    final nombre = PerfilStore.i.nombre(widget.home);
    return Column(
      key: const ValueKey('bienvenida'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nombre.isEmpty ? '${saludo()}.' : '${saludo()}, $nombre.',
          textAlign: TextAlign.center,
          style: serif(bajo ? 26 : 32, color: AureColors.doradoClaro),
        ),
        const SizedBox(height: 8),
        Text(t('talk.pregunta'), textAlign: TextAlign.center, style: serif(bajo ? 24 : 30)),
      ],
    );
  }

  Widget _intercambio(bool bajo) {
    return Column(
      key: ValueKey(_frase),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('«$_frase»', textAlign: TextAlign.center, style: sans(16, color: AureColors.gris)),
        const SizedBox(height: 16),
        Text(_respuesta, textAlign: TextAlign.center, style: serif(bajo ? 23 : 28, height: 1.35)),
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: _cambios.isEmpty || _modo == OrbMode.speaking
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('talk.cambios'), style: sans(13, color: AureColors.gris)),
                      const SizedBox(height: 10),
                      for (final e in _cambios)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ListenableBuilder(
                            listenable: widget.home,
                            builder: (context, _) => DeviceTile(
                              key: ValueKey('cambio-${e.id}'),
                              entity: widget.home.entities[e.id] ?? e,
                              home: widget.home,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Historial de la conversación, con estilo editorial.
  void _abrirHistorial() {
    abrirHoja<void>(context, builder: (hoja) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AsaHoja(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
            child: Text(t('talk.historial'), style: serif(26)),
          ),
          Flexible(
            child: _historial.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(t('talk.vacio'), style: sans(15, color: AureColors.gris)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: _historial.length,
                    itemBuilder: (context, i) {
                      final m = _historial[_historial.length - 1 - i];
                      if (!m.$2) {
                        return Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: AureColors.panelAlto,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(m.$1, style: sans(15)),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsetsDirectional.only(top: 10, end: 12),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AureColors.dorado),
                            ),
                            Expanded(child: Text(m.$1, style: serif(20, height: 1.45))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }

  /// Atajos rápidos: escenas y preguntas frecuentes, como sugerencias de un chat.
  Widget _atajos() {
    final sugerencias = [t('talk.s1'), t('talk.s4'), t('talk.s2')];
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final escena in escenasAure)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _pastilla(t(escena.claveTitulo), escena.icono, () => _escena(escena)),
            ),
          for (final s in sugerencias)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _pastilla(s, null, () => _enviar(s)),
            ),
        ],
      ),
    );
  }

  Widget _pastilla(String texto, IconData? icono, VoidCallback onTap) {
    return Pressable(
      label: texto,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AureColors.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: icono == null ? AureColors.linea : AureColors.dorado.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 16, color: AureColors.dorado),
              const SizedBox(width: 8),
            ],
            Text(texto, style: sans(14)),
          ],
        ),
      ),
    );
  }

  Widget _entrada() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(
            children: [
              ListenableBuilder(
                listenable: Voz.i,
                builder: (context, _) => Pressable(
                  label: t('voz.microfono'),
                  onTap: _escuchar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Voz.i.escuchando ? AureColors.dorado : AureColors.panel,
                      border: Border.all(color: AureColors.dorado.withValues(alpha: 0.5)),
                    ),
                    child: Icon(
                      Voz.i.escuchando ? Icons.graphic_eq : Icons.mic_none_rounded,
                      color: Voz.i.escuchando ? AureColors.negro : AureColors.dorado,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _texto,
                  focusNode: _foco,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviar(),
                  style: sans(16),
                  decoration: InputDecoration(
                    hintText: t('talk.hint'),
                    hintStyle: sans(16, color: AureColors.grisOscuro),
                    filled: true,
                    fillColor: AureColors.panel,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: AureColors.linea),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: AureColors.dorado),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                label: t('talk.enviar'),
                onTap: _enviar,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AureColors.dorado),
                  child: const Icon(Icons.arrow_upward, color: AureColors.negro),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
