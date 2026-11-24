-- ONEchat — Migración v1.11: cerrar la autopromoción (seguridad)
-- Detectado en la verificación del HUD de Ayuda (2026-11-23): la
-- política de «actualiza tu propia fila» permitía a cualquier
-- usuario cambiarse el rol global (profiles.global_role) y el rol
-- y las sanciones de su fila de miembro (room_members) con una
-- llamada directa a la API, saltándose las funciones del servidor
-- de la Etapa 3. Estos disparadores congelan esos campos cuando
-- quien actualiza es el propio usuario desde la app; las
-- funciones de moderación (security definer, actualizan filas de
-- OTROS) y el panel de control (sin sesión de app) no se afectan.

create or replace function public.freeze_profile_role()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and auth.uid() = old.uid then
    new.global_role := old.global_role;
  end if;
  return new;
end $$;

drop trigger if exists trg_freeze_profile_role on public.profiles;
create trigger trg_freeze_profile_role
  before update on public.profiles
  for each row execute function public.freeze_profile_role();

create or replace function public.freeze_member_sanctions()
returns trigger language plpgsql as $$
begin
  if auth.uid() is not null and auth.uid() = old.uid then
    new.role := old.role;
    new.muted_until := old.muted_until;
    new.banned_at := old.banned_at;
    new.featured_until := old.featured_until;
  end if;
  return new;
end $$;

drop trigger if exists trg_freeze_member_sanctions on public.room_members;
create trigger trg_freeze_member_sanctions
  before update on public.room_members
  for each row execute function public.freeze_member_sanctions();
