-- ONEchat v1.15 — Fase S1 antitóxicos: el Destierro
-- Plan aprobado por Mario el 2026-11-24 (PLAN-SEGURIDAD-
-- ANTITOXICOS): como la MAC no es alcanzable en web, el
-- castigo supremo combina cuenta + dispositivo (huella e
-- identificador persistente) + IP. Cambiar la IP ya no
-- basta para volver.
--
-- platform_bans: una fila por capa bloqueada.
--   kind: 'account' (value = uid), 'device' (value =
--   device_id o huella), 'ip' (value = dirección IP).
--   expires_at null = permanente (solo lo aplica y lo
--   levanta el dueño). lifted_at: cuándo se levantó.
-- Solo Staff global y dueño leen la tabla (RLS); los
-- cambios van por las funciones apply/lift (definer), que
-- verifican el rol y dejan todo auditado en la misma fila
-- (applied_by, reason obligatoria).

create table public.platform_bans (
  id              bigint generated always as identity primary key,
  kind            text not null check (kind in ('account', 'device', 'ip')),
  value           text not null,
  target_uid      uuid references public.profiles(uid) on delete set null,
  target_nickname text,
  reason          text not null,
  applied_by      uuid not null references public.profiles(uid),
  applied_by_nickname text,
  expires_at      timestamptz,
  lifted_at       timestamptz,
  lifted_by       uuid references public.profiles(uid),
  created_at      timestamptz not null default now()
);

create index platform_bans_lookup
  on public.platform_bans (kind, value) where lifted_at is null;
create index platform_bans_target
  on public.platform_bans (target_uid, created_at desc);

alter table public.platform_bans enable row level security;

create policy platform_bans_select_staff on public.platform_bans
  for select to authenticated
  using (exists (select 1 from public.profiles pr
                 where pr.uid = auth.uid()
                   and pr.global_role in ('staff', 'owner')));

-- La visita registra también el dispositivo (v1.14+).
alter table public.connection_log add column device_id text;
alter table public.connection_log add column fingerprint text;

-- ¿Está desterrada esta cuenta? (para frenar envíos desde
-- sesiones ya abiertas: el control de entrada actúa al
-- abrir la app; esto cierra la puerta también al escribir)
create or replace function public.account_banned(p_uid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.platform_bans b
    where b.kind = 'account' and b.value = p_uid::text
      and b.lifted_at is null
      and (b.expires_at is null or b.expires_at > now())
  );
$$;
grant execute on function public.account_banned(uuid) to anon, authenticated;

-- Aplicar el Destierro: una sola llamada bloquea las tres
-- capas del objetivo (cuenta + su dispositivo actual + su
-- IP actual, según su última conexión registrada).
-- p_hours null = permanente (SOLO el dueño).
-- Devuelve cuántas capas se bloquearon.
create or replace function public.apply_platform_ban(
  p_target uuid, p_hours int, p_reason text)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_nick text;
  v_actor_nick text;
  v_exp timestamptz := case when p_hours is null then null
                            else now() + make_interval(hours => p_hours) end;
  v_ip text;
  v_device text;
  v_fp text;
  v_count int := 0;
begin
  if p_reason is null or length(trim(p_reason)) < 3 then
    raise exception 'reason_required';
  end if;
  select global_role, nickname into v_role, v_actor_nick
    from public.profiles where uid = v_actor;
  if v_role is null or v_role not in ('staff', 'owner') then
    raise exception 'not_staff';
  end if;
  if p_hours is null and v_role <> 'owner' then
    raise exception 'permanent_only_owner';
  end if;
  if p_target = v_actor then
    raise exception 'cannot_ban_self';
  end if;
  select nickname into v_nick from public.profiles where uid = p_target;
  if v_nick is null then raise exception 'target_not_found'; end if;

  -- Última conexión registrada del objetivo: IP y equipo.
  select ip, device_id, fingerprint into v_ip, v_device, v_fp
    from public.connection_log
    where uid = p_target
    order by created_at desc limit 1;

  insert into public.platform_bans
    (kind, value, target_uid, target_nickname, reason,
     applied_by, applied_by_nickname, expires_at)
  values
    ('account', p_target::text, p_target, v_nick, p_reason,
     v_actor, v_actor_nick, v_exp);
  v_count := v_count + 1;

  if v_device is not null then
    insert into public.platform_bans
      (kind, value, target_uid, target_nickname, reason,
       applied_by, applied_by_nickname, expires_at)
    values
      ('device', v_device, p_target, v_nick, p_reason,
       v_actor, v_actor_nick, v_exp);
    v_count := v_count + 1;
  end if;
  if v_fp is not null and v_fp <> coalesce(v_device, '') then
    insert into public.platform_bans
      (kind, value, target_uid, target_nickname, reason,
       applied_by, applied_by_nickname, expires_at)
    values
      ('device', v_fp, p_target, v_nick, p_reason,
       v_actor, v_actor_nick, v_exp);
    v_count := v_count + 1;
  end if;
  if v_ip is not null then
    insert into public.platform_bans
      (kind, value, target_uid, target_nickname, reason,
       applied_by, applied_by_nickname, expires_at)
    values
      ('ip', v_ip, p_target, v_nick, p_reason,
       v_actor, v_actor_nick, v_exp);
    v_count := v_count + 1;
  end if;

  return v_count;
end;
$$;
grant execute on function public.apply_platform_ban(uuid, int, text)
  to authenticated;

-- Levantar un destierro (una fila). Los permanentes solo
-- los levanta el dueño; los temporales, Staff o dueño.
create or replace function public.lift_platform_ban(p_ban_id bigint)
returns boolean
language plpgsql security definer set search_path = public as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_exp timestamptz;
begin
  select global_role into v_role from public.profiles where uid = v_actor;
  if v_role is null or v_role not in ('staff', 'owner') then
    raise exception 'not_staff';
  end if;
  select expires_at into v_exp from public.platform_bans
    where id = p_ban_id and lifted_at is null;
  if not found then return false; end if;
  if v_exp is null and v_role <> 'owner' then
    raise exception 'permanent_only_owner';
  end if;
  update public.platform_bans
    set lifted_at = now(), lifted_by = v_actor
    where id = p_ban_id;
  return true;
end;
$$;
grant execute on function public.lift_platform_ban(bigint) to authenticated;

-- Frenar envíos de cuentas desterradas con la sesión ya
-- abierta: se recrean las políticas de inserción vigentes
-- (v1) con UNA condición sumada — la cuenta desterrada no
-- escribe en salas, privados ni susurros.
drop policy if exists room_messages_insert on public.room_messages;
create policy room_messages_insert on public.room_messages
  for insert with check (
    auth.uid() = sender_uid
    and not public.account_banned(auth.uid())
    and not exists (select 1 from public.room_members m
                    where m.room_id = room_messages.room_id
                      and m.uid = auth.uid()
                      and (m.banned_at is not null
                           or (m.muted_until is not null and m.muted_until > now())))
  );

drop policy if exists dm_insert_sender on public.direct_messages;
create policy dm_insert_sender on public.direct_messages
  for insert with check (
    auth.uid() = sender_uid
    and not public.account_banned(auth.uid())
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.user_a = auth.uid() or c.user_b = auth.uid()))
  );

drop policy if exists whispers_insert_sender on public.whispers;
create policy whispers_insert_sender on public.whispers
  for insert with check (
    auth.uid() = sender_uid
    and not public.account_banned(auth.uid())
  );
