-- ONEchat — Migración v1.3: el mensaje guarda el nickname de su autor.
--
-- Problema (reportado por Mario): los mensajes de sala guardaban solo
-- el uid del autor; al borrarse el perfil de un invitado (cierre de
-- sesión), la clave foránea dejaba sender_uid en NULL y el mensaje
-- quedaba sin autor («···» en la app).
-- Solución: foto del nickname dentro del propio mensaje al enviarlo;
-- el perfil sigue mandando si existe, pero el nombre ya no se pierde.

alter table public.room_messages
  add column if not exists sender_nickname text;

update public.room_messages m
   set sender_nickname = p.nickname
  from public.profiles p
 where p.uid = m.sender_uid
   and m.sender_nickname is null;

-- Restauración puntual y fiel: los dos mensajes de la Sala General que
-- Mario escribió como invitado «Zeta» en su prueba y quedaron sin autor
-- al cerrar esa sesión (identificados por su texto exacto).
update public.room_messages
   set sender_nickname = 'Zeta'
 where sender_uid is null
   and sender_nickname is null
   and body in ('Prueba 2, acceso web.', 'test de ingreso 2');
