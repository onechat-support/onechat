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

## Registro de cuentas: verificación (2026-11-23)
- «Confirm email» desactivado en Supabase durante la fase de pruebas
  (registro instantáneo; se reactivará antes del lanzamiento público).
- Verificado por API con la cuenta de prueba ZethRegistro: registro
  con sesión inmediata, perfil registrado y reserva de nickname
  creados; un invitado que intenta el mismo nickname recibe 409 y la
  función de reclamo lo rechaza (los registrados nunca se liberan).

## Confirmación de correo: reactivada a pedido de Mario (2026-11-23)
- Mario observó que sin confirmación, un correo mal escrito crea una
  cuenta irrecuperable y quema el nickname elegido. Correcto: se
  reactivó «Confirm email» en Supabase.
- Site URL y Redirect URL de Auth apuntan ahora a la app publicada
  (antes: localhost:3000); el enlace del correo devuelve a ONEchat.
- Flujo resultante: el nickname viaja en los datos de la cuenta al
  registrarse y SOLO se reserva al primer inicio de sesión tras
  confirmar. Una cuenta con correo erróneo jamás reserva el nickname.
- Verificado por API: el registro devuelve usuario SIN sesión, con
  confirmation_sent_at y user_metadata.nickname guardado.

## Errores de auth legibles + reenvío de confirmación (2026-11-23)
- Mario chocó con «email rate limit exceeded» (429) al registrarse:
  el correo integrado de Supabase (plan Free) tiene un cupo por hora
  muy bajo y las pruebas por API lo habían consumido. Su cuenta NO se
  creó (verificado en el panel): el diseño aguantó, nada se quemó.
- La app ya no muestra errores técnicos crudos: friendlyAuthError()
  traduce los casos de auth a lenguaje claro.
- «Iniciar sesión» suma el botón «¿No te llegó la confirmación?
  Reenviar» (auth.resend).
- Pendiente pre-lanzamiento: configurar un servicio de correo real
  (SMTP propio) — el integrado es solo para pruebas.

## Correo propio (SMTP): en configuración (2026-11-23, delegado por Mario)
- Decisión: Brevo (gratuito, 300 correos/día) como SMTP de Supabase
  Auth; el remitente integrado (2/hora) queda reemplazado. Con SMTP
  propio el límite de Supabase parte en 30/hora y se sube a 300/hora.
- Remitente interino: djserver22@gmail.com (nombre «ONEchat»).
  Antes del lanzamiento público conviene un dominio propio como
  remitente (decisión y compra de Mario).
- El plan Pro de Supabase NO cambia el límite de correo: el tope es
  del remitente integrado, no del plan.

## Correo propio (Brevo): CONFIGURADO (2026-11-23)
- Cuenta Brevo Free creada con Google (djserver22@gmail.com),
  organización «ONEchat», dirección de Las Vegas, NV facilitada por
  Mario; teléfono verificado por SMS. Plan Free: 300 correos/día.
- Remitente verificado y predeterminado: «ONEchat»
  <djserver22@gmail.com>. Clave SMTP generada (hay una segunda clave
  sin usar en Brevo: pendiente que Mario decida borrarla).
- Supabase: SMTP personalizado activo (smtp-relay.brevo.com:587) y
  límite de correos subido de 30 a 300/hora.
- Verificación real: dos registros de prueba seguidos (ZethSmtp1 y
  ZethSmtp2) enviaron su confirmación al instante; con el remitente
  integrado habrían chocado con el tope de 2/hora.
- Nota de entregabilidad: el remitente es una dirección Gmail (sin
  dominio propio ni DKIM); para el lanzamiento público conviene un
  dominio propio como remitente.

## Acceso unificado con nickname (2026-11-23, pedido de Mario)
- Mario pidió eliminar el acceso por correo: la pantalla de entrada
  solo pide el nickname. Si es registrado, ahí mismo se habilita la
  contraseña y se entra con nickname + clave; el correo queda solo
  para el registro y la recuperación.
- Piezas: función nickname_status (v1.4) que dice registered/guest/
  free sin exponer correos; Edge Function «login-with-nickname» que
  resuelve el correo internamente (service role) y devuelve la
  sesión; la app ya no tiene pantalla de inicio de sesión por correo
  (la recuperación y el reenvío de confirmación viven en el paso de
  contraseña, pidiendo el correo solo para enviar el mensaje).
- Migración v1.5: grants a service_role (las tablas creadas por SQL
  no lo incluían; sin eso la función recibía «permission denied»).
- Verificado por API: nickname+clave correctos devuelven sesión
  válida; clave mala e invitado, rechazados.

## Recuperación de contraseña funcional (2026-11-23)
- Faltaba la pantalla de cambio de clave: el enlace del correo abría
  el acceso normal. Ahora la app detecta el enlace de recuperación
  al abrirse (y el evento passwordRecovery) y muestra «Nueva
  contraseña» (dos campos, mínimo 8); al guardar cierra la sesión de
  recuperación y se entra con la clave nueva.
- Revisión de código: registro y acceso envían la contraseña tal
  cual, sin recortes; campos de clave sin autocorrección en todas
  las pantallas. La cuenta de Mario («Zeeth») existía y estaba
  confirmada; la clave guardada no coincidía con la escrita.

## Causa raíz del «contraseña incorrecta» (2026-11-23)
- La función login-with-nickname no respondía CORS: el navegador
  bloqueaba la llamada en el preflight (OPTIONS → 405) y la app
  mostraba «Nickname o contraseña incorrectos» aunque la clave
  fuera correcta. Por API directa (curl) funcionaba, por eso las
  pruebas pasaban. El registro de Auth lo confirmó: cero intentos
  con contraseña y un 422 «new password should be different» que
  probaba que la clave de Mario siempre fue la correcta.
- Corregido: la función responde OPTIONS y agrega las cabeceras
  Access-Control-* a todas sus respuestas. Verificado simulando
  un navegador (preflight 200 + POST 200 con sesión; clave mala 401).
- Lección: toda Edge Function invocada desde la app web DEBE
  manejar CORS, y las pruebas de acceso deben hacerse simulando
  el navegador, no solo por API directa.
