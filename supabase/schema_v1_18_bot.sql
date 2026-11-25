-- ============================================================
-- ONEchat · Migración v1.18 — Bot de Seguridad Infantil (Fase B1)
-- Motor de reglas en el servidor: analiza cada mensaje de sala,
-- privado y susurro al insertarse. Niveles: 1 registro silencioso,
-- 2 alerta a Staff/dueño en Status, 3 protección (congelamiento
-- automático SOLO ante señal A —menor declarado— o combinación
-- C+D en conversación 1:1; validado por Mario el 2026-11-25).
-- Las demás combinaciones críticas parten como alerta N3 sin
-- congelar durante el periodo de medición (1–2 semanas).
-- ============================================================

-- ---------- Tablas ----------

create table public.safety_patterns (
  id       int generated always as identity primary key,
  category text not null check (category in ('A','B','C','D','E','F','G','H')),
  pattern  text not null,          -- regex POSIX sobre texto normalizado
  active   boolean not null default true,
  note     text,
  created_at timestamptz not null default now()
);

create table public.safety_signals (
  id              bigint generated always as identity primary key,
  source          text not null check (source in ('room','dm','whisper')),
  message_id      bigint,
  context_key     text not null,
  room_id         uuid references public.rooms(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  sender_uid      uuid references public.profiles(uid) on delete set null,
  sender_nickname text,
  other_uid       uuid references public.profiles(uid) on delete set null,
  other_nickname  text,
  category        text not null,
  pattern_id      int references public.safety_patterns(id) on delete set null,
  excerpt         text,
  created_at      timestamptz not null default now()
);
create index safety_signals_ctx_time on public.safety_signals (context_key, created_at desc);

create table public.safety_alerts (
  id              bigint generated always as identity primary key,
  context_key     text not null,
  source          text not null,
  level           int not null check (level in (1,2,3)),
  status          text not null default 'open'
                  check (status in ('open','released','held','reported')),
  categories      text[] not null default '{}',
  score           int not null default 0,
  frozen          boolean not null default false,
  room_id         uuid references public.rooms(id) on delete set null,
  room_name       text,
  conversation_id uuid references public.conversations(id) on delete set null,
  sender_uid      uuid references public.profiles(uid) on delete set null,
  sender_nickname text,
  other_uid       uuid references public.profiles(uid) on delete set null,
  other_nickname  text,
  last_excerpt    text,
  reviewed_by     uuid references public.profiles(uid) on delete set null,
  reviewed_by_nickname text,
  reviewed_at     timestamptz,
  resolution_note text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create unique index safety_alerts_open_ctx
  on public.safety_alerts (context_key) where status = 'open';
create index safety_alerts_status_level on public.safety_alerts (status, level, updated_at desc);

create table public.safety_holds (
  id          bigint generated always as identity primary key,
  scope       text not null check (scope in ('user','pair','room')),
  uid         uuid not null references public.profiles(uid) on delete cascade,
  other_uid   uuid references public.profiles(uid) on delete cascade,
  room_id     uuid references public.rooms(id) on delete cascade,
  alert_id    bigint references public.safety_alerts(id) on delete set null,
  reason      text not null,
  created_at  timestamptz not null default now(),
  released_at timestamptz,
  released_by uuid references public.profiles(uid) on delete set null
);
create index safety_holds_active on public.safety_holds (uid, scope) where released_at is null;

-- ---------- RLS: solo Staff global y dueño leen ----------

alter table public.safety_patterns enable row level security;
alter table public.safety_signals  enable row level security;
alter table public.safety_alerts   enable row level security;
alter table public.safety_holds    enable row level security;

create policy safety_patterns_select_staff on public.safety_patterns
  for select using (exists (select 1 from public.profiles p
    where p.uid = auth.uid() and p.global_role in ('staff','owner')));
create policy safety_signals_select_staff on public.safety_signals
  for select using (exists (select 1 from public.profiles p
    where p.uid = auth.uid() and p.global_role in ('staff','owner')));
create policy safety_alerts_select_staff on public.safety_alerts
  for select using (exists (select 1 from public.profiles p
    where p.uid = auth.uid() and p.global_role in ('staff','owner')));
create policy safety_holds_select_staff on public.safety_holds
  for select using (exists (select 1 from public.profiles p
    where p.uid = auth.uid() and p.global_role in ('staff','owner')));

grant select on public.safety_patterns, public.safety_signals,
  public.safety_alerts, public.safety_holds to authenticated;
grant all on public.safety_patterns, public.safety_signals,
  public.safety_alerts, public.safety_holds to service_role;

-- ---------- Normalización ----------

create or replace function public.safety_normalize(p_text text)
returns text language sql immutable as $$
  select regexp_replace(
           translate(lower(coalesce(p_text,'')),
                     'áéíóúüñ', 'aeiouun'),
           '[''’]', '', 'g')
$$;

-- ---------- Consultas de congelamiento (para las políticas) ----------

create or replace function public.safety_user_blocked(p_uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.safety_holds h
    where h.scope='user' and h.uid = p_uid and h.released_at is null);
$$;

create or replace function public.safety_room_blocked(p_uid uuid, p_room uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.safety_holds h
    where h.scope='room' and h.uid = p_uid and h.room_id = p_room
      and h.released_at is null);
$$;

create or replace function public.safety_pair_users_blocked(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.safety_holds h
    where h.scope='pair' and h.released_at is null
      and ((h.uid = p_a and h.other_uid = p_b)
        or (h.uid = p_b and h.other_uid = p_a)));
$$;

create or replace function public.safety_pair_blocked(p_conversation uuid, p_uid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversations c
    where c.id = p_conversation
      and (c.user_a = p_uid or c.user_b = p_uid)
      and public.safety_pair_users_blocked(c.user_a, c.user_b));
$$;

grant execute on function public.safety_user_blocked(uuid),
  public.safety_room_blocked(uuid, uuid),
  public.safety_pair_users_blocked(uuid, uuid),
  public.safety_pair_blocked(uuid, uuid) to anon, authenticated;

-- ---------- Aviso al equipo (Status) ----------

create or replace function public.safety_notify(
  p_alert_id bigint, p_level int, p_sender_nick text, p_other_nick text,
  p_room_name text, p_categories text[], p_excerpt text)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (uid, kind, payload)
  select p.uid, 'safety', jsonb_build_object(
      'alert_id', p_alert_id,
      'level', p_level,
      'from_nickname', p_sender_nick,
      'other_nickname', p_other_nick,
      'room_name', p_room_name,
      'categories', p_categories,
      'excerpt', left(coalesce(p_excerpt,''), 200))
  from public.profiles p
  where p.global_role in ('staff','owner');
end $$;

-- ---------- Motor de análisis ----------

create or replace function public.safety_analyze()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_source text; v_body text; v_norm text;
  v_sender uuid; v_sender_nick text;
  v_other uuid; v_other_nick text;
  v_room uuid; v_room_name text; v_conv uuid;
  v_ctx text; v_msg_id bigint;
  v_pat record; v_matched text[] := '{}'; v_first_pat int;
  v_cats text[]; v_score int;
  v_hasA boolean; v_hasB boolean; v_hasC boolean; v_hasD boolean;
  v_hasE boolean; v_hasF boolean;
  v_level int := 0; v_freeze boolean := false;
  v_alert public.safety_alerts%rowtype; v_is_new boolean := false;
  v_old_level int := 0;
begin
  -- Contexto según la tabla de origen
  if TG_TABLE_NAME = 'room_messages' then
    if NEW.kind <> 'text' then return NEW; end if;
    v_source := 'room'; v_body := NEW.body; v_sender := NEW.sender_uid;
    v_room := NEW.room_id; v_msg_id := NEW.id;
    v_ctx := 'room:' || NEW.room_id || ':' || NEW.sender_uid;
    select name into v_room_name from public.rooms where id = NEW.room_id;
  elsif TG_TABLE_NAME = 'direct_messages' then
    if NEW.body is null then return NEW; end if;
    v_source := 'dm'; v_body := NEW.body; v_sender := NEW.sender_uid;
    v_conv := NEW.conversation_id; v_msg_id := NEW.id;
    v_ctx := 'dm:' || NEW.conversation_id;
    select case when c.user_a = NEW.sender_uid then c.user_b else c.user_a end
      into v_other from public.conversations c where c.id = NEW.conversation_id;
  elsif TG_TABLE_NAME = 'whispers' then
    v_source := 'whisper'; v_body := NEW.body; v_sender := NEW.sender_uid;
    v_other := NEW.target_uid; v_room := NEW.room_id; v_msg_id := NEW.id;
    v_ctx := 'whisper:' || NEW.room_id || ':' ||
             least(NEW.sender_uid, NEW.target_uid) || ':' ||
             greatest(NEW.sender_uid, NEW.target_uid);
    select name into v_room_name from public.rooms where id = NEW.room_id;
  else
    return NEW;
  end if;

  select nickname into v_sender_nick from public.profiles where uid = v_sender;
  if v_other is not null then
    select nickname into v_other_nick from public.profiles where uid = v_other;
  end if;

  v_norm := public.safety_normalize(v_body);

  -- Coincidencias por categoría (una señal por categoría y mensaje)
  for v_pat in
    select distinct on (p.category) p.category, p.id
    from public.safety_patterns p
    where p.active and v_norm ~ p.pattern
      -- Guarda anti-falsos-positivos de la categoría A numérica:
      -- «tengo 16 años de experiencia / de casados / 15 hijos…»
      -- no es una declaración de minoría de edad.
      and not (p.category = 'A' and p.note = 'edad' and v_norm ~
        '(tengo 1[0-7] (dias|semanas|meses|hijos|hermanos|pesos|dolares|euros|libros)|anos de (experiencia|trabaj|casad|servicio|relacion|noviazgo)|anos (juntos|en la empresa)|years of (experience|working|marriage))')
    order by p.category, p.id
  loop
    v_matched := array_append(v_matched, v_pat.category);
    insert into public.safety_signals
      (source, message_id, context_key, room_id, conversation_id,
       sender_uid, sender_nickname, other_uid, other_nickname,
       category, pattern_id, excerpt)
    values
      (v_source, v_msg_id, v_ctx, v_room, v_conv,
       v_sender, v_sender_nick, v_other, v_other_nick,
       v_pat.category, v_pat.id, left(v_body, 280));
  end loop;

  if array_length(v_matched, 1) is null then return NEW; end if;

  -- Ventana de 24 h en este contexto
  select array_agg(distinct category), count(*)
    into v_cats, v_score
  from public.safety_signals
  where context_key = v_ctx and created_at > now() - interval '24 hours';

  v_hasA := 'A' = any(v_cats); v_hasB := 'B' = any(v_cats);
  v_hasC := 'C' = any(v_cats); v_hasD := 'D' = any(v_cats);
  v_hasE := 'E' = any(v_cats); v_hasF := 'F' = any(v_cats);

  -- Nivel y congelamiento (reglas validadas el 2026-11-25)
  if v_hasA then
    v_level := 3; v_freeze := true;
  elsif v_source in ('dm','whisper') and v_hasC and v_hasD then
    v_level := 3; v_freeze := true;
  elsif v_source in ('dm','whisper') and ((v_hasB and v_hasC)
      or (v_hasC and v_hasF) or (v_hasE and v_hasC)) then
    v_level := 3; v_freeze := false;   -- medición: alerta sin congelar
  elsif array_length(v_cats, 1) >= 2 or v_score >= 3 then
    v_level := 2;
  else
    v_level := 1;
  end if;

  -- Alerta abierta del contexto (crear o escalar)
  select * into v_alert from public.safety_alerts
   where context_key = v_ctx and status = 'open' for update;

  if found then
    v_old_level := v_alert.level;
    update public.safety_alerts set
      level = greatest(level, v_level),
      categories = (select array_agg(distinct c) from
        unnest(categories || v_cats) as c),
      score = v_score,
      frozen = frozen or v_freeze,
      last_excerpt = left(v_body, 280),
      updated_at = now()
    where id = v_alert.id
    returning * into v_alert;
  else
    insert into public.safety_alerts
      (context_key, source, level, categories, score, frozen,
       room_id, room_name, conversation_id,
       sender_uid, sender_nickname, other_uid, other_nickname,
       last_excerpt)
    values
      (v_ctx, v_source, v_level, v_cats, v_score, v_freeze,
       v_room, v_room_name, v_conv,
       v_sender, v_sender_nick, v_other, v_other_nick,
       left(v_body, 280))
    returning * into v_alert;
    v_is_new := true;
  end if;

  -- Congelamientos (sin duplicar)
  if v_freeze then
    if v_hasA then
      insert into public.safety_holds (scope, uid, alert_id, reason)
      select 'user', v_sender, v_alert.id,
             'Bot de seguridad: posible menor de edad (señal A)'
      where not exists (select 1 from public.safety_holds h
        where h.scope='user' and h.uid = v_sender
          and h.released_at is null);
    end if;
    if v_other is not null then
      insert into public.safety_holds (scope, uid, other_uid, alert_id, reason)
      select 'pair', v_sender, v_other, v_alert.id,
             'Bot de seguridad: conversación de riesgo congelada'
      where not exists (select 1 from public.safety_holds h
        where h.scope='pair' and h.released_at is null
          and ((h.uid = v_sender and h.other_uid = v_other)
            or (h.uid = v_other and h.other_uid = v_sender)));
    end if;
  end if;

  -- Aviso al equipo: alerta nueva de nivel 2+, o escalada de nivel
  if (v_is_new and v_level >= 2) or (not v_is_new and v_level > v_old_level and v_level >= 2) then
    perform public.safety_notify(v_alert.id, v_alert.level,
      v_sender_nick, v_other_nick, v_room_name, v_alert.categories, v_body);
  end if;

  return NEW;
end $$;

create trigger trg_safety_room after insert on public.room_messages
  for each row execute function public.safety_analyze();
create trigger trg_safety_dm after insert on public.direct_messages
  for each row execute function public.safety_analyze();
create trigger trg_safety_whisper after insert on public.whispers
  for each row execute function public.safety_analyze();

-- ---------- Revisión humana (Staff/dueño) ----------

create or replace function public.safety_review(
  p_alert_id bigint, p_action text, p_note text default null)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_role text; v_nick text; v_alert public.safety_alerts%rowtype;
begin
  select global_role, nickname into v_role, v_nick
    from public.profiles where uid = auth.uid();
  if v_role is null or v_role not in ('staff','owner') then
    return false;
  end if;
  select * into v_alert from public.safety_alerts where id = p_alert_id;
  if not found then return false; end if;

  if p_action = 'release' then
    update public.safety_holds set released_at = now(),
      released_by = auth.uid()
    where alert_id = p_alert_id and released_at is null;
    update public.safety_alerts set status = 'released',
      reviewed_by = auth.uid(), reviewed_by_nickname = v_nick,
      reviewed_at = now(), resolution_note = p_note,
      updated_at = now()
    where id = p_alert_id;
  elsif p_action = 'keep' then
    update public.safety_alerts set status = 'held',
      reviewed_by = auth.uid(), reviewed_by_nickname = v_nick,
      reviewed_at = now(), resolution_note = p_note,
      updated_at = now()
    where id = p_alert_id;
  elsif p_action = 'reported' then
    update public.safety_alerts set status = 'reported',
      reviewed_by = auth.uid(), reviewed_by_nickname = v_nick,
      reviewed_at = now(), resolution_note = p_note,
      updated_at = now()
    where id = p_alert_id;
  else
    return false;
  end if;
  return true;
end $$;

grant execute on function public.safety_review(bigint, text, text) to authenticated;

-- ---------- Políticas de inserción: sumar el congelamiento ----------
-- (Se recrean las políticas vigentes de v1.15 con las condiciones
-- del bot: usuario congelado no escribe; pareja congelada no se
-- escribe; usuario congelado en una sala no escribe en ella.)

drop policy if exists room_messages_insert on public.room_messages;
create policy room_messages_insert on public.room_messages
  for insert with check (
    auth.uid() = sender_uid
    and not public.account_banned(auth.uid())
    and not public.safety_user_blocked(auth.uid())
    and not public.safety_room_blocked(auth.uid(), room_messages.room_id)
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
    and not public.safety_user_blocked(auth.uid())
    and not public.safety_pair_blocked(conversation_id, auth.uid())
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.user_a = auth.uid() or c.user_b = auth.uid()))
  );

drop policy if exists whispers_insert_sender on public.whispers;
create policy whispers_insert_sender on public.whispers
  for insert with check (
    auth.uid() = sender_uid
    and not public.account_banned(auth.uid())
    and not public.safety_user_blocked(auth.uid())
    and not public.safety_pair_users_blocked(auth.uid(), target_uid)
  );
