import 'ha/ha_home.dart';
import 'i18n.dart';

String saludo([DateTime? ahora]) {
  final h = (ahora ?? DateTime.now()).hour;
  if (h < 6) return t('saludo.noche');
  if (h < 13) return t('saludo.manana');
  if (h < 21) return t('saludo.tarde');
  return t('saludo.noche');
}

/// "miércoles, 14 de octubre" / "Wednesday, 14 October" / "الأربعاء، 14 أكتوبر"
String fechaLarga(DateTime d) {
  final i = I18n.i.idioma.index;
  final dia = diasSemana[i][d.weekday - 1];
  final mes = mesesAno[i][d.month - 1];
  return switch (I18n.i.idioma) {
    Idioma.es => '$dia, ${d.day} de $mes',
    Idioma.en => '$dia, ${d.day} $mes',
    Idioma.ar => '$dia، ${d.day} $mes',
    Idioma.fr => '$dia ${d.day} $mes',
    Idioma.ru => '$dia, ${d.day} $mes',
    Idioma.hi => '$dia, ${d.day} $mes',
  };
}

String hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _numero(double n) {
  final texto = n.toStringAsFixed(1);
  const conComa = {Idioma.es, Idioma.fr, Idioma.ru};
  return conComa.contains(I18n.i.idioma) ? texto.replaceAll('.', ',') : texto;
}

String grados(double n) => _numero(n);

String resumenCasa(HaHome h) {
  if (h.status == HaStatus.connecting) return t('resumen.conectando');
  if (h.status == HaStatus.error) return h.error ?? t('resumen.sinConexion');
  final n = h.lightsOn;
  final luces = n == 0
      ? t('resumen.lucesApagadas')
      : n == 1
          ? t('resumen.unaLuz')
          : t('resumen.nLuces', {'n': '$n'});
  final temp = h.insideTemp;
  return temp == null ? luces : '$luces  ·  ${t('resumen.dentro', {'t': grados(temp)})}';
}

/// Resumen del día en una frase: tiempo, temperatura, agenda y estado de la casa.
String resumenDia(HaHome h, List<Evento> eventos) {
  final partes = <String>[];
  final tiempo = h.tiempo;
  final fuera = tiempo?.attributes['temperature'];
  if (tiempo != null && fuera is num) {
    final clave = 'tiempo.${tiempo.state}';
    final condicion = t(clave) == clave ? tiempo.state : t(clave);
    partes.add(t('brief.fuera', {'t': grados(fuera.toDouble()), 'c': condicion}));
  }
  final dentro = h.insideTemp;
  if (dentro != null) partes.add(t('brief.dentro', {'t': grados(dentro)}));
  if (eventos.isEmpty) {
    partes.add(t('brief.sinEventos'));
  } else {
    final lista = eventos.take(3).map((e) {
      final cuando = e.todoElDia ? t('brief.todoDia') : hora(e.inicio);
      return '${e.titulo} ($cuando)';
    }).join(', ');
    partes.add(t('brief.eventos', {'lista': lista}));
  }
  final abiertas = h.persianasAbiertas;
  if (abiertas > 0) partes.add(t('brief.persianas', {'n': '$abiertas'}));
  if (h.playing > 0) partes.add(t('brief.musica'));
  return partes.join(' ');
}
