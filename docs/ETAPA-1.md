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
