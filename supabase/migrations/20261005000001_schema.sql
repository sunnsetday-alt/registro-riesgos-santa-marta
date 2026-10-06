-- =====================================================================
-- Registro de Riesgos Santa Marta
-- Migración 1: Esquema base
-- =====================================================================
-- Diseño:
--  * auth.users (Supabase Auth) guarda credenciales. public.profiles guarda
--    datos personales protegidos por RLS (nunca se exponen públicamente).
--  * Los reportes referencian catálogos (categorías, estados, sectores) para
--    que puedan administrarse sin tocar código.
--  * "entities" deja preparada la asignación de categorías a diferentes
--    entidades responsables (Secretarías, empresas de servicios, etc.).
--  * Las coordenadas se guardan como latitud/longitud con índices; las
--    distancias se calculan con Haversine (ver migración 2). Si en el futuro
--    se requiere análisis espacial avanzado, se puede añadir PostGIS sin
--    cambiar el contrato de la API (columnas latitude/longitude).
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- ---------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------
create table public.roles (
  code        text primary key,
  name        text not null,
  description text,
  is_staff    boolean not null default false
);
comment on table public.roles is 'Roles del sistema. is_staff=true otorga acceso al panel administrativo.';

-- ---------------------------------------------------------------------
-- Entidades responsables (Alcaldía, Secretarías, empresas de servicios...)
-- ---------------------------------------------------------------------
create table public.entities (
  id            uuid primary key default gen_random_uuid(),
  name          text not null unique check (char_length(name) between 3 and 150),
  kind          text not null default 'secretaria'
                check (kind in ('alcaldia','secretaria','servicios_publicos','gestion_riesgo','otra')),
  contact_email text,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Perfiles (datos personales — PRIVADOS)
-- ---------------------------------------------------------------------
create table public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  full_name         text not null default '' check (char_length(full_name) <= 120),
  phone             text check (phone is null or phone ~ '^[0-9+ ()-]{7,20}$'),
  role              text not null default 'citizen' references public.roles(code),
  entity_id         uuid references public.entities(id) on delete set null,
  is_active         boolean not null default true,
  accepted_terms_at timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
comment on table public.profiles is 'Datos personales del usuario. Nunca se exponen en vistas públicas.';

-- ---------------------------------------------------------------------
-- Sectores de la ciudad (asignación automática por cercanía)
-- ---------------------------------------------------------------------
create table public.sectors (
  id         serial primary key,
  name       text not null unique,
  center_lat double precision not null,
  center_lng double precision not null,
  radius_m   integer not null default 1500 check (radius_m > 0),
  is_active  boolean not null default true
);
comment on table public.sectors is 'Sectores/barrios aproximados. Un reporte se asigna al sector activo más cercano dentro de su radio.';

-- ---------------------------------------------------------------------
-- Categorías
-- ---------------------------------------------------------------------
create table public.categories (
  id                    serial primary key,
  code                  text not null unique check (code ~ '^[a-z_]{2,40}$'),
  name                  text not null check (char_length(name) between 2 and 60),
  description           text,
  icon                  text not null default 'report',
  color                 text not null default '#0077B6' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  priority_weight       numeric(3,2) not null default 1.00 check (priority_weight between 0.5 and 1.5),
  keywords              text[] not null default '{}',
  responsible_entity_id uuid references public.entities(id) on delete set null,
  is_active             boolean not null default true,
  sort_order            integer not null default 0,
  created_at            timestamptz not null default now()
);
comment on column public.categories.priority_weight is 'Peso de la categoría en el índice de prioridad (0.5 = menos urgente, 1.5 = más urgente).';
comment on column public.categories.keywords is 'Palabras clave usadas por el clasificador automático de categorías.';

-- ---------------------------------------------------------------------
-- Estados
-- ---------------------------------------------------------------------
create table public.report_statuses (
  code           text primary key,
  name           text not null,
  description    text,
  color          text not null default '#64748B',
  sort_order     integer not null,
  is_open        boolean not null default true,  -- cuenta como problema pendiente
  notify_citizen boolean not null default false  -- genera notificación al ciudadano
);

-- ---------------------------------------------------------------------
-- Reportes
-- ---------------------------------------------------------------------
create table public.reports (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique,                       -- RSM-2026-000001
  user_id            uuid not null references public.profiles(id) on delete restrict,
  title              text not null check (char_length(btrim(title)) between 5 and 120),
  description        text not null check (char_length(btrim(description)) between 10 and 2000),
  category_id        integer not null references public.categories(id),
  severity           smallint not null check (severity between 1 and 5),
  priority_score     numeric(5,2) not null default 0,
  priority_level     text not null default 'baja' check (priority_level in ('baja','media','alta','critica')),
  status             text not null default 'recibido' references public.report_statuses(code),
  latitude           double precision not null check (latitude between 10.80 and 11.45),
  longitude          double precision not null check (longitude between -74.40 and -73.50),
  address            text check (address is null or char_length(address) <= 250),
  sector_id          integer references public.sectors(id) on delete set null,
  photo_url          text,
  assigned_entity_id uuid references public.entities(id) on delete set null,
  possible_duplicate boolean not null default false,
  duplicate_of       uuid references public.reports(id) on delete set null,
  is_test_data       boolean not null default false,
  client_uuid        uuid unique,           -- idempotencia para sincronización offline
  reported_at        timestamptz,           -- hora en que el ciudadano llenó el reporte (puede ser offline)
  search_text        text,                  -- texto normalizado para búsquedas/duplicados
  admin_notes        text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  resolved_at        timestamptz
);
comment on table public.reports is 'Reportes ciudadanos. Los límites de lat/lng cubren el Distrito de Santa Marta.';

create index reports_status_idx      on public.reports (status);
create index reports_category_idx    on public.reports (category_id);
create index reports_user_idx        on public.reports (user_id);
create index reports_created_idx     on public.reports (created_at desc);
create index reports_priority_idx    on public.reports (priority_score desc);
create index reports_sector_idx      on public.reports (sector_id);
create index reports_latlng_idx      on public.reports (latitude, longitude);
create index reports_search_trgm_idx on public.reports using gin (search_text extensions.gin_trgm_ops);

-- Contador anual para el código RSM-AAAA-NNNNNN
create table public.report_counters (
  year       integer primary key,
  last_value integer not null
);

-- ---------------------------------------------------------------------
-- Fotografías (un reporte puede tener varias; photo_url guarda la principal)
-- ---------------------------------------------------------------------
create table public.report_photos (
  id           uuid primary key default gen_random_uuid(),
  report_id    uuid not null references public.reports(id) on delete cascade,
  storage_path text not null unique,
  public_url   text not null,
  uploaded_by  uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index report_photos_report_idx on public.report_photos (report_id);

-- ---------------------------------------------------------------------
-- Historial de estados
-- ---------------------------------------------------------------------
create table public.status_history (
  id          bigserial primary key,
  report_id   uuid not null references public.reports(id) on delete cascade,
  from_status text references public.report_statuses(code),
  to_status   text not null references public.report_statuses(code),
  changed_by  uuid references public.profiles(id) on delete set null,
  note        text,
  created_at  timestamptz not null default now()
);
create index status_history_report_idx on public.status_history (report_id, created_at);

-- ---------------------------------------------------------------------
-- Observaciones
-- ---------------------------------------------------------------------
create table public.observations (
  id         uuid primary key default gen_random_uuid(),
  report_id  uuid not null references public.reports(id) on delete cascade,
  author_id  uuid references public.profiles(id) on delete set null,
  body       text not null check (char_length(btrim(body)) between 2 and 2000),
  is_public  boolean not null default true,  -- visible para el ciudadano que reportó
  created_at timestamptz not null default now()
);
create index observations_report_idx on public.observations (report_id, created_at);

-- ---------------------------------------------------------------------
-- Posibles duplicados (NUNCA se elimina un reporte automáticamente)
-- ---------------------------------------------------------------------
create table public.duplicate_candidates (
  id              bigserial primary key,
  report_id       uuid not null references public.reports(id) on delete cascade, -- reporte nuevo
  candidate_id    uuid not null references public.reports(id) on delete cascade, -- reporte anterior parecido
  distance_m      numeric(8,1) not null,
  text_similarity numeric(4,3) not null,
  score           numeric(4,3) not null,
  decision        text not null default 'pendiente' check (decision in ('pendiente','confirmado','descartado')),
  decided_by      uuid references public.profiles(id) on delete set null,
  decided_at      timestamptz,
  created_at      timestamptz not null default now(),
  unique (report_id, candidate_id),
  check (report_id <> candidate_id)
);
create index duplicate_candidates_report_idx on public.duplicate_candidates (report_id);
create index duplicate_candidates_candidate_idx on public.duplicate_candidates (candidate_id);

-- ---------------------------------------------------------------------
-- Notificaciones (in-app + base para push)
-- ---------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  report_id  uuid references public.reports(id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text not null,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

-- Tokens de dispositivo para notificaciones push (FCM) — preparado
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  token      text not null unique,
  platform   text not null default 'android' check (platform in ('android','ios','web')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Parámetros del índice de prioridad (modificables sin desplegar código)
-- ---------------------------------------------------------------------
create table public.priority_settings (
  key         text primary key,
  value       numeric not null,
  description text not null
);
