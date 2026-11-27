-- ONEchat · Migración v1.26 — Privados efímeros al salir + récord vs en juegos
-- Pedido de Mario, 2026-11-27:
--  1) Al cerrar sesión se borra el historial de conversaciones
--     privadas del usuario (las conversaciones completas, con sus
--     mensajes y sesiones de cine; los juegos no cuelgan de la
--     conversación y el récord vs vive en su propia tabla).
--  2) Récord permanente de encuentros vs por pareja de jugadores:
--     cada partida terminada (por jugada final o por rendición)
--     suma victoria/derrota/empate en game_records, y la app lo
--     muestra al terminar cada encuentro.

-- ---------- 1) Limpiar privados al cerrar sesión ----------
create or replace function public.clear_my_private_history()
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  -- La fila de conversación arrastra en cascada los mensajes
  -- (direct_messages) y las sesiones de cine (cine_sessions).
  delete from public.conversations
   where user_a = auth.uid() or user_b = auth.uid();
end $$;

revoke execute on function public.clear_my_private_history() from public;
grant execute on function public.clear_my_private_history() to authenticated;

-- ---------- 2) Récord vs por pareja ----------
create table if not exists public.game_records (
  user_a     uuid not null references public.profiles(uid) on delete cascade,
  user_b     uuid not null references public.profiles(uid) on delete cascade,
  a_wins     int not null default 0,
  b_wins     int not null default 0,
  draws      int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);

alter table public.game_records enable row level security;

drop policy if exists game_records_select_own on public.game_records;
create policy game_records_select_own on public.game_records
  for select to authenticated
  using (auth.uid() in (user_a, user_b));

grant select on public.game_records to authenticated;

-- Suma el resultado cuando una partida pasa a 'finished'
-- (cubre tanto game_move como game_resign, que ya actualizan
-- status/winner_uid sobre games).
create or replace function public.record_game_result()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_a  uuid := least(new.player_a, new.player_b);
  v_b  uuid := greatest(new.player_a, new.player_b);
  v_aw int := case when new.winner_uid = v_a then 1 else 0 end;
  v_bw int := case when new.winner_uid = v_b then 1 else 0 end;
  v_dr int := case when new.winner_uid is null then 1 else 0 end;
begin
  if old.status = 'finished' or new.status <> 'finished' then
    return new;
  end if;
  insert into public.game_records (user_a, user_b, a_wins, b_wins, draws, updated_at)
  values (v_a, v_b, v_aw, v_bw, v_dr, now())
  on conflict (user_a, user_b) do update set
    a_wins     = game_records.a_wins + v_aw,
    b_wins     = game_records.b_wins + v_bw,
    draws      = game_records.draws + v_dr,
    updated_at = now();
  return new;
end $$;

drop trigger if exists games_record_result on public.games;
create trigger games_record_result
  after update on public.games
  for each row execute function public.record_game_result();

-- Backfill: contar las partidas ya terminadas.
insert into public.game_records (user_a, user_b, a_wins, b_wins, draws)
select least(player_a, player_b),
       greatest(player_a, player_b),
       (count(*) filter (where winner_uid = least(player_a, player_b)))::int,
       (count(*) filter (where winner_uid = greatest(player_a, player_b)))::int,
       (count(*) filter (where winner_uid is null))::int
  from public.games
 where status = 'finished'
 group by 1, 2
on conflict (user_a, user_b) do nothing;
