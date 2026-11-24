-- ONEchat — Migración v1.13: el aviso de invitación a jugar
-- incluye el nickname de quien invita, para que la Sala Status
-- pueda mostrar «X te invitó a jugar al Gato» (detalle en los
-- avisos, pedido de Mario en el alfa, 2026-11-24).

create or replace function public.game_invite(p_other uuid, p_type text default 'gato')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_existing uuid; v_nick text;
begin
  if p_other = auth.uid() then return null; end if;
  select id into v_existing from public.games
   where game_type = p_type and status in ('invited','active')
     and ((player_a = auth.uid() and player_b = p_other)
       or (player_a = p_other and player_b = auth.uid()))
   order by created_at desc limit 1;
  if v_existing is not null then return v_existing; end if;
  select nickname into v_nick from public.profiles where uid = auth.uid();
  insert into public.games (game_type, player_a, player_b, state, turn_uid, status)
  values (p_type, auth.uid(), p_other,
          '{"board":[null,null,null,null,null,null,null,null,null]}'::jsonb,
          auth.uid(), 'invited')
  returning id into v_id;
  insert into public.notifications (uid, kind, payload)
  values (p_other, 'game_invite',
          jsonb_build_object('game_id', v_id, 'game_type', p_type,
                             'from_uid', auth.uid(),
                             'from_nickname', v_nick));
  return v_id;
end $$;
