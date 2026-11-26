import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../pantalla.dart';
import '../perfil.dart';
import '../theme.dart';
import '../voz.dart';
import '../utils.dart';
import '../acento.dart';
import '../widgets/avisos.dart';
import '../widgets/common.dart';
import 'personalizar.dart';
import 'rutinas_vista.dart';

/// "Mis preferencias": quién eres y cómo te gusta la casa.
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    final perfil = PerfilStore.i;
    return ListenableBuilder(
      listenable: Listenable.merge([home, perfil, I18n.i]),
      builder: (context, _) {
        final p = perfil.prefs;
        final nombre = perfil.nombre(home);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AureColors.negro,
            surfaceTintColor: Colors.transparent,
            title: Text(t('ajustes.preferencias'), style: serif(24)),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                  children: [
                    // Perfil
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: aureCard(radius: 22),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AureColors.dorado.withValues(alpha: 0.18),
                            child: Text(
                              nombre.isEmpty ? '·' : nombre.characters.first.toUpperCase(),
                              style: serif(24, color: AureColors.dorado),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nombre.isEmpty ? t('pref.perfil') : nombre, style: serif(24)),
                                Text(
                                  '${t('pref.rol')}: ${perfil.rol(home)}',
                                  style: sans(14, color: AureColors.gris),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (home.personas.length > 1) ...[
                      const SizedBox(height: 24),
                      _titulo(t('pref.quien')),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final persona in home.personas)
                            _pastilla(
                              persona.nombre,
                              persona.nombre == nombre,
                              () => perfil.elegirPersona(persona.nombre),
                            ),
                        ],
                      ),
                    ],

                    // Personalizar
                    const SizedBox(height: 28),
                    _titulo(t('pers.titulo')),
                    SeccionPersonalizar(home: home),

                    // Temperatura
                    const SizedBox(height: 28),
                    _titulo(t('pref.temp')),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      decoration: aureCard(radius: 22),
                      child: Column(
                        children: [
                          Text('${grados(p.temperatura)}°', style: serif(54, color: AureColors.doradoClaro)),
                          Slider(
                            value: p.temperatura,
                            min: 17,
                            max: 27,
                            divisions: 20,
                            onChanged: (v) {
                              p.temperatura = v;
                              perfil.guardarPrefs();
                            },
                          ),
                        ],
                      ),
                    ),

                    // Tono de luz
                    const SizedBox(height: 28),
                    _titulo(t('pref.tono')),
                    Row(
                      children: [
                        for (final tono in const [
                          ('calida', 'pref.calida', Color(0xFFF2C77E)),
                          ('neutra', 'pref.neutra', Color(0xFFF6E7C8)),
                          ('fria', 'pref.fria', Color(0xFFDCE8F5)),
                        ]) ...[
                          if (tono.$1 != 'calida') const SizedBox(width: 10),
                          Expanded(
                            child: Pressable(
                              label: t(tono.$2),
                              onTap: () {
                                p.tono = tono.$1;
                                perfil.guardarPrefs();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: aureCard(active: p.tono == tono.$1, radius: 18),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: tono.$3,
                                        boxShadow: [
                                          BoxShadow(color: tono.$3.withValues(alpha: 0.5), blurRadius: 16),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(t(tono.$2), style: sans(14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Brillo
                    const SizedBox(height: 28),
                    _titulo('${t('pref.brillo')}  ·  ${(p.brillo * 100).round()}%'),
                    Slider(
                      value: p.brillo,
                      min: 0.1,
                      max: 1,
                      divisions: 18,
                      onChanged: (v) {
                        p.brillo = v;
                        perfil.guardarPrefs();
                      },
                    ),
                    const SizedBox(height: 8),
                    Pressable(
                      label: t('pref.aplicar'),
                      onTap: () async {
                        await perfil.aplicarAmbiente(home);
                        if (context.mounted) {
                          Tacto.confirmar();
                          Avisos.mostrar(context, t('pref.aplicada'), icono: Icons.wb_twilight);
                        }
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AureColors.dorado),
                        ),
                        child: Text(t('pref.aplicar'), style: sans(15, color: AureColors.doradoClaro)),
                      ),
                    ),

                    // Idioma
                    const SizedBox(height: 32),
                    _titulo(t('pref.idioma')),
                    const SelectorIdioma(),

                    // Color de acento
                    const SizedBox(height: 32),
                    _titulo(t('pref.acento')),
                    const SelectorEstilo(),

                    // Voz
                    const SizedBox(height: 32),
                    ListenableBuilder(
                      listenable: Voz.i,
                      builder: (context, _) => Container(
                        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                        decoration: aureCard(active: Voz.i.responderEnVoz, radius: 18),
                        child: Row(
                          children: [
                            const Icon(Icons.record_voice_over_outlined, color: AureColors.dorado),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t('pref.voz'), style: sans(16, weight: FontWeight.w500)),
                                  Text(t('pref.vozSub'), style: sans(13, color: AureColors.gris)),
                                ],
                              ),
                            ),
                            AureToggle(value: Voz.i.responderEnVoz, onChanged: Voz.i.cambiarResponderEnVoz),
                          ],
                        ),
                      ),
                    ),

                    // Automatismos (viven en Home Assistant: funcionan aunque la app esté cerrada)
                    if (!perfil.invitado) ...[
                      const SizedBox(height: 32),
                      _titulo(t('auto.titulo')),
                      _Automatismo(
                        home: home,
                        id: 'aure_llegada',
                        icono: Icons.home_outlined,
                        titulo: t('auto.llegada'),
                        subtitulo: t('auto.llegadaSub'),
                        activar: () => home.activarLlegada(brillo: p.brillo, temperatura: p.temperatura),
                      ),
                      const SizedBox(height: 10),
                      _Automatismo(
                        home: home,
                        id: 'aure_vacaciones',
                        icono: Icons.flight_takeoff_outlined,
                        titulo: t('auto.vacaciones'),
                        subtitulo: t('auto.vacacionesSub'),
                        activar: home.activarVacaciones,
                      ),
                      const SizedBox(height: 10),
                      _Automatismo(
                        home: home,
                        id: 'aure_saludo',
                        icono: Icons.waving_hand_outlined,
                        titulo: t('auto.saludo'),
                        subtitulo: t('auto.saludoSub'),
                        activar: home.activarSaludoLlegada,
                      ),
                      if (home.esAdmin) ...[
                        const SizedBox(height: 10),
                        SeccionRutinas(home: home),
                      ],
                    ],

                    // Modo noche
                    const SizedBox(height: 32),
                    ListenableBuilder(
                      listenable: PantallaStore.i,
                      builder: (context, _) {
                        final pan = PantallaStore.i;
                        return Container(
                          padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
                          decoration: aureCard(active: pan.modoNoche, radius: 18),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.nights_stay_outlined, color: AureColors.dorado),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t('pref.noche'), style: sans(16, weight: FontWeight.w500)),
                                        Text(t('pref.nocheSub'), style: sans(13, color: AureColors.gris)),
                                      ],
                                    ),
                                  ),
                                  AureToggle(value: pan.modoNoche, onChanged: pan.cambiarModoNoche),
                                ],
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                child: pan.modoNoche
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${t('pref.brilloNoche')}  ·  ${(pan.brilloNoche * 100).round()}%',
                                              style: sans(13, color: AureColors.gris),
                                            ),
                                            Slider(
                                              value: pan.brilloNoche,
                                              min: 0.4,
                                              max: 1,
                                              divisions: 12,
                                              onChanged: pan.cambiarBrillo,
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(width: double.infinity),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Modo invitado
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                      decoration: aureCard(active: perfil.invitado, radius: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: AureColors.dorado),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t('pref.invitado'), style: sans(16, weight: FontWeight.w500)),
                                Text(t('pref.invitadoSub'), style: sans(13, color: AureColors.gris)),
                              ],
                            ),
                          ),
                          AureToggle(value: perfil.invitado, onChanged: perfil.cambiarInvitado),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(texto, style: sans(14, color: AureColors.gris)),
      );

  Widget _pastilla(String texto, bool activa, VoidCallback onTap) {
    return Pressable(
      label: texto,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: activa ? AureColors.dorado : AureColors.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AureColors.linea),
        ),
        child: Text(texto, style: sans(14, color: activa ? AureColors.negro : AureColors.crema)),
      ),
    );
  }
}

/// Un automatismo que se crea o se borra dentro de Home Assistant.
class _Automatismo extends StatefulWidget {
  const _Automatismo({
    required this.home,
    required this.id,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.activar,
  });

  final HaHome home;
  final String id;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Future<String?> Function() activar;

  @override
  State<_Automatismo> createState() => _AutomatismoState();
}

class _AutomatismoState extends State<_Automatismo> {
  bool _activo = false;
  bool _ocupado = true;

  @override
  void initState() {
    super.initState();
    widget.home.existeAutomatizacion(widget.id).then((v) {
      if (mounted) {
        setState(() {
          _activo = v;
          _ocupado = false;
        });
      }
    });
  }

  Future<void> _cambiar(bool valor) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    String? error;
    if (valor) {
      error = await widget.activar();
    } else {
      final ok = await widget.home.borrarAutomatizacion(widget.id);
      if (!ok) error = t('auto.error');
    }
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (error == null) _activo = valor;
    });
    Avisos.mostrar(
      context,
      error ?? t(valor ? 'auto.activado' : 'auto.desactivado', {'n': widget.titulo}),
      icono: error == null ? widget.icono : Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: aureCard(active: _activo, radius: 18),
      child: Row(
        children: [
          Icon(widget.icono, color: AureColors.dorado),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.titulo, style: sans(16, weight: FontWeight.w500)),
                Text(widget.subtitulo, style: sans(13, color: AureColors.gris)),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _ocupado ? 0.4 : 1,
            duration: const Duration(milliseconds: 200),
            child: AureToggle(value: _activo, onChanged: _cambiar),
          ),
        ],
      ),
    );
  }
}

/// Selector de idioma: Español, English, العربية.
class SelectorIdioma extends StatelessWidget {
  const SelectorIdioma({super.key, this.compacto = false});

  final bool compacto;

  @override
  Widget build(BuildContext context) {
    const opciones = [
      (Idioma.es, 'Español', 'ES'),
      (Idioma.en, 'English', 'EN'),
      (Idioma.ar, 'العربية', 'ع'),
    ];
    return ListenableBuilder(
      listenable: I18n.i,
      builder: (context, _) => Row(
        mainAxisSize: compacto ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < opciones.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _boton(opciones[i]),
          ],
        ],
      ),
    );
  }

  Widget _boton((Idioma, String, String) op) {
    final activo = I18n.i.idioma == op.$1;
    final hijo = Pressable(
      label: op.$2,
      onTap: () => I18n.i.cambiar(op.$1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: compacto ? 36 : 46,
        padding: EdgeInsets.symmetric(horizontal: compacto ? 12 : 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? AureColors.dorado : AureColors.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AureColors.linea),
        ),
        child: Text(
          compacto ? op.$3 : op.$2,
          style: sans(14, color: activo ? AureColors.negro : AureColors.crema),
        ),
      ),
    );
    return compacto ? hijo : Expanded(child: hijo);
  }
}

/// Selector del estilo de color: cinco muestras con su color real.
class SelectorEstilo extends StatelessWidget {
  const SelectorEstilo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AcentoStore.i,
      builder: (context, _) => SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: muestrasAcento.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final m = muestrasAcento[i];
            final activo = AcentoStore.i.acento == m.$1;
            return Pressable(
              label: t(m.$2),
              onTap: () {
                Tacto.confirmar();
                AcentoStore.i.cambiar(m.$1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 96,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: aureCard(active: activo, radius: 18),
                child: Column(
                  children: [
                    // La muestra se ve con su color real, sea cual sea el estilo actual.
                    SinFiltroAcento(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.$3,
                          border: Border.all(color: m.$4.withValues(alpha: 0.9), width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: m.$4,
                            boxShadow: [BoxShadow(color: m.$4.withValues(alpha: 0.5), blurRadius: 10)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(t(m.$2), style: sans(13), textAlign: TextAlign.center, maxLines: 1),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
