-- ONEchat — Migración v1.2.1: la función de reclamo usa como actividad
-- la más reciente entre last_seen_at y created_at (los perfiles
-- creados antes del seguimiento de actividad tienen last_seen_at NULL).

create or replace function public.claim_guest_nickname(p_nickname text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.profiles%rowtype;
begin
  select * into v from public.profiles
   where nickname_lower = lower(p_nickname);
  if not found then
    return true;
  end if;
  if v.is_guest
     and coalesce(v.last_seen_at, v.created_at) < now() - interval '15 minutes' then
    delete from public.profiles where uid = v.uid;
    return true;
  end if;
  return false;
end;
$$;
