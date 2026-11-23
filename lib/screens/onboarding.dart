import 'package:flutter/material.dart';

import '../i18n.dart';
import '../theme.dart';
import '../widgets/breathing_orb.dart';
import '../widgets/common.dart';
import '../widgets/house_view.dart';

/// Bienvenida tras conectar la casa por primera vez: tres pantallas
/// en las que la casa se va iluminando mientras se presenta Auré.
class Bienvenida extends StatefulWidget {
  const Bienvenida({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<Bienvenida> createState() => _BienvenidaState();
}

class _BienvenidaState extends State<Bienvenida> {
  final _paginas = PageController();
  int _pagina = 0;

  static const _luces = <Map<String, double>>[
    {'porche': .9},
    {'porche': .9, 'salon': .7, 'comedor': .5, 'cocina': .4},
    {'porche': .9, 'salon': .8, 'comedor': .7, 'cocina': .6, 'dorm': .6, 'estudio': .6, 'garaje': .5},
  ];

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _siguiente() {
    Tacto.toque();
    if (_pagina == 2) {
      Tacto.confirmar();
      widget.alTerminar();
      return;
    }
    _paginas.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final niveles = {
      for (final z in ['salon', 'comedor', 'cocina', 'dorm', 'estudio', 'porche', 'garaje']) z: _luces[_pagina][z] ?? 0.0,
    };
    return Scaffold(
      backgroundColor: AureColors.negro,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 12, 26, 22),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: widget.alTerminar,
                      child: Text(t('bien.saltar'), style: sans(14, color: AureColors.gris)),
                    ),
                  ),
                  const Spacer(),
                  BreathingOrb(size: 92, mode: _pagina == 1 ? OrbMode.listening : OrbMode.idle),
                  const SizedBox(height: 22),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: HouseView(niveles: niveles, colores: const {}),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 170,
                    child: PageView(
                      controller: _paginas,
                      onPageChanged: (i) {
                        Tacto.toque();
                        setState(() => _pagina = i);
                      },
                      children: [
                        for (final n in [1, 2, 3])
                          Column(
                            children: [
                              Text(t('bien.${n}t'), textAlign: TextAlign.center, style: serif(32)),
                              const SizedBox(height: 12),
                              Text(
                                t('bien.${n}d'),
                                textAlign: TextAlign.center,
                                style: sans(16, color: AureColors.gris),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _pagina ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _pagina ? AureColors.dorado : AureColors.grisOscuro,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Pressable(
                    label: _pagina == 2 ? t('bien.empezar') : t('bien.siguiente'),
                    onTap: _siguiente,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AureColors.dorado,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _pagina == 2 ? t('bien.empezar') : t('bien.siguiente'),
                        style: sans(16, weight: FontWeight.w600, color: AureColors.negro),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
