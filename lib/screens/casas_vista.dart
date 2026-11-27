import 'package:flutter/material.dart';

import '../casas.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/hoja.dart';
import 'personalizar.dart';

/// Mis casas: cambiar de casa con un toque, renombrarlas o añadir otra.
void abrirCasas(BuildContext context) {
  final store = CasasStore.i;
  abrirHoja<void>(context, builder: (hoja) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AsaHoja(),
            const SizedBox(height: 6),
            Text(t('casas.titulo'), style: serif(26)),
            const SizedBox(height: 4),
            Text(t('casas.una'), style: sans(13, color: AureColors.gris)),
            const SizedBox(height: 16),
            for (final c in store.casas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Pressable(
                  label: c.nombre,
                  onTap: () {
                    if (c.id == store.activa) return;
                    Tacto.confirmar();
                    Navigator.pop(hoja);
                    store.alCambiar?.call(c.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                    decoration: aureCard(active: c.id == store.activa, radius: 18),
                    child: Row(
                      children: [
                        Icon(
                          c.id == store.activa ? Icons.home : Icons.home_outlined,
                          color: AureColors.dorado,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.nombre, style: sans(16, weight: FontWeight.w500)),
                              Text(
                                c.id == store.activa ? t('casas.activa') : CasaGuardada.nombreDe(c.casa),
                                style: sans(12, color: c.id == store.activa ? AureColors.dorado : AureColors.grisOscuro),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AureColors.gris),
                          color: AureColors.panelAlto,
                          onSelected: (accion) async {
                            if (accion == 'nombre') {
                              final nuevo = await pedirTexto(context, t('casas.nombre'), c.nombre, t('casas.nombreAyuda'));
                              if (nuevo != null) await store.renombrar(c.id, nuevo);
                            } else if (accion == 'quitar') {
                              final si = await showDialog<bool>(
                                context: context,
                                builder: (d) => AlertDialog(
                                  backgroundColor: AureColors.panelAlto,
                                  content: Text(t('casas.quitarPregunta', {'c': c.nombre}), style: sans(15)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: Text(t('comun.cancelar'), style: sans(14, color: AureColors.gris)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: Text(t('casas.quitar'), style: sans(14, color: AureColors.dorado)),
                                    ),
                                  ],
                                ),
                              );
                              if (si == true) await store.olvidar(c.id);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'nombre', child: Text(t('casas.renombrar'), style: sans(14))),
                            if (c.id != store.activa)
                              PopupMenuItem(value: 'quitar', child: Text(t('casas.quitar'), style: sans(14))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Pressable(
              label: t('casas.anadir'),
              onTap: () {
                Navigator.pop(hoja);
                store.alAnadir?.call();
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AureColors.dorado),
                ),
                child: Text(t('casas.anadir'), style: sans(15, color: AureColors.doradoClaro)),
              ),
            ),
          ],
        ),
      ),
    );
  });
}

/// Pastilla con el nombre de la casa (solo si hay más de una): toca para cambiar.
class SelectorCasa extends StatelessWidget {
  const SelectorCasa({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CasasStore.i;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final actual = store.actual;
        if (store.casas.length < 2 || actual == null) return const SizedBox.shrink();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Pressable(
            label: t('casas.titulo'),
            onTap: () => abrirCasas(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: AureColors.panel,
                border: Border.all(color: AureColors.dorado.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.home_outlined, size: 16, color: AureColors.dorado),
                  const SizedBox(width: 8),
                  Text(actual.nombre, style: sans(13, color: AureColors.doradoClaro)),
                  const SizedBox(width: 6),
                  const Icon(Icons.unfold_more, size: 16, color: AureColors.gris),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
