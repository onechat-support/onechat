-- ONEchat · Limpieza de los datos de la auditoría de seguridad 2026-11-25
-- Invitados de prueba: ZethAudit (dece3d4e-c923-44eb-892d-dda7e5d3fb0c)
-- y ZethAudit2 (4434c3ea-25f0-43e8-a2c4-42853b41411b), más sus mensajes
-- (incluidos los 15 de la prueba de flood en la Sala General).
delete from public.room_messages
 where sender_uid in ('dece3d4e-c923-44eb-892d-dda7e5d3fb0c',
                      '4434c3ea-25f0-43e8-a2c4-42853b41411b');
delete from public.direct_messages
 where sender_uid in ('dece3d4e-c923-44eb-892d-dda7e5d3fb0c',
                      '4434c3ea-25f0-43e8-a2c4-42853b41411b');
delete from public.whispers
 where sender_uid in ('dece3d4e-c923-44eb-892d-dda7e5d3fb0c',
                      '4434c3ea-25f0-43e8-a2c4-42853b41411b');
delete from public.room_members
 where uid in ('dece3d4e-c923-44eb-892d-dda7e5d3fb0c',
               '4434c3ea-25f0-43e8-a2c4-42853b41411b');
delete from auth.users
 where id in ('dece3d4e-c923-44eb-892d-dda7e5d3fb0c',
              '4434c3ea-25f0-43e8-a2c4-42853b41411b');

-- Verificación: debe devolver 0 (los mensajes de auditoría ya no existen).
-- Nota: la comprobación de que profiles.email ya no es legible por API
-- se hace desde fuera del SQL Editor (consulta anónima por REST),
-- porque el editor corre con privilegios de propietario y ve la columna.
select count(*) as mensajes_auditoria_restantes
  from public.room_messages
 where sender_uid in ('dece3d4e-c923-44eb-892d-dda7e5d3fb0c',
                      '4434c3ea-25f0-43e8-a2c4-42853b41411b');
