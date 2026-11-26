"""Ajusta el proyecto Flutter de Auré antes de compilar.

Se puede ejecutar las veces que haga falta: solo cambia lo que aún no está hecho.
  - Android: permisos (internet, micrófono, notificaciones, huella), conexión http,
    nombre "Auré", huella (FlutterFragmentActivity) y notificaciones (desugaring).
  - Windows: el programa se llama Aure.exe y la ventana "Auré".
"""
import glob
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def ruta(*partes):
    return os.path.join(RAIZ, *partes)


def leer(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def escribir(p, texto):
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(texto)


def manifiesto():
    p = ruta("android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.exists(p):
        return
    s = leer(p)
    permisos = ["INTERNET", "RECORD_AUDIO", "POST_NOTIFICATIONS", "USE_BIOMETRIC"]
    nuevos = "".join(
        f'    <uses-permission android:name="android.permission.{x}"/>\n'
        for x in permisos
        if f"android.permission.{x}" not in s
    )
    if nuevos:
        s = re.sub(r"\n([ \t]*)<application", lambda m: "\n" + nuevos + m.group(1) + "<application", s, count=1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="Auré"', s, count=1)
    if "usesCleartextTraffic" not in s:
        s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
    intents = {
        "android.speech.RecognitionService": '        <intent><action android:name="android.speech.RecognitionService"/></intent>\n',
        "android.intent.action.TTS_SERVICE": '        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>\n',
        'android:scheme="https"': '        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n',
    }
    faltan = "".join(v for k, v in intents.items() if k not in s)
    if faltan:
        if "<queries>" in s:
            s = s.replace("<queries>", "<queries>\n" + faltan.rstrip("\n"), 1)
        else:
            s = s.replace("</manifest>", "    <queries>\n" + faltan + "    </queries>\n</manifest>", 1)
    # Widget de la pantalla de inicio (home_widget): receptor y apertura desde el widget.
    if "AureWidget" not in s:
        s = s.replace(
            "</application>",
            '    <receiver android:name=".AureWidget" android:exported="true">\n'
            '            <intent-filter>\n'
            '                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>\n'
            '            </intent-filter>\n'
            '            <meta-data android:name="android.appwidget.provider" android:resource="@xml/aure_widget_info"/>\n'
            '        </receiver>\n'
            '    </application>',
            1,
        )
    if "es.antonborri.home_widget.action.LAUNCH" not in s:
        s = s.replace(
            "</activity>",
            '    <intent-filter>\n'
            '                <action android:name="es.antonborri.home_widget.action.LAUNCH"/>\n'
            '            </intent-filter>\n'
            '        </activity>',
            1,
        )
    escribir(p, s)
    print("AndroidManifest.xml listo")


def actividad():
    for p in glob.glob(ruta("android", "app", "src", "main", "**", "MainActivity.*"), recursive=True):
        s = leer(p)
        if "FlutterFragmentActivity" in s:
            continue
        s = s.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
        s = re.sub(r"\bFlutterActivity\b", "FlutterFragmentActivity", s)
        escribir(p, s)
        print(os.path.basename(p), "listo")


def widget():
    """Copia el widget de Auré (Kotlin y recursos) junto a MainActivity."""
    import shutil
    actividades = glob.glob(ruta("android", "app", "src", "main", "**", "MainActivity.*"), recursive=True)
    if not actividades:
        return
    principal = actividades[0]
    paquete = re.search(r"^package\s+([\w.]+)", leer(principal), re.M)
    if not paquete:
        return
    codigo = leer(ruta("tool", "android_extra", "kotlin", "AureWidget.kt")).replace("PAQUETE", paquete.group(1))
    escribir(os.path.join(os.path.dirname(principal), "AureWidget.kt"), codigo)
    origen = ruta("tool", "android_extra", "res")
    res = ruta("android", "app", "src", "main", "res")
    for carpeta, _, archivos in os.walk(origen):
        destino = os.path.join(res, os.path.relpath(carpeta, origen))
        os.makedirs(destino, exist_ok=True)
        for a in archivos:
            shutil.copyfile(os.path.join(carpeta, a), os.path.join(destino, a))
    print("widget listo")


def gradle():
    kts = ruta("android", "app", "build.gradle.kts")
    groovy = ruta("android", "app", "build.gradle")
    if os.path.exists(kts):
        s = leer(kts)
        if "isCoreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
        if "desugar_jdk_libs" not in s:
            s = s.rstrip() + '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        s = s.replace("minSdk = flutter.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 23)")
        # Firma fija de Auré: si existe android/key.properties, las versiones se instalan encima.
        if os.path.exists(ruta("android", "key.properties")) and "aureFirma" not in s:
            if "import java.util.Properties" not in s:
                s = "import java.io.FileInputStream\nimport java.util.Properties\n\n" + s
            s = s.replace(
                "android {",
                "android {\n"
                "    val aureFirma = Properties().apply {\n"
                "        val f = rootProject.file(\"key.properties\")\n"
                "        if (f.exists()) FileInputStream(f).use { load(it) }\n"
                "    }\n"
                "    signingConfigs {\n"
                "        create(\"aure\") {\n"
                "            keyAlias = aureFirma.getProperty(\"keyAlias\")\n"
                "            keyPassword = aureFirma.getProperty(\"keyPassword\")\n"
                "            storeFile = file(aureFirma.getProperty(\"storeFile\"))\n"
                "            storePassword = aureFirma.getProperty(\"storePassword\")\n"
                "            storeType = \"PKCS12\"\n"
                "        }\n"
                "    }\n",
                1,
            )
            s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("aure")')
            print("firma fija activada")
        # Algunos plugins nuevos piden compilar contra Android 37 o superior.
        s = re.sub(r"compileSdk = flutter\.compileSdkVersion\b", "compileSdk = maxOf(flutter.compileSdkVersion, 37)", s)
        escribir(kts, s)
        print("build.gradle.kts listo")
    elif os.path.exists(groovy):
        s = leer(groovy)
        if "coreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
        if "desugar_jdk_libs" not in s:
            s = s.rstrip() + "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        s = s.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion Math.max(flutter.minSdkVersion, 23)")
        s = re.sub(r"compileSdk(Version)? flutter\.compileSdkVersion\b", "compileSdk Math.max(flutter.compileSdkVersion, 37)", s)
        escribir(groovy, s)
        print("build.gradle listo")


def windows():
    cm = ruta("windows", "CMakeLists.txt")
    if os.path.exists(cm):
        s = leer(cm)
        s = re.sub(r'set\(BINARY_NAME "[^"]*"\)', 'set(BINARY_NAME "Aure")', s, count=1)
        escribir(cm, s)
        print("windows/CMakeLists.txt listo")
    mc = ruta("windows", "runner", "main.cpp")
    if os.path.exists(mc):
        s = leer(mc)
        s = s.replace('L"flutter_application_1"', 'L"Aur\\u00E9"')
        escribir(mc, s)
        print("windows/runner/main.cpp listo")


def iconos():
    """Pone el logo de Auré como icono de la app (Android y Windows) y quita el destello blanco al abrir."""
    import shutil
    origen = ruta("tool", "iconos", "android")
    res = ruta("android", "app", "src", "main", "res")
    if os.path.isdir(origen) and os.path.isdir(res):
        for carpeta, _, archivos in os.walk(origen):
            destino = os.path.join(res, os.path.relpath(carpeta, origen))
            os.makedirs(destino, exist_ok=True)
            for a in archivos:
                shutil.copyfile(os.path.join(carpeta, a), os.path.join(destino, a))
        man = ruta("android", "app", "src", "main", "AndroidManifest.xml")
        s = leer(man)
        if "android:roundIcon" not in s:
            s = s.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"', 1)
            escribir(man, s)
        for fondo in glob.glob(os.path.join(res, "drawable*", "launch_background.xml")):
            t = leer(fondo)
            t = t.replace("?android:colorBackground", "@color/aure_fondo_icono").replace("@android:color/white", "@color/aure_fondo_icono")
            escribir(fondo, t)
        print("iconos de Android listos")
    ico = ruta("tool", "iconos", "windows", "app_icon.ico")
    destino = ruta("windows", "runner", "resources", "app_icon.ico")
    if os.path.exists(ico) and os.path.isdir(os.path.dirname(destino)):
        shutil.copyfile(ico, destino)
        print("icono de Windows listo")


if __name__ == "__main__":
    manifiesto()
    actividad()
    gradle()
    windows()
    iconos()
    widget()
