// Prepara la carpeta android/ del proyecto (multiplataforma: Windows, macOS, Linux).
//
// Uso (desde la carpeta app/):
//   dart run tool/setup_android.dart
//
// Qué hace:
//  1. Si no existe android/, ejecuta `flutter create` para generarla con la
//     plantilla oficial de TU versión de Flutter (no se sobreescribe lib/).
//  2. Agrega permisos al AndroidManifest (Internet, ubicación, cámara,
//     notificaciones) y el nombre visible de la app.
//  3. Ajusta Gradle: minSdk 23, core library desugaring (requerido por
//     flutter_local_notifications) y firma de release con key.properties.
//
// Es idempotente: puede ejecutarse varias veces.
import 'dart:io';

const appLabel = 'Riesgos Santa Marta';
const org = 'co.santamarta';
const projectName = 'registro_riesgos_sm';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Ejecuta este script desde la carpeta app/ (donde está pubspec.yaml).');
    exit(1);
  }

  if (!Directory('android').existsSync()) {
    stdout.writeln('→ Generando carpeta android/ con flutter create…');
    final r = await Process.run(
      'flutter',
      ['create', '--org', org, '--project-name', projectName, '--platforms=android,web', '.'],
      runInShell: true,
    );
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    if (r.exitCode != 0) exit(r.exitCode);
    // flutter create agrega un test de ejemplo que no aplica a esta app.
    final sample = File('test/widget_test.dart');
    if (sample.existsSync() && sample.readAsStringSync().contains('Counter increments')) {
      sample.deleteSync();
    }
  }

  _patchManifest();
  _patchGradle();
  stdout.writeln('\n✔ Android listo. Siguiente paso:');
  stdout.writeln('  flutter build apk --release --dart-define-from-file=env.json');
}

void _patchManifest() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('No se encontró ${f.path}');
    return;
  }
  var s = f.readAsStringSync();
  const perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.CAMERA',
    'android.permission.POST_NOTIFICATIONS',
  ];
  final missing = perms.where((p) => !s.contains('"$p"')).toList();
  if (missing.isNotEmpty || !s.contains('android.hardware.camera')) {
    final lines = [
      for (final p in missing) '    <uses-permission android:name="$p"/>',
      if (!s.contains('android.hardware.camera'))
        '    <uses-feature android:name="android.hardware.camera" android:required="false"/>',
    ].join('\n');
    final idx = s.indexOf('>', s.indexOf('<manifest')) + 1;
    s = '${s.substring(0, idx)}\n$lines${s.substring(idx)}';
  }
  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="$appLabel"');
  f.writeAsStringSync(s);
  stdout.writeln('✔ AndroidManifest.xml actualizado');
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    _patchKts(kts);
  } else if (groovy.existsSync()) {
    _patchGroovy(groovy);
  } else {
    stderr.writeln('No se encontró android/app/build.gradle(.kts)');
  }
}

void _warn(String what) => stderr.writeln(
    '⚠ No se pudo aplicar automáticamente: $what. Ver docs/GENERAR_APK.md (configuración manual).');

void _patchKts(File f) {
  var s = f.readAsStringSync();
  if (!s.contains('import java.util.Properties')) {
    s = 'import java.util.Properties\nimport java.io.FileInputStream\n\n$s';
  }
  if (!s.contains('keystorePropertiesFile')) {
    s = s.replaceFirst(
      'android {',
      'val keystoreProperties = Properties()\n'
          'val keystorePropertiesFile = rootProject.file("key.properties")\n'
          'if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n\n'
          'android {',
    );
  }
  if (!s.contains('isCoreLibraryDesugaringEnabled')) {
    if (s.contains('compileOptions {')) {
      s = s.replaceFirst('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
    } else {
      _warn('coreLibraryDesugaring');
    }
  }
  s = s.replaceFirst(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), 'minSdk = 23');
  if (!s.contains('signingConfigs {')) {
    if (s.contains('buildTypes {')) {
      s = s.replaceFirst(
        'buildTypes {',
        'signingConfigs {\n'
            '        create("release") {\n'
            '            if (keystorePropertiesFile.exists()) {\n'
            '                keyAlias = keystoreProperties["keyAlias"] as String\n'
            '                keyPassword = keystoreProperties["keyPassword"] as String\n'
            '                storeFile = file(keystoreProperties["storeFile"] as String)\n'
            '                storePassword = keystoreProperties["storePassword"] as String\n'
            '            }\n'
            '        }\n'
            '    }\n\n'
            '    buildTypes {',
      );
      s = s.replaceFirst(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
            'else signingConfigs.getByName("debug")',
      );
    } else {
      _warn('firma de release');
    }
  }
  if (!s.contains('desugar_jdk_libs')) {
    s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n';
  }
  f.writeAsStringSync(s);
  stdout.writeln('✔ build.gradle.kts actualizado');
}

void _patchGroovy(File f) {
  var s = f.readAsStringSync();
  if (!s.contains('keystorePropertiesFile')) {
    s = s.replaceFirst(
      'android {',
      'def keystoreProperties = new Properties()\n'
          "def keystorePropertiesFile = rootProject.file('key.properties')\n"
          'if (keystorePropertiesFile.exists()) {\n'
          '    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n'
          '}\n\n'
          'android {',
    );
  }
  if (!s.contains('coreLibraryDesugaringEnabled')) {
    if (s.contains('compileOptions {')) {
      s = s.replaceFirst('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true');
    } else {
      _warn('coreLibraryDesugaring');
    }
  }
  s = s.replaceFirst(RegExp(r'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion'), 'minSdkVersion 23');
  if (!s.contains('signingConfigs {') && s.contains('buildTypes {')) {
    s = s.replaceFirst(
      'buildTypes {',
      'signingConfigs {\n'
          '        release {\n'
          '            if (keystorePropertiesFile.exists()) {\n'
          "                keyAlias keystoreProperties['keyAlias']\n"
          "                keyPassword keystoreProperties['keyPassword']\n"
          "                storeFile file(keystoreProperties['storeFile'])\n"
          "                storePassword keystoreProperties['storePassword']\n"
          '            }\n'
          '        }\n'
          '    }\n\n'
          '    buildTypes {',
    );
    s = s.replaceFirst(
      'signingConfig = signingConfigs.debug',
      'signingConfig = keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug',
    );
    s = s.replaceFirst(
      'signingConfig signingConfigs.debug',
      'signingConfig keystorePropertiesFile.exists() ? signingConfigs.release : signingConfigs.debug',
    );
  }
  if (!s.contains('desugar_jdk_libs')) {
    s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n";
  }
  f.writeAsStringSync(s);
  stdout.writeln('✔ build.gradle actualizado');
}
