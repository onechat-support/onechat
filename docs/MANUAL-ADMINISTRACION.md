# ONEchat — Manual de administración de la plataforma

**Propietario:** Mario Valdes (cuenta «Zeeth», dueño global)
**Versión del manual:** 1.0 — 24 de noviembre de 2026
**Versión de la app:** v2026.11.24.6 (acceso anticipado, estado alfa)
**App en vivo:** https://onechat-support.github.io/onechat/

Este manual reúne todo lo necesario para administrar ONEchat
sin depender de memoria ni de terceros: cuentas, roles,
moderación, salas, operación diaria, publicación de versiones,
base de datos, costos, seguridad y solución de problemas.
Las contraseñas NO están en este documento: viven en el
gestor seguro de Mario. Aquí solo se indica qué cuenta es
dueña de cada servicio.

---

## 1. Qué es ONEchat y en qué estado está

ONEchat es una app social de chat por salas, en el espíritu
de los chats clásicos (MSN / IRC / LatinChat) con estándar
moderno: salas públicas por región y tema, mensajes privados
1:1, susurros dentro de la sala, presencia en vivo, perfiles,
favoritos, moderación completa y juegos en los privados.

Estado al 24-11-2026: **acceso anticipado (alfa)** abierto a
un grupo pequeño de testers. Etapas 0 a 5 completadas y
publicadas; el Gato 1 vs 1 se adelantó desde la Etapa 6 a
pedido del propietario. La Etapa 6 completa (Premium y más
juegos) sigue en su fase, a la espera de la orden de Mario.

## 2. Cuentas y accesos (quién es dueño de qué)

| Servicio | Cuenta / identificador | Para qué sirve |
|---|---|---|
| App pública | https://onechat-support.github.io/onechat/ | La app que usan los testers |
| GitHub | Usuario «onechat-support» — repo github.com/onechat-support/onechat | Código fuente (rama main) y publicación web (rama gh-pages) |
| Supabase | Organización «ONEchat», proyecto «onechat», ref jsdyoqmgdkqlkucebjmt, región us-east-1 | Base de datos, autenticación, tiempo real y funciones |
| Supabase (panel) | https://supabase.com/dashboard/project/jsdyoqmgdkqlkucebjmt | Administración: SQL, usuarios, registros |
| Brevo | Cuenta gratuita, organización «ONEchat», ingreso con djserver22@gmail.com | Envío de correos (confirmación y recuperación) |
| Correo del proyecto | onechat.support@gmail.com | Correo oficial de soporte y registros del proyecto |
| DeepL | Cuenta creada con djserver22@gmail.com (sin plan activo) | Traducción futura (ver §14) |

Reglas de oro de acceso:

- La cuenta **«Zeeth»** (correo m.valdesur@gmail.com) es el
  **dueño global** de la plataforma dentro de la app.
- El ingreso a GitHub y Supabase se hace con la cuenta
  «onechat-support». Si un día se cambia la contraseña, hay
  que actualizarla en el gestor seguro, no en documentos.
- La **clave secreta de Supabase (service_role) nunca** debe
  salir del panel de Supabase: no va en la app, ni en correos,
  ni en este manual. La app solo usa la clave «publishable»,
  que es pública por diseño (la seguridad la impone la base
  de datos, no el secreto de esa clave).

## 3. Arquitectura en breve

- **Cliente:** app Flutter en código (Dart), una sola base
  para web, Android e iOS. Hoy se usa la versión web.
- **Backend:** Supabase (PostgreSQL): autenticación, datos
  con seguridad a nivel de filas (RLS), tiempo real
  (mensajes, presencia, partidas) y funciones de servidor
  para todo lo sensible (moderación, juegos, acceso).
- **Publicación:** GitHub Pages sirve la versión web desde
  la rama gh-pages del repositorio.
- **Correo:** Brevo (SMTP) conectado a Supabase Auth.
- **Traducción de mensajes:** función «translate» de
  Supabase con el servicio MyMemory (ver §14).

Identidad visual oficial: turquesa #00C2A8 (principal),
azul #4F8CFF (secundario), fondo oscuro #121212. Colores de
rol y aviso: mención #FF5252, susurro #B388FF, favorito
#FF6B6B, moderador #FFB74D, dueño de sala #FFD54F,
Staff #00E5C4.

## 4. Usuarios y formas de entrar

- **Invitado:** entra solo con un nickname libre. No necesita
  correo ni contraseña. Su identidad es persistente en ese
  navegador.
- **Registrado:** crea su cuenta con nickname, correo y
  contraseña. El correo solo se usa para registrarse y para
  recuperar la contraseña; **el ingreso es por nickname**:
  en la pantalla de bienvenida se escribe el nickname y, si
  está registrado, aparece ahí mismo el campo de contraseña.
  El correo nunca se muestra dentro de la app.
- **Reserva de nickname:** un nickname registrado queda
  reservado (sin distinguir mayúsculas): nadie puede usarlo
  como invitado ni registrarlo de nuevo. La unicidad la
  garantiza la base de datos.
- **Recuperación de contraseña:** desde la misma pantalla,
  con el correo de registro; el enlace abre la pantalla
  «Nueva contraseña» de la app (escribirla dos veces).
- **Perfil:** cada usuario puede editar su bio, color de
  nickname, foto de presencia/estado, país, tema
  (Sistema/Oscuro/Claro) e idioma (ES/EN). Todo se guarda en
  su cuenta y se aplica en vivo.

## 5. Roles y poderes

| Rol | Alcance | Puede |
|---|---|---|
| Dueño global («Zeeth») | Toda la plataforma | Todo lo del Staff, nombrar moderadores en salas sin dueño (General y Ayuda), y es la máxima autoridad |
| Staff | Global | Moderar en cualquier sala, atender la sala Ayuda con el HUD de Staff, nombrar moderadores en salas sin dueño |
| Dueño de sala | Su sala | Nombrar y quitar moderadores de su sala, silenciar, banear, expulsar y destacar en ella |
| Moderador de sala | Las salas donde fue nombrado | Silenciar, banear, expulsar y destacar en esas salas |
| Destacado | Visual | Distinción visual por 7 días; sin poderes de moderación |
| Usuario | — | Chatear, susurrar, privados, favoritos, bloquear, reportar |

Notas de administración de roles:

- El dueño de una sala nombra moderadores desde la propia
  sala (ficha del usuario). La persona debe haber entrado al
  menos una vez a esa sala, porque el rol se asigna sobre su
  membresía.
- Los moderadores NO pueden nombrar a otros moderadores ni
  tocar al dueño de la sala.
- En las salas sin dueño individual (General y Ayuda), solo
  el dueño global y el Staff nombran moderadores.
- Los **roles globales** (Staff) hoy se asignan solo por
  base de datos (panel de Supabase), no desde la app; el
  panel en la app quedó anotado en la lista post-alfa.
- **Iconos por rango** (definidos por Mario): destacado =
  manzana; moderador y dueño de sala = placa de sheriff;
  Staff = espadas (⚔️ como emoji); dueño del chat = por
  ahora, el mismo del moderador. Se muestran junto al
  nickname con el color del rol. (Implementación visual en
  la lista post-alfa.)

## 6. Las salas (30)

Estructura vigente, agrupada en la app por secciones:

- **General** — categoría propia, sin dueño, primera
  pestaña: la app entra directamente conversando aquí.
- **Plataforma** — Ayuda (sin dueño, atendida por el Staff).
- **Latino** — 20 salas, una por país (incluye Chile).
- **Norteamérica** — Estados Unidos y Canadá.
- **Europa** — una sala continental.
- **Temáticos** — Amistad, Encuentros, Debates, Pasiones y
  Hot (+18).

Todas las salas con dueño están a nombre de «Zeeth» como
dueño inicial. Las pestañas de la app son: **General ·
Salas · Privados · Status · Perfil**.

## 7. Moderación en el día a día

Todo lo sensible lo ejecuta el **servidor** (funciones que
verifican el rol de quien sanciona y dejan registro en la
auditoría); la app solo muestra botones. Nadie puede
auto-quitarse una sanción editando sus datos: desde la
migración v1.11, la base congela los campos de rol y sanción
cuando el propio usuario intenta tocarlos.

Desde la ficha de un usuario dentro de la sala (tocar su
nickname), quien tenga poder puede:

- **Silenciar:** 10 minutos, 1 hora o 24 horas. El
  silenciado no puede escribir ni susurrar (el servidor
  rechaza sus mensajes) y ve el aviso de su sanción.
- **Banear:** el baneado no entra a la sala y ve la pantalla
  de baneo.
- **Expulsar:** lo saca de la sala en el momento.
- **Destacar:** distinción visual por 7 días.

Panel de moderación de la sala: lista de sanciones vigentes
y registro de acciones (quién sancionó, a quién, qué y
cuándo), visible para dueño y moderadores de esa sala.

**Sala Ayuda y HUD del Staff:** los miembros del Staff y el
dueño global ven un icono de soporte (en la barra principal
y dentro de General) con el número de mensajes sin atender
en Ayuda. Al entrar, quedan marcados como leídos. Los
usuarios comunes no ven este icono.

**Reportes y bloqueos de usuarios:** cualquier usuario puede
reportar un mensaje o un perfil, y bloquear a otra persona
(el bloqueado no puede escribirle privados ni susurros, y
sus mensajes se le ocultan). Los reportes llegan al equipo
para su revisión.

## 8. Status y notificaciones

La pestaña **Status** reúne los avisos de cada usuario. Los
avisos nuevos dicen **quién, qué y dónde**, con icono propio,
y **al tocarlos llevan a la actividad**:

- «X te envió un mensaje privado» → abre esa conversación.
- «X te invitó a jugar al Gato» → abre la conversación con
  la tarjeta de la partida.
- «X te mencionó en (sala)» / «X te susurró en (sala)» →
  abre esa sala.
- Avisos de favoritos y de moderación, con su etiqueta.

Los contadores de **Privados** y **Status** en la barra
principal se actualizan **en vivo**: no hay que entrar a la
pestaña para enterarse. Los avisos antiguos (anteriores al
24-11-2026) pueden mostrar la etiqueta genérica, porque en
su momento no registraban el nombre de quien los generó.

## 9. Mensajes privados y susurros

- **Privados 1:1:** pestaña Privados con la lista de
  conversaciones (último mensaje, no leídos), chat en vivo y
  marcado de leídos solo por el destinatario. La
  conversación es legible únicamente por sus dos
  participantes (regla de la base de datos, no solo visual).
- **Susurros:** dentro de una sala, mensaje visible solo
  para emisor y destinatario (se muestra en morado). Misma
  garantía de servidor: nadie más puede leerlos, ni con
  trucos de cliente.
- **Menciones:** escribir @Nickname avisa a esa persona en
  su Status. (El botón «Mencionar» en la ficha y el
  autocompletado están en la lista post-alfa.)
- **Traducción:** mantener presionado un mensaje (sala,
  susurro o privado) y tocar «Traducir» lo traduce al idioma
  del perfil.

## 10. Juegos en privados: Gato 1 vs 1

- Dentro de cualquier conversación privada, el botón
  **«Jugar al Gato»** envía la invitación: llega como tarjeta
  en la misma conversación (botones **Aceptar / Rechazar**) y
  como aviso en el Status del invitado.
- Quien invita es **X** y parte jugando; el invitado es O.
- El tablero vive sobre el campo de texto y se actualiza en
  vivo para ambos. Botones: **Rendirse** durante la partida;
  al terminar, **Revancha** y **Cerrar**.
- Todo lo valida el servidor (funciones game_invite,
  game_respond, game_move, game_resign): turno, celda libre,
  ganador y empate. No se puede jugar antes de que acepten,
  ni fuera de turno, ni sobre una celda ocupada; el
  historial de movimientos queda guardado.
- Las tablas de juegos ya soportan los próximos títulos del
  roadmap (Conecta 4, Damas, Ludo, Ajedrez) con el mismo
  patrón.

## 11. Operación del acceso anticipado (alfa)

- **Cuenta del equipo:** «PruebaZeth», cuenta invitada
  persistente del equipo de ONEchat, con presentación
  publicada en General y Ayuda.
- **Rondas de monitoreo:** Muse revisa la actividad
  **cada hora entre 07:00 y 22:00 (hora del Pacífico)** con
  esa cuenta: saluda a los testers nuevos, responde dudas de
  uso en Ayuda y en General cuando le hablan al equipo, y
  avisa a Mario **solo cuando hay novedades** (testers
  nuevos, preguntas respondidas, fallos o abuso).
- **Lo que PruebaZeth NO hace:** no modera (no tiene
  poderes), no promete funciones ni fechas ni precios, y no
  discute la tecnología interna. Ante abuso, no discute: lo
  reporta a Mario.
- **Límite honesto:** la presencia es por rondas (puede
  haber hasta ~1 hora entre respuestas), no es un chat en
  vivo 24/7. Para avisos inmediatos de Ayuda, Mario tiene el
  HUD de Staff en su propia cuenta.
- Los nombres de prueba del equipo usan siempre «Zeth»
  (regla de Mario), p. ej. PruebaZeth.

## 12. Publicar una versión nueva (procedimiento)

1. Se edita el código en el repositorio (carpeta app).
2. Verificación local: análisis de código sin errores y
   pruebas aprobadas.
3. Se compila la web con base /onechat/ y se sube el
   repositorio a GitHub (rama main = código, rama gh-pages =
   web publicada) con la herramienta de publicación del
   proyecto.
4. GitHub Pages tarda ~1 minuto en servir la versión nueva;
   se confirma comparando la huella (MD5) del archivo
   principal servido contra el compilado.
5. **Sello de versión:** cada versión lleva un sello visible
   al final de la pestaña **Perfil** («ONEchat ·
   vAAAA.MM.DD.N»). Al probar un arreglo, primero confirmar
   que el Perfil muestra el sello nuevo.

**La caché del navegador (causa n.º 1 de «sigue fallando»):**
la web guarda copias de la app para cargar rápido y puede
seguir ejecutando la versión anterior aunque se recargue una
vez. Si un fallo «persiste» tras publicar el arreglo: cerrar
la pestaña y volver a abrir el enlace, y confirmar el sello
de versión en el Perfil antes de reportar.

**Toda función del servidor que la app llama debe manejar
CORS** (incluida la respuesta a la verificación previa del
navegador). Su ausencia fue la causa raíz del fallo de
ingreso del 23-11-2026: la contraseña de Mario siempre fue
correcta; el navegador bloqueaba la respuesta.

## 13. Base de datos y migraciones

Proyecto Supabase «onechat» (ref jsdyoqmgdkqlkucebjmt).
Las migraciones se aplican en orden desde el SQL Editor del
panel; los archivos viven en la carpeta supabase del
repositorio:

| Versión | Contenido |
|---|---|
| v0 | Esquema base: 16 tablas (perfiles, salas, mensajes, privados, susurros, favoritos, bloqueos, reportes, juegos, notificaciones, auditoría…) |
| v1 | Políticas de seguridad (RLS) y publicación en tiempo real |
| v1.1 | Permisos (grants) de las tablas |
| v1.2 – v1.2.1 | Reclamo de nickname de invitado y ajustes |
| v1.3 | Nombre del remitente guardado en cada mensaje |
| v1.4 | Estado del nickname |
| v1.5 | Permisos para funciones del servidor |
| v1.6 | Etapa 2: privados y susurros |
| v1.7 | Etapa 3: moderación (roles y sanciones por servidor) |
| v1.8 – v1.9 | Salas v2 (30 salas) y Sala General |
| v1.10 | Control de leídos en Ayuda |
| v1.11 | Seguridad: congelamiento de roles y sanciones contra auto-edición |
| v1.12 | Juegos: funciones del Gato en privados |
| v1.13 | Aviso de juego con nombre de quien invita |

Funciones de servidor clave: acceso por nickname
(login-with-nickname y translate son funciones Edge; deben
tener CORS), moderación (can_moderate, moderate_member,
set_room_role) y juegos (game_invite, game_respond,
game_move, game_resign).

## 14. Correo y traducción

**Correo (Brevo, plan gratuito):** 300 correos al día.
Supabase está conectado a Brevo por SMTP (smtp-relay.brevo.com,
puerto 587) con remitente «ONEchat» verificado, y el límite
de Auth quedó en 300 correos por hora (con el remitente
integrado de Supabase serían solo 2 por hora en cualquier
plan). Pendientes conocidos: existen dos claves SMTP de
Brevo y solo una está configurada (borrar la sobrante es
decisión de Mario); antes del lanzamiento público conviene
enviar desde un **dominio propio con DKIM** en vez de la
dirección de Gmail.

**Traducción:** interfaz completa ES/EN (selector en el
Perfil y acceso rápido ES/EN en la bienvenida; se guarda en
la cuenta). La traducción de mensajes usa **MyMemory**
(gratis, sin tarjeta): cupo de 10.000 caracteres al día para
el proyecto. La cuenta de **DeepL** está creada, pero su
plan gratuito exige tarjeta al activarlo y es un crédito
único de 1.000.000 de caracteres; activarlo es decisión y
tarjeta de Mario, y el cambio es tocar solo la función
«translate» del servidor.

## 15. Costos y límites conocidos

| Pieza | Hoy | Nota |
|---|---|---|
| Supabase | Plan Free, US$0 | El plan **Pro (US$25/mes)** se justifica cuando haya usuarios reales |
| GitHub / GitHub Pages | Gratis | Repositorio público |
| Brevo | Gratis, 300 correos/día | Suficiente para el alfa |
| MyMemory | Gratis, 10.000 caracteres/día | Traducción de mensajes |
| DeepL | Sin plan activo | Requiere tarjeta de Mario para activar |

Límite práctico del plan Free de Supabase: las consultas
tardan ~0,4–1,2 s (se nota en los envíos: el mensaje se
muestra al instante de forma provisional y se confirma al
volver la respuesta). Es el costo conocido del alfa, no un
fallo.

## 16. Solución de problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| «El arreglo no se ve» o un fallo «sigue igual» | El navegador ejecuta la versión anterior desde su caché | Cerrar la pestaña, reabrir el enlace y confirmar el sello de versión en el Perfil (§12) |
| Un privado nuevo no aparece en la lista | En versiones antiguas la lista cargaba una sola vez | Actualizar la app (corregido el 24-11-2026: la lista se refresca al entrar y en vivo) |
| Mensajes propios duplicados en pantalla | Eco en tiempo real vs. confirmación del envío; la base nunca guardó duplicados | Corregido el 24-11-2026; si reaparece, revisar primero la versión (caché) |
| La tarjeta del Gato se ve sin botones | Los botones del tema no se pintaban dentro de la tarjeta en web | Corregido el 24-11-2026 con botones propios de la app |
| No puedo entrar con mi nickname y clave | Revisar que el nickname sea el registrado; si es fallo del sistema, revisar CORS de la función de acceso (§12) | Pedir un correo de recuperación nuevo si hace falta (el enlace usado caduca) |
| Un moderador no puede sancionar | Debe tener el rol en ESA sala y la persona debe haber entrado a la sala | El dueño de la sala lo nombra desde la ficha del usuario (§5) |
| No llegan los correos de confirmación | Límite de Brevo (300/día) o correo en spam | Revisar la carpeta de spam y el panel de Brevo |
| La app se siente lenta | Plan Free de Supabase (§15) | Evaluar el plan Pro con usuarios reales |

## 17. Seguridad (resumen de lo ya aplicado)

- **RLS en todas las tablas:** cada quien lee y escribe
  solo lo que le corresponde (privados y susurros legibles
  únicamente por sus participantes).
- **Moderación solo por servidor:** las sanciones pasan por
  funciones que verifican el rol y escriben la auditoría.
- **Congelamiento v1.11:** un usuario no puede cambiarse su
  propio rol global ni quitarse sanciones editando sus
  datos; verificado con ataques de prueba reales.
- **Claves:** la app lleva solo la clave pública
  «publishable». La clave service_role y la contraseña de la
  base de datos jamás salen del panel ni se escriben en
  documentos o chats.
- **Sin contraseñas en el chat:** ninguna contraseña de los
  servicios debe compartirse por chat; se guardan en el
  gestor seguro.

## 18. Respaldos

- **Código:** el repositorio de GitHub es la copia maestra
  (rama main) y la web publicada vive en gh-pages.
- **Documentación:** la carpeta docs del repositorio guarda
  la arquitectura, el detalle por etapa, las salas, la
  ayuda del Staff, los juegos, los arreglos del alfa y la
  lista post-alfa. Este manual es el resumen operativo.
- **Base de datos:** Supabase mantiene la operación del
  proyecto; al pasar al plan Pro se suman respaldos
  automáticos del panel.
- **Este manual:** queda guardado como archivo (PDF y su
  fuente en Markdown dentro del repositorio, en
  docs/MANUAL-ADMINISTRACION.md) para respaldo de Mario.

## 19. Lista post-alfa (anotado, NO implementado)

Se implementa **solo cuando Mario declare cerrado el acceso
anticipado** (detalle completo en docs/CAMBIOS-POST-ALFA.md):

1. Botón «Mencionar» en la ficha del usuario y evaluar
   autocompletado de @.
2. Panel del dueño en la app para dar roles globales.
3. Verificar que todo moderador vea y pueda destacar.
4. Iconos por rango junto al nickname (§5).
5. Que la conversación suba con el teclado (sugerencia de
   tester).
6. Pantalla siempre encendida con el chat abierto.
7. Fallo: el color de nick propio no se refleja en la Sala
   General para el propio usuario (los demás sí lo ven).
8. Videos de YouTube como tarjeta con reproductor dentro de
   la app (sin autoplay).
9. Enlaces que no sean de YouTube en salas: no se publican
   y silencian al autor con escalera creciente (5 min,
   30 min, 2 h, 24 h). Sin baneo automático: el baneo lo
   decide el Staff con el historial.
10. Avisos de moderación en el Status con alcance: dueños y
    moderadores solo de sus salas; dueño global y Staff, de
    todo.
11. Ajuste para abrir/cerrar los privados (los favoritos
    propios siempre pueden escribir).
12. Avisos del sistema dentro de la sala (entradas/salidas
    y sanciones sin mostrar el nick del castigado), con
    interruptor por usuario.
13. Cambio de nickname desde el Perfil (atómico, conserva
    cuenta, roles y membresías).
14. Ajuste para desactivar susurros (anti-acoso; los
    favoritos siempre tienen acceso, igual que en privados).
15. Opción «Copiar» en el menú de toque largo, junto a
    «Traducir».
16. Sonidos del chat y aviso con sonido y vibración al ser
    mencionado, con ajustes por usuario.
17. «Cine juntos» Premium: ver video en simultáneo en
    privado 1:1, solo Premium (vía realista: sincronizar
    YouTube; las plataformas de streaming no permiten
    re-transmisión por licencias).

## 20. Roadmap

- **Etapa 6 — Premium y juegos:** Gato ya adelantado y en
  vivo. Pendientes, a la orden de Mario: sistema Premium
  (incluye «Cine juntos») y los juegos Conecta 4, Damas,
  Ludo y Ajedrez en privados.
- Antes del lanzamiento público: dominio propio para el
  correo (DKIM), evaluar Supabase Pro y activar DeepL si el
  cupo de traducción se queda corto.

---

*Manual generado el 24 de noviembre de 2026, con la
plataforma en la versión v2026.11.24.6. Ante cualquier
diferencia entre este manual y la app, manda la app: el
manual se actualiza.*
