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
    }
    faltan = "".join(v for k, v in intents.items() if k not in s)
    if faltan:
        if "<queries>" in s:
            s = s.replace("<queries>", "<queries>\n" + faltan.rstrip("\n"), 1)
        else:
            s = s.replace("</manifest>", "    <queries>\n" + faltan + "    </queries>\n</manifest>", 1)
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
        escribir(kts, s)
        print("build.gradle.kts listo")
    elif os.path.exists(groovy):
        s = leer(groovy)
        if "coreLibraryDesugaringEnabled" not in s:
            s = s.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
        if "desugar_jdk_libs" not in s:
            s = s.rstrip() + "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        s = s.replace("minSdkVersion flutter.minSdkVersion", "minSdkVersion Math.max(flutter.minSdkVersion, 23)")
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


if __name__ == "__main__":
    manifiesto()
    actividad()
    gradle()
    windows()
