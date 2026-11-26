-- ONEchat · Migración v1.20b — Auditoría de seguridad 2026-11-25 (hallazgo 2)
-- Límite de velocidad de mensajes: máximo 30 por minuto por usuario,
-- sumando salas, privados y susurros. Un humano escribiendo rápido
-- queda muy por debajo; el flood automatizado se corta al instante.
create or replace function public.check_message_rate()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  select count(*) into v_count from (
    select created_at from public.room_messages
      where sender_uid = NEW.sender_uid
        and created_at > now() - interval '60 seconds'
    union all
    select created_at from public.direct_messages
      where sender_uid = NEW.sender_uid
        and created_at > now() - interval '60 seconds'
    union all
    select created_at from public.whispers
      where sender_uid = NEW.sender_uid
        and created_at > now() - interval '60 seconds'
  ) s;
  if v_count >= 30 then
    raise exception 'message_rate_limit' using errcode = 'P0001';
  end if;
  return NEW;
end $$;

create trigger trg_rate_room before insert on public.room_messages
  for each row execute function public.check_message_rate();
create trigger trg_rate_dm before insert on public.direct_messages
  for each row execute function public.check_message_rate();
create trigger trg_rate_whisper before insert on public.whispers
  for each row execute function public.check_message_rate();
