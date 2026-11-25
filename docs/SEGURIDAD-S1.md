# ONEchat — Fase S1 antitóxicos: el Destierro (implementada)

**Fecha:** 24 de noviembre de 2026 · **Versión de la app:**
v2026.11.24.11 · **Migración:** v1.15
(`supabase/schema_v1_15_destierro.sql`) · **Plan:**
`docs/PLAN-SEGURIDAD-ANTITOXICOS.md` (aprobado por Mario;
duraciones y reglas tal como se propusieron).

## Qué quedó funcionando

- **Identidad de dispositivo** (`lib/device_identity*.dart`):
  al entrar, la app genera un identificador de dispositivo
  que guarda en localStorage **y** en una cookie (borrar
  uno solo no basta), más una **huella** calculada con
  señales del navegador/equipo (agente, pantalla, idioma,
  zona horaria, núcleos, lienzo gráfico). Ambos viajan a la
  función `log-visit`, que los guarda en `connection_log`
  junto a la IP observada por el servidor.
- **La puerta de entrada:** `log-visit` (v2) registra la
  visita y verifica el Destierro (cuenta, dispositivo — id
  o huella — e IP). La app lo consulta en dos caminos:
  `SessionGate` (sesión restaurada) y `HomePage` (entrada
  fresca desde la bienvenida; agregado en la .11 tras
  detectar que ese camino no pasaba por la puerta). Si hay
  destierro vigente → **pantalla «Acceso revocado»** con la
  fecha de término (o permanente) y el correo de apelación,
  sin revelar qué capa detectó el bloqueo.
- **Tabla `platform_bans`:** una fila por capa (account /
  device / ip), con motivo obligatorio, quién lo aplicó,
  vencimiento y levantamiento. Lectura solo Staff/dueño
  (RLS). Sin políticas de escritura: todo pasa por las
  funciones del servidor.
- **`apply_platform_ban(target, hours, reason)`:** solo
  Staff/dueño; permanente (hours null) **solo el dueño**;
  bloquea en una llamada la cuenta + el dispositivo (id y
  huella) + la IP de la última conexión del objetivo.
  **`lift_platform_ban(id)`:** los permanentes solo los
  levanta el dueño.
- **Cierre al escribir:** las políticas de inserción de
  salas, privados y susurros suman `not account_banned()`:
  una cuenta desterrada con la sesión abierta tampoco puede
  escribir (403).
- **En la app:** la ficha de usuario, para Staff/dueño,
  muestra la sección «Destierro (toda la plataforma)»:
  destierros vigentes con botón «Levantar» y el diálogo
  «Desterrar» (24 h / 7 días / 30 días / permanente solo
  dueño; motivo obligatorio; aviso de las tres capas).

## Verificación (24-11-2026)

- **12/12 controles de API** jugando al tóxico
  (`ZethToxico`, con `ZethRegistro` como Staff temporal,
  rol restaurado al terminar): entrada normal; escribe;
  destierro de 24 h = **4 capas**; entrada bloqueada; no
  puede escribir (403); **cuenta nueva + mismo dispositivo
  = bloqueada**; levantada solo la IP, **el dispositivo
  solo sigue bloqueando**; equipo nuevo + cuenta nueva =
  entra (límite honesto); Staff no puede aplicar permanente
  (`permanent_only_owner`); un usuario común no puede
  desterrar (`not_staff`); levantado todo, vuelve a entrar.
- **Prueba visual en la app real** (perfil de navegador
  nuevo, invitado `ZethPuerta2`, v.11): destierro aplicado
  → al recargar, pantalla «Acceso revocado … hasta el
  25-11-2026» con el logo y el correo de apelación;
  reaplicado con su conexión ya registrada = **4 capas**
  contra su dispositivo real (`dev-…` + huella `fp…`);
  sigue revocado; levantadas las 4 capas, vuelve a entrar.
- Analizador sin problemas; prueba de humo OK; MD5 del
  `main.dart.js` en vivo idéntico al compilado (.11).

## Límites (los del plan, confirmados en la práctica)

- Equipo nuevo + cuenta nueva + red distinta = entra. El
  Destierro encarece la vuelta; no la hace imposible.
- La puerta es «fail-open» ante fallas de red (si la
  función no responde, la app deja pasar y reintenta en la
  próxima apertura): se privilegió no dejar fuera a la
  comunidad sana por un corte de red.
- El identificador vive en el navegador: un usuario técnico
  que borre **todos** los almacenes y cambie su huella
  (otro navegador/equipo) genera una identidad nueva. Las
  fases S2 (cuentas hermanas visibles, límite de invitados
  por dispositivo) y S3 (anti-doxxing) siguen en el plan.
