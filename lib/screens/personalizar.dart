import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../perfil.dart';
import '../theme.dart';
import '../voz.dart';
import '../widgets/avisos.dart';
import '../widgets/common.dart';
import '../widgets/hoja.dart';

/// "Personalizar": cómo te llama, cómo se llama ella, con qué palabra despierta y su voz.
class SeccionPersonalizar extends StatelessWidget {
  const SeccionPersonalizar({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    final perfil = PerfilStore.i;
    final hayMicros = home.satelitesEn(null).isNotEmpty;
    return ListenableBuilder(
      listenable: Listenable.merge([perfil, Voz.i, I18n.i]),
      builder: (context, _) {
        final nombre = perfil.nombre(home);
        return Container(
          decoration: aureCard(radius: 22),
          child: Column(
            children: [
              _fila(
                Icons.badge_outlined,
                t('pers.tuNombre'),
                nombre.isEmpty ? t('pers.sinNombre') : nombre,
                () async {
                  final nuevo = await pedirTexto(context, t('pers.tuNombre'), nombre, t('pers.tuNombreAyuda'));
                  if (nuevo != null) await perfil.cambiarApodo(nuevo);
                },
              ),
              _linea(),
              _fila(
                Icons.auto_awesome_outlined,
                t('pers.suNombre'),
                I18n.nombreAsistente ?? 'Auré',
                () async {
                  final nuevo = await pedirTexto(
                    context,
                    t('pers.suNombre'),
                    I18n.nombreAsistente ?? 'Auré',
                    t('pers.suNombreAyuda'),
                  );
                  if (nuevo != null) await perfil.cambiarNombreAsistente(nuevo);
                },
              ),
              if (hayMicros && home.esAdmin) ...[
                _linea(),
                _fila(
                  Icons.hearing_outlined,
                  t('pers.palabra'),
                  t('pers.palabraSub'),
                  () => abrirPalabraActivacion(context, home),
                ),
              ],
              _linea(),
              _fila(
                Icons.graphic_eq,
                t('pers.voz'),
                Voz.i.vozElegida == null ? t('pers.vozDefecto') : t('pers.vozPropia'),
                () => abrirElegirVoz(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _linea() => const Divider(height: 1, indent: 58, color: AureColors.linea);

  Widget _fila(IconData icono, String titulo, String valor, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Tacto.toque();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 14, 15),
        child: Row(
          children: [
            Icon(icono, color: AureColors.dorado),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: sans(16, weight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(valor, style: sans(13, color: AureColors.gris), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AureColors.grisOscuro),
          ],
        ),
      ),
    );
  }
}

/// Pide un texto corto. Devuelve null si se cancela.
Future<String?> pedirTexto(BuildContext context, String titulo, String valor, String ayuda) {
  final campo = TextEditingController(text: valor);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AureColors.panelAlto,
      title: Text(titulo, style: serif(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ayuda, style: sans(14, color: AureColors.gris)),
          const SizedBox(height: 14),
          TextField(
            controller: campo,
            autofocus: true,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            style: sans(17),
            onSubmitted: (v) => Navigator.pop(c, v),
            decoration: InputDecoration(
              filled: true,
              fillColor: AureColors.panel,
              counterStyle: sans(11, color: AureColors.grisOscuro),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(t('comun.cancelar'), style: sans(14, color: AureColors.gris)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, campo.text),
          child: Text(t('comun.guardar'), style: sans(14, color: AureColors.dorado)),
        ),
      ],
    ),
  );
}

/// Nombre bonito para una voz del sistema: "Voz 2 · España".
String _region(String locale) {
  final partes = locale.replaceAll('_', '-').split('-');
  final pais = partes.length > 1 ? partes[1].toUpperCase() : '';
  return switch (pais) {
    'ES' => t('region.es'),
    'MX' => t('region.mx'),
    'US' => t('region.us'),
    'GB' => t('region.gb'),
    'AE' => t('region.ae'),
    'SA' => t('region.sa'),
    'EG' => t('region.eg'),
    '' => locale,
    _ => pais,
  };
}

/// Elegir la voz de Auré en este móvil, su tono y su velocidad.
Future<void> abrirElegirVoz(BuildContext context) async {
  final voces = await Voz.i.voces();
  if (!context.mounted) return;
  await abrirHoja<void>(context, builder: (hoja) {
    return ListenableBuilder(
      listenable: Voz.i,
      builder: (context, _) {
        final v = Voz.i;
        Widget opcion(String? nombre, String? locale, String titulo, String sub) {
          final activa = v.vozElegida == nombre;
          return Pressable(
            label: titulo,
            onTap: () async {
              Tacto.toque();
              await v.elegirVoz(nombre, locale);
              await v.decir(t('voz.prueba'), forzar: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: aureCard(active: activa, radius: 16),
              child: Row(
                children: [
                  Icon(activa ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: activa ? AureColors.dorado : AureColors.grisOscuro, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(titulo, style: sans(15))),
                  Text(sub, style: sans(12, color: AureColors.gris)),
                ],
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AsaHoja(),
              const SizedBox(height: 6),
              Text(t('pers.voz'), style: serif(26)),
              const SizedBox(height: 4),
              Text(t('pers.vozAyuda'), style: sans(13, color: AureColors.gris)),
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    opcion(null, null, t('pers.vozDefecto'), ''),
                    for (var i = 0; i < voces.length; i++)
                      opcion(
                        voces[i].$1,
                        voces[i].$2,
                        '${t('pers.vozN')} ${i + 1}',
                        '${_region(voces[i].$2)}${voces[i].$1.contains('network') ? ' · ${t('pers.internet')}' : ''}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('${t('pers.tono')}  ·  ${v.tono < 0.95 ? t('pers.grave') : (v.tono > 1.05 ? t('pers.aguda') : t('pers.normal'))}',
                  style: sans(13, color: AureColors.gris)),
              Slider(value: v.tono, min: 0.7, max: 1.3, divisions: 12, onChanged: v.cambiarTono),
              Text('${t('pers.velocidad')}  ·  ${v.velocidad < 0.45 ? t('pers.pausada') : (v.velocidad > 0.55 ? t('pers.rapida') : t('pers.normal'))}',
                  style: sans(13, color: AureColors.gris)),
              Slider(value: v.velocidad, min: 0.3, max: 0.7, divisions: 8, onChanged: v.cambiarVelocidad),
              const SizedBox(height: 6),
              Pressable(
                label: t('pers.probar'),
                onTap: () => v.decir(t('voz.prueba'), forzar: true),
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AureColors.dorado),
                  ),
                  child: Text(t('pers.probar'), style: sans(15, color: AureColors.doradoClaro)),
                ),
              ),
            ],
          ),
        );
      },
    );
  });
}

/// Elegir la palabra con la que se despierta Auré en los micrófonos de la casa.
Future<void> abrirPalabraActivacion(BuildContext context, HaHome home) async {
  final micros = home.satelitesEn(null);
  if (micros.isEmpty) return;
  final config = await home.palabrasActivacion(micros.first.id);
  if (!context.mounted) return;
  if (config == null || config.$1.isEmpty) {
    Avisos.mostrar(context, t('palabra.noDisponible'), icono: Icons.hearing_disabled_outlined);
    return;
  }
  var activa = config.$2.isEmpty ? null : config.$2.first;
  await abrirHoja<void>(context, builder: (hoja) {
    return StatefulBuilder(
      builder: (context, setHoja) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AsaHoja(),
            const SizedBox(height: 6),
            Text(t('pers.palabra'), style: serif(26)),
            const SizedBox(height: 4),
            Text(t('palabra.ayuda', {'n': '${micros.length}'}), style: sans(13, color: AureColors.gris)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in config.$1)
                    Pressable(
                      label: p.$2,
                      onTap: () async {
                        Tacto.confirmar();
                        setHoja(() => activa = p.$1);
                        var bien = true;
                        for (final m in micros) {
                          bien = await home.ponerPalabraActivacion(m.id, p.$1) && bien;
                        }
                        if (context.mounted) {
                          Avisos.mostrar(
                            context,
                            bien ? t('palabra.hecho', {'p': p.$2}) : t('palabra.error'),
                            icono: bien ? Icons.hearing_outlined : Icons.error_outline,
                          );
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: aureCard(active: activa == p.$1, radius: 16),
                        child: Row(
                          children: [
                            Icon(
                              activa == p.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: activa == p.$1 ? AureColors.dorado : AureColors.grisOscuro,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text('«${p.$2}»', style: serif(18)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(t('palabra.propia'), style: sans(12, color: AureColors.grisOscuro)),
          ],
        ),
      ),
    );
  });
}
