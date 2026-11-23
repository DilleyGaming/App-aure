import 'dart:async';

import 'package:flutter/material.dart';

import '../dispositivo.dart';
import '../i18n.dart';
import '../permisos.dart';
import '../theme.dart';
import 'common.dart';

/// Tarjeta que sube desde abajo cuando Auré necesita permiso para hacer algo.
class PermisoOverlay extends StatelessWidget {
  const PermisoOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([PermisosStore.i, DispositivoStore.i]),
      builder: (context, _) {
        // Las pantallas de pared las usa cualquiera: allí no se aprueban permisos.
        final p = DispositivoStore.i.esPared || PermisosStore.i.pendientes.isEmpty
            ? null
            : PermisosStore.i.pendientes.first;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            child: p == null
                ? const SizedBox.shrink(key: ValueKey('vacio'))
                : _Tarjeta(key: ValueKey(p.id), permiso: p, mas: PermisosStore.i.pendientes.length - 1),
          ),
        );
      },
    );
  }
}

class _Tarjeta extends StatefulWidget {
  const _Tarjeta({super.key, required this.permiso, required this.mas});

  final Permiso permiso;
  final int mas;

  @override
  State<_Tarjeta> createState() => _TarjetaState();
}

class _TarjetaState extends State<_Tarjeta> {
  Timer? _reloj;
  bool _recordar = false;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _responder(bool aprobado) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    aprobado ? Tacto.confirmar() : Tacto.toque();
    final ok = await PermisosStore.i.responder(widget.permiso, aprobado, recordar: _recordar);
    if (!ok && mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.permiso;
    final quedan = p.expira.difference(DateTime.now());
    final mm = quedan.inMinutes.clamp(0, 99);
    final ss = (quedan.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final puedeRecordar = !p.seguro && p.clave.isNotEmpty;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: AureColors.panelAlto,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AureColors.dorado.withValues(alpha: 0.55)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(p.seguro ? Icons.verified_user_outlined : Icons.help_outline,
                          color: AureColors.dorado, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t('perm.pide'), style: sans(13, color: AureColors.gris))),
                      Text('$mm:$ss', style: sans(13, color: AureColors.grisOscuro)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(p.titulo, style: serif(22, height: 1.25)),
                  if (p.detalle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(p.detalle, style: sans(14, color: AureColors.gris)),
                  ],
                  if (p.importe.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(p.importe, style: serif(20, color: AureColors.doradoClaro)),
                  ],
                  if (p.seguro) ...[
                    const SizedBox(height: 8),
                    Text(t('perm.seguro'), style: sans(13, color: AureColors.grisOscuro)),
                  ],
                  if (puedeRecordar) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AureToggle(value: _recordar, onChanged: (v) => setState(() => _recordar = v)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t('perm.siempre'), style: sans(14))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          label: t('perm.rechazar'),
                          onTap: _ocupado ? null : () => _responder(false),
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AureColors.linea),
                            ),
                            child: Text(t('perm.rechazar'), style: sans(15)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Pressable(
                          label: t('perm.permitir'),
                          onTap: _ocupado ? null : () => _responder(true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _ocupado ? AureColors.panel : AureColors.dorado,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(t('perm.permitir'),
                                style: sans(15, weight: FontWeight.w600, color: AureColors.negro)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.mas > 0) ...[
                    const SizedBox(height: 10),
                    Center(child: Text(t('perm.mas', {'n': '${widget.mas}'}), style: sans(12, color: AureColors.grisOscuro))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Registro de lo que se ha permitido o rechazado.
class HistorialPermisos extends StatelessWidget {
  const HistorialPermisos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AureColors.negro,
        surfaceTintColor: Colors.transparent,
        title: Text(t('perm.titulo'), style: serif(24)),
      ),
      body: ListenableBuilder(
        listenable: PermisosStore.i,
        builder: (context, _) {
          final st = PermisosStore.i;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
                children: [
                  Text(t('perm.explica'), style: sans(14, color: AureColors.gris)),
                  const SizedBox(height: 20),
                  if (st.siempre.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
                      decoration: aureCard(radius: 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(t('perm.permitidos', {'n': '${st.siempre.length}'}), style: sans(15)),
                          ),
                          TextButton(
                            onPressed: st.olvidarPermitidos,
                            child: Text(t('perm.olvidar'), style: sans(14, color: AureColors.dorado)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (st.historial.isEmpty)
                    Text(t('perm.vacio'), style: sans(15, color: AureColors.grisOscuro))
                  else
                    for (final d in st.historial)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AureColors.linea))),
                        child: Row(
                          children: [
                            Icon(d.aprobado ? Icons.check_circle_outline : Icons.block,
                                color: d.aprobado ? AureColors.dorado : AureColors.grisOscuro, size: 20),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.titulo, style: sans(15)),
                                  Text(
                                    '${d.aprobado ? t('perm.aprobado') : t('perm.rechazado')}'
                                    '${d.automatico ? ' · ${t('perm.auto')}' : ''} · '
                                    '${d.cuando.day}/${d.cuando.month} ${d.cuando.hour.toString().padLeft(2, '0')}:${d.cuando.minute.toString().padLeft(2, '0')}',
                                    style: sans(12, color: AureColors.grisOscuro),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
