# Arquitectura

## Visión general

```
┌──────────────────────────── App Android (Flutter) ────────────────────────────┐
│  UI (features/*/presentation)  ←→  Estado (Riverpod)  ←→  Repositorios (data) │
│        │                                   │                     │            │
│   go_router (roles)            Cola offline (SQLite)      supabase_flutter    │
└────────────────────────────────────────────────────────────────┬──────────────┘
                                                                 │ HTTPS (JWT)
┌─────────────────────────────────── Supabase ───────────────────┴──────────────┐
│  Auth (JWT)  │  PostgREST (API REST autogenerada)  │  Storage  │  Realtime    │
│              ▼                                                                │
│  PostgreSQL: tablas + RLS + triggers + funciones (prioridad, duplicados,      │
│              historial, notificaciones, estadísticas) + vista pública         │
│  Edge Functions (Deno): classify-report (IA opcional)                         │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Tecnologías y por qué

| Tecnología | Motivo de la elección |
|---|---|
| **Flutter** | Un solo código para Android (APK), con posibilidad de iOS y web (el panel admin puede publicarse como web con `flutter build web`). Rendimiento nativo, Material 3 y ecosistema maduro de mapas, cámara y GPS. Se prefirió sobre React Native por su motor de renderizado propio (UI consistente en gamas bajas) y compilación AOT. |
| **Supabase (PostgreSQL)** | Los reportes son datos relacionales (categorías, estados, historial, usuarios, entidades) que se consultan con filtros, agregaciones y cálculos geográficos. PostgreSQL resuelve esto mejor que una base documental (Firebase/Firestore). Supabase añade Auth, Storage, Realtime y API REST, es de código abierto y se puede auto-hospedar en infraestructura institucional, evitando dependencia de un proveedor. |
| **Row Level Security** | La autorización vive en la base de datos: aunque alguien use la API directamente, no puede leer datos ajenos ni escalar privilegios. |
| **Lógica en SQL (triggers/funciones)** | Código de reporte, prioridad, duplicados, historial y notificaciones se calculan en el servidor: son consistentes sin importar el cliente (app, web, futuras integraciones). |
| **flutter_map + OpenStreetMap** | Sin costo ni llave obligatoria para empezar; el proveedor de teselas se cambia por variable de entorno (Mapbox, servidor propio de la Alcaldía). Google Maps exige facturación y llave embebida en el APK. |
| **Riverpod** | Estado reactivo, testeable y sin dependencia del árbol de widgets. |
| **go_router** | Rutas declarativas con protección por sesión y por rol. |
| **SQLite (sqflite)** | Cola persistente de reportes sin conexión. |
| **Edge Functions** | Integraciones con APIs externas (IA) sin exponer llaves en el APK. |

## Capas del código (app/lib)

- `core/`: configuración (`Env`), tema, router, constantes (estados, niveles, íconos), utilidades (validación, formato, geo, errores).
- `data/`: modelos y proveedor del cliente Supabase.
- `shared/widgets/`: componentes reutilizables (tarjetas, chips de estado, insignias, línea de tiempo, foto remota).
- `features/<módulo>/`: cada módulo separa `data/` (repositorios/servicios), `application/` o `domain/` (estado y reglas) y `presentation/` (pantallas y widgets).

## Flujo de un reporte

1. El ciudadano llena el formulario (GPS automático, ajuste en mapa, foto comprimida sin EXIF).
2. Pantalla de confirmación → **ENVIAR REPORTE**.
3. `SyncService`: si hay red, sube la foto a `report-photos/<uid>/<client_uuid>.jpg` e inserta el reporte; si no, lo guarda en SQLite.
4. Triggers en PostgreSQL: fuerzan `user_id`, `status = recibido`, generan `RSM-AAAA-NNNNNN`, asignan sector y entidad responsable, registran historial, crean notificación, buscan duplicados y calculan prioridad (y recalculan la de reportes cercanos).
5. Realtime entrega la notificación → notificación del sistema Android.
6. El administrador cambia estados (`change_report_status`) → historial + notificación al ciudadano.

## Escalabilidad institucional

- **Multi-entidad:** tabla `entities`; cada categoría tiene `responsible_entity_id` y cada reporte `assigned_entity_id` (asignado automáticamente). Los roles `official` y `entity_admin` ya existen; para que cada entidad vea solo lo suyo basta con ajustar la política RLS de `reports` (`assigned_entity_id = (select entity_id from profiles where id = auth.uid())`).
- **API pública / transparencia:** la vista `public_reports` ya es consultable por REST sin datos personales (`GET /rest/v1/public_reports`).
- **Integración con sistemas institucionales:** Database Webhooks de Supabase o Edge Functions sobre `status_history`.
- **Mapas de calor y predicción:** `get_dashboard_stats` ya agrupa zonas críticas; para análisis espacial avanzado se puede habilitar PostGIS y añadir una columna `geography` sin romper la API.
- **Notificaciones push con app cerrada:** tabla `device_tokens` lista; falta registrar FCM (ver INSTALACION.md, sección Notificaciones push).
- **Análisis de fotografías:** la Edge Function `classify-report` es el punto de extensión (enviar `photo_url` a un modelo con visión).
- **Aplicación para funcionarios:** el mismo proyecto Flutter con el shell `/admin`, o un *flavor* separado.
- **Volumen:** índices en estado, categoría, fecha, prioridad, ubicación y texto (GIN trigramas). Las búsquedas de cercanía usan pre-filtro por caja de coordenadas antes de Haversine.
