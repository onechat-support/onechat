-- ONEchat · Migración v1.21 — Eliminación de cuenta (requisito
-- de Google Play: borrar la cuenta desde la app y desde la web).
-- purge_user_data(uid): desvincula las referencias sin cascada,
-- borra el contenido propio en salas y susurros, y elimina el
-- perfil (el resto cae en cascada: miembros, favoritos, bloqueos,
-- conversaciones y sus mensajes, notificaciones, partidas,
-- suscripciones, registro de conexiones, filas de la Galería y
-- reserva de nickname). Las señales de seguridad ya registradas
-- quedan desvinculadas (sender en null), como dicen los Términos.
-- Solo la invoca la función Edge «delete-account» con la clave
-- de servicio; nadie más tiene permiso de ejecutarla.
create or replace function public.purge_user_data(p_uid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid;
begin
  select uid into v_owner from public.profiles
    where global_role = 'owner' order by created_at limit 1;
  update public.rooms set owner_uid = null where owner_uid = p_uid;
  if v_owner is not null and v_owner <> p_uid then
    update public.platform_bans set applied_by = v_owner
      where applied_by = p_uid;
  else
    delete from public.platform_bans where applied_by = p_uid;
  end if;
  update public.platform_bans set lifted_by = null
    where lifted_by = p_uid;
  update public.reports_center set target_uid = null
    where target_uid = p_uid;
  update public.reports_center set resolved_by = null
    where resolved_by = p_uid;
  delete from public.room_messages where sender_uid = p_uid;
  delete from public.whispers
    where sender_uid = p_uid or target_uid = p_uid;
  delete from public.profiles where uid = p_uid;
end $$;

revoke execute on function public.purge_user_data(uuid)
  from public, anon, authenticated;
-- Ojo: el revoke a PUBLIC también quita el acceso del rol de
-- servicio (lo hereda de PUBLIC), así que hay que re-otorgárselo
-- explícito o la función Edge recibe «permission denied»
-- (cazado en la verificación del 2026-11-25).
grant execute on function public.purge_user_data(uuid)
  to service_role;
