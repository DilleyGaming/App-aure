import 'ha/ha_home.dart';
import 'i18n.dart';

/// Una rutina entendida en una frase: "todos los días a las 7 sube las persianas".
class RutinaDicha {
  const RutinaDicha(this.hora, this.minuto, this.dias, this.orden, this.cuando);

  final int hora;
  final int minuto;

  /// Días de Home Assistant (mon, tue…); vacío = todos los días.
  final List<String> dias;

  /// Lo que hay que hacer, tal cual lo dijiste.
  final String orden;

  /// Cómo lo decimos al confirmar: "todos los días", "de lunes a viernes"…
  final String cuando;

  String get horaTexto => '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';
}

const _laborables = ['mon', 'tue', 'wed', 'thu', 'fri'];
const _finde = ['sat', 'sun'];

const _diasEs = {
  'lunes': 'mon',
  'martes': 'tue',
  'miercoles': 'wed',
  'jueves': 'thu',
  'viernes': 'fri',
  'sabados': 'sat',
  'sabado': 'sat',
  'domingos': 'sun',
  'domingo': 'sun',
};

const _diasEn = {
  'monday': 'mon',
  'tuesday': 'tue',
  'wednesday': 'wed',
  'thursday': 'thu',
  'friday': 'fri',
  'saturday': 'sat',
  'sunday': 'sun',
};

String _sinTildes(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ñ', 'n');

/// Intenta entender una frase como rutina. Devuelve null si no lo es.
RutinaDicha? entenderRutina(String frase) {
  var f = _sinTildes(frase.trim()).replaceAll(RegExp(r'^(aure|oye aure|hey aure)[, ]+'), '');
  f = f.replaceAll(RegExp(r'[.!¡?¿]+$'), '').trim();

  // ¿Qué días?
  List<String>? dias;
  String? cuando;
  String? resto;
  final patronesDias = <(RegExp, List<String>, String)>[
    (RegExp(r'(todos los dias|cada dia|diariamente|every day|daily)'), const [], 'rutina.diario'),
    (RegExp(r'(de lunes a viernes|entre semana|los dias laborables|on weekdays|every weekday)'), _laborables, 'rutina.laborables'),
    (RegExp(r'(los fines de semana|el fin de semana|on weekends|every weekend)'), _finde, 'rutina.finde'),
  ];
  for (final (re, d, clave) in patronesDias) {
    final m = re.firstMatch(f);
    if (m != null) {
      dias = d;
      cuando = t(clave);
      resto = f.replaceRange(m.start, m.end, ' ');
      break;
    }
  }
  if (dias == null) {
    final m = RegExp(r'(?:todos )?los (lunes|martes|miercoles|jueves|viernes|sabados|domingos)|every (monday|tuesday|wednesday|thursday|friday|saturday|sunday)')
        .firstMatch(f);
    if (m != null) {
      final dia = m.group(1) != null ? _diasEs[m.group(1)!] : _diasEn[m.group(2)!];
      if (dia != null) {
        dias = [dia];
        cuando = m.group(0)!;
        resto = f.replaceRange(m.start, m.end, ' ');
      }
    }
  }
  if (dias == null || resto == null || cuando == null) return null;

  // ¿A qué hora?
  final h = RegExp(r'\b(?:a las?|at)\s+(\d{1,2})(?:[:.h](\d{2}))?\s*(?:h\b|horas?\b)?\s*(de la manana|de la tarde|de la noche|am|pm)?').firstMatch(resto);
  if (h == null) return null;
  var hora = int.parse(h.group(1)!);
  final minuto = int.tryParse(h.group(2) ?? '') ?? 0;
  final franja = h.group(3);
  if ((franja == 'de la tarde' || franja == 'de la noche' || franja == 'pm') && hora < 12) hora += 12;
  if (franja == 'am' && hora == 12) hora = 0;
  if (hora > 23 || minuto > 59) return null;

  // Lo que queda es la orden.
  final orden = resto
      .replaceRange(h.start, h.end, ' ')
      .replaceAll(RegExp(r'^\s*(,|y|que|quiero que|and)\s+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[ ,]+|[ ,]+$'), '')
      .trim();
  if (orden.length < 4) return null;
  // Recuperamos la orden con sus tildes y mayúsculas originales (mismas posiciones).
  final original = frase.trim();
  final normal = _sinTildes(original);
  final i = normal.length == original.length ? normal.indexOf(orden) : -1;
  final ordenOriginal = i >= 0 ? original.substring(i, i + orden.length) : orden;
  return RutinaDicha(hora, minuto, dias, ordenOriginal, cuando);
}

/// Habla con Auré. Si la frase es una rutina, la crea en la casa; si no, se la pasa al asistente.
Future<String> hablarConAure(HaHome home, String frase) async {
  final rutina = entenderRutina(frase);
  if (rutina == null) return home.talk(frase);
  if (!home.esAdmin) return t('rutina.soloPropietario');
  final error = await home.crearRutina(
    hora: rutina.hora,
    minuto: rutina.minuto,
    dias: rutina.dias,
    orden: rutina.orden,
    descripcion: '${rutina.cuando} ${rutina.horaTexto} · ${rutina.orden}',
  );
  if (error != null) return error;
  return t('rutina.hecha', {'cuando': rutina.cuando, 'h': rutina.horaTexto, 'o': rutina.orden});
}
