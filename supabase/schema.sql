-- ONEchat — Esquema de base de datos v0 (Etapa 0, fundación)
-- PostgreSQL (Supabase). Se aplica al crear el proyecto; entornos dev/prod separados.
-- Principios: RLS activo en todo; la privacidad vive en la base, no en la app.

create extension if not exists "pgcrypto";

-- ============ IDENTIDAD Y PERFILES ============

create table public.profiles (
  uid            uuid primary key,               -- = auth.users.id (invitado o registrado)
  nickname       text not null,
  nickname_lower text not null unique,           -- unicidad sin distinguir mayúsculas
  nickname_color text not null default '#00C2A8',
  email          text,
  bio            text,
  photo_url      text,
  is_guest       boolean not null default true,
  global_role    text not null default 'user'    -- user | moderator | staff | owner
                 check (global_role in ('user','moderator','staff','owner')),
  language       text not null default 'es',
  country        text,
  gender         text,
  birth_year     int,
  theme_mode     text not null default 'system'  -- system | dark | light
                 check (theme_mode in ('system','dark','light')),
  profile_views  int not null default 0,
  created_at     timestamptz not null default now(),
  last_seen_at   timestamptz
);

-- Reserva atómica de nicknames registrados: insertar aquí es la única vía
-- de registrar un nickname; el índice único hace imposible la colisión.
create table public.nickname_reservations (
  nickname_lower text primary key,
  uid            uuid not null references public.profiles(uid) on delete cascade,
  reserved_at    timestamptz not null default now()
);

-- ============ SALAS ============

create table public.rooms (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,              -- acceso manual / búsqueda
  name        text not null,
  kind        text not null default 'thematic'   -- regional | thematic | private | temporary
              check (kind in ('regional','thematic','private','temporary')),
  country     text,                              -- para salas regionales
  owner_uid   uuid references public.profiles(uid),
  welcome_msg text,
  is_public   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table public.room_members (
  room_id   uuid not null references public.rooms(id) on delete cascade,
  uid       uuid not null references public.profiles(uid) on delete cascade,
  role      text not null default 'member'       -- owner | moderator | member
            check (role in ('owner','moderator','member')),
  featured_until timestamptz,                    -- usuario destacado (sin poderes)
  muted_until    timestamptz,
  banned_at      timestamptz,
  joined_at timestamptz not null default now(),
  primary key (room_id, uid)
);

create table public.room_messages (
  id         bigint generated always as identity primary key,
  room_id    uuid not null references public.rooms(id) on delete cascade,
  sender_uid uuid references public.profiles(uid) on delete set null,
  kind       text not null default 'text'        -- text | system
             check (kind in ('text','system')),
  body       text not null,
  mentions   uuid[] not null default '{}',       -- uids mencionados
  created_at timestamptz not null default now()
);
create index room_messages_room_time on public.room_messages (room_id, created_at desc);

-- ============ SOCIAL ============

create table public.favorites (
  uid          uuid not null references public.profiles(uid) on delete cascade,
  favorite_uid uuid not null references public.profiles(uid) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (uid, favorite_uid),
  check (uid <> favorite_uid)
);

create table public.blocks (
  uid        uuid not null references public.profiles(uid) on delete cascade,
  blocked_uid uuid not null references public.profiles(uid) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (uid, blocked_uid),
  check (uid <> blocked_uid)
);

-- ============ PRIVADOS Y SUSURROS (privacidad real por RLS) ============

create table public.conversations (
  id         uuid primary key default gen_random_uuid(),
  user_a     uuid not null references public.profiles(uid) on delete cascade,
  user_b     uuid not null references public.profiles(uid) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table public.direct_messages (
  id              bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_uid      uuid not null references public.profiles(uid) on delete cascade,
  kind            text not null default 'text'   -- text | voice (Premium)
                  check (kind in ('text','voice')),
  body            text,
  media_url       text,                          -- notas de voz en Storage
  duration_sec    int,
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index dm_conv_time on public.direct_messages (conversation_id, created_at desc);

-- Susurros: visibles SOLO para emisor y destinatario (RLS lo impone).
create table public.whispers (
  id          bigint generated always as identity primary key,
  room_id     uuid not null references public.rooms(id) on delete cascade,
  sender_uid  uuid not null references public.profiles(uid) on delete cascade,
  target_uid  uuid not null references public.profiles(uid) on delete cascade,
  body        text not null,
  created_at  timestamptz not null default now()
);

-- ============ SALA STATUS / NOTIFICACIONES ============

create table public.notifications (
  id         bigint generated always as identity primary key,
  uid        uuid not null references public.profiles(uid) on delete cascade,
  kind       text not null,   -- mention | whisper | dm | favorite_in | favorite_out | moderation | system
  payload    jsonb not null default '{}',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_time on public.notifications (uid, created_at desc);

-- ============ MODERACIÓN ============

create table public.reports (
  id          bigint generated always as identity primary key,
  reporter_uid uuid not null references public.profiles(uid) on delete cascade,
  target_uid   uuid references public.profiles(uid) on delete set null,
  room_id      uuid references public.rooms(id) on delete set null,
  message_ref  text,
  reason       text not null,
  status       text not null default 'open'      -- open | reviewed | dismissed
               check (status in ('open','reviewed','dismissed')),
  created_at   timestamptz not null default now()
);

create table public.mod_actions (
  id          bigint generated always as identity primary key,
  actor_uid   uuid not null references public.profiles(uid) on delete cascade,
  target_uid  uuid references public.profiles(uid) on delete set null,
  room_id     uuid references public.rooms(id) on delete set null,
  action      text not null,                     -- mute | ban | unban | feature | kick
  detail      text,
  created_at  timestamptz not null default now()
);

-- ============ JUEGOS Y PREMIUM (modelo listo desde el inicio) ============

create table public.games (
  id          uuid primary key default gen_random_uuid(),
  game_type   text not null,                     -- gato | conecta4 | damas | ludo | ajedrez
  player_a    uuid not null references public.profiles(uid) on delete cascade,
  player_b    uuid not null references public.profiles(uid) on delete cascade,
  state       jsonb not null default '{}',       -- tablero autoritativo en servidor
  turn_uid    uuid,
  status      text not null default 'invited'    -- invited | active | finished | declined
              check (status in ('invited','active','finished','declined')),
  winner_uid  uuid,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.game_moves (
  id         bigint generated always as identity primary key,
  game_id    uuid not null references public.games(id) on delete cascade,
  uid        uuid not null references public.profiles(uid) on delete cascade,
  move       jsonb not null,
  created_at timestamptz not null default now()
);

create table public.subscriptions (
  uid        uuid primary key references public.profiles(uid) on delete cascade,
  plan       text not null default 'free',       -- free | premium
  provider   text,                               -- google_play | app_store
  status     text not null default 'none',       -- none | active | expired | refunded
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ============ RLS (base; las políticas detalladas se completan en Etapa 1) ============

alter table public.profiles enable row level security;
alter table public.nickname_reservations enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_messages enable row level security;
alter table public.favorites enable row level security;
alter table public.blocks enable row level security;
alter table public.conversations enable row level security;
alter table public.direct_messages enable row level security;
alter table public.whispers enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.mod_actions enable row level security;
alter table public.games enable row level security;
alter table public.game_moves enable row level security;
alter table public.subscriptions enable row level security;

-- Susurros: solo emisor y destinatario pueden leerlos. Nadie más. Sin excepciones visuales.
create policy whispers_only_participants on public.whispers
  for select using (auth.uid() = sender_uid or auth.uid() = target_uid);

-- Privados: solo los dos participantes de la conversación.
create policy dm_only_participants on public.direct_messages
  for select using (
    exists (select 1 from public.conversations c
            where c.id = conversation_id
              and (c.user_a = auth.uid() or c.user_b = auth.uid()))
  );

-- Notificaciones (Sala Status): solo el dueño.
create policy notifications_only_owner on public.notifications
  for select using (auth.uid() = uid);

-- Suscripción: solo el dueño puede ver la suya; los cambios llegan solo
-- desde funciones de servidor (service role), nunca desde el cliente.
create policy subscriptions_only_owner on public.subscriptions
  for select using (auth.uid() = uid);
