# Pestañas de salas, limpieza automática y Galería pulida

Pedidos de Mario del 2026-11-26 por la tarde. Publicados en
dos versiones el mismo día: app v2026.11.26.4 (pestañas,
orden alfabético, sala del país, limpieza, ventana flotante)
y v2026.11.26.5 (presencia sin duplicados y Galería).
Migración v1.25 + log-visit v3.

## 1. Pestañas de salas (lib/rooms_host.dart)

- La pestaña principal aloja ahora varias salas abiertas a
  la vez: fila de pestañas arriba y PageView que se recorre
  **deslizando el dedo**. Cada sala abierta queda viva
  (presencia y mensajes corren en todas, con keep-alive).
- General es la primera y **no se puede cerrar**; las demás
  se cierran con la ✕. Máximo **6** abiertas (aviso
  `rooms.maxOpen` si se intenta una séptima).
- Desde la lista de Salas, tocar una sala la abre como
  pestaña (ya no empuja una pantalla encima) y salta a ella.

## 2. Países por orden alfabético

- `fetchRooms`: dentro de cada sección, las salas con país
  se ordenan por nombre de país sin acentos (Argentina,
  Bolivia, Brasil, Chile, Colombia…).
- La lista de países del Perfil (selector «País») también
  quedó alfabética — era la que vio desordenada la tester
  Mkrena.

## 3. Sala del país según la IP (migración v1.25 + log-visit v3)

- `connection_log` gana la columna `country`.
- log-visit resuelve el país de la IP observada por el
  servidor (caché por IP en connection_log; si no hay dato,
  consulta ipapi.co y, en su defecto, ip-api.com, con
  timeout de 2,5 s) y lo devuelve en la respuesta
  `{ok, country}`.
- La app mapea el código ISO al país de la sala (CL→Chile,
  US→Estados Unidos…; España y el resto de Europa →
  Europa) y abre esa sala junto a General **sin cambiar de
  pestaña**. Una sola vez por sesión: si el usuario la
  cierra, no se reabre sola.
- Verificado por API: log-visit responde country (la IP de
  prueba salió «US», como correspondía a su origen).

## 4. Limpieza automática (migración v1.25)

- **pg_cron** dentro de la base: trabajo
  `onechat-purge-messages-3h`, horario `0 */3 * * *` (cada
  3 horas en punto, UTC): borra `room_messages`,
  `direct_messages` y `whispers`. Las conversaciones (la
  lista de privados) quedan, vacías.
- La evidencia de reportes vive copiada en
  `reports_center.evidence` y las señales de Centinel en
  `safety_*`: la limpieza no las toca.
- **Notificaciones**: la app las borra al cerrar la sesión
  (nueva política `notifications_delete_own` + limpieza en
  `signOut()`); al eliminar la cuenta ya caían en cascada
  desde profiles.
- Verificado: columna y trabajo de cron activos; la purga
  se probó dentro de una transacción con rollback.

## 5. YouTube flotante en salas

- La tarjeta del mensaje ya no despliega el reproductor
  dentro de la conversación (eso cortaba el video al llegar
  mensajes, como notó Mkrena): al tocarla se abre
  `FloatingVideoPlayer`, una **ventana flotante** sobre el
  chat que se arrastra desde su barra superior y se cierra
  con la ✕. La conversación no se mueve.
- Aplicado en salas y en privados (el «Cine juntos» no
  cambia: es otra función, compartida).

## 6. Presencia sin duplicados (v.5)

- Presence guardaba una presencia por conexión: salir a la
  web y volver contaba a Mario 3 veces. `joinPresence` ahora
  deduplica por uid: una persona, un ocupante.

## 7. Galería pulida (v.5)

Diagnóstico: el servidor estaba sano (subida completa
probada por API: objeto + fila + URL pública 200), pero la
foto de Mario nunca llegó: **cero filas** en gallery_photos.
La subida moría en su iPhone. Correcciones:

- El selector de archivos ahora se **adjunta al DOM** (en
  Safari/iOS un input suelto puede no disparar el cambio).
- Toda foto se **convierte a JPEG en el navegador** antes
  de subir (canvas, máx. 1600 px, calidad 0,85): adiós al
  HEIC del iPhone que Chrome/Android no muestran, y subidas
  mucho más livianas. Si la conversión falla, sube el
  original.
- Al publicar, la app confirma: «Foto publicada en tu
  Galería».
- **La Galería se ve en el chat**: la ficha de cada usuario
  muestra sus fotos como **carrusel** con contador «1 / 3»
  (las 3 de las cuentas básicas; Premium, todas).

## 8. Reproductor estable y con autoplay (v2026.11.26.6)

Mario reportó que el video flotante se cortaba al mover la
ventana y al tocar fuera de ella. Causa: `youtubePlayer()`
creaba un iframe nuevo en cada reconstrucción de la
pantalla (viewType con contador). Arreglo en fx_web.dart:
el widget se cachea por video (y el de Cine juntos por
sesión+video, que sufría lo mismo con su reloj de 1 s) y
Flutter ya no reemplaza el iframe al redibujar. Además el
embed parte con `autoplay=1` (el toque en la tarjeta es la
orden de reproducir) y la pausa queda solo en los controles
del propio reproductor. Verificado en vivo en ambas rutas.
