-- ONEchat migración v1.8 — Reestructura de salas (enfoque regional)
-- Todas las salas tienen dueño, excepto General y Ayuda (plataforma,
-- atendidas por el Staff). El dueño inicial de las demás es Zeeth.

alter table public.rooms
  add column if not exists category text not null default 'tematicos';
alter table public.rooms
  add column if not exists sort int not null default 0;
alter table public.rooms drop constraint if exists rooms_category_check;
alter table public.rooms add constraint rooms_category_check
  check (category in ('plataforma', 'latino', 'norteamerica', 'europa', 'tematicos'));
alter table public.rooms drop constraint if exists rooms_kind_check;
alter table public.rooms add constraint rooms_kind_check
  check (kind in ('regional', 'thematic', 'private', 'temporary', 'platform'));

-- Se recrean todas las salas (la cascada limpia mensajes, miembros
-- y susurros de las salas anteriores; era historial de prueba).
delete from public.rooms;

-- Plataforma: sin dueño, las atiende el Staff.
insert into public.rooms (slug, name, kind, category, sort, owner_uid, welcome_msg) values
  ('general', 'General', 'platform', 'plataforma', 1, null,
   'Bienvenido a la Sala General de ONEchat. Pasa, saluda y conversa con todos.'),
  ('ayuda', 'Ayuda', 'platform', 'plataforma', 2, null,
   '¿Necesitas ayuda? Aquí te atiende el Staff de ONEchat.');

-- Latino: una sala por país, dueño Zeeth.
insert into public.rooms (slug, name, kind, category, sort, country, owner_uid)
select v.slug, v.name, 'regional', 'latino', v.sort, v.country,
       (select uid from public.profiles where nickname_lower = 'zeeth')
from (values
  ('mexico', '🇲🇽 México', 1, 'México'),
  ('guatemala', '🇬🇹 Guatemala', 2, 'Guatemala'),
  ('honduras', '🇭🇳 Honduras', 3, 'Honduras'),
  ('el-salvador', '🇸🇻 El Salvador', 4, 'El Salvador'),
  ('nicaragua', '🇳🇮 Nicaragua', 5, 'Nicaragua'),
  ('costa-rica', '🇨🇷 Costa Rica', 6, 'Costa Rica'),
  ('panama', '🇵🇦 Panamá', 7, 'Panamá'),
  ('cuba', '🇨🇺 Cuba', 8, 'Cuba'),
  ('republica-dominicana', '🇩🇴 República Dominicana', 9, 'República Dominicana'),
  ('puerto-rico', '🇵🇷 Puerto Rico', 10, 'Puerto Rico'),
  ('colombia', '🇨🇴 Colombia', 11, 'Colombia'),
  ('venezuela', '🇻🇪 Venezuela', 12, 'Venezuela'),
  ('ecuador', '🇪🇨 Ecuador', 13, 'Ecuador'),
  ('peru', '🇵🇪 Perú', 14, 'Perú'),
  ('bolivia', '🇧🇴 Bolivia', 15, 'Bolivia'),
  ('paraguay', '🇵🇾 Paraguay', 16, 'Paraguay'),
  ('chile', '🇨🇱 Chile', 17, 'Chile'),
  ('argentina', '🇦🇷 Argentina', 18, 'Argentina'),
  ('uruguay', '🇺🇾 Uruguay', 19, 'Uruguay'),
  ('brasil', '🇧🇷 Brasil', 20, 'Brasil')
) as v(slug, name, sort, country);

-- Norteamérica.
insert into public.rooms (slug, name, kind, category, sort, country, owner_uid)
select v.slug, v.name, 'regional', 'norteamerica', v.sort, v.country,
       (select uid from public.profiles where nickname_lower = 'zeeth')
from (values
  ('estados-unidos', '🇺🇸 Estados Unidos', 1, 'Estados Unidos'),
  ('canada', '🇨🇦 Canadá', 2, 'Canadá')
) as v(slug, name, sort, country);

-- Europa: una sola sala continental por ahora.
insert into public.rooms (slug, name, kind, category, sort, country, owner_uid)
values ('europa', '🇪🇺 Europa', 'regional', 'europa', 1, 'Europa',
        (select uid from public.profiles where nickname_lower = 'zeeth'));

-- Temáticos.
insert into public.rooms (slug, name, kind, category, sort, owner_uid)
select v.slug, v.name, 'thematic', 'tematicos', v.sort,
       (select uid from public.profiles where nickname_lower = 'zeeth')
from (values
  ('amistad', '🤝 Amistad', 1),
  ('encuentros', '💘 Encuentros', 2),
  ('debates', '🗣️ Debates', 3),
  ('pasiones', '❤️ Pasiones', 4),
  ('hot', '🔥 Hot (+18)', 5)
) as v(slug, name, sort);
