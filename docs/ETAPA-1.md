# Etapa 1 — MVP (completada el 2026-11-23)

## Backend (Supabase, proyecto «onechat»)
- Migración v1 aplicada: políticas RLS completas (perfiles, salas, mensajes,
  favoritos, bloqueos, conversaciones, susurros, notificaciones, reportes,
  juegos), publicación en tiempo real (room_messages, notifications,
  direct_messages) y 5 salas iniciales (general, chile, tecnologia, amistad,
  musica).
- Migración v1.1: GRANT de API a los roles `authenticated`/`anon`
  (las tablas creadas por SQL no los traían; detectado en la prueba real).
- Acceso anónimo (invitados) activado en Authentication.
- Verificación real por API: sesión anónima → perfil → salas → enviar y leer
  mensaje → nickname duplicado rechazado (409). Quedó un usuario invitado de
  prueba «PruebaMuse» con un mensaje en la Sala General (datos de desarrollo).

## App (Flutter)
- Acceso: invitado con nickname único (sesión anónima), crear cuenta e
  iniciar sesión con correo, completar nickname tras confirmar correo.
- Salas: lista de salas públicas, entrar y chatear en tiempo real,
  presencia básica (quién está en la sala), menciones @nickname en rojo
  para el mencionado + aviso en su Status.
- Status: lista de notificaciones con contador de no leídas.
- Perfiles mínimos: ver ficha de usuario, mi perfil con bio y color de
  nickname, favoritos, bloquear/desbloquear y reportar.
- Verificado: `flutter analyze` limpio, prueba de widgets aprobada,
  `flutter build web --release` OK.

## Pendiente para probar en dispositivo
- Publicar la compilación web en un enlace (GitHub Pages desde su repo)
  para que Mario la abra en su iPhone, y primera prueba con dos usuarios.

## Publicación para pruebas (2026-11-23)
- Repositorio público: https://github.com/onechat-support/onechat
  (rama main = código fuente, 114 archivos; rama gh-pages = web del MVP).
- **Enlace para probar en el teléfono: https://onechat-support.github.io/onechat/**
- Publicación vía API de GitHub con el token de Mario guardado en la
  bóveda segura (conector custom.github); Supabase Storage descartado
  para hospedar la web porque sirve el HTML como texto plano.
- Usuario de prueba de Muse renombrado a «PruebaZeth» (regla de Mario:
  las pruebas usan el nombre Zeth).

## Correcciones tras la primera prueba de Mario (2026-11-23)
- Error 1: volver a una sala ya visitada no cargaba mensajes. Causa: el
  upsert de membresía necesitaba permiso de UPDATE (migración v1.2) y la
  app ahora se une de forma idempotente (ignoreDuplicates). Verificado
  por API: unirse 3 veces y leer mensajes, todo OK.
- Error 2: el nickname de invitado quedaba ocupado tras cerrar sesión.
  Ahora la app borra el perfil del invitado al salir, y la función
  `claim_guest_nickname` permite reclamar nicknames de invitados
  inactivos >15 min (v1.2 + ajuste v1.2.1 con coalesce de actividad).
  Verificado por API: reclamo de inactivo OK, reclamo de activo
  rechazado, borrado al salir OK. El perfil huérfano «Zeta» de la
  primera prueba fue eliminado.

## Corrección: mensajes sin autor (2026-11-23)
- Síntoma: al volver a una sala, los mensajes propios salían con «···».
  Causa raíz: eran mensajes de una sesión de invitado anterior; al
  cerrarla, el perfil se borró y la FK dejó sender_uid en NULL.
- Arreglo (v1.3): cada mensaje guarda una foto del nickname del autor
  (sender_nickname); la app lo usa si el perfil ya no existe. Los dos
  mensajes de Mario en la Sala General quedaron restaurados como «Zeta».
- Verificado por API: mensaje de ZethFoto conserva su nombre tras
  borrar el perfil del invitado.

## Optimización de velocidad (2026-11-23)
- Medido: cada consulta al servidor tarda ~0,4–1,2 s (plan gratuito
  «Nano» de Supabase); entrar a una sala encadenaba 4 consultas en
  serie (bloqueos → unión → mensajes → perfiles) = varios segundos.
- Arreglos: historial + perfiles en UNA consulta (join), carga en
  paralelo, unión a la sala sin bloquear, y envío optimista (el
  mensaje se pinta al instante y se confirma al volver del servidor,
  sin duplicados). Restaurados como «Zeta» los 2 mensajes huérfanos
  que quedaban en la sala Chile.
- Lo que no cambia con código: el piso de latencia del plan gratuito
  y la descarga inicial de la web (~10 MB la primera vez; luego queda
  en caché). El salto grande será Supabase Pro (US$25/mes) cuando
  Mario lo decida, y la app nativa en su momento.
