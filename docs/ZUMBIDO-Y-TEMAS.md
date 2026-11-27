# Zumbidos y temas nostálgicos — ONEchat

Pedidos de Mario, 2026-11-27. En vivo en app **v2026.11.26.12**.

## Zumbido estilo mensajero clásico (migración v1.27, app v.11)

- Un zumbido es una fila de `direct_messages` con `kind='nudge'`
  y `body` null (la v1.27 amplió el check de `kind`). Viaja por
  el mismo tiempo real que los mensajes, se purga con el resto
  del historial privado (3 h / cierre de sesión) y la bandeja de
  Privados lo previsualiza como «🔔 Zumbido».
- Botón con icono de vibración junto al cuadro de texto del
  privado. Al recibirlo: la ventana **se sacude** (animación de
  550 ms), suena `assets/sounds/nudge.wav` (sintetizado, dos
  golpes con trémolo; NO es el audio original protegido) y vibra
  si el perfil lo permite (`sound_enabled` / `vibrate_enabled`).
  Al enviarlo también hay sacudida local, como en el original.
- Espera de 20 s entre zumbidos por conversación (en la app) y
  el límite global anti-spam de 30 mensajes/min lo cubre.
- En la conversación queda la línea centrada «{nick} te envió
  un zumbido» / «Le enviaste un zumbido a {nick}».
- Prueba API: 4/4 (insertar, recibir, purga al salir).

## Interruptor «Recibir zumbidos» (migración v1.28, app v.12)

Pedido expreso de Mario: que se pueda desactivar la recepción.

- `profiles.nudges_open` (default true) + interruptor en
  Perfil → «Privacidad y contacto».
- Guarda en el servidor (`nudge_guard`, BEFORE INSERT): si el
  destinatario los apagó, el insert se rechaza con
  `nudges_closed` (P0001). RPC `can_nudge(p_other)` para el
  pre-chequeo del botón; aviso amable «{nick} desactivó los
  zumbidos». Los mensajes normales no se ven afectados.
- Prueba API: 6/6 (columna, can_nudge abierto/cerrado, bloqueo
  efectivo, mensaje normal pasa, skin guardado).

## Temas visuales nostálgicos (v1.28, app v.12)

- `profiles.skin` ('onechat' | 'mensajero'), selector en
  Perfil → «Tema visual». `appSkin` (theme.dart) manda sobre el
  modo claro/oscuro cuando hay un skin nostálgico;
  `applyProfileTheme` lo lee del perfil y al cerrar sesión
  vuelve a 'onechat'.
- **«Mensajero 2000»** (el primero, elección de Mario): homenaje
  al mensajero clásico con NOMBRE EVOCATIVO PROPIO — nada de
  marcas registradas en la app pública. Celeste (#3D8BC2) y
  blanco, acentos verdes, fondo celeste pálido (#E9F4FB),
  superficies blancas, botones azul profundo.
- Listado propuesto por Muse y aprobado en orden por Mario:
  1) Mensajero 2000 ✅, 2) WhatsApp clásico, 3) Winamp, 4) ICQ,
  5) IRC/mIRC, 6) Windows XP, 7) Yahoo! Messenger, 8) Skype
  clásico, 9) Fotolog/MetroFLOG, 10) BBM. Los demás quedan
  pendientes de su orden, con nombres evocativos equivalentes.
