-- =====================================================================
-- Registro de Riesgos Santa Marta
-- Migración 2: Funciones, triggers, priorización y duplicados
-- =====================================================================

-- ---------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------

-- Distancia en metros entre dos coordenadas (fórmula de Haversine).
create or replace function public.distance_m(lat1 double precision, lng1 double precision,
                                             lat2 double precision, lng2 double precision)
returns double precision
language sql immutable parallel safe
as $$
  select 2 * 6371000 * asin(least(1, sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  )));
$$;

-- Lee un parámetro de priority_settings (con valor por defecto).
create or replace function public.setting(p_key text, p_default numeric default 0)
returns numeric
language sql stable security definer
set search_path = public
as $$
  select coalesce((select value from public.priority_settings where key = p_key), p_default);
$$;

-- Texto normalizado (minúsculas, sin tildes) para comparar descripciones.
create or replace function public.normalize_text(p text)
returns text
language sql stable
set search_path = public, extensions
as $$
  select lower(extensions.unaccent(coalesce(p, '')));
$$;

-- ---------------------------------------------------------------------
-- Roles / autorización
-- ---------------------------------------------------------------------
create or replace function public.is_staff()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    join public.roles r on r.code = p.role
    where p.id = auth.uid() and p.is_active and r.is_staff
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active and p.role = 'admin'
  );
$$;

-- ---------------------------------------------------------------------
-- Perfiles
-- ---------------------------------------------------------------------

-- Crea el perfil cuando un usuario se registra en Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_phone text := nullif(btrim(new.raw_user_meta_data ->> 'phone'), '');
begin
  if v_phone is not null and v_phone !~ '^[0-9+ ()-]{7,20}$' then
    v_phone := null;
  end if;
  insert into public.profiles (id, full_name, phone, accepted_terms_at)
  values (
    new.id,
    left(coalesce(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 120),
    v_phone,
    case when coalesce((new.raw_user_meta_data ->> 'accepted_terms')::boolean, false) then now() end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Impide que un usuario se autoasigne rol, entidad o reactive su cuenta.
create or replace function public.profiles_before_update()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if new.role is distinct from old.role
       or new.entity_id is distinct from old.entity_id
       or new.is_active is distinct from old.is_active then
      raise exception 'No tienes permisos para modificar rol, entidad o estado de la cuenta'
        using errcode = '42501';
    end if;
  end if;
  new.id := old.id;
  new.created_at := old.created_at;
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_before_update
  before update on public.profiles
  for each row execute function public.profiles_before_update();

-- ---------------------------------------------------------------------
-- Sectores
-- ---------------------------------------------------------------------
create or replace function public.find_sector(p_lat double precision, p_lng double precision)
returns integer
language sql stable
set search_path = public
as $$
  select s.id
  from public.sectors s
  where s.is_active
    and public.distance_m(p_lat, p_lng, s.center_lat, s.center_lng) <= s.radius_m
  order by public.distance_m(p_lat, p_lng, s.center_lat, s.center_lng)
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- ÍNDICE DE PRIORIDAD
-- ---------------------------------------------------------------------
-- Fórmula (documentada en docs/PRIORIZACION.md):
--
--   S = severidad normalizada        = (severity - 1) / 4
--   D = reportes similares           = min(similares / similar_cap, 1)
--   A = antigüedad                   = min(días_abierto / age_cap_days, 1)
--   C = peso de la categoría         = (priority_weight - 0.5) / 1.0
--   G = concentración geográfica     = min(reportes_abiertos_cercanos / geo_cap, 1)
--
--   score = 100 * (wS*S + wD*D + wA*A + wC*C + wG*G) / (wS + wD + wA + wC + wG)
--
--   Si severity = 5 → score = max(score, critical_severity_floor)
--
--   Nivel: score >= threshold_critica → 'critica'
--          score >= threshold_alta    → 'alta'
--          score >= threshold_media   → 'media'
--          de lo contrario            → 'baja'
--
-- Todos los parámetros viven en public.priority_settings.
-- ---------------------------------------------------------------------
create or replace function public.compute_priority(p_id uuid)
returns numeric
language plpgsql stable security definer
set search_path = public
as $$
declare
  r          public.reports;
  w_sev      numeric := public.setting('w_severity', 0.40);
  w_sim      numeric := public.setting('w_similar', 0.15);
  w_age      numeric := public.setting('w_age', 0.15);
  w_cat      numeric := public.setting('w_category', 0.10);
  w_geo      numeric := public.setting('w_geo', 0.20);
  v_radius   numeric := public.setting('geo_radius_m', 300);
  v_window   numeric := public.setting('geo_window_days', 90);
  v_similar  numeric;
  v_nearby   numeric;
  v_age_days numeric;
  v_cat      numeric;
  v_sum_w    numeric;
  v_score    numeric;
  v_dlat     double precision;
  v_dlng     double precision;
begin
  select * into r from public.reports where id = p_id;
  if not found then
    return 0;
  end if;

  -- Reportes similares: candidatos no descartados + duplicados confirmados.
  select count(*) into v_similar
  from public.duplicate_candidates dc
  where (dc.report_id = p_id or dc.candidate_id = p_id) and dc.decision <> 'descartado';
  v_similar := v_similar + (select count(*) from public.reports d where d.duplicate_of = p_id);

  -- Concentración geográfica: otros reportes abiertos en el radio configurado.
  v_dlat := v_radius / 111320.0;
  v_dlng := v_radius / (111320.0 * cos(radians(r.latitude)));
  select count(*) into v_nearby
  from public.reports o
  join public.report_statuses st on st.code = o.status
  where o.id <> p_id
    and st.is_open
    and o.duplicate_of is null
    and o.latitude  between r.latitude  - v_dlat and r.latitude  + v_dlat
    and o.longitude between r.longitude - v_dlng and r.longitude + v_dlng
    and public.distance_m(r.latitude, r.longitude, o.latitude, o.longitude) <= v_radius
    and o.created_at > now() - make_interval(days => v_window::int);

  -- Antigüedad: días desde la creación (hasta la resolución si ya se atendió).
  v_age_days := greatest(0, extract(epoch from (coalesce(r.resolved_at, now()) - r.created_at)) / 86400.0);

  select priority_weight into v_cat from public.categories where id = r.category_id;

  v_sum_w := nullif(w_sev + w_sim + w_age + w_cat + w_geo, 0);
  v_score := 100 * (
      w_sev * ((r.severity - 1) / 4.0)
    + w_sim * least(v_similar / nullif(public.setting('similar_cap', 3), 0), 1)
    + w_age * least(v_age_days / nullif(public.setting('age_cap_days', 30), 0), 1)
    + w_cat * greatest(0, least(1, (coalesce(v_cat, 1.0) - 0.5) / 1.0))
    + w_geo * least(v_nearby / nullif(public.setting('geo_cap', 5), 0), 1)
  ) / coalesce(v_sum_w, 1);

  if r.severity = 5 then
    v_score := greatest(v_score, public.setting('critical_severity_floor', 55));
  end if;

  return round(least(100, greatest(0, coalesce(v_score, 0))), 2);
end;
$$;

create or replace function public.priority_level_for(p_score numeric)
returns text
language sql stable security definer
set search_path = public
as $$
  select case
    when p_score >= public.setting('threshold_critica', 75) then 'critica'
    when p_score >= public.setting('threshold_alta', 55)    then 'alta'
    when p_score >= public.setting('threshold_media', 35)   then 'media'
    else 'baja'
  end;
$$;

-- Recalcula y guarda la prioridad de un reporte.
create or replace function public.refresh_priority(p_id uuid)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_score numeric := public.compute_priority(p_id);
begin
  perform set_config('app.system_update', 'on', true);
  update public.reports
     set priority_score = v_score,
         priority_level = public.priority_level_for(v_score)
   where id = p_id
     and (priority_score is distinct from v_score
          or priority_level is distinct from public.priority_level_for(v_score));
  perform set_config('app.system_update', 'off', true);
end;
$$;

-- Recalcula todos los reportes abiertos (la antigüedad cambia con el tiempo).
-- Se puede programar con pg_cron (ver docs/PRIORIZACION.md).
create or replace function public.recalculate_all_priorities()
returns integer
language plpgsql security definer
set search_path = public
as $$
declare
  v_id    uuid;
  v_count integer := 0;
begin
  if auth.uid() is not null and not public.is_staff() then
    raise exception 'Acceso restringido' using errcode = '42501';
  end if;
  for v_id in
    select r.id from public.reports r
    join public.report_statuses st on st.code = r.status
    where st.is_open
  loop
    perform public.refresh_priority(v_id);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------
-- DETECCIÓN DE POSIBLES DUPLICADOS
-- ---------------------------------------------------------------------
-- Un reporte anterior es candidato si:
--   * está a <= dup_radius_m metros, y
--   * su texto es similar (trigramas >= dup_text_threshold) o es de la misma
--     categoría y está a <= dup_same_category_radius_m metros,
--   * se creó en los últimos dup_window_days días y no fue rechazado.
-- Solo se MARCA el reporte; el administrador decide (resolve_duplicate).
-- ---------------------------------------------------------------------
create or replace function public.detect_duplicates(p_id uuid)
returns integer
language plpgsql security definer
set search_path = public, extensions
as $$
declare
  r        public.reports;
  v_radius numeric := public.setting('dup_radius_m', 150);
  v_same   numeric := public.setting('dup_same_category_radius_m', 50);
  v_thr    numeric := public.setting('dup_text_threshold', 0.35);
  v_window numeric := public.setting('dup_window_days', 60);
  v_dlat   double precision;
  v_dlng   double precision;
  v_rows   integer;
begin
  select * into r from public.reports where id = p_id;
  if not found then
    return 0;
  end if;

  v_dlat := v_radius / 111320.0;
  v_dlng := v_radius / (111320.0 * cos(radians(r.latitude)));

  insert into public.duplicate_candidates (report_id, candidate_id, distance_m, text_similarity, score)
  select p_id, o.id, round(m.dist::numeric, 1), round(m.sim::numeric, 3),
         round((0.5 * (1 - m.dist / v_radius) + 0.5 * m.sim)::numeric, 3)
  from public.reports o
  cross join lateral (
    select public.distance_m(r.latitude, r.longitude, o.latitude, o.longitude) as dist,
           greatest(
             extensions.similarity(public.normalize_text(r.title), public.normalize_text(o.title)),
             extensions.similarity(r.search_text, o.search_text)
           ) as sim
  ) m
  where o.id <> p_id
    and o.status <> 'rechazado'
    and o.created_at <= r.created_at
    and o.created_at > r.created_at - make_interval(days => v_window::int)
    and o.latitude  between r.latitude  - v_dlat and r.latitude  + v_dlat
    and o.longitude between r.longitude - v_dlng and r.longitude + v_dlng
    and m.dist <= v_radius
    and (m.sim >= v_thr or (o.category_id = r.category_id and m.dist <= v_same))
  on conflict (report_id, candidate_id) do nothing;

  get diagnostics v_rows = row_count;

  if v_rows > 0 then
    perform set_config('app.system_update', 'on', true);
    update public.reports set possible_duplicate = true where id = p_id;
    perform set_config('app.system_update', 'off', true);
  end if;
  return v_rows;
end;
$$;

-- El administrador confirma o descarta un posible duplicado.
create or replace function public.resolve_duplicate(p_candidate_id bigint, p_decision text)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  dc public.duplicate_candidates;
begin
  if not public.is_staff() then
    raise exception 'Acceso restringido' using errcode = '42501';
  end if;
  if p_decision not in ('confirmado', 'descartado', 'pendiente') then
    raise exception 'Decisión inválida';
  end if;

  update public.duplicate_candidates
     set decision = p_decision,
         decided_by = auth.uid(),
         decided_at = case when p_decision = 'pendiente' then null else now() end
   where id = p_candidate_id
  returning * into dc;

  if not found then
    raise exception 'Candidato no encontrado';
  end if;

  perform set_config('app.system_update', 'on', true);
  if p_decision = 'confirmado' then
    update public.reports set duplicate_of = dc.candidate_id where id = dc.report_id;
  elsif (select duplicate_of from public.reports where id = dc.report_id) = dc.candidate_id then
    update public.reports set duplicate_of = null where id = dc.report_id;
  end if;

  update public.reports r
     set possible_duplicate = exists (
       select 1 from public.duplicate_candidates x
       where x.report_id = r.id and x.decision = 'pendiente')
   where r.id = dc.report_id;
  perform set_config('app.system_update', 'off', true);

  perform public.refresh_priority(dc.report_id);
  perform public.refresh_priority(dc.candidate_id);
end;
$$;

-- ---------------------------------------------------------------------
-- Triggers de reportes
-- ---------------------------------------------------------------------
create or replace function public.reports_before_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_count integer;
  v_year  integer;
  v_next  integer;
begin
  if v_uid is not null then
    -- Valores controlados por el servidor (el cliente no puede forzarlos).
    if not exists (select 1 from public.profiles where id = v_uid and is_active) then
      raise exception 'Tu cuenta está inactiva' using errcode = '42501';
    end if;
    select count(*) into v_count
      from public.reports where user_id = v_uid and created_at > now() - interval '24 hours';
    if v_count >= public.setting('max_reports_per_day', 20) then
      raise exception 'Has alcanzado el límite diario de reportes' using errcode = 'P0001';
    end if;
    new.user_id            := v_uid;
    new.status             := 'recibido';
    new.is_test_data       := false;
    new.possible_duplicate := false;
    new.duplicate_of       := null;
    new.admin_notes        := null;
    new.resolved_at        := null;
    new.created_at         := now();
  end if;

  if not exists (select 1 from public.categories where id = new.category_id and is_active) then
    raise exception 'Categoría inválida o inactiva';
  end if;

  new.created_at := coalesce(new.created_at, now());
  if new.reported_at is null
     or new.reported_at > new.created_at + interval '5 minutes'
     or new.reported_at < new.created_at - interval '30 days' then
    new.reported_at := new.created_at;
  end if;

  new.title          := btrim(new.title);
  new.description    := btrim(new.description);
  new.address        := nullif(btrim(new.address), '');
  new.priority_score := 0;
  new.priority_level := 'baja';
  new.search_text    := public.normalize_text(new.title || ' ' || new.description);
  new.sector_id      := public.find_sector(new.latitude, new.longitude);
  new.updated_at     := now();

  select c.responsible_entity_id into new.assigned_entity_id
    from public.categories c where c.id = new.category_id;

  -- Código único RSM-AAAA-NNNNNN (secuencia por año, segura ante concurrencia)
  v_year := extract(year from (new.created_at at time zone 'America/Bogota'))::int;
  insert into public.report_counters as rc (year, last_value) values (v_year, 1)
  on conflict (year) do update set last_value = rc.last_value + 1
  returning last_value into v_next;
  new.code := format('RSM-%s-%s', v_year, lpad(v_next::text, 6, '0'));

  return new;
end;
$$;

create trigger reports_before_insert
  before insert on public.reports
  for each row execute function public.reports_before_insert();

create or replace function public.reports_after_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_radius numeric := public.setting('geo_radius_m', 300);
  v_dlat   double precision := v_radius / 111320.0;
  v_dlng   double precision := v_radius / (111320.0 * cos(radians(new.latitude)));
  v_id     uuid;
begin
  insert into public.status_history (report_id, from_status, to_status, changed_by, note)
  values (new.id, null, new.status, new.user_id, 'Reporte creado por el ciudadano');

  insert into public.notifications (user_id, report_id, type, title, body)
  values (new.user_id, new.id, 'recibido', 'Reporte recibido',
          format('Tu reporte %s "%s" fue recibido. Te avisaremos cuando cambie de estado.', new.code, new.title));

  perform public.detect_duplicates(new.id);
  perform public.refresh_priority(new.id);

  -- La concentración geográfica de los reportes cercanos cambió.
  for v_id in
    select o.id from public.reports o
    join public.report_statuses st on st.code = o.status
    where o.id <> new.id and st.is_open
      and o.latitude  between new.latitude  - v_dlat and new.latitude  + v_dlat
      and o.longitude between new.longitude - v_dlng and new.longitude + v_dlng
  loop
    perform public.refresh_priority(v_id);
  end loop;

  return new;
end;
$$;

create trigger reports_after_insert
  after insert on public.reports
  for each row execute function public.reports_after_insert();

create or replace function public.reports_before_update()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_open boolean;
begin
  -- Campos inmutables
  new.id          := old.id;
  new.code        := old.code;
  new.user_id     := old.user_id;
  new.created_at  := old.created_at;
  new.client_uuid := old.client_uuid;

  if new.title is distinct from old.title or new.description is distinct from old.description then
    new.title       := btrim(new.title);
    new.description := btrim(new.description);
    new.search_text := public.normalize_text(new.title || ' ' || new.description);
  end if;

  if new.latitude is distinct from old.latitude or new.longitude is distinct from old.longitude then
    new.sector_id := public.find_sector(new.latitude, new.longitude);
  end if;

  if new.category_id is distinct from old.category_id then
    select c.responsible_entity_id into new.assigned_entity_id
      from public.categories c where c.id = new.category_id;
  end if;

  if new.status is distinct from old.status then
    select is_open into v_open from public.report_statuses where code = new.status;
    if new.status in ('atendido', 'cerrado') then
      new.resolved_at := coalesce(old.resolved_at, now());
    elsif coalesce(v_open, true) then
      new.resolved_at := null;
    end if;
  end if;

  if coalesce(current_setting('app.system_update', true), 'off') <> 'on' then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

create trigger reports_before_update
  before update on public.reports
  for each row execute function public.reports_before_update();

-- Registra automáticamente cualquier cambio de estado y notifica al ciudadano.
create or replace function public.reports_after_update()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  st     public.report_statuses;
  v_note text := nullif(current_setting('app.status_note', true), '');
begin
  if new.status is distinct from old.status then
    insert into public.status_history (report_id, from_status, to_status, changed_by, note)
    values (new.id, old.status, new.status, auth.uid(), v_note);

    select * into st from public.report_statuses where code = new.status;
    if st.notify_citizen then
      insert into public.notifications (user_id, report_id, type, title, body)
      values (new.user_id, new.id, new.status,
              format('Reporte %s', lower(st.name)),
              format('Tu reporte %s cambió a "%s".%s', new.code, st.name,
                     case when v_note is not null then ' Observación: ' || v_note else '' end));
    end if;
  end if;

  if new.severity is distinct from old.severity
     or new.category_id is distinct from old.category_id
     or new.status is distinct from old.status
     or new.latitude is distinct from old.latitude
     or new.longitude is distinct from old.longitude then
    perform public.refresh_priority(new.id);
  end if;
  return new;
end;
$$;

create trigger reports_after_update
  after update on public.reports
  for each row execute function public.reports_after_update();

-- Notifica al ciudadano cuando se agrega una observación pública
-- (excepto si viene de un cambio de estado, que ya genera su notificación).
create or replace function public.observations_after_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  r public.reports;
begin
  if new.is_public and coalesce(current_setting('app.status_note', true), '') = '' then
    select * into r from public.reports where id = new.report_id;
    insert into public.notifications (user_id, report_id, type, title, body)
    values (r.user_id, r.id, 'observacion', 'Nueva actualización de tu reporte',
            format('%s: %s', r.code, left(new.body, 180)));
  end if;
  return new;
end;
$$;

create trigger observations_after_insert
  after insert on public.observations
  for each row execute function public.observations_after_insert();

create or replace function public.observations_before_insert()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    new.author_id := auth.uid();
  end if;
  new.body := btrim(new.body);
  new.created_at := now();
  return new;
end;
$$;

create trigger observations_before_insert
  before insert on public.observations
  for each row execute function public.observations_before_insert();

-- ---------------------------------------------------------------------
-- RPC: cambio de estado con observación (panel administrativo)
-- ---------------------------------------------------------------------
create or replace function public.change_report_status(p_report_id uuid, p_status text, p_note text default null)
returns void
language plpgsql security definer
set search_path = public
as $$
declare
  v_old  text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if not public.is_staff() then
    raise exception 'Acceso restringido' using errcode = '42501';
  end if;
  if not exists (select 1 from public.report_statuses where code = p_status) then
    raise exception 'Estado inválido: %', p_status;
  end if;
  select status into v_old from public.reports where id = p_report_id for update;
  if not found then
    raise exception 'Reporte no encontrado';
  end if;
  if v_old = p_status then
    raise exception 'El reporte ya está en ese estado';
  end if;

  perform set_config('app.status_note', coalesce(v_note, ''), true);
  update public.reports set status = p_status where id = p_report_id;
  if v_note is not null then
    insert into public.observations (report_id, author_id, body, is_public)
    values (p_report_id, auth.uid(), v_note, true);
  end if;
  perform set_config('app.status_note', '', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Vista pública (sin datos personales)
-- ---------------------------------------------------------------------
-- Se ejecuta con permisos del propietario a propósito: expone SOLO
-- información de la problemática, nunca user_id, notas internas ni perfiles.
create or replace view public.public_reports
with (security_barrier = true)
as
select r.id, r.code, r.title, r.description,
       r.category_id, c.code as category_code, c.name as category_name,
       c.color as category_color, c.icon as category_icon,
       r.severity, r.priority_score, r.priority_level,
       r.status, st.name as status_name, st.color as status_color,
       r.latitude, r.longitude, r.address,
       r.sector_id, s.name as sector_name,
       r.photo_url, r.is_test_data,
       r.created_at, r.updated_at, r.resolved_at
from public.reports r
join public.categories c       on c.id = r.category_id
join public.report_statuses st on st.code = r.status
left join public.sectors s     on s.id = r.sector_id
where r.status <> 'rechazado'
  and r.duplicate_of is null;

-- Reportes públicos cercanos a un punto.
create or replace function public.nearby_reports(p_lat double precision, p_lng double precision,
                                                 p_radius_m double precision default 1500,
                                                 p_limit integer default 20)
returns setof public.public_reports
language sql stable
set search_path = public
as $$
  select pr.* from public.public_reports pr
  where pr.latitude  between p_lat - p_radius_m / 111320.0 and p_lat + p_radius_m / 111320.0
    and public.distance_m(p_lat, p_lng, pr.latitude, pr.longitude) <= p_radius_m
  order by public.distance_m(p_lat, p_lng, pr.latitude, pr.longitude)
  limit least(p_limit, 100);
$$;

-- ---------------------------------------------------------------------
-- Estadísticas
-- ---------------------------------------------------------------------
create or replace function public.get_public_stats()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select jsonb_build_object(
    'total',     (select count(*) from public.public_reports),
    'open',      (select count(*) from public.public_reports pr
                  join public.report_statuses st on st.code = pr.status where st.is_open),
    'resolved',  (select count(*) from public.public_reports where status in ('atendido','cerrado')),
    'last_7_days', (select count(*) from public.public_reports where created_at > now() - interval '7 days'),
    'critical_open', (select count(*) from public.public_reports pr
                  join public.report_statuses st on st.code = pr.status
                  where st.is_open and pr.severity = 5)
  );
$$;

create or replace function public.get_dashboard_stats(p_from timestamptz default null,
                                                      p_to   timestamptz default null)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  if not public.is_staff() then
    raise exception 'Acceso restringido' using errcode = '42501';
  end if;

  with base as (
    select r.*, c.name as category_name, c.color as category_color, s.name as sector_name,
           st.is_open
    from public.reports r
    join public.categories c on c.id = r.category_id
    join public.report_statuses st on st.code = r.status
    left join public.sectors s on s.id = r.sector_id
    where (p_from is null or r.created_at >= p_from)
      and (p_to   is null or r.created_at <  p_to)
  )
  select jsonb_build_object(
    'total', (select count(*) from base),
    'critical_open', (select count(*) from base where severity = 5 and is_open),
    'priority_critical', (select count(*) from base where priority_level = 'critica' and is_open),
    'possible_duplicates', (select count(*) from base where possible_duplicate and duplicate_of is null),
    'by_status', (
      select coalesce(jsonb_agg(jsonb_build_object(
               'code', st.code, 'name', st.name, 'color', st.color,
               'count', (select count(*) from base b where b.status = st.code))
             order by st.sort_order), '[]'::jsonb)
      from public.report_statuses st),
    'by_category', (
      select coalesce(jsonb_agg(x order by (x->>'count')::int desc), '[]'::jsonb) from (
        select jsonb_build_object('name', category_name, 'color', category_color, 'count', count(*)) x
        from base group by category_name, category_color) t),
    'by_severity', (
      select jsonb_agg(jsonb_build_object('severity', g,
               'count', (select count(*) from base b where b.severity = g)) order by g)
      from generate_series(1, 5) g),
    'by_priority', (
      select jsonb_agg(jsonb_build_object('level', l,
               'count', (select count(*) from base b where b.priority_level = l and b.is_open)))
      from unnest(array['baja','media','alta','critica']) l),
    'by_sector', (
      select coalesce(jsonb_agg(x order by (x->>'count')::int desc), '[]'::jsonb) from (
        select jsonb_build_object('name', coalesce(sector_name, 'Sin sector'), 'count', count(*),
                                  'open', count(*) filter (where is_open),
                                  'avg_priority', round(avg(priority_score), 1)) x
        from base group by sector_name) t),
    'by_date', (
      select jsonb_agg(jsonb_build_object('date', d::date,
               'count', (select count(*) from base b
                         where (b.created_at at time zone 'America/Bogota')::date = d::date)) order by d)
      from generate_series(
        coalesce(p_from, now() - interval '29 days')::date,
        coalesce(p_to, now())::date, interval '1 day') d),
    'hotspots', (
      select coalesce(jsonb_agg(x order by (x->>'count')::int desc, (x->>'avg_severity')::numeric desc), '[]'::jsonb)
      from (
        select jsonb_build_object(
                 'lat', round(avg(latitude)::numeric, 5), 'lng', round(avg(longitude)::numeric, 5),
                 'count', count(*), 'avg_severity', round(avg(severity), 1),
                 'sector', max(sector_name)) x
        from base
        where is_open and duplicate_of is null
        group by round(latitude::numeric, 3), round(longitude::numeric, 3)
        having count(*) >= 2
        limit 10) t)
  ) into v;
  return v;
end;
$$;

-- ---------------------------------------------------------------------
-- Permisos de ejecución: solo se exponen las RPC pensadas para el cliente
-- ---------------------------------------------------------------------
revoke execute on function public.compute_priority(uuid)        from public, anon, authenticated;
revoke execute on function public.refresh_priority(uuid)        from public, anon, authenticated;
revoke execute on function public.detect_duplicates(uuid)       from public, anon, authenticated;
revoke execute on function public.handle_new_user()             from public, anon, authenticated;
revoke execute on function public.reports_before_insert()       from public, anon, authenticated;
revoke execute on function public.reports_after_insert()        from public, anon, authenticated;
revoke execute on function public.reports_before_update()       from public, anon, authenticated;
revoke execute on function public.reports_after_update()        from public, anon, authenticated;
revoke execute on function public.observations_after_insert()   from public, anon, authenticated;
revoke execute on function public.observations_before_insert()  from public, anon, authenticated;
revoke execute on function public.profiles_before_update()      from public, anon, authenticated;
revoke execute on function public.recalculate_all_priorities()  from public, anon;
revoke execute on function public.get_dashboard_stats(timestamptz, timestamptz) from public, anon;
revoke execute on function public.change_report_status(uuid, text, text) from public, anon;
revoke execute on function public.resolve_duplicate(bigint, text) from public, anon;

grant execute on function public.recalculate_all_priorities()  to authenticated;
grant execute on function public.get_dashboard_stats(timestamptz, timestamptz) to authenticated;
grant execute on function public.change_report_status(uuid, text, text) to authenticated;
grant execute on function public.resolve_duplicate(bigint, text) to authenticated;
grant execute on function public.get_public_stats()            to anon, authenticated;
grant execute on function public.nearby_reports(double precision, double precision, double precision, integer) to anon, authenticated;
grant execute on function public.is_staff()                    to authenticated;
grant execute on function public.is_admin()                    to authenticated;
