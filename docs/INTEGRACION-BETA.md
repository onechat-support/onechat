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

## Lote C — Mensajes y multimedia (v2026.11.26.2) · EN VIVO

Verificado en vivo 2026-11-26: MD5 d62a8ccfefac248dc20e6038e58a2648
en /chat/ y /onechat/, versión 2026.11.26.2 presente y los tres
archivos de sonido responden HTTP 200 en ambas rutas.

- **Punto 15 — Copiar:** el menú de toque largo (salas, susurros y
  privados) suma «Copiar» junto a «Traducir»; aviso «Mensaje
  copiado».
- **Punto 8 — YouTube en el chat:** si un mensaje trae un enlace de
  YouTube, bajo el texto aparece la tarjeta con la miniatura; al
  tocarla se despliega el reproductor oficial (youtube-nocookie)
  dentro de la app, sin autoplay. Toque largo en la tarjeta abre el
  video en YouTube. En salas y en privados.
- **Punto 5 — Teclado:** al abrirse el teclado, la conversación
  sube sola hasta el último mensaje (observador de métricas en
  salas y privados).
- **Punto 6 — Pantalla encendida:** WakeLock API del navegador
  mientras una sala o un privado está abierto; se libera al salir.
  Si el navegador no lo soporta, no hace nada.
- **Punto 16 — Sonidos y vibración:** tres sonidos cortos propios
  (enviar, recibir con freno de 2,5 s, mención en dos tonos) y
  vibración al ser mencionado o recibir un susurro, todo con los
  interruptores `sound_enabled` / `vibrate_enabled` del Perfil
  (sección «Privacidad y contacto»). En web iOS la vibración es
  limitada (límite conocido y avisado en el propio ajuste).
- **De paso (Lote A en la app):** al intentar abrir un privado de
  alguien que los cerró, avisa «tiene los mensajes privados
  cerrados» sin abrir el chat; el error `dm_closed` y el
  `whispers_closed` ya se muestran con su texto amable.

## Lote D — Premium (punto 17) · HECHO Y EN VIVO (app v2026.11.26.3)

- **Migración v1.24**: tabla `cine_sessions` (solo lectura para los
  participantes; sin políticas de escritura) y RPC `cine_invite` /
  `cine_respond` / `cine_control` / `cine_end`, todas security definer.
  Invitar exige Premium (o dueño/Staff global, mientras no existan
  usuarios Premium reales). La invitación llega como aviso
  `cine_invite` en Status y al tocarlo se abre el privado.
- **Sincronización**: el estado compartido vive en la fila (play_state,
  position_sec, updated_at). La posición se estima como posición
  guardada + tiempo transcurrido si está sonando. Cada reproductor es
  el oficial de YouTube (youtube-nocookie, sin autoplay, controles
  propios de la app: play/pausa y ±10 s); cuando el otro pulsa un
  control, mi reproductor salta a la posición compartida y obedece.
- **App**: botón «Cine juntos» en el privado junto al Gato; diálogo
  para pegar el enlace de YouTube; tarjeta de invitación con
  miniatura (aceptar/rechazar); reproductor + controles al aceptar.
- **Verificación**: batería API 7/7 (sin Premium no se puede invitar;
  video inválido rechazado; RLS sin fugas) y camino feliz por SQL
  (invitar → aceptar → control «playing» en el segundo 42,5 → aviso
  recibido), con limpieza total de los datos de prueba.
- **Panel «Early en cifras» actualizado**: las 17 mejoras ya figuran
  como «en prueba en el Early» y los errores resueltos suben a 9/9
  (el pendiente era el color del nick propio, corregido en el Lote B).

Con el Lote D, **la integración de los 17 cambios está completa**:
los cuatro lotes están publicados y verificados en vivo dentro del
Early, que es justo lo que se buscaba: que lo nuevo se rompa aquí,
con los testers, y no el día del anuncio de la Beta.

## Addendum v2026.11.26.13–.14 (2026-11-27)

- **v.13 — Ficha de usuario desplazable**: con la Galería grande
  (v.10) el contenido de la ficha dejó de caber en pantalla y
  los botones quedaban cortados. `showUserSheet` ahora usa
  `isScrollControlled` y el contenido va en un
  `SingleChildScrollView` con tope del 90 % de la pantalla.
- **v.14 — La invitación de Cine aparece EN VIVO**: la
  invitación no genera ningún mensaje, así que si el invitado
  ya estaba dentro del privado no se enteraba hasta salir y
  volver a entrar. `DmChatPage` ahora se suscribe a los cambios
  de `cine_sessions` de la conversación
  (`subscribeConversationCine`) y recarga el área de cine al
  instante. Caso real que lo destapó: invitación de Zeeth a
  YouShookMe (2026-11-27 02:53 PT) creada y notificada sin
  problema, pero cancelada desde la propia cuenta de Zeeth a
  los 90 segundos (botón «Cancelar» de su tarjeta), por lo que
  el invitado nunca llegó a verla.
