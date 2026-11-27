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
