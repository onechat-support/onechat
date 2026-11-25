-- ONEchat v1.17 — Centro de reportes y código de conducta del poder.
-- Plan: docs/PLAN-REPORTES-Y-CONDUCTA.md (aprobado por Mario el 2026-11-24).
-- Un botón «Reportar» con tres caminos (error, usuario, abuso de poder);
-- la evidencia la captura el SERVIDOR al enviar (últimos 30 mensajes de
-- la sala o últimas 20 acciones de moderación del acusado), no una foto.
-- Regla de oro de visibilidad: errores -> staff/dueño global; usuarios ->
-- moderadores de la sala + staff/dueño global; abuso de poder -> SOLO el
-- dueño global. Aceptar el código de conducta es condición del poder.

-- ============ 1) Aceptación del código de conducta ============
alter table public.profiles
  add column if not exists conduct_accepted_at timestamptz;

-- ============ 2) Tabla del centro de reportes ============
create table public.reports_center (
  id                   bigint generated always as identity primary key,
  kind                 text not null
                       check (kind in ('error', 'user', 'abuse')),
  reporter_uid         uuid not null
                       references public.profiles(uid) on delete cascade,
  reporter_nickname    text not null,
  target_uid           uuid references public.profiles(uid)
                       on delete set null,
  target_nickname      text,
  room_id              uuid references public.rooms(id)
                       on delete set null,
  room_name            text,
  description          text not null,
  evidence             jsonb not null default '{}'::jsonb,
  app_version          text,
  status               text not null default 'new'
                       check (status in ('new', 'review',
                                         'resolved', 'dismissed')),
  resolution_note      text,
  resolved_by          uuid references public.profiles(uid)
                       on delete set null,
  resolved_by_nickname text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
create index reports_center_status_idx
  on public.reports_center (status, created_at desc);
create index reports_center_room_idx
  on public.reports_center (room_id);

alter table public.reports_center enable row level security;

-- Solo lectura directa, y solo con el alcance del plan. Las escrituras
-- van exclusivamente por las funciones del servidor (sin políticas de
-- insert/update/delete: nadie escribe la tabla desde el cliente).
create policy reports_center_select_scoped on public.reports_center
  for select using (
    (kind = 'abuse' and exists (
       select 1 from public.profiles pr
       where pr.uid = auth.uid() and pr.global_role = 'owner'))
    or (kind = 'error' and exists (
       select 1 from public.profiles pr
       where pr.uid = auth.uid()
         and pr.global_role in ('staff', 'owner')))
    or (kind = 'user' and (
       exists (select 1 from public.profiles pr
               where pr.uid = auth.uid()
                 and pr.global_role in ('staff', 'owner'))
       or (room_id is not null
           and public.can_moderate(room_id, auth.uid()))))
  );

grant select on public.reports_center to authenticated;
grant all on public.reports_center to service_role;

-- ============ 3) Enviar un reporte (con evidencia del servidor) ====
create or replace function public.submit_report(
  p_kind text, p_target uuid, p_room uuid,
  p_description text, p_app_version text default null)
returns bigint
language plpgsql security definer set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_reporter text;
  v_target_nick text;
  v_room_name text;
  v_items  jsonb;
  v_evidence jsonb := '{}'::jsonb;
  v_id     bigint;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_kind not in ('error', 'user', 'abuse') then
    raise exception 'bad_kind';
  end if;
  if p_description is null or length(trim(p_description)) < 3 then
    raise exception 'description_required';
  end if;
  if p_kind in ('user', 'abuse') and p_target is null then
    raise exception 'target_required';
  end if;
  if p_target is not null and p_target = v_uid then
    raise exception 'cannot_report_self';
  end if;

  select nickname into v_reporter from public.profiles where uid = v_uid;
  if p_target is not null then
    select nickname into v_target_nick
      from public.profiles where uid = p_target;
  end if;
  if p_room is not null then
    select name into v_room_name from public.rooms where id = p_room;
  end if;

  if p_kind = 'user' and p_room is not null then
    -- Últimos 30 mensajes de la sala, en orden cronológico.
    select coalesce(jsonb_agg(e order by ord desc), '[]'::jsonb)
      into v_items
      from (select row_number() over (order by id desc) as ord,
                   jsonb_build_object('at', created_at,
                                      'from', sender_nickname,
                                      'body', body) as e
              from public.room_messages
             where room_id = p_room
             order by id desc
             limit 30) s;
    v_evidence := jsonb_build_object('room_messages', v_items);
  elsif p_kind = 'abuse' and p_target is not null then
    -- Últimas 20 acciones de moderación del acusado, cronológicas.
    select coalesce(jsonb_agg(e order by ord desc), '[]'::jsonb)
      into v_items
      from (select row_number() over (order by id desc) as ord,
                   jsonb_build_object(
                     'at', a.created_at,
                     'action', a.action,
                     'detail', a.detail,
                     'room', (select name from public.rooms
                               where id = a.room_id),
                     'target', (select nickname from public.profiles
                                 where uid = a.target_uid)) as e
              from public.mod_actions a
             where a.actor_uid = p_target
             order by a.id desc
             limit 20) s;
    v_evidence := jsonb_build_object('mod_actions', v_items);
  end if;

  insert into public.reports_center(
    kind, reporter_uid, reporter_nickname, target_uid, target_nickname,
    room_id, room_name, description, evidence, app_version)
  values (
    p_kind, v_uid, v_reporter, p_target, v_target_nick,
    p_room, v_room_name, trim(p_description), v_evidence, p_app_version)
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function
  public.submit_report(text, uuid, uuid, text, text) to authenticated;

-- ============ 4) Resolver un reporte (mismo alcance que la lectura)
create or replace function public.resolve_report(
  p_id bigint, p_status text, p_note text default null)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.reports_center%rowtype;
  v_nick text;
begin
  if v_uid is null then return false; end if;
  if p_status not in ('review', 'resolved', 'dismissed') then
    return false;
  end if;
  select * into v_row from public.reports_center where id = p_id;
  if not found then return false; end if;

  if v_row.kind = 'abuse' then
    if not exists (select 1 from public.profiles
                    where uid = v_uid and global_role = 'owner') then
      return false;
    end if;
  elsif v_row.kind = 'error' then
    if not exists (select 1 from public.profiles
                    where uid = v_uid
                      and global_role in ('staff', 'owner')) then
      return false;
    end if;
  else
    if not (exists (select 1 from public.profiles
                     where uid = v_uid
                       and global_role in ('staff', 'owner'))
            or (v_row.room_id is not null
                and public.can_moderate(v_row.room_id, v_uid))) then
      return false;
    end if;
  end if;

  select nickname into v_nick from public.profiles where uid = v_uid;
  update public.reports_center
     set status = p_status,
         resolution_note =
           case when p_status in ('resolved', 'dismissed')
                then p_note else resolution_note end,
         resolved_by =
           case when p_status in ('resolved', 'dismissed')
                then v_uid else resolved_by end,
         resolved_by_nickname =
           case when p_status in ('resolved', 'dismissed')
                then v_nick else resolved_by_nickname end,
         updated_at = now()
   where id = p_id;
  return true;
end;
$$;
grant execute on function
  public.resolve_report(bigint, text, text) to authenticated;

-- ============ 5) Mi situación de poder y de conducta ============
create or replace function public.my_power_status()
returns jsonb
language sql stable security definer set search_path = public
as $$
  select jsonb_build_object(
    'has_power',
      exists (select 1 from public.profiles
               where uid = auth.uid()
                 and global_role in ('staff', 'owner'))
      or exists (select 1 from public.room_members
                  where uid = auth.uid()
                    and role in ('owner', 'moderator'))
      or exists (select 1 from public.rooms
                  where owner_uid = auth.uid()),
    'conduct_accepted',
      coalesce((select conduct_accepted_at is not null
                  from public.profiles where uid = auth.uid()), false),
    'center_visible',
      exists (select 1 from public.profiles
               where uid = auth.uid()
                 and global_role in ('staff', 'owner'))
      or exists (select 1 from public.room_members
                  where uid = auth.uid()
                    and role in ('owner', 'moderator'))
      or exists (select 1 from public.rooms
                  where owner_uid = auth.uid()),
    'is_owner',
      exists (select 1 from public.profiles
               where uid = auth.uid() and global_role = 'owner')
  );
$$;
grant execute on function public.my_power_status() to authenticated;

-- ============ 6) Aceptar el código de conducta ============
create or replace function public.accept_conduct()
returns boolean
language plpgsql security definer set search_path = public
as $$
begin
  if auth.uid() is null then return false; end if;
  update public.profiles
     set conduct_accepted_at = now()
   where uid = auth.uid();
  return true;
end;
$$;
grant execute on function public.accept_conduct() to authenticated;
