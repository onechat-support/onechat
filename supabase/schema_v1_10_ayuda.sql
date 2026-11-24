-- ONEchat — Migración v1.10: marcador de lectura (sala Ayuda/Staff)
-- Cada miembro guarda cuándo leyó la sala por última vez; el HUD
-- del Staff lo usa para contar mensajes de usuarios sin leer en
-- la sala Ayuda. La política members_update_own ya permite que
-- cada quien actualice su propia fila.
alter table public.room_members
  add column if not exists last_read_at timestamptz;
