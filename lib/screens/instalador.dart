import 'package:flutter/material.dart';

import '../ha/ha_home.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/avisos.dart';
import '../widgets/common.dart';

void abrirInstalador(BuildContext context, HaHome home) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InstaladorScreen(home: home)));
}

/// Modo instalador: comprobar en minutos que toda la casa responde.
class InstaladorScreen extends StatelessWidget {
  const InstaladorScreen({super.key, required this.home});

  final HaHome home;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AureColors.negro,
      appBar: AppBar(
        backgroundColor: AureColors.negro,
        surfaceTintColor: Colors.transparent,
        title: Text(t('inst.titulo'), style: serif(24)),
      ),
      body: ListenableBuilder(
        listenable: home,
        builder: (context, _) {
          final micros = home.satelitesEn(null);
          final sinEstancia = micros.where((m) => home.areaOf(m.id) == null).toList();
          final fallan = home.noResponden;
          final pilas = home.pilas;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Resumen
              Container(
                padding: const EdgeInsets.all(18),
                decoration: aureCard(radius: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(home.status == HaStatus.connected ? Icons.check_circle_outline : Icons.error_outline,
                            color: home.status == HaStatus.connected ? AureColors.dorado : const Color(0xFFE8A87C)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            home.status == HaStatus.connected ? t('inst.conectada') : t('inst.sinConexion'),
                            style: sans(16, weight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(home.baseUrl + (home.usandoFuera ? '  ·  ${t('dir.usandoFuera')}' : ''),
                        style: sans(12, color: AureColors.grisOscuro)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        _cifra('${home.areas.length}', t('inst.estancias')),
                        _cifra('${home.devices.length}', t('inst.aparatos')),
                        _cifra('${micros.length}', t('inst.micros')),
                        _cifra('${home.camaras.length}', t('inst.camaras')),
                        _cifra('${fallan.length}', t('inst.fallan')),
                      ],
                    ),
                  ],
                ),
              ),

              // Lo que no responde
              const SizedBox(height: 24),
              _titulo(fallan.isEmpty ? t('inst.todoResponde') : t('inst.noResponden')),
              for (final e in fallan.take(30))
                _fila(Icons.portable_wifi_off, e.name, home.areaName(home.areaOf(e.id)) ?? t('inst.sinEstancia'), aviso: true),
              if (sinEstancia.isNotEmpty) ...[
                const SizedBox(height: 18),
                _titulo(t('inst.microsSinEstancia')),
                for (final m in sinEstancia) _fila(Icons.mic_off_outlined, m.name, t('inst.asignaEstancia'), aviso: true),
              ],

              // Estancia por estancia
              const SizedBox(height: 24),
              _titulo(t('inst.porEstancia')),
              for (final a in home.areas) _Estancia(home: home, area: a),

              // Pilas
              if (pilas.isNotEmpty) ...[
                const SizedBox(height: 24),
                _titulo(t('inst.pilas')),
                for (final (e, nivel) in pilas)
                  _fila(
                    nivel == null ? Icons.battery_full : (nivel <= 15 ? Icons.battery_alert : Icons.battery_std),
                    e.name,
                    nivel == null ? t('inst.pilaBien') : '${nivel.round()} %',
                    aviso: nivel != null && nivel <= 15,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cifra(String valor, String texto) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor, style: serif(26)),
          Text(texto, style: sans(12, color: AureColors.gris)),
        ],
      );

  Widget _titulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texto, style: serif(20, color: AureColors.doradoClaro)),
      );

  Widget _fila(IconData icono, String titulo, String sub, {bool aviso = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icono, size: 20, color: aviso ? const Color(0xFFE8A87C) : AureColors.dorado),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: sans(14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(sub, style: sans(12, color: AureColors.gris)),
          ],
        ),
      );
}

class _Estancia extends StatelessWidget {
  const _Estancia({required this.home, required this.area});

  final HaHome home;
  final HaArea area;

  @override
  Widget build(BuildContext context) {
    final aparatos = home.inArea(area.id);
    final luces = aparatos.where((e) => e.domain == 'light').length;
    final micros = home.satelitesEn(area.id);
    final microsBien = micros.every((m) => m.state != 'unavailable' && m.state != 'unknown');
    Widget boton(IconData icono, String texto, VoidCallback onTap) => Expanded(
          child: Pressable(
            label: texto,
            onTap: () {
              Tacto.confirmar();
              onTap();
            },
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AureColors.dorado.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 16, color: AureColors.dorado),
                  const SizedBox(width: 6),
                  Flexible(child: Text(texto, style: sans(13, color: AureColors.doradoClaro), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: aureCard(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(area.name, style: sans(16, weight: FontWeight.w500))),
              if (micros.isNotEmpty)
                Text(
                  microsBien ? t('inst.microListo') : t('inst.microNoResponde'),
                  style: sans(12, color: microsBien ? AureColors.dorado : const Color(0xFFE8A87C)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t('inst.resumenEstancia', {'a': '${aparatos.length}', 'l': '$luces', 'm': '${micros.length}'}),
            style: sans(12, color: AureColors.gris),
          ),
          if (luces > 0 || micros.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (luces > 0) boton(Icons.flare, t('inst.parpadear'), () => home.parpadear(area.id)),
                if (luces > 0 && micros.isNotEmpty) const SizedBox(width: 10),
                if (micros.isNotEmpty)
                  boton(Icons.campaign_outlined, t('inst.probarVoz'), () {
                    home.probarVoz(area.id, t('inst.mensajePrueba', {'a': area.name}));
                    Avisos.mostrar(context, t('inst.escucha'), icono: Icons.campaign_outlined);
                  }),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
