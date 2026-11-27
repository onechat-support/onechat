-- ONEchat · Migración v1.28 — Apagar zumbidos + tema visual (skin)
-- Pedidos de Mario, 2026-11-27:
--  (a) Un interruptor para NO recibir zumbidos (a quien le
--      molesten): profiles.nudges_open + guarda en el servidor
--      que rechaza el zumbido con 'nudges_closed' (P0001), igual
--      que dm_open/whispers_open de la v1.22.
--  (b) Base para los temas visuales nostálgicos: profiles.skin
--      ('onechat' por defecto; 'mensajero' = el tema inspirado
--      en el mensajero clásico, nombre evocativo propio).

alter table public.profiles
  add column if not exists nudges_open boolean not null default true;

alter table public.profiles
  add column if not exists skin text not null default 'onechat';

grant select (nudges_open, skin) on public.profiles to authenticated;
grant update (nudges_open, skin) on public.profiles to authenticated;

-- ¿Puede p_from enviarle un zumbido a p_to? Solo si el destino
-- los tiene abiertos.
create or replace function public.nudges_allowed(p_from uuid, p_to uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select nudges_open from public.profiles where uid = p_to),
    true)
$$;

revoke execute on function public.nudges_allowed(uuid, uuid) from public;
grant execute on function public.nudges_allowed(uuid, uuid) to authenticated;

-- Helper para la app (pre-chequeo del botón de zumbido).
create or replace function public.can_nudge(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.nudges_allowed(auth.uid(), p_other)
$$;

revoke execute on function public.can_nudge(uuid) from public;
grant execute on function public.can_nudge(uuid) to authenticated;

-- Guarda: un zumbido hacia alguien que los desactivó no entra.
create or replace function public.nudge_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_other uuid;
begin
  if new.kind <> 'nudge' then
    return new;
  end if;
  select case when c.user_a = new.sender_uid then c.user_b else c.user_a end
    into v_other
    from public.conversations c
   where c.id = new.conversation_id;
  if v_other is not null
     and not public.nudges_allowed(new.sender_uid, v_other) then
    raise exception 'nudges_closed' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists direct_messages_nudge_guard on public.direct_messages;
create trigger direct_messages_nudge_guard
  before insert on public.direct_messages
  for each row execute function public.nudge_guard();
