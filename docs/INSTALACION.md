# Instalación y ejecución

## 1. Requisitos

- Flutter SDK (canal stable, 3.24 o superior) — `flutter doctor` sin errores para Android.
- Android Studio (Android SDK, platform-tools) y JDK 17.
- Una cuenta en Supabase (plan gratuito suficiente para pruebas).
- Opcional: Supabase CLI (para migraciones y Edge Functions desde la terminal).

## 2. Configurar Supabase (backend)

### 2.1 Crear el proyecto
1. En https://supabase.com crea un proyecto (región recomendada: la más cercana, p. ej. `us-east-1` o `sa-east-1`).
2. En **Project Settings → API** copia:
   - `Project URL` → `SUPABASE_URL`
   - `anon public key` → `SUPABASE_ANON_KEY`
   - **Nunca** pongas la `service_role key` en la app.

### 2.2 Ejecutar las migraciones (en orden)

**Opción A – SQL Editor (sin instalar nada):** abre **SQL Editor**, pega y ejecuta cada archivo de `supabase/migrations/` en este orden:

1. `20261005000001_schema.sql` – tablas e índices
2. `20261005000002_functions.sql` – triggers, prioridad, duplicados, estadísticas
3. `20261005000003_rls.sql` – seguridad por filas
4. `20261005000004_catalogs.sql` – roles, estados, categorías, sectores, parámetros
5. `20261005000005_storage.sql` – bucket de fotos y sus políticas
6. `20261005000006_test_data.sql` – funciones opcionales para pruebas técnicas (no cargan nada por sí solas)

**Opción B – Supabase CLI:**
```bash
cd supabase/..           # raíz del proyecto
supabase login
supabase link --project-ref TU_REF
supabase db push
```

### 2.3 Autenticación
En **Authentication → Providers → Email**: habilitado.

- **Confirm email:** recomendado en producción. Si lo desactivas, el ciudadano entra apenas se registra.
- **Recuperación de contraseña con código (obligatorio):** en **Authentication → Email Templates → Reset Password** reemplaza el contenido por algo como:
  ```html
  <h2>Recuperar contraseña – Registro de Riesgos Santa Marta</h2>
  <p>Tu código de verificación es: <strong>{{ .Token }}</strong></p>
  <p>Si no solicitaste este cambio, ignora este correo.</p>
  ```
  La app pide el código y la nueva contraseña (no requiere enlaces profundos).
- Para producción configura un SMTP propio (**Project Settings → Auth → SMTP**): el servidor de correo por defecto de Supabase tiene límites bajos.

### 2.4 Realtime
La migración 3 añade la tabla `notifications` a la publicación `supabase_realtime`. Verifica en **Database → Publications** que esté incluida.

### 2.5 Recalcular prioridades periódicamente (recomendado)
La antigüedad aumenta con el tiempo. Habilita la extensión `pg_cron` (**Database → Extensions**) y ejecuta:
```sql
select cron.schedule('recalcular-prioridades', '0 * * * *', $$select public.recalculate_all_priorities()$$);
```
(El panel también tiene un botón "Recalcular prioridades".)

### 2.6 Primer administrador
1. Ejecuta la app y crea tu cuenta.
2. En el SQL Editor:
   ```sql
   -- convertir la cuenta en administrador
   update public.profiles set role = 'admin'
   where id = (select id from auth.users where email = 'tu@correo.com');

   ```
3. Cierra sesión y vuelve a entrar: en **Perfil** aparece "Abrir panel administrativo".


### 2.7 IA opcional: Edge Function `classify-report`
```bash
supabase functions deploy classify-report
supabase secrets set AI_API_KEY=tu_llave_de_anthropic
# opcional: supabase secrets set AI_MODEL=claude-haiku-4-5-20251001
```
Y en `env.json` de la app: `"AI_CLASSIFIER_ENABLED": "true"`. Sin esto, la app usa solo el clasificador local (funciona sin conexión).

## 3. Variables de entorno de la app

Copia `app/env.example.json` a `app/env.json` (está en `.gitignore`):

| Variable | Obligatoria | Descripción |
|---|---|---|
| `SUPABASE_URL` | Sí | URL del proyecto Supabase |
| `SUPABASE_ANON_KEY` | Sí | Llave pública *anon* (protegida por RLS) |
| `MAP_TILE_URL` | No | Plantilla de teselas. Por defecto OpenStreetMap |
| `MAP_ACCESS_TOKEN` | No | Token si el proveedor lo exige (Mapbox) |
| `MAP_ATTRIBUTION` | No | Texto de atribución del mapa |
| `AI_CLASSIFIER_ENABLED` | No | `true` para usar la Edge Function de IA |

Ejemplo con **Mapbox**:
```json
"MAP_TILE_URL": "https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}",
"MAP_ACCESS_TOKEN": "pk.xxxxx",
"MAP_ATTRIBUTION": "© Mapbox © OpenStreetMap"
```
> Nota: los servidores públicos de OpenStreetMap tienen una política de uso justo. Para un despliegue masivo use Mapbox, MapTiler o un servidor de teselas propio.

Las variables de Supabase del lado servidor (`AI_API_KEY`, `AI_MODEL`) se configuran con `supabase secrets set` y nunca viajan en el APK.

## 4. Ejecutar la app en desarrollo

```bash
cd app
flutter pub get
dart run tool/setup_android.dart       # solo la primera vez: genera y configura android/
flutter analyze
flutter test
flutter run --dart-define-from-file=env.json
```

Con un emulador Android, define la ubicación en **Extended controls → Location** (por ejemplo 11.2408, -74.1990) para simular GPS en Santa Marta.

### Panel administrativo en navegador (opcional)
```bash
flutter run -d chrome --dart-define-from-file=env.json      # desarrollo
flutter build web --release --dart-define-from-file=env.json  # publicación
```

## 5. Pruebas de la base de datos (opcional)

Con PostgreSQL 15+ local:
```bash
PGHOST=localhost PGUSER=postgres ./supabase/tests/run_local_tests.sh
```
Crea una base temporal, aplica todas las migraciones sobre una simulación mínima de Supabase y ejecuta pruebas funcionales y de seguridad.

## 6. Notificaciones push con la app cerrada (siguiente fase)

Hoy las notificaciones llegan por Realtime mientras la app está abierta o en segundo plano reciente. Para push con la app cerrada:
1. Crear proyecto Firebase y agregar `google-services.json` en `app/android/app/`.
2. Agregar `firebase_messaging` y guardar el token en `public.device_tokens`.
3. Crear una Edge Function `push-notify` que envíe mediante FCM HTTP v1 y conectarla con un **Database Webhook** sobre `INSERT` en `public.notifications`.

## 7. Cuenta administradora de la versión web (modo local)

- El correo del administrador y la huella cifrada de su clave están en `web/public/config.js` (`ADMIN_ACCOUNT`). La clave en sí no está guardada en ningún archivo.
- Cambiar la clave: `node web/tools/admin-hash.mjs "NuevaClaveSegura"`, pegar `salt`, `iterations` y `hash` en `ADMIN_ACCOUNT` y subir el cambio (GitHub vuelve a publicar la web y la APK).
- La clave del administrador no se puede recuperar ni cambiar desde la aplicación, y nadie puede registrarse con ese correo.
- Sin Supabase, cada dispositivo guarda sus propios datos. Desde el Dashboard el administrador puede **Descargar copia de seguridad** y **Restaurar copia**.
