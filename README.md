# Registro de Riesgos Santa Marta

Aplicación Android de participación ciudadana para reportar problemáticas, riesgos y daños urbanos en Santa Marta, con panel administrativo para que la entidad responsable (por ejemplo, la Alcaldía) reciba, visualice, clasifique, priorice y gestione los reportes.

## Qué incluye

| Área | Implementación |
|---|---|
| App Android | Flutter 3 (Dart), Material 3, Riverpod, go_router |
| Backend | Supabase: PostgreSQL + Auth + Storage + Realtime + Edge Functions |
| Base de datos | 15 tablas, triggers, funciones, vista pública, RLS en todas las tablas |
| Autenticación | Registro, inicio/cierre de sesión, recuperación con código, edición de perfil |
| Reportes | Formulario A–H, resumen de confirmación, código `RSM-AAAA-NNNNNN`, estado inicial "Recibido" |
| Fotografías | Cámara/galería, compresión, eliminación de EXIF, Storage con carpetas por usuario |
| Mapas | flutter_map + OpenStreetMap (Mapbox configurable), marcadores por nivel, filtros, ubicación GPS ajustable |
| Estados | 7 estados, historial automático (anterior, nuevo, fecha, responsable, observación) |
| Observaciones | Públicas (notifican al ciudadano) o internas |
| Priorización | Índice 0–100 en SQL con parámetros editables en tabla; 4 niveles |
| Duplicados | Distancia Haversine + similitud de texto por trigramas; decisión manual del administrador |
| IA (opcional) | Clasificador local por palabras clave (sin conexión) + Edge Function con LLM vía variable de entorno |
| Sin internet | Cola SQLite; envío automático al recuperar conexión; idempotente por `client_uuid` |
| Notificaciones | Tabla `notifications` + Realtime + notificaciones del sistema Android; FCM preparado |
| Panel admin | Dashboard con KPI y gráficos, listado con búsqueda/filtros/orden por prioridad, gestión de reportes, usuarios, categorías, mapa completo, zonas críticas |
| Privacidad | Vista pública sin datos personales; política y términos preliminares |
| Datos de prueba | 9 reportes ficticios marcados `[PRUEBA]` / `is_test_data` (incluye un duplicado para demostración) |
| Pruebas | Pruebas SQL funcionales y de seguridad (RLS) + pruebas unitarias Dart |

## Estructura

```
registro-riesgos-santa-marta/
├── README.md
├── docs/
│   ├── ARQUITECTURA.md          # tecnologías, por qué, diagrama, escalabilidad
│   ├── INSTALACION.md           # Supabase, variables de entorno, ejecución
│   ├── GENERAR_APK.md           # comandos exactos para compilar la APK
│   ├── PRIORIZACION_Y_DUPLICADOS.md
│   └── SEGURIDAD_Y_PRIVACIDAD.md
├── supabase/
│   ├── migrations/              # esquema, funciones, RLS, catálogos, storage, datos de prueba
│   ├── functions/classify-report/  # Edge Function de IA (opcional)
│   └── tests/                   # pruebas de la base de datos en PostgreSQL local
└── app/                         # aplicación Flutter
    ├── pubspec.yaml
    ├── env.example.json         # plantilla de variables (copiar a env.json)
    ├── tool/setup_android.dart  # genera/configura android/ automáticamente
    ├── assets/legal/            # política de privacidad y términos (preliminares)
    ├── test/                    # pruebas unitarias
    └── lib/
        ├── main.dart / app.dart
        ├── core/                # config, tema, router, constantes, utilidades
        ├── data/                # modelos y cliente Supabase
        ├── shared/widgets/      # componentes reutilizables
        └── features/
            ├── auth/            # autenticación y sesión
            ├── home/            # pantalla de inicio
            ├── reports/         # crear, confirmar, mis reportes, detalle, clasificador
            ├── map/             # mapa de riesgos, filtros, GPS
            ├── offline/         # cola sin conexión y sincronización
            ├── notifications/   # Realtime + notificaciones locales
            ├── profile/         # perfil, edición, textos legales
            ├── admin/           # panel administrativo y dashboard
            └── shell/           # navegación principal
```

## Inicio rápido

1. Crea un proyecto en [Supabase](https://supabase.com) y ejecuta las migraciones de `supabase/migrations/` en orden (ver `docs/INSTALACION.md`).
2. Copia `app/env.example.json` a `app/env.json` y completa `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
3. En `app/`:
   ```bash
   flutter pub get
   dart run tool/setup_android.dart
   flutter run --dart-define-from-file=env.json
   ```
4. Genera la APK:
   ```bash
   flutter build apk --release --dart-define-from-file=env.json
   ```
   Resultado: `app/build/app/outputs/flutter-apk/app-release.apk`

5. Crea tu cuenta en la app, conviértela en administrador y carga los datos de prueba desde el SQL Editor de Supabase:
   ```sql
   update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'tu@correo.com');
   select public.seed_test_data((select id from auth.users where email = 'tu@correo.com'));
   ```

## Estado de verificación

- **Base de datos:** las 6 migraciones se aplicaron y probaron sobre PostgreSQL 16 con un entorno que simula Supabase (`supabase/tests/run_local_tests.sh`): generación de códigos, sectores, prioridad, detección del duplicado de la Avenida Libertador, historial de estados, notificaciones, dashboard y las restricciones RLS (un ciudadano no puede ver reportes ajenos, escalar su rol, cambiar estados ni ver el dashboard).
- **App Flutter:** el entorno donde se construyó no tenía Flutter SDK ni acceso a sus servidores de descarga, por lo que el código Dart no se pudo compilar aquí. Ejecuta `flutter analyze` y `flutter test` como primer paso; si tu versión de Flutter es más reciente y algún paquete cambió su API, el analizador lo señalará con precisión.
