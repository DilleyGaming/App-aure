import 'package:flutter/material.dart';

import '../dispositivo.dart';
import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// "¿Cómo se va a usar este dispositivo?" — móvil, tablet personal o pantalla de pared.
class ModoScreen extends StatefulWidget {
  const ModoScreen({super.key, required this.home, required this.alTerminar, this.cerrable = false});

  final HaHome home;
  final VoidCallback alTerminar;
  final bool cerrable;

  @override
  State<ModoScreen> createState() => _ModoScreenState();
}

class _ModoScreenState extends State<ModoScreen> {
  late ModoDispositivo _modo;
  String? _area;

  @override
  void initState() {
    super.initState();
    final d = DispositivoStore.i;
    _area = d.area;
    if (d.configurado) {
      _modo = d.modo;
    } else {
      // Sugerencia según el tamaño de la pantalla.
      final corta = WidgetsBinding.instance.platformDispatcher.views.first;
      final lado = corta.physicalSize.shortestSide / corta.devicePixelRatio;
      _modo = lado < 600 ? ModoDispositivo.movil : ModoDispositivo.tablet;
    }
  }

  bool get _valido => _modo != ModoDispositivo.pared || _area != null;

  Future<void> _guardar() async {
    if (!_valido) return;
    Tacto.confirmar();
    await DispositivoStore.i.elegir(_modo, areaPared: _area);
    widget.alTerminar();
  }

  @override
  Widget build(BuildContext context) {
    final opciones = [
      (ModoDispositivo.movil, Icons.smartphone_outlined, 'modo.movil', 'modo.movilSub'),
      (ModoDispositivo.tablet, Icons.tablet_outlined, 'modo.tablet', 'modo.tabletSub'),
      (ModoDispositivo.pared, Icons.tablet_mac_outlined, 'modo.pared', 'modo.paredSub'),
    ];
    return Scaffold(
      appBar: widget.cerrable
          ? AppBar(backgroundColor: AureColors.negro, surfaceTintColor: Colors.transparent)
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListenableBuilder(
              listenable: widget.home,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                children: [
                  aureLogo(size: 40),
                  const SizedBox(height: 22),
                  Text(t('modo.titulo'), style: serif(32)),
                  const SizedBox(height: 8),
                  Text(t('modo.sub'), style: sans(15, color: AureColors.gris)),
                  const SizedBox(height: 26),
                  for (final op in opciones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Pressable(
                        label: t(op.$3),
                        onTap: () => setState(() => _modo = op.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(18),
                          decoration: aureCard(active: _modo == op.$1, radius: 20),
                          child: Row(
                            children: [
                              Icon(op.$2, color: _modo == op.$1 ? AureColors.dorado : AureColors.grisOscuro, size: 28),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t(op.$3), style: sans(17, weight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(t(op.$4), style: sans(14, color: AureColors.gris)),
                                  ],
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: _modo == op.$1 ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.check_circle, color: AureColors.dorado),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_modo == ModoDispositivo.pared) ...[
                    const SizedBox(height: 14),
                    Text(t('modo.donde'), style: sans(15, color: AureColors.gris)),
                    const SizedBox(height: 10),
                    if (widget.home.areas.isEmpty)
                      Text(t('modo.sinAreas'), style: sans(14, color: AureColors.grisOscuro))
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final a in widget.home.areas)
                            Pressable(
                              label: a.name,
                              onTap: () => setState(() => _area = a.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                decoration: BoxDecoration(
                                  color: _area == a.id ? AureColors.dorado : AureColors.panel,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AureColors.linea),
                                ),
                                child: Text(a.name, style: sans(14, color: _area == a.id ? AureColors.negro : AureColors.crema)),
                              ),
                            ),
                        ],
                      ),
                  ],
                  const SizedBox(height: 30),
                  Pressable(
                    label: t('comun.guardar'),
                    onTap: _valido ? _guardar : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _valido ? AureColors.dorado : AureColors.panelAlto,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(t('modo.listo'), style: sans(16, weight: FontWeight.w600, color: AureColors.negro)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(t('modo.cambiar'), textAlign: TextAlign.center, style: sans(13, color: AureColors.grisOscuro)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
