-- =====================================================================
-- Registro de Riesgos Santa Marta
-- Migración 6: Funciones de DATOS DE PRUEBA
-- =====================================================================
-- Los datos de prueba NO se cargan automáticamente. Se generan desde el
-- SQL Editor de Supabase, asignándolos a una cuenta existente:
--
--   select public.seed_test_data('<UUID-del-usuario>');
--   select public.clear_test_data();   -- para eliminarlos
--
-- Todos quedan con is_test_data = true y el prefijo "[PRUEBA]" en el título.
-- Solo pueden ejecutarse sin sesión de usuario (SQL Editor / service role)
-- o por un administrador.
-- =====================================================================

create or replace function public.seed_test_data(p_user uuid)
returns integer
language plpgsql security definer
set search_path = public
as $$
declare
  v_id    uuid;
  v_count integer := 0;
  rec     record;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Acceso restringido' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'El usuario % no existe en profiles. Regístrate primero en la app.', p_user;
  end if;

  for rec in
    select * from (values
      -- titulo, descripcion, categoria, severidad, lat, lng, direccion, dias_atras, estado_final, observacion
      ('[PRUEBA] Hueco en Avenida Libertador',
       'Hay un hueco enorme en la Avenida Libertador, ocupa casi todo el carril derecho y ya han caído motos.',
       'vias', 5, 11.23652, -74.19480, 'Avenida del Libertador, frente a la estación de servicio', 12,
       'en_proceso', 'Se verificó en campo. Se programó intervención de infraestructura vial.'),
      ('[PRUEBA] Alcantarilla dañada en Mamatoco',
       'La tapa de la alcantarilla está rota y hay rebosamiento de aguas negras sobre la calle principal.',
       'alcantarillado', 4, 11.22910, -74.17330, 'Calle principal de Mamatoco, cerca de la iglesia', 8,
       'validado', 'Problemática validada. Se remitió a la empresa de servicios públicos.'),
      ('[PRUEBA] Inundación en Bonda',
       'Con cada aguacero el arroyo se desborda y la calle queda inundada, el agua entra a las casas.',
       'inundaciones', 5, 11.23440, -74.12930, 'Bonda, sector del arroyo', 3,
       'en_revision', null),
      ('[PRUEBA] Alumbrado público defectuoso',
       'Cinco postes de luz apagados en la cuadra, la zona queda totalmente oscura en la noche.',
       'alumbrado', 3, 11.20640, -74.22660, 'El Rodadero, carrera 2', 20,
       'atendido', 'Se reemplazaron las luminarias. Favor confirmar funcionamiento.'),
      ('[PRUEBA] Acumulación de basura',
       'Acumulación de basura y escombros en la esquina desde hace más de una semana, genera malos olores.',
       'basuras', 3, 11.24230, -74.20790, 'Centro, cerca del mercado', 6,
       'recibido', null),
      ('[PRUEBA] Señal de tránsito dañada',
       'La señal de PARE de la intersección está caída en el suelo, los carros no se detienen.',
       'senalizacion', 4, 11.19460, -74.21830, 'Gaira, intersección principal', 15,
       'cerrado', 'Señal reinstalada por la Secretaría de Movilidad.'),
      ('[PRUEBA] Árbol en riesgo de caer',
       'Árbol grande muy inclinado sobre la vía y cables eléctricos, las raíces están levantando el andén.',
       'arboles', 4, 11.22350, -74.18760, 'Los Almendros, calle 29', 2,
       'recibido', null),
      ('[PRUEBA] Daño en vía hacia Taganga',
       'Hundimiento del pavimento en la curva de la vía a Taganga, peligroso para vehículos de noche.',
       'vias', 4, 11.26010, -74.19310, 'Vía Santa Marta - Taganga, curva principal', 10,
       'rechazado', 'Reporte de prueba rechazado para demostrar el estado.'),
      ('[PRUEBA] Hueco peligroso en la Avenida Libertador',
       'Hay un hueco peligroso en la Avenida Libertador, casi frente a la estación de gasolina.',
       'vias', 4, 11.23670, -74.19455, 'Av. Libertador', 1,
       'recibido', null)
    ) as t(title, description, category_code, severity, lat, lng, address, days_ago, final_status, note)
  loop
    insert into public.reports (user_id, title, description, category_id, severity,
                                latitude, longitude, address, is_test_data, status, created_at)
    values (p_user, rec.title, rec.description,
            (select id from public.categories where code = rec.category_code),
            rec.severity, rec.lat, rec.lng, rec.address, true, 'recibido',
            now() - make_interval(days => rec.days_ago))
    returning id into v_id;

    -- Avanza por los estados intermedios para que el historial sea realista.
    if rec.final_status <> 'recibido' then
      perform set_config('app.status_note', '', true);
      if rec.final_status in ('validado','en_proceso','atendido','cerrado') then
        update public.reports set status = 'en_revision' where id = v_id;
        update public.reports set status = 'validado' where id = v_id;
      end if;
      if rec.final_status in ('en_proceso','atendido','cerrado') then
        update public.reports set status = 'en_proceso' where id = v_id;
      end if;
      if rec.final_status in ('atendido','cerrado') then
        update public.reports set status = 'atendido' where id = v_id;
      end if;
      if rec.final_status in ('cerrado','en_revision','rechazado') then
        perform set_config('app.status_note', coalesce(rec.note, ''), true);
        update public.reports set status = rec.final_status where id = v_id;
        perform set_config('app.status_note', '', true);
      end if;
    end if;

    if rec.note is not null then
      insert into public.observations (report_id, author_id, body, is_public)
      values (v_id, null, rec.note || ' (dato de prueba)', true);
    end if;

    v_count := v_count + 1;
  end loop;

  perform public.recalculate_all_priorities();
  return v_count;
end;
$$;

create or replace function public.clear_test_data()
returns integer
language plpgsql security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Acceso restringido' using errcode = '42501';
  end if;
  delete from public.reports where is_test_data;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.seed_test_data(uuid) from public, anon;
revoke execute on function public.clear_test_data() from public, anon;
grant execute on function public.seed_test_data(uuid) to authenticated;
grant execute on function public.clear_test_data() to authenticated;
