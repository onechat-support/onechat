# Auditoría de seguridad de ONEchat — web y app (2026-11-25)

Auditoría defensiva solicitada por el propietario ante el riesgo de
ataques entre operadores de chats similares. Método: 33 controles en
vivo contra el sistema real, actuando como (a) anónimo sin cuenta,
(b) invitado con sesión anónima y (c) usuario registrado normal
(cuentas de prueba Zeth*), más revisión de código, repositorio y
cabeceras del sitio. Los datos de prueba se eliminan al cerrar el
proceso.

## Hallazgo 1 — CRÍTICO: correos de registrados legibles sin cuenta

La tabla `profiles` guarda el correo de los usuarios registrados y su
política de lectura permite a un visitante **sin ninguna sesión**
descargarla completa. Verificado en vivo: la consulta anónima
`profiles?select=nickname,email` devolvió los correos reales, incluido
el del dueño (Zeeth). Es un vector directo de doxxing y suplantación.

**Corrección (migración v1.20, pendiente de aprobación):**
`revoke select (email) on public.profiles from anon, authenticated;`
Verificado que no rompe nada: el ingreso por nickname
(`login-with-nickname`) lee el correo con la clave de servicio en el
servidor; la app solo escribe la columna al registrarse (el permiso de
inserción no se toca); la web pública nunca la solicita.

## Hallazgo 2 — ALTO: sin límite de velocidad de mensajes

Un invitado envió 15 mensajes en ráfaga a la Sala General y los 15
fueron aceptados. Un script puede inundar salas/privados y agotar la
cuota del plan de Supabase, degradando el servicio para todos.

**Corrección (v1.20):** gatillo en el servidor que rechaza el mensaje
si el usuario ya envió 30 en los últimos 60 segundos (sumando salas,
privados y susurros). El uso humano rápido queda muy por debajo; el
flood automatizado se corta. Complementa al Destierro (que castiga
cuentas/dispositivos, no volumen).

## Hallazgo 3 — MENOR: traducción sin sesión

La función Edge `translate` responde con solo la clave pública: un
tercero puede quemar la cuota diaria de MyMemory (10.000 caracteres) y
dejar sin traducción a los usuarios. **Corrección:** exigir un JWT de
sesión válido en la función (la app siempre opera con sesión, incluso
de invitado). Requiere redesplegar la función; se propone junto a
v1.20 o en un paso posterior.

## Verificado correcto (sin acción)

- Tablas sensibles cerradas a anónimos e invitados: `connection_log`
  (IPs), `platform_bans`, `mod_actions`, `reports_center`,
  `safety_alerts/signals/holds/patterns`, `notifications`.
- Identidad: imposible escribir como otro usuario; imposible editar o
  borrar mensajes ajenos; imposible editar perfiles ajenos;
  auto-asignarse `owner` está bloqueado por los gatillos de congelación
  (v1.11); los RPC de moderación, Destierro y revisión de Centinel
  verifican el rol del llamante.
- Salas: un invitado no puede crear salas, renombrarlas ni banear
  editando membresías. Storage: no puede subir a la galería de otro.
- Secretos: la clave `service_role` no está en la app, la web ni el
  repositorio (las funciones Edge la leen del entorno del servidor).
  Sin mapas de código fuente publicados (404). HTTPS forzado.
- Higiene local: `.alpha/session.json` (sesión de PruebaZeth) estaba
  versionado en el repositorio local; el repo no tiene remoto, así que
  nunca salió de esta máquina. Ya se retiró del control de versiones
  y se agregó a `.gitignore`.

## Observaciones (sin urgencia)

- GitHub Pages no permite cabeceras de seguridad personalizadas
  (CSP/HSTS). Riesgo práctico bajo: el sitio es estático y no maneja
  sesiones (viven en la API). Si se desea CSP estricta en el futuro:
  poner Cloudflare delante o migrar el sitio a un hosting que las
  permita.
- Año de nacimiento y género de los perfiles son legibles por
  cualquier sesión (incluida una de invitado recién creada): es el
  comportamiento social por diseño de la ficha pública; se deja
  constancia por si el propietario quiere restringirlo más adelante.
- El plan gratuito de Supabase sigue siendo el techo ante un ataque
  de volumen sostenido; el límite de velocidad reduce el riesgo, y el
  plan Pro (US$25/mes) queda como mitigación futura si aparecen
  ataques reales.

## Estado

Informe entregado al propietario el 2026-11-25 y correcciones
APLICADAS el mismo día con su aprobación («Aplicar todas las
correcciones ahora»), todo verificado en vivo:

- **Migración v1.20** (`supabase/schema_v1_20_seguridad.sql`):
  (a) el correo deja de ser legible por la API. Lección: el permiso
  original era a nivel de TABLA (v1.1), así que un revoke por
  columna no bastó — la primera aplicación no hizo efecto y la
  verificación lo cazó; la forma aplicada revoca el select de
  tabla y lo re-otorga por columnas (las 19 públicas, sin email).
  Consecuencia: pedir perfiles con * ahora falla entero, por lo
  que la app (v2026.11.25.6) pide los perfiles con la lista
  explícita `profileColumns` de services.dart. El registro sigue
  pudiendo GUARDAR el correo (permiso de inserción intacto) y el
  ingreso por nickname no se afectó (lee con clave de servicio).
  (b) límite de velocidad: gatillo de 30 mensajes por 60 segundos
  por usuario sumando salas, privados y susurros; verificado
  (30 pasan, el 31.º se rechaza).
- **Traducción**: la función `translate` ahora exige sesión
  válida (verificado: sin sesión responde 401; con sesión de
  invitado traduce normal).
- **Limpieza**: cuentas y mensajes de la auditoría y de la
  verificación eliminados (0 filas restantes, comprobado).
- **Higiene local**: `.alpha/session.json` y `.alpha/state.json`
  salieron del control de versiones (repo sin remoto; nunca
  salieron de esta máquina) y quedaron en .gitignore.
