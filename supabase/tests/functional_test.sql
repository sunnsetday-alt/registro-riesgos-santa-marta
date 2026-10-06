-- Pruebas funcionales de la base de datos (ejecutar sobre supabase_stub + migraciones).
\set ON_ERROR_STOP 1
insert into auth.users (id, email, raw_user_meta_data) values
 ('11111111-1111-1111-1111-111111111111','ciudadano@test.co','{"full_name":"Ana Ciudadana","phone":"3001234567","accepted_terms":true}'),
 ('22222222-2222-2222-2222-222222222222','admin@test.co','{"full_name":"Admin Alcaldía"}'),
 ('33333333-3333-3333-3333-333333333333','otro@test.co','{"full_name":"Otro","phone":"xx"}');
update public.profiles set role='admin' where id='22222222-2222-2222-2222-222222222222';
select 'perfiles' t, full_name, phone, role, accepted_terms_at is not null terms from public.profiles order by full_name;

select 'seed' t, public.seed_test_data('11111111-1111-1111-1111-111111111111') n;
select code, left(title,45) title, status, severity, priority_score, priority_level, possible_duplicate dup, (select name from sectors s where s.id=sector_id) sector
from reports order by code;
select 'duplicados' t, (select title from reports where id=report_id) nuevo, (select title from reports where id=candidate_id) anterior, distance_m, text_similarity, score from duplicate_candidates;
select 'historial' t, r.code, h.from_status, h.to_status, h.note from status_history h join reports r on r.id=h.report_id where r.title like '%Mamatoco%' order by h.id;

-- ===== Como ciudadano =====
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111', false);
select 'ciudadano ve reportes propios' t, count(*) from reports;
select 'ciudadano ve perfiles' t, count(*) from profiles;
select 'ciudadano ve publicos' t, count(*) from public_reports;
-- Intento de forzar estado / user_id: el servidor lo ignora
insert into reports (user_id, title, description, category_id, severity, latitude, longitude, status, client_uuid)
values ('33333333-3333-3333-3333-333333333333', 'Hueco grande en Avenida Libertador', 'Hay un hueco enorme en la avenida libertador cerca de la bomba', (select id from categories where code='vias'), 3, 11.23660, -74.19470, 'cerrado', 'aaaaaaaa-0000-0000-0000-000000000001')
returning code, status, user_id = auth.uid() es_propio, possible_duplicate, priority_level;
do $$ begin
  begin update profiles set role='admin' where id=auth.uid(); raise exception 'FALLO: escaló rol';
  exception when insufficient_privilege then raise notice 'OK: no puede escalar rol'; end;
  begin perform change_report_status((select id from reports limit 1),'cerrado','x'); raise exception 'FALLO';
  exception when insufficient_privilege then raise notice 'OK: ciudadano no cambia estados'; end;
  begin perform get_dashboard_stats(); raise exception 'FALLO';
  exception when insufficient_privilege then raise notice 'OK: ciudadano sin dashboard'; end;
end $$;
select 'notificaciones ciudadano' t, count(*) from notifications;
select 'obs visibles ciudadano' t, count(*) from observations;
-- Otro ciudadano no ve los reportes de Ana
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333', false);
select 'otro ve reportes ajenos' t, count(*) from reports;
select 'otro ve historial ajeno' t, count(*) from status_history;
-- ===== Como anónimo =====
reset role; set role anon; select set_config('request.jwt.claim.sub','', false);
select 'anon publicos' t, count(*) from public_reports; select 'anon stats' t, get_public_stats();
-- ===== Como admin =====
reset role; set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222', false);
select 'admin ve' t, count(*) from reports;
select change_report_status((select id from reports where title like '%Inundación%'), 'validado', 'Se verificó en campo. Se requiere intervención.');
select 'hist inundacion' t, from_status, to_status, changed_by is not null by_admin, note from status_history where report_id=(select id from reports where title like '%Inundación%') order by id;
select resolve_duplicate((select id from duplicate_candidates order by id limit 1), 'confirmado');
select 'tras confirmar' t, code, possible_duplicate, duplicate_of is not null from reports where possible_duplicate or duplicate_of is not null;
select 'dashboard' t, jsonb_pretty(get_dashboard_stats() - 'by_date');
select 'recalc' t, recalculate_all_priorities();
reset role;
select 'notif ana' t, type, title from notifications where user_id='11111111-1111-1111-1111-111111111111' order by created_at desc limit 4;
