import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum Idioma { es, en, ar }

/// Idioma de la app. Al cambiarlo, toda la app se redibuja.
class I18n extends ChangeNotifier {
  I18n._();

  static final I18n i = I18n._();
  static const _almacen = FlutterSecureStorage();

  Idioma idioma = Idioma.es;

  String get codigo => idioma.name;
  bool get rtl => idioma == Idioma.ar;
  TextDirection get direccion => rtl ? TextDirection.rtl : TextDirection.ltr;

  Future<void> cargar() async {
    final guardado = await _almacen.read(key: 'idioma');
    for (final id in Idioma.values) {
      if (id.name == guardado) idioma = id;
    }
  }

  /// Se llama al cambiar de idioma (por ejemplo, para traducir los accesos directos).
  static void Function()? alCambiar;

  Future<void> cambiar(Idioma nuevo) async {
    idioma = nuevo;
    notifyListeners();
    alCambiar?.call();
    await _almacen.write(key: 'idioma', value: nuevo.name);
  }
}

/// Traduce una clave. Los valores entre llaves {así} se sustituyen.
String t(String clave, [Map<String, String>? valores]) {
  var texto = _textos[clave]?[I18n.i.idioma.index] ?? clave;
  valores?.forEach((k, v) => texto = texto.replaceAll('{$k}', v));
  return texto;
}

const diasSemana = <List<String>>[
  ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'],
  ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'],
];

const mesesAno = <List<String>>[
  ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'],
  ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'],
];

// [español, inglés, árabe]
const _textos = <String, List<String>>{
  // General
  'app.lema': ['Tu casa, en buenas manos.', 'Your home, in good hands.', 'منزلك في أيدٍ أمينة.'],
  'saludo.manana': ['Buenos días', 'Good morning', 'صباح الخير'],
  'saludo.tarde': ['Buenas tardes', 'Good afternoon', 'مساء الخير'],
  'saludo.noche': ['Buenas noches', 'Good evening', 'مساء الخير'],
  'comun.borrar': ['Borrar', 'Delete', 'حذف'],
  'comun.cancelar': ['Cancelar', 'Cancel', 'إلغاء'],
  'comun.guardar': ['Guardar', 'Save', 'حفظ'],
  'comun.mostrar': ['Mostrar', 'Show', 'إظهار'],
  'comun.ocultar': ['Ocultar', 'Hide', 'إخفاء'],
  'comun.cerrar': ['Cerrar', 'Close', 'إغلاق'],

  // Resumen
  'resumen.conectando': ['Conectando con tu casa…', 'Connecting to your home…', 'جارٍ الاتصال بمنزلك…'],
  'resumen.sinConexion': ['Sin conexión con la casa', 'No connection to your home', 'لا يوجد اتصال بالمنزل'],
  'resumen.lucesApagadas': ['Todas las luces apagadas', 'All lights are off', 'جميع الأضواء مطفأة'],
  'resumen.unaLuz': ['1 luz encendida', '1 light on', 'ضوء واحد مضاء'],
  'resumen.nLuces': ['{n} luces encendidas', '{n} lights on', '{n} أضواء مضاءة'],
  'resumen.dentro': ['{t} °C dentro', '{t} °C inside', '{t} °م في الداخل'],

  // Errores
  'error.token': ['El token no es válido.', 'The token is not valid.', 'رمز الوصول غير صالح.'],
  'error.respuesta': ['La casa respondió con un error ({c}).', 'Your home replied with an error ({c}).', 'أرسل المنزل خطأً ({c}).'],
  'error.conexion': [
    'No puedo conectar con la casa. Revisa la dirección.',
    "I can't reach your home. Check the address.",
    'لا أستطيع الوصول إلى منزلك. تحقّق من العنوان.',
  ],

  // Conectar
  'conectar.direccion': ['Dirección de la casa', 'Home address', 'عنوان المنزل'],
  'conectar.token': ['Token de acceso', 'Access token', 'رمز الوصول'],
  'conectar.boton': ['Conectar con mi casa', 'Connect to my home', 'اتصل بمنزلي'],
  'conectar.conectando': ['Conectando…', 'Connecting…', 'جارٍ الاتصال…'],
  'conectar.faltan': ['Escribe la dirección y el token.', 'Enter the address and the token.', 'أدخل العنوان والرمز.'],
  'conectar.fallo': ['No he podido conectar con la casa.', "I couldn't connect to your home.", 'تعذّر الاتصال بمنزلك.'],
  'conectar.ayuda': [
    'El token se crea en Home Assistant: tu perfil → Seguridad → Tokens de acceso de larga duración.',
    'Create the token in Home Assistant: your profile → Security → Long-lived access tokens.',
    'يُنشأ الرمز في Home Assistant: ملفك الشخصي ← الأمان ← رموز الوصول طويلة الأمد.',
  ],

  // Navegación y ajustes
  'nav.inicio': ['Inicio', 'Home', 'الرئيسية'],
  'nav.habitaciones': ['Habitaciones', 'Rooms', 'الغرف'],
  'nav.escenas': ['Escenas', 'Scenes', 'المشاهد'],
  'nav.ajustes': ['Ajustes', 'Settings', 'الإعدادات'],
  'hablar.boton': ['Hablar con Auré', 'Talk to Auré', 'تحدّث مع أوري'],
  'ajustes.conectada': ['Conectada a {url}', 'Connected to {url}', 'متصل بـ {url}'],
  'ajustes.preferencias': ['Mis preferencias', 'My preferences', 'تفضيلاتي'],
  'ajustes.preferenciasSub': ['Temperatura, luz, idioma y perfil', 'Temperature, light, language and profile', 'الحرارة والإضاءة واللغة والملف الشخصي'],
  'ajustes.reposo': ['Ver el modo reposo', 'Show rest mode', 'عرض وضع الاستراحة'],
  'ajustes.reposoSub': ['Así se ve una tablet de pared en espera', 'How a wall tablet looks while waiting', 'هكذا تبدو اللوحة الجدارية في وضع الانتظار'],
  'ajustes.desconectar': ['Desconectar esta casa', 'Disconnect this home', 'فصل هذا المنزل'],
  'aviso.cambiar': ['Cambiar', 'Change', 'تغيير'],

  // Inicio
  'inicio.luces': ['luces encendidas', 'lights on', 'أضواء مضاءة'],
  'inicio.dentro': ['dentro', 'inside', 'في الداخل'],
  'inicio.sonando': ['sonando', 'playing', 'قيد التشغيل'],
  'inicio.verTodas': ['Ver todas', 'See all', 'عرض الكل'],
  'inicio.tuDia': ['Tu día', 'Your day', 'يومك'],
  'reposo.pista': ['Di «Auré» o toca la pantalla', 'Say "Auré" or tap the screen', 'قل «أوري» أو المس الشاشة'],

  // Resumen del día
  'brief.fuera': ['Fuera {t} °C, {c}.', 'Outside {t} °C, {c}.', 'في الخارج {t} °م، {c}.'],
  'brief.dentro': ['Dentro {t} °C.', 'Inside {t} °C.', 'في الداخل {t} °م.'],
  'brief.sinEventos': ['No tienes nada en la agenda hoy.', 'Nothing on your calendar today.', 'لا شيء في جدولك اليوم.'],
  'brief.eventos': ['Hoy: {lista}.', 'Today: {lista}.', 'اليوم: {lista}.'],
  'brief.persianas': ['{n} persianas abiertas.', '{n} blinds open.', '{n} ستائر مفتوحة.'],
  'brief.musica': ['Hay música sonando.', 'Music is playing.', 'هناك موسيقى قيد التشغيل.'],
  'brief.todoDia': ['todo el día', 'all day', 'طوال اليوم'],
  'tiempo.sunny': ['soleado', 'sunny', 'مشمس'],
  'tiempo.clear-night': ['despejado', 'clear', 'صافٍ'],
  'tiempo.cloudy': ['nublado', 'cloudy', 'غائم'],
  'tiempo.partlycloudy': ['parcialmente nublado', 'partly cloudy', 'غائم جزئياً'],
  'tiempo.rainy': ['lluvioso', 'rainy', 'ممطر'],
  'tiempo.pouring': ['lluvia fuerte', 'heavy rain', 'أمطار غزيرة'],
  'tiempo.snowy': ['nieve', 'snow', 'ثلوج'],
  'tiempo.fog': ['niebla', 'fog', 'ضباب'],
  'tiempo.windy': ['viento', 'windy', 'عاصف'],
  'tiempo.lightning': ['tormenta', 'thunderstorm', 'عاصفة رعدية'],
  'tiempo.lightning-rainy': ['tormenta con lluvia', 'storm with rain', 'عاصفة ممطرة'],
  'tiempo.hail': ['granizo', 'hail', 'برد'],
  'tiempo.exceptional': ['tiempo extremo', 'extreme weather', 'طقس استثنائي'],

  // Habitaciones
  'hab.subtitulo': ['Toca una para ver y controlar sus aparatos', 'Tap one to see and control its devices', 'المس غرفة لعرض أجهزتها والتحكم بها'],
  'hab.otros': ['Otros dispositivos', 'Other devices', 'أجهزة أخرى'],
  'hab.vacia': ['Aún no hay aparatos en esta casa.', 'There are no devices in this home yet.', 'لا توجد أجهزة في هذا المنزل بعد.'],
  'hab.aparatos': ['{n} aparatos', '{n} devices', '{n} أجهزة'],
  'hab.activos': ['{a} de {n} activos', '{a} of {n} active', '{a} من {n} نشطة'],
  'hab.apagarLuces': ['Apagar luces', 'Lights off', 'إطفاء الأضواء'],
  'hab.consejo': [
    'Consejo: asigna tus aparatos a habitaciones en Home Assistant (Configuración → Áreas) y aparecerán aquí organizados.',
    "Tip: assign your devices to rooms in Home Assistant (Settings → Areas) and they'll appear here organised.",
    'نصيحة: خصّص أجهزتك للغرف في Home Assistant (الإعدادات ← المناطق) وستظهر هنا مرتّبة.',
  ],

  // Escenas
  'esc.subtitulo': ['Toda la casa cambia con un solo toque', 'Your whole home changes with one touch', 'يتغيّر منزلك كله بلمسة واحدة'],
  'esc.bienvenida': ['Bienvenida', 'Welcome', 'ترحيب'],
  'esc.bienvenidaSub': ['Tu luz y tu temperatura favoritas', 'Your favourite light and temperature', 'ضوؤك وحرارتك المفضّلان'],
  'esc.cena': ['Modo cena', 'Dinner', 'وضع العشاء'],
  'esc.cenaSub': ['Ambiente suave al 30 %', 'Soft ambience at 30%', 'أجواء هادئة بنسبة 30٪'],
  'esc.noches': ['Buenas noches', 'Good night', 'تصبح على خير'],
  'esc.nochesSub': ['Apaga luces y baja persianas', 'Lights off and blinds down', 'إطفاء الأضواء وإنزال الستائر'],
  'esc.salgo': ['Salgo de casa', 'Leaving home', 'مغادرة المنزل'],
  'esc.salgoSub': ['Todo apagado y música en pausa', 'Everything off and music paused', 'إطفاء كل شيء وإيقاف الموسيقى'],
  'esc.tuyas': ['Tus escenas', 'Your scenes', 'مشاهدك'],
  'esc.crear': ['Crear escena', 'Create scene', 'إنشاء مشهد'],
  'esc.crearSub': ['Elige aparatos y cómo quedan', 'Choose devices and how they look', 'اختر الأجهزة وحالتها'],
  'esc.borrar': ['¿Borrar la escena «{n}»?', 'Delete the scene "{n}"?', 'حذف المشهد «{n}»؟'],
  'esc.mantenerBorrar': ['Mantén pulsada una escena para borrarla.', 'Long-press a scene to delete it.', 'اضغط مطولاً على مشهد لحذفه.'],

  // Editor de escenas
  'editor.titulo': ['Nueva escena', 'New scene', 'مشهد جديد'],
  'editor.nombre': ['Nombre de la escena', 'Scene name', 'اسم المشهد'],
  'editor.icono': ['Icono', 'Icon', 'الأيقونة'],
  'editor.aparatos': ['Aparatos', 'Devices', 'الأجهزة'],
  'editor.ayuda': [
    'Activa los aparatos que formarán parte de la escena y elige cómo deben quedar.',
    'Switch on the devices that will be part of the scene and choose how they should be.',
    'فعّل الأجهزة التي ستكون جزءاً من المشهد واختر حالتها.',
  ],
  'editor.faltaNombre': ['Ponle un nombre a la escena.', 'Give the scene a name.', 'أعطِ المشهد اسماً.'],
  'editor.faltaAparato': ['Elige al menos un aparato.', 'Choose at least one device.', 'اختر جهازاً واحداً على الأقل.'],
  'editor.sinPermiso': ['Solo el propietario puede guardar escenas.', 'Only the owner can save scenes.', 'يمكن للمالك فقط حفظ المشاهد.'],
  'editor.error': ['No he podido guardar la escena.', "I couldn't save the scene.", 'تعذّر حفظ المشهد.'],
  'editor.guardada': [
    'Escena guardada. Ya puedes pedírsela a Auré por su nombre.',
    'Scene saved. You can now ask Auré for it by name.',
    'تم حفظ المشهد. يمكنك الآن طلبه من أوري باسمه.',
  ],

  // Aparatos
  'disp.encendida': ['Encendida', 'On', 'مضاء'],
  'disp.apagada': ['Apagada', 'Off', 'مطفأ'],
  'disp.encendido': ['Encendido', 'On', 'يعمل'],
  'disp.apagado': ['Apagado', 'Off', 'متوقف'],
  'disp.abierta': ['Abierta', 'Open', 'مفتوحة'],
  'disp.cerrada': ['Cerrada', 'Closed', 'مغلقة'],
  'disp.abriendo': ['Abriendo…', 'Opening…', 'جارٍ الفتح…'],
  'disp.cerrando': ['Cerrando…', 'Closing…', 'جارٍ الإغلاق…'],
  'disp.subir': ['Subir', 'Up', 'رفع'],
  'disp.parar': ['Parar', 'Stop', 'إيقاف'],
  'disp.bajar': ['Bajar', 'Down', 'خفض'],
  'clima.heat': ['Calefacción', 'Heating', 'تدفئة'],
  'clima.cool': ['Frío', 'Cooling', 'تبريد'],
  'clima.auto': ['Automático', 'Auto', 'تلقائي'],
  'clima.dry': ['Deshumidificar', 'Dry', 'تجفيف'],
  'clima.fan': ['Ventilación', 'Fan', 'تهوية'],
  'clima.off': ['Apagado', 'Off', 'متوقف'],
  'clima.dentro': ['{m}  ·  {t} °C dentro', '{m}  ·  {t} °C inside', '{m}  ·  {t} °م في الداخل'],
  'clima.bajar': ['Bajar temperatura', 'Lower temperature', 'خفض الحرارة'],
  'clima.subir': ['Subir temperatura', 'Raise temperature', 'رفع الحرارة'],
  'musica.reproduciendo': ['Reproduciendo', 'Playing', 'قيد التشغيل'],
  'musica.pausa': ['En pausa', 'Paused', 'متوقف مؤقتاً'],
  'musica.pausar': ['Pausar', 'Pause', 'إيقاف مؤقت'],
  'musica.reproducir': ['Reproducir', 'Play', 'تشغيل'],

  // Conversación
  'talk.idle': ['Toca abajo para hablar con Auré', 'Tap below to talk to Auré', 'المس في الأسفل للتحدث مع أوري'],
  'talk.escucha': ['Te escucho', "I'm listening", 'أنا أستمع'],
  'talk.piensa': ['Pensando…', 'Thinking…', 'أفكّر…'],
  'talk.habla': ['Auré está respondiendo', 'Auré is answering', 'أوري يجيب'],
  'talk.pregunta': ['¿En qué te ayudo?', 'How can I help?', 'كيف أساعدك؟'],
  'talk.hint': ['Habla con Auré…', 'Talk to Auré…', 'تحدّث مع أوري…'],
  'talk.enviar': ['Enviar', 'Send', 'إرسال'],
  'talk.hecho': ['Listo.', 'Done.', 'تم.'],
  'nav.funciones': ['Funciones', 'Functions', 'الوظائف'],
  'talk.sinRespuesta': ['No tengo respuesta ahora mismo.', "I don't have an answer right now.", 'ليس لديّ ردّ الآن.'],
  'talk.error': ['No he podido hablar con la casa.', "I couldn't talk to your home.", 'لم أتمكن من التحدث مع المنزل.'],
  'talk.s1': ['¿Qué luces están encendidas?', 'Which lights are on?', 'ما الأضواء المضاءة؟'],
  'talk.s2': ['Apaga todas las luces', 'Turn off all the lights', 'أطفئ جميع الأضواء'],
  'talk.s3': ['Enciende todas las luces', 'Turn on all the lights', 'أضئ جميع الأضواء'],
  'talk.s4': ['¿Qué temperatura hace dentro?', "What's the temperature inside?", 'كم درجة الحرارة في الداخل؟'],

  'disp.deslizar': ['Desliza sobre la tarjeta para regular', 'Slide across the card to dim', 'مرّر على البطاقة لضبط الإضاءة'],
  'esc.vista': ['Así quedará tu casa', 'This is how your home will look', 'هكذا سيبدو منزلك'],
  'esc.activar': ['Activar escena', 'Activate scene', 'تفعيل المشهد'],
  'esc.activada': ['{n} activada', '{n} activated', 'تم تفعيل {n}'],
  'esc.mantener': ['Mantén pulsada una escena para ver cómo quedará la casa.', 'Long-press a scene to preview your home.', 'اضغط مطولاً على مشهد لمعاينة منزلك.'],
  'talk.historial': ['Conversación', 'Conversation', 'المحادثة'],
  'talk.cambios': ['Lo que ha cambiado', 'What changed', 'ما الذي تغيّر'],
  'talk.vacio': ['Aún no habéis hablado.', 'You haven\'t talked yet.', 'لم تتحدثا بعد.'],
  'tu': ['Tú', 'You', 'أنت'],
  'pref.noche': ['Modo noche', 'Night mode', 'الوضع الليلي'],
  'pref.nocheSub': ['De 23:00 a 7:00 la pantalla se atenúa sin cambiar los colores', 'From 11 pm to 7 am the screen dims without changing colours', 'من 11 مساءً إلى 7 صباحاً تخفت الشاشة دون تغيير الألوان'],
  'pref.brilloNoche': ['Brillo por la noche', 'Night brightness', 'السطوع ليلاً'],
  'pref.acento': ['Color de acento', 'Accent colour', 'لون التمييز'],
  'acento.champan': ['Oro champán', 'Champagne gold', 'ذهبي شمبانيا'],
  'acento.rosa': ['Oro rosa', 'Rose gold', 'ذهبي وردي'],
  'acento.plata': ['Plata', 'Silver', 'فضي'],
  'bien.1t': ['Esta es tu casa.', 'This is your home.', 'هذا منزلك.'],
  'bien.1d': ['Auré ya la conoce: sus luces, sus estancias y cómo la vivís.', 'Auré already knows it: its lights, its rooms and how you live in it.', 'أوري يعرفه بالفعل: إضاءته وغرفه وطريقة عيشكم فيه.'],
  'bien.2t': ['Háblale como a una persona.', 'Talk to it like a person.', 'تحدّث إليه كما تتحدث إلى شخص.'],
  'bien.2d': ['«Modo cena», «llego en diez minutos» o «¿viene alguien mañana?». Ella se encarga.', '"Dinner mode", "I\'ll be home in ten minutes" or "is anyone coming tomorrow?". It takes care of it.', '«وضع العشاء»، «سأصل خلال عشر دقائق» أو «هل سيأتي أحد غداً؟». وهو يتولى الأمر.'],
  'bien.3t': ['Tu casa, en buenas manos.', 'Your home, in good hands.', 'منزلك في أيدٍ أمينة.'],
  'bien.3d': ['Cuando no la necesites, esperará en silencio. Cuando la llames, estará lista.', 'When you don\'t need it, it waits in silence. When you call, it\'s ready.', 'عندما لا تحتاجه ينتظر بصمت، وعندما تناديه يكون جاهزاً.'],
  'bien.siguiente': ['Siguiente', 'Next', 'التالي'],
  'bien.empezar': ['Empezar', 'Get started', 'ابدأ'],
  'bien.saltar': ['Saltar', 'Skip', 'تخطّي'],
  'voz.noDisponible': ['Hablar por el micrófono está disponible en el móvil. Aquí puedes escribirle.', 'Talking by microphone is available on mobile. Here you can type.', 'التحدث عبر الميكروفون متاح على الهاتف. هنا يمكنك الكتابة.'],
  'voz.escuchando': ['Te escucho… habla cuando quieras', 'I\'m listening… speak whenever you like', 'أنا أستمع… تحدّث متى شئت'],
  'voz.tocar': ['Toca la luz para hablar', 'Touch the light to talk', 'المس الضوء للتحدث'],
  'voz.microfono': ['Hablar', 'Speak', 'تحدّث'],
  'alerta.agua': ['Hay agua en {n}. Revísalo cuanto antes.', 'Water detected at {n}. Please check it soon.', 'تم اكتشاف ماء في {n}. يرجى التحقق قريباً.'],
  'alerta.humo': ['Detectado humo en {n}.', 'Smoke detected at {n}.', 'تم اكتشاف دخان في {n}.'],
  'alerta.gas': ['Detectado gas en {n}. Ventila y sal de la estancia.', 'Gas detected at {n}. Ventilate and leave the room.', 'تم اكتشاف غاز في {n}. قم بالتهوية واخرج من الغرفة.'],
  'noche.ok': ['Todo cerrado y en orden. Que descanses.', 'Everything is closed and in order. Sleep well.', 'كل شيء مغلق ومنظّم. نوماً هانئاً.'],
  'noche.abierto': ['Antes de dormir: sigue abierto {lista}.', 'Before you sleep: {lista} is still open.', 'قبل النوم: ما زال {lista} مفتوحاً.'],
  'auto.titulo': ['Automatismos de la casa', 'Home automations', 'أتمتة المنزل'],
  'auto.llegada': ['Llegada automática', 'Automatic arrival', 'الوصول التلقائي'],
  'auto.llegadaSub': ['Al llegar alguien de noche, la casa enciende tu bienvenida. Usa la app de Home Assistant en el móvil de cada persona.', 'When someone arrives after dark, the home switches on your welcome. Uses the Home Assistant app on each person\'s phone.', 'عند وصول أحد ليلاً يُشغّل المنزل الترحيب. يستخدم تطبيق Home Assistant على هاتف كل شخص.'],
  'auto.vacaciones': ['Modo vacaciones', 'Holiday mode', 'وضع العطلة'],
  'auto.vacacionesSub': ['Enciende y apaga luces a horas naturales para que parezca que hay alguien.', 'Switches lights on and off at natural times so it looks like someone is home.', 'يشغّل الأضواء ويطفئها في أوقات طبيعية ليبدو أن أحداً في المنزل.'],
  'auto.activado': ['{n} activado', '{n} on', 'تم تفعيل {n}'],
  'auto.desactivado': ['{n} desactivado', '{n} off', 'تم إيقاف {n}'],
  'auto.error': ['No he podido guardar la automatización.', 'I couldn\'t save the automation.', 'تعذّر حفظ الأتمتة.'],
  'auto.sinPersonas': ['No hay personas configuradas en Home Assistant.', 'There are no people set up in Home Assistant.', 'لا يوجد أشخاص معرّفون في Home Assistant.'],
  'auto.sinLuces': ['No hay luces en esta casa.', 'There are no lights in this home.', 'لا توجد أضواء في هذا المنزل.'],
  'pref.voz': ['Responder en voz alta', 'Answer out loud', 'الرد بصوت عالٍ'],
  'pref.vozSub': ['Cuando le hablas, Auré te contesta con su voz', 'When you speak to Auré, it answers with its voice', 'عندما تتحدث إلى أوري يجيبك بصوته'],
  'modo.titulo': ['¿Cómo se va a usar este dispositivo?', 'How will this device be used?', 'كيف سيُستخدم هذا الجهاز؟'],
  'modo.sub': ['Auré se adapta a cada pantalla de la casa.', 'Auré adapts to every screen in the home.', 'يتكيّف أوري مع كل شاشة في المنزل.'],
  'modo.movil': ['Mi móvil', 'My phone', 'هاتفي'],
  'modo.movilSub': ['Lista para hablar, dentro y fuera de casa.', 'Ready to talk, at home and away.', 'جاهز للحديث داخل المنزل وخارجه.'],
  'modo.tablet': ['Mi tablet', 'My tablet', 'جهازي اللوحي'],
  'modo.tabletSub': ['El panel de la casa, con tu perfil.', 'The home panel, with your profile.', 'لوحة المنزل بملفك الشخصي.'],
  'modo.pared': ['Pantalla de pared', 'Wall screen', 'شاشة جدارية'],
  'modo.paredSub': ['Siempre encendida, en reposo y ligada a una estancia.', 'Always on, resting and tied to one room.', 'تعمل دائماً، في وضع الاستراحة ومرتبطة بغرفة.'],
  'modo.donde': ['¿En qué estancia está?', 'Which room is it in?', 'في أي غرفة توجد؟'],
  'modo.sinAreas': ['Crea las estancias en Home Assistant (Configuración → Áreas) para poder elegirla.', 'Create rooms in Home Assistant (Settings → Areas) to choose one.', 'أنشئ الغرف في Home Assistant (الإعدادات ← المناطق) لاختيار واحدة.'],
  'modo.listo': ['Listo', 'Done', 'تم'],
  'modo.cambiar': ['Puedes cambiarlo cuando quieras en Ajustes.', 'You can change this anytime in Settings.', 'يمكنك تغييره متى شئت من الإعدادات.'],
  'modo.ajuste': ['Este dispositivo', 'This device', 'هذا الجهاز'],
  'modo.reposoTablet': ['Reposo en esta tablet', 'Rest mode on this tablet', 'وضع الاستراحة لهذا الجهاز'],
  'modo.activado': ['Activado', 'On', 'مفعّل'],
  'modo.desactivado': ['Desactivado', 'Off', 'متوقف'],
  'modo.estaEstancia': ['Lo que hay en esta estancia', 'What is in this room', 'ما في هذه الغرفة'],
  'perm.notif': ['Auré necesita tu permiso', 'Auré needs your permission', 'أوري يحتاج إذنك'],
  'perm.pide': ['Auré te pide permiso', 'Auré is asking for permission', 'أوري يطلب إذنك'],
  'perm.seguro': ['Se confirmará con tu huella, Face ID o PIN.', 'You will confirm with your fingerprint, Face ID or PIN.', 'سيتم التأكيد ببصمتك أو Face ID أو الرمز.'],
  'perm.siempre': ['Permitir siempre esta acción', 'Always allow this action', 'السماح دائماً بهذا الإجراء'],
  'perm.permitir': ['Permitir', 'Allow', 'سماح'],
  'perm.rechazar': ['Rechazar', 'Decline', 'رفض'],
  'perm.mas': ['{n} peticiones más esperando', '{n} more requests waiting', '{n} طلبات أخرى بانتظارك'],
  'perm.titulo': ['Permisos de Auré', 'Auré permissions', 'أذونات أوري'],
  'perm.sub': ['Lo que has permitido o rechazado', 'What you have allowed or declined', 'ما سمحت به أو رفضته'],
  'perm.explica': ['Antes de comprar, pagar, abrir una puerta o usar un servicio nuevo, Auré te pide permiso aquí.', 'Before buying, paying, opening a door or using a new service, Auré asks for your permission here.', 'قبل الشراء أو الدفع أو فتح باب أو استخدام خدمة جديدة، يطلب أوري إذنك هنا.'],
  'perm.permitidos': ['{n} acciones permitidas siempre', '{n} actions always allowed', '{n} إجراءات مسموح بها دائماً'],
  'perm.olvidar': ['Volver a preguntar', 'Ask again', 'اسأل مجدداً'],
  'perm.vacio': ['Todavía no hay peticiones.', 'No requests yet.', 'لا توجد طلبات بعد.'],
  'perm.aprobado': ['Permitido', 'Allowed', 'مسموح'],
  'perm.rechazado': ['Rechazado', 'Declined', 'مرفوض'],
  'perm.auto': ['automático', 'automatic', 'تلقائي'],
  // Preferencias
  'pref.perfil': ['Perfil', 'Profile', 'الملف الشخصي'],
  'pref.quien': ['¿Quién usa este dispositivo?', 'Who uses this device?', 'من يستخدم هذا الجهاز؟'],
  'pref.temp': ['Temperatura favorita', 'Favourite temperature', 'الحرارة المفضّلة'],
  'pref.tono': ['Tono de luz', 'Light tone', 'لون الإضاءة'],
  'pref.calida': ['Cálida', 'Warm', 'دافئ'],
  'pref.neutra': ['Neutra', 'Neutral', 'محايد'],
  'pref.fria': ['Fría', 'Cool', 'بارد'],
  'pref.brillo': ['Brillo de bienvenida', 'Welcome brightness', 'سطوع الترحيب'],
  'pref.idioma': ['Idioma', 'Language', 'اللغة'],
  'pref.invitado': ['Modo invitado', 'Guest mode', 'وضع الضيف'],
  'pref.invitadoSub': [
    'Oculta los ajustes y la creación de escenas',
    'Hides settings and scene creation',
    'يخفي الإعدادات وإنشاء المشاهد',
  ],
  'pref.rol': ['Rol', 'Role', 'الدور'],
  'rol.propietario': ['Propietario', 'Owner', 'المالك'],
  'rol.familia': ['Familia', 'Family', 'العائلة'],
  'rol.invitado': ['Invitado', 'Guest', 'ضيف'],
  'pref.aplicar': ['Aplicar mi ambiente ahora', 'Apply my ambience now', 'طبّق أجوائي الآن'],
  'pref.aplicada': ['Tu ambiente está listo.', 'Your ambience is ready.', 'أجواؤك جاهزة.'],
};
