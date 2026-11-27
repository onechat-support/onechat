-- ONEchat · Migración v1.25 — País por IP, limpieza automática
-- de mensajes y borrado de notificaciones propias
-- (pedidos de Mario, 2026-11-26)
--
-- 1) País de la conexión: lo resuelve la función log-visit
--    desde la IP observada por el servidor y lo guarda aquí;
--    la app lo usa para abrir la sala del país al entrar.
alter table public.connection_log
  add column if not exists country text;

-- 2) Cada usuario puede borrar SUS notificaciones: la app las
--    limpia al cerrar la sesión. Al eliminar la cuenta ya caen
--    en cascada desde profiles (uid references on delete
--    cascade), así que ese caso ya estaba cubierto.
drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own on public.notifications
  for delete to authenticated
  using (uid = auth.uid());

-- 3) Limpieza automática cada 3 horas (pg_cron, dentro de la
--    propia base): se borran los mensajes de salas, los
--    privados y los susurros. La evidencia de los reportes ya
--    vive copiada en reports_center.evidence y las señales de
--    Centinel en las tablas safety_*, así que la limpieza no
--    toca reportes ni seguridad. Las conversaciones (la lista
--    de privados) quedan, vacías.
create extension if not exists pg_cron;
select cron.schedule(
  'onechat-purge-messages-3h',
  '0 */3 * * *',
  $$delete from public.room_messages;
    delete from public.direct_messages;
    delete from public.whispers;$$
);
