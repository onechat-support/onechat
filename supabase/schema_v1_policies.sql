-- ONEchat — Migración v1 (Etapa 1, MVP)
-- Políticas RLS completas para el MVP, salas iniciales y tiempo real.
-- Se aplica DESPUÉS de schema.sql v0. Idempotente en lo posible.

-- ============ PERFILES ============
create policy profiles_select_all on public.profiles
  for select using (true);
create policy profiles_insert_own on public.profiles
  for insert with check (auth.uid() = uid);
create policy profiles_update_own on public.profiles
  for update using (auth.uid() = uid) with check (auth.uid() = uid);

-- ============ RESERVAS DE NICKNAME ============
create policy reservations_select_all on public.nickname_reservations
  for select using (true);
create policy reservations_insert_own on public.nickname_reservations
  for insert with check (auth.uid() = uid);
create policy reservations_delete_own on public.nickname_reservations
  for delete using (auth.uid() = uid);

-- ============ SALAS ============
create policy rooms_select on public.rooms
  for select using (
    is_public
    or owner_uid = auth.uid()
    or exists (select 1 from public.room_members m
               where m.room_id = id and m.uid = auth.uid())
  );
create policy rooms_insert_own on public.rooms
  for insert with check (auth.uid() = owner_uid);
create policy rooms_update_owner on public.rooms
  for update using (auth.uid() = owner_uid) with check (auth.uid() = owner_uid);

create policy members_select_all on public.room_members
  for select using (true);
create policy members_insert_own on public.room_members
  for insert with check (auth.uid() = uid);
create policy members_delete_own on public.room_members
  for delete using (auth.uid() = uid);

-- ============ MENSAJES DE SALA ============
create policy room_messages_select on public.room_messages
  for select using (
    exists (select 1 from public.rooms r
            where r.id = room_id
              and (r.is_public or r.owner_uid = auth.uid()
                   or exists (select 1 from public.room_members m
                              where m.room_id = r.id and m.uid = auth.uid())))
  );
create policy room_messages_insert on public.room_messages
  for insert with check (
    auth.uid() = sender_uid
    and not exists (select 1 from public.room_members m
                    where m.room_id = room_messages.room_id
                      and m.uid = auth.uid()
                      and (m.banned_at is not null
                           or (m.muted_until is not null and m.muted_until > now())))
  );

-- ============ SOCIAL (favoritos y bloqueos: solo el dueño) ============
create policy favorites_all_own on public.favorites
  for all using (auth.uid() = uid) with check (auth.uid() = uid);
create policy blocks_all_own on public.blocks
  for all using (auth.uid() = uid) with check (auth.uid() = uid);

-- ============ CONVERSACIONES Y PRIVADOS ============
create policy conversations_select_participant on public.conversations
  for select using (auth.uid() = user_a or auth.uid() = user_b);
create policy conversations_insert_participant on public.conversations
  for insert with check (auth.uid() = user_a or auth.uid() = user_b);
create policy dm_insert_sender on public.direct_messages
  for insert with check (
    auth.uid() = sender_uid
    and exists (select 1 from public.conversations c
                where c.id = conversation_id
                  and (c.user_a = auth.uid() or c.user_b = auth.uid()))
  );

-- ============ SUSURROS ============
create policy whispers_insert_sender on public.whispers
  for insert with check (auth.uid() = sender_uid);

-- ============ NOTIFICACIONES (Status) ============
create policy notifications_insert_any_auth on public.notifications
  for insert with check (auth.uid() is not null);
create policy notifications_update_own on public.notifications
  for update using (auth.uid() = uid) with check (auth.uid() = uid);

-- ============ REPORTES ============
create policy reports_insert_own on public.reports
  for insert with check (auth.uid() = reporter_uid);
create policy reports_select_own on public.reports
  for select using (auth.uid() = reporter_uid);

-- ============ JUEGOS (modelo; la lógica llega en su fase) ============
create policy games_select_participants on public.games
  for select using (auth.uid() = player_a or auth.uid() = player_b);
create policy games_insert_participant on public.games
  for insert with check (auth.uid() = player_a or auth.uid() = player_b);
create policy game_moves_select_participants on public.game_moves
  for select using (
    exists (select 1 from public.games g
            where g.id = game_id
              and (g.player_a = auth.uid() or g.player_b = auth.uid()))
  );

-- ============ TIEMPO REAL ============
alter publication supabase_realtime add table public.room_messages;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.direct_messages;

-- ============ SALAS INICIALES ============
insert into public.rooms (slug, name, kind, country, welcome_msg, is_public) values
  ('general',    'Sala General',  'thematic', null, 'Bienvenido a la Sala General de ONEchat.', true),
  ('chile',      'Chile',         'regional', 'CL', 'Sala regional de Chile.', true),
  ('tecnologia', 'Tecnología',    'thematic', null, 'Hablemos de tecnología.', true),
  ('amistad',    'Amistad',       'thematic', null, 'Conoce gente y haz amigos.', true),
  ('musica',     'Música',        'thematic', null, 'Comparte tu música favorita.', true)
on conflict (slug) do nothing;
