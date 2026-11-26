# ONEchat — Eliminación de cuenta (Google Play)

Requisito de Google Play: el usuario debe poder eliminar su
cuenta y sus datos **desde la app y desde la web**. Construido y
verificado el 2026-11-25 (app v2026.11.25.7), con la aprobación
de Mario dentro del paquete «lo relacionado con Play Store».

## Piezas

- **Migración v1.21** (`supabase/schema_v1_21_eliminar_cuenta.sql`):
  función `purge_user_data(uid)` (security definer). Desvincula
  las referencias sin cascada (salas propias quedan sin dueño;
  los Destierros aplicados se reasignan al dueño; reportes del
  centro quedan sin acusado ni resolvedor), borra los mensajes
  de sala y los susurros del usuario, y elimina el perfil — el
  resto cae en cascada (miembros, favoritos, bloqueos,
  conversaciones y privados, notificaciones, partidas,
  suscripciones, registro de conexiones, filas de Galería y
  reserva de nickname). Las señales de seguridad ya registradas
  quedan desvinculadas (emisor en null), como dicen los
  Términos. Solo el rol de servicio puede ejecutarla
  (`grant execute ... to service_role` explícito: el revoke a
  PUBLIC también quita el acceso heredado del servicio — cazado
  en la verificación).
- **Función Edge `delete-account`**: dos modos. App: JWT del
  usuario + contraseña si la cuenta es registrada (los
  invitados, solo con su sesión). Web: `{nickname, password}`
  sin sesión, verificado contra el correo interno (que la API
  no expone desde la v1.20). Borra los archivos de la Galería
  (bucket `gallery`, carpeta `<uid>/`), ejecuta la purga y
  elimina el usuario de Auth.
- **App**: Perfil → «Eliminar mi cuenta» (al final, en rojo):
  diálogo con la explicación, campo de contraseña en cuentas
  registradas y confirmación; al terminar vuelve a la
  bienvenida. Textos ES/EN en strings.dart (`profile.delete*`).
- **Web**: `web/eliminar-cuenta.html` →
  https://getonechat.com/eliminar-cuenta.html (esta es la URL
  que se declara en Play Console), enlazada desde el pie de la
  portada. Explica el camino por la app y trae el formulario
  web con doble confirmación.

## Verificación (2026-11-25)

- Invitado: borrado con su sesión; perfil y mensajes
  desaparecen; sin sesión ni credenciales la función rechaza.
- Registrado (modo web): contraseña incorrecta → 401 y la
  cuenta queda intacta; borrado correcto → no puede volver a
  ingresar, perfil y mensajes eliminados, archivo de su foto
  de Galería eliminado del almacenamiento.
- Cuentas de prueba (ZethBorrarInv, ZethBorrarInv2, ZethBorrar)
  eliminadas por el propio flujo; limpieza comprobada en 0.
