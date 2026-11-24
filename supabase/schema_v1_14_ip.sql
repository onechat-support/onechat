-- ONEchat v1.14 — Registro de conexiones (IP)
-- Pedido del dueño (2026-11-24): la plataforma debe ver y
-- registrar las IP que la visitan, para seguridad y
-- moderación. La IP la observa el servidor (función
-- log-visit) desde las cabeceras de la conexión real; la app
-- no puede inventarla ni modificarla.
--
-- Privacidad: el registro SOLO lo puede leer el Staff
-- global y el dueño (RLS). Ningún cliente puede escribir:
-- las filas las crea únicamente la función con rol de
-- servicio. Las IP NO van en profiles (esa tabla la lee
-- cualquier usuario autenticado).

create table public.connection_log (
  id         bigint generated always as identity primary key,
  uid        uuid not null references public.profiles(uid) on delete cascade,
  nickname   text,
  ip         text not null,
  user_agent text,
  created_at timestamptz not null default now()
);

create index connection_log_uid_time
  on public.connection_log (uid, created_at desc);
create index connection_log_time
  on public.connection_log (created_at desc);

alter table public.connection_log enable row level security;

-- Lectura: solo Staff global y dueño de la plataforma.
create policy connection_log_select_staff on public.connection_log
  for select to authenticated
  using (exists (select 1 from public.profiles pr
                 where pr.uid = auth.uid()
                   and pr.global_role in ('staff', 'owner')));

-- Sin políticas de insert/update/delete: escribe solo el
-- rol de servicio (la función log-visit), que salta RLS.
