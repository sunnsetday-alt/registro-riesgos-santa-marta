-- =====================================================================
-- Registro de Riesgos Santa Marta
-- Migración 3: Seguridad a nivel de fila (RLS)
-- =====================================================================
-- Principios:
--  * Todo está cerrado por defecto (RLS activado en todas las tablas).
--  * El ciudadano solo ve SUS datos personales y SUS reportes completos.
--  * La información pública sale por la vista public_reports (sin datos personales).
--  * El personal (roles is_staff) gestiona reportes; solo 'admin' gestiona
--    usuarios, categorías, sectores y parámetros.
--  * Las escrituras sensibles (historial, notificaciones, duplicados,
--    prioridad) solo ocurren mediante triggers/RPC con SECURITY DEFINER.
-- =====================================================================

alter table public.roles                enable row level security;
alter table public.entities             enable row level security;
alter table public.profiles             enable row level security;
alter table public.sectors              enable row level security;
alter table public.categories           enable row level security;
alter table public.report_statuses      enable row level security;
alter table public.reports              enable row level security;
alter table public.report_counters      enable row level security;
alter table public.report_photos        enable row level security;
alter table public.status_history       enable row level security;
alter table public.observations         enable row level security;
alter table public.duplicate_candidates enable row level security;
alter table public.notifications        enable row level security;
alter table public.device_tokens        enable row level security;
alter table public.priority_settings    enable row level security;

-- Catálogos de lectura pública --------------------------------------------
create policy "roles: lectura" on public.roles for select to anon, authenticated using (true);
create policy "estados: lectura" on public.report_statuses for select to anon, authenticated using (true);
create policy "sectores: lectura" on public.sectors for select to anon, authenticated using (true);
create policy "categorias: lectura" on public.categories for select to anon, authenticated using (true);

create policy "sectores: admin" on public.sectors for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "categorias: admin" on public.categories for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "estados: admin" on public.report_statuses for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Entidades ----------------------------------------------------------------
create policy "entidades: lectura" on public.entities for select to authenticated using (true);
create policy "entidades: admin" on public.entities for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Perfiles (datos personales) ---------------------------------------------
create policy "perfiles: ver propio o staff" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_staff());
create policy "perfiles: editar propio" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "perfiles: admin edita" on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Reportes -----------------------------------------------------------------
create policy "reportes: ver propios o staff" on public.reports for select to authenticated
  using (user_id = auth.uid() or public.is_staff());
create policy "reportes: crear propio" on public.reports for insert to authenticated
  with check (user_id = auth.uid());
create policy "reportes: staff modifica" on public.reports for update to authenticated
  using (public.is_staff()) with check (public.is_staff());
create policy "reportes: admin elimina" on public.reports for delete to authenticated
  using (public.is_admin());

-- Fotografías --------------------------------------------------------------
create policy "fotos: ver propias o staff" on public.report_photos for select to authenticated
  using (public.is_staff() or exists (
    select 1 from public.reports r where r.id = report_id and r.user_id = auth.uid()));
create policy "fotos: registrar en reporte propio" on public.report_photos for insert to authenticated
  with check (uploaded_by = auth.uid() and exists (
    select 1 from public.reports r where r.id = report_id and r.user_id = auth.uid()));
create policy "fotos: staff elimina" on public.report_photos for delete to authenticated
  using (public.is_staff());

-- Historial de estados (solo lectura; lo escribe el trigger) ---------------
create policy "historial: ver propio o staff" on public.status_history for select to authenticated
  using (public.is_staff() or exists (
    select 1 from public.reports r where r.id = report_id and r.user_id = auth.uid()));

-- Observaciones ------------------------------------------------------------
create policy "observaciones: ver" on public.observations for select to authenticated
  using (public.is_staff() or (is_public and exists (
    select 1 from public.reports r where r.id = report_id and r.user_id = auth.uid())));
create policy "observaciones: staff crea" on public.observations for insert to authenticated
  with check (public.is_staff());
create policy "observaciones: admin modifica" on public.observations for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
create policy "observaciones: admin elimina" on public.observations for delete to authenticated
  using (public.is_admin());

-- Duplicados (solo staff; las decisiones pasan por resolve_duplicate) ------
create policy "duplicados: staff ve" on public.duplicate_candidates for select to authenticated
  using (public.is_staff());

-- Notificaciones -----------------------------------------------------------
create policy "notificaciones: ver propias" on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy "notificaciones: marcar leídas" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "notificaciones: eliminar propias" on public.notifications for delete to authenticated
  using (user_id = auth.uid());

-- Tokens push ----------------------------------------------------------------
create policy "tokens: propios" on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Parámetros de prioridad ----------------------------------------------------
create policy "prioridad: staff lee" on public.priority_settings for select to authenticated
  using (public.is_staff());
create policy "prioridad: admin modifica" on public.priority_settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- report_counters: sin políticas → inaccesible para clientes.

-- Vista pública -------------------------------------------------------------
grant select on public.public_reports to anon, authenticated;

-- Las notificaciones viajan por Realtime al dispositivo del ciudadano.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
