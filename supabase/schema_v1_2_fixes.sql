-- ONEchat — Migración v1.2: correcciones tras la primera prueba real
-- (Mario, 2026-11-23).
--
-- Error 1: al volver a una sala ya visitada, la unión (upsert) intenta
-- actualizar la membresía existente y no había política de UPDATE en
-- room_members → la entrada fallaba y los mensajes no cargaban.
-- Error 2: el nickname de un invitado quedaba ocupado para siempre tras
-- cerrar sesión. Ahora el invitado puede borrar su propio perfil al
-- salir (la app lo hace) y existe una función para reclamar nicknames
-- de invitados inactivos hace más de 15 minutos.

create policy members_update_own on public.room_members
  for update using (auth.uid() = uid) with check (auth.uid() = uid);

create policy profiles_delete_own on public.profiles
  for delete using (auth.uid() = uid);

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
    return true;  -- libre
  end if;
  if v.is_guest
     and (v.last_seen_at is null
          or v.last_seen_at < now() - interval '15 minutes') then
    delete from public.profiles where uid = v.uid;
    return true;  -- reclamado
  end if;
  return false;   -- ocupado (registrado o invitado activo)
end;
$$;

grant execute on function public.claim_guest_nickname(text) to authenticated;

-- Limpieza puntual: perfil de invitado de prueba «Zeta» que Mario usó
-- en la primera prueba y quedó huérfano al cerrar sesión.
delete from public.profiles
 where nickname_lower = 'zeta' and is_guest = true;
