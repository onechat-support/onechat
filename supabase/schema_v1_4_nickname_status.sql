-- ONEchat migración v1.4: estado de un nickname para el acceso
-- unificado (solo nickname en la pantalla de entrada).
-- Devuelve 'registered' | 'guest' | 'free' sin exponer ningún correo.
create or replace function public.nickname_status(p_nickname text)
returns text
language sql
security definer
set search_path = public
as $$
  select case
    when exists (
      select 1 from public.profiles
      where nickname_lower = lower(p_nickname) and is_guest = false
    ) then 'registered'
    when exists (
      select 1 from public.nickname_reservations
      where nickname_lower = lower(p_nickname)
    ) then 'registered'
    when exists (
      select 1 from public.profiles
      where nickname_lower = lower(p_nickname) and is_guest = true
    ) then 'guest'
    else 'free'
  end;
$$;

grant execute on function public.nickname_status(text) to anon, authenticated;
