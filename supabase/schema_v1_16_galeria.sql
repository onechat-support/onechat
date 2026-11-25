-- ONEchat v1.16 — Web oficial W1+W2: Comunidad y Galería
-- Plan aprobado por Mario el 2026-11-24 (diseño mezcla
-- A+C; la función se llama «Galería», nunca «fotolog»).
--
-- 1) profiles.show_in_directory: aparecer en el directorio
--    público de la Comunidad (visible por defecto; el
--    usuario lo apaga en su Perfil).
-- 2) profiles.is_premium: indicador Premium (lo usará la
--    Etapa 6; hoy nace en false y la Galería lo respeta
--    para el límite de fotos). Queda CONGELADO ante la
--    auto-edición, igual que global_role (v1.11): nadie se
--    auto-otorga Premium.
-- 3) gallery_photos: las fotos de la Galería de cada
--    usuario registrado. Lectura para cualquier sesión
--    (la web lee con sesión anónima); escritura solo del
--    dueño. Límite: 3 fotos gratis; Premium, ilimitadas —
--    lo impone un gatillo en el servidor.
-- 4) Bucket de Storage «gallery» (lectura pública; cada
--    quien escribe solo en su carpeta <uid>/...).

alter table public.profiles
  add column if not exists show_in_directory boolean not null default true;
alter table public.profiles
  add column if not exists is_premium boolean not null default false;

create or replace function public.freeze_profile_role()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and auth.uid() = old.uid then
    new.global_role := old.global_role;
    new.is_premium := old.is_premium;
  end if;
  return new;
end $$;

create table public.gallery_photos (
  id         bigint generated always as identity primary key,
  uid        uuid not null references public.profiles(uid) on delete cascade,
  url        text not null,
  created_at timestamptz not null default now()
);
create index gallery_photos_uid on public.gallery_photos (uid, created_at);

alter table public.gallery_photos enable row level security;

create policy gallery_photos_select on public.gallery_photos
  for select to authenticated using (true);
create policy gallery_photos_insert_own on public.gallery_photos
  for insert to authenticated with check (uid = auth.uid());
create policy gallery_photos_delete_own on public.gallery_photos
  for delete to authenticated using (uid = auth.uid());

create or replace function public.enforce_gallery_limit()
returns trigger language plpgsql as $$
declare
  v_count int;
  v_premium boolean;
begin
  select is_premium into v_premium from public.profiles where uid = new.uid;
  if coalesce(v_premium, false) then
    return new;
  end if;
  select count(*) into v_count from public.gallery_photos where uid = new.uid;
  if v_count >= 3 then
    raise exception 'gallery_limit';
  end if;
  return new;
end $$;

drop trigger if exists trg_gallery_limit on public.gallery_photos;
create trigger trg_gallery_limit
  before insert on public.gallery_photos
  for each row execute function public.enforce_gallery_limit();

insert into storage.buckets (id, name, public)
values ('gallery', 'gallery', true)
on conflict (id) do nothing;

create policy gallery_objects_read on storage.objects
  for select using (bucket_id = 'gallery');
create policy gallery_objects_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'gallery'
              and (storage.foldername(name))[1] = auth.uid()::text);
create policy gallery_objects_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'gallery'
         and (storage.foldername(name))[1] = auth.uid()::text);
create policy gallery_objects_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'gallery'
         and (storage.foldername(name))[1] = auth.uid()::text);
