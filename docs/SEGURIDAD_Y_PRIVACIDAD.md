# Seguridad y privacidad

## Controles implementados

| Requisito | Implementación |
|---|---|
| Autenticación segura | Supabase Auth (contraseñas con hash bcrypt, JWT de corta duración con renovación). Contraseña mínima de 8 caracteres con letras y números. |
| Autorización por roles | `profiles.role` (`citizen`, `official`, `entity_admin`, `admin`) + funciones `is_staff()` / `is_admin()` usadas por RLS y RPC. El router de la app oculta el panel, pero la protección real está en el servidor. |
| Anti-escalamiento | Trigger `profiles_before_update`: un usuario no puede cambiar su rol, entidad ni estado de cuenta. Probado. |
| Protección de endpoints | RLS activado en las 15 tablas. Las RPC sensibles validan rol y tienen `EXECUTE` revocado para `anon`. Las funciones internas (prioridad, duplicados, triggers) no son invocables desde la API. |
| Valores controlados por el servidor | Al insertar un reporte se fuerzan `user_id = auth.uid()`, estado `recibido`, prioridad, código y marcas de duplicado: el cliente no puede falsificarlos. |
| Validación de datos | Restricciones `CHECK` (longitudes, rango 1–5, coordenadas dentro del Distrito, formato de teléfono y color) + validación equivalente en los formularios. |
| Límite anti-abuso | Máximo de reportes por ciudadano en 24 h (`max_reports_per_day`). |
| Almacenamiento de fotos | Solo usuarios autenticados, solo en su carpeta `<uid>/`, máx. 5 MB, solo JPEG/PNG/WebP. La app elimina metadatos EXIF (incluida la ubicación GPS de la cámara). |
| Datos personales | Nombre, correo y teléfono solo en `profiles`/`auth.users`, visibles únicamente para el titular y el personal. El mapa y las estadísticas públicas usan la vista `public_reports`, que no incluye `user_id`, notas internas ni datos de perfil. |
| Variables de entorno | `--dart-define-from-file=env.json` (excluido de git). La llave `anon` es pública por diseño; la `service_role` y la llave de IA solo existen en el servidor. |
| Cuentas inactivas | Un administrador puede desactivar cuentas; una cuenta inactiva no puede crear reportes ni ejerce permisos de personal. |

## Pruebas de seguridad incluidas (`supabase/tests/functional_test.sql`)

- Un ciudadano solo ve sus reportes y su propio perfil.
- Otro ciudadano no ve reportes ni historial ajenos.
- Un ciudadano no puede escalar su rol, cambiar estados ni ver el dashboard.
- Si el cliente intenta enviar `status = 'cerrado'` o el `user_id` de otra persona, el servidor lo ignora.
- El usuario anónimo solo accede a la vista pública y a estadísticas agregadas.

## Antes de un lanzamiento oficial

- Revisión legal de la política de privacidad y términos (textos preliminares en `app/assets/legal/`) frente a la Ley 1581 de 2012.
- SMTP institucional, dominio propio y confirmación de correo obligatoria.
- Revisión del contenido de fotos (moderación) y procedimiento para retirar imágenes con datos de terceros.
- Respaldos automáticos (Supabase Pro o servidor propio) y monitoreo.
- Prueba de penetración externa.
