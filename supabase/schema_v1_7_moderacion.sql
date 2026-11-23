-- ONEchat migración v1.7 — Etapa 3 (moderación completa)
-- El esquema ya traía global_role, room_members.role, muted_until,
-- banned_at y mod_actions; la política de mensajes ya bloquea a
-- silenciados y baneados. Aquí se agrega la capa de permisos: las
-- sanciones se aplican SOLO desde funciones del servidor que
-- verifican el rol de quien actúa y dejan registro de auditoría.

-- ¿Puede este usuario moderar esta sala? Staff/dueño global,
-- dueño de la sala o moderador de la sala.
create or replace function public.can_moderate(p_room uuid, p_uid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    exists (select 1 from public.profiles pr
            where pr.uid = p_uid and pr.global_role in ('staff', 'owner'))
    or exists (select 1 from public.rooms r
               where r.id = p_room and r.owner_uid = p_uid)
    or exists (select 1 from public.room_members m
               where m.room_id = p_room and m.uid = p_uid
                 and m.role in ('owner', 'moderator'));
$$;
grant execute on function public.can_moderate(uuid, uuid) to anon, authenticated;

-- ¿Puede asignar roles en esta sala? Dueño de la sala o staff global.
create or replace function public.can_manage_roles(p_room uuid, p_uid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select
    exists (select 1 from public.profiles pr
            where pr.uid = p_uid and pr.global_role in ('staff', 'owner'))
    or exists (select 1 from public.rooms r
               where r.id = p_room and r.owner_uid = p_uid);
$$;
grant execute on function public.can_manage_roles(uuid, uuid) to anon, authenticated;

-- Aplicar una sanción en una sala. Acciones: mute (con p_minutes),
-- unmute, ban, unban, kick, feature, unfeature. Verifica permisos,
-- protege al dueño de la sala y al staff, y registra la auditoría.
create or replace function public.moderate_member(
  p_room uuid, p_target uuid, p_action text,
  p_minutes int default null, p_detail text default null)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or p_target = v_actor then return false; end if;
  if not public.can_moderate(p_room, v_actor) then return false; end if;
  -- El dueño de la sala solo puede ser moderado por staff global.
  if exists (select 1 from public.rooms r
             where r.id = p_room and r.owner_uid = p_target)
     and not exists (select 1 from public.profiles pr
                     where pr.uid = v_actor
                       and pr.global_role in ('staff', 'owner')) then
    return false;
  end if;
  -- El staff global solo puede ser moderado por el dueño de la plataforma.
  if exists (select 1 from public.profiles pr
             where pr.uid = p_target and pr.global_role in ('staff', 'owner'))
     and not exists (select 1 from public.profiles pr
                     where pr.uid = v_actor and pr.global_role = 'owner') then
    return false;
  end if;

  if p_action = 'mute' then
    if p_minutes is null or p_minutes <= 0 then return false; end if;
    insert into public.room_members (room_id, uid, muted_until)
    values (p_room, p_target, now() + (p_minutes || ' minutes')::interval)
    on conflict (room_id, uid)
    do update set muted_until = excluded.muted_until;
  elsif p_action = 'unmute' then
    update public.room_members set muted_until = null
     where room_id = p_room and uid = p_target;
  elsif p_action = 'ban' then
    insert into public.room_members (room_id, uid, banned_at)
    values (p_room, p_target, now())
    on conflict (room_id, uid)
    do update set banned_at = excluded.banned_at;
  elsif p_action = 'unban' then
    update public.room_members set banned_at = null
     where room_id = p_room and uid = p_target;
  elsif p_action = 'kick' then
    delete from public.room_members
     where room_id = p_room and uid = p_target and banned_at is null;
    if not found then return false; end if;
  elsif p_action = 'feature' then
    insert into public.room_members (room_id, uid, featured_until)
    values (p_room, p_target, now() + interval '7 days')
    on conflict (room_id, uid)
    do update set featured_until = excluded.featured_until;
  elsif p_action = 'unfeature' then
    update public.room_members set featured_until = null
     where room_id = p_room and uid = p_target;
  else
    return false;
  end if;

  insert into public.mod_actions (actor_uid, target_uid, room_id, action, detail)
  values (v_actor, p_target, p_room, p_action, p_detail);
  return true;
end $$;
grant execute on function public.moderate_member(uuid, uuid, text, int, text) to authenticated;

-- Asignar rol en la sala (moderator | member). Solo dueño/staff;
-- el dueño de la sala conserva siempre su rol. Queda en auditoría.
create or replace function public.set_room_role(
  p_room uuid, p_target uuid, p_role text)
returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  if p_role not in ('moderator', 'member') then return false; end if;
  if not public.can_manage_roles(p_room, auth.uid()) then return false; end if;
  if exists (select 1 from public.rooms r
             where r.id = p_room and r.owner_uid = p_target) then
    return false;
  end if;
  update public.room_members set role = p_role
   where room_id = p_room and uid = p_target;
  if not found then return false; end if;
  insert into public.mod_actions (actor_uid, target_uid, room_id, action, detail)
  values (auth.uid(), p_target, p_room, 'role', p_role);
  return true;
end $$;
grant execute on function public.set_room_role(uuid, uuid, text) to authenticated;

-- Los susurros también respetan el silencio y el baneo de la sala.
drop policy whispers_insert_sender on public.whispers;
create policy whispers_insert_sender on public.whispers
  for insert with check (
    auth.uid() = sender_uid
    and not exists (select 1 from public.room_members m
                    where m.room_id = whispers.room_id
                      and m.uid = auth.uid()
                      and (m.banned_at is not null
                           or (m.muted_until is not null
                               and m.muted_until > now())))
  );

-- Auditoría legible por: el actor, el afectado, quien modera la
-- sala y el staff global.
create policy mod_actions_select on public.mod_actions
  for select using (
    auth.uid() = actor_uid
    or auth.uid() = target_uid
    or (room_id is not null and public.can_moderate(room_id, auth.uid()))
    or exists (select 1 from public.profiles pr
               where pr.uid = auth.uid()
                 and pr.global_role in ('staff', 'owner'))
  );

-- Mario, dueño de la plataforma.
update public.profiles set global_role = 'owner'
 where nickname_lower = 'zeeth';
