# ONEchat — Centro de reportes y código de conducta del poder

**Fecha:** 24 de noviembre de 2026 · **Pedido de Mario:**
un botón de reporte para los usuarios con tres caminos
—reportar error, reportar usuario y reportar abuso de
poder— que **capture la evidencia**; y un plan de
conducta para los usuarios con poder, con advertencias y
castigos por abuso. **Estado:** propuesta para validar
en conjunto con Mario antes de construir.

## 1. El botón de reporte

Un solo botón, visible siempre: en la cabecera de cada
sala y en el Perfil («Reportar»). Al tocarlo se despliegan
tres opciones:

1. **Reportar un error** — algo de la app no funciona.
   Formulario breve: qué pasó y dónde (sala/pantalla).
2. **Reportar a un usuario** — acoso, spam, suplantación,
   contenido indebido. Se elige al usuario (o se llega
   desde su ficha, como el «Reportar» actual) y la sala.
3. **Reportar abuso de poder** — un moderador, dueño de
   sala, miembro del Staff o el propio sistema de
   sanciones usado contra alguien por motivos personales,
   sin motivo, o con exceso. Se elige al usuario con poder
   y se describe el hecho.

## 2. La captura de evidencia (automática, del servidor)

Pedido de Mario: que el botón «tome captura». Mi juicio
técnico: **la captura más eficiente y más justa no es una
foto de pantalla, es la evidencia del servidor**, porque
ya existe, no se puede recortar ni falsificar, y el
usuario no tiene que probar nada:

- Al reportar a un usuario en una sala, el sistema adjunta
  solo los **últimos 30 mensajes de esa sala** (con hora y
  autor) y marca el mensaje reportado si se eligió uno.
- Al reportar **abuso de poder**, el sistema adjunta las
  **últimas 20 acciones de moderación del acusado**
  (silencios, baneos, expulsiones, destacados) con sus
  motivos declarados, tomadas del registro de auditoría
  que la plataforma ya guarda desde la Etapa 3.
- Todo reporte guarda además: quién reporta, cuándo, en
  qué sala, y la versión de la app.
- **Extra opcional:** el que reporta puede adjuntar una
  imagen de su equipo si ya tiene una captura propia.

La evidencia queda guardada con el reporte y **solo la
ven quienes deben juzgarlo** (ver §3). Nunca es pública.

## 3. Quién ve cada reporte (la regla de oro)

- **Errores:** el dueño global y el Staff.
- **Usuarios:** los moderadores y el dueño de la sala
  donde ocurrió, y el Staff/dueño global (como hoy).
- **Abuso de poder: SOLO el dueño global (Mario).** Ni el
  Staff ni ningún moderador ven estos reportes — nadie
  juzga a su propio equipo ni a sí mismo. Si el acusado
  es del Staff, lo resuelve Mario en persona.

Cada reporte tiene estado: **Nuevo → En revisión →
Resuelto / Desestimado**, con una nota de cierre. El
Centro de reportes vive en la pestaña Status de quienes
tienen poder (con el alcance de arriba) y en una sección
propia del dueño con los tres tipos.

## 4. Código de conducta para usuarios con poder

*Aplica a moderadores de sala, dueños de sala, Staff y
moderadores globales. Aceptarlo es condición para
recibir y conservar cualquier rol.*

### Principios

1. **El poder es un servicio, no un privilegio.** Sirve
   para cuidar la sala y a la comunidad, jamás para
   beneficio, venganza o lucimiento personal.
2. **Toda sanción lleva motivo real y queda registrada.**
   Si no hay motivo que se pueda escribir, no hay sanción.
3. **Proporcionalidad:** la menor sanción que resuelva el
   problema. Primero advertir; el castigo máximo es el
   último recurso, no el primero.
4. **Nada personal:** prohibido sancionar por discusiones,
   celos, rivalidades o asuntos privados. Quien sea parte
   de un conflicto **no lo modera**: lo deriva al Staff o
   al dueño de la sala.
5. **Respeto a la privacidad:** los datos que el poder
   permite ver (IP, registro de conexiones, reportes) se
   usan solo para moderar. Publicarlos, compartirlos o
   usarlos fuera de la plataforma es la falta más grave.
6. **Sin favoritismos:** las normas se aplican igual a
   amigos, favoritos y conocidos que a desconocidos.
7. **Ejemplo público:** quien tiene poder se comunica con
   respeto en las salas; su conducta es la vidriera de la
   comunidad.

### Faltas típicas (ejemplos, no lista cerrada)

Silenciar o banear sin motivo o por motivos personales;
amenazar con el rol («te baneo si…»); sancionar fuera de
la propia sala; filtrar datos privados (doxxing);
proteger a infractores por amistad; usar el destacado o
los avisos del sistema para fines personales; ignorar
sistemáticamente los reportes de su sala.

## 5. Escalera de castigos por abuso de poder

Aplicada por el dueño global (y, para faltas de sala, por
el dueño de sala con aviso al Staff). Cada paso queda en
el registro de auditoría y la persona puede **apelar ante
el dueño** con la evidencia del caso.

1. **Llamado de atención privado** — conversación y
   explicación de la norma (primera falta leve).
2. **Advertencia formal registrada** — queda en su ficha
   interna; la próxima falta sube de nivel.
3. **Suspensión del rol por 7 a 30 días** — conserva su
   cuenta de usuario común, sin poderes.
4. **Retiro definitivo del rol** — no vuelve a ejercer
   poder en la plataforma.
5. **Destierro** (solo faltas gravísimas: doxxing, acoso
   desde el poder, extorsión) — la sanción suprema de la
   Fase S1, aplicada por el dueño.

**Regla de oro del sistema:** el que abusa del poder
pierde el poder. Y como toda acción de moderación ya
queda auditada, ningún abuso queda «sin testigos».

## 6. Construcción (al validar Mario)

- Migración v1.17: tabla `reports_center` (tipo, autor,
  acusado, sala, descripción, evidencia adjunta en JSON,
  estado, nota de cierre) con RLS por alcance del §3;
  los reportes de abuso solo legibles por el dueño.
- App: botón «Reportar» en salas y Perfil con las tres
  opciones y sus formularios; captura de evidencia al
  enviar (función del servidor); Centro de reportes en
  Status para Staff/dueño y moderadores de sala (su
  alcance); pantalla del dueño con los reportes de abuso.
- El texto del Código (§4) se muestra al otorgar un rol
  (la persona lo acepta con un toque) y queda enlazado en
  el Centro de reportes.
- Costo: US$0. Tiempo estimado: una sesión de trabajo,
  como las fases anteriores.

## 7. Para validar con Mario

1. ¿La escalera de castigos (§5) tiene el tono justo?
2. ¿Los reportes de abuso los ve solo el dueño, o también
   un Staff de máxima confianza si algún día lo nombras?
3. ¿La evidencia automática (30 mensajes / 20 acciones)
   alcanza, o quieres más contexto?
4. ¿El botón va en la cabecera de cada sala y en el
   Perfil, o también en la ficha de cada usuario?
