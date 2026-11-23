# ONEchat — Arquitectura v0 (Etapa 0)

Fecha: 2026-11-22 · Estado: fundación aprobada por el propietario

## 1. Decisiones

| Tema | Decisión | Motivo |
|---|---|---|
| Cliente | Flutter en código (Dart), sin FlutterFlow | Una base para Android/iOS/web; el editor visual es un techo para presencia, juegos y privacidad fina |
| Backend | Supabase (PostgreSQL) | Tiempo real y presencia integrados, seguridad a nivel de filas (RLS), costo predecible (Pro US$25/mes), código abierto y autoalojable |
| Alternativa evaluada | Firebase | Ecosistema de chat probado y push gratuito, pero costo por uso (lecturas) difícil de predecir en un chat y dependencia total de Google |
| Repositorio | Git desde el día 1, a nombre del propietario | El activo es del propietario; cualquier desarrollador o agente puede retomar con la documentación |

## 2. Identidad (resuelto desde la arquitectura, no como parche)

- Cada persona tiene un `uid` interno estable (Supabase Auth, incluye acceso anónimo para invitados).
- El invitado entra solo con nickname. Si luego crea cuenta, **conserva el mismo uid**, nickname y perfil (vinculación de credenciales sobre la misma identidad).
- Nickname registrado: único sin distinguir mayúsculas (`Mario` = `mario`). La unicidad la garantiza la base de datos (índice único sobre `nickname_lower` + tabla de reservas), no el cliente.
- Si un nickname está registrado, nadie puede usarlo como invitado: el backend lo rechaza y pide iniciar sesión. Sin suplantación.

## 3. Modelo de datos (v0, en `supabase/schema.sql`)

- `profiles` — un registro por uid: nickname, color, bio, rol global, idioma, país, datos opcionales, contadores.
- `nickname_reservations` — reserva atómica de nicknames registrados.
- `rooms` — salas regionales, temáticas, públicas, privadas y temporales; dueño y configuración.
- `room_members` — membresía y rol dentro de la sala (dueño, moderador, miembro, destacado).
- `room_messages` — mensajes públicos de sala (con tipo: normal, sistema; y marcas de mención).
- `conversations` / `direct_messages` — privados 1:1, legibles solo por sus dos participantes (RLS).
- `whispers` — susurros dentro de sala: filas legibles solo por emisor y destinatario (RLS), no un truco visual.
- `favorites`, `blocks` — relaciones sociales; el bloqueo se aplica en servidor: el bloqueado no puede enviar privados ni susurros al bloqueador, y sus mensajes públicos se filtran.
- `notifications` — el contenido de la Sala Status: menciones, susurros, privados, avisos de moderación y de favoritos.
- `reports`, `mod_actions` — reportes y auditoría de moderación.
- `games` / `game_moves` — partidas VS con movimientos validados en servidor (desde el modelo, aunque la UI llegue en su etapa).
- `subscriptions` — estado Premium verificado en backend (nunca flags locales).

La presencia (quién está conectado, en qué sala, online/ausente) usa los canales de presencia de Supabase Realtime; no se simula con lecturas de base de datos.

## 4. Seguridad

- Row Level Security activo en todas las tablas: cada quien lee y escribe solo lo que le corresponde.
- Operaciones sensibles (reservar nickname, moderar, validar movimientos de juego, verificar Premium, traducir) en Edge Functions con la clave de servicio solo en backend.
- Límites anti-spam en servidor (frecuencia de mensajes por usuario/sala) desde el MVP.
- Entornos separados: desarrollo y producción, con respaldos antes de cada cambio de esquema.

## 5. Internacionalización

- Interfaz ES/EN desde el inicio (archivos de mensajes, sin textos quemados en pantallas).
- La traducción automática de mensajes será un servicio enchufable vía Edge Function (proveedor por definir), con el original siempre disponible. No forma parte del MVP.

## 6. Roadmap (del Documento Maestro, adaptado)

- **Etapa 0 — Fundación:** repositorio, proyecto Flutter, proyecto Supabase, tema visual, pantalla de acceso. ← *actual*
- **Etapa 1 — MVP:** acceso (invitado/cuenta), salas, chat público en tiempo real, presencia básica, Status, perfiles mínimos, bloqueo y reportes.
- **Etapa 2 — Social avanzado:** menciones, favoritos, susurros, privados completos, notificaciones.
- **Etapa 3 — Moderación completa:** roles de sala, silencios, baneos, auditoría.
- **Etapa 4 — Temas y personalización.**
- **Etapa 5 — Traducción.**
- **Etapa 6 — Premium y juegos** (Gato primero), comunidad/retención e internacionalización avanzada.

## 7. Costos de operación estimados

- Desarrollo y pruebas internas: US$0 (capas gratuitas).
- Lanzamiento: Supabase Pro US$25/mes (500 conexiones en tiempo real incluidas, escala por tramos).
- Cuentas de tienda, cuando llegue publicación: Google Play US$25 una vez; Apple US$99/año. Solo con aprobación del propietario.
