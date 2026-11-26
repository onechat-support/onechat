-- ONEchat — Migración v1.24: «Cine juntos» Premium (punto 17)
-- Sesiones 1:1 dentro de una conversación privada para ver un
-- video de YouTube en sincronía. El estado compartido vive en
-- cine_sessions (play_state + position_sec + updated_at): cada
-- cliente calcula la posición actual como position_sec + el
-- tiempo transcurrido desde updated_at cuando está sonando.
-- Todo el flujo va por funciones security definer; la app solo
-- dibuja el estado y manda comandos al reproductor.

create table public.cine_sessions (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  host_uid        uuid not null references public.profiles(uid) on delete cascade,
  guest_uid       uuid not null references public.profiles(uid) on delete cascade,
  video_id        text not null,
  status          text not null default 'invited'
                  check (status in ('invited','active','ended','declined')),
  play_state      text not null default 'paused'
                  check (play_state in ('playing','paused')),
  position_sec    double precision not null default 0,
  updated_by      uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.cine_sessions enable row level security;

-- Solo los dos participantes pueden ver la sesión. Sin políticas
-- de escritura: todo pasa por las funciones de abajo.
create policy cine_select_participants on public.cine_sessions
  for select to authenticated
  using (auth.uid() in (host_uid, guest_uid));

grant select on public.cine_sessions to authenticated;

-- Invitar: solo un participante de la conversación, solo al otro
-- participante, y solo si quien invita es Premium (o dueño/Staff,
-- para operar y probar). Si ya hay una sesión viva en la
-- conversación, se devuelve esa.
create or replace function public.cine_invite(
    p_conversation uuid, p_other uuid, p_video_id text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_existing uuid; v_nick text;
begin
  if p_other = auth.uid() then return null; end if;
  if p_video_id is null or p_video_id !~ '^[A-Za-z0-9_-]{6,}$' then
    return null;
  end if;
  if not exists (
    select 1 from public.conversations c
     where c.id = p_conversation
       and ((c.user_a = auth.uid() and c.user_b = p_other)
         or (c.user_b = auth.uid() and c.user_a = p_other))
  ) then return null; end if;
  if not exists (
    select 1 from public.profiles
     where uid = auth.uid()
       and (is_premium or global_role in ('owner','staff'))
  ) then return null; end if;
  select id into v_existing from public.cine_sessions
   where conversation_id = p_conversation
     and status in ('invited','active')
   order by created_at desc limit 1;
  if v_existing is not null then return v_existing; end if;
  insert into public.cine_sessions
    (conversation_id, host_uid, guest_uid, video_id, updated_by)
  values (p_conversation, auth.uid(), p_other, p_video_id, auth.uid())
  returning id into v_id;
  select nickname into v_nick from public.profiles where uid = auth.uid();
  insert into public.notifications (uid, kind, payload)
  values (p_other, 'cine_invite',
          jsonb_build_object('session_id', v_id,
                             'from_uid', auth.uid(),
                             'from_nickname', v_nick,
                             'video_id', p_video_id));
  return v_id;
end $$;

-- Responder: el invitado acepta (pasa a activa) o cualquiera de
-- los dos rechaza/cancela estando invitada.
create or replace function public.cine_respond(
    p_session uuid, p_accept boolean)
returns boolean language plpgsql security definer set search_path = public as $$
declare s public.cine_sessions;
begin
  select * into s from public.cine_sessions where id = p_session;
  if s.id is null or s.status <> 'invited' then return false; end if;
  if p_accept and s.guest_uid = auth.uid() then
    update public.cine_sessions
       set status = 'active', updated_at = now(), updated_by = auth.uid()
     where id = p_session;
    return true;
  end if;
  if not p_accept and auth.uid() in (s.host_uid, s.guest_uid) then
    update public.cine_sessions
       set status = 'declined', updated_at = now(), updated_by = auth.uid()
     where id = p_session;
    return true;
  end if;
  return false;
end $$;

-- Control compartido: play/pausa/salto. Cualquiera de los dos
-- puede tocarlo; el otro cliente obedece el estado nuevo.
create or replace function public.cine_control(
    p_session uuid, p_play_state text, p_position double precision)
returns boolean language plpgsql security definer set search_path = public as $$
declare s public.cine_sessions;
begin
  select * into s from public.cine_sessions where id = p_session;
  if s.id is null or s.status <> 'active' then return false; end if;
  if auth.uid() not in (s.host_uid, s.guest_uid) then return false; end if;
  if p_play_state not in ('playing','paused') then return false; end if;
  update public.cine_sessions
     set play_state = p_play_state,
         position_sec = greatest(0, coalesce(p_position, 0)),
         updated_by = auth.uid(), updated_at = now()
   where id = p_session;
  return true;
end $$;

-- Terminar la sesión (cualquiera de los dos).
create or replace function public.cine_end(p_session uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare s public.cine_sessions;
begin
  select * into s from public.cine_sessions where id = p_session;
  if s.id is null or s.status not in ('invited','active') then
    return false;
  end if;
  if auth.uid() not in (s.host_uid, s.guest_uid) then return false; end if;
  update public.cine_sessions
     set status = 'ended', updated_at = now(), updated_by = auth.uid()
   where id = p_session;
  return true;
end $$;

grant execute on function public.cine_invite(uuid, uuid, text) to authenticated;
grant execute on function public.cine_respond(uuid, boolean) to authenticated;
grant execute on function public.cine_control(uuid, text, double precision) to authenticated;
grant execute on function public.cine_end(uuid) to authenticated;

-- Tiempo real para seguir la sesión en vivo
alter publication supabase_realtime add table public.cine_sessions;
