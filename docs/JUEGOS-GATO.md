# Juegos en privados: Gato 1 vs 1 (adelanto de la Etapa 6)

Pedido expreso de Mario (2026-11-24) durante el acceso
anticipado: implementar ya el Gato 1 vs 1 en los mensajes
privados para que los testers lo prueben. El resto de la
Etapa 6 (Premium y más juegos) sigue en su fase.

## Cómo funciona

- En la conversación privada hay un botón «Jugar al Gato».
  La invitación le llega al otro como tarjeta en la misma
  conversación (Aceptar / Rechazar) y como aviso en su Status.
- Quien invita es X y parte jugando. El tablero vive sobre el
  campo de texto de la conversación y se actualiza en vivo
  (tabla games en tiempo real).
- Rendirse, revancha al terminar y cerrar la tarjeta incluidos.

## Servidor (migración v1.12)

Todo el flujo pasa por funciones security definer que validan
en el servidor; la app solo dibuja el estado:

- `game_invite(p_other, p_type)`: crea la partida (o devuelve
  la vigente entre ambos) y deja el aviso `game_invite`.
- `game_respond(p_game, p_accept)`: solo el invitado acepta;
  invitado o invitante pueden rechazar/cancelar.
- `game_move(p_game, p_cell)`: exige partida activa, turno del
  que juega y celda libre; escribe el tablero, registra el
  movimiento en `game_moves`, detecta línea ganadora o empate
  y cierra la partida con `winner_uid`.
- `game_resign(p_game)`: el que se rinde pierde.

Verificación por API (13 controles): invitación y aviso,
no jugar antes de aceptar, turno respetado, celda ocupada
rechazada, victoria por fila con ganador correcto, historial
de movimientos, revancha y rechazo.

Las tablas `games`/`game_moves` ya soportan los demás juegos
del roadmap (conecta4, damas, ludo, ajedrez) con el mismo
patrón de funciones.
