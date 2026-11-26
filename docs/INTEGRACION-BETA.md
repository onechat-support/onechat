# Integración de la Beta en el Early (orden de Mario, 2026-11-26)

Mario ordenó integrar AHORA, durante el Early, los 17 cambios de
`docs/CAMBIOS-POST-ALFA.md` que estaban previstos para la Beta,
para probarlos con los testers y evitar sorpresas al anunciarla.
Implementación por lotes, cada uno publicado y verificado en vivo.

## Lote A — Servidor (migración v1.22) · COMPLETO Y VERIFICADO

- **Punto 9 — Enlaces de terceros en salas:** trigger `link_guard`:
  si un mensaje trae un enlace que no es de YouTube (youtube.com y
  subdominios, youtu.be), el mensaje NO se publica, se registra la
  infracción (`link_infractions`) y se aplica silencio en la sala
  con escalera 5 min → 30 min → 2 h → 24 h. Sin baneo automático.
  Staff y dueño global exentos.
- **Punto 10 — Avisos de moderación en Status:** función
  `notify_moderation` crea una notificación por destinatario según
  alcance: dueño/moderadores de la sala solo su sala; Staff y dueño
  global, todo. Fuentes: sanciones humanas (moderate_member),
  silencios automáticos por enlaces y reportes recibidos (trigger
  sobre reports_center; el abuso de poder avisa SOLO al dueño).
- **Punto 11 — Privados cerrables:** `profiles.dm_open` + trigger
  `dm_privacy_guard` (error `dm_closed`); los favoritos DEL
  DESTINATARIO siempre pueden. RPC `can_dm` para la interfaz.
- **Punto 14 — Susurros cerrables:** `profiles.whispers_open` +
  trigger `whisper_privacy_guard` (error `whispers_closed`), misma
  excepción de favoritos. RPC `can_whisper`.
- **Punto 13 — Cambio de nickname:** RPC `change_nickname`
  atómica (validación del registro, reserva sincronizada, freno
  de 7 días con `nickname_changed_at`). Devuelve
  ok/invalid/taken/same/cooldown.
- **Punto 12 (servidor):** códigos de sistema en room_messages
  kind 'system': 'join'/'leave' (con nick, los inserta la app) y
  'mod:mute'/'mod:ban' (sin nick, los inserta el servidor al
  sancionar). Ajuste `profiles.show_system_notices`.
- **Columnas nuevas en profiles:** dm_open, whispers_open,
  show_system_notices, sound_enabled, vibrate_enabled,
  nickname_changed_at (con grant select por columna, patrón v1.20).
- **Hallazgo corregido de paso:** la política de inserción de
  susurros había perdido en v1.18 el respeto al silencio/baneo de
  la sala (puesto en v1.7); v1.22 lo restaura.

Verificación (2026-11-26): batería API 17/17 con invitados Zeth
(YouTube se publica; enlace externo no + silencio 5 min + aviso al
autor + aviso de sala; DM cerrado/favorito; susurro
cerrado/favorito; nick inválido/ocupado/válido/enfriamiento) y
batería SQL 6/6 (escalera: 2ª infracción = 30 min; moderate_member
de Zeeth genera auditoría + aviso Status + aviso en sala; reportes
de usuario y de abuso avisan al dueño). Datos de prueba purgados
(verificación 0/0/0).

## Lote B — App social y visual (v2026.11.26.1)

- **Migración v1.23:** RPC `set_global_role` (solo el dueño;
  no puede tocarse a sí mismo ni a otro dueño; auditoría en
  mod_actions con acción 'global_role').
- **Punto 1 — Mencionar:** botón «Mencionar» en la ficha del
  usuario (inserta @Nick en el texto) + autocompletado al escribir
  @ con sugerencias de la sala.
- **Punto 2 — Panel del dueño:** en Perfil (solo dueño) → «Equipo
  global»: buscar por nickname y poner rol usuario / moderador
  global / Staff, con confirmación.
- **Punto 4 — Iconos por rango:** helper `rankIcons` — sheriff
  (dueño del chat, moderadores y dueño de sala), ⚔️ (Staff),
  manzana (destacado vigente); visibles en mensajes, ocupantes y
  ficha. Punto 3 (destacar por moderadores) ya existía desde la
  Etapa 3; ahora el destacado se nota con la manzana.
- **Punto 7 — Color de nick propio en General:** `didUpdateWidget`
  en ChatPage refresca el perfil propio en la sala montada cuando
  cambia en el Perfil.
- **Punto 12 (app):** avisos del sistema en la sala (se
  conectó / se desconectó con freno de 10 min; silencios y baneos
  sin nick), ocultables con el ajuste del Perfil.
- **Puntos 11/14 (app):** interruptores en Perfil → «Privacidad y
  contacto», y pantalla de Status con el detalle de los avisos de
  moderación y del enlace bloqueado.
- **Punto 13 (app):** «Cambiar mi nickname» en el Perfil, con los
  mensajes del servidor (ocupado, inválido, enfriamiento).

## Lotes C y D — pendientes (ver CAMBIOS-POST-ALFA.md)

C: Copiar (15), YouTube en el chat (8), teclado (5), wakelock (6),
sonidos y vibración (16). D: Cine juntos Premium (17).
