import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Rutinas creadas hablando con Auré ("todos los días a las 7 sube las persianas").
class SeccionRutinas extends StatelessWidget {
  const SeccionRutinas({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: home,
      builder: (context, _) {
        final rutinas = home.rutinas;
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 12),
          decoration: aureCard(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: AureColors.dorado),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t('rutina.titulo'), style: sans(16, weight: FontWeight.w500))),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 38, end: 10),
                child: Text(t('rutina.pista'), style: sans(13, color: AureColors.gris)),
              ),
              if (rutinas.isNotEmpty) const SizedBox(height: 8),
              for (final r in rutinas)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 38),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.$2,
                          style: sans(14, color: r.$3.state == 'on' ? AureColors.crema : AureColors.grisOscuro),
                        ),
                      ),
                      IconButton(
                        tooltip: t('rutina.borrar'),
                        onPressed: () async {
                          Tacto.toque();
                          await home.borrarAutomatizacion(r.$1);
                        },
                        icon: const Icon(Icons.close, size: 18, color: AureColors.gris),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
