-- ONEchat — Migración v1.12: Gato 1 vs 1 en privados
-- Las tablas games/game_moves ya existen (v0). Todo el flujo va
-- por funciones security definer que validan en el servidor:
-- quién invita, quién acepta, de quién es el turno, celda libre
-- y cuándo termina la partida. La app solo dibuja el estado.

create or replace function public.game_invite(p_other uuid, p_type text default 'gato')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_existing uuid;
begin
  if p_other = auth.uid() then return null; end if;
  select id into v_existing from public.games
   where game_type = p_type and status in ('invited','active')
     and ((player_a = auth.uid() and player_b = p_other)
       or (player_a = p_other and player_b = auth.uid()))
   order by created_at desc limit 1;
  if v_existing is not null then return v_existing; end if;
  insert into public.games (game_type, player_a, player_b, state, turn_uid, status)
  values (p_type, auth.uid(), p_other,
          '{"board":[null,null,null,null,null,null,null,null,null]}'::jsonb,
          auth.uid(), 'invited')
  returning id into v_id;
  insert into public.notifications (uid, kind, payload)
  values (p_other, 'game_invite',
          jsonb_build_object('game_id', v_id, 'game_type', p_type,
                             'from_uid', auth.uid()));
  return v_id;
end $$;

create or replace function public.game_respond(p_game uuid, p_accept boolean)
returns boolean language plpgsql security definer set search_path = public as $$
declare g public.games;
begin
  select * into g from public.games where id = p_game;
  if g.id is null or g.status <> 'invited' then return false; end if;
  if p_accept and g.player_b = auth.uid() then
    update public.games set status = 'active', updated_at = now()
     where id = p_game;
    return true;
  end if;
  if not p_accept and auth.uid() in (g.player_b, g.player_a) then
    update public.games set status = 'declined', updated_at = now()
     where id = p_game;
    return true;
  end if;
  return false;
end $$;

create or replace function public.game_move(p_game uuid, p_cell int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g public.games;
  v_board jsonb;
  v_mark text;
  v_winner uuid;
  v_full boolean;
  v_line int[];
  v_lines int[][] := array[[0,1,2],[3,4,5],[6,7,8],[0,3,6],
                           [1,4,7],[2,5,8],[0,4,8],[2,4,6]];
  v_next uuid;
begin
  select * into g from public.games where id = p_game for update;
  if g.id is null or g.status <> 'active' then return null; end if;
  if g.turn_uid <> auth.uid() then return null; end if;
  if p_cell < 0 or p_cell > 8 then return null; end if;
  v_board := g.state -> 'board';
  if v_board -> p_cell <> 'null'::jsonb then return null; end if;
  v_mark := case when g.player_a = auth.uid() then 'X' else 'O' end;
  v_board := jsonb_set(v_board, array[p_cell::text], to_jsonb(v_mark));
  foreach v_line slice 1 in array v_lines loop
    if v_board ->> v_line[1] = v_mark
       and v_board ->> v_line[2] = v_mark
       and v_board ->> v_line[3] = v_mark then
      v_winner := auth.uid();
    end if;
  end loop;
  select not exists (
    select 1 from jsonb_array_elements(v_board) e
     where e.value = 'null'::jsonb
  ) into v_full;
  insert into public.game_moves (game_id, uid, move)
  values (p_game, auth.uid(),
          jsonb_build_object('cell', p_cell, 'mark', v_mark));
  if v_winner is not null or v_full then
    update public.games
       set state = jsonb_set(g.state, '{board}', v_board),
           status = 'finished', winner_uid = v_winner,
           turn_uid = null, updated_at = now()
     where id = p_game;
  else
    v_next := case when g.player_a = auth.uid()
                   then g.player_b else g.player_a end;
    update public.games
       set state = jsonb_set(g.state, '{board}', v_board),
           turn_uid = v_next, updated_at = now()
     where id = p_game;
  end if;
  return jsonb_build_object('board', v_board, 'winner', v_winner,
                            'finished', v_winner is not null or v_full);
end $$;

create or replace function public.game_resign(p_game uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare g public.games;
begin
  select * into g from public.games where id = p_game;
  if g.id is null or g.status <> 'active' then return false; end if;
  if auth.uid() not in (g.player_a, g.player_b) then return false; end if;
  update public.games
     set status = 'finished',
         winner_uid = case when g.player_a = auth.uid()
                           then g.player_b else g.player_a end,
         turn_uid = null, updated_at = now()
   where id = p_game;
  return true;
end $$;

-- Tiempo real para seguir la partida en vivo
alter publication supabase_realtime add table public.games;
