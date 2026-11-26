-- ONEchat · Migración v1.20 — Correcciones de la auditoría de
-- seguridad del 2026-11-25 (docs/AUDITORIA-SEGURIDAD.md).

-- 1) CRÍTICO: el correo de los perfiles deja de ser legible por la
--    API. El ingreso por nickname lo lee con la clave de servicio
--    en el servidor (no se ve afectado); la app solo ESCRIBE la
--    columna al registrarse (el permiso de inserción no se toca).
--    OJO: el permiso original era a nivel de TABLA (v1.1), así que
--    un revoke por columna no basta: se revoca el select de tabla
--    y se re-otorga por columnas, todas menos email. (La primera
--    versión de esta migración usó solo el revoke por columna y la
--    verificación en vivo demostró que el correo seguía legible;
--    esta es la forma corregida, verificada el mismo día.)
revoke select on public.profiles from anon, authenticated;
grant select (uid, nickname, nickname_lower, nickname_color, bio,
  photo_url, is_guest, global_role, language, country, gender,
  birth_year, theme_mode, profile_views, created_at, last_seen_at,
  show_in_directory, is_premium, conduct_accepted_at)
  on public.profiles to anon, authenticated;

-- 2) ALTO: límite de velocidad de mensajes. Máximo 30 mensajes en
--    60 segundos por usuario, sumando salas, privados y susurros.
--    El uso humano queda muy por debajo; el flood se corta.
create index if not exists idx_room_messages_sender_time
  on public.room_messages (sender_uid, created_at desc);
create index if not exists idx_dm_sender_time
  on public.direct_messages (sender_uid, created_at desc);
create index if not exists idx_whispers_sender_time
  on public.whispers (sender_uid, created_at desc);

create or replace function public.enforce_message_rate_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  select
    (select count(*) from public.room_messages
      where sender_uid = NEW.sender_uid
        and created_at > now() - interval '60 seconds')
  + (select count(*) from public.direct_messages
      where sender_uid = NEW.sender_uid
        and created_at > now() - interval '60 seconds')
  + (select count(*) from public.whispers
      where sender_uid = NEW.sender_uid
        and created_at > now() - interval '60 seconds')
  into v_count;
  if v_count >= 30 then
    raise exception 'rate_limit: demasiados mensajes seguidos; espera unos segundos';
  end if;
  return NEW;
end $$;

create trigger trg_rate_limit_room before insert on public.room_messages
  for each row execute function public.enforce_message_rate_limit();
create trigger trg_rate_limit_dm before insert on public.direct_messages
  for each row execute function public.enforce_message_rate_limit();
create trigger trg_rate_limit_whisper before insert on public.whispers
  for each row execute function public.enforce_message_rate_limit();
