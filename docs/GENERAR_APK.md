# Generar la APK

## Opción 1 — Sin instalar nada: GitHub Actions (recomendada)

El proyecto incluye `.github/workflows/build-apk.yml`, que compila la APK en los servidores de GitHub.

1. Crea una cuenta en https://github.com (si no tienes) y un repositorio nuevo, por ejemplo `registro-riesgos-santa-marta` (puede ser privado).
2. Descomprime el .zip en tu computador y sube **todo el contenido de la carpeta** al repositorio: en la página del repositorio, *Add file → Upload files*, arrastra las carpetas `app`, `supabase`, `docs`, `.github` y el `README.md`, y pulsa *Commit changes*.
   - Importante: la carpeta `.github` está oculta en algunos sistemas. En Windows actívala en *Vista → Elementos ocultos*; en macOS pulsa `Cmd + Shift + .`.
3. En el repositorio: *Settings → Secrets and variables → Actions → New repository secret*. Crea:
   - `SUPABASE_URL` = la URL de tu proyecto Supabase
   - `SUPABASE_ANON_KEY` = la llave pública *anon*
4. Ve a la pestaña *Actions → Generar APK → Run workflow*. Tarda unos 8–12 minutos.
5. Al terminar (círculo verde), abre la ejecución y en *Artifacts* descarga `registro-riesgos-santa-marta-apk` (un .zip que contiene `app-release.apk`).
6. Pasa la APK al teléfono, ábrela y acepta *Instalar aplicaciones de origen desconocido*.

Si la ejecución falla (círculo rojo), abre el paso que falló, copia el error y compártelo para corregirlo.

## Opción 2 — En tu computador con Flutter

El entorno donde se desarrolló el proyecto no tenía Flutter ni Android SDK, por lo que la APK debe compilarse en tu equipo. Son 5 comandos.

## Pasos

```bash
cd registro-riesgos-santa-marta/app

# 1. Dependencias
flutter pub get

# 2. Generar y configurar la carpeta android/ (permisos, minSdk 23, desugaring, firma)
dart run tool/setup_android.dart

# 3. Verificar el código
flutter analyze
flutter test

# 4. Compilar la APK de producción
flutter build apk --release --dart-define-from-file=env.json
```

**Archivo resultante:** `app/build/app/outputs/flutter-apk/app-release.apk`

Instalar en un teléfono conectado por USB (con depuración USB activa):
```bash
flutter install --release
# o
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### APK más livianas (una por arquitectura)
```bash
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```
Genera `app-arm64-v8a-release.apk` (la mayoría de teléfonos actuales), `app-armeabi-v7a-release.apk` y `app-x86_64-release.apk`.

### Para Google Play (App Bundle)
```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

## Firma de la versión de producción

Sin firma propia, la APK release se firma con la llave de depuración (sirve para pruebas internas, no para Play Store).

1. Crear la llave (una sola vez; guárdala en un lugar seguro):
   ```bash
   keytool -genkey -v -keystore ~/rsm-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rsm
   ```
2. Crear `app/android/key.properties` (no se sube al repositorio):
   ```properties
   storePassword=TU_CLAVE
   keyPassword=TU_CLAVE
   keyAlias=rsm
   storeFile=/ruta/absoluta/rsm-release.jks
   ```
3. Volver a compilar. `tool/setup_android.dart` ya dejó Gradle preparado para leer este archivo.

## Configuración manual (si el script no pudo aplicar algún cambio)

En `android/app/build.gradle.kts`:
```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // ...
    }
    defaultConfig {
        minSdk = 23
        // ...
    }
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```
En `android/app/src/main/AndroidManifest.xml`, antes de `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| La app muestra "Falta la configuración del servidor" | Compilaste sin `--dart-define-from-file=env.json` |
| `requires core library desugaring` | Aplicar la sección de configuración manual |
| Conflicto de versiones al hacer `pub get` con una versión de Flutter más nueva | `flutter pub upgrade` y luego `flutter analyze` para ver si algún paquete cambió su API |
| El mapa sale gris | Revisa conexión y `MAP_TILE_URL`; algunos proveedores exigen token |
| No llega el código de recuperación | Configurar la plantilla "Reset Password" con `{{ .Token }}` y un SMTP propio |
| "No tienes permisos" en el panel | El rol del usuario no es de personal; actualizar `profiles.role` |
