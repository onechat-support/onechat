-- ONEchat migración v1.29 — Paneles de control y origen de visitas
-- Pedido del dueño (2026-11-28):
--  1) Contador interno de visitas según su origen: Instagram,
--     buscadores (Google y otros), redes sociales, directo, etc.
--     Se registra en cada conexión al chat (connection_log) y en
--     cada visita a las páginas del sitio oficial (web_visits).
--  2) Dashboard global para Staff y dueño: datos de la
--     plataforma, moderación y gráficos de conexiones/orígenes.
--  3) Dashboard por sala para dueños de sala y moderadores:
--     historial de moderación de SU sala, actividad diaria de
--     sus moderadores y ranking de moderadores más activos.
--     El Staff/dueño global ve todas las salas.
-- Privacidad: las IP siguen SOLO en connection_log (lectura
-- Staff/dueño). Los paneles devuelven AGREGADOS: ningún panel
-- expone IP ni correos. Los RPC verifican el rol de quien
-- llama y devuelven {'error':'forbidden'} si no tiene permiso.

-- ---------- 1) Origen de las conexiones al chat ----------
alter table public.connection_log
  add column if not exists source   text,
  add column if not exists referrer text;

create index if not exists connection_log_source_time
  on public.connection_log (source, created_at desc);

-- ---------- 2) Visitas a las páginas del sitio oficial ----------
create table if not exists public.web_visits (
  id         bigint generated always as identity primary key,
  page       text,
  source     text,
  referrer   text,
  created_at timestamptz not null default now()
);

create index if not exists web_visits_time
  on public.web_visits (created_at desc);
create index if not exists web_visits_source_time
  on public.web_visits (source, created_at desc);

alter table public.web_visits enable row level security;
-- Sin políticas: escribe solo la función log-web-visit con rol
-- de servicio; la lectura va por los RPC de panel (definer).

-- ---------- Ayudantes de rol ----------
create or replace function public.is_global_staff(p_uid uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.profiles pr
                 where pr.uid = p_uid
                   and pr.global_role in ('staff', 'owner'));
$$;
grant execute on function public.is_global_staff(uuid)
  to anon, authenticated;

-- ---------- 3) Dashboard global (Staff y dueño) ----------
create or replace function public.dashboard_global()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tz  text := 'America/Los_Angeles';
  v_today date := (now() at time zone 'America/Los_Angeles')::date;
  v_out jsonb;
begin
  if v_uid is null or not public.is_global_staff(v_uid) then
    return jsonb_build_object('error', 'forbidden');
  end if;

  select jsonb_build_object(
    'users_total',
      (select count(*) from public.profiles),
    'users_registered',
      (select count(*) from public.profiles where not is_guest),
    'users_guests',
      (select count(*) from public.profiles where is_guest),
    'users_new_7d',
      (select count(*) from public.profiles
        where created_at >= now() - interval '7 days'),
    'connections_today',
      (select count(*) from public.connection_log
        where (created_at at time zone v_tz)::date = v_today),
    'connections_7d',
      (select count(*) from public.connection_log
        where created_at >= now() - interval '7 days'),
    'chat_sources_7d',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select coalesce(source, 'sin_dato') as source,
                count(*) as count
           from public.connection_log
          where created_at >= now() - interval '7 days'
          group by 1 order by 2 desc) x),
    'web_visits_today',
      (select count(*) from public.web_visits
        where (created_at at time zone v_tz)::date = v_today),
    'web_visits_7d',
      (select count(*) from public.web_visits
        where created_at >= now() - interval '7 days'),
    'web_sources_7d',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select coalesce(source, 'sin_dato') as source,
                count(*) as count
           from public.web_visits
          where created_at >= now() - interval '7 days'
          group by 1 order by 2 desc) x),
    'web_pages_7d',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select coalesce(page, '/') as source, count(*) as count
           from public.web_visits
          where created_at >= now() - interval '7 days'
          group by 1 order by 2 desc limit 8) x),
    'countries_7d',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select country as source, count(*) as count
           from public.connection_log
          where created_at >= now() - interval '7 days'
            and country is not null
          group by 1 order by 2 desc limit 8) x),
    'connections_by_day',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select to_char(d.day, 'YYYY-MM-DD') as day,
                coalesce(c.count, 0) as count
           from (select generate_series(v_today - 13, v_today,
                                        interval '1 day')::date as day) d
           left join (select (created_at at time zone v_tz)::date as day,
                             count(*) as count
                        from public.connection_log
                       where created_at >= now() - interval '14 days'
                       group by 1) c on c.day = d.day
          order by d.day) x),
    'mod_actions_7d',
      (select count(*) from public.mod_actions
        where created_at >= now() - interval '7 days'),
    'platform_bans_active',
      (select count(*) from public.platform_bans
        where lifted_at is null
          and (expires_at is null or expires_at > now())),
    'reports_pending',
      (select count(*) from public.reports_center
        where status in ('new', 'review'))
  ) into v_out;
  return v_out;
end;
$$;
grant execute on function public.dashboard_global() to authenticated;

-- ---------- 4) Salas que el usuario puede ver en panel ----------
-- Staff/dueño global: todas. Dueño de sala: las suyas.
-- Moderador: solo las salas donde modera.
create or replace function public.dashboard_my_rooms()
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_staff boolean;
  v_out jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'forbidden');
  end if;
  v_staff := public.is_global_staff(v_uid);

  select coalesce(jsonb_agg(x order by x.name), '[]'::jsonb) into v_out
  from (
    select r.id as id, r.name as name,
           case
             when v_staff then 'staff'
             when r.owner_uid = v_uid then 'owner'
             else 'moderator'
           end as my_role
      from public.rooms r
     where v_staff
        or r.owner_uid = v_uid
        or exists (select 1 from public.room_members m
                    where m.room_id = r.id and m.uid = v_uid
                      and m.role in ('owner', 'moderator'))
  ) x;
  return jsonb_build_object(
    'is_staff', v_staff,
    'rooms', coalesce(v_out, '[]'::jsonb));
end;
$$;
grant execute on function public.dashboard_my_rooms() to authenticated;

-- ---------- 5) Dashboard de una sala ----------
-- Permiso: Staff/dueño global, dueño de la sala o moderador
-- de la sala. Devuelve SOLO datos de esa sala: historial de
-- moderación, sancionados actuales, equipo de moderación con
-- su actividad de conexión y su ranking por acciones.
create or replace function public.dashboard_room(p_room uuid)
returns jsonb
language plpgsql stable security definer set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tz  text := 'America/Los_Angeles';
  v_today date := (now() at time zone 'America/Los_Angeles')::date;
  v_staff boolean;
  v_scope text;
  v_room record;
  v_out jsonb;
begin
  if v_uid is null then
    return jsonb_build_object('error', 'forbidden');
  end if;
  select * into v_room from public.rooms where id = p_room;
  if v_room is null then
    return jsonb_build_object('error', 'not_found');
  end if;

  v_staff := public.is_global_staff(v_uid);
  if v_staff then
    v_scope := 'global';
  elsif v_room.owner_uid = v_uid then
    v_scope := 'owner';
  elsif exists (select 1 from public.room_members m
                 where m.room_id = p_room and m.uid = v_uid
                   and m.role in ('owner', 'moderator')) then
    v_scope := 'moderator';
  else
    return jsonb_build_object('error', 'forbidden');
  end if;

  select jsonb_build_object(
    'room', jsonb_build_object('id', v_room.id, 'name', v_room.name),
    'my_scope', v_scope,
    'messages_3h',
      (select count(*) from public.room_messages
        where room_id = p_room
          and created_at >= now() - interval '3 hours'),
    'members_now',
      (select count(*) from public.room_members where room_id = p_room),
    'sanctioned_now',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select p.nickname as nickname,
                case when m.banned_at is not null then 'ban'
                     else 'mute' end as kind,
                case when m.banned_at is not null then null
                     else m.muted_until end as until
           from public.room_members m
           join public.profiles p on p.uid = m.uid
          where m.room_id = p_room
            and (m.banned_at is not null
                 or (m.muted_until is not null and m.muted_until > now()))
          order by p.nickname) x),
    'history',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select pa.nickname as actor,
                pt.nickname as target,
                a.action as action,
                a.detail as detail,
                a.created_at as at
           from public.mod_actions a
           left join public.profiles pa on pa.uid = a.actor_uid
           left join public.profiles pt on pt.uid = a.target_uid
          where a.room_id = p_room
          order by a.created_at desc limit 40) x),
    'moderators',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select t.nickname as nickname,
                t.role as role,
                t.actions_total as actions_total,
                t.actions_7d as actions_7d,
                t.connections_7d as connections_7d,
                t.active_days_7d as active_days_7d,
                t.last_seen as last_seen
           from (
             select p.nickname,
                    case when v_room.owner_uid = p.uid then 'owner'
                         else coalesce(m.role, 'moderator') end as role,
                    (select count(*) from public.mod_actions a
                      where a.actor_uid = p.uid
                        and a.room_id = p_room) as actions_total,
                    (select count(*) from public.mod_actions a
                      where a.actor_uid = p.uid and a.room_id = p_room
                        and a.created_at >= now() - interval '7 days')
                      as actions_7d,
                    (select count(*) from public.connection_log c
                      where c.uid = p.uid
                        and c.created_at >= now() - interval '7 days')
                      as connections_7d,
                    (select count(distinct (c.created_at at time zone v_tz)::date)
                       from public.connection_log c
                      where c.uid = p.uid
                        and c.created_at >= now() - interval '7 days')
                      as active_days_7d,
                    (select max(c.created_at) from public.connection_log c
                      where c.uid = p.uid) as last_seen
               from public.profiles p
               left join public.room_members m
                 on m.room_id = p_room and m.uid = p.uid
              where v_room.owner_uid = p.uid
                 or (m.role is not null and m.role in ('owner', 'moderator'))
           ) t
          order by t.actions_7d desc, t.connections_7d desc, t.nickname) x),
    'mod_today',
      (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
         select p.nickname as nickname,
                count(*) as connections,
                min(c.created_at) as first_at,
                max(c.created_at) as last_at
           from public.connection_log c
           join public.profiles p on p.uid = c.uid
          where (c.created_at at time zone v_tz)::date = v_today
            and (c.uid = v_room.owner_uid
                 or exists (select 1 from public.room_members m
                             where m.room_id = p_room and m.uid = c.uid
                               and m.role in ('owner', 'moderator')))
          group by p.nickname order by connections desc) x)
  ) into v_out;
  return v_out;
end;
$$;
grant execute on function public.dashboard_room(uuid) to authenticated;
