# Privados efímeros al salir + récord vs en juegos — v1.26 / app v2026.11.26.9

Pedido de Mario, 2026-11-27. Publicado y verificado el 2026-11-27.

## 1) Al cerrar sesión se borra el historial de privados

Motivo (Mario): la lista de personas con quienes se tuvo privados y
su contenido «no sirve más que para que los usuarios tengan
problemas» (p. ej. con sus parejas). Los privados son efímeros por
diseño: la purga automática de 3 horas (v1.25) ya los borraba; ahora
además se borran en el momento de cerrar sesión.

- Migración v1.26: función `clear_my_private_history()`
  (security definer) que borra las filas de `conversations` del
  usuario; en cascada caen `direct_messages` y `cine_sessions`.
  La conversación desaparece para ambos (igual que con la purga).
- App: `OnechatService.signOut()` la invoca (best-effort) junto al
  borrado de notificaciones que ya existía desde v2026.11.26.4.
- Los juegos NO cuelgan de la conversación (games referencia a los
  jugadores), y el récord vs vive en su propia tabla: sobrevive.

## 2) Récord vs por pareja de jugadores

- Tabla `game_records` (user_a < user_b, a_wins, b_wins, draws),
  RLS: cada jugador solo lee sus propias filas.
- Trigger `games_record_result` (AFTER UPDATE en games): cuando una
  partida pasa a `finished` suma victoria/derrota/empate según
  `winner_uid` (null = empate). Cubre `game_move` y `game_resign`.
- Backfill inicial con las partidas ya terminadas: 3 filas.
- App: `gameRecordVs()` en services; en el privado, al terminar una
  partida la tarjeta muestra «Vs {nick} · Tú X — Y · Empates Z»
  (strings `game.vsScore` ES/EN), y la misma línea aparece junto al
  botón «Jugar al Gato» cuando ya hay historial con esa persona.

## Verificación

Batería API 14/14 (2026-11-27): login ZethRegistro + invitado nuevo
ZethVs*, partida completa ganada por A → récord creado con la
victoria correcta; conversación + mensaje creados →
`clear_my_private_history` → conversaciones 0, mensajes 0 en
cascada, récord intacto; limpieza final por cascada al borrar el
perfil de prueba.

## Extra en la misma versión de app (v2026.11.26.9)

Enlaces de YouTube sin previsualización (pedido de Mario,
2026-11-27): fuera la tarjeta con miniatura; el mensaje muestra una
línea azul «YouTube - <título>» (título vía oEmbed oficial,
cacheado por sesión) que abre la ventana flotante. La URL larga se
retira del texto visible del mensaje. Aplica en salas y privados.
Componente: `YoutubeTitleLink` en youtube_card.dart (reemplaza a
`YoutubeCard`); título vía `fetchYoutubeTitle` en fx_web.dart.

## Addendum v2026.11.26.10 (2026-11-27)

- Mario reportó que su lista de Privados seguía mostrando personas:
  su cuenta Zeeth tenía 2 conversaciones en el servidor (la sesión
  anterior se cerró sin pasar por el signOut de la .9). Se borraron
  por SQL (verificado: 0) y, como blindaje, `signOut()` dejó de ser
  el único punto de limpieza: `signIn()` y `loginWithNickname()`
  también invocan `clear_my_private_history()` al entrar. Aunque la
  sesión anterior se cierre con una versión antigua o cerrando la
  pestaña, la lista amanece vacía al volver a entrar.
- Galería en el perfil (pedido de Mario): en la pestaña Perfil la
  Galería se movió entre el nick y la barra de colores — carrusel
  a ancho completo (300 px), deslizable con el dedo, contador y
  borrado de la foto actual; se eliminaron las miniaturas de la
  sección «Mi página web». En la ficha de usuario del chat, la
  galería subió justo bajo el nick (antes de la bio) y el carrusel
  creció de 230 a 300 px.
