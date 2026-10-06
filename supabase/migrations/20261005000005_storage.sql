-- =====================================================================
-- Registro de Riesgos Santa Marta
-- Migración 5: Almacenamiento de fotografías (Supabase Storage)
-- =====================================================================
-- Bucket de lectura pública: las fotos de problemáticas se muestran en el
-- mapa público. Las rutas son <user_id>/<uuid>.jpg (no adivinables) y la
-- app comprime y elimina metadatos EXIF antes de subir (ver PhotoService).
-- Solo usuarios autenticados pueden subir, y solo en su propia carpeta.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-photos', 'report-photos', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "fotos storage: subir en carpeta propia"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'report-photos'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "fotos storage: actualizar propias"
  on storage.objects for update to authenticated
  using (bucket_id = 'report-photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'report-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "fotos storage: listar propias o staff"
  on storage.objects for select to authenticated
  using (bucket_id = 'report-photos'
         and ((storage.foldername(name))[1] = auth.uid()::text or public.is_staff()));

create policy "fotos storage: staff elimina"
  on storage.objects for delete to authenticated
  using (bucket_id = 'report-photos' and public.is_staff());
