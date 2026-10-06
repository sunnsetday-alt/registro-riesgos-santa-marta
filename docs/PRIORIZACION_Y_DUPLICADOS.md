# Índice de prioridad y detección de duplicados

Ambos se calculan en PostgreSQL (`supabase/migrations/20261005000002_functions.sql`) y todos sus parámetros están en la tabla `public.priority_settings`, por lo que se ajustan con un `UPDATE` sin recompilar la app.

## 1. Índice de prioridad (0 – 100)

| Componente | Cálculo (valor entre 0 y 1) | Peso por defecto |
|---|---|---|
| **S** – Nivel de importancia | `(severity − 1) / 4` | `w_severity` = 0.40 |
| **D** – Reportes similares | `min(similares / similar_cap, 1)` — similares = posibles duplicados no descartados + duplicados confirmados | `w_similar` = 0.15 |
| **A** – Antigüedad | `min(días_abierto / age_cap_days, 1)` | `w_age` = 0.15 |
| **C** – Categoría | `(priority_weight − 0.5) / 1.0` — peso de 0.5 a 1.5 por categoría | `w_category` = 0.10 |
| **G** – Concentración geográfica | `min(abiertos_en_radio / geo_cap, 1)` — otros reportes abiertos a ≤ `geo_radius_m` en los últimos `geo_window_days` | `w_geo` = 0.20 |

```
score = 100 × (wS·S + wD·D + wA·A + wC·C + wG·G) / (wS + wD + wA + wC + wG)
si severity = 5 → score = max(score, critical_severity_floor)      (55 por defecto)
```

| Nivel | Condición por defecto |
|---|---|
| Prioridad crítica | score ≥ `threshold_critica` (75) |
| Alta prioridad | score ≥ `threshold_alta` (55) |
| Prioridad media | score ≥ `threshold_media` (35) |
| Baja prioridad | resto |

**Cuándo se recalcula:** al crear un reporte (y los reportes abiertos cercanos), al cambiar su estado, severidad, categoría o ubicación, al decidir sobre un duplicado, con el botón del dashboard y, si se programa, cada hora con `pg_cron`.

**Ejemplo:** un hueco de severidad 5 (S=1), categoría Vías (peso 1.2 → C=0.7), 12 días abierto (A=0.4), un reporte similar (D=0.33) y otro cercano (G=0.2):
`100 × (0.40 + 0.05 + 0.06 + 0.07 + 0.04) / 1.0 = 62` → **Alta prioridad**.

### Modificar la fórmula
```sql
-- Dar más peso a la concentración geográfica
update public.priority_settings set value = 0.30 where key = 'w_geo';
-- Cambiar el umbral de prioridad crítica
update public.priority_settings set value = 70 where key = 'threshold_critica';
-- Aplicar a todos los reportes abiertos
select public.recalculate_all_priorities();
```
El peso de cada categoría se cambia desde el panel (**Categorías → Peso en el índice de prioridad**).

## 2. Posibles duplicados

Al crear un reporte, `detect_duplicates()` compara con reportes anteriores:

1. Creados en los últimos `dup_window_days` (60) días y no rechazados.
2. A una distancia ≤ `dup_radius_m` (150 m) — Haversine, con pre-filtro por caja de coordenadas (usa índice).
3. Y además **una** de estas condiciones:
   - similitud de texto ≥ `dup_text_threshold` (0.35), medida con trigramas (`pg_trgm`) sobre título y sobre título+descripción, sin tildes ni mayúsculas;
   - o misma categoría a ≤ `dup_same_category_radius_m` (50 m).

Puntaje mostrado al administrador: `0.5 × (1 − distancia/radio) + 0.5 × similitud`.

Ejemplo verificado en las pruebas:
- A: "Hay un hueco enorme en la Avenida Libertador…"
- B: "Hay un hueco peligroso en la Avenida Libertador…"
- Distancia 33.8 m · similitud 0.76 · puntaje 0.77 → B queda marcado **"Posible duplicado"**.

**Ningún reporte se elimina.** El administrador decide en el detalle del reporte:
- **Es duplicado:** se guarda `duplicate_of`, el reporte deja de mostrarse en el mapa público y el original sube de prioridad.
- **No es duplicado:** se descarta la coincidencia y se quita la marca.

## 3. Inteligencia artificial (uso concreto, no decorativo)

| Función | Cómo | Requiere conexión externa |
|---|---|---|
| Sugerencia de categoría | Clasificador por palabras clave (editables por categoría), explicable: muestra qué palabras detectó | No |
| Sugerencia de nivel de riesgo | Términos de peligro (cables, colapso, heridos…) proponen nivel 4–5; el ciudadano decide | No |
| Detección de duplicados | Trigramas + distancia en PostgreSQL | No |
| Clasificación con LLM | Edge Function `classify-report` (categoría + severidad + motivo) | Sí, `AI_API_KEY` |

Las sugerencias nunca se aplican solas: el ciudadano (o el administrador) las acepta.
