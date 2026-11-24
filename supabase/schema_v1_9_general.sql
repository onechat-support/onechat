-- ONEchat migración v1.9 — La Sala General es la sala de entrada
-- Decisión de Mario (2026-11-23): General sale de la sección
-- Plataforma y pasa a ser la primera sala que se abre al entrar
-- a ONEchat. Sigue sin dueño (owner_uid nulo): la atienden
-- moderadores nombrados por el Staff, y solo el Staff/administradores
-- tienen poder de dueño sobre ella (can_manage_roles ya lo exige).

alter table public.rooms drop constraint if exists rooms_category_check;
alter table public.rooms add constraint rooms_category_check
  check (category in ('plataforma', 'latino', 'norteamerica', 'europa', 'tematicos', 'general'));

update public.rooms set category = 'general' where slug = 'general';
