-- ONEchat migración v1.22 — Integración Beta en el Early (Lote A)
-- Orden de Mario (2026-11-26): integrar en el Early los cambios
-- previstos para la Beta (docs/CAMBIOS-POST-ALFA.md, puntos 9–14).
--   9  Enlaces de terceros en salas: el mensaje NO se publica y el
--      autor queda silenciado con escalera 5 min / 30 min / 2 h /
--      24 h. Sin baneo automático. Staff y dueño global exentos.
--  10  Avisos de moderación en Status con alcance por rol: dueño y
--      moderadores de la sala solo ven su sala; Staff y dueño
--      global ven todo. Incluye silencios automáticos (punto 9),
--      sanciones humanas y reportes recibidos.
--  11  Privados cerrables por usuario (profiles.dm_open); los
--      favoritos DEL DESTINATARIO siempre pueden escribirle.
--  12  Avisos del sistema en sala: códigos en room_messages kind
--      'system' ('join', 'leave', 'mod:mute', 'mod:ban' — estos dos
--      sin nick) y ajuste profiles.show_system_notices.
--  13  Cambio de nickname atómico (RPC change_nickname), con las
--      mismas validaciones del registro y freno de 7 días.
--  14  Susurros cerrables por usuario (profiles.whispers_open),
--      con la misma excepción de favoritos que los privados.
-- Extra: se restaura en la política de susurros el respeto al
-- silencio/baneo de la sala, que la recreación de v1.18 había
-- perdido. Columnas de sonido/vibración para el Lote C (punto 16).

-- ============ 1) Nuevas columnas de perfil ============
alter table public.profiles
  add column if not exists dm_open boolean not null default true,
  add column if not exists whispers_open boolean not null default true,
  add column if not exists show_system_notices boolean not null default true,
  add column if not exists sound_enabled boolean not null default true,
  add column if not exists vibrate_enabled boolean not null default true,
  add column if not exists nickname_changed_at timestamptz;

-- Tras v1.20 el select de profiles es por columnas: hay que otorgar
-- las columnas nuevas explícitamente (la actualización ya está
-- cubierta por el grant de tabla de v1.1 y la política de dueño).
grant select (dm_open, whispers_open, show_system_notices,
              sound_enabled, vibrate_enabled, nickname_changed_at)
  on public.profiles to anon, authenticated;

-- ============ 2) Infracciones por enlaces (punto 9) ============
create table if not exists public.link_infractions (
  id         bigint generated always as identity primary key,
  room_id    uuid not null references public.rooms(id) on delete cascade,
  uid        uuid not null references public.profiles(uid) on delete cascade,
  created_at timestamptz not null default now()
);
create index if not exists link_infractions_room_user
  on public.link_infractions (room_id, uid, created_at desc);
alter table public.link_infractions enable row level security;
drop policy if exists link_infractions_select on public.link_infractions;
create policy link_infractions_select on public.link_infractions
  for select using (
    exists (select 1 from public.profiles pr
            where pr.uid = auth.uid()
              and pr.global_role in ('staff', 'owner'))
    or (room_id is not null and public.can_moderate(room_id, auth.uid()))
  );

-- ============ 3) Avisos de moderación con alcance (punto 10) ====
-- Una fila de notificación por destinatario según su alcance:
-- staff/dueño global (todo) + dueño de la sala + sus moderadores.
create or replace function public.notify_moderation(
  p_room uuid, p_payload jsonb)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.notifications (uid, kind, payload)
  select distinct u.uid, 'moderation', p_payload
  from (
    select pr.uid as uid from public.profiles pr
     where pr.global_role in ('staff', 'owner')
    union
    select r.owner_uid from public.rooms r
     where r.id = p_room and r.owner_uid is not null
    union
    select m.uid from public.room_members m
     where m.room_id = p_room and m.role in ('owner', 'moderator')
  ) u;
end $$;
revoke execute on function public.notify_moderation(uuid, jsonb)
  from public, anon, authenticated;

-- Reportes recibidos -> aviso en Status (mismo alcance que el
-- centro de reportes: abuso de poder SOLO al dueño global).
create or replace function public.reports_center_notify()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if NEW.kind = 'abuse' then
    insert into public.notifications (uid, kind, payload)
    select pr.uid, 'moderation', jsonb_build_object(
        'action', 'report_abuse',
        'report_id', NEW.id,
        'room_name', NEW.room_name,
        'target_nickname', NEW.target_nickname,
        'reporter_nickname', NEW.reporter_nickname)
    from public.profiles pr where pr.global_role = 'owner';
  else
    insert into public.notifications (uid, kind, payload)
    select pr.uid, 'moderation', jsonb_build_object(
        'action', case when NEW.kind = 'error'
                       then 'report_error' else 'report_user' end,
        'report_id', NEW.id,
        'room_name', NEW.room_name,
        'target_nickname', NEW.target_nickname,
        'reporter_nickname', NEW.reporter_nickname)
    from public.profiles pr
    where pr.global_role in ('staff', 'owner');
  end if;
  return NEW;
end $$;
drop trigger if exists trg_reports_center_notify on public.reports_center;
create trigger trg_reports_center_notify
  after insert on public.reports_center
  for each row execute function public.reports_center_notify();

-- ============ 4) Guarda de enlaces en salas (punto 9) ==========
-- BEFORE INSERT: si el cuerpo trae un enlace que no es de YouTube,
-- el mensaje NO se publica (return null), se registra la
-- infracción, se aplica el silencio de la escalera, se avisa al
-- equipo (punto 10) y al propio autor, y queda el aviso de sistema
-- en la sala sin nick (punto 12). YouTube permitido: youtube.com
-- (y subdominios) y youtu.be.
create or replace function public.link_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_role text;
  v_nick text;
  v_match text;
  v_host text;
  v_bad boolean := false;
  v_count int;
  v_minutes int;
  v_room_name text;
begin
  if NEW.kind <> 'text' then return NEW; end if;
  select global_role, nickname into v_role, v_nick
    from public.profiles where uid = NEW.sender_uid;
  if v_role in ('staff', 'owner') then return NEW; end if;

  for v_match in
    select (regexp_matches(NEW.body,
            '(https?://[^\s]+|www\.[^\s]+)', 'gi'))[1]
  loop
    v_host := lower(regexp_replace(v_match, '^https?://', ''));
    v_host := regexp_replace(v_host, '^www\.', '');
    v_host := split_part(v_host, '/', 1);
    v_host := split_part(v_host, '?', 1);
    v_host := split_part(v_host, '#', 1);
    v_host := split_part(v_host, ':', 1);
    if v_host = 'youtu.be' or v_host = 'youtube.com'
       or v_host like '%.youtube.com' then
      -- enlace de YouTube: permitido
      null;
    else
      v_bad := true;
      exit;
    end if;
  end loop;
  if not v_bad then return NEW; end if;

  insert into public.link_infractions (room_id, uid)
  values (NEW.room_id, NEW.sender_uid);
  select count(*) into v_count
    from public.link_infractions
   where room_id = NEW.room_id and uid = NEW.sender_uid;
  v_minutes := case when v_count <= 1 then 5
                    when v_count = 2 then 30
                    when v_count = 3 then 120
                    else 1440 end;

  insert into public.room_members (room_id, uid, muted_until)
  values (NEW.room_id, NEW.sender_uid,
          now() + (v_minutes || ' minutes')::interval)
  on conflict (room_id, uid) do update
    set muted_until = case
          when public.room_members.muted_until is not null
           and public.room_members.muted_until > excluded.muted_until
          then public.room_members.muted_until
          else excluded.muted_until end;

  select name into v_room_name from public.rooms where id = NEW.room_id;

  perform public.notify_moderation(NEW.room_id, jsonb_build_object(
    'action', 'auto_mute_link',
    'room_id', NEW.room_id,
    'room_name', v_room_name,
    'target_nickname', v_nick,
    'minutes', v_minutes,
    'infractions', v_count));

  insert into public.notifications (uid, kind, payload)
  values (NEW.sender_uid, 'system', jsonb_build_object(
    'code', 'link_blocked',
    'room_name', v_room_name,
    'minutes', v_minutes,
    'infractions', v_count));

  insert into public.room_messages (room_id, sender_uid, kind, body)
  values (NEW.room_id, null, 'system', 'mod:mute');

  return null;  -- el mensaje NO se publica
end $$;
drop trigger if exists trg_link_guard on public.room_messages;
create trigger trg_link_guard
  before insert on public.room_messages
  for each row execute function public.link_guard();

-- ============ 5) Sanciones humanas: aviso y sistema (10 y 12) ===
-- Se recrea moderate_member de v1.7 agregando, tras aplicar la
-- sanción: el aviso de sistema en la sala para mute/ban (sin nick)
-- y la notificación de moderación con alcance por rol.
create or replace function public.moderate_member(
  p_room uuid, p_target uuid, p_action text,
  p_minutes int default null, p_detail text default null)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_nick text;
  v_target_nick text;
  v_room_name text;
begin
  if v_actor is null or p_target = v_actor then return false; end if;
  if not public.can_moderate(p_room, v_actor) then return false; end if;
  if exists (select 1 from public.rooms r
             where r.id = p_room and r.owner_uid = p_target)
     and not exists (select 1 from public.profiles pr
                     where pr.uid = v_actor
                       and pr.global_role in ('staff', 'owner')) then
    return false;
  end if;
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

  -- Punto 12: aviso de sistema en la sala, sin mostrar el nick.
  if p_action = 'mute' then
    insert into public.room_messages (room_id, sender_uid, kind, body)
    values (p_room, null, 'system', 'mod:mute');
  elsif p_action = 'ban' then
    insert into public.room_messages (room_id, sender_uid, kind, body)
    values (p_room, null, 'system', 'mod:ban');
  end if;

  -- Punto 10: aviso al equipo con alcance por rol.
  select nickname into v_actor_nick from public.profiles where uid = v_actor;
  select nickname into v_target_nick from public.profiles where uid = p_target;
  select name into v_room_name from public.rooms where id = p_room;
  perform public.notify_moderation(p_room, jsonb_build_object(
    'action', p_action,
    'room_id', p_room,
    'room_name', v_room_name,
    'actor_nickname', v_actor_nick,
    'target_nickname', v_target_nick,
    'minutes', p_minutes));

  return true;
end $$;
grant execute on function public.moderate_member(uuid, uuid, text, int, text)
  to authenticated;

-- ============ 6) Privados cerrables (punto 11) =================
create or replace function public.dm_allowed(
  p_sender uuid, p_recipient uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
           (select dm_open from public.profiles where uid = p_recipient),
           true)
      or exists (select 1 from public.favorites f
                  where f.uid = p_recipient
                    and f.favorite_uid = p_sender);
$$;
grant execute on function public.dm_allowed(uuid, uuid)
  to anon, authenticated;

create or replace function public.can_dm(p_target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select public.dm_allowed(auth.uid(), p_target); $$;
grant execute on function public.can_dm(uuid) to authenticated;

create or replace function public.dm_privacy_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare v_other uuid;
begin
  select case when c.user_a = NEW.sender_uid then c.user_b
              else c.user_a end
    into v_other
    from public.conversations c where c.id = NEW.conversation_id;
  if v_other is not null
     and not public.dm_allowed(NEW.sender_uid, v_other) then
    raise exception 'dm_closed' using errcode = 'P0001';
  end if;
  return NEW;
end $$;
drop trigger if exists trg_dm_privacy on public.direct_messages;
create trigger trg_dm_privacy
  before insert on public.direct_messages
  for each row execute function public.dm_privacy_guard();

-- ============ 7) Susurros cerrables (punto 14) =================
create or replace function public.whisper_allowed(
  p_sender uuid, p_target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select coalesce(
           (select whispers_open from public.profiles
             where uid = p_target),
           true)
      or exists (select 1 from public.favorites f
                  where f.uid = p_target
                    and f.favorite_uid = p_sender);
$$;
grant execute on function public.whisper_allowed(uuid, uuid)
  to anon, authenticated;

create or replace function public.can_whisper(p_target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$ select public.whisper_allowed(auth.uid(), p_target); $$;
grant execute on function public.can_whisper(uuid) to authenticated;

create or replace function public.whisper_privacy_guard()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if not public.whisper_allowed(NEW.sender_uid, NEW.target_uid) then
    raise exception 'whispers_closed' using errcode = 'P0001';
  end if;
  return NEW;
end $$;
drop trigger if exists trg_whisper_privacy on public.whispers;
create trigger trg_whisper_privacy
  before insert on public.whispers
  for each row execute function public.whisper_privacy_guard();

-- Política de susurros: se recrea la de v1.18 RESTAURANDO el
-- respeto al silencio/baneo de la sala (v1.7) que se había perdido.
drop policy if exists whispers_insert_sender on public.whispers;
create policy whispers_insert_sender on public.whispers
  for insert with check (
    auth.uid() = sender_uid
    and not public.account_banned(auth.uid())
    and not public.safety_user_blocked(auth.uid())
    and not public.safety_pair_users_blocked(auth.uid(), target_uid)
    and not exists (select 1 from public.room_members m
                    where m.room_id = whispers.room_id
                      and m.uid = auth.uid()
                      and (m.banned_at is not null
                           or (m.muted_until is not null
                               and m.muted_until > now())))
  );

-- ============ 8) Cambio de nickname (punto 13) =================
create or replace function public.change_nickname(p_new text)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_old_lower text;
  v_new_lower text := lower(p_new);
  v_guest boolean;
  v_changed timestamptz;
begin
  if v_uid is null then return 'not_authenticated'; end if;
  if p_new !~ '^[A-Za-z0-9_]{3,20}$' then return 'invalid'; end if;
  select nickname_lower, is_guest, nickname_changed_at
    into v_old_lower, v_guest, v_changed
    from public.profiles where uid = v_uid;
  if v_old_lower is null then return 'no_profile'; end if;
  if v_old_lower = v_new_lower then return 'same'; end if;
  if v_changed is not null
     and v_changed > now() - interval '7 days' then
    return 'cooldown';
  end if;
  if exists (select 1 from public.profiles
              where nickname_lower = v_new_lower) then
    return 'taken';
  end if;
  if exists (select 1 from public.nickname_reservations
              where nickname_lower = v_new_lower
                and uid <> v_uid) then
    return 'taken';
  end if;
  begin
    update public.profiles
       set nickname = p_new,
           nickname_lower = v_new_lower,
           nickname_changed_at = now()
     where uid = v_uid;
    delete from public.nickname_reservations where uid = v_uid;
    if not v_guest then
      insert into public.nickname_reservations (nickname_lower, uid)
      values (v_new_lower, v_uid);
    end if;
  exception when unique_violation then
    return 'taken';
  end;
  return 'ok';
end $$;
grant execute on function public.change_nickname(text) to authenticated;
