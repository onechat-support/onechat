-- ONEchat — Migración v1.1: permisos de API (GRANT) para las tablas.
-- Las tablas creadas por SQL necesitan GRANT explícito a los roles de la
-- API (authenticated / anon); las políticas RLS siguen decidiendo fila a fila.

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on all tables in schema public
  to authenticated;
grant select on public.profiles, public.rooms, public.room_members,
  public.nickname_reservations to anon;

grant usage, select on all sequences in schema public to authenticated;

-- Para tablas futuras creadas por SQL en este proyecto:
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant usage, select on sequences to authenticated;
